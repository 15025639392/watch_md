# 华为 Wear Engine / Health Kit / AppGallery 申请与 SDK 接入说明 v0.1

更新日期：2026-06-06  
适用范围：Apple Watch MVP 之后的华为生态验证预研。本文不改变当前首发 Apple Watch / watchOS 的 MVP 范围。

## 结论摘要

| 能力 | 是什么 | 是否需要申请 | SDK / 工具获取方式 | 当前项目用途 |
| --- | --- | --- | --- | --- |
| Wear Engine | HMS Core 中的手机与华为穿戴设备协同能力，支持设备发现、状态监听、消息、文件、通知和部分传感器能力 | 通常不按业务资质单独申请，但需要开发者账号、AppGallery Connect 应用配置、签名证书、运行时用户授权；具体地区和能力以后台为准 | Android 侧通过华为 Maven 仓集成 `com.huawei.hms:wearengine`；HarmonyOS / lite wearable 侧优先用 DevEco Studio SDK Manager / HMS SDK | 验证手机下发路线 JSON / GPX、手表 ACK、状态回传 |
| Health Kit / Health Service Kit | 华为运动健康数据开放能力，用户授权后读取或写入健康、运动数据 | 需要在 AppGallery Connect 申请服务和数据权限；运行时还需用户授权 | Android 侧通过华为 Maven 仓集成 `com.huawei.hms:health`；HarmonyOS 侧按 DevEco / HMS Kit 文档选择对应 SDK | 运动后复盘、心率/步数/运动记录读取或写入华为健康生态 |
| AppGallery / AppGallery Connect | 华为应用分发、应用配置、测试、审核、上架和运营后台 | 需要开发者账号实名认证；上架需要提交应用审核；使用健康等能力需额外开通对应服务 | Web 后台：AppGallery Connect；AGC SDK 可在官方资源中心下载，也可用 Maven/DevEco 集成 | 华为手机/手表版本的配置、测试、内测、上架与服务开通 |

## Wear Engine

### SDK 下载与获取

Wear Engine 的手机侧 SDK 属于 HMS Core Android SDK，常规获取方式不是手动下载 jar，而是在 Android / HarmonyOS 工程里配置华为 Maven 仓库并添加依赖。

```gradle
repositories {
    maven { url "https://developer.huawei.com/repo/" }
    google()
    mavenCentral()
}

dependencies {
    implementation "com.huawei.hms:wearengine:{latest-version}"
}
```

版本号不要写死在产品文档里。实际开发时进入官方 Wear Engine 开发文档、Codelab 或 HMS SDK 版本页确认最新版本。

手表侧或轻量穿戴侧开发优先通过 DevEco Studio 获取：

1. 安装 DevEco Studio。
2. 在 `Settings/Preferences > SDK` 中安装目标 HarmonyOS / OpenHarmony SDK。
3. 在 SDK Manager 或 HMS SDK 目录确认 Wear Engine 相关声明文件和 Kit 已安装。
4. 用 `docs/huawei-watch-dev-env.md` 中的脚本检查本机 SDK 状态。

### 如何使用

华为路线的最小验证链路建议按以下顺序做：

1. 在 AppGallery Connect 创建手机端应用，配置包名和签名证书指纹。
2. 如果有手表端应用，配置手表端包名、签名证书指纹和调试签名。
3. 手机端集成 Wear Engine SDK。
4. 手机端请求设备管理、连接状态、通信等所需权限。
5. 手机端发现已配对的华为穿戴设备。
6. 手机向手表发送一条路线 JSON 或 GPX 文件。
7. 手表收到后落本地并回 ACK。
8. 手表回传连接、电量、佩戴、运动状态等最小状态。
9. 记录华为手机、非华为 Android、iPhone 三类配对路径差异。

### 需要准备的材料

| 材料 | 用途 |
| --- | --- |
| 华为开发者账号 | 登录 AppGallery Connect、DevEco Studio、申请能力和测试发布 |
| 手机端包名 | 创建 AGC 应用和绑定 SDK 配置 |
| 手机端签名证书指纹 | 校验应用身份 |
| 手表端包名和证书指纹 | 手机-手表应用通信、调试和发布配置 |
| 功能说明 | 说明为什么需要设备发现、消息、文件、状态监听 |
| 测试设备清单 | 至少区分 WATCH 数字系列、WATCH GT 系列、华为手机、非华为 Android、iPhone |

### 当前项目注意事项

Wear Engine 只能作为华为路线验证项，不能写进 Apple Watch MVP 必需能力。文档和需求中应使用“待华为真机验证”，不要承诺所有华为手表都能安装第三方徒步 App 或获得完整后台能力。

## Health Kit / Health Service Kit

### SDK 下载与获取

Health Kit 同样属于 HMS Core 能力。Android 侧通常通过华为 Maven 仓库添加依赖：

```gradle
repositories {
    maven { url "https://developer.huawei.com/repo/" }
    google()
    mavenCentral()
}

dependencies {
    implementation "com.huawei.hms:health:{latest-version}"
}
```

