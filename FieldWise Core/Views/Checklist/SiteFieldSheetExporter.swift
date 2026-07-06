//
//  SiteFieldSheetExporter.swift
//  Student Fieldwork App
//
//  Exports a SiteFieldSheet (single site) or a whole FieldSheetTrip
//  (all sites) to PDF, reusing the shared FieldPDFKit drawing helper.
//  Embeds photo thumbnails inline so the exported sheet is genuinely
//  useful as an assessment attachment, not just a text dump.
//

import Foundation
import UIKit

enum SiteFieldSheetExporter {

    // MARK: - Single site PDF

    static func makePDF(for sheet: SiteFieldSheet, trip: FieldSheetTrip, store: SiteFieldSheetStore) -> URL? {
        let data = FieldPDFKit.render(title: "Site Field Sheet - \(sheet.siteName)") { flow in
            drawSiteSheet(sheet, trip: trip, store: store, flow: flow)
        }
        return FieldPDFKit.writeTemporaryFile(
            data: data,
            filename: FieldPDFKit.sanitizedFilename(sheet.siteName, fallback: "Site_Field_Sheet") + ".pdf"
        )
    }

    // MARK: - Whole trip PDF (one section per site)

    static func makeTripPDF(for trip: FieldSheetTrip, store: SiteFieldSheetStore) -> URL? {
        let data = FieldPDFKit.render(title: "Field Sheets - \(trip.name)") { flow in
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let subtitleFont = UIFont.systemFont(ofSize: 12)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long

            flow.draw(trip.name, font: titleFont, extraSpacing: 6)
            if !trip.locationDescription.isEmpty {
                flow.draw(trip.locationDescription, font: subtitleFont, color: .darkGray)
            }
            flow.draw(dateFormatter.string(from: trip.date), font: subtitleFont, color: .darkGray, extraSpacing: 10)
            flow.draw("\(trip.siteSheets.count) site(s) recorded", font: subtitleFont, color: .darkGray, extraSpacing: 14)

            for (index, sheet) in trip.siteSheets.enumerated() {
                if index > 0 { flow.newPage() }
                drawSiteSheet(sheet, trip: trip, store: store, flow: flow)
            }
        }
        return FieldPDFKit.writeTemporaryFile(
            data: data,
            filename: FieldPDFKit.sanitizedFilename(trip.name, fallback: "Field_Sheets") + "_AllSites.pdf"
        )
    }

    // MARK: - Shared drawing

