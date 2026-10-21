# 1953 — Phase spreading: what "spread it out" has to change, and the choice it needs

Date: 2026-10-17 · Status: **Accepted.** Brendan ruled P-1953-1 "Work ahead in the background", (C) staged, on
2026-10-17 (see "Brendan's ruling").

Lane PHASE-SPREADING, branch `perf/phase-spreading`, cut from master `537a9a2e`. That base has:

- activation #272 (content 12 mounted);
- C2.3 #268;
- both dig-tick-cost PRs;
- slice D1 #270.

Decision numbers 1953–1969 are this lane's.

Brendan ruled P-1952-2 (decision 1952) **"Spread it out"** on 2026-10-16: phase preparation is to run across several
ticks, so a dig phase opens a few ticks later and the START/settlement stalls go away. This record scopes that ruling
against the code as it stands. Its finding is that a phase cannot be spread across ticks while the transaction model
stays as it is. Every way of doing it changes more than "a phase opens a few ticks later", so the choice goes back to
Brendan.

## 1. What a stall is made of

The measurements come from `tools/benchmark_dig_tick.gd` at `537a9a2e`, under a load average of about 11:

- **Room:** START p50 70.5 ms and settlement p50 72.8 ms.
- **Entry:** 30 ticks of 20 ms or more, p50 0.48 s and max 0.82 s. The foreman's per-tick p50 is 0.67 ms.

A scratch instrumented profile of the entry run (instrumented, so the absolute figures are inflated) shows:

| Part of a phase START or settlement | Share |
|---|---:|
| `SpaceAuthority.operation_refusal`, the cold operation (whole) | 100% |
| `_prepare`, then `prepare_companions`, then `_phase_prepare_routes`: requalifying every published route edge against the staged geometry (`Routes.stage_refresh`, then `WorldRoutes.edge_refusal` for each of about 85 profiles) | about 70% |
| the rest of `_prepare`: Locations stage refresh, staged physical geometry, final preflight | about 25% |
| `_cold_refusal`: the survey, the snapshot and the qualification | about 5% |

The room is similar. There the cold survey is a larger share (about 23%) and route requalification about 50%.

**A single edge's requalification takes about 4–8 ms.** That is already more than the 2 ms tick budget, so spreading
at the granularity of one edge would still leave a tick above budget. Spreading below one edge means a profile proof
that can be resumed partway through.

## 2. Why a preparation cannot simply span ticks today

A START or settlement is one synchronous transaction:

1. It acquires the shared cold lease (`Budget` / `begin_cold_operation`).
2. It stages SpaceOwner, Locations and Routes (`_owner.has_prepared()`, `_locations._token`, `_routes._token`).
3. It proves the result.
4. It pays.
5. It publishes, all in the same call.

While anything is staged, the rest of the underground is refused by design:

- **No resident moves.** `Routes.advance_tick` returns 0 while `_owner.has_prepared()` or a route token is open.
- **No dig site earns work.** `SpaceAuthority._work_refusal` returns `SPACE_TRANSITION_BUSY` for every site, so
  `Work.tick_solo` refuses.
- **No other START, settlement or route-composition operation runs** (`SPACE_TRANSITION_BUSY` /
  `_cold_token != 0`).
- **A save can't be taken mid-transaction.** The Session's save and load paths refuse
  (`UNDERGROUND_SESSION_NOT_QUIESCENT` when `_space.has_prepared()` or the cold budget is not quiescent).
  WorldRoutes' capture and restore require `_wire_quiescent()`.

So holding a preparation open across ticks does not delay only the phase: it **freezes the whole underground** for
those ticks.

The callers of `begin_phase_work` and `settle_phase` are the entry foreman (`underground_entry_foreman.gd`, held by
slice D) and the room builder (`underground_room_builder.gd`, held by the C2 follow-up lane). Both treat a refusal as a
failure code. A "still preparing, try next tick" result therefore needs a hook in both held files.

## 3. The options

