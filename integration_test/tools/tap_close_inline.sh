#!/bin/bash
# Host-side UI driver for T25 (embedded PLYPresentationView close).
#
# Unlike Flutter's `integration_test` package (see the Flutter repo's
# INLINE_PAYWALL_CLOSE.md), the RN E2E harness drives the REAL running app via
# adb/uiautomator, not an in-process widget-test pointer binding — the
# embedded view is a real Android Fragment in the real view hierarchy
# (PurchaselyViewManager.createFragment), so an OS-level tap on its close (X)
# button reaches it exactly like any other on-screen view.
#
# Polls the device UI for the inline paywall's close button (content-desc
# contains "action:close") and taps its center. Run it concurrently with the
# test:
#   bash integration_test/tools/tap_close_inline.sh emulator-5554 &
#
# Exits 0 after a successful tap, 1 on timeout.
DEV="${1:-emulator-5554}"
DESC="action:close"
for i in $(seq 1 90); do
  adb -s "$DEV" exec-out uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1
  adb -s "$DEV" pull /sdcard/uidump.xml /tmp/uidump_close_inline.xml >/dev/null 2>&1
  coords=$(python3 - "$DESC" <<'PY'
import sys, re
desc = sys.argv[1]
try:
    xml = open('/tmp/uidump_close_inline.xml', encoding='utf-8').read()
except Exception:
    sys.exit(0)
for m in re.finditer(r'<node\b[^>]*>', xml):
    tag = m.group(0)
    cd = re.search(r'content-desc="([^"]*)"', tag)
    if cd and desc in cd.group(1):
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
        if b:
            x1, y1, x2, y2 = map(int, b.groups())
            print((x1 + x2) // 2, (y1 + y2) // 2)
            break
PY
)
  if [ -n "$coords" ]; then
    echo "[tap_close_inline] found '$DESC' at $coords (iter $i)"
    adb -s "$DEV" shell input tap $coords
    echo "[tap_close_inline] tapped"
    exit 0
  fi
  sleep 1
done
echo "[tap_close_inline] close button not found after polling"
exit 1
