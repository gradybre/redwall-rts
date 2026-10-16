# 2041 — Slice D-flight scoping: an earth/timber flight down a full level, stopped for rulings

Date: 2026-10-16 · Status: Accepted. Brendan ruled every PROPOSAL, P-DF-1 to P-DF-9, the recommended option on
2026-10-16 (see "Brendan's rulings"). The scoping itself (sections 1–7) changed no code and no data; phase 2a
follows under this record and decisions 2042–2043.

Number range: 2041–2049, allocated to the D-flight lane by the slice D coordinator (session `dbd322db`). This is the
lane record; later records of the lane take 2042 onwards. The numbers were checked free on every local and remote ref
and with `decision_numbers.py`. Branch `docs/slice-d-flight`, from origin/master `c11da82e`.

## Brendan's rulings (2026-10-16)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion. Every ruling is the recommended option.

| Proposal | Ruling | What it means |
|---|---|---|
| P-DF-1 | **(b)**, "Build F40, probe 1:3.2" | F40 (128/512, 40 steps) is built with qualified motion only. The 160 u gait is probed offline; no 160 u authoring before Brendan sees the probe |
| P-DF-2 | **(a)**, "Approve all" | Straight, 2 × 23 cells |
| P-DF-3 | **(a)**, "Approve all" | Open to the sky (or to the clear space of the Passage or Mound room); 142 cubes |
| P-DF-4 | **(a)**, "Approve all" | D3 / DEC-059 per tread, long-post treads included; T0's and L0's bills; §7.2 per cube. F40 = wood 78,500, stone 35,500, 858,980 milli-WU, earth out 284,000 milli-U |
| P-DF-5 | **(a)**, "Moles now" | Qualified for the claw crew; every other species' way to level 1 stays open MOVE-G01/G04 work |
| P-DF-6 | **(a)**, "Approve all" | Rotation 0 only. D1's Stair-head placeholder becomes F40's 2 × 23 cells at rotation 0 (the D1 lane has been told) |
| P-DF-7 | **(a)**, "Qualify an earth carry" | One basic earth carry, level and stair, before the deep layers are cut: decision 2042 |
| P-DF-8 | **(a)**, "Approve all" | Bench down by plateau; per-plateau Frontiers (c) if the Frontier byte bound is met |
| P-DF-9 | **(a)**, "Approve all" | DEC-050's 1 s per step for any later 160 u tread |

Indexed in `docs/handoff/RULINGS.md`.

### Pending SET-BUILD-001 §9 amendment (for the phase 2b lane to apply)

§9's Stair-head row (line 314) says "a full 5120 u level needs 40 treads over 20480 u". Under P-DF-2 (a) the derived
figures are: **40 steps, 39 treads (T0–T37 and the sill T38), 39 × 512 = 19,968 u of treads, and 23 rows (23,552 u)
including L0's 2,048 u and the 1,536 u run-out.** The row should also name F40 as the qualified first entrance
(rotation 0 only, P-DF-6) and give its bill (P-DF-4). This record does not edit §9: the phase 2b lane applies it with
the runtime, so the contract and the code change together.

## The question

Brendan ruled OPEN-10 (a) on 2026-10-11 ([decision 1851](1851-painted-room-contracts.md) lines 138–141 and 174). The
ruling: qualify a steeper earth/timber flight that takes the first entrance down a full level, 5,120 u to level 1's
floor, with "the 20 m flight" as the fallback. That fallback is ADR 1209's 128 u rise per 512 u run, repeated.
[SET-BUILD-001](../building_model_amendment.md) §9 (line 314) records the same ruling.

Today the only qualified flight has six treads. It ends 1,024 u down. Nothing reaches level 1.

This record scopes seven things: geometry, motion, the bill, reuse between levels, the bottom of the flight, the file
plan and the fallback.

## Decision (as proposed)

**The premise holds only weakly, and this record says so plainly.**

- **No meaningfully steeper earth/timber flight is open to the mole.**
  - **A steeper rise was refused.** A 256 u rise (1:2) was attempted, and the mole's leg cannot reach the step
    (`DESCENT_LEG_REACH_FRAME_28`, ADR 1209 line 25).
  - **A shorter run breaks the tread station.** The station from which each tread is fitted needs about 499 u of
    tread (F3).
  - **Only one rise is left.** The only whole-number rise between 128 and 256 u that divides 5,120 exactly is
    **160 u (1:3.2)**.
  - **What 160 u buys.** It saves 4 of 23 cells of length and 17 % of each haul trip.
  - **What 160 u costs.** Every stair motion would be re-authored and re-proved, 21 or more rows would be added, and
    the flight could never fold: a 160 u flight lands on the 1 m cube grid only at its 32nd step.
- **Recommendation: build the fallback first, using only qualified motion.** That is the 40-step flight at 128/512,
  laid straight (F40): 2 × 23 cells, 39 treads, 142 cut cubes. It needs **no new motion and no new Profiles rows**.
  Its only new geometry is two longer tread posts. The 160 u gait is meanwhile probed offline, so Brendan can decide
  with evidence whether it is worth a full qualification.
- **Three findings change slice D's plan** (F2, F7 and F8):
  - **F2.** No painted room can be dug at the 1 m flight's floor.
  - **F7.** Earth has no certified carry, so the flight's 96 deep cubes have nowhere legal to put their spoil.
  - **F8.** Only the mole has any stair motion, so no flight, steep or shallow, serves every species today.

