# Formally Verifiable Distributed Data Types

Athena development for the paper *Formally Verifiable Distributed Data Types for Reasoning
about Fault Tolerant Services* (Mateo Sanabria, Nicolás Cardozo, Stacy Patterson, Carlos
Varela).

The development defines distributed data types whose fields live at locations that may fail,
and proves their fault tolerance properties: replicated functions and their composition,
distributed hash tables (DHTs) with replication, and an operation-based grow-only set CRDT.
`sensor_app.ath` uses these theorems to derive service-level guarantees for the sensor
application of the paper.

## Requirements

* Athena 1.6.1, with `ATHENA_HOME` set and `$ATHENA_HOME` and `$ATHENA_HOME/util` on `PATH`.
* Vampire is needed only by the tests in `test/` (see `test/VAMPIRE.md`). The development
  itself does not call an external prover.

## Checking the proofs

Loading a file checks every declaration and every proof in it and in the files it loads.
`sensor_app.ath` is the top of the dependency graph, so one run checks the whole development:

```sh
cd Code
athena-run sensor_app > out.txt 2>&1        # or: echo quit | athena sensor_app.ath
grep -ni error out.txt                       # must print nothing
grep -c '^Theorem:' out.txt                  # 180
```

Athena exits with status 0 also when a proof fails, so the result must be read from the
output. The first error stops the load, and nothing after it is checked.

## Structure

The files form layers. Each file loads the files it depends on.

1. Libraries: `bool.ath`, `pair.ath`, `function.ath`, `list.ath`, `location.ath`,
   `lst-in.ath`, `lst-toset.ath`, `set-util.ath`, `sets-notp.ath`.
2. Local hash table: `htable.ath`.
3. Distributed types, each the distributed analogue of a base type: `dpair.ath` (pairs),
   `dfunction.ath` (replicated functions), `dlist.ath` (lists), `dlls.ath` (distributed lists
   of buckets), `dhtable_mateo.ath` (DHTs). `crdt.ath` holds the grow-only set.
4. Application: `sensor_app.ath`, which adds no library theorem and instantiates the three
   modules `DFunction`, `DHTable` and `CRDT` at the sorts of the sensor application.

The load order in `sensor_app.ath` matters. Its header explains why.

## What is asserted

Every theorem of the paper is proven in Athena. The files loaded by `sensor_app.ath` assert
only the definitions of the data types and of their functions, and the axioms of the libraries.
No lemma is asserted, and no proof uses `!force` or an external prover. The tests check these
definitions on concrete examples and ask Vampire for refutations of the assumption base
(`test/README.md`).

## Tests

`test/` holds concrete examples and edge cases for each module, enumeration checks of the DHT
definitions against reference procedures, and consistency checks with Vampire:

```sh
cd Code/test
./run_tests.sh            # quick mode, about 35 minutes
./run_tests.sh --night    # night mode, several hours
```

See `test/README.md` for what each test checks and how to read the results.
