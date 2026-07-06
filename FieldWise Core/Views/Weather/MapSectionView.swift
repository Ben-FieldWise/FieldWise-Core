//
//  MapSectionView.swift
//  Student Fieldwork App
//
//  Top-level "Map" tab (5th tab in ContentView). Internally switches
//  between the full GIS map and a separate full-screen Compass panel —
//  per design decision, these are alternate screens, not simultaneous
//  overlays, so only one location-consuming view is active at a time.
//

import SwiftUI

struct MapSectionView: View {
    @State private var selectedMode = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedMode) {
                    Text("Map").tag(0)
                    Text("Compass").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("GeoSurface"))

                Divider()

                Group {
                    switch selectedMode {
                    case 0: GISMapView()
                    case 1: CompassView()
                    default: EmptyView()
                    }
                }
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Map & Compass")
            .navigationBarTitleDisplayMode(.inline)
            .helpButton()
        }
    }
}
