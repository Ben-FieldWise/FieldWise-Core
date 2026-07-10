//
//  AddQuestionView.swift
//  FieldWise Core
//
//  Modal for adding one question to a section: pick a type, write the
//  prompt, and (for types that need it) configure choices / rating range
//  / table columns.
//

import SwiftUI

struct AddQuestionView: View {
    var onAdd: (_ type: WorksheetQuestionType, _ prompt: String,
                _ options: WorksheetQuestionOptions, _ required: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var type: WorksheetQuestionType = .shortAnswer
    @State private var prompt = ""
    @State private var required = false

    // Options state
    @State private var choiceText = ""
    @State private var choices: [String] = []
    @State private var ratingMin = 1
    @State private var ratingMax = 5
    @State private var columnText = ""
    @State private var columns: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Question type") {
                    Picker("Type", selection: $type) {
                        ForEach(WorksheetQuestionType.allCases) { t in
                            Label(t.title, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Prompt") {
                    TextField("What should the student do here?", text: $prompt, axis: .vertical)
                    Toggle("Required", isOn: $required)
                }

                if type.usesOptions {
                    optionsSection
                }
            }
            .navigationTitle("Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(type, prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                              buildOptions(), required)
                        dismiss()
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        switch type {
        case .multipleChoice, .checkbox:
            Section("Choices") {
                HStack {
                    TextField("Add a choice", text: $choiceText)
                    Button("Add") {
                        let trimmed = choiceText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        choices.append(trimmed)
                        choiceText = ""
                    }
                    .disabled(choiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(choices, id: \.self) { choice in
                    Text(choice)
                }
                .onDelete { choices.remove(atOffsets: $0) }
            }

        case .ratingScale:
            Section("Scale range") {
                Stepper("Minimum: \(ratingMin)", value: $ratingMin, in: 0...ratingMax - 1)
                Stepper("Maximum: \(ratingMax)", value: $ratingMax, in: ratingMin + 1...10)
            }

        case .dataTable:
            Section("Columns") {
                HStack {
                    TextField("Add a column (e.g. Depth (cm))", text: $columnText)
                    Button("Add") {
                        let trimmed = columnText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        columns.append(trimmed)
                        columnText = ""
                    }
                    .disabled(columnText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(columns, id: \.self) { column in
                    Text(column)
                }
                .onDelete { columns.remove(atOffsets: $0) }
            }

        default:
            EmptyView()
        }
    }

    private func buildOptions() -> WorksheetQuestionOptions {
        switch type {
        case .multipleChoice, .checkbox:
            return WorksheetQuestionOptions(choices: choices)
        case .ratingScale:
            return WorksheetQuestionOptions(min: ratingMin, max: ratingMax)
        case .dataTable:
            return WorksheetQuestionOptions(columns: columns)
        default:
            return WorksheetQuestionOptions()
        }
    }
}
