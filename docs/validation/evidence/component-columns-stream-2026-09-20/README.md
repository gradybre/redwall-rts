# Section4 streaming implementation evidence

Active SAVE-S4-STREAM-R01v2 / ADR0169, based on PR159 mergef0d91ba0b34323ea6b8f4b1d41836c40c15a7847. This does not complete SAVE-S4-CODEC or full-world save/load.

- Independent planning acceptance, fresh298 source-count proofs and independent Python wire hashes: sibling section4-planning-2026-09-20.
- Claude author metadata/generator850lines and stream938lines: strict exact-path intake, all frozen input hashes verified, both workers stopped before intake. Original outputs and parent repair witnesses retained. Schema-parent-integration.md records every metadata/generator repair.
- First complete focused run:20tests/11764assertions/0failures; review additions pass21/11814/0. Both12947565-byte streams match independent hashes; all298 fields round-trip including signed extrema and arbitrary u8. Refusal/state/input/previous-owner checks run.
- Generator black-box suite:58checks after the review additions. Counts/source drift, explicit primary/child bindings, duplicate/reversed markers, numeric-token types and read-only --check covered. All live production files remain unchanged by test clones.
- Six required mutants killed by assertion failures, no script/parser-error kills: child extent comparison, payload length comparison, equal-shape column swap, owner order, partial publication, section-length preflight. Final baseline and restored clone both21/11814/0. The first mutation harness stopped before variant3 because an insertion anchor matched two functions; that harness error is retained, narrowed to the intended function and rerun. Production source was never edited by mutation runs.
- Seventeen static gates pass and editor import has no errors/warnings. Both new modules are classified in the persistence registry; no new canonical field or owner is introduced.
- Immutable metadata10536 logical bytes is independently source-counted and ledgered; see metadata-memory-accounting.md for conditional stream lifetimes and unmeasured native overhead.

Independent source review found no blockers; all nine findings have explicit dispositions. The original full regression passed4868tests/202411assertions/0failures with unchanged553object/33resource shutdown diagnostics. Final regression passes4869tests/202461assertions/0failures with the same553object/33resource shutdown diagnostics. Bounded independent follow-up accepts the remedies with no blocker; remaining low findings and the report output-budget exception are dispositioned. Exact-head CI and merge remain pending; no gameplay acceptance is asserted.

Review follow-through adds seven disposable-clone fault cases (56assertions) and kills four additional bypass mutants for the two cursors’ metadata and byte-order guards. These run in CI; no native big-endian host was tested. The generator numeric parity repair preserves legitimate registry policy booleans.
