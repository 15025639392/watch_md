# Watch Hiking App

这是 Apple Watch 优先的徒步导航与轨迹记录 MVP 工程目录。仓库根目录和 `docs/` 继续作为规格输入，本目录承载后续 iOS/watchOS/shared 代码、测试、fixture 和工程配置。

## 当前 Slice

Slice 1：路线导入与数据模型。

已完成：

1. App 自有路线模型：`HikingRoute`、`RouteVariant`、`RoutePoint`、`Waypoint`、`TurnPoint`、`RemoteRouteSummary`。
2. GPX 导入解析、距离/bounds/爬升统计、起终点生成。
3. Watch 简化路线生成和明显转向点识别。
4. 远端路线接口协议形状与 `MockRemoteRouteClient`。
5. 本地路线 JSON 落盘，供后续 WatchConnectivity 可靠同步前先保存。
6. iPhone/Watch SwiftUI app 源码骨架。
7. iPhone 路线列表已接入 GPX 文件选择器，也支持系统分享或“用 Watch Hiking 打开”GPX；导入后保存到本地路线库并打开详情页。
8. iPhone 首屏已接入定位状态卡：支持真实 Core Location When In Use / Always 定位、持续高精度定位开关和朝向显示。
9. iPhone 路线详情地图会显示接近 iOS 地图蓝点风格的当前定位标记，并随定位点位置和朝向更新。

Slice 2 已开始并完成核心可测试闭环：

1. `SyncEnvelope`、`routeManifest`、`routePayload` 和 `syncAck` 数据结构。
2. Watch 端路线安装校验：manifest 先验、payload checksum 校验、字段一致性校验。
3. 同版本路线幂等去重，重复 manifest 返回 `syncAck(status=alreadyReceived, action=routeAlreadyInstalled)`。
4. payload 校验失败不覆盖 Watch 上一条可用路线。
5. iPhone 侧 `RouteSyncCoordinator` 状态推进：`manifestSent -> readyForPayload -> payloadTransferred -> installed`。
6. iPhone 路线详情页已接入 MapKit 计划路线预览、起终点标记、路线统计和 mock Watch 同步入口。
7. iPhone 侧已抽象 `WatchRouteSyncTransport`，路线详情默认使用 `iPhoneSessionSyncService` 通过 WatchConnectivity 发送 manifest / payload，并等待 Watch ACK；两端 reachable 时优先走 `sendMessageData`，不可达或实时发送失败时回退到 `transferUserInfo` 可靠队列。
8. Watch App 已在现有 `WCSessionDelegate` 中接收 `routeManifest` / `routePayload`，调用 `WatchRouteInstaller` 保存到 `WatchInstalledRoutes`，安装成功后刷新当前路线。
9. 路线详情页同步成功后会回写列表状态，并在“已同步”tab 展示已完成 ACK 的路线。

Slice 3 已开始并完成核心可测试闭环：

1. `HikingSession`、`TrackPoint`、`SessionEvent`、`SessionSummary` 和会话同步状态模型。
2. Watch 侧 `HikingSessionRecorder`：开始、暂停、继续、结束状态机。
3. 暂停期间不写正式轨迹点，恢复后继续递增 `TrackPoint.sequence`。
4. 结束时生成距离、时长、爬升、心率、轨迹点数和待上传状态摘要。
5. `HikingSessionStore` 本地 JSON 落盘，并支持恢复 active/paused 会话。
6. Watch UI 已接入会话控制面板：开始、暂停、继续、结束、恢复未结束会话和结束摘要展示。
7. Watch UI 已接入 Core Location 最小采样：开始/继续时请求定位并写入真实 `CLLocation` 轨迹点，暂停/结束时停止定位。
8. Watch UI 已接入 HKWorkoutSession 最小闭环：请求 HealthKit 权限、开始户外徒步 workout、暂停/继续/结束并保存 workout。
9. Watch UI 已接入 HKLiveWorkoutBuilder 实时指标：心率、活动能量和运动距离；定位点写入时会带上最新心率。
10. Watch 启动时优先从本地 `WatchInstalledRoutes` 路线库读取已安装路线；没有路线时进入自由记录模式，可直接记录实际轨迹，但不显示计划路线、不做偏航判断。

Slice 4 已开始，Watch 地图页 MVP 已接入：

