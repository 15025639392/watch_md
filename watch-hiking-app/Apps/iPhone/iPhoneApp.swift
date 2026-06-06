import CoreLocation
import MapKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct WatchHikingiPhoneApp: App {
    @StateObject private var routeListViewModel = RouteListViewModel()
    @StateObject private var sessionSyncService = iPhoneSessionSyncService.shared
    @StateObject private var locationViewModel = iPhoneLocationViewModel()

    var body: some Scene {
        WindowGroup {
            RouteListView(viewModel: routeListViewModel)
                .environmentObject(sessionSyncService)
                .environmentObject(locationViewModel)
                .task {
                    sessionSyncService.start()
                    await routeListViewModel.autoSyncFirstRouteForDebugIfRequested()
                }
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

    func autoSyncFirstRouteForDebugIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--auto-sync-first-route") else { return }
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let summaries = try await client.fetchRouteSummaries(query: nil)
            guard let first = summaries.first else { return }
            let route = try await client.fetchRouteDetail(remoteRouteId: first.remoteRouteId)
            try await routeStore.save(route)
            importedRoutes = try await routeStore.listRoutes()
            var didInstall = false
            for try await state in iPhoneSessionSyncService.shared.sync(route) {
                didInstall = state == .installed
            }
            if didInstall {
                markSynced(route)
            }
        } catch {
            errorMessage = "自动同步验证失败：\(error.localizedDescription)"
        }
    }
}

struct RouteListView: View {
    @StateObject var viewModel: RouteListViewModel
    @EnvironmentObject private var sessionSyncService: iPhoneSessionSyncService
    @EnvironmentObject private var locationViewModel: iPhoneLocationViewModel
    @State private var searchText = ""
    @State private var isImportingGPX = false
    @State private var selectedFilter: RouteFilter = .remote

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            WatchSessionSyncListView()
                        } label: {
                            WatchHubStatusCard(
                                connectionTitle: sessionSyncService.watchConnectionTitle,
                                receivedCount: sessionSyncService.receivedSessions.count,
                                isConnected: sessionSyncService.isWatchConnected,
                                activeSyncCount: sessionSyncService.receivedSessions.filter { $0.displayState != .completed }.count
                            )
                        }
                        .buttonStyle(.plain)

                        iPhoneLocationStatusCard(viewModel: locationViewModel)

                        RouteFilterBar(selection: $selectedFilter)

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

struct iPhoneLocationSnapshot: Equatable {
    var coordinate: CLLocationCoordinate2D
    var horizontalAccuracyMeters: Double
    var courseDegrees: Double
    var timestamp: Date

    static func == (lhs: iPhoneLocationSnapshot, rhs: iPhoneLocationSnapshot) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.horizontalAccuracyMeters == rhs.horizontalAccuracyMeters &&
            lhs.courseDegrees == rhs.courseDegrees &&
            lhs.timestamp == rhs.timestamp
    }
}

