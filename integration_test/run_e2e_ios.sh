#!/bin/bash
# Purchasely React Native — E2E test orchestrator (iOS Simulator)
#
# Mirrors run_e2e.sh for Android. Runs T1-T13 against an iOS simulator.
# The test logic (T1-T13) executes inside the RN JS context on-device; UI
# drivers for T8/T9 are launched from the host when the device signals
# readiness via log markers.
#
# Build strategy (parity with Android): a *Release* build is used so the JS
# bundle is embedded in the .app — no Metro bundler is required in CI. JS
# console.log markers reach the host via `xcrun simctl launch --console`
# (RN forwards console.* to the native logging hook → stderr).
#
# Usage:
#   bash integration_test/run_e2e_ios.sh [--skip-build] [--debug] [UDID]
#
# Options:
#   --skip-build   Re-use the last built .app (avoids the full xcodebuild)
#   --debug        Build the Debug configuration (requires Metro running)
#
# Prerequisites:
#   - Xcode + xcrun + simctl on PATH
#   - idb + idb_companion (brew install idb-companion) for T8/T9 UI drivers
#   - yarn (Node 20) in PATH
#   - an iOS Simulator booted (or pass its UDID)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Args ──────────────────────────────────────────────────────────────────────
SKIP_BUILD=0
DEBUG_BUILD=0
UDID="${IOS_SIMULATOR_UDID:-}"

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --debug)      DEBUG_BUILD=1 ;;
    *)            UDID="$arg" ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[E2E]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WRN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; }

# ── Auto-detect booted simulator ─────────────────────────────────────────────
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices booted -j \
    | python3 -c "import sys,json; d=json.load(sys.stdin)['devices']; \
      devs=[v for vs in d.values() for v in vs if v.get('state')=='Booted']; \
      print(devs[0]['udid'] if devs else '')" 2>/dev/null || true)
  if [ -z "$UDID" ]; then
    err "No booted iOS simulator found. Boot one first or pass its UDID."
    exit 1
  fi
fi
log "Using simulator: $UDID"

# ── Config ────────────────────────────────────────────────────────────────────
# Xcode project: workspace/scheme/product are all named "example".
APP_BUNDLE="com.purchasely.demo"
WORKSPACE="$REPO_ROOT/example/ios/example.xcworkspace"
SCHEME="example"
PROCESS_NAME="example"   # PRODUCT_NAME — used by `log stream` predicate
if [ "$DEBUG_BUILD" -eq 1 ]; then
  CONFIG="Debug"
else
  CONFIG="Release"
fi
DERIVED="$REPO_ROOT/example/ios/build"
APP_PATH="$DERIVED/Build/Products/${CONFIG}-iphonesimulator/example.app"
LOGFILE="/tmp/e2e_rn_ios_$$.log"
TAP_DRIVER="$SCRIPT_DIR/tools/tap_purchase_ios.sh"
BACK_DRIVER="$SCRIPT_DIR/tools/swipe_dismiss_ios.sh"

