# WatchOS 能力使用取舍 v0.1

更新日期：2026-06-06

## 文档目的

本文说明 Apple Watch / watchOS 徒步导航 MVP 使用哪些系统能力、不使用哪些能力，以及背后的产品和技术原因。

它不是 API 详细设计，也不是最终实测结论。凡涉及后台表现、耗电、定位精度、WatchConnectivity 传输延迟、MapKit 渲染性能和 HealthKit 采集稳定性的内容，在没有真机和实地验证前都标记为“需要验证”。

## 取舍原则

1. 首版优先保证端到端闭环：路线下发、腕上地图、路线跟随、偏航提醒、轨迹记录、暂停/继续/结束和结束回传。
2. Watch 端只承担行进中高频决策，不复制 iPhone 的路线管理、复杂检索和复盘分析。
3. 核心数据使用 App 自有模型，系统框架只作为采集、展示、同步或授权能力。
4. 不把不稳定、未验证或平台限制明显的能力包装成首版承诺。
5. 能降级的能力必须有降级路径；不能降级的能力要在开始前明确提示。

## 首版使用的能力

| 能力 | 首版用途 | 使用边界 | 为什么使用 |
| --- | --- | --- | --- |
| SwiftUI | iPhone / Watch 页面骨架、状态视图、确认层、控制入口 | 不追求复杂动画和重型可视化 | 原生开发成本低，适合 watchOS 小屏状态驱动界面 |
| MapKit | Watch 地图底图、路线叠加、当前位置、已走轨迹；iPhone 路线预览和复盘地图 | Watch 固定标准底图，不做图层切换；MapKit 不作为路线核心数据模型 | 原生地图集成成本最低，首版优先把路线关系讲清楚 |
| Core Location | Watch 行进中定位、速度/方向辅助判断、轨迹点采集、偏航计算输入 | 采样频率按电量模式调整；低可信定位点不能直接触发偏航或中途接入路线 | 徒步导航和轨迹记录的 P0 能力 |
| HealthKit / HKWorkoutSession | 徒步运动会话、心率/能量等运动数据引用、后台运动记录能力探索 | 权限缺失或启动失败时，地图导航和轨迹记录继续；健康数据为空或不完整 | 可提升长时间运动记录和复盘价值，但不能成为导航闭环的单点依赖 |
| WatchConnectivity | iPhone 下发路线、Watch 回传会话状态、轨迹 chunk、事件 chunk 和摘要 | 路线/轨迹不能只依赖即时消息；需要本地落盘、ACK、去重和补传 | Apple Watch 与 iPhone 协同的主通道，符合本产品端分工 |
| UserNotifications / Watch 触觉提醒 | 偏航、接近转向点、低电量、关键状态提醒 | 首版以触觉和轻量状态为主；复杂通知策略后置 | 徒步中用户不应频繁看屏，偏航提醒必须能抬腕外感知 |
| 本地文件 / App 自有存储 | 路线 payload、会话、轨迹点、事件、待同步 chunk | 不把 HealthKit 或 MapKit 当主存储；同步完成前不删除 Watch 本地记录 | 户外弱连接下必须保证轨迹不丢 |
| Digital Crown | Watch 地图缩放 | 不承担复杂菜单导航 | 符合手表地图操作习惯，减少遮挡 |

## 有限使用或降级使用的能力

