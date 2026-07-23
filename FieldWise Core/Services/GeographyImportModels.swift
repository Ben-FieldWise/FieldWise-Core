//
//  GeographyImportModels.swift
//  FieldWise Core
//
//  Decode-side models for the .fieldwise.json interchange format produced
//  by FieldWise Geography's InvestigationDataExporter (format_version 2).
//
//  These are intentionally separate types from Geography's own
//  InvestigationExport/ExportedSite/ExportedFieldRecord -- Core doesn't
//  share a Swift module with Geography, so it decodes the same JSON shape
//  into its own local mirror of it. Field names/CodingKeys below must
//  stay in lockstep with Geography's InvestigationDataExporter.swift if
//  that format ever changes again; the `formatVersion` check in
//  GeographyImportService is the guard against silently misreading a
//  future incompatible shape.
//

import Foundation

struct ImportedFieldRecord: Codable {
    var fieldId: String
    var label: String
    var kind: String     // raw value of Geography's InvField.Kind: text/number/rating/choice/checklist/note
    var unit: String?
    var options: [String]
    var guidance: String?
    var value: ImportedFieldValue

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case label, kind, unit, options, guidance, value
    }
}

/// Mirrors Geography's InvFieldValue shape exactly (same field names),
/// since that struct's Codable derivation encodes/decodes each member
/// directly with no custom keys.
struct ImportedFieldValue: Codable {
    var text: String
    var number: Double?
    var rating: Int
    var choice: String
    var checklist: [String]
}

struct ImportedSite: Codable {
    var name: String
    var latitude: Double?
    var longitude: Double?
    var recordedAt: Date?
    var observationNotes: String
    var photoFilenames: [String]
    var fields: [ImportedFieldRecord]

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, fields
        case recordedAt = "recorded_at"
        case observationNotes = "observation_notes"
        case photoFilenames = "photo_filenames"
    }
}

struct InvestigationImport: Codable {
    var formatVersion: Int
    var title: String
    var templateId: String
    var createdAt: Date
    var updatedAt: Date

    var question: String
    var prediction: String
    var explanation: String
    var evaluation: String
    var conclusion: String
    var countryReflection: String?

    var sites: [ImportedSite]

    enum CodingKeys: String, CodingKey {
        case title, question, prediction, explanation, evaluation, conclusion, sites
        case formatVersion = "format_version"
        case templateId = "template_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case countryReflection = "country_reflection"
    }
}
