import SwiftUI

struct PlanRootView: View {
    @EnvironmentObject var store: PlanStore
    @State private var currentStep = 0
    private let totalSteps = 6

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Progress header
                    VStack(spacing: 10) {
                        HStack {
                            Text("\(store.plan.completedSections) of 6 sections complete")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(store.plan.readinessPercentage * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color("GeoGreen"))
                        }
                        GeoProgressBar(value: store.plan.readinessPercentage)
                        StepDotsView(total: totalSteps, current: currentStep)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // Step content
                    Group {
                        switch currentStep {
                        case 0: PlanStep0View(onNext: { currentStep = 1 })
                        case 1: PlanStep1View(onBack: { currentStep = 0 }, onNext: { currentStep = 2 })
                        case 2: PlanStep2View(onBack: { currentStep = 1 }, onNext: { currentStep = 3 })
                        case 3: PlanStep3View(onBack: { currentStep = 2 }, onNext: { currentStep = 4 })
                        case 4: PlanStep4View(onBack: { currentStep = 3 }, onNext: { currentStep = 5 })
                        case 5: PlanStep5View(onBack: { currentStep = 4 })
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Fieldwork Plan")
            .navigationBarTitleDisplayMode(.large)
            .helpButton()
        }
    }
}

// MARK: - Step 0: Aims & Location

struct PlanStep0View: View {
    @EnvironmentObject var store: PlanStore
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            GeoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Aims & location", systemImage: "scope")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Research aim / hypothesis")
                        GeoTextField(placeholder: "e.g. How does river velocity change downstream?",
                                     text: $store.plan.aim, axis: .vertical)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Study location / site")
                        GeoTextField(placeholder: "e.g. River Wye, Herefordshire",
                                     text: $store.plan.location)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Fieldwork date")
                        DatePicker("", selection: Binding(
                            get: { store.plan.fieldDate ?? Date() },
                            set: { store.plan.fieldDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Sampling strategy")
                        Picker("Strategy", selection: $store.plan.samplingStrategy) {
                            Text("Select strategy…").tag("")
                            Text("Random sampling").tag("Random sampling")
                            Text("Systematic sampling").tag("Systematic sampling")
                            Text("Stratified sampling").tag("Stratified sampling")
                            Text("Opportunistic / convenience").tag("Opportunistic / convenience")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color("GeoSurface"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            GeoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Background research", systemImage: "book.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    GeoTextField(placeholder: "Maps, secondary data, theory reviewed, OS sources…",
                                 text: $store.plan.backgroundResearch, axis: .vertical)

                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Permissions obtained")
                        VStack(spacing: 8) {
                            ForEach(["Landowner / site manager permission",
                                     "School / university approval",
                                     "Parental consent (if under 18)"], id: \.self) { item in
                                CheckRow(text: item,
                                         isChecked: Binding(
                                            get: { store.plan.permissions.contains(item) },
                                            set: { if $0 { store.plan.permissions.insert(item) } else { store.plan.permissions.remove(item) } }
                                         ))
                            }
                        }
                    }
                }
            }

            PrimaryButton(title: "Equipment", iconName: "arrow.right", action: onNext)
        }
    }
}

// MARK: - Step 1: Equipment

struct PlanStep1View: View {
    @EnvironmentObject var store: PlanStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(equipmentCategories) { category in
                GeoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(category.name, systemImage: category.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(category.items, id: \.self) { item in
                                ChipToggle(label: item,
                                           isSelected: Binding(
                                            get: { store.plan.equipment.contains(item) },
                                            set: { if $0 { store.plan.equipment.insert(item) } else { store.plan.equipment.remove(item) } }
                                           ))
                            }
                        }
                    }
                }
            }
            NavRow(onBack: onBack, nextTitle: "Data methods", onNext: onNext)
        }
    }
}

// MARK: - Step 2: Data Methods

struct PlanStep2View: View {
    @EnvironmentObject var store: PlanStore
    let onBack: () -> Void
    let onNext: () -> Void

