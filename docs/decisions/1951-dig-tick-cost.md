# 1951 — Dig-tick cost: a benchmark, four exact speed-ups, and what still exceeds REQ-SET-163

Date: 2026-10-15 · Status: Accepted for the engineering changes; P-1951-1 to P-1951-4 are proposals awaiting Brendan.

Lane DIG-TICK-COST, branch `perf/dig-tick-cost`. It was ruled by Brendan on 2026-10-12 as P-C2-2 (a) of decision 1931
("a separate cost lane ... fixes the 6.4 ms per working tick the excavation owners cost"), with **no rule changes**.
On 2026-10-15 Brendan chose "Real digging, in full" for slice C, and the lane resumed. Decision numbers 1951–1969 were
allocated to this lane by the coordinator and checked free. This is the lane record. Decision 1931 is cited from
commit `a0da1dce` on `feat/room-foreman-slice-c2`, so it is not on this branch.

## Decision

1. **A repeatable benchmark is committed:** `tools/benchmark_dig_tick.gd`. Its two suites live under `godot/test/bench/`,
   which the test runner does not discover, so CI never pays for them.
2. **Four changes make the excavation owners cheaper without changing any result.** Each reads the same inputs and
   returns the same answer as before:
   - The unregistered-occupant scan is answered from a snapshot, keyed on four owners' revisions.
   - The SpaceOwner region and source scans walk only the rows that are present.
   - Digests are compared as 64-bit words.
   - The step-program closure is read once per source check.
3. **Behaviour is proved tick for tick.** A SHA-256 over every owner the benchmark drives, taken every tick, is
   byte-identical before and after on both benchmarks. The test checkpoints keep their exact save bytes.
4. **The result is still well over budget.** The 2 ms simulation tick at 1x and the removal of the phase stalls cannot
   be reached without changing either attestation designs that other records fix (ADR 1205, the provider contracts) or
   the tick cadence. The four proposals below give the options.

## 1. The benchmark

Run it from the repository root:

```bash
REDWALL_DIG_REPORT=<file> [REDWALL_DIG_TRACE=<file>] [REDWALL_DIG_BENCH=room|entry] \
    godot --headless --path godot --script "$PWD/tools/benchmark_dig_tick.gd"
```

It runs through the test runner's own supervisor, so a script error still fails the run. Each suite prints lines of
the form `DIG-BENCH <label> <series> n= p50= p95= p99= max= sum=`, in microseconds, and appends them to the report.
`REDWALL_DIG_TRACE` adds one SHA-256 per tick over every owner's capture or `state_bytes()`, plus the event outcomes.
Take timings from untraced runs, and compare the traces of two revisions with `cmp`.

| Suite | What it runs | Timed |
|---|---|---|
| `bench_dig_room_loop.gd` (`room1`) | ADR 1213's whole-Kitchen loop on the content-6 `StepFixture`: 8 cubes, one builder, 3,905 ticks, exact ledgers asserted | `Routes.advance_tick` and `Work.tick_solo` per tick; the one-tick events (contact selection, phase open, START, settlement, handoffs, turns) |
| `bench_dig_entry.gd` (`entry1`) | The live settlement (generated world, mounted underground) from the surface walk to the end of the entry prefix: 3,462 ticks, 12 residents, `DONE_TICK` and `DONE_LEDGER` asserted | `UndergroundEntryRuntime.advance` (what `_advance_underground_entry` calls) and the whole `run_tick`; foreman ticks of 20 ms or more are listed as stalls |

**Four builders cannot be measured on any fixture today.** The room fixture has one worker and one contact path, and
the multi-builder room foreman is C2.1's work. The cost is per actor: Routes advances each registered actor, and Work
ticks each Job. Four builders therefore cost about four times the per-builder rows below, plus whatever extra
occupancy queries their mutual proximity adds.

## 2. Where the time went (profile, before)

