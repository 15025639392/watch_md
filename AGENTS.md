# AGENTS.md

本文件给 Codex 和其他编码代理使用，说明在本仓库中应该如何工作。

## 项目性质

这是一个户外徒步手表 App 的产品与技术规格文档仓库，同时已经包含 Apple Watch / iPhone MVP 工程骨架 `watch-hiking-app/`。规格文档仍是产品和架构输入，工程目录承载当前已落代码、测试和后续实现。

当前主线是 Apple Watch / watchOS 徒步导航 MVP：

- iPhone 负责 GPX 导入、路线详情、路线同步和运动后复盘。
- Apple Watch 负责腕上地图、路线跟随、偏航提醒、轨迹记录、暂停/继续/结束和结束后回传。
- 第一版重点完成端到端闭环，不优先扩展 Android、Wear OS、华为手表或路线社区。

## 工作优先级

1. 保持 MVP 范围清晰，优先服务 Apple Watch 首发闭环。
2. 保证文档之间一致，尤其是产品定义、开发切分、数据模型、同步协议、地图页、偏航检测和会话流程。
3. 对平台能力、SDK、政策、设备支持、上架限制等容易变化的信息，不要只凭记忆；需要时查证官方文档并写明日期。
4. 不要把调研性结论写成已实测事实。没有实机验证时，明确标注“需要验证”。

## 重要文档

- `watch-outdoor-app-device-support-research.md`：跨平台设备支持与产品路线判断。
- `docs/watchos-hiking-app-product-v0.1.md`：MVP 产品定义。
- `docs/mvp-development-slices-v0.1.md`：MVP 开发切片。
- `docs/watchos-capability-decisions-v0.1.md`：watchOS 能力使用、不使用和延期评估的取舍说明。
- `docs/watchos-development-prompt-implementation-plan-v0.1.md`：可复制给 Codex 的开发提示词与实施计划。
- `docs/watchos-development-release-flow-v0.1.md`：开发准备、真机验证、TestFlight、App Store 上架和发布后维护流程。
- `docs/current-ui-operation-alignment-v0.1.md`：当前 UI、操作入口、临时实现和目标规格边界，避免后续 AI 误解当前代码状态。
- `docs/hiking-data-model-v0.1.md`：路线、会话、轨迹、事件和同步对象模型。
- `docs/watchconnectivity-sync-protocol-v0.1.md`：iPhone 与 Apple Watch 的同步协议。
- `docs/ios-watchos-operation-data-linkage-v0.1.md`：iOS / watchOS 操作分工、页面动作、数据归属和跨端联动。
- `docs/watchos-map-page-spec-v0.1.md`：Watch 地图页规格。
- `docs/off-route-detection-spec-v0.1.md`：偏航检测规则。
- `docs/hiking-session-flow-v0.1.md`：完整徒步会话流程。
- `docs/battery-long-hike-strategy-v0.1.md`：低电量和长时间徒步策略。
- `docs/iphone-route-review-spec-v0.1.md`：iPhone 路线详情与复盘规格。
- `docs/huawei-watch-dev-env.md`：华为手表开发环境记录。

## 文档写作规则

- 默认使用中文。
- 文件名保持小写英文、连字符和版本号风格，例如 `watchos-map-page-spec-v0.1.md`。
- 新增规格文档放在 `docs/`。
- 顶层只放项目入口、总体调研、代理说明和必要脚本目录。
- Markdown 表格用于能力对比、字段定义和状态矩阵。
- 对流程和状态机优先使用简洁的文本图或分阶段说明。
- 不引入没有来源或没有验证路径的平台结论。
- 如果更新某个核心概念，需要搜索并同步其他文档中的引用。

## 平台事实与查证

以下内容属于高变动信息，修改时应重新查证：

- Apple、Huawei、Google、Garmin、Suunto、COROS 的 SDK 能力。
- HealthKit、WatchConnectivity、WorkoutKit、MapKit、Core Location 等 API 限制。
- HarmonyOS、Wear Engine、Health Kit、DevEco Studio、AppGallery 或 HMS 的版本和政策。
- 手表机型是否支持第三方 App、离线地图、传感器访问、后台运行和长时间定位。
- App Store、AppGallery、Google Play 或 Garmin Connect IQ 的上架要求。

优先引用官方文档、开发者文档或厂商支持页面。调研类文档应保留日期。

## 编辑注意事项

- 不要删除用户已有文档，除非用户明确要求。
- 不要把 `docs/watchos-development-prompt-implementation-plan-v0.1.md` 改成泛泛提示词；它应保持可直接用于开发实施。
- 修改 UI、按钮、页面顺序、同步状态或会话操作时，先读并同步 `docs/current-ui-operation-alignment-v0.1.md`。
- 不要把 Apple Watch MVP 范围悄悄扩大到多平台实现。
- 不要在文档里承诺未验证的华为、Wear OS 或专业户外品牌能力。
- 修改范围、模型字段、同步协议或偏航规则时，检查相关文档是否需要同步调整。

## 可用脚本

华为手表开发环境自检：

```sh
bash scripts/check-harmonyos-watch-env.sh
```

该脚本只用于检查本机 DevEco Studio、HarmonyOS SDK、WearEngine、liteWearable 预览器、Node、ohpm、hdc 和 Java 状态。

## 给 Codex 的默认行为

- 每次处理用户请求时，都要自动判断本次工作是否影响 Markdown 文档维护。只要涉及项目范围、MVP 定义、平台结论、规格结构、文档增删改、文件命名、目录组织、开发提示词或代理工作规则，就主动检查并维护相关 Markdown；用户不需要明确提出“同步 README”“更新 AGENTS”或“检查相关文档”。
- 如果用户要求“补文档”“写提示词”“整理规划”，先读相关现有文档再改。
- 如果用户新增、删除、归档或更新 Markdown 文档，自动完成文档维护流程：判断文件位置和命名，搜索现有引用，更新 `README.md` 文档索引，必要时更新 `AGENTS.md`，并检查相关规格文档是否存在范围、术语、模型或流程冲突。用户不需要额外说明这些维护步骤。
- 如果用户要求“实现 App”，先检查 `watch-hiking-app/` 当前工程状态；除非用户明确要求新建独立工程，否则优先在现有工程内延续实现。
- 如果用户要求“查最新支持情况”，必须联网查证，不要沿用旧结论。
- 如果用户要求“评审”，优先找文档矛盾、范围膨胀、技术不可行、缺少验证路径和高风险假设。
