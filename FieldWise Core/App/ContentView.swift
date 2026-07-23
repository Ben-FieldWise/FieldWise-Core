//
//  ContentView.swift
//  FieldWise Core
//
//  Root view — switches between:
//    • AuthRootView  — when nobody is signed in (role picker → teacher
//                      sign-up/sign-in, or student class-code join)
//    • The 5-tab TabView — once AuthService.currentUserProfile is set
//
//  The Welcome onboarding sheet still shows exactly once on first launch
//  (gated by @AppStorage), separately from auth state — a student who
//  just joined their class still gets the feature tour.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var planStore          = PlanStore()
    @StateObject private var checklistStore     = ChecklistStore()
    @StateObject private var siteFieldSheetStore = SiteFieldSheetStore()
    @StateObject private var gisMapStore        = GISMapStore()
    @StateObject private var navCoordinator     = AppNavigationCoordinator()
    @StateObject private var authService: AuthService
    @State private var showingWelcome = false

    init() {
        _authService = StateObject(wrappedValue: AuthService())
    }

    var body: some View {
        Group {
            if authService.isLoading {
                // ── Splash while Firebase auth state resolves ────────────
                SplashView()
            } else if authService.currentUserProfile == nil {
                // ── Not signed in → auth gate ────────────────────────────
                AuthRootView()
                    .environmentObject(authService)
            } else {
                // ── Signed in → main app ─────────────────────────────────
                mainTabView
                    .onAppear {
                        showingWelcome = true
                    }
                    .fullScreenCover(isPresented: $showingWelcome) {
                        WelcomeView(displayName: authService.currentUserProfile?.displayName ?? "")
                    }
            }
        }
        .environmentObject(planStore)
        .environmentObject(checklistStore)
        .environmentObject(siteFieldSheetStore)
        .environmentObject(gisMapStore)
        .environmentObject(navCoordinator)
        .environmentObject(authService)
    }

    // MARK: - Main tab view

    private var mainTabView: some View {
        TabView(selection: $navCoordinator.selectedTab) {
            CoreHubView()
                .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.home)

            ClassroomView()
                .tabItem { Label("Classes", systemImage: "person.3.fill") }
                .tag(AppTab.classes)

            CoreActivitiesView()
                .tabItem { Label("Activities", systemImage: "rectangle.3.group.fill") }
                .tag(AppTab.activities)

            PlanRootView()
                .tabItem { Label("Fieldwork", systemImage: "figure.hiking") }
                .tag(AppTab.excursions)

            CoreMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(AppTab.more)
        }
        .tint(Color("BrandGreen"))
    }
}

// MARK: - Splash (Firebase auth state loading)

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color("GeoSurface").ignoresSafeArea()
            VStack(spacing: 20) {
                Image("FieldWiseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 147)
                ProgressView()
                    .tint(Color("BrandGreen"))
            }
        }
    }
}

// MARK: - Auth root (role picker → sign-in / join)

