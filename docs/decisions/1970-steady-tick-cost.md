# 1970 — Steady-tick cost: where an ordinary underground tick goes, and the exact fixes (phase 1)

Date: 2026-10-21 · Status: **Proposed (phase 1: measured and named; nothing built).** The functions to edit (§7) wait
for the coordinator to clear them.

Lane STEADY-TICK (Slice C), branch `perf/steady-tick`, cut from master `e0e7065a`. Decision number 1970 is this
lane's. Analyzer port 6443.

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

**Three and four builders cannot be measured on any fixture today. This is BLOCKED.** With a third or fourth claw
mole parked in the Corridor:

- the Kitchen stops with `ROOM_FOREMAN_CREW_BLOCKED` at cube 5;
- the 4×4 room stops at cube 16 with three builders;
- with four builders it stalls (`ROOM_BUILDER_STALLED`, then `ROOM_BUILDER_STUCK_UNDERGROUND`).

Before blocking, three builders' 250 earning ticks measured p50 3.4–3.7 ms. The cost is per builder: each earning
builder adds about 0.7–1.1 ms of Work, and each registered actor adds about 0.35–0.45 ms of Routes. So four
builders earning at once would cost roughly 2.5 ms plus 3 × (0.8 + 0.4) ms, about 6 ms before the fixes and about
3.5 ms after.

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
  - the levels revision;
  - `graph._location_capacity`.

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

**Memory.** About 32 × (128 B key + 48 B replay + 256 B chain), about 14 KB. It is runtime-only, charged as a new
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
- **Fixtures.** No fixture can hold three or four claw builders today (§2, BLOCKED). C3 or a test lane would need a
  Corridor with room for four parkings that do not freeze the crew.

## Source

- REQ-SET-163 (`docs/game_gdd.md`); decisions 1951, 1952 (P-1952-1 and its ruling), 1953 §6–§7, 1954 §3.3, 1942,
  1943, 1939.
- Scratch, never committed:
  - logs and data in `scratchpad/st/`: `clean1`, `light1`, `med1`, `heavy1`, `m5flight`;
  - scripts in the same place: `prof_patch.py`, `zz_prof.gd`, `zz_steady_room.gd`, `zz_steady_host.gd`,
    `analyze.py`, `light_sum.py` and `watch_pct.py`.