A scratch profiler, never committed, wrapped every top-level function in the underground, excavation, Work, Jobs,
Construction and Inventory scripts with inclusive and exclusive timing. Findings, in order of cost:

- **The unregistered-occupant scan.** `Routes._unregistered_occupants` ran over all 512 resident rows on every
  occupancy query. A stationary actor's endpoint attestation (`WorldRoutes._endpoint_box_refusal`, one query per
  profile box) makes about ten queries a tick. This was about half of `Routes.advance_tick`, which costs the same on
  travel and earning ticks. Its cost grows with population.
- **The step-program closure.** `ShortStep.uses()` re-verifies, on every call, the appended handling row's
  descriptor, its 70 box words and two image digests through `Assembly.uses()`, at about 25 µs a call. Routes called
  it up to three times per actor source check, about 50,000 times per room run.
- **SpaceOwner scans.** `_claims_refusal` and `_sources_refusal` walked every region and source row, nearly all of
  them absent, about 7,600 times per room run.
- **Digest loops.** The entry Frontier's seven-way 32-byte loop ran 125,000 times per entry run, and the source facts'
  loop 178,000 times.
- **Not changed by this lane (§5):**
  - The per-tick provider re-attestation inside `Work.tick_solo`.
  - The per-phase route-edge requalification behind START and settlement.

## 3. What changed

| Commit | Change | Why it is exact |
|---|---|---|
| `f263a850` | **Unregistered standing snapshot.** Each present row's standing does not depend on the query box: absent or dead (nothing), STALE or UNBOUND (a refusal), or placed at a root. It is read once into `_standing_x`, an `(x << 10) \| row` packed column sorted by root x, plus `_standing_refused` in row order. A query binary-searches the rows whose reach cube can meet its x range, then tests y and z. | Every placed row gives the same code, so only one question matters: does a reaching row exist before the first unskipped refusal in row order? The registered and excepted skips are read live for each candidate. The 16-per-row budget charge is unchanged. A saturated (zero) revision answers by the original scan. |
| `c4d0188f` | SpaceOwner scans walk present rows with `PackedByteArray.find(1)`. | This path is taken only when `count(0) + count(1) == size`. Otherwise every row is visited, so a corrupt presence byte (2) is still checked exactly as the scan did. |
| `c4d0188f`, review fix | The entry Frontier's seven digest equalities, and the source facts' two, are compared with `decode_u64` (four words, no allocation), through one helper, `SourceFacts._same_words`. | This path is taken only when every range exists; otherwise the original byte loop runs. Equal words if and only if equal bytes. |
| `c4d0188f` | `ShortStep.is_short()` (pure, constant-time) is tested before `ShortStep.uses()` (pure) in five conjunctions. `uses()` is skipped where `ShortStep.mapped()` leaves the row unchanged. | Both are pure and total, so `A and B` equals `B and A`. Where the row maps to itself, both branches yield the same row. |
| `13a742a6`, review fix | The profile check and the clock check call `ShortStep.profile_refusal()` first, and read `uses()` again only after a refusal. Handling, stair and claw rows keep their own proof and clock in `_owned_clock_leaf`; the review fix reads the owner once (`_source_owner`, the same first-match order as `_source_profile_refusal`) instead of three times. | `ShortStep.profile_refusal()` begins `if not uses(actual) or ...: return ROUTE_SOURCE_PROFILE`, so a pass proves the closure. After a refusal, the closure decides between the step and the parent program exactly as before. |

### The caching choice: revision counters

The coordinator allowed either revision counters on Residents, Needs and Directory, or input-value comparison, and
asked for counters where they change no rule, outcome or saved byte. **Counters were chosen.** Value comparison
cannot be cheap for these inputs. The Directory's six columns hold 352,418 rows each. "Alive" is `health > 0`, which
no packed compare expresses. Re-reading the per-row identity words to validate a snapshot costs as much as the scan
it would save.

