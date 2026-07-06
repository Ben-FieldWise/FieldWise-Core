//
//  GISDetailSheets.swift
//  Student Fieldwork App
//
//  Detail/edit sheets for a tapped pin or drawn shape, including the
//  "link to a site" picker that ties a pin/shape to a specific
//  FieldSheetTrip + SiteFieldSheet recorded in SiteFieldSheetStore.
//

import SwiftUI

// MARK: - Pin detail sheet

struct PinDetailSheet: View {
    @ObservedObject var siteSheetStore: SiteFieldSheetStore
    @Environment(\.dismiss) private var dismiss

    @State private var pin: GISMapPin
    let onSave: (GISMapPin) -> Void
    let onDelete: () -> Void

    init(pin: GISMapPin, siteSheetStore: SiteFieldSheetStore, onSave: @escaping (GISMapPin) -> Void, onDelete: @escaping () -> Void) {
        self._pin = State(initialValue: pin)
        self.siteSheetStore = siteSheetStore
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pin details") {
                    TextField("Title", text: $pin.title)
                    TextField("Note", text: $pin.note, axis: .vertical)
                }

                Section("Marker colour") {
                    GISColorSwatchRow(selectedHex: $pin.colorHex)
                }

                Section("Link to a site (optional)") {
                    SiteLinkPicker(
                        siteSheetStore: siteSheetStore,
                        linkedTripID: $pin.linkedTripID,
                        linkedSiteSheetID: $pin.linkedSiteSheetID
                    )
                }

                Section {
                    Text("Coordinates: \(String(format: "%.5f", pin.coordinate.latitude)), \(String(format: "%.5f", pin.coordinate.longitude))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete pin", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Observation Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(pin) }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Shape detail sheet

struct ShapeDetailSheet: View {
    @ObservedObject var siteSheetStore: SiteFieldSheetStore
    @Environment(\.dismiss) private var dismiss

    @State private var shape: GISShape
    let onSave: (GISShape) -> Void
    let onDelete: () -> Void

    init(shape: GISShape, siteSheetStore: SiteFieldSheetStore, onSave: @escaping (GISShape) -> Void, onDelete: @escaping () -> Void) {
        self._shape = State(initialValue: shape)
        self.siteSheetStore = siteSheetStore
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(shape.kind == .polygon ? "Area details" : "Transect details") {
                    TextField("Title", text: $shape.title)
                    TextField("Note", text: $shape.note, axis: .vertical)
                }

                Section("Measurement") {
                    HStack {
                        Text(shape.kind == .polygon ? "Perimeter" : "Length")
                        Spacer()
                        Text(formatDistance(shape.lengthMeters))
                            .foregroundStyle(.secondary)
                    }
                    if shape.kind == .polygon {
                        HStack {
                            Text("Area")
                            Spacer()
                            Text(formatArea(shape.areaSquareMeters))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Points")
                        Spacer()
                        Text("\(shape.points.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Colour") {
                    GISColorSwatchRow(selectedHex: $shape.colorHex)
                }

                Section("Link to a site (optional)") {
                    SiteLinkPicker(
                        siteSheetStore: siteSheetStore,
                        linkedTripID: $shape.linkedTripID,
                        linkedSiteSheetID: $shape.linkedSiteSheetID
                    )
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete \(shape.kind == .polygon ? "area" : "transect")", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(shape.kind == .polygon ? "Area / Quadrat" : "Line / Transect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(shape) }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Shared: colour swatch picker

struct GISColorSwatchRow: View {
    @Binding var selectedHex: String

    private let options: [(name: String, hex: String)] = [
        ("Green", "2D6A4F"),
        ("Blue", "1A6FA8"),
        ("Amber", "8B6914"),
        ("Coral", "C1440E"),
        ("Purple", "5B4FCF"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options, id: \.hex) { option in
                Button {
                    selectedHex = option.hex
                } label: {
                    Circle()
                        .fill(Color(hex: option.hex))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().strokeBorder(Color.primary, lineWidth: selectedHex == option.hex ? 2 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shared: link-to-site picker

struct SiteLinkPicker: View {
    @ObservedObject var siteSheetStore: SiteFieldSheetStore
    @Binding var linkedTripID: UUID?
    @Binding var linkedSiteSheetID: UUID?

    var body: some View {
        if siteSheetStore.trips.isEmpty {
            Text("No trips recorded yet in the Report tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("Trip", selection: tripSelection) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(siteSheetStore.trips) { trip in
                    Text(trip.name).tag(Optional(trip.id))
                }
            }

            if let tripID = linkedTripID, let trip = siteSheetStore.trips.first(where: { $0.id == tripID }) {
                Picker("Site", selection: siteSelection) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(trip.siteSheets) { site in
                        Text(site.siteName.isEmpty ? "Untitled site" : site.siteName).tag(Optional(site.id))
                    }
                }
            }
        }
    }

    private var tripSelection: Binding<UUID?> {
        Binding(
            get: { linkedTripID },
            set: { newValue in
                linkedTripID = newValue
                linkedSiteSheetID = nil // reset site choice when trip changes
            }
        )
    }

    private var siteSelection: Binding<UUID?> {
        Binding(
            get: { linkedSiteSheetID },
            set: { linkedSiteSheetID = $0 }
        )
    }
}
