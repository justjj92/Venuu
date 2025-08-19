// GeoConcertManager.swift
import Foundation
import CoreLocation
import UserNotifications

/// Monitors regions for nearby concerts and fires a local notification on entry.
/// Geocodes by venue/city/country text (no city.state / coords dependency).
final class GeoConcertMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = GeoConcertMonitor()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastRefreshAt: Date?
    private var cache: [String: CLLocationCoordinate2D] = [:]

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    // Call once from App start
    func enable() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            manager.startUpdatingLocation()
        case .authorizedAlways:
            manager.startUpdatingLocation()
            Task { await refreshMonitoredRegions() }
        default:
            break
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            manager.startUpdatingLocation()
        case .authorizedAlways:
            manager.startUpdatingLocation()
            Task { await refreshMonitoredRegions() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Throttle refresh (20 minutes)
        if let last = lastRefreshAt, Date().timeIntervalSince(last) < 20*60 { return }
        Task { await refreshMonitoredRegions(around: loc) }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { await sendLocalNotificationForRegion(region.identifier) }
    }

    // MARK: Monitoring

    private func apply(regions: [CLCircularRegion]) {
        for r in manager.monitoredRegions {
            if let rr = r as? CLCircularRegion { manager.stopMonitoring(for: rr) }
        }
        for r in regions { manager.startMonitoring(for: r) }
    }

    private func refreshMonitoredRegions(around location: CLLocation? = nil) async {
        lastRefreshAt = Date()
        let loc = location ?? manager.location
        guard let loc else { return }

        // Reverse-geocode to city/state/country for a coarse nearby query
        let placemark = try? await reverse(loc)
        let city        = placemark?.locality ?? placemark?.subAdministrativeArea
        let stateCode   = placemark?.administrativeArea
        let countryCode = placemark?.isoCountryCode

        guard let city else { return }

        // Fetch “nearby” setlists by city (best effort)
        let items = (try? await SetlistAPI.shared.searchSetlists(
            cityName: city, stateCode: stateCode, countryCode: countryCode, page: 1
        )) ?? []

        // Build up to 20 geofences around their venues (forward-geocode address text)
        var regions: [CLCircularRegion] = []
        for s in items.prefix(20) {
            guard let coord = await coordinate(for: s) else { continue }
            let region = CLCircularRegion(center: coord, radius: 250, identifier: s.id)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            regions.append(region)
        }
        apply(regions: regions)
    }

    // MARK: Geocoding (forward + reverse)

    private func coordinate(for setlist: APISetlist) async -> CLLocationCoordinate2D? {
        if let cached = cache[setlist.id] { return cached }

        var parts: [String] = []
        if let v = setlist.venue?.name, !v.isEmpty { parts.append(v) }
        if let c = setlist.venue?.city?.name, !c.isEmpty { parts.append(c) }
        if let cc = setlist.venue?.city?.country?.name ?? setlist.venue?.city?.country?.code {
            parts.append(cc)
        }
        guard !parts.isEmpty else { return nil }

        let address = parts.joined(separator: ", ")
        guard let location = try? await forward(address) else { return nil }
        cache[setlist.id] = location.coordinate
        return location.coordinate
    }

    /// Forward-geocode an address string -> CLLocation. Uses async API on iOS 16+.
    private func forward(_ address: String) async throws -> CLLocation {
        if #available(iOS 16.0, *) {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let loc = placemarks.first?.location { return loc }
            throw NSError(domain: "geo", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No geocode result for \(address)"])
        } else {
            return try await withCheckedThrowingContinuation { cont in
                var resumed = false
                geocoder.geocodeAddressString(address) { placemarks, error in
                    guard !resumed else { return }
                    resumed = true
                    if let e = error { cont.resume(throwing: e); return }
                    if let loc = placemarks?.first?.location { cont.resume(returning: loc); return }
                    cont.resume(throwing: NSError(domain: "geo", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "No geocode result for \(address)"]))
                }
                // Safety timeout so we never leak the continuation
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                    if !resumed {
                        self.geocoder.cancelGeocode()
                        resumed = true
                        cont.resume(throwing: CancellationError())
                    }
                }
            }
        }
    }

    /// Reverse-geocode a location -> CLPlacemark. Uses async API on iOS 16+.
    private func reverse(_ location: CLLocation) async throws -> CLPlacemark {
        if #available(iOS 16.0, *) {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let pm = placemarks.first { return pm }
            throw NSError(domain: "geo", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No placemark for location"])
        } else {
            return try await withCheckedThrowingContinuation { cont in
                var resumed = false
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    guard !resumed else { return }
                    resumed = true
                    if let e = error { cont.resume(throwing: e); return }
                    if let pm = placemarks?.first { cont.resume(returning: pm); return }
                    cont.resume(throwing: NSError(domain: "geo", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "No placemark for location"]))
                }
                // Safety timeout so we never leak the continuation
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                    if !resumed {
                        self.geocoder.cancelGeocode()
                        resumed = true
                        cont.resume(throwing: CancellationError())
                    }
                }
            }
        }
    }

    // MARK: Local notification

    private func sendLocalNotificationForRegion(_ setlistId: String) async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "At a concert?"
        content.body  = "Want to save this show to your Venuu list?"
        content.sound = .default
        content.userInfo = ["setlistId": setlistId]

        let request = UNNotificationRequest(
            identifier: "save-\(setlistId)",
            content: content,
            trigger: nil // deliver immediately upon region entry
        )

        do {
            try await center.add(request)
        } catch {
            // Not fatal—just log it
            print("Failed to schedule local notification:", error)
        }
    }
}