如果工程使用 AppGallery Connect 配置文件，还需要从 AGC 应用详情中下载 `agconnect-services.json`，放入 Android app 模块的对应目录，并接入 AGC Gradle 插件。

### 如何申请

1. 注册并实名认证华为开发者账号。
2. 在 AppGallery Connect 创建项目和应用。
3. 配置应用包名、签名证书指纹。
4. 在服务列表中开通 Health Kit / Health Service Kit。
5. 选择需要的数据权限，例如步数、心率、运动记录、运动会话、卡路里、距离等。
6. 填写用途说明、隐私政策和数据处理说明。
7. 提交审核。
8. 审核通过后，在 App 内发起华为账号登录和 Health Kit 授权。
9. 用户授权后才能读取或写入对应数据。

### 需要准备的材料

| 材料 | 用途 |
| --- | --- |
| 开发者实名主体 | 申请服务和上架审核 |
| 应用包名、签名证书指纹 | 绑定应用身份 |
| 隐私政策 URL | 说明健康数据采集、使用、存储、共享、删除方式 |
| 用户协议 URL | 说明用户权利和服务边界 |
| 数据权限清单 | 明确读取/写入哪些健康和运动数据 |
| 使用场景说明 | 解释为什么需要这些数据，例如运动后复盘、心率曲线、步频分析 |
| App 截图或演示视频 | 帮助审核人员确认数据用途 |
| 测试账号 | 供审核人员进入相关页面验证 |

### 当前项目建议

华为 Health Kit 不应作为首轮华为验证的 P0 依赖。更稳妥的顺序是：

1. P0：先验证手表端应用安装、定位、路线显示、偏航提醒和 Wear Engine 路线下发。
2. P1：验证运动后轨迹回传到自有 App。
3. P1/P2：再验证是否需要把运动记录写入华为健康，或从华为健康读取心率/运动数据。

## AppGallery / AppGallery Connect

### SDK / 工具下载与获取

AppGallery 本身是应用分发平台，不是单一 SDK。常用入口分为：

| 项 | 获取方式 |
| --- | --- |
| AppGallery Connect 后台 | 登录华为开发者平台进入 AGC 控制台 |
| `agconnect-services.json` | 在 AGC 的具体应用详情中下载 |
| AGC Gradle 插件 | 通过华为 Maven 仓配置 `com.huawei.agconnect:agcp:{latest-version}` |
| AGC 各服务 SDK | 在 AppGallery Connect 官方资源中心下载，或按具体服务文档用 Maven 集成 |
| DevEco Studio | 从华为 DevEco Studio 官方下载页安装 |
| HarmonyOS SDK / HMS SDK | 在 DevEco Studio 的 SDK Manager 中安装 |

Android 工程常见配置示例：

```gradle
buildscript {
    repositories {
        maven { url "https://developer.huawei.com/repo/" }
        google()
        mavenCentral()
    }
    dependencies {
        classpath "com.huawei.agconnect:agcp:{latest-version}"
    }
}
```

### 如何上架或内测

1. 完成华为开发者账号注册和实名认证。
2. 在 AGC 创建应用，填写应用名称、包名、分类、默认语言。
3. 配置签名证书、服务能力和必要的 SDK。
4. 上传 APK / App Bundle / HarmonyOS 应用包，具体格式以目标平台和后台要求为准。
5. 填写应用介绍、截图、图标、隐私政策、用户协议、权限说明。
6. 提供测试账号、测试步骤和必要的测试路线数据。
7. 先走开放测试、内测或云测试，确认安装和核心流程。
8. 提交正式审核。
9. 审核通过后按地区、版本和灰度策略发布。

### 需要准备的材料

| 材料 | 用途 |
| --- | --- |
| 个人或企业开发者认证材料 | 开发者账号实名认证 |
| 应用安装包 | 上架、内测、云测试 |
| 应用图标和截图 | 商店展示和审核 |
| 应用简介、详细描述、分类 | 商店信息 |
| 隐私政策 URL、用户协议 URL | 合规审核 |
| 权限说明 | 定位、后台定位、蓝牙、健康数据、通知、文件等敏感权限解释 |
| 测试账号和测试说明 | 审核人员复现功能 |
| 软著、ICP备案或行业资质 | 中国大陆、特定类目或后台要求时补充；是否必须以审核后台为准 |

## SDK 使用顺序建议

华为路线不要一次性集成所有 Kit。建议按最小闭环推进：

| 阶段 | 目标 | 使用能力 | 验证通过标准 |
| --- | --- | --- | --- |
| H0 | 环境可用 | DevEco Studio、HarmonyOS SDK、模拟器/真机、hdc | 能运行空白 Wearable Demo |
| H1 | 手表端 App 可运行 | HarmonyOS Wearable / liteWearable | WATCH 或 GT 目标机型能安装和打开 Demo |
| H2 | 手机-手表通信 | Wear Engine | 手机发送路线 JSON，手表收到并 ACK |
| H3 | 户外核心能力 | 定位、震动、通知、后台运动能力 | 30 分钟户外记录不中断，偏航提醒可感知 |
| H4 | 运动后数据 | 自有同步链路，必要时 Health Kit | 轨迹能回传；健康数据权限可申请、可授权、可读写 |
| H5 | 分发验证 | AppGallery Connect | 内测包可安装，审核材料闭环 |

