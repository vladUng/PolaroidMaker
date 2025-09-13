//
//  Geo.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import Foundation
import CoreLocation

struct Geo {
    private static var cache: [String: String] = [:]
    private static var lastRequestTime: Date = Date.distantPast
    private static let minRequestInterval: TimeInterval = 1.5 // 1.5 seconds between requests
    private static let maxCacheSize = 100
    
    static func reverseGeocode(location: CLLocation) async -> String {
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        
        // Check cache first
        if let cached = cache[cacheKey] {
            return cached
        }
        
        // Rate limiting: ensure minimum time between requests
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minRequestInterval {
            let delay = minRequestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        do {
            lastRequestTime = Date()
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                cache[cacheKey] = ""
                return ""
            }
            
            let city = placemark.locality ?? placemark.subAdministrativeArea
            let country = placemark.country
            
            let result = EXIFHelper.formatLocationString(city: city, country: country)
            
            // Cache the result
            cache[cacheKey] = result
            trimCacheIfNeeded()
            
            return result
            
        } catch {
            print("Geocoding failed: \(error.localizedDescription)")
            // Cache empty result to avoid repeated failures
            cache[cacheKey] = ""
            return ""
        }
    }
    
    static func reverseGeocodeSync(location: CLLocation, completion: @escaping (String) -> Void) {
        Task {
            let result = await reverseGeocode(location: location)
            await MainActor.run {
                completion(result)
            }
        }
    }
    
    private static func trimCacheIfNeeded() {
        if cache.count > maxCacheSize {
            // Remove 20% of cache entries (oldest first by removing arbitrary keys)
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 5))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    static func clearCache() {
        cache.removeAll()
    }
}