1. Watch 首屏改为地图优先布局；有计划路线时显示计划路线、起点、终点、当前定位点和已走轨迹，无计划路线时显示自由记录状态和实际轨迹。
2. 会话进行中每个定位点会执行路线几何匹配，写入最近路线距离和路线进度。
3. 地图顶部状态胶囊覆盖路线上、疑似偏航、确认偏航、定位不稳、暂停和结束状态。
4. 地图底部提示有路线时显示剩余距离，确认偏航时显示回到路线的大致方向；自由记录时显示“无路线也可开始 / 记录实际轨迹”。
5. 偏航 MVP 使用计划路线线段投影、30m 偏航阈值、20m 回归阈值、50m 定位弱阈值和连续 3 个可信点确认。
6. 确认偏航时地图显示当前位置到最近路线投影点的警示连接线。
7. 首次确认偏航会写入 `offRouteStarted` 事件并触发 Watch 触觉提醒；持续偏航会限频写入 `offRouteUpdated`，回到路线会写入 `offRouteEnded`。
8. 定位不稳会写入 `locationAccuracyPoor`，恢复到可靠路线判断后写入 `locationRecovered`。

Slice 5 已开始并完成核心可测试闭环：

1. `sessionStatus`、`trackChunk`、`eventChunk` 和 `sessionSummary` envelope 已接入共享同步模型。
2. Watch 端可把已结束的 `StoredHikingSession` 切成上传计划，包含状态、轨迹 chunk、事件 chunk 和摘要。
3. Watch 端新增待上传队列模型，未收到 ACK 前保留 envelope，收到 `ok` / `alreadyReceived` ACK 后再清理。
4. iPhone 端新增会话接收器，按 `sessionId + TrackPoint.sequence` 去重轨迹点，按 `eventId` 去重事件。
5. 重复 chunk 会返回 `syncAck(status=alreadyReceived, action=trackChunkReceived/eventChunkReceived)`。
6. 乱序或缺失轨迹会返回 `syncAck(status=missingData, action=missingRangesRequested)` 并带缺失 sequence 范围。
7. iPhone 收齐摘要、最终轨迹和最终事件后返回 `syncAck(status=ok, action=sessionComplete)`。
8. iPhone App 已接入 `WCSessionDelegate` 真实接收入口：通过 `transferUserInfo` 接收 Watch envelope、调用会话接收器、落盘到 `ReceivedSessions`，并通过 `transferUserInfo` 回发 ACK。
9. iPhone 路线列表首屏显示 Watch 会话回传状态和已接收会话数量，状态卡可点击进入回传会话列表。
10. iPhone 已接入 Watch 回传会话列表：按“正在同步 / 部分同步 / 已完成”分组，展示轨迹点、事件数和缺口数量。
11. iPhone 已接入回传详情页：展示轨迹完整性、缺失 sequence 范围、事件数、摘要状态；同步完成后可进入实际轨迹复盘地图。
12. Watch App 已接入 `WCSessionDelegate` 真实上传入口：会话结束后生成 `SessionUploadPlan`，通过 `transferUserInfo` 发送 status、track chunk、event chunk 和 summary。
13. Watch App 已接入 ACK 处理：收到 iPhone ACK 后清理 pending envelope，收到 `missingRangesRequested` 后按缺失 sequence 补传相关 track chunk，收到 `sessionComplete` 后显示回传完成。
14. Watch App 已接入 pending upload 持久化：会话结束上传时把待 ACK envelope ID 落盘到 `WatchPendingUploads`。
15. Watch App 已接入重启/重连恢复：`WCSession` 激活后扫描已结束且未 `synced` 的本地会话，重新生成上传计划并自动补发。
16. Watch App 已接入本地同步状态回写：开始上传写为 `syncing`，收到 `sessionComplete` 写为 `synced`，失败/拒绝写为 `failed`。
17. Watch 上传状态机已下沉到独立 `WatchSessionUploadEngine` actor；主线程上的 `WatchSessionUploadService` 只保留 `WCSessionDelegate`、`transferUserInfo` 和 UI 状态回调 glue。
18. 已用 iPhone 模拟器 + 配套 Watch 模拟器验证 Watch 生成调试会话、上传 status / track chunk / event chunk / summary、iPhone ACK、iPhone `ReceivedSessions` JSON 落盘和完成态显示闭环。

服务端搜索/详情接口待接入；当前使用 mock client 和测试 fixture，不把 mock 结果写成真实服务端能力。

## 验证

```sh
cd watch-hiking-app
swift test
```

Xcode app target 验证：

