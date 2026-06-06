package com.example.hiking.huawei.sync

class RouteFlowRunner(
    private val transport: RouteTransport
) {
    fun run(payload: RoutePayload): List<RouteFlowResult> {
        return transport.discoverDevices().map { device ->
            val ack = transport.sendRoutePayload(device, payload)
            val status = transport.readStatus(device, payload.routeId)

            RouteFlowResult(
                device = device,
                ack = ack,
                status = status
            )
        }
    }
}

data class RouteFlowResult(
    val device: HuaweiWatchDevice,
    val ack: RouteAck,
    val status: WatchStatus
)

