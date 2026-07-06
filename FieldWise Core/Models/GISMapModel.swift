//
//  GISMapModel.swift
//  Student Fieldwork App
//
//  Data model for the GIS Map tab: map pins (observation points),
//  drawn shapes (lines for transects, polygons for quadrats/areas), and
//  the topographic contour tile overlay. Pins and shapes can optionally
//  link back to a specific FieldSheetTrip / SiteFieldSheet so tapping a
//  pin can surface that site's recorded data.
//
//  Persists as JSON via FileManager, consistent with the rest of the app.
//

import Foundation
import MapKit
import SwiftUI

// MARK: - Coordinate (Codable wrapper for CLLocationCoordinate2D)

struct GISCoordinate: Codable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Map Pin

/// A single observation point dropped on the map. Optionally tagged to
/// a trip/site so tapping it can show that site's field sheet data.
struct GISMapPin: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var coordinate: GISCoordinate
    var title: String = "New observation point"
    var note: String = ""
    var symbolName: String = "mappin.circle.fill"
    var colorHex: String = "2D6A4F" // GeoGreen by default

    /// If set, this pin represents (or links to) a site recorded in
    /// SiteFieldSheetStore — tapping it can deep-link to that site sheet.
    var linkedTripID: UUID?
    var linkedSiteSheetID: UUID?

    var createdAt: Date = Date()
}

// MARK: - Drawn Shape (line or polygon)

enum GISShapeKind: String, Codable, CaseIterable {
    case line     // transect, route
    case polygon  // quadrat boundary, study area

    var displayName: String {
        switch self {
        case .line: return "Line / transect"
        case .polygon: return "Polygon / area"
        }
    }

    var symbolName: String {
        switch self {
        case .line: return "line.diagonal"
        case .polygon: return "pentagon"
        }
    }
}

struct GISShape: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: GISShapeKind
    var points: [GISCoordinate] = []
    var title: String = ""
    var note: String = ""
    var colorHex: String = "1A6FA8" // GeoBlue by default

    var linkedTripID: UUID?
    var linkedSiteSheetID: UUID?

    var createdAt: Date = Date()

    /// Total length in metres for a line, or perimeter for a polygon.
    var lengthMeters: Double {
        guard points.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<(points.count - 1) {
            total += distance(points[i], points[i + 1])
        }
        if kind == .polygon, points.count > 2 {
            total += distance(points[points.count - 1], points[0])
        }
        return total
    }

    /// Approximate area in square metres for a polygon (planar shoelace
    /// formula projected via equirectangular approximation — adequate
    /// for small fieldwork-scale areas, not for large/polar regions).
    var areaSquareMeters: Double {
        guard kind == .polygon, points.count >= 3 else { return 0 }
        let refLat = points[0].latitude * .pi / 180
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(refLat)

        let projected = points.map { pt -> (x: Double, y: Double) in
            (x: pt.longitude * metersPerDegLon, y: pt.latitude * metersPerDegLat)
        }
        var area: Double = 0
        for i in 0..<projected.count {
            let j = (i + 1) % projected.count
            area += projected[i].x * projected[j].y
            area -= projected[j].x * projected[i].y
        }
        return abs(area) / 2.0
    }

    private func distance(_ a: GISCoordinate, _ b: GISCoordinate) -> Double {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - GPS Track (foreground recording; background is a later phase)

struct GISTrack: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = "Field track"
    var points: [TrackPoint] = []
    var startedAt: Date = Date()
    var endedAt: Date?
    var linkedTripID: UUID?
    var linkedSiteSheetID: UUID?

    struct TrackPoint: Codable, Equatable {
        var coordinate: GISCoordinate
        var timestamp: Date
        var altitude: Double?
    }

    var isActive: Bool { endedAt == nil }

    var distanceMeters: Double {
        guard points.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<(points.count - 1) {
            let loc1 = CLLocation(latitude: points[i].coordinate.latitude, longitude: points[i].coordinate.longitude)
            let loc2 = CLLocation(latitude: points[i + 1].coordinate.latitude, longitude: points[i + 1].coordinate.longitude)
            total += loc1.distance(from: loc2)
        }
        return total
    }

    var durationSeconds: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }
}

// MARK: - Map style (including topo)

enum GISMapStyle: String, Codable, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid
    case topographic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        case .topographic: return "Topographic"
        }
    }

    var symbolName: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas.fill"
        case .hybrid: return "photo.on.rectangle"
        case .topographic: return "mountain.2"
        }
    }

    var mkMapType: MKMapType {
        switch self {
        case .standard: return .standard
        case .satellite: return .satellite
        case .hybrid: return .hybrid
        case .topographic: return .standard // base layer; contours render via tile overlay on top
        }
    }
}

// MARK: - Topographic tile overlay (OpenTopoMap)

/// Contour-line topographic tiles from OpenTopoMap (OSM + SRTM data,
/// CC-BY-SA). Free, no API key. Per OSMF tile usage policy this must
/// show visible attribution and identify itself with a real User-Agent —
/// both handled here and in GISMapView. Bulk/offline downloading is not
/// permitted; this overlay only fetches the tiles visible in the current
/// viewport, matching normal interactive use, and relies on URLCache for
/// standard HTTP caching rather than any custom prefetch/bulk logic.
final class TopographicTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: "https://tile.opentopomap.org/{z}/{x}/{y}.png")
        self.canReplaceMapContent = false
        self.maximumZ = 17
        self.minimumZ = 2
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        URL(string: "https://tile.opentopomap.org/\(path.z)/\(path.x)/\(path.y).png")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        var request = URLRequest(url: url(forTilePath: path))
        // Identifies this app to the tile server, as required by the
        // OSMF tile usage policy (no generic SDK default User-Agent).
        request.setValue("FieldWiseGeography-iOS-StudentFieldworkApp/1.0", forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            result(data, error)
        }
        task.resume()
    }
}
