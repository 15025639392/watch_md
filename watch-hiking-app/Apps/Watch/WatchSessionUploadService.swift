import Foundation
import WatchConnectivity

@MainActor
final class WatchSessionUploadService: NSObject {
    var onStatusChange: ((String) -> Void)?
    var onRouteInstalled: ((InstalledRoute) -> Void)?

    private let engine: WatchSessionUploadEngine
    private let routeInstaller: WatchRouteInstaller
    private let routeStore: RouteStore
    private let session: WCSession?

    init(sessionStore: HikingSessionStore, routeStore: RouteStore, pendingDirectoryURL: URL) {
        engine = WatchSessionUploadEngine(
            sessionStore: sessionStore,
            pendingStore: try! WatchPendingUploadStore(directoryURL: pendingDirectoryURL)
        )
        self.routeStore = routeStore
        routeInstaller = WatchRouteInstaller(routeStore: routeStore)
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
    }

    func start() {
        guard let session else {
            onStatusChange?("回传不可用")
            return
        }
        session.activate()
        onStatusChange?("等待回传")
        Task {
            await apply(engine.restorePendingUploads())
        }
    }

    func upload(_ storedSession: StoredHikingSession) async {
        guard session != nil else {
            onStatusChange?("回传不可用")
            return
        }

        do {
            apply(try await engine.upload(storedSession))
        } catch {
            onStatusChange?("回传失败：\(error.localizedDescription)")
        }
    }

    private func handleAckData(_ data: Data) async {
        do {
            let header = try RouteSyncCodec.decoder.decode(SyncEnvelopeHeader.self, from: data)
            guard header.kind == .syncAck else { return }
            let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<SyncAck>.self, from: data)
            apply(try await engine.handleAck(envelope.payload))
        } catch {
            onStatusChange?("ACK 处理失败：\(error.localizedDescription)")
        }
    }

    private func handleRouteData(_ data: Data) async {
        do {
            let header = try RouteSyncCodec.decoder.decode(SyncEnvelopeHeader.self, from: data)
            let ack: SyncEnvelope<SyncAck>
            switch header.kind {
            case .routeManifest:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<RouteManifest>.self, from: data)
                ack = try await routeInstaller.receiveManifest(envelope)
                onStatusChange?("路线清单已接收")
            case .routePayload:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<RoutePayload>.self, from: data)
                ack = try await routeInstaller.receivePayload(envelope)
                let installed = try await routeStore.load(routeId: envelope.payload.route.routeId)
                onRouteInstalled?(installed)
                onStatusChange?("路线已安装")
            default:
                return
            }
            transfer(try RouteSyncCodec.encoder.encode(ack))
        } catch {
            onStatusChange?("路线接收失败：\(error.localizedDescription)")
        }
    }

    private func apply(_ result: WatchUploadEngineResult) {
        result.envelopeData.forEach(transfer)
        if let statusText = result.statusText {
            onStatusChange?(statusText)
        }
    }

    private func transfer(_ data: Data) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.onStatusChange?("实时发送失败，改用可靠队列：\(error.localizedDescription)")
                    self?.session?.transferUserInfo([
                        WatchSessionTransferKeys.envelopeData: data,
                        WatchSessionTransferKeys.kind: "syncEnvelope"
                    ])
                }
            }
        } else {
            session.transferUserInfo([
                WatchSessionTransferKeys.envelopeData: data,
                WatchSessionTransferKeys.kind: "syncEnvelope"
            ])
        }
    }

    private func receiveEnvelopeData(_ data: Data) async {
        do {
            let header = try RouteSyncCodec.decoder.decode(SyncEnvelopeHeader.self, from: data)
            switch header.kind {
            case .syncAck:
                await handleAckData(data)
            case .routeManifest, .routePayload:
                await handleRouteData(data)
            default:
                onStatusChange?("收到暂不处理的数据：\(header.kind.rawValue)")
            }
        } catch {
            onStatusChange?("同步数据解析失败：\(error.localizedDescription)")
        }
    }

}

