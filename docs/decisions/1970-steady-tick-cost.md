# 1970 — Steady-tick cost: where an ordinary underground tick goes, and the exact fixes (phase 1)

Date: 2026-10-21 · Status: **Accepted.** Brendan ruled "Fixes now, then tokens" on 2026-10-21 (see "Brendan's ruling").
F1–F4 are cleared and being built. The per-row tokens are scoped in §9 and wait for their files to be cleared.

Lane STEADY-TICK (Slice C), branch `perf/steady-tick`, cut from master `e0e7065a`. Decision number 1970 is this
lane's. Analyzer port 6443.

## Brendan's ruling (2026-10-21), relayed by the coordinator

**"Fixes now, then tokens."**

- Build F1–F4 now (§5), then re-measure.
- Then build P-1952-1 (a)'s per-row write tokens. Its "Later, if needed" condition is now met: the 2 ms target is
  still missed after activation and phase-spreading stage 1.
- The tokens are scoped in this record first (§9), naming every file and function. The coordinator clears them with
  slice D before anything is built.

**The coordinator's clearances:**

- F1 and F3 were cleared with the ruling.
- F2's WorldRoutes members and `_allocate_scratch`, and F4's two claw programs and the Profiles member, were cleared
  after slice D agreed.
- The 3.4 ms `paw_physical_certificate` cost inside `advance_tick` (§3.4) belongs to slice D's M5 Contacts work
  (P-2044-9's successor). This lane does not touch it.

**The coordinator's first task:** find out why three- and four-builder crews froze (§2a) before any performance
work.

## The problem

REQ-SET-163 requires the simulation tick at 1x to have p99 ≤ 2 ms. Decision 1953 §6 measured the steady room-dig
(earning) tick at about 2.1 ms p50 and 3.3 ms p95. The Routes cost lane (decision 1954 §3.3) measured
`Routes.advance_tick` at 1.6 ms on an ordinary tick, with its meter running.

This lane covers **ordinary ticks only**. The one-tick stalls at START, settlement and route publication belong to
phase-spreading stage 2 (decision 1953 §7), which Brendan has deferred. Those stalls are shown below as "cold" and
are not discussed.

## In short

- **A one-builder room earning tick is about 2.0–2.3 ms at p50 and 3.9–4.4 ms at p99** with the real room runtime
  on content 12. Two builders take it to 2.8–2.9 ms at p50 and 4.7–5.5 ms at p99. A 4×4 room takes one builder to
  3.0 ms and 5.9 ms.
- **Where the earning tick goes**, for one builder (claw Kitchen, mean of 800 ticks, 2.55 ms):

  | Part | Time | Share |
  |---|---:|---:|
  | Routes' itinerary searches (4.2 a tick, all repeats of the previous tick's) | 0.70 ms | 27% |
  | The rest of the room provider's worker and output re-attestation | 1.08 ms | 42% |
  | `Routes.advance_tick` | 0.45 ms | 18% |
  | Sites, Work and the runtime | 0.32 ms | 13% |

  The itinerary searches are where the p95 and p99 come from. A CUT tick also runs the output check, which makes
  about 7 searches (about 2.1 ms) instead of 3.
- **`Routes.advance_tick`'s 1.6 ms does not hold without the meter.** I timed it with timers on only 11
  functions. On the M5 flight (first 30,000 ticks), its ordinary ticks measure p50 0.60 ms, p95 0.82 ms and p99
  1.04 ms (mean 0.68 ms). On master's entry prefix it averages 1.4 ms only because the installer's handling proof
  runs inside it (§3.4). On a room tick it is 0.45 ms per actor, and that time is the actor's stationary or moving
  re-attestation, not the loop.
- **I propose four exact fixes, F1–F4 (§5).** Together they should bring the one-builder earning tick to about
  1.3 ms at p50, 1.7 ms at p95 and 2.1 ms at p99. Two builders would still be at about 1.8 ms, 2.1 ms and 2.4 ms.
  - F2 is the large one: a memo of the whole itinerary search, keyed on the same publication receipts WorldRoutes'
    witness already uses, with its spend and scratch replayed.
  - F1, F3 and F4 are small: hoisting the Routes loop's invariants, reading the binding once per scope check, and a
    load-revision memo for the claw image digest.
- **What remains after them cannot be cut exactly** without owner tokens that P-1952-1 (a) deferred: per-row write
  tokens on Transforms, Inventory and Gear, and revisions on the surface exclusions. What remains is each actor's
  per-tick Routes re-attestation (about 0.35–0.45 ms an actor) and the worker and output live leaves (about
  0.6 ms an earning builder). §6 lists them.

## 1. How it was measured

**The scenarios** are scratch suites that were never committed. They run the real room runtime
(`underground_room_runtime.gd` → foreman → builders) on the content-12 claw fixtures:

| Scenario | Fixture | Builders | What it covers |
|---|---|---:|---|
| `claw1`, `claw2` | `ClawKitchen` (decision 1939), stocked | 1, 2 | room digging |
| `retire2` | `LargeRoom` crowded with 35 edges (decision 1942) | 2 | retirement on from the first cube |
| `heading_n` | `SideRooms`, a 2×2 Kitchen north of the Corridor (decision 1943) | 1 | multi-heading rooms |
| `wide1`, `wide2` | `LargeRoom` 4×4, 64 cubes, capped at 12,000 ticks | 1, 2 | larger rooms |
| `entry` | the live settlement's `run_tick`, entry prefix to `DONE_TICK` | — | the entry crew |
| `idle` | the live settlement, underground mounted and every owner composed, no entry begun | — | idle settlement, 1,800 ticks |
| `flight` | M5 (`origin/feat/slice-d-m5-full` `ea9c7ed6` merged onto `e0e7065a`), `_begin_live_entry` with `_sustain` | — | the M5 flight, first 30,000 ticks |

**The tick classes.** Each tick of `runtime.advance` (or `run_tick`) is timed with `Time.get_ticks_usec()` and
classified:

- **cold:** a cold lease was taken (`Budget._next_token` moved). These are the phase-spreading stalls.
- **publish:** a route or Location publication.
- **event:** a builder's stage, leg or leg state changed: a handoff, turn or route request.
- **earn:** a builder is in `STAGE_EARN`.
- **travel:** a builder is walking a leg.
- **other:** everything else: entry, recovery, waiting, walking in.

On the host scenarios, **earn** means `Work.tick_solo` ran. On the flight, **slow** means a non-cold tick over
33.3 ms; there were none.

**Three levels of instrumentation:**

- **Clean:** no wrappers. These give the absolute numbers below.
- **Light:** 11–22 functions wrapped with inclusive timers (about 20 wrapped calls a tick), for the per-system split.
  The light totals match the clean ones.