| Owner | Token | Moves on |
|---|---|---|
| `residents.gd` | `identity_revision()` | allocate, `_clear_identity_columns`, `_clear_reference_columns`, `_write_spawn_row`, `despawn`, `_install_columns` (restore): every write of `_present`, `_ref_slot`, `_ref_generation` |
| `needs.gd` | `life_revision()` | allocate, `clear`, `_write_spawn_row`, `_despawn_checked`, `_install_columns`, and a health write that crosses zero (`_apply_health_event_checked`, `_integrate_health`) |
| `entity_directory.gd` | `mutation_revision()` | `_publish_row` (every create), `destroy`, `clear`, `_allocate_columns`, `_fill_owner_map`, `_install_columns` |

How the tokens behave:

- Each token is runtime-only, like Transforms' existing `mutation_revision()`. It is never saved or hashed and is
  excluded from `state_bytes()`, which the tests assert.
- Each saturates at the int64 maximum and then reads 0, which permanently disables the snapshot.
- The snapshot key is these three tokens, plus Transforms' `mutation_revision()` (which Routes already trusts for its
  occupancy index), plus the four owners' instance ids.
- A grep of `godot/scripts`, `godot/demo` and `godot/test` found no write to these columns outside their own owner, apart from tests that poke them and restore them before any occupancy query: the Directory's own batch tests and the workpieces test set a non-resident slot's generation, and `test_underground_final_facts.gd` sets a Resident's Transforms binding and Directory row and restores both. A future test that pokes these columns and then queries occupancy must move the owner's token too.

The snapshot's columns use 6,208 B of the 16,384 B that two write-only Routes columns held: `_occupancy_bounds` and
`_occupancy_profile`, written at admission and never read. Those two columns are removed. The Routes arena formula
`48 * RESIDENT_CAPACITY` is unchanged, so `configure`'s admission and the memory census's grep of it are unchanged.
The five occupancy columns now hold 32 B a row plus the 64 B key (16,448 B) against its 24,576 B: 8,128 B of slack.
Before this lane they held 52 B a row (26,624 B), 2,048 B more than the formula reserved, because `_occupancy_visit`
was never in it. The two new int counters are charged to Routes' `HEADER_RESERVE`.

## 4. Behaviour proof

- **Tick-for-tick trace.** `REDWALL_DIG_TRACE` hashes the following, every tick:
  - Sites, Work, Jobs, Inventory and Construction `state_bytes()`;
  - the Routes, WorldRoutes and Locations captures;
  - in the entry run, every store `_snapshot()` covers, both route images and the entry runtime's record.

  Event lines (phase opened, settled, loop step, final ledger) are written in order with them. The trace is 7,433
  lines with 7,367 distinct per-tick hashes. A control run of the unchanged baseline reproduced it byte for byte.
  **After each of the four steps the trace is byte-identical to the baseline** (`cmp`).
- **Save parity.** `./tools/regenerate_test_checkpoints.sh` was rerun after each step. Both checkpoints'
  `.rwlsave.gz` save bytes are unchanged; only the source-fingerprint manifests move.
- **Oracles in the suite.** Each oracle is a verbatim copy of the replaced code, and the new code must agree with it:
  - `test_underground_route_standing.gd`: ADR 1219's scan, against randomized spawns, moves, deaths, despawns, stale
    Needs rows, registered rows, excepted workers, half-open faces on every axis and poisoned revisions; plus every
    revision-counter write site.
  - `test_underground_route_source_checks.gd`: the pre-1951 `_source_profile_refusal` and `_source_clock_leaf` over
    every row, revision, content, phase word and clock, of content 6 and of the mounted content 10 (claw, stair and
    handling rows), with the step closure whole and broken.
  - `test_dig_tick_equivalences.gd`: the present-row walk against `!= 0` scans (including non-binary columns); both
    digest compares against their byte loops at every byte; SpaceOwner rows that are unclaimed, absent or non-binary
    in both banks.

