export interface RoutePoint {
  index?: number
  lat: number
  lon: number
  ele?: number
  distanceFromStartMeters?: number
  role?: string
}

export interface RouteWaypoint {
  waypointId: string
  name: string
  kind: string
  distanceFromStartMeters?: number
  alertDistanceMeters?: number
}

export interface TurnPrompt {
  promptId: string
  distanceFromStartMeters: number
  direction: string
  text: string
  alertDistanceMeters?: number
}

export interface RouteAlert {
  kind: string
  thresholdMeters?: number
  returnThresholdMeters?: number
  confirmPointCount?: number
}

export interface RoutePayload {
  type: 'routePayload'
  protocolVersion: string
  targetDeviceLine: 'WATCH'
  routeId: string
  routeVersion: number
  routeName: string
  source: string
  sentAt: string
  distanceMeters: number
  ascentMeters?: number
  estimatedDurationSeconds?: number
  startName?: string
  endName?: string
  checksum: string
  routeVariant?: string
  points: RoutePoint[]
  waypoints?: RouteWaypoint[]
  alerts?: RouteAlert[]
}

export interface GtNavigationPayload {
  type: 'gtNavigationPayload'
  protocolVersion: string
  targetDeviceLine: 'GT'
  routeId: string
  routeVersion: number
  routeName: string
  source: string
  sentAt: string
  expiresAt?: string
  distanceMeters: number
  ascentMeters?: number
  estimatedDurationSeconds?: number
  startName?: string
  endName?: string
  checksum: string
  offRouteThresholdMeters: number
  waypoints: RouteWaypoint[]
  turnPrompts: TurnPrompt[]
}

export interface RouteAck {
  type: 'routeAck'
  protocolVersion: string
  routeId: string
  routeVersion?: number
  deviceLine: string
  receivedAt: string
  status: string
  storedPointCount?: number
  storedWaypointCount?: number
  storedPromptCount?: number
  checksum?: string
  nextAction?: string
}

export interface WatchStatus {
  type: 'watchStatus'
  protocolVersion: string
  deviceLine: string
  recordingState: string
  navigationStatus?: string
  batteryPercent: number
  isWorn: boolean
  isCharging: boolean
  isConnectedToPhone?: boolean
  lastRouteId: string
  lastRouteVersion?: number
  lastOffRouteDistanceMeters?: number
  updatedAt: string
}