| 能力 | 首版处理 | 降级路径 | 原因 |
| --- | --- | --- | --- |
| Watch 地图底图加载 | 正常情况下显示 Apple MapKit 标准底图 | 底图慢、网络弱或低电量时，保留路线线框、当前位置、已走轨迹和偏航关系 | 地图底图不能成为记录和偏航判断的前置条件 |
| iPhone 实时状态同步 | 行进中低频同步 `sessionStatus` | 断连、低电量或后台受限时停止实时同步，结束后补传 | 实时状态有用，但可靠轨迹回传更重要 |
| HealthKit 运动指标 | 尽量采集心率、能量和运动引用 | 无授权或不可用时，复盘页显示地图和轨迹，健康指标为空 | 徒步导航核心是位置和路线，不是健康数据完整性 |
| 转向点识别 | 从 GPX 几何初步生成明显转向点 | 识别不足时只保留偏航检测和路线显示 | GPX 通常缺少标准路口语义，几何转向需要实地验证阈值 |
| 低电量策略 | 分标准、节能、低电量、极低电量模式调整采样、刷新和同步 | 极低电量下优先保存会话和最后位置 | 长时间徒步中，保命的是轨迹和状态，而不是视觉完整度 |
| Watch 端自由记录 | 无路线时允许开始记录实际轨迹 | 不显示计划路线、不算剩余距离、不触发偏航和转向提醒 | 保证记录闭环，但不假装提供路线导航 |
| 自由记录中途接入路线 | 仅在当前位置离路线足够近且用户确认后接入 | 距离过远时只安装为下次可用；历史轨迹不补算 | 避免静默改写会话语义和复盘数据 |

## 首版不使用的能力

| 能力 | 首版结论 | 为什么不使用 |
| --- | --- | --- |
| Watch 端卫星 / 混合 / 多图层切换 | 不做 | 2026-06-06 查证 Apple MapKit 文档，`MapStyle.imagery` 和 `MapStyle.hybrid(...)` 在 watchOS 上可能渲染回标准样式，不能作为稳定产品能力承诺 |
| Watch 离线地图瓦片 | 不做 | 离线图涉及瓦片来源、缓存策略、授权、存储、电量和渲染性能，超出 MVP 闭环 |
| 第三方地图 SDK | 不做 | 首版优先降低集成、计费、授权和 watchOS 兼容复杂度 |
| 专业等高线 / 山地地形图 | 不做 | 对徒步有价值，但首版目标是路线跟随和偏航提醒，不先扩展地图专业层 |
| Watch 端路线社区 / 附近路线发现 / AI 推荐 | 不做 | Watch 小屏不适合复杂探索；产品首版不做路线社区和推荐 |
| Watch 端远程获取指定 GPX 路线 | MVP 不做，后续计划 | 首版主路径是 iPhone 准备并同步路线；Watch 远程获取需要接口、鉴权、缓存、失败兜底和确认层 |
| Watch 端复杂路线编辑 | 不做 | 编辑 GPX、关键点和路线变体需要大屏交互，放在 iPhone 或后续版本 |
| Watch 端返航导航 / 路线反向规划 | 不做 | 需要额外路线生成、风险提示和状态处理，容易扩大安全承诺 |
| 团队位置共享 | 不做 | 需要账号、隐私、网络、实时同步和安全策略，偏离单人徒步闭环 |
| 多日徒步计划 | 不做 | 涉及跨天会话、营地、补给、电量和数据分段策略，先不进入首版 |
| 订阅体系 / 商业 POI | 不做 | 与首版验证路线和会话闭环无关 |
| Android / Wear OS / 华为手表版本 | 不做 | 当前主线是 Apple Watch 首发闭环，其他平台仅保留调研和后续路线判断 |
| WorkoutKit 深度训练计划能力 | 不做 | 本产品不是训练计划 App，首版只需要徒步会话和复盘相关健康数据 |
| Live Activities / Dynamic Island | 不作为核心能力 | 徒步行进中主视图在 Watch；iPhone 只做准备和复盘 |

## 能力与 MVP 闭环的关系

