# 0001 — The Settlement GDD is authoritative over CLAUDE.md
Date: 2026-09-05 · Status: Accepted

## Decision
`docs/game_gdd.md` and `docs/ui_ux_controls.md` outrank `CLAUDE.md`. Where they
disagree, the GDD wins and `CLAUDE.md` is the file that gets fixed.

## Why
`CLAUDE.md` was written before the GDD existed and contradicted it in three
places: it specified 200 units / 50 MB at 1000 entities against the GDD's 256
residents / 100 MB; it listed `CombatSystem` as a settlement autoload when the
settlement layer defines no damage model; and its economist brief asked for
population tables at 500 and 1000 with `wealth(n) = base * ln(n+1)` — a float
formula at populations the GDD forbids existing.

## Consequences
Binding constraints that override anything written elsewhere:

- Integer arithmetic for all authoritative state; float is presentation/import only
- 30 fixed ticks/second at 1x; 18000 ticks/day; 750 ticks/game hour
- Speeds are `PAUSED=0, NORMAL=1, DOUBLE=2, QUADRUPLE=4` — there is no 3x
- Structure-of-arrays component storage, not one object per entity
- `EntityRef = (slot:int32, generation:int32)`, null `(-1,0)`, slots reused
- Living population caps at **256**; never tabulate or model beyond it
- Quantities are `quantity_milli:int64`; needs/mood integers 0–10000

## Source
User decision, 2026-09-05: "use GDD". Constraints from `docs/game_gdd.md` §4.1,
§4.3, §5.1, REQ-SET-002/003/163.
