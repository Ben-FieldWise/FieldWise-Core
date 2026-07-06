//
//  FieldChecklistView.swift
//  Student Fieldwork App
//
//  Root container for Checklist / Survey Forms / Report Outline, switched
//  via a segmented picker (matching WeatherRootView / GeologyRootView's
//  internal sub-navigation pattern) rather than a nested TabView — this
//  view is itself hosted inside the app's main 4-tab TabView, and a
//  TabView-inside-a-TabView produces a broken double tab bar.
//
//  NOTE: The "Checklist" segment shows the new interactive Site Field
//  Sheet (SiteFieldSheetRootView, in SiteFieldSheetView.swift), which
//  manages its own self-contained store (SiteFieldSheetStore) and does
//  not use FieldChecklistStore. Survey Forms and Report Outline are
//  unchanged and continue to use FieldChecklistStore / FieldTrip.
//

import SwiftUI

// MARK: - Root View

struct FieldChecklistView: View {
    @StateObject private var store = FieldChecklistStore()
    @State private var selectedSegment = 0
    @State private var showingTripPicker = false
    @State private var showingNewTripSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSegment) {
                Text("Field Sheet").tag(0)
                Text("Survey Forms").tag(1)
                Text("Report Outline").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            // On iPad / Mac (regular width), SwiftUI floats the TabView's
            // tabs in a bar across the top of the screen instead of
            // pinning them to the bottom like on iPhone. Since this
            // picker has no NavigationStack of its own above it to
            // reserve that space (segments 1 and 2 only get one further
            // down, inside the switch), it needs extra top padding here
            // on regular-width layouts so it doesn't sit under that bar.
            .padding(.top, horizontalSizeClass == .regular ? 44 : 16)
            .padding(.bottom, 12)
            .background(Color("GeoSurface"))

            Group {
                switch selectedSegment {
                case 0:
                    SiteFieldSheetRootView()
                case 1:
                    NavigationStack {
                        SurveyFormListView(store: store)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    tripPickerButton
                                }
                            }
                    }
                case 2:
                    NavigationStack {
                        FieldReportOutlineView(store: store)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    tripPickerButton
                                }
                            }
                    }
                default:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showingTripPicker) {
            TripHistoryView(store: store)
        }
        .sheet(isPresented: $showingNewTripSheet) {
            NewTripSheet(store: store)
        }
    }

    private var tripPickerButton: some View {
        Button {
            showingTripPicker = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .accessibilityLabel("Trip history")
    }
}

// MARK: - New Trip Sheet

struct NewTripSheet: View {
    @ObservedObject var store: FieldChecklistStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var location: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip name (e.g. Yarra River AT3)", text: $name)
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    Text("A fresh checklist with all default categories will be created for this trip.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let tripName = name.trimmingCharacters(in: .whitespaces)
                        store.startNewTrip(
                            name: tripName.isEmpty ? "Untitled Trip" : tripName,
                            locationDescription: location.trimmingCharacters(in: .whitespaces),
                            date: date
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Trip Details Sheet

struct EditTripDetailsSheet: View {
    @ObservedObject var store: FieldChecklistStore
    let trip: FieldTrip
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var location: String
    @State private var date: Date

    init(store: FieldChecklistStore, trip: FieldTrip) {
        self.store = store
        self.trip = trip
        _name = State(initialValue: trip.name)
        _location = State(initialValue: trip.locationDescription)
        _date = State(initialValue: trip.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip name", text: $name)
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateTripMeta(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Trip" : name,
                            locationDescription: location.trimmingCharacters(in: .whitespaces),
                            date: date
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Trip History View

struct TripHistoryView: View {
    @ObservedObject var store: FieldChecklistStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.trips) { trip in
                    Button {
                        store.selectTrip(trip)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(trip.name)
                                        .font(.headline)
                                    if trip.id == store.activeTripID {
                                        Text("Active")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                if !trip.locationDescription.isEmpty {
                                    Text(trip.locationDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(trip.completedItems)/\(trip.totalItems)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.deleteTrip(trip)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            store.duplicateTrip(trip)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Trip History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if store.trips.isEmpty {
                    ContentUnavailableViewCompat()
                }
            }
        }
    }
}

// MARK: - iOS 16 compatible "no content" view (ContentUnavailableView is iOS 17+)

struct ContentUnavailableViewCompat: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No trips yet")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    FieldChecklistView()
}