## 5. Results

Back-to-back runs, alternating baseline (`c09f9297`, the merge with the benchmark and nothing else) and after
(`13a742a6`). Three rounds each, on Brendan's Mac (Apple Silicon), headless editor binary, load average 4.6–11.8
while other lanes ran. The table gives the median of the three rounds' p50 (and p95 or max where stated). This is
not the qualification floor (Ryzen 5 3600), and the numbers are for scale.

| Room loop, one builder | Before | After | Change |
|---|---:|---:|---:|
| Travel tick p50 (Routes) | 1,959 µs | 718 µs | −63% |
| Earning tick p50 (Routes + Work) | 6,988 µs | 5,090 µs | −27% |
| — `Routes.advance_tick` while earning | 1,901 µs | 784 µs | −59% |
| — `Work.tick_solo` | 4,942 µs | 4,212 µs | about −15% (noise-level) |
| Earning tick p99 | 14,909 µs | 12,826 µs | −14% |
| START p50 / max | 111 / 166–187 ms | 71 / 106–134 ms | −36% |
| Settlement p50 / max | 116 / 190–212 ms | 75 / 120–153 ms | −35% |
| Phase open p50 | 22.0 ms | 18.9 ms | −14% |
| Contact selection p50 | 7.7 ms | 7.4 ms | — |
| Whole run (wall) | 17.5–19.1 s | 9.7–12.0 s | −40% |

| Entry prefix, 12 residents | Before | After | Change |
|---|---:|---:|---:|
| Foreman tick p50 | 1,451 µs | 696 µs | −52% |
| Foreman tick p95 | 18,120 µs | 14,509 µs | −20% |
| Foreman tick p99 | 22,619 µs | 18,062 µs | −20% |
| Ticks of 20 ms or more | 149–231 | 29–117 | −80% (rounds 1–2) |
| Their total | 22.2–26.3 s | 14.8–20.1 s | −33% |
| Worst tick | 1.01–1.11 s | 0.79–0.94 s | −22% |
| Whole run (wall) | 38.7–43.0 s | 28.8–35.9 s | −25% |

## 6. What still exceeds the budget, and whose code it is

REQ-SET-163 allows about 2 ms for the whole simulation tick at 1x (p99), and 6 ms per render frame at 4x. The after
column above is still several times over for the following reasons.

1. **The per-tick provider re-attestation inside `Work.tick_solo` (room: about 4.2 ms per builder).**
   - The call path is `Sites.work_tick_refusal`, then `_worker_refusal` and `_productive_refusal`/`_output_refusal`,
     into the spatial authority's provider. The provider's contract reads "Productive Work always reattests the actual
     worker, full motion, tool/cargo, current routes and local facts" (`underground_room_world_bindings.gd`
     `worker_refusal`).
   - For rooms that file is C2.1's: `_ordinary_live_contact`, `_ordinary_path`, `_ordinary_observers` and
     `_ordinary_live_leaf`, together about 5.8 ms instrumented per call. **This lane did not edit it.**
   - For the entry path the provider is `underground_entry_world_bindings.gd`, plus Connector Contacts and Work.
     There `Work.tick_solo` costs 7–21 ms per call during installs.
2. **Per-phase route-edge requalification (room START/settlement about 70 ms; entry stalls up to 0.8 s).**
   - The call path is `SpaceAuthority._prepare`, then `prepare_companions` and `ConnectorPlacements._phase_prepare_routes`,
     then `Routes.stage_refresh` for every published edge, then `WorldRoutes._compile_profiles` for every profile.
   - ADR 1205 carries an edge's admitted profiles when no change meets their sweeps. It still **fully re-proves every
     profile the live certificate refused**, because surface exclusions carry no revision, and it always fully
     re-proves source rows 2 and 6. Most of the remaining stall is those re-proofs: `_solid_contacts_covered`,
     `_body_covered` and `_body_blocked` scanning every volume row, about 1.3 million box reads and 2.2 million overlap
     tests per entry run.
