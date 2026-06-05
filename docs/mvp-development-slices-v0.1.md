# WatchOS 徒步 App MVP 开发切分 v0.1

更新日期：2026-06-05

## MVP 目标

第一版要验证一个完整闭环：

1. iPhone 从远端接口获取路线列表，也支持导入 GPX。
2. iPhone 展示计划路线。
3. iPhone 同步路线到 Apple Watch。
4. Watch 以地图为首屏开始徒步。
5. Watch 记录实际轨迹并显示在地图上。
6. Watch 触发偏航和转向提醒。
7. Watch 结束后回传轨迹和事件。
8. iPhone 复盘计划路线和实际轨迹。

## 不做范围

第一版暂不做：

1. 路线社区。
2. AI 路线推荐。
3. 复杂路线编辑。
4. 多地图源。
5. 专业等高线地图。
6. 团队位置共享。
7. 多日徒步。
8. 订阅体系。
9. Android / Wear OS / 华为手表版本。
10. Watch 端通过接口远程获取指定 GPX 路线。
11. Watch 端返航导航和路线反向规划。
12. Watch 端手动标记点的完整编辑、同步冲突处理和复盘分析。
13. 日落时间风险、预计完成时间晚于日落、长时间停留自动判断。
14. 完整安全页、完整数据页和复杂控制页；首版只保留必要状态和暂停/继续/结束入口。

说明：Watch 远程获取指定路线是 MVP 后续计划。它只按用户已知路线编号、短码或精确名称获取路线，不做路线推荐、附近路线发现或路线社区。

## 开发切片

### Slice 1：路线导入与数据模型

目标：

建立 App 自有路线数据结构，完成远端路线列表获取、路线详情下载、GPX 导入和路线预览。

范围：

1. `HikingRoute`。
2. `RouteVariant`。
3. `RoutePoint`。
4. `Waypoint` 起点/终点。
5. `TurnPoint` 初版生成。
6. `RemoteRouteSummary`。
7. 远端路线列表接口请求、刷新和本地缓存状态。
8. 按名称、编号或区域搜索远端路线摘要；服务端暂不支持时先做本地摘要过滤。
9. 远端路线详情下载、校验并安装为本地 `HikingRoute`。
10. GPX 导入解析。
11. 路线距离、bounds、点数统计。
12. Watch 简化路线生成。

验收：

1. 能从远端接口获取路线列表并显示摘要。
2. 能下载一条远端路线详情并保存为本地路线。
3. 能按名称、编号或区域搜索或过滤远端路线摘要。
4. 能导入一条 GPX。
5. 能在 iPhone 地图上显示计划路线。
6. 能显示距离、点数、起点、终点。
7. 能生成 Watch 端简化路线。
8. 能识别明显转向点。

参考文档：

1. [徒步路线与会话数据模型 v0.1](./hiking-data-model-v0.1.md)
2. [iPhone 路线详情与复盘页面规格 v0.1](./iphone-route-review-spec-v0.1.md)

### Slice 2：iPhone 路线详情与 Watch 路线下发

目标：

让用户确认路线，并可靠同步到 Watch。

范围：

1. iPhone 路线详情页。
2. Watch 准备状态展示。
3. `routeManifest`。
4. `routePayload`。
5. `syncAck(status=ok, action=routeInstalled)`。
6. Watch 路线卡片。
7. 同步失败重试。
8. route payload 字段完整性：`HikingRoute` 摘要、`simplifiedForWatch`、`TurnPoint`、`Waypoint`、默认提醒配置。

验收：

1. iPhone 能显示 Watch 是否已连接。
2. iPhone 能把路线同步到 Watch。
3. Watch 能显示路线名称、距离和开始按钮。
4. 同步失败不覆盖 Watch 旧路线。
5. Watch 收到同版本路线时能去重。
6. Watch 安装 payload 成功后回 `syncAck(status=ok, action=routeInstalled)`。
7. route payload 校验失败不会覆盖旧路线。

参考文档：

1. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
2. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)

### Slice 3：Watch 徒步会话与轨迹记录

目标：

Watch 能独立开始、暂停、继续、结束一次徒步，并本地保存轨迹。

范围：

1. `HikingSession`。
2. `TrackPoint`。
3. `SessionEvent`。
4. Watch 开始徒步。
5. Core Location 定位采样。
6. HealthKit / HKWorkoutSession 初步接入。
7. 暂停、继续、结束。
8. App 恢复 active session。
9. 无计划路线时的 Watch 自由记录模式。

验收：

1. Watch 可在 iPhone 断连时开始徒步。
2. Watch 能持续记录轨迹点。
3. 暂停期间不写正式轨迹点。
4. 结束后生成 `SessionSummary`。
5. App 重启后能恢复进行中会话。
6. Watch 没有收到路线时也能开始自由记录，且轨迹点不写路线投影字段。

参考文档：

1. [徒步路线与会话数据模型 v0.1](./hiking-data-model-v0.1.md)
2. [低电量与长时间徒步策略 v0.1](./battery-long-hike-strategy-v0.1.md)

### Slice 4：Watch 地图页、偏航检测与转向提醒

目标：

把 Watch 地图页做成行进中主体验。

范围：

