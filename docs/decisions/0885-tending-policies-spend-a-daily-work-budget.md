# 0885 — Tending policies: three standing orders a group, a daily work budget, exceptions only
Date: 2026-10-01 · Status: Accepted

Brendan approved the review's **ECO-007** ("Tending policies with work budgets", REVIEW.md 2339): "A garden may permit
'protect from forecast frost,' 'water below suitable band' and 'avoid waterlogging.' Show maximum materials/work this
policy may spend during the next day; a player can cap it or reserve staff. Routine execution follows P2 priorities;
structural changes still require a chosen project. Notify exceptions, not every successful cover." Numbering: see 0881.

## Decision

`farm/farm_tending.gd`, run once a farm hour from `demo_farm.gd _hourly`, and the planner's **Tending** tab
(`farm_tending_page.gd`).

- **Two groups**: the field beds and the kitchen garden's laid beds (0883). Each has four policies -- the fourth, Sow
  empty beds in season, is decision 0886's -- **all off in the module** (GDD §4.2 FieldPolicy's `auto_rotation=false`),
  the live village turning the field's sowing on (0886); and one **daily budget** in WU: 0, 4, 8, 16 or 32 (demo
  values; 16 by default since 0886: four sowings a day). The budget is spent when a job is ordered -- its plan's own work
  (`farm_jobs.gd plan_work_usec`, the walks not counted, as the action cards) -- and comes back at midnight.
- **What each policy orders**, only on a growing crop and only with no such job already on the bed, through the bed
  panel's own verbs (`farm_crew.gd order`, ORIGIN_ROUTINE), so the work board's priorities, the cook's garden hours
  (0883) and every refusal apply:
  * **Protect from forecast frost**: with a frost due (`farm_weather.gd frost_due`: from noon the day before), Cover a
    bed not covered and not raised (a raised bed is warm enough);
  * **Water below the suitable band**: Water a bed LOW or DRY against its crop's band and not tended today (§5.6
    tending, at most once a day; 0.25 U of well water);
  * **Avoid waterlogging**: on a wet growing crop, set a fitted outlet over a dry tunnel to Drain, and shut one set to
    Feed (boards, no work: 0884). A ditch, raising or the weir's sluice -- which serves three beds -- are structural or
    shared: the policy says them, never does them;
  * **Sow empty beds in season**: decision 0886.
- **Exceptions only**: what a policy could not do -- beds left for want of budget, an order the board refused (with
  its answer), wet beds with no drain to open -- is posted to the village news once a day per group and policy, and
  shown on the tab; a sowing waiting for its window is said once a bed and entry. A successful cover says nothing.
- **The next day's most** is shown before anything is spent: each growing bed watered once and covered if a frost night
  falls in the next day, capped by the budget, with the well water it would draw.
- **Staff**: the garden's work goes to the cook between meals (0883); the field's to whoever is free, the Field crew
  first.

## Brendan's ruling (2026-10-01)

The tending defaults are **approved as built** (proposals 1–3 below). Recorded at the batch 7 integration (decision 0902); nothing changed in behaviour.

## Proposals for Brendan

1. **Budget steps and the default** (0/4/8/16/32 WU, 16) are demo values; a cancelled job's WU is not refunded.
   **Recommendation:** keep.
2. **Reserve staff for the field group** (a named resident kept for the policy) is not built. **Recommendation:** with
   crew intents (SOC-004).
3. **Avoid waterlogging never turns the sluice.** Option: let it step the sluice down when every bed it serves is wet.
   **Recommendation:** keep it the player's choice.
