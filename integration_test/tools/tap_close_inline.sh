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
# Polls the device UI for the inline paywall's close button (content-desc is
# the EXACT token "action:close", see the matcher note below) and taps its
# center, then verifies the tap actually did something before declaring
# success. Run it concurrently with the test:
#   bash integration_test/tools/tap_close_inline.sh emulator-5554 &
#
# Exits 0 once the close node has disappeared from the UI tree, 1 on timeout.
DEV="${1:-emulator-5554}"
DESC="action:close"
FAIL_SHOT="/tmp/e2e_rn_t25_close_fail_$(date +%s).png"

dump_and_match() {
  # $1 = point-nudge in [0..3], used to jitter the tap point across retries.
  adb -s "$DEV" exec-out uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1
  adb -s "$DEV" pull /sdcard/uidump.xml /tmp/uidump_close_inline.xml >/dev/null 2>&1
  python3 - "$DESC" "$1" <<'PY'
import sys, re
desc, nudge = sys.argv[1], int(sys.argv[2])
try:
    xml = open('/tmp/uidump_close_inline.xml', encoding='utf-8').read()
except Exception:
    sys.exit(0)
for m in re.finditer(r'<node\b[^>]*>', xml):
    tag = m.group(0)
    cd = re.search(r'content-desc="([^"]*)"', tag)
    if not cd:
        continue
    # Exact-token match, not substring: a plan row's combined descriptor like
    # "action:purchase,plan:monthly; action:close_all" contains "action:close"
    # as a literal PREFIX of "action:close_all" — a naive `desc in text` match
    # picks that decoy (a loading/purchase row, inert at tap time) whenever it
    # sorts before the real header button in the UI-tree dump, which is what
    # happened on the CI emulator's narrow 320x640 layout (T25 always timed
    # out there despite the driver reporting a "successful" tap). Splitting on
    # ';' and comparing each token exactly rules the decoy out: "action:close"
    # is never one of its tokens, only a prefix of "action:close_all".
    tokens = [t.strip() for t in cd.group(1).split(';')]
    if desc not in tokens:
        continue
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
    if b:
        x1, y1, x2, y2 = map(int, b.groups())
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        # Nudge within the bounds on retries in case the dead center is ever
        # a bad hit-test spot (icon padding, ripple mask edge, ...).
        offsets = [(0, 0), (-5, 0), (5, 0), (0, -5)]
        dx, dy = offsets[nudge % len(offsets)]
        cx = min(max(cx + dx, x1 + 1), x2 - 1)
        cy = min(max(cy + dy, y1 + 1), y2 - 1)
        print(f"{cx}|{cy}|[{x1},{y1}][{x2},{y2}]")
        break
PY
}

for attempt in $(seq 1 5); do
  # Find the button — poll up to 90s only on the first attempt (rendering may
  # still be in flight); retries just need one fresh dump.
  found=""
  polls=$([ "$attempt" -eq 1 ] && echo 90 || echo 1)
  for i in $(seq 1 "$polls"); do
    result=$(dump_and_match $((attempt - 1)))
    if [ -n "$result" ]; then
      found="$result"
      break
    fi
    sleep 1
  done

  if [ -z "$found" ]; then
    echo "[tap_close_inline] close button not found after polling (attempt $attempt)"
    continue
  fi

  IFS='|' read -r tap_x tap_y bounds <<< "$found"
  echo "[tap_close_inline] found '$DESC' at $tap_x $tap_y bounds=$bounds (attempt $attempt)"
  adb -s "$DEV" shell input tap "$tap_x" "$tap_y"
  echo "[tap_close_inline] tapped"

  # Verify the tap actually did something: poll up to ~8s for the close node
  # to vanish from the tree (view torn down / re-rendered without it). A tap
  # that lands on dead UI (the substring-collision decoy, or a transient
  # overlay) leaves the exact same node sitting at the exact same bounds.
  for i in $(seq 1 8); do
    sleep 1
    still_there=$(dump_and_match 0)
    if [ -z "$still_there" ]; then
      echo "[tap_close_inline] close button gone after tap — success"
      exit 0
    fi
  done
  echo "[tap_close_inline] close button still present ${i}s after tap (attempt $attempt) — retrying"
done

echo "[tap_close_inline] close button never dismissed after 5 attempts"
adb -s "$DEV" exec-out screencap -p > "$FAIL_SHOT" 2>/dev/null
echo "[tap_close_inline] saved failure screenshot to $FAIL_SHOT"
exit 1
