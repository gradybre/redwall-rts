# Buildings owner-0 local validator — feasibility review
Read-only audit. No contract accepted, no code changed, nothing executed here.
## Re-derived shape
29 fields over three row groups. 4 u8 fields: `_b_present` 1024, `_r_present` 16384,
`_f_present` 81920, `_r_valid` 16384 = 115712 bytes. 25 i32 fields: 9x1024, 8x16384,
8x81920 = 36864 + 524288 + 2621440 = 3182592 bytes. Value bytes 3298304, matching the
snapshot. Payload = 3298304 + 29x8 count headers (232) + child header 4 + 2 extents x8
(20) = 3298556. Block = 4 + 9 key bytes + 4 version + 8 primary + 8 payload_length (33)
+ 3298556 = 3298589. All three agree with `source-layout.json`; primary_count 1024 is
the building group only, and the 16384 room rows coincide with section 1's tile count by
accident of ROOM_CAPACITY, so every bound must be taken from `element_count(0, field)`.
Self identities (`_b_ref_*`, `_r_ref_*`, `_f_ref_*`), the building/room/furniture chain
links, `_b_room_count`, `_r_furniture_count`, `_f_kind_count`, `_room_tile_id` and the
three tile maps are **not** among these 29 fields. A local predicate therefore cannot
check mask-versus-chain agreement, tile-run coverage or parent liveness; those stay with
the sections 1/5 joins in the full common file.
## Writer-derived local domains
Active (`present==1`) rows, from `place_building`/`designate_room`/`place_furniture`,
the public setters, and `_clear_*_columns`:
- Building: type 0..29; tier 1, or 2 only for ids 5, 12, 23, 29; origin 0..16383;
  rotation 0..3; state 0..5; condition 0..INT32_MAX; construction slot null or any
  structural slot; interior -1 or 0..INT32_MAX; rotated footprint inside 128x128.
- Room: type 0..7; building slot non-null structural; tile_count >= 1; tile_offset >= 0
  with offset+count <= 16384; temperature full signed i32; mask 0..511; occupants
  0..256; valid 0/1.
- Furniture: type 0..8; room slot non-null structural; origin 0..16383; rotation 0..3;
  user null or structural; condition 0..INT32_MAX. Edge kinds (ids 3, 4) have a 0x0
  floor footprint, so no rule may require a floor tile.
Both u8 presence columns and `_r_valid` are strictly 0 or 1; 2..255 is unrepresentable
by any writer and must be refused.
## Never-used defaults versus retained history
`_clear_*_columns` writes distinct defaults: building origin -1 and tier 0; room and
furniture parent slot -1; furniture origin -1. Destructors keep more than they clear.
`demolish_building` clears presence and self-reference only, retaining type, tier,
origin, rotation, state, condition, interior and a possibly stale construction
reference. `remove_room` resets tile_offset, tile_count, mask and valid to 0 but keeps
type, parent, temperature and occupants. `remove_furniture` keeps type, parent, origin,
rotation and condition, and requires a null user first, so a retained furniture row
always has a null user.
Discriminants, each traced to a writer: `tier == 0` occurs only in the clear image,
because placement writes MIN_TIER and `accepts_tier` rejects anything below it;
`_r_building_slot == -1` and `_f_room_slot == -1` likewise occur only in the clear
image, because designation and placement copy a live reference. `origin_tile == -1`
corroborates for buildings and furniture. Do **not** key on the generation column:
`NULL_GENERATION` and the first live generation are not pinned by any file in scope.
A free-row all-zero rule would refuse the legitimate clear image itself (origin -1, slot
-1) and would also refuse every retained row. An "every inactive row equals the clear
image" rule refuses all retained history. Both must be rejected.
## Cold immutable facts
Yes — use a static, source-pinned keyed fact table, not a live `BuildingDefinitions`
construction. That constructor allocates 18 packed arrays and relies on `assert`, which
is stripped in release builds, so its key-set and station guarantees are not runtime
guarantees. The validator needs exactly: building id count 30, furniture id count 9, the
tier-2 id set {5, 12, 23, 29}, and the 30x2 footprint pairs for the rotated-fit rule.
Pin those as constants and add a test-time parity assertion against `BUILDING_FACTS` and
`Catalog.BUILDING_DEFINITION` so catalog drift fails a test rather than a player's load.
## Source pins and safe access
Pin `buildings.gd` 8f21111b..., `building_definitions.gd` eedac020..., `catalog.gd`
3fcc0665..., `save_component_columns_schema.gd` 3ba6151c.... **Gap:**
`entity_directory.gd` is unpinned yet supplies NULL_SLOT, NULL_GENERATION,
RESIDENT_LIVING_CAP (256) and KIND_CAPACITY; pin it before freezing occupants or the
null discriminants.
Access rules: validate all 29 extents against `element_count(0, field)` before reading
any element; bind row counts per field, never from one shared constant; index type
buckets by `storage_index`, never by the owner-local ordinal; if a Dictionary is
accepted, check `has(key)` and `typeof(...) == TYPE_PACKED_INT32_ARRAY` /
`TYPE_PACKED_BYTE_ARRAY` per entry, since a failed cast yields a legal-looking empty
array.
## Producer findings (counterexample-backed)

