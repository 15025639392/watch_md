import Combine
import Foundation
import WatchConnectivity

@MainActor
final class iPhoneSessionSyncService: NSObject, ObservableObject {
    static let shared = iPhoneSessionSyncService()

    @Published private(set) var receivedSessions: [ReceivedSessionRecord] = []
    @Published private(set) var liveTrackSnapshot: LiveTrackSnapshot?
    @Published private(set) var lastSyncMessage = "等待 Watch 回传"
    @Published private(set) var isWatchConnectivityAvailable = WCSession.isSupported()
    @Published private(set) var isWatchConnected = false
    @Published private(set) var watchConnectionTitle = "检查 Watch"
    @Published private(set) var watchConnectionDetail = "正在读取 Apple Watch 状态"

    private let receiver = iPhoneSessionSyncReceiver()
    private let store: iPhoneReceivedSessionStore
    private let session: WCSession?
    private var routeSyncContinuation: AsyncThrowingStream<RouteSyncState, Error>.Continuation?
    private var routeSyncCoordinator: RouteSyncCoordinator?
    private var pendingRoute: InstalledRoute?

    override init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReceivedSessions", isDirectory: true)
        store = try! iPhoneReceivedSessionStore(directoryURL: directory)
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
    }

    func start() {
        guard let session else {
            lastSyncMessage = "当前设备不支持 WatchConnectivity"
            isWatchConnected = false
            watchConnectionTitle = "当前设备不支持"
            watchConnectionDetail = "这台设备不能与 Apple Watch 通信"
            return
        }
        updateWatchConnectionState(session)
        session.activate()
        Task {
            await reloadStoredSessions()
        }
    }

    private func updateCurrentWatchConnectionState() {
        guard let session else {
            isWatchConnected = false
            watchConnectionTitle = "当前设备不支持"
            watchConnectionDetail = "这台设备不能与 Apple Watch 通信"
            return
        }
        updateWatchConnectionState(session)
    }

    private func updateWatchConnectionState(_ session: WCSession) {
        isWatchConnectivityAvailable = WCSession.isSupported()

        guard isWatchConnectivityAvailable else {
            isWatchConnected = false
            watchConnectionTitle = "当前设备不支持"
            watchConnectionDetail = "这台设备不能与 Apple Watch 通信"
            return
        }

        guard session.activationState == .activated else {
            isWatchConnected = false
            watchConnectionTitle = "正在连接 Watch"
            watchConnectionDetail = "WatchConnectivity 正在激活"
            return
        }

        guard session.isPaired else {
            isWatchConnected = false
            watchConnectionTitle = "未配对 Watch"
            watchConnectionDetail = "请先在 iPhone 上配对 Apple Watch"
            return
        }

        guard session.isWatchAppInstalled else {
            isWatchConnected = false
            watchConnectionTitle = "Watch App 未安装"
            watchConnectionDetail = "请先把 Watch App 安装到 Apple Watch"
            return
        }

        if session.isReachable {
            isWatchConnected = true
            watchConnectionTitle = "Watch 已连接"
            watchConnectionDetail = "可以实时通信；结束后也会继续支持可靠回传"
        } else {
            isWatchConnected = true
            watchConnectionTitle = "Watch 后台同步可用"
            watchConnectionDetail = "Watch 可能在后台；路线和回传会通过可靠队列继续同步"
        }
    }

    private func reloadStoredSessions() async {
        do {
            receivedSessions = try await store.listRecords()
        } catch {
            lastSyncMessage = "读取历史回传失败：\(error.localizedDescription)"
        }
    }

    private func handleEnvelopeData(_ data: Data) async {
        do {
            let header = try RouteSyncCodec.decoder.decode(SyncEnvelopeHeader.self, from: data)
            let ack: SyncEnvelope<SyncAck>
            let sessionId: String

            switch header.kind {
            case .syncAck:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<SyncAck>.self, from: data)
                await handleRouteSyncAck(envelope.payload)
                return
            case .sessionStatus:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<SessionStatusPayload>.self, from: data)
                ack = try await receiver.receiveStatus(envelope)
                sessionId = envelope.payload.sessionId
            case .liveTrackSnapshot:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<LiveTrackSnapshot>.self, from: data)
                liveTrackSnapshot = envelope.payload
                lastSyncMessage = "Watch 位置已回传"
                return
            case .trackChunk:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<TrackChunk>.self, from: data)
                ack = try await receiver.receiveTrackChunk(envelope)
                sessionId = envelope.payload.sessionId
            case .eventChunk:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<EventChunk>.self, from: data)
                ack = try await receiver.receiveEventChunk(envelope)
                sessionId = envelope.payload.sessionId
            case .evidenceManifest:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<EvidenceManifest>.self, from: data)
                ack = try await receiver.receiveEvidenceManifest(envelope)
                sessionId = envelope.payload.sessionId
            case .evidenceChunk:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<EvidenceChunk>.self, from: data)
                ack = try await receiver.receiveEvidenceChunk(envelope)
                sessionId = envelope.payload.sessionId
                if let evidenceData = try await receiver.evidenceData(sessionId: sessionId) {
                    try await store.saveEvidence(sessionId: sessionId, data: evidenceData)
                }
            case .sessionSummary:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<SessionSummary>.self, from: data)
                ack = try await receiver.receiveSummary(envelope)
                sessionId = envelope.payload.sessionId
            case .routeManifest, .routePayload:
                lastSyncMessage = "收到非会话回传数据：\(header.kind.rawValue)"
                return
            }

            if let record = await receiver.record(sessionId: sessionId) {
                try await store.save(record)
                await reloadStoredSessions()
            }
            sendAck(ack)
            lastSyncMessage = message(for: ack.payload)
        } catch {
            lastSyncMessage = "处理 Watch 回传失败：\(error.localizedDescription)"
        }
    }

    private func sendAck(_ envelope: SyncEnvelope<SyncAck>) {
        do {
            let data = try RouteSyncCodec.encoder.encode(envelope)
            sendEnvelopeData(data, kind: envelope.kind.rawValue)
        } catch {
            lastSyncMessage = "ACK 编码失败：\(error.localizedDescription)"
        }
    }

    private func sendEnvelopeData(_ data: Data, kind: String) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastSyncMessage = "实时发送失败，改用可靠队列：\(error.localizedDescription)"
                    self?.session?.transferUserInfo([
                        WatchSessionSyncTransferKeys.envelopeData: data,
                        WatchSessionSyncTransferKeys.kind: kind
                    ])
                }
            }
        } else {
            session.transferUserInfo([
                WatchSessionSyncTransferKeys.envelopeData: data,
                WatchSessionSyncTransferKeys.kind: kind
            ])
        }
    }

    private func message(for ack: SyncAck) -> String {
        switch (ack.status, ack.action) {
        case (.ok, .sessionComplete):
            return "会话回传完成"
        case (.missingData, .missingRangesRequested):
            return "轨迹缺口等待补传"
        case (.alreadyReceived, _):
            return "重复数据已去重"
        default:
            return "已接收：\(ack.action.rawValue)"
        }
    }
}

