# 2045 — Slice D, the M5 round: the full flight mounted, measured and scoped (stopped for rulings)

Date: 2026-10-19 · Status: Accepted. Phase 1 (measure and scope) stopped for rulings; Brendan ruled P-2045-1 to
P-2045-6, all (a), on 2026-10-19 (see "Brendan's rulings"). The build phase stopped again under that ruling's own
condition: WorldRoutes and Locations still do not fit (see "Build phase"; P-2045-7 to P-2045-10 wait for rulings).

Number range: 2045–2049 (the D-flight lane's phase 2b). This is the M5 round's record; decision
[2044](2044-slice-d-2b-1-m5-flight-runtime-scoping-and-claims.md) holds the lane's claims, every ruling so far
(P-2044-1 to -17) and the M2 interim, which is PR #275.

- **Branch:** `feat/slice-d-m5-full`, cut from `14d7f42e` (PR #275's head). **Worktree:** `scratchpad/wt-m5`.
- **The brief** (from the coordinator): switch the runtime to M5; run the M5 chain on a scratch mount as far as it
  goes and measure every cold operation per module, without projecting; make exact cost fixes inside the claims
  where they keep outcomes identical under the cache checks; write this record with the measurements, the ground
  re-proof fix and how it is proved exact, every file or function outside the claims, and proposals; then stop.

## Brendan's rulings (2026-10-19)

Relayed by the coordinator: Brendan answered in chat through AskUserQuestion.

| Proposal | Ruling | What it means |
|---|---|---|
| P-2045-1 to P-2045-4 | **(a), "Approve all four"** | Four items outside the claims are cleared: `underground_budget.gd` `BINDINGS_AND_GROWTH_BYTES` +22,879 B (and up to +24,576 B more if P-2045-6's scratch list needs it); `underground_geometry_journal.gd` `_row_changed` compares the owner, with a reused-slot, new-owner test; `underground_locations.gd` `restore_state_bytes` clears `_prism_key[0]`, with a mid-preparation restore-versus-fresh spend test; `underground_world_routes.gd` `_endpoint_observation_refusal` charges a memo-answered observation at its real cost, proved as §5 and Slice C's three cautions |
| P-2045-5 and P-2045-6 | **(a), "Batch + exact fixes"** | Batch the deep floor graph's edges as the work area batches its stations; keep making exact fixes in the claims (contact air, strips, Locations landing counts); no bound raise. **If Locations or any cold operation still cannot fit after both, the lane stops and reports before (b), the Placements transaction** |

Indexed in `docs/handoff/RULINGS.md`. Master moved to `e841d89e` (#276 station retirement, #277 C3 with room record
v2 and the `bind_underground_way_in` seam); this branch merges it only after #275 (M2) lands, on the coordinator's
word. Build order: the rulings; the four outside-claim changes with their tests; the batching; the exact fixes;
re-measure every landing; fix the two non-budget stops (the module-0 pre-clearance applies if either is that case);
the chain to level 1; then the census pass, the full gates and frames.

## In short

- **First refusal (today's bound, after this round's four exact fixes):** tick 34,927, module 0's sill, the
  bindings' entry operation (`ROOM_MASK_OPERATION_BUDGET`, 1,048,603 tried). It is the installation that publishes
  landing 1 and its **40 deep stations** (M2's landing 1 had 10).
- **Measured past the bound** (a scratch clone with the budget lifted, so each number is real spend): module 0's
  sill needs 1.70 M in the bindings and 1.57 M in Locations; landing 1's floor graph publication 3.33 M in
  WorldRoutes; module 1's sill 1.95 M (bindings) and 1.97 M (Locations); landing 2's floor graph 3.81 M and
  Locations 2.28 M. The cost is not module 4's accumulation, as 2044 projected: **it is the size of each landing's
  deep stage, and it starts at landing 1.**
- **Two functional stops past the bound** (claimed code): a haul begun on a deep floor (tick 35,770), and module 2's
  T0″ from landing 2 (tick 49,454). Modules 3 and 4 were not reached.
- **Outside the claims:** the bindings reserve (+22,879 B), the journal's owner compare (P-2044-18), the kept prisms'
  key on restore (one line in Locations `restore_state_bytes`), and stage 1's observation charge. Proposals
  P-2045-1 to -6.

## 1. What was done

| Commit | What |
|---|---|
| `cf4e1779` | **The runtime mounts M5.** `qualified-m5-runtime-v1/tread_geometry.gd` `MODULES` 5; the work area's `CUT_ROWS` 27; the route composition, entry site and entry composition preload `qualified-stairs-m5-v1`; the contact retirement scope's table census 36/190/26/235/301/154; Frontier `MAX_BYTES` 51,476 (P-2044-2 (a)). |
| `036f6d05` | Exact cost fixes 1–3 (§3), the retirement scope's registry rows (`SOURCE32` 10,253, `SOURCE64` 1,087), the renewed source pins. |
| `e8c15121` | Exact cost fix 4 (§3) and the terrain scope re-check (fix 2's final form). |

`qualified-stairs-m5-v1` was already published and byte-identical (`test_publish_m5_flight.py`, 10 tests OK); no data
changed. The M5 mount leaves the branch knowingly red in two places until the rulings, both listed in §6: the memory
census refuses Frontier `MAX_BYTES` 51,476 until the bindings reserve grows (P-2045-1), and the suites and the two
ADR 1240 checkpoints pinned to the M2 bundle are stale (the census and checkpoint pass of 2044's claim 16 runs once,
in the build phase).

## 2. How it was measured

- **The chain.** `underground_host_case.gd`'s `_begin_live_entry` on the mounted Session, sustained exactly as the M2
  whole-flight suites are (`_sustain`: needs held full, R's staged stock topped up), with the cache checks **off**
  (spend as production spends). Scratch only, in APFS clones of the worktree, never committed:
  `scratchpad/m5r/instrument.py` adds counters to `WorldRoutes.Clearance.spend` (route preparations and the bindings'
  timber clearances), the bindings' `_entry_spend` and Locations' `_spend`, and `test_zz_m5_measure.gd` prints each
  interval's peak at every plan change and installation. A backtrace tracer charges every check to its call chain
  where a refusal needed explaining.
- **The same chain with the cache checks on** (every runtime cache and each new fix's cross-check running) was run
  through module 0 twice, after each round of fixes: **no `RUNTIME_CACHE_STALE` report**, and the same refusal at
  the same tick.
- **Past the bound.** To measure what each operation actually needs after the first refusal, the same chain was run
  in a clone whose `Space.MAX_CHECKS` is 268,435,456: nothing refuses on budget, and each counter is that
  operation's true spend under today's code. These are **measurements, not projections**; they say how far over
  1,048,576 each operation is, and where the chain would go next.

## 3. Exact cost fixes made inside the claims

Each changes spend only; admitted masks, refusal codes per edge and the saved state are unchanged while the
operation stays under the bound (Slice C's caution 1), and each is checked by the cache checks in every test run.

1. **A WORK contact's station rows by search** (`underground_entry_bindings.gd` `_timber_profile`,
   `_station_rows_start`). The rows were scanned whole (190 rows at 12 checks) twice per installed contact. When the
   STATION rows are ordered by endpoint (one check a row; the M5 Frontier's are) the scan starts at the endpoint's
   first row, found by binary search, and stops after its last: the same rows in the same order, so the same answer.
   Unordered rows are scanned from row 0 as before.
2. **The timber scope re-check after a terrain read** (`_timber_terrain`, `_terrain_scope_checked`). It was charged
   2,048 checks after every terrain window. A terrain read changes no part of the operation scope, and every
   operation that reads terrain re-checks the scope on entry and before it returns (`_timber_physical`,
   `_workpiece_physical`), so the per-window re-check is no longer charged. With the cache checks on it still runs
   after every window, unspent, and reports a refusal. (2044's M2 round moved the same re-check out of the refresh
   and staging loops.)
3. **Heading first** (`underground_world_routes.gd` `_profile_edge_refusal`, Slice C's hold for this lane, plus new
   private helpers `_heading_first_refusal` and `_segment_headings_refusal`). A profile's segment-heading test reads
   only its descriptor, its selection policy and the edge's immutable path; it ran after both endpoint observations
   (256 checks each) and the endpoint boxes. It now runs first: a profile it refuses is refused by the full proof as
   well (the full proof is the endpoints and then the segments, which refuse at that heading or earlier), and a pass
   changes nothing because the full proof still runs. With the cache checks on, each such refusal is confirmed,
   unspent, by the segment proof. On M5's module 0 this removed 541,372 of a 968,770-check preparation (448
   heading-refused profile proofs at 1,208 each). `test_underground_route_memos.gd` (29/29),
   `test_underground_world_routes.gd`, `test_underground_stair_carry_routes.gd` and
   `test_underground_entry_bindings.gd` pass with it.
4. **One Region pass for an installation's natural bearings** (`_timber_dependencies`,
   `_timber_natural_verdicts`, `_timber_natural_pass`, `_timber_bearing`'s new `natural` argument). The live Region
   rows were scanned once per natural or strip bearing; module 0's sill has 25. They are now judged against every
   bearing in one pass (a row charged as one bearing's scan charges it, plus one check per bearing it is tested
   against), and each bearing's verdict is used at its own place in the bearing order, so the refusal and its code
   are unchanged. Over 62 bearings, or when a bearing box would be refused, each bearing is scanned as before.
   Module 0's sill: 228,600 checks became 26,594.

## 4. Measurements

### 4.1 Stages and their task counts (measured from the foreman's plans)

| Stage | Plans at | Tasks | Made of |
|---|---:|---:|---|
| 0 | tick 1 | 13 | L0: rows 0–1, 4 cubes × 3 phases, + L0 |
| 1 | tick 2,232 | 7 | T0: row 2, 2 cubes × 3, + T0 |
| 2 | tick 3,361 | 150 | the top metre of rows 3–26 (48 cubes) + T1–T6 (module 0) |
| 3 | tick 34,926 (32,748 with M stocked) | 127 | landing 1: layer 2 of rows 7–26 (40 cubes) + T0′–T6′ (module 1) |
| 4 | tick 42,735 (M stocked) | 97 | landing 2: layer 3 of rows 12–26 (30 cubes) + T0″–T6″ (module 2) |
| 5–6 | not reached | 67 / 37 (from the Frontier) | layers 4 and 5 (20 and 10 cubes) + seven installs each |

Every stage fits `Progress.MAX_TASKS` 160 (P-2044-8 (a)). In all: 498 tasks, 154 cubes × 3 + 36 installs.

### 4.2 The first refusal (today's bound, the fixes in)

**Tick 34,927, the last task of stage 2: module 0's sill (T6, the eighth installation, the one that makes
landing 1).** The entry bindings' operation budget runs out (`ROOM_MASK_OPERATION_BUDGET`, from `_entry_spend`):
the installation's one entry budget is carried through its preflight, its staging and its Location staging, and
they need 326,000, 618,000 and 110,000 checks of it (1,048,603 tried against 1,048,576). Before fixes 1–4 the same
installation refused at the same tick with 1,035,336 spent and the WorldRoutes peak at 968,770.

The sill is where M5 first differs in kind from M2: it publishes landing 1 and the **40 deep stations of layer 2**
(M2's landing 1 had 10). Its installed contacts are 47 (M2: 17) and its bearings 25.

### 4.3 Per module, per cold operation

Peaks per interval, cache checks off, against `Space.MAX_CHECKS` 1,048,576 (share in brackets). "Past the bound"
figures come from the unbounded clone and are each operation's true spend; from module 1 on that clone also kept M
stocked (§4.6), so its ticks run about 2,200 earlier than the bounded chain's. A module here is its landing's deep
stage plus its seven treads (module 1: ticks 32,748–42,735; module 2: from 42,735).

| Interval | WorldRoutes | Locations | Bindings entry op | Bindings timber |
|---|---:|---:|---:|---:|
| The entry's confirmation (tick 0) | 478,272 (45.6 %) | 378,861 | 542,447 | — |
| Stage 0, L0 (ticks 1–2,232) | 467,836 | 198,208 | 367,526 | 250,019 |
| Stage 1, T0 (to tick 3,361) | 482,204 | 420,139 | 384,420 | 235,992 |
| Stage 2, the top metre's 48 cubes (to tick 30,000) | 573,472 (54.7 %), rising about 4,000 a 1,000 ticks | 287,881 | — | — |
| Stage 2, T1–T5 and module 0's sill (to tick 34,927), **refuses** | 594,209 | 551,624 | **1,048,603 tried** | 613,485 |
| *Past the bound:* T1–T5 and the sill | 1,745,283 (166 %) | 1,565,004 (149 %) | 1,704,420 (163 %) | 613,485 |
| *Past the bound:* landing 1's floor graph published (tick 35,000) | **3,331,208 (318 %)** | — | — | — |
| *Past the bound, module 1:* landing 1's floor graph published | **3,331,208 (318 %)** | 1,816,683 (173 %) | — | — |
| *Past the bound, module 1:* landing 1's deep phases (40 cubes) | 1,094,904 at first, falling to 928,841 as stations retire; 12 preparations over the bound | 1,517,751 (145 %) | — | — |
| *Past the bound, module 1:* T0′–T6′ and module 1's sill (to tick 42,735) | 627,407 | **1,972,180 (188 %)** | **1,953,599 (186 %)** | 686,927 |
| *Past the bound, module 2:* landing 2's floor graph published (60 new ground edges, 654 image volumes) | **3,808,940 (363 %)** | **2,275,188 (217 %)** | — | — |
| *Past the bound, module 2:* landing 2's deep phases (30 cubes; to tick 49,454) | up to 1,392,269 (133 %); 60 preparations over the bound | 1,966,254 (188 %) | — | — |
| Modules 3 and 4 | **not reached** (§4.6: the chain stops at module 2's T0″) | | | |

### 4.4 What dominates past the bound (landing 1)

From the backtrace tracer, ticks 34,926–35,770 (about thirteen preparations):

- **WorldRoutes** (13.9 M charged over the window).
  - The **deep floor graph's publication** (tick 35,000): 80 new ground edges compiled in full, 320 admitted
    profile proofs at about 10,000 checks each: **3,331,208** in one preparation.
  - **Every deep phase on landing 1 after it: about 1,095,000** with 111 carried ground edges, 42 carried stair
    edges and 4 recompiled. Of that, carried admitted ground profiles 478,396 (372), refused-profile re-proofs
    141,232 (496, all `WORLD_ROUTE_ENDPOINT_BODY`; heading refusals now cost 1,324 for 1,316), recompiled ground
    edges 231,068, stair edges 55,459, eligibility 32,827.
  - By call site over the window: per-profile endpoint observations 2,247,680 (+ 954,368 per edge, + 442,368 on
    stair rows), full-proof volume scans about 8.5 M (`subtract_role` under `_body_covered` 2,032,148,
    `_solid_contacts_covered` 1,714,960 + 1,271,468, `_body_blocked` 1,695,440, `_subtract_pending_bearer` 847,720,
    stance `blocked`/`covered` about 800,000), `_carry_hull_clean` 377,251.
- **Locations, 1,816,683 at the peak.** The witness passes and per-record refreshes over the 47 new installed
  records; the largest call sites over the window: `_installed_landing_count` under `_installed_row_site` and `_installed_record_kind`
  (1,445,640 each), `_installed_record_kind` / `_installed_surface_site` in `_derive_witnesses` (about 1.3 M each),
  `_pass_landing_count` (705,600 twice), `_covered` 784,392, `_record_obstacles_refusal` 667,512.
- **Bindings, the sill: 1,704,420**: the contacts' air (`_timber_air_box`, one Region scan per contact: 214,320 in
  the preflight and 221,088 in staging), the strips' staging (`_stage_strips` 109,692 + `_timber_support_residual`
  41,920), the part partition (33,088 + 32,768 scope re-checks), the new Locations' datum lookups
  (`_timber_datum_ref` 70,044).

**Landing 2 is worse than landing 1, though it has fewer stations (30 against 40):** the image has grown to 654
volumes (423 at landing 1), so a full ground compile's volume scans cost more: the floor graph's 60 new edges took
3,808,940, about 15,300 checks for each of 240 admitted profile proofs (10,000 at landing 1). Every scan in a full
proof charges one check per image row, so this grows with every module however few edges a landing has.

### 4.5 Frontier bytes

`Frontier.required_bytes` for M5's table census (36 / 190 / 26 / 235 / 301 / 154 rows): **51,476 B** (wire file
49,656 B). M2's: 16,232. The bound before this round, 28,597, is 22,879 short; the shared bindings reserve
`Budget.BINDINGS_AND_GROWTH_BYTES` (524,544) is fully assigned, so it must grow by the same amount (P-2045-1).

### 4.6 Two functional stops past the bound (not budget refusals; claimed code, for the build phase)

**1. A haul from a deep floor.** In the unbounded clone the chain first stopped at **tick 35,770, stage 3 task 6**:
`PROFILE_VARIANT_UNAUTHORED`, from `Profiles.query_travel_profile_into` under Routes `refresh_travel_actor`, called by
the hauler's `_next_leg` for a haul the foreman began from landing 1's floor (`_open` → `_begin_haul` →
`_haul`): the leg is a claw floor row that the hauler's tooled posture does not match. It happened with R stocked
at 3,000 and at 12,000 milli. M2's deep stage (10 cubes) never hauled from a floor. The foreman's deep haul legs are
this lane's (claimed); the fix (climb to the surface leg by leg before a haul, as the installer does since 2044) is
for the build phase. For the measurement, the clone then stocked M directly (scratch) so that no phase hauls
mid-stage. (A run that also kept R at 12,000 milli of each stock stopped at tick 48,054 with the inventory's
`CAPACITY_EXCEEDED`, R's pile filling with stock beside the spoil; that is the stand-in's own artifact, and R went
back to the suites' 3,000.)

**2. Module 2's T0″ from landing 2.** With M stocked, the chain ran through module 1 and landing 2's deep stage and
stopped at **tick 49,454, stage 4 task 90 (installation 15, module 2's T0″)** with `ROUTE_TURN_PROFILE`: the
installer, climbing off landing 2's floor leg by leg (2044's fix), is on landing 1 at (0, −1,024, −6,825) with its
next leg to (300, −2,048, −11,882). Two landings below the surface never occurred in M2. The installer and the stair
path are this lane's; the fix is for the build phase. **Modules 3 and 4 were therefore not reached**, and nothing
is projected for them here.

## 5. The ground-edge re-proof (the brief's question), and how it is proved exact

**What M5 measured.** Carried ground edges' refused profiles are refused on three grounds only, at module 0 and on
landing 1 alike: `ROUTE_SOURCE_STEP_SPAN` (already free, before any observation), `WORLD_ROUTE_PROFILE_HEADING` and
`WORLD_ROUTE_ENDPOINT_BODY`. **None refused on Space volumes or terrain.** So a skip keyed on "refused on Space"
(a stored refusal class per profile) would save nothing here, and skipping refused profiles wholesale stays unsafe
(Slice C's caution: a refusal can turn on unjournaled terrain).

**The fix, in two parts.**

1. **Heading first: built** (§3 fix 3). It is exact for every edge, carried or not: the heading test reads only
   immutable inputs, and the full proof refuses wherever it refuses.
2. **Endpoint-body refusals: the observations' charge (P-2045-4).** Each refused profile still pays one endpoint
   observation (256 checks) and the endpoint boxes' replayed spend before it is refused on the endpoint's body. The
   observation is answered from stage 1's memo, which is kept only inside one edge compile (`_observed`,
   `_observed_key`, keyed by `_observe_serial`), so what it answers is fixed by the compile alone and never by
   history. Charging an answered observation what it does (a key compare and a record copy) instead of a fresh
   observation's 256 keeps the spend deterministic across save and load, and changes no answer.
   `_endpoint_observation_refusal` is stage 1's function, outside the six held for this lane, so it needs Slice C.
   The endpoint boxes' memo (decision 1952) is kept across preparations, so its replayed spend must stay what the
   live check spends: it is not touched.

**How each is proved exact (Slice C's three cautions, recorded in 2044).**

1. *Spend versus outcome.* Outcome: each edge's admitted mask, its refusal code, the certificate's generation,
   geometry and content revisions, the saved WorldRoutes wire and the ADR 1240 checkpoints' state. Spend: `remaining`,
   `_proof_checks` (runtime only, never saved) and a `WORLD_ROUTE_CHECK_CAPACITY` refusal. The build phase confirms
   that the dig benchmark's SHA trace hashes no spend field before comparing it.
2. *Master's differential scenarios under the bound.* The trace scenarios (`REDWALL_DIG_TRACE`, the room run and the
   entry run) and the save-parity runs are first run on master with a counter that fails if any preparation reaches
   `WORLD_ROUTE_CHECK_CAPACITY`; only then are the trace and the checkpoints compared byte for byte. A scenario that
   reaches it on master is named, with its changed outcome, as P-2044-15's ruled effect.
3. *Stage 1's caches.* The cache-checks run still goes through `_endpoint_observation_refusal` for every
   observation; `test_underground_route_memos.gd`'s differential compile (code, spend, error, certificate row,
   descriptor, endpoint record, pace, and every short budget) stays green, as it is now with heading first.

Also for heading first: under the cache checks every heading refusal is confirmed by the segment proof (unspent),
and a contradiction reports `RUNTIME_CACHE_STALE`; the M5 chain ran through module 0 with the checks on and none
was reported.

## 6. Everything needed outside the claims (one list)

| # | File and function | Why | Proposal |
|---|---|---|---|
| O-1 | `scripts/core/underground_budget.gd` `BINDINGS_AND_GROWTH_BYTES` | +22,879 B for Frontier `MAX_BYTES` 51,476 (§3's fixes added no storage); and, if P-2045-6 (a) builds the contact-air candidate list as a fixed bindings scratch, up to 24,576 B more (one int32 per Region slot); ledger rows | P-2045-1 |
| O-2 | `scripts/core/underground_geometry_journal.gd` `_row_changed` | P-2044-18: compare the owner slot and generation, so a SUPPORT row removed and re-added with the same box and role but another owner, in one stage, is a change; with a test of the reused-slot, new-owner case. No Slice C lane holds it; phase-spreading stage 2 names the journal but waits for M5 | P-2045-2 |
| O-3 | `scripts/core/underground_locations.gd` `restore_state_bytes` (Slice C hold) | Clear the kept prisms' key (`_prism_key[0] = 0`) on entry, before `_restore_current_refusal` re-proves the witnesses: a Placements bank restored in place keeps its instance and may restore an equal revision. The landing key needs nothing (it is keyed by the witness pass serial, which a restore never repeats). Neither stage 1's WorldRoutes caches nor C3's room runtime is involved. With a test that restores mid-preparation and compares the spend with a fresh run | P-2045-3 |
| O-4 | `scripts/core/underground_world_routes.gd` `_endpoint_observation_refusal` (stage 1's, Slice C) | Charge an observation answered from the in-compile memo what it does, not 256 (§5 part 2) | P-2045-4 |
| O-5 | none new for the entry runtime, Session, Profiles, stair motion or catalog | The M5 mount needed none of them | — |

**Not outside the claims, but recorded:** fixes 1, 2 and 4 are in the claimed bindings; fix 3 is in
`_profile_edge_refusal`, held for this lane, with two new private helpers beside it (as `_carry_hull_clean` was);
the bindings gained a `CacheChecks` preload. The successor-pattern pre-clearance (P-2044-17) and the episode lookup
budget pre-clearance were **not used** this round.

**Slice C's answers, recorded** (relayed by the coordinator, 2026-10-19):

1. The M2 round's Locations and WorldRoutes edits beyond the named functions (`_order_prisms`,
   `_cached_prisms_hold`, `_landing_boxes`, `_landing_key`, `_prism_tops`, `PASS_LANDINGS`, `TOP_BIAS`, the
   `_allocate_banks` resizes, `_carry_hull_clean`) are now on both Slice C lanes' hold lists. Neither lane touches
   Locations, WorldRoutes, the geometry journal or the Session.
2. P-2044-18: no Slice C lane holds the journal and Slice C does not object; it is proposed here (P-2045-2) with a
   test of the reused-slot, new-owner case, and is not edited before Brendan rules.
3. The restore key: the exact function is O-3. It is neither stage 1's WorldRoutes caches (`_observed`,
   `_observed_key`, `_pace_inputs`) nor C3's room restore or `_read_state`. A restore-mid-preparation spend test
   comes with it either way.
4. Slice C's lanes add no Locations spend; their route peaks go down (a 12×4 room: 798,332 → 518,302).

## 7. Proposals

**P-2045-1 — The bindings reserve for M5's Frontier.**

- **(a) Raise `Budget.BINDINGS_AND_GROWTH_BYTES` by 22,879 B (524,544 → 547,423) with a ledger row, so Frontier
  `MAX_BYTES` 51,476 fits the fully assigned reserve.** About 23 KB against about 43.9 MB of headroom under the
  150 MB gate.
- (b) Per-module Frontiers chained by the foreman (2044's P-2044-2 (b)): no raise, but five bundles' digests and a
  Frontier switch in the foreman.

**Recommendation: (a).**

**P-2045-2 — The geometry journal and owner changes (P-2044-18).**

- **(a) One line in `underground_geometry_journal.gd` `_row_changed`: compare the owner slot and generation as well,
  with a test that removes a SUPPORT row and re-adds one with the same box and role but another owner in one stage,
  in a reused slot, and sees the change.** ADR 1205's ground carry gains the same guarantee.
- (b) Refuse to carry a stair row whose decks or bodies meet SUPPORT of any other owner: a Space scan per edge,
  most of what the carried form saves.

**Recommendation: (a).**

**P-2045-3 — Restore and the kept prisms.**

- **(a) Clear the kept prisms' key at the start of `underground_locations.gd` `restore_state_bytes` (one line, a
  Slice C-held Locations function), with a test that restores mid-preparation and compares the spend with a fresh
  run.**
- (b) Key the prisms on a Locations restore epoch instead: the same function still has to move the epoch.

**Recommendation: (a).**

**P-2045-4 — The charge for an observation answered inside one compile.**

- **(a) Clear `_endpoint_observation_refusal` (stage 1, Slice C) to charge a memo answer a fixed small amount (the
  key compare and the record copy) instead of `PREPARED_OBSERVATION_CHECKS` (256).** The memo lives only inside one
  edge compile, so the spend stays a function of the compile, never of history; answers are unchanged; proved as §5.
- (b) Leave it: the refused profiles' endpoint observations stay at 256 each (141,232 a deep phase on landing 1).

**Recommendation: (a)**, because it is exact, deterministic and touches one function; but it is not enough on its
own (P-2045-5).

**P-2045-5 — The deep stage's size (the measured bottleneck).**

M5's landing 1 cuts layer 2 under 20 rows from 40 deep stations, all installed by module 0's sill, with their whole
floor graph published at once and live for the whole stage; landing 2 does the same for 30. Measured: module 0's
sill 1.70 M checks in the bindings and 1.57 M in Locations; landing 1's floor graph publication 3.33 M in
WorldRoutes; landing 1's deep phases about 1.10 M (WorldRoutes) and up to 1.82 M (Locations); module 1's sill
1.95 M and 1.97 M; landing 2's floor graph 3.81 M and Locations 2.28 M. A full ground compile's cost also grows with
the image (10,000 checks a profile at 423 volumes, 15,300 at 654), so fewer live edges help but do not by themselves
stop later landings from growing. The bound is 1.05 M and is not to be raised (ruled).

- **(a) Batch the deep floor graph, as the work area batches the surface stations (ADR 1229): the stair path and
  foreman (claimed) publish only the next batch's stations' walks (for example four rows, eight stations), joined
  when its first cut opens and retired with the batch after it; the strips stay as staged.** This bounds the live
  ground edges and the publication spike by the batch, not the stage. It leaves the 47 Locations the sill creates
  (they are installed contacts of the sill; creating them mid-stage needs an issuer no claim has, as P-2044-12
  found), so Locations' witness work and the sill's own operation still need their exact fixes in the claimed
  Locations functions and bindings (P-2045-6). To be measured before it is relied on.
- (b) As (a), and also move the deep stations out of the sill's installed contacts into per-batch Locations,
  through a new Placements transaction (outside the claims, several hundred lines, like P-2044-12 (b)).
- (c) Re-plan the dig so no landing cuts more than one module's rows at a time: not available; layer 2 of rows 12–26
  can only be struck from depth 1 (2043 §3).

**Recommendation: (a), with P-2045-6**, measured landing by landing; **if Locations still cannot fit at landing 1
or 2 with (a) and P-2045-6 built, the lane stops and asks for (b)**, which is the change that bounds Locations by
the batch too.

**P-2045-6 — Exact cost fixes in claimed code for the sill and Locations (no new clearance; for the record).**

- **(a) Continue under P-2044-15's "Exact cost fixes" in the claimed files: one Region pass for an installation's
  contact air in the bindings (a per-contact candidate list instead of a Region scan per contact; a fixed scratch,
  a ledger row), the strips' staging, and in the held Locations functions the landing counts outside a witness pass
  (`_installed_landing_count` under `stage_refresh`'s per-record refresh) — each proved like §3 and measured on the
  mount.**
- (b) Stop at P-2045-5 (a) and re-measure first.

**Recommendation: (a)**, built together with P-2045-5 (a) and re-measured module by module; if a landing still
cannot fit, the lane stops again with the numbers.

## 8. Gates this round

Phase 1 only (no suite-wide gates; the build phase runs them):

- `test_underground_world_routes.gd`, `test_underground_entry_bindings.gd` and `test_underground_stair_carry_routes.gd`
  pass with fixes 1–3; `test_underground_route_memos.gd` failed one test (the cache-checks confirmation then observed
  the endpoints and left a different endpoint record than an unchecked run), fixed by confirming with the segment
  proof only, then 29/29. After fix 4: `test_underground_entry_bindings.gd` and `test_underground_m5_entry_costs.gd`
  54/54. 0 unexpected errors or warnings, 0 leaks in each.
- The analyzer (`tools/gdscript_warnings.py --max 0 --port 6505`): 0 warnings in 1,638 files. No function this
  round added is over 30 lines, and none of the two edited files gained one.
- `docs/validation/state_registry_coverage.py` PASS (206 modules, 847 rows).
- `test_publish_m5_flight.py` 10/10 (the M5 bundle unchanged).
- The M5 chain with the cache checks on, through module 0: no `RUNTIME_CACHE_STALE`.

## Source

Decision 2044 (claims, P-2044-1 to -17, the M2 measurements and Slice C's cautions); 2043 §3 (M5's geometry and dig
order); 1972 "Phase 3b"; 1953 §6 (stage 1's caches); decision 1990 (C3's seam, for awareness: D2 fills it). The
coordinator's brief and Slice C's answers of 2026-10-19. Measurements: `scratchpad/m5r/` (logs `a1`–`a3`, `b1`–`b2`,
`u1`–`u5`, `v1`), from the clones `m5a`, `m5b`, `m5u` and `m5v`.

## Build phase (2026-10-19): built, re-measured, and stopped under the P-2045-5/-6 ruling

The rulings' stop condition holds: **after P-2045-5 (a) and P-2045-6 (a), WorldRoutes (at module 0's sill) and
Locations (from module 0's sill on) still cannot fit `Space.MAX_CHECKS`.** The lane stops here, before (b) (the
Placements transaction) and before the census pass, the full gates and the frames, which wait for a chain that
reaches level 1. Two non-budget stops were found past the bound as well: one is fixed, one is a design gap.

### Built

| Commit | What |
|---|---|
| `e0f01b30` | The rulings, here and in `docs/handoff/RULINGS.md` |
| `ada355ea` | **P-2045-1** `BINDINGS_AND_GROWTH_BYTES` 547,423 (+22,879). **P-2045-2** the journal's `_row_changed` compares the owner slot and generation; `test_underground_geometry_journal_owner.gd` (4 tests: unchanged row, reused slot with a new owner slot, a new owner generation, box/role/presence still count). **P-2045-3** Locations `restore_state_bytes` forgets the kept prisms first; `test_a_restore_re_derives_kept_prisms_and_spends_as_a_fresh_load` (an in-place restore with prisms kept, and kept boxes that no longer match, spends exactly what the same restore spends with nothing kept, and re-derives the prisms). `restore_state_bytes` refuses while an operation is open, so "mid-preparation" is between two preparations of a running entry |
| `ba11e40c` | **P-2045-5 (a)**: the deep floor graph is joined a block at a time (stair path `floor_block`, `floor_missing`, `_floor_pairs(…, row)`, foreman `_open_deep_floor`): D to the landing row's column-1 station, one straight walk down the column-1 spine to the block's nearest row (over the spine strips), and the block's own spine and crossings; a block's walks leave with its stations (`retire_row`). **P-2045-6 (a)**: the bindings' Region scans read a row's z extent first (`Z_READ_CHECKS` 2 of a box read's 12) and the rest only when it meets the tested bounds (`_z_misses`): the contacts' air, the part clearance and staging, the natural rows and installed bearings, the workpiece air and foot, the support residual and the datum lookup |
| `4fb4c06f`, `1af18805` | **P-2045-6 (a)** in the held Locations functions: a Placement row's LANDING datums are kept for the open Locations operation (its token) as well as a witness pass, keyed also by the Catalog revision, and sorted by (level, low z) so a record compares only its own (`_landing_scope`, `_order_landings`, `_landing_order_key`, `_landing_sorted`, `_checked_landing_count`, `_scanned_landing_count`); with the cache checks on a kept count is compared, unspent, with the per-record scan. Registry rows updated |
| `506b44e1` | **P-2045-4 (a)**, after Slice C's question: an observation answered from stage 1's in-compile memo is charged `ANSWERED_OBSERVATION_CHECKS` (51: both kept keys compared, one record copied) instead of 256. **The cases, measured:** over the preparations above 600,000 checks, 157,668 observations were answered and 62,725 observed live; module 0's sill requalification answered 263 (67,328 checks charged for them, about 13,400 of real work) and observed 88; landing 2's block publications answered none (every observation was a first one). The memos differential (29/29, every short budget) stays green; the save/load parity re-runs with the census pass |
| `dff8923f` | The M2-pinned suites on the mounted M5 bundle: the work area (59 Locations, 301 endpoints), the handling certificates and bundle source (`qualified-stairs-m5-v1`), the first-prefix fixture's Sites (160) |
| `1b591b60` | **Stop 1 fixed** (`_haul_or_climb`, foreman): a phase short of inputs on a deep floor walks the crew up to X on its own legs under the phase's BUILD Job, turning as it goes, and hauls from there; every leg's end re-checks. **Two-row floor blocks**: four rows took landing 2's first block to 1,291,518 checks; two take it to 864,051 |
| `ad7d3723` | origin/master `1b71992b` merged (#275 M2, #276, #277); no conflicts; the focused suites (259 tests) pass after a fresh import. Generated files are regenerated in the census pass |

Built and removed again (not committed): taking a ground row at the crew's current heading before a turn, for the
U0' stop below. Every candidate (approach 45, retreat 49, the all-yaw walk 42) is refused there with
`WORLD_ROUTE_ENDPOINT_BODY`, so it changed nothing.

Focused suites after each step: 0 failures, 0 unexpected errors or warnings, 0 leaks. The cache checks (every test
run) found no `RUNTIME_CACHE_STALE`.

### Re-measured, every landing reached (cache checks off)

Bounded is today's `Space.MAX_CHECKS`; unbounded is the scratch clone with the bound lifted (real spend). "M stocked"
runs fed M directly so that no phase hauls, as in §4.6; the others ran the real haul.

| Point | WorldRoutes | Locations | Bindings entry | Bindings timber |
|---|---:|---:|---:|---:|
| Module 0 before its sill (to tick 30,000) | ≤ 573,472 | ≤ 414,000 | ≤ 542,447 | ≤ 231,669 |
| Module 0's sill (tick 34,927) | **1,691,368 (161 %)** | **1,108,077 (106 %)** | 956,047 (91 %) | 403,812 |
| Landing 1, two-row blocks | 590,822 – 610,838 | **1,091,580 – 1,304,088** | — | — |
| Module 1's sill (M stocked) | 557,940 | **1,397,555** | 969,679 (92 %) | 398,387 |
| Landing 2, two-row blocks (M stocked, to tick 50,300) | 780,725 – 865,311 | **1,258,989 – 1,629,919** | — | — |
| Modules 3 and 4 | not reached (below) | | | |

Before this phase the same points were: the sill 1,745,283 / 1,565,004 / 1,704,420; landing 1's floor graph
3,331,208 / 1,816,683; module 1's sill 627,407 / 1,972,180 / 1,953,599; landing 2's floor graph 3,808,940 /
2,275,188. The batching took every landing's WorldRoutes peak under the bound; the bindings now fit with 8 % to spare.

**First refusal, bounded:** tick 34,927, module 0's sill (task 150 of stage 2), WorldRoutes
`WORLD_ROUTE_CHECK_CAPACITY` in the installation's route requalification (`_stage_timber_routes`). Of its 1.69 M,
770,048 is `_preparation_refusal`'s source pass, charged twice for each of the 44 old edges the sill's staging
does not let carry (29 ground, 15 stair), and most of the rest is those edges' full proofs.

**Where Locations still spends** (landing 2, the traced window): outside the held functions, the per-record scans of
every Placement slot in `_installed_record_kind` and `_installed_surface_site` (with their source charge, 1,024
outside a witness pass), and `_record_geometry_refusal`'s `_covered` and `_record_obstacles_refusal`; together about
70 % of each witness pass and refresh. The held functions' remaining share (`_natural_floor_site`'s two Site
lookups, the landing counts) is about a fifth: no fix inside the claims can bring 1.63 M under 1.05 M.

### Non-budget stops

1. **Fixed: a haul from a deep floor** (`1b591b60`). Landing 1's stage runs through with the real haul.
2. **A design gap: climbing up through a landing.** A crew coming up module j arrives at U0' (landing j) facing up
   the flight; the way on up (P-2044-16 (a): U0' → F' backing on the retreat 47, then 72, 55 and the ascent) needs it
   to face down. Routes turns only a ground actor (`ROUTE_TURN_PROFILE`: the crew still carries the stair's family),
   and no ground row at its heading fits U0''s air (approach 45, retreat 49 and the all-yaw walk 42 are each refused
   `WORLD_ROUTE_ENDPOINT_BODY`). M2 never climbed through a landing. Every later module needs it: module 2's T0''
   installer (tick 49,454 earlier) and landing 2's hauls (tick 50,336) both stop here. **This is §4.6's stop 2.**
3. **New: `STEP2_ACTIVITY_FORBIDS_WORK`** at tick 45,414 in the real-haul run, when T0''s order was committed at X:
   the crew's schedule forbade work. The whole flight now spans days, and the entry runtime ends the chain on this
   refusal although its gap text says it waits for a work hour (`underground_entry_runtime.gd`, the C2 follow-up's
   file). The M-stocked runs, whose timing differs, did not meet it.

### Everything else needed outside the claims (one list)

| # | File and function | Why | Proposal |
|---|---|---|---|
| O-6 | `underground_world_routes.gd` `edge_refusal` / `_preparation_refusal` (Slice C) | The prepared source and claim pass is charged before and after every uncarried edge (2 × `SOURCE_PASS_CHECKS`); module 0's sill pays 770,048 of its 1.69 M for it. Charged once per preparation, with the cache checks re-running it per edge unspent, the sill would be about 0.92 M. Needs Slice C to confirm no callback inside a preparation can change source or claim truth | P-2045-7 |
| O-7 | `underground_locations.gd` `_installed_record_kind`, `_installed_surface_site`, `_record_geometry_refusal` (`_covered`, `_record_obstacles_refusal`) (Slice C hold) | The per-record scans above; exact fixes of the same kind as §3 (find the record's Room's Placement rows once per pass or operation, keyed like the kept prisms; the z-first Region read) | P-2045-8 |
| O-8 | Data and paths in the claims, but a design choice: the M5 bundle's U0' stop and the stair path's up-route | Climbing through a landing | P-2045-9 |
| O-9 | `underground_entry_runtime.gd` (the C2 follow-up's) | `STEP2_ACTIVITY_FORBIDS_WORK` should wait, as its gap text says, not end the chain | P-2045-10 |

### Proposals

**P-2045-7 — The route requalification's source pass.**
- **(a) Clear `edge_refusal`/`_preparation_refusal` to prove the prepared source and claim pass once per
  preparation and charge it once, re-running it per edge, unspent, under the cache checks.** Exact if nothing inside a
  preparation can change source or claim truth, which Slice C confirms first.
- (b) Leave it, and spread the sill's staging so fewer old edges lose their carry (not exact: it changes what the
  sill stages).

**Recommendation: (a).**

**P-2045-8 — Locations' per-record scans.**
- **(a) Clear the three Locations functions for exact fixes of §3's kind, measured landing by landing.**
- (b) The Placements transaction (P-2045-5 (b)): deep stations' Locations per batch, so fewer records are witnessed
  at once. Larger, and the scans per record stay.

**Recommendation: (a)**; (b) only if (a) does not bring landing 2 under the bound.

**P-2045-9 — Climbing up through a landing.**
- **(a) Re-size U0' (the M5 publisher, the clearance test) so that the all-yaw walk 42 fits there, then turn at U0'
  on 42 before the retreat 47.** The clearance test decides first whether the body clears module j−1's sill and
  module j's T0 (42's ±712 u body reaches about 480 u past the sill's far edge, with T0's deck below the floor).
- (b) Keep each landing's hub D as a lasting stop (today it retires with T0's last leg) and route the way up through
  it on 42 (U0' → D, a turn at D, D → F' on 47). It needs the same fit at U0' for the first walk.
- (c) Qualify a rooted half-turn from facing up to facing down on a landing floor: new motion, which is ruled out.

**Recommendation: (a)**, proved by the clearance test before any runtime change; if the body does not clear, stop
with the numbers.

**P-2045-10 — The schedule refusal ends the chain.**
- **(a) The C2 follow-up's owner (or this lane, cleared) makes the entry runtime wait on
  `STEP2_ACTIVITY_FORBIDS_WORK`, as its gap row says.**
- (b) The whole-flight suites hold the crew's schedule open as they hold its needs (a stand-in only).

**Recommendation: (a)**, with (b) for the suites until it lands.

### Gates

Not run: the census pass, the full sharded suite and the frames wait for a chain that reaches level 1, per the
brief. The focused suites, the registry coverage, the decision numbers and the source pins pass on `ad7d3723`; the
analyzer (port 6505) reports 0 warnings in 1,660 files once the journal test's duck-typed fixture fields are
annotated.
