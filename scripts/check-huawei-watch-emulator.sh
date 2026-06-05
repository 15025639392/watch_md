#!/usr/bin/env bash
set -u

DEVECO_STUDIO_HOME="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app/Contents}"
HUAWEI_SDK_ROOT="${HUAWEI_SDK_ROOT:-$HOME/Library/Huawei/Sdk}"
EMULATOR_JSON="$DEVECO_STUDIO_HOME/tools/emulator/emulator.json"
EMULATOR_BIN="$DEVECO_STUDIO_HOME/tools/emulator/Emulator"

info() {
  printf '%s\n' "$*"
}

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*"
}

info 'Huawei watch emulator image check'
info "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
info ''

if [ -x "$EMULATOR_BIN" ]; then
  ok "Emulator binary: $EMULATOR_BIN"
else
  fail "Emulator binary missing: $EMULATOR_BIN"
fi

if [ -f "$EMULATOR_JSON" ]; then
  ok "Emulator template list: $EMULATOR_JSON"
  info ''
  info 'Available watch templates in DevEco Studio:'
  if command -v jq >/dev/null 2>&1; then
    jq -r '.[] | select(.deviceType | test("wear"; "i")) | "  API \(.api): \(.name) / \(.deviceType) / \(.resolutionWidth)x\(.resolutionHeight)"' "$EMULATOR_JSON"
  else
    warn 'jq not found; cannot pretty-print watch templates.'
  fi
else
  fail "Emulator template list missing: $EMULATOR_JSON"
fi

info ''
info 'Downloaded watch system images:'
watch_images="$(find "$HUAWEI_SDK_ROOT/system-image" -maxdepth 3 -type d \( -iname '*wearable*' -o -iname '*watch*' \) 2>/dev/null | sort)"
if [ -n "$watch_images" ]; then
  printf '%s\n' "$watch_images" | sed 's/^/  /'
  ok 'Watch emulator image is installed.'
else
  warn 'No wearable/watch system image found locally.'
  info '  Expected location after download:'
  info "  $HUAWEI_SDK_ROOT/system-image/<HarmonyOS-version>/<wearable-image>"
fi

info ''
info 'Current system images:'
find "$HUAWEI_SDK_ROOT/system-image" -maxdepth 3 -type d 2>/dev/null | sed 's/^/  /'

info ''
info 'Download path in DevEco Studio:'
info '  1. Open DevEco Studio.'
info '  2. Open Device Manager.'
info '  3. Choose Local Emulator / Local Simulator, then create a new device.'
info '  4. Select Huawei_Wearable, API 24, 466x466.'
info '  5. Let DevEco download the required system image and create the virtual device.'
info ''
info 'Tip: pass --open to open DevEco Studio now.'

if [ "${1:-}" = "--open" ]; then
  open -a /Applications/DevEco-Studio.app
fi
