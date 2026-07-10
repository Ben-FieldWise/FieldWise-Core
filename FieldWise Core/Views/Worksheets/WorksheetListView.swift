//
//  WorksheetListView.swift
//  FieldWise Core
//
//  Teacher's "My Worksheets" — list of fieldwork_sheets they've created,
//  create a new one, tap through to the builder. Pushed from CoreHomeView
//  (Home tab's "Worksheets" quick action), so it does NOT wrap its own
//  NavigationStack — it relies on the one already on Home.
//

import SwiftUI

struct WorksheetListView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = WorksheetStore()
    @State private var showingNew = false

    var body: some View {
        Group {
            if store.isLoading && store.sheets.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.sheets.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle("My Worksheets")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FieldworkSheet.self) { sheet in
            SheetEditorView(sheet: sheet)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .tint(Color("BrandGreen"))
            }
        }
        .sheet(isPresented: $showingNew) {
            NewSheetView { title, description, subject, year in
                Task {
                    if let uid = authService.uid,
                       let created = await store.createSheet(
                           teacherId: uid, title: title, description: description,
                           subjectArea: subject, yearLevel: year) {
                        showingNew = false
                        // Navigation to the new sheet happens via the list's
                        // own NavigationLink once it appears; nothing more to do.
                        _ = created
                    }
                }
            }
        }
        .task {
            if let uid = authService.uid { await store.loadMySheets(teacherId: uid) }
        }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
    }

    private var list: some View {
        List {
            ForEach(store.sheets) { sheet in
                NavigationLink(value: sheet) {
                    SheetRow(sheet: sheet)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let sheet = store.sheets[index]
                    Task { await store.deleteSheet(sheet) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            if let uid = authService.uid { await store.loadMySheets(teacherId: uid) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text("No worksheets yet").font(.system(size: 18, weight: .semibold))
            Text("Build a fieldwork worksheet with sections and questions your students will complete on site.")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            PrimaryButton(title: "New worksheet", iconName: "plus") { showingNew = true }
                .padding(.horizontal, 40)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct SheetRow: View {
    let sheet: FieldworkSheet

    private var dateText: String {
        guard let d = sheet.updatedAt else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sheet.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                HStack(spacing: 8) {
                    StatusPill(status: sheet.status)
                    if !dateText.isEmpty {
                        Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct StatusPill: View {
    let status: String
    private var color: Color {
        switch status {
        case "active": return Color("BrandGreen")
        case "archived": return .gray
        default: return Color("BrandAmber")
        }
    }
    var body: some View {
        Text(status.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - New sheet

private struct NewSheetView: View {
    var onCreate: (_ title: String, _ description: String?, _ subject: String?, _ year: String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var subjectArea = ""
    @State private var yearLevel = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Worksheet") {
                    TextField("Title (e.g. River fieldwork investigation)", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                }
                Section("Details") {
                    TextField("Subject area (e.g. Geography)", text: $subjectArea)
                    TextField("Year level (e.g. Year 10)", text: $yearLevel)
                }
            }
            .navigationTitle("New Worksheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        onCreate(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description,
                            subjectArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : subjectArea,
                            yearLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : yearLevel
                        )
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
