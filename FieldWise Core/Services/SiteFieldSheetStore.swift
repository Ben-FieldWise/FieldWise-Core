//
//  SiteFieldSheetStore.swift
//  Student Fieldwork App
//
//  Self-contained ObservableObject store for FieldSheetTrip / SiteFieldSheet.
//  Persists trip JSON to Documents/site_field_sheets.json and saves photos
//  as individual JPEG files under Documents/SiteFieldPhotos/. Deliberately
//  independent of FieldChecklistStore so it doesn't touch the existing
//  checklist/survey/report model files.
//

import Foundation
import UIKit
import Combine

final class SiteFieldSheetStore: ObservableObject {

    @Published var trips: [FieldSheetTrip] = []
    @Published var activeTripID: UUID?
    @Published var activeSiteSheetID: UUID?

    private let fileName = "site_field_sheets.json"
    private let photosDirectoryName = "SiteFieldPhotos"

    private var fileURL: URL {
        documentsDirectory.appendingPathComponent(fileName)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var photosDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent(photosDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    init() {
        load()
        if trips.isEmpty {
            startNewTrip(name: "Untitled Trip")
        } else {
            activeTripID = trips.first?.id
            activeSiteSheetID = trips.first?.siteSheets.first?.id
        }
    }

    // MARK: - Active trip / site helpers

    var activeTrip: FieldSheetTrip? {
        guard let id = activeTripID else { return nil }
        return trips.first { $0.id == id }
    }

    var activeTripIndex: Int? {
        guard let id = activeTripID else { return nil }
        return trips.firstIndex { $0.id == id }
    }

    var activeSiteSheet: SiteFieldSheet? {
        guard let trip = activeTrip, let sid = activeSiteSheetID else { return nil }
        return trip.siteSheets.first { $0.id == sid }
    }

    func selectTrip(_ trip: FieldSheetTrip) {
        activeTripID = trip.id
        activeSiteSheetID = trip.siteSheets.first?.id
    }

    func selectSiteSheet(_ sheet: SiteFieldSheet) {
        activeSiteSheetID = sheet.id
    }

    // MARK: - Trip management

    func startNewTrip(name: String, locationDescription: String = "", date: Date = Date()) {
        var trip = FieldSheetTrip(name: name, locationDescription: locationDescription, date: date)
        let firstSite = SiteFieldSheet(siteName: "Site 1", dateVisited: date)
        trip.siteSheets = [firstSite]
        trips.insert(trip, at: 0)
        activeTripID = trip.id
        activeSiteSheetID = firstSite.id
        save()
    }

    func deleteTrip(_ trip: FieldSheetTrip) {
        // Clean up any photos belonging to this trip before removing it.
        for sheet in trip.siteSheets {
            deleteAllPhotoFiles(for: sheet)
        }
        trips.removeAll { $0.id == trip.id }
        if activeTripID == trip.id {
            activeTripID = trips.first?.id
            activeSiteSheetID = trips.first?.siteSheets.first?.id
        }
        save()
    }

    func updateTripMeta(name: String, locationDescription: String, date: Date) {
        updateActiveTrip { trip in
            trip.name = name
            trip.locationDescription = locationDescription
            trip.date = date
        }
    }

    // MARK: - Site sheet management

    func addSiteSheet(name: String? = nil) {
        updateActiveTrip { trip in
            let nextNumber = trip.siteSheets.count + 1
            let sheet = SiteFieldSheet(siteName: name ?? "Site \(nextNumber)", dateVisited: trip.date)
            trip.siteSheets.append(sheet)
            self.activeSiteSheetID = sheet.id
        }
    }

    func deleteSiteSheet(_ sheet: SiteFieldSheet) {
        deleteAllPhotoFiles(for: sheet)
        updateActiveTrip { trip in
            trip.siteSheets.removeAll { $0.id == sheet.id }
        }
        if activeSiteSheetID == sheet.id {
            activeSiteSheetID = activeTrip?.siteSheets.first?.id
        }
    }

    func duplicateSiteSheet(_ sheet: SiteFieldSheet) {
        updateActiveTrip { trip in
            guard let index = trip.siteSheets.firstIndex(where: { $0.id == sheet.id }) else { return }
            var copy = sheet
            copy.id = UUID()
            copy.siteName = sheet.siteName + " (copy)"
            copy.createdAt = Date()
            copy.lastModifiedAt = Date()
            // Fresh copy starts with no photos and unchecked state, ready for a new site
            copy.sitePhotos = []
            for sIndex in copy.sections.indices {
                for iIndex in copy.sections[sIndex].items.indices {
                    copy.sections[sIndex].items[iIndex].isCompleted = false
                    copy.sections[sIndex].items[iIndex].notes = ""
                    copy.sections[sIndex].items[iIndex].photos = []
                }
            }
            for gIndex in copy.observationGroups.indices {
                copy.observationGroups[gIndex].groupNote = ""
                for tIndex in copy.observationGroups[gIndex].terms.indices {
                    copy.observationGroups[gIndex].terms[tIndex].isChecked = false
                    copy.observationGroups[gIndex].terms[tIndex].note = ""
                }
            }
            trip.siteSheets.insert(copy, at: index + 1)
            self.activeSiteSheetID = copy.id
        }
    }

    // MARK: - Mutating the active trip / site sheet

    func updateActiveTrip(_ mutate: (inout FieldSheetTrip) -> Void) {
        guard let index = activeTripIndex else { return }
        mutate(&trips[index])
        trips[index].lastModifiedAt = Date()
        save()
    }

    func updateActiveSiteSheet(_ mutate: (inout SiteFieldSheet) -> Void) {
        guard let tIndex = activeTripIndex, let sid = activeSiteSheetID else { return }
        guard let sIndex = trips[tIndex].siteSheets.firstIndex(where: { $0.id == sid }) else { return }
        mutate(&trips[tIndex].siteSheets[sIndex])
        trips[tIndex].siteSheets[sIndex].lastModifiedAt = Date()
        trips[tIndex].lastModifiedAt = Date()
        save()
    }

    func updateSiteMeta(siteName: String, siteNumber: String, gridReference: String, weatherSummary: String) {
        updateActiveSiteSheet { sheet in
            sheet.siteName = siteName
            sheet.siteNumber = siteNumber
            sheet.gridReference = gridReference
            sheet.weatherSummary = weatherSummary
        }
    }

    func updateOverallNotes(_ notes: String) {
        updateActiveSiteSheet { $0.overallNotes = notes }
    }

    // MARK: - Checklist item mutations

    func toggleItem(sectionID: UUID, itemID: UUID) {
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIndex = sheet.sections[sIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
            sheet.sections[sIndex].items[iIndex].isCompleted.toggle()
        }
    }

    func updateItemNotes(sectionID: UUID, itemID: UUID, notes: String) {
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIndex = sheet.sections[sIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
            sheet.sections[sIndex].items[iIndex].notes = notes
        }
    }

    func addCustomItem(sectionID: UUID, title: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            sheet.sections[sIndex].items.append(
                SiteSheetItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines), isCustom: true)
            )
        }
    }

    func removeItem(sectionID: UUID, itemID: UUID) {
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            let item = sheet.sections[sIndex].items.first { $0.id == itemID }
            if let item { self.deletePhotoFiles(item.photos) }
            sheet.sections[sIndex].items.removeAll { $0.id == itemID }
        }
    }

    func toggleSectionExpanded(sectionID: UUID) {
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            sheet.sections[sIndex].isExpanded.toggle()
        }
    }

    // MARK: - Observation group (checkbox) mutations

    func toggleTerm(groupID: UUID, termID: UUID) {
        updateActiveSiteSheet { sheet in
            guard let gIndex = sheet.observationGroups.firstIndex(where: { $0.id == groupID }) else { return }
            guard let tIndex = sheet.observationGroups[gIndex].terms.firstIndex(where: { $0.id == termID }) else { return }
            sheet.observationGroups[gIndex].terms[tIndex].isChecked.toggle()
        }
    }

    func updateTermNote(groupID: UUID, termID: UUID, note: String) {
        updateActiveSiteSheet { sheet in
            guard let gIndex = sheet.observationGroups.firstIndex(where: { $0.id == groupID }) else { return }
            guard let tIndex = sheet.observationGroups[gIndex].terms.firstIndex(where: { $0.id == termID }) else { return }
            sheet.observationGroups[gIndex].terms[tIndex].note = note
        }
    }

    func updateGroupNote(groupID: UUID, note: String) {
        updateActiveSiteSheet { sheet in
            guard let gIndex = sheet.observationGroups.firstIndex(where: { $0.id == groupID }) else { return }
            sheet.observationGroups[gIndex].groupNote = note
        }
    }

    // MARK: - Munsell soil colour mutations

    /// Records a new soil colour match. `suppressName` mirrors the source
    /// chart's `suppressesNameInUI` flag — when true the Munsell code is
    /// still stored (it's the universal reference notation) but the name
    /// string is left blank so the UI never displays it for that chart.
    func addMunsellSelection(chartHue: String, swatch: MunsellSwatch, suppressName: Bool, rating: Int, note: String) {
        let selection = MunsellSelection(
            chartHue: chartHue,
            value: swatch.value,
            chroma: swatch.chroma,
            hex: swatch.hex,
            name: suppressName ? "" : swatch.name,
            qualityRating: rating,
            note: note
        )
        updateActiveSiteSheet { sheet in
            sheet.munsellSelections.append(selection)
        }
    }

    func removeMunsellSelection(id: UUID) {
        updateActiveSiteSheet { sheet in
            sheet.munsellSelections.removeAll { $0.id == id }
        }
    }

    // MARK: - Photo management (site-level)

    func addSitePhoto(_ image: UIImage, caption: String = "") {
        guard let photo = savePhoto(image, caption: caption) else { return }
        updateActiveSiteSheet { sheet in
            sheet.sitePhotos.append(photo)
        }
    }

    func removeSitePhoto(_ photo: FieldPhoto) {
        deletePhotoFiles([photo])
        updateActiveSiteSheet { sheet in
            sheet.sitePhotos.removeAll { $0.id == photo.id }
        }
    }

    // MARK: - Photo management (item-level gallery)

    func addItemPhoto(sectionID: UUID, itemID: UUID, image: UIImage, caption: String = "") {
        guard let photo = savePhoto(image, caption: caption) else { return }
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIndex = sheet.sections[sIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
            sheet.sections[sIndex].items[iIndex].photos.append(photo)
        }
    }

    func removeItemPhoto(sectionID: UUID, itemID: UUID, photo: FieldPhoto) {
        deletePhotoFiles([photo])
        updateActiveSiteSheet { sheet in
            guard let sIndex = sheet.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            guard let iIndex = sheet.sections[sIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
            sheet.sections[sIndex].items[iIndex].photos.removeAll { $0.id == photo.id }
        }
    }

    /// Loads a UIImage for a FieldPhoto from disk. Returns nil if missing.
    func loadImage(for photo: FieldPhoto) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(photo.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Photo file helpers

    private func savePhoto(_ image: UIImage, caption: String) -> FieldPhoto? {
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        let photo = FieldPhoto(fileName: UUID().uuidString + ".jpg", caption: caption)
        let url = photosDirectory.appendingPathComponent(photo.fileName)
        do {
            try data.write(to: url, options: .atomic)
            return photo
        } catch {
            print("SiteFieldSheetStore photo save error: \(error)")
            return nil
        }
    }

    private func deletePhotoFiles(_ photos: [FieldPhoto]) {
        for photo in photos {
            let url = photosDirectory.appendingPathComponent(photo.fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func deleteAllPhotoFiles(for sheet: SiteFieldSheet) {
        deletePhotoFiles(sheet.sitePhotos)
        for section in sheet.sections {
            for item in section.items {
                deletePhotoFiles(item.photos)
            }
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder.siteFieldSheet.encode(trips)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("SiteFieldSheetStore save error: \(error)")
        }
    }

    func load() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            trips = try JSONDecoder.siteFieldSheet.decode([FieldSheetTrip].self, from: data)
        } catch {
            print("SiteFieldSheetStore load error: \(error)")
            trips = []
        }
    }
}

// MARK: - Shared encoder/decoder

extension JSONEncoder {
    static var siteFieldSheet: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var siteFieldSheet: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