    var columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            GeoCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Primary data methods", systemImage: "cylinder.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(dataMethods) { method in
                            let selected = store.plan.dataMethods.contains(method.name)
                            Button(action: {
                                if selected { store.plan.dataMethods.remove(method.name) }
                                else { store.plan.dataMethods.insert(method.name) }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: method.icon)
                                            .font(.system(size: 13))
                                        Text(method.name)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    Text(method.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(selected ? Color("GeoBlue").opacity(0.8) : .secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(selected ? Color("GeoBlue").opacity(0.1) : Color("GeoSurface"))
                                .foregroundColor(selected ? Color("GeoBlue") : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(selected ? Color("GeoBlue") : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: selected)
                        }
                    }
                }
            }

            GeoCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Group roles", systemImage: "person.3.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    GeoTextField(placeholder: "e.g. Jamie — flow meter; Sara — recording sheet…",
                                 text: $store.plan.groupRoles, axis: .vertical)
                }
            }

            NavRow(onBack: onBack, nextTitle: "Safety", onNext: onNext)
        }
    }
}

// MARK: - Step 3: Safety

struct PlanStep3View: View {
    @EnvironmentObject var store: PlanStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            GeoCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Risk assessment", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        RiskLevelPicker(label: "Weather risk", level: $store.plan.weatherRisk)
                        RiskLevelPicker(label: "Terrain / physical", level: $store.plan.terrainRisk)
                        RiskLevelPicker(label: "Traffic / road", level: $store.plan.trafficRisk)
                        RiskLevelPicker(label: "Water / flooding", level: $store.plan.waterRisk)
                    }
                }
            }

            GeoCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Emergency contacts", systemImage: "phone.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Teacher / supervisor")
                        GeoTextField(placeholder: "Name & phone number", text: $store.plan.emergencyContact1)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Nearest hospital / local area")
                        GeoTextField(placeholder: "e.g. Hereford County Hospital", text: $store.plan.emergencyContact2)
                    }
                }
            }

            GeoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Safety & ethics", systemImage: "lock.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    let items = [
                        "Working in pairs / groups — never alone",
                        "Following risk assessment at all times",
                        "Leave no trace — respect the environment",
                        "Participant anonymity maintained in surveys",
                        "Respectful to local people and communities",
                        "No damage to site or ecosystem"
                    ]
                    VStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            CheckRow(text: item,
                                     isChecked: Binding(
                                        get: { store.plan.safetyChecks.contains(item) },
                                        set: { if $0 { store.plan.safetyChecks.insert(item) } else { store.plan.safetyChecks.remove(item) } }
                                     ))
                        }
                    }
                }
            }

            NavRow(onBack: onBack, nextTitle: "Recording", onNext: onNext)
        }
    }
}

// MARK: - Step 4: Recording

struct PlanStep4View: View {
    @EnvironmentObject var store: PlanStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            GeoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Recording formats", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    let formats = ["Accurate, neat data tables", "Annotated photographs", "Field sketches and diagrams", "Audio / video notes"]
                    VStack(spacing: 8) {
                        ForEach(formats, id: \.self) { item in
                            CheckRow(text: item,
                                     isChecked: Binding(
                                        get: { store.plan.recordingFormats.contains(item) },
                                        set: { if $0 { store.plan.recordingFormats.insert(item) } else { store.plan.recordingFormats.remove(item) } }
                                     ))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color("GeoAmber"))
                    Text("Anomaly & problem log")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("GeoAmberDark"))
                }
                GeoTextField(placeholder: "Note any issues on the day — e.g. heavy rain before measurements, equipment malfunction…",
                             text: $store.plan.anomalyLog, axis: .vertical)
            }
            .padding(14)
            .background(Color(red: 1.0, green: 0.98, blue: 0.93))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color("GeoAmber").opacity(0.5), lineWidth: 1)
            )

            GeoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Post-fieldwork plan", systemImage: "chart.bar.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    let items = ["Graphs and charts to be produced", "Statistical analysis planned", "Analysis linked back to aim / theory", "Evaluation of methodology planned"]
                    VStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            CheckRow(text: item,
                                     isChecked: Binding(
                                        get: { store.plan.postFieldwork.contains(item) },
                                        set: { if $0 { store.plan.postFieldwork.insert(item) } else { store.plan.postFieldwork.remove(item) } }
                                     ))
                        }
                    }
                }
            }

            NavRow(onBack: onBack, nextTitle: "Final checklist", onNext: onNext)
        }
    }
}

// MARK: - Step 5: Departure Checklist + Summary

struct PlanStep5View: View {
    @EnvironmentObject var store: PlanStore
    let onBack: () -> Void
    @State private var showSummary = false

