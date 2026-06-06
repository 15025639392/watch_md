# iPhone App + Apple Watch App 上架准备文档 v0.1

更新日期：2026-06-07

## 文档目的

本文用于指导当前徒步 App 后续以“iPhone App + Apple Watch App”形态提交 TestFlight 和 App Store 审核。

本文不改变 MVP 范围。首版仍以 iPhone 负责 GPX 导入、路线详情、路线同步和运动后复盘，Apple Watch 负责腕上地图、路线跟随、偏航提醒、轨迹记录、暂停/继续/结束和结束后回传。

本文涉及 App Store Connect、TestFlight、App Review、隐私问卷、watchOS 截图和 Apple Developer Program 等高变动信息。以下内容基于 2026-06-07 查阅的 Apple 官方文档；正式提交前需要再次核对 Apple Developer、App Store Connect、Xcode 和当前 App Review Guidelines。

## 上架形态

首版按 iOS App 附带 Apple Watch App 发布，不按 watch-only App 发布。

原因：

1. iPhone 是路线导入、路线管理、路线同步和复盘中心。
2. Apple Watch 是行进中导航、记录和提醒终端。
3. 审核材料、隐私说明、截图和测试路径需要同时覆盖 iPhone 与 Watch。
4. Apple 官方 App Store Connect 文档说明，为 iPhone 和 Apple Watch 提供 App 时，应在 Xcode 中创建包含 watchOS counterpart 的 iOS App，并从同一个 Xcode project 上传到 App Store Connect。

## 总体流程

```txt
Apple Developer Program 准备
  -> Bundle ID、签名和 Capabilities 配置
  -> iPhone / Watch 真机闭环验证
  -> 隐私政策、权限文案和 App 隐私问卷整理
  -> App Store Connect 创建 iOS App 记录
  -> 上传包含 Watch App 的 iOS build
  -> 配置 iPhone 与 Apple Watch 截图、描述和审核说明
  -> TestFlight 内测
  -> 外部 TestFlight / Beta App Review
  -> App Review 正式提交
  -> 分阶段发布和发布后监控
```

## 发布前必备清单

| 类别 | 必备项 | 当前项目注意事项 |
| --- | --- | --- |
| 开发者账号 | Apple Developer Program | 需要能访问 Certificates, Identifiers & Profiles、App Store Connect 和 TestFlight |
| App Store Connect 权限 | Account Holder、Admin、App Manager 或相关角色 | watchOS app 信息、截图和构建提交需要相应角色权限 |
| Xcode 工程 | iOS App target + Watch App target | 当前优先延续 `watch-hiking-app/`，不要新建割裂工程 |
| Bundle ID | iPhone App、Watch App 相关标识 | Bundle ID 必须与 Xcode project、Apple Developer 后台和 App Store Connect 一致 |
| 签名 | Development / Distribution signing | 建议先用自动签名跑通，再按团队需要固化 |
| Capabilities | Location、HealthKit、WatchConnectivity、Notifications、MapKit 相关能力 | 是否启用以实际代码和权限用途为准 |
| 真机设备 | iPhone + Apple Watch | 长时间定位、Workout、后台、锁屏、断连重连不能只依赖模拟器 |
| 隐私政策 | 可公开访问的 Privacy Policy URL | iOS App 必填，且内容必须覆盖位置、路线、健康和诊断数据 |
| App 隐私问卷 | 数据类型、用途、是否追踪、是否关联用户 | 必须与代码、服务端、第三方 SDK 和隐私政策一致 |
| 素材 | App 图标、iPhone 截图、Apple Watch 截图 | iPhone + Watch 形态需要同时准备对应截图 |
| 审核说明 | 测试路线、测试步骤、账号或 GPX 文件说明 | 审核员需要能理解 iPhone 到 Watch 的完整闭环 |

## App Store Connect 建档

### 创建 App 记录

操作方向：

1. 在 App Store Connect 的 Apps 中新建 App。
2. 平台选择 iOS。
3. 关联主 iPhone App Bundle ID。
4. 填写 App 名称、默认语言、SKU、Bundle ID。
5. 创建后在 Apple Watch 相关截图区域补充 Watch 信息和截图。

注意：

