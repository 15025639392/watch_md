import { GtNavigationPayload, RouteAck, RoutePayload, WatchStatus } from './RoutePayload'
import { HuaweiWatchDevice, RouteTransport } from './RouteTransport'

export class WearEngineRouteTransport implements RouteTransport {
  async discoverDevices(): Promise<HuaweiWatchDevice[]> {
    // TODO: Replace with HarmonyOS / HMS Wear Engine device discovery.
    return []
  }

  async sendRoutePayload(_device: HuaweiWatchDevice, _payload: RoutePayload): Promise<RouteAck> {
    // TODO: Serialize RoutePayload and send through Wear Engine message or file APIs.
    throw new Error('Wear Engine route send is not wired yet.')
  }

  async sendGtNavigationPayload(_device: HuaweiWatchDevice, _payload: GtNavigationPayload): Promise<RouteAck> {
    // TODO: Serialize GtNavigationPayload and send through Wear Engine message, file, or notification APIs.
    throw new Error('Wear Engine GT navigation send is not wired yet.')
  }

  async readStatus(_device: HuaweiWatchDevice, _routeId: string): Promise<WatchStatus> {
    // TODO: Read status from Wear Engine or app-level status messages.
    throw new Error('Wear Engine status read is not wired yet.')
  }
}
