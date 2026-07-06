//
//  MunsellSoilColorModel.swift
//  Student Fieldwork App
//
//  Munsell soil colour reference data and picker model, used by the
//  Site Field Sheet's "Soil colour" section (sits after "Soil
//  characteristics", before "Vegetation" in the observation groups list).
//
//  All 12 charts now use real swatch data derived from the official
//  Munsell Soil Color Charts (2009 revision / 1994 manual + 2010-2013
//  production scans) via the standard Munsell renotation system.
//  10R, 2.5YR, 5YR, 7.5YR, 10YR, and 2.5Y were sampled directly from
//  chart reference pages; 5R, 7.5R, 5Y, the 10Y-5GY "Olive Greens"
//  chart, and both Gley charts were derived from the renotation tables
//  using each chart's official value/chroma grid and printed colour
//  names. No placeholder charts remain.
//

import Foundation
import SwiftUI

// MARK: - Single Swatch

/// One Munsell notation cell: Hue (implied by the chart it belongs to),
/// Value (lightness, 2.5–8) and Chroma (saturation, 1–8).
struct MunsellSwatch: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(hueTag ?? "")\(value)/\(chroma)" }
    let value: String   // e.g. "5", "2.5"
    let chroma: String  // e.g. "1", "4", "8"
    let hex: String     // sampled or placeholder sRGB hex
    let name: String    // printed Munsell colour name, e.g. "yellowish brown"
    var context: String? = nil  // typical fieldwork context, e.g. "Common topsoils"
    /// Set when a single chart mixes codes from multiple hue families
    /// (e.g. the common-soils quick reference) so `id` stays unique.
    /// Charts with one hue per page can leave this nil.
    var hueTag: String? = nil

    var color: Color { Color(hex: hex) }

    /// Full Munsell notation for a given chart, e.g. "10YR 5/4".
    func notation(hue: String) -> String { "\(hueTag ?? hue) \(value)/\(chroma)" }
}

// MARK: - Chart (one hue page)

struct MunsellChart: Identifiable {
    var id: String { hue }
    let hue: String              // e.g. "10R", "2.5YR", "Gley 1"
    let displayName: String      // shown in the picker, e.g. "Munsell 10R Soil Chart"
    let swatches: [MunsellSwatch]
    /// True if this chart's swatches are provisional / not yet verified
    /// against an official chart. No charts currently set this — kept on
    /// the struct in case a chart is added later before its data is fully
    /// confirmed, since the picker view checks this flag to surface a
    /// "Provisional" notice.
    let isPlaceholder: Bool
    /// True only for the special "no Munsell name shown" reference page.
    let suppressesNameInUI: Bool
    /// True for reference charts where each entry has a distinct
    /// description (and usually a context note) rather than being part
    /// of a dense regular value/chroma grid — shown as a readable list
    /// instead of small grid cells. Currently just the common-soils chart.
    let usesListLayout: Bool

    init(hue: String, displayName: String, swatches: [MunsellSwatch], isPlaceholder: Bool = false, suppressesNameInUI: Bool = false, usesListLayout: Bool = false) {
        self.hue = hue
        self.displayName = displayName
        self.swatches = swatches
        self.isPlaceholder = isPlaceholder
        self.suppressesNameInUI = suppressesNameInUI
        self.usesListLayout = usesListLayout
    }
}

// MARK: - The student's saved selection

/// What actually gets stored on the field sheet when a student picks a
/// swatch. The Munsell code is always retained internally — even for the
/// "no name shown" chart — since it's the universally recognised
/// reference notation; only the *name* is hidden from that one chart's UI.
struct MunsellSelection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var chartHue: String        // which chart it came from, e.g. "10YR"
    var value: String
    var chroma: String
    var hex: String
    var name: String            // may be empty for the no-name chart
    var qualityRating: Int = 0  // 1-5 "how confident / how good a match" rating
    var note: String = ""
    var selectedAt: Date = Date()

    var notation: String { "\(chartHue) \(value)/\(chroma)" }
}