- **Heavy and medium**, for attribution:
  - heavy wraps all 5,396 functions in `scripts/core/underground_*`, `excavation_*`, Work, Jobs, Inventory,
    Transforms, Residents, Needs, Directory, the source programs and the settlement system;
  - medium wraps 37 chosen functions.

  The heavy profile inflates a tick 2.5–3×. Its per-function figures are corrected by the wrapper overhead
  (0.50–0.55 µs a call), measured as the difference from the clean mean.

**The machine** is the development Mac (Apple Silicon), headless editor binary, with cache checks off as the
benchmark runs them. The load average was 11–16 while other lanes ran, so the runs were noisy. These are single
runs; phase 2's before/after runs are alternating rounds on the same scenarios.

## 2. Results (clean, microseconds)

| Scenario | Earning tick p50 / p95 / p99 | Travel tick p50 / p95 / p99 | Stationary ("other") p50 / p95 / p99 |
|---|---|---|---|
| `claw1` (1 builder) | 2,099 / 4,045 / 4,434 | 572 / 728 / 902 | 479 / 567 / 699 |
| `heading_n` (1 builder, north) | 2,250 / 3,939 / 4,273 | 552 / 647 / 768 | 465 / 571 / 686 |
| `wide1` (1 builder, 4×4) | 2,952 / 5,314 / 5,939 | 596 / 830 / 1,042 | 520 / 692 / 804 |
| `claw2` (2 builders) | 2,797 / 5,141 / 5,491 | 819 / 956 / 1,029 | 75 (walking in) |
| `retire2` (2 builders, retirement on) | 2,913 / 4,337 / 4,721 | 904 / 1,109 / 1,290 | 74 |
| `wide2` (2 builders, 4×4) | 3,565 / 5,744 / 6,516 | 739 / 1,183 / 1,332 | — |

| Host scenario | Ordinary tick p50 / p95 / p99 | Work tick p50 / p95 / p99 |
|---|---|---|
| `entry` (master prefix, 12 residents) | 830 / 11,604 / 12,943 | 8,836 / 14,552 / 15,691 |
| `flight` (M5, first 30,000 ticks) | 891 / 1,194 / 1,749 | 997 / 14,022 / 17,697 |
| `idle` (underground mounted, no entry) | 149 / 218 / 319 | — |

**Three and four builders froze in phase 1.** My hand-placed parkings froze the crew with
`ROOM_FOREMAN_CREW_BLOCKED`, `ROOM_BUILDER_STALLED` or `ROOM_BUILDER_STUCK_UNDERGROUND`. §2a gives the cause (a
fixture fault, and three parking defects behind it) and the fixes. A crew of three now digs to the end. One access
parks at most three builders, so a crew of four digs with three.

## 2a. The three- and four-builder freeze: three parking defects, fixed

Before any performance work, the coordinator asked whether the freezes in §2 were a production defect or a fixture
fault. **It was both.**

**The fixture fault.** My phase 1 fixtures parked the third and fourth moles by hand on Corridor points I chose,
bypassing the composer. Those points broke decision 1991's H-1 rules, which forbid parking on a builder's way or on
the storage's location.

**The production defects.** With the composer's own parking (`Composer.order`, the real Confirm route), crews still
froze. The case is an access whose floor has room for more than one parking: the claw Kitchen with its old Corridor
widened west, south and north. The plain Kitchen Corridor has room for only one composer parking. That is why
decision 1991's four-crew test parks two: the composer's one and an authored one. There are three defects, all in
`underground_room_parking.gd`:

1. **A parking walled in behind another (`ROOM_FOREMAN_CREW_BLOCKED` at 0 of 16 cubes, crew of two).**
   - The composer tries points two and three cells from the access along each direction. With the first builder
     parked two cells west, the second took the point three cells west, behind it.
   - Its only way to the access runs through the first builder's body. The crew's walk-in froze.
   - **Fix:** `_crosses_taken` refuses a candidate whose straight way to the access sweeps through a taken parking's
     body, and one whose body stands on a taken parking's way. It is an exact integer test, `_sweep_meets`: the
     segment is tested against the Minkowski box, slab by slab, in integer fractions.
2. **Lateral parkings could never be joined (`WORLD_ROUTE_NO_FITTING_PROFILE`).**
   - The claw READY travel rows walk only along their heading (+X in the Kitchen). A span across it is walked on the
     source's canonical ground row (42), whose stance is ±406 u.
   - The parking endpoint's footing was the READY rows' stance alone (−249…274 by −274…299), so the ground row never
     fitted. Every north or south parking span was refused, and the endpoint was left behind unused.
   - So the only parkings ever offered lay on the heading line, which is exactly where defect 1 bites.
   - **Fix:** `_footing` adds the ground row's stance for a lateral point (`_lateral`, `_ground_row`, using the
     itinerary's own compatibility rule). In-line parkings keep their footing unchanged.
3. **A lateral parking in a station chain's way (`ROOM_BUILDER_STALLED` at 6 of 16 cubes, crew of three).**
   - With 2 fixed, the third builder parked two cells north. Its body (±712 u with the ground row) reached the floor
     where the chains to the northern cubes' stations run.
   - Routes held the walking builder ("another body in the way") until the 1,200-tick stall bound. The foreman's own
     footprint check does not see this, because it uses the narrower stance.
   - **Fix:** `_beside_the_way` refuses a lateral parking whose body overlaps the box spanned by the access and the
     room's cell centres, grown by a walking body. This is the body-sized version of `_between`, which tests only the
     root. It is asked of lateral parkings only, so every in-line parking keeps decision 1991's rule.

**Consequences.**

