import CoreMotion
import CoreLocation
@preconcurrency import HealthKit
import MapKit
import SwiftUI
import WatchKit

@main
struct WatchHikingWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRouteCardView(viewModel: WatchRouteCardViewModel())
        }
    }
}

@MainActor
final class WatchRouteCardViewModel: ObservableObject {
    @Published private(set) var route: InstalledRoute?
    @Published private(set) var session: HikingSession?
    @Published private(set) var trackPointCount = 0
    @Published private(set) var summary: SessionSummary?
    @Published private(set) var errorMessage: String?
    @Published private(set) var locationStatusText = "定位未启动"
    @Published private(set) var workoutStatusText = "运动未启动"
    @Published private(set) var workoutMetrics = WorkoutMetrics()
    @Published private(set) var uploadStatusText = "等待回传"
    @Published private(set) var trackPoints: [TrackPoint] = []
    @Published private(set) var currentCoordinate: CLLocationCoordinate2D?
    @Published private(set) var routeMatch = RouteMatchSnapshot.empty
    @Published private(set) var routeSourceText = "路线未加载"
    @Published private(set) var isLoadingRoute = false

    private let recorder: HikingSessionRecorder
    private let routeStore: RouteStore
    private let locationSampler = WatchLocationSampler()
    private let barometerSampler = WatchBarometerSampler()
    private let motionSampler = WatchMotionSampler()
    private let workoutController = WatchWorkoutController()
    private let uploadService: WatchSessionUploadService
    private var matcher: WatchRouteMatcher?
    private var isOffRouteEventOpen = false
    private var lastOffRouteUpdateAt: Date?
    private var isLocationAccuracyPoorEventOpen = false
    private var lastLiveSnapshotSentAt: Date?
    private var lastLiveSnapshotPointCount = 0
    private let freeRecordingSourceProvider = "watch-free-recording"