private actor WatchSessionUploadEngine {
    private let queue = PendingSessionUploadQueue()
    private let sessionStore: HikingSessionStore
    private let pendingStore: WatchPendingUploadStore
    private var activePlansBySessionId: [String: SessionUploadPlan] = [:]

    init(sessionStore: HikingSessionStore, pendingStore: WatchPendingUploadStore) {
        self.sessionStore = sessionStore
        self.pendingStore = pendingStore
    }

    func upload(_ storedSession: StoredHikingSession) async throws -> WatchUploadEngineResult {
        do {
            let syncingSession = try await sessionStore.updateSyncStatus(sessionId: storedSession.session.sessionId, syncStatus: .syncing)
            let plan = try SessionUploadPlanner.makeUploadPlan(for: syncingSession)
            activePlansBySessionId[syncingSession.session.sessionId] = plan
            await queue.enqueue(plan)
            try await pendingStore.save(WatchPendingUploadRecord(sessionId: syncingSession.session.sessionId, pendingEnvelopeIds: plan.envelopeIds))
            return WatchUploadEngineResult(statusText: "正在回传 · \(await queue.pendingCount) 项", envelopeData: try plan.encodedEnvelopeData())
        } catch {
            _ = try? await sessionStore.updateSyncStatus(sessionId: storedSession.session.sessionId, syncStatus: .failed)
            throw error
        }
    }

    func restorePendingUploads() async -> WatchUploadEngineResult {
        do {
            let records = try await pendingStore.listRecords()
            let unfinishedSessions = try await sessionStore.listSessions()
                .filter { $0.session.status == .finished && $0.session.syncStatus != .synced }
            var envelopeData: [Data] = []

            for storedSession in unfinishedSessions {
                let plan = try SessionUploadPlanner.makeUploadPlan(for: storedSession)
                activePlansBySessionId[storedSession.session.sessionId] = plan
                await queue.enqueue(plan)
                try await pendingStore.save(WatchPendingUploadRecord(sessionId: storedSession.session.sessionId, pendingEnvelopeIds: plan.envelopeIds))
                envelopeData.append(contentsOf: try plan.encodedEnvelopeData())
            }

            let status = (!records.isEmpty || !unfinishedSessions.isEmpty) ? "恢复回传 · \(await queue.pendingCount) 项" : nil
            return WatchUploadEngineResult(statusText: status, envelopeData: envelopeData)
        } catch {
            return WatchUploadEngineResult(statusText: "恢复回传失败：\(error.localizedDescription)", envelopeData: [])
        }
    }

    func handleAck(_ ack: SyncAck) async throws -> WatchUploadEngineResult {
        switch (ack.status, ack.action) {
        case (.missingData, .missingRangesRequested):
            return try resendMissingTrackRanges(for: ack)
        case (.ok, .sessionComplete):
            try await queue.handleAck(ack)
            _ = try await sessionStore.updateSyncStatus(sessionId: ack.entityId, syncStatus: .synced)
            try await pendingStore.remove(sessionId: ack.entityId)
            activePlansBySessionId.removeValue(forKey: ack.entityId)
            return WatchUploadEngineResult(statusText: "回传完成", envelopeData: [])
        case (.rejected, _), (.failed, _):
            try await queue.handleAck(ack)
            _ = try await sessionStore.updateSyncStatus(sessionId: ack.entityId, syncStatus: .failed)
            return WatchUploadEngineResult(statusText: "回传失败", envelopeData: [])
        default:
            try await queue.handleAck(ack)
            if let envelopeId = ack.ackForEnvelopeId {
                try await pendingStore.removeEnvelope(envelopeId, sessionId: ack.entityId)
            }
            return WatchUploadEngineResult(statusText: "正在回传 · \(await queue.pendingCount) 项", envelopeData: [])
        }
    }

    private func resendMissingTrackRanges(for ack: SyncAck) throws -> WatchUploadEngineResult {
        guard let plan = activePlansBySessionId[ack.entityId] else {
            return WatchUploadEngineResult(statusText: "补传等待恢复", envelopeData: [])
        }
        var envelopeData: [Data] = []
        for chunk in plan.trackChunks where chunk.payload.intersects(ack.missingRanges) {
            envelopeData.append(try RouteSyncCodec.encoder.encode(chunk))
        }
        envelopeData.append(try RouteSyncCodec.encoder.encode(plan.summary))
        return WatchUploadEngineResult(statusText: "补传轨迹缺口", envelopeData: envelopeData)
    }
}

