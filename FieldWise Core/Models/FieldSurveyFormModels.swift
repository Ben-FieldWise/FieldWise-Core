//
//  FieldSurveyFormModels.swift
//  Student Fieldwork App
//
//  Data models for the structured per-site Survey Form (header fields,
//  editable grid groups, checkbox terms with an "Other – please describe"
//  row, and overall notes). Mirrors the paper survey sheet the in-app
//  form is modelled on.
//

import Foundation

// MARK: - Header (top of the survey sheet)

struct FieldSurveyHeader: Codable, Equatable {
    var surveyorName: String
    var contactInfo: String
    var siteOwnerOrManager: String
    var siteOwnerContact: String
    var mapCodeOrGridRef: String
    var siteNumber: String
    var siteName: String
    var areaOrRegion: String

    init(
        surveyorName: String = "",
        contactInfo: String = "",
        siteOwnerOrManager: String = "",
        siteOwnerContact: String = "",
        mapCodeOrGridRef: String = "",
        siteNumber: String = "",
        siteName: String = "",
        areaOrRegion: String = ""
    ) {
        self.surveyorName = surveyorName
        self.contactInfo = contactInfo
        self.siteOwnerOrManager = siteOwnerOrManager
        self.siteOwnerContact = siteOwnerContact
        self.mapCodeOrGridRef = mapCodeOrGridRef
        self.siteNumber = siteNumber
        self.siteName = siteName
        self.areaOrRegion = areaOrRegion
    }
}

// MARK: - Term (one checkbox row inside a grid group)

struct FieldSurveyTerm: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var isChecked: Bool
    var isOther: Bool
    var otherDescription: String

    init(
        id: UUID = UUID(),
        label: String,
        isChecked: Bool = false,
        isOther: Bool = false,
        otherDescription: String = ""
    ) {
        self.id = id
        self.label = label
        self.isChecked = isChecked
        self.isOther = isOther
        self.otherDescription = otherDescription
    }
}

// MARK: - Grid group (a titled cluster of terms, e.g. "Landscape / Physical Features")

struct FieldSurveyGridGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var terms: [FieldSurveyTerm]
    var photoTaken: Bool
    var photoReference: String
    var sectionNotes: String

    init(
        id: UUID = UUID(),
        title: String,
        terms: [FieldSurveyTerm] = [],
        photoTaken: Bool = false,
        photoReference: String = "",
        sectionNotes: String = ""
    ) {
        self.id = id
        self.title = title
        self.terms = terms
        self.photoTaken = photoTaken
        self.photoReference = photoReference
        self.sectionNotes = sectionNotes
    }

    var checkedCount: Int { terms.filter { $0.isChecked }.count }
}

// MARK: - Survey form (one per site visit)

struct FieldSurveyForm: Identifiable, Codable, Equatable {
    var id: UUID
    var formTitle: String
    var header: FieldSurveyHeader
    var gridGroups: [FieldSurveyGridGroup]
    var overallNotes: String
    var createdAt: Date
    var lastModifiedAt: Date

    init(
        id: UUID = UUID(),
        formTitle: String = "Site Survey Form",
        header: FieldSurveyHeader = FieldSurveyHeader(),
        gridGroups: [FieldSurveyGridGroup] = FieldSurveyForm.defaultGridGroups(),
        overallNotes: String = "",
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date()
    ) {
        self.id = id
        self.formTitle = formTitle
        self.header = header
        self.gridGroups = gridGroups
        self.overallNotes = overallNotes
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
    }

    var totalTerms: Int { gridGroups.reduce(0) { $0 + $1.terms.count } }
    var totalChecked: Int { gridGroups.reduce(0) { $0 + $1.checkedCount } }

    // MARK: Default grid groups modelled on the paper survey sheet

    static func defaultGridGroups() -> [FieldSurveyGridGroup] {
        [
            FieldSurveyGridGroup(title: "Landscape / Physical Features", terms: [
                FieldSurveyTerm(label: "Hill / slope"),
                FieldSurveyTerm(label: "Valley / gully"),
                FieldSurveyTerm(label: "River / stream"),
                FieldSurveyTerm(label: "Coast / shoreline"),
                FieldSurveyTerm(label: "Wetland / marsh"),
                FieldSurveyTerm(label: "Other", isOther: true),
            ]),
            FieldSurveyGridGroup(title: "Vegetation", terms: [
                FieldSurveyTerm(label: "Grassland"),
                FieldSurveyTerm(label: "Shrubs / scrub"),
                FieldSurveyTerm(label: "Trees / woodland"),
                FieldSurveyTerm(label: "Cultivated / crops"),
                FieldSurveyTerm(label: "Bare ground"),
                FieldSurveyTerm(label: "Other", isOther: true),
            ]),
            FieldSurveyGridGroup(title: "Land Use", terms: [
                FieldSurveyTerm(label: "Residential"),
                FieldSurveyTerm(label: "Commercial / retail"),
                FieldSurveyTerm(label: "Industrial"),
                FieldSurveyTerm(label: "Agricultural"),
                FieldSurveyTerm(label: "Recreational / open space"),
                FieldSurveyTerm(label: "Other", isOther: true),
            ]),
            FieldSurveyGridGroup(title: "Built Environment", terms: [
                FieldSurveyTerm(label: "Roads / paths"),
                FieldSurveyTerm(label: "Buildings"),
                FieldSurveyTerm(label: "Fences / walls"),
                FieldSurveyTerm(label: "Signage"),
                FieldSurveyTerm(label: "Street furniture"),
                FieldSurveyTerm(label: "Other", isOther: true),
            ]),
            FieldSurveyGridGroup(title: "Human Impact", terms: [
                FieldSurveyTerm(label: "Litter"),
                FieldSurveyTerm(label: "Graffiti / vandalism"),
                FieldSurveyTerm(label: "Erosion / damage"),
                FieldSurveyTerm(label: "Pollution (air / water / noise)"),
                FieldSurveyTerm(label: "Management / maintenance evidence"),
                FieldSurveyTerm(label: "Other", isOther: true),
            ]),
        ]
    }
}
