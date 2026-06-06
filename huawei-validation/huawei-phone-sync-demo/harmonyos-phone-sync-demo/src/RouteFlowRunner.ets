import { GtNavigationPayload, RoutePayload, RouteAck, WatchStatus } from './RoutePayload'
import { HuaweiWatchDevice, RouteTransport } from './RouteTransport'

export interface RouteFlowResult {
  device: HuaweiWatchDevice
  ack: RouteAck
  status: WatchStatus
}

export class RouteFlowRunner {
  private transport: RouteTransport

  constructor(transport: RouteTransport) {
    this.transport = transport
  }

  async run(watchPayload: RoutePayload, gtPayload: GtNavigationPayload): Promise<RouteFlowResult[]> {
    const devices = await this.transport.discoverDevices()
    const results: RouteFlowResult[] = []

    for (const device of devices) {
      const ack = device.deviceLine === 'GT'
        ? await this.transport.sendGtNavigationPayload(device, gtPayload)
        : await this.transport.sendRoutePayload(device, watchPayload)
      const status = await this.transport.readStatus(device, ack.routeId)
      results.push({ device, ack, status })
    }

    return results
  }
}
