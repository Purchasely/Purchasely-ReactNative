#!/bin/bash
# Host-side UI driver for T8 (purchase interceptor) — iOS Simulator.
#
# iOS counterpart of tools/tap_purchase.sh (Android/uiautomator). Polls the
# simulator's accessibility tree via `$IDB ui describe-all` and taps the centre
# of the most likely purchase CTA. The Purchasely iOS paywall is a binary pod,
# so we don't have a stable "action:purchase" identifier like Android's
# content-desc — we match on common CTA labels and fall back to the lowest
# button-shaped element.
#
# Coordinate spaces: `ui describe-all` returns frames in POINTS, but `idb ui
# tap` expects PIXELS — so we scale the centre by the screen density.
#
# Usage:  bash integration_test/tools/tap_purchase_ios.sh <UDID>
# Exits 0 after a successful tap, 1 on timeout.

UDID="${1:?usage: tap_purchase_ios.sh <UDID>}"
IDB="${IDB:-idb}"
TMP="${TMPDIR:-/tmp}/tap_ios_$$"
MATCHER="$TMP.py"
TREE="$TMP.json"
cleanup() { rm -f "$MATCHER" "$TREE"; }
trap cleanup EXIT

# The matcher reads the a11y JSON from a FILE (argv[2]) — NOT stdin — because a
# heredoc on `python3 -` would shadow a piped stdin and silently feed it nothing.
cat > "$MATCHER" <<'PY'
import sys, json, re

# idb ui tap uses POINT coordinates (same space as describe-all frames).
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

# CTA keywords (en/fr) commonly used on purchase buttons.
KEYWORDS = [
    'action:purchase', 'purchase', 'subscribe', 'continue', 'unlock',
    'start', 'try', 'trial', 'get ', 'upgrade', 'buy',
    'acheter', 'abonn', 'continuer', 'essai', 'essayer', 'commencer',
    "s'abonner", 'debloquer', 'débloquer',
]

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
    return ' '.join(str(p) for p in parts if p).lower()

def is_tappable(e):
    t = (e.get('type') or e.get('AXType') or '').lower()
    return 'button' in t or 'link' in t or e.get('AXTraits', 0)

candidates = []
for e in elems:
    fr = frame(e)
    if not fr:
        continue
    x, y, w, h = fr
    if w <= 0 or h <= 0:
        continue
    txt = text(e)
    score = 0
    for kw in KEYWORDS:
        if kw in txt:
            score += 10
            break
    if is_tappable(e):
        score += 2
    if w > 150 and 30 <= h <= 120:
        score += 2
    if score <= 0:
        continue
    cx, cy = x + w / 2, y + h / 2
    candidates.append((score, y, cx, cy, txt[:40]))

if not candidates:
    sys.exit(0)

candidates.sort(key=lambda c: (c[0], c[1]), reverse=True)
_, _, cx, cy, label = candidates[0]
px, py = int(round(cx)), int(round(cy))
sys.stderr.write(f"[tap_purchase_ios] match '{label}' pt=({px},{py})\n")
print(px, py)
PY

for i in $(seq 1 90); do
  $IDB ui describe-all --udid "$UDID" --json > "$TREE" 2>/dev/null
  coords=$(python3 "$MATCHER" "$TREE")
  if [ -n "$coords" ]; then
    echo "[tap_purchase_ios] tapping at $coords (iter $i)"
    $IDB ui tap --udid "$UDID" $coords
    echo "[tap_purchase_ios] tapped"
    exit 0
  fi
  sleep 1
done

echo "[tap_purchase_ios] purchase button not found after polling"
exit 1
