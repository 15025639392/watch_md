# 华为真实工程迁移与真机验证清单 v0.1

更新日期：2026-06-06  
适用范围：把 `huawei-validation/` 骨架迁入 DevEco Studio / Android Studio 真实工程，并开始 WATCH 5/4 与 GT 6/5 的 H0-H2 真机验证。

## 本机环境快照

2026-06-06 已运行：

```sh
bash scripts/check-harmonyos-watch-env.sh
```

结果摘要：

| 项 | 状态 |
| --- | --- |
| DevEco Studio | OK，`6.1.1` |
| HarmonyOS SDK | OK |
| OpenHarmony SDK | OK |
| HMS SDK | OK |
| WearEngine ArkTS kit | OK |
| WearEngine API 声明 | OK |
| liteWearable previewer | OK |
| Java | OK，OpenJDK 17 |
| ohpm | 命令存在但 8s 内未返回，需要 DevEco 内再次确认 |
| hdc | 命令存在但 5s 内未返回，需要连接真机后再次确认 |
| hdc list targets | 5s 内未返回，当前未确认真机连接 |
| 手表模拟器模板 | OK，DevEco 本地有 `Huawei_Wearable` API 20-24 模板 |
| 手表模拟器系统镜像 | 未安装，本机当前只有 `phone_all_arm` 系统镜像 |

结论：本机已具备创建 DevEco Studio wearable / lite wearable 工程的基础条件，但真机连接、ohpm、hdc 仍需要在 DevEco 和设备连接后复查。若没有 WATCH / GT 真机，需要先在 DevEco Device Manager 下载 `Huawei_Wearable` API 24、466x466 的手表系统镜像，否则无法完成手表模拟器 H0。

## 目标工程

| 工程 | DevEco / Android Studio 目标 | 迁入骨架 |
| --- | --- | --- |
| WATCH 手表端 | DevEco Studio `Wearable` 工程 | `huawei-watch-demo/` |
| GT 手表端 | DevEco Studio `liteWearable` 或目标 GT 支持的轻量工程 | `huawei-gt-lite-demo/` |
| HarmonyOS / 华为手机端 | DevEco Studio 手机应用工程 | `huawei-phone-sync-demo/harmonyos-phone-sync-demo/` |
| Android 手机端 | Android Studio Kotlin 工程 | `huawei-phone-sync-demo/android-phone-sync-demo/` |

## 生成导入包

真实工程由 DevEco Studio / Android Studio 创建。创建前可先运行：

```sh
node huawei-validation/scripts/prepare-real-project-import.mjs
```

脚本会生成 `huawei-validation/generated/real-project-import/`：

| 目录 | 用途 |
| --- | --- |
| `watch-wearable/src/` | WATCH Wearable 工程待迁入 ArkTS 文件 |
| `gt-lite/src/` | GT liteWearable 工程待迁入 HTML / CSS / JS 文件 |
| `harmonyos-phone-sync/src/` | HarmonyOS / 华为手机工程待迁入 ArkTS 同步骨架 |
| `android-phone-sync/src/` | Android 手机工程待迁入 Kotlin 同步骨架 |
| `shared/` | WATCH / GT payload、ACK、状态和 checklist |

导入包只做文件整理，不代表真实工程已经可构建。

## 创建 WATCH 真实工程

1. 打开 DevEco Studio。
2. 新建面向智能可穿戴设备的 `Wearable` 工程。
3. 记录工程名、`bundleName`、签名配置和 API 版本。
4. 迁入或对照 `huawei-watch-demo/src/`：
   - `MainPage.ets`
   - `RouteModels.ets`
   - `WearEngineBridge.ets`
5. 确认工程可在 preview 或真机上打开 Demo 首页。
6. 接入本地模拟入口，先用字符串形式注入 `shared/route-payload.sample.json`。
7. 验证 ACK 字段：
   - `routeId`
   - `routeVersion`
   - `storedPointCount`
   - `storedWaypointCount`
   - `checksum`
   - `nextAction`

### WATCH 模拟器前置

如果暂时没有 WATCH 5 / 4 真机，先完成模拟器准备：

