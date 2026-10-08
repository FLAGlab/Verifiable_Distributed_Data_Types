#!/bin/bash
# Runs the tests of Code/test/ and the two example files of Code/.
# A test passes when its Athena output contains no "error" line (any case).
# Usage:  ./run_tests.sh            all tests
#         ./run_tests.sh t_dpair    only the named tests (without .ath)
# Each test is run with `echo quit | athena <file>`, which is safe to run in
# parallel with other Athena processes (athena-run is not).

cd "$(dirname "$0")" || exit 2
command -v athena >/dev/null || { echo "athena not on PATH (set ATHENA_HOME)"; exit 2; }

out=$(mktemp -d)
status=0

if [ $# -gt 0 ]; then
    tests=("$@")
else
    tests=(t_*.ath ../dlls_ncf_examples.ath ../dlls_index_examples.ath)
fi

for t in "${tests[@]}"; do
    f="${t%.ath}.ath"
    name=$(basename "$f" .ath)
    start=$(date +%s)
    ( cd "$(dirname "$f")" && echo quit | timeout 1800 athena "$(basename "$f")" ) > "$out/$name.txt" 2>&1
    secs=$(( $(date +%s) - start ))
    errs=$(grep -ci 'error' "$out/$name.txt")
    thms=$(grep -c '^Theorem:' "$out/$name.txt")
    if [ "$errs" -eq 0 ]; then
        printf 'PASS  %-24s %4d theorems  %4ds\n' "$name" "$thms" "$secs"
    else
        printf 'FAIL  %-24s (see %s)\n' "$name" "$out/$name.txt"
        grep -i -m3 -A4 'error' "$out/$name.txt" | sed 's/^/      /'
        status=1
    fi
    grep -h '^CONSISTENCY' "$out/$name.txt" | sed 's/^/      /'
done

exit $status
