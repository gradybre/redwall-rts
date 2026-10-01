# 0361 — Explicit arrival, crew hand-offs, and routes planned across frames
Date: 2026-10-01 · Status: Accepted

Review group A (F02, F03, F04, F05, F08, F09, F15) and D2 (F01, F06) of the live-demo review
(`redwall-review/REVIEW.md`, written against 157a3a4). Built on feat/live-demo 6b6e2ca (tunnel phase 6, decision
0212). Everything here is the demo's presentation layer; nothing the simulation owns. MOVE-G01–G05 stay open.

Number: the next free above 0360 after checking every branch and worktree (the highest in use was 0351).

## Decision

1. **Arrival is an explicit outcome** (`resident_brain.gd` ARRIVAL AND REFUSAL). `trip_outcome` is UNDERWAY when a
   trip starts, ARRIVED only in `_arrive()`, FAILED when it is given up. A job's owner credits work or a delivery only
   to a worker for which `arrived_near(spot, reach)` holds — arrived AND within reach of the spot it reserved — and
   rechecks it every frame it works. The spoil crew pauses a row whose walk failed (`blocked`, a 3 s retry, at most
   three tries, a basket kept in hand); a basket reaches the store only by being tipped at the drop spot — a row ended
   anywhere else (called away, re-ordered, given up) puts it back on its heap (`farm_tunnels.return_spoil_into`). This
   **replaces 0205's "called away, its basket goes into the store"**: that was a delivery from afar. The bridge crew
   drops the builder, the feed naming who could not get where, lets it go (`work_done`) and keeps the routine crew off
   that bridge for 10 s. A dig crew's basket (0211) is tipped only at its tip spot; one whose walk out failed goes back
   to the pile behind the face. Holding is no longer evidence of arrival (F05).
2. **An empty route is never walked** (F02). `_begin_leg` refuses an empty path wherever it was planned (the review's
   `_replan_or_abandon` path had been guarded since d0663be; `_go_on_from_mouth`, the mouth queues and every order
   start were not — reproduced at `_go_on_from_mouth`): the trip is given up at once, the job suspended (kept to come
   back to), reservations released and any mouth line left, and `route_refusal()` says why. The party panel shows
   "holding — can't find a way there" / "holding — gave up: the way there stayed blocked".
3. **A crew member resolves its piece's active segment itself** (F03, `tunnel_crew_task.gd` `_site_now`). Stepped
   after a Foremole that opened a segment and began the next in its own update, a member whose crew's segment is
   open walks the piece's chain to the segment being dug and moves the whole crew there before deciding anything —
   the works' `_watch_opening` move, made synchronously. Independent of cast order and sub-steps.
4. **A finished dig takes the saved job back up** (F04) once the digger has stepped clear of the hole (`_hold_here`
   after `_step_clear`). R still forgets saved jobs; at night `take_up_unfinished` keeps them for the morning
   (decision 0210); any new order or release during the step-out — on the surface or still walking out below — wins.
