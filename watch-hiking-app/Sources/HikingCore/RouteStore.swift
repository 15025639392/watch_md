import Foundation

public actor RouteStore {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func save(_ route: InstalledRoute) throws {
        let data = try encoder.encode(route)
        let routeURL = directoryURL.appendingPathComponent("\(route.route.routeId).json")
        let temporaryURL = directoryURL.appendingPathComponent("\(route.route.routeId).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: routeURL.path) {
            try FileManager.default.removeItem(at: routeURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: routeURL)
    }

    public func load(routeId: String) throws -> InstalledRoute {
        let data = try Data(contentsOf: directoryURL.appendingPathComponent("\(routeId).json"))
        return try decoder.decode(InstalledRoute.self, from: data)
    }

    public func listRoutes() throws -> [InstalledRoute] {
        let urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try urls.map { try decoder.decode(InstalledRoute.self, from: Data(contentsOf: $0)) }
            .sorted { $0.route.updatedAt > $1.route.updatedAt }
    }
}
