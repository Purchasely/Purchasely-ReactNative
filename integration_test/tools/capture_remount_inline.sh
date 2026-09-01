#!/bin/bash
# Host-side visual capture for T30 (embedded view remounted under another
# react-native-screens screen) -- Android.
#
# Like T28's driver, the hard assertion is not here: on an implementation that
# cached the first parent controller, iOS would have raised
# `UIViewControllerHierarchyInconsistency` on the remount and the app would be
# dead before this runs. This captures the second mount for a human to read.
#
# Usage:
#   bash integration_test/tools/capture_remount_inline.sh <device> [out_dir]

set -uo pipefail

DEV="${1:?usage: capture_remount_inline.sh <device> [out_dir]}"
OUT_DIR="${2:-/tmp}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t30_remount_inline_android.png"

sleep 2

echo "[capture_remount_inline] capturing screenshot -> $SHOT"
adb -s "$DEV" exec-out screencap -p > "$SHOT" 2>/dev/null

if [ ! -s "$SHOT" ]; then
  echo "[capture_remount_inline] screenshot came back empty"
  exit 1
fi

echo "[capture_remount_inline] captured $(wc -c < "$SHOT" | tr -d ' ') bytes"
exit 0
