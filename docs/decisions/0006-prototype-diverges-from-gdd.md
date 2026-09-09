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


## Row 9 closed (2026-09-08) — retirement, not GDD satisfaction

`CombatSystem` is retired from the settlement layer under ARCH-MIG-006 step 7.
The module moved to `godot/scripts/legacy_battle/`, its autoload was removed
(returning autoloads from 6 to 5), and its `_ready()` was **deleted** — that hook
called `set_entity_manager(EntityManager)` against a settlement autoload, so
leaving it would let a future reader drop the node into a scene and have it
silently self-wire to settlement state. The collaborator is now injected
explicitly or not at all.

A regression guard, `test_the_legacy_battle_module_is_not_registered_as_an_autoload`,
scans `ProjectSettings` for any `autoload/*` entry targeting
`res://scripts/legacy_battle/` and fails if one reappears. The original mistake
now fails loudly rather than recurring quietly.

**The tests stay directly under `test/` on purpose.** `run_tests.gd` does not
recurse, so a `test/legacy/` subdirectory would have silently stopped running
those 9 tests and left retained code unverified. Untested retained code rots into
deleted code. Separation is carried by the suite name, not by invisibility.

### The 9 legacy tests
Seven semantics ported to `needs.gd` and `SettlementSystem`; two are
battle-layer only and were **not** ported — rejecting non-positive *damage*
(the settlement defines no damage model, only a signed health-event channel) and
a float `health_fraction()` (settlement health is an integer 0–100).

Two ports are upgrades rather than transcriptions. Lethal damage **destroyed**
the entity; the settlement **retains** the row as `STATUS_DEAD`, because the
chronicle, burial job and recoverable inventory all still have to find the
corpse. And combat answered `0` health for an entity it never heard of — a
forbidden sentinel, since 0 is a real corpse's health — where the settlement
refuses `INVALID_SLOT`.

### What closing this row does NOT mean
The module still uses one `Resource` per entity, monotonic non-reused ids,
sentinel returns and a float fraction. Those are enumerated in its own header as
re-derivation requirements. **It is a head start for the battle layer, not an
adoptable foundation.**

### Still open
**Row 10** — the input map still uses `select` / `move_command` / `build` /
`cancel` where the GDD and UI spec require `select_primary`, `command_context`,
`open_build`, `ui_cancel` and roughly fifty more. Changing them needs the UI
consumer changed with them.

### Incidental
Two of the eight mutations run against this work were killed **only** by the
newly added tests — dropping `clampi` in the health-event path, and returning
`NOT_PRESENT` for an out-of-range slot. Both were real coverage gaps in existing
code that the port exposed.


## Row 10 closed (2026-09-09) — and one architectural residual

The prototype's four action IDs are gone. `godot/project.godot` now declares
**87 actions**, the full `docs/ui_ux_controls.md` §5 map — 51 table rows expand
to 87 because five rows name two or more IDs and three are families of ten
(`group_assign_0..9`, `group_recall_0..9`, `group_center_0..9`).

**The consumer change was a semantic fix, not a rename.** `main.gd` mapped
`cancel` (Escape) to the pause toggle. §5 puts pause on **`time_pause`** (Space,
and Ctrl+Space outside text contexts), while Escape is `ui_cancel`, which
dismisses one layer. Renaming `cancel` to `ui_cancel` would have preserved the
wrong behaviour behind a correct name — worse than the original, because it would
look compliant. The sole consumer now reads `time_pause`.

### Engine behaviour that cannot be fixed in the InputMap
Verified on Godot 4.7.2: a key action matches when the **action's** modifier mask
is a *subset* of the pressed event's mask. So `Ctrl+3` raises both
`group_assign_3` and `group_recall_3`; `Ctrl+Z` raises both `tool_undo` and
`open_zones`; `Shift+Enter` raises both `select_toggle` and `select_primary`.
That is §5's "modifier gesture before plain" precedence, which the **router** must
resolve — it is not expressible as bindings. All **43** such pairs are pinned by
test so a new one cannot appear unnoticed.

Only three exact-chord collisions exist, and §5 states all three outright: Enter,
Shift+Enter and Escape dismissal ladders.

`ui_accept` and `ui_cancel` explicitly **replace** Godot's built-ins, because the
default `ui_accept` also carries Space, which §5 assigns to `time_pause`.
Cmd+Q and Alt+F4 are asserted uncaptured. W/A/S/D/Q/E use `physical_keycode`;
everything else uses the logical `keycode`, including the Cmd+Z / Cmd+A variants.

### The residual, which is a new task and not this row
**§5's input router does not exist.** Consequently:
- `group_center_0..9` are registered with **empty event arrays** — a same-key
  double tap inside 300 ms is not expressible as an `InputEventKey`. Binding the
  plain digit would make every `group_recall_N` also fire `group_center_N`.
- **No pointer gesture is bound as a raw mouse event** except the wheel.
  `select_primary`, `placement_commit`, `interior_commit` and `command_context`
  deliberately carry no click binding, because they share raw buttons and §5
  forbids exactly that independent double-fire.

So the map is correct and the pointer half is unreachable until a router exists.

### One unresolved contract found in the spec
§5 says `placement_rotate` is "R; Shift+R reverse" but **names no second ID**.
Both are bound to `placement_rotate`; the direction must come from the shift
modifier at the consumer. No `placement_rotate_reverse` was invented.

### Status of decision 0006
**All ten divergence rows are now closed.** What remains of the prototype is
`entity_manager.gd` and `scripts/components/`, superseded by
`entity_directory.gd` but still autoloaded and still referenced by `main.gd`.
