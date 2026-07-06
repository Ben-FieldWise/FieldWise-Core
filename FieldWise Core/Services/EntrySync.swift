//
//  EntrySync.swift
//  FieldWise Core
//
//  Offline-first sync for FieldworkEntry — the capability Firestore gave
//  for free, rebuilt deliberately on Supabase.
//
//  How it works: every save is written durably to a local JSON queue
//  FIRST, then pushed to Supabase. If the push fails (no signal), the
//  entry simply stays queued and is retried automatically when the
//  network comes back (NWPathMonitor) or on next launch. Because entry
//  IDs are client-generated UUIDs and the server write is an idempotent
//  upsert, retries are safe and never duplicate.
//
//  This mirrors Firestore's "setData returns immediately, syncs later"
//  behaviour: `save` never throws on a connectivity failure — the entry
//  stays queued.
//

import Foundation
import Supabase
import Network

actor EntrySync {
    static let shared = EntrySync()

    private let client = SupabaseManager.shared.client
    private let fileURL: URL
    private var pending: [String: FieldworkEntry]      // keyed by entry id
    private let monitor = NWPathMonitor()
    private var started = false

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("pending_entries.json")
        pending = [:]
    }

    /// Call once at launch (see FieldWiseCoreApp). Starts network
    /// monitoring and flushes anything left over from a previous session.
    func start() { Task { await self.begin() } }

    private func begin() async {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied { Task { await self.flush() } }
        }
        monitor.start(queue: DispatchQueue(label: "EntrySync.monitor"))
        let loaded = await EntrySync.load(from: fileURL)
        pending = loaded
        await flush()
    }

    /// Durable save. Persists locally, then attempts to push. Never
    /// throws on connectivity failure — the entry stays queued.
    func save(_ entry: FieldworkEntry) async {
        var e = entry
        e.updatedAt = Date()
        pending[e.id] = e
        persist()
        await tryPush(e)
    }

    /// Retry every queued entry (called on reconnect and at launch).
    func flush() async {
        for (_, e) in pending { await tryPush(e) }
    }

    /// Snapshot of how many entries are still waiting to reach the
    /// server. Used by the Core dashboard's sync-status card. Zero means
    /// everything recorded on this device has synced.
    func pendingCount() -> Int { pending.count }

    /// Locally-queued (not-yet-synced) entries for a student+task, so the
    /// UI can show drafts made offline alongside server rows.
    func pendingEntries(studentUid: String, taskId: String) -> [FieldworkEntry] {
        pending.values.filter { $0.studentUid == studentUid && $0.taskId == taskId }
    }

    // MARK: - Internals

    private func tryPush(_ entry: FieldworkEntry) async {
        do {
            try await upload(entry)
            pending[entry.id] = nil
            persist()
        } catch {
            // Offline or transient — keep queued; retried on next flush.
        }
    }

    private struct EntryPayload: Encodable {
        let id, taskId, classId, studentUid, studentDisplayName, status, notes: String
        let gps: FieldworkEntryGPS?
        let soilColour: FieldworkEntrySoilColour?
        let weather: FieldworkEntryWeather?
        let photoStoragePaths: [String]
        let clientCreatedAt, updatedAt: Date?
    }

    private func upload(_ entry: FieldworkEntry) async throws {
        let p = EntryPayload(
            id: entry.id, taskId: entry.taskId, classId: entry.classId,
            studentUid: entry.studentUid, studentDisplayName: entry.studentDisplayName,
            status: entry.status.rawValue, notes: entry.notes,
            gps: entry.gps, soilColour: entry.soilColour, weather: entry.weather,
            photoStoragePaths: entry.photoStoragePaths,
            clientCreatedAt: entry.clientCreatedAt, updatedAt: entry.updatedAt)
        try await client.from("fieldworkEntries").upsert(p, onConflict: "id").execute()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(pending) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    @MainActor private static func load(from url: URL) async -> [String: FieldworkEntry] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: FieldworkEntry].self, from: data)
        else { return [:] }
        // Entry IDs are excluded from Codable, so reattach from the keys.
        var out: [String: FieldworkEntry] = [:]
        for (key, value) in dict { out[key] = value.with(id: key) }
        return out
    }
}
