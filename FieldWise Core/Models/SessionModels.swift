//
//  SessionModels.swift
//  FieldWise Core
//
//  Codable models for the Phase 1C tables: fieldwork_sessions /
//  student_responses. Mirrors WorksheetModels' conventions — camelCase
//  Swift properties mapped to snake_case columns via CodingKeys.
//

import Foundation

// MARK: - Session

struct FieldworkSession: Codable, Identifiable, Hashable {
    var id: String
    var sheetId: String
    var createdBy: String
    var classId: String?
    var sessionCode: String
    var status: String          // "active" | "closed"
    var opensAt: Date?
    var closesAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case sheetId = "sheet_id"
        case createdBy = "created_by"
        case classId = "class_id"
        case sessionCode = "session_code"
        case opensAt = "opens_at"
        case closesAt = "closes_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isActive: Bool { status == "active" }
}

// MARK: - Student response

enum StudentResponseStatus: String, Codable {
    case draft
    case submitted
    case reviewed
}

/// One student's answers to a session's worksheet, keyed by
/// `worksheet_questions.id`. Values are stored as loosely-typed JSON so a
/// single jsonb column can hold every question type's answer shape
/// (string, [String], Int, [[String]] for tables, etc.) without a rigid
/// Swift enum on the wire.
struct StudentResponse: Codable, Identifiable, Equatable {
    var id: String
    var sessionId: String
    var studentId: String
    var answers: [String: SessionAnswerValue]
    var status: StudentResponseStatus
    var submittedAt: Date?
    var reviewedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, answers, status
        case sessionId = "session_id"
        case studentId = "student_id"
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A permissive JSON value so `answers` can hold whatever shape a
/// question type needs. Kept intentionally small — just enough for the
/// worksheet question types in WorksheetModels.swift.
enum SessionAnswerValue: Codable, Equatable {
    case string(String)
    case stringArray([String])
    case int(Int)
    case table([[String]])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode([String].self) { self = .stringArray(v); return }
        if let v = try? c.decode([[String]].self) { self = .table(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .stringArray(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .table(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    // MARK: Convenience accessors for the fill-in view

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var stringArrayValue: [String] {
        if case .stringArray(let v) = self { return v }
        return []
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var tableValue: [[String]] {
        if case .table(let v) = self { return v }
        return []
    }
}

// MARK: - join_session_by_code RPC result

/// Decodes the single row returned by the `join_session_by_code` RPC.
struct JoinSessionResult: Decodable {
    var sessionId: String
    var sheetId: String
    var sessionStatus: String
    var responseId: String
    var responseStatus: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case sheetId = "sheet_id"
        case sessionStatus = "session_status"
        case responseId = "response_id"
        case responseStatus = "response_status"
    }
}