## 1. Findings (origin/master `c11da82e` unless stated)

**F1. Where level 1 is, and where the first flight ends.**

- **The datum and the land.** The level pack's datum is y 512 (`godot/data/underground/initial_level_pack.json`
  `datum_u`). Land is at world y 512 (`world_init.gd:244` `LAND_Y_UNITS`, `:902–908`). The entry origin is the
  surveyed ground point; the tests use y 512 (`test_underground_host.gd:561`). The entry places it at rotation 0
  (`underground_entry_site.gd:78`).
- **The source frame.** Source-local y 0 is world 512.
- **Level 1.** `underground_level_catalog.gd:267–271` puts level 1's floor at 512 − 5,120 = **world −4,608 u**,
  which is source −5,120. The clear space is world −4,608..−512. The protected roof band is −512..512: **the top
  metre of ground below the land.**
- **The first flight.** Its trench floor is source −1,024, which is world −512 (`tread_geometry.gd:16–21`, ADR 1209).
  So the whole first-entry trench lies inside level 1's roof band.
- **Any entrance pierces the band.** A flight from the land must pass through the band. SET-BUILD-001 §3 says
  nothing about connectors and the band. This record treats the flight's footprint as its opening, as the structure
  catalog's single OPENING region already does for the stair top (ADR 1209).

**F2. No painted Room can be admitted at the 1 m floor.**

- **The rule.** `underground_room_bindings.gd:308–320` `_level_refusal` admits a Room only on a level with a roof,
  and only at one of that level's section floors. Level 0 has no roof and refuses any offset
  (`underground_level_catalog.gd:264–266, 290`). Level 1's section floors are world −5,632, −4,608 and −3,584
  (offsets −1,024, 0, +1,024: pack `section_offsets_u`).
- **The 1 m floor matches none of them.** Its world y is −512. So a "Kitchen-level" room (decision 1972, Phase 2e,
  activation branch line 659) is refused `ROOM_AUTHORED_LEVEL_REQUIRED` (`underground_room_bindings.gd:34`).
- **Consequence.** The activation lane's floor end makes the stair carry real, but **no room dig can be ordered in
  the game until a flight reaches a level-1 floor.** The admission's +1,024 section, world −3,584, is 32 steps
  down. Using it would break BUILD-REQ-018's single floor per level, so it is not proposed.

**F3. The qualified flight and its motion.**

- **The geometry** (`tread_geometry.gd:16–33`).
  - T_k is T0 translated by (0, −128k, −512k).
  - Stops sit 169 u (A), 310 u (S) and 343 u (U) behind each deck's far edge.
  - There are seven parts per assembly. The T6 sill's bearers are cut to 64 u (D1).
- **The bodies.**
  - The trench is x ±1,024 (two cubes wide).
  - The run-out is 1,536 u past the sill: D2's seventh row, end wall at z −7,168.
  - At F′ the all-yaw carry body clears the sill by 7 u ([decision 1981](1981-one-basic-stair-carry-scoping.md)
    line 98).
- **Rise.** 128 u is the only authored rise. The 256 u descent refused at frame 28 (ADR 1209 line 25).
- **Run.** The tread station was derived from the ready body's own vertices. The back vertex lies 188.4 u behind the
  root, and the station window was 297–323 u (ADR 1209 line 221).
  - So the riser must lie at least 310 + 188.4 = 498.4 u behind the far edge.
  - A run below about 499 u cannot hold the station that fits the next tread.
  - The side-on station already failed on 512 u (feet 568.68 u apart, line 406).
  - **512 u is effectively the minimum run.**
- **Pace.** DEC-050 gives 30 ticks a tread and 45 a half-turn; the addendum adds 90 per three-step laden handoff. The
  publisher's edge lengths are 528 u per tread and 174 u per turn (`publish_qualified_stairs.py:72–73`).
  - **The pace is source-specific.** DEC-050 "assigns no timing to … other connector types".
- **Rows are exact-heading.**
  - **Content 12.** Its loaded rows exist at yaw 0 (approach, descent, turn, back-up) and yaw 32,768 (ascent,
    retreat) only (decision 1981 lines 503 and 535). The claw stair rows 51–55 likewise
    (`underground_stair_motion.gd:100–101`).
  - **Rotation.** The first entry is always placed at rotation 0 (`underground_entry_site.gd:78`).
  - **Consequence.** A flight descending in any other direction has no rows.

**F4. Capacities that a 40-step flight meets.**

| Owner | Bound | 1 m flight | F40 (estimate) |
|---|---|---|---|
| `underground_connector_catalog.gd:17` `MAX_PARTS` | 256 | 52 parts (L0 + T0–T5 at 7, sill 3) | 7 + 38 × 7 + 3 = **276: over** |
| `underground_entry_frontier.gd:28` `MAX_BYTES` | 28,597 B | v10's Frontier is 6,836 B (14 cubes, 8 installs) | 142 cubes and 40 installs: very likely over; measure |
| `underground_routes.gd:53` `MAX_EDGES` / `:56` `MAX_LOCATIONS` | 1,536 / 1,024 | tens | about 290 edges, about 130 stops: inside |
| `room_space.gd:10` `MAX_CHECKS` per preparation | 1,048,576 | content 10: 1,038,133 (99.0 %); content 12: 1,067,179, **over** (1972 M-2) | unknown; depends on cost-2's incremental proofs |
| `underground_entry_contact_retirement_scope.gd:25` `ENDPOINTS` | 44 (49 in v10) | — | grows by about 3 per tread |
| `underground_stair_motion.gd:29–31` programs and keys | 5 / 457 | — | **unchanged at 128/512**: rows are root-relative |

