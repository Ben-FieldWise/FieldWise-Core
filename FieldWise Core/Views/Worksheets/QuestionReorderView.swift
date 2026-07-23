//
//  QuestionReorderView.swift
//  FieldWise Core
//
//  Standalone screen for reordering the questions within ONE section.
//  See SectionReorderView's header comment for why this is a separate
//  single-list screen rather than a nested ForEach inside the main
//  builder's List -- the short version: nesting nested reorderable
//  ForEachs inside one List crashed SwiftUI's own internals on a
//  cross-boundary drag, before any of this app's code ran. A dedicated
//  screen with exactly one ForEach+.onMove removes the possibility.
//

import SwiftUI

struct QuestionReorderView: View {
    let section: WorksheetSection
    @ObservedObject var store: WorksheetStore

    private var questions: [WorksheetQuestion] {
        store.questionsBySection[section.id] ?? []
    }

    var body: some View {
        List {
            ForEach(questions) { question in
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 13))
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color("BrandGreen").opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: question.questionType.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("BrandGreen"))
                    }
                    Text(question.prompt)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .onMove { source, destination in
                Task {
                    await store.reorderQuestions(sectionId: section.id, from: source, to: destination)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reorder Questions")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
    }
}
