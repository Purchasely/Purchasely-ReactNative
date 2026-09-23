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
def attr(tag, k):
    m = re.search(k + r'="([^"]*)"', tag)
    return m.group(1) if m else ''

def bounds(tag):
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
    return tuple(map(int, b.groups())) if b else None

nodes = [m.group(0) for m in re.finditer(r'<node\b[^>]*>', xml)]
for tag in nodes:
    b = bounds(tag)
    if b and desc in attr(tag, 'content-desc'):
        print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
        sys.exit(0)

# Android SDK >= 6.1.1 (MOB-471) moved the action metadata out of content-desc
# into a view tag uiautomator cannot read. Fallback: the first clickable SDK
# node with no label of its own that holds a price text ("... per ...").
prices = [bounds(t) for t in nodes if re.search(r'\bper\b', attr(t, 'text')) and bounds(t)]
for tag in nodes:
    b = bounds(tag)
    if not b or attr(tag, 'package') != 'com.purchasely.demo' or attr(tag, 'clickable') != 'true':
        continue
    if attr(tag, 'text') or attr(tag, 'content-desc'):
        continue
    if any(b[0] <= p[0] and b[1] <= p[1] and p[2] <= b[2] and p[3] <= b[3] for p in prices):
        print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
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
