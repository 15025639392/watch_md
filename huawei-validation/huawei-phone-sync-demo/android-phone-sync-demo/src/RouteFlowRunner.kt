package com.example.hiking.huawei.sync

class RouteFlowRunner(
    private val transport: RouteTransport
) {
    fun run(watchPayload: RoutePayload, gtPayload: GtNavigationPayload): List<RouteFlowResult> {
        return transport.discoverDevices().map { device ->
            val ack = if (device.deviceLine == DeviceLine.GT) {
                transport.sendGtNavigationPayload(device, gtPayload)
            } else {
                transport.sendRoutePayload(device, watchPayload)
            }
            val status = transport.readStatus(device, ack.routeId)

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
