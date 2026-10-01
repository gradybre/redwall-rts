# 0437 — The ferry: a fixed two-landing cargo ferry across the run, carrying the far copse's windfall
Date: 2026-10-01 · Status: Accepted

Water part B, lane 3 (ferries and the regatta; group K of decision 0493). Builds on decision 0432's boat core and its
notes for this lane. Numbered in lane 1's 0431–0439 range (0437–0439 were free on every branch when written).
Brendan's approval, despite the review rating ECO-041 "Stretch" and moving vessels lying outside the adopted movement
scope, is decision 0439.

## Decision

**Geometry** (`demo/boats/boat_routes.gd`, decision 0432's shapes, checked by `validate`):

- **Two landings, each lane 1's jetty pattern**, outside every building footprint: the **ferry stage** on the run's west
  bank 8 m below the fisher shelter -- land end (22.9, 15.2), deck end (26.2, 15.2) -- and the **far stage** on the
  stream's far bank at its mouth -- land end (34.0, 21.8), deck end (31.6, 24.1) over the pond's north-east lobe. The
  same staged jetty model is drawn at each (`demo/ferry/ferry_view.gd`); the planner never routes over a deck.
- **A third boat, the ferry boat** (`FERRY_BOAT` = 2, `BERTH_COUNT` 3): moored off the ferry stage's end (27.6, 15.6),
  its ONE FIXED ROUTE down the run into the lobe -- (27.6, 15.6) -> (28.6, 19.6) -> (29.6, 23.2) -> (30.3, 25.35), 10.1 m
  -- off the far stage's end. No free sailing: the course is always this route, out and back. Each berth boards from its
  own jetty (`BERTH_JETTY`); the boathouse keeps the two fishing boats (`FISHING_BOATS`), the only ones fishing may take,
  and the only two the regatta races. The coracle prop moved off the lobe to (31.8, 29.6).

**The reason on the far bank -- the far copse** (DEMO): windfall at the east woods' edge on the stream's far bank, six
fixed spots north of the far stage, reached by land only over the ford (wading) or a bridge upstream. Its piles follow
the woods' own deadfall numbers (1.0–2.0 U in 0.25 U steps, 20 WU a U to gather), on its own spots and books -- never
the woods' deadfall rows, so nothing is counted twice: two lie at the start, one falls each midnight on the next empty
spot (a fixed function of the day, no generator). Measured on the real village (cast surface planner, a carrier's pace):
the far copse to the log stack is about 3.2 game hours by land over the ford and 2.3 by ferry -- 28 % quicker, plus the
wait for a departure. That benefit is the Ferry section's own preview line.

**The ferry** (`demo/ferry/ferry.gd`, numbers in `ferry_rules.gd`):

- **A staffed timetable and a departure threshold**: a crossing departs from the ferry stage at 06:00, 08:00 … 18:00 when
  anything waits to be carried (cargo at a stage, or a passenger waiting) and a crew takes it; between those, at once when
  the far stage's stack reaches **4.0 U**. A departure that falls while a crossing is out is skipped (the next is two
  hours on: no crossing posts at night after a long one). A crossing is a round trip; its crew is a **helm, FISH >= 1** (the boat core's
  rule; LORE-P12: never a species -- the boatwright or the fisher, or anyone who learns). No helm in the village:
  "unstaffed", said on the board. With every job row live, no crossing posts ("the ferry's job list is full").
- **Cargo first**: a gatherer carries a pile to the far stage's stack; the crew LOADS it (1 WU a unit, up to **12 U** a
  crossing), rows, UNLOADS onto the ferry stage's stack; a hauler (the woods' 6 U load) carries it to the log stack --
  the one stores' wood. **Passengers** ride the boat's second seat, one a crossing, cargo or none.
- **The boat is given back between crossings** (`fleet.take` at boarding under the crossing's serial, `give_back` once
  moored at home): free, the boat rescue may take it (`boat_rescue.gd`: each boat from its own jetty -- a rescue in the
  ferry boat walks to the ferry stage, rows from its berth and lands the victim there). A crossing due while a rescue has
  it waits for it.
