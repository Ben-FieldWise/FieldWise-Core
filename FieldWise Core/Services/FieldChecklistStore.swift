//
//  FieldChecklistStore.swift
//  Student Fieldwork App
//
//  Persists FieldTrip history to disk as JSON. No third-party dependencies,
//  consistent with the rest of the app (URLSession/MapKit/SwiftUI only).
//

import Foundation
import Combine

final class FieldChecklistStore: ObservableObject {

    @Published var trips: [FieldTrip] = []
    @Published var activeTripID: UUID?

    private let fileName = "field_checklist_trips.json"

    private var fileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    init() {
        load()
        if trips.isEmpty {
            startNewTrip(name: "Untitled Trip")
        } else {
            activeTripID = trips.first?.id
        }
    }

    // MARK: - Active trip helpers

    var activeTrip: FieldTrip? {
        guard let id = activeTripID else { return nil }
        return trips.first { $0.id == id }
    }

    var activeTripIndex: Int? {
        guard let id = activeTripID else { return nil }
        return trips.firstIndex { $0.id == id }
    }

    func startNewTrip(name: String, locationDescription: String = "", date: Date = Date()) {
        let trip = FieldTrip(name: name, locationDescription: locationDescription, date: date)
        trips.insert(trip, at: 0)
        activeTripID = trip.id
        save()
    }

    func selectTrip(_ trip: FieldTrip) {
        activeTripID = trip.id
    }

    func deleteTrip(_ trip: FieldTrip) {
        trips.removeAll { $0.id == trip.id }
        if activeTripID == trip.id {
            activeTripID = trips.first?.id
        }
        save()
    }

    func duplicateTrip(_ trip: FieldTrip) {
        var newTrip = trip
        newTrip.id = UUID()
        newTrip.name = trip.name + " (copy)"
        newTrip.date = Date()
        newTrip.createdAt = Date()
        newTrip.lastModifiedAt = Date()
        // Reset checked state on duplicate so it's ready for a new outing
        for sIndex in newTrip.sections.indices {
            for iIndex in newTrip.sections[sIndex].items.indices {
                newTrip.sections[sIndex].items[iIndex].isChecked = false
                newTrip.sections[sIndex].items[iIndex].checkedAt = nil
            }
        }
        trips.insert(newTrip, at: 0)
        activeTripID = newTrip.id
        save()
    }

    // MARK: - Mutating the active trip

    func updateActiveTrip(_ mutate: (inout FieldTrip) -> Void) {
        guard let index = activeTripIndex else { return }
        mutate(&trips[index])
        trips[index].lastModifiedAt = Date()
        save()
    }

    func toggleItem(sectionID: UUID, itemID: UUID) {
        updateActiveTrip { trip in
            guard let sIndex = trip.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIndex = trip.sections[sIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
            trip.sections[sIndex].items[iIndex].toggle()
        }
    }

    func addCustomItem(sectionID: UUID, title: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        updateActiveTrip { trip in
            guard let sIndex = trip.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            trip.sections[sIndex].items.append(
                FieldChecklistItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines), isCustom: true)
            )
        }
    }

    func removeItem(sectionID: UUID, itemID: UUID) {
        updateActiveTrip { trip in
            guard let sIndex = trip.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            trip.sections[sIndex].items.removeAll { $0.id == itemID }
        }
    }

    func toggleSectionExpanded(sectionID: UUID) {
        updateActiveTrip { trip in
            guard let sIndex = trip.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            trip.sections[sIndex].isExpanded.toggle()
        }
    }

    func linkObservation(sectionID: UUID, itemID: UUID, observationID: UUID?) {
        updateActiveTrip { trip in
            guard let sIndex = trip.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIndex = trip.sections[sIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
            trip.sections[sIndex].items[iIndex].linkedObservationID = observationID
        }
    }

    func updateTripMeta(name: String, locationDescription: String, date: Date) {
        updateActiveTrip { trip in
            trip.name = name
            trip.locationDescription = locationDescription
            trip.date = date
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder.fieldChecklist.encode(trips)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("FieldChecklistStore save error: \(error)")
        }
    }

    func load() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            trips = try JSONDecoder.fieldChecklist.decode([FieldTrip].self, from: data)
        } catch {
            print("FieldChecklistStore load error: \(error)")
            trips = []
        }
    }
}

// MARK: - Shared encoder/decoder

extension JSONEncoder {
    static var fieldChecklist: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var fieldChecklist: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
