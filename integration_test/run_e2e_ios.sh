#!/bin/bash
# Purchasely React Native — E2E test orchestrator (iOS Simulator)
#
# Mirrors run_e2e.sh for Android. Runs T1-T26 against an iOS simulator, then
# T27 (cold-start deeplink) as a dedicated second phase on a fresh process.
# The test logic executes inside the RN JS context on-device; UI
# drivers for T8/T9/T25 are launched from the host when the device signals
# readiness via log markers.
#
# T27 needs its own process because the SDK init builder must chain
# `.handleDeeplink()` BEFORE start(); the app is relaunched with the real
# environment variable E2E_PHASE=deeplink_coldstart (via `SIMCTL_CHILD_E2E_PHASE`
# on `xcrun simctl launch`), which AppDelegate.swift forwards as a `phase`
# initial prop (mirrors Android MainActivity forwarding the E2E_PHASE intent
# extra).
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

# ── log stream startup (attach-race guard) ───────────────────────────────────
# `log stream` has a real, multi-second attach latency after being spawned and
# does NOT backfill: any event emitted before it is fully attached to the live
# feed is silently dropped forever (proven empirically — a canary fired at
# t=0 never appears even after 20s of polling the SAME already-running
# stream). Unlike Android's `logcat`, there is no replay. Starting the app
# before the stream is provably attached risks losing early markers
# (T1-T7, [E2E:READY_FOR_TAP], ...) with no trace of why.
#
# This starts `log stream` (predicate widened to also match `syslog`, the
# canary's own process name) and blocks the caller until a real canary event
# is observed flowing through that SAME stream instance, before returning —
# so whatever gets launched right after is guaranteed not to race the attach.
# Sets the global STREAM_PID. Returns 1 (stream killed) if never attached
# within ~20s, so the caller can abort rather than launch blind.
start_log_stream() {
  xcrun simctl spawn "$UDID" log stream \
    --level debug \
    --predicate "process == \"$PROCESS_NAME\" OR process == \"syslog\"" \
    --style compact >> "$LOGFILE" 2>&1 &
  STREAM_PID=$!

  local canary="E2E_STREAM_READY_$$_$RANDOM"
  local i
  for i in $(seq 1 40); do
    xcrun simctl spawn "$UDID" syslog -s "$canary" 2>/dev/null
    if grep -q "$canary" "$LOGFILE" 2>/dev/null; then
      ok "log stream attached (canary observed, iter $i)"
      return 0
    fi
    sleep 0.5
  done
  err "log stream never attached (canary not observed after 20s) -- aborting rather than launching blind"
  kill "$STREAM_PID" 2>/dev/null || true
  return 1
}

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
INLINE_CLOSE_DRIVER="$SCRIPT_DIR/tools/tap_close_inline_ios.sh"

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
if ! xcrun simctl install "$UDID" "$APP_PATH"; then
  err "simctl install failed -- aborting"
  exit 1
fi
ok "App installed"

# ── Launch with console capture ───────────────────────────────────────────────
# `--console` attaches the app's stdout/stderr to this process; RN's
# console.log/error reach stderr via the native logging hook, so the E2E
# markers land in $LOGFILE. `E2E_MODE true` is read by AppDelegate.swift.
# The `log stream` capture (belt-and-suspenders for console.log) is started
# and confirmed-attached BEFORE the app launches -- see start_log_stream.
xcrun simctl terminate "$UDID" "$APP_BUNDLE" 2>/dev/null || true
sleep 1
: > "$LOGFILE"

log "Starting log stream capture..."
start_log_stream || exit 1

log "Launching E2E runner on $UDID..."
xcrun simctl launch --console --terminate-running-process \
  "$UDID" "$APP_BUNDLE" E2E_MODE true >> "$LOGFILE" 2>&1 &
LAUNCH_PID=$!

cleanup() {
  kill "$STREAM_PID" 2>/dev/null || true
  kill "$LAUNCH_PID"  2>/dev/null || true
  # In CI the upload-artifact step collects the log after this trap fires.
  if [ -z "${GITHUB_ACTIONS:-}" ]; then
    rm -f "$LOGFILE"
  fi
}
trap cleanup EXIT

