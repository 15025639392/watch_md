# WatchOS 徒步 App 开发提示词与技术实施计划 v0.1

更新日期：2026-06-05

## 用途

本文档用于启动 WatchOS 徒步 App MVP 的实际开发。它既是一份可以直接复制给 Codex 的开发提示词，也是一份按 slice 推进的技术实施计划。

配套规格：

1. [WatchOS 徒步 App MVP 产品定义 v0.1](./watchos-hiking-app-product-v0.1.md)
2. [WatchOS 徒步 App MVP 开发切分 v0.1](./mvp-development-slices-v0.1.md)
3. [徒步路线与会话数据模型 v0.1](./hiking-data-model-v0.1.md)
4. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
5. [WatchOS 徒步地图页规格 v0.1](./watchos-map-page-spec-v0.1.md)
6. [偏航检测规则 v0.1](./off-route-detection-spec-v0.1.md)
7. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)
8. [低电量与长时间徒步策略 v0.1](./battery-long-hike-strategy-v0.1.md)

## 总开发提示词

```txt
你是一个资深 iOS/watchOS 工程师，请像真正接手一个新产品工程一样工作：先读规格、收敛范围、建立可运行骨架，再按 slice 逐步实现 Apple Watch 优先的徒步导航与轨迹记录 App MVP。目标不是堆功能，而是交付一个可运行、可测试、可恢复、可同步的端到端闭环。

开工前必须先检查当前仓库是否已经存在 Xcode 工程或 Swift Package。如果已有工程，优先在现有工程内最小必要整理；如果没有工程，在当前仓库下新建独立 App 工程目录，例如 `app/` 或 `watch-hiking-app/`，后续所有 iOS/watchOS/shared 代码、测试、fixture 和工程配置都放在该 App 工程目录中。仓库根目录和 `docs/` 继续作为产品与技术规格输入，不把工程文件散落到文档目录。

开工前必须阅读并对齐这些规格：
1. `docs/watchos-hiking-app-product-v0.1.md`
2. `docs/mvp-development-slices-v0.1.md`
3. `docs/hiking-data-model-v0.1.md`
4. `docs/watchconnectivity-sync-protocol-v0.1.md`
5. `docs/watchos-map-page-spec-v0.1.md`
6. `docs/off-route-detection-spec-v0.1.md`
7. `docs/hiking-session-flow-v0.1.md`
8. `docs/battery-long-hike-strategy-v0.1.md`
9. `docs/iphone-route-review-spec-v0.1.md`

产品定位：
iPhone 负责路线导入、路线管理、路线同步和复盘；Apple Watch 负责腕上地图、路线跟随、偏航提醒、轨迹记录、暂停/继续/结束和结束后回传。

第一版必须完成的闭环：
1. iPhone 从远端接口获取路线列表，并支持导入 GPX 路线。
2. iPhone 展示计划路线详情和地图预览。
3. iPhone 将 Watch 简化路线、转向点、起终点和提醒配置同步到 Apple Watch。
4. Watch 显示路线卡片，并以地图作为徒步首屏。
5. Watch 开始徒步后独立采集定位、记录轨迹、显示计划路线和已走轨迹。
6. Watch 根据计划路线几何做偏航检测和转向提醒。
7. Watch 支持暂停、继续、结束，并在 App 重启后恢复 active/paused 会话。
8. Watch 结束后可靠回传轨迹点、事件和摘要到 iPhone。
9. iPhone 复盘页叠加计划路线、实际轨迹和偏航事件。

核心技术约束：
1. 使用 Swift / SwiftUI / MapKit / Core Location / WatchConnectivity；HealthKit / HKWorkoutSession 可接入，但失败时必须降级。
2. Watch 端行进中能力不能依赖 iPhone 在线。
3. 路线、轨迹、事件、同步封包使用 App 自有数据模型，不把 MapKit 类型当核心模型。
4. 定位、HealthKit、通知权限和 WatchConnectivity 能力必须有明确状态；权限缺失时 UI 不崩溃，并说明哪些能力受影响。
5. 路线和轨迹这类不能丢的数据不能只依赖 sendMessage；必须本地先落盘，再通过 WatchConnectivity 的可靠通道补传。
6. 偏航检测只基于 GPX 几何和实时定位，不依赖 Apple Maps 路网。
7. 单个 GPS 漂移点不能触发偏航；定位不稳时优先提示定位不稳。
8. 低电量时可以降低地图刷新、采样频率和实时同步，但必须保留本地轨迹保存、偏航判断、关键提醒和结束摘要。
9. 地图底图失败时，仍要能显示计划路线线框、当前位置、已走轨迹和偏航关系；MapKit 底图不是轨迹记录和偏航判断的前置条件。
10. Watch 路线卡片不是徒步会话。`HikingSession` 只在用户开始徒步时创建；`planned` 若实现，应只是开始流程中的内部状态，不能把每条已同步路线都变成历史会话。

远端路线接口是 MVP 主路径。如果真实服务端接口尚未提供，请先实现同一协议形状的 mock client、本地 JSON fixture 或轻量 mock server，并在代码和交付说明中明确“服务端搜索/详情接口待接入”。不要因为缺少真实服务端而阻塞 GPX 导入、路线模型、地图预览或 Watch 同步。

请按 slice 开发，每个 slice 都要做到可运行、可验证、可回滚。每次只实现当前 slice 所需的最小完整能力，避免把后续功能提前塞进 MVP。不要提前实现路线社区、AI 推荐、多地图源、专业等高线、团队位置共享、多日徒步、订阅体系、Android/Wear OS/华为手表版本，也不要在 MVP 中实现 Watch 端远程获取指定 GPX 路线。

每次实现前先阅读相关规格文档，优先复用现有项目结构和代码风格。每个 slice 完成后必须补充必要的单元测试、fixture、可手动验证步骤、真机待验证项和已知限制。没有实机验证的 WatchConnectivity、Core Location、HKWorkoutSession、MapKit 性能和电量结论，必须标注“需要真机验证”，不要写成已实测事实。
```

