//
//  GISMapRepresentable.swift
//  Student Fieldwork App
//
//  UIViewRepresentable bridge to MKMapView. Renders pins, drawn shapes
//  (lines/polygons), GPS tracks, the in-progress drawing polyline, and
//  the topographic contour tile overlay. Handles tap gestures for both
//  dropping pins and adding drawing points.
//

import SwiftUI
import MapKit

struct GISMapRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let mapStyle: GISMapStyle
    let pins: [GISMapPin]
    let shapes: [GISShape]
    let tracks: [GISTrack]
    let inProgressPoints: [GISCoordinate]
    let drawingMode: GISMapView.DrawingMode
    let currentLocation: CLLocationCoordinate2D?
    let onMapTap: (CLLocationCoordinate2D) -> Void
    let onPinTap: (GISMapPin) -> Void
    let onShapeTap: (GISShape) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.showsScale = true

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tapGesture)

        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.mapType = mapStyle.mkMapType

        // Topographic overlay: add/remove the contour tile layer.
        let hasTopoOverlay = mapView.overlays.contains { $0 is TopographicTileOverlay }
        if mapStyle == .topographic && !hasTopoOverlay {
            let overlay = TopographicTileOverlay()
            overlay.canReplaceMapContent = false
            mapView.addOverlay(overlay, level: .aboveLabels)
        } else if mapStyle != .topographic && hasTopoOverlay {
            mapView.overlays.filter { $0 is TopographicTileOverlay }.forEach { mapView.removeOverlay($0) }
        }

        context.coordinator.syncContent(
            mapView: mapView,
            pins: pins,
            shapes: shapes,
            tracks: tracks,
            inProgressPoints: inProgressPoints,
            drawingMode: drawingMode
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GISMapRepresentable
        private var pinByAnnotation: [ObjectIdentifier: GISMapPin] = [:]
        private var shapeByOverlay: [ObjectIdentifier: GISShape] = [:]

        init(_ parent: GISMapRepresentable) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }

        func syncContent(
            mapView: MKMapView,
            pins: [GISMapPin],
            shapes: [GISShape],
            tracks: [GISTrack],
            inProgressPoints: [GISCoordinate],
            drawingMode: GISMapView.DrawingMode
        ) {
            // --- Pins ---
            let existingPinAnnotations = mapView.annotations.compactMap { $0 as? GISPinAnnotation }
            mapView.removeAnnotations(existingPinAnnotations)
            pinByAnnotation.removeAll()

            for pin in pins {
                let annotation = GISPinAnnotation(pin: pin)
                mapView.addAnnotation(annotation)
                pinByAnnotation[ObjectIdentifier(annotation)] = pin
            }

            // --- Shapes (committed lines/polygons) ---
            let existingShapeOverlays = mapView.overlays.filter { $0 is GISLineOverlay || $0 is GISPolygonOverlay }
            mapView.removeOverlays(existingShapeOverlays)
            shapeByOverlay.removeAll()

            for shape in shapes {
                let coords = shape.points.map { $0.clCoordinate }
                guard coords.count >= 2 else { continue }
                if shape.kind == .line {
                    let overlay = GISLineOverlay(coordinates: coords, count: coords.count)
                    overlay.shapeID = shape.id
                    overlay.colorHex = shape.colorHex
                    mapView.addOverlay(overlay)
                    shapeByOverlay[ObjectIdentifier(overlay)] = shape
                } else {
                    let overlay = GISPolygonOverlay(coordinates: coords, count: coords.count)
                    overlay.shapeID = shape.id
                    overlay.colorHex = shape.colorHex
                    mapView.addOverlay(overlay)
                    shapeByOverlay[ObjectIdentifier(overlay)] = shape
                }
            }

            // --- In-progress drawing preview ---
            mapView.overlays.filter { $0 is GISInProgressOverlay }.forEach { mapView.removeOverlay($0) }
            if drawingMode != .none, inProgressPoints.count >= 2 {
                let coords = inProgressPoints.map { $0.clCoordinate }
                let overlay = GISInProgressOverlay(coordinates: coords, count: coords.count)
                overlay.isPolygon = (drawingMode == .polygon)
                mapView.addOverlay(overlay)
            }

            // --- Tracks ---
            mapView.overlays.filter { $0 is GISTrackOverlay }.forEach { mapView.removeOverlay($0) }
            for track in tracks where track.points.count >= 2 {
                let coords = track.points.map { $0.coordinate.clCoordinate }
                let overlay = GISTrackOverlay(coordinates: coords, count: coords.count)
                overlay.isActive = track.isActive
                mapView.addOverlay(overlay)
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pinAnnotation = annotation as? GISPinAnnotation else { return nil }
            let identifier = "GISPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
            view.annotation = pinAnnotation
            view.markerTintColor = UIColor(Color(hex: pinAnnotation.pin.colorHex))
            view.glyphImage = UIImage(systemName: pinAnnotation.pin.symbolName)
            view.canShowCallout = true
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let pinAnnotation = annotation as? GISPinAnnotation else { return }
            parent.onPinTap(pinAnnotation.pin)
            mapView.deselectAnnotation(annotation, animated: false)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? TopographicTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let line = overlay as? GISLineOverlay {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor(Color(hex: line.colorHex))
                renderer.lineWidth = 3
                return renderer
            }
            if let polygon = overlay as? GISPolygonOverlay {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let color = UIColor(Color(hex: polygon.colorHex))
                renderer.strokeColor = color
                renderer.fillColor = color.withAlphaComponent(0.18)
                renderer.lineWidth = 2.5
                return renderer
            }
            if let inProgress = overlay as? GISInProgressOverlay {
                let renderer: MKOverlayPathRenderer
                if inProgress.isPolygon {
                    let polygon = MKPolygon(coordinates: inProgress.coordinatesArray, count: inProgress.coordinatesArray.count)
                    let polygonRenderer = MKPolygonRenderer(polygon: polygon)
                    polygonRenderer.fillColor = UIColor(Color("GeoBlue")).withAlphaComponent(0.15)
                    renderer = polygonRenderer
                } else {
                    let polyline = MKPolyline(coordinates: inProgress.coordinatesArray, count: inProgress.coordinatesArray.count)
                    renderer = MKPolylineRenderer(polyline: polyline)
                }
                renderer.strokeColor = UIColor(Color("GeoBlue"))
                renderer.lineWidth = 3
                renderer.lineDashPattern = [6, 4]
                return renderer
            }
            if let track = overlay as? GISTrackOverlay {
                let renderer = MKPolylineRenderer(polyline: track)
                renderer.strokeColor = UIColor(Color(track.isActive ? "GeoCoral" : "GeoAmberDark"))
                renderer.lineWidth = 3.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

// MARK: - Custom annotation / overlay subclasses (carry our model IDs)

final class GISPinAnnotation: NSObject, MKAnnotation {
    let pin: GISMapPin
    var coordinate: CLLocationCoordinate2D { pin.coordinate.clCoordinate }
    var title: String? { pin.title }
    var subtitle: String? { pin.note.isEmpty ? nil : pin.note }

    init(pin: GISMapPin) {
        self.pin = pin
    }
}

final class GISLineOverlay: MKPolyline {
    var shapeID: UUID?
    var colorHex: String = "1A6FA8"
}

final class GISPolygonOverlay: MKPolygon {
    var shapeID: UUID?
    var colorHex: String = "1A6FA8"
}

final class GISTrackOverlay: MKPolyline {
    var isActive: Bool = false
}

final class GISInProgressOverlay: MKPolyline {
    var isPolygon: Bool = false
    var coordinatesArray: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
