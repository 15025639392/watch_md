#!/usr/bin/env bash
set -u

failures=0

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
  failures=$((failures + 1))
}

exists() {
  [ -e "$1" ]
}

check_dir() {
  if exists "$1"; then
    ok "$2: $1"
  else
    fail "$2 missing: $1"
  fi
}

check_file() {
  if [ -f "$1" ]; then
    ok "$2: $1"
  else
    fail "$2 missing: $1"
  fi
}

run_version() {
  local label="$1"
  local timeout_seconds="$2"
  shift 2

  if ! command -v "$1" >/dev/null 2>&1 && [ ! -x "$1" ]; then
    fail "$label command not found: $1"
    return
  fi

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
  output="$(sed -n '1,6p' "$output_file")"
  rm -f "$output_file"

  if [ "$status" -eq 143 ] || [ "$status" -eq 137 ]; then
    warn "$label did not finish within ${timeout_seconds}s"
    return
  fi

  if [ "$status" -ne 0 ]; then
    warn "$label exited with status $status"
  else
    ok "$label"
  fi

  if [ -n "$output" ]; then
    printf '%s\n' "$output" | sed 's/^/  /'
  fi
}

read_json_field() {
  local file="$1"
  local field="$2"
  sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -1
}

DEVECO_STUDIO_HOME="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app/Contents}"
HARMONYOS_SDK_HOME="${HARMONYOS_SDK_HOME:-$DEVECO_STUDIO_HOME/sdk/default}"
OHOS_SDK_HOME="${OHOS_SDK_HOME:-$HARMONYOS_SDK_HOME/openharmony}"
HMS_SDK_HOME="${HMS_SDK_HOME:-$HARMONYOS_SDK_HOME/hms}"

info 'HarmonyOS / Huawei watch development environment check'
info "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
info ''

info 'Host'
sw_vers 2>/dev/null | sed 's/^/  /' || uname -a | sed 's/^/  /'
uname -m | sed 's/^/  arch: /'
info ''

info 'Configured paths'
check_dir "$DEVECO_STUDIO_HOME" 'DevEco Studio home'
check_dir "$HARMONYOS_SDK_HOME" 'HarmonyOS SDK home'
check_dir "$OHOS_SDK_HOME" 'OpenHarmony SDK'
check_dir "$HMS_SDK_HOME" 'HMS SDK'
check_file "$DEVECO_STUDIO_HOME/Info.plist" 'DevEco Info.plist'
check_file "$OHOS_SDK_HOME/ets/oh-uni-package.json" 'ArkTS SDK package'
check_file "$OHOS_SDK_HOME/toolchains/hdc" 'hdc'
check_file "$HMS_SDK_HOME/ets/kits/@kit.WearEngine.d.ts" 'WearEngine ArkTS kit'
check_file "$HMS_SDK_HOME/ets/api/@hms.health.wearEngine.d.ts" 'WearEngine API'
check_dir "$OHOS_SDK_HOME/previewer/liteWearable" 'liteWearable previewer'
info ''

if [ -f "$DEVECO_STUDIO_HOME/Info.plist" ]; then
  info 'DevEco Studio'
  plutil -p "$DEVECO_STUDIO_HOME/Info.plist" 2>/dev/null \
    | sed -n '/CFBundleShortVersionString/p;/CFBundleVersion/p;/CFBundleGetInfoString/p' \
    | sed 's/^/  /'
  info ''
fi

if [ -f "$OHOS_SDK_HOME/ets/oh-uni-package.json" ]; then
  api_version="$(read_json_field "$OHOS_SDK_HOME/ets/oh-uni-package.json" apiVersion)"
  sdk_version="$(read_json_field "$OHOS_SDK_HOME/ets/oh-uni-package.json" version)"
  release_type="$(read_json_field "$OHOS_SDK_HOME/ets/oh-uni-package.json" releaseType)"
  info 'SDK'
  info "  ArkTS API version: ${api_version:-unknown}"
  info "  ArkTS SDK version: ${sdk_version:-unknown}"
  info "  Release type: ${release_type:-unknown}"
  info ''
fi

info 'Tool versions'
run_version 'DevEco embedded Node' 5 "$DEVECO_STUDIO_HOME/tools/node/bin/node" -v
run_version 'ohpm' 8 "$DEVECO_STUDIO_HOME/tools/ohpm/bin/ohpm" -v
run_version 'hdc' 5 "$OHOS_SDK_HOME/toolchains/hdc" -v
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  run_version 'Java from JAVA_HOME' 5 "$JAVA_HOME/bin/java" -version
else
  run_version 'Java from PATH' 5 java -version
fi
info ''

info 'Device probe'
if [ -x "$OHOS_SDK_HOME/toolchains/hdc" ]; then
  run_version 'hdc list targets' 5 "$OHOS_SDK_HOME/toolchains/hdc" list targets
else
  warn 'Skip hdc device probe because hdc is missing'
fi
info ''

if [ "$failures" -eq 0 ]; then
  ok 'Environment looks ready for DevEco Studio wearable/lite wearable project setup.'
else
  fail "$failures required check(s) failed."
fi

exit "$failures"
