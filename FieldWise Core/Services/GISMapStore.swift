//
//  GISMapStore.swift
//  Student Fieldwork App
//
//  Persists GIS map pins, drawn shapes, and tracks as JSON via
//  FileManager, consistent with the rest of the app. Independent of
//  SiteFieldSheetStore's own persistence, but reads trip/site names from
//  it (passed in by the view) to populate the "link to a site" picker.
//

import Foundation
import Combine
import CoreLocation

final class GISMapStore: NSObject, ObservableObject {

    @Published var pins: [GISMapPin] = []
    @Published var shapes: [GISShape] = []
    @Published var tracks: [GISTrack] = []
    @Published var activeTrackID: UUID?

    // Live location for "follow me" / track recording.
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRecordingTrack: Bool = false

    // Full location detail for the Compass screen (elevation, accuracy).
    @Published var lastLocation: CLLocation?
    // Device heading for the Compass screen — shares this same manager
    // rather than creating a second CLLocationManager elsewhere.
    @Published var heading: CLHeading?
    @Published var headingAvailable: Bool = CLLocationManager.headingAvailable()

    /// Set by the Report tab to request the Map tab centre on a specific
    /// site's pins as soon as it appears (or becomes visible again).
    @Published var pendingFocus: MapFocusRequest?

    struct MapFocusRequest: Equatable {
        var tripID: UUID
        var siteSheetID: UUID
        var fallbackCoordinate: CLLocationCoordinate2D?

        static func == (lhs: MapFocusRequest, rhs: MapFocusRequest) -> Bool {
            lhs.tripID == rhs.tripID && lhs.siteSheetID == rhs.siteSheetID
        }
    }

    private let locationManager = CLLocationManager()
    private let fileName = "gis_map_data_v1.json"

    private var fileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Foreground-only for this phase. Background tracking (Always
        // authorization, allowsBackgroundLocationUpdates) is a planned
        // follow-up and intentionally not enabled yet.
        load()
    }

    // MARK: - Location permission (foreground only, this phase)

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Heading (compass)

    func startUpdatingHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Cross-tab focus request (used by "View on Map" in Report tab)

    func requestFocus(tripID: UUID, siteSheetID: UUID, fallbackCoordinate: CLLocationCoordinate2D?) {
        pendingFocus = MapFocusRequest(tripID: tripID, siteSheetID: siteSheetID, fallbackCoordinate: fallbackCoordinate)
    }

    /// Drops a pin for the given site at the device's current location
    /// (falling back to the map's last known region centre if location
    /// isn't available yet), pre-linked to that trip/site.
    @discardableResult
    func dropPinForSite(tripID: UUID, siteSheetID: UUID, siteName: String, at coordinate: CLLocationCoordinate2D) -> GISMapPin {
        var pin = GISMapPin(coordinate: GISCoordinate(coordinate), title: siteName.isEmpty ? "Site pin" : siteName)
        pin.linkedTripID = tripID
        pin.linkedSiteSheetID = siteSheetID
        pins.append(pin)
        save()
        return pin
    }

    // MARK: - Pins

    func addPin(at coordinate: CLLocationCoordinate2D, title: String = "New observation point") {
        pins.append(GISMapPin(coordinate: GISCoordinate(coordinate), title: title))
        save()
    }

    func updatePin(_ id: UUID, mutate: (inout GISMapPin) -> Void) {
        guard let index = pins.firstIndex(where: { $0.id == id }) else { return }
        mutate(&pins[index])
        save()
    }

    func removePin(_ id: UUID) {
        pins.removeAll { $0.id == id }
        save()
    }

    // MARK: - Shapes

    func addShape(_ shape: GISShape) {
        shapes.append(shape)
        save()
    }

    func updateShape(_ id: UUID, mutate: (inout GISShape) -> Void) {
        guard let index = shapes.firstIndex(where: { $0.id == id }) else { return }
        mutate(&shapes[index])
        save()
    }

    func removeShape(_ id: UUID) {
        shapes.removeAll { $0.id == id }
        save()
    }

    // MARK: - Tracks (foreground recording)

    func startTrack(title: String = "Field track") {
        let track = GISTrack(title: title)
        tracks.append(track)
        activeTrackID = track.id
        isRecordingTrack = true
        startUpdatingLocation()
        save()
    }

    func stopActiveTrack() {
        guard let id = activeTrackID, let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[index].endedAt = Date()
        activeTrackID = nil
        isRecordingTrack = false
        stopUpdatingLocation()
        save()
    }

    func removeTrack(_ id: UUID) {
        tracks.removeAll { $0.id == id }
        if activeTrackID == id { activeTrackID = nil; isRecordingTrack = false }
        save()
    }

    private func appendPointToActiveTrack(_ location: CLLocation) {
        guard let id = activeTrackID, let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        let point = GISTrack.TrackPoint(
            coordinate: GISCoordinate(location.coordinate),
            timestamp: location.timestamp,
            altitude: location.altitude
        )
        tracks[index].points.append(point)
    }

    // MARK: - Persistence

    func save() {
        let payload = GISMapPersistencePayload(pins: pins, shapes: shapes, tracks: tracks)
        do {
            let data = try JSONEncoder.gisMap.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("GISMapStore save error: \(error)")
        }
    }

    func load() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            let payload = try JSONDecoder.gisMap.decode(GISMapPersistencePayload.self, from: data)
            pins = payload.pins
            shapes = payload.shapes
            tracks = payload.tracks
        } catch {
            print("GISMapStore load error: \(error)")
        }
    }
}

private struct GISMapPersistencePayload: Codable {
    var pins: [GISMapPin]
    var shapes: [GISShape]
    var tracks: [GISTrack]
}

extension JSONEncoder {
    static var gisMap: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var gisMap: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - CLLocationManagerDelegate

extension GISMapStore: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        currentLocation = latest.coordinate
        lastLocation = latest
        if isRecordingTrack {
            appendPointToActiveTrack(latest)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GISMapStore location error: \(error)")
    }
}
