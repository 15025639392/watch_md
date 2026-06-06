#!/usr/bin/env node

import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = resolve(scriptDir, '..')
const watchRoutePayloadPath = resolve(rootDir, 'shared/route-payload.sample.json')
const gtNavigationPayloadPath = resolve(rootDir, 'shared/gt-navigation-payload.sample.json')

function nowIso() {
  return new Date().toISOString()
}

function ensureWatchRoutePayload(payload) {
  const errors = []

  if (payload.type !== 'routePayload') {
    errors.push('type must be routePayload')
  }
  if (payload.targetDeviceLine !== 'WATCH') {
    errors.push('targetDeviceLine must be WATCH')
  }
  if (!payload.protocolVersion) {
    errors.push('protocolVersion is required')
  }
  if (!payload.routeId) {
    errors.push('routeId is required')
  }
  if (!payload.routeName) {
    errors.push('routeName is required')
  }
  if (!Array.isArray(payload.points) || payload.points.length < 2) {
    errors.push('points must contain at least 2 points')
  }
  if (!payload.checksum) {
    errors.push('checksum is required')
  }

  if (errors.length > 0) {
    throw new Error(`Invalid WATCH route payload:\n- ${errors.join('\n- ')}`)
  }
}

function ensureGtNavigationPayload(payload) {
  const errors = []

  if (payload.type !== 'gtNavigationPayload') {
    errors.push('type must be gtNavigationPayload')
  }
  if (payload.targetDeviceLine !== 'GT') {
    errors.push('targetDeviceLine must be GT')
  }
  if (!payload.protocolVersion) {
    errors.push('protocolVersion is required')
  }
  if (!payload.routeId) {
    errors.push('routeId is required')
  }
  if (!payload.routeName) {
    errors.push('routeName is required')
  }
  if (!Array.isArray(payload.waypoints) || payload.waypoints.length < 2) {
    errors.push('waypoints must contain at least start and finish')
  }
  if (!Array.isArray(payload.turnPrompts)) {
    errors.push('turnPrompts must be an array')
  }
  if (!payload.checksum) {
    errors.push('checksum is required')
  }

  if (errors.length > 0) {
    throw new Error(`Invalid GT navigation payload:\n- ${errors.join('\n- ')}`)
  }
}

function receiveOnWatch(payload) {
  return {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    routeVersion: payload.routeVersion,
    deviceLine: 'WATCH',
    receivedAt: nowIso(),
    status: 'accepted',
    storedPointCount: payload.points.length,
    storedWaypointCount: payload.waypoints?.length ?? 0,
    checksum: payload.checksum,
    nextAction: 'awaitUserStartConfirmation'
  }
}

function receiveOnGt(payload) {
  return {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    routeVersion: payload.routeVersion,
    deviceLine: 'GT',
    receivedAt: nowIso(),
    status: 'accepted',
    storedWaypointCount: payload.waypoints.length,
    storedPromptCount: payload.turnPrompts.length,
    hasOptionalGeometry: Boolean(payload.optionalGeometry),
    checksum: payload.checksum,
    nextAction: 'renderStatusAndPrepareAlerts'
  }
}

function statusFrom(deviceLine, payload, navigationStatus) {
  return {
    type: 'watchStatus',
    protocolVersion: payload.protocolVersion,
    deviceLine,
    recordingState: 'idle',
    navigationStatus,
    batteryPercent: deviceLine === 'WATCH' ? 82 : 91,
    isWorn: true,
    isCharging: false,
    isConnectedToPhone: true,
    lastRouteId: payload.routeId,
    lastRouteVersion: payload.routeVersion,
    lastOffRouteDistanceMeters: null,
    updatedAt: nowIso()
  }
}

function printStep(title, data) {
  console.log(`\n== ${title} ==`)
  console.log(JSON.stringify(data, null, 2))
}

async function main() {
  const watchPayload = JSON.parse(await readFile(watchRoutePayloadPath, 'utf8'))
  const gtPayload = JSON.parse(await readFile(gtNavigationPayloadPath, 'utf8'))
  ensureWatchRoutePayload(watchPayload)
  ensureGtNavigationPayload(gtPayload)

  printStep('phone loads WATCH route payload', {
    routeId: watchPayload.routeId,
    routeName: watchPayload.routeName,
    pointCount: watchPayload.points.length,
    waypointCount: watchPayload.waypoints.length,
    distanceMeters: watchPayload.distanceMeters
  })

  printStep('phone sends route to WATCH demo', {
    transport: 'local-simulation',
    target: 'huawei-watch-demo',
    payloadType: watchPayload.type
  })
  printStep('WATCH ack', receiveOnWatch(watchPayload))
  printStep('WATCH status', statusFrom('WATCH', watchPayload, 'routeInstalled'))

  printStep('phone loads GT navigation payload', {
    routeId: gtPayload.routeId,
    routeName: gtPayload.routeName,
    waypointCount: gtPayload.waypoints.length,
    promptCount: gtPayload.turnPrompts.length,
    hasOptionalGeometry: Boolean(gtPayload.optionalGeometry)
  })

  printStep('phone sends route to GT lite demo', {
    transport: 'local-simulation',
    target: 'huawei-gt-lite-demo',
    payloadType: gtPayload.type
  })
  printStep('GT ack', receiveOnGt(gtPayload))
  printStep('GT status', statusFrom('GT', gtPayload, 'statusSyncReady'))

  console.log('\n[OK] Local Huawei route flow demo completed.')
}

main().catch((error) => {
  console.error(`[FAIL] ${error.message}`)
  process.exit(1)
})
