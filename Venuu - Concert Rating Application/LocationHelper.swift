import Foundation
import CoreLocation

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var city: String?
    @Published var stateCode: String?
    @Published var countryCode: String?
    @Published var status: CLAuthorizationStatus?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() {
        status = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    // MARK: CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                if let p = placemarks.first {
                    // Prefer the city; fall back to subAdministrativeArea
                    self.city = p.locality ?? p.subAdministrativeArea
                    self.stateCode = p.administrativeArea // e.g. "CA"
                    self.countryCode = p.isoCountryCode   // e.g. "US"
                    print("Nearby using city:", self.city ?? "nil",
                          "state:", self.stateCode ?? "nil",
                          "country:", self.countryCode ?? "nil")
                }
            } catch {
                print("Reverse geocode error:", error.localizedDescription)
            }
        }
    }
}
