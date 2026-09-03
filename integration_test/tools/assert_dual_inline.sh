#!/bin/bash
# Host-side assertion + visual capture for T29 (two embedded PLYPresentationView
# mounted at once) -- Android.
#
# React Native reuses ONE view-manager instance across every
# `<PLYPresentationView />`. `PurchaselyViewManager` used to keep `propWidth` /
# `propHeight` on the manager itself, so the last view to receive its style
# forced its dimensions on both, and one banner rendered clipped.
#
# JS cannot see that: the sizes that go wrong belong to the NATIVE children, and
# the RN containers keep the heights the test set regardless. So the proof is
# read from the real view hierarchy: `uiautomator dump` gives the measured bounds
# of the SDK's own paywall content view (`:id/content`, from ply_template_view),
# one per mounted banner. Their heights must differ, and must track the two
# container heights the runner asked for.
#
# A screenshot is captured alongside as the visual artifact -- it is the thing a
# human reads, not the thing the test trusts.
#
# Usage:
#   bash integration_test/tools/assert_dual_inline.sh <device> <tall_dp> <short_dp> [out_dir]
#
# Exits 0 when the two native views have distinct heights matching the request,
# 1 otherwise (and still writes the screenshot, which is when you most want it).

set -uo pipefail

DEV="${1:?usage: assert_dual_inline.sh <device> <tall_dp> <short_dp> [out_dir]}"
TALL_DP="${2:?missing tall_dp}"
SHORT_DP="${3:?missing short_dp}"
OUT_DIR="${4:-/tmp}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t29_dual_inline_android.png"
DUMP="$OUT_DIR/e2e_t29_dual_inline_android.xml"

# The paywall content settles a frame or two after PRESENTATION_VIEWED.
sleep 2

echo "[assert_dual_inline] capturing screenshot -> $SHOT"
adb -s "$DEV" exec-out screencap -p > "$SHOT" 2>/dev/null

# `uiautomator dump` grabs the single UiAutomation connection the platform
# allows. T25's close driver polls the same way and can still be retrying, which
# makes this dump die on "UiAutomationService already registered". Retry rather
# than serialise the drivers: the window is short and a retry costs a second.
for attempt in $(seq 1 10); do
  adb -s "$DEV" exec-out uiautomator dump /sdcard/uidump_dual.xml >/dev/null 2>&1
  adb -s "$DEV" pull /sdcard/uidump_dual.xml "$DUMP" >/dev/null 2>&1
  if [ -s "$DUMP" ] && grep -q '<node' "$DUMP" 2>/dev/null; then
    break
  fi
  echo "[assert_dual_inline] view dump unavailable (attempt $attempt) — retrying"
  sleep 1
done

# Density: bounds are in PIXELS, the runner asked in dp.
DENSITY=$(adb -s "$DEV" shell wm density 2>/dev/null | sed -n 's/.*: *\([0-9][0-9]*\).*/\1/p' | tail -1)
DENSITY="${DENSITY:-160}"

python3 - "$DUMP" "$TALL_DP" "$SHORT_DP" "$DENSITY" <<'PY'
import re, sys

dump_path, tall_dp, short_dp, density = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
scale = density / 160.0

try:
    xml = open(dump_path, encoding='utf-8').read()
except Exception as e:
    print(f"[assert_dual_inline] cannot read {dump_path}: {e}")
    sys.exit(1)

# The SDK inflates ply_template_view for every PLYPresentationView; its root
# content FrameLayout carries `<app package>:id/content`. One node per mounted
# banner, in tree order, which is top-to-bottom on screen for this layout.
nodes = []
for m in re.finditer(r'<node\b[^>]*>', xml):
    tag = m.group(0)
    rid = re.search(r'resource-id="([^"]*)"', tag)
    # `android:id/content` is the activity's own content frame and ends the same
    # way; only the app-package one belongs to an inflated ply_template_view.
    if not rid or not rid.group(1).endswith(':id/content') or rid.group(1).startswith('android:'):
        continue
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
    if not b:
        continue
    x1, y1, x2, y2 = map(int, b.groups())
    nodes.append({'top': y1, 'height': y2 - y1, 'width': x2 - x1, 'bounds': f"[{x1},{y1}][{x2},{y2}]"})

nodes.sort(key=lambda n: n['top'])

for n in nodes:
    print(f"[assert_dual_inline] paywall content view bounds={n['bounds']} "
          f"height={n['height']}px ({n['height'] / scale:.0f}dp)")

if len(nodes) != 2:
    print(f"[assert_dual_inline] FAIL: expected 2 embedded paywall views, found {len(nodes)}")
    sys.exit(1)

tall, short = nodes[0], nodes[1]

# Both views collapsing to one size is the regression itself.
if tall['height'] == short['height']:
    print(f"[assert_dual_inline] FAIL: both embedded views measured {tall['height']}px — "
          "one view's style is being applied to the other (shared propWidth/propHeight)")
    sys.exit(1)

if tall['height'] <= short['height']:
    print(f"[assert_dual_inline] FAIL: the top banner ({tall['height']}px) is not taller than "
          f"the bottom one ({short['height']}px), but it was mounted in the {tall_dp}dp slot")
    sys.exit(1)

# Each native view must track ITS OWN container, not the other's. A generous
# tolerance: the SDK's own layout can inset the content, and the emulator
# rounds dp→px. What must not happen is a view landing on the other's height.
def close_enough(px, dp):
    expected = dp * scale
    return abs(px - expected) <= max(24.0, expected * 0.25)

ok = True
if not close_enough(tall['height'], tall_dp):
    print(f"[assert_dual_inline] FAIL: top banner is {tall['height']}px, expected ~{tall_dp * scale:.0f}px ({tall_dp}dp)")
    ok = False
if not close_enough(short['height'], short_dp):
    print(f"[assert_dual_inline] FAIL: bottom banner is {short['height']}px, expected ~{short_dp * scale:.0f}px ({short_dp}dp)")
    ok = False

if not ok:
    sys.exit(1)

print(f"[assert_dual_inline] PASS: {tall['height']}px ≠ {short['height']}px — "
      f"each embedded view kept its own height ({tall_dp}dp / {short_dp}dp @ {density}dpi)")
PY
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "[assert_dual_inline] screenshot of the failure: $SHOT"
  echo "[assert_dual_inline] view hierarchy dump: $DUMP"
fi
exit "$STATUS"
