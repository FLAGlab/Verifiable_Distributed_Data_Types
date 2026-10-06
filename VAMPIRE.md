# Running Vampire from Athena

Athena can send a goal and a list of premises to the Vampire theorem prover with the
`vprove-from` method. We use it to check that the axioms of the project are consistent and
to try to prove lemmas that are still asserted.

## Setup

1. Install Vampire. On Manjaro, the AUR package `vampire-bin` puts it in `/usr/bin/vampire`.
2. Athena does not search `PATH` for Vampire. It looks for a file named `vampire` in the
   current directory or in `$ATHENA_HOME`.
3. Athena calls Vampire with `--mode casc`. Vampire 5.0.1 crashes in that mode after it
   finds a proof, and Athena then reports a failure. The script below first runs Vampire's
   default strategy. If that finds no proof, it runs the `snake_tptp_uns` portfolio. The
   default strategy is better on small goals that need case analysis, and the portfolio is
   better on large premise sets. Each stage gets the time limit given in `max-time`. Save
   the script as `$ATHENA_HOME/vampire` and run `chmod +x $ATHENA_HOME/vampire`.

```bash
#!/bin/bash
# Stage 1: default strategy (drop `--mode casc`).
# Stage 2: snake_tptp_uns portfolio instead of casc.
default=()
portfolio=()
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  a="${args[$i]}"
  if [ "$a" = "--mode" ] && [ "${args[$((i+1))]}" = "casc" ]; then
    portfolio+=(--mode portfolio --schedule snake_tptp_uns)
    i=$((i+2))
    continue
  fi
  default+=("$a")
  portfolio+=("$a")
  i=$((i+1))
done
out=$(mktemp)
/usr/bin/vampire "${default[@]}" > "$out" 2>/dev/null
if grep -q "Refutation found" "$out"; then
  cat "$out"; rm -f "$out"; exit 0
fi
rm -f "$out"
exec /usr/bin/vampire "${portfolio[@]}"
```

## Calling Vampire from Athena

```
(!vprove-from goal premises [['max-time 60]])
```

`goal` is a sentence, `premises` is a list of sentences, and `max-time` is in seconds. On
success the goal is added to the assumption base. On failure Athena reports
`Unable to derive the conclusion ...`.

Athena does not check the proof that Vampire finds. A theorem obtained this way depends on
Vampire being correct.

## Consistency check

Create a file such as `consistency_check.ath` in `Code/`:

```
load "sensor_app"
(!vprove-from false (ab) [['max-time 300]])
```

Run it with `athena-run consistency_check`.

- `Theorem: false` means the axioms are inconsistent. Vampire found a contradiction.
- `Unable to derive the conclusion false` means Vampire found no contradiction within the
  time limit. This is evidence of consistency, not a proof.

To see which axioms Vampire used, read the last output file in `$ATHENA_HOME/tmp`:

```sh
o=$(ls -t $ATHENA_HOME/tmp/vamp.o.* | head -1)
sed -n '/SZS output start/,/SZS output end/p' $o
```

The lines marked `axiom` are the premises in the proof. The matching input problem is the
file `vamp.in.*` with the same number.

## Proving an asserted lemma

Replace `assert lemma := P` with a call to Vampire on the axioms the lemma depends on:

```
define lemma := P
conclude lemma
  (!vprove-from lemma [ax1 ax2 ax3] [['max-time 60]])
```

A short list of premises works better than `(ab)`, because Vampire then searches a smaller
space.
