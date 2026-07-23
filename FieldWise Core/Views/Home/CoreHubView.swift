import SwiftUI

// MARK: - Core hub catalogue

/// The Core dashboard uses the same searchable, category-based card language
/// as FieldWise Agriculture. Core remains the shared platform: it launches
/// subject apps and owns classes, activities, excursions, evidence and sync.
struct CoreHubView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var nav: AppNavigationCoordinator
    @Environment(\.openURL) private var openURL

    @State private var searchText = ""
    @State private var selectedCategory: CoreHubCategory?
    @State private var appLaunchError: FieldWiseStudentApp?
    @State private var returnedFromApp: String?

    private var modules: [CoreHubModule] {
        CoreHubCatalog.modules(for: authService.currentUserProfile?.role ?? .student)
    }

    private var filtered: [CoreHubModule] {
        modules.filter { module in
            let matchesCategory = selectedCategory == nil || module.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || module.title.localizedCaseInsensitiveContains(searchText)
                || module.subtitle.localizedCaseInsensitiveContains(searchText)
                || module.category.rawValue.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var visibleCategories: [CoreHubCategory] {
        CoreHubCategory.allCases.filter { category in
            filtered.contains(where: { $0.category == category })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    hero
                    categoryFilter

                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "No Core tools found",
                            systemImage: "magnifyingglass",
                            description: Text("Try another search or clear the category filter.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(visibleCategories) { category in
                            categorySection(category)
                        }
                    }
                }
                .padding()
            }
            .background(Color("GeoSurface").ignoresSafeArea())
            .navigationTitle("Core")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search Core, activities and apps")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("FieldWiseIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { authService.signOut() } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Sign out")
                }
            }
            .alert(item: $appLaunchError) { app in
                Alert(
                    title: Text("\(app.displayName) is not available"),
                    message: Text("Install the student app or confirm its URL scheme has been added to the target."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Returned to Core", isPresented: Binding(
                get: { returnedFromApp != nil },
                set: { if !$0 { returnedFromApp = nil } }
            )) {
                Button("OK", role: .cancel) { returnedFromApp = nil }
            } message: {
                Text(returnedFromApp ?? "The student app returned successfully.")
            }
            .onOpenURL { url in
                guard url.scheme == "fieldwisecore" else { return }
                let values = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let source = values.first(where: { $0.name == "sourceApp" })?.value ?? "student app"
                let activity = values.first(where: { $0.name == "activityTitle" })?.value ?? "the activity"
                returnedFromApp = "\(source) returned work for \(activity)."
            }
        }
        .tint(Color("BrandGreen"))
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("FieldWiseLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 245, alignment: .leading)

            Text(authService.currentUserProfile?.role == .teacher
                 ? "Plan, assign and review fieldwork"
                 : "Your fieldwork in one place")
                .font(.largeTitle.bold())

            Text(authService.currentUserProfile?.role == .teacher
                 ? "Manage classes and activities, then send students directly into Geography, History or Agriculture with their class context attached."
                 : "Open assigned work, launch the correct student app and bring evidence back into your FieldWise portfolio.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color("BrandGreen").opacity(0.12))
                .padding(14)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                categoryChip(title: "All", icon: "square.grid.2x2", category: nil)
                ForEach(CoreHubCategory.allCases) { category in
                    categoryChip(title: category.rawValue, icon: category.systemImage, category: category)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(title: String, icon: String, category: CoreHubCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .foregroundStyle(isSelected ? .white : Color("BrandGreen"))
                .background(isSelected ? Color("BrandGreen") : .white, in: Capsule())
                .overlay(Capsule().stroke(Color("BrandGreen").opacity(isSelected ? 0 : 0.24)))
        }
        .buttonStyle(.plain)
    }

    private func categorySection(_ category: CoreHubCategory) -> some View {
        let categoryModules = filtered.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(category.rawValue, systemImage: category.systemImage)
                    .font(.title3.bold())
                    .foregroundStyle(Color("GeoGreenDark"))
                Spacer()
                Text("\(categoryModules.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white, in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                ForEach(categoryModules) { module in
                    moduleButton(module)
                }
            }
        }
    }

    @ViewBuilder
    private func moduleButton(_ module: CoreHubModule) -> some View {
        switch module.action {
        case .destination(let destination):
            NavigationLink {
                destinationView(destination)
            } label: {
                CoreModuleCard(module: module)
            }
            .buttonStyle(.plain)
        case .tab(let tab):
            Button {
                nav.selectedTab = tab
            } label: {
                CoreModuleCard(module: module)
            }
            .buttonStyle(.plain)
        case .studentApp(let app):
            Button {
                launch(app)
            } label: {
                CoreModuleCard(module: module, subjectTint: app.tint)
            }
            .buttonStyle(.plain)
        }
    }

    private func launch(_ app: FieldWiseStudentApp) {
        guard let url = app.activityURL(
            activityID: "core-demo-activity",
            classID: "core-demo-class",
            studentID: authService.currentUserProfile?.id ?? "current-user",
            taskID: "task-1",
            activityTitle: "FieldWise Core Assignment"
        ) else {
            appLaunchError = app
            return
        }
        openURL(url) { accepted in
            if !accepted { appLaunchError = app }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: CoreDestination) -> some View {
        switch destination {
        case .dashboard: CoreHomeView()
        case .classes: ClassroomView()
        case .worksheets: WorksheetListView()
        case .sessions: AllSessionsView()
        case .joinSession: JoinSessionView()
        case .myWorksheets: MyWorksheetsView()
        case .excursions: PlanRootView()
        case .map: MapSectionView()
        case .evidence: FieldChecklistView()
        case .connectedApps: ConnectedStudentAppsView()
        case .syncCentre: CoreSyncCentreView()
        }
    }
}

