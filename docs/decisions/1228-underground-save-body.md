# 1228 — The underground save body: the mount record, the wire owners and the re-mounted load

Date: 2026-10-08 · Status: Accepted; built in steps (ADR 1222 step 10, ADR 1221 option B, DEC-055).

## Context

ADR 1222's settlement save writes sections 1-15 and loads a surface world into a fresh settlement,
proved by recapture. A mounted underground Session refuses the save: its owners use
`UnsupportedAdapter`, and buildings, inventory and construction refuse their spatial rows. ADR 1221
built the owner codecs (Routes, WorldRoutes, Contacts, the Planner) and ADR 1222 records that a load
must re-mount the Session through the world-retirement path, never mount a second Session over live
owners. This record decides how the underground state is carried and loaded.

## Decision

### 1. Seven new section 6 owners (registry v15, `RWL-CANONICAL-REGISTRY-2026-10-08-UG1`)

Section 1's layout and section 4's owner set are fixed, so, as ADR 1221 did for `haul_planner` and
DEC-055 Q7(a) for the five Q7 owners, the new state is section 6.

- **`underground_mount`**, the mount record ADR 1222 asks for: `_mounted` (u8), `_operations_prefix`
  (i32: the composition prefix the Session reached, 0, 4, 8, 9 or 17) and `_content_digest` (32 bytes,
  the SHA-256 of the mounted content). A Session mid-composition or with a retained failed prefix
  refuses the save.
- **Six wire owners**, one per ADR 1221 or earlier owner codec that already writes its own versioned,
  validated image: `underground_locations` (110,464 bytes), `underground_routes` (320,608),
  `underground_world_routes` (84,184), `underground_connector_contacts` (74),
  `underground_connector_placements` (43,776) and `underground_connector_workpieces` (5,436). Each is a
  `wire_length` (u32) and a bounded `wire` (u8) whose maximum is the production image size; an
  unmounted world writes length 0. The persistence registry's "§1 WORLD" rows for these owners move
  to section 6. Placements and Workpieces stream to a file, so their adapters stage the image through
  one temporary file under `user://`.

Registry v15: section 6 schema 9 with 25 owners; 810 canonical records (+15, none packed); 75 owners,
820 fields and 12,145 key bytes, so the shared declaration grows by 642 bytes (7 × 16 + 15 × 15 + 305)
to 25,645. The joint pack is 100,211,658 bytes, 49,788,342 under DEC-053's gate.

Registry v16 (`...-UG2`, section 6 schema 10) proves the one bound the first capture hit: Inventory's
five spatial endpoint columns had a count field and no bound, so the generated schema admitted only
empty columns. They now carry `max_count` 1,024 (`SPATIAL_ENDPOINT_CAPACITY`). No record, field or
key byte changes, so the declaration bytes and the joint pack are unchanged.

### 2. Content

The mounted content is immutable and large (7 MB); it is identified, not saved. A load takes the
target's own mounted content, or a caller-supplied one, and refuses if its digest differs from the
record's.

### 3. Load order

After section 3, the world runtime and section 1's ordinary owners, the loader re-mounts the target
(`mount_underground` and the composer steps up to the saved prefix), then restores section 1's Space
block into the new Session's owner, then section 4 onwards as before. The section 6 underground
owners are applied after the surface section 6 owners: the Space block; funding, Sites and the
Router; Placements and Workpieces; Locations; the spatial endpoints; Routes; WorldRoutes; Contacts;
the Planner; then Placements' full `audit()`; and ADR 1218's entry record last. ADR 1221's order put
Locations first and Sites and Placements later because its cold restores kept those owners live. A
fresh load cannot: Locations' survey reads Sites, and its installed endpoints are proved from the
Placements' installed prefixes, while a Placement's anchor is itself a Location. So Placements
restore first with only their anchor check deferred, and the closing `audit()` proves the anchors
against the restored Locations. The composer
steps must see a quiescent, unoccupied world, which is why they run before any underground owner is
restored.

### 4. Owners with no production instance

Production composes no `RoomLayout`, `RoomProjects` or `SpoilTips` instance. Their section 6 blocks
stay canonical empty, and an instance holding state still refuses (fail closed), as DEC-055 Q9 does
for the surface's absent owners.

### 5. What is not saved

