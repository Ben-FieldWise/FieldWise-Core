import Foundation
import Combine

// MARK: - Plan Model

struct FieldworkPlan: Codable {
    var aim: String = ""
    var location: String = ""
    var fieldDate: Date? = nil
    var samplingStrategy: String = ""
    var backgroundResearch: String = ""
    var groupRoles: String = ""
    var anomalyLog: String = ""
    var emergencyContact1: String = ""
    var emergencyContact2: String = ""

    var permissions: Set<String> = []
    var equipment: Set<String> = []
    var dataMethods: Set<String> = []
    var safetyChecks: Set<String> = []
    var recordingFormats: Set<String> = []
    var postFieldwork: Set<String> = []
    var departureChecks: Set<String> = []

    var weatherRisk: RiskLevel = .notSet
    var terrainRisk: RiskLevel = .notSet
    var trafficRisk: RiskLevel = .notSet
    var waterRisk: RiskLevel = .notSet

    enum RiskLevel: String, Codable, CaseIterable {
        case notSet = "Not set"
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var color: String {
            switch self {
            case .notSet: return "GeoGray"
            case .low:    return "GeoGreen"
            case .medium: return "GeoAmber"
            case .high:   return "GeoCoral"
            }
        }
    }

    var completedSections: Int {
        var count = 0
        if !aim.isEmpty { count += 1 }
        if !equipment.isEmpty { count += 1 }
        if !dataMethods.isEmpty { count += 1 }
        if weatherRisk != .notSet { count += 1 }
        if !recordingFormats.isEmpty { count += 1 }
        if departureChecks.count >= 5 { count += 1 }
        return count
    }

    var readinessPercentage: Double {
        Double(completedSections) / 6.0
    }

    var hasHighRisk: Bool {
        [weatherRisk, terrainRisk, trafficRisk, waterRisk].contains(.high)
    }
}

// MARK: - Equipment Options

struct EquipmentCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let items: [String]
}

let equipmentCategories: [EquipmentCategory] = [
    EquipmentCategory(name: "Measuring tools", icon: "ruler", items: [
        "Tape measure", "Ranging poles", "Clinometer", "Flow meter",
        "pH meter", "Quadrat", "Thermometer", "Secchi disc"
    ]),
    EquipmentCategory(name: "Recording & navigation", icon: "ipad.landscape", items: [
        "Recording sheets", "Data logger", "Maps / OS", "GPS / smartphone",
        "Compass", "Camera / phone", "Clipboard & pens", "Waterproof covers"
    ]),
    EquipmentCategory(name: "Safety gear", icon: "cross.circle", items: [
        "Hi-vis vest", "First aid kit", "Whistle", "Waterproof clothing",
        "Good footwear", "Spare batteries", "Sunscreen / hat", "Water bottle"
    ])
]

// MARK: - Data Methods

struct DataMethod: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
}

let dataMethods: [DataMethod] = [
    DataMethod(name: "Measurements", description: "Width, depth, velocity, slope angle, pebble size", icon: "ruler.fill"),
    DataMethod(name: "Sketches & photos", description: "Field sketches, annotated photographs", icon: "pencil.and.outline"),
    DataMethod(name: "Counts & surveys", description: "Traffic, pedestrian counts, EQS", icon: "number.circle.fill"),
    DataMethod(name: "Questionnaires", description: "Opinions, interviews, local views", icon: "bubble.left.and.bubble.right.fill"),
    DataMethod(name: "Land use mapping", description: "Recording land use by area or transect", icon: "map.fill"),
    DataMethod(name: "Soil / water sampling", description: "Collecting soil or water samples", icon: "drop.fill"),
    DataMethod(name: "Biodiversity survey", description: "Quadrats or transects for species", icon: "leaf.fill")
]

// MARK: - Plan Store

class PlanStore: ObservableObject {
    @Published var plan: FieldworkPlan {
        didSet { save() }
    }

    private let key = "geofield_plan_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(FieldworkPlan.self, from: data) {
            self.plan = decoded
        } else {
            self.plan = FieldworkPlan()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        plan = FieldworkPlan()
    }
}
