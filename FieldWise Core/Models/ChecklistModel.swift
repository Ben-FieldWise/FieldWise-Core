import Foundation

// MARK: - Checklist Item

struct ChecklistItem: Identifiable, Codable {
    let id: String
    let text: String
    var isChecked: Bool = false
}

struct ChecklistSection: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let items: [ChecklistItem]
}

let masterChecklist: [ChecklistSection] = [
    ChecklistSection(
        title: "Before you leave home",
        iconName: "sun.max.fill",
        items: [
            ChecklistItem(id: "pre_1", text: "Aim / hypothesis clearly written"),
            ChecklistItem(id: "pre_2", text: "Risk assessment completed and signed off"),
            ChecklistItem(id: "pre_3", text: "Equipment packed — spare batteries & pens"),
            ChecklistItem(id: "pre_4", text: "Weather forecast checked — conditions suitable"),
            ChecklistItem(id: "pre_5", text: "Permission obtained (school / parental)"),
            ChecklistItem(id: "pre_6", text: "Transport and meeting point confirmed"),
            ChecklistItem(id: "pre_7", text: "Emergency contact shared with group")
        ]
    ),
    ChecklistSection(
        title: "On site",
        iconName: "mappin.circle.fill",
        items: [
            ChecklistItem(id: "site_1", text: "Working in pairs / groups — never alone"),
            ChecklistItem(id: "site_2", text: "Hi-vis / safety gear being worn"),
            ChecklistItem(id: "site_3", text: "Recording sheets / data logger ready"),
            ChecklistItem(id: "site_4", text: "Sampling strategy agreed by group"),
            ChecklistItem(id: "site_5", text: "Photos being taken with annotations"),
            ChecklistItem(id: "site_6", text: "Anomalies and problems being recorded")
        ]
    ),
    ChecklistSection(
        title: "Back at base",
        iconName: "house.fill",
        items: [
            ChecklistItem(id: "post_1", text: "Data entered into graphs / charts"),
            ChecklistItem(id: "post_2", text: "Analysis explains patterns, linked to theory"),
            ChecklistItem(id: "post_3", text: "Evaluation written (strengths, limitations)"),
            ChecklistItem(id: "post_4", text: "Conclusion links back to original aim")
        ]
    )
]
