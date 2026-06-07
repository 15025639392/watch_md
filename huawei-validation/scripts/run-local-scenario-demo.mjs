#!/usr/bin/env node

import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rootDir = resolve(scriptDir, '..')
const outputDir = resolve(rootDir, 'generated/local-simulation')
const watchRoutePayloadPath = resolve(rootDir, 'shared/route-payload.sample.json')
const gtNavigationPayloadPath = resolve(rootDir, 'shared/gt-navigation-payload.sample.json')

function nowIso() {
  return new Date().toISOString()
}

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function assertPayload(condition, message) {
  if (!condition) {
    throw new Error(message)
  }
}

function ensureWatchRoutePayload(payload) {
  assertPayload(payload.type === 'routePayload', 'WATCH payload type must be routePayload')
  assertPayload(payload.targetDeviceLine === 'WATCH', 'WATCH payload targetDeviceLine must be WATCH')
  assertPayload(Boolean(payload.protocolVersion), 'WATCH payload protocolVersion is required')
  assertPayload(Boolean(payload.routeId), 'WATCH payload routeId is required')
  assertPayload(Boolean(payload.routeName), 'WATCH payload routeName is required')
  assertPayload(Array.isArray(payload.points) && payload.points.length >= 2, 'WATCH payload points must contain at least 2 points')
  assertPayload(Boolean(payload.checksum), 'WATCH payload checksum is required')
}

function ensureGtNavigationPayload(payload) {
  assertPayload(payload.type === 'gtNavigationPayload', 'GT payload type must be gtNavigationPayload')
  assertPayload(payload.targetDeviceLine === 'GT', 'GT payload targetDeviceLine must be GT')
  assertPayload(Boolean(payload.protocolVersion), 'GT payload protocolVersion is required')
  assertPayload(Boolean(payload.routeId), 'GT payload routeId is required')
  assertPayload(Boolean(payload.routeName), 'GT payload routeName is required')
  assertPayload(Array.isArray(payload.waypoints) && payload.waypoints.length >= 2, 'GT payload waypoints must contain at least 2 points')
  assertPayload(Array.isArray(payload.turnPrompts), 'GT payload turnPrompts must be an array')
  assertPayload(Boolean(payload.checksum), 'GT payload checksum is required')
}

function createAck(deviceLine, payload) {
  const common = {
    type: 'routeAck',
    protocolVersion: payload.protocolVersion,
    routeId: payload.routeId,
    routeVersion: payload.routeVersion,
    deviceLine,
    receivedAt: nowIso(),
    status: 'accepted',
    checksum: payload.checksum
  }

  if (deviceLine === 'WATCH') {
    return {
      ...common,
      storedPointCount: payload.points.length,
      storedWaypointCount: payload.waypoints?.length ?? 0,
      nextAction: 'awaitUserStartConfirmation'
    }
  }

  return {
    ...common,
    storedWaypointCount: payload.waypoints.length,
    storedPromptCount: payload.turnPrompts.length,
    hasOptionalGeometry: Boolean(payload.optionalGeometry),
    nextAction: 'renderStatusAndPrepareAlerts'
  }
}

function createStatus(deviceLine, payload, overrides = {}) {
  return {
    type: 'watchStatus',
    protocolVersion: payload.protocolVersion,
    deviceLine,
    recordingState: 'idle',
    navigationStatus: deviceLine === 'WATCH' ? 'routeInstalled' : 'statusSyncReady',
    batteryPercent: deviceLine === 'WATCH' ? 82 : 91,
    isWorn: true,
    isCharging: false,
    isConnectedToPhone: true,
    lastRouteId: payload.routeId,
    lastRouteVersion: payload.routeVersion,
    lastOffRouteDistanceMeters: null,
    updatedAt: nowIso(),
    ...overrides
  }
}

function event(scenarioId, step, status, detail) {
  return {
    at: nowIso(),
    scenarioId,
    step,
    status,
    detail
  }
}

function runHappyPath(watchPayload, gtPayload) {
  const events = []
  events.push(event('happy-path', 'discoverDevices', 'ok', {
    devices: ['local-watch-demo', 'local-gt-lite-demo']
  }))
  events.push(event('happy-path', 'sendWatchRoute', 'ok', createAck('WATCH', watchPayload)))
  events.push(event('happy-path', 'readWatchStatus', 'ok', createStatus('WATCH', watchPayload)))
  events.push(event('happy-path', 'sendGtNavigation', 'ok', createAck('GT', gtPayload)))
  events.push(event('happy-path', 'readGtStatus', 'ok', createStatus('GT', gtPayload)))
  return events
}