## 架构边界

### Watch 首版页面边界

产品定义中提到地图页、数据页、安全页和控制页。MVP 实施时以地图页为行进中首屏和主体验，必须提供暂停、继续、结束等最小控制入口；数据页和安全页可以先做为轻量状态页或地图浮层，不要求完整四页体验。返航、标记点、日落风险、长时间停留判断和复杂安全分析不进入第一版。

### 端职责

| 端 | 必做 | 不做 |
| --- | --- | --- |
| iPhone | 远端路线列表、GPX 导入、路线库、路线详情、Watch 同步、历史记录、复盘、GPX 导出、设置 | 行进中主导航 |
| Watch | 路线卡片、地图首屏、定位采样、轨迹记录、偏航检测、转向提醒、暂停/继续/结束、本地待同步 | 复杂路线编辑、深度复盘分析 |

### 推荐模块

| 模块 | 所属端 | 职责 |
| --- | --- | --- |
| `RemoteRouteCatalog` | iPhone | 远端路线列表拉取、摘要缓存、详情下载、版本和 checksum 校验 |
| `RouteImport` | iPhone | GPX 解析、路线摘要、距离和 bounds 计算 |
| `RouteSimplification` | iPhone | 生成 `simplifiedForWatch`、检测路线质量 |
| `TurnPointDetection` | iPhone / Shared | 从路线几何生成转向点 |
| `HikingModels` | Shared | `HikingRoute`、`RoutePoint`、`HikingSession`、`TrackPoint`、`SessionEvent`、`SyncEnvelope` |
| `WatchSync` | Shared + 两端 | WatchConnectivity 封包、ACK、重试、去重 |
| `WatchSessionEngine` | Watch | 会话状态机、定位、轨迹写入、恢复 |
| `RouteMatcher` | Watch / Shared | 最近路线段投影、路线进度、偏航距离 |
| `OffRouteDetector` | Watch | 偏航状态机、提醒限频、事件生成 |
| `WatchMap` | Watch | 地图底图、路线叠加、当前位置、状态浮层、降级显示 |
| `Review` | iPhone | 计划路线与实际轨迹叠加、事件列表、导出 |

