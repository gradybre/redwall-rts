# Actual demo foundation lifecycle — 2026-10-04

ADR1149 mounts the existing Session on the real demo's SettlementSystem owners.
Reset retires it before clearing settlement, EntityManager or EconomySystem
state. UI Create reuses the host's existing World staging banks and remounts
the foundation using its one borrowed Content image. No starter stock, Room,
paid excavation or worker permission is introduced.

The initial candidate was independently rejected for allocating a second
175,364-byte World and failing to remount after in-scene Create. Its exact
source archive and evidence remain in `focused-1/`; the independent review is
in `../underground-room-publication-2026-10-04/host-lifecycle-review-v1/`.
The corrected implementation removes both gaps. Ordinary availability still
refuses a prepared World; only explicit whole-world retirement may accept its
staged replacement over the unchanged live World identity.

## Focused strict validation

`focused-2/` ran all seven affected suites: **287 tests / 7,038 assertions /
0 failures**, with six expected diagnostics, no tolerated diagnostics and no
unexpected errors, warnings or leaks. Its analyzer correctly rejected the new
test-local name `seed`, which shadows a built-in. Renaming only that local to
`published_seed` left production sources unchanged. `focused-3/` then reran
the affected Host suite and analyzer on the corrected eight-file packet:

```text
8 test(s), 82 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 8 file(s)
```

The harness parks any demo assets, deletes `.godot`, imports cleanly and uses
`./tools/run_tests.sh` strict singleton shards. It checks source stability and
restores the project and assets; the actual shared registry is never replaced.
Complete commands and restoration results are in each `invocation.json`.
The independent reviewer then identified an outdated UIManager docstring;
correcting that prose is the only difference between `focused-3` and the final
eight pins in `final-source-sha256.json`. `final-source.tar.gz` retains them.

## Actual scene lifecycle

`host_live.gd` boots the real DemoVillage scene, observes the mounted foundation,
restarts the actual scene, checks the new full World reference and retired old
Session, then resets cleanly. `live-3/` records:

```text
LIVE-SUMMARY 14 0
```

This is a headless 1280×720 lifecycle check, not a rendered room or input-quality
qualification. It produced no script errors, unexpected diagnostics or leak
reports. It did produce **44 explicitly recorded missing-demo-asset/audio
warnings** across two boots. The probe accepts only the listed unstaged asset
messages; it does not change any suite diagnostic allowance. The initial
`live-1/` probe failed because it eagerly preloaded the autoload script before
autoload initialization; that failed probe was stopped and its log retained.
The corrected probe borrows the actual autoload Node dynamically. `live-2/`
retains the first successful corrected run; `live-3/` also applies the explicit
missing-asset diagnostic classification.

## Memory and limits

The shared source-derived memory checker passed **225 tests**; the capacity
audit passed **190 checks / 0 failures**. `capacity-tests.log` is a rejected
unittest-discovery invocation that executed zero tests; `capacity-checks.log`
contains the actual audit. No bank, global reserve or capacity was increased.
Session still has 27 numeric bytes, 24 reference/alias members, no own packed
columns, and a 55-byte longest numeric helper chain inside its existing
1,536-byte slice. The host adds one retained Session handle and the synchronous
UI replacement borrows Content; reference/native overhead remains provisional,
not measured RAM qualification.

Operational Room/phase teardown must accompany subsequent activation. The
current foundation safely refuses retirement once external authorities or
live spatial work have been installed. D20's worker-built empty Kitchen,
save/resume, native visual/input and 256-resident qualification remain open.
