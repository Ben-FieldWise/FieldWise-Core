//
//  FieldSurveyFormView.swift
//  Student Fieldwork App
//
//  Structured site survey form: header fields, editable checkbox grid
//  groups (with an "Other - please describe" row), per-group notes,
//  and an overall notes box. Modelled on paper field-survey sheets.
//

import SwiftUI

// MARK: - List of survey forms for the active trip

struct SurveyFormListView: View {
    @ObservedObject var store: FieldChecklistStore

    var body: some View {
        Group {
            if let trip = store.activeTrip {
                List {
                    ForEach(trip.surveyForms) { form in
                        NavigationLink {
                            SurveyFormDetailView(store: store, formID: form.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(form.formTitle)
                                    .font(.headline)
                                Text("\(form.totalChecked)/\(form.totalTerms) features checked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteSurveyForm(form)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                store.duplicateSurveyForm(form)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .overlay {
                    if trip.surveyForms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No survey forms yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Add one per site you visit.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Start a trip first to add survey forms.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Survey Forms")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.addSurveyForm()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(store.activeTrip == nil)
            }
        }
    }
}

// MARK: - Detail / edit view for a single survey form

struct SurveyFormDetailView: View {
    @ObservedObject var store: FieldChecklistStore
    let formID: UUID

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingAddGroupAlert = false
    @State private var newGroupTitle = ""

    private var form: FieldSurveyForm? {
        store.activeTrip?.surveyForms.first { $0.id == formID }
    }

    var body: some View {
        Group {
            if let form {
                Form {
                    titleSection(form)
                    headerSection(form)

                    ForEach(form.gridGroups) { group in
                        GridGroupSectionView(store: store, formID: formID, group: group)
                    }

                    Section {
                        Button {
                            showingAddGroupAlert = true
                        } label: {
                            Label("Add Grid Group", systemImage: "plus.square.on.square")
                        }
                    }

                    Section("Overall Notes") {
                        TextEditor(text: Binding(
                            get: { form.overallNotes },
                            set: { store.updateOverallNotes(formID, notes: $0) }
                        ))
                        .frame(minHeight: 120)
                    }
                }
                .navigationTitle(form.formTitle)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            exportPDF(form)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .alert("New Grid Group", isPresented: $showingAddGroupAlert) {
                    TextField("Group title", text: $newGroupTitle)
                    Button("Add") {
                        let trimmed = newGroupTitle.trimmingCharacters(in: .whitespaces)
                        store.addGridGroup(formID, title: trimmed.isEmpty ? "New Group" : trimmed)
                        newGroupTitle = ""
                    }
                    Button("Cancel", role: .cancel) { newGroupTitle = "" }
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: shareItems)
                }
            } else {
                Text("Form not found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func titleSection(_ form: FieldSurveyForm) -> some View {
        Section {
            TextField("Form title", text: Binding(
                get: { form.formTitle },
                set: { store.renameSurveyForm(formID, title: $0) }
            ))
            .font(.headline)
        }
    }

    private func headerSection(_ form: FieldSurveyForm) -> some View {
        Section("Survey Details") {
            headerFieldBinding(form, \.surveyorName, label: "Surveyor")
            headerFieldBinding(form, \.contactInfo, label: "Contact Telephone / Email")
            headerFieldBinding(form, \.siteOwnerOrManager, label: "Site Owner / Manager")
            headerFieldBinding(form, \.siteOwnerContact, label: "Owner / Manager Contact")
            headerFieldBinding(form, \.mapCodeOrGridRef, label: "Map Code / Grid Reference")
            headerFieldBinding(form, \.siteNumber, label: "Site Number")
            headerFieldBinding(form, \.siteName, label: "Site Name")
            headerFieldBinding(form, \.areaOrRegion, label: "Area / Region / Townland")
        }
    }

    private func headerFieldBinding(
        _ form: FieldSurveyForm,
        _ keyPath: WritableKeyPath<FieldSurveyHeader, String>,
        label: String
    ) -> some View {
        TextField(label, text: Binding(
            get: { form.header[keyPath: keyPath] },
            set: { newValue in
                var header = form.header
                header[keyPath: keyPath] = newValue
                store.updateSurveyHeader(formID, header: header)
            }
        ))
    }

    private func exportPDF(_ form: FieldSurveyForm) {
        guard let trip = store.activeTrip, let url = FieldSurveyExporter.makePDF(for: form, trip: trip) else { return }
        shareItems = [url]
        showShareSheet = true
    }
}

// MARK: - One grid group (e.g. "Landscape / Physical Features")

struct GridGroupSectionView: View {
    @ObservedObject var store: FieldChecklistStore
    let formID: UUID
    let group: FieldSurveyGridGroup

    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @State private var showingAddTermAlert = false
    @State private var newTermLabel = ""

    var body: some View {
        Section {
            // Photo taken / reference row, matching the sample form's pattern
            HStack {
                Toggle("Photo taken", isOn: Binding(
                    get: { group.photoTaken },
                    set: { _ in store.toggleGroupPhotoTaken(formID, groupID: group.id) }
                ))
            }
            if group.photoTaken {
                TextField("Photo reference (e.g. IMG_0231)", text: Binding(
                    get: { group.photoReference },
                    set: { store.updateGroupPhotoReference(formID, groupID: group.id, reference: $0) }
                ))
                .font(.caption)
            }

            ForEach(group.terms) { term in
                SurveyTermRow(store: store, formID: formID, groupID: group.id, term: term)
            }

            if showingAddTermAlert {
                HStack {
                    TextField("New term…", text: $newTermLabel)
                        .onSubmit { addTerm() }
                    Button("Add") { addTerm() }
                        .disabled(newTermLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Button {
                    showingAddTermAlert = true
                } label: {
                    Label("Add term", systemImage: "plus.circle")
                        .font(.caption)
                }
            }

            DisclosureGroup("Section Notes") {
                TextEditor(text: Binding(
                    get: { group.sectionNotes },
                    set: { store.updateGroupSectionNotes(formID, groupID: group.id, notes: $0) }
                ))
                .frame(minHeight: 80)
            }
        } header: {
            HStack {
                if isEditingTitle {
                    TextField("Group title", text: $titleDraft, onCommit: commitTitle)
                        .font(.subheadline.bold())
                    Button("Save") { commitTitle() }
                        .font(.caption)
                } else {
                    Text(group.title)
                    Spacer()
                    Text("\(group.checkedCount)/\(group.terms.count)")
                        .font(.caption)
                    Button {
                        titleDraft = group.title
                        isEditingTitle = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    Button(role: .destructive) {
                        store.removeGridGroup(formID, groupID: group.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.renameGridGroup(formID, groupID: group.id, title: trimmed)
        }
        isEditingTitle = false
    }

    private func addTerm() {
        let trimmed = newTermLabel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addTerm(formID, groupID: group.id, label: trimmed)
        newTermLabel = ""
        showingAddTermAlert = false
    }
}

// MARK: - One checkbox term row, with "Other" handled specially

struct SurveyTermRow: View {
    @ObservedObject var store: FieldChecklistStore
    let formID: UUID
    let groupID: UUID
    let term: FieldSurveyTerm

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    store.toggleTerm(formID, groupID: groupID, termID: term.id)
                } label: {
                    Image(systemName: term.isChecked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(term.isChecked ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(term.isOther ? "Other – please describe" : term.label)
                    .strikethrough(term.isChecked && !term.isOther, color: .secondary)

                Spacer()

                if !term.isOther {
                    Button(role: .destructive) {
                        store.removeTerm(formID, groupID: groupID, termID: term.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            if term.isOther {
                TextField("Describe…", text: Binding(
                    get: { term.otherDescription },
                    set: { store.updateOtherDescription(formID, groupID: groupID, termID: term.id, description: $0) }
                ))
                .font(.caption)
                .padding(.leading, 28)
            }
        }
    }
}