### 数据原则

1. 所有可同步实体都有稳定 ID、版本或 sequence、时间戳和 checksum。
2. Watch 会话数据先写本地，再尝试同步。
3. iPhone 接收轨迹点以 `sessionId + sequence` 去重。
4. iPhone 接收事件以 `eventId` 去重。
5. Watch 收到路线 payload 后先写临时文件，校验成功后原子替换。
6. Watch 收到新路线失败时保留上一条可用路线。

## 技术实施计划

### Phase 0：工程骨架与权限

目标：

建立 iOS App、watchOS App、共享模型、权限和基础诊断能力。

任务：

1. 先检查当前仓库是否已有 `.xcodeproj`、`.xcworkspace` 或 `Package.swift`。
2. 如果已有工程，优先复用现有工程结构；如果没有工程，在当前仓库下创建独立 App 工程目录，并在其中建立 iOS target、watchOS target、shared module 或 shared source group。
3. 后续所有 App 代码、测试、fixture、工程配置和生成物都放在 App 工程目录中；文档仓库根目录和 `docs/` 只作为规格输入。
4. 配置定位权限、HealthKit entitlement、通知权限和 WatchConnectivity capability。
5. 增加基础日志分类：route、sync、location、session、offRoute、battery。
6. 建立本地存储抽象，先支持 JSON/file 或 SwiftData/CoreData 中的一种，不在 MVP 中同时维护多套存储。
7. 准备至少 3 条 GPX fixture：普通路线、回头路/交叉路线、点稀疏路线；Phase 0 只要求准备文件，不要求完成 GPX parser。

验收：

1. 明确记录本次使用的 App 工程目录。
2. iPhone 和 Watch App 都能启动。
3. 两端能访问 shared models。
4. 定位、HealthKit 和通知权限缺失时 UI 有明确状态，不崩溃。
5. Watch 与 iPhone 能完成一条最小 ping/ack。

### Phase 1：远端路线、路线导入与 iPhone 预览

目标：

iPhone 能从远端接口获取路线列表、下载路线详情，也能导入 GPX，生成 App 自有路线模型，并展示计划路线。

任务：

1. 实现 `RemoteRouteCatalog`，从远端接口获取 `RemoteRouteSummary` 列表；如果真实服务端暂未提供，先实现同一协议形状的 mock client、本地 JSON fixture 或轻量 mock server，并明确标注待接真实接口。
2. 列表显示路线名称、距离、爬升、预计耗时、区域、质量状态和本地状态。
3. 支持按名称、编号或区域搜索远端路线摘要；如果服务端暂不支持搜索，先实现本地摘要过滤，并明确标注服务端搜索待接入。
4. 点击远端路线后下载详情 payload，校验 `remoteVersion` 和 `checksum`，保存为 `HikingRoute(source=remoteCatalog)`。
5. 实现 GPX parser，读取 trkpt/rtept/wpt 的经纬度、海拔和时间。
6. 生成 `HikingRoute`、`RouteVariant.original`、起点、终点。
7. 计算距离、bounds、点数、海拔可用性、checksum。
8. 生成 `simplifiedForWatch`，保留原始路线用于复盘和导出。
9. 生成初版 `TurnPoint`，并保证输出字段能被 Watch route payload、地图页和偏航检测复用。
10. iPhone 路线详情页展示地图、距离、点数、起终点、转向点数量和同步入口。

验收：

1. 能获取远端路线列表并显示摘要。
2. 能下载一条远端路线详情并保存为本地路线。
3. 远端刷新失败时，本地已保存路线仍可查看。
4. 能按名称、编号或区域搜索或过滤远端路线摘要。
5. 能导入有效 GPX 并保存路线。
6. 无有效轨迹点的 GPX 会失败并提示。
7. 点数过多时生成 Watch 简化路线。
8. 点间距过大时标记路线质量风险。
9. iPhone 地图能显示计划路线、起点和终点。

### Phase 2：路线下发到 Watch

目标：

