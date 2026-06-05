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
你是一个资深 iOS/watchOS 工程师。请在现有仓库中实现一个 Apple Watch 优先的徒步导航与轨迹记录 App MVP。

产品定位：
iPhone 负责路线导入、路线管理、路线同步和复盘；Apple Watch 负责腕上地图、路线跟随、偏航提醒、轨迹记录、暂停/继续/结束和结束后回传。

第一版必须完成的闭环：
1. iPhone 导入 GPX 路线。
2. iPhone 展示计划路线详情和地图预览。
3. iPhone 将 Watch 简化路线、转向点、起终点和提醒配置同步到 Apple Watch。
4. Watch 显示路线卡片，并以地图作为徒步首屏。
5. Watch 开始徒步后独立采集定位、记录轨迹、显示计划路线和已走轨迹。
6. Watch 根据计划路线几何做偏航检测和转向提醒。
7. Watch 支持暂停、继续、结束，并在 App 重启后恢复 active/paused 会话。
8. Watch 结束后可靠回传轨迹点、事件和摘要到 iPhone。
9. iPhone 复盘页叠加计划路线、实际轨迹和偏航事件。

核心技术约束：
1. 使用 Swift / SwiftUI / MapKit / Core Location / WatchConnectivity。
2. Watch 端行进中能力不能依赖 iPhone 在线。
3. 路线、轨迹、事件、同步封包使用 App 自有数据模型，不把 MapKit 类型当核心模型。
4. HealthKit / HKWorkoutSession 可以接入运动记录和心率，但 HealthKit 失败不能阻断地图导航和轨迹记录。
5. 路线和轨迹这类不能丢的数据不能只依赖 sendMessage；必须本地先落盘，再通过 WatchConnectivity 的可靠通道补传。
6. 偏航检测只基于 GPX 几何和实时定位，不依赖 Apple Maps 路网。
7. 单个 GPS 漂移点不能触发偏航；定位不稳时优先提示定位不稳。
8. 低电量时可以降低地图刷新、采样频率和实时同步，但必须保留本地轨迹保存、偏航判断和结束摘要。

请按 slice 开发，每个 slice 都要做到可运行、可验证、可回滚。不要提前实现路线社区、AI 推荐、多地图源、专业等高线、团队位置共享、多日徒步、订阅体系、Android/Wear OS/华为手表版本。

