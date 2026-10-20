# 2081 — Entry pacing study: what a 30–60 second full-level stair would take (stopped for rulings)

Date: 2026-10-20 · Status: **Proposed.** A docs-only study. No code, data or test is changed. It waits on Brendan's
rulings P-2081-1 to P-2081-9 below.

Number: **2081**, from the range 2081–2089 the coordinator gave this study. It was checked free on every local and
remote ref (`git for-each-ref refs/heads refs/remotes`, then `git ls-tree` of each ref's `docs/decisions/`); 2051, 2052
and 2061 are used on other branches. `python3 docs/validation/decision_numbers.py` passes. Branch
`docs/entry-pacing-study`, from origin/master `d41269dd`.

## The ruling being studied

Brendan, 2026-10-20, relayed by the coordinator, superseding P-2052-8 (decision 2052): **"Building the stair should
be ~30s–1m"**. He confirmed the reading: **the whole full-level stair, from Confirm until level 1 is open, takes
30–60 real seconds at 1x game speed.** He asked for options before anything changes: **"Study options first"**.

At 1x the game runs 30 ticks a second (REQ-SET-002), so the target is **900–1,800 ticks**, midpoint 1,350.

## In short

- **Today the M5 stair takes 92,559 ticks** to reach level 1 (about 51 minutes at 1x) in M5's own measured run, with
  the crew's needs held full. That is **51 to 103 times** the target. Real play would take longer still: the earth
  carry is not active yet (it adds at least 70,800 ticks by DEC-050's paces), and a crew that really sleeps adds
  about 31,000 more, or stalls for good today (decision 2061).
- **Nearly half the time is walking.** Walks and climbs take 52.8 %. Cube work in the claw takes 21.9 % (only 8.0 %
  is the Work itself). Treads and installs take 10.5 %, hauls 9.9 % and rest waits 4.6 %.
- **Four floors rule out a 30–60 s build at today's rates, whatever the crew does:**
  1. **One walk down the finished stair takes about 2,100 ticks at DEC-050's pace**, more than the whole target.
  2. **The Work alone is 10,373 ticks** at DEC-059's amounts. Four builders would still need 2,593.
  3. **Each cube costs 83 ticks of claw entry and recovery** clips (12,813 in all), which no DEC sets.
  4. **The cold operations do not cost ticks, but they cost real seconds.** The game does not skip ticks at 1x
     (REQ-SET-008), so each synchronous transition lengthens the build in real time. Measured here: the first
     67,863 ticks (to landing 3) took 996 s of computation; 4,563 ticks took 20 ms or more and add up to 880 s
     (88 %), and 497 took 0.5 s or more (the longest 3.8 s). **For the whole flight the transitions alone come to
     an estimated 25 minutes of real time on this Mac**, 25–50 times the target, however fast the ticks between
     them run.
- **Options (c), no crew hauls, and (d), no rest pauses, are needed but small.** Together they save about 24,000
  ticks and leave about 68,400.
- **Option (b), more crews, does not help on a two-cell trench.** Builders take turns on the footprint (decision 1933
  measured two builders *slower* than one), and more live faces add requalification edges where WorldRoutes and
  Locations already exceed `Space.MAX_CHECKS` at landings 3 and 4.
- **Option (e), a fast-forward of the entry alone, is not honest under the GDD and cannot run.** It gives the crew a
  different clock from everyone else's (REQ-SET-002, -003, -008). It would also put about 69 entry ticks and about 0.6
  cold transitions into every world tick.
- **Option (a) as briefed is not enough.** Scaling only DEC-059's Work and DEC-050's stair pace still leaves about
  43,000 ticks after (c) and (d). Only a time scale on **every** duration of the entry crew's work and motion
  reaches the target. Kept per cube, that scale must be **38–76×**, the crew looks like a time-lapse, and the build
  still has about 760 cold transitions.
- **The one design that can fit is new: a batched build (g).** Keep M5's geometry, bill and final state, but have
  the crew work in a few long episodes, about one dig and one fitting episode per module. Committed in tens of
  transitions instead of about 760, it needs a time scale of about **8–16×**. Its transitions' real time is the
  open risk: at today's cost per transition it fits only with about 10–20 commits, or with phase-spreading stage 2.
  **Recommended, with (c), (d), one crew and no fast-forward.** M5 finishes as briefed, as the exact reference, and
  the batched build is a new lane after M5 merges.

## 1. Where the ticks go

### 1.1 How it was measured

Two runs of the same chain: `underground_host_case.gd`'s `_begin_live_entry`, held by `_sustain` (needs refilled
every 20 ticks, R's staged wood and stone topped up), on the default schedule. Because the needs stay above 9,000,
the SLEEP hours resolve to ANYTHING (`schedule.gd`, the GDD §5.3 sleep exception), so only the SOCIAL hours
18:00–20:00 forbid work.

- **M5's own tally (the coordinator, 2026-10-20).** `origin/feat/slice-d-m5-full` at `786d8974`, decision 2045's
  "Third build phase", with the check bound lifted so the chain reaches level 1, and the scratch tally
  `scratchpad/m5r/kinds.py` (`k1.log`). Each tick is classed by the crew's stage at the end of the tick, and by
  whether the worker moved. **This record uses these numbers for the breakdown.**
- **This study's own run.** The M5 branch at `2ed939f6`, in a scratch clone (never committed), with today's bound. A
  scratch suite classed each tick by the foreman's, installer's and hauler's stage at its start, labelled each walk
  by what preceded and followed it, and timed every `run_tick` with `Time.get_ticks_usec()`. It runs the same ticks
  as the M5 lane's measurements: plans at ticks 1, 2,233, 3,362, 34,927, 50,012 and 65,010. Like M5's bounded run,
  it stops at landing 3 (tick 67,863, `SPACE_COMPANION_PREPARATION_REFUSED`). It supplies the fastening per module,
  the haul climbs and the wall-clock times, which the tally does not separate.
- **Estimated, and marked as such:** modules 3 and 4 where only this study's run gives the split; the earth carry
  (inactive until 2b-2); and real sleep.

### 1.2 By window (M5's tally)

| Window | Ticks | What it holds |
|---|---:|---|
| Confirm to first installs | 3,360 | Walk to H; L0 (4 cubes) and T0 (2 cubes) |
| Module 0 | 31,565 | The top metre of rows 3–26 (48 cubes); T1–T6 |
| Landing 1 + module 1 | 15,085 | 40 deep cubes; T0′–T6′ |
| Landing 2 + module 2 | 14,998 | 30 deep cubes; seven installs |
| Landing 3 + module 3 | 13,126 | 20 deep cubes; seven installs |
| Landing 4 + module 4 + level 1 | 14,425 | 10 deep cubes; seven installs |
| **Total** | **92,559** | 154 cubes (462 phases), 36 installs; 3,085 s, **51.4 min at 1x** |

Module 0 is the longest because its 48 top-metre cubes are each reached from M on the surface: this study's run
measured 14,260 ticks of walks to those stations, about 297 a cube.

### 1.3 By kind (M5's tally, with this study's split of three rows)

| Kind | Ticks | Share | Note |
|---|---:|---:|---|
| Walks and climbs, moving | 41,328 | 44.7 % | Walks to stations, the installer's legs, climbs to haul and back |
| Walks and climbs, standing (turns, leg ends, route waits) | 7,499 | 8.1 % | |
| Cube work in WORK | 7,439 | 8.0 % | Brace 1,645, cut 3,282, finish 2,512: 651,420 mWU at 87.6 mWU a tick |
| Cube work, entering WORK | 4,804 | 5.2 % | 31.2 a cube |
| Cube work, recovering to READY | 8,009 | 8.7 % | 52.0 a cube |
| Treads and installs | 9,684 | 10.5 % | Of which fastening 2,934 (measured here: L0 317, T0 119, T1–T6 390, then 527 a module of 45,840 mWU) and handling, entry and recovery about 6,750 (152 an install) |
| Hauls, walking | 6,622 | 7.2 % | One unit a trip (DEC-050 addendum) |
| Hauls, lift and set down | 2,502 | 2.7 % | |
| Rest waits (2,966 at haul stands, 1,298 at X) | 4,264 | 4.6 % | SOCIAL hours only, because needs are held |
| Planning stalls | 408 | 0.4 % | |
| **Total** | **92,559** | 100 % | |

**Requalification costs no ticks.** Each cold operation (a phase START or settlement, an installation, a block's
publication) runs inside one tick. It costs real time instead (§1.5).

**Haul-related walking, from this study's run.** Each deep stage climbs once from its landing to X before its hauls
and walks back after them: 1,244 ticks at landing 1, 1,917 at landing 2 and 2,326 at landing 3. Module 0's walks back
from its twelve hauls take 2,499. Landing 4 is estimated at about 2,800. Together with the hauls themselves, about
**19,900 ticks (21.5 %) exist only because the crew hauls** (estimated: 9,124 measured plus about 10,800).

### 1.4 What the measurement leaves out (estimates)

- **The earth carry (2b-2, decision 2042).** The 100 deep cubes make 200 U of earth, 5 U a trip (P-2042-2 (a)). That
  is 16, 12, 8 and 4 trips from landings 1–4. The round trip from landing j by 2041 §2.3's paces (30 a step, 45 a
  half-turn, 90 a handoff, 180 down and 225 up a landing; ground walks left out) is 885, 1,770, 2,655 and 3,540
  ticks. Total at least 16 × 885 + 12 × 1,770 + 8 × 2,655 + 4 × 3,540 = **70,800 ticks**.
- **Real needs.** Over 92,559 ticks (5.1 days) a crew that sleeps 22:00–06:00 loses about 6,000 ticks a day, so
  about **31,000 more**. Today a crew with no rested relief never resumes at all (decision 2061).
- **So in real play** the full flight would take about 92,559 + 70,800 + 31,000 ≈ **194,000 ticks, about 1.8 hours
  at 1x**, once 2b-2 and 2061's fix land.

### 1.5 Wall-clock: the cold operations

The game never skips ticks at 1x; it pauses rather than fall behind by more than 0.25 s (REQ-SET-008). A tick that
takes longer than 33 ms therefore makes the build longer in real seconds. This study's run timed every tick, with
the cache checks off as production runs:

| Measure (ticks 1–67,863: modules 0–2 and landing 3's start) | Value |
|---|---:|
| Computation, all ticks | 996 s (14.7 ms a tick on average) |
| Ticks of 20 ms or more | 4,563, together **880 s (88 %)** |
| Ticks of 100 ms or more | 618 |
| Ticks of 500 ms or more | **497** |
| Longest tick | 3,783 ms |
| Every other tick | 1.83 ms on average (116 s over 63,300 ticks) |
| Computation by window | module 0: 230 s; landing 1 + module 1: 329 s; landing 2 + module 2: 397 s |
| By kind (where the transitions fall) | cube work 559 s (5,939 ticks, the phase settlements and STARTs); installs 167 s; claw entry and recovery 230 s; walks 23 s (0.84 ms a tick); hauls 14 s |

**How many transitions.** About 760 for the whole flight (estimated: a cube's START, two hand-overs and a
settlement, 4 × 154 = 616; about three for each of 36 installations, 108; and the floor blocks' publications). The
run's 618 ticks of 100 ms or more over 73 % of the flight agree with that order.

**What this means for the target.** At 1x the build's real time is at least the sum, over its ticks, of 33.3 ms or
the tick's own cost, whichever is larger. For these 67,863 ticks: 2,262 s of clock plus about 728 s of overrun, about
50 minutes instead of 38. For the whole flight, modules 3 and 4 estimated at about 350–400 s each, the computation is
about 1,700 s, of which about 1,500 s (**about 25 minutes**) is transitions. **Any option that keeps M5's about 760
per-cube transitions takes at least about 25 minutes of real time on this machine, however few ticks it has.**

A cache-checks-on run (`run1.log`, as the suites run) took 1,956 s for the same ticks, 1,839 s of it in ticks of
20 ms or more.

Decision 1953 measured the entry's START and settlement stalls at 0.4–0.65 s each before M5. Phase-spreading stage
2, the work that would move them out of the tick, waits for M5 ("After M5, re-measure", P-1953-2). The machine is
an Apple Silicon Mac, faster than REQ-SET-163's Ryzen 5 3600 floor, so these times are lower bounds for that floor.

### 1.6 Floors at today's rates

| Floor | Arithmetic | Ticks | Against 1,800 |
|---|---|---:|---|
| One walk down the finished stair (DEC-050) | Laden: 90 + 40 × 30 + 90 + 4 × 180 (2041 §2.3, 2043 §3) | **2,100** | Over by itself |
| The Work (DEC-059 P3) | 7,439 cube Work + 2,934 fastening, both measured (651,420 + 261,200 mWU at about 87–88 mWU a tick) | **10,373** | 5.8× over; 2,593 with four builders |
| Claw clips per cube (DEC-059 P2: one entry and one recovery a cube) | 154 × 83.2 | **12,813** | 7.1× over |
| Install clips (handling, entry, recovery) | 36 × about 152 (measured on T1–T6) | **about 6,750** | 3.8× over |
| Discrete steps | Every motion edge and clip lasts at least one tick; this study's run changed stage 993 times in 67,863 ticks, about 1,350 over the whole flight, and each stage holds one or more edges | **≥ about 1,350** | A floor even at an infinite time scale, for per-cube choreography |

## 2. The options, costed

Each option is costed from the measured 92,559 ticks (one crew, needs held), against 900–1,800.

### Summary

| Option | Ticks (estimate where marked) | Meets 900–1,800? | Rulings it amends | Cold operations | M5 in flight |
|---|---:|---|---|---|---|
| (a) As briefed: DEC-059 Work and DEC-050 stair pace scaled, entry only | ≥ about 67,000 alone; ≥ about 43,000 with (c)+(d), at any factor | No | DEC-059 P3, DEC-050, BAL-UG-001 | Unchanged (about 760), concentrated | Data successors only |
| (a′) Widened: one time scale k on every entry duration (work, clips, walks, stair) | 92,559 / k; k = 51–103, or 38–76 after (c)+(d) | Only at k ≥ 38, and not in real seconds (§1.5) | As (a), plus every clip's timing | Unchanged, one every 1–2 ticks | Survives; a Routes and clip playback scale is new code in Slice C's files |
| (b) N crews on parallel faces | Ideal 92,559 / 4 = 23,140; measured precedent about 1× | No | P-1936-2-style crew rule for the entry; P-1933-3 (b) | More live edges: over the bound | The entry foreman is single-crew; a multi-crew foreman is new |
| (c) No crew hauls; spoil to an underground pile | About 72,700 (and avoids the +70,800 earth carry) | No | DEC-061's paying rule untouched if haulers stock M | Unchanged | Haul code idle on the entry path |
| (d) No rest-hour pauses | 88,295 (−4,264); in real play also −31,000 sleep | No | ADR 1226 and REQ-SET-034 for the entry crew; DEC-059 shift change | Unchanged | P-2045-10's waits unused; the rest-wait test needs its own schedule |
| (e) Fast-forward of the entry only | 92,559 entry ticks inside about 1,350 world ticks | Not honest; cannot run | REQ-SET-002, -003, -008 | About 0.6 a world tick | Survives; a new clock |
| (c)+(d) | About 68,400 | No | (c)'s and (d)'s | Unchanged | As (c), (d) |
| **(g) Batched build + (c) + (d) + time scale about 8–16×** | **Designed to about 1,350** | **Yes, if its commits fit** | DEC-059, DEC-050 and clip timings for the entry; ECON-002 phases batched for the entry; DEC-060 extended | **Tens**, each to be measured against the bound | The per-cube foreman plan is replaced; most of M5 survives |

### (a) Entry-only faster rates: DEC-059 Work and DEC-050 pace

- **Ticks.** Work is 10,373 ticks and the stair motion is at most about 15,000 (estimated: the installer's stair legs
  and the climbs; the module-0 walks are on the ground). Even at an infinite factor this leaves at least about
  **67,000 ticks**, or about 43,000 with (c) and (d). The clips and the ground walks are not DEC-050 numbers.
- **To reach the target the scale must cover every duration (a′).** One time scale k: 92,559 / k ≤ 1,800 needs
  k ≥ 51.4, and ≤ 900 needs k ≥ 102.8. After (c) and (d), about 68,400 / k needs k = 38–76. Above k ≈ 30 a stair
  edge (30 ticks) becomes one tick, so the discrete-step floor (§1.6) takes over.
- **Docs and rulings.** A new DEC amending DEC-059 P3 (work × 0.47) and DEC-050 (30 ticks a tread) for entry
  episodes only (the Frontier's EPISODE and INSTALL rows, ADR 1202 and 1209); BAL-UG-001 gains an entry column. (a′)
  also amends the qualified clip timings (ADR 1217 step 5's claw loops, ADR 1229's handling) for the entry crew.
- **Performance.** The per-tick work of moving one mole stays about the same; the number of cold transitions stays
  about 760. Compressed into about 1,350 ticks that is **one every 1.8 ticks**, each still a synchronous stall
  (§1.5): the frame budget fails continuously, and the build's real time is the stalls' sum, about 25 minutes
  today, not 45 s. The check
  bound is unaffected per operation (the same operations), and still unmet at landings 3 and 4 (WorldRoutes 1.09 M and
  1.40 M, Locations 1.11–1.15 M, M5's tally).
- **M5.** Survives. (a) is a create-only bundle successor of the work amounts (as `qualified-stairs-v9` did for
  DEC-059) and pace rows. (a′) also needs a playback scale in Routes (Slice C's file) and re-pinned tick constants
  (`DONE_TICK`, the whole-flight ticks, the rest-wait test).
- **Feel.** At k ≈ 50 the crew visibly runs at 50× speed: a time-lapse inside a 1x world. Rooms keep their pace, so
  a 16-cube room (decision 1933: 2,976 ticks, 99 s with one builder) takes about twice as long as the 154-cube
  stair: about **20× slower a cube** (186 ticks against 9).

### (b) A bigger crew

- **What is allowed.** BUILD-REQ-012 allows up to 4 builders on a room's parallel faces "as ECON-001 allows"; the
  entry has no crew rule beyond one crew and its replacement (ADR 1225, DEC-059's shift change). P-1936-2 gives rooms
  one builder now, the player's choice of 1–4 since C3.
- **Ticks.** Ideal 92,559 / 4 = **23,140**: 13–26× over. Measured precedent: decision 1933's two builders in a 2 m
  room took **4,475 ticks against 2,976 for one**, because a builder's footprint is its whole way there, its station
  and its way back (P-1933-3 (a)), and in 2 m the footprints always meet. M5's trench is two cells wide and every
  crew's way runs down the same flight, so footprints meet there too: **about 1×, or worse**. Parallel work needs
  P-1933-3 (b), exact per-tick occupancy, which was not chosen.
- **The check bound.** Each crew needs its own block of published floor walks (P-2045-5 (a)'s two-row blocks: landing
  2's first block 864,051 checks). Two or more live blocks add edges to every requalification where M5 is already at
  91.8–92.5 % (landing 1 and 2) and over the bound at landings 3 and 4. The bound is not to be raised (P-2044-15). One
  cold lease serves the whole underground (decision 1953 §2), so crews also queue for their transitions.
- **M5.** The entry foreman, installer and hauler run one crew; a multi-crew foreman is new work in M5's files.
- **Feel.** More moles on the stair reads well, but they would mostly stand and wait.

### (c) Pre-staged materials: no crew hauls

- **Ticks.** About 19,900 haul-related ticks go (estimated, §1.3): **about 72,700** remain. The +70,800 of the
  earth carry is avoided if deep spoil goes to an underground pile instead of up the stair.
- **Who moves the stock.** The bill is wood 77,500 and stone 38,500 milli-U (2043 §3), 116 whole units at one a
  trip. DEC-061 keeps "hauled, used when work starts", so either the village's haulers keep M stocked while the crew
  digs (today a labelled stand-in, as P-2052-7 (a) moves stock into R; HAUL-H3+ later), or the bill leaves the stores
  at Confirm, which Brendan declined for building in general ("don't deduct at confirm, keep as we currently do").
  The current runtime already pays a deep brace from M's stock without carrying it down, so stocking M is enough.
- **Spoil.** P-2042-4 (a) already rules "underground piles first". 100 deep cubes are 200 U; one ground pile holds
  about 200 cubes (decision 2052 §F), so the foot pile of P-2052-2 holds them with room to spare. Haulers can carry
  it up later, off the build's clock.
- **Performance.** No change per operation; fewer haul routes are prepared.
- **M5.** The hauler and `_haul_or_climb` stay for rooms and as the fallback when M is empty; on the entry they idle.
  Stair-leg Delivery (1941 §2) leaves the entry's critical path; it stays needed for level-1 rooms (2052 F3).
- **Feel.** Natural: the builders build and the haulers haul.

### (d) No rest-hour pauses for a first-entry crew

- **Ticks.** −4,264 measured (SOCIAL only, needs held): **88,295**. In real play also the sleep hours (about −31,000)
  and decision 2061's stall.
- **At the target's scale it matters differently.** A 1,800-tick build is 2.4 game hours. The SOCIAL window is 2 h
  (1,500 ticks, 50 s at 1x) and SLEEP 8 h (6,000 ticks, 200 s). A Confirm at a uniformly random time meets a no-work
  hour about (10 + 2.4) / 24 ≈ **half the time**, so without (d) about half of all builds would take 50–200 s more.
  Needs barely move in 2.4 hours (rest −900, hunger −600), so no shift change is needed.
- **Docs and rulings.** A DEC exempting a started stair build from schedule pauses, amending ADR 1226 (rest at safe
  points) and REQ-SET-034's schedule change for the entry crew; DEC-059's shift change stays as the safety net.
- **M5.** P-2045-10's waits stay in the code for rooms; `test_underground_m5_rest_wait.gd`, which relies on a rest
  hour near tick 45,414, needs its own schedule (or a test that the exemption holds).

### (e) Exact and paced simulation, but the player sees a short build

Three readings, none honest under the GDD or runnable:

1. **The entry runs extra ticks per world tick** (about 92,559 / 1,350 ≈ 69). The crew's Work, Routes and schedule
   would run on a different clock from its own needs and from every other resident: REQ-SET-002 (one authoritative 30
   ticks a second) and REQ-SET-003 (speed changes run more ticks "without changing per-tick rules") forbid it, and
   occupancy and route proofs between the crew and other residents would compare different times.
   **Performance:** this study measured the entry chain's ordinary ticks at 1.83 ms each, so 69 of them is
   about 126 ms in one world tick, before about 0.6 cold transitions a tick. Far over 2 ms and 16.67 ms.
2. **The whole world fast-forwards until the stair is done.** Honest (one clock), but it is a speed outside
   PAUSED/1/2/4 (AGENTS.md's non-negotiables), and 92,559 ticks in 45 s is 2,057 ticks a second, 69× speed, against a
   measured 14.7 ms average tick for the entry alone.
3. **The way shows open while the crew is still building.** The UI would state something the simulation does not
   hold. The GDD's line "Anonymous presentation does not mean disposable simulation" (§1) and the UI's rule of showing
   actual entry conditions instead of invented ones (`ui_ux_controls.md`, UI-SET-049 under HAZ-005) both point the
   other way. What *is* honest is already ruled: BUILD-REQ-013 lets the player paint and confirm level-1 rooms
   reached only through the drafted stair, and their digging waits.

**Judgement: not honest under the GDD.** Not proposed.

### (f) Combinations

| Combination | Ticks | Notes |
|---|---:|---|
| (c) + (d) | about 68,400 | The base every faster option needs |
| (c) + (d) + (a) as briefed | ≥ about 43,000 | Work and stair motion gone; clips and walks left |
| (c) + (d) + (a′) | 68,400 / k; k = 38 (1,800) to 76 (900) | Per-cube; the discrete-step floor and about 760 transitions remain |
| (c) + (d) + (b) ideal + (a′) | 17,100 / k; k = 9.5–19 | Needs four parallel crews, which the trench and the bound refuse |
| **(c) + (d) + (g) + time scale** | **about 14,059 / k; k = 7.8 (1,800), 10.4 (1,350), 15.6 (900)** | Below |

### (g) A batched build (not in the brief; found by the floors)

The floors in §1.6 come from M5's choreography: one claw cycle a cube, one walk a station, one transition a phase.
A build that keeps M5's **geometry, bill, proofs and final state**, but changes how the crew's work is divided, can
reach the target with a moderate time scale.

- **Shape.** The crew walks to H, then for each module: one dig episode at the module's work spot (the module's cubes,
  committed as a few blocks), one walk down the new module, one fitting episode (the module's seven installs). The
  materials come from a stocked M (c); spoil goes to the foot pile; no schedule pause (d). Precedent: DEC-060 already
  lets treads be fitted "with a general paw working motion" without exact contact, and DEC-061 asks to match EG2,
  whose stairs are an item built by workers on a timer.
- **Budget at today's rates** (k = 1): walk to H 366 (ADR 1229); Work 7,436 + 2,982 = 10,418 (DEC-059 amounts at
  87.6 mWU a tick); clips 5 × 83 + 5 × 152 = 1,175; one walk down 2,100 (DEC-050). **Total 14,059.** One time scale on
  all of it gives k = 14,059 / 1,800 = **7.8**, / 1,350 = **10.4**, / 900 = **15.6**. The mix can differ (for example
  Work × 1/20 and motion × 5), as long as the sum lands in the window.
- **Cold operations.** Tens instead of about 760, but each is large: today's transitions of 0.5 s or more average up to
  1.8 s (§1.5). Forty commits at that cost would take the whole 60 s, so **the real-time budget, not the tick budget,
  decides the batch size**: about 10–20 commits at today's cost, or phase-spreading stage 2 (decision 1953 §7, which
  estimates 5–15 ms an adopted transition). A module's 10–48 cubes in one commit is unmeasured and may not fit
  `Space.MAX_CHECKS` (module 0's sill installation alone is 91.8 %), and fewer, bigger commits push against that
  bound. The lane's first step measures the largest commit and the stalls' real-time sum, and stops if either does
  not fit (the bound, and about 15 s of stalls).
- **Docs and rulings.** A new DEC: the entry's work is batched, its pace is set by one entry time scale, the crew does
  not haul or pause. It amends for the entry only DEC-059 (P2's per-cube cycle and P3's amounts), DEC-050, the clip
  timings, ECON-002's per-quantum phases (the cubes are still braced and cut, but committed per block), ADR 1226's
  pauses and ADR 1202/1209's episode order; BAL-UG-001 gains the entry rows. SET-BUILD-001 §9 records it.
- **M5.** Kept: the M5 geometry and bundle, the bindings, Locations and WorldRoutes fixes, the stair path and R′, the
  landings, the Frontier and its byte bound, save v4. Replaced: the foreman's per-cube plan (a Frontier successor with
  block episodes, and a block foreman). M5's per-cube chain stays as the qualified reference suite.
- **Feel.** A crew working at about 10× for 45 seconds, with the stair growing module by module, reads as a
  construction sequence rather than a dig. Rooms still dig per cube at their own pace (P-2081-8).

## 3. Proposals

Each is one choice. The recommendations together give the batched build, (g) + (c) + (d), with one crew.

**P-2081-1 — How the stair gets to 30–60 seconds.**
- **(a) Batched build: M5's geometry and final state, built in a few long episodes per module at one entry time
  scale (about 10×), committed in measured blocks.**
- (b) Keep M5's per-cube choreography and scale every entry duration by about 38–76×. It stays above the target in
  real seconds until the cold transitions leave the tick (phase-spreading stage 2).
- (c) Keep M5's pace (about 51 min, or about 38 min with (c) and (d)) and set a different target.

**Recommendation: (a).** It is the only option whose arithmetic reaches 900–1,800 ticks. The per-cube options keep
about 760 transitions, about 25 minutes of real time today; the batched build's tens of transitions are measured
first, and if they cannot fit about 15 s the lane stops and phase-spreading stage 2 comes first.

**P-2081-2 — Where the speed comes from.**
- **(a) One entry time scale on everything the entry crew does (Work, clips, walks, stair), set so the build lands
  near 45 s; rooms and other residents unchanged.**
- (b) Only DEC-059's Work and DEC-050's stair pace: the clips and walks stay at today's timings, which alone are
  1,541 ticks of the batched budget, so it lands at the target's edge (about 55–60 s).
- (c) Only the Work amounts: the walk down alone (2,100 ticks) exceeds the target.

**Recommendation: (a).**

**P-2081-3 — Materials.**
- **(a) The crew never hauls. The village's haulers keep M stocked (the labelled stand-in now, as P-2052-7 (a); HAUL-H3+
  later). If M runs dry the build waits and says so.**
- (b) The stair's bill leaves the stores at Confirm (DEC-061's paying rule changed for the stair only).
- (c) The crew hauls as today: 116 trips, which cannot fit.

**Recommendation: (a).**

**P-2081-4 — Spoil from the deep cuts.**
- **(a) Onto the foot's ground pile (P-2042-4 (a), P-2052-2); haulers carry it up later, off the build's clock.**
- (b) Carried up the stair during the build: at least 70,800 ticks at DEC-050's paces.
- (c) Removed at Confirm without a carry (breaks ECON's real spoil).

**Recommendation: (a).**

**P-2081-5 — Rest hours.**
- **(a) A started stair build runs to the end through rest and sleep hours; DEC-059's shift change stays as the
  safety net.**
- (b) It pauses as today: about half of all builds would take 50–200 s longer.
- (c) Confirm any time, but the crew starts only in a work hour.

**Recommendation: (a).**

**P-2081-6 — Crew size.**
- **(a) One crew, as today.**
- (b) Up to 4 on parallel faces: they take turns on a two-cell trench, and more live edges exceed the check bound.
- (c) Two.

**Recommendation: (a).**

**P-2081-7 — A fast-forward or a shown-early way.**
- **(a) Neither: no entry-only clock, no world skip, no "open" before it is open.**
- (b) A labelled world-wide "skip until built" (a new speed; 69× is not runnable).
- (c) Show the stair as built while the crew finishes.

**Recommendation: (a).** Painting level 1 before the stair is built is already allowed (BUILD-REQ-013).

**P-2081-8 — Rooms.**
- **(a) Entry only now. Rooms keep DEC-059's rates; a room-pace study follows D2, when rooms are first dug for
  real.**
- (b) Give room digs the same time scale now.
- (c) Entry only, for good.

**Recommendation: (a).** A 16-cube room would otherwise take about twice as long as the whole stair; that gap should be
judged on real level-1 rooms.

**P-2081-9 — M5 and the order of work.**
- **(a) M5 finishes as briefed (exact, today's pace) and merges as the qualified reference; the batched build is a new
  lane on M5's files after it merges; D2 carries on meanwhile.**
- (b) Stop M5 now and redirect it to the batched build.
- (c) Merge M5 at landing 2 and leave modules 3–4 to the batched lane.

**Recommendation: (a).** Everything in M5 except the per-cube plan carries into (g), and its chain is the reference
the batched build is checked against.

## 4. Sequencing

1. **M5 (decision 2045, `feat/slice-d-m5-full`)** keeps going as briefed. Nothing here changes its files. Its open
   items stay: the check bound at landings 3 and 4, the census pass, the gates, the frames. Its tick constants and
   `test_underground_m5_rest_wait.gd` are today's pace; a later pace lane re-pins them (the rest-wait test then needs
   its own schedule, P-2081-5).
2. **D2 (decision 2052, phase 1 in 2053)** carries on in its own files. P-2052-8 is already ruled so that D2 assumes
   no build duration; nothing here changes that.
3. **This ruling**, then the **fast-entry lane** (range 2082–2089 or the coordinator's next), after M5 merges:
   1. measure first: the largest block commit against `Space.MAX_CHECKS` and the stalls' real-time sum, on M5's
      mount; stop and report if the sum cannot fit about 15 s;
   2. the entry-only DEC (P-2081-1, -2, -5) and BAL-UG-001 rows;
   3. the Frontier successor with block episodes, the block foreman, the stocked-M wait, the foot pile;
   4. the whole-flight suites shrink with the build (good for decision 1244's CI split, and for D2's checkpoint
      recipes, which take tens of minutes today).
4. **Stair-leg Delivery (1941 §2)** and **2b-2 (the earth carry)** leave the entry's critical path under P-2081-3 (a)
   and P-2081-4 (a). Both are still needed: stair-leg Delivery for level-1 rooms' materials (2052 F3), the earth carry
   to clear the foot pile.
5. **Phase-spreading stage 2** (decision 1953) stays "After M5, re-measure". It is a prerequisite for every
   per-cube option (about 25 minutes of transitions today) and the fallback for (g) if its commits' real time does
   not fit.

## Source

- Brendan's ruling of 2026-10-20 as relayed by the coordinator (`docs/handoff/LIVE_WORK_SLICE_D.md`, untracked) and
  decision 2052's rulings.
- M5's tally: decision 2045 "Third build phase", `origin/feat/slice-d-m5-full` at `786d8974`, relayed by the
  coordinator 2026-10-20.
- This study's run: `feat/slice-d-m5-full` at `2ed939f6`, a scratch clone and a scratch suite, never committed;
  logs `scratchpad/pace_tools/run1.log` (cache checks on) and `run2.log` (off).
- DEC-050 and its addendum, DEC-059, DEC-060, DEC-061 (`docs/setting_decisions.md`); BAL-UG-001
  (`docs/gameplay_balance.md`); REQ-SET-002, -003, -008, -034, -163 (`docs/game_gdd.md`); BUILD-REQ-012, -013, -019
  (`docs/building_model_amendment.md`).
- Decisions 1202, 1209, 1229 (§ Build time), 1933, 1936, 1941, 1953, 1981, 2041 (§2.3), 2042, 2043 (§3), 2044
  (P-2044-15), 2045, 2052, 2061 and 1244.
