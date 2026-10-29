#!/bin/bash
# Usage: launch_check_test.sh <launch check script>
# Runs the launch check against a fake `xcrun` and requires the right exit code for each case.
set -u
CHECK=$1
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
cat > "$DIR/xcrun" <<'EOF'
#!/bin/bash
case "$2" in
  launch)
    if [ "${FAKE_ALIVE:-1}" = 1 ]; then sleep 30 >/dev/null 2>&1 & echo "$3: $!"; else echo "$3: 999999"; fi ;;
  spawn)
    # Like `log show`: lines of the app always; lines of other processes only without a processID clause.
    printf '%b\n' "${FAKE_LOG:-}"
    case "$*" in *"processID == "*) ;; *) printf '%b\n' "${FAKE_OTHER_LOG:-}" ;; esac ;;
  terminate) exit "${FAKE_TERM_RC:-0}" ;;
esac
EOF
chmod +x "$DIR/xcrun"
failed=0
expect() { # <name> <expected exit: 0|nonzero> <FAKE_ALIVE> <FAKE_LOG> <FAKE_TERM_RC> [FAKE_OTHER_LOG]
  PATH="$DIR:$PATH" LAUNCH_WAIT=0 FAKE_ALIVE=$3 FAKE_LOG=$4 FAKE_TERM_RC=$5 FAKE_OTHER_LOG=${6:-} bash "$CHECK" udid app.app bundle.id >/dev/null 2>&1
  rc=$?
  if { [ "$2" = 0 ] && [ $rc -eq 0 ]; } || { [ "$2" = nonzero ] && [ $rc -ne 0 ]; }; then echo "PASS $1 (exit $rc)"; else echo "FAIL $1 (exit $rc, expected $2)"; failed=1; fi
}
expect "good run, terminate fails" 0 1 '[TGZ:START]\n[TGZ:T13:PASS]' 1
expect "dyld line next to T13 PASS" nonzero 1 '[TGZ:T13:PASS]\nLibrary not loaded: @rpath/Purchasely.framework/Purchasely' 0
expect "OS_REASON_DYLD line" nonzero 1 '[TGZ:T13:PASS]\nOS_REASON_DYLD' 0
expect "dyld line from another process" 0 1 '[TGZ:T13:PASS]' 0 'Library not loaded: other app'
expect "no T13 marker" nonzero 1 '[TGZ:START]' 0
expect "dead process" nonzero 0 '[TGZ:T13:PASS]' 0
exit $failed
