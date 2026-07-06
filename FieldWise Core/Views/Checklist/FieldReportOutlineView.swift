//
//  FieldReportOutlineView.swift
//  Student Fieldwork App
//
//  Guided report-writing scaffold for the active trip. Lists each
//  FieldReportSectionType from the trip's reportOutline with an editable
//  TextEditor and the section's guidance prompts shown as inline hints.
//  Mirrors the Survey Forms tab pattern: takes the shared FieldChecklistStore,
//  handles the "no active trip" state, and offers a PDF export via
//  FieldReportExporter.
//

import SwiftUI

struct FieldReportOutlineView: View {
    @ObservedObject var store: FieldChecklistStore

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        Group {
            if let trip = store.activeTrip {
                Form {
                    summarySection(trip: trip)

                    ForEach(trip.reportOutline.sections) { section in
                        ReportSectionEditor(store: store, section: section)
                    }
                }
            } else {
                Text("Start a trip first to begin a report outline.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Report Outline")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    exportPDF()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(store.activeTrip == nil)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    private func summarySection(trip: FieldTrip) -> some View {
        Section {
            HStack {
                Text("Sections written")
                Spacer()
                Text("\(trip.reportOutline.sectionsWithContent)/\(trip.reportOutline.sections.count)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Total words")
                Spacer()
                Text("\(trip.reportOutline.totalWordCount)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(trip.name)
        } footer: {
            Text("Use this outline to draft each part of your fieldwork report. Tap a section to expand the guidance prompts.")
                .font(.caption)
        }
    }

    private func exportPDF() {
        guard let trip = store.activeTrip, let url = FieldReportExporter.makePDF(for: trip) else { return }
        shareItems = [url]
        showShareSheet = true
    }
}

// MARK: - Single editable section

private struct ReportSectionEditor: View {
    @ObservedObject var store: FieldChecklistStore
    let section: FieldReportSection

    @State private var showingGuidance = false

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $showingGuidance) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(section.type.guidancePrompts.enumerated()), id: \.offset) { _, prompt in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•")
                            Text(prompt)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Text("Guidance")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: Binding(
                get: { section.content },
                set: { store.updateReportSection(section.type, content: $0) }
            ))
            .frame(minHeight: 140)
        } header: {
            HStack {
                Text(section.type.rawValue)
                Spacer()
                Text("\(section.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FieldReportOutlineView(store: FieldChecklistStore())
    }
}
