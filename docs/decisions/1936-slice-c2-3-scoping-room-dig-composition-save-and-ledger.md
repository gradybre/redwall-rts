# 1936 — Slice C2.3 scoping: composing, saving and ledgering room digs

Date: 2026-10-15 · Status: Proposed. Scoping only; no code. Stopped for Brendan's rulings on P-1936-1 to P-1936-6,
and for the coordinator's clearance of the files outside this lane (§3).

Number range: this lane's 1931–1949 (decision 1931). Branch `feat/room-foreman-c2-3`, from `114e4acf` (C2.2,
PR #264).

## Decision

C2.3 composes the room-dig runtime (decisions 1933 and 1935) in the running game and the demo. It also saves and
loads the runtime, and ledgers its memory. The scope, as relayed by the coordinator:

- a composite Jobs dispatcher (review H4);
- composition from the Session;
- the crews' walk-in (P-1933-1 (a));
- save and load, with resume of paid phases (P-1933-2 (a));
- moving a stopped crew's route actors;
- the memory row;
- crew parking off the Corridor access.

Not in C2.3:

- station-chain retirement (P-C22-2 (a));
- the stair legs of Delivery and the hauler (P-1981-4 (a));
- activating contents 11 and 12 (the activation lane).

Every claim below was checked against the code at `114e4acf`. Six findings shape the scope.

## 1. Findings

**F1. The Jobs dispatcher has one slot, and the entry takes it for every excavation Job.**

- `jobs.gd` keeps one dispatcher (`bind_dispatcher(owns, reserves)` :2132, "A later binding replaces it").
- The entry runtime binds itself when it plans and on restore (`underground_entry_runtime.gd` `_bind_dispatcher`
  :264). Its `owns_job` (:245) answers true for **every** Job whose requester is an excavation or connector Project.
- Once the entry has planned, a room builder assigning itself to its own BRACE Job is refused
  `JOB_DISPATCHED_TO_CREW`, because room builders are not reserved.
- Room Jobs are also unprotected while a builder walks to the storage or hauls (decision 1935). The BRACE Job is
  then queued and unassigned, and the JobSelector could give it to any idle resident.

**F2. Nothing composes the room phases' contacts in the game, and they bind once, with one way in.**

- `underground_room_world_bindings.gd` `bind_room_phase_contacts(actual, face, placements, retreat, travel,
  revision, controls)` (:54) is called only by tests. It refuses a second bind (`_ordinary_routes != null`).
- The bound retreat endpoint and travel row serve **every** room in the World. So one way in serves all rooms
  (ADR 1202 steps 3–4).
- No such endpoint exists in the game until slice D gives level 1 its way in.

**F3. Nothing chooses a crew, publishes parking, or walks a crew in.**

- `start_room(room, owners, crew)` takes a ready-made crew of 1–4 `Builder.Crew {worker, tool, parking}`. Every
  test builds that crew by hand.
- A parking endpoint must be a published TRANSIT Location joined to the access by spans, off every station chain.
  A body on the access closes every later station chain (decision 1935); see also ADR 1213 "Parking".
- `register()` only places the builder (P-1933-1 is unbuilt).

**F4. No save code knows the room runtime.**

- `settlement_save_world.gd` `bind_underground` binds only the entry, and `quiescence_refusal` never checks the
  room runtime.
- So a save taken with a room runtime adopted would drop it silently. Today nothing in the game adopts one, so no
  game save is affected.
- ARCH-SAVE-006 (next-tick parity) rules out a record-only save: in-flight digs must resume byte-identically. So the
  builders' cursors and hauls are saved as the entry's are (ADR 1218).

**F5. Nothing a room dig needs exists in the game yet.**

- **No way in:** slice D.
- **No room stroke:** the claw wall rows are content 11 (decision 1971), activated by the activation lane.
- **No stock underground:** stair carry, P-1981-4.

