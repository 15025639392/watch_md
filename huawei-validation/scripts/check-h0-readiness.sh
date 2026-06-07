#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEVECO_STUDIO_HOME="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app/Contents}"
HUAWEI_SDK_ROOT="${HUAWEI_SDK_ROOT:-$HOME/Library/Huawei/Sdk}"
OHOS_SDK_HOME="${OHOS_SDK_HOME:-$DEVECO_STUDIO_HOME/sdk/default/openharmony}"
EMULATOR_JSON="$DEVECO_STUDIO_HOME/tools/emulator/emulator.json"
EMULATOR_BIN="$DEVECO_STUDIO_HOME/tools/emulator/Emulator"
HDC_BIN="$OHOS_SDK_HOME/toolchains/hdc"

failures=0
warnings=0

info() {
  printf '%s\n' "$*"
}

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
  warnings=$((warnings + 1))
}

fail() {
  printf '[FAIL] %s\n' "$*"
  failures=$((failures + 1))
}

run_with_timeout() {
  local label="$1"
  local timeout_seconds="$2"
  shift 2

  local output_file
  output_file="$(mktemp)"

  "$@" >"$output_file" 2>&1 &
  local pid=$!

  (
    sleep "$timeout_seconds"
    kill "$pid" >/dev/null 2>&1
  ) &
  local killer=$!

  wait "$pid"
  local status=$?
  kill "$killer" >/dev/null 2>&1
  wait "$killer" 2>/dev/null

  local output
  output="$(sed -n '1,12p' "$output_file")"
  rm -f "$output_file"

  if [ "$status" -eq 143 ] || [ "$status" -eq 137 ]; then
    warn "$label did not finish within ${timeout_seconds}s"
    return 124
  fi

  if [ "$status" -ne 0 ]; then
    warn "$label exited with status $status"
  else
    ok "$label"
  fi

  if [ -n "$output" ]; then
    printf '%s\n' "$output" | sed 's/^/  /'
  fi

  return "$status"
}

info 'Huawei validation H0 readiness check'
info "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
info ''

info 'DevEco / SDK'
if [ -d "$DEVECO_STUDIO_HOME" ]; then
  ok "DevEco Studio home: $DEVECO_STUDIO_HOME"
else
  fail "DevEco Studio home missing: $DEVECO_STUDIO_HOME"
fi

if [ -x "$EMULATOR_BIN" ]; then
  ok "Emulator binary: $EMULATOR_BIN"
else
  fail "Emulator binary missing: $EMULATOR_BIN"
fi

if [ -f "$EMULATOR_JSON" ]; then
  ok "Emulator template list: $EMULATOR_JSON"
  if grep -q '"Huawei_Wearable"' "$EMULATOR_JSON"; then
    ok 'Huawei_Wearable template is available'
  else
    warn 'Huawei_Wearable template was not found in emulator.json'
  fi
else
  fail "Emulator template list missing: $EMULATOR_JSON"
fi
info ''

info 'Wearable system image'
watch_images="$(find "$HUAWEI_SDK_ROOT/system-image" -maxdepth 3 -type d \( -iname '*wearable*' -o -iname '*watch*' \) 2>/dev/null | sort)"
if [ -n "$watch_images" ]; then
  ok 'Wearable/watch system image is installed'
  printf '%s\n' "$watch_images" | sed 's/^/  /'
else
  warn 'Wearable/watch system image is not installed'
  info '  Open DevEco Studio > Device Manager and create Huawei_Wearable API 24, 466x466.'
fi
info ''

info 'hdc targets'
if [ -x "$HDC_BIN" ]; then
  run_with_timeout 'hdc list targets' 8 "$HDC_BIN" list targets || true
else
  fail "hdc missing: $HDC_BIN"
fi
info ''

info 'Import bundle'
if node "$ROOT_DIR/huawei-validation/scripts/prepare-real-project-import.mjs" >/tmp/huawei-import-bundle.log 2>&1; then
  ok 'Real project import bundle generated'
  sed -n '1,10p' /tmp/huawei-import-bundle.log | sed 's/^/  /'
else
  fail 'Real project import bundle generation failed'
  sed -n '1,20p' /tmp/huawei-import-bundle.log | sed 's/^/  /'
fi
rm -f /tmp/huawei-import-bundle.log
info ''

info 'Local protocol flow'
if node "$ROOT_DIR/huawei-validation/scripts/run-local-flow-demo.mjs" >/tmp/huawei-local-flow.log 2>&1; then
  ok 'Local Huawei route flow demo completed'
  tail -1 /tmp/huawei-local-flow.log | sed 's/^/  /'
else
  fail 'Local Huawei route flow demo failed'
  sed -n '1,40p' /tmp/huawei-local-flow.log | sed 's/^/  /'
fi
rm -f /tmp/huawei-local-flow.log
info ''

info 'Local scenario simulation'
if node "$ROOT_DIR/huawei-validation/scripts/run-local-scenario-demo.mjs" >/tmp/huawei-local-scenario.log 2>&1; then
  ok 'Local Huawei scenario demo completed'
  tail -1 /tmp/huawei-local-scenario.log | sed 's/^/  /'
else
  fail 'Local Huawei scenario demo failed'
  sed -n '1,60p' /tmp/huawei-local-scenario.log | sed 's/^/  /'
fi
rm -f /tmp/huawei-local-scenario.log
info ''

if [ "$failures" -gt 0 ]; then
  fail "$failures required check(s) failed; do not start H0 true-device validation yet."
  exit "$failures"
fi

if [ "$warnings" -gt 0 ]; then
  warn "$warnings warning(s) remain. H0 project creation can proceed, but emulator/true-device validation may still be blocked."
else
  ok 'H0 readiness checks passed.'
fi