每次实现前先阅读相关规格文档，优先复用现有项目结构和代码风格。每个 slice 完成后请补充必要的单元测试、模拟数据、真机验证步骤和已知限制。
```

## 架构边界

### 端职责

| 端 | 必做 | 不做 |
| --- | --- | --- |
| iPhone | GPX 导入、路线库、路线详情、Watch 同步、历史记录、复盘、GPX 导出、设置 | 行进中主导航 |
| Watch | 路线卡片、地图首屏、定位采样、轨迹记录、偏航检测、转向提醒、暂停/继续/结束、本地待同步 | 复杂路线编辑、深度复盘分析 |

### 推荐模块

| 模块 | 所属端 | 职责 |
| --- | --- | --- |
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

1. 建立 iOS target、watchOS target、shared module 或 shared source group。
2. 配置定位权限、HealthKit entitlement、WatchConnectivity capability。
3. 增加基础日志分类：route、sync、location、session、offRoute、battery。
4. 建立本地存储抽象，先支持 JSON/file 或 SwiftData/CoreData 中的一种，不在 MVP 中同时维护多套存储。
5. 准备至少 3 条 GPX fixture：普通路线、回头路/交叉路线、点稀疏路线。

验收：

1. iPhone 和 Watch App 都能启动。
2. 两端能访问 shared models。
3. 权限缺失时 UI 有明确状态，不崩溃。
4. Watch 与 iPhone 能完成一条最小 ping/ack。

### Phase 1：路线导入与 iPhone 预览

目标：

iPhone 能导入 GPX，生成 App 自有路线模型，并展示计划路线。

任务：

1. 实现 GPX parser，读取 trkpt/rtept/wpt 的经纬度、海拔和时间。
2. 生成 `HikingRoute`、`RouteVariant.original`、起点、终点。
3. 计算距离、bounds、点数、海拔可用性、checksum。
4. 生成 `simplifiedForWatch`，保留原始路线用于复盘和导出。
5. 生成初版 `TurnPoint`。
6. iPhone 路线详情页展示地图、距离、点数、起终点、转向点数量和同步入口。

验收：

1. 能导入有效 GPX 并保存路线。
2. 无有效轨迹点的 GPX 会失败并提示。
3. 点数过多时生成 Watch 简化路线。
4. 点间距过大时标记路线质量风险。
5. iPhone 地图能显示计划路线、起点和终点。

### Phase 2：路线下发到 Watch

目标：

iPhone 能可靠把路线 manifest 和 payload 下发到 Watch，Watch 能安装并展示路线卡片。

任务：

1. 定义 `SyncEnvelope` 编解码、checksum、schemaVersion。
2. 实现 `routeManifest` 发送和 Watch ACK：`alreadyInstalled`、`readyForPayload`、`rejected`。
3. 实现 `routePayload` 文件传输或小 payload userInfo 传输。
4. Watch 端安装路线时采用临时文件 + 校验 + 原子替换。
5. iPhone 显示同步状态：未同步、同步中、已同步、失败、Watch 不在线。
6. Watch 显示路线卡片：名称、距离、同步时间、开始按钮。

验收：

1. Watch 在线时能同步并安装路线。
2. Watch 不在线时不会假装已就绪。
3. 同版本同 checksum 路线不会重复安装。
4. payload 校验失败不会覆盖旧路线。
5. 同步失败后可以重试。

### Phase 3：Watch 会话与轨迹记录

目标：

Watch 能独立开始、暂停、继续、结束徒步，并可靠保存轨迹。

任务：

1. 实现 `HikingSession` 状态机：planned、active、paused、finished、abandoned。
2. 接入 Core Location，按当前电量模式采样。
3. 接入 HKWorkoutSession；失败时降级为纯地图导航和轨迹记录。
4. 实现 `TrackPoint` sequence 递增写入。
5. 暂停期间不写正式轨迹点。
6. 每次状态变化立即落盘，每 1-5 分钟更新摘要草稿。
7. App 启动时恢复 active/paused 会话并写入 `appRecovered` 事件。

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
8. 实现转向点提醒，同一转向点只提醒一次。
9. 生成 `SessionEvent`：offRouteStarted、offRouteUpdated、offRouteEnded、locationAccuracyPoor、turnAlert。

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
3. 每个 chunk 带 sequence、isFinal、checksum。
4. iPhone 按 `sessionId + sequence` 去重写入轨迹点。
5. Watch 未收到 ACK 前保留待同步 chunk。
6. 断连后重新连接自动补传。
7. iPhone 标记部分同步、完整同步和失败状态。

验收：

1. Watch 结束后 iPhone 能收到摘要、轨迹和事件。
2. 重复发送 chunk 不产生重复轨迹。
3. 断连结束后，重新连接可以补传。
4. iPhone 能展示同步不完整状态。
5. Watch 收到完整 ACK 前不删除本地会话数据。

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

### 集成测试

1. iPhone 导入 GPX -> 同步 Watch -> Watch 安装路线。
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

## 开工顺序建议

1. 先完成 Phase 0 和 Phase 1，让路线模型和 GPX 导入站稳。
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
请开始实现 WatchOS 徒步 App MVP 的 Phase 0 和 Phase 1。

先阅读 docs/watchos-development-prompt-implementation-plan-v0.1.md、docs/hiking-data-model-v0.1.md、docs/mvp-development-slices-v0.1.md、docs/iphone-route-review-spec-v0.1.md。

目标：
1. 建立 iOS/watchOS/shared 的工程骨架或对现有工程做最小必要整理。
2. 定义 HikingRoute、RouteVariant、RoutePoint、Waypoint、TurnPoint、GeoBounds、GeoCoordinate 等 shared models。
3. 实现 GPX 导入解析，生成 original route variant。
4. 计算距离、bounds、起终点、点数、checksum。
5. 生成 simplifiedForWatch variant。
6. 实现初版 TurnPoint 检测。
7. 在 iPhone 路线详情页显示地图预览、距离、点数、起终点、Watch 简化点数和转向点数量。
8. 增加 GPX fixture 和单元测试。

约束：
1. 不要实现社区、AI、多地图源、订阅或复杂路线编辑。
2. MapKit 只用于展示，不作为核心模型。
3. 数据模型要能被 Watch 同步和本地存储复用。
4. 点数过多时必须保留 original，同时生成 simplifiedForWatch。
5. GPX 无有效点时必须失败并给出可理解错误。

完成后请运行可用测试，并说明哪些 Watch 真机项尚未验证。
```