- `set_room_valid` accepts an externally supplied boolean on a room with mask 0 and no
  furniture; the supplied probe log records this across 3 tests / 40 assertions. A rule
  "valid implies the countable room rules hold" is producer-false.
- `set_furniture_user` does not consult `user_slots_of`, so a decoration or partition can
  carry a non-null user. A rule "user non-null implies user_slots >= 1" is producer-false.
- Stale non-null construction references survive demolition and external destruction by
  design. Treat them as structural only; do not invent cleanup.
- `restore_section_1_columns` validates local ranges only, so tile-map/row agreement
  remains a separate caller-invoked cross-check, not an installation guarantee.

## Memory gap and the Columns proposal

The 6417408 allowance was derived for Construction (4893696 + 2x663552 + 3x65536). A
full caller image plus a fully allocated default Columns image peaks at 6596608, i.e.
179200 over, and the stream contract forbids a second full-owner copy. Do not raise the
budget. With no second image, Buildings' own worst case is 3298304 + 2x327680 (largest
field, 81920 i32) + 3x65536 = 4150272, leaving 2267136 bytes of headroom.

Risks of `allocate_defaults=false` plus 29 share-assignments: (a) a two-mode object where
a forgotten assignment leaves an empty typed column — mitigate by having every predicate
entry point call a complete `is_sized` first, and kill a dropped-assignment mutant; (b)
the predicate borrows caller buffers, so "pure" must be proven, not asserted — compare
every input array before and after, and kill a single-cell-write mutant; (c) packed-array
assignment is copy-on-write, so an accidental write would silently allocate rather than
corrupt the caller, which means the purity test protects the caller's data but does not
by itself prove no allocation; (d) empty-array and object overhead is unmeasured.

Alternative worth reviewing first: validate directly from the decoder's `FramedOwner`,
whose `u8_column`/`i32_column` accessors already return the stored column without
duplicating it. That adds no constructor mode and no second image at all; its cost is
coupling the validator to the codec record, so capture-side callers holding raw arrays
would need a thin wrapper. Either way the envelope stays at 6417408.

## Verification scale

Avoid a full-store predicate re-run per field per row; 81920 rows makes that quadratic.
Proposed bounded design: for each of the 29 fields, three witness rows (first, last, one
interior) x {low endpoint, high endpoint, one just-outside value}; one full-capacity
mixed valid image checked once for acceptance and once for non-mutation; one clear image;
one all-retained image. Because per-row coverage is sampled, the sampling itself must be
attacked: include mutants that check only row 0, only even rows, and only the first
group, and place at least one invalid witness at the final row of the 81920-row group so
those mutants die. Do not claim exhaustive per-row fault injection. Record a real
wall-clock measurement of the full-capacity path before asserting any time budget.

## Open before contract

Pin `entity_directory.gd`; decide FramedOwner-based versus bridged Columns; settle the
priority order when several field rules fail in one row; confirm whether the rotated
footprint rule belongs locally or in the section-1 cross-check.
