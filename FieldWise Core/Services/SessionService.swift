//
//  SessionService.swift
//  FieldWise Core
//
//  Data layer for Phase 1C (fieldwork_sessions / student_responses).
//  Mirrors WorksheetService's shape — a separate class so it doesn't
//  touch existing files. RLS enforces access server-side; these calls
//  just shape reads/writes.
//

import Foundation
import Supabase

final class SessionService {

    private let client = SupabaseManager.shared.client

    // MARK: - Insert / patch payloads

    private struct SessionInsert: Encodable {
        let sheet_id: String
        let created_by: String
        let class_id: String?
        let session_code: String
    }

    private struct SessionStatusPatch: Encodable { let status: String; let updated_at: String }
    private struct SessionEditPatch: Encodable { let class_id: String; let session_code: String; let updated_at: String }

    private struct AnswersPatch: Encodable {
        let answers: [String: SessionAnswerValue]
        let status: String
        let submitted_at: String?
        let updated_at: String
    }

    private struct AutosavePatch: Encodable {
        let answers: [String: SessionAnswerValue]
        let updated_at: String
    }

    private struct ReviewedPatch: Encodable {
        let status: String
        let reviewed_at: String
        let updated_at: String
    }

    private struct CodeParam: Encodable { let code: String }

    // MARK: - Teacher: publish / manage sessions

    func createSession(sheetId: String, createdBy: String, classId: String? = nil) async throws -> FieldworkSession {
        for attempt in 0..<3 {
            let code = Self.generateCode()
            let payload = SessionInsert(sheet_id: sheetId, created_by: createdBy, class_id: classId, session_code: code)
            do {
                let session: FieldworkSession = try await client
                    .from("fieldwork_sessions").insert(payload).select().single().execute().value
                return session
            } catch {
                if attempt == 2 { throw error }
                continue
            }
        }
        throw AuthError.classCodeNotFound
    }

    func fetchMySessions(createdBy: String) async throws -> [FieldworkSession] {
        try await client
            .from("fieldwork_sessions").select()
            .eq("created_by", value: createdBy)
            .order("created_at", ascending: false)
            .execute().value
    }

    func fetchSessions(sheetId: String) async throws -> [FieldworkSession] {
        try await client
            .from("fieldwork_sessions").select()
            .eq("sheet_id", value: sheetId)
            .order("created_at", ascending: false)
            .execute().value
    }

    /// Sessions assigned to a class — the "Worksheets" section on
    /// ClassDetailView. Distinct from fetchSessions(sheetId:) above,
    /// which scopes by the worksheet instead of the class; a session can
    /// only ever belong to one class at a time (SessionEditView already
    /// enforces exactly one classId per session), so no de-duplication
    /// is needed on the result.
    func fetchSessions(classId: String) async throws -> [FieldworkSession] {
        try await client
            .from("fieldwork_sessions").select()
            .eq("class_id", value: classId)
            .order("created_at", ascending: false)
            .execute().value
    }

    func fetchSession(id: String) async throws -> FieldworkSession {
        try await client
            .from("fieldwork_sessions").select().eq("id", value: id).single().execute().value
    }

    func setSessionStatus(id: String, status: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("fieldwork_sessions")
            .update(SessionStatusPatch(status: status, updated_at: now))
            .eq("id", value: id).execute()
    }

    func updateSession(id: String, classId: String, sessionCode: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("fieldwork_sessions")
            .update(SessionEditPatch(class_id: classId, session_code: sessionCode, updated_at: now))
            .eq("id", value: id).execute()
    }

    private struct IdOnly: Decodable { let id: String }
    func countResponses(sessionId: String) async throws -> Int {
        let rows: [IdOnly] = try await client
            .from("student_responses").select("id")
            .eq("session_id", value: sessionId)
            .execute().value
        return rows.count
    }

    func deleteSession(id: String) async throws {
        try await client.from("fieldwork_sessions")
            .delete().eq("id", value: id).execute()
    }

    // MARK: - Teacher: read responses for review

    func fetchResponses(sessionId: String) async throws -> [StudentResponse] {
        try await client
            .from("student_responses").select()
            .eq("session_id", value: sessionId)
            .order("updated_at", ascending: false)
            .execute().value
    }

    func markReviewed(responseId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("student_responses")
            .update(ReviewedPatch(status: "reviewed", reviewed_at: now, updated_at: now))
            .eq("id", value: responseId).execute()
    }

    // MARK: - Student: join + answer

    func joinSession(code: String) async throws -> JoinSessionResult {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let rows: [JoinSessionResult] = try await client
            .rpc("join_session_by_code", params: CodeParam(code: trimmed)).execute().value
        guard let result = rows.first else { throw AuthError.classCodeNotFound }
        return result
    }

    func fetchMyResponse(id: String) async throws -> StudentResponse {
        try await client
            .from("student_responses").select().eq("id", value: id).single().execute().value
    }

    func fetchMyResponses() async throws -> [StudentResponse] {
        try await client
            .from("student_responses").select()
            .order("updated_at", ascending: false)
            .execute().value
    }

    private struct DisplayNameRow: Decodable {
        let id: String
        let displayName: String
    }

    func fetchDisplayNames(for studentIds: [String]) async throws -> [String: String] {
        guard !studentIds.isEmpty else { return [:] }
        let rows: [DisplayNameRow] = try await client
            .from("users").select("id, displayName")
            .in("id", values: studentIds)
            .execute().value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.displayName) })
    }

    func saveDraft(responseId: String, answers: [String: SessionAnswerValue]) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let patch = AutosavePatch(answers: answers, updated_at: now)
        try await client.from("student_responses")
            .update(patch).eq("id", value: responseId).execute()
    }

    func submit(responseId: String, answers: [String: SessionAnswerValue]) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let patch = AnswersPatch(answers: answers, status: "submitted", submitted_at: now, updated_at: now)
        try await client.from("student_responses")
            .update(patch).eq("id", value: responseId).execute()
    }

    // MARK: - Helpers

    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
