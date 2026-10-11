import CoreLocation
import Foundation

/// 대시보드용 실시간 시각·대략적 위치(도시 수준). 데이터는 기기 밖으로 전송하지 않음.
@MainActor
final class LocalContextService: NSObject, ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var locationLabel = "위치 확인 중…"

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var clockTimer: Timer?
    private var lastGeocodedLocation: CLLocation?
    private var geocodeTask: Task<Void, Never>?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm:ss"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 500
    }

    func start() {
        now = Date()
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
        refreshLocationAuthorization()
    }

    func stop() {
        clockTimer?.invalidate()
        clockTimer = nil
        geocodeTask?.cancel()
        locationManager.stopUpdatingLocation()
    }

    var timeTitle: String {
        Self.timeFormatter.string(from: now)
    }

    var dateLabel: String {
        Self.dateFormatter.string(from: now)
    }

    var locationAndDateSubtitle: String {
        "\(locationLabel) · \(dateLabel)"
    }

    var timeOfDayEmoji: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<11: return "🌅"
        case 11..<17: return "☀️"
        case 17..<21: return "🌇"
        default: return "🌙"
        }
    }

    private func refreshLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            locationLabel = "위치 확인 중…"
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            locationLabel = "위치 권한 필요"
        @unknown default:
            locationLabel = "위치를 사용할 수 없음"
        }
    }

    private func updateLocationLabel(for location: CLLocation) async {
        if let lastGeocodedLocation,
           location.distance(from: lastGeocodedLocation) < 500 {
            return
        }

        geocodeTask?.cancel()
        geocodeTask = Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard !Task.isCancelled else { return }
                locationLabel = Self.formatPlacemark(placemarks.first) ?? "현재 위치"
                lastGeocodedLocation = location
            } catch {
                guard !Task.isCancelled else { return }
                if locationLabel == "위치 확인 중…" {
                    locationLabel = "위치를 표시할 수 없음"
                }
            }
        }
    }

    private static func formatPlacemark(_ placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }

        var parts: [String] = []
        if let locality = placemark.locality, !locality.isEmpty {
            parts.append(locality)
        } else if let subAdmin = placemark.subAdministrativeArea, !subAdmin.isEmpty {
            parts.append(subAdmin)
        } else if let admin = placemark.administrativeArea, !admin.isEmpty {
            parts.append(admin)
        }

        if let country = placemark.country, !country.isEmpty {
            if parts.isEmpty {
                parts.append(country)
            } else if !parts.contains(country) {
                parts.append(country)
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

extension LocalContextService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshLocationAuthorization()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await updateLocationLabel(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if locationLabel == "위치 확인 중…" {
                locationLabel = "위치를 가져올 수 없음"
            }
        }
    }
}
