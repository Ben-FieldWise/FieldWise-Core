//
//  CoreHomeView.swift
//  FieldWise Core
//
//  The platform home screen — the first thing anyone sees after signing
//  in, and the surface that makes this app *FieldWise Core* rather than a
//  single subject app.
//
//  Section 1 of the FieldWise plan describes Core as the shared school
//  system: accounts, classes, excursions, maps, offline sync, evidence,
//  teacher review, reporting and portfolios. This view is the role-aware
//  dashboard that ties those areas together:
//
//    • Teacher dashboard — classes at a glance (with join codes), quick
//      actions into class management / excursion planning / maps /
//      reports, and offline sync status.
//    • Student dashboard — their class, how many activities are assigned,
//      quick access to their work, and offline sync status.
//
//  It deliberately holds NO subject-specific fieldwork tools (no coasts,
//  soils, weather, landforms). Those belong to the subject apps that plug
//  into Core — keeping this screen inside the Core boundary from the plan.
//

import SwiftUI

struct CoreHomeView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var navCoordinator: AppNavigationCoordinator
    @StateObject private var store = ClassroomStore()

    @State private var pendingCount = 0
    @State private var isSyncing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = authService.currentUserProfile {
                    VStack(spacing: 18) {
                        GreetingHeader(profile: profile)

                        if profile.role == .teacher {
                            TeacherHome(store: store, profile: profile)
                        } else {
                            StudentHome(store: store, profile: profile)
                        }

                        SyncStatusCard(
                            pendingCount: pendingCount,
                            isSyncing: isSyncing,
                            onSync: syncNow
                        )
                    }
                    .padding(20)
                    .task { await load(for: profile) }
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("FieldWiseIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 26)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        authService.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .tint(Color("BrandGreen"))
                }
            }
        }
        .tint(Color("BrandGreen"))
    }

    // MARK: - Data

    private func load(for profile: UserProfile) async {
        if profile.role == .teacher {
            await store.loadTeacherClasses(teacherId: profile.id)
        } else if let classId = profile.classId {
            await store.loadStudentClass(classId: classId)
            await store.loadTasks(classId: classId)
        }
        await refreshPending()
    }

    private func refreshPending() async {
        pendingCount = await EntrySync.shared.pendingCount()
    }

    private func syncNow() {
        Task {
            isSyncing = true
            await EntrySync.shared.flush()
            await refreshPending()
            isSyncing = false
        }
    }
}

// MARK: - Greeting

private struct GreetingHeader: View {
    let profile: UserProfile