extension iPhoneSessionSyncService: WatchRouteSyncTransport {
    var readinessText: String {
        guard let session else { return "当前设备不支持 WatchConnectivity" }
        guard session.activationState == .activated else { return "正在连接 Watch" }
        guard session.isPaired else { return "未配对 Apple Watch" }
        guard session.isWatchAppInstalled else { return "Watch App 未安装" }
        return session.isReachable ? "Watch 已连接，可发送路线" : "Watch 在后台或未实时可达，将通过可靠队列同步"
    }

    func sync(_ route: InstalledRoute) -> AsyncThrowingStream<RouteSyncState, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard session != nil else {
                    continuation.finish(throwing: RouteSyncTransportError.watchConnectivityUnavailable)
                    return
                }
                pendingRoute = route
                routeSyncContinuation = continuation
                routeSyncCoordinator = RouteSyncCoordinator()
                do {
                    let manifest = try RouteSyncCodec.makeManifestEnvelope(for: route)
                    try transfer(manifest)
                    await routeSyncCoordinator?.markManifestSent()
                    continuation.yield(await routeSyncCoordinator?.state ?? .manifestSent)
                    lastSyncMessage = "路线清单已加入 Watch 同步队列"
                } catch {
                    routeSyncContinuation = nil
                    routeSyncCoordinator = nil
                    pendingRoute = nil
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func handleRouteSyncAck(_ ack: SyncAck) async {
        guard let continuation = routeSyncContinuation,
              let coordinator = routeSyncCoordinator else {
            lastSyncMessage = "收到路线 ACK：\(ack.action.rawValue)"
            return
        }

        do {
            switch ack.action {
            case .readyForPayload, .routeAlreadyInstalled, .routeManifestRejected:
                try await coordinator.handleManifestAck(ack)
                continuation.yield(await coordinator.state)
                if await coordinator.state == .readyForPayload {
                    guard let pendingRoute else { throw RouteSyncTransportError.missingPendingRoute }
                    let payload = try RouteSyncCodec.makePayloadEnvelope(for: pendingRoute)
                    try transfer(payload)
                    await coordinator.markPayloadTransferred()
                    continuation.yield(await coordinator.state)
                    lastSyncMessage = "路线数据已加入 Watch 同步队列"
                } else {
                    finishRouteSync()
                }
            case .routeInstalled, .routePayloadRejected:
                try await coordinator.handlePayloadAck(ack)
                continuation.yield(await coordinator.state)
                lastSyncMessage = "路线已同步到 Watch"
                finishRouteSync()
            default:
                break
            }
        } catch {
            continuation.finish(throwing: error)
            routeSyncContinuation = nil
            routeSyncCoordinator = nil
            pendingRoute = nil
            lastSyncMessage = "路线同步失败：\(error.localizedDescription)"
        }
    }

    private func finishRouteSync() {
        routeSyncContinuation?.finish()
        routeSyncContinuation = nil
        routeSyncCoordinator = nil
        pendingRoute = nil
    }

    private func transfer<Payload>(_ envelope: SyncEnvelope<Payload>) throws where Payload: Codable & Equatable & Sendable {
        let data = try RouteSyncCodec.encoder.encode(envelope)
        sendEnvelopeData(data, kind: envelope.kind.rawValue)
    }
}

private enum RouteSyncTransportError: LocalizedError {
    case watchConnectivityUnavailable
    case missingPendingRoute

