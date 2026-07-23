//
//  WorksheetService.swift
//  FieldWise Core
//
//  Data layer for the worksheet builder (Phase 1A tables). Mirrors the
//  shape of SupabaseService but is a separate class so it doesn't touch
//  the existing file. RLS enforces access server-side; these calls just
//  shape reads/writes. Ownership (`created_by`) is passed in from the
//  signed-in teacher's uid (AuthService.uid) since there's no DB default.
//

import Foundation
import Supabase

final class WorksheetService {

    private let client = SupabaseManager.shared.client

    // MARK: - Insert payloads (snake_case → columns; no id / timestamps)

    private struct SheetInsert: Encodable {
        let title: String
        let created_by: String
        let visibility: String
        let status: String
        let description: String?
        let subject_area: String?
        let year_level: String?
        let template_id: String?
        let excursion_id: String?
        let school_id: String?
    }

    private struct SectionInsert: Encodable {
        let sheet_id: String
        let title: String
        let instructions: String?
        let section_order: Int
    }

    private struct QuestionInsert: Encodable {
        let section_id: String
        let question_type: String
        let prompt: String
        let options: WorksheetQuestionOptions
        let required: Bool
        let required_tool: String?
        let question_order: Int
    }

    // MARK: - Sheets

    func createSheet(createdBy: String,
                     title: String,
                     description: String? = nil,
                     subjectArea: String? = nil,
                     yearLevel: String? = nil,
                     templateId: String? = nil,
                     excursionId: String? = nil,
                     schoolId: String? = nil) async throws -> FieldworkSheet {
        let payload = SheetInsert(
            title: title, created_by: createdBy,
            visibility: "private", status: "draft",
            description: description, subject_area: subjectArea, year_level: yearLevel,
            template_id: templateId, excursion_id: excursionId, school_id: schoolId
        )
        let sheet: FieldworkSheet = try await client
            .from("fieldwork_sheets").insert(payload).select().single().execute().value
        return sheet
    }

    func fetchMySheets(createdBy: String) async throws -> [FieldworkSheet] {
        try await client
            .from("fieldwork_sheets").select()
            .eq("created_by", value: createdBy)
            .order("updated_at", ascending: false)
            .execute().value
    }

    func fetchSheet(id: String) async throws -> FieldworkSheet {
        try await client
            .from("fieldwork_sheets").select().eq("id", value: id).single().execute().value
    }

    func setSheetStatus(id: String, status: String) async throws {
        struct StatusPatch: Encodable { let status: String; let updated_at: String }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("fieldwork_sheets")
            .update(StatusPatch(status: status, updated_at: now))
            .eq("id", value: id).execute()
    }

    func renameSheet(id: String, title: String, description: String?) async throws {
        struct Patch: Encodable { let title: String; let description: String?; let updated_at: String }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("fieldwork_sheets")
            .update(Patch(title: title, description: description, updated_at: now))
            .eq("id", value: id).execute()
    }

    func deleteSheet(id: String) async throws {
        // sections + questions cascade via FK ON DELETE CASCADE
        try await client.from("fieldwork_sheets").delete().eq("id", value: id).execute()
    }

    /// Creates an independent copy of a sheet — new fieldwork_sheets row
    /// (own id, always starts as draft/private regardless of the
    /// original's status/visibility), plus a copy of every section and
    /// question. Deliberately built on top of createSheet/addSection/
    /// addQuestion rather than a bespoke bulk-insert, so duplication
    /// always goes through the same validated write path as manual
    /// authoring — if those methods' behavior ever changes, duplication
    /// automatically stays consistent with it rather than silently
    /// drifting out of sync.
    ///
    /// Sections/questions are copied in original order but their
    /// section_order/question_order values are preserved as-is (not
    /// recomputed), since addSection/addQuestion take an explicit order
    /// parameter and the originals' order is already correct.
    func duplicateSheet(_ original: FieldworkSheet, createdBy: String) async throws -> FieldworkSheet {
        let newTitle = "\(original.title) (Copy)"
        let newSheet = try await createSheet(
            createdBy: createdBy,
            title: newTitle,
            description: original.description,
            subjectArea: original.subjectArea,
            yearLevel: original.yearLevel,
            templateId: original.templateId,
            excursionId: original.excursionId,
            schoolId: original.schoolId
        )

        let sections = try await fetchSections(sheetId: original.id)
        for section in sections {
            let newSection = try await addSection(
                sheetId: newSheet.id,
                title: section.title,
                instructions: section.instructions,
                order: section.sectionOrder
            )
            let questions = try await fetchQuestions(sectionId: section.id)
            for question in questions {
                _ = try await addQuestion(
                    sectionId: newSection.id,
                    type: question.questionType,
                    prompt: question.prompt,
                    options: question.options,
                    required: question.required,
                    requiredTool: question.requiredTool,
                    order: question.questionOrder
                )
            }
        }

        return newSheet
    }