```sh
cd watch-hiking-app

# watchOS 模拟器构建
xcodebuild -project WatchHikingApp.xcodeproj \
  -scheme WatchHikingWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build

# watchOS 模拟器安装和启动
xcrun simctl install D51B7367-4F07-4C13-AF43-DFD99970657B \
  ~/Library/Developer/Xcode/DerivedData/WatchHikingApp-fitvitphwmstmbfubyszsjrusvwt/Build/Products/Debug-watchsimulator/WatchHikingWatch.app
xcrun simctl launch D51B7367-4F07-4C13-AF43-DFD99970657B com.watchmd.hiking.watch

# iOS 真机架构无签名构建
xcodebuild -project WatchHikingApp.xcodeproj \
  -scheme WatchHikingiPhone \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

iOS 真机安装待完成签名配置：当前本机能看到已配对 iPhone 和 Apple Development 证书，但 Xcode CLI 报告没有登录 Team `YTQ3SFT962` 的账号，也没有匹配 `com.watchmd.hiking.iphone` 的 iOS Development provisioning profile。因此真机安装需要先在 Xcode Accounts 登录对应 Apple Developer 账号，或安装匹配 bundle id 和设备 UDID 的 provisioning profile；之后可用 `-allowProvisioningUpdates` 重新运行真机构建。

手动验证：

1. 运行测试确认 GPX fixture 可导入并生成路线摘要。
2. 检查 `Apps/iPhone/iPhoneApp.swift`：路线列表从 mock 远端目录加载，也可通过文件选择器、系统分享或“用 Watch Hiking 打开”导入 GPX；点击后展示 MapKit 路线详情、路线统计和同步入口。
3. 在 iPhone 首屏定位卡点击开始可请求 iPhone When In Use 定位；打开“持续高精度定位”后会请求 Always 权限并启用后台 location 模式，以便 App 退到后台后继续接收位置更新。该卡仅用于 iPhone 当前定位状态展示和调试，不代表 iPhone 已成为徒步记录入口。
4. 在路线详情页点击“同步到 Watch”，当前会通过 WatchConnectivity 发送路线清单和路线数据；两端可达时走实时消息，离线或实时发送失败时回退到可靠队列。收到 Watch 安装 ACK 后关闭详情或返回列表，可在“已同步”tab 看到该路线。
5. 检查 `Apps/Watch/WatchApp.swift`：Watch 端已显示地图首页和会话控制面板，可触发开始、暂停、继续、二次确认结束；会话进行中会通过 Core Location 写入真实定位点，通过 HKWorkoutSession 记录户外徒步 workout，并展示心率、活动能量和运动距离；有路线时底部显示路线关系，无路线时进入自由记录模式。

真机待验证：

1. MapKit iPhone 路线预览已接入 Xcode app target；视觉渲染仍需要真机/模拟器验证。
2. WatchConnectivity 真实路线下发、会话回传、ACK 处理和可靠文件传输需要 iPhone + Apple Watch 真机验证；当前已完成 iPhone 路线下发入口、Watch 路线接收安装入口、Watch 上传入口与 iPhone 接收入口，并已用 iPhone 模拟器 + 配套 Watch 模拟器验证路线 manifest / payload / ACK / Watch 落盘闭环，以及 Watch 会话 status / track chunk / event chunk / summary / ACK / iPhone `ReceivedSessions` 落盘闭环，但断连、后台、锁屏、重连和大体量 chunk 的真实表现仍需真机验证。
3. iPhone 后台持续定位已配置 `UIBackgroundModes=location` 和 Always 权限文案；退后台长时间稳定性、耗电、系统蓝条/指示器表现和用户授权路径仍需真机验证。
3. Core Location 真实采样、HKWorkoutSession 生命周期、Watch 地图性能、偏航状态切换、触觉提醒和电量策略需要后续 slice 真机验证。
4. Slice 3 当前已接入 Core Location、HKWorkoutSession 和实时 workout 指标最小闭环；后台持续采样、运动权限弹窗、HealthKit 写入、心率数据刷新和长时间运行仍需要 Apple Watch 真机验证。

## 已知限制

1. Xcode project 已有 iPhone/Watch app target，但还没有正式的 iPhone-Watch companion 嵌入、签名和真机安装闭环。
2. iPhone GPX 文件导入入口已接入系统文件选择器和外部文档打开；系统分享入口、iCloud Drive 文件和大 GPX 性能仍需要真机/模拟器验证。
3. mock 远端目录只有一条样例路线；Watch 无本地路线时不再显示该样例路线，而是进入自由记录模式。
4. workout 的能量/距离汇总尚未写入核心 `SessionSummary`。
5. Watch 地图页不提供图层切换。2026-06-06 查证 Apple MapKit 文档，`MapStyle.imagery` 和 `MapStyle.hybrid(...)` 在 watchOS 上可能渲染回 `Standard` 标准地图，因此卫星/混合图层切换不作为稳定 Watch MVP 能力；更完整的图层检查优先放在 iPhone。

官方参考：

1. [MapStyle.imagery - Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mapstyle/imagery)
2. [MapStyle.hybrid(elevation:pointsOfInterest:showsTraffic:) - Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mapstyle/hybrid%28elevation%3Apointsofinterest%3Ashowstraffic%3A%29)
