# watch_md

面向徒步户外 App 的手表端产品、技术与设备支持研究文档库。

当前重点是验证一个以 Apple Watch 为首发平台的徒步导航 MVP：iPhone 负责远端路线列表、路线导入、路线管理、路线同步和复盘，Apple Watch 负责腕上地图、路线跟随、偏航提醒、轨迹记录和结束后回传。

仓库同时保留华为手表、Wear OS、Garmin、Suunto、COROS 等平台的开发支持调研，用于后续平台路线图判断。

## App 工程

- [Apple Watch 徒步 App 工程骨架](./watch-hiking-app/README.md)
- [华为 WATCH / GT / 手机同步验证工程骨架](./huawei-validation/README.md)

当前工程目录为 `watch-hiking-app/`。已建立 Swift Package 核心包、iPhone/Watch SwiftUI 源码骨架、GPX fixture、Xcode app target 和单元测试；路线导入、WatchConnectivity 路线下发入口、Watch 路线接收安装入口、Watch 会话记录、地图偏航 MVP、会话/轨迹回传核心模型、Watch 上传入口和 iPhone 接收入口已落代码，并已用 iPhone 模拟器 + 配套 Watch 模拟器验证路线下发到 Watch 落盘闭环、Watch 会话回传到 iPhone `ReceivedSessions` 落盘闭环。真实服务端路线搜索/详情接口、签名安装闭环、WatchConnectivity 断连/后台/锁屏/重连表现、Core Location / HKWorkoutSession / MapKit 长时间表现仍需真机验证。

## 当前结论

1. MVP 优先选择 Apple Watch / watchOS，因为第三方开发能力、HealthKit、WatchConnectivity、后台运动和手机-手表协同路径最明确。
2. 徒步场景优先级是路线可靠、定位不断、偏航能提醒、轨迹不丢、结束能同步。
3. 第一版暂不做 Android、Wear OS、华为手表、路线社区、复杂路线编辑、多地图源、专业等高线地图和订阅体系。
4. iPhone 可通过远端接口获取官方/运营维护的路线列表，并下载指定路线详情后同步到 Watch；它不是路线社区、附近路线发现或 AI 推荐。
5. Watch 端按用户已知路线编号、短码或精确名称远程获取指定 GPX 路线，作为 MVP 后续计划；它不是路线推荐、附近路线发现或路线社区。
6. 华为手表具备后续验证价值，当前优先验证 WATCH 数字系列和 WATCH GT 系列；仍要按手机生态、系统版本、地区、机型和上架路径逐项确认。

## 文档索引

### 总体调研

- [手表设备支持情况与户外 App 开发调研](./watch-outdoor-app-device-support-research.md)

### WatchOS MVP 规格

- [WatchOS 徒步 App MVP 产品定义](./docs/watchos-hiking-app-product-v0.1.md)
- [WatchOS 徒步 App MVP 开发切分](./docs/mvp-development-slices-v0.1.md)
- [WatchOS 能力使用取舍](./docs/watchos-capability-decisions-v0.1.md)
- [WatchOS 徒步 App 开发提示词与技术实施计划](./docs/watchos-development-prompt-implementation-plan-v0.1.md)
- [WatchOS 徒步 App 开发与上架流程](./docs/watchos-development-release-flow-v0.1.md)
- [iPhone App + Apple Watch App 上架准备文档](./docs/iphone-watchos-app-store-submission-v0.1.md)
- [WatchOS 徒步 App 产品原型 v0.1](./docs/prototypes/watchos-product-prototype-v0.1.html)
- [iPhone 徒步 App 产品原型 v0.1](./docs/prototypes/iphone-product-prototype-v0.1.html)
- [当前 UI 与操作逻辑对齐说明](./docs/current-ui-operation-alignment-v0.1.md)

### 核心功能规格

- [徒步路线与会话数据模型](./docs/hiking-data-model-v0.1.md)
- [WatchConnectivity 同步协议](./docs/watchconnectivity-sync-protocol-v0.1.md)
- [iOS / watchOS 操作与数据联动规格](./docs/ios-watchos-operation-data-linkage-v0.1.md)
- [WatchOS 徒步地图页规格](./docs/watchos-map-page-spec-v0.1.md)
- [偏航检测规则](./docs/off-route-detection-spec-v0.1.md)
- [徒步会话完整流程](./docs/hiking-session-flow-v0.1.md)
- [低电量与长时间徒步策略](./docs/battery-long-hike-strategy-v0.1.md)
- [iOS 定位耗电分析、最终目标与优化方案](./docs/ios-location-power-analysis-v0.1.md)
- [iPhone 路线详情与复盘页面规格](./docs/iphone-route-review-spec-v0.1.md)

### 华为手表

- [华为手表开发环境搭建记录](./docs/huawei-watch-dev-env.md)
- [华为各类型手表支持情况调研](./docs/huawei-watch-support-research-v0.1.md)
- [华为 Wear Engine / Health Kit / AppGallery 申请与 SDK 接入说明](./docs/huawei-sdk-application-integration-v0.1.md)
- [华为 WATCH 系列徒步 App MVP 规格](./docs/huawei-watch-series-mvp-spec-v0.1.md)
- [华为 WATCH GT 系列徒步 App MVP 规格](./docs/huawei-gt-series-mvp-spec-v0.1.md)
- [华为真实工程迁移与真机验证清单](./huawei-validation/real-project-setup-checklist.md)
- [HarmonyOS / Huawei watch 开发环境自检脚本](./scripts/check-harmonyos-watch-env.sh)

## 建议阅读顺序

1. 先读总体调研，理解为什么首发 Apple Watch。
2. 再读产品定义，明确端分工、目标用户和 MVP 范围。
3. 然后读开发切分，按 slice 推进实现。
4. 开始编码前读数据模型、同步协议、iOS / watchOS 操作与数据联动、地图页、偏航检测和完整会话流程。
5. 准备真机测试、TestFlight 或 App Store 上架前，读开发与上架流程，以及 iPhone App + Apple Watch App 上架准备文档，确认账号、签名、权限、隐私、审核和截图材料。
6. 修改 UI、按钮、页面顺序、同步状态或会话操作前，先读当前 UI 与操作逻辑对齐说明，区分已落代码、临时实现和目标规格。
7. 需要验证华为路径时，阅读华为开发环境文档并运行自检脚本。

## 华为开发环境自检

在仓库根目录运行：

```sh
bash scripts/check-harmonyos-watch-env.sh
```

脚本会检查 DevEco Studio、HarmonyOS SDK、WearEngine、liteWearable 预览器、Node、ohpm、hdc 和 Java。

## 文档维护规则

- 新规格文档放在 `docs/` 下，文件名建议使用 `主题-v0.1.md` 形式。
- 文档内容尽量保持中文，术语可以保留英文原名，例如 `WatchConnectivity`、`HealthKit`、`GPX`。
- 涉及平台能力、SDK、系统限制和上架规则时，应标注调研日期；如果结论依赖最新政策或文档，需要重新查证。
- 修改 MVP 范围时，同步更新产品定义、开发切分和实施计划，避免文档之间互相矛盾。
