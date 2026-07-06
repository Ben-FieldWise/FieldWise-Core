//
//  BookletFillView.swift
//  FieldWise Geography
//
//  Renders a structured booklet (a FieldworkTask with a bookletId) as a
//  scrollable set of typed question blocks a student fills in. Each block
//  type has its own editor; answers save per-block to Supabase.
//
//  SKETCH_MAP and PHOTO are shown as placeholders for now (drawing /
//  camera capture is a later pass) so the rest of the booklet is usable.
//

import SwiftUI

// MARK: - Store

@MainActor
final class BookletFillStore: ObservableObject {
    private let service = BookletService()
    let task: FieldworkTask
    let studentUid: String

    @Published var sections: [BookletSection] = []
    @Published var answers: [String: AnswerValue] = [:]
    @Published var savingBlockIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorText: String?

    init(task: FieldworkTask, studentUid: String) {
        self.task = task; self.studentUid = studentUid
    }

    func load() async {
        guard let bookletId = task.bookletId else { return }
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do {
            sections = try await service.fetchSections(bookletId: bookletId)
            let resp = try await service.fetchMyResponses(taskId: task.id, studentUid: studentUid)
            var map: [String: AnswerValue] = [:]
            for r in resp { if let v = r.value { map[r.blockId] = v } }
            answers = map
        } catch { errorText = error.localizedDescription }
    }

    func save(blockId: String, value: AnswerValue) async {
        answers[blockId] = value
        savingBlockIds.insert(blockId)
        defer { savingBlockIds.remove(blockId) }
        do {
            try await service.saveResponse(taskId: task.id, blockId: blockId,
                                           studentUid: studentUid, value: value)
        } catch { errorText = error.localizedDescription }
    }
}

// MARK: - Fill view

struct BookletFillView: View {
    @StateObject private var store: BookletFillStore

    init(task: FieldworkTask, studentUid: String) {
        _store = StateObject(wrappedValue: BookletFillStore(task: task, studentUid: studentUid))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if store.isLoading && store.sections.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
                ForEach(store.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("BrandGreen"))
                        ForEach(section.blocks) { block in
                            BlockEditor(
                                block: block,
                                initial: store.answers[block.id],
                                saving: store.savingBlockIds.contains(block.id),
                                onSave: { value in
                                    Task { await store.save(blockId: block.id, value: value) }
                                })
                        }
                    }
                }
                if let err = store.errorText {
                    Text(err).font(.system(size: 13)).foregroundColor(.red)
                }
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle(store.task.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
    }
}

// MARK: - Block dispatcher

private struct BlockEditor: View {
    let block: BookletBlock
    let initial: AnswerValue?
    let saving: Bool
    let onSave: (AnswerValue) -> Void

    var body: some View {
        switch block.type {
        case .instruction:
            InstructionBlock(prompt: block.prompt, sourceUrl: block.sourceUrl)
        case .shortText, .longText:
            TextBlock(prompt: block.prompt ?? "",
                      long: block.type == .longText,
                      initial: initialText, saving: saving, onSave: onSave)
        case .table:
            TableBlock(prompt: block.prompt ?? "",
                       columns: block.config?.columns ?? ["Column"],
                       minRows: block.config?.minRows ?? 1,
                       initial: initialTable, saving: saving, onSave: onSave)
        case .ratingScale:
            RatingBlock(prompt: block.prompt ?? "",
                        rows: block.config?.rows ?? [],
                        maxValue: block.config?.max ?? 5,
                        initial: initialRatings, saving: saving, onSave: onSave)
        case .checklist:
            ChecklistBlock(prompt: block.prompt ?? "",
                           items: block.config?.items ?? [],
                           initial: initialChecklist, saving: saving, onSave: onSave)
        case .fieldData:
            FieldDataBlock(prompt: block.prompt ?? "",
                           fields: block.config?.fields ?? [],
                           initial: initialFields, saving: saving, onSave: onSave)
        case .gate:
            GateBlock(prompt: block.prompt ?? "", initial: initialGate, saving: saving, onSave: onSave)
        case .sketchMap:
            ComingSoonBlock(prompt: block.prompt ?? "", icon: "pencil.and.outline", label: "Sketch map — capture coming soon")
        case .photo:
            ComingSoonBlock(prompt: block.prompt ?? "", icon: "camera.fill", label: "Photo — capture coming soon")
        }
    }

