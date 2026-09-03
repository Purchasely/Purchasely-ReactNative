#!/bin/bash
# Host-side visual capture for T29 (two embedded PLYPresentationView mounted at
# once) -- iOS Simulator.
#
# Deliberately NOT the counterpart of tools/assert_dual_inline.sh. On Android
# that script measures the two native views and its verdict fails the run,
# because the bug it guards (a view manager sharing one width/height across
# every mounted view) is an Android bug and `uiautomator dump` reports the SDK's
# own content view with its real bounds.
#
# iOS has no equivalent. `idb ui describe-all` returns the ACCESSIBILITY tree:
# labels and controls, not the plain container `UIView`s the paywalls live in.
# There is no element whose frame is the slot's, so any height assertion here
# would be a heuristic dressed up as a measurement — the kind of green tick that
# proves nothing. iOS therefore keeps what it can honestly claim: both views
# reported themselves rendered (asserted in JS by T29), and here is the picture.
#
# Usage:
#   bash integration_test/tools/capture_dual_inline_ios.sh <UDID> [out_dir]

set -uo pipefail

UDID="${1:?usage: capture_dual_inline_ios.sh <UDID> [out_dir]}"
OUT_DIR="${2:-/tmp}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t29_dual_inline_ios.png"

sleep 2

echo "[capture_dual_inline_ios] capturing screenshot -> $SHOT"
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1

if [ ! -s "$SHOT" ]; then
  echo "[capture_dual_inline_ios] screenshot came back empty"
  exit 1
fi

echo "[capture_dual_inline_ios] captured $(wc -c < "$SHOT" | tr -d ' ') bytes"
exit 0