iPhone 能可靠把路线 manifest 和 payload 下发到 Watch，Watch 能安装并展示路线卡片。

任务：

1. 定义 `SyncEnvelope` 编解码、checksum、schemaVersion。
2. 实现 `routeManifest` 发送和 Watch ACK：`syncAck(status=alreadyReceived, action=routeAlreadyInstalled)`、`syncAck(status=ok, action=readyForPayload)`、`syncAck(status=rejected, action=routeManifestRejected)`。
3. 实现 `routePayload` 文件传输或小 payload userInfo 传输，payload 至少包含 `HikingRoute` 摘要、`simplifiedForWatch`、`TurnPoint`、`Waypoint` 和默认提醒配置。
4. Watch 端安装路线时采用临时文件 + 校验 + 原子替换。
5. Watch 安装成功后回 `syncAck(status=ok, action=routeInstalled)`。
6. iPhone 显示同步状态：未同步、同步中、已同步、失败、Watch 不在线。
7. Watch 显示路线卡片：名称、距离、同步时间、开始按钮。

验收：

1. Watch 在线时能同步并安装路线。
2. Watch 不在线时不会假装已就绪。
3. 同版本同 checksum 路线不会重复安装。
4. payload 校验失败不会覆盖旧路线。
5. Watch 安装 payload 成功后回 `syncAck(status=ok, action=routeInstalled)`。
6. 同步失败后可以重试。

### Phase 3：Watch 会话与轨迹记录

目标：

Watch 能独立开始、暂停、继续、结束徒步，并可靠保存轨迹。

任务：

1. 实现 `HikingSession` 状态机：planned、active、paused、finished、abandoned。
2. 接入 Core Location，并实现最小 `BatteryMode` / `SamplingPolicy`：标准、节能、低电量、极低电量模式的阈值、采样间隔和当前模式判断。
3. 接入 HKWorkoutSession；失败时降级为纯地图导航和轨迹记录。
4. 实现 `TrackPoint` sequence 递增写入。
5. 暂停期间不写正式轨迹点。
6. 每次状态变化立即落盘，每 1-5 分钟更新摘要草稿。
7. App 启动时恢复 active/paused 会话并写入 `appRecovered` 事件。
8. 明确 Watch 路线卡片不创建 `HikingSession`；只有用户点击开始后才创建会话，`planned` 若实现只作为开始流程中的内部状态。
9. 低电量进入阈值时写入 `SessionEvent.lowBattery`，模式变化事件可后置。

验收：

1. Watch 在 iPhone 断连时可以开始和结束会话。
2. 轨迹点 sequence 连续且可持久化。
3. 暂停/继续不会破坏 session 状态。
4. App 重启后能恢复进行中的会话。
5. HealthKit 不可用时核心记录仍能继续。

### Phase 4：Watch 地图、路线匹配与偏航

目标：

Watch 地图页成为行进中主体验，能显示路线关系并触发偏航/转向提醒。

任务：

1. Watch 首屏进入地图页，显示 Apple MapKit 底图。
2. 绘制计划路线、已走轨迹、当前位置、方向箭头、起点、终点。
3. 实现 Digital Crown 缩放和自动居中。
4. 实现 `RouteMatcher`：最近路线段投影、距离、进度、回路线方向。
5. 匹配时优先扫描上一次进度附近窗口，必要时扩大或全量扫描。
6. 实现 `OffRouteDetector` 状态机：onRoute、suspectedOffRoute、offRoute、locationUnreliable、paused。
7. 使用默认阈值：偏航 30m、回归 20m、弱定位 50m、连续 3 点或 10-15 秒确认。
8. 实现转向点提醒，同一接近周期只提醒一次；用户离开足够距离或路线进度重新进入后，可再次提醒。
9. 生成 `SessionEvent`：offRouteStarted、offRouteUpdated、offRouteEnded、locationAccuracyPoor、turnAlertTriggered。
10. 实现地图降级模式：底图不可用时仍渲染路线线框、当前位置、已走轨迹和偏航连接线。

验收：

