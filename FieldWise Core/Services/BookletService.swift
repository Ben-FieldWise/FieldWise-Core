//
//  BookletService.swift
//  FieldWise Core
//
//  Reads structured booklet content and saves a student's per-block
//  answers. RLS keeps content readable to all signed-in users and
//  responses private to their author (teacher of the class can review).
//

import Foundation
import Supabase

final class BookletService {

    private let client = SupabaseManager.shared.client

    // MARK: - Content

    func fetchBooklet(id: String) async throws -> BookletTemplate {
        try await client.from("bookletTemplates").select().eq("id", value: id).single().execute().value
    }

    /// Sections in order, each with its blocks nested (PostgREST embed).
    /// Blocks are sorted client-side by their `order`.
    func fetchSections(bookletId: String) async throws -> [BookletSection] {
        let sections: [BookletSection] = try await client
            .from("bookletSections")
            .select("id, siteId, order, title, bookletBlocks(id, order, type, prompt, sourceUrl, config)")
            .eq("bookletId", value: bookletId)
            .order("order", ascending: true)
            .execute().value
        return sections.map { section in
            BookletSection(id: section.id, siteId: section.siteId, order: section.order,
                           title: section.title,
                           blocks: section.blocks.sorted { $0.order < $1.order })
        }
    }

    // MARK: - Responses

    func fetchMyResponses(taskId: String, studentUid: String) async throws -> [BookletResponse] {
        try await client.from("bookletResponses").select()
            .eq("taskId", value: taskId)
            .eq("studentUid", value: studentUid)
            .execute().value
    }

    /// Upsert one block's answer. The row id is deterministic for the
    /// (task, block, student) triple so re-saving updates in place.
    func saveResponse(taskId: String, blockId: String, studentUid: String, value: AnswerValue) async throws {
        struct Payload: Encodable {
            let id: String
            let taskId: String
            let blockId: String
            let studentUid: String
            let value: AnswerValue
            let status: String
            let updatedAt: Date
        }
        let payload = Payload(
            id: "\(taskId):\(blockId):\(studentUid)",
            taskId: taskId, blockId: blockId, studentUid: studentUid,
            value: value, status: "draft", updatedAt: Date())
        try await client.from("bookletResponses")
            .upsert(payload, onConflict: "taskId,blockId,studentUid")
            .execute()
    }
}
