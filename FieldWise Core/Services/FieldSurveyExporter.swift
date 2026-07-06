//
//  FieldSurveyExporter.swift
//  Student Fieldwork App
//
//  Exports a FieldSurveyForm to PDF (laid out like the paper grid-style
//  survey sheet it was modelled on) and CSV (flat row-per-term dump).
//

import Foundation
import UIKit

enum FieldSurveyExporter {

    // MARK: - CSV

    static func makeCSV(for form: FieldSurveyForm, trip: FieldTrip) -> URL? {
        var rows: [String] = ["Form,Trip,Group,Term,Checked,OtherDescription"]

        for group in form.gridGroups {
            for term in group.terms {
                let label = term.isOther ? "Other" : term.label
                let fields = [
                    csvEscape(form.formTitle),
                    csvEscape(trip.name),
                    csvEscape(group.title),
                    csvEscape(label),
                    term.isChecked ? "Yes" : "No",
                    csvEscape(term.otherDescription)
                ]
                rows.append(fields.joined(separator: ","))
            }
        }

        return FieldPDFKit.writeTemporaryFile(
            contents: rows.joined(separator: "\n"),
            filename: FieldPDFKit.sanitizedFilename(form.formTitle, fallback: "Survey_Form") + ".csv"
        )
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    // MARK: - PDF

    static func makePDF(for form: FieldSurveyForm, trip: FieldTrip) -> URL? {
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let subtitleFont = UIFont.systemFont(ofSize: 11)
        let headerLabelFont = UIFont.boldSystemFont(ofSize: 10)
        let groupTitleFont = UIFont.boldSystemFont(ofSize: 13)
        let termFont = UIFont.systemFont(ofSize: 10.5)
        let notesFont = UIFont.italicSystemFont(ofSize: 9.5)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let data = FieldPDFKit.render(title: "Survey Form - \(form.formTitle)") { flow in
            flow.draw(form.formTitle, font: titleFont, extraSpacing: 6)
            flow.draw(trip.name, font: subtitleFont, color: .darkGray)
            flow.draw(dateFormatter.string(from: trip.date), font: subtitleFont, color: .darkGray, extraSpacing: 12)

            flow.drawDivider()

            // Header / survey details block
            let header = form.header
            let headerPairs: [(String, String)] = [
                ("Surveyor", header.surveyorName),
                ("Contact", header.contactInfo),
                ("Site Owner / Manager", header.siteOwnerOrManager),
                ("Owner Contact", header.siteOwnerContact),
                ("Map Code / Grid Ref", header.mapCodeOrGridRef),
                ("Site Number", header.siteNumber),
                ("Site Name", header.siteName),
                ("Area / Region", header.areaOrRegion),
            ]
            for (label, value) in headerPairs where !value.isEmpty {
                flow.draw("\(label): \(value)", font: headerLabelFont, extraSpacing: 2)
            }
            flow.addSpace(10)
            flow.drawDivider()

            // Grid groups
            for group in form.gridGroups {
                flow.ensureSpace(28)
                flow.draw(
                    "\(group.title)  (\(group.checkedCount)/\(group.terms.count))",
                    font: groupTitleFont, extraSpacing: 2
                )
                if group.photoTaken {
                    let ref = group.photoReference.isEmpty ? "" : " — \(group.photoReference)"
                    flow.draw("Photo taken\(ref)", font: notesFont, color: .gray, extraSpacing: 4)
                }

                for term in group.terms {
                    let box = term.isChecked ? "[x]" : "[ ]"
                    if term.isOther {
                        let desc = term.otherDescription.isEmpty ? "(not described)" : term.otherDescription
                        flow.draw("\(box)  Other: \(desc)", font: termFont, extraSpacing: 2)
                    } else {
                        flow.draw("\(box)  \(term.label)", font: termFont, extraSpacing: 2)
                    }
                }

                if !group.sectionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    flow.addSpace(2)
                    flow.draw("Notes: \(group.sectionNotes)", font: notesFont, color: .darkGray, extraSpacing: 4)
                }
                flow.addSpace(10)
            }

            if !form.overallNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flow.drawDivider()
                flow.draw("Overall Notes", font: groupTitleFont, extraSpacing: 4)
                flow.draw(form.overallNotes, font: termFont)
            }
        }

        return FieldPDFKit.writeTemporaryFile(
            data: data,
            filename: FieldPDFKit.sanitizedFilename(form.formTitle, fallback: "Survey_Form") + ".pdf"
        )
    }
}
