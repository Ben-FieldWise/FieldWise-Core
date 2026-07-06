//
//  CompassView.swift
//  Student Fieldwork App
//
//  Full-screen compass: rotating heading dial (true + magnetic),
//  live GPS coordinates with accuracy, and elevation derived from
//  CLLocation's own GPS/barometric blend (no extra permission or
//  network call — this is the same altitude figure Apple Maps shows).
//
//  Shares GISMapStore's single CLLocationManager rather than creating
//  a second one, so location/heading state stays consistent with the
//  Map screen.
//

import SwiftUI
import CoreLocation
import UIKit

struct CompassView: View {
    @EnvironmentObject var gisStore: GISMapStore
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            if !gisStore.headingAvailable {
                unavailableNotice
            }

            Spacer(minLength: 12)

            compassDial
                .frame(maxWidth: 320, maxHeight: 320)
                .padding(.horizontal, 24)

            headingReadout

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                coordinateCard
                elevationCard
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 16)
        }
        .background(Color("GeoSurface"))
        .onAppear {
            gisStore.requestLocationPermission()
            gisStore.startUpdatingLocation()
            gisStore.startUpdatingHeading()
        }
        .onDisappear {
            gisStore.stopUpdatingHeading()
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("Coordinates copied")
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

    // MARK: - Unavailable notice (e.g. simulator, or a device without a magnetometer)

    private var unavailableNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color("GeoAmberDark"))
            Text("Compass hardware not available on this device — heading will not update.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color("GeoAmber").opacity(0.15))
    }

    // MARK: - Compass dial

    private var compassDial: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 2)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                // Degree ticks
                ForEach(0..<72, id: \.self) { i in
                    let isMajor = i % 18 == 0     // every 90°
                    let isMedium = i % 6 == 0     // every 30°
                    Rectangle()
                        .fill(isMajor ? Color("GeoGreenDark") : Color.black.opacity(isMedium ? 0.4 : 0.15))
                        .frame(width: isMajor ? 2.5 : 1, height: isMajor ? 16 : (isMedium ? 11 : 6))
                        .offset(y: -size / 2 + (isMajor ? 14 : (isMedium ? 11 : 8)))
                        .rotationEffect(.degrees(Double(i) * 5))
                }

                // Cardinal labels — rotate opposite to heading so they
                // stay screen-relative (the needle moves, not the dial),
                // which is the more intuitive convention for fieldwork.
                ForEach(cardinalPoints, id: \.label) { point in
                    Text(point.label)
                        .font(.system(size: point.label.count == 1 ? 20 : 13, weight: .bold))
                        .foregroundColor(point.label == "N" ? Color("GeoCoral") : .secondary)
                        .offset(y: -size / 2 + 34)
                        .rotationEffect(.degrees(point.degrees))
                }

                // Centre hub
                Circle()
                    .fill(Color("GeoGreenDark"))
                    .frame(width: 10, height: 10)

                // Needle — rotates with heading
                CompassNeedle()
                    .fill(Color("GeoCoral"))
                    .frame(width: size * 0.06, height: size * 0.42)
                    .offset(y: -size * 0.21)
                    .rotationEffect(.degrees(-currentHeadingDegrees))
                    .animation(.easeOut(duration: 0.2), value: currentHeadingDegrees)
            }
            .rotationEffect(.degrees(-currentHeadingDegrees))
            .overlay(
                // Fixed "you are facing this way" pointer at the top,
                // independent of dial rotation.
                Triangle()
                    .fill(Color("GeoGreenDark"))
                    .frame(width: 16, height: 12)
                    .offset(y: -size / 2 - 4)
            )
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private var cardinalPoints: [(label: String, degrees: Double)] {
        [
            ("N", 0), ("NE", 45), ("E", 90), ("SE", 135),
            ("S", 180), ("SW", 225), ("W", 270), ("NW", 315)
        ]
    }

    private var currentHeadingDegrees: Double {
        guard let heading = gisStore.heading else { return 0 }
        let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        return value
    }

    // MARK: - Heading readout

    private var headingReadout: some View {
        VStack(spacing: 4) {
            Text("\(Int(currentHeadingDegrees.rounded()))°")
                .font(.system(size: 40, weight: .light, design: .rounded))
            Text(compassDirectionLabel(for: currentHeadingDegrees))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color("GeoGreenDark"))

            if let heading = gisStore.heading {
                HStack(spacing: 14) {
                    Text("True: \(Int(heading.trueHeading.rounded()))°")
                    Text("Magnetic: \(Int(heading.magneticHeading.rounded()))°")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
        .padding(.top, 12)
    }

    private func compassDirectionLabel(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                           "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees / 22.5).rounded()) % 16
        return directions[(index + 16) % 16]
    }

    // MARK: - Coordinate card

    private var coordinateCard: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("GPS coordinates", systemImage: "location.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let location = gisStore.lastLocation {
                        Button {
                            copyCoordinates(location.coordinate)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13))
                                .foregroundColor(Color("GeoGreen"))
                        }
                    }
                }

                if let location = gisStore.lastLocation {
                    HStack {
                        coordinateColumn(label: "Latitude", value: String(format: "%.6f°", location.coordinate.latitude))
                        Divider().frame(height: 30)
                        coordinateColumn(label: "Longitude", value: String(format: "%.6f°", location.coordinate.longitude))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Accuracy ±\(Int(location.horizontalAccuracy))m")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Waiting for GPS signal…")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func coordinateColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copyCoordinates(_ coordinate: CLLocationCoordinate2D) {
        UIPasteboard.general.string = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showCopiedToast = false }
        }
    }

    // MARK: - Elevation card

    private var elevationCard: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Elevation", systemImage: "mountain.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                if let location = gisStore.lastLocation, location.verticalAccuracy >= 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", location.altitude))
                            .font(.system(size: 30, weight: .light, design: .rounded))
                        Text("m above sea level")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Accuracy ±\(Int(location.verticalAccuracy))m")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Elevation reading not yet available")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text("Derived from this device's GPS (blended with barometric pressure on supported models) — the same figure Apple Maps shows.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shapes

private struct CompassNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w / 2, y: h * 0.8))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