    // MARK: - Sections

    func fetchSections(sheetId: String) async throws -> [WorksheetSection] {
        try await client
            .from("worksheet_sections").select()
            .eq("sheet_id", value: sheetId)
            .order("section_order", ascending: true)
            .execute().value
    }

    func addSection(sheetId: String, title: String, instructions: String? = nil, order: Int) async throws -> WorksheetSection {
        let payload = SectionInsert(sheet_id: sheetId, title: title, instructions: instructions, section_order: order)
        return try await client
            .from("worksheet_sections").insert(payload).select().single().execute().value
    }

    func deleteSection(id: String) async throws {
        try await client.from("worksheet_sections").delete().eq("id", value: id).execute()
    }

    /// Persists a new section order after a drag-to-reorder. Takes the
    /// full ordered list of section ids (post-drag) and writes each
    /// one's new section_order in turn.
    ///
    /// This is N individual UPDATE calls rather than a single bulk
    /// upsert: worksheet_sections' RLS policy checks ownership per row
    /// via the parent fieldwork_sheets.owner_id, and a single multi-row
    /// upsert would need every row to already exist with matching
    /// unique keys for Supabase's upsert-by-conflict-target to target
    /// section_order safely. Individual updates by id sidestep that
    /// entirely and match the same per-row update style already used by
    /// setSheetStatus/renameSheet above. A worksheet has at most a
    /// handful of sections, so the extra round trips are not a real
    /// performance concern.
    func reorderSections(sheetId: String, orderedIds: [String]) async throws {
        struct OrderPatch: Encodable { let section_order: Int }
        for (index, id) in orderedIds.enumerated() {
            try await client.from("worksheet_sections")
                .update(OrderPatch(section_order: index))
                .eq("id", value: id)
                .eq("sheet_id", value: sheetId)
                .execute()
        }
    }

    // MARK: - Questions

    func fetchQuestions(sheetId: String) async throws -> [WorksheetQuestion] {
        // All questions across the sheet's sections, ordered.
        let sections = try await fetchSections(sheetId: sheetId)
        let ids = sections.map { $0.id }
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("worksheet_questions").select()
            .in("section_id", values: ids)
            .order("question_order", ascending: true)
            .execute().value
    }

    func fetchQuestions(sectionId: String) async throws -> [WorksheetQuestion] {
        try await client
            .from("worksheet_questions").select()
            .eq("section_id", value: sectionId)
            .order("question_order", ascending: true)
            .execute().value
    }

    func addQuestion(sectionId: String,
                     type: WorksheetQuestionType,
                     prompt: String,
                     options: WorksheetQuestionOptions? = nil,
                     required: Bool = false,
                     requiredTool: String? = nil,
                     order: Int) async throws -> WorksheetQuestion {
        let resolvedOptions = options ?? WorksheetQuestionOptions()
        let payload = QuestionInsert(
            section_id: sectionId, question_type: type.rawValue, prompt: prompt,
            options: resolvedOptions, required: required, required_tool: requiredTool, question_order: order
        )
        return try await client
            .from("worksheet_questions").insert(payload).select().single().execute().value
    }

    func deleteQuestion(id: String) async throws {
        try await client.from("worksheet_questions").delete().eq("id", value: id).execute()
    }

    /// Persists a new question order within a section after a drag-to-
    /// reorder, same per-row update approach as reorderSections above.
    func reorderQuestions(sectionId: String, orderedIds: [String]) async throws {
        struct OrderPatch: Encodable { let question_order: Int }
        for (index, id) in orderedIds.enumerated() {
            try await client.from("worksheet_questions")
                .update(OrderPatch(question_order: index))
                .eq("id", value: id)
                .eq("section_id", value: sectionId)
                .execute()
        }
    }

    // MARK: - Excursions / templates (read helpers for the builder pickers)

    func fetchMyExcursions(createdBy: String) async throws -> [Excursion] {
        // RLS also returns official/library rows; this filters to the teacher's own.
        try await client
            .from("excursions").select()
            .or("created_by.eq.\(createdBy),visibility.eq.official")
            .order("created_at", ascending: false)
            .execute().value
    }

    func fetchTemplates() async throws -> [FieldworkTemplate] {
        // RLS returns own + official + approved-library.
        try await client
            .from("fieldwork_templates").select()
            .order("created_at", ascending: false)
            .execute().value
    }
}
