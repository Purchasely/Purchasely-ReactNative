#!/bin/bash
# Host-side UI driver for T9 (default dismiss handler) — iOS Simulator.
#
# iOS counterpart of tools/press_back.sh (Android BACK key). iOS has no system
# back button, so we dismiss the Purchasely paywall by either tapping its close
# (X) button — yielding closeReason 'button' — or, failing that, swiping the
# sheet down (closeReason 'backSystem'). Both are accepted by T9.
#
# Coordinate spaces: `ui describe-all` frames AND `idb ui tap`/`swipe` both use
# POINTS, so we use screen_dimensions.{width,height}_points for the swipe
# geometry and the element-frame centres directly for the close button.
#
# Usage:  bash integration_test/tools/swipe_dismiss_ios.sh <UDID>
# Exits 0 after dismissing, 1 on timeout.

UDID="${1:?usage: swipe_dismiss_ios.sh <UDID>}"
IDB="${IDB:-idb}"
TMP="${TMPDIR:-/tmp}/swipe_ios_$$"
FINDER="$TMP.py"
TREE="$TMP.json"
cleanup() { rm -f "$FINDER" "$TREE"; }
trap cleanup EXIT

# The finder reads the a11y JSON from a FILE (argv[2]) — NOT stdin — because a
# heredoc on `python3 -` would shadow a piped stdin and silently feed it nothing.
# It prints "<px> <py>" for a close button, or "SWIPE" if a paywall is up but no
# close button is found, or nothing otherwise.
cat > "$FINDER" <<'PY'
import sys, json, re

# idb ui tap/swipe use POINT coordinates (same space as describe-all frames).
path = sys.argv[1]
try:
    raw = open(path, encoding='utf-8').read().strip()
except Exception:
    sys.exit(0)
if not raw:
    sys.exit(0)

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

CLOSE_KW = ['close', 'fermer', 'dismiss', 'cancel', 'annuler', 'action:close']
PAYWALL_KW = ['action:', 'purchase', 'subscribe', 'abonn', 'acheter',
              'continue', 'continuer']

def frame(e):
    f = e.get('frame') or e.get('AXFrame')
    if isinstance(f, dict):
        return (f.get('x', 0), f.get('y', 0), f.get('width', 0), f.get('height', 0))
    if isinstance(f, str):
        m = re.findall(r'-?\d+\.?\d*', f)
        if len(m) >= 4:
            return tuple(float(v) for v in m[:4])
    return None

def text(e):
    parts = [e.get('AXLabel'), e.get('AXValue'), e.get('label'),
             e.get('title'), e.get('AXIdentifier'), e.get('identifier'),
             e.get('AXUniqueId')]
    return ' '.join(str(p) for p in parts if p).lower().strip()

paywall_up = any(any(k in text(e) for k in PAYWALL_KW) for e in elems)
if not paywall_up:
    sys.exit(0)

for e in elems:
    txt = text(e)
    if not txt:
        continue
    is_close = txt in ('x', '×') or any(k in txt for k in CLOSE_KW)
    if not is_close:
        continue
    fr = frame(e)
    if not fr:
        continue
    x, y, w, h = fr
    if w <= 0 or h <= 0 or w > 120 or h > 120:
        continue
    print(int(round(x + w / 2)), int(round(y + h / 2)))
    sys.exit(0)

print("SWIPE")
PY

# Point screen size for the swipe geometry.
$IDB describe --udid "$UDID" --json > "$TREE" 2>/dev/null
read PTW PTH < <(python3 -c "
import json
try:
    d = json.load(open('$TREE')).get('screen_dimensions', {})
    print(int(d.get('width_points', 390)), int(d.get('height_points', 844)))
except Exception:
    print(390, 844)
" 2>/dev/null || echo "390 844")

for i in $(seq 1 60); do
  $IDB ui describe-all --udid "$UDID" --json > "$TREE" 2>/dev/null
  res=$(python3 "$FINDER" "$TREE")
  if [ -z "$res" ]; then
    sleep 1
    continue
  fi
  if [ "$res" = "SWIPE" ]; then
    cx=$((PTW / 2)); y1=$((PTH / 4)); y2=$((PTH - PTH / 6))
    echo "[swipe_dismiss_ios] no close button — swiping down ${cx},${y1} -> ${cx},${y2} (iter $i)"
    sleep 1
    $IDB ui swipe --udid "$UDID" "$cx" "$y1" "$cx" "$y2" --duration 0.3
    echo "[swipe_dismiss_ios] swiped"
    exit 0
  fi
  echo "[swipe_dismiss_ios] close button at px $res (iter $i) — tapping"
  sleep 1
  $IDB ui tap --udid "$UDID" $res
  echo "[swipe_dismiss_ios] close tapped"
  exit 0
done

echo "[swipe_dismiss_ios] paywall not detected after polling"
exit 1
