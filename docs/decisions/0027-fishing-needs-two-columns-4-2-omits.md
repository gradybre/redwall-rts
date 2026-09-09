# 0027 — Fishing needs two state columns §4.2 does not provide
Date: 2026-09-09 · Status: **Provisional — needs a planner ruling**
Same class as [0026](0026-forage-patches-belong-to-the-basin.md): requirement
text mandates behaviour that the schema has nowhere to store.

## The pattern
Twice in §5.4, a requirement demands memory the §4.2 row cannot hold. Neither is
a contradiction the way 0026's was — nothing in the GDD *denies* these columns.
They are simply absent, and the behaviour is unimplementable without them.

## Column 1 — effort-slot occupancy
§5.4 states the capacities ("Habitat effort capacity: river 4, lake 6, coast 6")
and REQ-SET-044 says a starting cycle "shall reserve its effort slots". But
§4.2's `FishHabitat` row carries only `effort_slots` — **a capacity, with
nowhere to record how many are taken.** REQ-SET-050 then requires that occupied
slots *queue* further fishers "rather than multiply yield with unbounded
workers", which cannot be enforced without knowing the current count.

An occupancy counter is added. **It is state a save must carry.**

REQ-SET-050's *queue* is deliberately **not** added here: `JobState` already has
`QUEUED=0` and §4.2 sizes the Job store at 8192 active/queued rows, so the queue
belongs there. What this store owns is the cap that makes queueing necessary —
`reserve_effort_slot()` refuses once `effort_slots` are taken, so extra fishers
can never multiply a habitat's yield.

## Column 2 — REQ-SET-048's hysteresis bit
> When fishing stock falls below 30% capacity, the system shall warn of
> depletion and default to restocking until stock recovers above 40%.

Two thresholds, 30 down and 40 up. Between them **the required behaviour depends
on which threshold was crossed last, and population alone cannot answer that.**
A `restocking` bit is added to `FishStock`; §4.2 gives that row only `closed`.

The thresholds are stated explicitly and are **not** collapsed into one. A
single-threshold reading would be simpler and would need no column, which is
precisely why it must not be chosen for that reason.

## The interpretation this forces
Below 30% the minimum-stock floor already refuses every harvest, so the
restocking flag **can only bite in the 30–40% band.** It is read there as
blocking harvest unless the habitat's visible intensive-harvest policy is on —
which §5.4 says lowers the 30% limit to the 10% hard floor. "Default to" implies
something the player may override, and that policy is the only override §5.4
offers.

This is labelled an interpretation in `fishing.gd`'s header, in the manner
`resource_nodes.gd` labelled `regrow_days == 0`. **The alternative is
warning-only, and it is one line away** — the last three lines of
`_harvest_block_code`.

## A structural choice made to honour "never by auto-fallback"
§5.4 is emphatic that the 30% limit "can be lowered by an explicitly visible
'intensive harvest' policy, **never by auto-fallback**". So `harvest()` takes
**no `intensive` argument** — deliberately unlike `forage.gd`'s `harvest()`,
which does. The only input that can return the 10% floor is the stored,
single-setter policy flag, which makes the requirement structural rather than a
rule a caller must remember. REQ-SET-047's prohibition during a spawning closure
is enforced on top of it.

## What is needed
Confirm both columns as GDD schema additions, or name the state you intended to
carry this behaviour. If REQ-SET-048 is warning-only, say so and column 2
disappears.

## Source
Task 03 increment 5 (partial), 2026-09-09. 926 tests / 27550 assertions / 0
failures; 36 mutations, 35 killed and one proven equivalent.
