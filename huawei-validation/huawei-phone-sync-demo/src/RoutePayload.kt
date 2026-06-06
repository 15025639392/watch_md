package com.example.hiking.huawei.sync

data class RoutePoint(
    val lat: Double,
    val lon: Double,
    val ele: Double? = null,
    val role: String? = null
)

data class RouteAlert(
    val kind: String,
    val thresholdMeters: Double? = null
)

data class RoutePayload(
    val type: String = "routePayload",
    val protocolVersion: String,
    val routeId: String,
    val routeName: String,
    val source: String,
    val sentAt: String,
    val distanceMeters: Double,
    val ascentMeters: Double? = null,
    val points: List<RoutePoint>,
    val alerts: List<RouteAlert> = emptyList()
)

data class RouteAck(
    val type: String = "routeAck",
    val protocolVersion: String,
    val routeId: String,
    val deviceLine: String,
    val receivedAt: String,
    val status: String,
    val storedPointCount: Int
)

