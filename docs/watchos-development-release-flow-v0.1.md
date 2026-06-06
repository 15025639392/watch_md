# WatchOS 徒步 App 开发与上架流程 v0.1

更新日期：2026-06-06

## 文档目的

本文补充 Apple Watch 徒步 App 从开发准备、真机验证、内测到 App Store 上架的完整流程。

它不是功能规格，也不扩大 MVP 范围。MVP 仍以 iPhone 准备路线、Apple Watch 腕上地图导航、偏航提醒、轨迹记录和结束回传为第一版闭环。

本文涉及 Apple Developer Program、App Store Connect、TestFlight、App 隐私、审核政策、HealthKit、定位、WatchConnectivity 等高变动信息。以下流程基于 2026-06-06 查阅的 Apple 官方文档；正式提交前需要再次核对官方页面、Xcode 当前版本和 App Store Connect 实际表单。

## 发布对象

首版按“包含 iPhone App 和 Apple Watch App 的 iOS App”准备，不按 watch-only App 规划。

原因：

1. 产品定义中 iPhone 承担路线列表、GPX 导入、路线详情、路线同步和复盘。
2. Watch 首版承担行进中地图、路线跟随、偏航提醒、轨迹记录和结束回传。
3. 上架材料、权限说明、隐私问卷、截图和审核说明需要同时覆盖 iPhone 与 Apple Watch 体验。

## 总体流程

```txt
账号与组织准备
  -> 开发环境和设备准备
  -> App 标识、签名和 Capabilities
  -> 隐私、权限和数据合规设计
  -> 按 MVP slice 开发
  -> 单元测试、模拟器验证和真机验证
  -> App Store Connect 建档
  -> TestFlight 内测
  -> 审核材料和发布版本准备
  -> App Review 提交
  -> 分阶段发布和线上监控
```

## 需要申请或准备的东西

| 类别 | 需要准备 | 用途 | 责任人 | 状态 |
| --- | --- | --- | --- | --- |
| Apple 账号 | Apple Developer Program 会员资格 | 真机签名、Capabilities、TestFlight、App Store 上架 | 产品 / 开发负责人 | 待准备 |
| 开发机器 | macOS、Xcode、Command Line Tools | 构建 iOS/watchOS App、归档和上传 | 开发负责人 | 待确认 |
| 测试设备 | iPhone 真机、Apple Watch 真机 | 验证定位、Workout、WatchConnectivity、地图、电量 | QA / 开发 | 待准备 |
| App 标识 | iPhone App Bundle ID、Watch App Bundle ID、Watch Extension / App 配置 | 签名、Capabilities、App Store Connect 关联 | 开发负责人 | 待配置 |
| 证书和描述文件 | Development / Distribution signing | 调试、TestFlight、App Store 分发 | 开发负责人 | 待配置 |
| Capabilities | HealthKit、WatchConnectivity、Location、Notifications 等 | 支撑运动记录、同步和提醒 | 开发负责人 | 待配置 |
| App Store Connect | App 记录、SKU、Bundle ID、分类、年龄分级 | 建立待发布 App | 产品 / 开发 | 待准备 |
| 隐私材料 | 数据收集清单、用途、第三方共享、追踪情况 | App 隐私问卷和审核 | 产品 / 法务 / 开发 | 待整理 |
| 权限文案 | 定位、健康、通知等 purpose strings | 系统弹窗和审核理解 | 产品 / 开发 | 待撰写 |
| 素材 | App 图标、iPhone 截图、Apple Watch 截图、描述、关键词 | App Store 产品页 | 产品 / 设计 | 待准备 |
| 支持信息 | 支持网址、隐私政策网址、联系邮箱 | App Store 必填与审核沟通 | 产品 / 运营 | 待准备 |
| 测试账号或说明 | 审核可复现路径、测试路线、权限授权步骤 | App Review 审核说明 | 产品 / QA | 待准备 |

## 开发环境准备

### Apple Developer Program

需要先加入 Apple Developer Program，才能完整使用证书、标识符、描述文件、TestFlight 和 App Store 分发能力。

准备项：

