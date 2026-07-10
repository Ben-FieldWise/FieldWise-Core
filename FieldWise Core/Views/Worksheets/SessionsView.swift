//
//  SessionsView.swift
//  FieldWise Core
//
//  Teacher-facing: sessions (published "runs") of one fieldwork_sheets
//  row. Each session gets its own join code, independent of class
//  membership. Pushed from SheetEditorView via a toolbar action.
//

import SwiftUI

struct SessionsView: View {
    let sheet: FieldworkSheet
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = SessionStore()

    @State private var showingNewConfirm = false
    @State private var newlyCreated: FieldworkSession?

    var body: some View {
        Group {
            if store.isLoading && store.sessions.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.sessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FieldworkSession.self) { session in
            SessionResponsesView(session: session)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await createSession() } } label: { Image(systemName: "plus") }
                    .tint(Color("BrandGreen"))
            }
        }
        .task { await store.loadSessions(sheetId: sheet.id) }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
        .sheet(item: $newlyCreated) { session in
            NewSessionCodeSheet(session: session)
        }
    }

    private var list: some View {
        List {
            ForEach(store.sessions) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
                .swipeActions {
                    if session.isActive {
                        Button("Close") { Task { await store.closeSession(session) } }
                            .tint(.gray)
                    } else {
                        Button("Reopen") { Task { await store.reopenSession(session) } }
                            .tint(Color("BrandGreen"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.loadSessions(sheetId: sheet.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "qrcode")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text("No sessions yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Create a session to get a join code students can enter to answer this worksheet.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            Button {
                Task { await createSession() }
            } label: {
                Label("Create session", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createSession() async {
        guard let uid = authService.uid else { return }
        if let created = await store.publish(sheetId: sheet.id, teacherId: uid) {
            newlyCreated = created
        }
    }
}

// MARK: - Row

private struct SessionRow: View {
    let session: FieldworkSession

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
                if !dateText.isEmpty {
                    Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
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

// MARK: - "Here's your code" sheet, shown right after creating a session

private struct NewSessionCodeSheet: View {
    let session: FieldworkSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Text("Session created")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(session.sessionCode)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundColor(Color("BrandGreen"))
                Text("Give this code to your students. They'll enter it in the app to open and answer this worksheet.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("BrandGreen"))
                    .padding(.horizontal, 32)
            }
            .padding(.vertical, 30)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
