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

export interface RouteAck {
  type: 'routeAck'
  protocolVersion: string
  routeId: string
  routeVersion?: number
  deviceLine: 'WATCH'
  receivedAt: string
  status: 'accepted' | 'rejected'
  storedPointCount: number
  storedWaypointCount?: number
  checksum?: string
  nextAction?: string
}
