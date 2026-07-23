//
//  CurriculumService.swift
//  FieldWise Core
//
//  Data layer for Phase 1E curriculum mapping. Mirrors WorksheetService's
//  shape: its own client, snake_case Encodable insert payloads, RLS does
//  the access-control work server-side.
//
//  Reference data (frameworks -> elaborations) is read-only from the app's
//  perspective — there's no create/update/delete here for those tables.
//  The only writable table is sheet_curriculum_links.
//

import Foundation
import Supabase

final class CurriculumService {

    private let client = SupabaseManager.shared.client

    // MARK: - Reference data reads

    /// Fetches curriculum points for a level band (e.g. "7-8"), with their
    /// substrand/strand names and elaborations embedded in one round trip.
    /// Subject is fixed to "Geography" for now — see note in the picker
    /// view about widening this once other subjects' data is seeded.
    func fetchPoints(levelBand: String, subjectName: String = "Geography") async throws -> [CurriculumPoint] {
        try await client
            .from("curriculum_points")
            .select("""
                id, substrand_id, code, level_band, description, sort_order, created_at, updated_at,
                curriculum_substrands!inner (
                    name, level_band,
                    curriculum_strands!inner (
                        name,
                        curriculum_subjects!inner ( name )
                    )
                ),
                curriculum_elaborations ( id, curriculum_point_id, body, sort_order, created_at )
            """)
            .eq("level_band", value: levelBand)
            .eq("curriculum_substrands.curriculum_strands.curriculum_subjects.name", value: subjectName)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    // MARK: - Sheet <-> curriculum links (the writable MVP table)

    private struct LinkInsert: Encodable {
        let sheet_id: String
        let curriculum_point_id: String
        let created_by: String
    }

    /// Fetches the curriculum points already linked to a sheet, with the
    /// point details embedded so the UI can show code + description
    /// directly without a second fetch.
    func fetchLinks(sheetId: String) async throws -> [SheetCurriculumLink] {
        try await client
            .from("sheet_curriculum_links")
            .select("""
                id, sheet_id, curriculum_point_id, created_by, created_at,
                curriculum_points ( id, substrand_id, code, level_band, description, sort_order, created_at, updated_at )
            """)
            .eq("sheet_id", value: sheetId)
            .execute()
            .value
    }

    @discardableResult
    func linkPoint(sheetId: String, curriculumPointId: String, createdBy: String) async throws -> SheetCurriculumLink {
        try await client
            .from("sheet_curriculum_links")
            .insert(LinkInsert(sheet_id: sheetId, curriculum_point_id: curriculumPointId, created_by: createdBy))
            .select("id, sheet_id, curriculum_point_id, created_by, created_at")
            .single()
            .execute()
            .value
    }

    func unlinkPoint(sheetId: String, curriculumPointId: String) async throws {
        try await client
            .from("sheet_curriculum_links")
            .delete()
            .eq("sheet_id", value: sheetId)
            .eq("curriculum_point_id", value: curriculumPointId)
            .execute()
    }
}
