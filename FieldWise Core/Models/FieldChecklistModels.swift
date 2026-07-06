//
//  FieldChecklistModels.swift
//  Student Fieldwork App
//
//  Data models for the standalone Field Data Collection checklist.
//  Separate from the existing pre/on-site/post-fieldwork prep checklist.
//

import Foundation

// MARK: - Checklist Item

struct FieldChecklistItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var detail: String?
    var isChecked: Bool
    var isCustom: Bool          // true if added by the student, false if a default item
    var linkedObservationID: UUID?   // optional link to an ObservationEntry (existing recorder feature)
    var checkedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        isChecked: Bool = false,
        isCustom: Bool = false,
        linkedObservationID: UUID? = nil,
        checkedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isChecked = isChecked
        self.isCustom = isCustom
        self.linkedObservationID = linkedObservationID
        self.checkedAt = checkedAt
    }

    mutating func toggle() {
        isChecked.toggle()
        checkedAt = isChecked ? Date() : nil
    }
}

// MARK: - Section Category

enum FieldChecklistCategory: String, Codable, CaseIterable, Identifiable {
    case equipment = "Equipment & Tech"
    case siteLocation = "Site & Location Data"
    case physicalGeography = "Physical Geography Measurements"
    case humanGeography = "Human / Urban Geography Observations"
    case photosEvidence = "Photos & Visual Evidence"
    case safetyWelfare = "Safety & Welfare"
    case assessmentSpecific = "Assessment-Specific"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .equipment: return "backpack.fill"
        case .siteLocation: return "mappin.and.ellipse"
        case .physicalGeography: return "mountain.2.fill"
        case .humanGeography: return "building.2.fill"
        case .photosEvidence: return "camera.fill"
        case .safetyWelfare: return "cross.case.fill"
        case .assessmentSpecific: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Checklist Section

struct FieldChecklistSection: Identifiable, Codable, Equatable {
    var id: UUID
    var category: FieldChecklistCategory
    var items: [FieldChecklistItem]
    var isExpanded: Bool

    init(
        id: UUID = UUID(),
        category: FieldChecklistCategory,
        items: [FieldChecklistItem],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.category = category
        self.items = items
        self.isExpanded = isExpanded
    }

    var completedCount: Int { items.filter { $0.isChecked }.count }
    var totalCount: Int { items.count }
    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }
}

// MARK: - Trip (a single fieldwork outing, ties a checklist to history)

struct FieldTrip: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var locationDescription: String
    var date: Date
    var sections: [FieldChecklistSection]
    var surveyForms: [FieldSurveyForm]
    var reportOutline: FieldReportOutline
    var createdAt: Date
    var lastModifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        locationDescription: String = "",
        date: Date = Date(),
        sections: [FieldChecklistSection] = FieldTrip.defaultSections(),
        surveyForms: [FieldSurveyForm] = [],
        reportOutline: FieldReportOutline = FieldReportOutline(),
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.locationDescription = locationDescription
        self.date = date
        self.sections = sections
        self.surveyForms = surveyForms
        self.reportOutline = reportOutline
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
    }

    var totalItems: Int { sections.reduce(0) { $0 + $1.totalCount } }
    var completedItems: Int { sections.reduce(0) { $0 + $1.completedCount } }
    var overallProgress: Double {
        totalItems == 0 ? 0 : Double(completedItems) / Double(totalItems)
    }

    // MARK: Default item set across all four fieldwork domains

    static func defaultSections() -> [FieldChecklistSection] {
        [
            FieldChecklistSection(category: .equipment, items: [
                FieldChecklistItem(title: "Smartphone / GPS device charged"),
                FieldChecklistItem(title: "Field notebook & pencil/waterproof pen"),
                FieldChecklistItem(title: "Clipboard or hard backing for recording sheets"),
                FieldChecklistItem(title: "Camera (or phone camera checked & space available)"),
                FieldChecklistItem(title: "Measuring tape / trundle wheel"),
                FieldChecklistItem(title: "Compass"),
                FieldChecklistItem(title: "Spare batteries / power bank"),
                FieldChecklistItem(title: "Data collection sheets / recording app ready"),
            ]),
            FieldChecklistSection(category: .siteLocation, items: [
                FieldChecklistItem(title: "Site name / grid reference recorded"),
                FieldChecklistItem(title: "GPS coordinates logged"),
                FieldChecklistItem(title: "Date and time of visit noted"),
                FieldChecklistItem(title: "Weather conditions recorded"),
                FieldChecklistItem(title: "Site sketch map drawn"),
                FieldChecklistItem(title: "Land use / zoning noted"),
            ]),
            FieldChecklistSection(category: .physicalGeography, items: [
                FieldChecklistItem(title: "Temperature reading taken"),
                FieldChecklistItem(title: "Wind speed/direction noted"),
                FieldChecklistItem(title: "Slope angle measured (if relevant)"),
                FieldChecklistItem(title: "Soil sample / texture test completed"),
                FieldChecklistItem(title: "Vegetation cover estimated (% / type)"),
                FieldChecklistItem(title: "Water sample / river measurements (width, depth, velocity)"),
                FieldChecklistItem(title: "Geology / rock type identified"),
                FieldChecklistItem(title: "Erosion or hazard indicators noted"),
            ]),
            FieldChecklistSection(category: .humanGeography, items: [
                FieldChecklistItem(title: "Pedestrian/traffic count completed"),
                FieldChecklistItem(title: "Land use survey completed"),
                FieldChecklistItem(title: "Building height / condition survey"),
                FieldChecklistItem(title: "Environmental quality survey (litter, noise, etc.)"),
                FieldChecklistItem(title: "Questionnaire / interview responses collected"),
                FieldChecklistItem(title: "Bipolar survey completed"),
                FieldChecklistItem(title: "Accessibility / walkability notes taken"),
            ]),
            FieldChecklistSection(category: .photosEvidence, items: [
                FieldChecklistItem(title: "Wide establishing shot of site"),
                FieldChecklistItem(title: "Close-up evidence photos taken"),
                FieldChecklistItem(title: "Photos labelled with location/time"),
                FieldChecklistItem(title: "Annotated photo / field sketch completed"),
                FieldChecklistItem(title: "Consent obtained for any photos with people"),
            ]),
            FieldChecklistSection(category: .safetyWelfare, items: [
                FieldChecklistItem(title: "Risk assessment reviewed on site"),
                FieldChecklistItem(title: "Group check-in / buddy system confirmed"),
                FieldChecklistItem(title: "Emergency contact accessible"),
                FieldChecklistItem(title: "First aid kit accessible"),
                FieldChecklistItem(title: "Appropriate footwear / PPE worn"),
                FieldChecklistItem(title: "Hydration / sun protection sorted"),
            ]),
            FieldChecklistSection(category: .assessmentSpecific, items: [
                FieldChecklistItem(title: "Add items specific to this assessment task", isCustom: true),
            ]),
        ]
    }
}
