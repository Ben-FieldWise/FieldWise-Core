//
//  SheetEditorView.swift
//  FieldWise Core
//
//  The worksheet builder itself: add sections, add questions of any of
//  the ten types to a section, reorder is by creation order (drag-to-
//  reorder is a follow-up), publish when ready.
//

import SwiftUI

struct SheetEditorView: View {
    let sheet: FieldworkSheet
    @StateObject private var store = WorksheetStore()

    @State private var showingAddSection = false
    @State private var newSectionTitle = ""
    @State private var addQuestionSectionId: String?
    @State private var pushSessions = false


    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if store.sections.isEmpty && !store.isLoading {
                    emptyState
                } else {
                    ForEach(store.sections) { section in
                        SectionCard(
                            section: section,
                            questions: store.questionsBySection[section.id] ?? [],
                            onAddQuestion: { addQuestionSectionId = section.id },
                            onDeleteQuestion: { q in Task { await store.deleteQuestion(q) } },
                            onDeleteSection: { Task { await store.deleteSection(section) } }
                        )
                    }
                }

                addSectionButton
            }
            .padding(20)
        }
        .background(Color("GeoSurface"))
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $pushSessions) {
            SessionsView(sheet: sheet)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await store.setStatus(sheet, status: "active") }
                    } label: {
                        Label("Publish", systemImage: "checkmark.seal.fill")
                    }
                    Button {
                        Task { await store.setStatus(sheet, status: "draft") }
                    } label: {
                        Label("Move to draft", systemImage: "pencil.circle")
                    }
                    Divider()
                    Button {
                        pushSessions = true
                    } label: {
                        Label("Sessions", systemImage: "qrcode")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(Color("BrandGreen"))
            }
        }

        .task { await store.loadDetail(sheetId: sheet.id) }
        .alert("Add section", isPresented: $showingAddSection) {
            TextField("Section title (e.g. Site 1)", text: $newSectionTitle)
            Button("Cancel", role: .cancel) { newSectionTitle = "" }
            Button("Add") {
                let title = newSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                Task { await store.addSection(sheetId: sheet.id, title: title, instructions: nil) }
                newSectionTitle = ""
            }
        }
        .sheet(item: Binding(
            get: { addQuestionSectionId.map { SectionID(id: $0) } },
            set: { addQuestionSectionId = $0?.id }
        )) { wrapped in
            AddQuestionView { type, prompt, options, required in
                Task {
                    await store.addQuestion(
                        sectionId: wrapped.id, type: type, prompt: prompt,
                        options: options, required: required, requiredTool: nil)
                    addQuestionSectionId = nil
                }
            }
        }
        .alert("Something went wrong", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description = sheet.description, !description.isEmpty {
                Text(description).font(.system(size: 14)).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                if let subject = sheet.subjectArea { InfoPill(text: subject) }
                if let year = sheet.yearLevel { InfoPill(text: year) }
                InfoPill(text: sheet.status.capitalized)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Color("BrandGreen").opacity(0.5))
            Text("Add your first section")
                .font(.system(size: 16, weight: .semibold))
            Text("Sections group related questions — e.g. one per site, or Introduction / Method / Results.")
                .font(.system(size: 13)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
    }

    private var addSectionButton: some View {
        Button {
            showingAddSection = true
        } label: {
            Label("Add section", systemImage: "plus.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color("BrandGreen"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color("BrandGreen").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Identifiable wrapper so a plain String section id can drive `.sheet(item:)`.
private struct SectionID: Identifiable { let id: String }

// MARK: - Section card

private struct SectionCard: View {
    let section: WorksheetSection
    let questions: [WorksheetQuestion]
    let onAddQuestion: () -> Void
    let onDeleteQuestion: (WorksheetQuestion) -> Void
    let onDeleteSection: () -> Void

    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(section.title).font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Menu {
                        Button(role: .destructive, action: onDeleteSection) {
                            Label("Delete section", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(.secondary)
                    }
                }
                if let instructions = section.instructions, !instructions.isEmpty {
                    Text(instructions).font(.system(size: 13)).foregroundColor(.secondary)
                }

                if questions.isEmpty {
                    Text("No questions yet.")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                } else {
                    ForEach(questions) { q in
                        QuestionRow(question: q, onDelete: { onDeleteQuestion(q) })
                        if q.id != questions.last?.id { Divider() }
                    }
                }

                Button(action: onAddQuestion) {
                    Label("Add question", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("BrandGreen"))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

private struct QuestionRow: View {
    let question: WorksheetQuestion
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color("BrandGreen").opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: question.questionType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("BrandGreen"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(question.prompt).font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
                HStack(spacing: 6) {
                    Text(question.questionType.title).font(.system(size: 11)).foregroundColor(.secondary)
                    if question.required {
                        Text("· Required").font(.system(size: 11)).foregroundColor(Color("GeoCoral"))
                    }
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct InfoPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
    }
}
