package com.example.hiking.huawei.sync

interface RouteTransport {
    fun discoverDevices(): List<HuaweiWatchDevice>

    fun sendRoutePayload(device: HuaweiWatchDevice, payload: RoutePayload): RouteAck

    fun readStatus(device: HuaweiWatchDevice, routeId: String): WatchStatus
}

data class HuaweiWatchDevice(
    val deviceId: String,
    val displayName: String,
    val deviceLine: DeviceLine
)

enum class DeviceLine {
    WATCH,
    GT
}

