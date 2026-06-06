import { GtNavigationPayload, RouteAck, RoutePayload, WatchStatus } from './RoutePayload'

export type DeviceLine = 'WATCH' | 'GT'

export interface HuaweiWatchDevice {
  deviceId: string
  displayName: string
  deviceLine: DeviceLine
}

export interface RouteTransport {
  discoverDevices(): Promise<HuaweiWatchDevice[]>
  sendRoutePayload(device: HuaweiWatchDevice, payload: RoutePayload): Promise<RouteAck>
  sendGtNavigationPayload(device: HuaweiWatchDevice, payload: GtNavigationPayload): Promise<RouteAck>
  readStatus(device: HuaweiWatchDevice, routeId: string): Promise<WatchStatus>
}
