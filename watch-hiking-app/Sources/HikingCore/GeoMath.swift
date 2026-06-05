import Foundation

public enum GeoMath {
    private static let earthRadiusMeters = 6_371_000.0

    public static func distanceMeters(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
        let lat1 = degreesToRadians(a.latitude)
        let lat2 = degreesToRadians(b.latitude)
        let dLat = degreesToRadians(b.latitude - a.latitude)
        let dLon = degreesToRadians(b.longitude - a.longitude)
        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        let h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
        return 2 * earthRadiusMeters * atan2(sqrt(h), sqrt(1 - h))
    }

    public static func bearingDegrees(from a: GeoCoordinate, to b: GeoCoordinate) -> Double {
        let lat1 = degreesToRadians(a.latitude)
        let lat2 = degreesToRadians(b.latitude)
        let dLon = degreesToRadians(b.longitude - a.longitude)
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalizedDegrees(radiansToDegrees(atan2(y, x)))
    }

    public static func angularDeltaDegrees(from first: Double, to second: Double) -> Double {
        var delta = normalizedDegrees(second - first)
        if delta > 180 { delta -= 360 }
        return delta
    }

    public static func cumulativeDistances(for coordinates: [GeoCoordinate]) -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        var distances = [0.0]
        for index in 1..<coordinates.count {
            distances.append(distances[index - 1] + distanceMeters(from: coordinates[index - 1], to: coordinates[index]))
        }
        return distances
    }

    static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}
