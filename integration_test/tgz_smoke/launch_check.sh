#!/bin/bash
# Usage: launch_check.sh <simulator udid> <path to .app> <bundle id>
# Installs and launches the app. Fails unless the process is alive after the wait, the log has
# [TGZ:T13:PASS], and the log has no dyld error. The final terminate never changes the exit code.
set -euo pipefail
UDID=$1
APP=$2
BUNDLE_ID=$3
trap 'rc=$?; xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true; exit $rc' EXIT

xcrun simctl install "$UDID" "$APP"
START=$(date '+%Y-%m-%d %H:%M:%S')
OUT=$(xcrun simctl launch "$UDID" "$BUNDLE_ID")
echo "$OUT"
PID=${OUT##*: }
sleep "${LAUNCH_WAIT:-15}"
ps -p "$PID" >/dev/null || { echo "FAIL: process $PID is dead"; exit 1; }

# Only the app process: other apps and simulator services log dyld errors too, and `log show` would
# match its own arguments.
LOG=$(xcrun simctl spawn "$UDID" log show --start "$START" --predicate "processID == $PID AND (eventMessage CONTAINS \"[TGZ:\" OR eventMessage CONTAINS \"Library not loaded\" OR eventMessage CONTAINS \"OS_REASON_DYLD\")" || true)
grep -oE '\[TGZ:[A-Z0-9:]*\]|Library not loaded.*|OS_REASON_DYLD.*' <<<"$LOG" | sort -u || true
if grep -qE 'Library not loaded|OS_REASON_DYLD' <<<"$LOG"; then echo "FAIL: dyld error in the log"; exit 1; fi
grep -q '\[TGZ:T13:PASS\]' <<<"$LOG" || { echo "FAIL: no [TGZ:T13:PASS] in the log"; exit 1; }
echo "PASS: alive, T13 passed, no dyld error"
