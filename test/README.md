# Tests for the Athena development

Concrete examples that exercise the definitions and the theorems of the paper on small
inputs, with edge cases. They complement the proofs. A proof can be correct while a
definition says something unintended, and an asserted sentence can be false. Both kinds of
error show up when a definition or a theorem is run on a concrete example.

## Running

```sh
cd Code/test
./run_tests.sh                    # quick mode: every t_*.ath, plus dlls_ncf_examples and dlls_index_examples
./run_tests.sh t_dpair            # quick mode, only the named tests
./run_tests.sh --night            # night mode, every test (hours)
nohup ./run_tests.sh --night > night.out 2>&1 &   # leave it running overnight
```

`ATHENA_HOME` must be set and `athena` must be on `PATH` (see `~/.zshrc`). A test passes when
its output has no `error` line. Each test loads the whole development (`../sensor_app`), so
it runs against exactly the sentences the paper uses. Tests run with
`echo quit | athena <file>`. The log of every test is kept in `logs/<date>_<mode>/`, and the
runner prints a `RUN` line when each test starts.

The folder also holds `dlls_ncf_examples.ath` and `dlls_index_examples.ath`, concrete checks of
`no_consecutive_failures` and of the bucket index that the comments in `dlls.ath` refer to. They
load only `../dlls`, not the whole development. `VAMPIRE.md` explains how to call Vampire.

Run only one suite at a time, and no other Athena process that calls Vampire. Athena writes its
Vampire input and output files to `$ATHENA_HOME/tmp/vamp.*.N`, numbered by a counter that
starts at 0 in every Athena process, so two such processes overwrite each other's files.

### Quick and night modes

The limits are in `mode.ath`. The checked-in file holds the quick values. `--night` writes the
night values into `mode.ath` for the run and restores the quick ones at the end, so a quick and
a night run must not overlap.

| Setting | Quick | Night | Used by |
| --- | --- | --- | --- |
| `vp-time` | 60 s | 300 s | every concrete Vampire call |
| `consistency-time` | 60 s | 600 s | each module in `t_consistency.ath` |
| `full-ab-time` | skipped | 1800 s | all definitions together, and the whole assumption base |
| `enum-time` | 30 s | 120 s | each step of `t_enum_dht.ath` |
| `enum-ring`, `enum-rv`, `enum-key` | 3, 2, 3 | 4, 3, 5 | groups 1 to 4 of `t_enum_dht.ath` |
| `enum-query-ring`, `-rv`, `-key` | 2, 1, 2 | 3, 1, 2 | groups 5 and 7 |
| `enum-two-ring`, `enum-two-key` | 2, 1 | 2, 2 | group 6 |

Vampire runs two strategies one after the other, each with the time limit, so a call can take
twice the limit. The quick suite takes about 20 minutes. The night suite is sized for about
9 hours: about 4 hours of consistency checks and about 5 hours of enumeration (some 12,000
Vampire calls, at about 1.7 s each in the run of 2026-10-08). The first night run used larger
enumeration bounds and would have needed two to three days, so it was stopped after the
first three groups (4,712 steps, all passing).

`t_enum_dht.ath` prints `ENUM progress` every 500 passing steps in its log
(`logs/<date>_<mode>/t_enum_dht.txt`). Athena may buffer its output, so the log can lag
behind.

## Conventions

* Every check is positive. A property that must not hold is tested by proving its
  negation.
* Concrete computations are sent to Vampire with `vp` (defined in `common.ath`), always with
  a short premise list. Vampire is strong on small premise sets and weak on the whole
  assumption base.
* Results obtained with `vp` are trusted from Vampire, not checked by Athena. Instances of the
  proven theorems (`!uspec*`, `!mp`) are checked by Athena. Each file says which is which.
* Test-local symbols (for example `kz` and `inc` in `t_dfunction.ath`, `rem` in `t_crdt.ath`)
  are fresh constants with defining equations or a distinctness fact. They cannot make the
  assumption base inconsistent.

## What the consistency checks can and cannot show

`t_consistency.ath` reports "no refutation within the time limit" for each module. That is
evidence, not a proof. A proof of consistency needs a model, and the natural numbers have no
finite model, so no finite model finder can certify the whole theory.

The probe file shows the limit concretely. The false `dht_functional_correctness` made the
assumption base inconsistent, and Vampire did not find the contradiction, neither from the
whole assumption base nor from the 104 DHT definitions alone. The contradiction needs a
concrete table and about ten unfoldings of recursive definitions. `t_dht_failures.ath` finds
it in seconds, by building that table step by step.

So the concrete tests are the main check. When a definition changes, add or update the test
that runs it on a small example, and run every test that mentions it.

## Adding a test

1. Create `t_<name>.ath` with `load "common"` and one module `T_<Name>`.
2. Build the example with `define`, compute with `(!vp goal premises)`, and instantiate the
   theorems with `!uspec*` and `!mp`.
3. Say in the header comment what the test checks and which results come from Vampire.
4. Run `./run_tests.sh t_<name>`.

Athena pitfalls met while writing these tests:

* A deduction written inside a premise list, as in `(!vp g [(!uspec ax t)])`, is evaluated
  but its result is not in the assumption base, so `vprove-from` rejects it. Bind it first
  with `define`.
* In a test module, `(?b <==> (p | ?b0))` with Boolean term variables fails with
  "Could not find a value for MOR". Write `(iff ?b (or p ?b0))` instead.
* `seq` is reserved, and `tl`, `c` and `p` are already bound after loading the development.
  Pick distinctive names.
* A deduction run inside a procedure (for example inside `map` or a `let` of a procedure body)
  extends the assumption base only within that expression. Its result is not available to
  later calls as a `vprove-from` premise. `t_enum_dht.ath` therefore proves each step under
  `assume`s of the steps already proved (the method `under`).
