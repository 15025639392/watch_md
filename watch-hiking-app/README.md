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

Slice 2 已开始并完成核心可测试闭环：

1. `SyncEnvelope`、`routeManifest`、`routePayload` 和 `syncAck` 数据结构。
2. Watch 端路线安装校验：manifest 先验、payload checksum 校验、字段一致性校验。
3. 同版本路线幂等去重，重复 manifest 返回 `syncAck(status=alreadyReceived, action=routeAlreadyInstalled)`。
4. payload 校验失败不覆盖 Watch 上一条可用路线。
5. iPhone 侧 `RouteSyncCoordinator` 状态推进：`manifestSent -> readyForPayload -> payloadTransferred -> installed`。
6. iPhone 路线详情页已接入 MapKit 计划路线预览、起终点标记、路线统计和 mock Watch 同步入口。
7. iPhone 侧已抽象 `WatchRouteSyncTransport`，当前默认使用模拟器同步模式跑完整 manifest/payload/ACK 流程。
8. 路线详情页同步成功后会回写列表状态，并在“已同步”tab 展示已完成模拟同步的路线。

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
3. 在路线详情页点击“同步到 Watch”，当前会走模拟器同步模式；成功后关闭详情或返回列表，可在“已同步”tab 看到该路线。
4. 检查 `Apps/Watch/WatchApp.swift`：Watch 端已显示地图首页和会话控制面板，可触发开始、暂停、继续、二次确认结束；会话进行中会通过 Core Location 写入真实定位点，通过 HKWorkoutSession 记录户外徒步 workout，并展示心率、活动能量和运动距离；有路线时底部显示路线关系，无路线时进入自由记录模式。

真机待验证：

1. MapKit iPhone 路线预览已接入 Xcode app target；视觉渲染仍需要真机/模拟器验证。
2. WatchConnectivity 真实路线下发、ACK 和可靠文件传输需要 iPhone + Apple Watch 真机验证；当前 iOS 真机 + Watch 模拟器只能跑模拟器同步模式。
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