log "Monitoring logs for E2E markers..."

# ── Monitor loop ──────────────────────────────────────────────────────────────
TIMEOUT_SECS=600
START_TS=$(date +%s)
TAP_DONE=0
BACK_DONE=0
INLINE_CLOSE_DONE=0
SUITE_RESULT=""
DRIVER_PIDS=()

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
    bash "$TAP_DRIVER" "$UDID" & DRIVER_PIDS+=("$!:T8 tap driver")
  fi

  # T9 back/swipe signal
  if [ "$BACK_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_BACK\]' "$LOGFILE" 2>/dev/null; then
    BACK_DONE=1
    log "T9: signaled — launching iOS swipe-dismiss driver..."
    bash "$BACK_DRIVER" "$UDID" & DRIVER_PIDS+=("$!:T9 swipe-dismiss driver")
  fi

  # T25 inline close signal
  if [ "$INLINE_CLOSE_DONE" -eq 0 ] && grep -q '\[E2E:READY_FOR_INLINE_CLOSE\]' "$LOGFILE" 2>/dev/null; then
    INLINE_CLOSE_DONE=1
    log "T25: signaled — launching iOS inline close driver..."
    bash "$INLINE_CLOSE_DRIVER" "$UDID" & DRIVER_PIDS+=("$!:T25 inline close driver")
  fi

  if grep -q '\[E2E:SUITE:PASS\]' "$LOGFILE" 2>/dev/null; then
    SUITE_RESULT="PASS"; break
  fi
  if grep -q '\[E2E:SUITE:FAIL\]' "$LOGFILE" 2>/dev/null; then
    SUITE_RESULT="FAIL"; break
  fi

  sleep 0.5
done

# ── T27 cold-start deeplink phase (fresh process) ─────────────────────────────
# Mirrors run_e2e.sh's Android relaunch: T27 chains .handleDeeplink() on the
# start builder BEFORE start(), which needs a brand-new process. `xcrun simctl
# launch` has no positional-argument channel for a keyed value, so the phase is
# passed as a real environment variable via `SIMCTL_CHILD_E2E_PHASE` — simctl
# strips the `SIMCTL_CHILD_` prefix before handing it to the launched process'
# environment (read by AppDelegate.swift, forwarded as the `phase` initial
# prop). Only attempted when the main suite passed (a failed main run already
# exits 1). Output is appended to the same $LOGFILE the main suite wrote to, so
# the report loop below sees both phases' markers.
#
# Reinstalls before relaunching (unlike Android's equivalent phase, which just
# force-stops + relaunches the same install). This is NOT parity for its own
# sake: bisected empirically (uninstall+reinstall vs. plain terminate+relaunch;
# wiping ONLY the app's UserDefaults plist on the SAME binary; a 10x longer
# cooldown between terminate and relaunch) down to one variable — a fresh
# install (or an install with its UserDefaults wiped) makes this phase pass in
# ~1.5-2s every time, while relaunching the SAME install right after T1-T26
# (which has warmed up plenty of `com.purchasely.cache.*` / device-key /
# anonymous-user-id state) hangs forever with ZERO `[Purchasely]` log output,
# even though the underlying network calls to api.purchasely.io /
# paywall.purchasely.io succeed. Android's SDK handles the identical
# "warm-state relaunch + immediate cold-start deeplink" scenario fine (its
# script doesn't reinstall either) — so this is a genuine iOS-native-SDK gap
# in the cold-start deeplink/presentation-resolution path when local SDK
# state is warm, not an RN/bridge bug and not something to patch here (see
# the mission report). Reinstalling makes this phase actually exercise a
# genuine cold start (a user who just installed the app tapping a deeplink),
# which is what T27 claims to test in the first place.
T27_RESULT="SKIP"
if [ "$SUITE_RESULT" = "PASS" ]; then
  log "T27: launching cold-start deeplink phase (E2E_PHASE=deeplink_coldstart)..."
  kill "$STREAM_PID" 2>/dev/null || true
  kill "$LAUNCH_PID"  2>/dev/null || true
  xcrun simctl uninstall "$UDID" "$APP_BUNDLE" 2>/dev/null || true
  if ! xcrun simctl install "$UDID" "$APP_PATH"; then
    err "T27: simctl reinstall failed -- aborting"
    exit 1
  fi
  sleep 1

  # Same attach-race guard as the main launch above: get the stream confirmed
  # BEFORE relaunching, or T27's own markers ([E2E:SUITE:START], DEEPLINK_OPENED,
  # PRESENTATION_VIEWED, ...) can be silently dropped with no trace, misread as
  # a genuine cold-start hang.
  if ! start_log_stream; then
    err "T27: aborting cold-start phase (log stream attach failed)"
    T27_RESULT="FAIL"
  else
    SIMCTL_CHILD_E2E_PHASE=deeplink_coldstart xcrun simctl launch --console --terminate-running-process \
      "$UDID" "$APP_BUNDLE" E2E_MODE true >> "$LOGFILE" 2>&1 &
    LAUNCH_PID=$!

    T27_START=$(date +%s)
    while true; do
      if [ $(( $(date +%s) - T27_START )) -ge 150 ]; then
        err "T27: timeout waiting for cold-start deeplink result"
        T27_RESULT="FAIL"; break
      fi
      # Match only PASS/FAIL (the main suite already logged [E2E:T27:SKIP]).
      if grep -q '\[E2E:T27:PASS\]' "$LOGFILE" 2>/dev/null; then T27_RESULT="PASS"; break; fi
      if grep -q '\[E2E:T27:FAIL\]' "$LOGFILE" 2>/dev/null; then T27_RESULT="FAIL"; break; fi
      sleep 0.5
    done
    [ "$T27_RESULT" = "PASS" ] && ok "T27: cold-start deeplink phase PASSED"
  fi
fi

# Stop the streams so `wait` doesn't hang (either the T27 relaunch above, or the
# original main-suite launch if T27 was skipped/not attempted).
kill "$STREAM_PID" 2>/dev/null || true
kill "$LAUNCH_PID"  2>/dev/null || true
STREAM_PID=""; LAUNCH_PID=""

# Wait for background drivers (tap/swipe/inline-close) to finish, surfacing a
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

# ── Report ────────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
echo " Purchasely RN E2E — iOS results"
echo "==========================================="

# Any id with NO marker at all is collected into MISSING_IDS: this loop was
# previously cosmetic (a warning only), with the exit code decided solely by
# the aggregate [E2E:SUITE:PASS|FAIL] marker, so a test that silently never
# reported would still read as a full pass. It is now authoritative -- a
# missing marker fails the run.
MISSING_IDS=()
for id in T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 T21 T22 T23 T24 T25 T26 T27; do
  PASS_LINE=$(grep "\[E2E:${id}:PASS\]" "$LOGFILE" 2>/dev/null | tail -1)
  FAIL_LINE=$(grep "\[E2E:${id}:FAIL\]" "$LOGFILE" 2>/dev/null | tail -1)
  SKIP_LINE=$(grep "\[E2E:${id}:SKIP\]" "$LOGFILE" 2>/dev/null | tail -1)
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

echo "==========================================="
if [ "$SUITE_RESULT" = "PASS" ] && [ "$T27_RESULT" != "FAIL" ] && [ "${#MISSING_IDS[@]}" -eq 0 ]; then
  ok "ALL E2E TESTS PASSED (iOS)"
  exit 0
else
  if [ "${#MISSING_IDS[@]}" -gt 0 ]; then
    err "Missing result marker for: ${MISSING_IDS[*]}"
  fi
  err "E2E TESTS FAILED (iOS)"
  echo ""
  echo "--- E2E markers (last 100) ---"
  grep 'E2E:' "$LOGFILE" 2>/dev/null | tail -100
  echo ""
  echo "--- JS / crashes (last 60) ---"
  grep -E "(ReactNativeJS|PURCHASELY|Purchasely|Fatal|Exception|bundle|RCTFatal)" "$LOGFILE" 2>/dev/null | tail -60
  exit 1
fi