1. Watch 地图显示计划路线、当前位置和已走轨迹。
2. 正常行进时显示“路线上”。
3. 单个 GPS 漂移点不会触发偏航。
4. 连续可信定位点超过阈值后进入偏航并震动。
5. 回到路线后退出偏航并记录事件。
6. 定位不稳时不频繁报偏航。
7. 接近明显转向点时提醒。
8. 地图底图失败时仍能显示路线线框、当前位置和已走轨迹。

### Phase 5：会话回传、去重与补传

目标：

Watch 结束后可靠把轨迹、事件和摘要同步回 iPhone。

任务：

1. 实现 `sessionStatus` 轻量同步。
2. 实现 `trackChunk`、`eventChunk`、`sessionSummary` 传输。
3. 所有跨端 payload 使用 `SyncEnvelope`，并包含 `envelopeId`、`schemaVersion`、`createdAt`、`sender`、`kind`、`entityId`、`entityVersion`、`sequence`、`isFinal`、`payloadChecksum` 和 `payload`。
4. `trackChunk` payload 至少包含 `sessionId`、`chunkId`、`startSequence`、`endSequence`、`isFinal`、`points`、`pointsChecksum`。
5. `eventChunk` payload 至少包含 `sessionId`、`chunkId`、`events`、`isFinal`。
6. iPhone 按 `sessionId + TrackPoint.sequence` 去重写入轨迹点，按 `eventId` 去重写入事件，按 `entityId + kind + sequence` 去重 chunk。
7. iPhone 收到 `trackChunk` 后回 `syncAck(status=ok, action=trackChunkReceived)`，收到 `eventChunk` 后回 `syncAck(status=ok, action=eventChunkReceived)`。
8. iPhone 发现 chunk 缺口时回 `syncAck(status=missingData, action=missingRangesRequested)`，并在 `missingRanges` 中带缺失 sequence 范围。
9. Watch 未收到 ACK 前保留待同步 chunk。
10. 断连后重新连接自动补传。
11. iPhone 校验完整会话后回 `syncAck(status=ok, action=sessionComplete)`。
12. Watch 收到 `sessionComplete` ACK 后标记本地会话为 `synced`。
13. iPhone 标记部分同步、完整同步和失败状态。
14. iPhone 缺少对应路线版本时，仍接收实际轨迹并标记路线缺失，必要时回 `syncAck(status=missingData, action=routeBackfillRequested)`。

验收：

1. Watch 结束后 iPhone 能收到摘要、轨迹和事件。
2. 重复发送 chunk 不产生重复轨迹。
3. iPhone 能对已接收 chunk 回 `trackChunkReceived` / `eventChunkReceived` ACK。
4. chunk 缺口会通过 `missingRangesRequested` 请求补传。
5. 断连结束后，重新连接可以补传。
6. iPhone 能展示同步不完整状态。
7. iPhone 完整性校验通过后会回 `syncAck(status=ok, action=sessionComplete)`。
8. Watch 收到完整 ACK 前不删除本地会话数据。

### Phase 6：iPhone 复盘与 GPX 导出

目标：

用户能在 iPhone 看清实际走了哪里、哪里偏航、轨迹是否保存完整。

任务：

1. 历史记录列表展示已完成会话。
2. 复盘详情页叠加计划路线和实际轨迹。
3. 偏航事件在地图上标记，并在列表中展示持续时间、最大偏航距离和发生位置。
4. 展示距离、用时、移动时间、累计爬升、平均速度；缺 HealthKit 数据时明确降级。
5. 轨迹未完整同步时提示。
6. 支持导出实际轨迹 GPX。

验收：

1. 复盘页能叠加计划路线和实际轨迹。
2. 偏航事件可见且能定位到地图。
3. 同步不完整时用户能看懂风险。
4. 无心率/能量数据时复盘仍可用。
5. GPX 导出文件能被常见地图工具打开。

## 测试计划

### 单元测试