    init() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sessionDirectory = documentDirectory
            .appendingPathComponent("WatchSessions", isDirectory: true)
        let store = try! HikingSessionStore(directoryURL: sessionDirectory)
        recorder = HikingSessionRecorder(store: store)
        routeStore = try! RouteStore(directoryURL: documentDirectory.appendingPathComponent("WatchInstalledRoutes", isDirectory: true))
        uploadService = WatchSessionUploadService(
            sessionStore: store,
            routeStore: routeStore,
            pendingDirectoryURL: documentDirectory.appendingPathComponent("WatchPendingUploads", isDirectory: true)
        )
        locationSampler.onLocation = { [weak self] location in
            guard let self else { return }
            Task { await self.append(location) }
        }
        locationSampler.onStatusChange = { [weak self] text in
            self?.locationStatusText = text
        }
        barometerSampler.onWindow = { [weak self] window in
            guard let self else { return }
            Task {
                try? await self.recorder.appendBarometerWindow(window)
            }
        }
        motionSampler.onWindow = { [weak self] window in
            guard let self else { return }
            Task {
                try? await self.recorder.appendDeviceMotionWindow(window)
            }
        }
        workoutController.onStatusChange = { [weak self] text in
            self?.workoutStatusText = text
        }
        workoutController.onMetricsChange = { [weak self] metrics in
            self?.workoutMetrics = metrics
        }
        uploadService.onStatusChange = { [weak self] text in
            self?.uploadStatusText = text
        }
        uploadService.onRouteInstalled = { [weak self] route in
            self?.install(route: route, source: "iPhone 同步路线")
        }
    }

    var statusText: String {
        if let summary {
            return "已结束 · \(Formatters.distance(summary.distanceMeters))"
        }
        guard let session else { return "等待开始" }
        switch session.status {
        case .planned: return "计划中"
        case .active: return "记录中"
        case .paused: return "已暂停"
        case .finished: return "已结束"
        case .abandoned: return "已放弃"
        }
    }

    var canStart: Bool {
        route != nil && session == nil
    }

    var canPause: Bool {
        session?.status == .active
    }

    var canResume: Bool {
        session?.status == .paused
    }

    var canFinish: Bool {
        session?.status == .active || session?.status == .paused
    }

    func load() async {
        guard !isLoadingRoute else { return }
        uploadService.start()
        uploadService.onControlRequest = { [weak self] request in
            await self?.handle(request)
        }
        isLoadingRoute = true
        errorMessage = nil
        defer { isLoadingRoute = false }

        do {
            let freeRecordingRoute = try makeFreeRecordingRoute()
            install(route: freeRecordingRoute, source: "自由记录")
            await recoverOpenSessionIfAvailable()
            if let installed = try? await routeStore.listRoutes().first {
                install(route: installed, source: "本地安装路线")
            }
            await autoUploadDebugSessionIfRequested()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func install(route installedRoute: InstalledRoute, source: String) {
        route = installedRoute
        routeSourceText = source
        matcher = installedRoute.isFreeRecordingPlaceholder ? nil : WatchRouteMatcher(route: installedRoute)
    }

    private func recoverOpenSessionIfAvailable() async {
        do {
            guard let recovered = try await recorder.recoverOpenSession() else { return }
            session = recovered
            let snapshot = try await recorder.storedSnapshot()
            trackPoints = snapshot.trackPoints
            trackPointCount = snapshot.trackPoints.count
            currentCoordinate = snapshot.trackPoints.last?.mapCoordinate
            if recovered.status == .active {
                locationStatusText = currentCoordinate == nil ? "等待定位样本" : "定位恢复中"
                locationSampler.start()
                barometerSampler.start()
                motionSampler.start()
            }
        } catch {
            errorMessage = "旧记录恢复失败，已使用预览路线"
        }
    }

    private func makeFreeRecordingRoute() throws -> InstalledRoute {
        let points = [
            GPXTrackPoint(latitude: 37.7749, longitude: -122.4194),
            GPXTrackPoint(latitude: 37.7750, longitude: -122.4194)
        ]
        return try RouteBuilder.buildRoute(
            name: "自由记录",
            source: .manual,
            rawPoints: points,
            remoteRouteId: "watch-free-recording",
            sourceProvider: freeRecordingSourceProvider
        )
    }

    private func autoUploadDebugSessionIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--auto-upload-debug-session"),
              session == nil,
              summary == nil,
              let route else {
            return
        }

        do {
            let start = Date()
            _ = try await recorder.start(route: route, watchDeviceId: "watch-simulator-debug-upload", now: start)
            for index in 0..<5 {
                _ = try await recorder.appendLocation(
                    latitude: 37.8044 + Double(index) * 0.001,
                    longitude: -122.4776 + Double(index) * 0.0004,
                    elevationMeters: 12 + Double(index) * 4,
                    horizontalAccuracyMeters: 8,
                    speedMetersPerSecond: 1.2,
                    courseDegrees: 35,
                    heartRateBpm: 110 + Double(index),
                    timestamp: start.addingTimeInterval(Double(index + 1) * 10)
                )
            }
            _ = try await recorder.appendEvent(
                type: .offRouteStarted,
                coordinate: GeoCoordinate(latitude: 37.8060, longitude: -122.4768),
                severity: .warning,
                timestamp: start.addingTimeInterval(35)
            )
            summary = try await recorder.finish(now: start.addingTimeInterval(70))
            let snapshot = try await recorder.storedSnapshot()
            trackPoints = snapshot.trackPoints
            trackPointCount = snapshot.trackPoints.count
            currentCoordinate = snapshot.trackPoints.last?.mapCoordinate
            await uploadService.upload(snapshot)
            session = nil
            routeMatch = .empty
        } catch {
            errorMessage = "自动回传验证失败：\(error.localizedDescription)"
        }
    }

    func start() async {
        guard let route else { return }
        do {
            summary = nil
            trackPoints = []
            trackPointCount = 0
            routeMatch = .empty
            isOffRouteEventOpen = false
            lastOffRouteUpdateAt = nil
            isLocationAccuracyPoorEventOpen = false
            session = try await recorder.start(route: route, watchDeviceId: "watch-simulator")
            await workoutController.start()
            locationSampler.start()
            barometerSampler.start()
            motionSampler.start()
            await sendLiveSnapshotIfNeeded(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause() async {
        do {
            locationSampler.stop()
            barometerSampler.stop()
            motionSampler.stop()
            workoutController.pause()
            try await recorder.pause()
            session = await recorder.currentSession
            await sendLiveSnapshotIfNeeded(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resume() async {
        do {
            try await recorder.resume()
            session = await recorder.currentSession
            await workoutController.resume()
            locationSampler.start()
            barometerSampler.start()
            motionSampler.start()
            await sendLiveSnapshotIfNeeded(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finish() async {
        do {
            locationSampler.stop()
            barometerSampler.stop()
            motionSampler.stop()
            await workoutController.finish()
            if session?.status == .paused {
                try await recorder.resume()
            }
            summary = try await recorder.finish()
            let snapshot = try await recorder.storedSnapshot()
            trackPoints = snapshot.trackPoints
            trackPointCount = snapshot.trackPoints.count
            currentCoordinate = snapshot.trackPoints.last?.mapCoordinate
            session = snapshot.session
            await sendLiveSnapshotIfNeeded(force: true)
            await uploadService.upload(snapshot)
            session = nil
            routeMatch = .empty
            isOffRouteEventOpen = false
            lastOffRouteUpdateAt = nil
            isLocationAccuracyPoorEventOpen = false
            lastLiveSnapshotSentAt = nil
            lastLiveSnapshotPointCount = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func append(_ location: CLLocation) async {
        do {
            let evidenceTiming = EvidenceLocationTiming(locationTimestamp: location.timestamp)
            currentCoordinate = location.coordinate
            let match = matcher?.match(
                location: location,
                isPaused: session?.status == .paused,
                previous: routeMatch
            ) ?? .empty
            routeMatch = match
            try await recordRouteMatchEventIfNeeded(match, location: location)
            _ = try await recorder.appendLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                elevationMeters: location.altitude,
                horizontalAccuracyMeters: location.horizontalAccuracy,
                verticalAccuracyMeters: location.verticalAccuracy,
                speedMetersPerSecond: location.speed >= 0 ? location.speed : nil,
                courseDegrees: location.course >= 0 ? location.course : nil,
                heartRateBpm: workoutMetrics.heartRateBpm,
                nearestRouteDistanceMeters: match.distanceFromRouteMeters,
                routeProgressMeters: match.routeProgressMeters,
                timestamp: location.timestamp,
                evidenceTiming: evidenceTiming
            )
            let snapshot = try await recorder.storedSnapshot()
            trackPoints = snapshot.trackPoints
            trackPointCount = snapshot.trackPoints.count
            session = snapshot.session
            locationStatusText = "定位中 · 精度 \(Int(location.horizontalAccuracy.rounded()))m"
            await sendLiveSnapshotIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendLiveSnapshotIfNeeded(force: Bool = false) async {
        guard let session else { return }
        guard force || session.status == .active || session.status == .paused else { return }
        let now = Date()
        let elapsed = lastLiveSnapshotSentAt.map { now.timeIntervalSince($0) } ?? .infinity
        let hasNewPoints = trackPointCount > lastLiveSnapshotPointCount
        guard force || (hasNewPoints && elapsed >= 5) || trackPointCount - lastLiveSnapshotPointCount >= 5 else { return }
        let routePoints = route?.isFreeRecordingPlaceholder == true ? [] : route?.simplifiedForWatch.points.map(\.coordinate) ?? []
        await uploadService.sendLiveSnapshot(
            session: session,
            trackPoints: trackPoints,
            routePoints: routePoints,
            workoutMetrics: workoutMetrics,
            routeMatch: routeMatch
        )
        lastLiveSnapshotSentAt = now
        lastLiveSnapshotPointCount = trackPointCount
    }

    private func handle(_ request: WatchControlRequest) async {
        switch request.action {
        case .sendLiveSnapshot:
            if session != nil {
                await sendLiveSnapshotIfNeeded(force: true)
                uploadStatusText = "已按 iPhone 请求回传"
                return
            }

            do {
                let snapshot = try await recorder.storedSnapshot()
                guard snapshot.session.status == .finished else {
                    uploadStatusText = "暂无可回传会话"
                    return
                }
                await uploadService.upload(snapshot)
            } catch {
                uploadStatusText = "请求回传失败：\(error.localizedDescription)"
            }
        }
    }

    private func recordRouteMatchEventIfNeeded(_ match: RouteMatchSnapshot, location: CLLocation) async throws {
        switch match.status {
        case .offRoute:
            if !isOffRouteEventOpen {
                WKInterfaceDevice.current().play(.failure)
                _ = try await recorder.appendEvent(
                    type: .offRouteStarted,
                    coordinate: location.geoCoordinate,
                    routeProgressMeters: match.routeProgressMeters,
                    severity: .warning,
                    payload: match.eventPayload,
                    timestamp: location.timestamp
                )
                isOffRouteEventOpen = true
                lastOffRouteUpdateAt = location.timestamp
            } else if shouldRecordOffRouteUpdate(at: location.timestamp) {
                _ = try await recorder.appendEvent(
                    type: .offRouteUpdated,
                    coordinate: location.geoCoordinate,
                    routeProgressMeters: match.routeProgressMeters,
                    severity: .warning,
                    payload: match.eventPayload,
                    timestamp: location.timestamp
                )
                lastOffRouteUpdateAt = location.timestamp
            }
        case .onRoute:
            if isLocationAccuracyPoorEventOpen {
                _ = try await recorder.appendEvent(
                    type: .locationRecovered,
                    coordinate: location.geoCoordinate,
                    routeProgressMeters: match.routeProgressMeters,
                    payload: match.eventPayload,
                    timestamp: location.timestamp
                )
                isLocationAccuracyPoorEventOpen = false
            }
            if isOffRouteEventOpen {
                WKInterfaceDevice.current().play(.success)
                _ = try await recorder.appendEvent(
                    type: .offRouteEnded,
                    coordinate: location.geoCoordinate,
                    routeProgressMeters: match.routeProgressMeters,
                    payload: match.eventPayload,
                    timestamp: location.timestamp
                )
                isOffRouteEventOpen = false
                lastOffRouteUpdateAt = nil
            }
        case .locationUnreliable:
            if !isLocationAccuracyPoorEventOpen {
                _ = try await recorder.appendEvent(
                    type: .locationAccuracyPoor,
                    coordinate: location.geoCoordinate,
                    routeProgressMeters: match.routeProgressMeters,
                    severity: .warning,
                    payload: match.eventPayload,
                    timestamp: location.timestamp
                )
                isLocationAccuracyPoorEventOpen = true
            }
        case .unknown, .suspectedOffRoute, .paused:
            break
        }
    }

    private func shouldRecordOffRouteUpdate(at timestamp: Date) -> Bool {
        guard let lastOffRouteUpdateAt else { return true }
        return timestamp.timeIntervalSince(lastOffRouteUpdateAt) >= 120
    }
}

private extension EvidenceLocationTiming {
    init(locationTimestamp: Date, receivedAt: Date = Date()) {
        let receivedNanos = Int64((ProcessInfo.processInfo.systemUptime * 1_000_000_000).rounded())
        let callbackDelay = max(0, Int64((receivedAt.timeIntervalSince(locationTimestamp) * 1_000_000_000).rounded()))
        self.init(
            estimatedFixElapsedRealtimeNanos: receivedNanos - callbackDelay,
            receivedElapsedRealtimeNanos: receivedNanos,
            callbackDelayNanos: callbackDelay
        )
    }
}

struct RouteMatchSnapshot: Equatable {
    enum Status: Equatable {
        case unknown
        case onRoute
        case suspectedOffRoute
        case offRoute
        case locationUnreliable
        case paused
    }

    var status: Status
    var distanceFromRouteMeters: Double?
    var routeProgressMeters: Double?
    var projectedCoordinate: CLLocationCoordinate2D?
    var bearingToRouteDegrees: Double?
    var consecutiveOffRoutePointCount: Int

    static let empty = RouteMatchSnapshot(
        status: .unknown,
        distanceFromRouteMeters: nil,
        routeProgressMeters: nil,
        projectedCoordinate: nil,
        bearingToRouteDegrees: nil,
        consecutiveOffRoutePointCount: 0
    )

    static func == (lhs: RouteMatchSnapshot, rhs: RouteMatchSnapshot) -> Bool {
        lhs.status == rhs.status &&
            lhs.distanceFromRouteMeters == rhs.distanceFromRouteMeters &&
            lhs.routeProgressMeters == rhs.routeProgressMeters &&
            lhs.projectedCoordinate?.latitude == rhs.projectedCoordinate?.latitude &&
            lhs.projectedCoordinate?.longitude == rhs.projectedCoordinate?.longitude &&
            lhs.bearingToRouteDegrees == rhs.bearingToRouteDegrees &&
            lhs.consecutiveOffRoutePointCount == rhs.consecutiveOffRoutePointCount
    }
}

extension RouteMatchSnapshot {
    var liveSnapshotStatus: LiveTrackSnapshot.RouteMatchStatus {
        switch status {
        case .unknown: .unknown
        case .onRoute: .onRoute
        case .suspectedOffRoute: .suspectedOffRoute
        case .offRoute: .offRoute
        case .locationUnreliable: .locationUnreliable
        case .paused: .paused
        }
    }

    var eventPayload: [String: String] {
        var payload: [String: String] = [:]
        if let distanceFromRouteMeters {
            payload["distanceFromRouteMeters"] = String(format: "%.1f", distanceFromRouteMeters)
        }
        if let bearingToRouteDegrees {
            payload["bearingToRouteDegrees"] = String(format: "%.1f", bearingToRouteDegrees)
        }
        if let routeProgressMeters {
            payload["routeProgressMeters"] = String(format: "%.1f", routeProgressMeters)
        }
        payload["status"] = "\(status)"
        return payload
    }
}

private struct WatchRouteMatcher {
    private let points: [RoutePoint]
    private let offRouteThresholdMeters = 30.0
    private let returnThresholdMeters = 20.0
    private let locationWeakAccuracyMeters = 50.0
    private let confirmPointCount = 3

    init(route: InstalledRoute) {
        points = route.simplifiedForWatch.points
    }

    func match(location: CLLocation, isPaused: Bool, previous: RouteMatchSnapshot) -> RouteMatchSnapshot {
        guard !isPaused else {
            var paused = previous
            paused.status = .paused
            paused.consecutiveOffRoutePointCount = 0
            return paused
        }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= locationWeakAccuracyMeters else {
            var unreliable = previous
            unreliable.status = .locationUnreliable
            unreliable.consecutiveOffRoutePointCount = 0
            return unreliable
        }
        guard let nearest = nearestProjection(to: location.coordinate) else { return .empty }

        let current = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let projected = GeoCoordinate(latitude: nearest.coordinate.latitude, longitude: nearest.coordinate.longitude)
        let distance = GeoMath.distanceMeters(from: current, to: projected)
        let offRouteCount = distance > offRouteThresholdMeters ? previous.consecutiveOffRoutePointCount + 1 : 0
        let status: RouteMatchSnapshot.Status
        if distance <= returnThresholdMeters {
            status = .onRoute
        } else if offRouteCount >= confirmPointCount {
            status = .offRoute
        } else if distance > offRouteThresholdMeters {
            status = .suspectedOffRoute
        } else {
            status = .onRoute
        }

        return RouteMatchSnapshot(
            status: status,
            distanceFromRouteMeters: distance,
            routeProgressMeters: nearest.routeProgressMeters,
            projectedCoordinate: nearest.coordinate,
            bearingToRouteDegrees: GeoMath.bearingDegrees(from: current, to: projected),
            consecutiveOffRoutePointCount: offRouteCount
        )
    }

    private func nearestProjection(to coordinate: CLLocationCoordinate2D) -> (coordinate: CLLocationCoordinate2D, routeProgressMeters: Double)? {
        guard points.count > 1 else { return nil }
        let origin = PlanarPoint(coordinate: coordinate, referenceLatitude: coordinate.latitude)
        var best: (coordinate: CLLocationCoordinate2D, routeProgressMeters: Double, squaredDistance: Double)?

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let startXY = PlanarPoint(coordinate: start.mapCoordinate, referenceLatitude: coordinate.latitude)
            let endXY = PlanarPoint(coordinate: end.mapCoordinate, referenceLatitude: coordinate.latitude)
            let dx = endXY.x - startXY.x
            let dy = endXY.y - startXY.y
            let lengthSquared = dx * dx + dy * dy
            let t = lengthSquared == 0 ? 0 : max(0, min(1, ((origin.x - startXY.x) * dx + (origin.y - startXY.y) * dy) / lengthSquared))
            let projectedX = startXY.x + t * dx
            let projectedY = startXY.y + t * dy
            let squaredDistance = pow(origin.x - projectedX, 2) + pow(origin.y - projectedY, 2)
            let progress = start.distanceFromStartMeters + (end.distanceFromStartMeters - start.distanceFromStartMeters) * t
            let projected = CLLocationCoordinate2D(
                latitude: projectedY / PlanarPoint.metersPerDegreeLatitude,
                longitude: projectedX / (PlanarPoint.metersPerDegreeLatitude * cos(coordinate.latitude * .pi / 180))
            )

            if best == nil || squaredDistance < best!.squaredDistance {
                best = (projected, progress, squaredDistance)
            }
        }
        return best.map { ($0.coordinate, $0.routeProgressMeters) }
    }
}

private struct PlanarPoint {
    static let metersPerDegreeLatitude = 111_320.0
    var x: Double
    var y: Double

    init(coordinate: CLLocationCoordinate2D, referenceLatitude: Double) {
        x = coordinate.longitude * Self.metersPerDegreeLatitude * cos(referenceLatitude * .pi / 180)
        y = coordinate.latitude * Self.metersPerDegreeLatitude
    }
}

struct WorkoutMetrics: Equatable {
    var heartRateBpm: Double?
    var activeEnergyKilocalories: Double?
    var distanceMeters: Double?

    var heartRateText: String {
        guard let heartRateBpm else { return "-- bpm" }
        return "\(Int(heartRateBpm.rounded())) bpm"
    }

    var energyText: String {
        guard let activeEnergyKilocalories else { return "-- kcal" }
        return "\(Int(activeEnergyKilocalories.rounded())) kcal"
    }

    var distanceText: String {
        guard let distanceMeters else { return "--" }
        return Formatters.distance(distanceMeters)
    }
}

@MainActor
final class WatchWorkoutController: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    var onStatusChange: ((String) -> Void)?
    var onMetricsChange: ((WorkoutMetrics) -> Void)?

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var metrics = WorkoutMetrics()

    func start() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            onStatusChange?("HealthKit 不可用")
            return
        }

        do {
            try await requestAuthorization()
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .hiking
            configuration.locationType = .outdoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            workoutSession = session
            workoutBuilder = builder

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            metrics = WorkoutMetrics()
            onMetricsChange?(metrics)
            onStatusChange?("运动记录中")
        } catch {
            onStatusChange?("运动启动失败：\(error.localizedDescription)")
        }
    }

    func pause() {
        workoutSession?.pause()
        onStatusChange?("运动已暂停")
    }

    func resume() async {
        if workoutSession == nil {
            await start()
            return
        }
        workoutSession?.resume()
        onStatusChange?("运动记录中")
    }

    func finish() async {
        guard let session = workoutSession, let builder = workoutBuilder else {
            onStatusChange?("运动已结束")
            return
        }
        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
            onStatusChange?("运动已保存")
        } catch {
            onStatusChange?("运动保存失败：\(error.localizedDescription)")
        }
        workoutSession = nil
        workoutBuilder = nil
    }

    private func requestAuthorization() async throws {
        let workoutType = HKObjectType.workoutType()
        let typesToShare: Set<HKSampleType> = [workoutType]
        let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)
        let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        let typesToRead = Set([heartRate, activeEnergy, distance].compactMap { $0 })
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            self?.handleWorkoutStateChange(to: toState)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.onStatusChange?("运动失败：\(error.localizedDescription)")
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor [weak self] in
            self?.collectMetrics(from: workoutBuilder, collectedTypes: collectedTypes)
        }
    }

    private func handleWorkoutStateChange(to toState: HKWorkoutSessionState) {
        switch toState {
        case .running:
            onStatusChange?("运动记录中")
        case .paused:
            onStatusChange?("运动已暂停")
        case .ended:
            onStatusChange?("运动结束中")
        case .stopped:
            onStatusChange?("运动已停止")
        case .prepared:
            onStatusChange?("运动准备中")
        case .notStarted:
            onStatusChange?("运动未启动")
        @unknown default:
            onStatusChange?("运动状态未知")
        }
    }

    private func collectMetrics(from workoutBuilder: HKLiveWorkoutBuilder, collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                metrics.heartRateBpm = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                metrics.activeEnergyKilocalories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
            case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
                metrics.distanceMeters = statistics?.sumQuantity()?.doubleValue(for: .meter())
            default:
                break
            }
        }
        onMetricsChange?(metrics)
    }
}

@MainActor
final class WatchBarometerSampler {
    var onWindow: ((EvidenceBarometerWindow) -> Void)?

    private let altimeter = CMAltimeter()
    private let queue = OperationQueue()
    private var accumulator = EvidenceBarometerWindowAccumulator(windowSeconds: 10)
    private var isRunning = false

    init() {
        queue.name = "WatchBarometerSampler"
        queue.qualityOfService = .utility
    }

    func start() {
        guard !isRunning, CMAltimeter.isRelativeAltitudeAvailable() else { return }
        accumulator = EvidenceBarometerWindowAccumulator(windowSeconds: 10)
        isRunning = true
        altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, error in
            guard error == nil, let data else { return }
            let sample = EvidenceBarometerSample(
                elapsedRealtimeNanos: Int64((ProcessInfo.processInfo.systemUptime * 1_000_000_000).rounded()),
                relativeAltitudeMeters: data.relativeAltitude.doubleValue,
                pressureKpa: data.pressure.doubleValue
            )
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                if let window = self.accumulator.append(sample) {
                    self.onWindow?(window)
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        altimeter.stopRelativeAltitudeUpdates()
        if let window = accumulator.flush(), window.sampleCount > 1 {
            onWindow?(window)
        }
    }
}

@MainActor
final class WatchMotionSampler {
    var onWindow: ((EvidenceDeviceMotionWindow) -> Void)?

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var accumulator = EvidenceDeviceMotionWindowAccumulator(windowSeconds: 10)
    private var isRunning = false

    init() {
        queue.name = "WatchMotionSampler"
        queue.qualityOfService = .utility
    }

    func start() {
        guard !isRunning, motionManager.isDeviceMotionAvailable else { return }
        accumulator = EvidenceDeviceMotionWindowAccumulator(windowSeconds: 10)
        motionManager.deviceMotionUpdateInterval = 1
        isRunning = true
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard error == nil, let motion else { return }
            let sample = EvidenceDeviceMotionSample(
                elapsedRealtimeNanos: Int64((ProcessInfo.processInfo.systemUptime * 1_000_000_000).rounded()),
                userAccelerationXMps2: motion.userAcceleration.x * 9.80665,
                userAccelerationYMps2: motion.userAcceleration.y * 9.80665,
                userAccelerationZMps2: motion.userAcceleration.z * 9.80665,
                rotationRateXRadps: motion.rotationRate.x,
                rotationRateYRadps: motion.rotationRate.y,
                rotationRateZRadps: motion.rotationRate.z
            )
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                if let window = self.accumulator.append(sample) {
                    self.onWindow?(window)
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
        if let window = accumulator.flush(), window.sampleCount > 1 {
            onWindow?(window)
        }
    }
}

@MainActor
final class WatchLocationSampler: NSObject, @MainActor CLLocationManagerDelegate {
    var onLocation: ((CLLocation) -> Void)?
    var onStatusChange: ((String) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = true
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            onStatusChange?("等待定位授权")
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            onStatusChange?("定位启动中")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            onStatusChange?("定位未授权")
        @unknown default:
            onStatusChange?("定位状态未知")
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        onStatusChange?("定位已停止")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            onStatusChange?("定位已授权")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            onStatusChange?("定位未授权")
        case .notDetermined:
            onStatusChange?("等待定位授权")
        @unknown default:
            onStatusChange?("定位状态未知")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        onLocation?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onStatusChange?("定位失败：\(error.localizedDescription)")
    }
}

struct WatchRouteCardView: View {
    @StateObject var viewModel: WatchRouteCardViewModel

    var body: some View {
        Group {
            if let route = viewModel.route {
                WatchNavigationMapScreen(route: route, viewModel: viewModel)
            } else {
                WatchRouteWaitingView(viewModel: viewModel)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            await viewModel.load()
        }
    }
}

struct WatchRouteWaitingView: View {
    @ObservedObject var viewModel: WatchRouteCardViewModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.title3)
                .foregroundStyle(.green)

            Text(viewModel.isLoadingRoute ? "读取路线中" : "等待路线")
                .font(.headline)

            Text(viewModel.errorMessage ?? "未收到 iPhone 路线时会载入预览路线。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)

            Button {
                Task { await viewModel.load() }
            } label: {
                Label(viewModel.isLoadingRoute ? "读取中" : "重试", systemImage: "arrow.clockwise")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isLoadingRoute)
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WatchNavigationMapScreen: View {
    let route: InstalledRoute
    @ObservedObject var viewModel: WatchRouteCardViewModel
    @State private var isChromeVisible = true

    var body: some View {
        ZStack {
            WatchRouteMapView(
                route: route,
                trackPoints: viewModel.trackPoints,
                currentCoordinate: viewModel.currentCoordinate,
                routeMatch: viewModel.routeMatch,
                sessionStatus: viewModel.session?.status,
                summary: viewModel.summary
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isChromeVisible.toggle()
                }
            }

            if isChromeVisible {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    WatchBottomOverlay(route: route, viewModel: viewModel)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .containerBackground(.clear, for: .navigation)
    }
}

struct WatchRouteMapView: View {
    let route: InstalledRoute
    let trackPoints: [TrackPoint]
    let currentCoordinate: CLLocationCoordinate2D?
    let routeMatch: RouteMatchSnapshot
    let sessionStatus: HikingSessionStatus?
    let summary: SessionSummary?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lastAutoCenterAt = Date.distantPast
    @State private var lastCenteredCoordinate: CLLocationCoordinate2D?

    var body: some View {
        Map(position: $cameraPosition) {
            if !isFreeRecording {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.cyan, lineWidth: 5)
            }

            if trackCoordinates.count > 1 {
                MapPolyline(coordinates: trackCoordinates)
                    .stroke(.orange.opacity(0.75), lineWidth: 3)
            }

            if let currentCoordinate {
                Annotation("", coordinate: currentCoordinate) {
                    Image(systemName: "location.north.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.blue, in: Circle())
                }
            }

            if !isFreeRecording, let currentCoordinate, let projected = routeMatch.projectedCoordinate, routeMatch.status == .offRoute {
                MapPolyline(coordinates: [currentCoordinate, projected])
                    .stroke(.red, style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
            }

            if !isFreeRecording {
                Annotation("", coordinate: route.route.startPoint.mapCoordinate) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
                Annotation("", coordinate: route.route.endPoint.mapCoordinate) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .mapControlVisibility(.hidden)
        .onAppear {
            cameraPosition = .region(mapRegion)
            if let currentCoordinate {
                lastCenteredCoordinate = currentCoordinate
                lastAutoCenterAt = Date()
            }
        }
        .onChange(of: trackPoints.count) { _, _ in
            autoCenterIfNeeded()
        }
        .onChange(of: sessionStatus) { _, _ in
            autoCenterIfNeeded(force: true)
        }
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        route.simplifiedForWatch.points.map(\.mapCoordinate)
    }

    private var trackCoordinates: [CLLocationCoordinate2D] {
        trackPoints.map(\.mapCoordinate)
    }

    private var isFreeRecording: Bool {
        route.isFreeRecordingPlaceholder
    }

    private var mapRegion: MKCoordinateRegion {
        if let currentCoordinate {
            return MKCoordinateRegion(
                center: currentCoordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
        }
        return MKCoordinateRegion(
            center: route.route.bounds.centerCoordinate,
            span: route.route.bounds.coordinateSpan(padding: 1.25)
        )
    }

    private func autoCenterIfNeeded(force: Bool = false) {
        guard summary == nil else { return }
        guard sessionStatus == .active || force else { return }
        guard let currentCoordinate else { return }

        let now = Date()
        let interval = routeMatch.status == .offRoute ? 5.0 : 12.0
        let movedMeters = lastCenteredCoordinate.map {
            GeoMath.distanceMeters(
                from: GeoCoordinate(latitude: $0.latitude, longitude: $0.longitude),
                to: GeoCoordinate(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
            )
        } ?? .infinity

        guard force || now.timeIntervalSince(lastAutoCenterAt) >= interval || movedMeters >= 80 else {
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: currentCoordinate,
                latitudinalMeters: routeMatch.status == .offRoute ? 380 : 500,
                longitudinalMeters: routeMatch.status == .offRoute ? 380 : 500
            ))
        }
        lastCenteredCoordinate = currentCoordinate
        lastAutoCenterAt = now
    }

    var topStatusText: String {
        if summary != nil { return "已结束" }
        if sessionStatus == .paused { return "已暂停" }
        if isFreeRecording {
            return sessionStatus == .active ? "自由记录中" : "自由记录"
        }
        switch routeMatch.status {
        case .offRoute:
            return "偏离 \(Formatters.distance(routeMatch.distanceFromRouteMeters ?? 0))"
        case .locationUnreliable:
            return "定位不稳"
        case .onRoute:
            return "路线上"
        case .suspectedOffRoute:
            return "路线待确认"
        case .paused:
            return "已暂停"
        case .unknown:
            if sessionStatus == .active {
                return currentCoordinate == nil ? "等待定位" : "定位中"
            }
            return route.route.name
        }
    }

    var bottomHintText: String {
        if sessionStatus == .paused { return "记录暂停中" }
        if isFreeRecording {
            return sessionStatus == .active ? "记录实际轨迹" : "无路线也可开始"
        }
        if routeMatch.status == .offRoute, let bearing = routeMatch.bearingToRouteDegrees {
            return "向\(Formatters.compassDirection(bearing))回到路线"
        }
        if let progress = routeMatch.routeProgressMeters {
            return "剩余 \(Formatters.distance(max(0, route.route.distanceMeters - progress)))"
        }
        return route.route.distanceText
    }

    var statusTint: Color {
        switch routeMatch.status {
        case .offRoute:
            return .red
        case .locationUnreliable:
            return .orange
        case .onRoute:
            return .green
        default:
            return .blue
        }
    }
}

struct WatchRouteHintOverlay: View {
    let route: InstalledRoute
    @ObservedObject var viewModel: WatchRouteCardViewModel

    var body: some View {
        let mapState = WatchRouteMapView(
            route: route,
            trackPoints: viewModel.trackPoints,
            currentCoordinate: viewModel.currentCoordinate,
            routeMatch: viewModel.routeMatch,
            sessionStatus: viewModel.session?.status,
            summary: viewModel.summary
        )

        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(mapState.statusTint)
                .frame(width: 3, height: 18)

            Text(mapState.topStatusText)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)

            if let directionBearingDegrees {
                Image(systemName: "location.north.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(directionBearingDegrees))
                    .frame(width: 14, height: 14)
                    .accessibilityLabel("回到路线方向")
            }

            Text(mapState.bottomHintText)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
    }

    private var directionBearingDegrees: Double? {
        guard viewModel.routeMatch.status == .offRoute else { return nil }
        return viewModel.routeMatch.bearingToRouteDegrees
    }
}

struct WatchBottomOverlay: View {
    let route: InstalledRoute
    @ObservedObject var viewModel: WatchRouteCardViewModel

    var body: some View {
        VStack(spacing: 5) {
            WatchRouteHintOverlay(route: route, viewModel: viewModel)

            HStack(spacing: 4) {
                CompactMetric(value: viewModel.workoutMetrics.heartRateText, title: "心率")
                CompactMetric(value: viewModel.workoutMetrics.distanceText, title: "距离")
                CompactMetric(value: viewModel.workoutMetrics.energyText, title: "能量")
            }
            WatchCompactControls(viewModel: viewModel)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

struct CompactMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }
}

struct WatchCompactControls: View {
    @ObservedObject var viewModel: WatchRouteCardViewModel
    @State private var isConfirmingFinish = false

    var body: some View {
        HStack(spacing: 8) {
            if isConfirmingFinish {
                CompactControlButton(title: "取消", systemImage: "xmark", tint: .gray) {
                    isConfirmingFinish = false
                }
                CompactControlButton(title: "确认结束", systemImage: "checkmark", tint: .red) {
                    isConfirmingFinish = false
                    Task { await viewModel.finish() }
                }
            } else if viewModel.canStart {
                CompactControlButton(title: "开始", systemImage: "play.fill", tint: .green) {
                    Task { await viewModel.start() }
                }
            } else if viewModel.canPause {
                CompactControlButton(title: "暂停", systemImage: "pause.fill", tint: .orange) {
                    Task { await viewModel.pause() }
                }
            } else if viewModel.canResume {
                CompactControlButton(title: "继续", systemImage: "play.fill", tint: .green) {
                    Task { await viewModel.resume() }
                }
            }

            if viewModel.canFinish && !isConfirmingFinish {
                CompactControlButton(title: "结束", systemImage: "stop.fill", tint: .red) {
                    isConfirmingFinish = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: viewModel.canFinish) { _, canFinish in
            if !canFinish {
                isConfirmingFinish = false
            }
        }
    }
}

struct CompactControlButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .background(tint.opacity(0.92), in: Capsule())
        .foregroundStyle(.white)
    }
}

struct WatchCompactStatus: View {
    @ObservedObject var viewModel: WatchRouteCardViewModel

    var body: some View {
        Text(statusLine)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLine: String {
        if let errorMessage = viewModel.errorMessage {
            return errorMessage
        }
        return "\(viewModel.statusText) · \(viewModel.uploadStatusText)"
    }
}

struct WatchStatusFooter: View {
    @ObservedObject var viewModel: WatchRouteCardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.statusText)
            Text(viewModel.routeSourceText)
            Text(viewModel.workoutStatusText)
            Text(viewModel.locationStatusText)
            Text(viewModel.uploadStatusText)
            if let summary = viewModel.summary {
                Text("用时 \(summary.durationText) · \(viewModel.uploadStatusText)")
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WatchMetricsGrid: View {
    let metrics: WorkoutMetrics

    var body: some View {
        HStack(spacing: 6) {
            WatchMetricCell(title: "心率", value: metrics.heartRateText)
            WatchMetricCell(title: "能量", value: metrics.energyText)
            WatchMetricCell(title: "距离", value: metrics.distanceText)
        }
    }
}

struct WatchMetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WatchSessionControls: View {
    @ObservedObject var viewModel: WatchRouteCardViewModel
    @State private var isShowingFinishConfirmation = false

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.canStart {
                Button {
                    Task { await viewModel.start() }
                } label: {
                    Label("开始", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.canPause {
                Button {
                    Task { await viewModel.pause() }
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                }
            }

            if viewModel.canResume {
                Button {
                    Task { await viewModel.resume() }
                } label: {
                    Label("继续", systemImage: "play.fill")
                }
            }

            if viewModel.canFinish {
                Button(role: .destructive) {
                    isShowingFinishConfirmation = true
                } label: {
                    Label("结束", systemImage: "stop.fill")
                }
            }
        }
        .confirmationDialog("结束本次记录？", isPresented: $isShowingFinishConfirmation, titleVisibility: .visible) {
            Button("确认结束", role: .destructive) {
                Task { await viewModel.finish() }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

private extension HikingRoute {
    var distanceText: String {
        Formatters.distance(distanceMeters)
    }
}

private extension InstalledRoute {
    var isFreeRecordingPlaceholder: Bool {
        route.remoteRouteId == "watch-free-recording" || route.sourceProvider == "watch-free-recording"
    }
}

private extension RoutePoint {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension TrackPoint {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension GeoCoordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension CLLocation {
    var geoCoordinate: GeoCoordinate {
        GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private extension GeoBounds {
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
    }

    func coordinateSpan(padding: Double) -> MKCoordinateSpan {
        MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * padding, 0.005),
            longitudeDelta: max((maxLongitude - minLongitude) * padding, 0.005)
        )
    }
}

private extension SessionSummary {
    var durationText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return "\(minutes)m \(seconds)s"
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