**F5. The pricing method reproduces the measured ledger.**

- **The method.** Each cut cube is priced at SET-BUILD-001 §7.2: wood 250, stone 250, 4,230 milli-WU (DEC-059),
  2,000 milli-U earth (`excavation_contract.gd:9–16`). The fixtures take ADR 1209 D3 and DEC-059 P3:
  - L0: wood 4,000, 32,000 milli-WU;
  - T0: wood 1,000, 12,000 milli-WU;
  - T1–T6: wood 1,000 and 5,640 milli-WU each.
- **The check on the 1 m flight.** 14 cubes × 4,230 = **59,220**; 32,000 + 12,000 + 6 × 5,640 = **77,840**. These
  are exactly the measured ledger `[50, 59,220, 19, 77,840, 8]` (decision 1229 line 469). Every bill below uses the
  same method.

**F6. What a room dig needs at the bottom** (C2.3, decisions [1936](1936-slice-c2-3-scoping-room-dig-composition-save-and-ledger.md) and [1937](1937-room-digs-composed-saved-and-ledgered.md)).

- **The order.** `UndergroundRoomComposer.Order` (`underground_room_composer.gd:26–33`) holds the room, an `access`
  Locations endpoint, a `travel` row, and `storage`, `output` and `staging` containers.
- **One access per World.** The first ordered room binds the access; another access is refused
  `ROOM_DIG_OTHER_ACCESS` (`:21`; P-1936-1 (a)).
- **The seed.** The dig order seeds from live SUPPORTED_VOID regions meeting the room's floor layer within one cube
  of its cells. Otherwise it refuses `ROOM_DIG_ORDER_NO_WAY_IN` (`underground_room_dig_order.gd:15, 54, 90–110`).
- **Staging.** A staging container on another level is refused `ROOM_HAUL_NO_STAIR_CARRY` until the carry legs are
  wired (decision 1935).
- **Nothing calls it yet.** `order_underground_room` (`settlement_system.gd:2046–2059`) is not called in the game,
  and neither is `begin_underground_entry` (`:1967–1979`).

**F7. Earth has no certified carry, and spoil must be placed close by.**

- **Only wood and stone are certified.** `grip_certificate.gd:47–49` (qualified-claw-runtime-v1) certifies "only
  wood and stone". Decision 1931 line 177 records the consequence: `SPOIL_OUTPUT_BLOCKED` once the pile is full.
- **Spoil must go next to the cut.** ECON-003 posts each cut's 2,000 milli-U to capacity that is "adjacent
  reachable … at most one existing 2m plan-tile away through an approved work contact", and "does not authorize
  remote delivery" (`underground_economy_hazard_amendment.md` lines 152–156).
- **The deep cubes have nowhere to go.**
  - A cube in the top metre is cut from a station on the land, and its spoil goes to a land pile, as today.
  - A deeper cube is cut from a floor inside the slot.
  - Its only adjacent capacity is a pile on that floor, which the treads will later occupy.
  - With no earth carry, the pile cannot be moved.

**F8. Only the mole has stair motion.**

- **The data.** `godot/data/underground/` holds motion for `mole-worker` only. Surface residents have no authored
  body ("MOVE-G01 body envelopes are unsupplied", ADR 1219 §1), and only crew moles register underground (ADR 1219).
- **Headroom is not the problem.** DEC-039's tallest species, the badger at 2,611 u, fits any headroom chosen below.
- **Tread depth may be.** Its stance on a 512 u tread is not measured. Scaled from the mole's yaw-0 carry stance,
  444 u deep (z −222..222, decision 1981 line 76), by 2,611 / 922 = 2.83, it is about 1,257 u: more than two treads.
  This is a **scaling estimate, not a measurement**. If real bodies bear it out, a shorter, steeper tread suits the
  badger even less.

**F9. The activation lane** (`feat/activate-content-11-12`, decision 1972, read only at `9c7d6ed5`).

- **What it adds.**
  - Content 12 is mounted.
  - The floor end (A and U on the sill; F, U and F′ on the floor) and 21 CARRY edges are added.
  - The trench floor is retained as natural SUPPORT, 128 u deep (P-1972-7 (a) "Natural earth counts", P-1972-9).
- **What it waits on.** M-2 (the check bound), which waits on cost-2.
- **The files it holds.** Its diff touches every runtime file a longer flight needs: the stair path, entry bindings,
  connector catalog and contacts, Locations, Profiles, the stair motion owner and the bundle publisher (§6).

## 2. Derivations

### 2.1 One rule for every option (no new constants)

