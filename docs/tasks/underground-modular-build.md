# Underground modular building implementation

Brendan authorized implementation of all approved D01–D28 (with D29 direct-on-dirt clarification) and concurrent
subagents on 2026-10-02. Decision
[1051](../decisions/1051-underground-build-lanes-and-integration.md) records
branch safety, ownership, the scheduling contract and discovered owner gaps.

The authoritative queue is [underground-build-queue.json](underground-build-queue.json).
It covers every one of the **107** requirements without treating helper modules
as completed player-facing features. Inspect it with:

```sh
python3 tools/underground_build_queue.py validate
python3 tools/underground_build_queue.py status
python3 tools/underground_build_queue.py ready
```

## Work order

| Lane | Deliverable | Prerequisites |
| --- | --- | --- |
| UG01 | Canonical integer footprints, painting shapes and boundaries | — |
| UG02 | Generation-safe projects and revision holds | — |
| UG03 | Furniture layout drafts and placement validation | — |
| UG04 | Interactive room drawing and blueprint controls | UG01 |
| UG05 | Fitted shells and physically scaled materials | UG01 |
| UG06 | Actual excavation, spoil, closure and Construction accounting | UG02 |
| UG18 | Room-purpose catalog and furnishing compatibility | UG01, UG03 |
| UG07 | Real room/equipment order coordinator | UG01, UG03, UG06, UG18 |
| UG08 | Multilevel occupancy, support, fixed connector catalog | UG01; compose with UG06 at UG09 |
| UG21 | Actual sparse underground geometry and phase preflight | UG01; uses integrated UG08A helpers |
| UG19 | Direct terrain painting and in-world preview | UG04, UG05 |
| UG09 | **First playable checkpoint: blueprint → workers → empty Kitchen** | UG04–08, UG19, UG21 |
| UG10 | Furnishing modes, real services and optional example guides | UG07, UG09 |
| UG11 | Two-level rooms, section painting, stairs and extra entrances | UG08, UG09 |
| UG12 | Safe structural amendments and Apply/Discard/Keep editing | UG02, UG06, UG09 |
| UG13 | Permanent room types, removal, backfill and replacement | UG06, UG08, UG10 |
| UG14 | Worker relocation, storage draining and restocking | UG08, UG10 |
| UG15 | Whole-surface renovation and coordinated item returns | UG05, UG13, UG14 |
| UG20 | Paid spoil-tip preparation, compaction and reclamation | UG06 |
| UG16 | Composed save/load and deterministic continuation | UG11–15, UG20 |
| UG22 | Bounded Gear lookup and excavation performance qualification | UG06 |
| UG17 | Complete catalog, visual polish, regression and scale qualification | UG16, UG22 |

## Automatic continuation

Current-thread heartbeat **Finish underground building** checks every ten
minutes. Its job is to resume existing agents, collect results, release ready
lanes and keep integration moving; it must not duplicate running work. The
queue remains the source of truth if the conversation is compacted or resumed.
The automation uses local execution and therefore needs the app and computer
running. Stop it when all lanes are verified or Brendan requests a stop.

Each worker has an isolated own `codex/*` branch created from current master.
Workers never edit the main/Claude checkout. Shared source files are serialized
by explicit ownership; the integration owner reconciles registry stanzas and
the queue. Code changes get independent review before integration. The queue
releases dependents only after the prerequisite is `verified`, which requires
a commit, test/diagnostic evidence, review and integration record.

## Completion evidence

The first integrated foundation checkpoint at `26283981` passed the full
CI procedure: **9,233 tests, 616,737 assertions, zero failures**, zero unexpected
errors/warnings and zero leaked objects/resources (272 expected diagnostics,
353 tolerated notices). The analyzer found zero warnings across 1,034 files.
See [source-pinned logs](../design/underground-planning/evidence/modular-build/checkpoint-26283981/).
This checkpoint covers UG01–03, not the subsequently developed components.