// MARK: - Chart Catalog

enum MunsellSoilColorCatalog {

    /// All charts in the exact order requested, ready for the nested
    /// dropdown-within-dropdown picker. The common-soils quick reference
    /// sits first since it's the fastest lookup for the colours students
    /// actually encounter most often in the field.
    static var allCharts: [MunsellChart] {
        [
            chartCommonAustralianSoils,
            chart10R, chart10YR, chart2_5Y, chart2_5YR, chart5Y, chart5YR,
            chart7_5YR, chartOliveGreens, chartGley1, chartGley2,
            chart5R, chart7_5R, chartNoNamePage
        ]
    }

    // MARK: Verified charts (sampled from the supplied PDF)

    static let chart10R = MunsellChart(
        hue: "10R", displayName: "10R Soil Chart",
        swatches: SwatchData.tenR
    )

    static let chart2_5YR = MunsellChart(
        hue: "2.5YR", displayName: "2.5YR Soil Chart",
        swatches: SwatchData.twoPointFiveYR
    )

    static let chart5YR = MunsellChart(
        hue: "5YR", displayName: "5YR Soil Chart",
        swatches: SwatchData.fiveYR
    )

    static let chart7_5YR = MunsellChart(
        hue: "7.5YR", displayName: "7.5YR Soil Chart",
        swatches: SwatchData.sevenPointFiveYR
    )

    static let chart10YR = MunsellChart(
        hue: "10YR", displayName: "10YR Soil Chart",
        swatches: SwatchData.tenYR
    )

    static let chart2_5Y = MunsellChart(
        hue: "2.5Y", displayName: "2.5Y Soil Chart",
        swatches: SwatchData.twoPointFiveY
    )

    // MARK: Additional verified charts (5R, 7.5R, 5Y, Olive Greens, Gley 1, Gley 2)

    static let chart5Y = MunsellChart(
        hue: "5Y", displayName: "5Y Soil Chart",
        swatches: SwatchData.fiveY
    )

    static let chartOliveGreens = MunsellChart(
        hue: "10Y–5GY", displayName: "10Y – 5GY Colors – Olive Greens Soil Chart",
        swatches: SwatchData.oliveGreens
    )

    static let chartGley1 = MunsellChart(
        hue: "Gley 1", displayName: "Gley 1 Soil Chart",
        swatches: SwatchData.gley1
    )

    static let chartGley2 = MunsellChart(
        hue: "Gley 2", displayName: "Gley 2 Soil Chart",
        swatches: SwatchData.gley2
    )

    static let chart5R = MunsellChart(
        hue: "5R", displayName: "5R Individual Soil Chart",
        swatches: SwatchData.fiveR
    )

    static let chart7_5R = MunsellChart(
        hue: "7.5R", displayName: "7.5R Individual Soil Chart",
        swatches: SwatchData.sevenPointFiveR
    )

    // MARK: Special "no Munsell name shown" page
    // Combines White, 7.5R, 10YR, and 2.5Y swatches, but the UI never
    // displays the Munsell name/code to the student — just colour +
    // rating. The code is still retained internally on the selection.

    static let chartNoNamePage = MunsellChart(
        hue: "Mixed", displayName: "Quick Colour Match (no chart names)",
        swatches: SwatchData.tenR.filter { $0.value == "8" } // whites/pale tones as a stand-in "White Page" row
            + SwatchData.sevenPointFiveYR
            + SwatchData.tenYR
            + SwatchData.twoPointFiveY,
        suppressesNameInUI: true
    )

    // MARK: Common Australian soils quick reference
    // Curated set of the colour/code combinations students encounter
    // most often when sampling Australian soils. All hex values are
    // drawn directly from the corresponding full chart's real swatch
    // data above.

    static let chartCommonAustralianSoils = MunsellChart(
        hue: "AU Common", displayName: "Common Australian Soil Colours",
        swatches: SwatchData.commonAustralianSoils,
        usesListLayout: true
    )
}

// MARK: - Color(hex:) helper

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
