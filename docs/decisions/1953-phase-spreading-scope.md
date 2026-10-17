# 1953 — Phase spreading: what "spread it out" has to change, and the choice it needs

Date: 2026-10-17 · Status: **Proposed. A ruling is needed before any code is written** (P-1953-1 below).

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

## Source

- Decision 1952 and its rulings (`docs/handoff/RULINGS.md`, 2026-10-16).
- ADR 1205 (incremental requalification), ADR 1219, ADR 1221 and ADR 1228 (save quiescence), REQ-SET-163.