    private var initialText: String { if case .text(let s)? = initial { return s }; return "" }
    private var initialTable: [[String]] { if case .table(let r)? = initial { return r }; return [] }
    private var initialRatings: [String: Int] { if case .ratings(let m)? = initial { return m }; return [:] }
    private var initialChecklist: [String: Bool] { if case .checklist(let m)? = initial { return m }; return [:] }
    private var initialFields: [String: String] { if case .fields(let m)? = initial { return m }; return [:] }
    private var initialGate: Bool { if case .gate(let b)? = initial { return b }; return false }
}

// MARK: - Shared bits

private struct SavedTick: View {
    let saving: Bool
    var body: some View {
        if saving { ProgressView().scaleEffect(0.7) }
        else { Image(systemName: "checkmark.circle.fill").foregroundColor(Color("GeoGreen")) }
    }
}

private struct BlockPrompt: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Editors

private struct InstructionBlock: View {
    let prompt: String?
    let sourceUrl: String?
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 6) {
                if let p = prompt { Text(p).font(.system(size: 14)).foregroundColor(.secondary) }
                if let s = sourceUrl, let url = URL(string: s) {
                    Link("Source", destination: url).font(.system(size: 12))
                }
            }
        }
    }
}

private struct TextBlock: View {
    let prompt: String; let long: Bool; let saving: Bool
    let onSave: (AnswerValue) -> Void
    @State private var text: String
    init(prompt: String, long: Bool, initial: String, saving: Bool, onSave: @escaping (AnswerValue) -> Void) {
        self.prompt = prompt; self.long = long; self.saving = saving; self.onSave = onSave
        _text = State(initialValue: initial)
    }
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                BlockPrompt(text: prompt)
                GeoTextField(placeholder: long ? "Write your answer…" : "Answer", text: $text, axis: long ? .vertical : .horizontal)
                HStack {
                    Spacer()
                    Button("Save") { onSave(.text(text)) }
                        .font(.system(size: 14, weight: .semibold))
                        .disabled(saving)
                    SavedTick(saving: saving)
                }
            }
        }
    }
}

private struct TableBlock: View {
    let prompt: String; let columns: [String]; let minRows: Int; let saving: Bool
    let onSave: (AnswerValue) -> Void
    @State private var rows: [[String]]
    init(prompt: String, columns: [String], minRows: Int, initial: [[String]], saving: Bool, onSave: @escaping (AnswerValue) -> Void) {
        self.prompt = prompt; self.columns = columns; self.minRows = minRows; self.saving = saving; self.onSave = onSave
        let start = initial.isEmpty ? Array(repeating: Array(repeating: "", count: columns.count), count: max(minRows, 1)) : initial
        _rows = State(initialValue: start)
    }
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                BlockPrompt(text: prompt)
                HStack {
                    ForEach(columns, id: \.self) { c in
                        Text(c).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(columns.indices, id: \.self) { c in
                            GeoTextField(placeholder: "", text: Binding(
                                get: { rows[r].indices.contains(c) ? rows[r][c] : "" },
                                set: { rows[r][c] = $0 }))
                        }
                    }
                }
                HStack {
                    Button {
                        rows.append(Array(repeating: "", count: columns.count))
                    } label: { Label("Add row", systemImage: "plus") }
                        .font(.system(size: 13))
                    Spacer()
                    Button("Save") { onSave(.table(rows)) }
                        .font(.system(size: 14, weight: .semibold)).disabled(saving)
                    SavedTick(saving: saving)
                }
            }
        }
    }
}