# ── Ensure Node is available (NVM) ───────────────────────────────────────────
if ! command -v node &>/dev/null; then
  [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
  nvm use 20 2>/dev/null || true
fi

# ── Build ─────────────────────────────────────────────────────────────────────
if [ "$SKIP_BUILD" -eq 0 ]; then
  log "Building JS SDK (yarn purchasely:prepare)..."
  cd "$REPO_ROOT"
  yarn purchasely:prepare 2>&1 | tail -5

  log "Building iOS app ($CONFIG)..."
  cd "$REPO_ROOT/example/ios"
  set -o pipefail
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -sdk iphonesimulator \
    -destination "id=$UDID" \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | (xcbeautify 2>/dev/null || tail -40)
  BUILD_RC=${PIPESTATUS[0]}
  set +o pipefail
  if [ "$BUILD_RC" -ne 0 ]; then
    err "xcodebuild failed (rc=$BUILD_RC)"
    exit 1
  fi
  if [ ! -d "$APP_PATH" ]; then
    err "App not found at $APP_PATH"
    exit 1
  fi
  ok "App built: $APP_PATH"
else
  warn "--skip-build: skipping xcodebuild"
  if [ ! -d "$APP_PATH" ]; then
    err "App not found at $APP_PATH — run without --skip-build first"
    exit 1
  fi
fi

# ── Install ───────────────────────────────────────────────────────────────────
log "Installing app on $UDID..."
xcrun simctl uninstall "$UDID" "$APP_BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"
ok "App installed"

# ── Launch with console capture ───────────────────────────────────────────────
# `--console` attaches the app's stdout/stderr to this process; RN's
# console.log/error reach stderr via the native logging hook, so the E2E
# markers land in $LOGFILE. `E2E_MODE true` is read by AppDelegate.swift.
xcrun simctl terminate "$UDID" "$APP_BUNDLE" 2>/dev/null || true
sleep 1
: > "$LOGFILE"

log "Launching E2E runner on $UDID..."
xcrun simctl launch --console --terminate-running-process \
  "$UDID" "$APP_BUNDLE" E2E_MODE true >> "$LOGFILE" 2>&1 &
LAUNCH_PID=$!

# Secondary capture via unified logging (belt-and-suspenders for console.log).
xcrun simctl spawn "$UDID" log stream \
  --level debug \
  --predicate "process == \"$PROCESS_NAME\"" \
  --style compact >> "$LOGFILE" 2>&1 &
STREAM_PID=$!

cleanup() {
  kill "$STREAM_PID" 2>/dev/null || true
  kill "$LAUNCH_PID"  2>/dev/null || true
  rm -f "$LOGFILE"
}
trap cleanup EXIT

log "Monitoring logs for E2E markers..."

# ── Monitor loop ──────────────────────────────────────────────────────────────
TIMEOUT_SECS=420
START_TS=$(date +%s)
TAP_DONE=0
BACK_DONE=0
SUITE_RESULT=""

while true; do
  ELAPSED=$(( $(date +%s) - START_TS ))
  if [ "$ELAPSED" -ge "$TIMEOUT_SECS" ]; then
    err "TIMEOUT: suite did not complete within ${TIMEOUT_SECS}s"
    SUITE_RESULT="FAIL"; break
  fi

  # T8 tap signal
  if [ "$TAP_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_TAP\]' "$LOGFILE" 2>/dev/null; then
    TAP_DONE=1
    log "T8: signaled — launching iOS tap driver..."
    bash "$TAP_DRIVER" "$UDID" &
  fi

  # T9 back/swipe signal
  if [ "$BACK_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_BACK\]' "$LOGFILE" 2>/dev/null; then
    BACK_DONE=1
    log "T9: signaled — launching iOS swipe-dismiss driver..."
    bash "$BACK_DRIVER" "$UDID" &
  fi

  if grep -q '\[E2E:SUITE:PASS\]' "$LOGFILE" 2>/dev/null; then
    SUITE_RESULT="PASS"; break
  fi
  if grep -q '\[E2E:SUITE:FAIL\]' "$LOGFILE" 2>/dev/null; then
    SUITE_RESULT="FAIL"; break
  fi

  sleep 0.5
done

# Stop the streams so `wait` doesn't hang
kill "$STREAM_PID" 2>/dev/null || true
kill "$LAUNCH_PID"  2>/dev/null || true
STREAM_PID=""; LAUNCH_PID=""
wait 2>/dev/null || true

# ── Report ────────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
echo " Purchasely RN E2E — iOS results"
echo "==========================================="

for id in T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13; do
  PASS_LINE=$(grep "\[E2E:${id}:PASS\]" "$LOGFILE" 2>/dev/null | tail -1)
  FAIL_LINE=$(grep "\[E2E:${id}:FAIL\]" "$LOGFILE" 2>/dev/null | tail -1)
  if [ -n "$PASS_LINE" ]; then
    ok "$id  $(echo "$PASS_LINE" | sed "s/.*\[E2E:${id}:PASS\] //")"
  elif [ -n "$FAIL_LINE" ]; then
    err "$id  $(echo "$FAIL_LINE" | sed "s/.*\[E2E:${id}:FAIL\] //")"
  else
    warn "$id  (no result logged)"
  fi
done

echo "==========================================="
if [ "$SUITE_RESULT" = "PASS" ]; then
  ok "ALL E2E TESTS PASSED (iOS)"
  exit 0
else
  err "E2E TESTS FAILED (iOS)"
  echo ""
  echo "--- E2E markers (last 100) ---"
  grep 'E2E:' "$LOGFILE" 2>/dev/null | tail -100
  echo ""
  echo "--- JS / crashes (last 60) ---"
  grep -E "(ReactNativeJS|PURCHASELY|Purchasely|Fatal|Exception|bundle|RCTFatal)" "$LOGFILE" 2>/dev/null | tail -60
  exit 1
fi
