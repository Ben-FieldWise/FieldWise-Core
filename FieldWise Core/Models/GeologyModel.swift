import Foundation
import SwiftUI

// MARK: - Rock Types

struct RockType: Identifiable {
    let id = UUID()
    let name: String
    let formation: String
    let hardness: String
    let examples: [String]
    let fieldworkClues: [String]
    let iconName: String
    let swatchColor: Color
    let accentColor: Color
    let textColor: Color
}

let rockTypes: [RockType] = [
    RockType(
        name: "Igneous",
        formation: "Cooled from molten magma (intrusive) or lava at the surface (extrusive)",
        hardness: "Very hard — highly resistant to erosion",
        examples: ["Granite", "Basalt", "Obsidian", "Gabbro", "Rhyolite"],
        fieldworkClues: [
            "Crystalline texture — sparkly interlocking crystals",
            "No bedding planes or fossils",
            "Found in volcanic areas, mountain cores, tors",
            "Granite uplands — Dartmoor, Cairngorms",
            "Forms resistant features (tors, ridges)"
        ],
        iconName: "flame.fill",
        swatchColor: Color(red: 1.0, green: 0.95, blue: 0.8),
        accentColor: Color(red: 0.91, green: 0.77, blue: 0.41),
        textColor: Color(red: 0.4, green: 0.3, blue: 0.08)
    ),
    RockType(
        name: "Sedimentary",
        formation: "Layers of sediment compressed and cemented over millions of years",
        hardness: "Softer — erodes more easily. Common in rivers & coasts",
        examples: ["Sandstone", "Limestone", "Shale", "Chalk", "Mudstone", "Conglomerate"],
        fieldworkClues: [
            "Clearly layered / banded (bedding planes)",
            "May contain fossils",
            "Limestone fizzes with dilute HCl acid",
            "Common in river valleys, coastal cliffs, lowlands",
            "Limestone = karst scenery, caves, pavements"
        ],
        iconName: "square.3.layers.3d",
        swatchColor: Color(red: 0.85, green: 0.95, blue: 0.86),
        accentColor: Color(red: 0.32, green: 0.72, blue: 0.53),
        textColor: Color(red: 0.11, green: 0.26, blue: 0.2)
    ),
    RockType(
        name: "Metamorphic",
        formation: "Pre-existing rocks changed by intense heat and pressure deep in the crust",
        hardness: "Very hard — often shiny or folded",
        examples: ["Slate", "Marble", "Schist", "Gneiss", "Quartzite"],
        fieldworkClues: [
            "Foliated — layered or banded appearance",
            "Shiny, glittery surface (mica crystals in schist)",
            "May show folding or distortion",
            "Found near igneous intrusions and mountain belts",
            "No fossils — destroyed by heat and pressure"
        ],
        iconName: "arrow.up.arrow.down.circle.fill",
        swatchColor: Color(red: 0.93, green: 0.91, blue: 1.0),
        accentColor: Color(red: 0.49, green: 0.44, blue: 0.93),
        textColor: Color(red: 0.22, green: 0.19, blue: 0.61)
    )
]

// MARK: - Soil Types

struct SoilType: Identifiable {
    let id = UUID()
    let name: String
    let feel: String
    let drainage: String
    let drainageRating: Int  // 1-5 (5 = fast)
    let nutrients: String
    let nutrientRating: Int  // 1-5 (5 = high)
    let phTendency: String
    let commonLocations: String
    let dotColor: Color
}

let soilTypes: [SoilType] = [
    SoilType(name: "Sand", feel: "Gritty, coarse feel", drainage: "Very fast", drainageRating: 5, nutrients: "Low", nutrientRating: 1, phTendency: "Neutral–acidic", commonLocations: "Beaches, dunes, river banks", dotColor: Color(red: 0.94, green: 0.62, blue: 0.15)),
    SoilType(name: "Silt", feel: "Silky, floury when dry", drainage: "Moderate", drainageRating: 3, nutrients: "Medium", nutrientRating: 3, phTendency: "Neutral", commonLocations: "Floodplains, river deposits", dotColor: Color(red: 0.77, green: 0.72, blue: 0.63)),
    SoilType(name: "Clay", feel: "Sticky when wet, cracks when dry", drainage: "Very poor", drainageRating: 1, nutrients: "High", nutrientRating: 5, phTendency: "Neutral–alkaline", commonLocations: "Low-lying areas, floodplains", dotColor: Color(red: 0.53, green: 0.53, blue: 0.5)),
    SoilType(name: "Loam", feel: "Sand + silt + clay mix", drainage: "Good", drainageRating: 4, nutrients: "Good", nutrientRating: 4, phTendency: "Neutral", commonLocations: "Farmland, gardens", dotColor: Color(red: 0.59, green: 0.77, blue: 0.35)),
    SoilType(name: "Peat", feel: "Dark, spongy, organic-rich", drainage: "Very poor", drainageRating: 1, nutrients: "Low (acidic)", nutrientRating: 2, phTendency: "Acidic", commonLocations: "Wetlands, bogs, moorlands", dotColor: Color(red: 0.24, green: 0.17, blue: 0.12))
]

