//
//  SiteFieldSheetModel.swift
//  Student Fieldwork App
//
//  Self-contained model for the interactive Site Field Sheet — a per-site
//  data collection form for students on a fieldtrip. Independent of
//  FieldChecklistStore / FieldTrip so it doesn't depend on (or risk
//  breaking) the existing checklist, survey, or report models.
//
//  Persists as JSON via FileManager, consistent with the rest of the app.
//  Photos are saved as separate JPEG files on disk (referenced by filename)
//  rather than embedded as base64 in the JSON, to keep the JSON small and
//  fast to encode/decode.
//

import Foundation
import SwiftUI

// MARK: - Photo Attachment

/// A single photo attached to a checklist item or a site as a whole.
/// `fileName` points to a JPEG stored in the app's Documents/SiteFieldPhotos
/// directory — only the filename (not a full path) is persisted, since the
/// container path can change between launches.
struct FieldPhoto: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fileName: String
    var caption: String = ""
    var takenAt: Date = Date()
}

// MARK: - Geography Observation Categories

/// One selectable term within a category (e.g. "Granite" within "Rock type").
struct GeoTerm: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var label: String
    var isChecked: Bool = false
    var note: String = ""
}

/// A group of related checkable terms, e.g. "Rock type", "Soil texture".
/// `icon` is a verified SF Symbol name.
struct GeoObservationGroup: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var terms: [GeoTerm]
    /// Free-text note for the group as a whole (e.g. "mostly outcrop on north face").
    var groupNote: String = ""

    var checkedCount: Int { terms.filter { $0.isChecked }.count }
}

/// Builds the default fixed set of geography/geology observation groups
/// covering common GCSE / VCE-level fieldwork categories: rock type,
/// weathering, soil, vegetation, slope/land use, and human/management
/// features. Each new site sheet starts with a fresh copy of this set.
enum GeoObservationCatalog {

    static func defaultGroups() -> [GeoObservationGroup] {
        [
            GeoObservationGroup(
                title: "Rock type",
                icon: "mountain.2.fill",
                terms: termList([
                    "Granite", "Basalt", "Sandstone", "Limestone", "Shale",
                    "Conglomerate", "Slate", "Schist", "Quartzite", "Marble"
                ])
            ),
            GeoObservationGroup(
                title: "Rock characteristics",
                icon: "square.grid.3x3.fill",
                terms: termList([
                    "Layered / bedded", "Crystalline", "Fine-grained", "Coarse-grained",
                    "Vesicular (holes/bubbles)", "Foliated (banded)", "Fossils visible",
                    "Jointed / fractured", "Folded", "Faulted"
                ])
            ),
            GeoObservationGroup(
                title: "Weathering & erosion",
                icon: "wind",
                terms: termList([
                    "Mechanical (freeze-thaw)", "Chemical (dissolution)", "Biological (roots/lichen)",
                    "Exfoliation / flaking", "Honeycomb weathering", "Wind abrasion",
                    "Water erosion / rilling", "Rockfall debris present"
                ])
            ),
            GeoObservationGroup(
                title: "Soil type",
                icon: "leaf.fill",
                terms: termList([
                    "Sandy", "Clay", "Loam", "Silty", "Peaty", "Chalky / calcareous", "Rocky / skeletal"
                ])
            ),
            GeoObservationGroup(
                title: "Soil characteristics",
                icon: "circle.grid.cross.fill",
                terms: termList([
                    "Well-drained", "Waterlogged", "Compacted", "Loose / friable",
                    "Dark, organic-rich", "Pale, leached", "Visible root mat",
                    "Erosion / bare patches"
                ])
            ),
            GeoObservationGroup(
                title: "Vegetation",
                icon: "tree.fill",
                terms: termList([
                    "Native eucalypt / forest", "Grassland", "Shrubland / scrub",
                    "Ferns / understory", "Moss / lichen on rock", "Cleared / grazed land",
                    "Introduced / weed species", "Regenerating growth"
                ])
            ),
            GeoObservationGroup(
                title: "Slope & land use",
                icon: "arrow.up.right",
                terms: termList([
                    "Flat / level", "Gentle slope", "Steep slope", "Cliff / rock face",
                    "Cultivated / farmland", "Residential", "Recreation / parkland",
                    "Conservation / protected area"
                ])
            ),
            GeoObservationGroup(
                title: "Human & management features",
                icon: "hammer.fill",
                terms: termList([
                    "Formed path / boardwalk", "Steps", "Signage / interpretation",
                    "Fencing", "Erosion control matting", "Litter / vandalism",
                    "Visitor facilities (seats, toilets)", "Evidence of restoration planting"
                ])
            ),
        ]
    }