1. 确认使用个人账号还是组织账号。
2. 组织账号需要准备法律实体信息、D-U-N-S Number 等 Apple 注册流程要求的信息。
3. 在团队内分配 App Manager、Developer、Marketing、Customer Support 等 App Store Connect 角色。
4. 保存团队 ID、Bundle ID 命名规则和签名管理方式。

### Xcode 与 SDK

准备项：

1. 安装当前稳定版 Xcode。
2. 安装 iOS / watchOS 对应 SDK 和模拟器运行时。
3. 确认工程可在 `watch-hiking-app/` 内构建，不把工程文件散落到文档目录。
4. 配置自动签名或手动签名策略。
5. 在开发机上登录 Apple Developer 账号。

需要验证：

1. iPhone App target 能在 iPhone 真机运行。
2. Watch App target 能安装到配对 Apple Watch。
3. Shared Swift Package / shared module 能被 iPhone 和 Watch target 使用。
4. Archive 能生成可上传到 App Store Connect 的构建产物。

## App 标识、签名和 Capabilities

### Bundle ID

建议按产品域名或组织域名建立稳定 Bundle ID，例如：

| Target | 示例 | 说明 |
| --- | --- | --- |
| iPhone App | `com.example.watchhiking` | App Store 主 App |
| Watch App | `com.example.watchhiking.watchkitapp` | Apple Watch App |

实际命名以 Xcode 工程和 Apple Developer 后台创建结果为准。

### Capabilities 初始清单

| Capability / 框架 | 首版用途 | 是否阻断发布 | 备注 |
| --- | --- | --- | --- |
| Core Location | Watch 行进中定位、轨迹点、偏航检测 | 是 | 没有定位无法完成核心导航和记录 |
| HealthKit / HKWorkoutSession | 徒步运动会话、心率和运动数据引用 | 否 | 无授权时降级为地图导航和轨迹记录 |
| WatchConnectivity | iPhone 下发路线、Watch 回传轨迹和事件 | 是 | 首版端协同主通道 |
| UserNotifications | 偏航、转向点、低电量等提醒 | 否 | 权限缺失时保留界面状态和触觉/前台提醒 |
| MapKit | iPhone / Watch 地图展示 | 是 | Watch 固定使用标准底图，不承诺图层切换 |

注意：

1. HealthKit 数据不能作为商业广告、营销或无关用途的数据来源。
2. 定位和健康数据属于敏感数据，权限弹窗、隐私政策和 App Store 隐私问卷必须一致。
3. WatchConnectivity 的可靠传输策略仍需要真机验证，不能只依赖模拟器结论。

## 隐私、权限和数据合规

### 首版可能涉及的数据

| 数据 | 来源 | 用途 | 是否敏感 | 是否需要明确告知 |
| --- | --- | --- | --- | --- |
| 位置轨迹 | Core Location | 徒步记录、偏航检测、复盘 | 是 | 是 |
| 路线 GPX | 用户导入或远端路线 | 路线导航、同步到 Watch | 可能是 | 是 |
| 心率 / 运动数据 | HealthKit | 复盘和运动摘要 | 是 | 是 |
| 设备连接状态 | WatchConnectivity | 判断 Watch 是否可同步 | 否 | 视隐私问卷要求填写 |
| App 诊断日志 | App 本地日志 | 排查同步、定位和会话问题 | 可能是 | 是，尤其不要上传精确位置日志 |

### 权限文案要求

必须在 `Info.plist` 中提供清晰的 purpose strings。文案应说明“为什么需要”，不要只写“用于提供更好体验”。

建议方向：

| 权限 | 文案应说明 |
| --- | --- |
| 定位 | 用于徒步中记录轨迹、显示当前位置、判断是否偏离计划路线 |
| HealthKit 读取 | 用于在复盘中展示心率等运动数据 |
| HealthKit 写入 / Workout | 用于记录徒步运动会话 |
| 通知 | 用于提醒偏航、接近关键转向点或低电量状态 |

### 隐私政策

上架前需要准备可公开访问的隐私政策 URL。

隐私政策至少覆盖：

1. 收集哪些位置、路线、运动、健康和诊断数据。
2. 数据保存在本地、iCloud、服务端或第三方服务的哪些位置。
3. 数据是否用于账号、统计、问题诊断、路线服务或客服支持。
4. 数据是否共享给第三方。
5. 用户如何删除路线、轨迹、账号和健康数据授权。
6. 未成年人或家庭共享场景是否支持，以及不支持时如何说明。

