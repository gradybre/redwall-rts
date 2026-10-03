# Underground modular building implementation

Brendan authorized implementation of all approved D01–D28 and concurrent
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
| UG07 | Room/equipment catalog and real order coordinator | UG01, UG03, UG06 |
| UG08 | Multilevel occupancy, support, fixed connector catalog | UG01, UG06 |
| UG09 | **First playable checkpoint: blueprint → workers → empty Kitchen** | UG04–08 |
| UG10 | Furnishing modes, real services and optional example guides | UG07, UG09 |
| UG11 | Two-level rooms, section painting, stairs and extra entrances | UG08, UG09 |
| UG12 | Safe structural amendments and Apply/Discard/Keep editing | UG02, UG06, UG09 |
| UG13 | Permanent room types, removal, backfill and replacement | UG06, UG08, UG10 |
| UG14 | Worker relocation, storage draining and restocking | UG08, UG10 |
| UG15 | Whole-surface renovation and coordinated item returns | UG05, UG13, UG14 |
| UG16 | Composed save/load and deterministic continuation | UG11–15 |
| UG17 | Complete catalog, visual polish, regression and scale qualification | UG16 |

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