private struct CoreModuleCard: View {
    let module: CoreHubModule
    var subjectTint: Color? = nil

    var body: some View {
        let tint = subjectTint ?? Color("BrandGreen")
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: module.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            Text(module.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(module.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.10)))
    }
}

// MARK: - Catalogue models

enum CoreHubCategory: String, CaseIterable, Identifiable {
    case activities = "Activities"
    case studentApps = "Student Apps"
    case fieldwork = "Fieldwork"
    case evidence = "Evidence & Portfolio"
    case classroom = "Classroom"
    case system = "System"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .activities: "rectangle.3.group.fill"
        case .studentApps: "square.grid.3x3.fill"
        case .fieldwork: "figure.hiking"
        case .evidence: "tray.full.fill"
        case .classroom: "person.2.fill"
        case .system: "gearshape.2.fill"
        }
    }
}

enum CoreDestination: Hashable {
    case dashboard, classes, worksheets, sessions, joinSession, myWorksheets
    case excursions, map, evidence, connectedApps, syncCentre
}

enum CoreModuleAction: Hashable {
    case destination(CoreDestination)
    case tab(AppTab)
    case studentApp(FieldWiseStudentApp)
}

struct CoreHubModule: Identifiable, Hashable {
    let id: String
    let category: CoreHubCategory
    let title: String
    let subtitle: String
    let systemImage: String
    let action: CoreModuleAction
}

enum FieldWiseStudentApp: String, CaseIterable, Identifiable, Hashable {
    case geography, history, agriculture

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .geography: "FieldWise Geography"
        case .history: "FieldWise History"
        case .agriculture: "FieldWise Agriculture"
        }
    }

    var scheme: String {
        switch self {
        case .geography: "fieldwisegeography"
        case .history: "fieldwisehistory"
        case .agriculture: "fieldwiseagriculture"
        }
    }

    var rootURL: URL? { URL(string: "\(scheme)://home") }

    func activityURL(
        activityID: String,
        classID: String,
        studentID: String,
        taskID: String,
        activityTitle: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "activity"
        components.path = "/\(activityID)"
        components.queryItems = [
            URLQueryItem(name: "classID", value: classID),
            URLQueryItem(name: "studentID", value: studentID),
            URLQueryItem(name: "taskID", value: taskID),
            URLQueryItem(name: "activityTitle", value: activityTitle),
            URLQueryItem(name: "returnToCore", value: "true")
        ]
        return components.url
    }

    var tint: Color {
        switch self {
        case .geography: Color("GeoBlue")
        case .history: Color("GeoCoral")
        case .agriculture: Color("GeoGreen")
        }
    }

    var icon: String {
        switch self {
        case .geography: "globe.asia.australia.fill"
        case .history: "building.columns.fill"
        case .agriculture: "leaf.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .geography: "Open maps, field tools, investigations and assigned Geography work."
        case .history: "Open sources, timelines, place investigations and assigned History work."
        case .agriculture: "Open farm tools, farm mapping, data and assigned Agriculture work."
        }
    }
}

