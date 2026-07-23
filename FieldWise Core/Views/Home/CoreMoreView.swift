import SwiftUI

struct CoreActivitiesView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var searchText = ""
    @State private var selectedFilter: ActivityHubFilter = .all

    private var isTeacher: Bool { authService.currentUserProfile?.role == .teacher }

    private var cards: [ActivityHubCard] {
        let all: [ActivityHubCard] = isTeacher ? [
            .init(id: "create", title: "Create Activity", subtitle: "Build instructions, tasks, evidence requirements and curriculum links.", icon: "plus.rectangle.on.rectangle", filter: .create, destination: .worksheets),
            .init(id: "library", title: "Activity Library", subtitle: "Browse, edit, duplicate and organise reusable activities and booklets.", icon: "square.grid.2x2.fill", filter: .library, destination: .worksheets),
            .init(id: "sessions", title: "Assigned Sessions", subtitle: "Run live or scheduled sessions and see which classes are participating.", icon: "person.2.wave.2.fill", filter: .assigned, destination: .sessions),
            .init(id: "review", title: "Review Student Work", subtitle: "Check submissions, provide feedback and return work for changes.", icon: "checkmark.seal.fill", filter: .review, destination: .classes),
            .init(id: "fieldwork", title: "Fieldwork Activities", subtitle: "Plan activities that launch Geography, History or Agriculture tools.", icon: "figure.hiking", filter: .fieldwork, destination: .excursions),
            .init(id: "templates", title: "Templates", subtitle: "Start from ready-made investigation, excursion and assessment structures.", icon: "doc.on.doc.fill", filter: .library, destination: .worksheets)
        ] : [
            .init(id: "assigned", title: "Assigned Activities", subtitle: "Open activities assigned by your teacher and continue where you stopped.", icon: "rectangle.stack.fill", filter: .assigned, destination: .myWorksheets),
            .init(id: "join", title: "Join Activity", subtitle: "Enter a teacher-provided session code.", icon: "number.square.fill", filter: .assigned, destination: .joinSession),
            .init(id: "drafts", title: "Draft Work", subtitle: "Continue unfinished work stored on this device.", icon: "doc.text.fill", filter: .drafts, destination: .myWorksheets),
            .init(id: "feedback", title: "Teacher Feedback", subtitle: "Review comments and work returned for changes.", icon: "text.bubble.fill", filter: .review, destination: .myWorksheets)
        ]
        return all.filter { card in
            let matchesFilter = selectedFilter == .all || card.filter == selectedFilter
            let matchesSearch = searchText.isEmpty || card.title.localizedCaseInsensitiveContains(searchText) || card.subtitle.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CoreSectionHero(
                        title: isTeacher ? "Activities" : "My Activities",
                        subtitle: isTeacher
                            ? "Create, assign, launch and review learning across every FieldWise student app."
                            : "Open assigned work, continue drafts and review teacher feedback.",
                        icon: "rectangle.3.group.fill"
                    )

                    activitySummary
                    filterBar

                    if cards.isEmpty {
                        ContentUnavailableView("No activities found", systemImage: "magnifyingglass", description: Text("Try another search or filter."))
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                            ForEach(cards) { card in
                                NavigationLink {
                                    destinationView(card.destination)
                                } label: {
                                    CoreNavigationCard(title: card.title, subtitle: card.subtitle, icon: card.icon, count: nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color("GeoSurface").ignoresSafeArea())
            .navigationTitle("Activities")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search activities")
        }
        .tint(Color("BrandGreen"))
    }

    private var activitySummary: some View {
        HStack(spacing: 12) {
            ActivityMetric(title: isTeacher ? "Active" : "Assigned", value: "0", icon: "play.circle.fill")
            ActivityMetric(title: isTeacher ? "To Review" : "Drafts", value: "0", icon: "clock.fill")
            ActivityMetric(title: isTeacher ? "Classes" : "Feedback", value: "0", icon: "person.2.fill")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(ActivityHubFilter.visible(forTeacher: isTeacher)) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedFilter = filter }
                    } label: {
                        Label(filter.title, systemImage: filter.icon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .foregroundStyle(selectedFilter == filter ? .white : Color("BrandGreen"))
                            .background(selectedFilter == filter ? Color("BrandGreen") : .white, in: Capsule())
                            .overlay(Capsule().stroke(Color("BrandGreen").opacity(selectedFilter == filter ? 0 : 0.20)))
                    }
                    .buttonStyle(.plain)
                }
            }
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

private struct ActivityMetric: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color("BrandGreen"))
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

private enum ActivityHubFilter: String, CaseIterable, Identifiable {
    case all, create, assigned, drafts, review, fieldwork, library
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All"
        case .create: "Create"
        case .assigned: "Assigned"
        case .drafts: "Drafts"
        case .review: "Review"
        case .fieldwork: "Fieldwork"
        case .library: "Library"
        }
    }
    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .create: "plus"
        case .assigned: "rectangle.stack"
        case .drafts: "doc.text"
        case .review: "checkmark.seal"
        case .fieldwork: "figure.hiking"
        case .library: "books.vertical"
        }
    }
    static func visible(forTeacher: Bool) -> [ActivityHubFilter] {
        forTeacher ? [.all, .create, .assigned, .review, .fieldwork, .library] : [.all, .assigned, .drafts, .review]
    }
}

private struct ActivityHubCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let filter: ActivityHubFilter
    let destination: CoreDestination
}

struct CoreMoreView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CoreSectionHero(
                        title: "More",
                        subtitle: "Reports, portfolios, curriculum, connected apps and system tools.",
                        icon: "ellipsis.circle.fill"
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        NavigationLink { FieldChecklistView() } label: {
                            CoreNavigationCard(title: "Evidence & Portfolios", subtitle: "Review field evidence and student records", icon: "tray.full.fill", count: nil)
                        }
                        NavigationLink { MapSectionView() } label: {
                            CoreNavigationCard(title: "Maps & Sites", subtitle: "Open shared fieldwork maps and locations", icon: "map.fill", count: nil)
                        }
                        NavigationLink { ReviewWorkView() } label: {
                            CoreNavigationCard(title: "Review Work", subtitle: "Check submissions and provide feedback", icon: "checkmark.seal.fill", count: nil)
                        }
                        NavigationLink { ConnectedStudentAppsView() } label: {
                            CoreNavigationCard(title: "Connected Apps", subtitle: "Geography, History and Agriculture", icon: "apps.iphone", count: "3")
                        }
                        NavigationLink { CoreSyncCentreView() } label: {
                            CoreNavigationCard(title: "Sync Centre", subtitle: "Uploads, downloads and connection status", icon: "arrow.triangle.2.circlepath", count: nil)
                        }
                        NavigationLink { WorksheetListView() } label: {
                            CoreNavigationCard(title: "Curriculum", subtitle: "Browse and attach curriculum outcomes", icon: "books.vertical.fill", count: nil)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color("GeoSurface").ignoresSafeArea())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color("BrandGreen"))
    }
}

private struct CoreSectionHero: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color("BrandGreen"))
                .frame(width: 58, height: 58)
                .background(Color("BrandGreen").opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.title.bold())
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct CoreNavigationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let count: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color("BrandGreen"))
                    .frame(width: 44, height: 44)
                    .background(Color("BrandGreen").opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                if let count {
                    Text(count).font(.caption.bold()).foregroundStyle(.secondary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color("GeoSurface"), in: Capsule())
                }
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            Text(title).font(.title3.bold()).foregroundStyle(.primary)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05)))
    }
}
