# 1222 — Settlement save and load (task 09): the plan, and the questions only Brendan can answer

Date: 2026-10-07 · Status: Accepted. Brendan answered all ten questions on 2026-10-07 (DEC-055); the build proceeds in the plan's order.

## Brendan's decision

> Build the settlement save/load (task 09) first; the underground section-6 body/orchestrator follows as its own
> step and should plug into it. (chat, 2026-10-07)

This chooses option A of [ADR 1221](1221-underground-cold-load.md)'s step 4. Option B (the underground section-6
body) still gets built, but later, and it plugs into the orchestrator described here.

## Decision

The settlement save is built as one orchestrator over the fifteen ARCH-SAVE-002 sections. It is written in the
order set out in "Build plan" below.

A load into a fresh settlement **reuses the world-retirement path**. It does not mount a new Session over the live
owners. The sequence is:

1. retire the live world;
2. restore every section into the cleared owners;
3. re-mount the underground Session;
4. restore the underground section-6 owners;
5. publish.

This is the only route that the one-way bindings permit (see "The one-way bindings").

Nothing is implemented in this step. Every remaining piece either depends on a question below or edits shared
registry, header or version state, which task 09 reserves to the integration lead.

## Where the code stands (read off source at 8b3bbd5b)

`docs/planning/save_implementation_matrix.md` is a 2026-09-15 snapshot and is stale. This table replaces it.

"Capture" means reading the live owners into a record. "Apply" means writing a record back into the live owners.

| § | Section | Module | Codec | Capture | Apply | Gap |
|---|---|---|:-:|:-:|:-:|---|
| 1 | WORLD | `save_section_01.gd` | yes | yes | yes (`restore_section`) | **Drift:** the code has 9 owners at section schema 3. The registry has 10 owners at schema 4, adding `underground_space_owner` (wire `state_bytes`/`restore_state_bytes` exists). |
| 2 | CATALOG_IDS | `catalog_ids.gd` | yes, unwired | n/a | none | `movement._profile_revision` has no carrier |
| 3 | ENTITY_DIRECTORY | `save_section_directory.gd` + `save_identity_restore.gd` | yes | yes | yes | — |
| 4 | COMPONENT_COLUMNS | `save_section_component_columns.gd` (streaming) | yes | **no** | **no** | 18 owners; 15 have a `save_owner_*.gd` validator, and only needs, residents and jobs have a live bulk copy/restore |
| 5 | CHILD_ARENAS | — | **no** | no | no | buildings, construction (`_delivered_milli`), forage, jobs, orchard_hive |
| 6 | AUXILIARY_STATE | — | **no body** | no | no | 13 owners (below) |
| 7 | INVENTORIES | `save_section_inventories.gd` + 4 restore helpers | yes | yes | yes | **Drift:** the code is at section 5 with inventory owner 4; the registry is at section 6 with owner 5. Capture refuses (`REFUSE_SPATIAL_CODEC`) whenever spatial endpoints exist. |
| 8 | JOB_INDEXES | `save_section_job_indexes.gd` | yes | yes | yes | — |
| 9 | NAVIGATION | `save_section_navigation.gd` | yes | **no** | **no** | BLOCKER N1: `navigation`/`movement` have no bulk column API |
| 10 | RNG | `save_section_rng.gd` | yes | yes | yes | — |
| 11 | EVENT_SCHEDULE | `save_section_event_schedule.gd` | yes | yes | yes | no event kinds or producers yet |
| 12 | PENDING_COMMANDS | `save_section_pending_commands.gd` | yes | yes | yes | — |
| 13 | CHRONICLE | — | **no** | no | no | no owner module; the wire is ruled (SAVE-R09 contract, 24-byte records) |
| 14 | NAME_POOL | `save_section_name_pool.gd` | yes | yes | yes | — |
| 15 | STATE_DIGEST | `canonical_state_hash.gd` | walker | — | — | Adapters exist only for §1 and §7 inventory, so the production digest refuses `CANONICAL_NO_ADAPTER` |

