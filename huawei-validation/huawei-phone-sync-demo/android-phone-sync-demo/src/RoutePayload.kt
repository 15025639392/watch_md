package com.example.hiking.huawei.sync

data class RoutePoint(
    val index: Int? = null,
    val lat: Double,
    val lon: Double,
    val ele: Double? = null,
    val distanceFromStartMeters: Double? = null,
    val role: String? = null
)

data class RouteWaypoint(
    val waypointId: String,
    val name: String,
    val kind: String,
    val distanceFromStartMeters: Double? = null,
    val alertDistanceMeters: Double? = null
)

data class TurnPrompt(
    val promptId: String,
    val distanceFromStartMeters: Double,
    val direction: String,
    val text: String,
    val alertDistanceMeters: Double? = null
)

data class RouteAlert(
    val kind: String,
    val thresholdMeters: Double? = null,
    val returnThresholdMeters: Double? = null,
    val confirmPointCount: Int? = null
)

data class RoutePayload(
    val type: String = "routePayload",
    val protocolVersion: String,
    val targetDeviceLine: String = "WATCH",
    val routeId: String,
    val routeVersion: Int,
    val routeName: String,
    val source: String,
    val sentAt: String,
    val distanceMeters: Double,
    val ascentMeters: Double? = null,
    val estimatedDurationSeconds: Int? = null,
    val startName: String? = null,
    val endName: String? = null,
    val checksum: String,
    val routeVariant: String? = null,
    val points: List<RoutePoint>,
    val waypoints: List<RouteWaypoint> = emptyList(),
    val alerts: List<RouteAlert> = emptyList()
)

data class GtNavigationPayload(
    val type: String = "gtNavigationPayload",
    val protocolVersion: String,
    val targetDeviceLine: String = "GT",
    val routeId: String,
    val routeVersion: Int,
    val routeName: String,
    val source: String,
    val sentAt: String,
    val expiresAt: String? = null,
    val distanceMeters: Double,
    val ascentMeters: Double? = null,
    val estimatedDurationSeconds: Int? = null,
    val startName: String? = null,
    val endName: String? = null,
    val checksum: String,
    val offRouteThresholdMeters: Double,
    val waypoints: List<RouteWaypoint>,
    val turnPrompts: List<TurnPrompt>
)

data class RouteAck(
    val type: String = "routeAck",
    val protocolVersion: String,
    val routeId: String,
    val routeVersion: Int? = null,
    val deviceLine: String,
    val receivedAt: String,
    val status: String,
    val storedPointCount: Int? = null,
    val storedWaypointCount: Int? = null,
    val storedPromptCount: Int? = null,
    val checksum: String? = null,
    val nextAction: String? = null
)

data class WatchStatus(
    val type: String = "watchStatus",
    val protocolVersion: String,
    val deviceLine: String,
    val recordingState: String,
    val navigationStatus: String? = null,
    val batteryPercent: Int,
    val isWorn: Boolean,
    val isCharging: Boolean,
    val isConnectedToPhone: Boolean? = null,
    val lastRouteId: String,
    val lastRouteVersion: Int? = null,
    val lastOffRouteDistanceMeters: Double? = null,
    val updatedAt: String
)
