# Underground integration status

Last updated 2026-10-12 on branch `feat/build-panel-slice-c` (decisions 1911 and 1912; the sections dated
2026-10-05/06 below are kept as they were written). Read this before `underground-claude-handoff-2026-10-05.md`.
This document supersedes that handoff's lane, worktree and overlay instructions (ADR 1192).

## Where it stands (2026-10-12)

The "Next, in order" list below (2026-10-05) is out of date. Checked in code at `5977191b` (decision 1911 §2):

- **The first-entry dispatcher exists.** `SettlementSystem.run_tick` advances the entry runtime and its foreman every
  tick after ProductiveWork (`settlement_system.gd` `_advance_underground_entry`, ADR 1210 G7). It digs only the
  authored first-entry stair (L0, T0–T6) and ends at `ENTRY_KITCHEN_UNBUILT`. **Nothing in the game starts it**:
  `begin_underground_entry` is called only by tests, and the demo composes the room and route owners but not the
  surface anchor or the entry owners. Settlement stock is never staged at the entry (`ENTRY_HAUL_NO_STAGED_STOCK`).
- **The entry stair ends 1 m below the surface; underground level 1 is 5 m down** (SET-BUILD-001 §3). Nothing can
  reach level 1 until slice D's entrance (OPEN-10 (a)).
- **No room is dug by anything in the game.** `RoomOrders.confirm_room` creates Sites and geometry, no project, job
  or worker; the room loop of ADR 1213 is test-only. Slice C2 (decision 1931 and its successors) builds the
  production room foreman.
- **Room digging in the game uses the claws' M1 down stroke**, under the rule change slice C2.1 makes in core
  (Brendan's ruling P-C2-1 on decision 1931, "Dig rooms with the down stroke"; decision 1931 and its successor).
  ADR 1217's M2/M3 strokes are no longer the room path.
- **The excavation owners cost about 6.4 ms per working tick per builder** against REQ-SET-163's 2 ms (decision 1931
  F3). The `perf/dig-tick-cost` lane is fixing it (P-C2-2 (a)).
- **A room's planned height and its price are read with the claw crew's identity** (P-C2-3 (a)): the build ledger
  and `modular_runtime.gd _make_plan` used "any row" (2,048 u, the retired pick's), which a claw work row refuses at
  confirm (`ROOM_APPROACH_HEIGHT_UNREACHABLE`). Both now read `modular_runtime.gd dug_height_u` with the claw crew's
  identity: 1,024 u on master, until C2.1 changes the rule (decision 1912).
- **The build panel (slices B and C1)** paints rooms on the actual World's levels and judges every cell before
  Confirm all ("No way in", "Cannot dig here", the 2 × 2 rule). Until slice D and C3 it orders nothing, and says so.
- **HAUL-H3 and later have not landed**, and underground work does not need them: the entry has its own haul path
  (`underground_entry_hauler.gd` → `underground_connector_delivery.gd`), wood and stone only, the entry Placement only.

Order now (Brendan's rulings on decisions 1911 and 1931): C1 ∥ the cost lane ∥ C2.1 → C2.2 → C2.3 → slice D → C3.

## How work is done now

- **One branch, committed files only.** The three sibling `codex/underground-*`
  worktrees are frozen source material. Their WIP has been imported by content
  (see the commit messages). Overlay runners no longer qualify anything.
- **Focused runs:** `./tools/run_tests.sh --suite test_x.gd [--suite ...]`. This
  uses the same zero-error and zero-leak guards as the full run.
- **Source pins:** after editing any of the ten pinned consumer scripts, run
  `python3 tools/renew_source_pins.py --write` in the same commit.
  `run_tests.sh` refuses to run while pins are stale.
- **Never edit files while a full run is in progress.** Suites load scripts as
  they run, so a mid-run edit makes the result meaningless.

## What works (real, not synthetic)

`test_underground_paid_assembly_handling.gd` covers 10 tests on the real
source and the ADR 1191 work area:

1. One worker cuts four L0 cubes (36,000 mWU).
2. The worker walks the all-yaw source12 profile to M, turns to the source2
   heading and approaches H without turning at H.
3. The completed first dig pair retires: WorldRoutes publishes, then
   Locations publishes (`underground_entry_contact_retirement.gd`).
4. The whole wood bill is paid, then START.
5. 60 ticks of handling, then INSTALL fastening (32,000 mWU), then commit.
6. Refusals: blocked refund, exact partial refund, productive terrain
   observers, pre-funded pause and stale-context START.

`test_underground_entry_world_bindings.gd` runs the complete synthetic L0+T0
prefix again (ADR 1193).

## Fixes made during integration

| Commit | Fix |
|---|---|
| `2d9f2cf1` | 158 of 165 failures were stale source pins. Added the renewal tool and its check. |
| `3af08939` | Wrote the missing retirement driver. Fixed three scope rules that had never run. |
| `a8060ef3` | Handling entry re-attests terrain after START advances the Space revision. |
| `b97e3899` | Moved the four productive-work scenarios onto the real fixture (ADR 1183). |
| `78f7fa8c`, `db82d895` | Imported entry-owner composition. Placements now releases its source readers. |
| `c7f63b49` | The installed WORK contact's footing covers its travel profile, which unblocks T0 (ADR 1193). |

## Latest full results — `c7f63b49`

```text
11341 test(s), 1084389 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1279 file(s)
```

This is a local no-argument `./tools/run_tests.sh` run plus `tools/gdscript_warnings.py --max 0`.
It replaces `4972a96d` (11,293 tests) as the latest green full-suite commit. It is not a strict-procedure
qualification: there was no assets-aside clean import, no captures and no soak.

## Since the last update (2026-10-06)

| Commit | Change |
|---|---|
| `969f8e72` | Fixed first-entry source bundle `qualified-handling-v1` (ADR 1190). Full suite green: 11,341 tests. |
| `ed783c46` | Runtime loads the content-4 profile publication `qualified-handling-v5`, which includes handling row 29 (ADR 1194). |
| `f55a1f10` | Structure/frontier source suites read the bundle. |
| `4b06f840` | The real SettlementSystem composes the entry owners from the bundle (ADR 1195): prefix 17, no gameplay change. |
| `5dd13208`/HEAD | The base source-phases fixture keeps its own content-3 pins. |

Full suite on `4b06f840`: 11,342 tests, 4 failures. All four were in the base
source-phases fixture and are fixed in the next commit. 0 unexpected
diagnostics, 0 leaks.

## Next, in order

1. **Underground dispatcher (UG24).** Nothing drives a worker through the
   entry episodes automatically: travel, BRACE/CUT/FINISH, handling and
   install. Only test fixtures do, step by step. A fixed-tick dispatcher must
   create the Jobs, assign workers, route them, run phases, deliver wood,
   retire the dig pair, and run START, handling and INSTALL using the real
   owners and their final guards.
2. **Demo wiring.** `demo_village.gd` composes room and route owners only.
   It also needs to compose the surface anchor and entry owners at mount.
3. **Row 29 presentation.** The mole actor matches profile rows by actor
   source digest, so a handling worker has no clip yet.
4. **UG09 first empty Kitchen.** Paint and confirm, then the dispatcher digs
   the entry and room. Verify with native 1280×720 input and screenshots.

## Not yet claimed

The branch has not had a strict-procedure run: no assets-aside clean import,
analyzer `--max 0`, 1280×720 captures or 256-resident soak. Nothing here is a
playable claim. The queue file still shows the old per-agent leases; its lane
statuses have not been re-derived from full-suite results.
