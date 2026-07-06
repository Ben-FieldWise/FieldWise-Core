//
//  FieldReportOutlineModels.swift
//  Student Fieldwork App
//
//  A guided write-up scaffold matching the standard geography fieldwork
//  report structure: Introduction, Geographic Characteristics, Method,
//  Presentation of Data, Analysis, Conclusion, Evaluation, Referencing.
//  One outline per trip. Each section carries placeholder guidance text
//  pulled from typical fieldwork report requirements so students know
//  what's expected without needing to look it up.
//

import Foundation

enum FieldReportSectionType: String, Codable, CaseIterable, Identifiable {
    case introduction = "Introduction"
    case geographicCharacteristics = "Geographic Characteristics of the Site"
    case method = "Method"
    case presentationOfData = "Presentation of Data"
    case analysisOfData = "Analysis of Data"
    case conclusion = "Conclusion"
    case evaluation = "Evaluation"
    case referencing = "Referencing"

    var id: String { rawValue }

    /// Guidance prompts shown as placeholder/help text for each section.
    var guidancePrompts: [String] {
        switch self {
        case .introduction:
            return [
                "State the aim of the fieldwork.",
                "State the research question.",
                "Briefly outline what the report will cover."
            ]
        case .geographicCharacteristics:
            return [
                "Describe the location of the site, supported by maps.",
                "Include a map showing the site in relation to the nearest city, and another showing it in relation to the state/country.",
                "Maps should be neatly presented and include BOLTSS (Border, Orientation, Legend, Title, Scale, Source).",
                "Describe the site: size, flora and fauna, history, formation, current use, and who manages it.",
                "Include an annotated photo to illustrate this section.",
                "Diagrams (if used) must have a title, clear labelling, and a source."
            ]
        case .method:
            return [
                "Describe the methods used to collect data in the field.",
                "Examples: taking photographs, drawing field sketches, completing surveys/questionnaires, taking measurements."
            ]
        case .presentationOfData:
            return [
                "Present the data collected at each site: summary tables, annotated photos, field sketches, graphs, etc.",
                "Identify which site each piece of data, photo, or sketch came from.",
                "Use a figure number for each photo/sketch/table so it can be referenced in the Analysis section."
            ]
        case .analysisOfData:
            return [
                "Describe and explain your results and data.",
                "Make specific reference to how humans have influenced each site: How is each site used? How is it managed? How much human impact has there been?",
                "Refer back to the research question.",
                "Reference specific figures, e.g. \"see Figure 1, The Natural Environment at Site 1\"."
            ]
        case .conclusion:
            return [
                "Sum up your findings in relation to the research question and aim.",
                "Note specific points learnt from the investigation.",
                "Refer back to the aim — has it been achieved?",
                "Note any patterns in the data."
            ]
        case .evaluation:
            return [
                "What did you enjoy / not enjoy about the fieldwork?",
                "What would you do differently if repeating this fieldwork?",
                "What other data could have been collected?",
                "Discuss how the fieldwork could be improved or modified in future."
            ]
        case .referencing:
            return [
                "Provide a correctly formatted list of references for all sources used."
            ]
        }
    }
}

struct FieldReportSection: Identifiable, Codable, Equatable {
    var id: UUID
    var type: FieldReportSectionType
    var content: String

    init(id: UUID = UUID(), type: FieldReportSectionType, content: String = "") {
        self.id = id
        self.type = type
        self.content = content
    }

    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

struct FieldReportOutline: Codable, Equatable {
    var sections: [FieldReportSection]

    init(sections: [FieldReportSection] = FieldReportOutline.defaultSections()) {
        self.sections = sections
    }

    static func defaultSections() -> [FieldReportSection] {
        FieldReportSectionType.allCases.map { FieldReportSection(type: $0) }
    }

    var totalWordCount: Int { sections.reduce(0) { $0 + $1.wordCount } }
    var sectionsWithContent: Int { sections.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
}
