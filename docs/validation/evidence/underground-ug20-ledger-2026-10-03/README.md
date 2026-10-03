# UG20 tip ledger component checkpoint

This evidence covers only the exact source hashes in `source-sha256.json`.
The final run moved demo assets aside if present, deleted this worktree's
`.godot`, clean-imported Godot 4.7.2, ran the two strict singleton shards, and
restored assets in a finally block. Every direct test file remains in the
unchanged automatic shard census; these are focused runs, not a full-suite
checkpoint. The initial failure log is retained: one fault-injection test
incorrectly assumed the allocator heap's prior row order. It now restores the
actual prior value. No allowance or runner gate changed.

```text
16 test(s), 747 assertion(s), 0 failure(s)
9 test(s), 114 assertion(s), 0 failure(s)
```

Both suites separately ended with:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The focused analyzer returned `0 GDScript warning(s) in 0 of 2 file(s)`.
The final clean import contained no ERROR, WARNING, SCRIPT ERROR or leak line.

`ug_geometry` independently reviewed the frozen source and tests without edits
or a separate runtime rerun. No functional blocker was found in full identity,
retained work/quantity, source/capacity claims, atomic refusal, counter overflow,
closure/reuse or two-way index auditing. Review corrected capture accounting:
48+103C is the image length; 48+119C is the current logical packed scratch peak
while a converted column coexists with the output. Live payload remains
107C+65536, and cold auditing needs C bytes. Native growth remains unmeasured.

The tests deliberately use a SyntheticPublisher with actual Construction
identities/progress and a labeled accounting fixture. They do not prove actual
spoil funding, inventory metadata, productive workers/tools, terrain siting,
hauling, composed save or demo activation. UG20 remains running; its typed
shared modular operation coordinator and actual world binding are required.
