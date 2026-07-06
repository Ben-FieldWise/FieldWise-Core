import Combine
import Foundation
import SwiftUI

// MARK: - Weather Response

struct WeatherResponse: Codable {
    let current: CurrentWeather
    let daily: DailyWeather
}

struct CurrentWeather: Codable {
    let temperature2m: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let windSpeed10m: Double
    let relativeHumidity2m: Double
    let visibility: Double?

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case relativeHumidity2m = "relative_humidity_2m"
        case visibility
    }
}

struct DailyWeather: Codable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationProbabilityMax: [Int?]

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }
}

// MARK: - Weather Code

struct WeatherInfo {
    let description: String
    let symbolName: String
    let isHazardous: Bool

    static func from(code: Int) -> WeatherInfo {
        switch code {
        case 0:       return WeatherInfo(description: "Clear sky", symbolName: "sun.max.fill", isHazardous: false)
        case 1, 2:    return WeatherInfo(description: "Partly cloudy", symbolName: "cloud.sun.fill", isHazardous: false)
        case 3:       return WeatherInfo(description: "Overcast", symbolName: "cloud.fill", isHazardous: false)
        case 45, 48:  return WeatherInfo(description: "Fog / mist", symbolName: "cloud.fog.fill", isHazardous: true)
        case 51...57: return WeatherInfo(description: "Drizzle", symbolName: "cloud.drizzle.fill", isHazardous: false)
        case 61...67: return WeatherInfo(description: "Rain", symbolName: "cloud.rain.fill", isHazardous: false)
        case 71...77: return WeatherInfo(description: "Snow", symbolName: "snowflake", isHazardous: true)
        case 80...82: return WeatherInfo(description: "Rain showers", symbolName: "cloud.heavyrain.fill", isHazardous: false)
        case 95...99: return WeatherInfo(description: "Thunderstorm", symbolName: "cloud.bolt.rain.fill", isHazardous: true)
        default:      return WeatherInfo(description: "Unknown", symbolName: "questionmark.circle.fill", isHazardous: false)
        }
    }
}

// MARK: - Suitability

struct SuitabilityCheck: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let note: String
    let status: Status

    enum Status {
        case good, caution, unsafe

        var color: Color {
            switch self {
            case .good:    return Color("GeoGreen")
            case .caution: return Color("GeoAmber")
            case .unsafe:  return Color("GeoCoral")
            }
        }

        var icon: String {
            switch self {
            case .good:    return "checkmark.circle.fill"
            case .caution: return "exclamationmark.triangle.fill"
            case .unsafe:  return "xmark.circle.fill"
            }
        }
    }

    static func evaluate(current: CurrentWeather) -> [SuitabilityCheck] {
        let temp = current.temperature2m
        let wind = current.windSpeed10m
        let humid = current.relativeHumidity2m
        let code = current.weatherCode

        return [
            SuitabilityCheck(
                label: "Temperature",
                value: "\(Int(temp.rounded()))°C",
                note: temp < 5 ? "Cold — extra layers needed" : temp > 30 ? "Hot — sun protection" : "Comfortable range",
                status: temp < 0 || temp > 35 ? .unsafe : (temp < 5 || temp > 28 ? .caution : .good)
            ),
            SuitabilityCheck(
                label: "Wind",
                value: "\(Int(wind.rounded())) km/h",
                note: wind > 50 ? "Dangerous — postpone" : wind > 30 ? "Gusty — secure equipment" : "Manageable",
                status: wind > 50 ? .unsafe : (wind > 30 ? .caution : .good)
            ),
            SuitabilityCheck(
                label: "Precipitation",
                value: code <= 2 ? "None" : code <= 49 ? "Fog" : code <= 67 ? "Rain" : "Severe",
                note: code > 80 ? "Unsafe — postpone fieldwork" : code > 49 ? "Bring waterproofs" : code > 2 ? "Low visibility" : "Clear conditions",
                status: code > 80 ? .unsafe : (code > 2 ? .caution : .good)
            ),
            SuitabilityCheck(
                label: "Humidity",
                value: "\(Int(humid.rounded()))%",
                note: humid > 90 ? "Mist / fog likely" : humid > 80 ? "Recording sheets may dampen" : "Fine",
                status: humid > 90 ? .caution : .good
            )
        ]
    }

    static func overallStatus(checks: [SuitabilityCheck]) -> Status {
        if checks.contains(where: { $0.status == .unsafe }) { return .unsafe }
        if checks.contains(where: { $0.status == .caution }) { return .caution }
        return .good
    }
}

// MARK: - Field Observation

struct FieldObservation: Codable {
    var cloudCover: String = ""
    var windCondition: String = ""
    var precipitation: String = ""
    var temperature: String = ""
    var visibility: String = ""
    var recentWeatherImpact: String = ""
    var additionalNotes: String = ""

    var autoNote: String {
        let parts = [cloudCover, windCondition, precipitation, temperature, visibility, recentWeatherImpact]
            .filter { !$0.isEmpty && $0 != "None — dry" }
        return parts.isEmpty ? "" : parts.joined(separator: ". ") + "."
    }
}

// MARK: - Checklist Store

class ChecklistStore: ObservableObject {
    @Published var observation: FieldObservation {
        didSet { save() }
    }

    private let key = "geofield_obs_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(FieldObservation.self, from: data) {
            self.observation = decoded
        } else {
            self.observation = FieldObservation()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(observation) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
