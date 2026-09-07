# 0006 — The task-01 bootstrap knowingly diverges from the GDD
Date: 2026-09-05 · Status: Accepted · **Re-verified against GDD rev 1.1 on 2026-09-06**

## Decision
The Godot code committed in task 01 predates the GDD and violates it in ways
that are **recorded rather than fixed**, until the systems architecture document
settles the target layout.

## Why
Fixing it before the architecture was settled risked a second rewrite. The
divergences are listed so nobody mistakes the prototype for a foundation.

`docs/systems_architecture.md` has since landed, so the blocker is gone — but
this audit was compiled against **GDD rev 1.0**, before `SET-AMEND-001` and
`settlement_rules_v2`. Re-verify each row against the current GDD before acting
on it. The binding constraints below were re-checked on 2026-09-06 and are
unchanged: the 256 cap, integer-only authoritative state, `QUADRUPLE=4`,
`quantity_milli`, `generation:int32`, and packed-column storage all survive.

## Known divergences

| Code | Divergence |
|---|---|
| `economy_system.gd` | Stores `float` stockpiles; GDD mandates integer `quantity_milli:int64`. Models `food`/`herbs` as stored resources; the GDD derives food-days from nutrition points across lots. Storage is a flat cap of 500; GDD uses container mass in grams with per-lot quality, age and reservations. |
| `economy_system.gd` | The `MAX_TICKS_PER_FRAME` catch-up **drops the remainder**, which REQ-SET-008 explicitly forbids — at 1x it must pause with a diagnostic rather than skip ticks. |
| `entity_manager.gd` | Monotonic non-reused int IDs; GDD requires `(slot, generation)` with slot reuse. `test_destroyed_ids_are_never_reused` encodes the wrong contract. |
| `components/*.gd` | One `Resource` per component (array-of-structures); GDD and crowd doc both require packed integer columns. |
| `game_manager.gd` | Speeds `[1.0, 2.0, 3.0]`; GDD has no 3x and does have 4x. No calendar at all. |
| `combat_system.gd` | Not a settlement system. The settlement layer models `Injury` and healing, with no damage or attack model. |
| Input map | All four action IDs wrong: GDD/UI want `select_primary`, `command_context`, `open_build`, `ui_cancel`. |

## What survives
HUD zone layout (matches UI §1.1), `ui_manager.gd`, the test framework and
runner, and `entity_manager.gd`'s API shape.

## Source
Audit against `docs/game_gdd.md` §4.1–4.3, §5.1, and
`docs/ui_ux_controls.md` §1.1, §5, on 2026-09-05.

## Recheck against `settlement_rules_v2` (2026-09-06)

All ten divergence rows were re-verified against GDD rev 1.1 as amended by
`SET-AMEND-001` and `SET-MOVE-001`. **Every row is still valid**; the amendments
change none of them. Corroborated independently by
`docs/systems_architecture.md`'s own `## Conflicts Found` table
(ARCH-CONFLICT-008, ARCH-CONFLICT-010).

Retired content in `SET-AMEND-001` (hunting, `hunter_hut`, carcass/hide items)
has no counterpart in the prototype, so the amendment adds no new code-level
divergence there.

### One gap the original audit could not have listed

`SET-MOVE-001` adopts connected multi-floor movement (DEC-035), but there is
**no movement or pathfinding code at all** in `godot/scripts/`. That is not a
divergence — there is nothing to diverge — but whoever writes the first movement
system must start from `MOVE-G01–05` and ARCH-PATH-002/003, **not** from a
ground-only assumption. The existing one-floor spatial bounds and memory ledger
are not sufficient for the adopted underground, swimming and climbing scope.

### Status of the replacements

Task 02 builds release modules **beside** the prototype rather than editing it
(ARCH-MIG-006 step 2). As of 2026-09-06 the prototype and its 52 tests are
untouched and green. Rows 1–3 (economy), 4–6 (entity/component storage) and 7–8
(speeds/calendar) now have release-side replacements in `godot/scripts/core/`;
rows 9 (CombatSystem) and 10 (input map) are untouched and remain open.
