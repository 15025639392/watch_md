import { RouteAck, RoutePayload, WatchStatus } from './RoutePayload'
import { HuaweiWatchDevice, RouteTransport } from './RouteTransport'

export class LocalSimulationTransport implements RouteTransport {
  async discoverDevices(): Promise<HuaweiWatchDevice[]> {
    return [
      {
        deviceId: 'local-watch-demo',
        displayName: 'Local WATCH Demo',
        deviceLine: 'WATCH'
      },
      {
        deviceId: 'local-gt-lite-demo',
        displayName: 'Local GT Lite Demo',
        deviceLine: 'GT'
      }
    ]
  }

  async sendRoutePayload(device: HuaweiWatchDevice, payload: RoutePayload): Promise<RouteAck> {
    return {
      type: 'routeAck',
      protocolVersion: payload.protocolVersion,
      routeId: payload.routeId,
      deviceLine: device.deviceLine,
      receivedAt: new Date().toISOString(),
      status: 'accepted',
      storedPointCount: payload.points.length
    }
  }

  async readStatus(device: HuaweiWatchDevice, routeId: string): Promise<WatchStatus> {
    return {
      type: 'watchStatus',
      protocolVersion: '0.1',
      deviceLine: device.deviceLine,
      recordingState: 'idle',
      batteryPercent: device.deviceLine === 'WATCH' ? 82 : 91,
      isWorn: true,
      isCharging: false,
      lastRouteId: routeId,
      updatedAt: new Date().toISOString()
    }
  }
}

