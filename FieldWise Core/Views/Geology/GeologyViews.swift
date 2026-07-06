import SwiftUI

// MARK: - Geology Root

struct GeologyRootView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Rocks").tag(0)
                    Text("Soils").tag(1)
                    Text("Landforms").tag(2)
                    Text("Tests").tag(3)
                    Text("Impact").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("GeoSurface"))

                ScrollView {
                    VStack(spacing: 12) {
                        switch selectedTab {
                        case 0: RockTypesView()
                        case 1: SoilTypesView()
                        case 2: LandformsView()
                        case 3: FieldTestsView()
                        case 4: HumanImpactView()
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 20)
                }
                .background(Color("GeoSurface"))
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Landscapes")
            .navigationBarTitleDisplayMode(.large)
            .helpButton()
        }
    }
}

// MARK: - Rocks

struct RockTypesView: View {
    var body: some View {
        ForEach(rockTypes) { rock in
            RockTypeCard(rock: rock)
        }
    }
}

struct RockTypeCard: View {
    let rock: RockType

    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(rock.swatchColor)
                            .frame(width: 44, height: 44)
                        Image(systemName: rock.iconName)
                            .foregroundColor(rock.accentColor)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rock.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(rock.textColor)
                        Text(rock.hardness)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Text(rock.formation)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Examples")
                    FlowLayout(spacing: 6) {
                        ForEach(rock.examples, id: \.self) { example in
                            Text(example)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(rock.swatchColor)
                                .foregroundColor(rock.textColor)
                                .clipShape(Capsule())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Fieldwork clues")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(rock.fieldworkClues, id: \.self) { clue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundColor(rock.accentColor)
                                    .padding(.top, 6)
                                Text(clue)
                                    .font(.system(size: 13))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Soils

struct SoilTypesView: View {
    var body: some View {
        RibbonBallTestCard()
        ForEach(soilTypes) { soil in
            SoilTypeCard(soil: soil)
        }
        OrganicContentCard()
    }
}

struct RibbonBallTestCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color("GeoBlue").opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "scope")
                        .foregroundColor(Color("GeoBlue"))
                        .font(.system(size: 15, weight: .semibold))
                }
                Text("Ribbon and ball test")
                    .font(.system(size: 16, weight: .semibold))
                BadgeView(text: "New", backgroundColor: Color("GeoBlue").opacity(0.15), foregroundColor: Color("GeoBlue"))
                Spacer()
            }
            Text("Moisten a small handful of soil and squeeze it into a ball, then try to push it out flat between thumb and finger into a ribbon.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(ribbonBallResults.enumerated()), id: \.element.id) { index, result in
                    HStack {
                        Circle()
                            .fill(Color("GeoBlue"))
                            .frame(width: 6, height: 6)
                        Text(result.observation)
                            .font(.system(size: 13))
                        Spacer()
                        Text(result.result)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.vertical, 8)
                    if index < ribbonBallResults.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color("GeoBlue").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color("GeoBlue").opacity(0.3), lineWidth: 1)
        )
    }
}

struct OrganicContentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color("GeoAmber").opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundColor(Color("GeoAmberDark"))
                        .font(.system(size: 15, weight: .semibold))
                }
                Text("Organic content by colour")
                    .font(.system(size: 16, weight: .semibold))
                BadgeView(text: "New", backgroundColor: Color("GeoBlue").opacity(0.15), foregroundColor: Color("GeoBlue"))
                Spacer()
            }
            Text("Compare a moist sample against a reference card. Darker soils generally hold more organic matter and nutrients.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(organicContentSwatches) { swatch in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(swatch.color)
                            .frame(height: 40)
                        VStack(spacing: 1) {
                            Text(swatch.label)
                                .font(.system(size: 11, weight: .semibold))
                            Text(swatch.detail)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color("GeoAmber").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color("GeoAmber").opacity(0.4), lineWidth: 1)
        )
    }
}

struct SoilTypeCard: View {
    let soil: SoilType

    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(soil.dotColor)
                        .frame(width: 18, height: 18)
                    Text(soil.name)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SoilDetailRow(label: "Feel", value: soil.feel)
                    SoilDetailRow(label: "pH tendency", value: soil.phTendency)
                    SoilDetailRow(label: "Common locations", value: soil.commonLocations)
                }

                VStack(spacing: 8) {
                    SoilRatingRow(label: "Drainage", note: soil.drainage, rating: soil.drainageRating, tint: Color("GeoBlue"))
                    SoilRatingRow(label: "Nutrients", note: soil.nutrients, rating: soil.nutrientRating, tint: Color("GeoGreen"))
                }
            }
        }
    }
}

