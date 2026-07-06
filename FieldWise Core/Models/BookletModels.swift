//
//  BookletModels.swift
//  FieldWise Core
//
//  Structured booklet content (a FieldworkTask may point at one) and a
//  student's per-block answers. Mirrors the Supabase booklet* tables;
//  camelCase property names match the column names so PostgREST decodes
//  directly.
//

import Foundation

// MARK: - Block types

enum BookletBlockType: String, Codable {
    case instruction  = "INSTRUCTION"
    case shortText    = "SHORT_TEXT"
    case longText     = "LONG_TEXT"
    case table        = "TABLE"
    case ratingScale  = "RATING_SCALE"
    case checklist    = "CHECKLIST"
    case sketchMap    = "SKETCH_MAP"
    case fieldData    = "FIELD_DATA"
    case photo        = "PHOTO"
    case gate         = "GATE"
}

/// Type-specific setup carried in the block's `config` JSON. All fields
/// optional — only the ones relevant to a given block type are present.
struct BlockConfig: Codable, Hashable {
    var columns: [String]?          // TABLE
    var minRows: Int?               // TABLE
    var rows: [String]?             // RATING_SCALE row labels
    var min: Int?                   // RATING_SCALE
    var max: Int?                   // RATING_SCALE
    var items: [String]?            // CHECKLIST
    var fields: [FieldDef]?         // FIELD_DATA
    var conventions: String?        // SKETCH_MAP (e.g. "BOLTSSNA")
    var gps: Bool?                  // PHOTO
}

struct FieldDef: Codable, Hashable, Identifiable {
    let key: String
    let label: String
    let unit: String?
    var id: String { key }
}

// MARK: - Content

struct BookletTemplate: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let yearLevel: String?
}

struct BookletBlock: Codable, Identifiable {
    let id: String
    let order: Int
    let type: BookletBlockType
    let prompt: String?
    let sourceUrl: String?
    let config: BlockConfig?
}

/// A section with its blocks nested (fetched via a PostgREST embed).
struct BookletSection: Codable, Identifiable {
    let id: String
    let siteId: String?
    let order: Int
    let title: String
    let blocks: [BookletBlock]

    enum CodingKeys: String, CodingKey {
        case id, siteId, order, title
        case blocks = "bookletBlocks"
    }
}

// MARK: - Answers

/// One value that adapts its JSON shape to the block type. Encodes to a
/// bare scalar/array/object so it lands cleanly in the jsonb column.
enum AnswerValue: Codable, Equatable {
    case text(String)                 // SHORT_TEXT / LONG_TEXT
    case table([[String]])            // TABLE (rows of cells)
    case ratings([String: Int])       // RATING_SCALE
    case checklist([String: Bool])    // CHECKLIST
    case fields([String: String])     // FIELD_DATA
    case gate(Bool)                   // GATE
    case empty

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s):      try c.encode(s)
        case .table(let r):     try c.encode(r)
        case .ratings(let m):   try c.encode(m)
        case .checklist(let m): try c.encode(m)
        case .fields(let m):    try c.encode(m)
        case .gate(let b):      try c.encode(b)
        case .empty:            try c.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .empty; return }
        if let b = try? c.decode(Bool.self) { self = .gate(b); return }
        if let s = try? c.decode(String.self) { self = .text(s); return }
        if let r = try? c.decode([[String]].self) { self = .table(r); return }
        if let m = try? c.decode([String: Int].self) { self = .ratings(m); return }
        if let m = try? c.decode([String: Bool].self) { self = .checklist(m); return }
        if let m = try? c.decode([String: String].self) { self = .fields(m); return }
        self = .empty
    }
}

struct BookletResponse: Codable, Identifiable {
    let id: String
    let taskId: String
    let blockId: String
    let studentUid: String
    let value: AnswerValue?
    let status: String
}
