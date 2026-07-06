//
//  MunsellSoilColorPickerView.swift
//  Student Fieldwork App
//
//  UI for the Munsell soil colour picker — a nested "dropdown within a
//  dropdown" matching the existing GeoObservationGroupView pattern.
//  Outer DisclosureGroup lists every chart; tapping a chart opens its
//  own swatch grid where the student taps a colour, rates the match,
//  and optionally adds a note. Selections are stored as MunsellSelection
//  records on the active SiteFieldSheet.
//

import SwiftUI

// MARK: - Root section (sits in the observation groups list)

struct MunsellSoilColorSectionView: View {
    @ObservedObject var store: SiteFieldSheetStore
    let selections: [MunsellSelection]
    @State private var isExpanded = false
    @State private var expandedChartHue: String? = nil
    @State private var showingSwatchDetail: (chart: MunsellChart, swatch: MunsellSwatch)? = nil

    var body: some View {
        Section {
            if isExpanded {
                if !selections.isEmpty {
                    savedSelectionsRow
                }

                ForEach(MunsellSoilColorCatalog.allCharts) { chart in
                    MunsellChartDisclosureRow(
                        chart: chart,
                        isOpen: expandedChartHue == chart.id,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedChartHue = expandedChartHue == chart.id ? nil : chart.id
                            }
                        },
                        onSelectSwatch: { swatch in
                            showingSwatchDetail = (chart, swatch)
                        }
                    )
                }

                Text("Charts marked “provisional” use placeholder colours, not an official Munsell chart, and should be treated as a rough guide only.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        } header: {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "eyedropper.halffull")
                        .foregroundStyle(Color("GeoAmberDark"))
                    Text("Soil colour (Munsell)")
                    Spacer()
                    if !selections.isEmpty {
                        Text("\(selections.count) recorded")
                            .font(.caption)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)
        }
        .sheet(item: Binding(
            get: { showingSwatchDetail.map { SwatchDetailWrapper(chart: $0.chart, swatch: $0.swatch) } },
            set: { _ in showingSwatchDetail = nil }
        )) { wrapper in
            MunsellSwatchDetailSheet(
                chart: wrapper.chart,
                swatch: wrapper.swatch,
                onSave: { rating, note in
                    store.addMunsellSelection(
                        chartHue: wrapper.swatch.hueTag ?? wrapper.chart.hue,
                        swatch: wrapper.swatch,
                        suppressName: wrapper.chart.suppressesNameInUI,
                        rating: rating,
                        note: note
                    )
                    showingSwatchDetail = nil
                }
            )
        }
    }

    private var savedSelectionsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recorded soil colours")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(selections) { selection in
                MunsellSelectionRow(
                    selection: selection,
                    onDelete: { store.removeMunsellSelection(id: selection.id) }
                )
            }
        }
        .padding(.bottom, 4)
    }
}

/// Identifiable wrapper so `.sheet(item:)` can present chart+swatch together.
private struct SwatchDetailWrapper: Identifiable {
    let chart: MunsellChart
    let swatch: MunsellSwatch
    var id: String { "\(chart.id)-\(swatch.id)" }
}

// MARK: - One chart row (the "dropdown within a dropdown")

struct MunsellChartDisclosureRow: View {
    let chart: MunsellChart
    let isOpen: Bool
    let onToggle: () -> Void
    let onSelectSwatch: (MunsellSwatch) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    swatchPreviewStrip
                    VStack(alignment: .leading, spacing: 1) {
                        Text(chart.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if chart.isPlaceholder {
                            Text("Provisional — not yet verified")
                                .font(.system(size: 10))
                                .foregroundStyle(Color("GeoCoral"))
                        }
                    }
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if isOpen {
                if chart.usesListLayout {
                    VStack(spacing: 6) {
                        ForEach(chart.swatches) { swatch in
                            MunsellSwatchListRow(
                                swatch: swatch,
                                onTap: { onSelectSwatch(swatch) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(chart.swatches) { swatch in
                            MunsellSwatchCell(
                                swatch: swatch,
                                suppressName: chart.suppressesNameInUI,
                                onTap: { onSelectSwatch(swatch) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    /// A tiny 5-chip preview of the chart's colour range, shown next to its name.
    private var swatchPreviewStrip: some View {
        HStack(spacing: 2) {
            ForEach(previewSample, id: \.id) { swatch in
                Circle()
                    .fill(swatch.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
            }
        }
    }

    private var previewSample: [MunsellSwatch] {
        let all = chart.swatches
        guard all.count > 5 else { return all }
        let stride = max(1, all.count / 5)
        return Swift.stride(from: 0, to: all.count, by: stride).prefix(5).map { all[$0] }
    }
}

// MARK: - List-style row (for charts with distinct descriptions, e.g. common soils)

struct MunsellSwatchListRow: View {
    let swatch: MunsellSwatch
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(swatch.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(swatch.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(swatch.notation(hue: swatch.hueTag ?? ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let context = swatch.context, !context.isEmpty {
                        Text(context)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(8)
            .background(Color("GeoSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Individual swatch cell in the grid

struct MunsellSwatchCell: View {
    let swatch: MunsellSwatch
    let suppressName: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(swatch.color)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                    )
                Text(suppressName ? "\(swatch.value)/\(swatch.chroma)" : swatch.value + "/" + swatch.chroma)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                if !suppressName && !swatch.name.isEmpty {
                    Text(swatch.name)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swatch detail / save sheet

struct MunsellSwatchDetailSheet: View {
    let chart: MunsellChart
    let swatch: MunsellSwatch
    let onSave: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 3
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(swatch.color)
                            .frame(width: 64, height: 64)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                        VStack(alignment: .leading, spacing: 3) {
                            if chart.suppressesNameInUI {
                                Text("Colour match")
                                    .font(.headline)
                            } else {
                                Text(swatch.name)
                                    .font(.headline)
                                Text(swatch.notation(hue: swatch.hueTag ?? chart.hue))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let context = swatch.context, !context.isEmpty {
                                    Text(context)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section("How confident is this match?") {
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundStyle(star <= rating ? Color("GeoAmber") : .secondary)
                                .font(.system(size: 22))
                                .onTapGesture { rating = star }
                        }
                        Spacer()
                        Text(ratingLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Notes (optional)") {
                    TextField("e.g. matched on moist soil, mid-profile", text: $note, axis: .vertical)
                }

                if chart.isPlaceholder {
                    Section {
                        Label("This chart's colours are provisional and not yet verified against an official Munsell chart.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Color("GeoCoral"))
                    }
                }
            }
            .navigationTitle("Record Soil Colour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(rating, note) }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Poor match"
        case 2: return "Rough match"
        case 3: return "Reasonable"
        case 4: return "Good match"
        case 5: return "Excellent match"
        default: return ""
        }
    }
}

// MARK: - Saved selection row (shown above the chart list once any exist)

struct MunsellSelectionRow: View {
    let selection: MunsellSelection
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: selection.hex))
                .frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(selection.name.isEmpty ? selection.notation : selection.name.capitalized)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= selection.qualityRating ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundStyle(star <= selection.qualityRating ? Color("GeoAmber") : .secondary.opacity(0.4))
                    }
                }
                if !selection.note.isEmpty {
                    Text(selection.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color("GeoSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
