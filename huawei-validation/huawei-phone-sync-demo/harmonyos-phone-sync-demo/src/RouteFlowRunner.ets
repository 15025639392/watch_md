import { RoutePayload, RouteAck, WatchStatus } from './RoutePayload'
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

  async run(payload: RoutePayload): Promise<RouteFlowResult[]> {
    const devices = await this.transport.discoverDevices()
    const results: RouteFlowResult[] = []

    for (const device of devices) {
      const ack = await this.transport.sendRoutePayload(device, payload)
      const status = await this.transport.readStatus(device, payload.routeId)
      results.push({ device, ack, status })
    }

    return results
  }
}

