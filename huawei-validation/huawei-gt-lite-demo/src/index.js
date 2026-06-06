const state = {
  routeId: null,
  routeName: 'Waiting for route',
  nextPoint: '--',
  syncState: 'idle'
}

function setText(id, value) {
  const node = document.getElementById(id)
  if (node) {
    node.textContent = value
  }
}

function render() {
  setText('routeName', state.routeName)
  setText('nextPoint', `Next: ${state.nextPoint}`)
  setText('syncState', `Sync: ${state.syncState}`)
}

function receiveRouteSummary(payload) {
  state.routeId = payload.routeId
  state.routeName = payload.routeName
  state.nextPoint = payload.points && payload.points.length > 1 ? 'waypoint' : 'finish'
  state.syncState = 'accepted'
  render()

  return {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    deviceLine: 'GT',
    receivedAt: new Date().toISOString(),
    status: 'accepted',
    storedPointCount: payload.points ? payload.points.length : 0
  }
}

render()