private struct RatingBlock: View {
    let prompt: String; let rows: [String]; let maxValue: Int; let saving: Bool
    let onSave: (AnswerValue) -> Void
    @State private var values: [String: Int]
    init(prompt: String, rows: [String], maxValue: Int, initial: [String: Int], saving: Bool, onSave: @escaping (AnswerValue) -> Void) {
        self.prompt = prompt; self.rows = rows; self.maxValue = maxValue; self.saving = saving; self.onSave = onSave
        _values = State(initialValue: initial)
    }
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 12) {
                BlockPrompt(text: prompt)
                ForEach(rows, id: \.self) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row).font(.system(size: 13))
                        HStack(spacing: 8) {
                            ForEach(1...maxValue, id: \.self) { n in
                                let selected = values[row] == n
                                Button { values[row] = n } label: {
                                    Text("\(n)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(width: 34, height: 34)
                                        .background(selected ? Color("GeoGreen") : Color("GeoSurface"))
                                        .foregroundColor(selected ? .white : .primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Save") { onSave(.ratings(values)) }
                        .font(.system(size: 14, weight: .semibold)).disabled(saving)
                    SavedTick(saving: saving)
                }
            }
        }
    }
}

private struct ChecklistBlock: View {
    let prompt: String; let items: [String]; let saving: Bool
    let onSave: (AnswerValue) -> Void
    @State private var checks: [String: Bool]
    init(prompt: String, items: [String], initial: [String: Bool], saving: Bool, onSave: @escaping (AnswerValue) -> Void) {
        self.prompt = prompt; self.items = items; self.saving = saving; self.onSave = onSave
        _checks = State(initialValue: initial)
    }
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                BlockPrompt(text: prompt)
                ForEach(items, id: \.self) { item in
                    Button {
                        checks[item] = !(checks[item] ?? false)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: (checks[item] ?? false) ? "checkmark.square.fill" : "square")
                                .foregroundColor((checks[item] ?? false) ? Color("GeoGreen") : .secondary)
                            Text(item).font(.system(size: 14)).foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Save") { onSave(.checklist(checks)) }
                        .font(.system(size: 14, weight: .semibold)).disabled(saving)
                    SavedTick(saving: saving)
                }
            }
        }
    }
}

private struct FieldDataBlock: View {
    let prompt: String; let fields: [FieldDef]; let saving: Bool
    let onSave: (AnswerValue) -> Void
    @State private var values: [String: String]
    init(prompt: String, fields: [FieldDef], initial: [String: String], saving: Bool, onSave: @escaping (AnswerValue) -> Void) {
        self.prompt = prompt; self.fields = fields; self.saving = saving; self.onSave = onSave
        _values = State(initialValue: initial)
    }
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                BlockPrompt(text: prompt)
                ForEach(fields) { f in
                    VStack(alignment: .leading, spacing: 4) {
                        FieldLabel(text: f.unit != nil ? "\(f.label) (\(f.unit!))" : f.label)
                        GeoTextField(placeholder: "", text: Binding(
                            get: { values[f.key] ?? "" },
                            set: { values[f.key] = $0 }))
                    }
                }
                HStack {
                    Spacer()
                    Button("Save") { onSave(.fields(values)) }
                        .font(.system(size: 14, weight: .semibold)).disabled(saving)
                    SavedTick(saving: saving)
                }
            }
        }
    }
}

private struct GateBlock: View {
    let prompt: String; let saving: Bool
    let onSave: (AnswerValue) -> Void
    @State private var done: Bool
    init(prompt: String, initial: Bool, saving: Bool, onSave: @escaping (AnswerValue) -> Void) {
        self.prompt = prompt; self.saving = saving; self.onSave = onSave
        _done = State(initialValue: initial)
    }
    var body: some View {
        GeoCard {
            HStack {
                Image(systemName: done ? "checkmark.seal.fill" : "hand.raised.fill")
                    .foregroundColor(done ? Color("GeoGreen") : Color("BrandAmber"))
                Text(prompt).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(done ? "Done" : "Mark done") {
                    done = true; onSave(.gate(true))
                }
                .font(.system(size: 14, weight: .semibold)).disabled(saving || done)
            }
        }
    }
}

private struct ComingSoonBlock: View {
    let prompt: String; let icon: String; let label: String
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 8) {
                BlockPrompt(text: prompt)
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundColor(.secondary)
                    Text(label).font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }
}
