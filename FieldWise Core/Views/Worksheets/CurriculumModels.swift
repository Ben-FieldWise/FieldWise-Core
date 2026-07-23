//
//  CurriculumModels.swift
//  FieldWise Core
//
//  Codable models for the Phase 1E curriculum mapping tables
//  (curriculum_frameworks -> ... -> curriculum_points -> curriculum_elaborations,
//  plus the sheet_curriculum_links join). Mirrors the shape and Hashable-by-id
//  pattern used by FieldworkSheet/WorksheetSection elsewhere in Core.
//

import Foundation

// MARK: - Reference data (read-only from the app's point of view)

struct CurriculumSubstrand: Codable, Identifiable, Hashable {
    var id: String
    var strandId: String
    var name: String
    var levelBand: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case strandId = "strand_id"
        case levelBand = "level_band"
        case createdAt = "created_at"
    }

    static func == (lhs: CurriculumSubstrand, rhs: CurriculumSubstrand) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CurriculumElaboration: Codable, Identifiable, Hashable {
    var id: String
    var curriculumPointId: String
    var body: String
    var sortOrder: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case curriculumPointId = "curriculum_point_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    static func == (lhs: CurriculumElaboration, rhs: CurriculumElaboration) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A single gradeable curriculum point (VCAA "content description"), the
/// thing a teacher actually attaches to a worksheet. Nests its substrand
/// name/strand name/elaborations via a Supabase embedded-select so the
/// picker UI can group and display without N+1 queries.
struct CurriculumPoint: Codable, Identifiable, Hashable {
    var id: String
    var substrandId: String
    var code: String
    var levelBand: String
    var description: String
    var sortOrder: Int?
    var createdAt: Date?
    var updatedAt: Date?

    // Populated only when fetched via the embedded query in
    // CurriculumService.fetchPoints(...) — nil otherwise.
    var substrand: CurriculumSubstrandEmbed?
    var elaborations: [CurriculumElaboration]?

    enum CodingKeys: String, CodingKey {
        case id, code, description
        case substrandId = "substrand_id"
        case levelBand = "level_band"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case substrand = "curriculum_substrands"
        case elaborations = "curriculum_elaborations"
    }

    static func == (lhs: CurriculumPoint, rhs: CurriculumPoint) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Nested substrand -> strand names as returned by the embedded select in
/// fetchPoints. Kept separate from CurriculumSubstrand (the standalone
/// fetch shape) since the embed only carries names, not the full row.
struct CurriculumSubstrandEmbed: Codable, Hashable {
    var name: String
    var levelBand: String
    var strand: CurriculumStrandEmbed?

    enum CodingKeys: String, CodingKey {
        case name
        case levelBand = "level_band"
        case strand = "curriculum_strands"
    }
}

struct CurriculumStrandEmbed: Codable, Hashable {
    var name: String
}

// MARK: - The MVP link (writable)

/// One "this worksheet covers this outcome" link. Workbook-level only for
/// the MVP — see schema.sql notes for how this extends to section/question
/// level later without altering this shape.
struct SheetCurriculumLink: Codable, Identifiable, Hashable {
    var id: String
    var sheetId: String
    var curriculumPointId: String
    var createdBy: String
    var createdAt: Date?

    // Populated only when fetched with the embedded point (for display in
    // the "linked outcomes" list on a sheet) — nil on plain link fetches.
    var curriculumPoint: CurriculumPoint?

    enum CodingKeys: String, CodingKey {
        case id
        case sheetId = "sheet_id"
        case curriculumPointId = "curriculum_point_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case curriculumPoint = "curriculum_points"
    }

    static func == (lhs: SheetCurriculumLink, rhs: SheetCurriculumLink) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
