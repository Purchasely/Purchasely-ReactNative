#!/bin/bash
# Purchasely React Native -- E2E test orchestrator
#
# Runs T1-T13 against a connected Android device/emulator.
# The test logic (T1-T13) executes inside the RN JS context on-device;
# UI drivers for T8/T9 are launched from the host when the device signals
# readiness via LogCat markers.
#
# Usage:
#   bash integration_test/run_e2e.sh [device_serial] [--skip-build]
#
# Options:
#   --skip-build   Re-use the last built APK (avoids the full Gradle build)
#
# Prerequisites:
#   - adb in PATH; target device/emulator connected
#   - node (v20), yarn in PATH (or NVM sourced)
#   - python3 in PATH (used by tap_purchase.sh for coord extraction)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# -- Arguments -----------------------------------------------------------------
DEV="emulator-5554"
SKIP_BUILD=0
DEBUG_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --debug)      DEBUG_BUILD=1 ;;
    *) DEV="$arg" ;;
  esac
done

# -- Colours -------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[E2E]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WRN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; }

# -- Paths ---------------------------------------------------------------------
if [ "$DEBUG_BUILD" -eq 1 ]; then
  APK="$REPO_ROOT/example/android/app/build/outputs/apk/debug/app-debug.apk"
else
  APK="$REPO_ROOT/example/android/app/build/outputs/apk/release/app-release.apk"
fi
TAP_DRIVER="$SCRIPT_DIR/tools/tap_purchase.sh"
BACK_DRIVER="$SCRIPT_DIR/tools/press_back.sh"
LOGCAT_FILE="/tmp/e2e_rn_logcat_$$.log"
PKG="com.purchasely.demo"
ACTIVITY="com.purchasely.demo/com.purchasely.MainActivity"

LOGCAT_PID=""

cleanup() {
  if [ -n "$LOGCAT_PID" ]; then
    kill "$LOGCAT_PID" 2>/dev/null || true
  fi
  rm -f "$LOGCAT_FILE"
}
trap cleanup EXIT

# -- Check device --------------------------------------------------------------
log "Checking device $DEV..."
if ! adb -s "$DEV" get-state >/dev/null 2>&1; then
  err "Device $DEV is not connected.  Aborting."
  exit 1
fi
ok "Device $DEV is ready"

# -- Ensure Node is available (NVM) -------------------------------------------
if ! command -v node &>/dev/null; then
  [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
  nvm use 20 2>/dev/null || true
fi

# -- Build ---------------------------------------------------------------------
if [ "$SKIP_BUILD" -eq 0 ]; then
  log "Building the SDK (yarn purchasely:prepare)..."
  cd "$REPO_ROOT"
  yarn purchasely:prepare 2>&1 | tail -5

  if [ "$DEBUG_BUILD" -eq 1 ]; then
    log "Building debug APK (./gradlew assembleDebug)..."
    cd "$REPO_ROOT/example/android"
    ./gradlew assembleDebug --quiet 2>&1 | tail -20
  else
    log "Building release APK (./gradlew assembleRelease)..."
    cd "$REPO_ROOT/example/android"
    # -x lintVitalRelease: Lint reports a false positive for ReactActivity
    # (which does extend android.app.Activity via AppCompatActivity).
    ./gradlew assembleRelease -x lintVitalRelease --quiet 2>&1 | tail -20
  fi

  if [ ! -f "$APK" ]; then
    err "APK not found at $APK"
    exit 1
  fi
  ok "APK built: $APK"
else
  warn "--skip-build: skipping Gradle build"
  if [ ! -f "$APK" ]; then
    err "APK not found at $APK -- run without --skip-build first"
    exit 1
  fi
fi

# -- Install -------------------------------------------------------------------
log "Installing APK on $DEV..."
adb -s "$DEV" shell pm uninstall "$PKG" 2>/dev/null || true
adb -s "$DEV" install "$APK" 2>&1
ok "APK installed"

# -- Clear LogCat --------------------------------------------------------------
adb -s "$DEV" logcat -c

# -- Start LogCat stream -------------------------------------------------------
adb -s "$DEV" logcat > "$LOGCAT_FILE" 2>&1 &
LOGCAT_PID=$!

# -- Launch E2E component ------------------------------------------------------
log "Launching E2E runner on $DEV..."
adb -s "$DEV" shell am force-stop "$PKG" 2>/dev/null || true
sleep 1

adb -s "$DEV" shell am start -n "$ACTIVITY" \
  --es E2E_MODE true

log "Test runner launched -- monitoring LogCat..."

# -- Monitor loop --------------------------------------------------------------
TIMEOUT_SECS=420  # 7 minutes (T8/T9 have 40 s waits; T10-T13 add ~30 s total)
START_TS=$(date +%s)
TAP_DONE=0
BACK_DONE=0
SUITE_RESULT=""

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TS))

  if [ "$ELAPSED" -ge "$TIMEOUT_SECS" ]; then
    err "TIMEOUT: suite did not complete within ${TIMEOUT_SECS}s"
    SUITE_RESULT="FAIL"
    break
  fi

  # T8 tap signal
  if [ "$TAP_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_TAP\]' "$LOGCAT_FILE" 2>/dev/null; then
    TAP_DONE=1
    log "T8: signaled -- launching tap driver in background..."
    bash "$TAP_DRIVER" "$DEV" &
  fi

  # T9 back signal
  if [ "$BACK_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_BACK\]' "$LOGCAT_FILE" 2>/dev/null; then
    BACK_DONE=1
    log "T9: signaled -- launching back driver in background..."
    bash "$BACK_DRIVER" "$DEV" &
  fi

  # Suite completion
  if grep -q '\[E2E:SUITE:PASS\]' "$LOGCAT_FILE" 2>/dev/null; then
    SUITE_RESULT="PASS"
    break
  fi
  if grep -q '\[E2E:SUITE:FAIL\]' "$LOGCAT_FILE" 2>/dev/null; then
    SUITE_RESULT="FAIL"
    break
  fi

  sleep 0.5
done

# Kill logcat so `wait` doesn't hang indefinitely on it
kill "$LOGCAT_PID" 2>/dev/null || true
LOGCAT_PID=""

# Wait for background drivers (tap/back) to finish
wait 2>/dev/null || true

# -- Report --------------------------------------------------------------------
echo ""
echo "==========================================="
echo " Purchasely RN E2E -- test results"
echo "==========================================="

# Extract and print individual test results in order
for id in T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13; do
  PASS_LINE=$(grep "\[E2E:${id}:PASS\]" "$LOGCAT_FILE" 2>/dev/null | tail -1)
  FAIL_LINE=$(grep "\[E2E:${id}:FAIL\]" "$LOGCAT_FILE" 2>/dev/null | tail -1)
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
  ok "ALL E2E TESTS PASSED"
  exit 0
else
  err "E2E TESTS FAILED"
  echo ""
  echo "--- E2E markers (last 100) ---"
  grep 'E2E:' "$LOGCAT_FILE" 2>/dev/null | tail -100
  echo ""
  echo "--- ReactNativeJS / crashes (last 60) ---"
  grep -E "(ReactNativeJS|PURCHASELY|AndroidRuntime|FATAL|bundle|Unable to load|No bundle)" "$LOGCAT_FILE" 2>/dev/null | tail -60
  exit 1
fi
