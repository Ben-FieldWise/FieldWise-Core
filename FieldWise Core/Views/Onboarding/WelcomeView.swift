//
//  WelcomeView.swift
//  FieldWise Core
//
//  First-launch onboarding sheet with real FieldWise Education branding.
//  Shown automatically exactly once (gated by AppStorage in ContentView)
//  and also reachable from Help & FAQ ("Show welcome screen again").
//

import SwiftUI

struct WelcomeFeature: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let accentColorName: String
}

let welcomeFeatures: [WelcomeFeature] = [
    WelcomeFeature(
        title: "Plan",
        description: "Build a 6-step fieldwork plan — aims, equipment, data methods, safety, recording, and a final readiness checklist before you head out.",
        iconName: "clipboard.fill",
        accentColorName: "GeoGreen"
    ),
    WelcomeFeature(
        title: "Landscapes",
        description: "Reference material on rocks, soils, landforms, field tests, and human impact — everything you need to identify what you're looking at on site.",
        iconName: "mountain.2.fill",
        accentColorName: "GeoAmberDark"
    ),
    WelcomeFeature(
        title: "Weather",
        description: "Live weather and a fieldwork suitability check for your site, plus a place to log on-day conditions and observations.",
        iconName: "cloud.sun.fill",
        accentColorName: "GeoBlue"
    ),
    WelcomeFeature(
        title: "Map",
        description: "An interactive GIS map with topographic overlays, pin drops, GPS tracking, and a built-in compass.",
        iconName: "map.fill",
        accentColorName: "GeoGreen"
    ),
    WelcomeFeature(
        title: "Report",
        description: "Record your field data site by site, fill in survey forms, draft your report outline, and export everything to PDF when you're done.",
        iconName: "doc.plaintext.fill",
        accentColorName: "GeoCoral"
    )
]

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    var displayName: String = ""
    var isReplay: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Hero: real FieldWise logo ──────────────────────────
                    VStack(spacing: 16) {
                        // Stacked logo SVG (icon mark + FieldWise + CORE)
                        Image("FieldWiseLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 162)
                            .padding(.top, 8)

                        Text(displayName.isEmpty
                             ? "Your fieldwork companion,\nfrom planning to report."
                             : "Welcome, \(displayName).\nYour fieldwork companion, from planning to report.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    // ── Feature rows ──────────────────────────────────────
                    VStack(spacing: 12) {
                        ForEach(welcomeFeatures) { feature in
                            WelcomeFeatureRow(feature: feature)
                        }
                    }

                    // ── Help tip ──────────────────────────────────────────
                    HStack(spacing: 10) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color("BrandGold"))
                        Text("Need help? Tap the **?** icon in any tab for the full FAQ, including how to export your data to PDF.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color("GeoSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // ── FieldWise Education footer ─────────────────────────
                    VStack(spacing: 4) {
                        Text("FieldWise Education")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("BrandGreen"))
                        Text("fieldwiseeducation.com.au")
                            .font(.system(size: 11))
                            .foregroundColor(Color("BrandAmber"))
                    }
                    .padding(.bottom, 8)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(Color("GeoSurface"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isReplay {
                        // Show icon-only logo in nav bar for replay
                        Image("FieldWiseIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get Started") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("BrandGreen"))
                }
            }
        }
    }
}

struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature
    var accentColor: Color { Color(feature.accentColorName) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: feature.iconName)
                    .foregroundColor(accentColor)
                    .font(.system(size: 19, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(feature.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }
}

#Preview {
    WelcomeView()
}