    private static func drawSiteSheet(_ sheet: SiteFieldSheet, trip: FieldSheetTrip, store: SiteFieldSheetStore, flow: FieldPDFFlow) {
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let subtitleFont = UIFont.systemFont(ofSize: 11)
        let headerLabelFont = UIFont.boldSystemFont(ofSize: 10)
        let sectionFont = UIFont.boldSystemFont(ofSize: 14)
        let itemFont = UIFont.systemFont(ofSize: 11)
        let detailFont = UIFont.italicSystemFont(ofSize: 9)
        let groupFont = UIFont.boldSystemFont(ofSize: 12)
        let termFont = UIFont.systemFont(ofSize: 10)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        // Header
        flow.draw(sheet.siteName, font: titleFont, extraSpacing: 6)
        flow.draw(trip.name, font: subtitleFont, color: .darkGray)
        if !sheet.siteNumber.isEmpty {
            flow.draw("Site number: \(sheet.siteNumber)", font: headerLabelFont, extraSpacing: 2)
        }
        if !sheet.gridReference.isEmpty {
            flow.draw("Grid reference: \(sheet.gridReference)", font: headerLabelFont, extraSpacing: 2)
        }
        if !sheet.weatherSummary.isEmpty {
            flow.draw("Weather: \(sheet.weatherSummary)", font: headerLabelFont, extraSpacing: 2)
        }
        flow.draw("Date: \(dateFormatter.string(from: sheet.dateVisited))", font: headerLabelFont, extraSpacing: 8)
        flow.drawDivider()

        // Site overview photos
        if !sheet.sitePhotos.isEmpty {
            flow.draw("Site overview photos", font: sectionFont, extraSpacing: 4)
            drawPhotoRow(sheet.sitePhotos, store: store, flow: flow)
            flow.addSpace(8)
        }

        // Checklist sections
        for section in sheet.sections {
            flow.ensureSpace(24)
            flow.draw("\(section.title)  (\(section.completedCount)/\(section.totalCount))", font: sectionFont, extraSpacing: 4)

            for item in section.items {
                let box = item.isCompleted ? "[x]" : "[ ]"
                flow.draw("\(box)  \(item.title)", font: itemFont, extraSpacing: 2)
                if !item.detail.isEmpty {
                    flow.draw("      \(item.detail)", font: detailFont, color: .gray, extraSpacing: 2)
                }
                if !item.notes.isEmpty {
                    flow.draw("      Notes: \(item.notes)", font: detailFont, color: .darkGray, extraSpacing: 2)
                }
                if !item.photos.isEmpty {
                    drawPhotoRow(item.photos, store: store, flow: flow)
                }
                flow.addSpace(2)
            }
            flow.addSpace(8)
        }

        // Geography / geology observation groups
        flow.drawDivider()
        flow.draw("Geography & geology observations", font: sectionFont, extraSpacing: 6)
        for group in sheet.observationGroups where group.checkedCount > 0 {
            flow.ensureSpace(20)
            flow.draw("\(group.title)  (\(group.checkedCount)/\(group.terms.count))", font: groupFont, extraSpacing: 2)
            let checkedTerms = group.terms.filter { $0.isChecked }
            let labels = checkedTerms.map { $0.label }.joined(separator: ", ")
            flow.draw(labels, font: termFont, extraSpacing: 2)
            for term in checkedTerms where !term.note.isEmpty {
                flow.draw("  \(term.label) — \(term.note)", font: detailFont, color: .darkGray, extraSpacing: 2)
            }
            if !group.groupNote.isEmpty {
                flow.draw("  Group note: \(group.groupNote)", font: detailFont, color: .darkGray, extraSpacing: 2)
            }
            flow.addSpace(6)
        }

        if !sheet.munsellSelections.isEmpty {
            flow.drawDivider()
            flow.draw("Soil colour (Munsell)", font: sectionFont, extraSpacing: 6)
            for selection in sheet.munsellSelections {
                flow.ensureSpace(16)
                let stars = String(repeating: "★", count: selection.qualityRating) + String(repeating: "☆", count: 5 - selection.qualityRating)
                let label = selection.name.isEmpty
                    ? "\(selection.notation)  \(stars)"
                    : "\(selection.name.capitalized) — \(selection.notation)  \(stars)"
                flow.draw(label, font: termFont, extraSpacing: 2)
                if !selection.note.isEmpty {
                    flow.draw("  \(selection.note)", font: detailFont, color: .darkGray, extraSpacing: 2)
                }
            }
            flow.addSpace(6)
        }

        if !sheet.overallNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            flow.drawDivider()
            flow.draw("Overall site notes", font: sectionFont, extraSpacing: 4)
            flow.draw(sheet.overallNotes, font: itemFont)
        }
    }

    /// Draws a row of small photo thumbnails (max 4 per row) inline in the PDF.
    private static func drawPhotoRow(_ photos: [FieldPhoto], store: SiteFieldSheetStore, flow: FieldPDFFlow) {
        let thumbSize: CGFloat = 70
        let spacing: CGFloat = 8
        let maxPerRow = 4
        let rows = photos.chunked(into: maxPerRow)

        for row in rows {
            flow.ensureSpace(thumbSize + spacing)
            let startY = flow.y
            var x = flow.margin
            for photo in row {
                if let image = store.loadImage(for: photo) {
                    let rect = CGRect(x: x, y: startY, width: thumbSize, height: thumbSize)
                    image.draw(in: rect)
                }
                x += thumbSize + spacing
            }
            flow.addSpace(thumbSize + spacing)
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