### Other pieces

- **Header.** `save_header.gd` is done: the 264-byte header, the 15×64 descriptor table, CRC-32 and the body digest.
  The rules, map, lookup and engine identity producers are **ruled** (SAVE-R09-003,
  `rulings/2026-09-11_save_codec_contract.md`) but **not implemented**. The 44-byte provenance prefix also has no
  producer (SAVE-PROVENANCE-PRODUCER).
- **No whole-file writer, reader or orchestrator exists.** Nothing in `core/` or `systems/` writes a save with
  `FileAccess`. `SettlementSystem` has no save path at all (settlement_system.gd:167, "CheckpointHash: no save
  stream").
- **GameManager's load barrier exists but is unused.** `begin_load`, `restore_clock_runtime`,
  `publish_restored_world`, `end_load` and `rollback_load` are in place, but nothing in production calls
  `begin_load`. The only production caller of `restore_clock_runtime` is `save_world_runtime_install.gd`. Its
  rollback checkpoint is ten clock scalars held in memory.

### Section 6 owners

| Owner | Codec today |
|---|---|
| `haul_planner` | **real** (`UHPL`, ADR 1221) |
| `underground_entry_progress` | **real** (`ENTP`, ADR 1218) |
| `buildings` (spatial kind, installed) | diagnostic `spatial_state_bytes` only; no restore |
| `excavation_inventory` | test image only (`state_bytes`); no restore |
| `excavation_sites` | test image only (`state_bytes`); no restore |
| `modular_projects` | test image only (`state_bytes`); no restore |
| `room_projects` | test image only (`state_bytes`); no restore |
| `spoil_tips` | test image only (`state_bytes`); no restore |
| `command_dispatch` (intent dedup) | none |
| `crop_weather` | none |
| `ecology` | none |
| `inventory` (8 `_spatial_*` columns) | none |
| `room_layout` | none |

`docs/persistence_state_registry.md` lists owners as category 1 that the canonical JSON does not declare:
`underground_connector_contacts` (§6), and `underground_routes`, `underground_world_routes`,
`underground_locations`, `underground_connector_placements` and `underground_connector_workpieces` (§1). All of
them already have owner codecs (ADR 1221). Declaring them belongs to the underground step. Room orders, the
bindings modules, the surface anchor and the Frontier have no codec and have not been audited (ADR 1221 option B).

### Seventeen UNRESOLVED registry rows

All of them are the same question: which owner and ordinals carry the state.

| Owner | Rows | Registry lines |
|---|---|---|
| construction (ConstructionPaidLedger) | 1 | 210 |
| demolition_admissions | 4 | 234–237 |
| demolition_work | 2 | 244–245 |
| households | 7 | 422–428 |
| store_policy | 3 | 972–974 |

## The one-way bindings (ADR 1221)

`UndergroundSession._initial_authority_refusal` (underground_session.gd:206-211) refuses
`UNDERGROUND_SESSION_AUTHORITY_LIFETIME` if any of these four links is non-null, **even when it has expired**:

- `Buildings._spatial_authority`
- `Construction._modular_authority`
- `Construction._excavation_authority`
- `Inventory._spatial_authority`

Composition also binds:

- Work's excavation, modular and spatial-delivery authorities;
- `Reservations.bind_inventory`;
- Placements' phase authority.

An owner's `clear()` keeps every one of these links. The only code that nulls them is the static
`world_retirement_release_preflighted_in` functions, which `UndergroundWorldRetirement.release_preflighted` calls.
That path runs only inside `SettlementSystem.prepare_world_reset()` → `reset()` →
`_release_underground_after_clear()`.

`Reservations._bound_inventory` is never reset. That is harmless, because Inventory's object survives `clear()`.

**Consequence.** A load cannot restore into owners that a mounted Session still holds, and it cannot mount a
second Session over them. The load path must therefore be:

1. `prepare_world_reset`;
2. after the incoming file is fully validated, `reset()` (this is the ARCH-SAVE-004 "reuse one world's arrays"
   point);
3. restore the surface sections into the cleared owners;
4. `mount_underground` and the four `compose_underground_*` steps, if the file carries an underground mount;
5. restore the underground owners in ADR 1221's order;
6. publish.

The rollback after a failure is the same sequence, run from the rollback checkpoint file. No owner needs an
unbind API.

The composition steps must be replayable to the exact saved configuration. Which composer steps ran, and with
what content, is itself saved state. It belongs in §6 as a small "underground mount" record, and the underground
step must define it.

## Construction's missing restore

`save_owner_construction.gd` validates a framed §4 block (`framed_refusal`). It captures and restores nothing.
Restoring Construction needs:

1. A live bulk copy/restore over its 16 frozen columns.
2. §5's `_delivered_milli` ledger, restored in the same call so that a half-applied pair never exists.
3. A home for ConstructionPaidLedger. This is UNRESOLVED; see Q7.
4. Purposes 4–6 (REMOVE_FURNITURE, EXCAVATION, SPATIAL_FURNITURE). These lie outside ADR 0186's frozen enum, which
   rejects them until a versioned codec exists.
5. The authority WeakRefs. These are re-bound by re-mounting the Session; they are never saved.

Item 1 has a clear contract; items 2–4 wait on Q7. Until they are settled, a world with an open demolition, an
excavation project or a paid package cannot be captured. The capture must **refuse** it explicitly, not drop it.

## File format

The format is already ruled; this section only collects the rules.

- **Header.** `RWLSET01`, format 2, 264 bytes, the endian sentinel, the completed tick, the five identity hashes,
  the redundant economic admission checkpoint, and a body SHA-256 (ARCH-SAVE-001, SAVE-REPLAY-R01).
- **Sections.** All 15 must be present, each with a 64-byte descriptor: id, schema_version, offset, length,
  row_count, CRC-32/ISO-HDLC and zeroed reserved bytes. Sections are column-major, in declared field order, with
  ascending slots (ARCH-SAVE-002, SAVE-LAYOUT-R01).
- **Versioning.** Exact version or refuse. Released versions are immutable. Development saves get no migration
  promise (SAVE-R09-001; `rulings/2026-09-12_save_registry_answers.md`). The **release** policy is open; see Q1.
- **Canonical hash.** ARCH-HASH-001 over every owner, through registered walker adapters (§15).
- **Compression.** Not ruled; see Q3. The header's exact total length and body digest assume the bytes are what is
  hashed.

## Transactional load (ARCH-SAVE-004, ARCH-MEM-006)

The memory gate is ruled: a **disk-backed** rollback checkpoint, never a second resident world. DEC-053's 150 MB
gate does not reopen this, because "the headroom … is not an allowance".

The load runs in this order:

1. `GameManager.begin_load()` raises the LOAD pause and barrier.
2. Capture the live world into `<slot>.rollback` through the same writer, then re-read and verify it.
3. Stream-validate the incoming file: header, table, CRCs, digest and identity.
4. Decode each section into section-local inactive records, one at a time with bounded buffers, and run every
   pure validator (`save_owner_*`, claim reconciliation, the cross-checks). Sorted joins use temporary files.
5. Recompute the incoming state digest.
6. Retire the world (see "The one-way bindings").
7. Apply each section in dependency order: §3 + the §1 cursor, §1, residents, jobs (§4 + §5 together), §7, §8, §9,
   §10, §11, §12, §14, then §6 (surface owners, then the underground mount and its owners).
8. Rebuild the derived indexes.
9. Recompute the digest; it must equal step 5's.
10. `publish_restored_world()` and then `end_load()`.

**Failure handling:**

- A failure before step 6 leaves the old world untouched.
- A failure after step 6 re-runs steps 6–10 from the rollback file, then calls `rollback_load()`.
- If the rollback itself fails, the game stays in an unrecoverable LOAD pause, and both files are kept.
- The incoming file is never modified.

**Save.** The save runs only at a completed tick boundary, with every quiescence gate passing: Delivery,
ConnectorWork, the Budget and Contacts. It streams to a sibling temp file in 65536-byte chunks, re-opens and
verifies it, then renames it over the target. Rotation happens only after that verification (ARCH-SAVE-003).

The policy for when a gate refuses is Q5.

Each memory addition is recomputed in the 09.3 ledger as it lands.

## Where the underground section 6 plugs in

The orchestrator's step 7 ends with an "underground" apply group, and its capture has the matching group. The
underground step (ADR 1221 option B) supplies:

1. canonical declarations for the undeclared owners listed above;
2. the mount record;
3. codecs or proven-empty audits for Room orders, the bindings modules, the surface anchor and the Frontier;
4. codecs for Sites, Router, `room_projects`, `room_layout`, `spoil_tips`, `excavation_inventory` and Inventory's
   spatial columns;
5. a group restore in ADR 1221's order, ending with ADR 1218's entry record.

It calls the orchestrator's group interface, and the orchestrator does not change.

## Build plan

Each step is one commit, or a few, with exact round-trip and corruption tests.

0. **Reconcile the code with the registry.** Take §1 to schema 4 by adding the `underground_space_owner` block.
   Take §7 to section 6 with inventory owner 5, including the spatial endpoint columns.
1. **§9 bulk APIs** on `navigation` and `movement`, plus capture and apply (SAVE-COLUMNS-NAVIGATION).
2. **§4 owner bulk APIs** and capture/apply for the 15 owners that lack them, including Construction's 16 columns.
3. **§5 CHILD_ARENAS codec.** Jobs, Construction and Buildings restore their §4 and §5 halves atomically.
4. **The §6 body framing**, plus the surface owners: command_dispatch, crop_weather, ecology, buildings spatial and
   haul_planner. Then the Q7 owners (paid ledger, demolition, households, store_policy).
5. **§13 Chronicle** owner and codec (see Q8).
6. **Identity producers:** rules, lookup, map and engine (SAVE-R09-003), and the provenance prefix.
7. **§15 adapters** for every owner, so that the production digest stops refusing.
8. **Orchestrator capture and writer:** the quiescence gate, temp file, verify, rename and rotation.
9. **Orchestrator reader and transactional load:** the disk checkpoint, retire-and-reapply, and rollback.
10. **The underground step** (ADR 1221 option B), plugged into step 9's group interface.
11. **09.5 UI:** the save browser, F5/F9, the error panel, LOAD pause and startup recovery.
12. **ARCH-SAVE-006 parity:** save at tick 3000, then compare every tick from 3001 to 18000, plus the edge
    fixtures.

Steps 0–3 and 6–7 do not depend on any question. Steps 4, 5, 8, 9 and 11 do.

## Already answered (not asked again)

| Question | Answer and source |
|---|---|
| Slots | Manual saves, 5 rotating daily autosaves, a prewinter save and a pre-major-demolition quicksave (REQ-SET-158, ARCH-SAVE-003) |
| Autosave cadence setting | Daily / Every 3 days / Off, default Daily (UI §8) |
| Quicksave and quickload | F5 writes at the next tick boundary; F9 asks for confirmation (UI §5, UX-T12) |
| In-flight activity | Saved, not deferred: "save at any quiescent fixed-tick boundary, in flight or not" (ADR 1218, Brendan) |
| Dev-save compatibility | Refuse; no migration (SAVE-R09-001, 2026-09-12 answers) |
| Memory | Disk-backed rollback checkpoint (ARCH-MEM-006) |
| Load errors | Keep the file, report the reason and offer other saves (REQ-SET-161); error panel UI-SET-085 |
| Collapse | Never overwrite the previous autosave (REQ-SET-156) |
| Identity hashes | Producers ruled (SAVE-R09-003) |
| Underground in scope | Yes, with no separate save (DEC-031) |

## Questions only Brendan can answer

Each question gives the options and a recommendation (marked "Rec").

- **Q1. Release saves across content revisions.**
  - (a) Refuse any save whose rules or catalog hash differs.
  - (b) Write tested migrations for each release.
  - (c) Refuse until 1.0, then migrate.
  - Rec: (c). Development saves keep today's refuse rule.
- **Q2. File location and metadata.**
  - (a) `user://saves/<kind>/<name>.rwlsave`, with the browser row (settlement, date, real time, version) in a
    small sidecar outside the canonical hash.
  - (b) Put the row data in the file, in an extra non-canonical section.
  - Rec: (a). The format stays frozen and the browser does not open whole saves.
- **Q3. Compression.**
  - (a) None.
  - (b) An outer deflate/zstd wrapper around the canonical bytes.
  - Rec: (a) for now. The hashes are defined on the raw bytes. Section 1 alone is 3,752,768 bytes; the whole-file
    size has not been computed yet.
- **Q4. Unspecified slot details.**
  - The number of manual slots: unbounded, or capped. Rec: unbounded.
  - The number of quicksave slots. Rec: 1.
  - When the daily autosave fires. Rec: the first quiescent boundary after midnight.
  - What triggers the prewinter save. Rec: the first midnight of the last autumn week.
  - Whether "Off" disables prewinter. Rec: no.
- **Q5. A save requested while an owner refuses for quiescence.**
  - (a) Defer to the next quiescent boundary, up to N ticks, then show an error.
  - (b) Refuse at once.
  - Rec: (a). F5 already says "at next tick boundary".
- **Q6. The pre-demolition quicksave** (open as Q-S5). When is it taken, and what counts as "major"?
  - Rec: take it when the player places the order; "major" means any building demolition, not a single piece of
    furniture.
- **Q7. Where the UNRESOLVED state lives** (Q-S4 / CONSTRUCTION-SAVED-BINDINGS): the paid ledger, demolition
  admission and work, households and store_policy.
  - (a) Each becomes its own new §4/§5 owner, and the frozen owners stay frozen.
  - (b) Append them to buildings and construction under new owner schemas.
  - Rec: (a). It touches no frozen contract and versions independently.
- **Q8. The Chronicle (§13).**
  - (a) Ship the owner with a count, a digest and an empty event inventory, so a save is development-only until
    events are authored.
  - (b) Author the event and detail inventory first.
  - Rec: (a).
- **Q9. Scope of the first deliverable.**
  - (a) A development save that refuses to capture any world holding state that has no codec yet, with an explicit
    `SAVE_UNSUPPORTED_STATE` code.
  - (b) Nothing ships until every owner is covered.
  - Rec: (a). It is testable at once, and `release_save_ready` stays false.
- **Q10. Startup recovery.** What happens to leftover `.tmp` or `.rollback` files at launch?
  - Rec: delete a `.tmp` whose target verifies. Keep a `.rollback` and offer it as "recovered".
  - Rename an unverifiable target to `.corrupt` and report it. Never delete a save.

## Build notes

These record the engineering choices made while building, step by step.

- **Step 0, section 1.** `save_section_01.gd` now carries the registry's tenth owner,
  `underground_space_owner`, and section 1 is at schema 4.
  - There are exactly two compiled layouts. UNMOUNTED is a world with no underground Session: capacities 0, an
    all-zero header and empty columns, 416 payload bytes, for a section of 3,753,231 bytes. MOUNTED is a world at
    the production pack of 6,144 regions and 2,048 sources: 504,224 payload bytes, for a section of 4,257,039 bytes.
  - The decoder reads both capacity scalars at their compiled offsets, which are the same in either layout, and
    from them selects the layout. It then requires every later item at that layout's compiled offset.
  - Capture reads the owner only through `state_bytes()`, so it refuses unless the owner is at a completed
    boundary. `restore_space_owner()` is separate from `restore_section()`, because the Space owner exists only
    after the Session has been re-mounted.
  - The owner file is unchanged. Its wire order differs from the registry's ordinal order, and
    `SPACE_WIRE_ORDER` maps one to the other.
- **Step 6, identities.** The release rules and lookup artifacts need owner registrations, and none exist yet.
  The development save therefore states its rules and lookup identities as SHA-256 over a `-DEV-` domain and the
  canonical registry declaration id.
- **Step 5, the Chronicle digest's contract.** The Chronicle owner made `_rolling_digest` a category-1 packed
  column, but the canonical registry still marked the field `REQUIRED_NOT_PRESENT_IN_SNAPSHOT` with no source
  contract, so the save-registry handoff validator refused the drift. The field now carries contract C197 and
  the persisted packed-field count is 678. The declaration itself (fields, types, ordinals, hash flags) is
  unchanged, so the registry id and version stay at CL1 / 13.
- **Step 4a, section 6 framing.**
  - **Layout.** `store_count` is followed by all 13 declared owner blocks in ASCII order. Each block has §1's
    wrapper and its ordinary payload form.
  - **Generated table.** `save_auxiliary_state_schema.gd` is generated from the registry and the capacity audit
    (`tools/generate_auxiliary_state_schema.py --check`, run in CI).
  - **Field rules.** Each field is SCALAR, FIXED(n), or BOUNDED(max). A BOUNDED count is checked before any byte is
    sliced.
  - **Fields with no proven bound.** Nineteen count fields have no bound that either file proves:
    - Inventory's spatial endpoint columns. ADR 1072's pack says 1,024.
    - Spoil Tips' columns. ADR 1072 says 256.

    These are compiled as UNPROVED, and they accept zero elements only. A world holding either kind of state
    therefore refuses to save, as DEC-055 Q9 requires. When their adapters are built, the bound must come from an
    audit row, never from prose.
  - **Unsupported owners.** Owners with no adapter yet use `UnsupportedAdapter`. It writes the canonical empty block
    or refuses `SAVE_UNSUPPORTED_STATE`.
- **Step 3, section 5 framing.** Section 5 uses section 6's owner-block wire form over its five owners
  (buildings, construction, forage, jobs, orchard_hive). Its table is generated by
  `tools/generate_auxiliary_state_schema.py --section 5` into `save_child_arenas_schema.gd`. Every field is FIXED
  at a proved capacity or SCALAR, so the section is exactly 5,081,011 bytes. `save_section_child_arenas.gd`
  mirrors the section 6 codec instead of sharing it, because GDScript binds a preloaded `Schema` per script; it
  has no owner-adapter registry, because Jobs, Buildings and Construction restore sections 4 and 5 in one joint
  bridge call that the orchestrator makes with both halves.
- **Q7(a), five new section 6 owners.** Section 4's owner set is frozen at 18 (SAVE-S4-STREAM-R01), so, as
  ADR 1221 did for `haul_planner`, the Q7 state becomes section 6 owners. Registry v14
  (`RWL-CANONICAL-REGISTRY-2026-10-07-SL1`), section 6 schema 8, 18 owners:
  - `construction_paid_ledger` (C198): `_paid_base_type`, `_paid_upgrade_mask`, 82,944 rows.
  - `demolition_admissions` (C199): the project and output pairs, the reserved grams, the admitted charge and
    the destination revision, 1,024 Building rows.
  - `demolition_work` (C200): the evacuate-then-demolish intent and the removal Job link (a demolition or one
    piece's furniture removal), 1,024 Building rows. The Job link is saved, not rebuilt by a Job scan.
  - `store_policy` (C201): decision 1031's filter and minimum arenas (262,144 cells) and the binding stamp.
  - `construction_extension`: Construction's sixteen section-4 columns again, for the rows whose purpose is
    outside ADR 0186's frozen enum (REMOVE_FURNITURE, EXCAVATION, SPATIAL_FURNITURE, SPOIL_TIP,
    CONNECTOR_INSTALL). Such a row is the clear row in section 4 and the real row here; every other row is the
    clear row here. It re-carries construction's own members, so it has no source contract of its own.

  Households keep their UNRESOLVED rows: there is no production instance, so a world never holds that state.
  The declaration grows by 1,115 bytes; the joint pack is 100,211,016 bytes (49,788,984 below DEC-053's gate).
- **Step 8, capture.** `settlement_save_capture.gd` captures sections 1-14 from a `settlement_save_world.gd`
  World binding; `settlement_save_owners.gd` dispatches every section 4, 5 and 6 owner to its bridge or adapter.
  - **Absent owners.** Production composes no spatial map, field policy, injury store, event schedule or
    Chronicle, and no movement until an underground Session mounts. The World binds fresh instances for them, so
    their captures are the canonical empty images; a load must prove the incoming records equal a fresh capture.
  - **Descriptor facts the rulings leave open.** Section 3 and section 10 are written at schema 1. Section 7's
    row count is the sum of its six owners' primary counts, section 10's is its nine streams, section 14's its 512
    name rows and section 15's is 1.
  - **Underground owners.** Until step 10 they use `UnsupportedAdapter`, so a mounted world (or a bound spatial
    inventory endpoint) refuses SAVE_UNSUPPORTED_STATE rather than losing state.
- **Step 9, load.** `settlement_save.gd` validates the whole file, decodes every section
  (`settlement_save_decode.gd`) and recomputes section 15 over the decoded records before any world is touched.
  It then retires the target through its own `reset()`, binds the empty command queue to the manager's clock (a
  queue cannot rebind while a load barrier is held), opens the load, applies every section in dependency order
  (`settlement_save_apply.gd`) and proves the result by recapturing it: sections 1-14 must come back
  byte-identical, with the same section 15. A refusal after the load opened rolls the clock back and resets the
  target, so it is left empty rather than half-restored.
  - **Section 14's apply** snapshots the prior names raw for its rollback. A validating capture there refused the
    deliberately mid-restore state (section 4 has installed the `_named` flags, the names are still cleared).
  - **The settlement's resident list** (`_live_slots`) is not registered state; it is rebuilt as the present
    residents in ascending persistent id, which is the order `create_initial_settlement()` appends them in.
- **Step 10, the underground body.** Built as [ADR 1228](1228-underground-save-body.md): the mount record and six
  wire owners in section 6 (registry v15/v16), the declared underground owners' adapters, a re-mount on load and
  the ADR 1221 restore order. The live entry chain saves to a file at six checkpoints from the surface walk to
  the installation, loads into a fresh settlement each time and continues byte-identically. The load also binds
  the ground-pile composer to the restored World row, which the surface load had missed.
- **Step 2, memory.** Every section-4 capture and apply makes a transient owner image. It is charged to "ADR 1222
  save/load working set" in the reviewed census deltas, and the 09.3 ledger owns the total. It is never resident
  between ticks.
- **Step 11, the save controls (partial: the browser waits on Brendan).** `scripts/ui/ui_save_session.gd`
  is the one path between the HUD and `settlement_save_slots.gd`. `scripts/ui/ui_save_controls.gd`, a node
  `main.gd` adds, owns one, polls it every frame (also while paused) and turns its signals into notices
  and UI-SET-085. **Why not UIManager:** `ui_manager.gd` and `ui_notices.gd` are reviewed witnesses of the
  underground memory census (`tools/underground_room_memory.py`, an immutable manifest), so editing either
  breaks `underground_memory_budget.py --check`. The controls therefore use the HUD's existing notice
  categories ("Settlement notice" for a save, a load and a recovery report; "Action refused" for a
  refusal) with the save's own wording in the message. Built:
  - **F5** (`save_quick`, `main.gd`): the quicksave at the next quiescent boundary.
  - **Autosaves:** the poll that first sees a new absolute day queues that midnight's daily slot on the
    cadence and the prewinter slot whatever the cadence (Off keeps prewinter). A day that moved by anything
    but one (the first poll, a load) only resynchronises: a missed midnight is never saved late.
  - **Busy (Q5):** the 30-tick wait is counted in completed ticks, so **while the world is paused a busy
    save is reported at once** (`SAVE_BUSY`) instead of waiting for a boundary that cannot come.
  - **Pre-demolition quicksave (Q6):** `order_demolition()` saves the slot, then places "evacuate, then
    demolish". A busy running world holds the order behind the queued save and places it when that save
    finishes or is dropped. **A save that fails for any other reason is reported and the order is still
    placed:** the slot is a safety copy, not a gate, and every development world that holds unsupported
    state would otherwise be unable to demolish anything. No UI places a demolition yet (UI-SET-034 is
    unavailable), so this is the entry point that panel must call.
  - **Launch recovery (Q10):** `enable()` runs the slots' recovery once and raises one notice per file
    kept, renamed `.corrupt` or removed (code `SAVE_RECOVERY_<ACTION>`).
  - **Development-only (Q8/Q9):** every Settlement saved notice ends "Development save: it loads only in
    this exact build of the game."; a refusal (`SAVE_UNSUPPORTED_STATE` and the rest) reaches UI-SET-085 as
    the code, a plain reason and the recovery action, and is kept as an error notice.
  - **Only the game scene turns the controls on.** `main.gd` adds and enables them when it is the scene root. The
    live demo instances `main.tscn` and draws a world, cast and services the settlement save does not
    carry, so there no controls exist: no autosave runs and F5 does nothing (a session that was never
    enabled refuses `SAVE_SESSION_DISABLED`).

  **Not built, because §4 leaves choices only Brendan can make:** the save browser (UI-SET-076/077), the
  game menu (UI-SET-078) and F9's confirmation, which by §4 is the browser's Load (066). `quickload_row()`
  and `load_slot()` are the calls those surfaces make. UI-SET-076/077 stay UNAVAILABLE, now naming the
  missing browser rather than missing files. The open choices: which of §4's three tabs (Manual, Autosave,
  Prewinter) holds the quicksave and the pre-demolition quicksave; how a manual save is named; how a
  recovered `.rollback` file is offered; where the development-only statement sits in the browser; and
  whether 078's Settings and Main menu, which have no owner, show as Unavailable.

  **Also open:** UI §3 auto-pauses on a save error (CRITICAL). No acknowledgement surface exists for a
  CRITICAL that is not the clock's overload, so a save error is an Error notice and does not pause.

  **Measured cost** (generated settlement, this Mac, 2026-10-08): a save takes about 33 s and writes
  56,989,480 bytes; a load about 66 s. Every autosave therefore stalls the frame it runs in for that long.