- **Trench.** It is a slot two cubes wide (x ±1,024), cut in 1,024 u rows along −Z.
  - **The top landing.** Rows 0–1 are L0's 2,048 u, cut one deep as today.
  - **The treads.** Tread T_k has its deck at z [−2,560 − 512k, −2,048 − 512k], so every tread row holds exactly
    two treads (the sill's row holds one).
  - **The bottom.** The run-out is 1,536 u past the sill's far edge (D2).
- **Floors step.** A row's floor is the least whole number of quanta that keeps every post in the row at least
  64 u long: `q = ceil_div(t_max + 192 + 64, 1024)`.
  - t_max is the deeper tread top in the row. 192 u is the deck plus its bearer.
  - The last tread is the sill, standing on the level floor (D1).
  - Every post bears on retained natural ground 128 u below its floor, as T0's do (ADR 1209).
- **Why F40 needs longer posts.** Every row holds two treads, T_2m and T_2m+1. To keep both posts within T0's
  64–704 u, the floor must lie in [512 + 256m, 1,024 + 256m]. For m = 3 that is [1,280, 1,792], which contains no
  multiple of 1,024. So the straight 40-step flight needs **posts of 832 and 960 u** (two of every eight treads),
  beyond T0's 704. That is derived, not chosen.
- **Headroom: an open slot.** Every row is cut from its floor up to the land. §2.3 shows that a roof barely helps.

### 2.2 Which rises are possible

- **The divisors.** The integer divisors of 5,120 = 2¹⁰ × 5 strictly between 128 and 256 are **160** only.
- **No folding at 160.** A landing must lie on the cube grid: 160k ≡ 0 (mod 1,024) needs k ≡ 0 (mod 32), because
  gcd(160, 1,024) = 32. So a 160 u flight reaches a cube floor only at its 32nd step, the level floor, and **cannot
  have an intermediate landing.** A 128 u flight can land every 8 steps.
- **Edge length.** At 160 u it is ceil(√(160² + 512²)) = 537 u, against 528 u at 128.

### 2.3 Options (computed by the rule above; footprint in 1 m cells)

| Option | Steps / treads | Cells (bounding box) | Cut cubes | Post lengths | New motion rows | Haul round trip |
|---|---|---|---:|---|---|---:|
| Today's 1 m flight | 8 / 7 | 2 × 7 | 14 | 64–704 | — | 885 |
| **F40**, straight, 128/512 | 40 / 39 | **2 × 23** (46) | **142** | 64–960 (adds 832, 960) | **none** | **2,805** |
| D2L, dogleg 16 + 24, one landing | 40 / 38 | 4 × 15 (52) | 152 | 64–960 | the 19 stair rows (51–55, 71–84) turned by 180° (derived, not authored) | 3,210 |
| U5, switchback, 5 lanes of today's module | 40 / 35 | 10 × 7 (70) | 194 | 64–704 (today's) | heading-32,768 rows for lanes 1 and 3 | 4,425 |
| M5, today's module × 5 in a straight line | 40 / 35 | 2 × 27 (54) | 154 | 64–704 | none | 4,425 |
| S160, straight, 160/512 (PROPOSED rise) | 32 / 31 | 2 × 19 (38) | 120 | about 30 distinct, 64–1,184 | all: gaits, turn, steps, fitting, 14 carry rows, floor end | 2,325 |
| S256, straight, 256/512 (refused motion) | 20 / 19 | 2 × 13 (26) | 82 | 64–1,088 | all, with a new gait recipe | 1,605 |

- **The haul round trip** is in ticks: a laden descent plus an empty ascent.
  - The paces are 30 a step and 45 a half-turn (DEC-050), and 90 a handoff (DEC-050 addendum, P-1972-6).
  - A landing between flights adds 180 down (walk-off and approach) and 225 up (retreat, back-up and half-turn).
  - Ground walks are left out, so these are lower bounds.
- **F40's figure.** Down is 90 + 40 × 30 + 90 = 1,380. Up is 90 + 45 + 1,200 + 90 = 1,425. **F40's 2,805 ticks
  are 3.74 game hours a round trip.**
