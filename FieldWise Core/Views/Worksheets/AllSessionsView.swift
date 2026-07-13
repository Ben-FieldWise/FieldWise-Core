//
//  AllSessionsView.swift
//  FieldWise Core
//
//  Teacher-facing: every session the teacher has created, across every
//  worksheet, in one place — reachable directly from Home rather than
//  requiring "Worksheets → pick a sheet → ⋯ → Sessions" for a teacher
//  who just wants to check on or create a session.
//
//  Deliberately flat for now (no class/subject grouping) — that's a
//  planned follow-up once there's a real need for filtering by class,
//  but this screen's shape (one list, sheet title shown per row) should
//  still work as the foundation for that without a rewrite.
//

import SwiftUI

struct AllSessionsView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var worksheetStore = WorksheetStore()

    @State private var selectedSession: FieldworkSession?

    /// sheetId -> sheet, so each session row can show which worksheet it
    /// belongs to without a separate fetch per row.
    private var sheetsById: [String: FieldworkSheet] {
        Dictionary(uniqueKeysWithValues: worksheetStore.sheets.map { ($0.id, $0) })
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
        .task { await load() }
        .alert("Something went wrong", isPresented: .constant(sessionStore.errorText != nil), actions: {
            Button("OK") { sessionStore.errorText = nil }
        }, message: {
            Text(sessionStore.errorText ?? "")
        })
    }

    private var list: some View {
        List {
            ForEach(sessionStore.sessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    HStack {
                        AllSessionsRow(session: session, sheetTitle: sheetsById[session.sheetId]?.title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