    let items = [
        "Aim clearly written and understood by group",
        "Risk assessment completed and signed off",
        "All equipment packed including spares",
        "Weather forecast checked — conditions suitable",
        "Permission obtained (school / parental)",
        "Transport and meeting point confirmed",
        "Emergency contacts shared with group"
    ]

    var body: some View {
        VStack(spacing: 12) {
            GeoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Before you go", systemImage: "checklist")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            CheckRow(text: item,
                                     isChecked: Binding(
                                        get: { store.plan.departureChecks.contains(item) },
                                        set: { if $0 { store.plan.departureChecks.insert(item) } else { store.plan.departureChecks.remove(item) } }
                                     ))
                        }
                    }
                }
            }

            PrimaryButton(title: "Generate readiness summary", iconName: "doc.badge.checkmark") {
                withAnimation { showSummary = true }
            }

            if showSummary {
                PlanSummaryView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button(action: onBack) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("GeoGreenDark"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color("GeoSurface"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
            }
        }
    }
}

// MARK: - Summary

struct PlanSummaryView: View {
    @EnvironmentObject var store: PlanStore

    var overallStatus: (String, Color) {
        let done = store.plan.completedSections
        if done >= 5 { return ("Ready to go", Color("GeoGreen")) }
        if done >= 3 { return ("In progress", Color("GeoAmber")) }
        return ("Needs attention", Color("GeoCoral")) 
    }

    var body: some View {
        VStack(spacing: 10) {
            summaryCard(title: "Planning overview", icon: "clipboard") {
                summaryRow("Aim", value: store.plan.aim.isEmpty ? "—" : store.plan.aim)
                summaryRow("Location", value: store.plan.location.isEmpty ? "—" : store.plan.location)
                summaryRow("Sampling", value: store.plan.samplingStrategy.isEmpty ? "—" : store.plan.samplingStrategy)
                if let date = store.plan.fieldDate {
                    summaryRow("Date", value: date.formatted(date: .abbreviated, time: .omitted))
                }
            }
            summaryCard(title: "Methods & equipment", icon: "cylinder") {
                summaryRow("Methods selected", value: store.plan.dataMethods.isEmpty ? "—" : "\(store.plan.dataMethods.count) selected")
                summaryRow("Equipment items", value: "\(store.plan.equipment.count) checked")
            }
            summaryCard(title: "Readiness", icon: "shield.checkered") {
                HStack {
                    Text("Risk level").foregroundColor(.secondary)
                    Spacer()
                    BadgeView(text: store.plan.hasHighRisk ? "High — review" : "Acceptable",
                              backgroundColor: store.plan.hasHighRisk ? Color("GeoCoral").opacity(0.15) : Color("GeoGreen").opacity(0.15),
                              foregroundColor: store.plan.hasHighRisk ? Color("GeoCoral") : Color("GeoGreen"))
                }
                .font(.system(size: 14))
                HStack {
                    Text("Departure checks").foregroundColor(.secondary)
                    Spacer()
                    BadgeView(text: "\(store.plan.departureChecks.count)/7 complete",
                              backgroundColor: store.plan.departureChecks.count >= 7 ? Color("GeoGreen").opacity(0.15) : Color("GeoAmber").opacity(0.15),
                              foregroundColor: store.plan.departureChecks.count >= 7 ? Color("GeoGreen") : Color("GeoAmberDark"))
                }
                .font(.system(size: 14))
                HStack {
                    Text("Overall readiness").foregroundColor(.secondary)
                    Spacer()
                    BadgeView(text: overallStatus.0,
                              backgroundColor: overallStatus.1.opacity(0.15),
                              foregroundColor: overallStatus.1)
                }
                .font(.system(size: 14))
            }
        }
    }

    private func summaryCard<Content: View>(title: String, icon: String, @ViewBuilder rows: () -> Content) -> some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Divider()
                rows()
            }
        }
    }

    private func summaryRow(_ key: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing).frame(maxWidth: 200, alignment: .trailing)
        }
        .font(.system(size: 14))
    }
}

// MARK: - NavRow

struct NavRow: View {
    let onBack: () -> Void
    let nextTitle: String
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(Color("GeoSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
            }
            .foregroundColor(Color("GeoGreenDark"))

            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text(nextTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color("GeoGreen"))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rowX = bounds.minX
        var rowY = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowX + size.width > bounds.maxX, rowX > bounds.minX {
                rowY += rowHeight + spacing
                rowX = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: rowX, y: rowY), proposal: ProposedViewSize(size))
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
