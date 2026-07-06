//
//  FieldChecklistStore+SurveyAndReport.swift
//  Student Fieldwork App
//
//  Extends FieldChecklistStore with mutation methods for the Survey Form
//  and Report Outline features. Reuses updateActiveTrip(_:) so persistence
//  and lastModifiedAt stamping stays consistent with the rest of the store.
//

import Foundation

// MARK: - Survey Form mutations

extension FieldChecklistStore {

    func addSurveyForm(title: String = "Site Survey Form") {
        updateActiveTrip { trip in
            trip.surveyForms.append(FieldSurveyForm(formTitle: title))
        }
    }

    func duplicateSurveyForm(_ form: FieldSurveyForm) {
        updateActiveTrip { trip in
            guard let index = trip.surveyForms.firstIndex(where: { $0.id == form.id }) else { return }
            var copy = trip.surveyForms[index]
            copy.id = UUID()
            copy.formTitle = form.formTitle + " (copy)"
            copy.createdAt = Date()
            copy.lastModifiedAt = Date()
            // Reset checked state for a fresh site visit
            for gIndex in copy.gridGroups.indices {
                copy.gridGroups[gIndex].photoTaken = false
                copy.gridGroups[gIndex].photoReference = ""
                for tIndex in copy.gridGroups[gIndex].terms.indices {
                    copy.gridGroups[gIndex].terms[tIndex].isChecked = false
                    copy.gridGroups[gIndex].terms[tIndex].otherDescription = ""
                }
            }
            trip.surveyForms.insert(copy, at: index + 1)
        }
    }

    func deleteSurveyForm(_ form: FieldSurveyForm) {
        updateActiveTrip { trip in
            trip.surveyForms.removeAll { $0.id == form.id }
        }
    }

    func updateSurveyForm(_ formID: UUID, _ mutate: (inout FieldSurveyForm) -> Void) {
        updateActiveTrip { trip in
            guard let index = trip.surveyForms.firstIndex(where: { $0.id == formID }) else { return }
            mutate(&trip.surveyForms[index])
            trip.surveyForms[index].lastModifiedAt = Date()
        }
    }

    func renameSurveyForm(_ formID: UUID, title: String) {
        updateSurveyForm(formID) { $0.formTitle = title }
    }

    func updateSurveyHeader(_ formID: UUID, header: FieldSurveyHeader) {
        updateSurveyForm(formID) { $0.header = header }
    }

    func updateOverallNotes(_ formID: UUID, notes: String) {
        updateSurveyForm(formID) { $0.overallNotes = notes }
    }

    // Grid groups

    func addGridGroup(_ formID: UUID, title: String = "New Group") {
        updateSurveyForm(formID) { form in
            var group = FieldSurveyGridGroup(title: title)
            group.terms = [FieldSurveyTerm(label: "Other", isOther: true)]
            form.gridGroups.append(group)
        }
    }

    func removeGridGroup(_ formID: UUID, groupID: UUID) {
        updateSurveyForm(formID) { form in
            form.gridGroups.removeAll { $0.id == groupID }
        }
    }

    func renameGridGroup(_ formID: UUID, groupID: UUID, title: String) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            form.gridGroups[gIndex].title = title
        }
    }

    func updateGroupSectionNotes(_ formID: UUID, groupID: UUID, notes: String) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            form.gridGroups[gIndex].sectionNotes = notes
        }
    }

    func toggleGroupPhotoTaken(_ formID: UUID, groupID: UUID) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            form.gridGroups[gIndex].photoTaken.toggle()
        }
    }

    func updateGroupPhotoReference(_ formID: UUID, groupID: UUID, reference: String) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            form.gridGroups[gIndex].photoReference = reference
        }
    }

    // Terms within a grid group

    func addTerm(_ formID: UUID, groupID: UUID, label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            // Insert before the trailing "Other" row if present, else append
            if let otherIndex = form.gridGroups[gIndex].terms.firstIndex(where: { $0.isOther }) {
                form.gridGroups[gIndex].terms.insert(FieldSurveyTerm(label: trimmed), at: otherIndex)
            } else {
                form.gridGroups[gIndex].terms.append(FieldSurveyTerm(label: trimmed))
            }
        }
    }

    func removeTerm(_ formID: UUID, groupID: UUID, termID: UUID) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            form.gridGroups[gIndex].terms.removeAll { $0.id == termID }
        }
    }

    func renameTerm(_ formID: UUID, groupID: UUID, termID: UUID, label: String) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            guard let tIndex = form.gridGroups[gIndex].terms.firstIndex(where: { $0.id == termID }) else { return }
            form.gridGroups[gIndex].terms[tIndex].label = label
        }
    }

    func toggleTerm(_ formID: UUID, groupID: UUID, termID: UUID) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            guard let tIndex = form.gridGroups[gIndex].terms.firstIndex(where: { $0.id == termID }) else { return }
            form.gridGroups[gIndex].terms[tIndex].isChecked.toggle()
        }
    }

    func updateOtherDescription(_ formID: UUID, groupID: UUID, termID: UUID, description: String) {
        updateSurveyForm(formID) { form in
            guard let gIndex = form.gridGroups.firstIndex(where: { $0.id == groupID }) else { return }
            guard let tIndex = form.gridGroups[gIndex].terms.firstIndex(where: { $0.id == termID }) else { return }
            form.gridGroups[gIndex].terms[tIndex].otherDescription = description
            // Auto-check "Other" once the student starts describing it
            if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                form.gridGroups[gIndex].terms[tIndex].isChecked = true
            }
        }
    }
}

// MARK: - Report Outline mutations

extension FieldChecklistStore {

    func updateReportSection(_ sectionType: FieldReportSectionType, content: String) {
        updateActiveTrip { trip in
            guard let index = trip.reportOutline.sections.firstIndex(where: { $0.type == sectionType }) else { return }
            trip.reportOutline.sections[index].content = content
        }
    }
}