enum CoreHubCatalog {
    static func modules(for role: UserRole) -> [CoreHubModule] {
        let result: [CoreHubModule] = [
            .init(id: "dashboard", category: .activities, title: "Activity Workspace", subtitle: "See current work, progress, instructions, feedback and submission status.", systemImage: "rectangle.3.group.fill", action: .tab(.activities)),
            .init(id: "worksheets", category: .activities, title: role == .teacher ? "Worksheets & Booklets" : "My Worksheets", subtitle: role == .teacher ? "Create reusable work and attach it to classes or excursions." : "Open worksheets and booklets assigned by your teacher.", systemImage: "square.and.pencil", action: .destination(role == .teacher ? .worksheets : .myWorksheets)),
            .init(id: "sessions", category: .activities, title: role == .teacher ? "Live Sessions" : "Join Session", subtitle: role == .teacher ? "Run live activities and review responses as students work." : "Join a teacher-led activity using its session code.", systemImage: "qrcode", action: .destination(role == .teacher ? .sessions : .joinSession)),

            .init(id: "geography", category: .studentApps, title: "Geography", subtitle: FieldWiseStudentApp.geography.subtitle, systemImage: FieldWiseStudentApp.geography.icon, action: .studentApp(.geography)),
            .init(id: "history", category: .studentApps, title: "History", subtitle: FieldWiseStudentApp.history.subtitle, systemImage: FieldWiseStudentApp.history.icon, action: .studentApp(.history)),
            .init(id: "agriculture", category: .studentApps, title: "Agriculture", subtitle: FieldWiseStudentApp.agriculture.subtitle, systemImage: FieldWiseStudentApp.agriculture.icon, action: .studentApp(.agriculture)),
            .init(id: "connected-apps", category: .studentApps, title: "Connected Apps", subtitle: "Check app links, launch each subject app and confirm integration readiness.", systemImage: "link.circle.fill", action: .destination(.connectedApps)),

            .init(id: "excursions", category: .fieldwork, title: "Excursions & Fieldwork", subtitle: "Plan sites, safety details, equipment, groups and station-based tasks.", systemImage: "figure.walk", action: .tab(.excursions)),
            .init(id: "map", category: .fieldwork, title: "Shared Fieldwork Map", subtitle: "View class sites, meeting points, hazards and evidence locations.", systemImage: "map.fill", action: .destination(.map)),

            .init(id: "evidence", category: .evidence, title: "Evidence Workspace", subtitle: "Collect, review and export notes, photos, forms and reports.", systemImage: "doc.text.fill", action: .destination(.evidence)),
            .init(id: "portfolio", category: .evidence, title: "Student Portfolio", subtitle: "Bring evidence from Geography, History and Agriculture into one record.", systemImage: "person.crop.rectangle.stack.fill", action: .destination(.evidence)),

            .init(id: "classes", category: .classroom, title: "Classes", subtitle: role == .teacher ? "Create classes, share join codes and review student membership." : "View your class and teacher-assigned work.", systemImage: "person.2.fill", action: .tab(.classes)),
            .init(id: "review", category: .classroom, title: role == .teacher ? "Review Student Work" : "Teacher Feedback", subtitle: role == .teacher ? "Check submissions, provide feedback and return work for changes." : "See feedback and work that needs changes.", systemImage: "checklist", action: .tab(.classes)),

            .init(id: "sync", category: .system, title: "Sync Centre", subtitle: "Check offline work, pending uploads and the last successful sync.", systemImage: "arrow.triangle.2.circlepath.circle.fill", action: .destination(.syncCentre))
        ]
        return result
    }
}

// MARK: - Connected apps and sync

struct ConnectedStudentAppsView: View {
    @Environment(\.openURL) private var openURL
    @State private var statuses: [FieldWiseStudentApp: Bool] = [:]

    var body: some View {
        List {
            Section("Student apps") {
                ForEach(FieldWiseStudentApp.allCases) { app in
                    HStack(spacing: 14) {
                        Image(systemName: app.icon)
                            .font(.title2)
                            .foregroundStyle(app.tint)
                            .frame(width: 42, height: 42)
                            .background(app.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.displayName).font(.headline)
                            Text(statuses[app] == true ? "Link ready" : "Tap Test Link to check")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Test Link") {
                            guard let url = app.activityURL(
                                activityID: "integration-test",
                                classID: "test-class",
                                studentID: "test-student",
                                taskID: "test-task",
                                activityTitle: "Connected App Test"
                            ) else { return }
                            openURL(url) { statuses[app] = $0 }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("How integration works") {
                Label("Core owns sign-in, classes and assignments", systemImage: "person.badge.key.fill")
                Label("The subject app opens for specialist fieldwork", systemImage: "arrow.up.forward.app.fill")
                Label("Evidence returns to the Core portfolio", systemImage: "tray.and.arrow.down.fill")
            }
        }
        .navigationTitle("Connected Apps")
    }
}

struct CoreSyncCentreView: View {
    @State private var pendingCount = 0
    @State private var isSyncing = false

    var body: some View {
        List {
            Section("Current status") {
                LabeledContent("Pending uploads", value: "\(pendingCount)")
                LabeledContent("Connection", value: "Ready")
            }
            Section {
                Button {
                    Task {
                        isSyncing = true
                        await EntrySync.shared.flush()
                        pendingCount = await EntrySync.shared.pendingCount()
                        isSyncing = false
                    }
                } label: {
                    HStack {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isSyncing { ProgressView() }
                    }
                }
                .disabled(isSyncing)
            }
        }
        .navigationTitle("Sync Centre")
        .task { pendingCount = await EntrySync.shared.pendingCount() }
    }
}