5. **The Dig tool opens whenever some piece could fit** (F08, `any_piece_refusal`: one free segment row); the piece
   as laid is refused for the capacity it would exhaust (`rows_refusal`: REFUSE_NO_MOUTH_ROWS / NO_NODE_ROWS /
   NO_SEGMENT_ROWS, worded with the demo's caps).
6. **A resident index that names nobody is refused** (F15): the bridge crew reads the builder before clearing its row;
   `DemoCast.actor` and `BridgeCrew.name_of` reject indices out of range (an error, never the cast's last actor).
7. **Per-frame reads make nothing** (F01): piece chains and each segment's offset along its piece are kept per graph
   `topology` (every chain change — add, split, free, room — bumps it); the selection has a revision with
   `first_selected` / `selected_into`, and the water controller reads it only when it changed.
8. **Route planning is budgeted per frame** (F06): `route_desk.gd`. Every plan's time is charged to a frame window
   (input through the cast's step); a trip start (order, task walk, replan, queue give-up) plans at once only while
   the window can take a typical plan (a running mean), else the resident waits in State.ROUTE — "finding a route"
   — and is served first come first served at the next frames' cast step, paused or not. Routine departures idle a
   moment instead. Budget 3.5 ms in the live scene; none out of the tree (the suites' hand-stepped brains are
   unchanged). The formation's reachability test is one sweep from the group's start over the static graph's
   connected parts (cast_nav.gd REACHABILITY BY ONE SWEEP), never one A* per candidate.

## Why

- Each finding was reproduced on this branch first with a failing integration test that runs the real owners in
  live order (`test_demo_handoffs.gd`): F02 (out-of-bounds at `_go_on_from_mouth`), F03 (a surface hand stepped after
  the Foremole left the crew 1772 frames early; a member below was masked by the baskets), F04 (both surface- and
  underground-ending pieces), F05 spoil (a physical wall: 6,000 milli-U delivered and 2,000 carried from afar) and
  bridge (loading from afar), F08 (the tool refused with 72 segment rows free), F15 (the feed named Placeholder 5).
  F07's consent recheck was already fixed by group C and its test (`test_demo_water_safety.gd`) runs the real order.
- A time budget, not a count: the precedent is the nav graph's sliced rebuilds (0209). It makes *when* a resident sets
  off depend on the machine, never *where* it goes; out of the tree there is no budget, so the suites stay exact.
- A look-ahead estimate rather than "spend until over": a plan cannot be cut in two, so the window must refuse to
  start one that would not fit.
- The sweep's yes is exact (the plan would find that very route); its no differs only where the plan's goal-side
  shrink would have cleared a start link — refused like an unreachable spot. A 9-resident formation fell from up to
  16.7 ms to 0.1–1.5 ms.
- Rejected: resumable (sliced) A*. The planner's search state is shared member scratch used by many synchronous
  callers; slicing it is a larger change than the review asked for.

## Measurements (local M5 Pro, uncontrolled; not qualification)

Before = 6b6e2ca, after = this branch with the review fixes.

- Group order (the review's probe: 9 residents x 8 goals x 3, paused): command median/p95/max **13.2/28.1/28.2 ms →
  3.4/4.8/5.1 ms**; worst routing frame **28.2 → 5.0 ms** (p95 4.7); every route served within 6 frames (~0.1 s).
- Rendered 1920x1080, vsync off, a nine-resident group move every 2 s for 20 s: 1x frame p95/p99/max **8.74/8.92/15.88 →
  8.83/8.98/9.31 ms**; 4x **8.96/9.23/17.86 → 9.03/9.28/10.75 ms**; the command's frame max **15.9 → 8.8 ms** (1x) and
  **17.9 → 8.8 ms** (4x); routing per frame p99 0.8 ms (1x) / 3.1 ms (4x), max 5.2 / 5.4 ms. The display paced frames at
  ~8.3 ms, so p95/p99 are the renderer's, not routing's: the change shows in the max and the command frames.
- The ~4 ms target holds at p99; the worst frame is ~5 ms because one plan is never cut in two (see Consequences).
- Crew following reads (12 tunnels in the table): **22.6 → 1.05 µs** a member sub-step (three members at 4x: 271 → 12.5 µs
  a frame). Water controller's selection read: 0.37 → 0.13 µs a frame, no array made.

## Verification

- `test_demo_handoffs.gd` (23 tests) and `test_demo_route_desk.gd` (13): each finding's reproduction, run in live
  order, plus the cases below. Basket hauling (0211) tips only at its tip spot and returns a basket whose walk out
  failed to the pile behind the face.
- Mutation: one mutant at a time, the file restored and its SHA checked each time. The first pass killed 37 of 42;
  the five survivors (the sweep's pocket and start-pocket closure, a new start's sweep, the chain's end clamp, a
  routine departure in a spent window) and one of three later mutants (the basket's tip-spot check) each got a test
  that kills them. The review fixes' own mutants are counted in the hand-back.
- An independent review of the first commit found two HIGH defects (an order during a below-ending dig's walk out was
  overridden by the step-out and the saved job; a paused basket was delivered from afar when its worker was called
  away) and four MEDIUM (the sweep cache ignored the body; a desk turn that re-waited could be dropped; an unreached
  bridge builder was left holding; spoil retries never ended). All fixed with tests.

## Integration with review batch 2 (decision 0332's cards, 0292's lens)

This branch was cut before review batch 2 (PR #201) and merged after it. Where the two met:

- **One selection source.** The Water range lens (`water_range.gd`, 0292) follows the selection only when its
  revision moved: `demo_waterplay.gd _follow_selection` reads `selection_revision()` and builds the selection array
  once per change, then repaints whenever the lens's own revision moves (a new selection or a ◀ ▶ step). The village
  map's dots and the canopy read `is_selected`, the same byte column; nothing reads the selection per frame by array.
- **The Dig tool's card refuses what `begin_plan` refuses.** `tunnel_control.gd tool_card_into` asks
  `any_piece_refusal` and, with no piece able to fit, states the capacity in `begin_plan`'s own words (code
  `NETWORK_FULL`). A piece refused as laid (`rows_refusal`) depends on the piece, so the card cannot preview it.
- **"Can't reach it" reaches the cards.** A spoil worker waiting to retry says so in its task text, which is the
  activity an action card's Interrupts line quotes. A bridge whose builder could not get there reads, in the Water
  panel, "waiting — can't reach it; the crew tries again in N s" for the UNREACHED_WAIT_USEC the crew leaves it; the
  build card's Who is unchanged (a new bridge's row has no such wait).

## Consequences

- Any new job owner must use `arrived_near`, not `state == HOLD`, before crediting work. **The farm crew
  (`farm_crew.gd`) and the woods crew (`forest_crew.gd`) still treat HOLD as arrival** — out of this review group's
  scope, left open.
- A single plan is still atomic: a search that fails over the whole graph (a goal boxed in by standing residents)
  costs up to ~10 ms in the village, and the desk can only keep it to one per frame.
- Code that reads `brain.path` right after an order must allow for State.ROUTE in the live scene. The sweep kept by
  `reaches()` is per start, body and graph; anything that changes the circles goes through `cast_nav.setup`, which
  drops it.

## Source

REVIEW.md F01–F06, F08, F09, F15, P2 lifecycle detail and P5 work package (1); decisions 0205, 0208–0212; CLAUDE.md
frame and routing targets (frame p95 < 16.67 ms; route ready p95 < 0.25 s).
