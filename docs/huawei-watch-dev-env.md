# 华为手表开发环境搭建记录

更新日期：2026-06-05

## 本机状态

当前机器已经具备华为手表开发的基础工具链：

| 项 | 当前值 |
| --- | --- |
| 操作系统 | macOS 26.4.1，Apple Silicon / arm64 |
| DevEco Studio | `/Applications/DevEco-Studio.app`，版本 `6.1.1`，构建 `DS-243.24978.46.36.611268` |
| HarmonyOS SDK | `/Applications/DevEco-Studio.app/Contents/sdk/default` |
| OpenHarmony SDK | `apiVersion: 24`，`version: 6.1.1.115`，`releaseType: Beta1` |
| Node | DevEco 内置 Node `18.20.1` |
| hdc | `3.2.0d` |
| WearEngine | 已安装 `@kit.WearEngine.d.ts` 和 `@hms.health.wearEngine.d.ts` |
| 预览器 | 已安装 `wearable` 与 `liteWearable` 相关资源 |

`~/.zshrc` 和 `~/.zprofile` 已配置以下关键变量：

```sh
export DEVECO_STUDIO_HOME="/Applications/DevEco-Studio.app/Contents"
export HARMONYOS_SDK_HOME="$DEVECO_STUDIO_HOME/sdk/default"
export OHOS_SDK_HOME="$HARMONYOS_SDK_HOME/openharmony"
export HMS_SDK_HOME="$HARMONYOS_SDK_HOME/hms"
export PATH="$DEVECO_STUDIO_HOME/tools/node/bin:$DEVECO_STUDIO_HOME/tools/ohpm/bin:$DEVECO_STUDIO_HOME/tools/hvigor/bin:$OHOS_SDK_HOME/toolchains:$PATH"
```

## 一键自检

在仓库根目录运行：

```sh
bash scripts/check-harmonyos-watch-env.sh
```

这个脚本会检查 DevEco Studio、HarmonyOS SDK、WearEngine、liteWearable 预览器、Node、ohpm、hdc 和 Java。脚本对外部命令带了超时保护，避免某个工具启动异常时卡住整次自检。

## DevEco Studio 设置

1. 打开 DevEco Studio：

```sh
open -a /Applications/DevEco-Studio.app
```

2. 进入 `DevEco Studio > Settings/Preferences > SDK`，确认已安装 HarmonyOS / OpenHarmony API 24 相关 SDK。
3. 进入 `Settings/Preferences > Tools > Huawei Account`，登录华为开发者账号。
4. 进入 `Settings/Preferences > Build, Execution, Deployment`，确认 SDK 路径指向：

```txt
/Applications/DevEco-Studio.app/Contents/sdk/default
```

5. 如果需要真机调试，进入证书/签名配置，按 AppGallery Connect 或 DevEco 向导创建调试签名。

## 创建手表项目

在 DevEco Studio 里创建新项目时，优先按目标设备选择：

| 目标 | 建议选择 |
| --- | --- |
| HarmonyOS 智能手表 App | `Wearable` / ArkTS / Stage 模型 |
| Watch GT、Fit、部分长续航穿戴设备 | 先验证是否只支持 `liteWearable` 或 WearEngine 协同 |
| 手机 App + 手表联动 | 手机侧 HarmonyOS App + WearEngine 能力 |

户外 App 的 MVP 建议先做：

1. 手表端：路线线框、当前位置、偏航提示、运动状态页。
2. 手机端：GPX 导入、路线预览、路线下发、运动后同步。
3. 通信：优先验证 WearEngine 的 P2P communication、monitor、notification 和 sensor 能力。
4. 机型验证：优先拿目标真机确认是否支持应用安装、手表端调试、定位、心率、气压/海拔、后台运动和通知震动。

## 真机调试 checklist

1. 手表和手机升级到目标系统版本。
2. 手机安装并登录华为运动健康。
3. 手机与手表完成配对。
4. 打开手表开发者选项或调试入口，允许调试连接。
5. 用 `hdc list targets` 确认设备是否可见。
6. 在 DevEco Studio 中选择手表设备运行。
7. 首次运行时处理签名、证书、权限授权和设备确认弹窗。

如果 `hdc list targets` 看不到设备，优先检查：

1. 手机/手表是否允许调试。
2. USB 线或无线调试是否稳定。
3. DevEco Studio 是否识别同一个 SDK 目录。
4. 华为运动健康、HMS Core、AppGallery 是否是可用版本。
5. 目标手表型号是否允许第三方 App 调试安装。

## 需要提前确认的产品边界

不要直接承诺“支持华为手表”。华为穿戴设备差异很大，至少要按这些维度建测试矩阵：

| 维度 | 要确认的问题 |
| --- | --- |
| 手表型号 | 是否支持第三方手表 App、Wearable/liteWearable、应用安装 |
| 系统版本 | 是否满足目标 API 和 WearEngine 能力 |
| 手机类型 | 华为手机、非华为 Android、iPhone 的能力差异很大 |
| 地区 | AppGallery、HMS Core、华为运动健康和 Health Kit 可用性 |
| 户外能力 | GPS、后台定位、心率、海拔/气压、震动通知、续航 |
| 发布路径 | 是否能上架 AppGallery 手表端应用或只能做手机侧联动 |

## 官方入口

- [DevEco Studio 下载页](https://developer.huawei.com/consumer/cn/deveco-studio/)
- [HarmonyOS Wearable App Development](https://developer.huawei.com/consumer/en/multidevice/wearables/get-started/)
- [Wear Engine](https://developer.huawei.com/consumer/en/hms/huawei-wearengine/)
- [Health Kit](https://developer.huawei.com/consumer/en/hms/huaweihealth/)
- [Location Kit Codelab](https://developer.huawei.com/consumer/en/codelab/HMS-LocationKit/)
- [华为手表/手环与 Android 手机配对](https://consumer.huawei.com/en/support/content/en-us16008856/)