| MVP 环节 | 必需能力 | 可选能力 | 不依赖 |
| --- | --- | --- | --- |
| iPhone 获取和准备路线 | 远端接口、GPX 解析、App 自有路线模型、iPhone MapKit | 搜索过滤、本地缓存 | Watch 端路线发现、路线社区 |
| 路线同步到 Watch | WatchConnectivity、本地校验、ACK、去重 | 同步进度提示 | 单次 `sendMessage` 成功 |
| Watch 开始徒步 | Core Location、本地会话存储、用户确认层 | HealthKit / HKWorkoutSession、触觉提示 | iPhone 在线 |
| 腕上地图导航 | MapKit 标准底图、路线叠加、当前位置、方向、轨迹 | Digital Crown 缩放、轻量状态浮层 | 多地图源、卫星图、离线地图 |
| 偏航检测 | Core Location、路线几何投影、连续点状态机、触觉提醒 | 回到路线方向提示 | 地图底图成功加载 |
| 自由记录 | Core Location、本地轨迹、会话状态 | HealthKit 指标 | 计划路线、偏航状态机 |
| 结束和回传 | 本地轨迹/事件/摘要、WatchConnectivity 可靠通道、ACK | 增量同步 | 行进中实时同步 |
| iPhone 复盘 | App 自有会话模型、轨迹点、事件、iPhone MapKit | HealthKit 指标、GPX 导出 | Watch 仍在线 |

## 权限和失败处理

| 权限 / 能力失败 | 是否阻断 | 产品处理 |
| --- | --- | --- |
| 定位权限缺失 | 阻断开始导航和记录 | 明确提示授权；没有定位无法生成可靠轨迹和偏航判断 |
| HealthKit 权限缺失 | 不阻断 | 允许继续地图导航和轨迹记录，运动数据标记为缺失 |
| 通知 / 触觉相关能力不可用 | 不阻断，但降级 | 地图状态仍显示偏航和转向，提醒体验降低 |
| WatchConnectivity 不可达 | 不阻断 Watch 已有路线会话 | iPhone 显示未连接或排队；Watch 本地记录，结束后补传 |
| MapKit 底图加载失败 | 不阻断 | Watch 显示路线线框、当前位置、已走轨迹和偏航连接线 |
| 路线 payload 校验失败 | 阻断安装新路线 | 保留旧路线，不覆盖当前可用数据 |

## 需要真机验证的事项

| 事项 | 验证目标 |
| --- | --- |
| WatchConnectivity 在锁屏、后台、断连、重连下的表现 | 确认 route payload、track chunk、event chunk 和 ACK 的延迟与可靠性 |
| Core Location 长时间采样 | 确认不同采样策略下的精度、电量和偏航误报率 |
| HKWorkoutSession 与定位并行运行 | 确认会话恢复、心率采集、后台行为和耗电 |
| MapKit Watch 路线绘制性能 | 确认长路线、多点轨迹、频繁刷新下是否卡顿 |
| 低电量策略 | 确认采样降低后仍能保留可用轨迹和关键偏航提醒 |
| 自由记录中途接入路线 | 验证距离阈值、用户确认层和复盘语义是否清晰 |

## 官方参考

以下页面在 2026-06-06 查阅。Apple Developer Documentation 页面需要 JavaScript 渲染，具体 API 行为仍以 Xcode SDK、官方文档和真机验证为准。

1. [WatchConnectivity - Apple Developer Documentation](https://developer.apple.com/documentation/watchconnectivity)
2. [HKWorkoutSession - Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
3. [Map - Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/map)
4. [Core Location - Apple Developer Documentation](https://developer.apple.com/documentation/corelocation)
5. [MapStyle.imagery - Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mapstyle/imagery)
6. [MapStyle.hybrid(elevation:pointsOfInterest:showsTraffic:) - Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mapstyle/hybrid%28elevation%3Apointsofinterest%3Ashowstraffic%3A%29)

## 相关文档

1. [WatchOS 徒步 App MVP 产品定义 v0.1](./watchos-hiking-app-product-v0.1.md)
2. [WatchOS 徒步 App MVP 开发切分 v0.1](./mvp-development-slices-v0.1.md)
3. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
4. [WatchOS 徒步地图页规格 v0.1](./watchos-map-page-spec-v0.1.md)
5. [偏航检测规则 v0.1](./off-route-detection-spec-v0.1.md)
6. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)
7. [低电量与长时间徒步策略 v0.1](./battery-long-hike-strategy-v0.1.md)
