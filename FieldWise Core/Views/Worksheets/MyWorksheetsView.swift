//
//  MyWorksheetsView.swift
//  FieldWise Core
//
//  Student-facing: every worksheet response they've started, across
//  every session — the "completed sheets" list that was missing
//  entirely before. Reachable from Home alongside "Join worksheet".
//
//  Resolves session_id -> sheet_id -> sheet title via lookups (a
//  student's own responses are rarely more than a handful, so this
//  isn't trying to be a paginated/optimized list — just correct).
//

import SwiftUI

struct MyWorksheetsView: View {
    @StateObject private var store = SessionStore()
    private let worksheetService = WorksheetService()
    private let sessionService = SessionService()

    @State private var sheetTitlesBySessionId: [String: String] = [:]
    @State private var selectedResponse: StudentResponse?
    @State private var isResolvingTitles = false

    var body: some View {
        Group {
            if store.isLoading && store.myResponses.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.myResponses.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle("My Worksheets")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedResponse) { response in
            WorksheetFillView(store: store)
                .task { await store.loadResponseDetail(response: response) }
        }
        .task { await load() }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
    }

    private var list: some View {
        List {
            ForEach(store.myResponses) { response in
                Button {
                    selectedResponse = response
                } label: {
                    HStack {
                        MyWorksheetRow(
                            response: response,
                            sheetTitle: sheetTitlesBySessionId[response.sessionId]
                        )
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
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text("No worksheets yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Worksheets you join will show up here so you can find your answers again later.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        await store.loadMyResponses()
        await resolveSheetTitles()
    }

    /// Resolves each response's session_id -> sheet title, deduplicating
    /// so a student who joined the same sheet's session twice (unlikely,
    /// but the schema allows re-joining a still-active session) doesn't
    /// trigger redundant fetches.
    private func resolveSheetTitles() async {
        guard !store.myResponses.isEmpty else { return }
        isResolvingTitles = true
        defer { isResolvingTitles = false }

        let sessionIds = Set(store.myResponses.map { $0.sessionId })
        var titleForSessionId: [String: String] = [:]

        for sessionId in sessionIds {
            guard titleForSessionId[sessionId] == nil else { continue }
            do {
                let session = try await sessionService.fetchSession(id: sessionId)
                let sheet = try await worksheetService.fetchSheet(id: session.sheetId)
                titleForSessionId[sessionId] = sheet.title
            } catch {
                // A title we can't resolve just shows a placeholder in
                // the row rather than blocking the whole list.
                continue
            }
        }
        sheetTitlesBySessionId = titleForSessionId
    }
}

// MARK: - Row

private struct MyWorksheetRow: View {
    let response: StudentResponse
    let sheetTitle: String?

    private var dateText: String {
        guard let d = response.submittedAt ?? response.updatedAt else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sheetTitle ?? "Worksheet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                if !dateText.isEmpty {
                    Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            Spacer()
            StatusPill(status: response.status)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusPill: View {
    let status: StudentResponseStatus
    private var text: String {
        switch status {
        case .draft: return "Draft"
        case .submitted: return "Submitted"
        case .reviewed: return "Reviewed"
        }
    }
    private var color: Color {
        switch status {
        case .draft: return Color(.systemGray5)
        case .submitted: return Color("BrandGreen")
        case .reviewed: return Color("GeoBlue")
        }
    }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(status == .draft ? .secondary : .white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}
