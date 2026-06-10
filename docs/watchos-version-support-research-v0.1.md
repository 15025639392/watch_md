# watchOS 版本支持情况调研 v0.1

更新日期：2026-06-10

## 文档目的

本文重新梳理 watchOS 各主要版本、Apple Watch 机型覆盖、开发工具链和本项目 Apple Watch 徒步 MVP 的版本策略。

它不是功能规格，也不扩大 MVP 范围。首版仍以 iPhone 准备路线、Apple Watch 腕上地图导航、偏航提醒、轨迹记录和结束回传为闭环。

## 当前结论

1. 截至 2026-06-10，Apple 官方稳定版支持口径是 `watchOS 26`；Apple Developer 已发布 `watchOS 27 beta`，但不应作为首发产品承诺。
2. App Store Connect 上传要求已经进入 `Xcode 26 + watchOS 26 SDK` 周期；这约束构建工具链，不等于 App 必须把最低运行版本设为 watchOS 26。
3. 当前工程配置为 `iOS 18.0` / `watchOS 11.0` deployment target，适合作为 MVP 起点：覆盖 Apple Watch Series 6 及之后、SE 2 及之后、Ultra 全系，同时避开 Series 4 / 5 / SE 1 等已停在 watchOS 10.6.1 的旧设备。
4. 真机验证优先使用 `Apple Watch Series 9 / 10 / 11` 或 `Apple Watch Ultra 2 / 3`，再补一台最低边界设备 `Series 6` 或 `SE 2` 做性能、电量和后台稳定性验证。
5. 不建议为首版降到 watchOS 10 或更低。收益主要是多覆盖旧设备，但会增加 UI、后台、性能和工具链兼容成本；这些旧设备也不适合承担长时间徒步导航的 P0 风险。

## 版本与设备支持矩阵

以下矩阵以 Apple 官方兼容性页面为主，结合当前稳定版和 beta 页面整理。旧版本只用于理解存量设备边界，不作为首版支持承诺。

| watchOS 版本 | 典型可运行设备范围 | 对本项目的意义 | 首版策略 |
| --- | --- | --- | --- |
| watchOS 27 beta | Apple 官方 watchOS 27 页面列出 Series 9 / 10 / 11、SE 3、Ultra 2 / 3；需要 iPhone 11 或更新机型并运行 iOS 27 | beta 周期，设备范围明显收窄；适合提前兼容性观察，不适合作为发布基线 | 不作为 MVP 承诺；只在备用设备上验证 |
| watchOS 26 | Apple 支持页列出 SE 2 及之后、Series 6 及之后、Ultra 及之后；新款 Series 11 / SE 3 / Ultra 3 出厂要求 watchOS 26 或之后 | 当前稳定系统主线；App Store 上传需使用 watchOS 26 SDK 或之后 | 用 Xcode 26 / watchOS 26 SDK 构建和提交 |
| watchOS 11 | Apple 兼容性脚注说明升级到 watchOS 11 需要 iPhone XS 或之后并运行 iOS 18 或之后；支持设备范围与 watchOS 26 主体相近 | 当前工程最低 watchOS target；可覆盖 Series 6+ / SE 2+ / Ultra | 推荐保留为 MVP 最低运行版本 |
| watchOS 10 | Series 4 / 5 / SE 1 最高到 watchOS 10.6.1；Series 9 / Ultra 2 起始为 watchOS 10 或之后 | 能覆盖一批旧设备，但这些设备已不能升到 watchOS 11 / 26 | 不作为首版最低版本，除非产品明确要旧表覆盖 |
| watchOS 9 | Series 8 / SE 2 / Ultra 起始版本；Series 6 / 7 可升级覆盖 | 是部分较新旧机的历史版本，不是当前开发基线 | 不支持为首版基线 |
| watchOS 8 | Series 7 起始版本；Series 3 最高到 watchOS 8.8.1 | Series 3 已是明显旧边界，性能和系统能力不适合导航 MVP | 排除 |
| watchOS 7 | Series 6 / SE 1 起始版本 | SE 1 最终停在 watchOS 10.6.1，Series 6 可升到当前稳定主线 | 只关注 Series 6 升级后的表现 |
| watchOS 6 及更早 | Series 5 及更早设备的历史版本 | 设备生命周期、性能和系统 API 都不适合首版户外导航验证 | 排除 |

## Apple Watch 机型边界

