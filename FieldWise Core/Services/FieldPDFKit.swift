//
//  FieldPDFKit.swift
//  Student Fieldwork App
//
//  Small shared helper for building paginated text PDFs with
//  UIGraphicsPDFRenderer. Used by FieldChecklistExporter, FieldSurveyExporter,
//  and FieldReportExporter so the pagination/text-flow logic lives in one
//  place instead of being copy-pasted across exporters.
//

import UIKit

/// A page-flow context handed to a drawing closure. Call `draw(...)` to lay
/// out text top-to-bottom; it automatically starts a new PDF page when the
/// current one runs out of room.
final class FieldPDFFlow {
    let context: UIGraphicsPDFRendererContext
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let margin: CGFloat
    var contentWidth: CGFloat { pageWidth - margin * 2 }
    private(set) var y: CGFloat

    init(context: UIGraphicsPDFRendererContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
        self.context = context
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.margin = margin
        self.y = margin
        context.beginPage()
    }

    func newPage() {
        context.beginPage()
        y = margin
    }

    func ensureSpace(_ needed: CGFloat) {
        if y + needed > pageHeight - margin {
            newPage()
        }
    }

    /// Draws left-aligned text at the current y position and advances y.
    /// Returns the height consumed.
    @discardableResult
    func draw(
        _ text: String,
        font: UIFont,
        color: UIColor = .black,
        x: CGFloat? = nil,
        width: CGFloat? = nil,
        extraSpacing: CGFloat = 4
    ) -> CGFloat {
        let drawX = x ?? margin
        let drawWidth = width ?? contentWidth
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let bounding = attributed.boundingRect(
            with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        ensureSpace(bounding.height + extraSpacing)
        attributed.draw(in: CGRect(x: drawX, y: y, width: drawWidth, height: bounding.height))
        y += bounding.height + extraSpacing
        return bounding.height
    }

    /// Draws a thin horizontal divider line and advances y.
    func drawDivider(spacingAfter: CGFloat = 14) {
        ensureSpace(2)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += spacingAfter
    }

    /// Adds blank vertical space.
    func addSpace(_ amount: CGFloat) {
        y += amount
    }
}

enum FieldPDFKit {
    static let pageWidth: CGFloat = 612   // US Letter @ 72dpi
    static let pageHeight: CGFloat = 792
    static let margin: CGFloat = 40

    static func render(title: String, draw: (FieldPDFFlow) -> Void) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator: "Student Fieldwork App",
            kCGPDFContextTitle: title
        ] as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        return renderer.pdfData { context in
            let flow = FieldPDFFlow(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            draw(flow)
        }
    }

    static func writeTemporaryFile(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("FieldPDFKit write error: \(error)")
            return nil
        }
    }

    static func writeTemporaryFile(contents: String, filename: String) -> URL? {
        guard let data = contents.data(using: .utf8) else { return nil }
        return writeTemporaryFile(data: data, filename: filename)
    }

    static func sanitizedFilename(_ raw: String, fallback: String = "Field_Export") -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        let cleaned = raw.components(separatedBy: allowed.inverted).joined()
        let spaced = cleaned.replacingOccurrences(of: " ", with: "_")
        return spaced.isEmpty ? fallback : spaced
    }
}