1. Bundle ID 在上传 build 后不可随意更换，应在上架前定好命名。
2. App 名称、SKU、主语言、分类、年龄分级和隐私政策 URL 要在产品页准备阶段统一确认。
3. 如果首版不做付费、订阅或内购，不要提前配置复杂商业化入口。

### 产品页信息

| 信息项 | 首版建议 |
| --- | --- |
| App 名称 | 使用稳定产品名，不在标题里承诺“专业救援”或“绝对安全” |
| 副标题 | 突出徒步路线、腕上导航或轨迹记录，保持克制 |
| 分类 | 优先评估 Health & Fitness、Navigation，最终按实际定位选择 |
| 描述 | 说明 iPhone 负责路线准备与复盘，Apple Watch 负责行进中导航与记录 |
| 关键词 | 徒步、路线、轨迹、Apple Watch、GPX、导航等，避免误导性词汇 |
| 支持 URL | 提供用户反馈、问题排查和联系方式 |
| 隐私政策 URL | 覆盖位置、路线、运动健康、诊断日志和删除方式 |

## 截图和素材

### iPhone 截图

建议覆盖：

1. 路线列表或路线详情。
2. GPX 导入或路线预览。
3. 同步到 Apple Watch 的状态。
4. 运动后复盘，包括计划路线、实际轨迹和基础统计。

### Apple Watch 截图

建议覆盖：

1. 腕上地图页，显示计划路线和当前位置。
2. 行进中状态，包括距离、时间、偏航状态或同步状态。
3. 暂停 / 继续 / 结束流程。
4. 结束后回传或等待同步状态。

### 素材边界

不要在截图、描述或宣传文案中承诺首版不做的能力：

1. 离线等高线地图。
2. 多平台同步。
3. 路线社区。
4. AI 推荐路线。
5. 专业救援或生命安全保障。
6. 未经真机验证的超长续航能力。

## 隐私与权限材料

### 首版数据清单

| 数据类型 | 来源 | 用途 | 上架说明重点 |
| --- | --- | --- | --- |
| 位置轨迹 | Core Location | 记录徒步轨迹、显示当前位置、判断偏航、复盘 | 需要在权限文案、隐私政策和 App 隐私问卷中一致说明 |
| 路线 GPX | 用户导入或远端路线 | 路线导航、同步到 Watch、复盘对比 | 如果包含用户活动位置，需要按敏感数据谨慎描述 |
| Workout / 运动数据 | HealthKit / HKWorkoutSession | 记录徒步运动、复盘展示 | 无 HealthKit 授权时应有降级路径 |
| 心率等健康数据 | HealthKit | 复盘展示或运动摘要 | 如未实现，不要在隐私问卷或宣传中写成已支持 |
| Watch 连接状态 | WatchConnectivity | 路线下发、轨迹回传、失败重试 | 说明用于端间同步和状态展示 |
| 诊断日志 | App 本地或调试导出 | 排查同步、定位和崩溃问题 | 不应默认上传精确位置日志，除非隐私政策明确覆盖 |

### 权限文案

| 权限 | 文案应说明 |
| --- | --- |
| 定位 | 用于徒步中显示当前位置、记录轨迹、判断是否偏离计划路线 |
| HealthKit 读取 | 用于在复盘中展示授权的运动或健康数据 |
| HealthKit 写入 / Workout | 用于记录徒步运动会话 |
| 通知 | 用于提醒偏航、接近关键点或低电量状态 |

文案原则：

1. 说明具体用途，不写泛泛的“改善体验”。
2. 权限用途必须与实际代码一致。
3. 如果用户拒绝 HealthKit 或通知授权，核心路线与轨迹流程应尽量降级可用。
4. 后台定位必须与徒步记录和行进中导航直接相关。

## TestFlight 流程

### 内部测试

内部测试目标是先让开发、产品和 QA 在真实 iPhone + Apple Watch 上跑通闭环。

最小测试路径：

1. 新安装 App。
2. 授权定位、通知、HealthKit。
3. iPhone 导入或选择一条测试 GPX 路线。
4. 同步路线到 Apple Watch。
5. Watch 开始徒步会话。
6. 查看地图、当前位置、路线和偏航状态。
7. 暂停、继续、结束。
8. Watch 回传轨迹和事件。
9. iPhone 查看复盘。

