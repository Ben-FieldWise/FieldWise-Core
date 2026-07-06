import SwiftUI
import MapKit
import Combine

// MARK: - Weather Root

struct WeatherRootView: View {
    @State private var selectedTab = 0
    @State private var searchResult: GeocodingResult? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Weather").tag(0)
                    Text("On-day obs").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("GeoSurface"))

                Divider() // Added a clean border separator below the sub-menu

                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case 0: WeatherView(searchResult: $searchResult)
                        case 1: FieldObservationsView()
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 20)
                }
                .background(Color("GeoSurface"))
            }
            .background(Color("GeoSurface"))
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline) // Changed to inline to eliminate vertical stacking collision
            .helpButton()
        }
    }
}

// MARK: - Weather View

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var response: WeatherResponse? = nil
    @Published var locationName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var searchResult: GeocodingResult? = nil

    func search(query: String) async {
        guard !query.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let geo = try await GeocodingService.shared.search(query: query)
            searchResult = geo
            locationName = String(geo.name.split(separator: ",").prefix(3).joined(separator: ","))
            let weather = try await WeatherService.shared.fetchWeather(lat: geo.latitude, lon: geo.longitude)
            response = weather
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct WeatherView: View {
    @StateObject private var vm = WeatherViewModel()
    @Binding var searchResult: GeocodingResult?
    @State private var query = ""

    var body: some View {
        VStack(spacing: 12) {
            SearchBar(text: $query, placeholder: "Enter field site (e.g. Dartmoor, River Wye…)") {
                Task { await vm.search(query: query); searchResult = vm.searchResult }
            }

            if vm.isLoading {
                LoadingCard(message: "Fetching weather for \(query)…")
            } else if let error = vm.errorMessage {
                ErrorCard(message: error)
            } else if let weather = vm.response {
                WeatherHeroCard(current: weather.current, locationName: vm.locationName)
                WeatherStatsRow(current: weather.current)
                SuitabilityCard(current: weather.current)
                ForecastStrip(daily: weather.daily)
            } else {
                EmptyWeatherCard()
            }
        }
    }
}

struct WeatherHeroCard: View {
    let current: CurrentWeather
    let locationName: String

    var info: WeatherInfo { WeatherInfo.from(code: current.weatherCode) }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(current.temperature2m.rounded()))°C")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(.white)
                Text(info.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
                Text(locationName)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: info.symbolName)
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(Color("GeoGreenDark"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct WeatherStatsRow: View {
    let current: CurrentWeather

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            WeatherStatCell(label: "Feels like", value: "\(Int(current.apparentTemperature.rounded()))°C")
            WeatherStatCell(label: "Wind speed", value: "\(Int(current.windSpeed10m.rounded())) km/h")
            WeatherStatCell(label: "Humidity", value: "\(Int(current.relativeHumidity2m.rounded()))%")
            if let vis = current.visibility {
                WeatherStatCell(label: "Visibility", value: String(format: "%.1f km", vis / 1000))
            } else {
                WeatherStatCell(label: "Visibility", value: "—")
            }
        }
    }
}

struct WeatherStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
    }
}

struct SuitabilityCard: View {
    let current: CurrentWeather

    var checks: [SuitabilityCheck] { SuitabilityCheck.evaluate(current: current) }
    var overall: SuitabilityCheck.Status { SuitabilityCheck.overallStatus(checks: checks) }

    var overallBadge: (String, Color, Color) {
        switch overall {
        case .good:    return ("Good to go", Color("GeoGreen").opacity(0.15), Color("GeoGreen"))
        case .caution: return ("Caution", Color("GeoAmber").opacity(0.2), Color("GeoAmberDark"))
        case .unsafe:  return ("Unsafe", Color("GeoCoral").opacity(0.15), Color("GeoCoral"))
        }
    }