1. GPX parser：有效 GPX、空 GPX、无海拔、点稀疏、超多点。
2. 距离和 bounds：跨小范围路线、回头路。
3. 路线简化：点数减少但起终点保留。
4. 转向点检测：左转、右转、急转、连续小抖动。
5. 最近路线段投影：线段中点、端点、交叉路线、回头路。
6. 偏航状态机：单点漂移、连续偏离、回归路线、定位不稳、暂停。
7. 同步去重：重复 envelope、重复 chunk、乱序 chunk。
8. 会话状态机：开始、暂停、继续、结束、恢复。
9. 路线质量检测：点数过少、点间距过大、无海拔、超多点。
10. 电量采样策略：标准、节能、低电量、极低电量的采样间隔和同步降频。
11. GPX 导出：实际轨迹导出后能被解析，缺失数据时有明确提示。

### 集成测试

1. iPhone 获取远端路线或导入 GPX -> 同步 Watch -> Watch 安装路线。
2. Watch 断连开始会话 -> 记录轨迹 -> 结束 -> 重连补传。
3. 偏航事件生成 -> 回传 iPhone -> 复盘展示。
4. payload 校验失败 -> Watch 保留旧路线。
5. App 重启 -> 恢复 active session。

### 真机验证

必须在 Apple Watch 真机验证：

1. WatchConnectivity 在锁屏、后台、断连、重连下的实际表现。
2. Core Location 采样频率、电量消耗和 GPS 精度。
3. HKWorkoutSession 权限、开始、暂停、结束。
4. MapKit 在 Watch 上的路线绘制性能。
5. 偏航 30m 阈值是否过敏或过钝。
6. 长时间记录后的本地存储、内存和电量表现。

## MVP 不做清单

1. 路线社区。
2. AI 推荐路线。
3. 复杂路线编辑。
4. 多地图源切换。
5. 专业等高线和山地地形图。
6. 团队位置共享。
7. 多日长线徒步计划。
8. 订阅体系。
9. Android、Wear OS、华为手表版本。
10. 完整训练分析和复杂运动评分。
11. Watch 端通过接口远程获取指定 GPX 路线。
12. Watch 端返航导航和路线反向规划。
13. Watch 端手动标记点的完整编辑、同步冲突处理和复盘分析。
14. 日落时间风险、预计完成时间晚于日落、长时间停留自动判断。
15. 完整安全页、完整数据页和复杂控制页；首版只保留必要状态和暂停/继续/结束入口。

## MVP 后续计划：Watch 远程获取指定路线

该能力用于用户已经知道路线编号、短码或精确名称时，由 Watch 调接口获取指定路线，并安装成本地计划路线。它不是路线推荐、附近路线发现或路线社区。

后续实现原则：

1. Watch 输入路线编号、短码或精确名称。
2. 服务端返回一条确定路线，或返回少量候选供用户确认。
3. 路线必须先下载、校验并安装成本地 `HikingRoute`。
4. 安装完成后复用 Watch 地图叠加、路线匹配、偏航检测、轨迹记录和结束回传。
5. 获取失败不影响 Watch 上已有路线。
6. 优先评估服务端直接返回 Watch route payload，减少 Watch 端解析和简化复杂 GPX 的负担。

## 开工顺序建议

1. 先完成 Phase 0 和 Phase 1，让远端路线、路线模型和 GPX 导入站稳。
2. 再做 Phase 2，尽早暴露 WatchConnectivity 的真实限制。
3. Phase 3 和 Phase 4 可以分支并行，但合并前必须以 Watch 本地会话为中心。
4. Phase 5 在 Watch 已能完整记录后推进，避免为不存在的数据设计复杂同步。
5. Phase 6 最后做，但复盘数据结构要在 Phase 3 起保持兼容。

## 每次开发迭代的输出格式

开发者每完成一个 slice，应输出：

1. 已实现功能。
2. 修改的主要文件。
3. 数据模型或协议变更。
4. 已运行的测试。
5. 未能验证的真机项。
6. 已知风险和下一步。

## 第一轮 Codex 任务建议

