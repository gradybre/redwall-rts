# 0027 — Fishing needs two state columns §4.2 does not provide
Date: 2026-09-09 · Status: **Accepted — planner ruling received 2026-09-09**
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

## What was needed
Confirm both columns as GDD schema additions, or name the state you intended to
carry this behaviour. If REQ-SET-048 is warning-only, say so and column 2
disappears.

## Source
Task 03 increment 5 (partial), 2026-09-09. 926 tests / 27550 assertions / 0
failures; 36 mutations, 35 killed and one proven equivalent.


---

## Planner ruling, 2026-09-09 — both columns confirmed, and a third counted

`docs/rulings/2026-09-09_ready06_open_item_answers.md` §5 ratifies
`FishHabitat.effort_used:I32[32]` (+128 bytes) and `FishStock.restocking:B8[96]`
(+96 bytes) as schema additions, **and adds the one this record forgot to
count**: `FishHabitat.intensive_harvest:B8[32]` (+32 bytes), which the
implementation already saved and the §2.2 ledger already listed. The ratified
total is **256 bytes** for the three columns, before any cycle-ownership index.
`systems_architecture.md` §2.2 now carries all three without the
**PROVISIONAL** marker.

### The interpretation above is now the contract, not a reading
This record labelled "default to restocking blocks harvest" an interpretation
and noted that "the alternative is warning-only, and it is one line away". The
ruling closes that: the latch **blocks new harvest cycles for the affected
stock**, "it is not just a warning". The explicitly enabled intensive policy may
bypass that soft stop down to the existing 10% hard floor, but never a closure,
an unavailable species, the quota, danger consent or required gear. **The line
does not move.**

Two further constraints qualify what this record described:

- The two thresholds are **strict cross-multiplications** — enter at
  `100*P < 30*K`, clear at `100*P > 40*K` — so equality at exactly 30% or 40%
  flips nothing. `_percent_of()` agreed with that for §5.4's nine capacities,
  all multiples of 10; the comparison is now stated rather than coincidental.
- The latch is updated **independently of the override**. This record's
  structural argument for `harvest()` taking no `intensive` argument survives
  unchanged; what is added is that turning the policy *off* must restore the
  restriction immediately, which requires the latch never to read the flag.

### What this record does NOT cover
Effort-slot **ownership**. This record added an occupancy counter; ruling §5
requires a cycle-owned claim on top of it, because a counter alone cannot tell
whose slots are being released. That is
[0036](0037-fishing-effort-is-claimed-by-the-cycle.md), which also retires the
single-slot `reserve_effort_slot()`/`release_effort_slot()` pair this record
described in favour of an atomic multi-slot admission.