So C2.3 composes a runtime that sits idle in the game. Its digging, saving and resuming are proven on fixtures, and
the game checkpoint waits for slice D (P-1936-4).

**F6. Routes can unregister only a lost actor or a resting one.**

- `unregister_lost_actor` (:3010) covers a dead or departed actor; `unregister_resting_actor` (:3033) covers a
  living actor at rest on an endpoint.
- A stopped crew can therefore leave only from rest, and its Transform stays where it is (ADR 1219 §4).
- The entry's shift change moves the resident by a timed teleport (ADR 1225, DEC-059 amendment).

## 2. What C2.3 builds

| Piece | What | Files |
|---|---|---|
| Dispatcher | **New `underground_dispatch.gd`**: one composite bound to Jobs once, when the underground is mounted. It owns a Job if the entry or the room runtime owns it, and reserves a resident if either reserves it. This pairing is sound: each foreman assigns only its own Jobs, and Jobs' `evaluate` refuses every reserved resident before any scan (`REFUSE_AGENT_RESERVED`), so the JobSelector never hands out an owned Job. The room runtime owns the BRACE/CUT/FINISH Jobs of its open phases and reserves every builder of a running dig, between cubes too, and afterwards for as long as the builder is a registered route actor (as ADR 1223 does for the entry) | new file; `underground_room_runtime.gd`; **`underground_entry_runtime.gd` `_bind_dispatcher`** (one function: bind through the composite instead of replacing it) |
| Composition | SettlementSystem builds the runtime once the room owners are composed (`compose_underground_room_owners`) and adopts it. So the game and the demo get it through the existing mount path, with no demo edit. A new `order_underground_room(room)` takes the confirmed room, its storage, spoil and staging containers, and a crew (P-1936-2), and starts the dig. It composes the room contacts on first use (P-1936-1). Builder owners come from the Session's `Retirement.Owners` (Delivery and Locations included) | `settlement_system.gd`; new `underground_room_session.gd` (owners packet, contact binding, crew choice) |
| Parking | A small planner publishes one TRANSIT endpoint per builder on the access section, joined to the access by two certified spans (the fixture's own shape), off every station chain's gateway. It uses Locations' and Routes' public staging calls only | new `underground_room_parking.gd` |
| Walk-in | P-1933-1 (a), ADR 1219's arrival: a timed walk of `ceil_div(D × 30, v)` ticks at the builder's Movement speed (no new constant), then placement on its parking and registration, one builder at a time | `underground_room_foreman.gd`, `underground_room_builder.gd` |
| Resume | P-1933-2 (a): a re-ordered room's cube with a live, started phase is taken first. The builder takes the Site's bound Job and walks to the station. Sites' own `resume_phase_work` (`excavation_sites.gd` :1395) continues the paid work, instead of a fresh `open_phase` | `underground_room_builder.gd` |
| Walk-out | P-1936-3: a finished or stopped dig's builders leave once they rest on an endpoint: `unregister_resting_actor`, then the walk-in's timed walk in reverse. Each builder is then released from the reservation | `underground_room_runtime.gd`, `underground_room_foreman.gd` |
| Save | A new §6 owner, `underground_room_progress`, with an owner codec after ADR 1218/1221 (§4) | new `underground_room_progress.gd`; `capture`/`restore` in the runtime, foreman and builder; save adapters and registry (§3) |
| Memory | The ledger row (§5) | `tools/underground_current_census.py`, `tools/underground_memory_budget.py`, their tests, the pack, `ready07_arithmetic.py`, `systems_architecture.md` |
| Claw Kitchen | A test fixture that loads content 11 (`qualified-claw-wall-v12`, tests only; activation stays with its lane), so the whole haul-and-dig runs with the claws. This covers the deferred cases from decision 1935: the turn after a haul, a column haul, and two builders hauling | tests only |

## 3. Files outside this lane (clearance needed)

| File | Change | Owner |
|---|---|---|
| `underground_entry_runtime.gd` `_bind_dispatcher` | Bind through the composite, not directly to Jobs | Entry (no active lane) |
| `settlement_save_owners.gd`, `save_underground_adapters.gd`, `settlement_save_apply.gd`, `settlement_save.gd` (`quiescence_refusal`), `settlement_save_world.gd` (`bind_underground`), `save_auxiliary_state_schema.gd`, `save_section_auxiliary.gd` | The new §6 owner, its adapter, its place in `AUX_APPLY_ORDER` (after `underground_entry_progress`), and its quiescence | Shared save format (ARCH-SAVE) |
| `docs/planning/canonical_state_registry.json`, `registry_capacity_audit.json`, `canonical_state_hash.gd` (generated), `validate_save_registry_handoff.py` (810 pin), the registry tools' tests | The registry step, as commit `ef0a367b` did for ADR 1228 | Shared |
| `underground_room_world_bindings.gd` | **No edit** under P-1936-1 (a): `bind_room_phase_contacts` is only called. `worker_refusal` and `output_refusal` stay the cost lane's | Cost lane |
| `godot/demo/` | **No edit**: the demo already mounts through `SettlementSystem` (`demo_village.gd` `_mount_modular_foundation`). Nothing orders a dig until C3 (P-C2 (c)) | Demo and Mound lanes |
| Routes, `work.gd`, `excavation_sites.gd`, Profiles | **No edit**: public calls only | Cost lane |

## 4. The save schema change

**Owner.** `underground_room_progress`, section 6, schema 1. It is registered like `underground_entry_progress`,
with two fields: `progress_length` (u32, hashed) and `progress_record` (u8 × `progress_length`, hashed, owner
codec).

**Codec.** `underground_room_progress.gd`, with its own magic and version (ADR 1221's convention). It:

- refuses `ROOM_SAVE_*`;
- captures only when quiescent (no Delivery packet, Budget lease or Locations/Routes token open, which is always
  true between ticks);
- checks a record, then swaps it in;
- re-encodes on restore to refuse a non-canonical record.

**Record contents:**

- **The room record:** only the rows in use (state not NONE). Each row is the room's directory row and generation,
  its state, and its storage, spoil and staging containers: 33 B.
- **Each kept foreman:** its room row, its builders, its registration latch, and the blocked and column-try
  counters.
- **Each builder:**
  - stage, stall count, order index, Site, operation, Job slot, station, work row, `_at`, `_departed`;
  - the three leg lists (current, home and approach) and the leg cursor;
  - the queue;
  - the ledgers;
  - the hauler block. `underground_entry_hauler.gd`'s own `write_state`/`read_state` is reused unchanged, with
    ADR 1218's limits (8 units, 5 legs).

**Re-derived on load (category 2):**

- the dig order, from Sites;
- the cube marks: done from Sites and taken from the builders; refused marks reopen;
- each builder's footprint, swept again from its saved legs;
- the row extents and the blocked epochs.

**Size.** The worst case is all 16,384 rows in use (540,672 B) plus 256 builders at about 600 B and their hauler
blocks. The exact maximum is set from the codec's block bounds when it is built, as ADR 1218 did.

**Registry and checks:**

- registry v16 → v17, §6 schema 10 → 11, owners 25 → 26, records 810 → 812;
- `MAX_SECTION_BYTES` grows by the record's maximum;
- every checkpoint is regenerated;
- the file format version stays 2 (§6 does not bump it);
- no migration (DEC-055 item 1). An older save loads with the owner canonical-empty, as ADR 1228's owners do.

## 5. Memory

- **The room record:** 475,136 B, allocated when the runtime is composed at mount. It enters ADR 1212's current
  census as a new key, `room_dig_runtime`, counted from an exact member set (as `entry_chain` counts the entry).
- **Per running dig, worst case at 256 residents.** Assumes 256 digs of one builder each, or fewer digs with more
  builders:
  - the dig order and marks: 13 B per Site, at most 73,909 Sites, so at most 960,817 B;
  - each builder: its footprint, capped at 512 boxes (12,288 B, P-1936-5), plus 1,608 B of row extents and about
    1 KB of legs, so 256 × 14,920 = 3,819,520 B.
- **Total:** about 5,255,473 B. The headroom falls from 49,749,393 B to about **44,493,920 B**. The exact figure
  comes from the counting function when it is built.
- **Decision 1880's 16,957,440 B fold is not triggered.** C2.3 allocates no painted cell, room, item or edge
  column. It stays held for C3 or slice G (P-C8 (a)). Once both are counted, the headroom is about 27.5 MB.

## 6. Proposals

**P-1936-1 — The room phases' way in (F2).**

- **(a)** Compose the room contacts on the first room order, from that room's access endpoint and its travel row.
  Refuse a room on another access (`ROOM_DIG_OTHER_ACCESS`) until a per-access binding exists. No edit to the
  world bindings.
- **(b)** Make the room contacts per access now. This edits `underground_room_world_bindings.gd` beyond the cost
  lane's two functions, so it needs that lane's agreement.

**Recommendation: (a).** Slice D gives one level one way in. A second way in is slice D's or later work.

**P-1936-2 — Who digs (F3).**

- **(a)** One builder per room for now: the first idle adult mole that is not the entry crew and not another dig's
  builder (the entry's `_idle_mole` rule).
- **(b)** Up to 4 by room size: one builder per 4 cells (ECON-001's cap).
- **(c)** The player chooses. This needs C3's interface.

**Recommendation: (a) now, then (c) with C3.** It is the smallest crew whose proof exists (decision 1933's
one-builder dig), and the footprint rule already lets more builders take turns when C3 asks for them.

**P-1936-3 — After a dig (F6).**

- **(a)** The builders walk out once they rest on their parking (`unregister_resting_actor`, then the walk-in's
  timed walk in reverse, to where each one came from), and are free again.
- **(b)** They stay parked and reserved underground until the next dig.

**Recommendation: (a).** Otherwise every room dug takes moles out of the village for good.

**P-1936-4 — Proving save and load (F5).**

- **(a)** Build the codec, the adapter and the registry step now. Prove next-tick parity in process on the Kitchen
  fixtures (save, restore into fresh owners, run on, compare), and prove an empty and a queued record through the
  real save path. Add the game checkpoint recipe when slice D makes a room diggable.
- **(b)** Defer save and load to slice D.

**Recommendation: (a).** Otherwise a game save made after the runtime is composed would drop digs silently (F4).

**P-1936-5 — Bounding a builder's footprint (§5).**

- **(a)** Cap it at 512 boxes. A longer plan refuses `ROOM_BUILDER_FOOTPRINT_CAPACITY`. The Kitchen's longest is
  306.
- **(b)** No cap, and ledger an estimate.

**Recommendation: (a).** ADR 1212 counts stores exactly; an unbounded array cannot be counted.

**P-1936-6 — The walk-in's distance (P-1933-1 (a)).**

- **(a)** ADR 1219's rule as it stands: the straight distance from the resident's Transform to its parking, at
  its Movement speed.
- **(b)** The distance to the burrow mouth plus the path below. This needs a path the stair-carry and slice D
  lanes have not built.

**Recommendation: (a).** No new constant, and ADR 1219's own rule.

## Source

Decisions 1202, 1212, 1213, 1218, 1219, 1221, 1223, 1225, 1228, 1880, 1911 (P-C8), 1931, 1933, 1934, 1935; the
code at `114e4acf`: `jobs.gd` :2116–2142, `underground_entry_runtime.gd` :245–267, `underground_room_world_bindings.gd`
:54–72, `settlement_system.gd` :1862–2283, `settlement_save_world.gd` :189–205, `underground_routes.gd` :3010–3068,
`excavation_sites.gd` :1395.
