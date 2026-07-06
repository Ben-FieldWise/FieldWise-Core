//
//  FieldChecklistExport.swift
//  Student Fieldwork App
//
//  Generates PDF and CSV exports of a FieldTrip checklist for sharing
//  or attaching to assessment submissions, plus a native share sheet wrapper.
//

import Foundation
import UIKit
import SwiftUI

enum FieldChecklistExporter {

    // MARK: - CSV Export

    static func makeCSV(for trip: FieldTrip) -> URL? {
        var rows: [String] = []
        rows.append("Trip,Location,Date,Category,Item,Detail,Checked,CheckedAt,Custom")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short

        for section in trip.sections {
            for item in section.items {
                let fields: [String] = [
                    csvEscape(trip.name),
                    csvEscape(trip.locationDescription),
                    csvEscape(dateFormatter.string(from: trip.date)),
                    csvEscape(section.category.rawValue),
                    csvEscape(item.title),
                    csvEscape(item.detail ?? ""),
                    item.isChecked ? "Yes" : "No",
                    csvEscape(item.checkedAt.map { timeFormatter.string(from: $0) } ?? ""),
                    item.isCustom ? "Yes" : "No",
                ]
                rows.append(fields.joined(separator: ","))
            }
        }

        let csvString = rows.joined(separator: "\n")
        return writeTemporaryFile(
            contents: csvString,
            filename: sanitizedFilename(for: trip) + ".csv"
        )
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - PDF Export

    static func makePDF(for trip: FieldTrip) -> URL? {
        let pageWidth: CGFloat = 612   // US Letter @ 72dpi
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        let pdfMetaData = [
            kCGPDFContextCreator: "Student Fieldwork App",
            kCGPDFContextTitle: "Field Data Checklist - \(trip.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let sectionFont = UIFont.boldSystemFont(ofSize: 14)
        let itemFont = UIFont.systemFont(ofSize: 11)
        let detailFont = UIFont.italicSystemFont(ofSize: 9)
        let footerFont = UIFont.systemFont(ofSize: 8)

        let data = renderer.pdfData { context in
            let contentWidth = pageWidth - margin * 2
            var y: CGFloat = margin
            var pageNumber = 1

            func newPage() {
                context.beginPage()
                y = margin
                pageNumber += 1
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    newPage()
                }
            }

            func draw(_ text: String, font: UIFont, color: UIColor = .black, x: CGFloat = margin, width: CGFloat = contentWidth) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let attributed = NSAttributedString(string: text, attributes: attrs)
                let bounding = attributed.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                ensureSpace(bounding.height + 4)
                attributed.draw(in: CGRect(x: x, y: y, width: width, height: bounding.height))
                return bounding.height
            }

            context.beginPage()

            // Title block
            y += draw("Field Data Collection Checklist", font: titleFont)
            y += 6
            y += draw(trip.name, font: subtitleFont, color: .darkGray)
            if !trip.locationDescription.isEmpty {
                y += draw("Location: \(trip.locationDescription)", font: subtitleFont, color: .darkGray)
            }
            y += draw("Date: \(dateFormatter.string(from: trip.date))", font: subtitleFont, color: .darkGray)
            let progressPct = Int(round(trip.overallProgress * 100))
            y += draw(
                "Overall completion: \(trip.completedItems)/\(trip.totalItems) items (\(progressPct)%)",
                font: subtitleFont, color: .darkGray
            )
            y += 14

            // Divider
            ensureSpace(2)
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: y))
            dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.lightGray.setStroke()
            dividerPath.lineWidth = 0.5
            dividerPath.stroke()
            y += 14

            for section in trip.sections {
                ensureSpace(24)
                y += draw(
                    "\(section.category.rawValue)  (\(section.completedCount)/\(section.totalCount))",
                    font: sectionFont
                )
                y += 4

                for item in section.items {
                    let box = item.isChecked ? "[x]" : "[ ]"
                    y += draw("\(box)  \(item.title)", font: itemFont)
                    if let detail = item.detail, !detail.isEmpty {
                        y += draw("      \(detail)", font: detailFont, color: .gray)
                    }
                    y += 2
                }
                y += 10
            }

            // Footer with page numbers - simple approach: stamp current page
            let footerText = "Generated by Student Fieldwork App"
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.gray]
            let footerString = NSAttributedString(string: footerText, attributes: footerAttrs)
            footerString.draw(at: CGPoint(x: margin, y: pageHeight - margin + 10))
        }

        return writeTemporaryFile(data: data, filename: sanitizedFilename(for: trip) + ".pdf")
    }

    // MARK: - File helpers

    private static func sanitizedFilename(for trip: FieldTrip) -> String {
        let raw = trip.name.isEmpty ? "Field_Checklist" : trip.name
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        let cleaned = raw.components(separatedBy: allowed.inverted).joined()
        let spaced = cleaned.replacingOccurrences(of: " ", with: "_")
        return spaced.isEmpty ? "Field_Checklist" : spaced
    }

    private static func writeTemporaryFile(contents: String, filename: String) -> URL? {
        guard let data = contents.data(using: .utf8) else { return nil }
        return writeTemporaryFile(data: data, filename: filename)
    }

    private static func writeTemporaryFile(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("FieldChecklistExporter write error: \(error)")
            return nil
        }
    }
}

// MARK: - Share Sheet wrapper (UIActivityViewController bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
