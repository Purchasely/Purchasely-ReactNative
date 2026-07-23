#!/bin/bash
# Host-side UI driver for T10 (default_dismiss_handler).
#
# Waits for a Purchasely paywall to render (any content-desc containing "action:")
# then presses the system BACK button to dismiss it. Run it concurrently:
#   bash integration_test/tools/press_back.sh emulator-5554 &
#
# Exits 0 after pressing BACK, 1 on timeout.
# Source: identical to Flutter integration_test/tools/press_back.sh
DEV="${1:-emulator-5554}"
for i in $(seq 1 60); do
  adb -s "$DEV" exec-out uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1
  adb -s "$DEV" pull /sdcard/uidump.xml /tmp/uidump_back.xml >/dev/null 2>&1
  if grep -q 'action:' /tmp/uidump_back.xml 2>/dev/null; then
    echo "[press_back] paywall detected (iter $i), pressing BACK"
    sleep 1
    adb -s "$DEV" shell input keyevent 4
    echo "[press_back] BACK pressed"
    exit 0
  fi
  sleep 1
done
echo "[press_back] paywall not detected after polling"
exit 1
