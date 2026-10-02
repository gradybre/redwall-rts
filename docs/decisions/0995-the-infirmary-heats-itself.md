# 0995 — The infirmary is its own heated interior, with its own hearth and fuel
Date: 2026-10-02 · Status: Accepted

From the range 0993–0999 assigned to the fixes of the independent review of 2026-10-02
(`docs/reviews/2026-10-02-codex-review.md`, branch `codex/review-2026-10-02`). This record answers its **R03** and amends
decision 0571's sources.

## The finding

`care_tasks.gd` set `brain.indoors` when a patient entered the infirmary, and `demo_winter.gd` treated every indoors
resident as being in the HALL (`hearth_fuel.gd` had only the burrow homes and the hall). A Chilled patient in an
infirmary far from the hall warmed at the hall's fire; banking the hall changed the patient's thermal state; the
infirmary burned no fuel.

## The ruling

**Brendan, 2026-10-02:** "R03: the infirmary is its own heated interior with its own hearth and fuel, under the same
rules as homes in the winter fuel loop (decision 0571: demand, burn, the cold-room convergence, exposure). Patients warm
up from the infirmary's own heat, not the hall's. Resolve a resident's actual interior and heat source instead of a
boolean that maps to the hall. Add an integrated test: a patient in the infirmary and another resident in the hall,
while the hall's hearth is toggled. Check the GDD for the infirmary's hearth or fuel specifics and use them if present;
otherwise use the home rules and record that as derived from Brendan's ruling. Fuel-days and the HUD's heating demand
must include the infirmary."

## What the GDD says

- §5.9 room validity: an infirmary room must be "heated" -- so it has a hearth's heat whenever it is a valid infirmary.
- §5.9's Infirmary row: interior 6×6 = 36 tiles; §5.8 / managed-building heat: one hearth heats up to 120 interior tiles,
  so the infirmary is **one** hearth, and "one normal residence/hall hearth consumes 4 wood/day in winter; spring/autumn
  2/day when daily mean < 10 °C, summer 0" -- the same rate as a home's. REQ-SET-130/131: 18 °C at tier 1; out of fuel,
  halfway toward the outside air each hour.
- The GDD has no infirmary-specific fuel figure beyond these. So: **the GDD's general hearth rules, which are the homes'
  rules in decision 0571**; the remaining choices below are derived from Brendan's ruling.

## Decision

- `hearth_fuel.gd` gains a source row `INFIRMARY` after `HALL` (`SOURCES` = rooms + 2). Its hearth is installed while the
  infirmary is **built** (`demo_winter.gd bind_infirmary(built, occupied)`, refreshed every hour; `demo_village.gd` binds
  `infirmary_project.gd is_done` / `has_patients`). It is demanded, burns through the accumulator, converges when out
  and may be let go out / relit from the fuel panel exactly like any other row; it counts in `burning_count`, so in
  `heating_day_milli` (the HUD's heating demand), the fuel-days, REQ-SET-147's warning and the twelve-day projection.
- **The actual interior.** `resident_brain.gd` keeps `interior` (`INTERIOR_NONE / HALL / INFIRMARY`) beside `indoors`;
  `task_go_indoors(inside, building)` takes the building as a required argument (the hall's floor sleep and warm-up break
  pass HALL, the infirmary's bed rest and treatment pass INFIRMARY). `demo_winter.gd interior_source` maps the
  building to its own hearth row; a resident indoors that names no building is read as outdoors -- never defaulted to
  the hall.
- With a patient inside, an infirmary out of fuel and below freezing is a cold home (its own incident, "The infirmary
  has gone cold"), as a home with sleepers is.
- Derived, not taken from the GDD: the infirmary is **not** a warm-up-break destination and **not** touched by
  consolidation (which banks empty homes). Those are not among the ruling's four rules, and keeping them unchanged keeps
  the scope to heat and fuel.

## Tests

`test_demo_winter.gd`: a patient in the infirmary and a resident in the hall, both Chilled, while the hall's hearth is let
go out and relit (the patient clears exposure at the infirmary's 18 °C regardless; the hall's resident clears only when
its hearth burns; the infirmary let go out cools its own room); the infirmary's hearth burning 4 U a winter day and
counting in the demand line, fuel-days and projection, and no hearth when not built; a cold infirmary with a patient
reported in its own name; `interior_source` for none / infirmary / out again. `test_demo_care_desk.gd`: an admitted
patient's interior is the infirmary.

## Proposals for Brendan

- **P1 — warm-up breaks at the infirmary.** Options: (a) as built: Chilled residents warm at homes or the hall only;
  (b) the infirmary's lit hearth is also a warm-up destination for anyone; (c) only for its patients' healers.
  Recommendation: (a) -- an infirmary is for the hurt, and its 8 beds should not fill with the merely cold.
- **P2 — consolidation and the infirmary.** Options: (a) as built: consolidation never banks it; (b) bank it when
  empty, as an empty home is. Recommendation: (b) would save 4 U a winter day while nobody is hurt, but a patient
  arriving would then find it cold until the player relights it; (a) is safer until an auto-relight rule exists.

## Source

Brendan's ruling of 2026-10-02 on R03; GDD §5.8 (fuel-days, hearth demand), §5.9 (Infirmary row, room validity
"heated", managed-building heat), REQ-SET-018/019/130/131; decision 0571.