## WATCH 系列与 GT 系列的开发差异

华为官方穿戴开发入口把设备分为智能可穿戴设备和轻量级智能可穿戴设备。当前项目应把 WATCH 数字系列和 WATCH GT 系列拆成两条验证线。

| 项 | WATCH 数字系列 | WATCH GT 系列 |
| --- | --- | --- |
| 推荐目标机 | WATCH 5 或 WATCH 4 | WATCH GT 6 或 WATCH GT 5 |
| 开发入口 | 智能可穿戴设备 | 轻量级智能可穿戴设备，或手机 App + Wear Engine 协同 |
| 主要语言 | ArkTS | 兼容 JS 的类 Web 开发范式；具体以目标机型和 DevEco 模板为准 |
| UI 技术 | ArkUI 声明式 UI | 类 Web UI / 轻量穿戴组件 |
| 工程目标 | 完整手表 App Demo | 轻量手表 Demo 或手机协同 Demo |
| 适合首轮验证 | 路线页、会话控制、定位记录、偏航震动、运动后同步 | 路线提醒、关键点、偏航通知、长续航、手机导航同步 |
| 不应默认承诺 | eSIM 独立网络、长期后台、系统离线地图复用 | 完整离线地图、复杂 GPX 渲染、所有 GT 型号一致支持 |

实操上可以这样拆：

1. `WATCH` Demo：在 DevEco Studio 中创建 Wearable / ArkTS / ArkUI 工程，目标是验证完整手表 App。
2. `GT` Demo：先确认目标 GT 机型在 DevEco Studio 和 AppGallery Connect 中支持的应用类型；如果走轻量级智能可穿戴，按类 Web / JS 范式做轻量页面；如果不支持安装目标 App，则只做手机侧 Wear Engine 协同验证。
3. 手机侧 Android/HarmonyOS App：无论 WATCH 还是 GT，都准备 Wear Engine 通信 Demo，用于路线 JSON / GPX 下发和状态 ACK。
4. 文档、测试矩阵和上架材料中分别标记 `WATCH ArkTS/ArkUI` 与 `GT liteWearable/JS 或 Wear Engine`，不要合并成单一“华为手表版本”。

建议先按三个工程沉淀：

| 工程 | 用途 | 说明 |
| --- | --- | --- |
| `huawei-watch-demo` | WATCH 数字系列完整手表 App | 使用 `Wearable`、ArkTS、ArkUI，验证完整路线页、运动页、定位、震动和后台 |
| `huawei-gt-lite-demo` | GT 系列轻量手表 App | 使用 `liteWearable` 或兼容 JS 的类 Web 范式；若目标 GT 不支持安装，则只保留为验证记录 |
| `huawei-phone-sync-demo` | 手机侧 Wear Engine 通信 | 手机管理路线和 GPX，分别向 WATCH / GT Demo 下发路线和接收 ACK |

路线模型、GPX 解析、偏航规则和通信 payload 可以共享；手表端工程不要默认共享。是否能最终合并成一个发布包，需要等 WATCH / GT 真机安装、AGC 应用类型和 AppGallery 分发路径验证后再判断。

当前仓库已在 `huawei-validation/` 下放置这些验证工程骨架。真实开发时仍需要用 DevEco Studio / Android Studio 创建可编译工程，并按目标设备迁入骨架文件。

## 官方入口

- Huawei Wear Engine: https://developer.huawei.com/consumer/en/hms/huawei-wearengine/
- Wear Engine Codelab: https://developer.huawei.com/consumer/en/codelab/WearEngine/
- Huawei Health Kit: https://developer.huawei.com/consumer/en/hms/huaweihealth/
- HMS Core Android 集成准备: https://developer.huawei.com/consumer/en/codelab/HMSPreparation/index.html
- AppGallery Connect: https://developer.huawei.com/consumer/en/agconnect
- DevEco Studio 下载页: https://developer.huawei.com/consumer/cn/deveco-studio/

## 未验证项

以下内容必须在华为账号后台和真机上再次确认，不能直接作为产品承诺：

1. Wear Engine 在中国区、海外区、华为手机、非华为 Android、iPhone 上的能力差异。
2. WATCH 数字系列和 WATCH GT 系列是否支持同一套第三方手表 App 安装、调试和上架路径。
3. Health Kit 可申请的数据字段、审核周期和敏感数据限制。
4. AppGallery 是否支持目标手表应用类型、目标地区和目标设备分发。
5. 后台定位、长时间运动、震动、通知、地图资源和传感器读取在目标机型上的实际表现。
