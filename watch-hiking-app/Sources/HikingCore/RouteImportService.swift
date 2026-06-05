import Foundation

public struct RouteImportService: Sendable {
    public var parser: @Sendable () -> GPXParser
    public var buildOptions: RouteBuildOptions

    public init(parser: @escaping @Sendable () -> GPXParser = { GPXParser() }, buildOptions: RouteBuildOptions = RouteBuildOptions()) {
        self.parser = parser
        self.buildOptions = buildOptions
    }

    public func importGPX(data: Data, routeName: String) throws -> InstalledRoute {
        let points = try parser().parse(data: data)
        return try RouteBuilder.buildRoute(name: routeName, source: .gpxImport, rawPoints: points, options: buildOptions)
    }
}
