#!/bin/bash
# Host-side visual capture for T30 (embedded view remounted under another
# react-native-screens screen) -- iOS Simulator.
#
# Like T28's driver, the hard assertion is not here: on an implementation that
# cached the first parent controller, iOS would have raised
# `UIViewControllerHierarchyInconsistency` on the remount and the app would be
# dead before this runs. This captures the second mount for a human to read.
#
# Usage:
#   bash integration_test/tools/capture_remount_inline_ios.sh <UDID> [out_dir]

set -uo pipefail

UDID="${1:?usage: capture_remount_inline_ios.sh <UDID> [out_dir]}"
OUT_DIR="${2:-/tmp}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t30_remount_inline_ios.png"

sleep 2

echo "[capture_remount_inline_ios] capturing screenshot -> $SHOT"
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1

if [ ! -s "$SHOT" ]; then
  echo "[capture_remount_inline_ios] screenshot came back empty"
  exit 1
fi

echo "[capture_remount_inline_ios] captured $(wc -c < "$SHOT" | tr -d ' ') bytes"
exit 0