// MARK: - Landform Processes

struct LandformProcess: Identifiable {
    let id = UUID()
    let category: ProcessCategory
    let title: String
    let description: String
    let iconName: String

    enum ProcessCategory: String {
        case weathering = "Weathering"
        case erosion = "Erosion"
        case massMovement = "Mass movement"
    }
}

let landformProcesses: [LandformProcess] = [
    LandformProcess(category: .weathering, title: "Physical weathering", description: "Freeze-thaw cracks rock apart. Look for angular fragments at cliff bases (scree), or onion-skin peeling from heat.", iconName: "snowflake"),
    LandformProcess(category: .weathering, title: "Chemical weathering", description: "Acidic rain dissolves limestone, leaving smooth pitted surfaces. Rust-coloured staining shows oxidation of iron minerals.", iconName: "drop.fill"),
    LandformProcess(category: .weathering, title: "Biological weathering", description: "Roots in cracks widen them over time. Lichen on rock surfaces slowly breaks down the surface.", iconName: "leaf.fill"),
    LandformProcess(category: .erosion, title: "Hydraulic action", description: "Waves or river force compresses air in cracks, prising rock apart. Look for hollowed-out sections at cliff or bank bases.", iconName: "circle.dotted"),
    LandformProcess(category: .erosion, title: "Abrasion", description: "Sediment-carrying water or wind sandpapers rock smooth. Look for rounded pebbles and smoothed rock surfaces.", iconName: "wind"),
    LandformProcess(category: .massMovement, title: "Soil creep", description: "Very slow downhill movement. Look for trees or fence posts tilted downslope, and small step-like ridges (terracettes).", iconName: "arrow.down.left"),
    LandformProcess(category: .massMovement, title: "Slumping", description: "Sudden rotational slip on saturated cliffs. Look for a curved scar on the cliff face and debris piled at the base.", iconName: "arrow.down.right")
]

/// Slope and aspect sits as a standalone explainer card below the Mass
/// Movement process cards — it's a concept + technique rather than a
/// "spot this in the field" clue, so it's deliberately not in the array
/// above. The pace-method note is bundled inside this same card.
struct SlopeAspectInfo {
    static let title = "Slope and aspect"
    static let iconName = "location.north.line"
    static let description = "Aspect is the compass direction a slope faces. In the Southern Hemisphere, north-facing slopes get more direct sun, making soils warmer and drier. South-facing slopes stay cooler and moister."
    static let paceMethodNote = "Slope gradient: pace a measured distance upslope, estimate the height gained, then calculate rise over run."
}

// MARK: - Human Impact

struct SoilDegradationIssue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}

let soilDegradationIssues: [SoilDegradationIssue] = [
    SoilDegradationIssue(title: "Compaction", description: "Look for puddles or waterlogging on paths and trampled areas — water can no longer infiltrate the soil.", iconName: "arrow.down.to.line"),
    SoilDegradationIssue(title: "Sheet erosion", description: "Look for a thin, even loss of topsoil across a slope, often with exposed plant roots.", iconName: "wind"),
    SoilDegradationIssue(title: "Dryland salinity", description: "Look for white salt crust on the soil surface and dead or dying vegetation patches, common after land clearing in low-rainfall areas.", iconName: "square.fill")
]

struct ManagementStrategyGroup: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let strategies: [String]
    let accentColor: Color
}

let managementStrategyGroups: [ManagementStrategyGroup] = [
    ManagementStrategyGroup(title: "Coastal", iconName: "anchor", strategies: ["Seawalls", "Groynes", "Rock revetments", "Dune fencing"], accentColor: Color("GeoBlue")),
    ManagementStrategyGroup(title: "Riverine", iconName: "square.stack.3d.up.fill", strategies: ["Riprap", "Retaining walls", "Bank revegetation", "Levees"], accentColor: Color("GeoGreen")),
    ManagementStrategyGroup(title: "Agricultural land", iconName: "leaf.fill", strategies: ["Contour ploughing", "Crop rotation", "Windbreaks", "Controlled grazing"], accentColor: Color("GeoAmberDark"))
]

