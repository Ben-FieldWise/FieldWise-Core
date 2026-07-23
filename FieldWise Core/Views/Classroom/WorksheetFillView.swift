//
//  WorksheetFillView.swift
//  FieldWise Core
//
//  Student-facing "answer it" counterpart to AddQuestionView's "configure
//  it" editor. Renders every worksheet_questions type as an input control,
//  bound to SessionStore.answers, with autosave-on-change and a submit
//  flow that validates required questions.
//
//  Pushed from JoinSessionView once a session has been joined, so it
//  takes the already-populated store rather than re-fetching.
//

import SwiftUI

struct WorksheetFillView: View {
    @ObservedObject var store: SessionStore

    @State private var showSubmitConfirm = false
    @State private var showSubmittedBanner = false

    private var isLocked: Bool { store.myResponse?.status == .reviewed }
    private var isSubmitted: Bool { store.myResponse?.status == .submitted }

    var body: some View {
        Group {
            if store.mySheet == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
            }
        }
        .background(Color("GeoSurface"))
        .navigationTitle(store.mySheet?.title ?? "Worksheet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSubmitConfirm = true
                } label: {
                    Text(isSubmitted ? "Update" : "Submit")
                        .fontWeight(.semibold)
                }
                .tint(Color("BrandGreen"))
                .disabled(isLocked)
            }
        }
        .confirmationDialog(
            store.unansweredRequiredCount > 0
                ? "\(store.unansweredRequiredCount) required question\(store.unansweredRequiredCount == 1 ? "" : "s") still need an answer."
                : "Submit your answers to your teacher?",
            isPresented: $showSubmitConfirm,
            titleVisibility: .visible
        ) {
            if store.unansweredRequiredCount == 0 {
                Button("Submit") { Task { await submit() } }
            }
            Button("Cancel", role: .cancel) { }
        }
        .overlay(alignment: .bottom) {
            if showSubmittedBanner {
                submittedBanner
            }
        }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
        .onDisappear {
            // Text fields only commit to `store.answers` as the user
            // types (no per-keystroke network call); catch that up here
            // so leaving mid-question doesn't lose it. Choice/rating/
            // table controls already save immediately on tap.
            Task { await store.saveDraft() }
        }
    }

    private var form: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(store.mySections) { section in
                    sectionCard(section)
                }

                Color.clear.frame(height: 40) // room above the submit banner
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description = store.mySheet?.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                statusBadge
                if isLocked {
                    Text("Reviewed by your teacher — no further changes.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch store.myResponse?.status {
            case .reviewed: return ("Reviewed", Color("GeoBlue"))
            case .submitted: return ("Submitted", Color("BrandGreen"))
            default: return ("Draft", .gray)
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private func sectionCard(_ section: WorksheetSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.title).font(.system(size: 17, weight: .bold))
                if let instructions = section.instructions, !instructions.isEmpty {
                    Text(instructions).font(.system(size: 13)).foregroundColor(.secondary)
                }
            }

            ForEach(store.myQuestionsBySection[section.id] ?? []) { question in
                questionRow(question)
                if question.id != (store.myQuestionsBySection[section.id] ?? []).last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Seed value fallback

    /// The answer to actually display for a question: the student's own
    /// recorded answer if one exists, otherwise the question's seedValue
    /// (set only on worksheets imported from a FieldWise Geography
    /// investigation — see GeographyImportService). Every read site below
    /// goes through this rather than reading `store.answers` directly, so
    /// a freshly-joined student sees the imported investigation's
    /// original data as a starting point instead of a blank question.
    ///
    /// Deliberately does NOT write the seed into `store.answers` on
    /// read — it stays a display-only fallback until the student actually
    /// edits the field (at which point setAnswer/saveDraft persist their
    /// real edit as normal). This keeps "has this student actually
    /// answered yet" meaningful for unansweredRequiredCount and for a
    /// teacher reviewing responses later, rather than every imported
    /// worksheet's first response looking pre-answered before anyone
    /// touched it.
    private func effectiveAnswer(for question: WorksheetQuestion) -> SessionAnswerValue? {
        store.answers[question.id] ?? question.options.seedValue?.asAnswerValue
    }

    // MARK: - Per-type question rendering

    @ViewBuilder
    private func questionRow(_ question: WorksheetQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: question.questionType.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("BrandGreen"))
                    .padding(.top, 2)
                Text(question.prompt)
                    .font(.system(size: 15, weight: .medium))
                if question.required {
                    Text("*").foregroundColor(.red).font(.system(size: 15, weight: .bold))
                }
                Spacer()
            }

            answerControl(for: question)
                .disabled(isLocked)
        }
    }

    @ViewBuilder
    private func answerControl(for question: WorksheetQuestion) -> some View {
        switch question.questionType {
        case .shortAnswer:
            TextField("Your answer", text: stringBinding(question))
                .textFieldStyle(.roundedBorder)

        case .longAnswer:
            TextField("Your answer", text: stringBinding(question), axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)

        case .multipleChoice:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(question.options.choices ?? [], id: \.self) { choice in
                    choiceRow(
                        label: choice,
                        selected: effectiveAnswer(for: question)?.stringValue == choice,
                        style: .radio
                    ) {
                        store.setAnswer(.string(choice), for: question.id)
                        Task { await store.saveDraft() }
                    }
                }
            }

        case .checkbox:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(question.options.choices ?? [], id: \.self) { choice in
                    let selected = effectiveAnswer(for: question)?.stringArrayValue.contains(choice) ?? false
                    choiceRow(label: choice, selected: selected, style: .checkbox) {
                        var current = effectiveAnswer(for: question)?.stringArrayValue ?? []
                        if selected { current.removeAll { $0 == choice } }
                        else { current.append(choice) }
                        store.setAnswer(.stringArray(current), for: question.id)
                        Task { await store.saveDraft() }
                    }
                }
            }

        case .ratingScale:
            let min = question.options.min ?? 1
            let max = question.options.max ?? 5
            HStack(spacing: 10) {
                ForEach(min...max, id: \.self) { value in
                    let selected = effectiveAnswer(for: question)?.intValue == value
                    Button {
                        store.setAnswer(.int(value), for: question.id)
                        Task { await store.saveDraft() }
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(selected ? Color("BrandGreen") : Color(.systemGray6))
                            .foregroundColor(selected ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }

        case .dataTable:
            dataTableInput(question)

        case .photoUpload:
            placeholderNotice("Photo capture for worksheet questions isn't wired up yet — use the class Photos tool for now.")

        case .gpsPoint:
            placeholderNotice("GPS capture for worksheet questions isn't wired up yet — use the class GPS tool for now.")

        case .sketch:
            placeholderNotice("Sketching for worksheet questions isn't wired up yet.")

        case .teacherNote:
            EmptyView() // display-only prompt; no input needed
        }
    }

    // MARK: - Choice row

    private enum ChoiceStyle { case radio, checkbox }

    private func choiceRow(label: String, selected: Bool, style: ChoiceStyle, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: iconName(selected: selected, style: style))
                    .foregroundColor(selected ? Color("BrandGreen") : .secondary)
                Text(label).font(.system(size: 14)).foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func iconName(selected: Bool, style: ChoiceStyle) -> String {
        switch style {
        case .radio: return selected ? "largecircle.fill.circle" : "circle"
        case .checkbox: return selected ? "checkmark.square.fill" : "square"
        }
    }

    // MARK: - Data table input

    private func dataTableInput(_ question: WorksheetQuestion) -> some View {
        let columns = question.options.columns ?? []
        let rows = store.answers[question.id]?.tableValue ?? [Array(repeating: "", count: columns.count)]

        return VStack(alignment: .leading, spacing: 10) {
            if !columns.isEmpty {
                HStack {
                    ForEach(columns, id: \.self) { col in
                        Text(col).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack {
                    ForEach(columns.indices, id: \.self) { colIndex in
                        TextField("—", text: cellBinding(question.id, row: rowIndex, col: colIndex, columnCount: columns.count))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                }
            }
            Button {
                var current = rows
                current.append(Array(repeating: "", count: columns.count))
                store.setAnswer(.table(current), for: question.id)
            } label: {
                Label("Add row", systemImage: "plus.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .tint(Color("BrandGreen"))
        }
    }

    private func cellBinding(_ questionId: String, row: Int, col: Int, columnCount: Int) -> Binding<String> {
        Binding(
            get: {
                let table = store.answers[questionId]?.tableValue ?? []
                guard row < table.count, col < table[row].count else { return "" }
                return table[row][col]
            },
            set: { newValue in
                var table = store.answers[questionId]?.tableValue ?? [Array(repeating: "", count: columnCount)]
                while table.count <= row { table.append(Array(repeating: "", count: columnCount)) }
                while table[row].count <= col { table[row].append("") }
                table[row][col] = newValue
                store.setAnswer(.table(table), for: questionId)
            }
        )
    }

    // MARK: - Text bindings (with debounced-by-navigation autosave)

    /// Always stores a `.string` (even "") while typing, so the binding
    /// never round-trips through `nil` and fights the user mid-edit.
    /// Required-question validation checks for a trimmed-empty string,
    /// not for the key being absent, so this doesn't affect the "still
    /// needs an answer" count.
    private func stringBinding(_ question: WorksheetQuestion) -> Binding<String> {
        Binding(
            get: { effectiveAnswer(for: question)?.stringValue ?? "" },
            set: { newValue in
                store.setAnswer(.string(newValue), for: question.id)
            }
        )
    }

    private func placeholderNotice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Submit

    private func submit() async {
        let ok = await store.submit()
        if ok {
            withAnimation { showSubmittedBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showSubmittedBanner = false }
            }
        }
    }

    private var submittedBanner: some View {
        Label("Submitted", systemImage: "checkmark.circle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color("BrandGreen"))
            .clipShape(Capsule())
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
