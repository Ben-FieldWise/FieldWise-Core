//
//  WorksheetModels.swift
//  FieldWise Core
//
//  Codable models for the Phase 1A worksheet-builder tables:
//  fieldwork_sheets / worksheet_sections / worksheet_questions
//  (+ light Excursion / FieldworkTemplate). These map camelCase Swift
//  properties to the tables' snake_case columns via CodingKeys.
//
//  Convention (matches SupabaseService): the `id` and server timestamps
//  ARE decoded on reads; inserts use dedicated payload structs in
//  WorksheetService so the DB fills id / created_at / updated_at.
//

import Foundation

// MARK: - Question types

enum WorksheetQuestionType: String, Codable, CaseIterable, Identifiable {
    case shortAnswer   = "short_answer"
    case longAnswer    = "long_answer"
    case multipleChoice = "multiple_choice"
    case checkbox
    case photoUpload   = "photo_upload"
    case gpsPoint      = "gps_point"
    case ratingScale   = "rating_scale"
    case dataTable     = "data_table"
    case sketch
    case teacherNote   = "teacher_note"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortAnswer: return "Short answer"
        case .longAnswer: return "Long answer"
        case .multipleChoice: return "Multiple choice"
        case .checkbox: return "Checkboxes"
        case .photoUpload: return "Photo"
        case .gpsPoint: return "GPS point"
        case .ratingScale: return "Rating scale"
        case .dataTable: return "Data table"
        case .sketch: return "Sketch"
        case .teacherNote: return "Teacher note"
        }
    }

    var icon: String {
        switch self {
        case .shortAnswer: return "textformat"
        case .longAnswer: return "text.alignleft"
        case .multipleChoice: return "list.bullet.circle"
        case .checkbox: return "checklist"
        case .photoUpload: return "camera.fill"
        case .gpsPoint: return "mappin.and.ellipse"
        case .ratingScale: return "star.fill"
        case .dataTable: return "tablecells"
        case .sketch: return "pencil.and.outline"
        case .teacherNote: return "info.circle.fill"
        }
    }

    /// Whether the builder should show the choice/scale/column editor.
    var usesOptions: Bool {
        switch self {
        case .multipleChoice, .checkbox, .ratingScale, .dataTable: return true
        default: return false
        }
    }
}

/// A single seed/default value carried on an imported question — the
/// original recorded answer from a Geography investigation, used to
/// pre-populate a fresh student_responses row the first time someone
/// answers this question in Core. Nil for every question authored
/// directly in Core (the Phase 1A/1D builder never sets this).
///
/// Kept as its own type rather than reusing SessionAnswerValue:
/// SessionAnswerValue's Codable implementation is a decoder-only "try
/// each shape in turn" pattern tuned for round-tripping
/// student_responses.answers, and an Int-shaped seed value would be
/// genuinely ambiguous against WorksheetQuestionOptions' own
/// `min`/`max: Int?` fields if decoded the same permissive way. The
/// explicit `kind` tag here avoids that.
enum SeedValue: Codable, Equatable {
    case string(String)
    case stringArray([String])
    case int(Int)

    private enum Kind: String, Codable { case string, stringArray, int }
    private enum CodingKeys: String, CodingKey { case kind, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .string: self = .string(try c.decode(String.self, forKey: .value))
        case .stringArray: self = .stringArray(try c.decode([String].self, forKey: .value))
        case .int: self = .int(try c.decode(Int.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let v):
            try c.encode(Kind.string, forKey: .kind)
            try c.encode(v, forKey: .value)
        case .stringArray(let v):
            try c.encode(Kind.stringArray, forKey: .kind)
            try c.encode(v, forKey: .value)
        case .int(let v):
            try c.encode(Kind.int, forKey: .kind)
            try c.encode(v, forKey: .value)
        }
    }

    /// Converts to the shape SessionAnswerValue needs when pre-populating
    /// a fresh response — see WorksheetFillView's initial-value fallback.
    /// SessionAnswerValue is defined in SessionModels.swift (Phase 1C),
    /// not this file; its .string/.stringArray/.int cases are the ones
    /// this seed data actually needs (it also has .table and .null,
    /// which SeedValue never produces).
    var asAnswerValue: SessionAnswerValue {
        switch self {
        case .string(let v): return .string(v)
        case .stringArray(let v): return .stringArray(v)
        case .int(let v): return .int(v)
        }
    }
}

/// Flexible option payload stored in the `options` jsonb column. All
/// optional so an empty `{}` decodes cleanly and unused fields are omitted.
struct WorksheetQuestionOptions: Codable, Equatable {
    var choices: [String]?     // multiple_choice / checkbox
    var min: Int?              // rating_scale
    var max: Int?              // rating_scale
    var columns: [String]?     // data_table
    var seedValue: SeedValue?  // set only by the Geography import; nil otherwise

    init(choices: [String]? = nil, min: Int? = nil, max: Int? = nil, columns: [String]? = nil,
         seedValue: SeedValue? = nil) {
        self.choices = choices; self.min = min; self.max = max; self.columns = columns
        self.seedValue = seedValue
    }
}

// MARK: - Sheet

struct FieldworkSheet: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var description: String?
    var templateId: String?
    var excursionId: String?
    var subjectArea: String?
    var yearLevel: String?
    var createdBy: String
    var schoolId: String?
    var visibility: String
    var version: Int
    var status: String
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, visibility, version, status
        case templateId = "template_id"
        case excursionId = "excursion_id"
        case subjectArea = "subject_area"
        case yearLevel = "year_level"
        case createdBy = "created_by"
        case schoolId = "school_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func == (lhs: FieldworkSheet, rhs: FieldworkSheet) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Section

struct WorksheetSection: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var sheetId: String
    var title: String
    var instructions: String?
    var sectionOrder: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, instructions
        case sheetId = "sheet_id"
        case sectionOrder = "section_order"
        case createdAt = "created_at"
    }

    // Identity-based Hashable/Equatable (id only), matching
    // FieldworkSheet's rationale above: this type now drives
    // .navigationDestination(item:) in SheetEditorView (for
    // QuestionReorderView), and default field-wise hashing would change
    // as `title`/`instructions`/`sectionOrder` are edited, risking the
    // same "no matching navigationDestination" failure documented on
    // FieldworkSheet.
    static func == (lhs: WorksheetSection, rhs: WorksheetSection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Question

struct WorksheetQuestion: Codable, Identifiable, Equatable {
    var id: String
    var sectionId: String
    var questionType: WorksheetQuestionType
    var prompt: String
    var options: WorksheetQuestionOptions
    var required: Bool
    var requiredTool: String?
    var questionOrder: Int
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, prompt, options, required
        case sectionId = "section_id"
        case questionType = "question_type"
        case requiredTool = "required_tool"
        case questionOrder = "question_order"
        case createdAt = "created_at"
    }
}

// MARK: - Excursion (light)

struct Excursion: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var description: String?
    var locationName: String?
    var suburb: String?
    var state: String?
    var latitude: Double?
    var longitude: Double?
    var siteType: String?
    var createdBy: String?
    var visibility: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, suburb, state, latitude, longitude, visibility
        case locationName = "location_name"
        case siteType = "site_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

// MARK: - Template (light)

struct FieldworkTemplate: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var description: String?
    var subjectArea: String?
    var topic: String?
    var visibility: String
    var isOfficial: Bool
    var createdBy: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, topic, visibility
        case subjectArea = "subject_area"
        case isOfficial = "is_official"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
