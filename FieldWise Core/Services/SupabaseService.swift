//
//  SupabaseService.swift
//  FieldWise Core
//
//  Data layer over Supabase (PostgREST) — replaces FirestoreService.
//  Mirrors the old method surface (schools / classes / tasks / entries)
//  so the classroom UI can adopt it unchanged. RLS enforces access
//  server-side; these calls just shape the reads/writes.
//
//  Row structs carry the primary-key `id` (which the shared Codable
//  models deliberately omit from their CodingKeys) and map into the
//  app models via their memberwise initialisers.
//
//  Offline note: unlike Firestore, Supabase has no built-in offline
//  cache. Entry writes still use client-generated UUIDs (see
//  FieldworkEntry.newDraft), so a local write-queue can be layered on in
//  Phase 4 without changing these signatures.
//

import Foundation
import Supabase

final class SupabaseService {

    private let client = SupabaseManager.shared.client

    // MARK: - Row DTOs (include id; map to app models)

    private struct SchoolRow: Decodable { let id: String }

    private struct SchoolClassRow: Decodable {
        let id, teacherId, schoolId, name, classCode: String
        let active: Bool
        let createdAt: Date?
        func toModel() -> SchoolClass {
            SchoolClass(id: id, teacherId: teacherId, schoolId: schoolId,
                        name: name, classCode: classCode, active: active, createdAt: createdAt)
        }
    }

    private struct FieldworkTaskRow: Decodable {
        let id, classId, title, instructions: String
        let bookletId: String?
        let createdAt: Date?
        func toModel() -> FieldworkTask {
            FieldworkTask(id: id, classId: classId, title: title, instructions: instructions,
                          bookletId: bookletId, createdAt: createdAt)
        }
    }

    private struct FieldworkEntryRow: Decodable {
        let id, taskId, classId, studentUid, studentDisplayName, status, notes: String
        let gps: FieldworkEntryGPS?
        let soilColour: FieldworkEntrySoilColour?
        let weather: FieldworkEntryWeather?
        let photoStoragePaths: [String]
        let clientCreatedAt, serverCreatedAt, updatedAt: Date?
        func toModel() -> FieldworkEntry {
            FieldworkEntry(
                id: id, taskId: taskId, classId: classId,
                studentUid: studentUid, studentDisplayName: studentDisplayName,
                status: FieldworkEntryStatus(rawValue: status) ?? .draft,
                gps: gps, notes: notes, soilColour: soilColour, weather: weather,
                photoStoragePaths: photoStoragePaths,
                clientCreatedAt: clientCreatedAt, serverCreatedAt: serverCreatedAt, updatedAt: updatedAt)
        }
    }

    // MARK: - Schools

    func findOrCreateSchool(named name: String) async throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing: [SchoolRow] = try await client
            .from("schools").select("id").eq("name", value: trimmed).limit(1).execute().value
        if let first = existing.first { return first.id }
        struct SchoolInsert: Encodable { let name: String }
        let created: SchoolRow = try await client
            .from("schools").insert(SchoolInsert(name: trimmed)).select("id").single().execute().value
        return created.id
    }

    // MARK: - Users

    func fetchUserProfile(uid: String) async throws -> UserProfile {
        let profile: UserProfile = try await client
            .from("users").select().eq("id", value: uid).single().execute().value
        return profile.with(id: uid)
    }

    // MARK: - Classes

    func createClass(_ schoolClass: SchoolClass) async throws -> SchoolClass {
        // SchoolClass encodes without id (auto-generated); read it back.
        let row: SchoolClassRow = try await client
            .from("classes").insert(schoolClass).select().single().execute().value
        return row.toModel()
    }

    func fetchClasses(teacherId: String) async throws -> [SchoolClass] {
        let rows: [SchoolClassRow] = try await client
            .from("classes").select().eq("teacherId", value: teacherId).execute().value
        return rows.map { $0.toModel() }
    }

    /// A single class by id — used by students to show their class name.
    /// RLS allows a student to read only the class they belong to.
    func fetchClass(id: String) async throws -> SchoolClass {
        let row: SchoolClassRow = try await client
            .from("classes").select().eq("id", value: id).single().execute().value
        return row.toModel()
    }

    func setClassActive(_ classId: String, active: Bool) async throws {
        struct ActivePatch: Encodable { let active: Bool }
        try await client.from("classes").update(ActivePatch(active: active)).eq("id", value: classId).execute()
    }

    // MARK: - Fieldwork tasks

    func createTask(_ task: FieldworkTask) async throws -> FieldworkTask {
        let row: FieldworkTaskRow = try await client
            .from("fieldworkTasks").insert(task).select().single().execute().value
        return row.toModel()
    }

    func fetchTasks(classId: String) async throws -> [FieldworkTask] {
        let rows: [FieldworkTaskRow] = try await client
            .from("fieldworkTasks").select().eq("classId", value: classId).execute().value
        return rows.map { $0.toModel() }
    }

    // MARK: - Fieldwork entries

    /// Offline-first save — persists locally and syncs when online.
    /// Returns immediately (never throws on connectivity failure); see
    /// EntrySync. Safe to call repeatedly as a student edits a draft.
    func saveEntry(_ entry: FieldworkEntry) async {
        await EntrySync.shared.save(entry)
    }

    /// Server rows for this student+task, merged with any not-yet-synced
    /// local drafts (local wins) so offline edits are always visible.
    func fetchMyEntries(studentUid: String, taskId: String) async throws -> [FieldworkEntry] {
        let rows: [FieldworkEntryRow] = try await client
            .from("fieldworkEntries").select()
            .eq("studentUid", value: studentUid)
            .eq("taskId", value: taskId)
            .execute().value
        var byId = Dictionary(rows.map { ($0.id, $0.toModel()) }, uniquingKeysWith: { a, _ in a })
        for e in await EntrySync.shared.pendingEntries(studentUid: studentUid, taskId: taskId) {
            byId[e.id] = e
        }
        return Array(byId.values)
    }

    func fetchClassEntries(classId: String) async throws -> [FieldworkEntry] {
        let rows: [FieldworkEntryRow] = try await client
            .from("fieldworkEntries").select().eq("classId", value: classId).execute().value
        return rows.map { $0.toModel() }
    }
}