### 外部测试

外部 TestFlight 前需要准备：

1. Beta App Description。
2. 测试重点说明。
3. 反馈邮箱。
4. 可公开给测试员使用的测试路线或 GPX 文件。
5. 已知问题清单。
6. Beta App Review 说明。

外部测试重点：

1. 不同 Apple Watch 型号和 watchOS 版本。
2. 城市公园、山路、弱 GPS 区域等不同路线环境。
3. Watch 与 iPhone 断连、重连、锁屏和后台。
4. 长时间徒步后的电量、定位精度和轨迹完整性。

## App Review 提交材料

### 审核备注建议

审核备注应直接说明：

1. 本 App 是 iPhone + Apple Watch 徒步路线导航和轨迹记录 App。
2. iPhone 负责 GPX 导入、路线详情、同步到 Watch 和运动后复盘。
3. Apple Watch 负责行进中地图、路线跟随、偏航提醒、轨迹记录和结束后回传。
4. 定位权限用于显示当前位置、记录轨迹和偏航判断。
5. HealthKit 权限用于徒步 workout 和授权后的运动数据复盘；拒绝后仍可使用基础路线和轨迹能力。
6. 通知用于偏航、关键状态和低电量提醒。
7. 审核可使用的测试 GPX、路线编号或测试账号。
8. 如果需要 Apple Watch 真机才能完整验证，给出配对、同步和开始徒步的具体步骤。

### 提交前检查

| 检查项 | 要求 |
| --- | --- |
| 构建 | iPhone App 和 Watch App 都能从同一上传构建安装 |
| 启动 | iPhone 和 Watch 首次启动无崩溃 |
| 权限 | 定位、HealthKit、通知弹窗文案准确 |
| 路线 | 无路线、GPX 失败、远端失败时有空态和错误态 |
| 同步 | Watch 不在线、断连、重连、失败重试有明确状态 |
| 会话 | 开始、暂停、继续、结束和回传路径完整 |
| 数据 | 轨迹、事件、复盘数据不丢失或可补传 |
| 隐私 | 隐私政策、App 隐私问卷、权限文案和实际代码一致 |
| 描述 | 不承诺未实现、未验证或高风险安全能力 |

## 发布策略

首版建议不要全量激进发布。

推荐：

1. 先用 TestFlight 跑完真实户外测试。
2. 首个 App Store 版本采用手动发布或 phased release。
3. 发布后重点观察 Watch 崩溃、同步失败、定位异常、耗电反馈和用户隐私授权拒绝率。
4. 对严重影响轨迹完整性的问题建立热修复优先级。

## 发布后监控

需要持续记录：

1. iPhone App 崩溃率。
2. Watch App 崩溃率。
3. 路线同步失败率。
4. 会话结束后回传失败率。
5. 轨迹点缺失或复盘不完整反馈。
6. 后台定位和电量投诉。
7. 偏航误报和漏报反馈。
8. App Review、隐私问卷和 Apple 政策变化。

## 相关文档

1. [WatchOS 徒步 App 开发与上架流程 v0.1](./watchos-development-release-flow-v0.1.md)
2. [WatchOS 徒步 App MVP 产品定义 v0.1](./watchos-hiking-app-product-v0.1.md)
3. [WatchOS 徒步 App MVP 开发切分 v0.1](./mvp-development-slices-v0.1.md)
4. [WatchOS 能力使用取舍 v0.1](./watchos-capability-decisions-v0.1.md)
5. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
6. [iOS / watchOS 操作与数据联动规格 v0.1](./ios-watchos-operation-data-linkage-v0.1.md)
7. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)
8. [当前 UI 与操作逻辑对齐说明 v0.1](./current-ui-operation-alignment-v0.1.md)

## 官方参考

以下页面在 2026-06-07 查阅。正式提交前需要重新核对。

1. [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/)
2. [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
3. [Add watchOS app information](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-watchos-app-information/)
4. [Add platforms / Universal Purchase support](https://developer.apple.com/support/universal-purchase)
5. [App information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/)
6. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
7. [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
8. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