**(A) Freeze while preparing.** The preparation runs inside the existing exclusive window, cut into per-tick slices.

- **Callers.** The foremen get a `PHASE_PREPARING` result and retry the next tick. That is a hook in two held files.
- **Timing.** With a per-tick slice of about 4 ms:
  - an entry phase (about 0.5 s of work today) takes about 120 ticks, about 4 s of game time at 30 Hz;
  - a room phase (about 70 ms) takes about 18 ticks.

  For those ticks no resident underground moves and no other site earns.
- **Saving.** A save during the window must either be refused or discard the preparation and restart it after load.
  Restarting is safe, because the preparation is fully recomputed from saved owner state.

This option is exact and mechanically the smallest. But it replaces a visible stall with a visible freeze, and it is a
much larger timing change than "a phase opens a few ticks later".

**(B) Prepare concurrently.** The world keeps moving while a transition is staged.

- **What it requires.**
  - The Space, Locations and Routes transaction model allows movement, other sites' work and saving while one
    transition is staged.
  - At commit, the final leaves re-prove everything that might have changed in the meantime, and the preparation is
    rebuilt if it no longer holds.
- **Callers.** The foremen get the same `PHASE_PREPARING` result. That is a hook in the two held files.
- **Timing.** This matches the ruling's intent ("a phase opens a few ticks later", nothing else waits). But a
  preparation can be invalidated by any change it read (a resident moving through an edge's body, another site
  committing), so a busy underground could restart it repeatedly.
- **Scope.** It changes the exclusivity rules of several ADRs (1205, 1219, 1221/1228 quiescence for saves) and the
  owners `underground_space_owner.gd`, `underground_locations.gd` and `underground_space_authority.gd`. That is a large,
  high-risk redesign of the most heavily reviewed code. It needs an ADR, not a performance lane.

**(C) Speculative preparation off the live owners.**

- **How it works.**
  - While the current phase is being worked (hundreds of ticks), slices of the next transition's route
    requalification run each tick against a *private* copy of the staged world (proof image, staged Locations,
    staged route bank).
  - Nothing is staged on the live owners, so nothing freezes and no caller changes.
  - At START or settlement, the synchronous transaction uses the speculated per-edge results where every input they
    read is provably unchanged, and proves the rest live (the stall shrinks to what changed).
- **Inputs that need a token.** Each input the speculation read must be covered by a revision token or checked by value:
  - the Space geometry revision;
  - the Locations publication;
  - the route publication and certificates;
  - Profiles and the catalog;
  - **the surface exclusions** (water, resource nodes, Buildings), which have none.

  Those owners (World, `resource_nodes.gd`, `buildings.gd`) are outside this lane's files. The alternative is to
  re-run the exclusion leaves live at START. They are a few tile reads per box, but they are a real share of a proof.
- **Scope.**
  - `WorldRoutes`' compile path is refactored to run against an image it is handed, not against the live staged
    owners.
  - A per-tick driver is added. `Routes.advance_tick` is the one per-tick call this lane may edit.
  - Sites/SpaceAuthority must be able to predict the next transition's staged geometry. Settlement follows the work
    in progress. START follows a settlement in the same hand-over tick, so it is two transitions ahead.

  This is exact and needs no caller hooks. It is also the largest of the three, and it only shrinks the stall when
  nothing the speculation read has changed.

