import Foundation
import CoreLocation

// MARK: - Weather Service

class WeatherService {
    static let shared = WeatherService()

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherResponse {
        let urlString = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(lat)&longitude=\(lon)" +
            "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,visibility" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
            "&timezone=auto&forecast_days=5"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WeatherResponse.self, from: data)
    }

    enum WeatherError: LocalizedError {
        case invalidURL
        case invalidResponse
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:        return "Invalid URL"
            case .invalidResponse:   return "Server error — please try again"
            case .decodingFailed:    return "Could not read weather data"
            }
        }
    }
}

// MARK: - Geocoding Service

struct GeocodingResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
}

class GeocodingService {
    static let shared = GeocodingService()

    func search(query: String) async throws -> GeocodingResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&limit=1"

        guard let url = URL(string: urlString) else {
            throw GeocodingError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.setValue("FieldWise Geography iOS App", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        let results = try JSONDecoder().decode([NominatimResult].self, from: data)

        guard let first = results.first else {
            throw GeocodingError.notFound
        }

        return GeocodingResult(
            name: first.displayName,
            latitude: Double(first.lat) ?? 0,
            longitude: Double(first.lon) ?? 0
        )
    }

    enum GeocodingError: LocalizedError {
        case invalidQuery
        case notFound

        var errorDescription: String? {
            switch self {
            case .invalidQuery: return "Invalid search query"
            case .notFound:     return "Location not found — try a more specific name"
            }
        }
    }
}

private struct NominatimResult: Codable {
    let lat: String
    let lon: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case lat, lon
        case displayName = "display_name"
    }
}