1. Watch 地图页。
2. Apple MapKit 底图。
3. 计划路线叠加。
4. 已走轨迹叠加。
5. 当前定位点和方向。
6. 最近路线段投影。
7. 偏航状态机。
8. 偏航触觉提醒。
9. 转向点提醒。

验收：

1. Watch 首屏是地图页。
2. 地图显示计划路线、已走轨迹、当前位置。
3. 正常行进时显示“路线上”。
4. 连续偏离超过阈值后触发偏航。
5. 单个 GPS 漂移点不会触发偏航。
6. 接近明显转向点时提醒。
7. 无计划路线时地图显示自由记录状态，不显示计划路线、起终点、剩余距离和偏航状态。
8. 偏航和转向事件写入 `SessionEvent`。

参考文档：

1. [WatchOS 徒步地图页规格 v0.1](./watchos-map-page-spec-v0.1.md)
2. [偏航检测规则 v0.1](./off-route-detection-spec-v0.1.md)

### Slice 5：轨迹回传、去重与复盘数据完整性

目标：

Watch 结束后能可靠把轨迹、事件和摘要同步回 iPhone。

范围：

1. `sessionStatus`。
2. `trackChunk`。
3. `eventChunk`。
4. `sessionSummary`。
5. `syncAck(status=ok, action=sessionComplete)`。
6. `syncAck(status=ok, action=trackChunkReceived)`。
7. `syncAck(status=ok, action=eventChunkReceived)`。
8. `syncAck(status=missingData, action=missingRangesRequested)`。
9. 轨迹点去重。
10. 事件去重。
11. 断连后补传。
12. 部分同步状态。

验收：

1. Watch 结束后 iPhone 能收到会话摘要。
2. iPhone 能收到完整轨迹点。
3. 重复 chunk 不产生重复轨迹。
4. iPhone 能对 track/event chunk 回 ACK。
5. chunk 缺口能通过 `missingRanges` 请求补传。
6. iPhone 能识别部分同步和完整同步。
7. Watch 收到完整 ACK 前不删除本地记录。

参考文档：

1. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
2. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)

### Slice 6：iPhone 复盘页与 GPX 导出

目标：

用户能在 iPhone 看懂本次徒步结果，并导出实际轨迹。

范围：

1. 复盘详情页。
2. 计划路线和实际轨迹叠加。
3. 偏航段高亮。
4. 偏航事件列表。
5. 距离、用时、爬升、速度摘要。
6. 历史记录列表。
7. GPX 导出。

验收：

1. iPhone 能显示计划路线和实际轨迹叠加。
2. 复盘页能显示偏航事件。
3. 轨迹未完整同步时页面明确提示。
4. 没有 HealthKit 数据时仍可复盘地图。
5. 用户能导出实际轨迹 GPX。

参考文档：

1. [iPhone 路线详情与复盘页面规格 v0.1](./iphone-route-review-spec-v0.1.md)
2. [徒步路线与会话数据模型 v0.1](./hiking-data-model-v0.1.md)

## 横向技术任务

这些任务贯穿多个 slice。

| 任务 | 说明 |
| --- | --- |
| 权限管理 | 定位、HealthKit、通知 |
| 本地存储 | 路线、会话、轨迹、事件、同步队列 |
| 日志和诊断 | 同步失败、定位质量、偏航事件 |
| 测试数据 | 准备多条 GPX，包括回头路、路线交叉、点稀疏 |
| 真机验证 | Apple Watch 地图、GPS、Workout、WatchConnectivity |
| 省电策略 | 低电量模式、主动省电、App 恢复 |

## 推荐开发顺序

1. Slice 1：先让 iPhone 能获取远端路线、导入 GPX 并展示路线。
2. Slice 2：打通路线下发到 Watch。
3. Slice 3：让 Watch 能独立记录一条轨迹。
4. Slice 4：把 Watch 地图和偏航做出来。
5. Slice 5：做可靠回传和去重。
6. Slice 6：做 iPhone 复盘和导出。
7. MVP 后续：做 Watch 远程获取指定路线，复用同一套本地路线安装、地图叠加和偏航检测能力。

这个顺序的好处是每一步都有可见结果，不会在同步或算法里闷太久。

## MVP 总体验收

MVP 完成时，必须能演示：

1. 从 iPhone 获取一条远端路线，或导入一条 GPX。
2. iPhone 同步路线到 Watch。
3. Watch 显示地图和计划路线。
4. Watch 开始徒步并记录实际轨迹。
5. Watch 上已走轨迹实时叠加到地图。
6. 用户偏离路线后 Watch 震动提醒。
7. 用户结束徒步后轨迹同步回 iPhone。
8. iPhone 复盘页展示计划路线、实际轨迹和偏航事件。
9. Watch 与 iPhone 断连时不会丢失记录。
10. 低电量或底图失败时核心记录能力仍可用。

## 需要回看标记

数据模型后续需要重点回看，尤其是：

1. `RouteVariant` 是否过重。
2. `TrackPoint` 字段是否需要裁剪。
3. `SessionEvent` 类型是否足够。
4. `SyncEnvelope` 是否符合 WatchConnectivity 实测表现。
5. MVP 最小字段是否还能继续收缩。
6. Watch 远程获取指定路线时，服务端返回 GPX 还是直接返回 Watch route payload。