struct AuthRootView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var selectedRole: UserRole? = nil
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Logo
                    Image("FieldWiseLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 147)
                        .padding(.top, 20)

                    // Role picker
                    VStack(spacing: 12) {
                        Text("I am a...")
                            .font(.system(size: 18, weight: .semibold))

                        RoleCard(
                            title: "Teacher",
                            subtitle: "Create classes and view student submissions",
                            icon: "person.fill.badge.plus",
                            color: Color("BrandGreen"),
                            selected: selectedRole == .teacher
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedRole = .teacher
                            }
                        }

                        RoleCard(
                            title: "Student",
                            subtitle: "Join a class with a code — no account needed",
                            icon: "graduationcap.fill",
                            color: Color("BrandAmber"),
                            selected: selectedRole == .student
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedRole = .student
                            }
                        }
                    }
                    .padding(.horizontal, 4)

                    // Inline sign-in / join form
                    VStack(spacing: 0) {
                        if selectedRole == .teacher {
                            TeacherAuthForm()
                                .environmentObject(authService)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else if selectedRole == .student {
                            StudentJoinForm()
                                .environmentObject(authService)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedRole)

                    // Error
                    if let error = authService.lastError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Privacy note
                    Text("FieldWise Education · Students: first name and class code only. No email, no birthdate.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .padding(20)
            }
            .background(Color("GeoSurface"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("FieldWiseIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.lastError)
    }
}

// MARK: - Role card

private struct RoleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(selected ? 1 : 0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(selected ? .white : color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? color : Color.black.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Teacher auth form (sign up + sign in)

struct TeacherAuthForm: View {
    @EnvironmentObject private var authService: AuthService
    @State private var isSignUp = true
    @State private var schoolName = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            // Toggle sign-up / sign-in
            Picker("Mode", selection: $isSignUp) {
                Text("Create account").tag(true)
                Text("Sign in").tag(false)
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                if isSignUp {
                    BrandTextField("School name", text: $schoolName)
                    BrandTextField("Your name", text: $displayName)
                }
                BrandTextField("Email", text: $email, keyboard: .emailAddress)
                BrandTextField("Password", text: $password, secure: true)
            }

            if authService.isLoading {
                ProgressView().tint(Color("BrandGreen"))
            } else {
                Button {
                    Task {
                        if isSignUp {
                            await authService.teacherSignUp(
                                email: email,
                                password: password,
                                displayName: displayName,
                                schoolName: schoolName
                            )
                        } else {
                            await authService.teacherSignIn(
                                email: email,
                                password: password
                            )
                        }
                    }
                } label: {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("BrandGreen"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(email.isEmpty || password.isEmpty)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Student join form

struct StudentJoinForm: View {
    @EnvironmentObject private var authService: AuthService
    @State private var classCode = ""
    @State private var firstName = ""
    @State private var yearLevel: YearLevel = .year7

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                BrandTextField("Class code (e.g. RIV-294)", text: $classCode, autoCapitalise: .allCharacters)
                BrandTextField("Your first name", text: $firstName)
                Picker("Year level", selection: $yearLevel) {
                    ForEach(YearLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("GeoSurface"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                )
            }

            if authService.isLoading {
                ProgressView().tint(Color("BrandAmber"))
            } else {
                Button {
                    Task {
                        await authService.studentJoin(
                            classCode: classCode,
                            firstName: firstName,
                            yearLevel: yearLevel.rawValue
                        )
                    }
                } label: {
                    Text("Join Class")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("BrandAmber"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(classCode.trimmingCharacters(in: .whitespaces).isEmpty ||
                          firstName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("No email or account needed — just your class code, first name, and year level.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Shared branded text field

struct BrandTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false
    var autoCapitalise: UITextAutocapitalizationType = .words

    init(_ placeholder: String, text: Binding<String>,
         keyboard: UIKeyboardType = .default,
         secure: Bool = false,
         autoCapitalise: UITextAutocapitalizationType = .words) {
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
        self.secure = secure
        self.autoCapitalise = autoCapitalise
    }

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .autocapitalization(autoCapitalise)
                    .autocorrectionDisabled(keyboard == .emailAddress)
            }
        }
        .padding(12)
        .background(Color("GeoSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .font(.system(size: 15))
    }
}

// MARK: - Tab identity + shared navigation coordinator

/// The Core platform areas from Section 1 of the FieldWise plan:
/// Home (role-aware dashboard), Classes (management + review),
/// Excursions (planning + safety), Map (sites & locations), and
/// Reports (evidence exports / portfolios). Subject-specific tools
/// (landforms, weather, soils, coasts) deliberately live in the subject
/// apps, not here — that's the Core boundary.
enum AppTab: Hashable {
    case home, classes, activities, excursions, more
}

/// Lets any tab request a switch to another tab — used by "View on Map"
/// in the Reports tab to jump to the Map tab programmatically, and by the
/// Home dashboard's quick actions.
final class AppNavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .home

    func goToMap() {
        selectedTab = .more
    }
}

#Preview {
    ContentView()
}
