package com.example.hiking.huawei.sync

import java.time.Instant

class LocalSimulationTransport : RouteTransport {
    override fun discoverDevices(): List<HuaweiWatchDevice> {
        return listOf(
            HuaweiWatchDevice(
                deviceId = "local-watch-demo",
                displayName = "Local WATCH Demo",
                deviceLine = DeviceLine.WATCH
            ),
            HuaweiWatchDevice(
                deviceId = "local-gt-lite-demo",
                displayName = "Local GT Lite Demo",
                deviceLine = DeviceLine.GT
            )
        )
    }

    override fun sendRoutePayload(device: HuaweiWatchDevice, payload: RoutePayload): RouteAck {
        return RouteAck(
            protocolVersion = payload.protocolVersion,
            routeId = payload.routeId,
            deviceLine = device.deviceLine.name,
            receivedAt = Instant.now().toString(),
            status = "accepted",
            storedPointCount = payload.points.size
        )
    }

    override fun readStatus(device: HuaweiWatchDevice, routeId: String): WatchStatus {
        return WatchStatus(
            protocolVersion = "0.1",
            deviceLine = device.deviceLine.name,
            recordingState = "idle",
            batteryPercent = if (device.deviceLine == DeviceLine.WATCH) 82 else 91,
            isWorn = true,
            isCharging = false,
            lastRouteId = routeId,
            updatedAt = Instant.now().toString()
        )
    }
}

