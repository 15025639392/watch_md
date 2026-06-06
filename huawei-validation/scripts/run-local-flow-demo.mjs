#!/usr/bin/env node

import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = resolve(scriptDir, '..')
const routePayloadPath = resolve(rootDir, 'shared/route-payload.sample.json')

function nowIso() {
  return new Date().toISOString()
}

function ensureRoutePayload(payload) {
  const errors = []

  if (payload.type !== 'routePayload') {
    errors.push('type must be routePayload')
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

  if (errors.length > 0) {
    throw new Error(`Invalid route payload:\n- ${errors.join('\n- ')}`)
  }
}

function receiveOnWatch(payload) {
  return {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    deviceLine: 'WATCH',
    receivedAt: nowIso(),
    status: 'accepted',
    storedPointCount: payload.points.length,
    nextAction: 'renderRouteAndStartLocationProbe'
  }
}

function receiveOnGt(payload) {
  return {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    deviceLine: 'GT',
    receivedAt: nowIso(),
    status: 'accepted',
    storedPointCount: payload.points.length,
    nextAction: 'renderNextWaypointAndPrepareAlerts'
  }
}

function statusFrom(deviceLine, payload) {
  return {
    type: 'watchStatus',
    protocolVersion: payload.protocolVersion,
    deviceLine,
    recordingState: 'idle',
    batteryPercent: deviceLine === 'WATCH' ? 82 : 91,
    isWorn: true,
    isCharging: false,
    lastRouteId: payload.routeId,
    updatedAt: nowIso()
  }
}

function printStep(title, data) {
  console.log(`\n== ${title} ==`)
  console.log(JSON.stringify(data, null, 2))
}

async function main() {
  const payload = JSON.parse(await readFile(routePayloadPath, 'utf8'))
  ensureRoutePayload(payload)

  printStep('phone loads route payload', {
    routeId: payload.routeId,
    routeName: payload.routeName,
    pointCount: payload.points.length,
    distanceMeters: payload.distanceMeters
  })

  printStep('phone sends route to WATCH demo', {
    transport: 'local-simulation',
    target: 'huawei-watch-demo',
    payloadType: payload.type
  })
  printStep('WATCH ack', receiveOnWatch(payload))
  printStep('WATCH status', statusFrom('WATCH', payload))

  printStep('phone sends route to GT lite demo', {
    transport: 'local-simulation',
    target: 'huawei-gt-lite-demo',
    payloadType: payload.type
  })
  printStep('GT ack', receiveOnGt(payload))
  printStep('GT status', statusFrom('GT', payload))

  console.log('\n[OK] Local Huawei route flow demo completed.')
}

main().catch((error) => {
  console.error(`[FAIL] ${error.message}`)
  process.exit(1)
})