@MainActor
final class iPhoneLocationViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var snapshot: iPhoneLocationSnapshot?
    @Published private(set) var statusText = "真实定位未启动"
    @Published private(set) var isUpdating = false
    @Published var keepsUpdatingInBackground = false {
        didSet {
            guard oldValue != keepsUpdatingInBackground else { return }
            configureBackgroundLocation()
            if keepsUpdatingInBackground, manager.authorizationStatus == .authorizedWhenInUse {
                statusText = "需要始终允许定位"
                manager.requestAlwaysAuthorization()
            }
        }
    }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.activityType = .fitness
        manager.headingFilter = 5
        manager.pausesLocationUpdatesAutomatically = true
    }

    var coordinateText: String {
        guard let snapshot else { return "--" }
        return String(format: "%.5f, %.5f", snapshot.coordinate.latitude, snapshot.coordinate.longitude)
    }

    var accuracyText: String {
        guard let snapshot else { return "--" }
        return "\(Int(snapshot.horizontalAccuracyMeters.rounded()))m"
    }

    var headingText: String {
        guard let snapshot else { return "--" }
        return "\(Int(snapshot.courseDegrees.rounded()))° \(Formatters.compassDirection(snapshot.courseDegrees))"
    }

    var updatedText: String {
        guard let snapshot else { return "等待位置" }
        return snapshot.timestamp.formatted(date: .omitted, time: .standard)
    }

    func toggleUpdating() {
        isUpdating ? stop() : start()
    }

    func start() {
        startLiveLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        isUpdating = false
        statusText = "真实定位已停止"
    }

    private func startLiveLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            statusText = "等待定位授权"
            if keepsUpdatingInBackground {
                manager.requestAlwaysAuthorization()
            } else {
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            isUpdating = true
            configureBackgroundLocation()
            statusText = keepsUpdatingInBackground && manager.authorizationStatus != .authorizedAlways ? "前台定位中 · 等待始终允许" : "真实定位启动中"
            if keepsUpdatingInBackground, manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        case .denied, .restricted:
            isUpdating = false
            statusText = "定位未授权"
        @unknown default:
            isUpdating = false
            statusText = "定位状态未知"
        }
    }

    private func configureBackgroundLocation() {
        manager.allowsBackgroundLocationUpdates = keepsUpdatingInBackground && manager.authorizationStatus == .authorizedAlways
        manager.pausesLocationUpdatesAutomatically = !keepsUpdatingInBackground
        manager.showsBackgroundLocationIndicator = keepsUpdatingInBackground
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startLiveLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        snapshot = iPhoneLocationSnapshot(
            coordinate: location.coordinate,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            courseDegrees: location.course >= 0 ? location.course : snapshot?.courseDegrees ?? 0,
            timestamp: location.timestamp
        )
        statusText = keepsUpdatingInBackground && manager.authorizationStatus == .authorizedAlways ? "持续定位中" : "真实定位中"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard var current = snapshot, newHeading.trueHeading >= 0 else { return }
        current.courseDegrees = newHeading.trueHeading
        current.timestamp = Date()
        snapshot = current
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusText = "定位失败：\(error.localizedDescription)"
    }
}

struct iPhoneLocationStatusCard: View {
    @ObservedObject var viewModel: iPhoneLocationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.headline)
                    .foregroundStyle(viewModel.isUpdating ? AppTheme.green : AppTheme.blue)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.secondaryFill)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("iPhone 定位")
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    viewModel.toggleUpdating()
                } label: {
                    Image(systemName: viewModel.isUpdating ? "pause.fill" : "play.fill")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(viewModel.isUpdating ? AppTheme.orange : AppTheme.blue)
                .clipShape(Circle())
                .accessibilityLabel(viewModel.isUpdating ? "停止定位" : "开始定位")
            }

            Toggle(isOn: $viewModel.keepsUpdatingInBackground) {
                Label("持续高精度定位", systemImage: "location.viewfinder")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(AppTheme.green)

            HStack(spacing: 8) {
                WatchHubMetric(title: "坐标", value: viewModel.coordinateText, style: .neutral)
                WatchHubMetric(title: "精度", value: viewModel.accuracyText, style: .ok)
                WatchHubMetric(title: "朝向", value: viewModel.headingText, style: .neutral)
            }

            HStack {
                Text(viewModel.updatedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line.opacity(0.75), lineWidth: 1)
        }
    }
}

struct RouteFilterBar: View {
    @Binding var selection: RouteFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RouteFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(.subheadline.weight(selection == filter ? .semibold : .regular))
                        .foregroundStyle(selection == filter ? AppTheme.blue : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(selection == filter ? AppTheme.blue.opacity(0.10) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line.opacity(0.75), lineWidth: 1)
        }
    }
}

struct WatchHubStatusCard: View {
    let connectionTitle: String
    let receivedCount: Int
    let isConnected: Bool
    let activeSyncCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                .font(.headline)
                .foregroundStyle(isConnected ? AppTheme.green : AppTheme.orange)
                .frame(width: 34, height: 34)
                .background(AppTheme.secondaryFill)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(connectionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(activeSyncCount > 0 ? "\(activeSyncCount) 条待处理回传" : "\(receivedCount) 条 Watch 会话")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if activeSyncCount > 0 {
                StatusPill(text: "\(activeSyncCount)", style: .warning)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line.opacity(0.75), lineWidth: 1)
        }
    }
}