3. **Content source-closure checks.** `ShortStep.uses()`, through `Assembly.uses()`, still runs about once per
   `_source_word_for` and once per source check, about 25 µs each. That is about 0.2–0.3 ms of the remaining Routes
   tick. The fix belongs in the content program (`data/underground/mole-worker/*/source_program.gd`, the M3 lane's
   area) or in a Profiles load revision; both are pinned consumers.
4. **Population scaling of the per-actor re-checks.** At 256 residents the snapshot still costs one full rebuild per
   tick in which any pose changes (surface residents walk every tick): about 256 row reads. The other per-row loops do
   not yet use the snapshot:
   - Connector Contacts `_occupancy_leaf`;
   - Delivery `_occupants_leaf`;
   - `WorldRoutes.workpiece_occupancy_refusal`.

   Each of them still visits all 512 rows per call. They can adopt it exactly (§8).

## 7. Proposals for Brendan

**P-1951-1: the per-tick provider re-attestation (§6.1).**

- **(a)** Make productive Work's re-attestation event-driven. The provider would cache its worker and contact verdict
  keyed on a revision vector covering every input it reads: Space geometry, Locations, Routes actor rows, Transforms,
  gear/cargo and Jobs. Each owner would expose a write token, as this lane did for Residents, Needs and Directory. No
  rule changes: the same guard runs whenever an input changes. This is a provider contract change in C2.1's file
  (rooms) and the entry provider, so it would be its own lane after C2.1 lands, with this lane's trace method as its
  proof.
- **(b)** Keep re-attesting every tick, and accept about 4 ms per builder.
- **(c)** Re-attest every N ticks (a cadence change, which is a rule change).

**Recommendation: (a).** It is the only option that meets REQ-SET-163 for four builders without changing a rule.

**P-1951-2: the phase stalls (§6.2).**

- **(a)** Extend ADR 1205's carry to refused profiles. This needs a revision on the surface exclusions (water,
  resources, Buildings), which today carry none. A refusal would then carry when nothing that changed meets its
  sweeps. This is an amendment to ADR 1205's design in Routes/WorldRoutes and in the World facts owner.
- **(b)** Spread one phase preparation over several ticks (a budgeted cold operation). This removes the stall but not
  the cost, and it changes when a START or settlement completes: the phase is not open until the preparation finishes,
  so this is a timing change for ARCH-SYS order.
- **(c)** Index the proof image's volume rows spatially, so that `_solid_contacts_covered`, `_body_covered` and
  `_body_blocked` read only overlapping rows. Skipped rows' proof spends would be charged in bulk, in the same order.
  This is exact, but a large change in the most heavily reviewed code.

**Recommendation: (c) then (a).** (c) changes no outcome and is in this lane's files; (a) removes most of the
remaining work.

**P-1951-3: the content closure check (§6.3).**

- **(a)** Give Profiles a load revision (it changes only on `load_file`, and tests that poke `_live` already restore
  it). `Assembly.uses()` and `ShortStep.uses()` would then remember their verdict for that revision.
- **(b)** Leave it as is.

**Recommendation: (a)**, done in the M3 lane or after it, because the content programs are that lane's files.

**P-1951-4: cadence (ARCH-SYS order).** If P-1951-1 (a) is not wanted, the remaining lever is a different cadence
for underground work: earn work units every N ticks with N times the work. That is a rule change and is not proposed
by this lane.

## 8. Findings for other lanes (the coordinator merges; this lane did not edit them)

- **C2.1 (`underground_room_world_bindings.gd`).** `worker_refusal` and `output_refusal` are about 85% of a room
  earning tick after this lane (§6.1). A foreman with four builders multiplies them by four. See P-1951-1.