## 按 slice 开发时的发布准备

| 开发阶段 | 同步准备的发布事项 |
| --- | --- |
| Phase 0 / Slice 0：工程骨架 | 建立 Bundle ID、签名、Capabilities、权限文案草稿、真机安装路径 |
| Slice 1：路线导入和远端路线 | 明确远端路线来源、GPX 文件处理、路线数据保存和隐私说明 |
| Slice 2：路线下发 Watch | 真机验证 WatchConnectivity 在线、断连、重连和失败重试 |
| Slice 3：会话和轨迹记录 | 真机验证定位、HKWorkoutSession、后台、锁屏、暂停/恢复 |
| Slice 4：地图和偏航 | 真机验证 MapKit、路线绘制性能、偏航误报、触觉提醒 |
| Slice 5：轨迹回传 | 验证 chunk 去重、缺口补传、结束后同步和本地保留策略 |
| Slice 6：iPhone 复盘和导出 | 准备 App Store 截图、审核演示路线、隐私问卷最终版 |

## 测试与真机验证

### 必须覆盖的测试

| 测试类型 | 最小要求 |
| --- | --- |
| 单元测试 | GPX 解析、路线距离、checksum、路线简化、偏航状态机、同步封包 |
| 集成测试 | iPhone 路线安装、Watch route payload 校验、track/event chunk 去重 |
| 模拟器验证 | 基础 UI、权限缺失状态、导入失败、空数据、同步状态展示 |
| 真机验证 | Apple Watch 定位、地图、HKWorkoutSession、WatchConnectivity、触觉、电量 |
| 审核路径验证 | 新用户从授权、导入/选择路线、同步、开始、结束、复盘的完整流程 |

### 真机待验证清单

以下不能写成已实测事实，除非完成设备、系统版本、路线和日志记录：

1. WatchConnectivity 在锁屏、后台、断连、重连下的传输延迟和可靠性。
2. Watch 长时间 Core Location 采样的精度和耗电。
3. HKWorkoutSession 与定位、地图刷新并行时的稳定性。
4. Watch MapKit 长路线、多点轨迹和频繁刷新下的性能。
5. 偏航阈值在真实山路、林地、城市公园和弱 GPS 场景下的误报率。
6. 低电量模式下采样降级后轨迹是否仍可用于复盘。

## App Store Connect 建档

准备步骤：

1. 在 App Store Connect 创建新 App。
2. 选择平台为 iOS，并关联主 iPhone App Bundle ID；Watch App 随 iOS App 构建提交。
3. 填写 App 名称、默认语言、SKU、Bundle ID。
4. 配置分类，建议先按 Health & Fitness / Navigation 方向评估，最终以产品定位和 App Store 分类规则为准。
5. 填写年龄分级问卷。
6. 填写 App 隐私问卷，确保与代码、权限、隐私政策一致。
7. 上传截图、描述、关键词、支持 URL、隐私政策 URL。
8. 准备审核备注、测试账号或可复现路线数据。

### 截图和元数据

首版截图需要真实表达产品闭环：

1. iPhone 路线列表或路线详情。
2. iPhone GPX 导入或路线预览。
3. Apple Watch 地图页，显示计划路线和当前位置。
4. Apple Watch 偏航或行进中状态。
5. iPhone 复盘页，显示计划路线与实际轨迹。

不要在截图或描述中承诺首版不做的能力，例如离线地图、专业等高线、多平台、团队共享、AI 推荐、返航规划或救援能力。

## TestFlight 内测

推荐顺序：

1. 先上传内部测试构建，只开放给开发、产品和 QA。
2. 内部测试通过后再开外部 TestFlight。
3. 外部测试前准备 Beta App Review 需要的说明和测试路径。
4. 每个 build 记录测试范围、已知问题、设备型号、watchOS / iOS 版本。
5. 对涉及路线、轨迹、健康数据的问题，不要只收截图；需要同步导出诊断日志和会话 ID。

内测重点：

1. 新用户授权路径是否清楚。
2. 没有 HealthKit 授权时是否仍能记录轨迹。
3. Watch 与 iPhone 断连时是否不丢数据。
4. 结束后回传失败能否补传。
5. 隐私政策、权限弹窗和 App 隐私问卷是否一致。

