import { RouteAck, RoutePayload } from './RouteModels'

export class WearEngineBridge {
  async receiveRoutePayload(rawPayload: string): Promise<RouteAck> {
    const payload = JSON.parse(rawPayload) as RoutePayload

    return {
      type: 'routeAck',
      protocolVersion: payload.protocolVersion,
      routeId: payload.routeId,
      routeVersion: payload.routeVersion,
      deviceLine: 'WATCH',
      receivedAt: new Date().toISOString(),
      status: 'accepted',
      storedPointCount: payload.points.length,
      storedWaypointCount: payload.waypoints ? payload.waypoints.length : 0,
      checksum: payload.checksum,
      nextAction: 'awaitUserStartConfirmation'
    }
  }
}
