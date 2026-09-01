#!/bin/bash
# Host-side visual capture for T28 (embedded PLYPresentationView nested inside a
# react-native-screens screen) -- Android.
#
# T28's hard assertion is not here: on the unfixed iOS build the app is already
# dead by this point (UIViewControllerHierarchyInconsistency), so the test fails
# by the marker never arriving. This script only captures what the nesting looks
# like, as the artifact a human reads.
#
# Usage:
#   bash integration_test/tools/capture_nested_inline.sh <device> [out_dir]

set -uo pipefail

DEV="${1:?usage: capture_nested_inline.sh <device> [out_dir]}"
OUT_DIR="${2:-/tmp}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t28_nested_inline_android.png"

# Let the paywall settle inside the native screen before capturing.
sleep 2

echo "[capture_nested_inline] capturing screenshot -> $SHOT"
adb -s "$DEV" exec-out screencap -p > "$SHOT" 2>/dev/null

if [ ! -s "$SHOT" ]; then
  echo "[capture_nested_inline] screenshot came back empty"
  exit 1
fi

echo "[capture_nested_inline] captured $(wc -c < "$SHOT" | tr -d ' ') bytes"
exit 0