    private static func termList(_ labels: [String]) -> [GeoTerm] {
        labels.map { GeoTerm(label: $0) }
    }
}

// MARK: - Field Sheet Checklist Item (with photo gallery)

/// A single line item on the field sheet's data-collection checklist —
/// analogous to FieldChecklistItem but with its own photo gallery
/// (multiple photos per item, e.g. 3-5 shots of the same outcrop).
struct SiteSheetItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var detail: String = ""
    var isCompleted: Bool = false
    var notes: String = ""
    var photos: [FieldPhoto] = []
    var isCustom: Bool = false
}

/// A named section of the field sheet (mirrors the existing checklist's
/// section/category pattern) containing several SiteSheetItems.
struct SiteSheetSection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var items: [SiteSheetItem]
    var isExpanded: Bool = true

    var completedCount: Int { items.filter { $0.isCompleted }.count }
    var totalCount: Int { items.count }
}

enum SiteSheetCatalog {
    /// Default data-collection checklist sections for a new site sheet.
    static func defaultSections() -> [SiteSheetSection] {
        [
            SiteSheetSection(
                title: "Site overview",
                icon: "mappin.and.ellipse",
                items: [
                    SiteSheetItem(title: "Wide establishing photo of the site", detail: "Capture the full outcrop / landform from a fixed point"),
                    SiteSheetItem(title: "Grid reference / GPS coordinates recorded"),
                    SiteSheetItem(title: "Compass bearing / orientation noted"),
                ]
            ),
            SiteSheetSection(
                title: "Rock & landform sample",
                icon: "mountain.2.fill",
                items: [
                    SiteSheetItem(title: "Close-up photo of rock sample", detail: "Include a scale object (coin, ruler) in frame"),
                    SiteSheetItem(title: "Rock sample sketch with labels"),
                    SiteSheetItem(title: "Hardness / scratch test recorded"),
                ]
            ),
            SiteSheetSection(
                title: "Soil sample",
                icon: "leaf.fill",
                items: [
                    SiteSheetItem(title: "Soil profile photo"),
                    SiteSheetItem(title: "Soil texture (ribbon/feel) test recorded"),
                    SiteSheetItem(title: "Soil depth / horizon notes"),
                ]
            ),
            SiteSheetSection(
                title: "Human impact",
                icon: "person.2.fill",
                items: [
                    SiteSheetItem(title: "Photo of management feature (path, sign, fencing)"),
                    SiteSheetItem(title: "Evidence of visitor impact recorded (litter, erosion, graffiti)"),
                ]
            ),
        ]
    }
}

// MARK: - Site Field Sheet

/// One complete field sheet for a single site visited on a fieldtrip.
/// A FieldSheetTrip (below) holds one or more of these.
struct SiteFieldSheet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var siteName: String
    var siteNumber: String = ""
    var gridReference: String = ""
    var dateVisited: Date = Date()
    var weatherSummary: String = ""

    var sections: [SiteSheetSection] = SiteSheetCatalog.defaultSections()
    var observationGroups: [GeoObservationGroup] = GeoObservationCatalog.defaultGroups()

    /// Munsell soil colour matches recorded for this site (one site can
    /// have multiple — e.g. topsoil vs subsoil horizon).
    var munsellSelections: [MunsellSelection] = []

    /// Photos attached to the site as a whole (not tied to a specific item).
    var sitePhotos: [FieldPhoto] = []
    var overallNotes: String = ""

    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()

    // MARK: Derived progress

    var totalChecklistItems: Int { sections.reduce(0) { $0 + $1.items.count } }
    var completedChecklistItems: Int { sections.reduce(0) { $0 + $1.items.filter { $0.isCompleted }.count } }
    var checklistProgress: Double {
        totalChecklistItems == 0 ? 0 : Double(completedChecklistItems) / Double(totalChecklistItems)
    }

    var totalObservationTerms: Int { observationGroups.reduce(0) { $0 + $1.terms.count } }
    var checkedObservationTerms: Int { observationGroups.reduce(0) { $0 + $1.checkedCount } }

    var totalPhotoCount: Int {
        sitePhotos.count + sections.reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.photos.count } }
    }
}

// MARK: - Field Sheet Trip (container for multiple site sheets)

/// A fieldtrip containing one SiteFieldSheet per site visited, matching
/// the "Hanging Rock — 5 sites, whole day" style of fieldtrip structure.
struct FieldSheetTrip: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var locationDescription: String = ""
    var date: Date = Date()
    var siteSheets: [SiteFieldSheet] = []
    var createdAt: Date = Date()
    var lastModifiedAt: Date = Date()
}