The UG08 geometry increment now runs independently of excavation. It validates
explicit spatial input; UG09 still requires both the physical construction and
spatial owners. Production connector authoring, measured profiles and live
binding remain part of UG08/UG09 qualification, not implied by synthetic tests.

D29 explicitly requires drawing on the dirt in the selected world view.
The component test board is not the playable interaction. UG19 extracts the
independent camera/pointer/terrain-preview work from UG09 while physical owners
continue. Confirmation still depends on the integrated construction coordinator.

The next source checkpoint `97a95b92` ran 9,289 tests / 619,925 assertions and
correctly failed one obsolete ReservationPurpose domain-count assertion; all
unexpected diagnostics and leaks remained zero. The full analyzer found zero
warnings in 1,046 files. The exact failed log is retained under
[checkpoint-97a95b92](../design/underground-planning/evidence/modular-build/checkpoint-97a95b92/).
The narrow append-only enum test correction passes 33 tests /178 assertions;
the separate canonical RoomProjects declaration fix passes its independent
checks (decision1060). Neither focused fix retroactively makes that full run pass.
New full/CI validation is required for the assembled source.

The full build is not complete until all 107 criteria work in the actual demo.
Retain real worker routing, materials, tool checks, physical cut history,
furniture identity and service validity throughout. No paid asset generation
is authorized. Missing owner contracts are implementation tasks, not permission
to invent prices or bypass safety/accounting.

Integrated milestones use the user's CI procedure: move assets aside, delete
the integration worktree's `.godot`, clean headless import, and run the full
no-argument `./tools/run_tests.sh`, restoring assets afterwards. Record the
actual test summary and diagnostic/leak lines, plus the zero-warning analyzer.
Capture native 1280×720 input/visual evidence and test saving during work,
relocation, closure and revision. Measure the 256-resident workload and retain
any unmeasured Windows/qualification-floor limitations explicitly.

The next frozen source `bb557d1b` passed **9,304 tests /620,633 assertions**,
zero failures and zero unexpected diagnostics/leaks (272 expected,353 tolerated).
The analyzer reported zero warnings across1,048 files. Full exact logs are in
[checkpoint-bb557d1b](../design/underground-planning/evidence/modular-build/checkpoint-bb557d1b/).
Subsequently integrated geometry and WIP increments require their own assembled
checkpoint. UG20 explicitly owns spoil-tip preparation/compaction/reclamation;
UG06's local cut-output publication does not complete those ECON operations.

UG06 physical ownership is independently reviewed and integrated at `0172e808`,
with its registry at `8e542e98` and canonical/memory reconciliation at `56595fe5`.
Its strict focused validation covers 417 tests / 52,821 assertions with zero
unexpected diagnostics or leaks. All 32 assembled specification gates pass.
UG07 is automatically released for actual Room/Furniture order composition.
UG22 addresses measured Gear lookup costs separately; its addition does not
mark the 256-resident whole-tick target achieved.

The frozen integrated source `5d2d8eca` passed **9,418 tests / 645,308
assertions**, zero failures, zero unexpected diagnostics, and zero object or
resource leaks (272 expected diagnostics, 353 tolerated). The all-source analyzer
reported zero warnings across 1,059 files. This checkpoint includes UG06 physical
ownership, UG19 direct dirt painting and the 1066 canonical/memory reconciliation.
Its [exact evidence](../design/underground-planning/evidence/modular-build/checkpoint-5d2d8eca/README.md)
identifies later increments that were not part of that run.

UG22's private Gear lot index is implemented, independently reviewed and
integrated at `a30c0a7c`. It passed 217 focused tests / 34,020 assertions and the
zero-diagnostic/leak/analyzer gates. The recorded 256-worker workload still
exceeds the whole-tick budget; UG17 retains that qualification work. UG07 actual
Room/Furniture orders, UG08 qualified movement/connectors and UG21 spatial
composition remain active. None of these component results is a claim that the
complete playable underground lifecycle has been delivered.
