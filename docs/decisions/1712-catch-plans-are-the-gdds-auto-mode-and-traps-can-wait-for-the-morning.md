# 1712 — Catch plans are the GDD's auto mode, and traps can wait for the morning run
Date: 2026-10-07 · Status: Accepted (proposals P5–P7 approved as built, 2026-10-07)

Part of the fishing revamp (#49); the lane's record, its gates and its review are [1711](1711-the-fishing-rolls-hazards-and-rare-catches-on-the-fishing-stream.md).

## Decision

1. **Two catch plans** (review ECO-024: "Start with two profiles"; "a small planning choice"). The Water panel's
   **Fish ▸** steps through the water's three fish and then **Best catch** (`catch_plan.gd` PLAN_AUTO = 3).
   - **Chosen fish** is §5.4's "A gear cycle targets one selected eligible species". Closed at the water, the trip waits
     (REQ-SET-046's block), and every closed or out-of-season refusal now names the reopening day
     (`fishery.gd _reopens`, " — reopens spring 8").
   - **Best catch** is §5.4's **auto mode**: "auto mode chooses highest `predicted_NP/work`, then earliest closure,
     then species ID". It is chosen when the trip is authorised and **again at the water** (`fishery.gd _replan`, at
     the top of `begin_cycle`), which is REQ-SET-046's "select a legal fallback species only when auto mode is enabled".
   - `predicted_NP` is the cycle's expected catch (fishing.gd's own `catch_milli`) times §5.7's fish row, "All fish
     species except mussel | 1400" NP a unit. `work` is the gear's §5.4 work. The two are compared cross-multiplied, in
     integers.
   - "Earliest closure" is the fewest days to the species' next §5.4 closure window (`fishing_driver.gd
     days_to_closure`, scanning a year). "Species ID" is §5.4's table row.
   - No species is ever locked out by who fishes (LORE-P12). Eel and pike stay hazards (REQ-SET-056).
2. **Collection policy for traps** (review ECO-026: "scheduled morning run … collect before a warned closure"). The
   stewardship row's **Traps: when soaked / morning run** sets the policy new traps are authorised with
   (`fishery.gd collect_policy`, stored per trip in `fishery_tables.gd t_collect`).
   - **When soaked**, the default, is the behaviour before: the collection goes on the board when the 6 h soak ends.
   - **Morning run** keeps a soaked trap in the water until 06:00–10:00. A trap whose species closes **tomorrow** is
     collected at once: a cycle completed inside a closure catches nothing (`fishing_driver.gd complete_cycle`).

## PROPOSALS (Brendan's ruling needed)

- **P5. The morning run's window is 06:00–10:00.** The start is the night routine's dawn (`night_routine.gd
  DAWN_HOUR`); the four hours are the demo's. PROVISIONAL; source: this record.
- **P6. A "warned closure" means a closure that starts tomorrow** (`CLOSURE_WARNING_DAYS` 1). The review names no
  horizon. PROVISIONAL.
- **P7. Not built: the review's third plan and two collection extras.** These are a "preserving catch" profile
  (ECO-024), "collect when the planned menu needs it" and a "land catch now" override (ECO-026). Each needs a rule the
  GDD does not give: which dish or reserve a catch is for, and what an early lift catches. Options: (a) leave them out;
  (b) add "land now" as collection at once after the soak (it changes nothing the GDD fixes); (c) scope a menu-led
  plan with the kitchen chain (PRESERVE → BREW → FEAST → RG-W). **Recommendation: (a) now, (c) when the kitchen chain
  lands.**

## Why

- §5.4's own auto mode **is** the "mixed" plan the review asks for. It needs no new rule, and REQ-SET-046's fallback
  comes with it. A bait or selectivity mechanic would invent gear the GDD does not have (0431's "no line").
- The predicted-NP figure was the core's named gap ("the nine species have none"). §5.7 does give the inland fish
  their 1400 NP, so the demo can rank them. Mussel, which has no inland item, never enters the ranking.
- The policy is per trip and set at authorising, so a trap already out keeps the plan it was set with.

## Consequences

- `fishery.gd trip_refusal` and `authorise` accept `PLAN_AUTO` as the species choice and resolve it
  (`planned_species`). A future caller passing 0..2 is unchanged.
- `fishery_tables.gd` gains `t_auto` and `t_collect` (appended columns).

## Source

GDD §5.4 (auto mode, REQ-SET-046, the trap row), §5.7 (the fish row); review ECO-024 and ECO-026 (decision 0493 row W,
approved 2026-09-30); feature #49 (2026-10-01).

## Brendan's rulings (2026-10-07)

Relayed by the coordinator on PR #236 (no verbatim wording was passed on): P5, P6 and P7 **approved as built, the
values provisional** -- the morning run's 06:00–10:00 window and the one-day closure warning stay PROVISIONAL; the
preserving plan, menu-led collection and "land now" are not built (option (a)).
