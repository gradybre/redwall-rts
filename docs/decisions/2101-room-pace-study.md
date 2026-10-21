# 2101 — Room-pace study: what a room costs today, what target is sensible, and how to reach it (stopped for rulings)

Date: 2026-10-21 · Status: **Accepted (2026-10-21).** A docs-only study; no code, data or test is changed. P-2101-1 to P-2101-7
wait for Brendan.

Number: **2101**, from the range 2101–2109 the coordinator gave this study. It is free on every local and remote ref
(`git ls-tree` of each ref's `docs/decisions/`; `git log --all -- 'docs/decisions/210*'` finds nothing), and
`python3 docs/validation/decision_numbers.py` passes. Branch `docs/room-pace-study`, from origin/master `e0e7065a`.

**Citations.** Decisions 2081, 1933, 1935, 1943, 1953 and 2052/2053 are on master. Decision 2045 is on
`origin/feat/slice-d-m5-full`, 2082 on `origin/feat/entry-batched-build` and 2091 on `origin/docs/stair-leg-delivery`;
none of the three is on this branch. Slice C's Routes cost findings were relayed by the coordinator
(`docs/handoff/LIVE_WORK_SLICE_D.md`, untracked, 2026-10-21).

**Also for Slice C.** Room digs share the entry's cold-transition shape. §1.4 and §5 give the room's own transition
counts and costs, measured, as an input to phase-spreading stage 2.


## Brendan's rulings (2026-10-21)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2101-1 | **(a)**, "16 cubes in 30–60 s" | A 16-cube room takes 30–60 s of working time at 1x (about 3 s a cube; a 96-cube Kitchen about 5 min) |
| P-2101-2 to P-2101-7 | **(a)**, "Approve all" | Working time with materials stocked (rooms keep rest hours); a standing 24 wood + 24 stone stock in the level-1 store, with the stair runner at the entrance's ~10x scale (amends DEC-050 for the runner, and P-2091-2/-8); batched room digs reusing 2082 at k about 1.5–2 as a Work rate; spoil to the foot pile now, carried up on the runner's return once 2b-2 lands; crew 1–4 unchanged; no runtime change now: after the cost lane, measure one real level-1 room (gate: heavy operations about 15 s or less), then a room-pace build lane (2102–2109) |

## The ruling being studied

Brendan, 2026-10-21, relayed by the coordinator: **"Start room-pace study now".** Decision 2081 had ruled that the
whole full-level stair takes **30–60 real seconds at 1x** (900–1,800 ticks), and P-2081-8 (a) kept rooms at DEC-059's
rates "for now", with a room-pace study after D2. Decision 2091 then found that a 16-cube level-1 room needs about
**35,400 ticks (about 20 minutes at 1x)** of stair hauling, against about 2,976 ticks of digging.

## In short

- **A level-1 room today is a stair-haul, not a dig.** A 16-cube room takes about **36,100 ticks plus about 100 s of
  cold transitions: about 22 minutes at 1x** (estimated). Of that, 35,400 ticks are the eight stair trips; the dig is
  2,845 ticks. A 49-cube room takes about **70 minutes**. On the default schedule the hauling stretches by about 1.7×.
- **The same rooms on the surface level take about 1–5 minutes** (measured: 162 s for the 16-cube Kitchen with its
  eight same-level hauls; estimated about 61 s for 4 cubes and 281 s for a 4 × 4 floor band), and **about 17
  minutes for 49 cubes**.
- **Where a dig's ticks go** (measured on master, §1.3): in a 2 × 2 room dug its painted 4 m, claw clips 38 %, Work
  31 %, walks 30 %. In floor-band rooms, where every cube has its own station, **walks are 68–74 %**.
- **Each cube makes six heavy cold ticks** (three STARTs and three settlements, 47–200 ms each on the fixture,
  growing as the room is dug). On level 1 each is estimated at 0.5–2 s, because every transition re-proves the
  flight's published route graph. A 16-cube room has 103 of them.
- **Real rooms are bigger than the fixtures.** At the painted 4 m the GDD's minimum rooms are 48–128 cubes (the
  Kitchen 96). A 96-cube level-1 Kitchen needs **48 stair trips, about 212,400 ticks: about two hours at 1x** of
  hauling, twelve game days at the stair's four units a day.