    private var roleLabel: String {
        profile.role == .teacher ? "Teacher" : "Student"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome back")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(profile.displayName.isEmpty ? "FieldWise" : profile.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }
            Spacer()
            Text(roleLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color("BrandGreen"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color("BrandGreen").opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Teacher home

private struct TeacherHome: View {
    @ObservedObject var store: ClassroomStore
    let profile: UserProfile
    @EnvironmentObject private var nav: AppNavigationCoordinator

    private func navCoordinatorGoTo(_ tab: AppTab) { nav.selectedTab = tab }

    var body: some View {
        VStack(spacing: 18) {
            // Stat strip
            HStack(spacing: 12) {
                StatTile(value: "\(store.classes.count)",
                         label: store.classes.count == 1 ? "Class" : "Classes",
                         icon: "person.2.fill",
                         color: Color("BrandGreen"))
                StatTile(value: "\(store.classes.filter { $0.active }.count)",
                         label: "Active",
                         icon: "dot.radiowaves.left.and.right",
                         color: Color("GeoBlue"))
            }

            // Classes overview
            GeoCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your classes")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Button("Manage") { navCoordinatorGoTo(.classes) }
                            .font(.system(size: 14, weight: .semibold))
                            .tint(Color("BrandGreen"))
                    }

                    if store.isLoading && store.classes.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else if store.classes.isEmpty {
                        EmptyHint(
                            icon: "plus.circle",
                            text: "No classes yet. Create one to get a join code students can use.",
                            actionTitle: "Create a class"
                        ) { navCoordinatorGoTo(.classes) }
                    } else {
                        ForEach(store.classes.prefix(4)) { cls in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cls.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Code: \(cls.classCode)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                MiniPill(text: cls.active ? "Active" : "Closed",
                                         color: cls.active ? Color("GeoGreen") : .gray)
                            }
                            .padding(.vertical, 4)
                            if cls.id != store.classes.prefix(4).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            // Quick actions
            QuickActionsGrid(actions: [
                .init(title: "Review work", icon: "checklist", color: Color("BrandGreen")) { navCoordinatorGoTo(.classes) },
                .init(title: "Plan excursion", icon: "map.circle.fill", color: Color("GeoBlue")) { navCoordinatorGoTo(.excursions) },
                .init(title: "Sites & map", icon: "mappin.and.ellipse", color: Color("GeoCoral")) { navCoordinatorGoTo(.map) },
                .init(title: "Reports", icon: "doc.plaintext.fill", color: Color("BrandAmber")) { navCoordinatorGoTo(.reports) }
            ])
        }
    }
}

// MARK: - Student home

private struct StudentHome: View {
    @ObservedObject var store: ClassroomStore
    let profile: UserProfile
    @EnvironmentObject private var nav: AppNavigationCoordinator

    var body: some View {
        VStack(spacing: 18) {
            // Current class
            GeoCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your class")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    if let cls = store.currentClass {
                        Text(cls.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        MiniPill(text: cls.active ? "Active" : "Closed",
                                 color: cls.active ? Color("GeoGreen") : .gray)
                    } else if profile.classId == nil {
                        Text("You haven't joined a class yet.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        ProgressView()
                    }
                }
            }

            // Activities
            HStack(spacing: 12) {
                StatTile(value: "\(store.tasks.count)",
                         label: store.tasks.count == 1 ? "Activity" : "Activities",
                         icon: "list.bullet.clipboard.fill",
                         color: Color("BrandGreen"))
                StatTile(value: "\(store.tasks.filter { $0.isBooklet }.count)",
                         label: "Booklets",
                         icon: "book.closed.fill",
                         color: Color("GeoBlue"))
            }

            GeoCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Assigned to you")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Button("Open") { nav.selectedTab = .classes }
                            .font(.system(size: 14, weight: .semibold))
                            .tint(Color("BrandGreen"))
                    }
                    if store.tasks.isEmpty {
                        EmptyHint(
                            icon: "tray",
                            text: "Nothing assigned right now. Your teacher's activities will appear here.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        ForEach(store.tasks.prefix(4)) { task in
                            HStack(spacing: 10) {
                                Image(systemName: task.isBooklet ? "book.closed.fill" : "square.and.pencil")
                                    .foregroundColor(Color("BrandGreen"))
                                    .frame(width: 22)
                                Text(task.title)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            QuickActionsGrid(actions: [
                .init(title: "My activities", icon: "list.bullet.clipboard.fill", color: Color("BrandGreen")) { nav.selectedTab = .classes },
                .init(title: "Excursion", icon: "map.circle.fill", color: Color("GeoBlue")) { nav.selectedTab = .excursions },
                .init(title: "Map", icon: "mappin.and.ellipse", color: Color("GeoCoral")) { nav.selectedTab = .map },
                .init(title: "Reports", icon: "doc.plaintext.fill", color: Color("BrandAmber")) { nav.selectedTab = .reports }
            ])
        }
    }
}

// MARK: - Sync status card

private struct SyncStatusCard: View {
    let pendingCount: Int
    let isSyncing: Bool
    let onSync: () -> Void

    private var synced: Bool { pendingCount == 0 }

    var body: some View {
        GeoCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((synced ? Color("GeoGreen") : Color("BrandAmber")).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: synced ? "checkmark.icloud.fill" : "icloud.and.arrow.up.fill")
                        .foregroundColor(synced ? Color("GeoGreen") : Color("BrandAmber"))
                        .font(.system(size: 19, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(synced ? "All work synced" : "\(pendingCount) waiting to sync")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(synced
                         ? "Everything on this device is saved to the cloud."
                         : "Saved on this device. Will upload when back online.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSyncing {
                    ProgressView().tint(Color("BrandGreen"))
                } else if !synced {
                    Button(action: onSync) {
                        Text("Sync")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("BrandGreen"))
                    }
                }
            }
        }
    }
}

// MARK: - Small shared pieces (local to Home)

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GeoCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 17, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct MiniPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct EmptyHint: View {
    let icon: String
    let text: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .tint(Color("BrandGreen"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

private struct QuickActionsGrid: View {
    let actions: [QuickAction]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(actions) { action in
                Button(action: action.action) {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(action.color)
                            .frame(width: 24)
                        Text(action.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
