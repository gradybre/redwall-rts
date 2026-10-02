# 1005 — The cook serves what is in the pot, the seatless wait off the cook's spot, and a trip with no route waits before it plans again
Date: 2026-10-02 · Status: Accepted

Brendan's ruling of 2026-10-02, "fix kitchen now": when a meal is called, the cook serves what is in the pot rather than
cooking the whole meal first, then cooks on and serves again. The ruling follows the scale measurements in
`docs/performance/2026-10-02-route-planning.md`. After decision 1001, supper fed nobody at 50 to 256 residents.

## Decision

1. **SERVED AS IT IS COOKED** (`demo/kitchen/kitchen.gd`, `_serve_early`, used by `_pot_due`). While a meal is being
   served, if the pot holds its portions and the table has none of them left, the cook carries the pot out between
   batches. Then it cooks on. A batch in progress is always finished first.
2. **The wait spots** (`kitchen_places.gd`, `wait_spot`, `kitchen.gd _diner_spot`). A diner with no seat waits at one
   of WAIT_SPOTS_PER_TABLE = 12 spots on a ring WAIT_RING_GAP_M = 1 m beyond each table's seats, outside its serving
   gap. Each spot is moved clear and reachable like a seat. It used to stand at `stand_table`, the cook's own spot.
   With no wait spots (a fixture), it still does.
3. **NO WAY YET** (`resident_brain.gd`). When a plan finds no route, the walker still walks the straight line as before,
   but the trip is not planned again until NO_ROUTE_RETRY_S = 2 s has passed. Meanwhile it walks on into whoever stands
   across the line, and the per-frame constraint keeps it out of them.

## Why

Each part was traced in instrumented runs of the scale harness. The traces are summarised in the performance note.

- **The pot.** With 50 or more diners a meal is 25 to 128 batches, more than its two-hour window holds. The cook cooked
  straight through supper and carried the pot out after the serving had ended. The literal ruling feeds them as it is
  cooked.
- **The wait spots.** With the ruling alone, the cook could not reach the table to put the pot down: 40 diners without a
  seat stood on its spot. Two portions were eaten, against eight before. Moving the seatless off the serving gap let the
  pots out.
- **NO WAY YET.** This was the 256 case: the cook was never handed its round. Its store walk found no route,
  because it starts boxed in by the stress cast's off-POI residents stacked round the origin. After decision 1001 a
  failed plan costs a few expansions instead of a whole graph and seconds at the routing desk. So MAX_REPLANS retries,
  and the kitchen's MAX_FAILS walks, used themselves up within a second. The kitchen let the store go each hour, and
  nothing was fetched. Pacing the retries restores the old pacing without slowing the plans. Without it the 256 runs
  cooked nothing (2 of 2). With it, 5 to 8 batches were cooked.
- **Rejected:**
  - Serve early only when the meal cannot be cooked in its window: it left 25-resident suppers at 0 in two of four
    runs, because the cook started late after day 1's breakfast was served.
  - The same with an hour's margin: the same as the literal rule at 9 and 25, but 0 at 256 in its one run.
  - The literal rule alone, without the wait spots and NO WAY YET: 2 eaten at 50, 0 at 256.

## Measured

Supper, then breakfast fed, on the scale harness's full plan (stocked; meals `[breakfast, supper]`). These are
instrumented A/B runs on the loaded machine; the settlement clock runs on real time, so outcomes vary run to run
(decision 0561 §4).

| N | before (base, 3 runs at 25) | this decision |
|---|---|---|
| 9 | [0, 8] | [4, 7], [4, 7] |
| 25 | [0, 23], [0, 22], [0, 21] | [4, 17], [2, 17], [4, 18] |
| 50 | [0, 8] | [0, 18], [0, 18] |
| 100 | [0, 9] | [2, 16], [0, 20] |
| 256 | [0, 0] (15 batches cooked, none served) | [0, 8], [0, 8] |

- **Totals.** Portions eaten rose at every N: at 9 from 8 to 11, at 50 from 8 to 18, at 100 from 9 to 18–20, at 256
  from 0 to 8.
- **At 9 and 25 the results did not stay the same.** Breakfast on day 1 is now served at all (2–4 fed, against
  none). Supper fell from 8 to 7 at 9 and from about 22 to about 17 at 25. Total portions eaten were about the same at
  25 (19–22) and higher at 9. Serving breakfast shifts the cook's day, and at 25 supper is at the edge of what one cook
  can serve in the window.
- **For Brendan:** keep the literal rule as it is (recommended: every meal now feeds someone, and at 50 and above,
  supper is fed at all), or restrict it so 9 and 25 match exactly. The latter needs a different trigger, and none of
  the two tried did both.

## Consequences

- The seatless wait on a ring round each table. 12 spots a table are shared by index when more wait.
- A walker with no route takes up to MAX_REPLANS x NO_ROUTE_RETRY_S (8 s) more before it gives a trip up.
- **Not done:** the stress cast's stacked off-POI starts and the hall's and tables' capacity, the scale test's content
  limits. 256 still feeds only 8, and in some runs its cook is still late.
- **Merging with the review-fix lane** (`fix/codex-review`, decision 0997's meal-finalized event). This change touches
  `_pot_due`, `_serve_early`, `_seat_for` / `_diner_spot`, `_eat_next`'s walk and `_face_of_seat` in kitchen.gd. It
  does not touch `_close_meal`, `_record_meal` or the finalization.

## Source

Brendan's ruling of 2026-10-02; decisions 0381 (the kitchen) and 1001 (cheap failed plans); the traces and runs
summarised above.
