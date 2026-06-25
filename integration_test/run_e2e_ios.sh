#!/bin/bash
# Purchasely React Native — E2E test orchestrator (iOS Simulator)
#
# Mirrors run_e2e.sh for Android. Runs T1-T13 against an iOS simulator.
# T8/T9 use xcrun simctl and idb (or appium) for UI interaction.
#
# Status: PREPARED — not yet active in CI. Will be wired into e2e-ios.yml
#         once the iOS E2E workflow is enabled.
#
# Usage:
#   bash integration_test/run_e2e_ios.sh [--skip-build] [UDID]
#
# Prerequisites:
#   - Xcode + xcrun + simctl on PATH
#   - idb_companion installed (brew install idb-companion) for UI drivers
#   - yarn (Node 20) in PATH
#   - iOS Simulator booted (or pass UDID)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Args ──────────────────────────────────────────────────────────────────────
SKIP_BUILD=0
UDID="${IOS_SIMULATOR_UDID:-}"

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
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
    err "No booted iOS simulator found. Boot one first or pass UDID."
    exit 1
  fi
fi
log "Using simulator: $UDID"

# ── Config ────────────────────────────────────────────────────────────────────
APP_BUNDLE="com.purchasely.demo"
APP_PATH="$REPO_ROOT/example/ios/build/Build/Products/Debug-iphonesimulator/PurchaselyDemo.app"
LOGFILE="/tmp/e2e_rn_ios_logcat_$$.log"
TAP_DRIVER="$SCRIPT_DIR/tools/tap_purchase_ios.sh"   # TODO: create (uses idb tap)
BACK_DRIVER="$SCRIPT_DIR/tools/swipe_dismiss_ios.sh" # TODO: create (uses idb swipe)

# ── Build ─────────────────────────────────────────────────────────────────────
if [ "$SKIP_BUILD" -eq 0 ]; then
  log "Building JS SDK…"
  cd "$REPO_ROOT"
  yarn purchasely:prepare 2>&1 | tail -5

  log "Building iOS app (Debug)…"
  cd "$REPO_ROOT/example/ios"
  xcodebuild \
    -workspace PurchaselyDemo.xcworkspace \
    -scheme PurchaselyDemo \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "id=$UDID" \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    2>&1 | tail -30

  if [ ! -d "$APP_PATH" ]; then
    err "App not found at $APP_PATH"
    exit 1
  fi
  ok "App built"
else
  warn "--skip-build: skipping Xcode build"
fi

# ── Install & launch ──────────────────────────────────────────────────────────
log "Installing app on simulator $UDID…"
xcrun simctl install "$UDID" "$APP_PATH"
ok "App installed"

log "Clearing previous log stream…"
# iOS simulator log streaming via xcrun simctl spawn
xcrun simctl terminate "$UDID" "$APP_BUNDLE" 2>/dev/null || true
sleep 1

log "Launching E2E runner…"
xcrun simctl launch "$UDID" "$APP_BUNDLE" E2E_MODE true > "$LOGFILE" 2>&1 &
LAUNCH_PID=$!

# Capture simulator log
xcrun simctl spawn "$UDID" log stream \
  --predicate "process == 'PurchaselyDemo'" \
  --style compact >> "$LOGFILE" 2>&1 &
STREAM_PID=$!

cleanup() {
  kill "$STREAM_PID" 2>/dev/null || true
  kill "$LAUNCH_PID" 2>/dev/null || true
  rm -f "$LOGFILE"
}
trap cleanup EXIT

log "Monitoring logs for E2E markers…"

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
    log "T8: signaled — launching iOS tap driver…"
    # TODO: bash "$TAP_DRIVER" "$UDID" &
    warn "T8: iOS tap driver not yet implemented (idb tap)"
  fi

  # T9 back/swipe signal
  if [ "$BACK_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_BACK\]' "$LOGFILE" 2>/dev/null; then
    BACK_DONE=1
    log "T9: signaled — launching iOS swipe-dismiss driver…"
    # TODO: bash "$BACK_DRIVER" "$UDID" &
    warn "T9: iOS swipe driver not yet implemented (idb swipe)"
  fi

  if grep -q '\[E2E:SUITE:PASS\]' "$LOGFILE" 2>/dev/null; then
    SUITE_RESULT="PASS"; break
  fi
  if grep -q '\[E2E:SUITE:FAIL\]' "$LOGFILE" 2>/dev/null; then
    SUITE_RESULT="FAIL"; break
  fi

  sleep 0.5
done

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
  echo "Last 100 E2E log lines:"
  grep 'E2E:' "$LOGFILE" 2>/dev/null | tail -100
  exit 1
fi
