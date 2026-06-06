const state = {
  routeId: null,
  routeName: 'Waiting for route',
  nextPoint: '--',
  nextPrompt: '--',
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
  setText('nextPrompt', `Prompt: ${state.nextPrompt}`)
  setText('syncState', `Sync: ${state.syncState}`)
}

function receiveRouteSummary(payload) {
  state.routeId = payload.routeId
  state.routeName = payload.routeName
  state.nextPoint = payload.waypoints && payload.waypoints.length > 1
    ? payload.waypoints[1].name
    : payload.endName || 'finish'
  state.nextPrompt = payload.turnPrompts && payload.turnPrompts.length > 0
    ? payload.turnPrompts[0].text
    : 'follow phone navigation'
  state.syncState = 'accepted'
  render()

  return {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    deviceLine: 'GT',
    receivedAt: new Date().toISOString(),
    status: 'accepted',
    storedWaypointCount: payload.waypoints ? payload.waypoints.length : 0,
    storedPromptCount: payload.turnPrompts ? payload.turnPrompts.length : 0
  }
}

render()
