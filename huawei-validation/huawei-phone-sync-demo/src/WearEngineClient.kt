package com.example.hiking.huawei.sync

class WearEngineClient {
    fun discoverDevices(): List<String> {
        // TODO: Replace with the real Wear Engine device discovery API.
        return emptyList()
    }

    fun sendRoutePayload(deviceId: String, payload: RoutePayload): Boolean {
        // TODO: Serialize payload and send it through Wear Engine message/file APIs.
        return deviceId.isNotBlank() && payload.routeId.isNotBlank()
    }

    fun handleRouteAck(rawAck: String): RouteAck? {
        // TODO: Parse with the real app JSON serializer.
        return null
    }
}

