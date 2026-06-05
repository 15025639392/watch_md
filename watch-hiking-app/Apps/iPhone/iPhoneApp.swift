import MapKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct WatchHikingiPhoneApp: App {
    @StateObject private var routeListViewModel = RouteListViewModel()

    var body: some Scene {
        WindowGroup {
            RouteListView(viewModel: routeListViewModel)
                .onOpenURL { url in
                    Task {
                        await routeListViewModel.importGPX(from: url)
                    }
                }
        }
    }
}

@MainActor
final class RouteListViewModel: ObservableObject {
    @Published var summaries: [RemoteRouteSummary] = []
    @Published var importedRoutes: [InstalledRoute] = []
    @Published var syncedRoutes: [InstalledRoute] = []
    @Published var selectedRoute: InstalledRoute?
    @Published var errorMessage: String?

    private let client: RemoteRouteClient
    private let importService: RouteImportService
    private let routeStore: RouteStore

    init(client: RemoteRouteClient? = nil, importService: RouteImportService = RouteImportService()) {
        self.client = client ?? (try! MockRemoteRouteClient.sample())
        self.importService = importService
        let routeDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InstalledRoutes", isDirectory: true)
        routeStore = try! RouteStore(directoryURL: routeDirectory)
    }

    func refresh(query: String? = nil) async {
        do {
            summaries = try await client.fetchRouteSummaries(query: query)
            importedRoutes = try await routeStore.listRoutes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func install(summary: RemoteRouteSummary) async {
        do {
            selectedRoute = try await client.fetchRouteDetail(remoteRouteId: summary.remoteRouteId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importGPX(from url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let routeName = url.deletingPathExtension().lastPathComponent
            let route = try importService.importGPX(data: data, routeName: routeName)
            try await routeStore.save(route)
            importedRoutes = try await routeStore.listRoutes()
            selectedRoute = route
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markSynced(_ route: InstalledRoute) {
        syncedRoutes.removeAll { $0.route.routeId == route.route.routeId }
        syncedRoutes.insert(route, at: 0)
    }
}

struct RouteListView: View {
    @StateObject var viewModel: RouteListViewModel
    @State private var searchText = ""
    @State private var isImportingGPX = false
    @State private var selectedFilter: RouteFilter = .remote

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HeaderActions(isImportingGPX: $isImportingGPX)

                        Picker("路线筛选", selection: $selectedFilter) {
                            ForEach(RouteFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 0) {
                            switch selectedFilter {
                            case .remote:
                                ForEach(viewModel.summaries, id: \.remoteRouteId) { summary in
                                    Button {
                                        Task { await viewModel.install(summary: summary) }
                                    } label: {
                                        RemoteRouteCard(summary: summary)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.leading, 110)
                                }
                            case .local:
                                ForEach(viewModel.importedRoutes, id: \.route.routeId) { route in
                                    Button {
                                        viewModel.selectedRoute = route
                                    } label: {
                                        InstalledRouteCard(route: route)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.leading, 110)
                                }
                                ImportCallout {
                                    isImportingGPX = true
                                }
                            case .synced:
                                if viewModel.syncedRoutes.isEmpty {
                                    SyncedPlaceholder()
                                } else {
                                    ForEach(viewModel.syncedRoutes, id: \.route.routeId) { route in
                                        Button {
                                            viewModel.selectedRoute = route
                                        } label: {
                                            SyncedRouteCard(route: route)
                                        }
                                        .buttonStyle(.plain)
                                        Divider().padding(.leading, 110)
                                    }
                                }
                            }
                        }
                        .background(AppTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            }
            .navigationTitle("路线")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImportingGPX = true
                    } label: {
                        Label("导入 GPX", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImportingGPX,
                allowedContentTypes: [.gpx],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await viewModel.importGPX(from: url) }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert("路线处理失败", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .searchable(text: $searchText, prompt: "名称、编号或区域")
            .onSubmit(of: .search) {
                Task { await viewModel.refresh(query: searchText) }
            }
            .refreshable {
                await viewModel.refresh(query: searchText)
            }
            .task { await viewModel.refresh() }
            .overlay {
                if viewModel.summaries.isEmpty && viewModel.importedRoutes.isEmpty {
                    ContentUnavailableView {
                        Label("暂无路线", systemImage: "map")
                    } description: {
                        Text("刷新远端目录或导入 GPX 后显示。")
                    } actions: {
                        Button {
                            isImportingGPX = true
                        } label: {
                            Label("导入 GPX", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: { viewModel.selectedRoute.map(IdentifiedRoute.init(route:)) },
                set: { _ in viewModel.selectedRoute = nil }
            )) { identified in
                RouteDetailView(installedRoute: identified.route) { syncedRoute in
                    viewModel.markSynced(syncedRoute)
                }
            }
        }
    }
}

enum RouteFilter: String, CaseIterable, Identifiable {
    case remote
    case local
    case synced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remote: "远端路线"
        case .local: "本地"
        case .synced: "已同步"
        }
    }
}

struct HeaderActions: View {
    @Binding var isImportingGPX: Bool

    var body: some View {
        HStack(spacing: 10) {
            Label("搜索路线名称、编号或区域", systemImage: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(AppTheme.secondaryFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                isImportingGPX = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.blue)
            .background(AppTheme.panel)
            .clipShape(Circle())
        }
    }
}

struct RemoteRouteCard: View {
    let summary: RemoteRouteSummary

    var body: some View {
        RouteCardShell {
            RouteThumbnail()
        } content: {
            Text(summary.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            HStack {
                Text(summary.distanceText)
                Spacer()
                Text(summary.ascentText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Text(summary.regionName ?? "远端目录")
                Spacer()
                Text(summary.remoteVersion)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            StatusPill(text: summary.localStatus.pillText, style: summary.localStatus.pillStyle)
        }
    }
}

struct InstalledRouteCard: View {
    let route: InstalledRoute

    var body: some View {
        RouteCardShell {
            RouteThumbnail()
        } content: {
            Text(route.route.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            HStack {
                Text(route.route.distanceText)
                Spacer()
                Text(route.route.ascentText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Text("\(route.route.originalPointCount) 点")
                Spacer()
                Text("\(route.turnPoints.count) 转向")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            StatusPill(text: "已下载", style: .ok)
        }
    }
}

struct SyncedRouteCard: View {
    let route: InstalledRoute

    var body: some View {
        RouteCardShell {
            RouteThumbnail()
        } content: {
            Text(route.route.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            HStack {
                Text(route.route.distanceText)
                Spacer()
                Text(route.route.ascentText)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Text("\(route.simplifiedForWatch.pointCount) Watch 点")
                Spacer()
                Text("\(route.turnPoints.count) 转向")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            StatusPill(text: "模拟同步成功", style: .ok)
        }
    }
}

struct RouteCardShell<Thumbnail: View, Content: View>: View {
    @ViewBuilder var thumbnail: () -> Thumbnail
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail()
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}

struct RouteThumbnail: View {
    var body: some View {
        ZStack {
            AppTheme.map
            Path { path in
                path.move(to: CGPoint(x: 14, y: 72))
                path.addCurve(to: CGPoint(x: 42, y: 48), control1: CGPoint(x: 24, y: 52), control2: CGPoint(x: 36, y: 66))
                path.addCurve(to: CGPoint(x: 76, y: 16), control1: CGPoint(x: 50, y: 26), control2: CGPoint(x: 66, y: 32))
            }
            .stroke(AppTheme.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            Image(systemName: "arrowtriangle.right.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .shadow(color: AppTheme.green, radius: 2, x: 0, y: 0)
                .rotationEffect(.degrees(-42))
                .offset(x: 9, y: -2)
            PinLabel(text: "S", color: AppTheme.green)
                .offset(x: -30, y: 30)
            PinLabel(text: "E", color: AppTheme.orange)
                .offset(x: 30, y: -30)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PinLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color)
            .clipShape(Circle())
            .shadow(color: .white.opacity(0.9), radius: 0, x: 0, y: 0)
    }
}

struct StatusPill: View {
    let text: String
    let style: PillStyle

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.background)
            .clipShape(Capsule())
    }
}

struct ImportCallout: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                Text("导入本地 GPX")
                    .font(.headline)
                Text("解析路线、海拔、关键点，并生成 Watch 可用简化路线。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.blue)
        .padding(10)
    }
}

struct SyncedPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundStyle(AppTheme.blue)
            Text("暂无已同步路线")
                .font(.headline)
            Text("路线详情页同步成功后会出现在这里。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

struct IdentifiedRoute: Identifiable {
    var route: InstalledRoute
    var id: String { route.route.routeId }
}

struct RouteDetailView: View {
    let installedRoute: InstalledRoute
    let onSynced: (InstalledRoute) -> Void
    @StateObject private var viewModel = RouteDetailViewModel()
    @State private var isChromeVisible = true
    @State private var selectedMapLayer: RouteMapLayer = .standard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RoutePreviewMap(route: installedRoute, mapLayer: selectedMapLayer)
                .ignoresSafeArea()
                .accessibilityLabel("路线地图预览")
                .simultaneousGesture(
                    TapGesture().onEnded {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isChromeVisible.toggle()
                        }
                    }
                )

            if isChromeVisible {
                VStack {
                    HStack(alignment: .top) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .frame(width: 42, height: 42)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.blue)
                        .accessibilityLabel("关闭路线详情")

                        Spacer()

                        Picker("地图图层", selection: $selectedMapLayer) {
                            ForEach(RouteMapLayer.allCases) { layer in
                                Text(layer.title).tag(layer)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 178)
                        .padding(4)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()

                    Spacer()

                    RouteDetailSheet(installedRoute: installedRoute, viewModel: viewModel) {
                        onSynced(installedRoute)
                    }
                        .padding()
                }
                .transition(.opacity)
            }
        }
        .background(AppTheme.background)
    }
}

enum RouteMapLayer: String, CaseIterable, Identifiable {
    case standard
    case imagery
    case hybrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "标准"
        case .imagery: "卫星"
        case .hybrid: "混合"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard: .standard
        case .imagery: .imagery
        case .hybrid: .hybrid
        }
    }

    var mapType: MKMapType {
        switch self {
        case .standard: .standard
        case .imagery: .satellite
        case .hybrid: .hybrid
        }
    }
}

struct RouteDetailSheet: View {
    let installedRoute: InstalledRoute
    @ObservedObject var viewModel: RouteDetailViewModel
    let onSynced: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusPill(text: viewModel.statusText, style: viewModel.state.pillStyle)
                Spacer()
                Text("今天 09:42")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(installedRoute.route.name)
                .font(.title2.bold())
                .lineLimit(2)
            RouteStatsGrid(route: installedRoute)
            VStack(spacing: 8) {
                DetailStatusRow(title: "起点", value: "已识别")
                DetailStatusRow(title: "终点", value: "已识别")
                DetailStatusRow(title: "路线质量", value: "\(installedRoute.route.originalPointCount) 点 · \(installedRoute.turnPoints.count) 转向")
            }
            Button {
                Task {
                    if await viewModel.sync(installedRoute) {
                        onSynced()
                    }
                }
            } label: {
                Label(viewModel.buttonTitle, systemImage: viewModel.buttonSystemImage)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(viewModel.isSyncing)

            Text(viewModel.watchReadinessText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

struct DetailStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }
}

struct RoutePreviewMap: View {
    let route: InstalledRoute
    let mapLayer: RouteMapLayer

    var body: some View {
        RoutePatternMap(route: route, mapType: mapLayer.mapType)
    }
}

private struct RoutePatternMap: UIViewRepresentable {
    let route: InstalledRoute
    let mapType: MKMapType

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.routeOverlay = nil
        mapView.mapType = mapType
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        let coordinates = route.original.points.map(\.locationCoordinate)
        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.routeOverlay = polyline
            mapView.addOverlay(polyline)
        }

        mapView.addAnnotation(RouteEndpointAnnotation(title: "起点", coordinate: route.route.startPoint.locationCoordinate))
        mapView.addAnnotation(RouteEndpointAnnotation(title: "终点", coordinate: route.route.endPoint.locationCoordinate))
        mapView.setRegion(route.mapRegion, animated: false)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var routeOverlay: MKPolyline?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline, polyline === routeOverlay {
                return DirectionPatternPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let endpoint = annotation as? RouteEndpointAnnotation else { return nil }
            let identifier = "RouteEndpointAnnotation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            if let marker = view as? MKMarkerAnnotationView {
                marker.markerTintColor = endpoint.title == "起点" ? UIColor.systemGreen : UIColor.systemRed
                marker.glyphText = endpoint.title == "起点" ? "起" : "终"
            }
            return view
        }
    }
}

private final class RouteEndpointAnnotation: NSObject, MKAnnotation {
    let title: String?
    let coordinate: CLLocationCoordinate2D

    init(title: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
    }
}

private final class DirectionPatternPolylineRenderer: MKOverlayPathRenderer {
    private let polyline: MKPolyline
    private let routeColor = UIColor.systemBlue

    init(polyline: MKPolyline) {
        self.polyline = polyline
        super.init(overlay: polyline)
    }

    override func createPath() {
        let path = CGMutablePath()
        let points = polyline.points()
        guard polyline.pointCount > 0 else {
            self.path = path
            return
        }
        path.move(to: point(for: points[0]))
        for index in 1..<polyline.pointCount {
            path.addLine(to: point(for: points[index]))
        }
        self.path = path
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard path != nil else { return }
        configureRouteStroke(to: context, atZoomScale: zoomScale)
        context.setStrokeColor(routeColor.cgColor)
        context.addPath(path)
        context.strokePath()
        drawDirectionPattern(in: context, zoomScale: zoomScale)
    }

    private func configureRouteStroke(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        let lineWidth = max(3.5, MKRoadWidthAtZoomScale(zoomScale) * 0.45)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    private func drawDirectionPattern(in context: CGContext, zoomScale: MKZoomScale) {
        let mapPoints = polyline.points()
        guard polyline.pointCount >= 2 else { return }

        let arrowSpacing = 46 / zoomScale
        let arrowLength = 12 / zoomScale
        let arrowHalfWidth = 5 / zoomScale
        var distanceUntilNextArrow = arrowSpacing

        context.saveGState()
        context.setFillColor(UIColor.white.cgColor)

        for index in 1..<polyline.pointCount {
            let start = point(for: mapPoints[index - 1])
            let end = point(for: mapPoints[index])
            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = hypot(dx, dy)
            guard segmentLength > arrowLength else { continue }

            var traveled: CGFloat = 0
            while traveled + distanceUntilNextArrow < segmentLength {
                traveled += distanceUntilNextArrow
                let progress = traveled / segmentLength
                let center = CGPoint(
                    x: start.x + dx * progress,
                    y: start.y + dy * progress
                )
                drawArrow(center: center, angle: atan2(dy, dx), length: arrowLength, halfWidth: arrowHalfWidth, in: context)
                distanceUntilNextArrow = arrowSpacing
            }
            distanceUntilNextArrow -= (segmentLength - traveled)
            if distanceUntilNextArrow <= 0 {
                distanceUntilNextArrow = arrowSpacing
            }
        }

        context.restoreGState()
    }

    private func drawArrow(center: CGPoint, angle: CGFloat, length: CGFloat, halfWidth: CGFloat, in context: CGContext) {
        let tip = CGPoint(
            x: center.x + cos(angle) * length * 0.5,
            y: center.y + sin(angle) * length * 0.5
        )
        let base = CGPoint(
            x: center.x - cos(angle) * length * 0.5,
            y: center.y - sin(angle) * length * 0.5
        )
        let normal = CGPoint(x: -sin(angle), y: cos(angle))
        let left = CGPoint(x: base.x + normal.x * halfWidth, y: base.y + normal.y * halfWidth)
        let right = CGPoint(x: base.x - normal.x * halfWidth, y: base.y - normal.y * halfWidth)

        let arrow = CGMutablePath()
        arrow.move(to: tip)
        arrow.addLine(to: left)
        arrow.addLine(to: right)
        arrow.closeSubpath()
        context.addPath(arrow)
        context.fillPath()
    }
}

struct RouteStatsGrid: View {
    let route: InstalledRoute

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            RouteStatCell(title: "距离", value: route.route.distanceText)
            RouteStatCell(title: "爬升", value: route.route.ascentText)
            RouteStatCell(title: "预计用时", value: route.route.durationText)
        }
    }
}

struct RouteStatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(AppTheme.tertiaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published private(set) var state: RouteSyncState = .notSynced
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?

    private let syncService = WatchRouteSyncService(transport: SimulatorWatchRouteSyncTransport())

    var statusText: String {
        switch state {
        case .notSynced: "未同步到 Watch"
        case .manifestSent: "正在发送路线清单"
        case .readyForPayload: "Watch 已准备接收路线"
        case .payloadTransferred: "正在安装 Watch 路线"
        case .installed: "Watch 已就绪"
        case .failed: "同步失败"
        }
    }

    var watchReadinessText: String {
        if let errorMessage {
            return errorMessage
        }
        return syncService.readinessText
    }

    var buttonTitle: String {
        switch state {
        case .installed: "重新同步"
        case .failed: "重试同步"
        default: "同步到 Watch"
        }
    }

    var buttonSystemImage: String {
        switch state {
        case .installed: "checkmark.circle"
        case .failed: "arrow.clockwise.circle"
        default: "applewatch"
        }
    }

    func sync(_ route: InstalledRoute) async -> Bool {
        isSyncing = true
        errorMessage = nil
        var didInstall = false
        do {
            for try await newState in await syncService.sync(route) {
                state = newState
                didInstall = newState == .installed
            }
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
        }
        isSyncing = false
        return didInstall
    }
}

private enum AppTheme {
    static let background = Color(red: 0.949, green: 0.949, blue: 0.969)
    static let panel = Color.white
    static let map = Color(red: 0.902, green: 0.937, blue: 0.910)
    static let secondaryFill = Color(red: 0.898, green: 0.898, blue: 0.918)
    static let tertiaryFill = Color(red: 0.976, green: 0.976, blue: 0.984)
    static let line = Color(red: 0.820, green: 0.820, blue: 0.839)
    static let blue = Color(red: 0.000, green: 0.478, blue: 1.000)
    static let green = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let orange = Color(red: 1.000, green: 0.584, blue: 0.000)
    static let red = Color(red: 1.000, green: 0.231, blue: 0.188)
}

enum PillStyle {
    case ok
    case warning
    case danger
    case neutral

    var foreground: Color {
        switch self {
        case .ok: Color(red: 0.106, green: 0.498, blue: 0.216)
        case .warning: Color(red: 0.604, green: 0.353, blue: 0.000)
        case .danger: Color(red: 0.702, green: 0.149, blue: 0.118)
        case .neutral: AppTheme.blue
        }
    }

    var background: Color {
        switch self {
        case .ok: AppTheme.green.opacity(0.14)
        case .warning: AppTheme.orange.opacity(0.14)
        case .danger: AppTheme.red.opacity(0.13)
        case .neutral: AppTheme.blue.opacity(0.10)
        }
    }
}

private extension LocalRouteStatus {
    var pillText: String {
        switch self {
        case .notDownloaded: "未下载"
        case .downloaded: "已下载"
        case .hasUpdate: "有更新"
        case .syncedToWatch: "已同步"
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .notDownloaded: .warning
        case .downloaded, .syncedToWatch: .ok
        case .hasUpdate: .neutral
        }
    }
}

private extension RouteSyncState {
    var pillStyle: PillStyle {
        switch self {
        case .installed: .ok
        case .failed: .danger
        case .notSynced: .warning
        case .manifestSent, .readyForPayload, .payloadTransferred: .neutral
        }
    }
}

private extension InstalledRoute {
    var mapRegion: MKCoordinateRegion {
        let bounds = route.bounds
        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )
        let latitudeDelta = max((bounds.maxLatitude - bounds.minLatitude) * 1.6, 0.01)
        let longitudeDelta = max((bounds.maxLongitude - bounds.minLongitude) * 1.6, 0.01)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

}

private extension RoutePoint {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension GeoCoordinate {
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension RemoteRouteSummary {
    var distanceText: String {
        Formatters.distance(distanceMeters)
    }

    var ascentText: String {
        guard let ascentMeters else { return "爬升待确认" }
        return "爬升 \(Int(ascentMeters.rounded())) m"
    }
}

private extension HikingRoute {
    var distanceText: String {
        Formatters.distance(distanceMeters)
    }

    var ascentText: String {
        guard let ascentMeters else { return "待验证" }
        return "\(Int(ascentMeters.rounded())) m"
    }

    var durationText: String {
        guard let estimatedDurationSeconds else { return "待估算" }
        let hours = estimatedDurationSeconds / 3600
        let minutes = (estimatedDurationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) h \(minutes) min"
        }
        return "\(minutes) min"
    }
}

private enum Formatters {
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }
}

private extension UTType {
    static let gpx = UTType(filenameExtension: "gpx") ?? .xml
}

protocol WatchRouteSyncTransport: Sendable {
    func sync(_ route: InstalledRoute) -> AsyncThrowingStream<RouteSyncState, Error>
}

actor WatchRouteSyncService {
    let readinessText = "当前为模拟器同步模式：iPhone 侧会跑完整 manifest/payload/ACK 流程，但不会真实传到 Watch 模拟器。"
    private let transport: any WatchRouteSyncTransport

    init(transport: any WatchRouteSyncTransport) {
        self.transport = transport
    }

    func sync(_ route: InstalledRoute) -> AsyncThrowingStream<RouteSyncState, Error> {
        transport.sync(route)
    }
}

final class SimulatorWatchRouteSyncTransport: WatchRouteSyncTransport, @unchecked Sendable {
    private let coordinator = RouteSyncCoordinator()
    private let installer: WatchRouteInstaller

    init() {
        let routeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimulatorWatchInstalledRoutes", isDirectory: true)
        installer = try! WatchRouteInstaller(routeStore: RouteStore(directoryURL: routeDirectory))
    }

    func sync(_ route: InstalledRoute) -> AsyncThrowingStream<RouteSyncState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let manifest = try RouteSyncCodec.makeManifestEnvelope(for: route)
                    await coordinator.markManifestSent()
                    continuation.yield(await coordinator.state)

                    let manifestAck = try await installer.receiveManifest(manifest)
                    try await coordinator.handleManifestAck(manifestAck.payload)
                    continuation.yield(await coordinator.state)

                    guard await coordinator.state == .readyForPayload else {
                        continuation.finish()
                        return
                    }

                    let payload = try RouteSyncCodec.makePayloadEnvelope(for: route)
                    await coordinator.markPayloadTransferred()
                    continuation.yield(await coordinator.state)

                    let payloadAck = try await installer.receivePayload(payload)
                    try await coordinator.handlePayloadAck(payloadAck.payload)
                    continuation.yield(await coordinator.state)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
