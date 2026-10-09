# 1145 — Initial timber stair timing

Date: 2026-10-04 · Status: Accepted tuning; runtime qualification remains open

## Accepted choice

Brendan selected “Natural (recommended): 1 second per step; 1.5 seconds for a
half-turn” in this thread on 2026-10-04. [DEC-050](../setting_decisions.md#dec-050--initial-timber-stair-movement-pace)
records that user ruling. The initial unloaded adult mole carrying the existing
pick uses **30 fixed ticks per tread, ascending or descending, and 45 fixed
ticks per supported half-turn** at normal game speed. The existing 30 Hz clock
owns progression; 2×/4× and pause retain their established meanings.

This adopts the first option below. It does not qualify the source for actual
World traversal, relax the profile speed/sweep checks, or adopt laden/other-cast
timings. Decision1143's frozen source-only reader continues to refuse activation
until the paid route, contact, source and playback bindings are complete. No
production playback was enabled by recording the answer.

## Original proposal and engineering obligations

The approved connection catalog explicitly leaves traversal speeds unresolved
(underground planning D04 and SET-MOVE-001). The 1139/1142 source captures prove
motion geometry and joins; their preview frame rate is not gameplay timing.
Before actual stair playback is enabled, ask Brendan to choose a starting feel.

The first proposal applies only to the measured, unloaded adult mole carrying
the existing pick, on the first authored timber tread/landing sequence. It
grants no compatibility to other residents, loads or connector types. At 1×:

| Option | One tread ascent/descent | Supported half-turn | Assessment |
| --- | --- | --- | --- |
| Natural, recommended | 1 second / 30 ticks | 1.5 seconds / 45 ticks | A readable step without making an ordinary stair trip dominate travel |
| Deliberate | 1.5 seconds / 45 ticks | 2 seconds / 60 ticks | More weight and visible foot placement, with slower hauling routes |
| Careful | 2 seconds / 60 ticks | 3 seconds / 90 ticks | Strongest emphasis on cautious movement, with the largest travel cost |

The table retains the original alternatives; only Natural is now approved.
These values are tuning choices, not measured traversal durations.
At 1 second per tread, twenty tread traversals account for twenty real seconds
at 1×, before landings, approach, turns and any waiting. The 2×/4× game speeds
scale actual time through the existing fixed-tick clock; pause advances nothing.

Implementation must map each complete source interval through integer phase
progress and preserve its exact root, heading, planted-foot and collision
evidence. The current source has stationary-root phases; distance alone cannot
advance their clock. No animation event grants a route, source payment or Work.
The chosen timing must remain within the actual movement profile's admitted
speed and full swept checks. If it does not, report the conflict before activation.
Approach/retreat, laden profiles, other species/stages and the wider connection
catalog retain their own explicit engineering/admission obligations.

No additional wood bill, labour bill, need drain, speed bonus or global movement
coefficient follows from this choice. The first landing/tread fixture and native
source witness are not promoted to a complete paid staircase. Ongoing hauling,
memory, motion-reader and review work continues under its existing gates.