- **The roof band barely helps.** Leaving the earth above the required air gives:
  - at 4,096 u clear (P-1971-3's room height), 140 cubes against 142;
  - at three quanta (3,072 ≥ 2,611 u, the badger), 130 cubes, open for 18 of 23 rows;
  - at the mole's 1,422 u endpoint air (ADR 1219), 100 cubes, 12 open rows, moles only.

### 2.4 The F40 flight, row by row

Rows are 1,024 u along −Z from the stair top. "Depth" is the number of cubes cut per column, counted down from the
land.

| Rows | Holds | Depth | Posts (u) |
|---|---|---:|---|
| 0–1 | L0 deck (top landing) | 1 | L0's own |
| 2–4 | T0–T5 | 1 | 704, 576, 448, 320, 192, 64 |
| 5–8 | T6–T13 | 2 | 960, 832, 704, 576, 448, 320, 192, 64 |
| 9–12 | T14–T21 | 3 | the same cycle |
| 13–16 | T22–T29 | 4 | the same cycle |
| 17–20 | T30–T37 | 5 | the same cycle |
| 21 | T38, the sill (bearers cut to 64 u, D1) | 5 | — |
| 22 | run-out; end wall at z −23,552 | 5 | — |

- **Cubes.** Per column: 2 × 1 + 3 × 1 + 4 × 2 + 4 × 3 + 4 × 4 + 4 × 5 + 5 + 5 = 71. Two columns: **142**.
  - 46 cubes lie in the top metre: one per column on each of the 23 rows.
  - **96 are deeper.**
- **Where the bottom lands.** The sill's far edge is −2,560 − 512 × 38 = −22,016. The floor stops are therefore the
  activation lane's F, U and F′, moved by (0, −4,096, −16,384).

### 2.5 The bill in full (SET-BUILD-001 §9: excavation at §7.2 plus the fixture recipe)

| | F40 (128/512, fallback) | S160 (160/512, steeper) | U5 (switchback, for comparison) |
|---|---:|---:|---:|
| Fixtures: L0 | 4,000 wood · 32,000 milli-WU | the same | the same |
| Fixtures: T0 at T0's bill | 1 × (1,000 · 12,000) | 1 × | 5 × (one per lane: derived reading, P-DF-4) |
| Fixtures: other treads at D3 / DEC-059 | 38 × (1,000 · 5,640) | 30 × | 30 × |
| **Fixtures total** | wood 43,000 · 258,320 milli-WU | wood 35,000 · 213,200 | wood 39,000 · 261,200 |
| Excavation (cubes × 250 / 250 / 4,230 / 2,000) | 142: wood 35,500 · stone 35,500 · 600,660 milli-WU · earth 284,000 | 120: 30,000 · 30,000 · 507,600 · 240,000 | 194: 48,500 · 48,500 · 820,620 · 388,000 |
| **Total** | **wood 78,500 · stone 35,500 · 858,980 milli-WU · earth out 284,000** | **wood 65,000 · stone 30,000 · 720,800 · 240,000** | wood 87,500 · stone 48,500 · 1,081,820 · 388,000 |

Amounts are milli-U for materials and milli-WU for work.

**F40, per piece.**

- **A tread in plateau d** (d = 1..5): 1,000 wood and 5,640 milli-WU, plus d cubes (its half-row): 250d wood, 250d
  stone, 4,230d milli-WU and 2,000d earth.
- **The top landing** (L0 plus rows 0–1): 4,000 wood and 32,000 milli-WU, plus 4 cubes (1,000 wood, 1,000 stone,
  16,920 milli-WU).
- **The bottom landing** (the run-out's half of row 21 and all of row 22): 15 cubes (3,750 wood, 3,750 stone,
  63,450 milli-WU, 30,000 earth).
- **Check.** 4 + 123 (the treads) + 15 = 142.

**Scale.** F40 is 858,980 / 137,060 = **6.3 times** today's whole entry: 59,220 + 77,840 milli-WU of work, with
wood 14,500 and stone 3,500. DEC-059's goal of finishing the entry inside the first work block cannot hold for any
full-level option.

**Hauling per level-1 cell.** A painted underground cell needs 1 wood and 1 stone (§7.2), and the stair carry takes
one unit a trip (DEC-050 addendum). Down F40 that is two round trips, 5,610 ticks, about **7.5 game hours of one
hauler per cell**. For comparison: S160 takes about 6.2 h, and a 4 × 4 room down F40 about 120 hauler-hours. This
is a consequence for balance, not a proposal of this lane.

### 2.6 Reuse between levels (study §5 D, line 178: "the same item family placed on a passage")

- **The same variant one level down.** It is translated by −5,120 u (`room_connectors.gd:35–37` `level_base`,
  `start_floor_u`, `end_floor_u`). The cubes are counted relative to the start floor, so **the bill is identical**:
  142 cubes and the same fixtures.
- **The footprint must be Passage.** On level N the open slot's headroom is level N's own 4,096 u clear space. So
  the flight's whole footprint must lie inside finished Passage cells on level N, 2 × 23 for F40 (BUILD-REQ-016).
  - Those cells become the flight's opening; a walkway past it is more Passage.
  - The Passage itself is paid as a room: 46 × 16,920 = 778,320 milli-WU.
- **Bands and footings line up.** Level N's footing is level N+1's roof band, both 1,024 u
  (`underground_level_catalog.gd:269–271`), and both are pierced only by the footprint. The bearings sit 128 u
  below level N+1's floor, inside its footing. Level 4's footing ends at quantum −21, above the domain minimum −32.
- **Level 4** offers no "down" ("No level below level 4", §9).
- **Rotation.** F40 at rotation 0 needs nothing new. A rotated placement needs heading-rotated rows (F3, P-DF-6).

### 2.7 Inside a painted room (decision 2001, BUILD-MOUND-021)

- **A Mound room behaves as a level-0 Passage.** Its 4,096 u clear space is the slot's headroom, and level 1 is still
  5,120 u below its floor.
- **The room must hold the footprint.** F40 needs a Mound room covering 2 × 23 cells. U5 needs one covering 10 × 7.
- **A typical home cannot.** A typical Mound home cannot hold either, so BUILD-MOUND-021's refusal ("a family whose
  geometry does not fit the room is refused with its reason") will be the usual answer for this family. Only a
  compact family (ladder/hatch or spiral, OPEN-02) fits a home.

### 2.8 What the bottom must publish for C2.3's room digs (D2's needs)

1. **A SUPPORTED_VOID seed.** The run-out's cubes at level 1's floor layer (world y −4,608..−3,584), once finished
   (MOVE-REQ-002). A level-1 room painted against the run-out's end face or sides is then within one cube
   (`underground_room_dig_order.gd:90–110`).
2. **A Locations endpoint.** F′ on the level-1 floor, the one access for `Order.access` (P-1936-1 (a)). It stands on
   natural earth witnessed by its cut cube (P-1972-8).
3. **Routes to the surface.** The 40-step flight's WALK and CARRY edges F′ ↔ H, plus H ↔ M (ADR 1202's contact path).
4. **A Profiles travel row.** The claw walk on the floor, for `Order.travel`, from existing content.
5. **Containers.**
   - **Storage:** M on the surface, reached by the carry legs (C2.3's follow-up under P-1981-4), or a level-1 staging
     store.
   - **Output:** a level-1 ground pile within one plan tile of each cut (F7). One pile holds about 200 cubes
     (decision 1931 line 177), about 50 painted cells.
   - **Staging:** same-level, or refused `ROOM_HAUL_NO_STAIR_CARRY` until the carry legs are wired.

## 3. Motion qualification: what each option needs

| Need | F40 / D2L / U5 (128/512) | S160 (160/512) |
|---|---|---|
| Descent and ascent gaits (53, 54; 74–76, 80–82) | Reused. Re-prove over the new fixture in windows: four post cycles, each plateau step and the bottom. ADR 1209's proof is translation-invariant (4,044 pairs = 6 × 674); the prover's segment and solid capacities rise (as 4 → 8 and 32 → 96 did) | New candidates from the accepted authors at rise 160. Review, native capture and rows |
| Half-turn on T_k (55; 75 / 81) | Reused. Re-prove with the longer posts below the deck | New |
| Step back and forward 141 u (51, 52) | Reused (deck depth unchanged) | Reused only if the deck is unchanged; re-prove |
| Tread fitting (DEC-060 candidate b, rows 64/66) | Reused. Re-check its post superset boxes for 832 and 960 u posts | New candidate for a bearer 32 u lower |
| L0 approach and retreat, H (43/45/47; W1, W5) | Reused at the top | Reused at the top; the first step down is 160 u: re-prove |
| Floor end (F, F′, E1/E2, W6, floor 53–55) | Reused, translated to −5,120. P-1972-9's retention covers the floor's cut set | New: every floor proof re-run on new gaits |
| Landings (D2L, U5, M5 only) | Ground rows on natural floor (all-yaw at F′, decision 1981 line 98); the approach from a natural landing re-proves only its deck (P-1972-7 (a)); D2L and U5 need the heading-32,768 rows | Not possible (§2.2) |
| Deep cutting | Top-face rows 56–62 from a floor beside the cube: the slice-D case of decision 1971 §3, "rows 56–62 serve it unchanged". Stations stand on temporary floors inside the slot (P-DF-7) | The same |
| Profiles rows and policy words | **None new.** Policy words 10–13 exist | About 21 new rows (5 claw, 14 carry, fitting). That grows `PROFILE_BYTES` (already raised once by P-1972-2) and adds to every WorldRoutes per-profile loop, where M-2 already overflows |
| Pace | DEC-050 as ruled (the same tread) | Needs a word (P-DF-9) |
| Every species (DEC-039) | Headroom yes. Motion: mole only (F8) | The same, and a shorter tread suits big bodies worse |
| Paid generation | **None.** Offline authoring and proofs on the mole's existing rig; native capture uses staged demo art (handoff §3.9) | **None** for the mole. An earth load part (P-DF-7) or other species' stair clips might need art: asked separately, never assumed |

## 4. File plan and sequencing

**Held by the activation lane** (from its diff against master; read only).

- `underground_entry_stair_path.gd`: `LEVELS = Tread.TREADS + 1`, `classify` and `edge_plan` are shaped to 6 treads.
- `underground_entry_bindings.gd`: landing and cut-floor retention.
- `underground_connector_catalog.gd`: `MAX_PARTS`.
- `underground_connector_contacts.gd`, `underground_locations.gd`, `underground_profiles.gd`.
- `underground_stair_motion.gd`, `underground_entry_foreman.gd`.
- The publisher `first-entry-prefix-v1/publish_qualified_stairs.py` and `entry_source_constants.py`.
- Claimed besides: `underground_entry_contact_retirement_scope.gd` (`ENDPOINTS`), `underground_route_composition.gd`,
  `underground_session.gd`, `runtime_files.gd`.
- **Every one of these must change for a 40-step flight.** So the runtime half of D-flight waits for the activation
  lane to merge.

**Held by cost-2** (`perf/dig-tick-cost-2`).

- `underground_routes.gd`, `underground_world_routes.gd`, `underground_locations.gd`, `underground_profiles.gd`,
  `underground_connector_contacts.gd` and `underground_connector_delivery.gd`.
- **M-2.** Whether a WorldRoutes preparation's cost grows with the whole flight or only with what changed decides
  whether F40 fits `MAX_CHECKS` at all. M-2 is re-measured after cost-2.

**Can be built before activation merges (new files only; no collision):**

1. **The derivation.** A derivation module and its Python tests under `godot/data/underground/full-level-flight-v1/`
   (new directory): rows, floors, posts, cut set, stops, bills, checked against §2.4–2.5 and against today's flight
   (F5).
2. **The offline proofs.** New scripts under `mole-worker/contact-qualification/` running the accepted provers on F40
   windows:
   - gaits, half-turn and steps over stepped floors and the long posts;
   - tread fitting with the 832/960 u posts;
   - the floor end at −5,120.
   - **These need the demo art staged** (`cp -Rc`, handoff §3.9). This worktree has none.
3. **The 160 u feasibility probe** (if P-DF-1 (b)): the accepted descent and ascent authors run at rise 160. Results
   only: no rows, no review packet.
4. **The earth-carry scoping record** (P-DF-7 (a)), decision 2042.
5. **Godot fixture tests** (new test files, public APIs only) for top-face cuts from temporary slot floors (decision
   1971 rows 56–62 on content 11 as a test fixture, as C2.3 did).

**Must wait for activation, cost-2 or both:**

- **The bundle successor** (create-only `full-level-flight-v1/` with its own publisher; `MAX_PARTS` 276 > 256: two
  variants or a census-admitted raise).
- **A tread-geometry successor** for 39 treads and a post table.
- **The stair path,** generalised to 39 treads plus the floor end.
- **Entry bindings:** retention under stepped floors.
- **The Frontier and foreman** bench sequence, against Frontier `MAX_BYTES`.
- **Retirement endpoints, census, pins and checkpoints.**
- **The M-2 re-measurement.**

## 5. The fallback, if the steeper flight fails (and the recommended first build either way)

**F40 needs:**

- **Geometry.** Two new post lengths (832 and 960 u) on T0-family treads and a stepped trench. Each tread lies wholly
  in one row (§2.1).
- **Proofs.** Re-run with the accepted provers (§3); no motion is authored.
- **Capacities.** Parts, Frontier bytes and endpoints (F4), and the check bound after cost-2.
- **Construction order** (P-DF-8). Cut each plateau top-down, then fit its treads, then walk down them to cut the
  next. The deep spoil needs a destination (P-DF-7).
- **The surface.**
  - **Level 0.** A 2 × 23-cell open slot (46 cells against today's 14), descending toward −Z only (P-DF-6). For
    comparison, a 20 m run is about 20 cells.
  - **Level 1.** The same 46 cells cannot hold rooms: the slot is cut there, or the band above is pierced.
  - **The surface work area** (stations at ±1,430 u along the slot, ADR 1219's 5,222 u resident reach) stretches with
    the slot.
  - **If 23 cells cannot be found,** D2L (4 × 15) or U5 (10 × 7) fold it at the price in §2.3.

## 6. PROPOSALS

**P-DF-1 — The steeper flight (OPEN-10 (a)).**

- (a) Qualify the 160 u rise first, through the full motion pipeline (about 21 rows re-authored and reviewed, native
  capture, a pace word, about 30 post lengths). Build F40 only if it fails.
- **(b) Build F40 now with qualified motion only. Meanwhile, run the accepted gait authors at 160 u offline as a
  feasibility probe (no rows, no review), and bring the result back before any 160 u authoring.**
- (c) Drop the steeper flight: F40 is the entrance (as OPEN-10 (b)).

**Recommendation: (b).** At best the steeper flight saves 4 cells and 17 % of each haul. 1:2 is refused by the
mole's legs.

**P-DF-2 — Layout of the 128/512 flight.**

- **(a) Straight (F40): 2 × 23 cells. No new rows, the fastest haul (2,805 ticks), two new post lengths.**
- (b) Dogleg, 16 + 24 steps with one landing: 4 × 15 cells, 3,210 ticks. It needs the stair rows at heading 32,768.
- (c) Switchback (U5): 10 × 7 cells, four landings, 4,425 ticks (+58 %). It also needs rotated rows.

**Recommendation: (a).**

**P-DF-3 — Headroom over the flight.**

- **(a) Open to the sky, or to the clear space of the Passage or Mound room it stands in. Every species fits;
  142 cubes.**
- (b) Roofed at three quanta (3,072 ≥ the badger's 2,611): 130 cubes, still open for 18 of 23 rows.
- (c) Roofed at the mole's 1,422 u air: 100 cubes, only 12 rows open. Moles only.

**Recommendation: (a).** (b) saves 12 cubes for a second geometry. (c) breaks "rooms must fit every species"
(P-1971-3) for the way in.

**P-DF-4 — The bill.**

- **(a) ADR 1209 D3 and DEC-059 for every tread, long-post ones included (1,000 wood, 5,640 milli-WU); T0's bill
  for each T0 installed from a landing; L0's for L0; §7.2 per cube. F40 = wood 78,500, stone 35,500,
  858,980 milli-WU, earth out 284,000 milli-U.**
- (b) Price long-post treads by timber volume. D3 found no per-volume rule, so this needs a new constant.
- (c) Brendan sets the bills.

**Recommendation: (a).** No new number.

**P-DF-5 — Who the entrance is qualified for.**

- **(a) The claw crew (moles) now. Record every other species' way to level 1 as open MOVE-G01/G04 work (bodies,
  then stair motion per species). Nothing paid is part of this lane.**
- (b) Hold the entrance until all five species are qualified.
- (c) A mole-only stair now, plus a separate every-species family (the ramp) planned under OPEN-02.

**Recommendation: (a).** Until then, other residents cannot use level-1 rooms. That conflicts with no ruling, but
Brendan should know.

**P-DF-6 — Rotation of the full-level flight.**

- **(a) Rotation 0 only (descending toward −Z), as the first entry is placed today. The ghost shows the other
  rotations disabled: "No qualified stair for this direction yet".**
- (b) Derive the 19 stair rows at the other three headings now: 57 rows, `PROFILE_BYTES`, and the M-2 check
  bound.
- (c) Derive heading 32,768 only, enough for P-DF-2 (b)/(c).

**Recommendation: (a).** This touches D1's ghost.

**P-DF-7 — Spoil from the 96 deep cubes (F7).**

- **(a) Qualify one basic earth carry, level and stair, in the spirit of decision 1981, before the deep layers are
  cut. Layer-1 spoil keeps going to land piles. A new earth load part, if no existing one serves, is asked
  separately.**
- (b) Read ECON-003's "one 2m plan-tile away" as plan distance only, so land piles beside the slot take the deep
  spoil. That is Brendan's reading of ECON-003.
- (c) Temporary piles on the slot floor ahead of the dig front, carried out before the treads go in. This needs (a)
  anyway.

**Recommendation: (a).** Level-1 rooms need it too once a pile (about 50 cells) is full.

**P-DF-8 — The order of building (engineering; for the coordinator).**

- **(a) Bench down by plateau.**
  - For each layer, cut from the downhill end upward. Each cube is struck on its top face (rows 56–62) from its uphill
    neighbour's floor, still one layer higher.
  - Then fit that plateau's treads (DEC-060, chained as DEC-059 P1) and walk down them to cut the next plateau.
  - This is a create-only Frontier successor and a foreman extension, with no new motion.
- (b) Cut the whole slot from land stations first. This is not possible below the top metre: no station stands at
  depth without treads.
- (c) Per-plateau Frontiers chained by the foreman. The same work, split to stay inside Frontier `MAX_BYTES`.

**Recommendation: (a)**, falling back to (c) if the Frontier bound is met.

**P-DF-9 — Pace of a 160 u tread (only if P-DF-1 (a), or a later 160 u successor).**

- **(a) DEC-050's "1 second per step": 30 ticks a tread, 45 a half-turn, 90 a handoff, laden too.**
- (b) Scale by edge length: 537 / 528 gives 31 ticks.
- (c) Brendan sets it.

**Recommendation: (a).**

## 7. Phased build plan and gates

**Phase 1: now, docs, data and tests only, new files (after the rulings).**

- **Work.** §4 items 1–5. Stage the demo art first.
- **Gates.**
  - The offline proofs: 0 unresolved, support rows all inside, self-clearance clear, with segment and solid
    capacities recorded.
  - The derivation's Python tests reproduce §2.4–2.5 and today's ledger (F5).
  - `decision_numbers.py`; Godot fixture tests and the analyzer on port 6503 for any new `.gd`.
- **Stop.** Report the proofs and the 160 u probe to Brendan with the measured numbers. Decision 2043 records them.

**Phase 2: after the activation lane and cost-2 merge.**

- **Work.**
  - The bundle successor (create-only) and the tread-geometry successor.
  - The stair path, entry bindings, Frontier and foreman (P-DF-8).
  - Retirement endpoints; the parts capacity (split or raise, with a ledger row through ADR 1212).
  - The M-2 re-measurement on the full flight.
- **Gates.** The full Godot suite; the analyzer (port 6503, 0 warnings); census, pins and `ready07`; checkpoints
  regenerated with saves byte-identical; mutation testing; an independent review; frames at 1280×720 and 1920×1080.
- **The hand-fixture chain, then the live chain.** Both reach level 1 with exact ledgers:
  - 142 Sites and 40 installs;
  - wood 78,500, stone 35,500, 858,980 milli-WU;
  - earth 284,000 placed legally (P-DF-7).
- **Stop** if `MAX_CHECKS` overflows on master after cost-2: report options, raise nothing.

**Phase 3: D2 (decisions 2051–2069 reserved).**

- **Work.** Publish §2.8's five items at the bottom. Bind F′ as the World's access. Order a level-1 room against the
  run-out through `order_underground_room`.
- **Owed by D2.** The game checkpoint recipe (P-1936-4) and the S7 host restore fixture (decision 1937).
- **Gate.** A room seeded from the run-out digs on the live chain.

## Consequences

- **Slice D's plan changes in three places.**
  - No room dig can run in the game before a level-1 floor is reached (F2).
  - The flight's deep cubes need an earth carry or an ECON-003 reading (F7, P-DF-7).
  - The entrance serves moles only until MOVE-G01/G04 give other species bodies and stair motion (F8, P-DF-5).
- **The build is large.** A full-level entrance is about 6.3 times today's entry work. Hauling down it costs about
  7.5 hauler-hours per level-1 cell.
- **D1 is affected.** D1's entrance ghost should offer rotation 0 only for this family (P-DF-6). Its footprint is
  2 × 23 cells, not a 4 × 4 placeholder.
- **SET-BUILD-001 §9's row** ("40 treads over 20480 u") is corrected by this record's derivation: 39 treads, 19,968 u
  of treads, 23 rows including landings. That text is amended when the rulings land, not here.

## Source

- **Brendan's rulings.** OPEN-10 (a) ([decision 1851](1851-painted-room-contracts.md)); DEC-039, DEC-050 (and its
  addendum), DEC-052, DEC-054 (addendum, P-1971-3), DEC-059, DEC-060 and DEC-061 (`docs/setting_decisions.md`);
  P-1972-7 (a).
- **Contracts.** SET-BUILD-001 §3, §7.2, §9 and §12 (BUILD-MOUND-021); SET-MOVE-001 (MOVE-REQ-002/005/012, MOVE-G01
  to G05); SET-MOVE-ECON-001 ECON-003/004.
- **Engineering records.** ADRs 1142, 1202, 1209, 1219 and 1229; decisions 1931, 1935, 1936, 1937, 1971, 1981, 2001;
  decision 1972 and its diff on `feat/activate-content-11-12` at `9c7d6ed5` (read only).
- **The plan.** The Evil Genius 2 study §5 D and its dependency table (line 233).
- **The code.** Every figure in §2 was computed from the files cited in §1 by a scratch script (not committed); §2.4
  and §2.5 show the arithmetic.

## Gates run (this record)

- `python3 docs/validation/decision_numbers.py`: `decision_numbers: PASS -- 565 records, 0 problem(s)`.
- No GDScript, data or contract file changed, so the Godot suite, the analyzer and the census were not run.
