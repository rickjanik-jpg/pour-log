import Foundation
import CoreLocation
import MapKit
import Observation

/// Gets one GPS fix on demand and looks up nearby bars and restaurants.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var authContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var fixContinuation: CheckedContinuation<CLLocation?, Never>?

    var authorization: CLAuthorizationStatus = .notDetermined
    var denied: Bool { authorization == .denied || authorization == .restricted }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorization = manager.authorizationStatus
    }

    /// Asks permission the first time, then returns a fresh location (or nil if refused).
    func currentLocation() async -> CLLocation? {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                authContinuation = c
                manager.requestWhenInUseAuthorization()
            }
        }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        if let recent = manager.location, abs(recent.timestamp.timeIntervalSinceNow) < 60 {
            return recent
        }
        return await withCheckedContinuation { (c: CheckedContinuation<CLLocation?, Never>) in
            fixContinuation?.resume(returning: nil)
            fixContinuation = c
            manager.requestLocation()
        }
    }

    /// Bars, restaurants, breweries etc. within ~150 m, closest first.
    func nearbyPlaces(around loc: CLLocation) async -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(center: loc.coordinate, radius: 150)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .nightlife, .restaurant, .brewery, .winery, .cafe, .hotel
        ])
        do {
            let response = try await MKLocalSearch(request: request).start()
            func dist(_ item: MKMapItem) -> CLLocationDistance {
                item.placemark.location?.distance(from: loc) ?? .greatestFiniteMagnitude
            }
            return response.mapItems.sorted { dist($0) < dist($1) }
        } catch {
            return []
        }
    }

    /// "Des Moines, IA"
    func cityName(for loc: CLLocation) async -> String {
        guard let p = try? await CLGeocoder().reverseGeocodeLocation(loc).first else { return "" }
        return [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status != .notDetermined {
                self.authContinuation?.resume()
                self.authContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            self.fixContinuation?.resume(returning: latest)
            self.fixContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.fixContinuation?.resume(returning: nil)
            self.fixContinuation = nil
        }
    }
}
