# 1711 — The fishing rolls: hazards and rare catches on the FISHING stream
Date: 2026-10-07 · Status: Accepted (P1–P3 are PROPOSALS awaiting Brendan)

The fishing revamp, feature #49 (Brendan, 2026-10-01, "NEW 3"; selected for building on 2026-10-07). This is the
lane's main record. Its companions are **1712** (catch plans and trap collection) and **1713** (each water's record and
intensive harvest).

**Numbering.** BACKLOG.md printed 1321–1330 for this packet. That range is **superseded**: the parallel digging and
underground branch uses 0991–1217, so the handoff README (2026-10-07) moved the remaining packets to 1701 and up. This
lane holds **1711–1719**. 1711–1713 are used. `git ls-tree` over every local and remote ref found nothing at 1710–1719
before this branch.

## Decision

1. **The roll.** A completed fishing cycle is the packet's "hazard roll" (FOLLOW-UPS item 6, the same item, done once
   here). It rolls §5.4's hazard and rare-quality rolls in `demo/fishery/fishing_rolls.gd`, on `scripts/core/rng.gd`'s
   FISHING stream, seeded from the demo world's seed (`care_rules.gd WORLD_SEED`, which the FORAGE stream already
   uses). The discipline is ARCH-RNG-002's:
   - one hazard draw, then one rare-quality draw, per cycle;
   - "closed/invalid cycles cancelled before departure consume none; already departed cancelled cycle retains saved
     rolls".

   So both draws are taken when the cycle **departs**, when it opens at the water and its Expedition is created
   (`draw_into`). They are kept on the trip (`fishery_tables.gd t_hazard_roll`, `t_rare_roll`) and **resolved**
   against the crew, the gear and the catch when the cycle completes (`resolve_into`). A cycle called off after
   departure has spent its two draws; one never opened has spent none. Draws are modulo, never rejection sampling, and
   this module is the stream's only consumer.

   Cycles draw in the order they open, each keyed by the Expedition it opened with. Several opening in one frame draw
   in the fishery's job order, which is deterministic for a run but not sorted by Expedition slot (slots are reused):
   see P10. Rendering and the camera never draw.
2. **The hazard** (REQ-SET-053) is §5.4's formula: `max(1, base*(1+danger) − 2*crew_skill − 4*additional_crew)`.
   - The base per 10000 cycles is net 12, trap 8, weir 5, boat 20, ice 24 (`fishing_driver.gd injury_per_10000`, the
     one copy). A boat's crew of two counts its second crew. The panel's preview now does too (REQ-SET-055: 16, not
     20, for a boat at skill 0).
   - A hit on a net, trap or weir is a **severity 1 bite, −20 health**. A hit on a boat or the ice is **severity 2
     exposure, −35** (`care_rules.gd` NET_/BOAT_HAZARD_*, already cited from §5.4).
   - The description is "River pike and territorial eels … selected by habitat/day hash". It is `rng.gd
     hash_pair(habitat_type, day)`, a stateless hash, not a stream draw. Neither animal is ever food (REQ-SET-056).
   - The injury reaches the infirmary through `fishery.gd hurt`, which the village wires to `care_desk.gd hurt` with
     the Water source.
   - The care desk takes the patient to a bed only once nothing urgent holds them. A fisher carrying a catch, or still
     afloat or on the ice, lands first (`care_desk.gd may_take`).
3. **The rare-quality roll** is `min(1000, 100 + 30*skill)` per 10000 at the crew's skill (a boat's group skill). A
   success books 25% of the catch as EXCELLENT (`fishery_tables.gd t_excellent`, `fishing_rolls.gd excellent_milli`)
   and says so in the feed. It replaces that share; it adds nothing.
4. **The boats and the route planner** (perf 1001–1004). Brendan's ruling for fishing is "no free sailing", so a
   fishing boat's legs stay fixed routes (0432). Its crews' walks to the jetty are ordinary task walks through the
   routing desk. Under the live scene's routing window, those plans are carried across frames and served late, and
   the trip still sails, fishes and lands (`test_a_boat_crew_walks_to_the_jetty_through_the_route_desk`).

## PROPOSALS (Brendan's ruling needed)

- **P1. Who a hazard hurts.** §5.4 gives one roll per cycle and one injury, not whom. As built, it hurts the trip's
  first fisher: the netter, the trap's collector, the ice fisher, or a **boat's helm**. Options: (a) the helm, as
  built; (b) the crew member the same draw's parity picks (no extra draw); (c) the whole crew for a boat's exposure.
  **Recommendation: (a).** (c) doubles the GDD's stated harm.
- **P2. EXCELLENT stays in the fishery's books.** The pantry has no quality column, and every portion is PLAIN
  (`meal_store.gd`). So an excellent share is counted, shown and said, but stored as plain fish. Options: (a) as
  built; (b) give the pantry a quality column, so §5.7's eating order `-quality` can matter (a pantry and kitchen
  change: the kitchen chain's lane). **Recommendation: (a) now, (b) with the kitchen chain.**
