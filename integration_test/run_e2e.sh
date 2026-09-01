#!/bin/bash
# Purchasely React Native -- E2E test orchestrator
#
# Runs T1-T26 against a connected Android device/emulator, then T27 (cold-start
# deeplink) as a dedicated second phase on a fresh process.
# The test logic executes inside the RN JS context on-device;
# UI drivers for T8/T9/T25 are launched from the host when the device signals
# readiness via LogCat markers.
#
# T27 needs its own process because the SDK init builder must chain
# `.handleDeeplink()` BEFORE start(); the app is relaunched with the intent
# extra E2E_PHASE=deeplink_coldstart, which MainActivity forwards as a `phase`
# initial prop (routing the runner to its cold-start-only flow).
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
INLINE_CLOSE_DRIVER="$SCRIPT_DIR/tools/tap_close_inline.sh"
NESTED_SHOT_DRIVER="$SCRIPT_DIR/tools/capture_nested_inline.sh"
DUAL_INLINE_DRIVER="$SCRIPT_DIR/tools/assert_dual_inline.sh"
REMOUNT_SHOT_DRIVER="$SCRIPT_DIR/tools/capture_remount_inline.sh"
# Screenshots and view-hierarchy dumps land here; CI uploads the directory.
ARTIFACT_DIR="${E2E_ARTIFACT_DIR:-$REPO_ROOT/integration_test/artifacts}"
mkdir -p "$ARTIFACT_DIR"
LOGCAT_FILE="/tmp/e2e_rn_logcat_$$.log"
PKG="com.purchasely.demo"
ACTIVITY="com.purchasely.demo/com.purchasely.MainActivity"

LOGCAT_PID=""

