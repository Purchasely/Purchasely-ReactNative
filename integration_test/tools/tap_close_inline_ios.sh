#!/bin/bash
# Host-side UI driver for T25 (embedded PLYPresentationView close) — iOS Simulator.
#
# iOS counterpart of tools/tap_close_inline.sh (Android/uiautomator). Unlike
# Flutter's `integration_test` package (see the Flutter repo's
# INLINE_PAYWALL_CLOSE.md), this harness drives the REAL running app via idb —
# not an in-process widget-test pointer binding.
#
# NOTE: the E2E fixture screen (nr011, placement `integration_test_audiences`)
# renders NO close (X) button on iOS in ANY presentation mode — confirmed via
# an `idb ui describe-all` dump while T25 was up (zero close-shaped elements)
# and independently by T9's swipe_dismiss_ios.sh, whose own close-button finder
# (identical keyword/size logic) also finds nothing full-screen and falls back
# to swipe. Android's counterpart screen DOES have a real close button, driven
# for real by tools/tap_close_inline.sh — this is a content/fixture difference
# between platforms, not an RN/SDK bridge bug. So on iOS this driver instead
# taps a real, always-on-screen E2E-only fallback button that E2ETestRunner.tsx
# renders on top of the embedded view (label "Close", wired to
# `request.close()`) — a genuine OS-level tap through the bridge, just not
# through the SDK's own (absent) close control. The matcher below is otherwise
# unchanged: it still matches by visible label text + a ≤120×120pt frame, which
# the fallback button satisfies (label "Close", 90×36pt).
#
# Deliberately has NO swipe-down fallback (unlike swipe_dismiss_ios.sh/T9): the
# embedded view is not a dismissible sheet, so a swipe gesture would not close
# it — if the close element can't be found, polling times out and this exits 1,
# which is the honest outcome (T25 then fails via its own waitFor(), not a
# false pass from a no-op gesture).
#
# Coordinate spaces: `ui describe-all` returns frames in POINTS, `idb ui tap`
# expects the same POINT space (see tap_purchase_ios.sh for the rationale).
#
# Usage:  bash integration_test/tools/tap_close_inline_ios.sh <UDID>
# Exits 0 after a successful tap, 1 on timeout.

UDID="${1:?usage: tap_close_inline_ios.sh <UDID>}"
IDB="${IDB:-idb}"
TMP="${TMPDIR:-/tmp}/tap_close_inline_ios_$$"
MATCHER="$TMP.py"
TREE="$TMP.json"
cleanup() { rm -f "$MATCHER" "$TREE"; }
trap cleanup EXIT

# The matcher reads the a11y JSON from a FILE (argv[2]) — NOT stdin — because a
# heredoc on `python3 -` would shadow a piped stdin and silently feed it nothing.
cat > "$MATCHER" <<'PY'
import sys, json, re

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
    px, py = int(round(x + w / 2)), int(round(y + h / 2))
    sys.stderr.write(f"[tap_close_inline_ios] match '{txt[:40]}' pt=({px},{py})\n")
    print(px, py)
    sys.exit(0)
PY

for i in $(seq 1 60); do
  $IDB ui describe-all --udid "$UDID" --json > "$TREE" 2>/dev/null
  coords=$(python3 "$MATCHER" "$TREE")
  if [ -n "$coords" ]; then
    echo "[tap_close_inline_ios] tapping at $coords (iter $i)"
    $IDB ui tap --udid "$UDID" $coords
    echo "[tap_close_inline_ios] tapped"
    exit 0
  fi
  sleep 1
done

echo "[tap_close_inline_ios] close button not found after polling"
exit 1