- **C1 lane files:**
  - For `docs/underground-integration-status.md`: "The excavation owners cost, per one-builder room earning tick,
    5.1 ms after decision 1951 (was 7.0 ms on the same machine); START and settlement 71–75 ms (were 111–116 ms); the
    entry foreman's 20 ms-or-more stalls fell from about 150 to about 30 per prefix. REQ-SET-163 is still not met;
    see 1951 P-1951-1/2."
  - For `docs/handoff/RULINGS.md`: none (no ruling was made).
- **Exact follow-ups this lane can still do** (they change no outcome):
  - Connector Contacts `_occupancy_leaf`, Delivery `_occupants_leaf` and `WorldRoutes.workpiece_occupancy_refusal`
    can skip absent unregistered rows (their check returns empty for `present != 1`). To keep exact results they must
    fall back to the full loop when the catalog extent is stale, because `unregistered_body_refusal` returns
    `ROUTE_OCCUPANCY_STALE` for any unregistered row first.
  - Contacts and Delivery are entry-path files; `world_routes.gd` is this lane's.

## 9. Shared files touched

| File | Hook |
|---|---|
| `residents.gd`, `needs.gd`, `entity_directory.gd` | One runtime-only revision token each, an accessor, and a `_mark_*` call at every write site listed in §3 |
| `underground_space_owner.gd` | Present-row walk in `_claims_refusal`/`_sources_refusal`; `_claim_row_refusal`, `_binary_present` and `_next_present` helpers |
| `underground_entry_frontier.gd`, `underground_connector_source_facts.gd` | Digest word compares |
| `underground_routes.gd`, `underground_world_routes.gd` | Owned by this lane |

Pins, census and registry:

- Pinned consumers renewed with `tools/renew_source_pins.py --write`: `underground_routes.gd` and
  `underground_world_routes.gd`.
- ADR 1212 projection update: `residents.gd`, `needs.gd`, `entity_directory.gd` and
  `underground_connector_source_facts.gd` become projected census inputs. Their master bytes are archived under
  `reviewed-sources/`, the reviewed-delta rows are charged, `PROJECTION_SHA` and `REVIEWED_SHA` are re-pinned, and the
  pack is regenerated. No byte figure moves; headroom is still 49,749,393 B.
- `docs/persistence_state_registry.md`: the two removed Routes rows are replaced by the three snapshot columns
  (category 3). `docs/planning/registry_capacity_audit.json` is regenerated (line numbers only).
- `underground_routes.gd` is 243,519 characters, against the 262,144-character source limit that
  `mole_profile_catalog.gd` enforces on pinned consumers.

No file of C2.1, M3 or C1 was edited, and nothing in `underground_space_authority.gd`.

## Independent review

A `code-reviewer` subagent reviewed `c09f9297..e2220aff`. It modelled the snapshot query and the original scan in
Python and fuzzed them against each other: 120,000 queries over 3,000 random populations, including present bytes
0/1/2, all four standings, registered and excepted rows, int32-extreme coordinates and inverted boxes. Every answer
agreed. It also checked every write site of the snapshot's inputs, the source-check and SpaceOwner rewrites, and the
pins. **It found no equivalence break and no CRITICAL or HIGH finding.** Its other findings, and how each was handled:

| Severity | Finding | Handling |
|---|---|---|
| MEDIUM | The "does not rebuild" assertion could not fail: a rebuild writes the same key. | Fixed: a marker in `_standing_x` must survive an unchanged query. The "always rebuild" mutant is now killed. |
| MEDIUM | `_same_words` was duplicated in the Frontier and SourceFacts. | Fixed: the Frontier uses `SourceFacts._same_words`. |
| LOW | Owned rows ran the four `owns` checks three times. | Fixed: `_source_owner` reads it once. |
| LOW | An unknown standing code would read back as UNBOUND. | Fixed: an `assert` on the index (no such code exists today). |
| LOW | `<<`/`>>` on negative x. | Kept: the typed-int path is used, and negative x is exercised by the suite (±20,000 crowds, every half-open face). |
| LOW | "Over-reserves 10,176 B" was the net cut, not the slack. | Fixed to 8,128 B of slack, noting the earlier 2,048 B under-count of `_occupancy_visit`. |
| LOW | The grep claim missed `test_underground_final_facts.gd`'s restored poke. | Fixed in §3. |
| LOW | The three new scalars had no registry row. | Fixed: category-3 rows in the Residents, Needs and Directory sections. |
| LOW | The census carrier "settlement store scalars" was unbacked. | Fixed: charged to `none (new)`, the existing carrier for new uncarried scalars. |
| LOW | The short-Level-digest assertion's label overstated what it shows; SourceFacts' fallback is unreachable through `refusal()`. | Label corrected; the fallback stays as the guard for other callers. |
| LOW | The scan oracle used `is_valid_of_kind`/`get_typed_row`, not `_turn_directory_row`; and the clock pass path might be untested. | Fixed: the oracle calls `_turn_directory_row`, and the clock tests assert that some cases pass. |

## Gates (results)

Code at `cfa99272`. The worktree has no staged demo assets.

**Full suite, CI-style.** `godot/.godot` was deleted, the project re-imported with
`godot --headless --path godot --editor --quit`, and then `./tools/run_tests.sh` was run in one process (1 h 14 min).
It printed:

```text
12515 test(s), 1281209 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 278 expected, 448 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

One earlier attempt is discounted. Its re-import crashed inside the engine (`handle_crash: signal 11` while reimporting
a font, from `propagate_notification` called off the main thread). The `demo_lens_live.gd` harness then hung on the
broken cache. That run was stopped (only this lane's processes were killed, after checking their working directory)
and repeated from a clean import, which completed without a crash. The pre-review state `e2220aff` had also passed the
full suite: 12,515 tests, 0 failures, 0 unexpected diagnostics, 0 leaks.

**Other gates:**

- Analyzer: `python3 tools/gdscript_warnings.py --max 0 --port 6451` printed `0 GDScript warning(s) in 0 of 1543 file(s)`.
- `python3 docs/validation/decision_numbers.py`: `PASS -- 552 records, 0 problem(s)`.
- CI contracts: every `python3` contract command in `.github/workflows/tests.yml` that needs no Godot, 59 commands,
  ran with 0 failures. That includes `underground_memory_budget.py --check`, `state_registry_coverage.py`,
  `audit_registry_capacities.py --check` and `renew_source_pins.py --check`.
- **Mutation testing: 69 mutants, 68 killed.** A scratch script applies one mutant at a time, runs the focused suites
  through the shard runner, and restores the file. It counts a failure, a script error or an unexpected error as a kill.
  The mutants covered:
  - the snapshot, the key tokens and the three revision counters: 24;
  - the SpaceOwner walk and the digest compares: 14 + 4;
  - the source and clock checks: 10;
  - the review fixes: 8;
  - re-runs after test additions.

  The one survivor (`levels.size() >= 31` in SourceFacts' range guard) is equivalent within defined behaviour. Both
  forms fault on a 31-byte Level digest whose first 31 bytes match, and SourceFacts' only callers already require 32
  bytes.
- **Behaviour.** The per-tick traces at `cfa99272` are byte-identical to the baseline, and both checkpoints' save bytes
  are unchanged.
- **Independent review.** The `code-reviewer` subagent found no CRITICAL or HIGH finding (see above).

## Source

- REQ-SET-163 (`docs/game_gdd.md`); ARCH-SYS order (`docs/systems_architecture.md`).
- Decisions 1205, 1212, 1213, 1219 and 1931 (`a0da1dce`), and P-C2-2 (a) (`docs/handoff/RULINGS.md`).
- The coordinator's 2026-10-15 brief, which allowed revision counters on Residents, Needs and Directory.
- The benchmark and traces described in §1 and §4.