function runWatchDisconnectedThenRetry(watchPayload) {
  const events = []
  events.push(event('watch-disconnected-retry', 'discoverDevices', 'ok', {
    devices: ['local-watch-demo']
  }))
  events.push(event('watch-disconnected-retry', 'sendWatchRoute', 'retryableError', {
    deviceId: 'local-watch-demo',
    errorCode: 'deviceDisconnected',
    nextAction: 'waitForReconnectAndRetry'
  }))
  events.push(event('watch-disconnected-retry', 'deviceReconnect', 'ok', {
    deviceId: 'local-watch-demo',
    isConnectedToPhone: true
  }))
  events.push(event('watch-disconnected-retry', 'sendWatchRouteRetry', 'ok', createAck('WATCH', watchPayload)))
  events.push(event('watch-disconnected-retry', 'readWatchStatus', 'ok', createStatus('WATCH', watchPayload)))
  return events
}

function runGtLowBattery(watchPayload, gtPayload) {
  const events = []
  events.push(event('gt-low-battery', 'discoverDevices', 'ok', {
    devices: ['local-watch-demo', 'local-gt-lite-demo']
  }))
  events.push(event('gt-low-battery', 'sendGtNavigation', 'ok', createAck('GT', gtPayload)))
  events.push(event('gt-low-battery', 'readGtStatus', 'warning', createStatus('GT', gtPayload, {
    batteryPercent: 14,
    navigationStatus: 'statusSyncReadyLowBattery'
  })))
  events.push(event('gt-low-battery', 'sendWatchRoute', 'ok', createAck('WATCH', watchPayload)))
  return events
}

function runInvalidWatchPayload(watchPayload) {
  const invalidPayload = clone(watchPayload)
  invalidPayload.points = [invalidPayload.points[0]]

  try {
    ensureWatchRoutePayload(invalidPayload)
    return [event('invalid-watch-payload', 'validateWatchPayload', 'unexpectedOk', {})]
  } catch (error) {
    return [event('invalid-watch-payload', 'validateWatchPayload', 'rejected', {
      errorCode: 'invalidPayload',
      message: error.message,
      nextAction: 'fixPayloadBeforeTransport'
    })]
  }
}

function summarize(events) {
  const scenarioIds = [...new Set(events.map((item) => item.scenarioId))]
  return {
    generatedAt: nowIso(),
    protocolVersion: '0.1',
    transport: 'local-simulation',
    scenarioCount: scenarioIds.length,
    eventCount: events.length,
    scenarios: scenarioIds.map((scenarioId) => {
      const scenarioEvents = events.filter((item) => item.scenarioId === scenarioId)
      return {
        scenarioId,
        status: scenarioEvents.some((item) => item.status === 'unexpectedOk') ? 'failed' : 'completed',
        eventCount: scenarioEvents.length,
        warnings: scenarioEvents.filter((item) => item.status === 'warning').length,
        retryableErrors: scenarioEvents.filter((item) => item.status === 'retryableError').length,
        rejectedInputs: scenarioEvents.filter((item) => item.status === 'rejected').length
      }
    })
  }
}

function eventOutcomeLabel(item) {
  if (item.status === 'ok') {
    return '通过'
  }
  if (item.status === 'warning') {
    return '警告'
  }
  if (item.status === 'retryableError') {
    return '可重试错误'
  }
  if (item.status === 'rejected') {
    return '已拒绝'
  }
  return item.status
}

