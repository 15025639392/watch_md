# huawei-phone-sync-demo TODO

1. 创建真实 HarmonyOS / 华为手机工程，并迁入 `harmonyos-phone-sync-demo/`。
2. 创建真实 Android 手机工程，并迁入 `android-phone-sync-demo/`。
3. 在 AGC 分别确认手机端应用类型、包名 / bundleName 和证书指纹。
4. Android 线下载并放置 `agconnect-services.json`，配置华为 Maven 仓。
5. HarmonyOS 线确认 DevEco SDK、HMS Kit 和 Wear Engine Kit。
6. 两条手机线分别补齐 `WearEngineRouteTransport`。
7. 保持 `LocalSimulationTransport` 作为协议回归测试入口。
8. 分别连接 `huawei-watch-demo` 与 `huawei-gt-lite-demo`。
9. 记录华为手机、非华为 Android 和 iPhone 的能力差异。
