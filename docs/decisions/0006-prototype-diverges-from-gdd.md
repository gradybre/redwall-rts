# 0006 — The task-01 bootstrap knowingly diverges from the GDD
Date: 2026-09-05 · Status: Accepted · **Audit is against GDD rev 1.0; re-check against rev 1.1**

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