```txt
请开始实现 watchOS 徒步 App MVP 的第一轮工程落地任务：完成 Phase 0，并只实现 Phase 1 中不会让任务失控的基础部分。目标是建立一个可运行、可测试、后续能继续扩展的 iOS/watchOS/shared 工程骨架，而不是一次性做完整路线业务。

开工前先阅读并对齐：
1. `docs/watchos-development-prompt-implementation-plan-v0.1.md`
2. `docs/hiking-data-model-v0.1.md`
3. `docs/mvp-development-slices-v0.1.md`
4. `docs/watchconnectivity-sync-protocol-v0.1.md`
5. `docs/iphone-route-review-spec-v0.1.md`
6. `docs/battery-long-hike-strategy-v0.1.md`

目标：
1. 检查当前仓库是否已有 `.xcodeproj`、`.xcworkspace` 或 `Package.swift`；如果没有，在当前仓库下创建独立 App 工程目录，例如 `app/` 或 `watch-hiking-app/`。
2. 建立 iOS App、watchOS App、shared module 或 shared source group，保证 iPhone 和 Watch target 都能引用 shared models。
3. 配置定位、HealthKit、通知权限和 WatchConnectivity capability；权限缺失时 UI 显示明确状态，不崩溃。
4. 建立基础日志分类：route、sync、location、session、offRoute、battery。
5. 建立本地存储抽象，第一轮只选择 JSON/file、SwiftData 或 CoreData 中的一种；不要同时维护多套存储。
6. 定义第一轮必需 shared models：`GeoCoordinate`、`GeoBounds`、`HikingRoute`、`RouteVariant`、`RoutePoint`、`Waypoint`、`TurnPoint`、`RemoteRouteSummary`、`SyncEnvelope`、`SyncAck`。字段参考数据模型和同步协议，先保证 Codable、稳定 ID、版本/sequence、时间戳、checksum 能表达。
7. 明确 Watch 路线卡片和 `HikingSession` 的边界：同步路线不等于创建会话；会话只在用户开始徒步时创建。
8. 实现一个最小 `RemoteRouteCatalog` 协议和 mock/local fixture 实现。如果真实服务端接口尚未提供，使用本地 JSON fixture 返回远端路线摘要，并在交付说明中标注服务端接口待接入。
9. 准备至少 3 条 GPX fixture 文件：普通路线、回头路/交叉路线、点稀疏路线。本轮可以先准备 fixture，不要求完整 GPX parser 全部通过。
10. 实现最小 iPhone 路线列表/详情占位：能显示 mock 远端路线摘要、进入详情页、展示路线基本字段和 Watch 同步状态占位。
11. 实现最小 Watch 路线卡片占位：能显示一条本地/mock 路线的名称、距离、同步时间和开始按钮；开始按钮可以先进入占位地图或占位会话页。
12. 实现 WatchConnectivity 最小 ping/ack，用于验证两端通信链路。路线 payload、trackChunk、eventChunk 暂不在本轮实现。
13. 增加单元测试，至少覆盖 shared models Codable、checksum 计算、mock route catalog、本地存储读写、SyncEnvelope 编解码和 ping/ack payload 编解码。

约束：
1. 不要实现社区、AI、多地图源、订阅或复杂路线编辑。
2. MapKit 只用于展示，不作为核心模型。
3. 数据模型要能被 Watch 同步、本地存储、后续 GPX 导入和复盘复用。
4. 不要在第一轮实现完整 GPX parser、路线简化、TurnPoint 检测、偏航检测、轨迹记录、路线 payload 下发、trackChunk 回传或复盘导出；这些留给后续 slice。
5. 如果创建 Xcode 工程遇到模板或环境限制，可以先创建 Swift Package/shared module 和清晰的工程目录结构，但必须说明缺口和下一步如何补齐 iOS/watchOS target。
6. 所有平台能力、后台行为、WatchConnectivity 可靠性、Core Location 采样、电量表现和 MapKit 性能，如果没有真机验证，都必须标注“需要真机验证”。

完成后请运行可用测试，并输出：
1. 本轮使用的 App 工程目录。
2. 已实现功能和主要文件。
3. 数据模型或协议字段。
4. 已运行的测试及结果。
5. 未能验证的真机项。
6. 已知风险和下一轮建议。
```
