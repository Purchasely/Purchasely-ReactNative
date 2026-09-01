#!/bin/bash
# Host-side visual capture for T28 (embedded PLYPresentationView nested inside a
# react-native-screens screen) -- iOS Simulator.
#
# This is the platform the test exists for. `PurchaselyView.attachController`
# used to declare the embedded controller a child of the app's ROOT view
# controller while its view sat under an `RNSScreen`; UIKit raises
# `UIViewControllerHierarchyInconsistency` as soon as the two disagree, and the
# app dies. So the hard assertion is not here — on an unfixed build the marker
# that triggers this script never arrives, and T28 fails by timeout.
#
# What this captures is the proof for a human: the paywall rendered, inside a
# real native screen, with the app still alive.
#
# Usage:
#   bash integration_test/tools/capture_nested_inline_ios.sh <UDID> [out_dir]

set -uo pipefail

UDID="${1:?usage: capture_nested_inline_ios.sh <UDID> [out_dir]}"
OUT_DIR="${2:-/tmp}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t28_nested_inline_ios.png"

sleep 2

echo "[capture_nested_inline_ios] capturing screenshot -> $SHOT"
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1

if [ ! -s "$SHOT" ]; then
  echo "[capture_nested_inline_ios] screenshot came back empty"
  exit 1
fi

echo "[capture_nested_inline_ios] captured $(wc -c < "$SHOT" | tr -d ' ') bytes"
exit 0