- **Weather closure**: a storm (§5.10's heavy rain; REQ-SET-052), a hard freeze (REQ-SET-144), the tunnels' flood on the
  stream, or ice on the pond (its route ends in the pond's lobe). Closed, no crossing departs and no passenger boards;
  a crossing under way **finishes the leg it is on, then holds** (MOVE-REQ-007): arriving at the far stage it does not load
  (closing while it already loads, the load finishes aboard -- on the books), its crew steps ashore and the boat stays the
  crossing's until the ferry opens and a crew walks round to bring it home. That crossing is never ended while its boat is
  out: a bring-back crew who cannot reach the far stage gives the job back to the board ("waiting for a crew who can
  reach it"), and Cancel is refused while it is held -- ended with the boat afloat, the boat would be orphaned
  (`give_back` refuses a boat that is not moored).
  Closed at the ferry stage before pushing off, the crew stands down and the boat is given back (end a leg on any
  refusal); a passenger who boarded steps back ashore. **Stranded cargo** -- wood at the far stage or aboard, or the boat
  held, while closed -- is the WARNING incident `water:ferry_stranded`, resolved when it opens. The Routes layer draws the
  ferry's course labelled with its line ("Ferry: closed: a storm · …") and the Water panel's Ferry section says it too.
- **The books**: `fallen == lying + in hand (or set down) + far stack + aboard + near stack + stored` at every frame
  (`books_balance`), through cancel (a crossing is called off only before its crew is aboard; a delivery always
  finishes), closure mid-crossing and interruption (a carrier called away sets its load down where it stands for the
  next).

**The router's crossing row** (`demo/waterplay/water_crossings.gd`): the ferry is `FERRY_ROW` = 3500 -- its own row and
leg code, clear of the bridges', the swim links', the route preview's proposed bridge (`preview_crossings.gd
PROPOSAL_ROW`, 3000 -- a first choice of 3000 collided with it and made the Routes layer read the ferry as "new bridge")
and `ASHORE_ROW`. Offered to any trip crossing the water while open, staffed and boardable within **2 game hours**; its
cost is both decks walked (0.6 m/s), the row and the wait for its next boarding at the nearer stage (a crossing
posted at home still waiting for its crew: that crew's walk to the stage, a straight-line lower bound), as metres at
the walker's pace -- so the ferry wins for slow walkers and carriers, while a fast walker goes round by the ford. A passenger waits at the stage, boards when the boat loads there (a crew with nothing to load
holds `BOARD_GRACE_STEPS` simulation steps for a passenger waiting there: the passenger's own brain steps its leg and
may see the boat loading a step late -- seen live, the boat left without it), rides held on the water,
and steps off at the other stage; **any refusal while it waits ends the leg there** -- closed, the wait too long, the
seat taken, or an order given meanwhile (its goal or route changed) -- and the route is cut where it stands, as the bank
recheck cuts a refused swim, so it plans again by land.

**Wiring**: the work board's ninth source, `SOURCE_FERRY` (`work/ferry_work.gd`: gathering is Woods work, hauling and
crewing are Hauling; `SOURCE_WALK` moves to 9, past every source); action cards on Gather the far copse, Send the ferry
and Cancel crossing, from the orders' own decisions; the Routes layer's **by ferry** kind (`route_kinds.gd KIND_FERRY`,
its legend and colour) for a planned leg and for anyone aboard the ferry boat, and the post "waiting for the ferry"
(`route_reasons.gd WAITING_FERRY`); ferrying counts as work for the songs through the board's own states (no change to
the songs). **No deed** is recorded for a notable crossing count: none of the ledger's kinds fits one, and the brief
asked for none to be invented.

## Why

ECO-041 asks for exactly this shape -- two landings, a staffed timetable, a departure threshold, weather closure, cargo
first then passengers, no free sailing, and a reason on the far bank -- and decision 0432 left the boat core ready for
it. The village had no far-bank work a ferry would serve, so the far copse supplies one honestly from the woods' own
numbers. Rejected: a pond-only ferry (both its shores are reached quickly round the pond's south end: no benefit),
a stream crossing by the mill (the weir reach is narrower than a rowboat is long), using the woods' own deadfall rows
(the reason would depend on where the woods' daily pile happened to fall), and taking a fishing boat (the ferry would
compete with every boat trip and the regatta).

## Consequences

- Anything iterating `fleet.count` now sees three boats; fishing iterates `FISHING_BOATS` only.
- A new crossing row must avoid 3000 (the proposal), 3500 (the ferry) and 4000 (ashore).
- The Recipes and the farm are untouched: the ferry's cargo is the stores' wood.

## Source

Review ECO-041 (`docs/reviews/2026-09-30-external-review.md`); decision 0432's notes for this lane; GDD §5.4 (boats),
§5.10 (REQ-SET-052 storm, REQ-SET-144 hard freeze); SET-MOVE-001 MOVE-REQ-007; forest_rules.gd's deadfall numbers;
Brendan's approval (decision 0493, group K; decision 0439).
