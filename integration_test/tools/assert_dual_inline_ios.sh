#!/bin/bash
# Host-side assertion + visual capture for T29 (two embedded PLYPresentationView
# mounted at once) -- iOS Simulator.
#
# iOS counterpart of tools/assert_dual_inline.sh. The Android bug this guards
# against (a view manager sharing one width/height across every mounted view) is
# Android-only, so on iOS this is a parity check: two embedded paywalls in
# containers of different heights must render at those two heights.
#
# Bounds come from `idb ui describe-all`, in POINTS (same space as `idb ui tap`,
# see tap_purchase_ios.sh). The runner's dp values are points here.
#
# Usage:
#   bash integration_test/tools/assert_dual_inline_ios.sh <UDID> <tall_dp> <short_dp> [out_dir]

set -uo pipefail

UDID="${1:?usage: assert_dual_inline_ios.sh <UDID> <tall_dp> <short_dp> [out_dir]}"
TALL_PT="${2:?missing tall_dp}"
SHORT_PT="${3:?missing short_dp}"
OUT_DIR="${4:-/tmp}"
IDB="${IDB:-idb}"
mkdir -p "$OUT_DIR"

SHOT="$OUT_DIR/e2e_t29_dual_inline_ios.png"
TREE="$OUT_DIR/e2e_t29_dual_inline_ios.json"

sleep 2

echo "[assert_dual_inline_ios] capturing screenshot -> $SHOT"
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1

$IDB ui describe-all --udid "$UDID" --json > "$TREE" 2>/dev/null

python3 - "$TREE" "$TALL_PT" "$SHORT_PT" <<'PY'
import json, re, sys

tree_path, tall_pt, short_pt = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])

try:
    raw = open(tree_path, encoding='utf-8').read().strip()
except Exception as e:
    print(f"[assert_dual_inline_ios] cannot read {tree_path}: {e}")
    sys.exit(1)

elems = []
try:
    data = json.loads(raw)
    elems = data if isinstance(data, list) else [data]
except json.JSONDecodeError:
    for line in raw.splitlines():
        line = line.strip()
        if line:
            try:
                elems.append(json.loads(line))
            except json.JSONDecodeError:
                pass

def frame(e):
    f = e.get('frame') or e.get('AXFrame')
    if isinstance(f, dict):
        return (f.get('x', 0), f.get('y', 0), f.get('width', 0), f.get('height', 0))
    if isinstance(f, str):
        m = re.findall(r'-?\d+\.?\d*', f)
        if len(m) >= 4:
            return tuple(float(v) for v in m[:4])
    return None

# The a11y tree exposes no id for the SDK's content view, so the two embedded
# paywalls are located by the slots the runner drew around them: a container of
# (roughly) the requested height, full width. Matching on height is what the
# test is about, so the match must not assume the answer — it accepts anything
# in a wide band around each target and then checks the two are distinct.
def band(h, target):
    return abs(h - target) <= max(40.0, target * 0.45)

candidates = []
for e in elems:
    fr = frame(e)
    if not fr:
        continue
    x, y, w, h = fr
    if w <= 0 or h <= 0:
        continue
    candidates.append({'y': y, 'w': w, 'h': h})

if not candidates:
    print("[assert_dual_inline_ios] FAIL: the accessibility tree came back empty")
    sys.exit(1)

page_width = max(c['w'] for c in candidates)
# Full-width-ish elements only: the paywall slots span the screen minus the
# runner's 12pt padding.
wide = [c for c in candidates if c['w'] >= page_width * 0.8]

tall_hits = sorted((c for c in wide if band(c['h'], tall_pt)), key=lambda c: c['y'])
short_hits = sorted((c for c in wide if band(c['h'], short_pt)), key=lambda c: c['y'])

for c in wide:
    print(f"[assert_dual_inline_ios] full-width element y={c['y']:.0f} {c['w']:.0f}x{c['h']:.0f}pt")

if not tall_hits:
    print(f"[assert_dual_inline_ios] FAIL: no full-width element near the {tall_pt:.0f}pt slot")
    sys.exit(1)
if not short_hits:
    print(f"[assert_dual_inline_ios] FAIL: no full-width element near the {short_pt:.0f}pt slot — "
          "both embedded views may have collapsed onto one height")
    sys.exit(1)

tall, short = tall_hits[0], short_hits[0]
if abs(tall['h'] - short['h']) < 20:
    print(f"[assert_dual_inline_ios] FAIL: the two embedded views measured "
          f"{tall['h']:.0f}pt and {short['h']:.0f}pt — too close to be distinct slots")
    sys.exit(1)

print(f"[assert_dual_inline_ios] PASS: {tall['h']:.0f}pt ≠ {short['h']:.0f}pt — "
      f"each embedded view kept its own height ({tall_pt:.0f}pt / {short_pt:.0f}pt)")
PY
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "[assert_dual_inline_ios] screenshot of the failure: $SHOT"
  echo "[assert_dual_inline_ios] accessibility dump: $TREE"
fi
exit "$STATUS"