## Brendan's answers (DEC-055, 2026-10-07)

Brendan took the recommendation on every question, Q1–Q10. The coordinator relayed his answers and authorised
this lane, as integration lead, to edit the shared registry, header, version and validator files that the plan
requires.

The underground §6 body and mount record (ADR 1221 option B) are built inside this plan, at step 10.

**Prewinter timing, confirmed (2026-10-08).** Brendan confirmed in chat that the prewinter save fires at the first
midnight of autumn's last seven days: entering autumn day 6 of 12 (`settlement_save_slots.gd`,
`PREWINTER_SEASON_DAY`). DEC-055 Q4 records it.

**Engineering choice for Q5.** A busy save waits at most **30 ticks**, one real second at 1x. Every underground
quiescence gate is synchronous within a tick, so a boundary that still refuses after 30 ticks is a stuck owner,
not a slow one. The save then reports `SAVE_BUSY` with the refusing owner's code.

## Consequences

- No code that mounts a second Session over live owners, and no "unbind" API, may be written; the load path is
  retirement.
- Construction, demolition, households and store_policy cannot be captured until Q7 is answered. Under Q9(a) a
  capture refuses them.
- The two registry drifts (§1 and §7) must be fixed before any orchestrator writes a file.

## Source

Brendan's chat decision of 2026-10-07; ADR 1218; ADR 1221; task 09; REQ-SET-156/158–161; ARCH-SAVE-001–007/009;
ARCH-HASH-001; ARCH-MEM-006; SAVE-R09-001/003; DEC-031; DEC-053; `docs/handoff/OPEN_QUESTIONS.md` Q-S4–Q-S6.