**(D) No spreading: keep shrinking the synchronous preparation.** For example, carry more of each edge's
requalification across phases (decision 1952's endpoint memo was a step of this kind). This is exact and keeps the
timing, but the stall stays: about 0.1–0.5 s per entry phase.

## 4. P-1953-1, for Brendan

**P-1953-1: how phases spread.** Choose one of A, B, C or D, as described in §3:

- **(A) Freeze while preparing.** The whole underground pauses for about 4 s of game time per entry phase and about
  0.6 s per room phase, instead of a 0.5 s or 70 ms real-time stall. It is exact and small. It needs hooks in the
  entry foreman (slice D) and the room builder (C2 lane).
- **(B) Prepare concurrently.** Nothing else waits, but it is a transaction-model redesign. It needs its own ADR, and
  hooks in the same two held files.
- **(C) Speculate off the live owners.** No freeze and no caller hooks. It needs exclusion revision tokens in World,
  resource nodes and Buildings, or a live exclusion re-check at START. It is the largest amount of work.
- **(D) Don't spread.** Keep cutting the synchronous cost. The stalls get smaller but never go away.

**Recommendation: (C)**, staged. Its first step is the private-image compile with a live exclusion re-check, which
needs no new owner tokens. Only (C) delivers the ruling's intent without freezing the underground, and without
editing files held by other lanes. If (C)'s size is not wanted now, **(D)** is the safe interim.

## 5. Files

| Option | This lane's files | Held files it would need |
|---|---|---|
| A | `excavation_sites.gd`, `underground_space_authority.gd` (to be agreed: the universal-stroke lane touched `_contacts_refusal`), `underground_routes.gd`, `underground_world_routes.gd`, `underground_connector_placements.gd` | entry foreman (slice D), room builder (C2 lane) |
| B | the same, plus `underground_space_owner.gd` and `underground_locations.gd` (slice D holds `_installed_row_site`) | the same |
| C | `underground_world_routes.gd` (not `_carry_eligible`), `underground_routes.gd`, `underground_connector_placements.gd`, `excavation_sites.gd` | none; exclusion tokens would touch World/`resource_nodes.gd`/`buildings.gd` if chosen over the live re-check |
| D | `underground_world_routes.gd`, `underground_routes.gd` | none |

## 6. Stage 1: what was measured before building, and what was built

**How stage 1 changed, and who directed it.** The ruling's stage 1 was a speculative, off-live compile of the next
transition's route requalification, reused at START where its inputs are provably unchanged. Measuring first showed
that this cannot stay exact for the expensive part (below: a geometric proof's spend depends on the whole staged image),
and that what can be reused exactly is the work inside one preparation that does not depend on the image. The lane
reported that to the coordinator on 2026-10-17. The coordinator directed: carry on with stage 1 as the exact
within-preparation reuse (the pace memo and once-per-edge endpoint observation "help under any later choice"), prove it
with the trace and save/load parity, and write up stage 2 for Brendan. So stage 1 as built is **exact synchronous
reuse, not speculation**: it shortens the stalls but cannot remove them. Removing them is stage 2 (§7), which goes back
to Brendan with these results.

**Where the entry stall time goes.** Real timers at `537a9a2e` (not instrumentation), entry run, 28 ticks of 20 ms or
more, 13.6 s in all:

| Part | Time |
|---|---:|
| Route requalification (`WorldRoutes.edge_refusal`, all edges) | 6.9 s |
| - `_carry_eligible` (slice D holds it) | 1.7 s |
| - per-profile proofs that ran geometry on the staged image (admitted, uncarried, or refused after segment 0's geometry) | 2.9 s |
| - per-profile proofs refused before any geometry (heading at segment 0, endpoint body, kind, stair and step spans) | 1.7 s |
| - endpoint observations (`_endpoint_observation_refusal`, 44,306 calls) | 0.7 s |
| Everything else in the stalls (Space survey and staging, Locations stage refresh, final preflight, economic START and settlement) | 6.7 s |

**Why a geometric proof cannot be reused across preparations exactly.** Every scan of the proof image
(`Clearance.blocked`, `subtract_role`, `_solid_contacts_covered`, `_body_blocked`) spends one check per image row. Without a
limit, `subtract_role` also spends the current fragment count for every row of its role anywhere in the image. A proof's
spend therefore depends on the whole staged image, not only on the rows inside its sweeps, and the image gains rows as
the dig proceeds.

The budget is part of the outcome. A spend that runs out refuses the edge, and the activation lane measured a peak of
95.4% of `MAX_CHECKS`. Reusing a geometric proof's answer on another image could change that outcome, even where its
geometry within the sweeps is unchanged (ADR 1205's carry premise). So stage 1 reuses nothing across preparations.

**What was built** (exact, runtime only, never saved, checked live while `CacheChecks.enabled`):

- **Observing each endpoint once per edge compile.** Every profile proof re-observed both endpoints. Within one
  compile, the sealed staged Locations, the tokens and the target revision cannot change. So a repeated successful
  prepared observation is answered from one of two kept records (`_observed`, `_observed_key`), with the same
  `PREPARED_OBSERVATION_CHECKS` spent first. Failures, and the unprepared live path that tests subclass, are always
  observed afresh.
- **Pace once per preparation.** `_catalog.pace_into` is a function of (profile, revision, family, variant), the
  catalog and content revisions pinned for the preparation, and what it reads beyond them: Profiles' load token, the
  level pack's content revision, and each Movement profile's revision and speed. Those are stamped at `_begin_proof`
  (`_pace_inputs`). A repeat inside one preparation (`_pace_serial`) is answered from `_pace_memo` only while every
  stamped word still holds; nothing in production moves them mid-preparation, but nothing forbids it either. A refusal leaves `_pace` untouched and an answer calls
  `IntResult.succeed`, exactly as the call does. The catalog's own scratch (`_descriptor`, `_number`) is read only
  inside the same call.
- **Refusing another kind's profiles from the bank's own columns.** About 85 profiles are tried per edge, and most are
  of another mode, posture or family. `_other_kind` reads the certificate flags, mode, posture and family mask straight
  from the Profiles bank (the columns `descriptor_into` copies) and skips the proof that would refuse on kind. When the
  last profile is skipped, `_restored_descriptor` writes its descriptor, so `_descriptor` is left exactly as the full
  loop leaves it.

**Stage 1's results.**

**Exactness.** Stage 1 changes no outcome. Four checks show it:

- **SHA trace.** The dig benchmark's per-tick SHA-256 of every owner it drives (`REDWALL_DIG_TRACE`; 11,453 lines over
  the room run and the entry run) is byte-identical to master `cb8035d7`, and again, after merging #273, to master
  `9440b9d1`. The benchmark runs with the caches answering.
- **Checkpoints.** The two underground checkpoints were regenerated, also with the caches answering, before and after
  merging #273. Every save point's SHA-256, size and tick equals master's; only the source fingerprint moved.
- **Save/load parity.** `test_settlement_save_underground.gd` runs the live entry chain to tick 8,400 with the caches
  answering, and saves at every checkpoint. Those saves equal the checked run's, byte for byte. Each save, loaded
  into a fresh settlement (which discards the caches) and run to the next checkpoint, saves byte-identically there.
- **Differential compiles.** `test_underground_route_memos.gd` compiles every published edge in a real preparation
  twice, once with every cache recomputed live and once with the caches answering. The code, spend, proof error,
  certificate row, descriptor, endpoint record and pace are equal. The first edge is also replayed at every budget up
  to its whole spend (1,830 checks), so the budget runs out after each profile in turn.

**Mutation.** 29 mutants of the three caches and the pace stamp were run against the memo suite, each last run after
the test that answers it. 28 were killed. The survivor removes the check-mode comparison in `_other_kind`, which only
reports a fast path that disagrees with the full proof; it is equivalent while the two agree.

**Gates.** The complete suite, run as CI's ten shards (`./tools/run_tests_parallel.sh`, with a watchdog capping each
live harness at 900 s and each shard worker at 3,600 s), passed: 12,996 tests, 0 failures, 546 suite files each run
once, and nothing for the watchdog to stop. The analyzer reports 0 warnings, and all 59 CI contract commands pass.
An earlier complete run hung for six hours in `demo_lens_live.gd` at 1280x720. Its clean import had crashed (signal
11 while reimporting a font, exit 134), and the suite ran on the half-imported project. After a clean re-import,
the same harness passed 11 runs out of 11 on this branch (five at each size, plus one more at 1280x720), and once on
master; it reads no underground state. So the hang was the crashed import, not stage 1.

**Memory.** 19,048 B, runtime only, never saved (ADR 1212, census item `world_routes_compile_memos`). The headroom
below the 150 MB gate goes from 44,220,364 to 44,201,316 B.

**Measured effect.** Master `cb8035d7` against this branch, three alternating rounds each, on a quiet machine
(load 1.4–2.8). The figures are the means of the three rounds:

| | master | stage 1 | change |
|---|---:|---:|---:|
| Room START, p50 | 57.3 ms | 53.5 ms | −6.7% |
| Room settlement, p50 | 59.0 ms | 54.7 ms | −7.3% |
| Room settlement, p95 | 71.5 ms | 67.9 ms | −5.1% |
| Entry stalls, count | 28 | 28 | 0 |
| Entry stalls, sum | 12.68 s | 11.70 s | −7.7% |
| Entry stall, p50 | 415 ms | 392 ms | −5.5% |
| Entry stall, max | 678 ms | 647 ms | −4.5% |
| Room earning tick, p50 / p95 | 2.10 / 3.28 ms | 2.09 / 3.30 ms | none |

**Where the 2 ms target stands.** Unmet, and stage 1 does not move it materially. The steady earning tick is
unchanged at about 2.1 ms p50 and 3.3 ms p95 (the dig-tick-cost lanes' territory). A START or settlement is still one
synchronous tick of about 54 ms in a room and 0.4–0.65 s in the entry. Stage 1 trims the requalification inside those
ticks by 5–8%. Only stage 2 (§7) takes the stalls out of the tick.

## 7. Stage 2: a private staged world, prepared ahead in slices

**What it would do.** It would compute the whole next transition ahead of time, in per-tick slices, against a private
copy of the staged world: the survey, the staging, the Locations refresh and the route requalification. At START or
settlement, the transaction would adopt the result when the live world is provably the one it was computed against,
and run synchronously otherwise.

**Why only whole-preparation identity is exact.** As §6 shows, proof spends depend on the whole staged image. The only
cheap exact test is therefore that nothing published since the speculation began:

- the Space geometry revision and journal;
- the Locations and Routes publication tokens;
- the certificate revision;
- the Profiles and catalog revisions.

Three inputs have no token, and would be re-run live at adoption:

- the surface exclusions;
- resident occupancy (the survey's contact and occupancy checks read residents who move every tick);
- the economic leaves (inventory, jobs).

Those live re-runs set the adoption tick's ceiling.

**What it would take:**

- **Private staging.** Space, Locations and Routes stage into private banks rather than their own stage bank, and
  "prepared" stops meaning "the world is frozen". The files are:
  - `underground_space_owner.gd`, `underground_locations.gd` (slice D holds `_installed_row_site`) and
    `underground_routes.gd`;
  - the geometry journal;
  - `underground_space_authority.gd`'s cold operation (to be agreed with you).
- **Resumable slices.** `SpaceAuthority._prepare` → `prepare_companions` → `ConnectorPlacements.prepare_phase_refresh`
  / `_phase_prepare_routes` → `Routes.stage_refresh` → `WorldRoutes.edge_refusal` become a state machine. That covers
  the entry world bindings' and room world bindings' `prepare_companions`, and `underground_world_bindings.gd`'s staged
  physical geometry. Each slice is bounded so a tick stays near its stated budget. A single edge (about 4–8 ms) is
  itself larger than 2 ms, so an edge's profiles must be resumable too.
- **Prediction.** Settlement follows the work in progress. START comes right after a settlement in the same hand-over
  tick (DEC-059 P2), so its speculation must start from the predicted post-settlement world, two transitions ahead.
- **A second cold lease.** The speculation needs a second cold lease, about another 1 MB of cold memory (ADR 1212). The
  shared cold arena is sized for one lease today.
- **Saving.** Saves must ignore the speculation (it is discarded at load and rebuilt), so the Session's quiescence test
  must distinguish it from a live preparation.
- **Held files.** Of these, slice D holds `underground_locations.gd` `_installed_row_site` and `_carry_eligible` (which a
  sliced compile must call). The C2 lane holds the room builder and runtime, which need no change, because adoption
  happens inside `begin_phase_work` / `settle_phase`. The entry foreman needs none either.
- **Dependencies on slice D.** Two more slice-D-held files sit on the entry's START path, and stage 2 would not edit
  them; it depends on slice D for them:
  - `underground_entry_structure.gd` (P-2044-12), the entry's natural-bearing structure proof. A speculated entry
    START needs it either to run against the private image or to stay a live re-run at adoption. The second costs
    nothing from slice D but adds its time to the adoption tick.
  - `underground_entry_frontier.gd`, the entry's episode source, which the entry world bindings read when they
    stage. Predicting the next entry transition reads the next episode from it. Reading needs no change; any new
    read accessor would be slice D's to add.

**Size.** Roughly 2,000–4,000 changed lines across about ten of the most heavily reviewed core files. It needs its own
ADR, because it changes what "prepared" means and adds a third bank or a private-image contract. It is several weeks of
work with the same gates as this lane.

**Expected effect.**

- **With one active transition**, which is the entry crew and a single room builder, the speculation usually holds.
  START and settlement then cost only the adoption's live re-checks plus payment and publication: an estimated 5–15 ms
  rather than 0.4–0.8 s in the entry and about 60 ms in the room.
- **With several foremen digging at once**, each publication invalidates the others' speculation, and those
  transitions fall back to today's synchronous stall.
- **A resident walking through a speculated edge's body** invalidates only the occupancy re-run, which is live anyway.
- **The per-tick ceiling** while speculating is the slice budget plus the existing tick.

## Brendan's ruling (2026-10-17)

Brendan ruled in chat on 2026-10-17, and the coordinator relayed the ruling: **"Work ahead in the background"**, which
is (C), staged.

**Stage 1 is built first:**

- The next transition's route requalification is compiled speculatively, against a private image and off the live
  owners, in per-tick slices with a stated per-tick check budget.
- At START or settlement, only results whose inputs are provably unchanged are reused; the rest is redone
  synchronously.
- The surface exclusions are re-checked live at START, so no new owner tokens are needed.

**The hard requirements:**

- Behaviour stays byte-identical to master, proved by the SHA trace. The speculation may change only how much work the
  synchronous step does, never an outcome.
- The speculation's state never enters a save. Discarding it at load must give the same result, proved by next-tick
  save/load parity.
- Its memory is measured and routed through ADR 1212.
- No hooks are added to slice D's or the C2 lane's files.
- If stage 1 shows that (C) cannot stay exact, the lane stops and reports.

## Brendan's ruling on stage 2 (2026-10-18)

**P-1953-2: what happens with stage 2.** Put to Brendan with stage 1's measured results (§6) and the stage 2 scope (§7).
Brendan ruled in chat on 2026-10-18, relayed by the coordinator: **"After M5, re-measure"**.

- Stage 1 merges now, as built: exact synchronous reuse. The stalls remain.
- Stage 2 is not started. It is revisited once slice D's M5 flight has landed and its held files are free:
  `_carry_eligible`, `_installed_row_site`, `underground_entry_structure.gd` and `underground_entry_frontier.gd`.
- The revisit starts from a fresh measurement on master, covering the dig tick, START and settlement in the room and the
  entry, with M5's flight in place, before any stage 2 design is adopted.
- REQ-SET-163's 2 ms tick stays unmet until then. The steady earning tick is 2.09 / 3.30 ms (p50 / p95).

## Source

- Decision 1952 and its rulings (`docs/handoff/RULINGS.md`, 2026-10-16).
- ADR 1205 (incremental requalification), ADR 1219, ADR 1221 and ADR 1228 (save quiescence), REQ-SET-163.
