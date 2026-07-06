//
//  FieldReportExporter.swift
//  Student Fieldwork App
//
//  Exports the FieldReportOutline as a formatted draft report PDF, with
//  each section's heading followed by the student's written content.
//

import Foundation
import UIKit

enum FieldReportExporter {

    static func makePDF(for trip: FieldTrip) -> URL? {
        let titleFont = UIFont.boldSystemFont(ofSize: 22)
        let subtitleFont = UIFont.systemFont(ofSize: 12)
        let headingFont = UIFont.boldSystemFont(ofSize: 14)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let emptyFont = UIFont.italicSystemFont(ofSize: 10)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let data = FieldPDFKit.render(title: "Fieldwork Report - \(trip.name)") { flow in
            flow.draw(trip.name, font: titleFont, extraSpacing: 6)
            if !trip.locationDescription.isEmpty {
                flow.draw(trip.locationDescription, font: subtitleFont, color: .darkGray)
            }
            flow.draw(dateFormatter.string(from: trip.date), font: subtitleFont, color: .darkGray, extraSpacing: 16)

            flow.drawDivider()

            for section in trip.reportOutline.sections {
                flow.ensureSpace(30)
                flow.draw(section.type.rawValue, font: headingFont, extraSpacing: 6)

                let trimmed = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    flow.draw("(Not yet written)", font: emptyFont, color: .gray, extraSpacing: 16)
                } else {
                    flow.draw(section.content, font: bodyFont, extraSpacing: 16)
                }
            }
        }

        return FieldPDFKit.writeTemporaryFile(
            data: data,
            filename: FieldPDFKit.sanitizedFilename(trip.name, fallback: "Fieldwork_Report") + "_Report.pdf"
        )
    }
}