1. 打开 DevEco Studio。
2. 打开 Device Manager。
3. 选择 Local Emulator / Local Simulator。
4. 创建 `Huawei_Wearable`，优先 API 24，分辨率 466x466。
5. 等待 DevEco 下载 wearable/watch system image。
6. 下载后重新运行：

```sh
bash scripts/check-huawei-watch-emulator.sh
```

当前状态：2026-06-06 已确认本机有 `Huawei_Wearable` API 20-24 模板，但尚未下载 watch system image。

### H0 readiness 命令

下载镜像、连接真机或创建真实工程后，运行：

```sh
bash huawei-validation/scripts/check-h0-readiness.sh
```

该脚本检查：

1. DevEco Studio 与 Emulator 是否存在。
2. 是否能在模板中找到 `Huawei_Wearable`。
3. 本机是否已下载 wearable/watch system image。
4. `hdc list targets` 是否能返回。
5. 真实工程导入包是否能生成。
6. 本地 WATCH / GT payload 流程是否仍通过。

## 创建 GT 真实工程

1. 打开 DevEco Studio。
2. 新建 `liteWearable` 或目标 GT 支持的轻量穿戴工程。
3. 记录目标模板、应用类型、包名 / bundleName 和 API 版本。
4. 迁入或对照 `huawei-gt-lite-demo/src/`：
   - `index.html`
   - `index.css`
   - `index.js`
5. 确认页面可展示路线名、下一个关键点、转向提示和同步状态。
6. 接入本地模拟入口，先用字符串形式注入 `shared/gt-navigation-payload.sample.json`。
7. 验证 ACK 字段：
   - `routeId`
   - `routeVersion`
   - `storedWaypointCount`
   - `storedPromptCount`
   - `checksum`

## 创建 HarmonyOS / 华为手机真实工程

1. 新建 HarmonyOS / 华为手机应用工程。
2. 在 AppGallery Connect 或本地调试配置中记录：
   - `bundleName`
   - 签名证书指纹
   - 华为账号地区
   - SDK API 版本
3. 迁入或对照 `huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/`。
4. 先使用 `LocalSimulationTransport` 跑通：
   - WATCH 完整路线 payload
   - GT 轻量导航 payload
   - ACK
   - `watchStatus`
5. 再补 `WearEngineRouteTransport`：
   - 设备发现
   - WATCH payload 发送
   - GT payload 发送
   - 状态读取或状态消息订阅

## 创建 Android 手机真实工程

1. 新建 Android / Kotlin 工程。
2. 配置华为 Maven 仓。
3. 创建或绑定 AGC 应用。
4. 下载并放置 `agconnect-services.json`。
5. 迁入或对照 `huawei-phone-sync-demo/android-phone-sync-demo/src/`。
6. 先使用 `LocalSimulationTransport` 做协议回归。
7. 再接入 HMS Core Wear Engine Android SDK。

## H0-H2 验证记录

| 阶段 | WATCH 数字系列 | GT 系列 |
| --- | --- | --- |
| H0 工程创建 | 待验证 | 待验证 |
| H0 Demo 首页 | 待验证 | 待验证 |
| H1 真机安装 | 待验证 | 待验证 |
| H1 手机发现设备 | 待验证 | 待验证 |
| H2 payload 下发 | 待验证 | 待验证 |
| H2 ACK 回传 | 待验证 | 待验证 |
| H2 状态回传 | 待验证 | 待验证 |

## 阻塞条件

遇到以下任一情况，不进入正式功能开发：

1. WATCH 或 GT 目标机型无法安装对应 Demo。
2. 手机无法通过 Wear Engine 发现目标设备。
3. 路线 payload 无法稳定下发或 ACK 丢失。
4. GT 只能接收通知，不能运行轻量页面或回传控制事件。
5. AGC 应用类型、签名或地区限制导致调试链路不可用。

## 下一步输出物

1. DevEco 工程创建截图或配置记录。
2. WATCH / GT 真机型号、系统版本、手机型号和 Huawei Health / HMS Core 版本。
3. 首次真实 ACK JSON。
4. 首次真实 `watchStatus` JSON。
5. 失败项和可替代路径记录。
