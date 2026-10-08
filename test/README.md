# Tests for the Athena development

Concrete examples that exercise the definitions and the theorems of the paper on small
inputs, with edge cases. They complement the proofs. A proof can be correct while a
definition says something unintended, and an asserted sentence can be false. Both kinds of
error show up when a definition or a theorem is run on a concrete example.

## Running

```sh
cd Code/test
./run_tests.sh              # every t_*.ath, plus ../dlls_ncf_examples and ../dlls_index_examples
./run_tests.sh t_dpair      # only the named tests
```

`ATHENA_HOME` must be set and `athena` must be on `PATH` (see `~/.zshrc`). A test passes when
its output has no `error` line. Each test loads the whole development (`../sensor_app`), so
it runs against exactly the sentences the paper uses. Tests run with
`echo quit | athena <file>`, which is safe to run next to other Athena processes.

The whole suite takes about 20 minutes. Most of it is `t_consistency.ath` (about 10 minutes)
and `t_dht_running.ath` (about 1 minute).

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

## Files

| File | Paper | What it checks |
| --- | --- | --- |
| `common.ath` | | Loads the development. Defines `L` (alive), `U` (dead), numerals, `vp`, `expect-no-refutation`. |
| `premises.ath` | | The asserted sentences of each module, grouped for Vampire. |
| `t_dpair.ath` | 3.2 | Destructors per location. Structural equality versus `dpr-equiv` (two unobservable pairs with different values are equivalent but not equal). `pr-equiv` fails with one dead location. |
| `t_dfunction.ath` | 3.3 | Fault tolerance with both, one or no alive location. Composition order with two functions that do not commute. Composition fails when either stage has no alive location. |
| `t_dht_empty.ath` | 3.4 | Empty tables with the table location alive or dead, every bucket dead, or no buckets at all (why the replication theorem needs a non-empty bucket list). |
| `t_dht_running.ath` | 3.4 | Running example: ring `L U L`, `rv = 1`, inserts 1, 4, 2. Key 4 hashes past the end of the ring and collides with 1. Availability through `dht_replication_correctness`, query answers through `query_fc_insert`, values `{1, 4, 2}`, and `dht_functional_correctness` applied to the final table. |
| `t_dht_failures.ath` | 3.4 | Proves that the earlier, asserted `dht_functional_correctness` is false. Shows that each hypothesis of the replication theorem is needed, windows longer than the ring, and hash values past the end of the ring. |
| `t_crdt.ath` | 3.5 | Reordered and duplicated messages converge. The state holds exactly the added values. Different messages give different states. A non-add operation is outside the theorem. Empty mailboxes. |
| `t_consistency.ath` | | Vampire tries to derive `false` from the asserted sentences of each module separately. |
| `probe_vampire_misses_old_dfc.ath` | | Not run by default (about 10 minutes). Records that Vampire does not refute the false `dht_functional_correctness` even from the DHT definitions alone. |

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
