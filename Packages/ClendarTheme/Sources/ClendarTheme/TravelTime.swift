//
//  TravelTime.swift
//  ClendarTheme
//
//  Travel time to appointments (issue #176). Car and walk use live
//  MapKit routes. MapKit has no cycling routes, so bike scales the walking
//  route time and is always marked as an estimate.
//

import CoreLocation
import EventKit
import Foundation
import MapKit

public enum TravelMode: String, CaseIterable {
    case car
    case walk
    case bike

    public static var titles: [String] { allCases.map(\.localizedText) }

    public static var defaultValue: Self { .car }

    public var localizedText: String {
        switch self {
        case .car: return NSLocalizedString("Car", comment: "")
        case .walk: return NSLocalizedString("Walk", comment: "")
        case .bike: return NSLocalizedString("Bike", comment: "")
        }
    }

    public static func mapFromText(_ text: String?) -> Self {
        switch text {
        case TravelMode.car.localizedText: return .car
        case TravelMode.walk.localizedText: return .walk
        case TravelMode.bike.localizedText: return .bike
        default: return .defaultValue
        }
    }

    public var systemImageName: String {
        switch self {
        case .car: return "car.fill"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        }
    }

    public var symbol: String {
        switch self {
        case .car: return "🚗"
        case .walk: return "🚶"
        case .bike: return "🚲"
        }
    }

    /// MapKit has no cycling transport type, so bike reuses the walking
    /// route and scales the time. Nil means estimated, not routed.
    public var mkTransportType: MKDirectionsTransportType? {
        switch self {
        case .car: return .automobile
        case .walk: return .walking
        case .bike: return nil
        }
    }

    /// Walking time multiplied by this gives the bike estimate.
    public var bikeEstimateFactor: Double { 0.35 }
}

public struct TravelETA {
    public let seconds: TimeInterval
    public let distanceMeters: Double
    public let isEstimate: Bool

    public init(seconds: TimeInterval, distanceMeters: Double, isEstimate: Bool) {
        self.seconds = seconds
        self.distanceMeters = distanceMeters
        self.isEstimate = isEstimate
    }

    public func displayText(mode: TravelMode) -> String {
        let prefix = isEstimate ? "≈ " : ""
        return mode.symbol + " " + prefix + seconds.formattedTravelDuration()
    }
}

public extension TimeInterval {
    public func formattedTravelDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(self, 60)) ?? ""
    }
}

private actor TravelTimeCache {
    private var etas: [String: (seconds: TimeInterval, distance: Double, date: Date)] = [:]
    private var geocodes: [String: (latitude: Double, longitude: Double, date: Date)] = [:]

    private let ttl: TimeInterval = 15 * 60

    private func cacheKey(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, mode: TravelMode) -> String {
        let originKey = String(format: "%.2f,%.2f", origin.latitude, origin.longitude)
        let destinationKey = String(format: "%.4f,%.4f", destination.latitude, destination.longitude)
        return originKey + ">" + destinationKey + "#" + mode.rawValue
    }

    func cachedETA(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, mode: TravelMode) -> (seconds: TimeInterval, distance: Double)? {
        let key = cacheKey(origin: origin, destination: destination, mode: mode)
        guard let entry = etas[key], Date().timeIntervalSince(entry.date) < ttl else { return nil }
        return (entry.seconds, entry.distance)
    }

    func storeETA(_ eta: TravelETA, origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, mode: TravelMode) {
        let key = cacheKey(origin: origin, destination: destination, mode: mode)
        etas[key] = (eta.seconds, eta.distanceMeters, Date())
    }

    func cachedCoordinate(for address: String) -> CLLocationCoordinate2D? {
        guard let entry = geocodes[address], Date().timeIntervalSince(entry.date) < ttl else { return nil }
        return CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
    }

    func storeCoordinate(_ coordinate: CLLocationCoordinate2D, for address: String) {
        geocodes[address] = (coordinate.latitude, coordinate.longitude, Date())
    }
}

private let travelTimeCache = TravelTimeCache()