// MARK: - Organic content by colour (Soils tab addition)

struct OrganicContentSwatch: Identifiable {
    let id = UUID()
    let label: String
    let detail: String
    let color: Color
}

let organicContentSwatches: [OrganicContentSwatch] = [
    OrganicContentSwatch(label: "Very dark", detail: "High organic", color: Color(red: 0.13, green: 0.1, blue: 0.08)),
    OrganicContentSwatch(label: "Brown", detail: "Moderate", color: Color(red: 0.42, green: 0.27, blue: 0.16)),
    OrganicContentSwatch(label: "Red-orange", detail: "Iron-rich", color: Color(red: 0.72, green: 0.4, blue: 0.16)),
    OrganicContentSwatch(label: "Pale grey", detail: "Leached", color: Color(red: 0.78, green: 0.76, blue: 0.71))
]

// MARK: - Ribbon and ball test (shared by Soils + Field tests, different framing)

struct RibbonBallResult: Identifiable {
    let id = UUID()
    let observation: String
    let result: String
}

let ribbonBallResults: [RibbonBallResult] = [
    RibbonBallResult(observation: "Falls apart, no ball forms", result: "Sand"),
    RibbonBallResult(observation: "Ball holds, ribbon breaks <2cm", result: "Loam"),
    RibbonBallResult(observation: "Ribbon >5cm, shiny when smeared", result: "Clay")
]


struct FieldTest: Identifiable {
    let id = UUID()
    let category: TestCategory
    let title: String
    let description: String
    let iconName: String
    var isNew: Bool = false

    enum TestCategory: String {
        case rock = "Rock identification"
        case soil = "Soil identification"
        case siteAndSlope = "Site and slope"
    }
}

let fieldTests: [FieldTest] = [
    FieldTest(category: .rock, title: "Visual texture", description: "Large interlocking crystals = igneous. Fine grains or layers = sedimentary. Foliated / shiny = metamorphic.", iconName: "eye.fill"),
    FieldTest(category: .rock, title: "Hardness scratch test", description: "Use a knife (Mohs 5.5) or copper coin (Mohs 3). Granite: very hard. Limestone: medium. Shale: scratches easily.", iconName: "wrench.and.screwdriver.fill"),
    FieldTest(category: .rock, title: "Acid test (HCl)", description: "A drop of dilute hydrochloric acid on limestone fizzes (effervesces). No reaction on igneous or metamorphic rocks.", iconName: "drop.fill"),
    FieldTest(category: .rock, title: "Bedding planes", description: "Look for horizontal layers in sedimentary rock. Absent in igneous. Wavy foliation bands = metamorphic.", iconName: "rectangle.3.group.fill"),
    FieldTest(category: .rock, title: "Fossil search", description: "Fossils only exist in sedimentary rock — their presence immediately rules out igneous and metamorphic.", iconName: "magnifyingglass"),
    FieldTest(category: .soil, title: "Texture / feel test", description: "Rub moist soil between fingers. Gritty = sand. Silky/floury = silt. Sticky, smears ribbon = clay.", iconName: "hand.point.up.left.fill"),
    FieldTest(category: .soil, title: "Ribbon and ball test", description: "Moisten soil and squeeze into a ball, then push flat into a ribbon. No ball = sand. Short ribbon = loam. Long, shiny ribbon = clay.", iconName: "scope", isNew: true),
    FieldTest(category: .soil, title: "pH strips", description: "Mix soil with water, dip strip. Below 6 = acidic (peat/heath). 6–7 = neutral (loam). Above 7 = alkaline (clay, chalk).", iconName: "testtube.2"),
    FieldTest(category: .soil, title: "Colour assessment", description: "Dark brown/black = high organic content. Red/orange = iron-rich. Pale grey = leached / low fertility.", iconName: "paintpalette.fill"),
    FieldTest(category: .soil, title: "Infiltration rate", description: "Push a cylinder into soil, pour measured water, time absorption. Fast = sandy. Slow = clay. Compare across sites.", iconName: "timer"),
    FieldTest(category: .soil, title: "Soil profile pit", description: "Dig 30–50cm. Record horizons: O = organic litter, A = topsoil, B = subsoil, C = parent material.", iconName: "square.3.layers.3d.down.forward"),
    FieldTest(category: .siteAndSlope, title: "Slope gradient (pace method)", description: "Pace a measured distance upslope, estimate height gained against your own height, then calculate gradient as rise over run.", iconName: "flag.fill", isNew: true)
]