private struct WatchUploadEngineResult: Sendable {
    var statusText: String?
    var envelopeData: [Data]
}

private struct WatchPendingUploadRecord: Codable, Equatable, Sendable {
    var sessionId: String
    var pendingEnvelopeIds: [String]
    var updatedAt: Date

    init(sessionId: String, pendingEnvelopeIds: [String], updatedAt: Date = Date()) {
        self.sessionId = sessionId
        self.pendingEnvelopeIds = pendingEnvelopeIds
        self.updatedAt = updatedAt
    }
}

private actor WatchPendingUploadStore {
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

    func save(_ record: WatchPendingUploadRecord) throws {
        let data = try encoder.encode(record)
        let targetURL = url(for: record.sessionId)
        let temporaryURL = directoryURL.appendingPathComponent("\(record.sessionId).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
    }

    func listRecords() throws -> [WatchPendingUploadRecord] {
        let urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try urls.map { try decoder.decode(WatchPendingUploadRecord.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    func removeEnvelope(_ envelopeId: String, sessionId: String) throws {
        let recordURL = url(for: sessionId)
        guard FileManager.default.fileExists(atPath: recordURL.path) else { return }
        var record = try decoder.decode(WatchPendingUploadRecord.self, from: Data(contentsOf: recordURL))
        record.pendingEnvelopeIds.removeAll { $0 == envelopeId }
        record.updatedAt = Date()
        if record.pendingEnvelopeIds.isEmpty {
            try FileManager.default.removeItem(at: recordURL)
        } else {
            try save(record)
        }
    }

    func remove(sessionId: String) throws {
        let recordURL = url(for: sessionId)
        if FileManager.default.fileExists(atPath: recordURL.path) {
            try FileManager.default.removeItem(at: recordURL)
        }
    }

    private func url(for sessionId: String) -> URL {
        directoryURL.appendingPathComponent("\(sessionId).json")
    }
}

private extension SessionUploadPlan {
    var envelopeIds: [String] {
        [status.envelopeId] + trackChunks.map(\.envelopeId) + eventChunks.map(\.envelopeId) + [summary.envelopeId]
    }

    func encodedEnvelopeData() throws -> [Data] {
        try [RouteSyncCodec.encoder.encode(status)] +
            trackChunks.map { try RouteSyncCodec.encoder.encode($0) } +
            eventChunks.map { try RouteSyncCodec.encoder.encode($0) } +
            [RouteSyncCodec.encoder.encode(summary)]
    }
}

extension WatchSessionUploadService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                onStatusChange?("回传连接失败：\(error.localizedDescription)")
            } else {
                onStatusChange?(activationState == .activated ? "等待回传" : "回传未激活")
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchSessionTransferKeys.envelopeData] as? Data else {
            Task { @MainActor in
                onStatusChange?("收到数据但缺少 envelope")
            }
            return
        }
        Task { @MainActor in
            await receiveEnvelopeData(data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            await receiveEnvelopeData(messageData)
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in
            if let error {
                onStatusChange?("可靠队列发送失败：\(error.localizedDescription)")
            }
        }
    }
}

private enum WatchSessionTransferKeys {
    static let envelopeData = "syncEnvelopeData"
    static let kind = "kind"
}

private struct SyncEnvelopeHeader: Decodable {
    var kind: SyncEnvelopeKind
}

private extension TrackChunk {
    func intersects(_ ranges: [SequenceRange]) -> Bool {
        ranges.contains { range in
            startSequence <= range.endSequence && endSequence >= range.startSequence
        }
    }
}