struct WatchHubMetric: View {
    let title: String
    let value: String
    let style: PillStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(style.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WatchSessionSyncListView: View {
    @EnvironmentObject private var sessionSyncService: iPhoneSessionSyncService

    private var pendingRecords: [ReceivedSessionRecord] {
        sessionSyncService.receivedSessions.filter { $0.displayState != .completed }
    }

    private var completedRecords: [ReceivedSessionRecord] {
        sessionSyncService.receivedSessions.filter { $0.displayState == .completed }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    WatchLiveTrackCard(
                        snapshot: sessionSyncService.liveTrackSnapshot,
                        message: sessionSyncService.lastSyncMessage,
                        connectionTitle: sessionSyncService.watchConnectionTitle,
                        connectionDetail: sessionSyncService.watchConnectionDetail,
                        receivedCount: sessionSyncService.receivedSessions.count,
                        isConnected: sessionSyncService.isWatchConnected,
                        activeSyncCount: pendingRecords.count
                    )

                    if sessionSyncService.receivedSessions.isEmpty {
                        ContentUnavailableView {
                            Label("Watch 等待徒步记录", systemImage: "applewatch")
                        } description: {
                            Text("路线同步后请在 Watch 上开始；结束后轨迹、事件和摘要会回到这里。")
                        }
                        .padding(.top, 80)
                    } else {
                        if !pendingRecords.isEmpty {
                            WatchSessionRecordSection(title: "待处理", records: pendingRecords)
                        }
                        if !completedRecords.isEmpty {
                            WatchSessionRecordSection(title: "已完成", records: completedRecords)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Watch 中枢")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WatchSessionRecordSection: View {
    let title: String
    let records: [ReceivedSessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(records, id: \.sessionId) { record in
                    NavigationLink {
                        WatchSessionSyncDetailView(record: record)
                    } label: {
                        WatchSessionRecordRow(record: record)
                    }
                    .buttonStyle(.plain)

                    if record.sessionId != records.last?.sessionId {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct WatchLiveTrackCard: View {
    let snapshot: LiveTrackSnapshot?
    let message: String
    let connectionTitle: String
    let connectionDetail: String
    let receivedCount: Int
    let isConnected: Bool
    let activeSyncCount: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            if let snapshot, !snapshot.recentPoints.isEmpty {
                SessionTrackMap(trackPoints: snapshot.recentPoints, endpointMode: .currentOnly)
            } else {
                ZStack {
                    AppTheme.secondaryFill
                    ContentUnavailableView {
                        Label("暂无实时轨迹", systemImage: "location.slash")
                    } description: {
                        Text("开始徒步后显示 Watch 当前位置和最近轨迹。")
                    }
                }
            }
        }
        .frame(height: 360)
        .overlay(alignment: .top) {
            HStack(spacing: 10) {
                Image(systemName: snapshot == nil ? "applewatch" : "location.north.line")
                    .font(.headline)
                    .foregroundStyle(snapshot == nil ? AppTheme.orange : AppTheme.green)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.secondaryFill)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot == nil ? "等待 Watch 位置" : snapshot?.watchTopStatusText ?? "Watch 实时轨迹")
                        .font(.subheadline.weight(.semibold))
                    Text(snapshot == nil ? connectionDetail : "\(connectionTitle) · \(snapshot!.updatedAt.relativeShortText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)
        }
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot?.watchBottomHintText ?? (isConnected ? "同步可用" : "不可用"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    FloatingMetric(title: "心率", value: snapshot?.heartRateText ?? "-- bpm")
                    FloatingMetric(title: "距离", value: snapshot?.workoutDistanceText ?? "--")
                    FloatingMetric(title: "能量", value: snapshot?.energyText ?? "-- kcal")
                }

                HStack {
                    Text("\(message) · 已回传 \(receivedCount) 条 · 待处理 \(activeSyncCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FloatingMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WatchSessionRecordRow: View {
    let record: ReceivedSessionRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.displayState.systemImage)
                .font(.headline)
                .foregroundStyle(record.displayState.tint)
                .frame(width: 34, height: 34)
                .background(AppTheme.secondaryFill)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    StatusPill(text: record.displayState.title, style: record.displayState.pillStyle)
                }
                HStack {
                    Text(record.completionText)
                    Text("\(record.events.count) 个事件")
                    if !record.missingTrackRanges.isEmpty {
                        Text("\(record.missingTrackRanges.count) 段待补传")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}

struct WatchSessionSyncDetailView: View {
    let record: ReceivedSessionRecord

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            StatusPill(text: record.displayState.title, style: record.displayState.pillStyle)
                            Spacer()
                            Text(record.dateText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(record.displayTitle)
                            .font(.title2.bold())
                            .lineLimit(2)
                        SessionSyncMetricGrid(record: record)
                    }
                    .padding(12)
                    .background(AppTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("回传完整性")
                            .font(.headline)
                        DetailStatusRow(title: "轨迹", value: record.completionText)
                        DetailStatusRow(title: "事件", value: "\(record.events.count) 个")
                        DetailStatusRow(title: "摘要", value: record.summary == nil ? "未收到" : "已收到")
                        DetailStatusRow(title: "状态", value: record.displayState.title)
                    }
                    .padding(12)
                    .background(AppTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("缺失范围")
                            .font(.headline)
                        if record.missingTrackRanges.isEmpty {
                            DetailStatusRow(title: "轨迹缺口", value: "无")
                        } else {
                            ForEach(record.missingTrackRanges, id: \.displayText) { range in
                                DetailStatusRow(title: "等待补传", value: range.userFacingText)
                            }
                        }
                    }
                    .padding(12)
                    .background(AppTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if record.canOpenReview {
                        NavigationLink {
                            SessionReviewView(record: record)
                        } label: {
                            Label("查看复盘", systemImage: "map")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(AppTheme.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("回传详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SessionSyncMetricGrid: View {
    let record: ReceivedSessionRecord

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            MetricTile(title: "轨迹点", value: "\(record.trackPoints.count)")
            MetricTile(title: "事件", value: "\(record.events.count)")
            MetricTile(title: "缺口", value: "\(record.missingTrackRanges.count)")
            MetricTile(title: "距离", value: Formatters.distance(record.summary?.distanceMeters ?? 0))
            MetricTile(title: "时长", value: record.durationText)
            MetricTile(title: "偏航", value: "\(record.summary?.offRouteEventCount ?? 0)")
        }
    }
}

struct SessionReviewView: View {
    let record: ReceivedSessionRecord

    var body: some View {
        ZStack(alignment: .bottom) {
            SessionTrackMap(trackPoints: record.trackPoints)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusPill(text: "同步完成", style: .ok)
                    Spacer()
                    Text(record.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(record.displayTitle)
                    .font(.title2.bold())
                    .lineLimit(2)
                SessionSyncMetricGrid(record: record)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
        }
        .navigationTitle("徒步复盘")
        .navigationBarTitleDisplayMode(.inline)
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
            StatusPill(text: "Watch 已就绪", style: .ok)
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

struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.tertiaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
    @EnvironmentObject private var locationViewModel: iPhoneLocationViewModel
    @StateObject private var viewModel = RouteDetailViewModel()
    @State private var isChromeVisible = true
    @State private var selectedMapLayer: RouteMapLayer = .standard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RoutePreviewMap(
                route: installedRoute,
                mapLayer: selectedMapLayer,
                locationSnapshot: locationViewModel.snapshot
            )
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
                Text(viewModel.syncStageText)
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
            ReadinessChecklist(viewModel: viewModel)
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

struct ReadinessChecklist: View {
    @ObservedObject var viewModel: RouteDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watch 出发检查")
                .font(.subheadline.weight(.semibold))
            DetailStatusRow(title: "路线同步", value: viewModel.routeReadinessValue)
            DetailStatusRow(title: "连接状态", value: "模拟通道可用")
            DetailStatusRow(title: "定位 / 健康权限", value: "开始前由 Watch 确认")
        }
        .padding(10)
        .background(AppTheme.tertiaryFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct RoutePreviewMap: View {
    let route: InstalledRoute
    let mapLayer: RouteMapLayer
    let locationSnapshot: iPhoneLocationSnapshot?

    var body: some View {
        RoutePatternMap(route: route, mapType: mapLayer.mapType, locationSnapshot: locationSnapshot)
    }
}

private struct RoutePatternMap: UIViewRepresentable {
    let route: InstalledRoute
    let mapType: MKMapType
    let locationSnapshot: iPhoneLocationSnapshot?

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
        let routeKey = "\(route.route.routeId)-\(route.route.version)-\(mapType.rawValue)"
        mapView.mapType = mapType

        if context.coordinator.routeKey != routeKey {
            context.coordinator.routeKey = routeKey
            context.coordinator.routeOverlay = nil
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is UserLocationAnnotation) })

            let coordinates = route.original.points.map(\.locationCoordinate)
            if coordinates.count >= 2 {
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                context.coordinator.routeOverlay = polyline
                mapView.addOverlay(polyline)
                mapView.setVisibleMapRect(
                    polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 96, left: 34, bottom: 260, right: 34),
                    animated: false
                )
            } else {
                mapView.setRegion(route.mapRegion, animated: false)
            }

            mapView.addAnnotation(RouteEndpointAnnotation(title: "起点", coordinate: route.route.startPoint.locationCoordinate))
            mapView.addAnnotation(RouteEndpointAnnotation(title: "终点", coordinate: route.route.endPoint.locationCoordinate))
        }

        context.coordinator.updateUserLocation(locationSnapshot, in: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var routeOverlay: MKPolyline?
        var routeKey: String?
        private var userLocationAnnotation: UserLocationAnnotation?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline, polyline === routeOverlay {
                return DirectionPatternPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let userLocation = annotation as? UserLocationAnnotation {
                let identifier = "UserLocationAnnotation"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? UserLocationAnnotationView)
                    ?? UserLocationAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.update(courseDegrees: userLocation.courseDegrees)
                view.canShowCallout = true
                return view
            }

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

        func updateUserLocation(_ snapshot: iPhoneLocationSnapshot?, in mapView: MKMapView) {
            guard let snapshot else {
                if let userLocationAnnotation {
                    mapView.removeAnnotation(userLocationAnnotation)
                    self.userLocationAnnotation = nil
                }
                return
            }

            if let userLocationAnnotation {
                userLocationAnnotation.coordinate = snapshot.coordinate
                userLocationAnnotation.courseDegrees = snapshot.courseDegrees
                if let view = mapView.view(for: userLocationAnnotation) as? UserLocationAnnotationView {
                    view.update(courseDegrees: snapshot.courseDegrees)
                }
            } else {
                let annotation = UserLocationAnnotation(
                    coordinate: snapshot.coordinate,
                    courseDegrees: snapshot.courseDegrees
                )
                userLocationAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }
}

private struct SessionTrackMap: UIViewRepresentable {
    enum EndpointMode {
        case startAndEnd
        case currentOnly
    }

    let trackPoints: [TrackPoint]
    var endpointMode: EndpointMode = .startAndEnd

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.pointOfInterestFilter = .includingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.trackOverlay = nil
        context.coordinator.endpointMode = endpointMode
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.pointOfInterestFilter = .includingAll
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        let coordinates = trackPoints.sorted { $0.sequence < $1.sequence }.map(\.locationCoordinate)
        guard let first = coordinates.first else { return }

        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            context.coordinator.trackOverlay = polyline
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 90, left: 30, bottom: 220, right: 30), animated: false)
        } else {
            mapView.setRegion(
                MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
                animated: false
            )
        }

        switch endpointMode {
        case .startAndEnd:
            mapView.addAnnotation(RouteEndpointAnnotation(title: "起点", coordinate: first))
            if let last = coordinates.last, coordinates.count > 1 {
                mapView.addAnnotation(RouteEndpointAnnotation(title: "终点", coordinate: last))
            }
        case .currentOnly:
            if let last = coordinates.last {
                mapView.addAnnotation(RouteEndpointAnnotation(title: "当前", coordinate: last))
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var trackOverlay: MKPolyline?
        var endpointMode: EndpointMode = .startAndEnd

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline, polyline === trackOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 5
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let endpoint = annotation as? RouteEndpointAnnotation else { return nil }
            let identifier = "SessionEndpointAnnotation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            if let marker = view as? MKMarkerAnnotationView {
                switch endpoint.title {
                case "起点":
                    marker.markerTintColor = UIColor.systemGreen
                    marker.glyphText = "起"
                case "当前":
                    marker.markerTintColor = UIColor.systemBlue
                    marker.glyphImage = UIImage(systemName: "location.north.fill")
                default:
                    marker.markerTintColor = UIColor.systemOrange
                    marker.glyphText = "终"
                }
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

private final class UserLocationAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var courseDegrees: Double
    let title: String? = "当前位置"

    init(coordinate: CLLocationCoordinate2D, courseDegrees: Double) {
        self.coordinate = coordinate
        self.courseDegrees = courseDegrees
    }
}

private final class UserLocationAnnotationView: MKAnnotationView {
    private let accuracyView = UIView()
    private let headingView = UserHeadingView()
    private let dotView = UIView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 58, height: 58)
        centerOffset = .zero
        backgroundColor = .clear
        isOpaque = false
        collisionMode = .circle
        displayPriority = .required

        accuracyView.frame = bounds
        accuracyView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.16)
        accuracyView.layer.cornerRadius = bounds.width / 2
        accuracyView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.22).cgColor
        accuracyView.layer.borderWidth = 1
        accuracyView.isUserInteractionEnabled = false
        addSubview(accuracyView)

        headingView.frame = bounds
        headingView.backgroundColor = .clear
        headingView.isOpaque = false
        headingView.isUserInteractionEnabled = false
        addSubview(headingView)

        dotView.frame = CGRect(x: 20, y: 20, width: 18, height: 18)
        dotView.backgroundColor = .systemBlue
        dotView.layer.cornerRadius = 9
        dotView.layer.borderColor = UIColor.white.cgColor
        dotView.layer.borderWidth = 3
        dotView.layer.shadowColor = UIColor.black.cgColor
        dotView.layer.shadowOpacity = 0.20
        dotView.layer.shadowRadius = 4
        dotView.layer.shadowOffset = CGSize(width: 0, height: 1)
        dotView.isUserInteractionEnabled = false
        addSubview(dotView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(courseDegrees: Double) {
        headingView.transform = CGAffineTransform(rotationAngle: courseDegrees * .pi / 180)
    }
}

private final class UserHeadingView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: center.x, y: 6))
        path.addLine(to: CGPoint(x: center.x - 8, y: center.y - 4))
        path.addQuadCurve(to: CGPoint(x: center.x + 8, y: center.y - 4), controlPoint: CGPoint(x: center.x, y: center.y - 9))
        path.close()

        UIColor.systemBlue.withAlphaComponent(0.26).setFill()
        path.fill()

        UIColor.white.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 1
        path.stroke()

        context.restoreGState()
    }
}

private final class DirectionPatternPolylineRenderer: MKOverlayPathRenderer {
    private let polyline: MKPolyline
    private let routeColor = UIColor.systemBlue
    private let haloColor = UIColor.white.withAlphaComponent(0.92)

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

        configureRouteHalo(to: context, atZoomScale: zoomScale)
        context.setStrokeColor(haloColor.cgColor)
        context.addPath(path)
        context.strokePath()

        configureRouteStroke(to: context, atZoomScale: zoomScale)
        context.setStrokeColor(routeColor.cgColor)
        context.addPath(path)
        context.strokePath()
        drawDirectionPattern(in: context, zoomScale: zoomScale)
    }

    private func configureRouteHalo(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        context.setLineWidth(routeLineWidth(atZoomScale: zoomScale) + 5 / zoomScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    private func configureRouteStroke(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        context.setLineWidth(routeLineWidth(atZoomScale: zoomScale))
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    private func routeLineWidth(atZoomScale zoomScale: MKZoomScale) -> CGFloat {
        max(9 / zoomScale, MKRoadWidthAtZoomScale(zoomScale) * 1.2)
    }

	    private func drawDirectionPattern(in context: CGContext, zoomScale: MKZoomScale) {
	        let mapPoints = polyline.points()
	        guard polyline.pointCount >= 2 else { return }

	        let routeWidth = routeLineWidth(atZoomScale: zoomScale)
	        let arrowLength = routeWidth * 2.1
	        let arrowHalfWidth = routeWidth * 0.72
	        let arrowSpacing = routeWidth * 7.2
	        var distanceUntilNextArrow = arrowSpacing * 0.55

	        context.saveGState()
	        context.setFillColor(UIColor.white.cgColor)

	        for index in 1..<polyline.pointCount {
            let start = point(for: mapPoints[index - 1])
            let end = point(for: mapPoints[index])
	            let dx = end.x - start.x
	            let dy = end.y - start.y
	            let segmentLength = hypot(dx, dy)
	            guard segmentLength > 0 else { continue }

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

    private let syncService = WatchRouteSyncService(transport: iPhoneSessionSyncService.shared)

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

    var syncStageText: String {
        switch state {
        case .notSynced: "待同步"
        case .manifestSent, .readyForPayload, .payloadTransferred: "同步中"
        case .installed: "已就绪"
        case .failed: "需重试"
        }
    }

    var routeReadinessValue: String {
        switch state {
        case .notSynced: "未同步"
        case .manifestSent, .readyForPayload, .payloadTransferred: "同步中"
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
        case .installed: "重新同步到 Watch"
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
            for try await newState in syncService.sync(route) {
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

enum SessionSyncDisplayState: String, CaseIterable, Identifiable {
    case syncing
    case partial
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .syncing: "正在同步"
        case .partial: "部分同步"
        case .completed: "已完成"
        }
    }

    var sectionTitle: String {
        switch self {
        case .syncing: "正在同步"
        case .partial: "部分同步"
        case .completed: "已完成"
        }
    }

    var systemImage: String {
        switch self {
        case .syncing: "arrow.triangle.2.circlepath"
        case .partial: "exclamationmark.arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .syncing: AppTheme.blue
        case .partial: AppTheme.orange
        case .completed: AppTheme.green
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .syncing: .neutral
        case .partial: .warning
        case .completed: .ok
        }
    }
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

private extension ReceivedSessionRecord {
    var displayState: SessionSyncDisplayState {
        if syncStatus == .synced || (summary != nil && missingTrackRanges.isEmpty && trackPoints.count == expectedTrackPointCount) {
            return .completed
        }
        if summary != nil || !missingTrackRanges.isEmpty {
            return .partial
        }
        return .syncing
    }

    var displayTitle: String {
        summary?.routeName ?? status?.routeId ?? "自由记录"
    }

    var expectedTrackPointCount: Int {
        if let summary {
            return summary.trackPointCount
        }
        return max(status?.trackPointCount ?? 0, trackPoints.count)
    }

    var completionText: String {
        let expected = expectedTrackPointCount
        if expected == 0 {
            return trackPoints.isEmpty ? "等待轨迹" : "已收到 \(trackPoints.count) 个轨迹点"
        }
        if missingTrackRanges.isEmpty && trackPoints.count >= expected {
            return "轨迹完整"
        }
        return "已收到 \(trackPoints.count)/\(expected) 个轨迹点"
    }

    var missingTrackRanges: [SequenceRange] {
        let expected = expectedTrackPointCount
        guard expected > 0 else { return [] }
        let received = Set(trackPoints.map(\.sequence))
        var ranges: [SequenceRange] = []
        var start: Int?
        for sequence in 0..<expected {
            if !received.contains(sequence) {
                start = start ?? sequence
            } else if let missingStart = start {
                ranges.append(SequenceRange(startSequence: missingStart, endSequence: sequence - 1))
                start = nil
            }
        }
        if let missingStart = start {
            ranges.append(SequenceRange(startSequence: missingStart, endSequence: expected - 1))
        }
        return ranges
    }

    var canOpenReview: Bool {
        displayState == .completed && trackPoints.isEmpty == false
    }

    var dateText: String {
        guard let date = summary?.endedAt ?? status?.lastUpdatedAt ?? trackPoints.last?.timestamp else {
            return "未知时间"
        }
        return Self.shortDateFormatter.string(from: date)
    }

    var durationText: String {
        guard let seconds = summary?.durationSeconds else { return "--" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }
}

private extension SequenceRange {
    var displayText: String {
        startSequence == endSequence ? "\(startSequence)" : "\(startSequence)-\(endSequence)"
    }

    var userFacingText: String {
        if startSequence == endSequence {
            return "第 \(startSequence + 1) 个轨迹点"
        }
        return "第 \(startSequence + 1)-\(endSequence + 1) 个轨迹点"
    }
}

private extension HikingSessionStatus {
    var userFacingText: String {
        switch self {
        case .planned: "未开始"
        case .active: "记录中"
        case .paused: "已暂停"
        case .finished: "已结束"
        case .abandoned: "已放弃"
        }
    }
}

private extension LiveTrackSnapshot {
    var heartRateText: String {
        guard let heartRateBpm else { return "-- bpm" }
        return "\(Int(heartRateBpm.rounded())) bpm"
    }

    var energyText: String {
        guard let activeEnergyKilocalories else { return "-- kcal" }
        return "\(Int(activeEnergyKilocalories.rounded())) kcal"
    }

    var workoutDistanceText: String {
        guard let workoutDistanceMeters else { return "--" }
        return Formatters.distance(workoutDistanceMeters)
    }

    var watchTopStatusText: String {
        if status == .finished { return "已结束" }
        if status == .paused { return "已暂停" }
        switch routeMatchStatus {
        case .unknown:
            return status == .active ? "定位中" : status.userFacingText
        case .onRoute:
            return "路线上"
        case .suspectedOffRoute:
            return "路线待确认"
        case .offRoute:
            if let distanceFromRouteMeters {
                return "偏离 \(Formatters.distance(distanceFromRouteMeters))"
            }
            return "偏离路线"
        case .locationUnreliable:
            return "定位不稳"
        case .paused:
            return "已暂停"
        }
    }

    var watchBottomHintText: String {
        if status == .paused { return "记录暂停中" }
        if routeMatchStatus == .offRoute { return "回到路线" }
        if let routeProgressMeters {
            return "进度 \(Formatters.distance(routeProgressMeters))"
        }
        return status == .active ? "记录实际轨迹" : status.userFacingText
    }

    var routeMatchPillStyle: PillStyle {
        switch routeMatchStatus {
        case .onRoute:
            return .ok
        case .suspectedOffRoute, .locationUnreliable, .paused, .unknown:
            return .warning
        case .offRoute:
            return .danger
        }
    }
}

private extension Date {
    var relativeShortText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(self)))
        if seconds < 60 { return "\(seconds)s 前" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m 前" }
        let hours = minutes / 60
        return "\(hours)h 前"
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

private extension TrackPoint {
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

    static func compassDirection(_ degrees: Double) -> String {
        let directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let index = Int(((degrees + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return directions[max(0, min(index, directions.count - 1))]
    }
}

private extension UTType {
    static let gpx = UTType(filenameExtension: "gpx") ?? .xml
}

@MainActor
protocol WatchRouteSyncTransport: Sendable {
    var readinessText: String { get }
    func sync(_ route: InstalledRoute) -> AsyncThrowingStream<RouteSyncState, Error>
}

@MainActor
final class WatchRouteSyncService: @unchecked Sendable {
    private let transport: any WatchRouteSyncTransport

    init(transport: any WatchRouteSyncTransport) {
        self.transport = transport
    }

    func sync(_ route: InstalledRoute) -> AsyncThrowingStream<RouteSyncState, Error> {
        transport.sync(route)
    }

    var readinessText: String {
        transport.readinessText
    }
}

final class SimulatorWatchRouteSyncTransport: WatchRouteSyncTransport, @unchecked Sendable {
    let readinessText = "当前为模拟器同步模式：iPhone 侧会跑完整 manifest/payload/ACK 流程，但不会真实传到 Watch 模拟器。"
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