- **Three candidate targets** (P-2101-1): **(a) a 16-cube room in 30–60 s** (about 3 s a cube); (b) about 2 minutes
  (today's dig pace, logistics fixed); (c) the stair's own pace per cube (a 96-cube Kitchen in 30–60 s), which the
  stair's discrete-step floor makes impossible while materials come down the stair.
- **Recommended route to (a):** keep a standing stock in the level-1 store, with the stair runner at the entry's
  time scale (about 10×); batched room digs at a small room time scale (about 1.5–2×); spoil to the foot pile and,
  once 2b-2 lands, up the stair on the runner's return trips. The real-time half depends on the cost lane: today's
  level-1 transitions alone would take about 100 s for 16 cubes per cube-by-cube dig.

## 1. What a room costs today

### 1.1 How it was measured, and what was estimated

**Measured (this study).** A scratch suite, never committed and deleted after the run, in this worktree at
`e0e7065a`. It extended `test/room_heading_case.gd` (decision 1943's coverage fixture: the real room runtime, foreman
and builder, claw rows, station retirement, one mole, M topped up by the fixture) and
`test/test_underground_room_claw_kitchen.gd` (decision 1939: the same Kitchen with every BRACE's inputs hauled from a
staging R on the same level through Delivery's room branch). It timed every `runtime.advance(tick)` with
`Time.get_ticks_usec()` and classed the tick by the builder's stage at its start:

| Stage | What it is | Category below |
|---|---|---|
| IDLE (0) | The foreman plans the next contact and publishes stations | Planning |
| TRAVEL (1), RETREAT (7), COLUMN (9) | Walks to the station, home, and the step between a column's cubes | Walks |
| ENTER (2), RECOVER (5) | The claw entry and recovery clips | Clips |
| START (3), EARN (4) | The paid START tick and the Work ticks (with the hand-over ticks) | Work |
| TO_STORE (11), HAUL (12) | The walk to M and the haul trips | Same-level hauling |

Cache checks off, as production runs (`runtime_cache_checks.gd`). A **heavy tick** is one of 20 ms or more. The real
time at 1x is the sum over ticks of 33.3 ms or the tick's own cost, whichever is larger (REQ-SET-008: no skipped
ticks), that is, **ticks / 30 + the excess of every tick over 33.3 ms.** The machine is the development Mac at a load
average of about 8–10 (the M5 and stair-leg agents were running), so these times are high for this Mac and low for
REQ-SET-163's Ryzen floor. The dig ends before 18:00 on the fixture's clock, so no rest hour falls in it.

**Taken from other records:** the stair round trip, at least **4,425 ticks** (decision 2043 §3; ground walks left out),
and one whole unit a trip (2091 F11); the 7 × 7 room dug its full 4 m, **41,883 ticks** (1943 §4); M5's transition
costs (2082 §3.1) and the cost lane's findings (2082 §3.4, Slice C).

**Estimated, and marked as such:** everything on level 1. Nothing can be measured there yet: a save after about tick
78,000 does not load (P-2045-14, 2091 F10), D2 phase 2 has not bound the way in, and stair-leg Delivery is in phase 1.

### 1.2 The rooms

| Shape | Cubes | Why |
|---|---:|---|
| 2 × 2 cells, floor band | 4 | The smallest room the fixture digs |
| 2 × 2 cells, painted 4 m (the Kitchen fixture) | 16 | The "16-cube room" of 2091 (one column a cell, dug from its floor station) |
| 4 × 4 cells, floor band | 16 | Sixteen cubes with a station each |
| 7 × 7 cells, floor band | 49 | |
| 7 × 7 cells, painted 4 m | 196 | 1943's full-height room (ticks only) |

**Every cube needs** 940 + 1,880 + 1,410 = 4,230 milli-WU (DEC-059, BAL-UG-001), wood 250 and stone 250 milli-U
(ECON, `excavation_contract.gd`), and posts 2,000 milli-U of earth. So **N cubes need ceil(N / 4) whole units of wood
and as many of stone: 2 × ceil(N / 4) trips at one unit a trip**, and 2N U of earth.

### 1.3 The dig, measured (fixture, same level, materials in M)

| Room | Ticks | Planning | Walks | Clips | Work | Heavy ticks | Compute | Excess over 33.3 ms | **Real time at 1x** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 × 2 × 1 (4) | 1,333 | 5 | 832 (62 %) | 272 (20 %) | 224 (17 %) | 27 | 2.90 s | 0.91 s | **45.3 s** |
| 2 × 2 × 4 (16) | 2,845 | 5 | 856 (30 %) | 1,088 (38 %) | 896 (31 %) | 103 | 10.43 s | 3.85 s | **98.7 s** |
| 4 × 4 × 1 (16) | 6,229 | 17 | 4,228 (68 %) | 1,088 (17 %) | 896 (14 %) | 111 | 18.92 s | 9.54 s | **217.2 s** |
| 7 × 7 × 1 (49) | 23,361 | 50 | 17,235 (74 %) | 3,332 (14 %) | 2,744 (12 %) | 342 | 74.68 s | 42.39 s | **821.1 s** |
| 7 × 7 × 4 (196), 1943 | 41,883 | | | | | about 1,200 (est.) | | | about 26 min (est.) |

Arithmetic, for the 16-cube Kitchen: walks = TRAVEL 436 + RETREAT 404 + COLUMN 16; clips = ENTER 480 + RECOVER 608
(30 + 38 a cube); Work = START 48 + EARN 848 (48.3 ticks a cube of Work at 87.6 milli-WU a tick, plus the hand-over
ticks); real time = 2,845 / 30 + 3.85 = 94.8 + 3.8 = 98.7 s. The 196-cube row's real time is 41,883 / 30 = 1,396 s plus
about 1,200 heavy ticks at about 0.15 s, about 140 s of excess. The tick counts of the 4- and 16-cube rooms match
1943's table and 1933's pick Kitchen (2,976) within the claw/pick difference.

- **The painted-height column offer works**: in the 4 m Kitchen the builder walks once a column, so walks are 30 %. In
  a floor band every cube is a new station and a walk out and back, about 264 ticks a cube (4 × 4) to 351 (7 × 7).
- **Claw clips are 68 ticks a cube** (entry 30, recovery 38), not the entry's 83 (2081 §1.3).
- **The steady ticks are cheap but over 2 ms.** In the Kitchen, a Work tick that is not a transition costs 2.5 ms on
  average (2,042 ms over 816 ticks); a walking tick 0.58 ms; a clip tick 0.48 ms. REQ-SET-163 asks for 2 ms at p99.

### 1.4 The cold transitions, measured (the shape Slice C asked about)

Per cube the dig makes **six heavy ticks**: the BRACE, CUT and FINISH STARTs (`3>4`) and their three settlements (the
hand-over is two ticks here, settle `4>3` then START; the last settlement closes the recovery `5>9`). A new station's
publication adds one more (`0>1`, 33–140 ms), once per column in a 4 m room and once per cube in a floor band.

| Room | Heavy ticks | Of which STARTs / hand-over settlements / final settlements / publications | Mean heavy tick | Range |
|---|---:|---|---:|---|
| 2 × 2 × 4 (16) | 103 | 48 / 32 / 16 / 7 | 70 ms | 47–125 ms |
| 7 × 7 × 1 (49) | 342 | 147 / 98 / 49 / 48 | 157 ms | 49–202 ms |

**They grow as the room is dug**: about 50 ms for the first cube, about 80–120 ms by the 16th and 140–200 ms by the
20th to 49th in a large room, as the Space owner's regions and the live graph grow. With the room's own transitions
the dig's real-time excess is 2–5 % of its ticks' time on the fixture.

### 1.5 On level 1 (estimated)

**Materials.** Stair trips at 4,425 ticks each: 4 cubes 2 trips (8,850 ticks); 16 cubes 8 trips (35,400); 49 cubes
26 trips (115,050); 196 cubes 98 trips (433,650). The stair is single-file for a loaded mover (2091 F11), so the trips
are serial: **about four units a game day** if the runner never stops (18,000 / 4,425 = 4.07), about 2.4 on the default
schedule's working hours (06:00–18:00 and 20:00–22:00, 10,500 ticks: estimated).

**The same-level legs.** At level 1 the room's storage is the Foot's store beside F′ (decision 2053 §1, item 3), so the
builder's walk from the store to each station is inside the dig's walks, as on the fixture. A room farther from the
foot walks farther (not estimated).

**Transitions.** Estimated at **0.5–2 s a heavy tick, about 1 s central**, against 47–200 ms on the fixture. Basis: M5's
heavy ticks cost 0.44–1.0 s near the surface and 2.0–4.7 s at landing 4 (2082 §3.1). Roughly half of that is Contacts'
observation of the entry's episodes (2082 §3.4: Contacts 57 % of the transitions' checks, Routes 19 % mostly on
Contacts' behalf), which a room does not run: its provider is `underground_room_world_bindings.gd`. The rest, the
route requalification and the Locations refresh, scales with the flight's published graph, which a level-1 room
inherits. **This is the number most in need of measuring** (P-2101-7's gate).

**Room totals, level 1, one builder, needs held, no rest hour** (the runner model of P-2091-2 (a): the dig overlaps the
hauling, so the room ends with the dig of the four cubes the last two trips fund):

| Room | Stair hauling | Dig | Total ticks | Transitions (excess, central; range) | **Real time at 1x** |
|---|---:|---:|---:|---:|---:|
| 4 cubes | 8,850 | 1,333 | 10,183 | 26 s (13–53 s) | **about 6.1 min** |
| 16 cubes, 4 m | 35,400 | 2,845 | 35,400 + 711 = 36,111 | 100 s (48–203 s) | **about 21.7 min** |
| 16 cubes, floor band | 35,400 | 6,229 | 35,400 + 1,557 = 36,957 | 107 s (52–218 s) | **about 22.3 min** |
| 49 cubes, floor band | 115,050 | 23,361 | 115,050 + 1,907 = 116,957 | 331 s (160–673 s) | **about 70.5 min** |

The excess is the heavy-tick count × (1 s − 0.033 s). If the builder hauls its own units instead (P-2091-2 (b)), the
two add: 38,245 ticks for the 16-cube Kitchen. On the default schedule the hauling part runs about 24 / 14 = 1.7×
longer: about 60,700 ticks for the Kitchen's, **about 34 minutes** in all.

**Spoil.** The room's earth goes to the foot pile (P-2052-2 (a), P-2091-5 (a)) and costs no ticks until it is full.
One ground pile holds about 200 cubes (2042:82-83). If the entry's 100 deep cubes go there too (P-2081-4), about 100
cubes are left: six 16-cube rooms, two 49-cube floor bands, one GDD-minimum Dormitory (48 cubes at 4 m), and no
Kitchen (96). Then 2b-2's earth carry at 5 U a trip (P-2042-2) adds ceil(2N / 5) trips: 2, 7 and 20 trips for 4, 16
and 49 cubes, **8,850, 30,975 and 88,500 ticks**, about as much again as the materials.

**Rest.** Any dig that meets SOCIAL (18:00–20:00, 1,500 ticks, 50 s) or SLEEP (22:00–06:00, 6,000 ticks, 200 s) waits it
out between phases (ADR 1226; 1933). A 2,845-tick dig started at a random time meets one about (10 + 3.8) / 24 ≈ 57 %
of the time (2081 §2(d)'s formula). Over multi-day hauling the schedule is the 1.7× above.

**Planning** is 5–50 ticks a room and one heavy publication tick a station: small in ticks, about 7–14 % of the heavy
ticks.

### 1.6 On the surface level (level 0)

A room dug on the stores' own level (a Mound room, or any room whose staging is on its level) hauls over same-level
legs only. Measured: **the 16-cube claw Kitchen with all eight trips hauled from R: 4,727 ticks, 108 heavy ticks,
12.65 s of compute, 4.55 s excess: 162.1 s.** The eight trips added 1,882 ticks (TO_STORE 424, HAUL 1,016, and 442 more
TRAVEL), **about 235 ticks a trip** over the fixture's few metres from R to M. The haul's ticks are cheap (0.6–1 ms);
its lift and set-down run Delivery's final proof (about 3.5 ms, decision 1935).

| Room | Ticks | Real time at 1x |
|---|---:|---:|
| 4 cubes | 1,333 + 2 × 235 = 1,803 (est.) | about 61 s (est.) |
| 16 cubes, 4 m | **4,727 (measured)** | **162 s (measured)** |
| 16 cubes, floor band | 6,229 + 1,882 = 8,111 (est.) | about 281 s (est.) |
| 49 cubes, floor band | 23,361 + 26 × 235 = 29,471 (est.) | about 17.1 min (est.) |

Real village distances from the stores are longer than the fixture's; each 235 grows with the walk. Surface spoil goes
to a pile on the same level (Mound rooms: the heap's earth, decision 2001's rulings).

### 1.7 Real rooms are bigger than the fixtures

The GDD minimum floor areas (`room_catalog.gd`, 1943 §4) at the painted 4 m: Dormitory and Infirmary 12 cells (48
cubes), Pantry 16 (64), Kitchen and Bedroom 24 (96), Dining and Common room 32 (128). On level 1 their bills are 24, 32,
48 and 64 stair trips: **106,200 to 283,200 ticks (59 minutes to 2.6 hours at 1x)** of hauling, 6–16 game days at four
units a day. Digging the 96-cube Kitchen takes about 96 × 214 ≈ 20,500 ticks (the 7 × 7 × 4 room's rate; estimated).

## 2. What target is sensible

The stair is 154 cubes and 36 installs in 30–60 s: **0.2–0.4 s a cube.** Its batched build needs a time scale of about
10 (2081 (g)). Three candidates, each stated as working time at 1x with the room's materials already in its level's
store and the cold transitions included:

| Target | 4 cubes | 16 cubes | 49 cubes | 96-cube Kitchen | Rate | What it asks |
|---|---:|---:|---:|---:|---:|---|
| **(a) Brisk: 16 cubes in 30–60 s** | 10–15 s | **30–60 s** | 1.5–3 min | 3–6 min | about 3 s a cube | Batching or stage 2 for real time; a room time scale of about 1.5–2 (batched) or 2–5 (per cube); a stair runner at about 10× to keep up |
| (b) Dig pace: 16 cubes in about 2 min | about 45 s | 1.5–3.5 min | about 13 min | about 11 min | DEC-059's rates | Logistics and real time only; no room time scale |
| (c) Stair pace: the 96-cube Kitchen in 30–60 s | about 2 s | 5–10 s | 15–30 s | **30–60 s** | 0.3–0.6 s a cube | A room time scale of about 10–20 on batched digs, and materials faster than the stair can carry them |

**Why (a).**
- **It is the stair's own number for the first thing a player builds below it.** A 16-cube room as long as the whole
  stair keeps digging visible as work (about 3 s a cube), while the player's first real room (48–128 cubes) is a
  few minutes at 1x and about a minute at 4x.
- **It is reachable** with batching at a time scale of 1.5–2, or per-cube digs at 2–5, both under the k ≈ 10 the entry
  already uses (§3).
- **(c) cannot be fed by the stair.** A 96-cube Kitchen's 48 trips in 1,350 ticks is 28 ticks a trip, but one trip is
  113 legs (54 loaded down, 59 empty up; 2091 F3), at least 113 ticks at any time scale (2081 §1.6's discrete-step
  floor). (c) needs the materials somewhere else first.
- **(b) leaves the GDD rooms at 10–15 minutes each at 1x** even with the stair's hauling solved. It is the cheapest in
  rules.

**Keeping (a) fed.** At about 3 s a cube a player who digs continuously uses half a unit a cube: one trip every
5.6 s, 168 ticks. The stair runner at 4,425 ticks a trip supplies one cube every 74 s. A standing stock covers the first
rooms; to keep up the runner needs a time scale of about 26 for continuous digging, or about 10 for digging about
40 % of the time (one trip every 443 ticks, 40 units a game day). §3 option 9.

## 3. Options, costed

Costed on the 16-cube 4 m room (the Kitchen fixture) at level 1, from §1.5's 36,111 ticks and about 100 s of
transitions (about 21.7 min); against target (a), 900–1,800 ticks and 30–60 s. The other sizes follow in §3.2.

### 3.1 Each option alone

| # | Option | Ticks (16 cubes, level 1) | Real time | Meets (a)? |
|---|---|---:|---:|---|
| 0 | Today | 36,111 | about 21.7 min | No |
| 1 | Room time scale k on the room crew only (Work as a rate, clips and edges `ceil(base / k)`, as P-2082-5) | 35,400 + 2,845 / (4k): hauling unchanged | about 21 min | No: haul-bound |
| 2 | Batched room digs (2082's design: one block a column or a floor-band row, two transitions a block) | Dig about 2,029 (est.: clips 4 × 68, walks 856, Work 896, about 5 planning); hauling unchanged | about 21 min | No: haul-bound |
| 3 | A standing stock in the level-1 store, kept by the stair runner | Dig only: 2,845 | 95 s + about 100 s = **about 3.3 min** | No; and sustained digging is capped at about 16 cubes a game day |
| 4 | Up to 4 builders (BUILD-REQ-012) | 2 m room: 1.5× **slower** measured (4,475 against 2,976, 1933); large rooms 1.0–0.5× (unmeasured); hauling unchanged | about 21 min | No |
| 5 | A wider or a second stair | Hauling ÷ 2 at best: 17,700 + 711 | about 12 min | No; one access per World (P-1936-1 (a), 2052 F11), and a two-lane flight is new geometry and passing rules |
| 6 | Cheaper bills: bracing per cell, not per cube (÷ 4 in a 4 m room) | 2 trips: 8,850 + 2,845 | about 8 min | No |
| 7 | Spoil kept underground | 0 ticks now (already ruled); avoids 2b-2's 30,975 once the pile is full | — | Needed, not enough |
| 8 | The cost lane's expected gains | Ticks unchanged | Transitions: about 100 s → about 1–2 s with stage 2 adopted; about 85–90 s with the Routes owner pass and Fix D alone (est.) | No: ticks unchanged |
| 9 | The stair runner at a time scale k_r (new; DEC-050's pace amended for the runner, as P-2081-2 does for the entry crew) | 8 × 4,425 / k_r: k_r = 10 gives 3,540 + 711 | about 2.4 min + transitions | No alone; it is what keeps (3) supplied |

### 3.2 Combinations

| Combination | 16 cubes, 4 m | 16 cubes, floor band | 49 cubes, floor band | Level-1 real time (16 cubes, 4 m) |
|---|---:|---:|---:|---:|
| (3) + (1), k = 2 | 1,423 ticks | k = 4.6 for 1,350 | k = 5.7 for 4,130 (§2's 138 s) | 47 s + 100 s (today) = **2.5 min**; with stage 2 **about 48 s** |
| **(3) + (2) + (1), k ≈ 1.5** | **1,353 ticks** (2,029 / 1.5) | about 2,224 (est.) / 1.6 | about 5,675 (est.) / 1.4 | **45 s + 12 transitions × about 1 s = about 57 s today; about 46 s after the cost lane** |
| (3) + (9), k_r = 10, keeping it fed | standing stock refilled at 40 units a game day | | | |
| (7) + combined runner trips (option in P-2101-5) | spoil costs no extra trip | | | |

Arithmetic for the batched estimates (marked as such):
- **16 cubes, 4 m:** four blocks, one per column; clips 4 × 68 = 272, walks 856 (the column offer already walks once a
  column), Work 896, planning 5: **2,029**. Heavy ticks: 4 × 2 + about 4 publications = **about 12**.
- **16 cubes, floor band:** four blocks of a row; walks 4 × 264 = 1,056, clips 272, Work 896: **about 2,224**.
- **49 cubes, floor band:** seven blocks of a row; walks 7 × 351 = 2,457, clips 7 × 68 = 476, Work 2,744: **about
  5,675**; about 21 heavy ticks.
- **Per-cube k:** 2,845 / 1,350 = 2.1; 6,229 / 1,350 = 4.6; 23,361 / 4,130 = 5.7.

On the surface the transitions are already small (3.8–42 s of excess, §1.3), so **(1) alone at k ≈ 2 meets (a) for the
16-cube 4 m room on the surface today** (47 s + 3.8 s), but not for floor bands (k 4.6–5.7 is a time-lapse) nor on
level 1 (the transitions).

### 3.3 Each option's effect on performance, ledger and feel

| # | Performance (2 ms tick; `Space.MAX_CHECKS` 1,048,576) | Ledger and economy (DEC-059, BAL) | Feel |
|---|---|---|---|
| 1 Room time scale | Same per-tick cost; the same 103 heavy ticks in 1/k the ticks (one every 14 ticks at k = 2). Per-operation spend unchanged (fixture peaks 397,380–568,792). Playback scale in Routes (Slice C's file) | As a rate (P-2082-5) the milli-WU ledger is exact. A room column in BAL-UG-001; DEC-059 P3 and the clip timings amended for room crews; BAL §8's labor probes rerun | k ≤ 2 reads as brisk; k ≥ 5 is a time-lapse in a 1x world |
| 2 Batching | Heavy ticks ÷ 8 (103 → about 12). A block's commit stages its cubes (2082: staging 47 cubes took 75 ms; a 48-cube commit peaked at 51 % of the bound). Room blocks of 4–7 cubes should fit; measured first | Per-Site history as M5's (2082 §1.6); ECON-002's phases committed per block; BUILD-REQ-012's "one by one" order kept as the drawn order (P-2082-6) | The earth goes in M5's order with the earned Work, at most one block ahead; nothing walks a cube before its commit |
| 3 Standing stock | The runner's admission 75k–220k checks a trip (4–16 ms, 2091 §3) and its way check once a run; no per-room cost | DEC-061 and REQ-SET-124/125 unchanged: nothing is deducted at Confirm; units move store to store and are consumed at START. The level-1 store's capacity is the existing ground staging's (no new number) | Natural: a cellar kept stocked; "Waiting for wood and stone" only when it runs short |
| 4 Builders | More live stations and edges (Kitchen 20, 7 × 7 42, against retirement's 35 + a chain), footprint checks; concurrent transitions invalidate stage 2's speculation (1953 §7) | ECON-001 as is | More moles digging reads well; in small rooms they take turns (P-1933-3 (a)) |
| 5 Stairs | A second flight doubles the foot's published edges (2091: +100–120k a requalification each) | P-1936-1 (a) and 2052 F11 amended; a second stair's bill | A second stair is the player's choice later (slice F); a two-lane stair is new content |
| 6 Bills | None | BAL-ROOM-001's cell bill (wood 1,000, stone 1,000 a 4 m cell) and the BRACE rule change; a wood and stone sink shrinks; BAL §8 rerun. DEC-059 kept bills on purpose | Less logistics play; cheaper deep rooms |
| 7 Spoil underground | Pile capacity in the census; combined trips publish 2b-2's loaded ascent rows (estimated about +100–120k at the foot, as 2091 estimates for the descent's) | ECON-003/004 capacity unchanged | Piles grow beside the foot; a runner that never climbs empty looks purposeful |
| 8 Cost lane | Every option's real time; stage 2 adds a second cold lease (about 1 MB, 1953 §7) | None | — |
| 9 Runner time scale | A trip every 443 ticks at k_r = 10: one 4–16 ms admission and two 9–13 ms transfers each; below 33 ms, so no real-time excess; over 2 ms on those ticks, as today | DEC-050 and its laden addendum amended for the runner; no bill change; hauling labor falls | One mole running the stair at the entry crew's scale; consistent with the stair being "fast" |

## 4. Dependencies

| Dependency | State | What it gates here |
|---|---|---|
| **The cost lane** (P-2082-1 (a), "Cost lane first"): Contacts' memo (P-2045-15, M5 lane) → Routes (Slice C: owner pass once per compile window, 24.2 → 8.6 s over 2082's 184 transitions, about −85 ms a transition) → Fix D (Locations memo, about 4.5 s over the flight, Slice C after M5) → phase-spreading stage 2 reopened (P-1953-2) | In progress | Level-1 room transitions. Contacts' memo mostly helps the entry's Work ticks (`worker_refusal` 121.7 s), not rooms. Stage 2 (5–15 ms an adopted transition) is the one gain that takes per-cube room digs under (a) on level 1; with several digs at once it falls back |
| **The batched build** (2082) | Paused behind the cost lane | Option 2 reuses its block START and COMMIT (`excavation_sites.gd`, `underground_space_authority.gd`, Slice C's) and its gate. Room batching follows the entry's |
| **Stair-leg Delivery** (2091) | Phase 1 building; phases 2–5 wait for M5's merge and P-2045-14 | Options 3 and 9 amend P-2091-2 (a)'s runner (a standing stock as well as confirmed rooms' bills) and P-2091-8 (a) (today's rates) |
| **D2 phase 2** | In progress | The way in bound at the foot, the store's grip stand and CARRY span (P-2091-7 (a)): needed before any level-1 room can be measured |
| **2b-2, the earth carry** (2042) | After stair-leg Delivery (P-2091-5 (a)) | Option 7's combined trips; the foot pile fills after about 100 room cubes |
| **P-2045-14** (Space owner load) | M5 lane | Every level-1 measurement starts from a loadable save after tick 78,000 |

## 5. For Slice C (phase-spreading stage 2)

- **A room dig's cold shape:** six heavy ticks a cube (three STARTs, three settlements) plus one publication a station:
  103 in a 16-cube 4 m room, 342 in a 49-cube floor band (§1.4).
- **Costs on the fixture:** 47–202 ms each, growing with the dug cubes; 70 ms mean in the Kitchen, 157 ms in the 7 × 7.
  Estimated 0.5–2 s each on level 1 (§1.5).
- **One room, one builder** is stage 2's favourable case (one active transition). Up to four builders a room
  (BUILD-REQ-012) and several rooms at once (multi-heading, decision 1943) are its fallback case.
- **Batching (option 2) cuts the count about eightfold**, so stage 2 and batching are alternatives for rooms at target
  (a): either alone gets a 16-cube level-1 room under about 15 s of transitions (12 × about 1 s; or 103 × 5–15 ms).

## 6. Proposals

The recommendations together give: target (a); a standing level-1 stock kept by a runner at the entry's scale; batched
room digs at a small room time scale; spoil carried up on the runner's way back; one builder by default; nothing built
before the cost lane re-measures.

**P-2101-1 — The room target. Brendan sets the number.**
- **(a) A 16-cube room ready in 30–60 s at 1x, larger rooms in proportion (about 3 s a cube: a 96-cube Kitchen in 3–6
  minutes).**
- (b) A 16-cube room in about 2 minutes: today's dig rates (DEC-059); only the hauling and the real time fixed. The
  GDD rooms take 10–15 minutes each.
- (c) The stair's pace per cube: a 96-cube Kitchen in 30–60 s. The stair cannot carry its materials that fast (§2).

**Recommendation: (a).** One room about as long as the whole stair; reachable with time scales below the entry's.

**P-2101-2 — What the target counts.**
- **(a) Working time at 1x from Confirm, with the room's materials in its level's store, cold transitions included.
  Rooms keep the schedule: a dig meeting a rest hour waits it out, as today.**
- (b) Wall-clock time from Confirm, including stocking and rest hours.
- (c) As (a), but a started room digs through rest hours, as the stair does (P-2081-5 (a)).

**Recommendation: (a).** Rooms are the colony's ordinary work; the stair's exemption was for a one-off build.

**P-2101-3 — How level-1 materials keep up.**
- **(a) The stair runner keeps a standing stock in the level-1 store (at least one GDD-minimum room's bill, 24 + 24
  units) from the moment the way in binds, and runs the stair at the entry's time scale (about 10×: 443 ticks a trip,
  40 units a game day). DEC-050's pace is amended for the runner, as P-2081-2 amends it for the entry crew.**
- (b) A standing stock at today's pace: the first rooms are quick, then digging waits about a game day per 16 cubes.
- (c) Cheaper room bills (bracing per cell, a quarter of today's stair trips in a 4 m room): BAL-ROOM-001 and the BRACE
  rule change.

**Recommendation: (a).** Without it, every target is set by the stair's four units a day, not the dig.

**P-2101-4 — How the dig reaches the target.**
- **(a) Batched room digs (one block per column or floor-band row, 2082's design and gate) at one room time scale k,
  a Work rate as P-2082-5, set by measurement (about 1.5–2).**
- (b) Per-cube digs at a room time scale (about 2–5); on level 1 they wait for phase-spreading stage 2.
- (c) A room time scale alone now: the 4 m room on the surface meets (a) at k ≈ 2; floor bands and level 1 do not.

**Recommendation: (a),** after the cost lane: twelve transitions instead of 103 fit (a) at today's estimated level-1 cost.

**P-2101-5 — Spoil.**
- **(a) The foot pile now, as ruled; when 2b-2 lands, the runner carries earth up on its way back (5 U a trip covers 2.5
  cubes, more than the 2 cubes a trip down supplies), and a second level-1 pile is drafted before the first fills.**
- (b) 2b-2 as a separate earth hauler: about 31,000 more ticks of stair work per 16 cubes at today's pace.
- (c) More piles only, no carry: the run-out's floor room is unproved and it only postpones the problem (P-2091-5).

**Recommendation: (a).**

**P-2101-6 — Crew size.**
- **(a) The player's 1–4 builders (C3, P-1990-4 (a)) unchanged; the target is met with one; parallel faces are
  measured on a 7 × 7 room before anything counts on them.**
- (b) Two builders by default on rooms over 16 cubes.
- (c) Four by default.

**Recommendation: (a).** Two builders were slower in a 2 m room (1933); large rooms are unmeasured.

**P-2101-7 — The order of work.**
- **(a) No runtime change now. After the cost lane, and once P-2045-14 and D2 phase 2 land, measure one level-1 room's
  transitions (the gate: a 16-cube room's heavy ticks under about 15 s of real time, a third of the target, as 2082's
  gate). Then a room-pace lane (2102–2109) writes the DEC for P-2101-1/-3/-4 and builds it.**
- (b) Ship the room time scale on surface rooms now, before the cost lane.
- (c) Wait until the batched entry build has landed.

**Recommendation: (a).** Level 1's transition cost is the one unmeasured number every option rests on.

## Gates

Docs only: `python3 docs/validation/decision_numbers.py` passes. No runtime, data or test file changed. The scratch
suites (`test_zz_rpace_probe.gd`, `test_zz_rpace_haul.gd`) ran once (`./tools/run_tests.sh --suite`: 13 tests,
0 failures) and were deleted with the import cache and their log; every figure used is in §1.

## Source

- Brendan's ruling of 2026-10-21 ("Start room-pace study now") and P-2081-1 to -9, as relayed by the coordinator.
- Decisions 1933, 1935, 1939, 1943, 1953, 2001, 2042, 2043 (§3), 2045 (P-2045-14, -15), 2052, 2053, 2081, 2082 and
  2091; Slice C's Routes cost findings (2026-10-21, relayed).
- DEC-050 and its addendum, DEC-059, DEC-061 (`docs/setting_decisions.md`); BAL-UG-001, BAL-ROOM-001
  (`docs/gameplay_balance.md`); REQ-SET-002, -003, -008, -034, -163 (`docs/game_gdd.md`); BUILD-REQ-012, -019
  (`docs/building_model_amendment.md`).
- This study's measurement: master `e0e7065a`, the scratch suites above, 2026-10-21.
