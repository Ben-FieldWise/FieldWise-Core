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

    private struct AnswersPatch: Encodable {
        let answers: [String: SessionAnswerValue]
        let status: String
        let submitted_at: String?
        let updated_at: String
    }

    private struct ReviewedPatch: Encodable {
        let status: String
        let reviewed_at: String
        let updated_at: String
    }

    private struct CodeParam: Encodable { let code: String }

    // MARK: - Teacher: publish / manage sessions

    /// Publishes a sheet by creating a session with a fresh join code.
    /// Retries once on the (very unlikely) chance of a code collision,
    /// since session_code is UNIQUE.
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
                continue // likely a unique-constraint collision on session_code; retry with a new code
            }
        }
        // Unreachable, but keeps the compiler happy about the loop's exit path.
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

    func setSessionStatus(id: String, status: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("fieldwork_sessions")
            .update(SessionStatusPatch(status: status, updated_at: now))
            .eq("id", value: id).execute()
    }

    // MARK: - Teacher: read responses for review

    func fetchResponses(sessionId: String) async throws -> [StudentResponse] {
        try await client
            .from("student_responses").select()
            .eq("session_id", value: sessionId)
            .order("updated_at", ascending: false)
            .execute().value
    }

    /// Marks a response reviewed — the final lock, per the "editable until
    /// teacher reviews" decision. Only the owning teacher can do this
    /// (enforced by the student_responses_teacher_update RLS policy).
    func markReviewed(responseId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("student_responses")
            .update(ReviewedPatch(status: "reviewed", reviewed_at: now, updated_at: now))
            .eq("id", value: responseId).execute()
    }

    // MARK: - Student: join + answer

    /// Resolves a session code to a session, creating the student's
    /// response row if this is their first time joining. Uses the
    /// SECURITY DEFINER `join_session_by_code` RPC so the student doesn't
    /// need broad SELECT on fieldwork_sessions.
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

    /// Saves the student's current answers as a draft. Safe to call
    /// repeatedly as they work through the sheet (e.g. on question change
    /// or a periodic autosave), since it never advances status past
    /// 'draft'.
    func saveDraft(responseId: String, answers: [String: SessionAnswerValue]) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let patch = AnswersPatch(answers: answers, status: "draft", submitted_at: nil, updated_at: now)
        try await client.from("student_responses")
            .update(patch).eq("id", value: responseId).execute()
    }

    /// Submits the response. Still editable afterwards (student RLS only
    /// blocks writes once status = 'reviewed'), so this just records the
    /// submission moment and flips status for the teacher's review list.
    func submit(responseId: String, answers: [String: SessionAnswerValue]) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let patch = AnswersPatch(answers: answers, status: "submitted", submitted_at: now, updated_at: now)
        try await client.from("student_responses")
            .update(patch).eq("id", value: responseId).execute()
    }

    // MARK: - Helpers

    /// Same alphabet/shape as ClassroomStore.generateCode(), kept
    /// separate here so SessionService doesn't need to import/depend on
    /// ClassroomStore for one static helper.
    static func generateCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