function describeEventDetail(item) {
  const detail = item.detail ?? {}

  if (detail.errorCode) {
    return `${detail.errorCode}${detail.nextAction ? ` / ${detail.nextAction}` : ''}`
  }
  if (detail.type === 'routeAck') {
    const stored = [
      detail.storedPointCount != null ? `points=${detail.storedPointCount}` : null,
      detail.storedWaypointCount != null ? `waypoints=${detail.storedWaypointCount}` : null,
      detail.storedPromptCount != null ? `prompts=${detail.storedPromptCount}` : null
    ].filter(Boolean).join(', ')
    return `${detail.deviceLine} ACK accepted${stored ? ` (${stored})` : ''}`
  }
  if (detail.type === 'watchStatus') {
    return `${detail.deviceLine} ${detail.navigationStatus}, battery=${detail.batteryPercent}%`
  }
  if (Array.isArray(detail.devices)) {
    return `devices=${detail.devices.join(', ')}`
  }
  if (detail.deviceId) {
    return `${detail.deviceId}${detail.isConnectedToPhone != null ? ` connected=${detail.isConnectedToPhone}` : ''}`
  }

  return '-'
}

function renderReport(summary, events) {
  const lines = [
    '# Huawei Local Scenario Simulation Report',
    '',
    `Generated at: ${summary.generatedAt}`,
    '',
    'This report is produced by local simulation only. It does not prove real Wear Engine communication.',
    '',
    '## Summary',
    '',
    '| Item | Value |',
    '| --- | --- |',
    `| Transport | ${summary.transport} |`,
    `| Protocol version | ${summary.protocolVersion} |`,
    `| Scenario count | ${summary.scenarioCount} |`,
    `| Event count | ${summary.eventCount} |`,
    '',
    '## Scenarios',
    '',
    '| Scenario | Status | Events | Warnings | Retryable errors | Rejected inputs |',
    '| --- | --- | ---: | ---: | ---: | ---: |'
  ]

  for (const scenario of summary.scenarios) {
    lines.push(`| ${scenario.scenarioId} | ${scenario.status} | ${scenario.eventCount} | ${scenario.warnings} | ${scenario.retryableErrors} | ${scenario.rejectedInputs} |`)
  }

  lines.push('', '## Event Timeline', '')

  for (const scenario of summary.scenarios) {
    const scenarioEvents = events.filter((item) => item.scenarioId === scenario.scenarioId)
    lines.push(`### ${scenario.scenarioId}`, '')
    lines.push('| Step | Outcome | Detail |')
    lines.push('| --- | --- | --- |')
    for (const item of scenarioEvents) {
      lines.push(`| ${item.step} | ${eventOutcomeLabel(item)} | ${describeEventDetail(item)} |`)
    }
    lines.push('')
  }

  lines.push('## Next Real-Device Mapping', '')
  lines.push('| Local event | Wear Engine true-device evidence to capture |')
  lines.push('| --- | --- |')
  lines.push('| `discoverDevices` | Device id, model, connection state, worn state and battery from paired device discovery/status APIs |')
  lines.push('| `sendWatchRoute` / `sendGtNavigation` | Actual send API result, payload size, retry count and elapsed time |')
  lines.push('| `routeAck` | First ACK JSON returned by the watch app, including route id/version/checksum |')
  lines.push('| `watchStatus` | First status JSON returned by the watch app, including battery, worn, charging and route state |')
  lines.push('| `retryableError` | Real disconnection reason and whether automatic retry succeeds |')
  lines.push('')

  return `${lines.join('\n')}\n`
}

async function main() {
  const watchPayload = JSON.parse(await readFile(watchRoutePayloadPath, 'utf8'))
  const gtPayload = JSON.parse(await readFile(gtNavigationPayloadPath, 'utf8'))
  ensureWatchRoutePayload(watchPayload)
  ensureGtNavigationPayload(gtPayload)

  const events = [
    ...runHappyPath(watchPayload, gtPayload),
    ...runWatchDisconnectedThenRetry(watchPayload),
    ...runGtLowBattery(watchPayload, gtPayload),
    ...runInvalidWatchPayload(watchPayload)
  ]
  const summary = summarize(events)

  await mkdir(outputDir, { recursive: true })
  await writeFile(resolve(outputDir, 'events.jsonl'), `${events.map((item) => JSON.stringify(item)).join('\n')}\n`)
  await writeFile(resolve(outputDir, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`)
  await writeFile(resolve(outputDir, 'report.md'), renderReport(summary, events))

  console.log(JSON.stringify(summary, null, 2))
  console.log(`\n[OK] Local Huawei scenario demo wrote ${events.length} events to ${outputDir}`)
}

main().catch((error) => {
  console.error(`[FAIL] ${error.message}`)
  process.exit(1)
})
