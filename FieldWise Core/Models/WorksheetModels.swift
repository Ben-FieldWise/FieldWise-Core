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

/// Flexible option payload stored in the `options` jsonb column. All
/// optional so an empty `{}` decodes cleanly and unused fields are omitted.
struct WorksheetQuestionOptions: Codable, Equatable {
    var choices: [String]?     // multiple_choice / checkbox
    var min: Int?              // rating_scale
    var max: Int?              // rating_scale
    var columns: [String]?     // data_table

    init(choices: [String]? = nil, min: Int? = nil, max: Int? = nil, columns: [String]? = nil) {
        self.choices = choices; self.min = min; self.max = max; self.columns = columns
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

    // Custom Hashable/Equatable: identity for navigation purposes (and any
    // other place this type is used as a NavigationLink/dictionary/Set
    // value) should be `id` alone, matching Identifiable. The default
    // synthesized Hashable hashes every stored property, so if `updatedAt`
    // (or any other field) changes on a row between when a NavigationLink
    // is created and when SwiftUI resolves the tap against its
    // .navigationDestination(for:), the hash no longer matches and the
    // link silently fails to activate ("no matching navigationDestination
    // declaration" / "declared earlier on the stack").
    static func == (lhs: FieldworkSheet, rhs: FieldworkSheet) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Section

struct WorksheetSection: Codable, Identifiable, Equatable {
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