    var errorDescription: String? {
        switch self {
        case .watchConnectivityUnavailable:
            return "WatchConnectivity 不可用"
        case .missingPendingRoute:
            return "缺少待发送路线"
        }
    }
}

extension iPhoneSessionSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                lastSyncMessage = "WatchConnectivity 激活失败：\(error.localizedDescription)"
            } else {
                lastSyncMessage = activationState == .activated ? "等待 Watch 回传" : "WatchConnectivity 未激活"
            }
            updateCurrentWatchConnectionState()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            updateCurrentWatchConnectionState()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            updateCurrentWatchConnectionState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchSessionSyncTransferKeys.envelopeData] as? Data else {
            Task { @MainActor in
                lastSyncMessage = "收到 Watch 数据，但缺少 envelope"
            }
            return
        }
        Task { @MainActor in
            await handleEnvelopeData(data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            await handleEnvelopeData(messageData)
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let error {
                lastSyncMessage = "可靠队列发送失败：\(error.localizedDescription)"
            }
        }
    }
}

private enum WatchSessionSyncTransferKeys {
    static let envelopeData = "syncEnvelopeData"
    static let kind = "kind"
}

private struct SyncEnvelopeHeader: Decodable {
    var kind: SyncEnvelopeKind
}

private actor iPhoneReceivedSessionStore {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func save(_ record: ReceivedSessionRecord) throws {
        let data = try encoder.encode(record)
        let targetURL = directoryURL.appendingPathComponent("\(record.sessionId).json")
        let temporaryURL = directoryURL.appendingPathComponent("\(record.sessionId).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
    }

    func saveEvidence(sessionId: String, data: Data) throws {
        let targetURL = directoryURL.appendingPathComponent("\(sessionId).evidence.jsonl")
        let temporaryURL = directoryURL.appendingPathComponent("\(sessionId).evidence.tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
    }

    func listRecords() throws -> [ReceivedSessionRecord] {
        let urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try urls.map { url in
            var record = try decoder.decode(ReceivedSessionRecord.self, from: Data(contentsOf: url))
            let evidenceURL = directoryURL.appendingPathComponent("\(record.sessionId).evidence.jsonl")
            if let evidenceData = try? Data(contentsOf: evidenceURL), !evidenceData.isEmpty {
                record.evidenceByteCount = evidenceData.count
                record.evidenceLineCount = evidenceData.reduce(0) { count, byte in
                    byte == 0x0A ? count + 1 : count
                }
            }
            return record
        }
            .sorted { ($0.summary?.endedAt ?? .distantPast) > ($1.summary?.endedAt ?? .distantPast) }
    }
}
