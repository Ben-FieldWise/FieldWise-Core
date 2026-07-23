//
//  CurriculumPickerView.swift
//  FieldWise Core
//
//  Phase 1E MVP: lets a teacher browse VCAA Geography curriculum points
//  for a level band and attach/detach them to the sheet they're editing.
//  Pushed from SheetEditorView (a "Curriculum" row/button leads here),
//  so it does NOT wrap its own NavigationStack.
//
//  Workbook-level only, per the MVP scope decision — this is
//  sheet_curriculum_links, not section- or question-level linking.
//

import SwiftUI

struct CurriculumPickerView: View {
    let sheet: FieldworkSheet

    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = CurriculumStore()

    // Defaults to the sheet's own year level if it maps to a VCAA band,
    // otherwise "7-8". Teachers can switch bands with the picker below —
    // useful since a sheet's year_level is freeform text from Phase 1A/1D,
    // not guaranteed to be a VCAA band string.
    @State private var levelBand: String

    init(sheet: FieldworkSheet) {
        self.sheet = sheet
        _levelBand = State(initialValue: Self.inferLevelBand(from: sheet.yearLevel))
    }

    private static let availableBands = ["7-8", "9-10"]

    private static func inferLevelBand(from yearLevel: String?) -> String {
        guard let yearLevel else { return "7-8" }
        if yearLevel.contains("9") || yearLevel.contains("10") { return "9-10" }
        return "7-8"
    }

    var body: some View {
        Group {
            if store.isLoading && store.points.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.points.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Level band", selection: $levelBand) {
                    ForEach(Self.availableBands, id: \.self) { band in
                        Text("Levels \(band)").tag(band)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .task(id: levelBand) {
            await store.loadPoints(levelBand: levelBand)
        }
        .task {
            await store.loadLinks(sheetId: sheet.id)
        }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
    }

    // MARK: - List

    private var list: some View {
        List {
            if !store.links.isEmpty {
                Section {
                    ForEach(store.links.sorted(by: { ($0.curriculumPoint?.code ?? "") < ($1.curriculumPoint?.code ?? "") })) { link in
                        if let point = link.curriculumPoint {
                            linkedRow(point)
                        }
                    }
                } header: {
                    Text("Attached to this worksheet (\(store.links.count))")
                }
            }

            ForEach(store.pointsBySubstrand, id: \.substrandName) { group in
                Section {
                    ForEach(group.points) { point in
                        pointRow(point)
                    }
                } header: {
                    Text(group.substrandName)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Color("BrandGreen"))
            Text("No curriculum points found")
                .font(.system(size: 17, weight: .semibold))
            Text("Try switching the level band above.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Rows

    private func linkedRow(_ point: CurriculumPoint) -> some View {
        Button {
            Task {
                guard let uid = authService.uid else { return }
                await store.toggleLink(sheetId: sheet.id, point: point, teacherId: uid)
            }
        } label: {
            row(point, isLinked: true)
        }
        .buttonStyle(.plain)
    }

    private func pointRow(_ point: CurriculumPoint) -> some View {
        let isLinked = store.linkedPointIds.contains(point.id)
        return Button {
            Task {
                guard let uid = authService.uid else { return }
                await store.toggleLink(sheetId: sheet.id, point: point, teacherId: uid)
            }
        } label: {
            row(point, isLinked: isLinked)
        }
        .buttonStyle(.plain)
    }

    private func row(_ point: CurriculumPoint, isLinked: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isLinked ? Color("BrandGreen") : .secondary.opacity(0.4))
                .font(.system(size: 20))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(point.code)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color("BrandGreen"))
                Text(point.description)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
