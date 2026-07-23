//
//  AllSessionsView.swift
//  FieldWise Core
//
//  Teacher-facing: every session the teacher has created, across every
//  worksheet, in one place — reachable directly from Home rather than
//  requiring "Worksheets → pick a sheet → ⋯ → Sessions" for a teacher
//  who just wants to check on or create a session.
//
//  Grouped by class (a session's class_id, which SessionsView now
//  requires the teacher to set on creation). Sessions created before
//  that requirement existed have class_id = nil and fall into an
//  "Ungrouped" section rather than being hidden or causing an error.
//

import SwiftUI

struct AllSessionsView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var worksheetStore = WorksheetStore()
    @StateObject private var classroomStore = ClassroomStore()

    @State private var selectedSession: FieldworkSession?
    @State private var editingSession: FieldworkSession?
    @State private var editMode: EditMode = .inactive
    @State private var multiSelection = Set<String>()
    @State private var confirmBulkDelete = false
    @State private var pendingBulkDeleteTarget: [FieldworkSession] = []

    /// sheetId -> sheet, so each session row can show which worksheet it
    /// belongs to without a separate fetch per row.
    private var sheetsById: [String: FieldworkSheet] {
        Dictionary(uniqueKeysWithValues: worksheetStore.sheets.map { ($0.id, $0) })
    }

    /// Sessions grouped by class_id, ordered to match classroomStore's
    /// own class ordering (most-recently-created class first), with any
    /// class that has zero sessions simply not appearing — and a final
    /// "Ungrouped" bucket for sessions with no class_id at all.
    private var groupedSections: [(title: String, sessions: [FieldworkSession])] {
        var byClassId: [String: [FieldworkSession]] = [:]
        var ungrouped: [FieldworkSession] = []
        for session in sessionStore.sessions {
            if let classId = session.classId, !classId.isEmpty {
                byClassId[classId, default: []].append(session)
            } else {
                ungrouped.append(session)
            }
        }

        var sections: [(title: String, sessions: [FieldworkSession])] = []
        for cls in classroomStore.classes {
            if let sessions = byClassId[cls.id] {
                sections.append((title: cls.name, sessions: sessions))
            }
        }
        if !ungrouped.isEmpty {
            sections.append((title: "Ungrouped", sessions: ungrouped))
        }
        return sections
    }

    private var selectedSessions: [FieldworkSession] {
        sessionStore.sessions.filter { multiSelection.contains($0.id) }
    }

    var body: some View {
        Group {
            if sessionStore.isLoading && sessionStore.sessions.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessionStore.sessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedSession) { session in
            SessionResponsesView(session: session)
        }
        .navigationDestination(item: $editingSession) { session in
            SessionEditView(session: session, store: sessionStore)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !sessionStore.sessions.isEmpty {
                    Button(editMode.isEditing ? "Done" : "Select") {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                            if !editMode.isEditing { multiSelection.removeAll() }
                        }
                    }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode.isEditing && !multiSelection.isEmpty {
                    Button {
                        Task { await sessionStore.closeSessions(selectedSessions); multiSelection.removeAll() }
                    } label: {
                        Label("Close", systemImage: "lock")
                    }
                    Spacer()
                    Button {
                        Task { await sessionStore.reopenSessions(selectedSessions); multiSelection.removeAll() }
                    } label: {
                        Label("Reopen", systemImage: "lock.open")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        pendingBulkDeleteTarget = selectedSessions
                        confirmBulkDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .task { await load() }
        .alert("Something went wrong", isPresented: .constant(sessionStore.errorText != nil), actions: {
            Button("OK") { sessionStore.errorText = nil }
        }, message: {
            Text(sessionStore.errorText ?? "")
        })
        .confirmationDialog(
            "Delete \(pendingBulkDeleteTarget.count) session\(pendingBulkDeleteTarget.count == 1 ? "" : "s")? Any student responses on \(pendingBulkDeleteTarget.count == 1 ? "it" : "them") will be permanently deleted too. This can't be undone.",
            isPresented: $confirmBulkDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await sessionStore.deleteSessions(pendingBulkDeleteTarget)
                    multiSelection.removeAll()
                    pendingBulkDeleteTarget = []
                }
            }
            Button("Cancel", role: .cancel) { pendingBulkDeleteTarget = [] }
        }
    }

    private var list: some View {
        List(selection: $multiSelection) {
            ForEach(groupedSections, id: \.title) { section in
                Section {
                    ForEach(section.sessions) { session in
                        Button {
                            if editMode.isEditing {
                                if multiSelection.contains(session.id) { multiSelection.remove(session.id) }
                                else { multiSelection.insert(session.id) }
                            } else {
                                selectedSession = session
                            }
                        } label: {
                            HStack {
                                AllSessionsRow(session: session, sheetTitle: sheetsById[session.sheetId]?.title)
                                Spacer()
                                if !editMode.isEditing {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .tag(session.id)
                        .swipeActions {
                            if !editMode.isEditing {
                                if session.isActive {
                                    Button("Close") { Task { await sessionStore.closeSession(session) } }
                                        .tint(.gray)
                                } else {
                                    Button("Reopen") { Task { await sessionStore.reopenSession(session) } }
                                        .tint(Color("BrandGreen"))
                                }
                                Button("Edit") { editingSession = session }
                                    .tint(Color("GeoBlue"))
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(section.title)
                        Spacer()
                        if !editMode.isEditing {
                            Menu {
                                Button {
                                    Task { await sessionStore.closeSessions(section.sessions) }
                                } label: {
                                    Label("Close all", systemImage: "lock")
                                }
                                Button {
                                    Task { await sessionStore.reopenSessions(section.sessions) }
                                } label: {
                                    Label("Reopen all", systemImage: "lock.open")
                                }
                                Button(role: .destructive) {
                                    pendingBulkDeleteTarget = section.sessions
                                    confirmBulkDelete = true
                                } label: {
                                    Label("Delete all", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .listStyle(.insetGrouped)
        .refreshable { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "qrcode")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text("No sessions yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Open a worksheet and tap Sessions to create one — you'll see it here once it's published.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        guard let uid = authService.uid else { return }
        await sessionStore.loadMySessions(teacherId: uid)
        await worksheetStore.loadMySheets(teacherId: uid)
        await classroomStore.loadTeacherClasses(teacherId: uid)
    }
}

// MARK: - Row

private struct AllSessionsRow: View {
    let session: FieldworkSession
    let sheetTitle: String?

    private var dateText: String {
        guard let d = session.createdAt else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.sessionCode)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                HStack(spacing: 6) {
                    if let sheetTitle {
                        Text(sheetTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("·").foregroundColor(.secondary)
                    }
                    if !dateText.isEmpty {
                        Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Text(session.isActive ? "Active" : "Closed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(session.isActive ? .white : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(session.isActive ? Color("BrandGreen") : Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
