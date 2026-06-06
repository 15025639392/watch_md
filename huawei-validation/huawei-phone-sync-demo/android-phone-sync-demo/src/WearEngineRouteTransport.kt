package com.example.hiking.huawei.sync

class WearEngineRouteTransport : RouteTransport {
    override fun discoverDevices(): List<HuaweiWatchDevice> {
        // TODO: Replace with Wear Engine device discovery.
        // Expected mapping:
        // - WATCH 5/4 -> DeviceLine.WATCH
        // - GT 6/5 -> DeviceLine.GT
        return emptyList()
    }

    override fun sendRoutePayload(device: HuaweiWatchDevice, payload: RoutePayload): RouteAck {
        // TODO: Serialize RoutePayload and send through Wear Engine message or file APIs.
        // Keep the payload shape aligned with shared/route-payload.sample.json.
        throw NotImplementedError("Wear Engine route send is not wired yet.")
    }

    override fun sendGtNavigationPayload(device: HuaweiWatchDevice, payload: GtNavigationPayload): RouteAck {
        // TODO: Serialize GtNavigationPayload and send through Wear Engine message, file, or notification APIs.
        // Keep the payload shape aligned with shared/gt-navigation-payload.sample.json.
        throw NotImplementedError("Wear Engine GT navigation send is not wired yet.")
    }

    override fun readStatus(device: HuaweiWatchDevice, routeId: String): WatchStatus {
        // TODO: Read connection, worn, charging, battery and recording state from Wear Engine
        // or app-level status messages from the watch demo.
        throw NotImplementedError("Wear Engine status read is not wired yet.")
    }
}