/// One-shot location fetch that works from any task. Returns nil when
/// location is unavailable or permission is denied. Never throws.
private final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private static var active: [OneShotLocationFetcher] = []
    private static let lock = NSLock()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var finished = false

    private func finish(with location: CLLocation?) {
        Self.lock.lock()
        guard finished == false else {
            Self.lock.unlock()
            return
        }
        finished = true
        Self.lock.unlock()
        manager.stopUpdatingLocation()
        manager.delegate = nil
        Self.lock.lock()
        Self.active.removeAll { $0 === self }
        Self.lock.unlock()
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last)
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        finish(with: nil)
    }

    @MainActor
    static func fetch(timeoutSeconds: Double) async -> CLLocation? {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, watchOS 7.0, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        if status == .denied || status == .restricted {
            return nil
        }
        return await withCheckedContinuation { continuation in
            let fetcher = OneShotLocationFetcher()
            fetcher.continuation = continuation
            Self.lock.lock()
            active.append(fetcher)
            Self.lock.unlock()
            fetcher.manager.delegate = fetcher
            if status == .notDetermined {
                fetcher.manager.requestWhenInUseAuthorization()
            }
            fetcher.manager.requestLocation()
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                fetcher.finish(with: nil)
            }
        }
    }
}

public enum TravelTimeProvider {
    /// Current location with a timeout. Safe to call from widgets.
    public static func currentLocation(timeoutSeconds: Double = 8) async -> CLLocation? {
        await OneShotLocationFetcher.fetch(timeoutSeconds: timeoutSeconds)
    }

    /// Destination coordinate for an event. Prefers the map coordinate and
    /// only geocodes the location string when allowed. Widget timelines
    /// pass false to stay within the refresh budget.
    public static func coordinate(for event: EKEvent, allowGeocode: Bool) async -> CLLocationCoordinate2D? {
        if let coordinate = event.structuredLocation?.geoLocation?.coordinate,
           CLLocationCoordinate2DIsValid(coordinate) {
            return coordinate
        }
        guard allowGeocode,
              let address = event.location,
              address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        if let cached = await travelTimeCache.cachedCoordinate(for: address) {
            return cached
        }
        // Callback API keeps working back to the package minimum (iOS 13).
        let coordinate: CLLocationCoordinate2D? = await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
        guard let coordinate = coordinate,
              CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }
        await travelTimeCache.storeCoordinate(coordinate, for: address)
        return coordinate
    }

    public static func eta(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, mode: TravelMode) async -> TravelETA? {
        if let cached = await travelTimeCache.cachedETA(origin: origin, destination: destination, mode: mode) {
            return TravelETA(seconds: cached.seconds, distanceMeters: cached.distance, isEstimate: mode == .bike)
        }
        // Bike has no MapKit route type, so route as walking and scale.
        // Callback API keeps working back to the package minimum (iOS 13).
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = mode.mkTransportType ?? .walking
        let route: MKRoute? = await withCheckedContinuation { continuation in
            MKDirections(request: request).calculate { response, _ in
                continuation.resume(returning: response?.routes.first)
            }
        }
        guard let route = route else {
            return nil
        }
        let seconds = mode == .bike ? route.expectedTravelTime * mode.bikeEstimateFactor : route.expectedTravelTime
        let eta = TravelETA(seconds: seconds, distanceMeters: route.distance, isEstimate: mode == .bike)
        await travelTimeCache.storeETA(eta, origin: origin, destination: destination, mode: mode)
        return eta
    }

    /// ETAs keyed by event identifier for timeline entries. Coordinates only,
    /// no geocoding, so this stays fast enough for widget refreshes.
    public static func travelTimes(for events: [EKEvent], mode: TravelMode, maxEvents: Int = 6) async -> [String: TimeInterval] {
        guard let origin = await currentLocation() else { return [:] }
        var result: [String: TimeInterval] = [:]
        for event in events.prefix(maxEvents) {
            guard let identifier = event.eventIdentifier, result[identifier] == nil else { continue }
            guard let destination = event.structuredLocation?.geoLocation?.coordinate,
                  CLLocationCoordinate2DIsValid(destination) else { continue }
            if let eta = await eta(from: origin.coordinate, to: destination, mode: mode) {
                result[identifier] = eta.seconds
            }
        }
        return result
    }
}
