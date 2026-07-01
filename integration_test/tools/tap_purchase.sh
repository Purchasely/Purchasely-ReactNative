#!/bin/bash
# Host-side UI driver for T9 (interceptor_trigger).
#
# Polls the device UI for the Purchasely purchase button (content-desc contains
# "action:purchase") and taps its center. Run it concurrently with the test:
#   bash integration_test/tools/tap_purchase.sh emulator-5554 &
#
# Exits 0 after a successful tap, 1 on timeout.
# Source: identical to Flutter integration_test/tools/tap_purchase.sh
DEV="${1:-emulator-5554}"
DESC="action:purchase"
for i in $(seq 1 90); do
  adb -s "$DEV" exec-out uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1
  adb -s "$DEV" pull /sdcard/uidump.xml /tmp/uidump_tap.xml >/dev/null 2>&1
  coords=$(python3 - "$DESC" <<'PY'
import sys, re
desc = sys.argv[1]
try:
    xml = open('/tmp/uidump_tap.xml', encoding='utf-8').read()
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
    echo "[tap_purchase] found '$DESC' at $coords (iter $i)"
    adb -s "$DEV" shell input tap $coords
    echo "[tap_purchase] tapped"
    exit 0
  fi
  sleep 1
done
echo "[tap_purchase] button not found after polling"
exit 1
