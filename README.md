# watch_md

面向徒步户外 App 的手表端产品、技术与设备支持研究文档库。

当前重点是验证一个以 Apple Watch 为首发平台的徒步导航 MVP：iPhone 负责路线导入、路线管理、路线同步和复盘，Apple Watch 负责腕上地图、路线跟随、偏航提醒、轨迹记录和结束后回传。

仓库同时保留华为手表、Wear OS、Garmin、Suunto、COROS 等平台的开发支持调研，用于后续平台路线图判断。

## 当前结论

1. MVP 优先选择 Apple Watch / watchOS，因为第三方开发能力、HealthKit、WatchConnectivity、后台运动和手机-手表协同路径最明确。
2. 徒步场景优先级是路线可靠、定位不断、偏航能提醒、轨迹不丢、结束能同步。
3. 第一版暂不做 Android、Wear OS、华为手表、路线社区、复杂路线编辑、多地图源、专业等高线地图和订阅体系。
4. Watch 端按用户已知路线编号、短码或精确名称远程获取指定 GPX 路线，作为 MVP 后续计划；它不是路线推荐、附近路线发现或路线社区。
5. 华为手表具备后续验证价值，但要按手机生态、系统版本、地区、机型和上架路径逐项确认。

## 文档索引

### 总体调研

- [手表设备支持情况与户外 App 开发调研](./watch-outdoor-app-device-support-research.md)

### WatchOS MVP 规格

- [WatchOS 徒步 App MVP 产品定义](./docs/watchos-hiking-app-product-v0.1.md)
- [WatchOS 徒步 App MVP 开发切分](./docs/mvp-development-slices-v0.1.md)
- [WatchOS 徒步 App 开发提示词与技术实施计划](./docs/watchos-development-prompt-implementation-plan-v0.1.md)
- [WatchOS 徒步 App 产品原型 v0.1](./docs/prototypes/watchos-product-prototype-v0.1.html)

### 核心功能规格

- [徒步路线与会话数据模型](./docs/hiking-data-model-v0.1.md)
- [WatchConnectivity 同步协议](./docs/watchconnectivity-sync-protocol-v0.1.md)
- [WatchOS 徒步地图页规格](./docs/watchos-map-page-spec-v0.1.md)
- [偏航检测规则](./docs/off-route-detection-spec-v0.1.md)
- [徒步会话完整流程](./docs/hiking-session-flow-v0.1.md)
- [低电量与长时间徒步策略](./docs/battery-long-hike-strategy-v0.1.md)
- [iPhone 路线详情与复盘页面规格](./docs/iphone-route-review-spec-v0.1.md)

### 华为手表

- [华为手表开发环境搭建记录](./docs/huawei-watch-dev-env.md)
- [HarmonyOS / Huawei watch 开发环境自检脚本](./scripts/check-harmonyos-watch-env.sh)

## 建议阅读顺序

1. 先读总体调研，理解为什么首发 Apple Watch。
2. 再读产品定义，明确端分工、目标用户和 MVP 范围。
3. 然后读开发切分，按 slice 推进实现。
4. 开始编码前读数据模型、同步协议、地图页、偏航检测和完整会话流程。
5. 需要验证华为路径时，阅读华为开发环境文档并运行自检脚本。

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
