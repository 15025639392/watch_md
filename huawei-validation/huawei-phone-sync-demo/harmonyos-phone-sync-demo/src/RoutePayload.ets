export interface RoutePoint {
  lat: number
  lon: number
  ele?: number
  role?: string
}

export interface RouteAlert {
  kind: string
  thresholdMeters?: number
}

export interface RoutePayload {
  type: 'routePayload'
  protocolVersion: string
  routeId: string
  routeName: string
  source: string
  sentAt: string
  distanceMeters: number
  ascentMeters?: number
  points: RoutePoint[]
  alerts?: RouteAlert[]
}

export interface RouteAck {
  type: 'routeAck'
  protocolVersion: string
  routeId: string
  deviceLine: string
  receivedAt: string
  status: string
  storedPointCount: number
}

export interface WatchStatus {
  type: 'watchStatus'
  protocolVersion: string
  deviceLine: string
  recordingState: string
  batteryPercent: number
  isWorn: boolean
  isCharging: boolean
  lastRouteId: string
  updatedAt: string
}