| 机型 | Apple 官方兼容口径 | 对徒步 MVP 的判断 |
| --- | --- | --- |
| Series 11 / SE 3 / Ultra 3 | 需要 iPhone 11 或之后、iOS 26 或之后、watchOS 26 或之后 | 新设备验证对象，适合观察 watchOS 26 稳定表现 |
| Series 10 | iPhone XS 或之后、iOS 18 或之后、watchOS 11 或之后 | 与当前工程最低版本匹配，适合作为主力测试表 |
| Series 9 / Ultra 2 | iPhone XS 或之后、iOS 17 或之后、watchOS 10 或之后；可升级到 watchOS 11 / 26 | 高优先级测试表，性能和传感器余量更稳 |
| Series 8 / SE 2 / Ultra | iPhone 8 或之后、iOS 16 或之后、watchOS 9 或之后；可升级到 watchOS 11 / 26 | 可作为中端/旧款覆盖验证 |
| Series 7 | iPhone 6s 或之后、iOS 15 或之后、watchOS 8 或之后；可升级到 watchOS 11 / 26 | 可选兼容观察，不作为最低性能代表 |
| Series 6 | iPhone 6s 或之后、iOS 14 或之后、watchOS 7 或之后；可升级到 watchOS 11 / 26 | 推荐作为 MVP 最低边界真机 |
| Series 5 / Series 4 / SE 1 | 最高到 watchOS 10.6.1 | 不纳入首版支持，除非后续专门降低 deployment target |
| Series 3 及更早 | Series 3 最高到 watchOS 8.8.1；Series 1 / 2 最高到 watchOS 6.3；初代最高到 watchOS 4.3.2 | 排除 |

## Ultra 与普通 Apple Watch 的差异

Ultra 系列不是另一套独立平台。对第三方 watchOS App 来说，它仍然运行 watchOS，使用 SwiftUI、MapKit、Core Location、HealthKit、WatchConnectivity、通知和本地存储等同一套能力。差异主要体现在硬件配置、户外可靠性和测试优先级。

| 项目 | Ultra 系列 | 普通 Series / SE | 对本项目的影响 |
| --- | --- | --- | --- |
| App 支持模型 | 标准 watchOS App | 标准 watchOS App | 不需要为 Ultra 单独做一套 App |
| 屏幕和机身 | Ultra 3 为 49mm 钛金属表壳，显示面积大于 SE，接近或略大于 46mm Series | Series 有 42/46mm 等尺寸；SE 显示面积更小 | Ultra 地图、路线和状态文字更从容；SE 需要重点验证小屏布局 |
| 续航 | Ultra 3 官方标称日常最长 42 小时、低电量最长 72 小时；连续户外运动低电量模式可到 20 小时 GPS + 心率 | Series 11 官方标称日常最长 24 小时、低电量最长 38 小时；SE 3 日常最长 18 小时、低电量最长 32 小时 | Ultra 适合验证长时间徒步；普通表仍必须验证降采样和低电量策略 |
| 定位 | Ultra 系列面向户外运动，具备更强的 GPS 天线/定位配置；Ultra 2 规格列出 GPS antennas | 普通 Series / SE 也有 GPS，能完成路线跟随和轨迹记录 | 首版不能只按 Ultra 调参，偏航阈值要在普通表上回归 |
| 蜂窝与独立性 | Ultra 3 为内置 GPS + Cellular，并有 5G 和卫星通信等安全能力 | Series / SE 视型号有 GPS 或 GPS + Cellular；老款不一定有蜂窝 | 我们的 MVP 仍按 iPhone + Watch 协同，不把卫星通信写成 App 能力 |
| 操作按钮 | Ultra 有可自定义 Action button，官方规格列为硬件按钮之一 | 普通 Series / SE 没有 Action button | 可以作为后续快捷开始/标记点探索，首版不要依赖它 |
| 户外硬件 | Ultra 2 规格列出警笛扬声器、深度计/水温传感器等 | 普通 Series / SE 没有这些 Ultra 专属硬件 | 徒步导航 MVP 基本不用这些专属硬件 |
| 重量和佩戴 | Ultra 更大更重 | Series / SE 更轻，日常佩戴友好 | Ultra 适合户外重度用户；普通表代表更广泛用户 |
| 兼容性边界 | Ultra 全系可纳入 watchOS 11 / 26 主线观察 | Series 6+、SE 2+ 可作为 watchOS 11 / 26 主线；旧 Series 4/5/SE 1 停在 watchOS 10.6.1 | 支持范围仍按 watchOS 版本和机型代际，不按 Ultra/普通二分 |

结论：Ultra 是高优先级测试机，不是最低支持边界。首版支持策略应写成“支持符合最低 watchOS target 的 Apple Watch”，而不是“支持 Ultra”。测试矩阵里应同时保留普通表，避免路线绘制、字体、续航和偏航策略只在 Ultra 上表现良好。

## 开发与上架影响

### SDK 与 deployment target 要分开

Apple 的 App Store 上传要求说的是构建 SDK：自 2026-04-28 起，上传到 App Store Connect 的 App 必须使用 Xcode 26 或之后，并使用 iOS 26 / watchOS 26 等对应 SDK 或之后。