- **One access now parks at most three claw builders clear of each other**: two cells west, two cells south and three
  cells north on the widened Kitchen.
  - A fourth would need a point whose straight way to the access misses three ±712 u bodies standing two or three
    cells out. No such point exists on the floor around one access.
  - So **a named crew of four digs with three, and the fourth is left free** (decision 1991's rule for members beyond
    the access's room). A four-builder dig needs a second access, or a parking that slice D2's way in authors.
- **What changes for earlier digs, and what does not.**
  - In-line parkings keep decision 1991's rule.
  - The composer's lateral points never joined before, so no earlier dig parked on one.
  - The benchmark does not use the composer, so the SHA trace is unaffected.
  - **Before this fix, the composer left lateral endpoints behind.** Every order that reached a lateral point
    published an endpoint with the READY-only footing, then failed its spans. That spent a cold lease each time and
    left the endpoint unused.
    - **Fresh worlds:** such an order now publishes nothing at a point that cannot join, or it joins a lateral point.
      That can matter even for one builder, whose in-line points can all fail `_clear`.
    - **Worlds saved before the fix:** those old endpoints are passed over (`_ground_footed`: their stored support
      lacks the ground row's stance). They are not asked to publish their spans again on every order.
  - **An authored lateral parking** must now also pass `_beside_the_way` and `_crosses_taken`. Fixtures author
    parkings; no production code does. The claw suites' authored second parking passes both.
  - The parking suites pass: composer, parts, occupants, way in, stop, Confirm, Confirm host, claw Kitchen and
    foreman crews.
- **The test:** `test_underground_room_crew_parking.gd`, on the real Confirm route with the widened Corridor (about
  42 s, with its shard weight).
  - A crew of three parks apart and digs the Kitchen 16 of 16 with no refusal, each builder digging.
  - A crew of four digs with three and leaves the fourth free.
  - Unit cases cover the walled-in parking, the sweep's exactness at tangency, the lateral footing and the
    beside-the-way rule.
- **Measured afterwards on the widened Kitchen:**
  - A crew of three takes 4,827 ticks and digs 3, 5 and 8 cubes.
  - A crew of two takes 3,962 ticks.
  - The 2×2 Kitchen never lets two builders earn on the same tick: they take turns at its one face. Concurrent earning
    is measured on the 4×4 room (§10).

## 3. Where the time goes

### 3.1 The room earning tick (light timers, mean a tick)

| Part | `claw1` | `claw2` | `wide1` |
|---|---:|---:|---:|
| `Routes.advance_tick` | 455 | 897 | 625 |
| `Work.tick_solo_into` (one builder earns) | 2,052 | 2,915 | 2,808 |
| - room provider `worker_refusal` | 1,233 | 1,825 | 1,765 |
| - room provider `output_refusal` (CUT only, 0.44 a tick) | 542 | 747 | 701 |
| - itinerary searches inside both (4.2 a tick) | 700 | 1,068 | 1,086 |

Per-tick percentiles (medium timers), `claw1`:

| Part | p50 | p95 | p99 |
|---|---:|---:|---:|
| `Work.tick_solo_into` | 2,053 | 4,297 | 4,756 |
| `worker_refusal` | 1,515 | 1,965 | 2,163 |
| `output_refusal` | 0 | 1,962 | 2,215 |
| itinerary searches | 587 | 2,142 | 2,361 |
| `Routes.advance_tick` | 569 | 702 | 785 |

The p95 and p99 are the CUT phase's ticks. There, `output_refusal` runs `_ordinary_live_contact` again, along with
the output storage path and the live leaves.

### 3.2 Inside the room provider (heavy profile, overhead-corrected, `claw1` earn, µs a tick)

| Function | Inclusive | Calls a tick | What it is |
|---|---:|---:|---|
| `room_world_bindings._ordinary_live_contact` | 907 | 1.4 | re-pin, select, resources, retreat path |
| `room_world_bindings._ordinary_path` → `RoomItinerary.reachability_refusal` | 742 | 4.2 | material, output and retreat paths, every tick, same arguments |
| - `RoomItinerary._find` / `_relax` / `_edge_profile` | 306 / 266 / 200 | | Dijkstra over the live graph (the edge choice is already memoized, decision 1952) |
| - `RoomItinerary._sources` | 166 | | endpoint and section re-reads per proposed edge |
| `room_world_bindings._ordinary_observe_storage` | 606 | 2.8 | storage leaf plus one path each |
| `room_world_bindings._ordinary_live_leaf` | 481 | 1.4 | scope, lifecycle, selected, resource, terrain, worker, occupants, FinalFacts |
| `room_world_bindings._ordinary_binding_leaf` (+ `_original_binding_leaf`) | 263 | 28.9 | identity checks; about 9 µs a call |
| `room_world_bindings.qualification_revision` | 151 | 14.5 | binding leaf again, plus a token sum |
| claw image digest (`claw_program._digest_matches`) | about 125 | 29 | a 32-byte hex-decode compare in every `owns` |

### 3.3 `Routes.advance_tick` per actor

The loop over 512 rows costs about 80 µs a tick (light: `advance_tick` minus `_advance_actor`). Each registered
actor then costs about 0.35–0.45 ms.

| Part | Stationary source, `claw1` | Notes |
|---|---:|---|
| `_qualify_actor_at` | 294 | |
| - `WorldRoutes.actor_admission_refusal` | 186 | 12 endpoint boxes; terrain exclusions read World tiles; 4 occupancy queries |
| - `_source_clock_leaf` and `_source_owner` | 120 | 4 and 12 calls: claw `owns`/`profile_refusal`, each with the digest compare |
| `read_actor_into`, profile queries, clock write | about 60 | |

With two actors, each actor's occupancy queries also read the other's actor, profile and boxes through
`_query_cell`. That takes the stationary re-attestation from about 0.3 ms to about 0.6 ms.

### 3.4 The entry crew and the M5 flight

- **Master's entry prefix.** On ordinary ticks `Routes.advance_tick` averages 1.42 ms a call. 0.65 ms of that
  (3.4 ms a call, on 19% of ticks) is the installer's handling proof:
  - the chain is `_assembly_transition` → `assembly_handling_leaf_refusal` → `Handling.physical_refusal` →
    `qualified-m5-runtime-v1/paw_physical_certificate.gd`;
  - this sets the entry's ordinary p95 of 11.6 ms;
  - it is M5 content, slice D's.

  Entry Work ticks are 8.8 ms at p50, which is Connector Contacts' re-proof (decision 2082, slice D).
- **The M5 flight, ordinary ticks.** `Routes.advance_tick` measures p50 0.60 ms, p95 0.82 ms and p99 1.04 ms
  (mean 0.68 ms). The settlement tick around it measures p50 0.89 ms and p99 1.75 ms. Decision 1954 timed about 60
  functions and metered every check-domain spend inside the hot loops. Without that meter, the 1.6 ms is not
  reproduced. This is the unbatched flight: the batched prototype needs slice D's uncommitted `bb/` harness, so it
  was not rerun.

### 3.5 The idle settlement

With the underground mounted and nothing digging, the underground costs nothing: its two advance calls take 1.3 µs
together. The tick is the surface's:

- `needs.tick_all_staged` is about 95 µs for 12 residents, about 8 µs a resident;
- `_plan_jobs` is 56 µs;
- `_select_jobs` is 25 µs.

Scaled linearly to 256 residents, the needs sweep alone would be about 2 ms. **This is a REQ-SET-163 risk outside
this lane** (§8).

## 4. Constraints every fix keeps

- **The SHA trace** (`tools/benchmark_dig_tick.gd`, `REDWALL_DIG_TRACE`) stays byte-identical. The checkpoints keep
  their save bytes.
- **Spend is outcome** (decision 1953 §6). Every check charged by a skipped computation is charged in full, before
  the same points of failure, and a memo answers only when the remaining budget covers the whole recorded spend.
  Otherwise the live path runs.
- **Every new cache:**
  - is runtime-only and never saved;
  - is cross-checked live while `CacheChecks.enabled` (computed live, answered live, and a differing memo reported
    as `RUNTIME_CACHE_STALE`);
  - is charged through the ADR 1212 census.

## 5. The fixes

### F1 — `Routes.advance_tick`: hoist the loop's invariants and read the row reference inline

**What.**

- The three idle source words compared on every registered row (`_source_word_for(_profiles, PHASE_IDLE, READY)` and
  the two `Assembly.word` values) are computed once before the loop.
- The null test `_resident_ref(row) == NULL_REF` becomes two direct column reads (`R_SLOT == -1 and
  R_GENERATION == 0`).

**Why it is exact.**

- `_source_word_for` depends only on the Profiles bank and its step closure. `_advance_actor` never writes Profiles.
- The `Assembly.word` values are constants.
- The rows visited, and their order, are unchanged, because the column is still read live at each row.
- No spend is involved.

**Expected saving.** About 35–40 µs on every tick on which Routes advances: rooms, the entry and the flight.

**Considered and not proposed:** a maintained registered-row byte index walked with `find(1)`, about 25 µs more. Five
functions write `R_SLOT`:

- `_allocate`
- `_admit_actor`
- `unregister_lost_actor`
- `unregister_resting_actor`
- `_swap_loaded_banks`

`test_dig_tick_equivalences.gd` also pokes `R_SLOT` directly. And its 512 B would go through `packed_memory_bytes`,
which the Routes lane holds.

### F2 — a memo of the whole room itinerary search (P-1952-1 (b), now measured)

**What.** `RoomItinerary._search(actual, first, last, anchor, revision, content)`. With `checks` coming from
`reachability_refusal`, a successful search is remembered in a fixed packed memo on WorldRoutes (32 slots), keyed on:

- **the query:** `first` and `last` as full references, plus `anchor`, `revision` and `content`;
- **the epoch** (the witness key, `WorldRoutes._witness_key_matches`, plus what the search reads beyond it):
  - the Routes graph instance and `_last_published_token` (> 0);
  - the SpaceOwner instance, `_last_published_token` (> 0) and `_header[17]`;
  - the Locations instance and `_last_published_token` (> 0);
  - WorldRoutes' `_certificate_revision`;
  - the Profiles bank instance and load revision;
  - `_live_catalog_revision`;
  - the levels revision.

  `graph._location_capacity`, which the precharge reads, is fixed per graph instance and pinned by it.

**What a hit still runs live:**

- the opening precharge spend;
- both `_reach_stores_refusal` calls;
- `_reach_descriptor`;
- the anchor check (already memoized);
- both `_live_ref` reads.

**What a hit replaces with a replay:** `_find`, `_path_chain_refusal` and `_sources`.

- It spends their recorded total, as one `_spend` when the remaining budget covers it, and only then.
- It writes their recorded scratch effects: `_proposed_count`, `_proposed_edges`, and the five `actual._descriptor`
  fields the last edge choice wrote.
- It advances `_path_serial` exactly as `_find` does.

Only successful searches whose chain fits the slot (32 edges) are remembered. Refusals always run live.

**Why it is exact.**

- **The inputs.** The search reads the live Routes edge bank, WorldRoutes' certificates, live Locations rows, the
  SpaceOwner's live regions and sources (through `_reach_endpoint_refusal` and `_reach_section_refusal`), Profiles,
  the catalog and the levels. Each is written only by a publication or a restore.
  - A publication moves its owner's `_last_published_token`, from a never-reset `_next_token`, or `_certificate_revision`.
  - A restore clears `_last_published_token` to 0, which no slot matches.
  - The same epoch therefore means the same inputs, as the witness already relies on.
- **The spend.** It is a function of the inputs alone. With the budget covering the whole recorded spend, the live
  path cannot fail part way, so its final `_remaining` is `checks - spent` either way. `_operation_error` stays empty.
- **The scratch nobody reads.** `_distance`, `_predecessor`, `_heap_*` and `_search_state` are read outside a
  search only by `_witness_chain_matches`. That runs only when `_witness_serial == _path_serial`, and
  `reachability_refusal` zeroes `_witness_serial` before every itinerary search. The serial advance means no witness
  can match afterwards on either path.
- **The scratch that is read is replayed.** `_proposed_edges` and `_proposed_count` are read later by the builder's
  plan (`_trip_path`, `_plan_legs`) and by Routes' path accessors.
- **The edge memo.** Its slots fill differently on a hit, but that memo is outcome-neutral by decision 1952.

**What phase 2 must prove before relying on it:**

- the full read set of `_find`, `_path_chain_refusal` and `_sources` against the key, with no hidden live input (in
  particular Buildings' room liveness in `_resolve_section_refusal`);
- that no reader of `actual._descriptor` reads the fields a hit does not write.

**Proof in phase 2:**

- live cross-check under CacheChecks: run the replay, keep what it leaves, restore, run live, compare code,
  remaining budget, proposed chain, serial and descriptor;
- the differential and every-budget replay in `test_underground_route_memos.gd`;
- the SHA trace;
- next-checkpoint save/load parity;
- mutation testing.

Tests that edit the graph in place must announce it, as the edge memo already requires.

**Expected saving**, per earning builder, from the measured search costs:

| | Before | After | Saving |
|---|---:|---:|---:|
| `claw1`, mean | 0.70 ms | about 0.15 ms | about 0.55 ms |
| `claw2`, mean | 1.07 ms | | about 0.9 ms |
| `wide1`, mean | 1.09 ms | | about 0.9 ms |
| CUT ticks, p95 | 2.1 ms | about 0.25 ms | about 1.9 ms |

The "after" assumes about 35 µs a hit. After the first tick at a station, every search on that station is a hit
until the next publication.

**Memory (as built).** 32 slots × 27 int64 (6,912 B), 32 chains × 64 int32 (8,192 B) and one 19-word key packet (152 B): 15,256 B. It is runtime-only, charged as a new
census item.

### F3 — the room provider reads its binding once per scope check

**What.** `_ordinary_scope_leaf` calls `_ordinary_binding_leaf()`, and then `qualification_revision()`, which calls
`_ordinary_binding_leaf()` again with nothing in between. `worker_refusal` and `_ordinary_pin` do the same. A new
`_ordinary_bound_revision()` returns `_ordinary_revision_for(...)` and is called where the binding leaf has just
passed. `qualification_revision()` keeps its own check for every other caller.

**Why it is exact.**

- The binding leaf only reads the provider's own references, its owners' references and `_domain`.
- Nothing runs between the two calls in `_ordinary_scope_leaf` and `worker_refusal`. Between the two in
  `_ordinary_pin` there are only writes to `_ordinary_mode`, `_ordinary_valid`, `_entry_*` and `_ordinary_job` /
  `_ordinary_worker`, none of which the leaf reads.
- So the second call returns the same empty code, and no spend is involved.
- **No subclass overrides it.** The internal calls would no longer go through `qualification_revision()`, but no
  subclass of the room provider overrides it, in the game or in the tests. The one test override is
  `SyntheticBindings` in `test_underground_space_authority.gd`, and it extends `Authority.Bindings` instead. The
  Space authority's own calls, and every other external call, still go through `qualification_revision()`.

**Expected saving.** About 11 of the 29 binding-leaf calls a tick, about 9 µs each: about 0.1 ms per earning builder
(a little more on CUT ticks).

### F4 — the claw image digest, remembered against the Profiles load revision (P-1951-3's pattern)

**What.** The claw content programs' `_digest_matches(actual)` hex-decodes `Pins.CLAW_SOURCE_SHA` and compares 32
bytes on every `owns()`:

- `qualified-claw-runtime-v2/claw_program.gd`, which `stair_program.gd` also calls;
- `qualified-claw-runtime-v1/claw_program.gd`.

That is 29 calls a one-builder earning tick and 52 a two-builder tick, about 4.5 µs each. The verdict is
remembered on the Profiles store (`_claw_digest_memo`: token, bank instance, verdict, one pair per program), exactly
as `Routes._step_closure` keeps `ShortStep.uses()`. A loading store, or a zero or saturated token, reads it afresh.
With `CacheChecks.enabled`, it computes live, answers live and reports a difference.

**Why it is exact.**

- The verdict is a pure function of `actual._live.sources`, which changes only through `load_file` (which moves the
  load revision) or an announced in-place edit (`invalidate_runtime_caches()`, which moves it too).
- No spend is involved.

**Expected saving.**

- 0.12 ms on a one-builder earning tick and 0.22 ms on a two-builder tick;
- 0.05–0.1 ms on travel and stationary ticks;
- 0.04–0.06 ms on entry ticks.

The other `_digest(s)_match(es)` helpers (grip, paw, assembly) can take the same memo, but they were not on the
measured hot path. They are not proposed.

### Expected result (from the measured parts; phase 2 measures it)

| Tick | Before p50 / p95 / p99 | After, estimated |
|---|---|---|
| `claw1` earning | 2.04 / 3.93 / 4.38 ms | about 1.3 / 1.7 / 2.1 ms |
| `claw2` earning | 2.80 / 5.14 / 5.49 ms | about 1.8 / 2.1 / 2.4 ms |
| `wide1` earning | 2.95 / 5.31 / 5.94 ms | about 1.8 / 2.5 / 2.9 ms |
| Travel and stationary, per actor | 0.45–0.57 ms | about 0.36–0.48 ms |

**REQ-SET-163 at 1x would then hold for one builder on this Mac** (p95 under 2 ms, p99 at the line), but not for two
or more builders, nor at 256 residents (§3.5). The Mac is not the Ryzen 5 3600 qualification floor.

## 6. Considered and not proposed (they need owner tokens or another lane's files)

- **A whole-verdict cache of the worker and output checks** (P-1952-1 (a)): their live leaves read Transforms,
  Inventory, Gear, the terrain exclusions and occupancy. That needs per-row write tokens on those owners, which
  Brendan deferred ("Later, if needed"). What is left after F1–F4, about 0.6 ms per earning builder, is mostly this.
- **A memo of each actor's stationary re-attestation in Routes** (`_qualify_actor_at`, about 0.3 ms an actor):
  `WorldRoutes.actor_admission_refusal` reads the terrain exclusions (water, resources, Buildings; no revision) and
  live occupancy (Transforms). It has the same token need.
- **Occupant reads shared between one actor's four occupancy queries:** the other actor's `read_actor_into` and
  `_current_profile_into` read Inventory and Gear, which have no tokens.
- **Re-attesting every N ticks:** that changes cadence, which is a rule change (P-1951-4, never proposed).
- **The installer's handling proof**, 3.4 ms a call (`qualified-m5-runtime-v1/paw_physical_certificate.gd`, §3.4),
  and **Contacts' entry Work re-proof**, 8.8 ms at p50: both are slice D's files (§8).

## 7. The functions this lane would edit (for clearance)

| Fix | File | Functions |
|---|---|---|
| F1 | `godot/scripts/core/underground_routes.gd` | `advance_tick` only. It is not on the Routes lane's list, and M5 does not change `underground_routes.gd` |
| F2 | `godot/scripts/core/underground_room_itinerary.gd` (Slice C room file) | `reachability_refusal`, `_search`; new `_search_memo_at`, `_replay_search`, `_remember_search`, `_checked_search` |
| F2 | `godot/scripts/core/underground_world_routes.gd` | new members `_search_memo: PackedInt64Array` and `_search_chains: PackedInt32Array`, declared away from M5's changed member block; `_allocate_scratch` (two `resize` calls). No held function, and no hunk M5 changes |
| F3 | `godot/scripts/core/underground_room_world_bindings.gd` (Slice C room file) | `_ordinary_scope_leaf`, `_ordinary_pin`, `worker_refusal`; new `_ordinary_bound_revision`. `qualification_revision` is unchanged |
| F4 | `godot/scripts/core/underground_profiles.gd` | new member `_claw_digest_memo` (and its line in Profiles' control reserve) |
| F4 | `godot/data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd` and `qualified-claw-runtime-v1/claw_program.gd` | `_digest_matches` |

**Outside them, for the gates only:**

- **Source pins** renewed (`tools/renew_source_pins.py --write`).
- **The ADR 1212 census:**
  - one item for the F2 memo and one for F4's 64 B;
  - `tools/underground_current_census.py`, its test, and `docs/planning/underground_memory_pack.json`, regenerated
    after merging origin/master.
- **The registry rows** in `docs/persistence_state_registry.md`.
- **Tests:**
  - `test_underground_route_memos.gd` (F2's differential and budget replay), or a new suite with a shard weight if it
    would grow past its weight;
  - `test_dig_tick_equivalences.gd` (F1, F3 and F4).
- **Benchmarks:** `tools/benchmark_dig_tick.gd` / `godot/test/bench/` may gain the claw room scenarios used here, so
  phase 2's before/after runs are repeatable.

**Nothing** in Contacts, Locations, SpaceOwner, the geometry journal, the budget, any `underground_entry_*` file,
WorldRoutes' held functions or M5's content.

## 8. Findings for other lanes

- **Slice D (M5 content).** On the entry, the installer's handling proof (`Handling.physical_refusal` →
  `qualified-m5-runtime-v1/paw_physical_certificate.gd` `refusal`) costs about 3.4 ms a call. It runs on about 19%
  of ordinary entry ticks, inside `Routes.advance_tick`, and sets the entry's ordinary p95 of 11.6 ms. Entry Work
  ticks (Contacts' re-proof) are 8.8 ms at p50.
- **The surface (needs, jobs).** The idle settlement's needs sweep is about 8 µs a resident, so about 2 ms at 256
  residents, before any underground work. REQ-SET-163's 2 ms cannot be met at 256 residents while that holds. It
  should be measured on a 256-resident fixture.
- **Four builders on one access (§2a).** One access parks at most three claw builders clear of each other, so a
  crew of four digs with three. A four-builder dig needs a second access, which the composer does not support (one
  access a dig, P-1936-1 (a)), or a parking authored by slice D2's way in. This is the coordinator's call.

## 9. The per-row write tokens (P-1952-1 (a)): scope, for clearance

**Status: scoped, not built.** Brendan's ruling builds them after F1–F4 and the re-measure (§10). Many of the files
are shared with slice D, so the coordinator clears them first.

### 9.1 What the tokens buy

After F1–F4, an earning builder still pays for its own Work re-attestation every tick, and every registered actor
still pays for its own Routes re-attestation. Each re-reads inputs that rarely change between two ticks. The tokens let
two verdict caches answer while every input they read is provably unchanged:

- **The room provider's worker and output verdict.** This is what `worker_refusal` and `output_refusal` prove after
  the (now memoized) searches:
  - `_ordinary_live_contact`, without its paths;
  - `_ordinary_worker_leaf`;
  - `_ordinary_observers`;
  - `_ordinary_live_leaf` (terrain leaf, occupants leaf and the FinalFacts snapshot).

  This is about 0.9–1.1 ms per earning builder per tick measured after F1–F4 (`claw1`: `worker_refusal` 0.90 ms plus
  `output_refusal` 0.34 ms a tick, medium timers, minus the searches).
- **Routes' stationary re-attestation**: `_advance_stationary_source` → `_qualify_actor_at`, `actor_admission_refusal`
  (the endpoint boxes, terrain exclusions and occupancy) and the profile queries. This is about 0.30–0.35 ms per
  stationary actor per tick, and about 0.6 ms when a second actor's body is within reach.

**What is never cached** (cheap, or moving every tick, so it is read live on every answer):

- the actor's source clock (`R_PHASE`, `R_REQUEST_TICK`), which moves every tick;
- the Job's and the Project's `remaining_mwu` and their equality, which Work moves every earning tick;
- the Site's phase and operation columns, the Construction lifecycle columns;
- the cold-lease and scope checks;
- the budget arithmetic. The per-call `_entry_remaining` and `_domain._checks` start full. An answer replays the
  recorded spend and is used only when that spend fits, as F2 does.

**Expected saving** (from the measured parts; an estimate until built):

| What | Saving |
|---|---|
| Per earning builder per tick, on a hit | about 0.8–1.0 ms (1.1–1.3 ms on CUT ticks) |
| Per stationary actor per tick, on a hit | about 0.25 ms |
| Per moving actor | none (its pose changes every tick) |

**Hit rate.**

- With one builder, a miss comes only when something moves within reach of its station or its storage paths: about
  90%+ hits.
- With two to four builders taking turns at one face, every builder walking past the station is a miss for the earner.
  Expect 50–80% hits.

**Projection.** One builder's earning tick goes from about 1.8 to about 0.9 ms at p50, and to about 1.2–1.5 ms at p99.
Two or three builders reach about 1.5–2.2 ms at p99. That would meet REQ-SET-163's 2 ms on this Mac for one or two
builders. It is not a qualification-floor measurement.

### 9.2 The tokens

Every token is runtime-only and never saved, like `Transforms.mutation_revision()` and decision 1951's
Residents, Needs and Directory tokens. Each saturates at the int64 maximum and then reads 0, which permanently disables
the caches keyed on it. Each moves at every write of the columns it covers, including restore, reset and clear.

`CacheChecks` cross-checks every answer live (compute live, answer live, report a difference), as F2 and F4 do.

| # | Owner, file | Token | Covers | Write sites that move it |
|---|---|---|---|---|
| T1 | `godot/scripts/core/transforms.gd` | per-row pose revision `_row_revision: PackedInt64Array` (one per Transforms row) **and** a spatial cell revision grid `_cell_revision: PackedInt64Array` (hashed fixed-size buckets of a ~4 m cell; a pose write moves its old and new cells) | the worker's own pose; every occupant whose reach can meet the work box (the occupants leaf and Routes occupancy both scan every resident, so a per-row token alone is not enough: the verdict depends on who is *not* near) | `place`, `advance`, `set_yaw`, `turn_stationary_preflighted`, `unbind`, `reset`, `restore_columns`, `invalidate_runtime_caches`, and `_mark_mutated` beside them |
| T2 | `godot/scripts/core/underground_routes.gd` | per-actor motion-row revision `_actor_revision: PackedInt64Array[RESIDENT_CAPACITY]`, **excluding** the clock words (`R_PHASE` source subphase/time and `R_REQUEST_TICK`), which are read live | each registered actor's location, edge, job, tool, profile, revision and content columns, read by `physical_selection_into`, `_ordinary_committed_contact`, `_ordinary_worker_leaf`, occupancy | `_admit_actor`, `_set_resident_pair`, `_write_selected_fields`, `_publish_route`, `_pop_route_head`, `_release_route`, `_commit_motion`, `_set_route_phase` (route-phase bits only), `_reset_source_clock`, `request_source_ready`, `hand_over_source_job`, `refresh_work_actor`, `refresh_travel_actor`, `unregister_lost_actor`, `unregister_resting_actor`, `_swap_loaded_banks`, `_allocate`. (`_advance_stationary_source`, `_advance_source_motion_clock`, `_advance_stair_clock`, `_publish_assembly_clock` and `_begin_stair_crossing` write clock words only, or also non-clock words that the build must confirm.) |
| T3 | `godot/scripts/core/inventory.gd` | per-container revision (the spatial and policy columns `_ordinary_storage_row` reads), and per-holder carried-lot revision (tool, cargo and satchel lots that the Profiles selection reads) | the material and output containers' spatial endpoint and policy; the worker's and occupants' carried lots | `_write_new_container`, `_mint_container`, `_destroy_container_checked`, `_free_container_slot_in`, `_clear_container_rows`, `_create_ground_pile_checked`, `_create_spatial_staging_checked`, `_set_anchor_checked`, `_set_reachable_checked`, `_reduce_capacity_checked`, `_retire_empty_pile_in`, `_restore_container`, `_restore_spatial_endpoint`, `_clear_spatial_endpoint_in`, `_clear_spatial_endpoints`, `promote_to_ground_pile`, `promote_to_spatial_ground_pile`, `_allocate_container_columns`, `_allocate_spatial_arena`; plus every lot move, split, merge or consume that changes a lot's holder (to be enumerated by a write-site test, as decision 1951 did for its counters) |
| T4 | `godot/scripts/core/gear.gd` | per-row revision | the equipped tool's owner, claim, equip state and durability | `_write_new_row`, `_publish_row`, `_blank_row`, `_free_row`, `_apply_equip`, `_apply_unequip`, `_set_durability`, `claim_for_job`, `_release_claim`, `set_owner`, `clear_owner`, `clear`, `restore_row`, `_allocate_columns` |
| T5 | `godot/scripts/core/work.gd` | per-resident tool-binding revision | `_tool_lot_*`, `_tool_job_*` | `claim_tool_for_work`, `_clear_tool_binding`, `clear`, `_allocate_columns` |
| T6 | `godot/scripts/core/jobs.gd` | per-job-row and per-agent revision, **excluding** `_remaining_mwu` (read live) | kind, coordinator, worker, requester, tool gate, agent job and persistent id | `_write_new_job_row`, `_clear_job_row`, `_clear_job_columns`, `destroy_job`, `make_coordinator`, `spawn_agent`, `despawn_agent`, `_clear_agents`, `_rebuild_persistent_ids`, the restore path (`_worker_slot = columns...`), and the assignment and tool-gate writers (`_tool_gate` writes near lines 915 and 980; the worker assignment helper), to be enumerated by the write-site test |
| T7 | `godot/scripts/core/resource_nodes.gd` | a revision (global, or per tile) | the terrain leaf's `_local_resource` (stock and identity "visible immediately, even with an unchanged sparse revision") | `_write_created_row`, `harvest_into`, `regrow`, `destroy`, `clear`, `_allocate_columns` |
| T8 | `godot/scripts/core/buildings.gd` | a footprint and room revision | the terrain leaf's `_local_building` footprints; the section Room facts F2 re-reads (`_r_*`) | `_write_room_row_preflighted`, `publish_spatial_room_preflighted`, `_retire_room_row`, `_clear_room_columns`, `_allocate_room_columns`, `restore_section_1_columns`, and every footprint writer (to be enumerated) |
| T9 | `godot/scripts/core/world_init.gd` | none needed | terrain kinds are written only by `_allocate_columns`, `_reset_published` and `section_1_published_seed`, so the World instance and its published seed identify them | — |

Residents (`identity_revision`), Needs (`life_revision`), Directory (`mutation_revision`), Profiles (load revision),
SpaceOwner, Locations and Routes (publication receipts) and WorldRoutes (`_certificate_revision`) already carry tokens.

### 9.3 The consumers

| File | Functions | Change |
|---|---|---|
| `godot/scripts/core/underground_room_world_bindings.gd` (Slice C) | `worker_refusal`, `output_refusal`; new `_verdict_key_into`, `_verdict_memo_at`, `_replay_verdict`, `_remember_verdict`, `_checked_verdict` | Answer the verdict's slow part from a per-binding memo keyed on: T1 (worker row and the cells of the work box's and occupant reach), T2 (worker and every registered actor in those cells), T3–T8, the existing tokens, and the call's arguments. The cheap leaves listed in §9.1 run live |
| `godot/scripts/core/underground_world_routes.gd` | `actor_admission_refusal` (not slice D-held; M5 changes nearby hunks) | The same key over the actor's endpoint boxes, terrain exclusions and occupancy |
| `godot/scripts/core/underground_routes.gd` | `_advance_stationary_source`, `_qualify_actor_at` | Use the admission memo. The clock step and its checks stay live |
| `godot/scripts/core/underground_terrain.gd` | `exclusions_refusal`, `_local_refusal` (read only) | Expose the T7/T8 tokens it reads; no behaviour change |
| Census and registry | `tools/underground_current_census.py`, its test, `docs/persistence_state_registry.md`, the memory pack, `ready07_arithmetic.py`, `docs/systems_architecture.md` | About 4 KB per-row tokens on Transforms (it has 512+ rows; the exact count is set by its capacity), 32 KB cell grid, 4 KB Routes, Inventory/Gear/Jobs per-row columns at their capacities, and the two memos (estimated 30–60 KB in all) |

### 9.4 Risks and proof

- **Write-site completeness is the whole risk.** A write that forgets its token gives a stale answer. Two defences:
  - every token gets a write-site test that pokes each covered column through each public writer, as decision 1951
    did for Residents, Needs and Directory;
  - `CacheChecks` cross-checks every answer live in the whole suite, so a missed site fails the suite that exercises
    it.
- **Tests and other lanes' code that write these columns directly**, outside their owner, must announce the edit
  (`invalidate_runtime_caches()`, or a token bump), as the edge memo already requires. One is known already:
  `underground_connector_delivery.gd` writes `Jobs._remaining_mwu` directly. That column is read live, so it needs no
  token, but the build lane must grep for every such direct write.
- **Proof:** the SHA trace byte-identical; checkpoints with identical bytes; next-checkpoint save/load parity; the
  differential tests; mutation testing; the full suite with `CacheChecks` on.
- **Size:** about 1,500–2,500 changed lines across about twelve files. Transforms, Inventory, Gear, Work, Jobs,
  ResourceNodes, Buildings, Routes and WorldRoutes are all shared with slice D or the surface lanes.

## 10. F1–F4 measured (alternating rounds)

**Method.** The base is `fe85b96a`: master plus the §2a parking fix, which every three-builder scenario needs. The
after case is `6f705a0e` (F1–F4). The same scratch scenarios as §1 were run, plus the committed dig benchmark, in
three alternating rounds (base, after; after, base; base, after) on the development Mac. The load average was 6–21
during the rounds, so read the means of the rounds rather than any one round. The table gives the mean of the three
rounds' p50, p95 and p99, in microseconds, ordinary ticks only:

| Scenario, tick | Before p50 / p95 / p99 | After p50 / p95 / p99 | Change |
|---|---|---|---|
| `claw1` (1 builder), earning | 2,094 / 4,108 / 4,766 | 1,612 / 2,454 / 2,985 | −23% / −40% / −37% |
| `claw1`, travel | 551 / 645 / 763 | 480 / 541 / 605 | −13% / −16% / −21% |
| `claw1`, stationary | 457 / 553 / 637 | 384 / 443 / 510 | −16% / −20% / −20% |
| `crew2` (2 builders, the real Confirm route, widened Corridor), earning | 2,881 / 5,563 / 5,915 | 2,250 / 3,170 / 3,667 | −22% / −43% / −38% |
| `crew2`, travel | 873 / 992 / 1,096 | 753 / 878 / 962 | −14% / −11% / −12% |
| `crew3` (3 builders), earning | 3,103 / 5,700 / 6,014 | 2,490 / 3,360 / 4,098 | −20% / −41% / −32% |
| `crew3`, travel | 891 / 1,084 / 1,274 | 786 / 958 / 1,106 | −12% / −12% / −13% |
| `big2` (2 builders, 4×4 room), earning | 2,931 / 5,737 / 6,104 | 2,223 / 3,093 / 3,841 | −24% / −46% / −37% |
| `entry` prefix (live settlement), ordinary | 789 / 10,615 / 12,888 | 711 / 10,419 / 12,546 | −10% / −2% / −3% |
| Benchmark `room1` (content 6), earning | 2,326 / 3,600 / 4,019 | 2,104 / 2,972 / 3,275 | −10% / −17% / −19% |
| Benchmark `entry1`, foreman tick | 597 / 10,412 / 14,649 | 533 / 10,349 / 13,096 | −11% / −1% / −11% |

**What moved.**

- **The CUT ticks fell the most.** The output check's repeated searches are now memo hits, which takes 32–46% off
  the earning p95 and p99.
- **The searches are cheaper but not free.** A first run with temporary counters measured 94% of searches answered
  from the memo (3,872 of 4,104 on `claw1`). An answered search costs about 76 µs, against about 167 µs. Of that,
  `WorldRoutes._reach_stores_refusal`, the store and binding check run at both boundaries of every query, is about
  41 µs. It is not in this lane's cleared functions.
- **Every Routes tick is about 30–70 µs cheaper**, from F1 and F4's digest memo.
- **The content-6 benchmark gains less.** Its searches take WorldRoutes' automatic-row path, which its witness already
  memoizes, so F2 does not apply there.
- **The entry is set by slice D's costs:** the handling proof and Contacts' re-proof (§3.4).
- **Cold ticks were unchanged** in the clean rounds (−3% to +2%).

**Where REQ-SET-163 stands.** The 2 ms simulation tick at 1x (p99) is still missed.

- One earning builder is at 1.6 / 2.5 / 3.0 ms. That is better than §5's estimate at p99 (2.1 ms) and worse at p50
  (1.3 ms): the answered search's fixed cost is larger than estimated.
- Two or three builders are at 2.2–2.5 ms p50 and 3.7–4.1 ms p99.
- What remains is the work §9's tokens cache: the worker and output live leaves, about 1 ms per earning builder, and
  Routes' per-actor re-attestation, about 0.35 ms an actor.

**Exactness (F1–F4).**

- **SHA trace:** byte-identical to master `e0e7065a`, for room1's 7,988 lines and entry1's 3,464 lines.
- **Checkpoints:** regenerated with the same bytes (every `.rwlsave.gz` is identical; only the two manifests moved).
- **Live cross-checks:** with CacheChecks on, `test_underground_route_memos.gd`, `test_underground_room_search_memo.gd`
  and `test_underground_claw_digest_memo.gd` pass, as does every suite in the full run (§11).

## 11. Gates (F1–F4 and the parking fix)

**Branch.** `perf/steady-tick`. `origin/master` has not moved since this lane's base `e0e7065a`, so no merge was
needed.

**Full suite.** After `rm -rf godot/.godot` and a fresh import (exit 0), `./tools/run_tests_parallel.sh` ran master's
12 shards:

- 13,204 tests, 1,572,660 assertions, 0 failures;
- 0 unexpected errors or warnings and 0 leaks;
- 579 suite files, each executed exactly once.

A first run failed in five shards. They had loaded stale checkpoints after the review fix to
`underground_room_parking.gd`. The checkpoints were regenerated (the same save bytes as master), and the run above
followed.

**Analyzer.** `tools/gdscript_warnings.py --max 0 --port 6443`: 0 warnings in 1,676 files.

**Decision numbers.** `decision_numbers.py` passes.

**CI contracts.** Every Python step of `.github/workflows/tests.yml` that needs no Godot was run: 46 pass. The one
failure is the CI aggregation step, which reads `SHARDS_RESULT`, a variable only GitHub Actions sets.

**Memory (ADR 1212).**

- +15,256 B new retained (`world_routes_search_memo`). The digest memo's 48 B are inside Profiles' `CONTROL_RESERVE`.
- One live world plus reserve: 106,121,366 → 106,136,622 B.
- Headroom below the 150 MB gate: 43,878,634 → 43,863,378 B.
- With decision 1880's painted-room budget folded in, the headroom is 26,905,938 B, and 3,640,658 B are left for
  slice G.

**Exactness.** Covered in §10:

- the SHA trace is byte-identical to master;
- the checkpoints keep their exact save bytes;
- live CacheChecks run across the full suite.

**Independent review.** A `code-reviewer` subagent reviewed `e0e7065a..a193a848`. It found no equivalence break in
F1–F4 and no CRITICAL or HIGH item. It fuzzed a port of `_sweep_meets` against brute force: 200,000 cases, 0
mismatches. Its MEDIUM and LOW items, and how each was handled:

| Severity | Finding | Handling |
|---|---|---|
| MEDIUM | Lateral endpoints left by the pre-fix composer stay unjoinable and are retried every order; §2a overclaimed "unchanged" | Fixed: `_ground_footed` passes them over; §2a now states both effects |
| MEDIUM | The second sweep clause of `_crosses_taken` was untested | Fixed: a candidate two cells west against a taken parking three cells west |
| MEDIUM | Two tangency mutants of `_sweep_meets` survived | Fixed: start-touching-moving-away and low-side tangent cases |
| MEDIUM | F2's tests missed key words, query words and per-edge sections | Fixed: geometry, catalog and levels pokes; first and last generations, revision and content; an edge's and a reached endpoint's dead section |
| MEDIUM | Promised proofs and §9 were missing | Fixed: §9, §10 and this section; F3 has a direct test |
| LOW | `_crosses_taken` read a dead taken ref | Fixed: skipped, with a test |
| LOW | Default arguments; non-quarter-turn yaws; int64 bound; doc slips | Fixed: explicit arguments and documented behaviour; "all six"; the key text and size; the north/south wording |
| LOW | F1 changes the count of CacheChecks step-closure reports, not outcomes | Kept: diagnostics only |
| LOW | Authored lateral parkings now face the new rules | Documented in §2a |

**Mutation testing.** 34 mutants were run against the focused suites; 31 were killed. Six survived the first pass;
tests were added, and three of those six were then killed. The three that still survive:

- **`P10`**, `_ground_row` with no policy test: equivalent for content 12. The first certified all-yaw WALK row
  compatible with the claw READY rows is row 42, the canonical ground row.
- **`R01`**, F1's free-row test on the slot alone: equivalent in every reachable state. An unregistered row is always
  (−1, 0): `ACTOR_NULL_FIELDS`, `_allocate` and both unregister functions write both words.
- **`R03`**, F1 no longer skipping the `HANDLED_READY` idle word: this condition was carried over unchanged from
  master. No suite (Routes, world phases, foreman, paid assembly handling or install) has an actor idle in that word
  at a Routes tick. It is a pre-existing coverage gap, not new code.

## Source

- REQ-SET-163 (`docs/game_gdd.md`); decisions 1951, 1952 (P-1952-1 and its ruling), 1953 §6–§7, 1954 §3.3, 1942,
  1943, 1939.
- Scratch, never committed:
  - logs and data in `scratchpad/st/`: `clean1`, `light1`, `med1`, `heavy1`, `m5flight`;
  - scripts in the same place: `prof_patch.py`, `zz_prof.gd`, `zz_steady_room.gd`, `zz_steady_host.gd`,
    `analyze.py`, `light_sum.py` and `watch_pct.py`.
