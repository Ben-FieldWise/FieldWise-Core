//
//  SessionResponsesView.swift
//  FieldWise Core
//
//  Teacher-facing: every student's response to one session, with a
//  detail view rendering their answers against the sheet's questions,
//  and the "mark reviewed" action that finally locks a response.
//

import SwiftUI

struct SessionResponsesView: View {
    let session: FieldworkSession
    @StateObject private var store = SessionStore()
    @StateObject private var worksheetStore = WorksheetStore()

    @State private var showReviewedOnly = false

    private var sections: [WorksheetSection] { worksheetStore.sections }
    private var questionsBySection: [String: [WorksheetQuestion]] { worksheetStore.questionsBySection }

    private var visibleResponses: [StudentResponse] {
        store.responses.filter { showReviewedOnly || $0.status != .reviewed }
    }

    var body: some View {
        Group {
            if store.isLoading && store.responses.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.responses.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Responses — \(session.sessionCode)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                    .tint(Color("BrandGreen"))
            }
        }
        .task { await reload() }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text("\(store.responses.filter { $0.status == .submitted }.count) submitted")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Toggle("Show reviewed", isOn: $showReviewedOnly)
                        .labelsHidden()
                        .tint(Color("BrandGreen"))
                    Text("Show reviewed").font(.system(size: 13)).foregroundColor(.secondary)
                }
            }
            ForEach(visibleResponses) { response in
                NavigationLink {
                    ResponseDetailView(
                        response: response,
                        sections: sections,
                        questionsBySection: questionsBySection,
                        onMarkReviewed: { Task { await store.markReviewed(response) } }
                    )
                } label: {
                    ResponseRow(response: response)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text("No responses yet")
                .font(.system(size: 18, weight: .semibold))
            Text("When students join with the code \(session.sessionCode) and answer, they'll show up here.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() async {
        await store.loadResponses(sessionId: session.id)
        await worksheetStore.loadDetail(sheetId: session.sheetId)
    }
}

// MARK: - Row

private struct ResponseRow: View {
    let response: StudentResponse

    private var dateText: String {
        guard let d = response.submittedAt ?? response.updatedAt else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                // studentId is a uid, not a display name; a follow-up can
                // join against `users` for the name, mirroring how
                // ReviewWorkView shows studentDisplayName today.
                Text("Student \(response.studentId.prefix(8))")
                    .font(.system(size: 15, weight: .medium))
                if !dateText.isEmpty {
                    Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: response.status)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusBadge: View {
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

// MARK: - Detail

struct ResponseDetailView: View {
    let response: StudentResponse
    let sections: [WorksheetSection]
    let questionsBySection: [String: [WorksheetQuestion]]
    let onMarkReviewed: () -> Void

    @State private var confirmReview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                ForEach(sections) { section in
                    sectionCard(section)
                }
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Student \(response.studentId.prefix(8))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if response.status != .reviewed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark reviewed") { confirmReview = true }
                        .fontWeight(.semibold)
                        .tint(Color("BrandGreen"))
                }
            }
        }
        .confirmationDialog(
            "Mark this response as reviewed? The student won't be able to make further changes.",
            isPresented: $confirmReview,
            titleVisibility: .visible
        ) {
            Button("Mark reviewed") { onMarkReviewed() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            StatusBadge(status: response.status)
            if let submitted = response.submittedAt {
                Text("Submitted \(formatted(submitted))").font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
    }

    private func sectionCard(_ section: WorksheetSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title).font(.system(size: 16, weight: .semibold))
            ForEach(questionsBySection[section.id] ?? []) { question in
                answerCard(question)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
    }

    private func answerCard(_ question: WorksheetQuestion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question.prompt)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text(displayValue(for: question))
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func displayValue(for question: WorksheetQuestion) -> String {
        guard let value = response.answers[question.id] else { return "— no answer —" }
        switch value {
        case .string(let s): return s.isEmpty ? "— no answer —" : s
        case .stringArray(let a): return a.isEmpty ? "— no answer —" : a.joined(separator: ", ")
        case .int(let i): return "\(i)"
        case .table(let rows):
            guard !rows.isEmpty else { return "— no answer —" }
            return rows.map { $0.joined(separator: " · ") }.joined(separator: "\n")
        case .null: return "— no answer —"
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
