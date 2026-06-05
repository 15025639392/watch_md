import Foundation

public struct GPXTrackPoint: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var elevationMeters: Double?
    public var timestamp: Date?

    public init(latitude: Double, longitude: Double, elevationMeters: Double? = nil, timestamp: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.timestamp = timestamp
    }

    public var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}

public enum GPXParserError: Error, Equatable {
    case invalidDocument
    case noTrackPoints
}

public final class GPXParser: NSObject, XMLParserDelegate {
    private var parsedPoints: [GPXTrackPoint] = []
    private var currentLatitude: Double?
    private var currentLongitude: Double?
    private var currentElevation: Double?
    private var currentTimestamp: Date?
    private var currentText = ""
    private var parseError: Error?
    private let dateFormatter = ISO8601DateFormatter()

    public override init() {
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        super.init()
    }

    public func parse(data: Data) throws -> [GPXTrackPoint] {
        parsedPoints = []
        parseError = nil
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), parseError == nil else {
            throw parseError ?? parser.parserError ?? GPXParserError.invalidDocument
        }
        guard !parsedPoints.isEmpty else { throw GPXParserError.noTrackPoints }
        return parsedPoints
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        guard elementName == "trkpt" || elementName == "rtept" else { return }
        currentLatitude = Double(attributeDict["lat"] ?? "")
        currentLongitude = Double(attributeDict["lon"] ?? "")
        currentElevation = nil
        currentTimestamp = nil
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "ele":
            currentElevation = Double(trimmed)
        case "time":
            currentTimestamp = dateFormatter.date(from: trimmed) ?? ISO8601DateFormatter().date(from: trimmed)
        case "trkpt", "rtept":
            guard let latitude = currentLatitude, let longitude = currentLongitude else { return }
            guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
                parseError = RouteValidationError.invalidCoordinate(index: parsedPoints.count)
                parser.abortParsing()
                return
            }
            parsedPoints.append(GPXTrackPoint(latitude: latitude, longitude: longitude, elevationMeters: currentElevation, timestamp: currentTimestamp))
            currentLatitude = nil
            currentLongitude = nil
            currentElevation = nil
            currentTimestamp = nil
        default:
            break
        }
        currentText = ""
    }
}
