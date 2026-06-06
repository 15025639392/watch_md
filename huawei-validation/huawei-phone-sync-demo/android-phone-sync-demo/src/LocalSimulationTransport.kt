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
            routeVersion = payload.routeVersion,
            deviceLine = device.deviceLine.name,
            receivedAt = Instant.now().toString(),
            status = "accepted",
            storedPointCount = payload.points.size,
            storedWaypointCount = payload.waypoints.size,
            checksum = payload.checksum,
            nextAction = "awaitUserStartConfirmation"
        )
    }

    override fun sendGtNavigationPayload(device: HuaweiWatchDevice, payload: GtNavigationPayload): RouteAck {
        return RouteAck(
            protocolVersion = payload.protocolVersion,
            routeId = payload.routeId,
            routeVersion = payload.routeVersion,
            deviceLine = device.deviceLine.name,
            receivedAt = Instant.now().toString(),
            status = "accepted",
            storedWaypointCount = payload.waypoints.size,
            storedPromptCount = payload.turnPrompts.size,
            checksum = payload.checksum,
            nextAction = "renderStatusAndPrepareAlerts"
        )
    }

    override fun readStatus(device: HuaweiWatchDevice, routeId: String): WatchStatus {
        return WatchStatus(
            protocolVersion = "0.1",
            deviceLine = device.deviceLine.name,
            recordingState = "idle",
            navigationStatus = if (device.deviceLine == DeviceLine.WATCH) "routeInstalled" else "statusSyncReady",
            batteryPercent = if (device.deviceLine == DeviceLine.WATCH) 82 else 91,
            isWorn = true,
            isCharging = false,
            isConnectedToPhone = true,
            lastRouteId = routeId,
            updatedAt = Instant.now().toString()
        )
    }
}