cleanup() {
  if [ -n "$LOGCAT_PID" ]; then
    kill "$LOGCAT_PID" 2>/dev/null || true
  fi
  # In CI the upload-artifact step collects the log after this trap fires.
  if [ -z "${GITHUB_ACTIONS:-}" ]; then
    rm -f "$LOGCAT_FILE"
  fi
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
if ! adb -s "$DEV" install "$APK" 2>&1; then
  err "adb install failed -- aborting"
  exit 1
fi
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
TIMEOUT_SECS=600  # 10 minutes (T8/T9 have 40 s waits; T14-T26 add catalog/display/attr checks)
START_TS=$(date +%s)
TAP_DONE=0
BACK_DONE=0
INLINE_CLOSE_DONE=0
NESTED_SHOT_DONE=0
REMOUNT_SHOT_DONE=0
DUAL_INLINE_DONE=0
# T29's verdict comes from the host, not from a JS marker: the sizes it checks
# live in the native view tree, which JS cannot read.
DUAL_INLINE_RESULT="SKIP"
SUITE_RESULT=""
DRIVER_PIDS=()

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
    bash "$TAP_DRIVER" "$DEV" & DRIVER_PIDS+=("$!:T8 tap driver")
  fi

  # T9 back signal
  if [ "$BACK_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_BACK\]' "$LOGCAT_FILE" 2>/dev/null; then
    BACK_DONE=1
    log "T9: signaled -- launching back driver in background..."
    bash "$BACK_DRIVER" "$DEV" & DRIVER_PIDS+=("$!:T9 back driver")
  fi

  # T25 inline close signal
  if [ "$INLINE_CLOSE_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_INLINE_CLOSE\]' "$LOGCAT_FILE" 2>/dev/null; then
    INLINE_CLOSE_DONE=1
    log "T25: signaled -- launching inline close driver in background..."
    bash "$INLINE_CLOSE_DRIVER" "$DEV" & DRIVER_PIDS+=("$!:T25 inline close driver")
  fi

  # T28 nested-in-react-native-screens capture
  if [ "$NESTED_SHOT_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_NESTED_SHOT\]' "$LOGCAT_FILE" 2>/dev/null; then
    NESTED_SHOT_DONE=1
    log "T28: signaled -- capturing the nested embedded view..."
    bash "$NESTED_SHOT_DRIVER" "$DEV" "$ARTIFACT_DIR" & DRIVER_PIDS+=("$!:T28 nested capture")
  fi

  # T29 dual embedded views: assert the native bounds, capture the proof.
  # The runner prints the two container heights it used, so this script and the
  # runner cannot drift apart on hardcoded numbers.
  if [ "$DUAL_INLINE_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_DUAL_INLINE\]' "$LOGCAT_FILE" 2>/dev/null; then
    DUAL_INLINE_DONE=1
    DUAL_DP=$(grep -o '\[E2E:DUAL_INLINE_DP:[0-9]*:[0-9]*\]' "$LOGCAT_FILE" | tail -1 | tr -d '[]' | cut -d: -f3,4)
    TALL_DP="${DUAL_DP%%:*}"
    SHORT_DP="${DUAL_DP##*:}"
    if [ -z "$TALL_DP" ] || [ -z "$SHORT_DP" ]; then
      err "T29: the runner did not print [E2E:DUAL_INLINE_DP:tall:short]"
      DUAL_INLINE_RESULT="FAIL"
    else
      log "T29: signaled -- asserting the two embedded views (${TALL_DP}dp / ${SHORT_DP}dp)..."
      if bash "$DUAL_INLINE_DRIVER" "$DEV" "$TALL_DP" "$SHORT_DP" "$ARTIFACT_DIR"; then
        DUAL_INLINE_RESULT="PASS"
        ok "T29: native bounds assertion PASSED"
      else
        DUAL_INLINE_RESULT="FAIL"
        err "T29: native bounds assertion FAILED"
      fi
    fi
  fi

  # T30 remount capture
  if [ "$REMOUNT_SHOT_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_REMOUNT_SHOT\]' "$LOGCAT_FILE" 2>/dev/null; then
    REMOUNT_SHOT_DONE=1
    log "T30: signaled -- capturing the remounted embedded view..."
    bash "$REMOUNT_SHOT_DRIVER" "$DEV" "$ARTIFACT_DIR" & DRIVER_PIDS+=("$!:T30 remount capture")
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

# -- T27 cold-start deeplink phase (fresh process) -----------------------------
# T27 chains .handleDeeplink() on the start builder BEFORE start(), which needs
# a brand-new process. Relaunch with E2E_PHASE=deeplink_coldstart; the runner
# then runs ONLY the cold-start flow and emits [E2E:T27:PASS|FAIL]. Only
# attempted when the main suite passed (a failed main run already exits 1).
T27_RESULT="SKIP"
if [ "$SUITE_RESULT" = "PASS" ]; then
  log "T27: launching cold-start deeplink phase (E2E_PHASE=deeplink_coldstart)..."
  adb -s "$DEV" shell am force-stop "$PKG" 2>/dev/null || true
  sleep 1
  adb -s "$DEV" shell am start -n "$ACTIVITY" \
    --es E2E_MODE true \
    --es E2E_PHASE deeplink_coldstart
  T27_START=$(date +%s)
  while true; do
    if [ $(( $(date +%s) - T27_START )) -ge 150 ]; then
      err "T27: timeout waiting for cold-start deeplink result"
      T27_RESULT="FAIL"; break
    fi
    # Match only PASS/FAIL (the main suite already logged [E2E:T27:SKIP]).
    if grep -q '\[E2E:T27:PASS\]' "$LOGCAT_FILE" 2>/dev/null; then T27_RESULT="PASS"; break; fi
    if grep -q '\[E2E:T27:FAIL\]' "$LOGCAT_FILE" 2>/dev/null; then T27_RESULT="FAIL"; break; fi
    sleep 0.5
  done
  [ "$T27_RESULT" = "PASS" ] && ok "T27: cold-start deeplink phase PASSED"
fi

# Kill logcat so `wait` doesn't hang indefinitely on it
kill "$LOGCAT_PID" 2>/dev/null || true
LOGCAT_PID=""

# Wait for background drivers (tap/back/inline-close) to finish, surfacing a
# visible warning per driver exit code -- the JS-side waitFor()/fail() in
# E2ETestRunner.tsx remains the actual gate, this is a diagnostic net so a
# silently-failing driver doesn't read as a mysterious test timeout in the log.
for entry in "${DRIVER_PIDS[@]:-}"; do
  [ -z "$entry" ] && continue
  pid="${entry%%:*}"
  label="${entry#*:}"
  wait "$pid" 2>/dev/null
  driver_rc=$?
  if [ "$driver_rc" -eq 0 ]; then
    ok "$label exited 0"
  else
    warn "$label exited non-zero (rc=$driver_rc)"
  fi
done

# -- Report --------------------------------------------------------------------
echo ""
echo "==========================================="
echo " Purchasely RN E2E -- test results"
echo "==========================================="

# Extract and print individual test results in order. T27 (cold-start phase)
# logs a [E2E:T27:SKIP] in the main suite and its real PASS/FAIL in the phase
# run — PASS is checked first so it takes precedence. Any id with NO marker at
# all is collected into MISSING_IDS: this loop was previously cosmetic (a
# warning only) with the exit code decided solely by the aggregate
# [E2E:SUITE:PASS|FAIL] marker, so a test that silently never reported would
# still read as a full pass. It is now authoritative -- a missing marker fails
# the run.
MISSING_IDS=()
for id in T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 T21 T22 T23 T24 T25 T26 T27 T28 T29 T30; do
  PASS_LINE=$(grep "\[E2E:${id}:PASS\]" "$LOGCAT_FILE" 2>/dev/null | tail -1)
  FAIL_LINE=$(grep "\[E2E:${id}:FAIL\]" "$LOGCAT_FILE" 2>/dev/null | tail -1)
  SKIP_LINE=$(grep "\[E2E:${id}:SKIP\]" "$LOGCAT_FILE" 2>/dev/null | tail -1)
  if [ -n "$PASS_LINE" ]; then
    ok "$id  $(echo "$PASS_LINE" | sed "s/.*\[E2E:${id}:PASS\] //")"
  elif [ -n "$FAIL_LINE" ]; then
    err "$id  $(echo "$FAIL_LINE" | sed "s/.*\[E2E:${id}:FAIL\] //")"
  elif [ -n "$SKIP_LINE" ]; then
    warn "$id  SKIP $(echo "$SKIP_LINE" | sed "s/.*\[E2E:${id}:SKIP\] //")"
  else
    err "$id  (no result logged)"
    MISSING_IDS+=("$id")
  fi
done

# T29's own [E2E:T29:PASS] marker only says both views loaded. The size claim is
# the host's, and it is a gate: a SKIP here means the marker never fired, which
# is already covered by MISSING_IDS, but a FAIL must sink the run on its own.
case "$DUAL_INLINE_RESULT" in
  PASS) ok   "T29  native bounds: each embedded view kept its own height" ;;
  FAIL) err  "T29  native bounds: the two embedded views did not keep their own heights" ;;
  *)    warn "T29  native bounds: not asserted (driver never ran)" ;;
esac
if [ -d "$ARTIFACT_DIR" ]; then
  echo "Artifacts: $ARTIFACT_DIR"
fi

echo "==========================================="
if [ "$SUITE_RESULT" = "PASS" ] && [ "$T27_RESULT" != "FAIL" ] \
   && [ "$DUAL_INLINE_RESULT" != "FAIL" ] && [ "${#MISSING_IDS[@]}" -eq 0 ]; then
  ok "ALL E2E TESTS PASSED"
  exit 0
else
  if [ "${#MISSING_IDS[@]}" -gt 0 ]; then
    err "Missing result marker for: ${MISSING_IDS[*]}"
  fi
  err "E2E TESTS FAILED"
  echo ""
  echo "--- E2E markers (last 100) ---"
  grep 'E2E:' "$LOGCAT_FILE" 2>/dev/null | tail -100
  echo ""
  echo "--- ReactNativeJS / crashes (last 60) ---"
  grep -E "(ReactNativeJS|PURCHASELY|AndroidRuntime|FATAL|bundle|Unable to load|No bundle)" "$LOGCAT_FILE" 2>/dev/null | tail -60
  exit 1
fi