struct SoilDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

struct SoilRatingRow: View {
    let label: String
    let note: String
    let rating: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(note)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < rating ? tint : tint.opacity(0.15))
                        .frame(height: 6)
                }
            }
        }
    }
}

// MARK: - Field tests

struct FieldTestsView: View {
    var rockTests: [FieldTest] { fieldTests.filter { $0.category == .rock } }
    var soilTests: [FieldTest] { fieldTests.filter { $0.category == .soil } }
    var siteTests: [FieldTest] { fieldTests.filter { $0.category == .siteAndSlope } }

    var body: some View {
        FieldTestSection(title: "Rock identification", icon: "mountain.2.fill", tests: rockTests)
        FieldTestSection(title: "Soil identification", icon: "leaf.fill", tests: soilTests)
        FieldTestSection(title: "Site and slope", icon: "location.north.line", tests: siteTests)
    }
}

struct FieldTestSection: View {
    let title: String
    let icon: String
    let tests: [FieldTest]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(tests) { test in
                    FieldTestCard(test: test)
                }
            }
        }
    }
}

struct FieldTestCard: View {
    let test: FieldTest

    var body: some View {
        GeoCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color("GeoGreen").opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: test.iconName)
                        .foregroundColor(Color("GeoGreen"))
                        .font(.system(size: 17, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(test.title)
                            .font(.system(size: 15, weight: .semibold))
                        if test.isNew {
                            BadgeView(text: "New", backgroundColor: Color("GeoBlue").opacity(0.15), foregroundColor: Color("GeoBlue"))
                        }
                    }
                    Text(test.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Landforms

struct LandformsView: View {
    var weathering: [LandformProcess] { landformProcesses.filter { $0.category == .weathering } }
    var erosion: [LandformProcess] { landformProcesses.filter { $0.category == .erosion } }
    var massMovement: [LandformProcess] { landformProcesses.filter { $0.category == .massMovement } }

    var body: some View {
        LandformSection(title: LandformProcess.ProcessCategory.weathering.rawValue, icon: "thermometer.snowflake", processes: weathering, accentColors: [Color("GeoCoral"), Color("GeoBlue"), Color("GeoGreen")])
        LandformSection(title: LandformProcess.ProcessCategory.erosion.rawValue, icon: "wind", processes: erosion, accentColors: [Color("GeoBlue"), Color("GeoAmberDark")])
        LandformSection(title: LandformProcess.ProcessCategory.massMovement.rawValue, icon: "exclamationmark.triangle.fill", processes: massMovement, accentColors: [Color("GeoGreenMid"), Color("GeoCoral")])
        SlopeAspectCard()
    }
}

struct LandformSection: View {
    let title: String
    let icon: String
    let processes: [LandformProcess]
    let accentColors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                    LandformProcessCard(process: process, accentColor: accentColors[index % accentColors.count])
                }
            }
        }
    }
}

struct LandformProcessCard: View {
    let process: LandformProcess
    let accentColor: Color

    var body: some View {
        GeoCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: process.iconName)
                        .foregroundColor(accentColor)
                        .font(.system(size: 17, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(process.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct SlopeAspectCard: View {
    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(SlopeAspectInfo.title, systemImage: SlopeAspectInfo.iconName)
                    .font(.system(size: 15, weight: .semibold))
                Text(SlopeAspectInfo.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(SlopeAspectInfo.paceMethodNote)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("GeoSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// MARK: - Human Impact

struct HumanImpactView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Soil degradation", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(Array(soilDegradationIssues.enumerated()), id: \.element.id) { index, issue in
                    SoilDegradationCard(issue: issue, accentColor: [Color("GeoBlue"), Color("GeoAmberDark"), Color("GeoCoral")][index % 3])
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            Label("Management strategies", systemImage: "shield.lefthalf.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(managementStrategyGroups) { group in
                    ManagementStrategyCard(group: group)
                }
            }
        }
    }
}

struct SoilDegradationCard: View {
    let issue: SoilDegradationIssue
    let accentColor: Color

    var body: some View {
        GeoCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: issue.iconName)
                        .foregroundColor(accentColor)
                        .font(.system(size: 17, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(issue.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct ManagementStrategyCard: View {
    let group: ManagementStrategyGroup

    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(group.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: group.iconName)
                            .foregroundColor(group.accentColor)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(group.title)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                FlowLayout(spacing: 8) {
                    ForEach(group.strategies, id: \.self) { strategy in
                        Text(strategy)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(group.accentColor.opacity(0.15))
                            .foregroundColor(group.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

#Preview {
    GeologyRootView()
}