这不等于最低运行版本必须设为 iOS 26 / watchOS 26。对当前项目来说，更合理的组合是：

| 项目 | 建议 |
| --- | --- |
| 构建工具链 | Xcode 26 或之后 |
| 提交 SDK | iOS 26 SDK / watchOS 26 SDK 或之后 |
| iPhone deployment target | 当前工程为 iOS 18.0，暂不下调 |
| Watch deployment target | 当前工程为 watchOS 11.0，暂不下调 |
| 真机矩阵 | 至少覆盖一台最低边界表和一台新款表 |

### 当前工程状态

`watch-hiking-app/` 目前已经配置：

| 文件 | 当前配置 |
| --- | --- |
| `watch-hiking-app/Package.swift` | `.iOS(.v18)`、`.watchOS(.v11)`、`.macOS(.v15)` |
| `watch-hiking-app/WatchHikingApp.xcodeproj/project.pbxproj` | `IPHONEOS_DEPLOYMENT_TARGET = 18.0`、`WATCHOS_DEPLOYMENT_TARGET = 11.0` |

结论：工程配置与本文建议一致，不需要因为本次调研修改 target。

## 真机验证建议

| 验证层 | 推荐设备 | 目标 |
| --- | --- | --- |
| 最低边界 | Series 6 或 SE 2，升级到 watchOS 11 / 26 | 验证地图绘制、定位、轨迹写盘、HKWorkoutSession、WatchConnectivity 和电量下限 |
| 主力新款 | Series 9 / 10 / 11 或 Ultra 2 / 3 | 验证目标用户可能购买的新设备体验 |
| 长续航户外 | Ultra 2 或 Ultra 3 | 验证长时间徒步、电量策略、弱网和断连补传 |
| beta 观察 | 支持 watchOS 27 beta 的非主力设备 | 提前发现 API / UI / 后台行为变化，不作为发布阻断项 |

每次真机验证都应记录：

1. Apple Watch 型号、尺寸、蜂窝或 GPS 版本。
2. watchOS 版本和 build。
3. 配对 iPhone 型号、iOS 版本和 build。
4. Xcode 版本、构建 SDK、App build。
5. 路线长度、测试时长、是否锁屏、是否断连、是否低电量。
6. 定位、地图、Workout、同步、触觉提醒和电量结果。

## 风险与待验证

| 风险 | 判断 |
| --- | --- |
| watchOS 27 beta 设备范围收窄 | 可能影响 2026 年秋季之后的新系统覆盖策略；现在只做观察 |
| Series 6 / SE 2 性能和电量 | 虽然在 watchOS 26 支持范围内，但徒步长时间导航仍需真机验证 |
| watchOS 26 SDK 构建后的 watchOS 11 运行兼容 | 需要持续用最低 target 模拟器和真机回归 |
| Apple Intelligence / Workout Buddy 等新能力 | 与首版路线跟随、偏航和轨迹闭环无直接依赖，不纳入 MVP |
| Apple 官方页面更新 | 发布前需要再次核对 App Store 上传要求、Xcode 当前版本和 watchOS 兼容设备 |

## 官方参考

以下页面在 2026-06-10 查阅。

1. [Update your Apple Watch - Apple Support](https://support.apple.com/en-us/108926)
2. [Apple Watch and iPhone compatibility - Apple Support](https://support.apple.com/en-us/118490)
3. [watchOS 27 - Apple](https://www.apple.com/os/watchos/)
4. [watchOS 27 beta Release Notes - Apple Developer Documentation](https://developer.apple.com/documentation/watchos-release-notes/watchos-27-release-notes)
5. [watchOS 26 Release Notes - Apple Developer Documentation](https://developer.apple.com/documentation/watchos-release-notes/watchos-26-release-notes)
6. [SDK minimum requirements - Apple Developer](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)
7. [Upcoming Requirements - Apple Developer](https://developer.apple.com/news/upcoming-requirements/)
8. [Xcode - Support - Apple Developer](https://developer.apple.com/support/xcode/)

## 相关文档

1. [WatchOS 能力使用取舍 v0.1](./watchos-capability-decisions-v0.1.md)
2. [WatchOS 徒步 App 开发与上架流程 v0.1](./watchos-development-release-flow-v0.1.md)
3. [iPhone App + Apple Watch App 上架准备文档 v0.1](./iphone-watchos-app-store-submission-v0.1.md)
4. [当前 UI 与操作逻辑对齐说明 v0.1](./current-ui-operation-alignment-v0.1.md)
5. [WatchOS 徒步 App MVP 开发切分 v0.1](./mvp-development-slices-v0.1.md)
