//
//  WorksheetStore.swift
//  FieldWise Core
//
//  Observable view-model over WorksheetService for the worksheet builder:
//  a teacher's sheets, and the sections/questions of whichever sheet is
//  currently open. Mirrors the ClassroomStore pattern (run/errorText).
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class WorksheetStore: ObservableObject {

    private let service = WorksheetService()

    @Published var sheets: [FieldworkSheet] = []
    @Published var sections: [WorksheetSection] = []
    @Published var questionsBySection: [String: [WorksheetQuestion]] = [:]
    @Published var isLoading = false
    @Published var errorText: String?

    // MARK: - Sheets

    func loadMySheets(teacherId: String) async {
        await run { self.sheets = try await self.service.fetchMySheets(createdBy: teacherId) }
    }

    @discardableResult
    func createSheet(teacherId: String, title: String, description: String?,
                      subjectArea: String?, yearLevel: String?) async -> FieldworkSheet? {
        var created: FieldworkSheet?
        await run {
            let sheet = try await self.service.createSheet(
                createdBy: teacherId, title: title, description: description,
                subjectArea: subjectArea, yearLevel: yearLevel)
            self.sheets.insert(sheet, at: 0)
            created = sheet
        }
        return created
    }

    func renameSheet(_ sheet: FieldworkSheet, title: String, description: String?) async {
        await run {
            try await self.service.renameSheet(id: sheet.id, title: title, description: description)
            if let i = self.sheets.firstIndex(where: { $0.id == sheet.id }) {
                self.sheets[i].title = title
                self.sheets[i].description = description
            }
        }
    }

    func setStatus(_ sheet: FieldworkSheet, status: String) async {
        await run {
            try await self.service.setSheetStatus(id: sheet.id, status: status)
            if let i = self.sheets.firstIndex(where: { $0.id == sheet.id }) {
                self.sheets[i].status = status
            }
        }
    }

    func deleteSheet(_ sheet: FieldworkSheet) async {
        await run {
            try await self.service.deleteSheet(id: sheet.id)
            self.sheets.removeAll { $0.id == sheet.id }
        }
    }

    /// Duplicates a sheet (own copy of every section/question) and
    /// inserts the new sheet at the top of the list, mirroring
    /// createSheet's placement so a teacher immediately sees the copy
    /// they just made.
    @discardableResult
    func duplicateSheet(_ sheet: FieldworkSheet, teacherId: String) async -> FieldworkSheet? {
        var created: FieldworkSheet?
        await run {
            let copy = try await self.service.duplicateSheet(sheet, createdBy: teacherId)
            self.sheets.insert(copy, at: 0)
            created = copy
        }
        return created
    }

    // MARK: - Sheet detail (sections + questions)

    func loadDetail(sheetId: String) async {
        print("loadDetail called for sheetId: \(sheetId)")
        await run {
            self.sections = try await self.service.fetchSections(sheetId: sheetId)
            print("fetched \(self.sections.count) sections")
            var map: [String: [WorksheetQuestion]] = [:]
            for section in self.sections {
                map[section.id] = try await self.service.fetchQuestions(sectionId: section.id)
            }
            self.questionsBySection = map
        }
    }

    @discardableResult
    func addSection(sheetId: String, title: String, instructions: String?) async -> WorksheetSection? {
        var created: WorksheetSection?
        await run {
            let section = try await self.service.addSection(
                sheetId: sheetId, title: title, instructions: instructions,
                order: self.sections.count)
            self.sections.append(section)
            self.questionsBySection[section.id] = []
            created = section
        }
        return created
    }

    func deleteSection(_ section: WorksheetSection) async {
        await run {
            try await self.service.deleteSection(id: section.id)
            self.sections.removeAll { $0.id == section.id }
            self.questionsBySection.removeValue(forKey: section.id)
        }
    }

    /// Reorders sections after a drag in the builder's List. Moves the
    /// local array immediately (matching List's own .onMove semantics,
    /// so the UI reflects the drop position with no flicker or delay),
    /// then persists the full new order in the background.
    ///
    /// Deliberately does NOT roll the local move back on a persistence
    /// failure: `errorText` will surface the problem, and a reload of
    /// the sheet (e.g. via pull-to-refresh, or just re-opening it) would
    /// resync to the server's actual order at that point. Rolling back
    /// a drag the person just performed, mid-gesture-feeling, would be a
    /// more confusing experience than a delayed error banner for what's
    /// a low-stakes, easily-repeated action.
    ///
    /// Bounds-checked before calling move() — see reorderQuestions below
    /// for why: an out-of-range IndexSet/destination crashes with
    /// EXC_BREAKPOINT inside Collection.formIndex(after:) rather than
    /// failing gracefully, and it costs nothing to guard against it here
    /// too even though sections (unlike nested questions) aren't spread
    /// across multiple ForEach/.onMove pairs.
    func reorderSections(sheetId: String, from source: IndexSet, to destination: Int) async {
        let count = sections.count
        guard destination >= 0, destination <= count,
              source.allSatisfy({ $0 >= 0 && $0 < count }) else {
            return
        }
        sections.move(fromOffsets: source, toOffset: destination)
        let orderedIds = sections.map { $0.id }
        await run {
            try await self.service.reorderSections(sheetId: sheetId, orderedIds: orderedIds)
        }
    }

    @discardableResult
    func addQuestion(sectionId: String, type: WorksheetQuestionType, prompt: String,
                      options: WorksheetQuestionOptions, required: Bool,
                      requiredTool: String?) async -> WorksheetQuestion? {
        var created: WorksheetQuestion?
        await run {
            let order = self.questionsBySection[sectionId]?.count ?? 0
            let question = try await self.service.addQuestion(
                sectionId: sectionId, type: type, prompt: prompt, options: options,
                required: required, requiredTool: requiredTool, order: order)
            self.questionsBySection[sectionId, default: []].append(question)
            created = question
        }
        return created
    }

    func deleteQuestion(_ question: WorksheetQuestion) async {
        await run {
            try await self.service.deleteQuestion(id: question.id)
            self.questionsBySection[question.sectionId]?.removeAll { $0.id == question.id }
        }
    }

    /// Reorders questions within one section after a drag, same
    /// move-immediately-then-persist approach as reorderSections above.
    ///
    /// Validates `source`/`destination` against the section's actual
    /// question count before calling move(). This guards against a real
    /// crash that occurs when the List's nested Section/ForEach structure
    /// (one ForEach of sections, each containing its own ForEach of
    /// questions with its own .onMove) is used to drag a question across
    /// a section boundary: SwiftUI can hand back offsets computed against
    /// a different section's item count than the one actually named in
    /// this call, and calling Array.move(fromOffsets:toOffset:) with an
    /// out-of-bounds index/offset traps with EXC_BREAKPOINT inside
    /// Collection.formIndex(after:) rather than failing gracefully.
    /// Cross-section question moves aren't a supported operation here —
    /// reordering only ever means "within this section" — so an
    /// out-of-range request is simply dropped rather than attempted.
    func reorderQuestions(sectionId: String, from source: IndexSet, to destination: Int) async {
        guard var questions = questionsBySection[sectionId] else { return }
        let count = questions.count
        guard destination >= 0, destination <= count,
              source.allSatisfy({ $0 >= 0 && $0 < count }) else {
            return
        }
        questions.move(fromOffsets: source, toOffset: destination)
        questionsBySection[sectionId] = questions
        let orderedIds = questions.map { $0.id }
        await run {
            try await self.service.reorderQuestions(sectionId: sectionId, orderedIds: orderedIds)
        }
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> Void) async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do { try await work() }
        catch { errorText = error.localizedDescription }
    }
}
