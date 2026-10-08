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

### 2. Content

The mounted content is immutable and large (7 MB); it is identified, not saved. A load takes the
target's own mounted content, or a caller-supplied one, and refuses if its digest differs from the
record's.

### 3. Load order

After section 3, the world runtime and section 1's ordinary owners, the loader re-mounts the target
(`mount_underground` and the composer steps up to the saved prefix), then restores section 1's Space
block into the new Session's owner, then section 4 onwards as before. The section 6 underground
owners are applied after the surface section 6 owners in ADR 1221's order: Locations, Routes,
WorldRoutes, Placements, Workpieces, Sites, Router, Contacts, the Planner, and ADR 1218's entry record
last. The composer steps must see a quiescent, unoccupied world, which is why they run before any
underground owner is restored.

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
