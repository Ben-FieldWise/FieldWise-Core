//
//  ReviewWorkView.swift
//  FieldWise Core
//
//  Teacher-facing "Reports" tab: review what students have submitted.
//  Reads the fieldworkEntries table for the teacher's class(es) via the
//  existing ClassroomStore/SupabaseService — no new data layer.
//
//    ReviewWorkView   — class picker + entries grouped by student
//    EntryDetailView  — one submission in full (notes, GPS, weather,
//                       soil colour, photos)
//    ReportsTab       — role gate: teachers see the review; students keep
//                       the existing collection UI (FieldChecklistView)
//
//  Wire-up: in App/ContentView.swift, the Reports tab's content changes
//  from `FieldChecklistView()` to `ReportsTab()`.
//

import SwiftUI

// MARK: - Role gate for the Reports tab

struct ReportsTab: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        if authService.currentUserProfile?.role == .teacher {
            ReviewWorkView()
        } else {
            FieldChecklistView()
        }
    }
}

// MARK: - Review (teacher)

struct ReviewWorkView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = ClassroomStore()

    @State private var selectedClassId: String?
    @State private var taskTitles: [String: String] = [:]
    @State private var showDrafts = false

    private var currentClassId: String? {
        selectedClassId ?? store.classes.first?.id
    }

    private var currentClass: SchoolClass? {
        store.classes.first { $0.id == currentClassId }
    }

    /// Entries grouped by student, newest first, honouring the drafts filter.
    private var groups: [StudentGroup] {
        let visible = store.classEntries.filter { showDrafts || $0.status == .submitted }
        let byStudent = Dictionary(grouping: visible) { $0.studentUid }
        return byStudent.map { uid, entries in
            StudentGroup(
                id: uid,
                name: entries.first?.studentDisplayName ?? "Student",
                entries: entries.sorted {
                    ($0.clientCreatedAt ?? .distantPast) > ($1.clientCreatedAt ?? .distantPast)
                }
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var submittedCount: Int {
        store.classEntries.filter { $0.status == .submitted }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.classes.isEmpty {
                    emptyState(
                        icon: "person.2.slash",
                        title: "No classes yet",
                        message: "Create a class in the Classes tab, then student submissions will show up here."
                    )
                } else if groups.isEmpty {
                    emptyState(
                        icon: "tray",
                        title: showDrafts ? "Nothing recorded yet" : "No submissions yet",
                        message: "When students in this class submit their fieldwork, it appears here."
                    )
                } else {
                    entryList
                }
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Review work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.classes.count > 1 {
                    ToolbarItem(placement: .principal) { classMenu }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await reload() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(Color("BrandGreen"))
                }
            }
            .task { await initialLoad() }
        }
        .tint(Color("BrandGreen"))
    }

    // MARK: - List

    private var entryList: some View {
        List {
            Section {
                summaryRow
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry,
                                            taskTitle: taskTitles[entry.taskId] ?? "Fieldwork task")
                        } label: {
                            EntryRow(entry: entry, taskTitle: taskTitles[entry.taskId])
                        }
                    }
                } header: {
                    HStack {
                        Text(group.name)
                        Spacer()
                        Text("\(group.entries.filter { $0.status == .submitted }.count) submitted")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await reload() }
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            stat(value: "\(groups.count)", label: "students")
            Divider().frame(height: 30)
            stat(value: "\(submittedCount)", label: "submitted")
            Spacer()
            Toggle("Drafts", isOn: $showDrafts)
                .labelsHidden()
                .tint(Color("BrandGreen"))
            Text("Show drafts").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(Color("BrandGreen"))
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }

    private var classMenu: some View {
        Menu {
            ForEach(store.classes) { cls in
                Button {
                    selectedClassId = cls.id
                    Task { await loadEntries(for: cls.id) }
                } label: {
                    if cls.id == currentClassId { Label(cls.name, systemImage: "checkmark") }
                    else { Text(cls.name) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentClass?.name ?? "Class").font(.system(size: 16, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.primary)
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text(title).font(.system(size: 18, weight: .semibold))
            Text(message)
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func initialLoad() async {
        guard let profile = authService.currentUserProfile, profile.role == .teacher else { return }
        await store.loadTeacherClasses(teacherId: profile.id)
        if let cid = currentClassId { await loadEntries(for: cid) }
    }

    private func reload() async {
        if let cid = currentClassId { await loadEntries(for: cid) }
    }

    private func loadEntries(for classId: String) async {
        await store.loadClassEntries(classId: classId)
        await store.loadTasks(classId: classId)
        taskTitles = Dictionary(store.tasks.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
    }
}

// MARK: - Grouping model

private struct StudentGroup: Identifiable {
    let id: String            // studentUid
    let name: String
    let entries: [FieldworkEntry]
}

// MARK: - Row

private struct EntryRow: View {
    let entry: FieldworkEntry
    let taskTitle: String?

    private var dateText: String {
        guard let d = entry.clientCreatedAt else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(taskTitle ?? "Fieldwork task")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    StatusBadge(status: entry.status)
                    if !entry.photoStoragePaths.isEmpty {
                        Label("\(entry.photoStoragePaths.count)", systemImage: "photo")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if entry.gps != nil {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                if !dateText.isEmpty {
                    Text(dateText).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct StatusBadge: View {
    let status: FieldworkEntryStatus
    var body: some View {
        Text(status == .submitted ? "Submitted" : "Draft")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(status == .submitted ? .white : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status == .submitted ? Color("BrandGreen") : Color(.systemGray5))
            .clipShape(Capsule())
    }
}

// MARK: - Detail

struct EntryDetailView: View {
    let entry: FieldworkEntry
    let taskTitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    card(title: "Notes") {
                        Text(entry.notes).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let gps = entry.gps {
                    card(title: "Location") {
                        Text(String(format: "%.5f, %.5f", gps.lat, gps.lng))
                            .font(.system(size: 14, weight: .medium))
                    }
                }

                if let w = entry.weather {
                    card(title: "Weather") {
                        Text("\(ToolNumber.trim(w.temp)) °C · \(w.condition)")
                            .font(.system(size: 14))
                    }
                }

                if let soil = entry.soilColour {
                    card(title: "Soil colour") {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorFromHex(soil.hex))
                                .frame(width: 44, height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(soil.hue) \(soil.value)/\(soil.chroma)")
                                    .font(.system(size: 14, weight: .medium))
                                Text(soil.hex).font(.system(size: 12)).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                card(title: "Photos") {
                    if entry.photoStoragePaths.isEmpty {
                        Text("No photos.").font(.system(size: 14)).foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(entry.photoStoragePaths.count) photo\(entry.photoStoragePaths.count == 1 ? "" : "s") attached")
                                .font(.system(size: 14, weight: .medium))
                            ForEach(entry.photoStoragePaths, id: \.self) { path in
                                Text(path).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                            }
                            // Thumbnails need a Supabase Storage signed URL per path
                            // (bucket name required) — add once the bucket is confirmed.
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle(entry.studentDisplayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(taskTitle).font(.system(size: 20, weight: .bold))
            HStack(spacing: 8) {
                StatusBadge(status: entry.status)
                if let dateText = formattedDate(entry.clientCreatedAt) {
                    Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
        }
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
    }
}

// MARK: - Small helpers (file-private to avoid collisions)

private enum ToolNumber {
    static func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

private func colorFromHex(_ hex: String) -> Color {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt64(s, radix: 16) else { return Color(.systemGray4) }
    return Color(
        red: Double((v & 0xFF0000) >> 16) / 255,
        green: Double((v & 0x00FF00) >> 8) / 255,
        blue: Double(v & 0x0000FF) / 255
    )
}
