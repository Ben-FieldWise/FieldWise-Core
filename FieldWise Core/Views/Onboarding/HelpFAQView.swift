//
//  HelpFAQView.swift
//  Student Fieldwork App
//
//  The Help & FAQ sheet, reachable from the (?) icon added to every
//  tab's navigation bar via the .helpButton() modifier below — one
//  shared sheet rather than 5 separate implementations.
//

import SwiftUI

struct HelpFAQView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @State private var expandedItemID: UUID?
    @State private var showingWelcomeReplay = false
    @State private var searchText = ""

    private var filteredSections: [FAQSection] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return faqSections }
        let query = searchText.lowercased()
        return faqSections.compactMap { section in
            let matchingItems = section.items.filter {
                $0.question.lowercased().contains(query) || $0.answer.lowercased().contains(query)
            }
            guard !matchingItems.isEmpty else { return nil }
            return FAQSection(title: section.title, iconName: section.iconName, items: matchingItems)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search the FAQ…", text: $searchText)
                    }
                }

                if filteredSections.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("No matching questions")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }

                ForEach(filteredSections) { section in
                    Section {
                        ForEach(section.items) { item in
                            FAQRow(
                                item: item,
                                isExpanded: expandedItemID == item.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedItemID = expandedItemID == item.id ? nil : item.id
                                    }
                                }
                            )
                        }
                    } header: {
                        Label(section.title, systemImage: section.iconName)
                    }
                }

                Section {
                    Button {
                        showingWelcomeReplay = true
                    } label: {
                        Label("Show welcome screen again", systemImage: "arrow.clockwise")
                    }
                } footer: {
                    Text("Replays the introduction shown the first time you opened the app.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingWelcomeReplay) {
                WelcomeView(isReplay: true)
            }
        }
    }
}

struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(item.question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                if isExpanded {
                    Text(item.answer)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable toolbar button modifier

/// Adds a consistent (?) help icon to a navigation bar's trailing edge,
/// presenting the shared Help & FAQ sheet. Apply to any root view with
/// `.helpButton()` right after `.navigationTitle(...)`.
struct HelpButtonModifier: ViewModifier {
    @State private var showingHelp = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help & FAQ")
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpFAQView()
            }
    }
}

extension View {
    func helpButton() -> some View {
        modifier(HelpButtonModifier())
    }
}

#Preview {
    HelpFAQView()
}
