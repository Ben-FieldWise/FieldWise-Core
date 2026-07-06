//
//  GISMapView.swift
//  Student Fieldwork App
//
//  Replaces the old simple SiteMapView (Weather > Site map). Full-screen
//  interactive MapKit view (NOT inside a ScrollView — pan/zoom gestures
//  need the whole gesture space) with:
//   - Standard / Satellite / Hybrid / Topographic (contour lines) styles
//   - Pin dropping, linked optionally to a SiteFieldSheet site
//   - Line (transect) and polygon (quadrat/area) drawing with live
//     distance / area measurement
//   - Foreground GPS track recording
//
//  Background track recording is a planned follow-up and intentionally
//  not implemented here — see GISMapStore's location permission comment.
//

import SwiftUI
import MapKit

// MARK: - Root view (drop-in replacement for SiteMapView)

struct GISMapView: View {
    @EnvironmentObject var siteSheetStore: SiteFieldSheetStore
    @EnvironmentObject var gisStore: GISMapStore

    @State private var mapStyle: GISMapStyle = .standard
    @State private var drawingMode: DrawingMode = .none
    @State private var inProgressPoints: [GISCoordinate] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5, longitude: -2.5),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )
    @State private var query = ""
    @State private var showingSaveSheet = false
    @State private var showingLayerMenu = false
    @State private var selectedPin: GISMapPin?
    @State private var selectedShape: GISShape?

    enum DrawingMode: Equatable {
        case none, droppingPin, line, polygon
    }

    var body: some View {
        ZStack(alignment: .top) {
            GISMapRepresentable(
                region: $region,
                mapStyle: mapStyle,
                pins: gisStore.pins,
                shapes: gisStore.shapes,
                tracks: gisStore.tracks,
                inProgressPoints: inProgressPoints,
                drawingMode: drawingMode,
                currentLocation: gisStore.currentLocation,
                onMapTap: handleMapTap,
                onPinTap: { selectedPin = $0 },
                onShapeTap: { selectedShape = $0 }
            )
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                searchBar
                toolStrip
                if drawingMode != .none {
                    drawingStatusBar
                }
                Spacer()
                if gisStore.isRecordingTrack {
                    trackRecordingBar
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // OpenStreetMap / OpenTopoMap attribution — required by tile
            // usage policy, must remain visible (not hidden behind a toggle).
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    attributionLabel
                }
            }
            .padding(8)
        }
        .sheet(item: $selectedPin) { pin in
            PinDetailSheet(
                pin: pin,
                siteSheetStore: siteSheetStore,
                onSave: { updated in
                    gisStore.updatePin(updated.id) { $0 = updated }
                    selectedPin = nil
                },
                onDelete: {
                    gisStore.removePin(pin.id)
                    selectedPin = nil
                }
            )
        }
        .sheet(item: $selectedShape) { shape in
            ShapeDetailSheet(
                shape: shape,
                siteSheetStore: siteSheetStore,
                onSave: { updated in
                    gisStore.updateShape(updated.id) { $0 = updated }
                    selectedShape = nil
                },
                onDelete: {
                    gisStore.removeShape(shape.id)
                    selectedShape = nil
                }
            )
        }
        .onAppear {
            gisStore.requestLocationPermission()
            applyPendingFocus()
        }
        .onChange(of: gisStore.pendingFocus) {
            applyPendingFocus()
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                TextField("Search field site…", text: $query)
                    .font(.system(size: 14))
                    .onSubmit { Task { await searchAndMove() } }
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            Menu {
                ForEach(GISMapStyle.allCases) { style in
                    Button {
                        mapStyle = style
                    } label: {
                        Label(style.displayName, systemImage: style.symbolName)
                    }
                }
            } label: {
                Image(systemName: mapStyle.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color("GeoGreenDark"))
                    .frame(width: 38, height: 38)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }

    // MARK: - Drawing tool strip

    private var toolStrip: some View {
        HStack(spacing: 8) {
            toolButton(icon: "mappin", label: "Pin", active: drawingMode == .droppingPin) {
                toggleMode(.droppingPin)
            }
            toolButton(icon: "line.diagonal", label: "Line", active: drawingMode == .line) {
                toggleMode(.line)
            }
            toolButton(icon: "pentagon", label: "Area", active: drawingMode == .polygon) {
                toggleMode(.polygon)
            }

            Spacer()

            if drawingMode == .line || drawingMode == .polygon {
                Button {
                    finishDrawing()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color("GeoGreen"))
                        .clipShape(Capsule())
                }
            }

            Button {
                if gisStore.isRecordingTrack {
                    gisStore.stopActiveTrack()
                } else {
                    gisStore.startTrack()
                }
            } label: {
                Image(systemName: gisStore.isRecordingTrack ? "stop.circle.fill" : "location.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(gisStore.isRecordingTrack ? Color("GeoCoral") : Color("GeoGreenDark"))
                    .frame(width: 38, height: 38)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }

    private func toolButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(active ? .white : Color("GeoGreenDark"))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(active ? Color("GeoGreen") : .white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
    }

    private func toggleMode(_ mode: DrawingMode) {
        if drawingMode == mode {
            cancelDrawing()
        } else {
            inProgressPoints = []
            drawingMode = mode
        }
    }

    private func cancelDrawing() {
        drawingMode = .none
        inProgressPoints = []
    }

    // MARK: - Drawing status bar

    private var drawingStatusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color("GeoBlue"))
                .font(.system(size: 13))
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Button("Cancel") { cancelDrawing() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color("GeoCoral"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private var statusText: String {
        switch drawingMode {
        case .droppingPin:
            return "Tap the map to drop a pin"
        case .line:
            let dist = approxLength(inProgressPoints)
            return inProgressPoints.isEmpty
                ? "Tap to start a line"
                : "\(inProgressPoints.count) points — \(formatDistance(dist))"
        case .polygon:
            let area = approxArea(inProgressPoints)
            return inProgressPoints.isEmpty
                ? "Tap to start an area"
                : "\(inProgressPoints.count) points — \(formatArea(area))"
        case .none:
            return ""
        }
    }

    // MARK: - Track recording bar

    private var trackRecordingBar: some View {
        HStack(spacing: 10) {
            Circle().fill(Color("GeoCoral")).frame(width: 8, height: 8)
            Text("Recording track")
                .font(.system(size: 12, weight: .semibold))
            if let track = gisStore.tracks.first(where: { $0.id == gisStore.activeTrackID }) {
                Text(formatDistance(track.distanceMeters))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Stop") { gisStore.stopActiveTrack() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color("GeoCoral"))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    // MARK: - Attribution (required by OSM / OpenTopoMap tile usage policy)

    private var attributionLabel: some View {
        Group {
            if mapStyle == .topographic {
                Text("© OpenTopoMap (CC-BY-SA) · © OpenStreetMap contributors")
            } else {
                Text("© OpenStreetMap contributors")
            }
        }
        .font(.system(size: 9))
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - Map interaction

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch drawingMode {
        case .droppingPin:
            gisStore.addPin(at: coordinate)
            drawingMode = .none
        case .line, .polygon:
            inProgressPoints.append(GISCoordinate(coordinate))
        case .none:
            break
        }
    }

    private func finishDrawing() {
        guard inProgressPoints.count >= 2 else {
            cancelDrawing()
            return
        }
        let kind: GISShapeKind = drawingMode == .polygon ? .polygon : .line
        let shape = GISShape(kind: kind, points: inProgressPoints, title: kind == .polygon ? "New area" : "New transect")
        gisStore.addShape(shape)
        selectedShape = shape
        cancelDrawing()
    }

    /// Handles a "View on Map" request from the Report tab — centers the
    /// map on the requested site's pins (or its single drop point if no
    /// pins exist yet) and clears the request so it doesn't re-trigger.
    private func applyPendingFocus() {
        guard let focus = gisStore.pendingFocus else { return }

        let matchingPins = gisStore.pins.filter { $0.linkedSiteSheetID == focus.siteSheetID }
        if let coordinate = matchingPins.first?.coordinate.clCoordinate {
            withAnimation {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        } else if let fallback = focus.fallbackCoordinate {
            withAnimation {
                region = MKCoordinateRegion(
                    center: fallback,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
        gisStore.pendingFocus = nil
    }

    private func searchAndMove() async {
        do {
            let result = try await GeocodingService.shared.search(query: query)
            await MainActor.run {
                withAnimation {
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            }
        } catch {}
    }

    // MARK: - Measurement helpers (live, while drawing)

    private func approxLength(_ points: [GISCoordinate]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<(points.count - 1) {
            let a = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let b = CLLocation(latitude: points[i + 1].latitude, longitude: points[i + 1].longitude)
            total += a.distance(from: b)
        }
        return total
    }

    private func approxArea(_ points: [GISCoordinate]) -> Double {
        guard points.count >= 3 else { return 0 }
        let refLat = points[0].latitude * .pi / 180
        let mPerLat = 111_320.0
        let mPerLon = 111_320.0 * cos(refLat)
        let projected = points.map { (x: $0.longitude * mPerLon, y: $0.latitude * mPerLat) }
        var area: Double = 0
        for i in 0..<projected.count {
            let j = (i + 1) % projected.count
            area += projected[i].x * projected[j].y - projected[j].x * projected[i].y
        }
        return abs(area) / 2.0
    }
}

// MARK: - Shared formatting helpers

func formatDistance(_ meters: Double) -> String {
    meters >= 1000 ? String(format: "%.2f km", meters / 1000) : String(format: "%.0f m", meters)
}

func formatArea(_ squareMeters: Double) -> String {
    squareMeters >= 10_000 ? String(format: "%.2f ha", squareMeters / 10_000) : String(format: "%.0f m²", squareMeters)
}