- **P10. The order of cycles that open in the same frame.** ARCH-RNG-002 orders draws by Expedition ID. The demo
  opens at most a handful of cycles a frame and draws them in its job order, which is deterministic for a given run.
  Options: (a) as built; (b) collect each frame's departures and draw them sorted by Expedition slot. **Recommendation:
  (a)** for the demo; (b) belongs to the settlement simulation's own expedition system.
- **P3. REQ-SET-054's rescue job is not reachable in the demo.** It applies when a fisher is incapacitated (health
  1–15). The demo's infirmary keeps health at 16 or above (decision 0622 P1: the demo is non-fatal), and a cargo set
  down is already retained at its place (0431). So no rescue job is created for a fishing injury. Options: (a) leave
  it (the demo stays non-fatal); (b) allow incapacitation from fishing, with a rescue to the landing. **Recommendation:
  (a).** (b) reverses 0622 P1.

## Blocked, with options

- **Boats as router crossing rows** (the packet's Pitfall: "`route_kinds.gd` boat-crossing rows", group P's note).
  Making a fishing boat something a planned route may take would need a crossing row in
  `waterplay/water_crossings.gd` and the tunnel router. This lane may not touch the router: the digging revamp owns
  `demo/tunnel/`. It would also contradict "no free sailing" for fishing boats. `route_kinds.gd` already reads a crew
  member aboard as BOAT (0461). So it was **not built**. Options: (a) leave fishing boats task-driven (as 0432 and
  0461); (b) when river trade (#37) is scoped, give its own boats a crossing row like the ferry's, in a lane that owns
  the router. **Recommendation: (a), and (b) for TRADE.**
- **Fishing boats on the river.** §5.4 allows boats on river, lake and coast. The demo's two rowboats fish the pond
  only. A river station needs a new fixed route up the run and a validated draft. Not built; a small follow-up if
  wanted.

## Every number chosen here

None beyond the GDD's: the rolls, chances, injuries and the 25% share are §5.4's. The seed is the demo world's
(0622). PROVISIONAL numbers are in 1712 (P5, P6) and 1713 (P8).

## Files

- **New:** `godot/demo/fishery/fishing_rolls.gd`, `catch_plan.gd`, `fishery_stewardship.gd`, and
  `godot/test/test_demo_fishing_revamp.gd`.
- **Shared hooks:**
  - `fishing_driver.gd`: the preview's crew term; `danger_of_site`, `habitat_type_of_site`, `days_to_closure`,
    `set_intensive`, `intensive`; the header's blockers updated.
  - `fishery_tables.gd`: three appended trip columns.
  - `fishery.gd`: the rolls, the plan, collection and record hooks, and the reopening day.
  - `demo_fishery.gd`: Fish ▸'s fourth choice, the record line, the two buttons and the rare-catch line.
  - `waterplay/water_panel.gd`: two actions, one line, one row.
  - `demo_village.gd`: the infirmary hook, three lines.
- No pantry item or work-board source added. No key added.

## The independent review (code-reviewer, 2026-10-07)

No CRITICAL findings. Every HIGH and MEDIUM was fixed, each with a test:
- **HIGH:** draws were taken at completion, so a cycle called off after departure spent none (ARCH-RNG-002 says it
  keeps them). Now both are drawn at departure and resolved at completion, as in Decision 1.
- **MEDIUM:**
  - A morning-run trap scanned the calendar every frame. Its collection tick is now worked out once, when its soak
    ends (`fishery.gd _collect_tick`, `catch_plan.gd next_morning_tick`).
  - The panel recomputed Best catch's pick about six times a refresh. It is now cached for one refresh.
  - An event closure (the stored bit) was given an invented reopening date. It now says "reopening not known".
  - Best catch hid the real refusal (ice, the quota, full places) behind "no fish". The water's or the method's own
    reason is now shown first (`_no_fish_refusal`).
  - `on_action` had grown past 30 lines. The choice arms moved to `_on_choice`.
  - The excellent share was booked but never shown. The trips line now totals it, and a trip's share accumulates.
- **LOW, fixed:**
  - A refused injury was still announced.
  - The "-1 days" sentinel is now "not within two years".
  - Best catch stays chosen when the site changes.
  - Intensive takes two presses to turn on (the first says the floor and the recovery), so keyboard and gamepad
    players see REQ-SET-049's figures before accepting.
  - The record's trend sign, the pike/eel naming and the excellent share are now tested exactly.
- **LOW, left:**
  - The "earliest closure" tie-break inside `best_species` is reached only on an exact NP tie, and `better()` is
    unit-tested.
  - The restocking clause of the record line needs a stock in the latch, which takes many days of fishing to reach.
  - The village's wiring to `care_desk.hurt` is three lines, exercised by the live harnesses rather than a unit test.

## Gates

See "Gates (2026-10-07)" below.
