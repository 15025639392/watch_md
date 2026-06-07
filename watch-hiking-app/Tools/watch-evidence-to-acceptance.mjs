#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { basename } from 'node:path';
import { fileURLToPath } from 'node:url';

export function convertWatchEvidenceText(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => normalizeLine(line, index + 1))
    .map((event) => JSON.stringify(event))
    .join('\n') + '\n';
}

function normalizeLine(line, lineNumber) {
  let event;
  try {
    event = JSON.parse(line);
  } catch (error) {
    throw new Error(`Invalid JSONL at line ${lineNumber}: ${error.message}`);
  }

  switch (event.event) {
  case 'session_metadata':
    return normalizeSessionMetadata(event);
  case 'sampling_policy':
    return normalizeSamplingPolicy(event);
  case 'raw_location':
    return normalizeRawLocation(event);
  case 'barometer_window':
    return normalizeBarometerWindow(event);
  case 'device_motion_window':
    return normalizeDeviceMotionWindow(event);
  default:
    return event;
  }
}

function normalizeSessionMetadata(event) {
  const recordStart = firstNumber(
    event.recordStartElapsedRealtimeNanos,
    event.createdElapsedRealtimeNanos,
    event.eventElapsedRealtimeNanos
  );
  return omitUndefined({
    ...event,
    recordStartElapsedRealtimeNanos: recordStart
  });
}

function normalizeSamplingPolicy(event) {
  return omitUndefined({
    ...event,
    samplingEpochStartedElapsedRealtimeNanos: firstNumber(
      event.samplingEpochStartedElapsedRealtimeNanos,
      event.locationRequestRegisteredElapsedRealtimeNanos,
      event.eventElapsedRealtimeNanos
    ),
    requestedMinDistanceMeters: firstNumber(
      event.requestedMinDistanceMeters,
      event.locationRequestMinDistanceMeters,
      event.distanceFilterMeters
    ),
    locationRequestMinDistanceMeters: firstNumber(
      event.locationRequestMinDistanceMeters,
      event.requestedMinDistanceMeters,
      event.distanceFilterMeters
    ),
    requestedMinTimeMs: firstNumber(
      event.requestedMinTimeMs,
      event.locationRequestMinTimeMs,
      event.requestIntervalMillis,
      event.requestedIntervalMillis
    ),
    locationRequestMinTimeMs: firstNumber(
      event.locationRequestMinTimeMs,
      event.requestedMinTimeMs,
      event.requestIntervalMillis,
      event.requestedIntervalMillis
    )
  });
}

function normalizeRawLocation(event) {
  const elapsedRealtimeNanos = firstNumber(
    event.elapsedRealtimeNanos,
    event.estimatedFixElapsedRealtimeNanos,
    event.receivedElapsedRealtimeNanos,
    event.eventElapsedRealtimeNanos
  );
  return omitUndefined({
    ...event,
    provider: event.provider ?? 'core_location',
    elapsedRealtimeNanos,
    callbackReceivedElapsedRealtimeNanos: firstNumber(
      event.callbackReceivedElapsedRealtimeNanos,
      event.receivedElapsedRealtimeNanos
    )
  });
}

function normalizeBarometerWindow(event) {
  const avgPressureHpa = firstNumber(
    event.avgPressureHpa,
    kpaToHpa(event.avgPressureKpa)
  );
  const avgRawBarometerAltitudeMeters = firstNumber(
    event.avgRawBarometerAltitudeMeters,
    event.avgRelativeAltitudeMeters
  );
  return omitUndefined({
    ...event,
    avgPressureHpa,
    minPressureHpa: firstNumber(event.minPressureHpa, kpaToHpa(event.minPressureKpa)),
    maxPressureHpa: firstNumber(event.maxPressureHpa, kpaToHpa(event.maxPressureKpa)),
    deltaRawBarometerAltitudeMeters: firstNumber(
      event.deltaRawBarometerAltitudeMeters,
      event.deltaRawAltitudeMeters,
      event.deltaRelativeAltitudeMeters
    ),
    avgRawBarometerAltitudeMeters
  });
}

function normalizeDeviceMotionWindow(event) {
  return omitUndefined({
    ...event,
    firstElapsedRealtimeNanos: firstNumber(
      event.firstElapsedRealtimeNanos,
      event.startElapsedRealtimeNanos
    ),
    lastElapsedRealtimeNanos: firstNumber(
      event.lastElapsedRealtimeNanos,
      event.endElapsedRealtimeNanos
    ),
    linearAccelerationRmsMps2: firstNumber(
      event.linearAccelerationRmsMps2,
      event.accelerometerDynamicRmsMps2,
      event.dynamicAccelRmsMps2
    ),
    linearAccelerationMaxMps2: firstNumber(
      event.linearAccelerationMaxMps2,
      event.accelerometerDynamicMaxMps2
    ),
    stepDetectorCount: firstNumber(event.stepDetectorCount, event.stepCounterDelta)
  });
}

function firstNumber(...values) {
  for (const value of values) {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
  }
  return undefined;
}

function kpaToHpa(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value * 10 : undefined;
}

function omitUndefined(object) {
  return Object.fromEntries(
    Object.entries(object).filter(([, value]) => value !== undefined)
  );
}

function runCli() {
  const args = process.argv.slice(2);
  if (args.length < 1 || args.includes('-h') || args.includes('--help')) {
    printUsage();
    process.exit(args.length < 1 ? 1 : 0);
  }

  const input = args[0];
  const output = args[1] ?? input.replace(/\.jsonl(?:\.json)?$/i, '.acceptance.jsonl');
  if (input === output) {
    throw new Error('Output path must be different from input path.');
  }

  const converted = convertWatchEvidenceText(readFileSync(input, 'utf8'));
  writeFileSync(output, converted, 'utf8');
  console.log(`Converted ${basename(input)} -> ${output}`);
}

function printUsage() {
  console.log('Usage: node Tools/watch-evidence-to-acceptance.mjs <watch.evidence.jsonl> [output.acceptance.jsonl]');
}

const invokedPath = process.argv[1] ? fileURLToPath(new URL(`file://${process.argv[1]}`)) : '';
if (invokedPath === fileURLToPath(import.meta.url)) {
  runCli();
}