    var body: some View {
        GeoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Fieldwork suitability", systemImage: "backpack.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    BadgeView(text: overallBadge.0, backgroundColor: overallBadge.1, foregroundColor: overallBadge.2)
                }
                VStack(spacing: 8) {
                    ForEach(checks) { check in
                        HStack(spacing: 10) {
                            Image(systemName: check.status.icon)
                                .foregroundColor(check.status.color)
                                .font(.system(size: 14))
                            Text(check.label)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(check.value) — \(check.note)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(check.status.color)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 180, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

struct ForecastStrip: View {
    let daily: DailyWeather
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("5-day forecast")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(daily.time.prefix(5).enumerated()), id: \.offset) { idx, dateStr in
                        let info = WeatherInfo.from(code: daily.weatherCode[idx])
                        let date = parseDate(dateStr)
                        let rain = daily.precipitationProbabilityMax[idx] ?? 0

                        VStack(spacing: 6) {
                            Text(date.map { dayNames[Calendar.current.component(.weekday, from: $0) - 1] } ?? "—")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Image(systemName: info.symbolName)
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("\(Int(daily.temperature2mMax[idx].rounded()))° / \(Int(daily.temperature2mMin[idx].rounded()))°")
                                .font(.system(size: 12, weight: .semibold))
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill").font(.system(size: 9)).foregroundColor(Color("GeoBlue"))
                                Text("\(rain)%").font(.system(size: 11)).foregroundColor(Color("GeoBlue"))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

struct EmptyWeatherCard: View {
    var body: some View {
        GeoCard {
            VStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Enter a location above to check current conditions and fieldwork suitability")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}

struct LoadingCard: View {
    let message: String
    var body: some View {
        GeoCard {
            HStack(spacing: 12) {
                ProgressView().tint(Color("GeoGreen"))
                Text(message).font(.system(size: 14)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

struct ErrorCard: View {
    let message: String
    var body: some View {
        GeoCard {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(Color("GeoCoral"))
                Text(message).font(.system(size: 14)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Field Observations

struct FieldObservationsView: View {
    @EnvironmentObject var store: ChecklistStore

    var body: some View {
        VStack(spacing: 10) {
            GeoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("On-day conditions", systemImage: "thermometer.sun.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    ObsPicker(label: "Cloud cover", icon: "cloud.fill",
                              selection: $store.observation.cloudCover,
                              options: ["Clear (0–10%)", "Mostly clear (10–30%)", "Partly cloudy (30–60%)", "Mostly cloudy (60–90%)", "Overcast (90–100%)"])

                    ObsPicker(label: "Wind (Beaufort scale)", icon: "wind",
                              selection: $store.observation.windCondition,
                              options: ["Calm (0)", "Light air (1)", "Light breeze (2)", "Gentle breeze (3)", "Moderate breeze (4)", "Fresh breeze (5)", "Strong breeze (6)", "Near gale (7+)"])

                    ObsPicker(label: "Precipitation", icon: "drop.fill",
                              selection: $store.observation.precipitation,
                              options: ["None — dry", "Light drizzle", "Moderate rain", "Heavy rain", "Intermittent showers", "Hail / sleet", "Snow"])

                    ObsPicker(label: "Temperature feel", icon: "thermometer",
                              selection: $store.observation.temperature,
                              options: ["Very cold (below 5°C)", "Cold (5–10°C)", "Cool (10–15°C)", "Mild (15–20°C)", "Warm (20–25°C)", "Hot (above 25°C)"])

                    ObsPicker(label: "Visibility", icon: "eye.fill",
                              selection: $store.observation.visibility,
                              options: ["Excellent (10+ km)", "Good (4–10 km)", "Moderate (1–4 km)", "Poor (200m–1 km)", "Very poor — fog"])

                    ObsPicker(label: "Recent weather impact", icon: "arrow.clockwise",
                              selection: $store.observation.recentWeatherImpact,
                              options: ["Dry — no recent rain", "Damp — light rain recently", "Muddy — heavy rain 24h", "Flooding — river high", "Frost overnight", "Dry / cracked — heatwave"])
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Anomaly / weather notes", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("GeoAmberDark"))
                GeoTextField(placeholder: "e.g. Heavy rain last night — river significantly higher. Turbid water, inconsistent flow readings.",
                             text: $store.observation.additionalNotes, axis: .vertical)
            }
            .padding(14)
            .background(Color(red: 1.0, green: 0.98, blue: 0.93))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            PrimaryButton(title: "Auto-fill from selections", iconName: "wand.and.stars") {
                let note = store.observation.autoNote
                if !note.isEmpty { store.observation.additionalNotes = note }
            }
        }
    }
}

struct ObsPicker: View {
    let label: String
    let icon: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color("GeoGreen"))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            Picker(label, selection: $selection) {
                Text("Select…").tag("")
                ForEach(options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color("GeoSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .onSubmit(onSubmit)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))

            Button(action: onSubmit) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color("GeoGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}