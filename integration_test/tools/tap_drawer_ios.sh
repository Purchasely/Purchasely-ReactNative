#!/bin/bash
# Host-side UI driver for T31 (drawer closed by a real tap) — iOS Simulator.
#
# T31 reproduces the iOS 6.1.0/6.1.1 bug fixed in iOS SDK 6.1.2
# (Purchasely-iOS#790): after a Console-configured drawer was closed by its own
# button or by a tap on the scrim, the SDK window stayed alive, invisible and
# key above the app, so every later tap went nowhere.
#
# Modes:
#   button   tap the drawer's close button. Found by label in the a11y tree;
#            falls back to the top-right corner of the drawer (the fixture
#            screen is a 70% drawer, so its top edge is at 30% of the height).
#   outside  tap the scrim above the drawer, at 12% of the screen height.
#   probe    tap the centre of the screen, where E2ETestRunner.tsx shows a
#            full-screen React Native button after the drawer closed. The tap
#            goes by coordinates, NOT by a11y label: with the bug, the a11y
#            tree is the one of the leftover SDK window, and the point of the
#            probe is to find out whether an OS tap still reaches the app.
#
# Coordinate spaces: `ui describe-all` returns frames in POINTS, `idb ui tap`
# expects POINTS too (see tap_purchase_ios.sh).
#
# Usage:  bash integration_test/tools/tap_drawer_ios.sh <UDID> <button|outside|probe>

UDID="${1:?usage: tap_drawer_ios.sh <UDID> <button|outside|probe>}"
MODE="${2:?usage: tap_drawer_ios.sh <UDID> <button|outside|probe>}"
IDB="${IDB:-idb}"
TMP="${TMPDIR:-/tmp}/tap_drawer_ios_$$"
MATCHER="$TMP.py"
TREE="$TMP.json"
cleanup() { rm -f "$MATCHER" "$TREE"; }
trap cleanup EXIT

# Prints "W H" (screen size) on the first line, then "X Y" of a close-shaped
# element if one is found. Reads the a11y JSON from a FILE, not stdin (a
# heredoc on `python3 -` would shadow a piped stdin).
cat > "$MATCHER" <<'PY'
import sys, json, re

try:
    raw = open(sys.argv[1], encoding='utf-8').read().strip()
except Exception:
    sys.exit(0)
elems = []
try:
    data = json.loads(raw)
    elems = data if isinstance(data, list) else [data]
except json.JSONDecodeError:
    for line in raw.splitlines():
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

sw = sh = 0
for e in elems:
    fr = frame(e)
    if fr and fr[2] * fr[3] > sw * sh:
        sw, sh = fr[2], fr[3]
if not sw:
    sys.exit(0)
print(int(sw), int(sh))

CLOSE_KW = ['close', 'fermer', 'dismiss', 'action:close']
for e in elems:
    parts = [e.get('AXLabel'), e.get('AXValue'), e.get('label'), e.get('title'),
             e.get('AXIdentifier'), e.get('identifier'), e.get('AXUniqueId')]
    txt = ' '.join(str(p) for p in parts if p).lower().strip()
    if not (txt in ('x', '×') or any(k in txt for k in CLOSE_KW)):
        continue
    fr = frame(e)
    if not fr or fr[2] <= 0 or fr[3] <= 0 or fr[2] > 120 or fr[3] > 120:
        continue
    sys.stderr.write(f"[tap_drawer_ios] close match '{txt[:40]}'\n")
    print(int(fr[0] + fr[2] / 2), int(fr[1] + fr[3] / 2))
    break
PY

for i in $(seq 1 20); do
  $IDB ui describe-all --udid "$UDID" --json > "$TREE" 2>/dev/null
  out=$(python3 "$MATCHER" "$TREE")
  [ -n "$out" ] && break
  sleep 1
done
if [ -z "$out" ]; then
  echo "[tap_drawer_ios] could not read the screen size"
  exit 1
fi
read -r W H <<< "$(echo "$out" | sed -n 1p)"
CLOSE_XY=$(echo "$out" | sed -n 2p)

case "$MODE" in
  button)
    if [ -n "$CLOSE_XY" ]; then
      XY="$CLOSE_XY"
    else
      # ponytail: fixed corner of a 70% drawer; tune if the fixture screen changes.
      XY="$(( W - 32 )) $(( H * 30 / 100 + 32 ))"
      echo "[tap_drawer_ios] no labelled close button, corner fallback"
    fi ;;
  outside) XY="$(( W / 2 )) $(( H * 12 / 100 ))" ;;
  probe)   XY="$(( W / 2 )) $(( H / 2 ))" ;;
  *) echo "[tap_drawer_ios] unknown mode '$MODE'"; exit 1 ;;
esac

echo "[tap_drawer_ios] $MODE: tapping at $XY (screen ${W}x${H})"
$IDB ui tap --udid "$UDID" $XY
