import Foundation

public enum GeoMath {
    private static let earthRadiusMeters = 6_371_000.0
    private static let gcjA = 6_378_245.0
    private static let gcjEe = 0.00669342162296594323

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

    public static func wgs84ToGCJ02(_ coordinate: GeoCoordinate) -> GeoCoordinate {
        guard isInsideMainlandChina(latitude: coordinate.latitude, longitude: coordinate.longitude) else {
            return coordinate
        }

        var dLat = transformLatitude(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        var dLon = transformLongitude(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        let radLat = degreesToRadians(coordinate.latitude)
        var magic = sin(radLat)
        magic = 1 - gcjEe * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((gcjA * (1 - gcjEe)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (gcjA / sqrtMagic * cos(radLat) * .pi)
        return GeoCoordinate(latitude: coordinate.latitude + dLat, longitude: coordinate.longitude + dLon)
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

    private static func isInsideMainlandChina(latitude: Double, longitude: Double) -> Bool {
        longitude >= 72.004 && longitude <= 137.8347 && latitude >= 0.8293 && latitude <= 55.8271
    }

    private static func transformLatitude(x: Double, y: Double) -> Double {
        var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return result
    }

    private static func transformLongitude(x: Double, y: Double) -> Double {
        var result = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return result
    }
}
