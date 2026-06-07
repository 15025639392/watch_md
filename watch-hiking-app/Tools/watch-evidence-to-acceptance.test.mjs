import test from 'node:test';
import assert from 'node:assert/strict';

import { convertWatchEvidenceText } from './watch-evidence-to-acceptance.mjs';

test('converts watch evidence fields to acceptance-web compatible aliases', () => {
  const converted = convertWatchEvidenceText([
    '{"event":"session_metadata","sessionId":"S1","createdElapsedRealtimeNanos":1000}',
    '{"event":"sampling_policy","samplingEpochId":1,"state":"MOVING_STANDARD","eventElapsedRealtimeNanos":1000,"distanceFilterMeters":5}',
    '{"event":"raw_location","rawPointId":1,"provider":"core_location","lat":30,"lng":120,"accuracy":5,"estimatedFixElapsedRealtimeNanos":2000,"receivedElapsedRealtimeNanos":2100}',
    '{"event":"barometer_window","barometerWindowId":1,"avgPressureKpa":99.5,"avgRelativeAltitudeMeters":12,"deltaRelativeAltitudeMeters":3}',
    '{"event":"device_motion_window","deviceMotionWindowId":1,"startElapsedRealtimeNanos":1000,"endElapsedRealtimeNanos":2000,"accelerometerDynamicRmsMps2":0.3,"accelerometerDynamicMaxMps2":0.7,"gyroscopeRmsRadps":0.1}'
  ].join('\n'));

  const events = converted.trim().split('\n').map((line) => JSON.parse(line));

  assert.equal(events[0].recordStartElapsedRealtimeNanos, 1000);
  assert.equal(events[1].samplingEpochStartedElapsedRealtimeNanos, 1000);
  assert.equal(events[1].requestedMinDistanceMeters, 5);
  assert.equal(events[2].elapsedRealtimeNanos, 2000);
  assert.equal(events[2].callbackReceivedElapsedRealtimeNanos, 2100);
  assert.equal(events[3].avgPressureHpa, 995);
  assert.equal(events[3].avgRawBarometerAltitudeMeters, 12);
  assert.equal(events[3].deltaRawBarometerAltitudeMeters, 3);
  assert.equal(events[4].linearAccelerationRmsMps2, 0.3);
  assert.equal(events[4].linearAccelerationMaxMps2, 0.7);
});