## 提交 App Review 前检查

| 检查项 | 要求 |
| --- | --- |
| 功能完整性 | 审核员不依赖特殊硬件路线或内部服务，也能理解核心流程 |
| 登录 / 服务端 | 如果需要账号或远端路线服务，提供测试账号、测试路线和服务可用性说明 |
| 权限弹窗 | 定位、健康、通知文案和实际用途一致 |
| HealthKit | 健康数据用途清晰，不用于无关营销或广告 |
| 位置数据 | 说明用于徒步记录、导航和复盘；后台使用需要与功能匹配 |
| Watch App | iPhone 与 Watch 体验都能启动和完成关键路径 |
| 崩溃和空状态 | 无路线、无网络、Watch 不在线、权限缺失不崩溃 |
| 隐私问卷 | 与代码、服务端、第三方 SDK、隐私政策一致 |
| 截图描述 | 不承诺未实现或未验证能力 |

## 审核说明建议

App Review 备注建议包含：

1. App 是 iPhone + Apple Watch 徒步导航和轨迹记录 App。
2. iPhone 用于路线准备、GPX 导入、同步和复盘。
3. Apple Watch 用于行进中地图、路线跟随、轨迹记录、偏航提醒和结束回传。
4. HealthKit 权限用于徒步 workout 和运动数据复盘；拒绝授权时仍可记录位置轨迹。
5. 定位权限用于记录轨迹、显示当前位置和判断偏航。
6. 可供审核使用的测试路线、GPX 文件或远端路线编号。
7. 如果某些功能需要 Apple Watch 真机，明确说明测试步骤。

## 发布与发布后维护

### 发布策略

建议首版采用分阶段发布或小范围发布：

1. 先发布到较小地区或采用 phased release。
2. 观察崩溃、同步失败、定位异常和用户反馈。
3. 对 WatchConnectivity、定位和 HealthKit 问题建立可追踪的诊断日志。
4. 不在首版发布页宣称救援、安全保障或专业户外导航能力。

### 发布后监控

需要关注：

1. 崩溃率和 Watch App 启动失败。
2. 路线同步失败率。
3. 会话结束后轨迹未完整回传比例。
4. 定位权限拒绝率和 HealthKit 授权拒绝率。
5. 偏航提醒投诉和误报反馈。
6. 电量消耗反馈。
7. 审核反馈、隐私问卷变化和 Apple 政策更新。

## 官方参考

以下页面在 2026-06-06 查阅。Apple 文档和 App Store Connect 表单会随系统、SDK 和政策更新；正式提交前需要重新核对。

1. [Apple Developer Program Enrollment](https://developer.apple.com/programs/enroll/)
2. [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
3. [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
4. [Certificates, Identifiers & Profiles](https://developer.apple.com/help/account/)
5. [Uploading apps to App Store Connect](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
6. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
7. [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
8. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
9. [HealthKit - Apple Developer Documentation](https://developer.apple.com/documentation/healthkit)
10. [HKWorkoutSession - Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
11. [Core Location - Apple Developer Documentation](https://developer.apple.com/documentation/corelocation)
12. [Requesting authorization to use location services](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
13. [WatchConnectivity - Apple Developer Documentation](https://developer.apple.com/documentation/watchconnectivity)
14. [MapKit - Apple Developer Documentation](https://developer.apple.com/documentation/mapkit)
15. [User Notifications - Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications)

## 相关文档

1. [WatchOS 徒步 App MVP 产品定义 v0.1](./watchos-hiking-app-product-v0.1.md)
2. [WatchOS 徒步 App MVP 开发切分 v0.1](./mvp-development-slices-v0.1.md)
3. [WatchOS 能力使用取舍 v0.1](./watchos-capability-decisions-v0.1.md)
4. [WatchOS 徒步 App 开发提示词与技术实施计划 v0.1](./watchos-development-prompt-implementation-plan-v0.1.md)
5. [iPhone App + Apple Watch App 上架准备文档 v0.1](./iphone-watchos-app-store-submission-v0.1.md)
6. [当前 UI 与操作逻辑对齐说明 v0.1](./current-ui-operation-alignment-v0.1.md)
7. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
8. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)
