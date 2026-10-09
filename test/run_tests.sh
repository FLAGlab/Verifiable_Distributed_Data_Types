#!/bin/bash
# Runs the tests of Code/test/ and the two example files of Code/.
# A test passes when its Athena output contains no "error" line (any case).
#
# Usage:  ./run_tests.sh                 quick mode, all tests (about 20 minutes)
#         ./run_tests.sh t_dpair         quick mode, only the named tests (without .ath)
#         ./run_tests.sh --night         night mode: long Vampire limits, larger
#                                        enumerations, whole assumption base (hours)
#         ./run_tests.sh --night t_enum_dht
#
# The limits of each mode are in mode.ath. --night writes the night values
# into mode.ath for the run and restores the quick values at the end, so do
# not run a quick and a night run at the same time.
#
# Only one run at a time: Athena writes its Vampire input and output files to
# $ATHENA_HOME/tmp/vamp.*.N, numbered by a counter that starts at 0 in every
# Athena process, so two processes that call Vampire overwrite each other's
# files. Logs go to logs/<date>_<mode>/ and are kept.

cd "$(dirname "$0")" || exit 2
command -v athena >/dev/null || { echo "athena not on PATH (set ATHENA_HOME)"; exit 2; }

mode=quick
if [ "$1" = "--night" ]; then
    mode=night
    shift
fi

if [ "$mode" = night ]; then
    cp mode.ath .mode.quick.ath
    trap 'mv -f .mode.quick.ath mode.ath' EXIT
    cat > mode.ath <<'EOF'
### mode.ath (NIGHT settings, written by run_tests.sh --night; restored at the end)
module Mode {
    define name             := "night"
    define vp-time          := 200
    define consistency-time := 400
    define full-ab-time     := 1800
    define enum-time        := 120
    define enum-ring        := 4
    define enum-rv          := 3
    define enum-key         := 5
    define enum-query-ring  := 3
    define enum-query-rv    := 1
    define enum-query-key   := 2
    define enum-two-ring    := 2
    define enum-two-key     := 2
}
EOF
fi

logs="logs/$(date +%Y-%m-%d_%H%M)_$mode"
mkdir -p "$logs"
status=0

if [ $# -gt 0 ]; then
    tests=("$@")
else
    tests=(t_*.ath dlls_ncf_examples.ath dlls_index_examples.ath)
fi

echo "mode: $mode   logs: $logs   started: $(date)"
for t in "${tests[@]}"; do
    f="${t%.ath}.ath"
    name=$(basename "$f" .ath)
    start=$(date +%s)
    echo "RUN   $name   started $(date +%H:%M)"
    ( cd "$(dirname "$f")" && echo quit | timeout 43200 athena "$(basename "$f")" ) > "$logs/$name.txt" 2>&1
    secs=$(( $(date +%s) - start ))
    errs=$(grep -ci 'error' "$logs/$name.txt")
    thms=$(grep -c '^Theorem:' "$logs/$name.txt")
    if [ "$errs" -eq 0 ]; then
        printf 'PASS  %-24s %4d theorems  %6ds\n' "$name" "$thms" "$secs"
    else
        printf 'FAIL  %-24s (see %s)\n' "$name" "$logs/$name.txt"
        grep -i -m3 -A4 'error' "$logs/$name.txt" | sed 's/^/      /'
        status=1
    fi
    grep -h '^CONSISTENCY\|^ENUM' "$logs/$name.txt" | grep -v '^ENUM progress' | sed 's/^/      /'
done
echo "finished: $(date)"

exit $status
