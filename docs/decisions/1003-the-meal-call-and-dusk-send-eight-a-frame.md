# 1003 — The meal call and dusk send at most eight residents a frame, and the hall's door places are counted once
Date: 2026-10-02 · Status: Accepted

Part of Brendan's approved "route planning + bursts" (decision 1001 gives the context and numbering). It answers the
scale test's hot spot 2 (decision 0561): the moments that put the whole village on the routing desk in one frame.

## Decision

1. **The kitchen's call is spread** (`demo/kitchen/kitchen.gd` THE CALL IS SPREAD). One pass of `_call_diners` calls
   at most CALLS_PER_FRAME = 8 diners, in resident order. With more to call it sets `_calling_on`, and `update`
   calls on in the next frame, between the hand-out ticks. Who is called, the order, the parking of their work and the
   re-call of the free after RESEND_TICKS are unchanged.
2. **Dusk is spread** (`demo/burrow/night_routine.gd` DUSK IS SPREAD).
   - `_at_dusk` allocates the beds, then sends at most SENDS_PER_FRAME = 8 residents, in order. `_send_at_dusk`
     carries the cursor on, a frame at a time, until everyone has been asked.
   - Through the night `_send_the_free` also sends at most 8 a frame. It does not run while dusk's sending is still
     going, so a resident dusk has not reached yet is sent by dusk, with its work parked.
   - Dawn stops dusk's sending, were it still going.
3. **`hall_spot` is a lookup.** Each resident's place among the bedless is counted in one pass (`_rank_bedless`) and
   kept until `bed_of` changes. It used to be a count of the bedless before each resident, made for every resident:
   O(N²) at dusk. The comparison with `bed_of` is a native array compare, so a test or the winter's consolidation
   writing `bed_of` directly is still seen.

## Why

- **Eight.** It is the scale test's own example (its recommendation 3). With the routing desk now cutting plans
  (decision 1001), the desk, not the call, limits how fast residents set off. The call only has to stop handing the
  desk a hundred plan starts in one frame: a hundred residents are called within 13 frames, about 0.2 s.
- **Order kept.** Both loops already ran in resident order, so the spread calls the same residents first.
- **Rejected:** a quota per routing window (couples the kitchen to the desk for no gain once plans are cut); spreading
  dawn (dawn's sleep tasks end in each brain by itself, not in one loop of the night, and the measured plan does not
  reach dawn).

## Consequences

- At 9 residents nothing changes: eight or fewer are called or sent on the one frame. Above that, the rest follow on
  the next frames.
- **PROPOSAL (Brendan):** 8 a frame is a demo number with no source in the GDD or the balance document. Options: (a)
  keep 8; (b) tie it to the routing desk's budget; (c) a larger number such as 16. Recommendation: (a). Plans are now
  cut by the desk, so the number only shapes the first frames of a burst.
- The hall still has five door places (`hall_spot` steps them modulo 5). More places are a design call the scale test
  listed under "Limits that are not CPU".


## Brendan's rulings (2026-10-02)

Brendan approved 1003 as recommended:
- 8 a frame for the kitchen's call and dusk (option (a)).

## Source

Decision 0561's hot spot 2 and recommendation 3; decision 0381 (the kitchen) and 0210 (the night); Brendan's approval
of 2026-10-02.
