//
//  SectionReorderView.swift
//  FieldWise Core
//
//  Standalone screen for reordering a sheet's sections. Deliberately
//  separate from question reordering (see QuestionReorderView) and from
//  SheetEditorView's normal display -- each uses exactly one List with
//  exactly one ForEach+.onMove over one flat array.
//
//  This replaces an earlier design that nested a ForEach of questions
//  (each with its own .onMove) inside a ForEach of sections (itself with
//  .onMove) in a single List. That structure let a drag gesture attempt
//  to cross from one section's question list into another section's, and
//  crashed with EXC_BREAKPOINT inside SwiftUI's own internal list-update
//  machinery before the drag ever reached WorksheetStore's reorder
//  methods -- i.e. before any bounds-checking in Swift code could run.
//  Multiple independent ForEach+.onMove pairs sharing one List is not a
//  safely supported SwiftUI configuration; splitting reordering into two
//  separate single-list screens removes the possibility entirely, since
//  there is never more than one reorderable ForEach on screen at once.
//

import SwiftUI

struct SectionReorderView: View {
    let sheet: FieldworkSheet
    @ObservedObject var store: WorksheetStore

    var body: some View {
        List {
            ForEach(store.sections) { section in
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.system(size: 15, weight: .medium))
                        let count = store.questionsBySection[section.id]?.count ?? 0
                        Text("\(count) question\(count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .onMove { source, destination in
                Task {
                    await store.reorderSections(sheetId: sheet.id, from: source, to: destination)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reorder Sections")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
    }
}
