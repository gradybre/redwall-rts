# 1084 — The legacy World codec cannot claim underground coverage

Date: 2026-10-03 · Status: integration test correction; UG16 remains required

The full frozen e267eaec run exposed a stale test assumption: the schema3
`save_section_01.gd` codec supplies the nine owners fixed by R-WORLD-S1-001,
while decision1072 adds mandatory `underground_space_owner` to the newer
schema4 World declaration. The test demanded that the legacy codec register
every current World adapter. It cannot truthfully supply the added owner's
physical geometry, claims, generations and revisions from its old44 fields.

Keep the old wire format, independent nine-owner field/count/offset fixtures,
codec and production hash walker unchanged. Correct this test to require the
exact nine legacy owners plus the exact new owner before registration, and
exactly the underground owner still missing afterward. Additionally assert
incomplete adapter/release coverage, `CANONICAL_NO_ADAPTER` explicitly naming
underground state, and no digest or hashed bytes. This makes the integration
boundary explicit without registering an empty adapter or silently excluding
the new state.

UG16 must implement the new versioned World owner capture/restore, canonical
adapter, all cross-owner bindings and deterministic continuation tests before
production save/release activation. The current local sparse-owner codec is
not that composed implementation. Passing legacy tests does not close UG16.

The rejected full run is preserved under
`docs/design/underground-planning/evidence/modular-build/checkpoint-e267eaec/`:

```text
9670 test(s), 675202 assertion(s), 1 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1085 file(s)
```

The strict script stopped at the failing-test gate and emitted no final raw-log
footer; this checkpoint is not accepted as green. Clean import took3.737s,
suite1198.484s, analyzer211.148s. The actual source remained at e267eaec for
the whole run and assets were restored. Independent review, focused strict
validation and a subsequent complete integration run are still required.


## Reviewed focused correction

ug_construction independently reviewed the exact test delta, mandatory current
registry, unchanged legacy fixtures and coverage-before-hashing guard. The
clean-import strict singleton run reported41 tests,872 assertions,0 failures;
strict and raw diagnostics/leaks all0 with0 expected/tolerated. Analyzer reported
`0 GDScript warning(s) in 0 of 1 file(s)`. Raw evidence and the exact invocation
are in `docs/validation/evidence/underground-legacy-world-codec-2026-10-03/`.
The next full assembled run is still required; UG16 remains unimplemented.
