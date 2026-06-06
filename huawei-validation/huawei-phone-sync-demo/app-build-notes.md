# Phone sync demo build notes

真实 Android / HarmonyOS 手机工程创建后记录：

| 项 | 值 |
| --- | --- |
| AGC 应用 ID |  |
| 包名 |  |
| 签名证书指纹 |  |
| `agconnect-services.json` 是否已下载 |  |
| Wear Engine SDK 版本 |  |
| 测试手机 |  |

## Gradle 入口

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

版本号以开发时官方文档和 AGC 后台为准。

