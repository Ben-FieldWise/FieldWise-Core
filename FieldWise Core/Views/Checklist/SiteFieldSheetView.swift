//
//  SiteFieldSheetView.swift
//  Student Fieldwork App
//
//  Interactive fieldwork data-collection sheet replacing the old static
//  Checklist tab content. Students can: switch between sites on a
//  multi-site trip, tick off data-collection tasks with attached photo
//  galleries, and check off observed rock/soil/vegetation/feature terms
//  organised into named groups (modelled on the existing survey form's
//  grid-group pattern, but purpose-built for geology/geography terms).
//

import SwiftUI

// MARK: - Root

struct SiteFieldSheetRootView: View {
    @EnvironmentObject var store: SiteFieldSheetStore
    @EnvironmentObject var gisStore: GISMapStore
    @EnvironmentObject var navCoordinator: AppNavigationCoordinator
    @State private var showingTripPicker = false
    @State private var showingNewTripSheet = false
    @State private var showingSitePicker = false
    @State private var showingExportSheet = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showingPinDroppedToast = false
    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            Group {
                if let trip = store.activeTrip, let sheet = store.activeSiteSheet {
                    siteSheetContent(trip: trip, sheet: sheet)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Field Data Sheet")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingTripPicker = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Trip history")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingNewTripSheet = true
                        } label: {
                            Label("New Trip", systemImage: "plus.circle")
                        }
                        if store.activeTrip != nil {
                            Button {
                                store.addSiteSheet()
                            } label: {
                                Label("Add Site", systemImage: "mappin.and.ellipse")
                            }
                            Divider()
                            Button {
                                viewOnMap()
                            } label: {
                                Label("View on Map", systemImage: "map")
                            }
                            Button {
                                dropPinForCurrentSite()
                            } label: {
                                Label("Drop Pin for This Site", systemImage: "mappin.circle")
                            }
                            Divider()
                            Button {
                                showingExportSheet = true
                            } label: {
                                Label("Export / Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Divider()
                        Button {
                            showingHelp = true
                        } label: {
                            Label("Help & FAQ", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingTripPicker) {
                FieldSheetTripHistoryView(store: store)
            }
            .sheet(isPresented: $showingNewTripSheet) {
                NewFieldSheetTripSheet(store: store)
            }
            .sheet(isPresented: $showingHelp) {
                HelpFAQView()
            }
            .confirmationDialog("Export Field Sheet", isPresented: $showingExportSheet, titleVisibility: .visible) {
                Button("Export Current Site as PDF") { exportSite() }
                Button("Export Whole Trip as PDF") { exportTrip() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
            .overlay(alignment: .top) {
                if showingPinDroppedToast {
                    Text("Pin dropped for this site")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    /// Switches to the Map tab and asks it to centre on this site's pins
    /// (falling back to the device's current location if none exist yet).
    private func viewOnMap() {
        guard let trip = store.activeTrip, let sheet = store.activeSiteSheet else { return }
        gisStore.requestFocus(
            tripID: trip.id,
            siteSheetID: sheet.id,
            fallbackCoordinate: gisStore.currentLocation
        )
        navCoordinator.goToMap()
    }

    /// Drops a pin at the device's current GPS location, pre-linked to
    /// the active trip + site, without leaving the field sheet.
    private func dropPinForCurrentSite() {
        guard let trip = store.activeTrip, let sheet = store.activeSiteSheet else { return }
        guard let coordinate = gisStore.currentLocation else {
            // No fix yet — request one; the student can retry once GPS
            // has a lock, which usually only takes a second or two.
            gisStore.requestLocationPermission()
            gisStore.startUpdatingLocation()
            return
        }
        gisStore.dropPinForSite(
            tripID: trip.id,
            siteSheetID: sheet.id,
            siteName: sheet.siteName,
            at: coordinate
        )
        withAnimation { showingPinDroppedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showingPinDroppedToast = false }
        }
    }

    private func exportSite() {
        guard let trip = store.activeTrip, let sheet = store.activeSiteSheet,
              let url = SiteFieldSheetExporter.makePDF(for: sheet, trip: trip, store: store) else { return }
        shareItems = [url]
        showShareSheet = true
    }

    private func exportTrip() {
        guard let trip = store.activeTrip,
              let url = SiteFieldSheetExporter.makeTripPDF(for: trip, store: store) else { return }
        shareItems = [url]
        showShareSheet = true
    }

    @ViewBuilder
    private func siteSheetContent(trip: FieldSheetTrip, sheet: SiteFieldSheet) -> some View {
        List {
            Section {
                tripHeader(trip)
                sitePicker(trip)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                siteMetaFields(sheet)
            } header: {
                Text("Site details")
            }

            Section {
                sitePhotosRow(sheet)
            } header: {
                Text("Site overview photos")
            }

            ForEach(sheet.sections) { section in
                SiteSheetSectionView(store: store, section: section)
            }

            Section {
                Text("Tap a category below and check off everything you observe at this site.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Geography & geology observations")
            }

            ForEach(sheet.observationGroups) { group in
                GeoObservationGroupView(store: store, group: group)
                if group.title == "Soil characteristics" {
                    MunsellSoilColorSectionView(
                        store: store,
                        selections: sheet.munsellSelections
                    )
                }
            }

            Section("Overall site notes") {
                TextEditor(text: Binding(
                    get: { sheet.overallNotes },
                    set: { store.updateOverallNotes($0) }
                ))
                .frame(minHeight: 100)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func tripHeader(_ trip: FieldSheetTrip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name)
                        .font(.title2.bold())
                    if !trip.locationDescription.isEmpty {
                        Text(trip.locationDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(trip.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(trip.siteSheets.count) site\(trip.siteSheets.count == 1 ? "" : "s")")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("GeoGreen").opacity(0.15))
                    .foregroundStyle(Color("GeoGreen"))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func sitePicker(_ trip: FieldSheetTrip) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(trip.siteSheets) { sheet in
                    SiteChip(
                        sheet: sheet,
                        isActive: sheet.id == store.activeSiteSheetID,
                        onTap: { store.selectSiteSheet(sheet) }
                    )
                }
                Button {
                    store.addSiteSheet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color("GeoSurface"))
                        .foregroundStyle(Color("GeoGreen"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private func siteMetaFields(_ sheet: SiteFieldSheet) -> some View {
        Group {
            TextField("Site name (e.g. Site 1 — Lookout)", text: Binding(
                get: { sheet.siteName },
                set: { store.updateSiteMeta(siteName: $0, siteNumber: sheet.siteNumber, gridReference: sheet.gridReference, weatherSummary: sheet.weatherSummary) }
            ))
            TextField("Site number", text: Binding(
                get: { sheet.siteNumber },
                set: { store.updateSiteMeta(siteName: sheet.siteName, siteNumber: $0, gridReference: sheet.gridReference, weatherSummary: sheet.weatherSummary) }
            ))
            TextField("Grid reference / GPS", text: Binding(
                get: { sheet.gridReference },
                set: { store.updateSiteMeta(siteName: sheet.siteName, siteNumber: sheet.siteNumber, gridReference: $0, weatherSummary: sheet.weatherSummary) }
            ))
            TextField("Weather on the day", text: Binding(
                get: { sheet.weatherSummary },
                set: { store.updateSiteMeta(siteName: sheet.siteName, siteNumber: sheet.siteNumber, gridReference: sheet.gridReference, weatherSummary: $0) }
            ))
        }
    }

    private func sitePhotosRow(_ sheet: SiteFieldSheet) -> some View {
        FieldPhotoGalleryStrip(
            store: store,
            photos: sheet.sitePhotos,
            onAdd: { image in store.addSitePhoto(image) },
            onDelete: { photo in store.removeSitePhoto(photo) }
        )
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No active trip")
                .font(.headline)
            Text("Start a new trip to begin recording site field sheets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showingNewTripSheet = true
            } label: {
                Label("New Trip", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Site chip (horizontal site picker)

struct SiteChip: View {
    let sheet: SiteFieldSheet
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.siteName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                    Text("\(sheet.completedChecklistItems)/\(sheet.totalChecklistItems)")
                        .font(.system(size: 11))
                    if sheet.totalPhotoCount > 0 {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 9))
                        Text("\(sheet.totalPhotoCount)")
                            .font(.system(size: 11))
                    }
                }
                .foregroundColor(isActive ? .white.opacity(0.85) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color("GeoGreen") : Color("GeoSurface"))
            .foregroundColor(isActive ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checklist section (with photo galleries per item)

struct SiteSheetSectionView: View {
    @ObservedObject var store: SiteFieldSheetStore
    let section: SiteSheetSection
    @State private var newItemText: String = ""
    @State private var showingAddField = false

    var body: some View {
        Section {
            if section.isExpanded {
                ForEach(section.items) { item in
                    SiteSheetItemRow(store: store, sectionID: section.id, item: item)
                }

                if showingAddField {
                    HStack {
                        TextField("Add comment…", text: $newItemText)
                            .onSubmit { addItem() }
                        Button("Add") { addItem() }
                            .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        showingAddField = true
                    } label: {
                        Label("Add Comment", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }
        } header: {
            Button {
                withAnimation { store.toggleSectionExpanded(sectionID: section.id) }
            } label: {
                HStack {
                    Image(systemName: section.icon)
                        .foregroundStyle(Color("GeoGreen"))
                    Text(section.title)
                    Spacer()
                    Text("\(section.completedCount)/\(section.totalCount)")
                        .font(.caption)
                    Image(systemName: section.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addCustomItem(sectionID: section.id, title: trimmed)
        newItemText = ""
        showingAddField = false
    }
}

struct SiteSheetItemRow: View {
    @ObservedObject var store: SiteFieldSheetStore
    let sectionID: UUID
    let item: SiteSheetItem
    @State private var showingNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.toggleItem(sectionID: sectionID, itemID: item.id)
                    }
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    withAnimation { showingNotes.toggle() }
                } label: {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundStyle(item.notes.isEmpty ? .secondary : Color("GeoGreen"))
                }
                .buttonStyle(.plain)

                if item.isCustom {
                    Button(role: .destructive) {
                        store.removeItem(sectionID: sectionID, itemID: item.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            FieldPhotoGalleryStrip(
                store: store,
                photos: item.photos,
                onAdd: { image in store.addItemPhoto(sectionID: sectionID, itemID: item.id, image: image) },
                onDelete: { photo in store.removeItemPhoto(sectionID: sectionID, itemID: item.id, photo: photo) }
            )

            if showingNotes {
                TextField("Notes…", text: Binding(
                    get: { item.notes },
                    set: { store.updateItemNotes(sectionID: sectionID, itemID: item.id, notes: $0) }
                ), axis: .vertical)
                .font(.caption)
                .padding(8)
                .background(Color("GeoSurface"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Geography observation group (checkbox grid)

struct GeoObservationGroupView: View {
    @ObservedObject var store: SiteFieldSheetStore
    let group: GeoObservationGroup
    @State private var isExpanded = false

    var body: some View {
        Section {
            if isExpanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(group.terms) { term in
                        GeoTermToggle(
                            term: term,
                            onToggle: { store.toggleTerm(groupID: group.id, termID: term.id) }
                        )
                    }
                }
                .padding(.vertical, 4)

                DisclosureGroup("Group notes") {
                    TextField("e.g. mostly outcrop on the north face", text: Binding(
                        get: { group.groupNote },
                        set: { store.updateGroupNote(groupID: group.id, note: $0) }
                    ), axis: .vertical)
                    .font(.caption)
                }
            }
        } header: {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: group.icon)
                        .foregroundStyle(Color("GeoAmberDark"))
                    Text(group.title)
                    Spacer()
                    if group.checkedCount > 0 {
                        Text("\(group.checkedCount)/\(group.terms.count)")
                            .font(.caption)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}

struct GeoTermToggle: View {
    let term: GeoTerm
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: term.isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(term.isChecked ? Color("GeoGreen") : .secondary)
                    .font(.system(size: 15))
                Text(term.label)
                    .font(.system(size: 13))
                    .foregroundStyle(term.isChecked ? .primary : .secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(term.isChecked ? Color("GeoGreen").opacity(0.1) : Color("GeoSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Trip Sheet

struct NewFieldSheetTripSheet: View {
    @ObservedObject var store: SiteFieldSheetStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var location: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip name (e.g. Hanging Rock — Whole Day)", text: $name)
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    Text("A first site sheet will be created automatically. Add more sites once you arrive.")
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

// MARK: - Trip History

struct FieldSheetTripHistoryView: View {
    @ObservedObject var store: SiteFieldSheetStore
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
                            Text("\(trip.siteSheets.count) sites")
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

#Preview {
    SiteFieldSheetRootView()
}
