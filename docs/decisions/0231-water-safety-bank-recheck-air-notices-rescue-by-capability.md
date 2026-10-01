# 0231 — Water safety: the bank recheck, threshold air notices, rescue by capability
Date: 2026-09-30 · Status: Accepted

External review group C (F07, F38, F39), written against 157a3a4 and reconfirmed here on `feat/live-demo`
43d9654 with failing tests before any fix. **Numbered 0231, not 0212:** parallel review branches each take
their highest number plus 20 (0211 + 20 here), so they cannot collide. Everything is in
`godot/demo/waterplay/` (the demo's water; presentation over integer rules). No shared cast, router or
notice-feed file was changed.

## Decision

**F07 — the bank recheck** (`water_crossings.gd` THE BANK RECHECK). A swim link's eligibility is checked
again every step of the walk down the bank until the swimmer goes in (`entry_refusal`: `swim_refusal` with
the load actually carried, then whether it can still hold its line against the flow now). Refused, it walks
back up to the land end (PHASE_REFUSED), its route is cut there, and it plans again from land, where the
same refusal offers it no swim. The feed says why (`waterplay_text.gd bank_refusal_line`). **Someone already
swimming is not pulled out**: consent and HAZ-001's entry bar govern going *in*; mid-stream it finishes the
crossing to the far bank (MOVE-REQ-007), or turns back by HAZ-003's tiring return, or is rescued -- and its
next trip is planned on land, where the refusal applies.

**F38 — threshold notices** (`swim_state.gd` EVENTS). LOW_AIR (450) and AIR_OUT (0) are threshold entries,
latched in `air_latch` and re-armed only by a fresh dive (MODE_DIVE entered from the surface) or at the
surface with air back at `AIR_LOW_REARM` = 600 (demo value: a 150-unit band, about 1.3 s of breathing). One
dive says "low on air" at most once; the next dive says it again even if it starts below 600 (a fetch is
admitted with 300 plus its down-and-up ticks: 420 for a victim 1.0 m down). The breath is a meter the panels
read in place (swimmers list, party panel, the incident line); the feed carries transitions only, so an
incident no longer floods the 32-row ring.

**F39 — rescue by capability** (`rescue.gd` BY CAPABILITY, `rescue_tasks.gd` ONE RESPONDER).
- Only a rescuer able to do what the victim needs is ranked, nearest by route among those able. Held below
  (with air left): a diver who may swim now and whose air covers `fetch_ticks` (down and back up at 0.5 m/s)
  plus HAZ-002's 300 reserve. At the surface, or floating up with no air: any swimmer.
- Fallbacks carry an explicit reason in the feed and on the victim (`why`): no diver -- a swimmer treads
  above (RESPONSE_WATCH), ready to tow the moment it comes up; no swimmer -- a line from the nearest landing.
- Every DISPATCH_S a fallback is re-evaluated: a diver come free takes over from a watcher or a line; a
  swimmer from a line. The relieved one stands down (swims ashore if in). Nothing is replaced once the victim
  is in hand (`towed`), and a watcher is never swapped for another watcher or for a diver while the victim
  floats up.
- One responder per victim, reserved atomically (`reserve` names who, how and why in one call; `release`
  frees it only for its holder, so a relieved rescuer's cancel never frees the victim from its successor).
  The reservation is authoritative: a rescue task whose victim is no longer reserved for it ends when it
  next steps (a relieved rescuer whose `work_done` took up an unfinished job keeps its task until then), and
  `towed` (in hand) is set only by the holder and cleared when it lets go -- so the wash-ashore safety net,
  which waits while a victim is in hand, can never be frozen by a stale mark.
- A diver sent to watch because it was short of air is promoted to RESPONSE_DIVE in place once it has
  breathed enough (`_promote`), instead of being relieved by a farther diver (code review H1).
- A rescuer is checked again at the water like any swimmer: with swim shortcuts turned off on its way (or
  otherwise refused by HAZ-001) it lets the victim go there rather than going in, and the next look sends
  another.
- A rescuer the player calls away frees the victim at once and is not sent back to it (`let_go`): the
  player's order stands, and the next capable one goes. `let_go` holds one id and is also set by any other
  release (a failed walk, a stand-in); the only capable diver may therefore stay excluded from that victim,
  which the safety net covers.
- The Water panel's alert line is one incident per victim, updated in place: where it is and its breath,
  the responder and its phase, the landing once settled, and the reason -- or, with nobody, when the water
  brings it ashore.

The non-fatal safety net (DEC-040) is unchanged: wash ashore after 90 s unanswered, 240 s answered.

## Why

- **F07** reproduced with the real `toggle_consent` handler: a swimmer ordered across the run went in with
  consent off. Refusing at plan time only is not enough once the player can change the inputs between plan
  and entry. Checking every step down the bank (O(1)) catches a change during the descent too, and walking
  back to the land end keeps the refused swimmer where the planner can route it. Cancelling an in-water leg
  was rejected: it would strand a swimmer mid-stream, which the review itself warned against.
- **F38** reproduced through a real DiveTask admitted at T + 300: 50 notices in one dive (at 0.1 s frames;
  the review saw 150 at finer steps), all 32 rows low-air, the older actionable warning gone. Latching at the
  source is the smallest change that bounds every consumer; a per-resident coalesced feed entry was not
  needed once the meter lives in the panels.
- **F39** reproduced with a real DiveTask plus `cramp()`: the nearer mouse was sent, the farther otter left
  free, contact at 40.1 s after the victim's air had reached 0. With the fix the otter is sent and has the
  victim in hand at 23.8 s with 438 air left. The `let_go` rule came from the interrupted-rescuer test: the
  called-away diver was otherwise re-sent a second later, overruling the player.

## Consequences

- A bank refusal is a NOTE; it fires only when conditions change between plan and entry (routine plans
  already exclude swims the swimmer may not take).
- `AIR_LOW_REARM` is a demo value like the rest of `swim_rules.gd`'s rescue numbers; SET-MOVE-001 §4 still
  owns production oxygen values.
- Water part B (boats, fishing trips, rescue by boat) should add its responder as another RESPONSE_* rank
  through `reserve`/`release`, rank it with `nearest_capable_into`, and never post per-tick status to the
  feed.
- An independent code review (code-reviewer agent) found the H1 promotion gap, the untested `towed`
  reset, the rescue-entry consent gap and the stale-latch case for shallow fetches; all are fixed and
  tested. Its note that relieved fallbacks are re-ranked once a second for the whole incident (two
  full-cast gathers, at most 2 x MAX_PLANS route plans) is accepted at demo scale.
- Measured in `godot/test/test_demo_water_safety.gd` (time to contact, least air): farther diver 23.8 s /
  438; second diver after the first is called away 24.1 s / 408; first of two victims 14.9 s / 429; diver
  taking over from a line 24.1 s / 408; an otter by the pond promoted from watching once breathed 7.8 s /
  864; nobody able to swim 40.2 s / 0 (hauled in on the line after it floated up, unhurt).

## Source

`/Users/brendan/Developer/redwall-review/REVIEW.md` F07, F38, F39 and the water-safety work detail; HAZ-001/
002/003 (`docs/underground_economy_hazard_amendment.md`); REQ-SET-054; DEC-040 (`docs/setting_decisions.md`:
warned, preventable, non-fatal); decision 0196 (water part A), 0205 (nearest by route).