The registry calls the remaining underground members category 2 or 3 (scratch, derived indexes, the
Space authority's proof cache, binding scopes). The goal chains are the evidence for those calls: the
whole world is saved and reloaded on a fixed period through the live chain and must finish
byte-identically to the uninterrupted run.

## Build steps

1. Registry v15 and this record.
2. Capture: the mount record, the wire adapters and the declared underground owners' adapters
   (excavation sites, excavation inventory, modular projects, inventory's spatial columns), and the
   buildings/section 1 spatial rows.
3. Load: re-mount, then restore in the order above.
4. The goal tests: the live host chain saved and reloaded on a period, and the hauled prefix saved to
   a file, loaded into a fresh settlement, continued and compared byte for byte.

## Build notes

### What a load does with a mounted save

`settlement_save_apply.gd` runs, after section 1's ordinary owners:

1. **World wiring.** Decision 0532's ground-pile composer owns every pile as the World row, which
   `materialize_starter_colony()` binds in a generated world and no section carries. The loader binds
   it to the World row section 3 restored. *This was a latent bug in the surface load too:* a loaded
   world's composer kept a null World, so the first new pile would have been ownerless. The
   re-mount found it, because `UndergroundSession` checks that binding.
2. **Re-mount.** With the record's content (the target's own, or the caller's; the SHA-256 must
   match), `mount_underground()` and the composer steps up to the saved prefix. Then the world's
   underground view is re-bound, so section 4's movement owner is the new Session's.
3. Sections 4 and 7 as before; section 6 in `AUX_APPLY_ORDER`, with section 1's Space block restored
   first in the underground group; the entry record after section 14
   (`SettlementSystem.restore_underground_entry()`, which adopts the restored runtime only into a
   mounted host that has none).

The recapture proof then requires sections 1-14 byte-identical and the same section 15.

### The disk checkpoint and slots

`load_bytes(..., rollback_path)` saves a populated target to `rollback_path` (through the same
atomic writer) before it is retired. A failure after retirement re-applies that checkpoint into the
reset target, rolls the clock back and closes the load; the checkpoint is removed after it restores
or after a successful load. If it will not restore, the target stays empty, the barrier stays held
(`REFUSE_ROLLBACK`) and both files are kept. An empty target needs no checkpoint.

`settlement_save_slots.gd` implements DEC-055 Q2, Q4, Q5 and Q10: `user://saves/<kind>/<name>.rwlsave`
with a JSON sidecar, five rotating daily slots, one quicksave, one prewinter and one pre-demolition
slot; a scheduler that saves at the first quiescent boundary and drops a request still SAVE_BUSY after
30 ticks; and launch recovery that never deletes a save. The calendar has no week (seasons are 12
days), so "autumn's last week" is its last seven days, and the prewinter save fires at the midnight
that begins autumn day 6. This was an engineering reading when built; Brendan confirmed it on
2026-10-08 (DEC-055 Q4).

### Owner changes the load needed

- **Buildings** (commit 2de3ac8b): underground Rooms through the joint bridge and section 1.
- **Inventory**: section 7's canonical copy no longer refuses a world holding spatial endpoints; it
  admits an anchor `-2 - row` for a distinct endpoint row (never a satchel, and a spatial pile skips
  the tile map). The canonical restore still requires an empty arena: section 6 fills it later and
  `_audit_spatial_endpoints()` proves every anchored container.
- **Placements**: `_audit_bank()` required the staged image's frontier pin (header 14 and digest
  bytes 96-127) to equal the live bank's. A re-composed Session has never admitted an entry, so its
  pin is empty and the saved one could never restore. `restore_file()` now adopts the image's pin
  into a never-admitted empty store, and in that case defers only the anchor-liveness check to the
  loader's closing `audit()` (above); every other audit is unchanged.
- **Entry bindings**: the Placements authority's `restoration_refusal()` was the fail-closed base, so
  no Placement image could restore at all. The entry composition's authority now proves the staged
  frontier pin is unpinned or exactly its bound frontier source. Placements' own audit already proves
  every staged Room, section, anchor and Project against the restored owners. The installed parts'
  geometry is not re-derived here: an attempt to recognise installed timber by its Space claim was
  wrong (a confirmed Room's reserved cuts share that claim), so the geometry stays the restored
  Space's own image, re-read by the next installation's proofs.
  **Closed (2026-10-08):** the loader's closing cross-audit now runs `save_installed_geometry.gd` after
  Placements' `audit()`. It works from the Placements towards Space, never the reverse: for every
  installed part of every live Placement, the unclaimed regions with the part's Corridor owner, level
  and role (SUPPORT for treads, risers, posts and ramp decks; OBSTACLE otherwise, exactly as
  `_stage_timber_part` adds them) must cover its prism (by union, so a region split along its own
  faces still proves), and no unclaimed air may overlap it. A Room's reserved cuts carry a Room claim
  and are never asked to cover anything, so they cannot false-match. Evidence:
  `test_save_installed_geometry.gd` (the live chain's installation proves; an extra claimed group or a
  region that lost its owner refuses) and the goal test above, whose loads after the installation
  pass the proof.
- **Locations**: a cold load re-proves every row against the restored Space, and refused a work
  endpoint that the paid L0 piece had since been set down on. That overlap is legal in play: the
  piece is set down after the endpoint was proved, and WorldRoutes keeps every body out of it
  (`workpiece_occupancy_refusal`). While a load re-proves its rows (`_loading_rows`, false otherwise),
  an unclaimed obstacle owned by a live connector-installation Project is therefore not a blocker.
  Publication is unchanged.
- **Construction**: `retire_excavation_phase()` and `retire_modular_phase()` returned the row to the
  never-used clear row except its worker capacity. The frozen section 4 type gate refuses a typeless
  row with a worker capacity, so any world that had retired a paid phase could not be saved. They now
  clear it too.

### Evidence

`test_settlement_save_underground.gd`:

- A composed Session saves, loads into a fresh settlement (re-mounted through all four composer
  steps, a Session of its own) and saves byte-identically. Without its content the load refuses
  `SAVE_UNDERGROUND_MOUNT`, leaves the target empty and closes the load.
- **The goal test.** The live entry chain (claw content 9, ADR 1217 step 5) is driven by the
  GameManager from `begin_underground_entry` and saved at ticks 210 (the surface walk), 1200 (task
  4, two hauls), 2004 (task 9), 2805 (task 12, the paid L0 installation with its piece set down),
  3609 (task 15), 4410 (task 19) and 4800 (stopped at the next gap, `ENTRY_DESCENT_UNBUILT`). Each checkpoint's save is written to a file, loaded into a fresh
  settlement and run to the next checkpoint, where its save is byte-identical to the uninterrupted
  run's.

- A failed load over a populated target (a mounted save with no content to re-mount) restores the
  target from its disk checkpoint byte for byte and closes the load.

`test_settlement_save_slots.gd` covers slot names, a slot round trip with its sidecar, a checkpoint
that cannot be written (refused before the target is touched), the autosave timing, the scheduler's
30-tick wait and launch recovery.

`test_save_underground_columns.gd` round-trips Sites, funding, the Router and the spatial arena at
tick 2000 and refuses damaged images without a write.
