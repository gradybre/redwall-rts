# Construction real-history authoring guide

2026-09-20. Planning guidance for independent QA under CONSTRUCTION-S4-VALIDATE-R01v2. **None of the twelve histories below was executed for this guide.** Use the current frozen author packet; hashes below identify this source inspection. This is real public **component lifecycle** coverage, not complete gameplay construction, inventory conservation or whole-save acceptance.

## Fixture and observation rules

Use a fresh `Buildings.new()` and `Construction.new(buildings)` for each case, as `test_construction.gd:65–81` does. Construction borrows `buildings.directory()`; never create a separate Directory for its subjects. Read IDs through Catalog and assert the frozen witnesses: hall12, open_stockpile19, bed0; DORMITORY0; BLUEPRINT0, BUILDING1, ACTIVE2, DEMOLISHING5. Initial milestone mask1 and rotation0 are the existing fixtures, not new gameplay numbers.

Each mutator returns an OpResult. Assert `.ok`, and immediately return from that scenario on failure before using `.ref`/`.value`. Existing test helpers sometimes assert then keep going; the new author should strengthen setup control flow, not copy that accident. Capture target project `ref` and `row=opened.value` at its successful open; also assert `directory.get_typed_row(ref)==row` while live. Do not assume row0: setup build projects retire/recycle typed rows, while directory generations can change. Do not allocate another project between target retirement and its snapshot.

Observe genuine, unmodified `construction.state_bytes()` through the accepted engine-bound framing method in `retired-state-probe.gd`. Use its independent serialization-order table, running-engine `var_to_bytes` prototype lengths, total length check before slicing, and decoded type/count checks before indexing. Retain only the target row's16 scalars, four delivered cells and store live count. Public getters deliberately refuse after retirement. Do not read underscore fields, call `_retire`, reflect into private arrays, infer serialized offsets, or write a fake retired row and call it a real history. State serialization starts with container fields and puts `present` eighth; it is **not** the section4 canonical order. Same-type/length segment swaps remain outside this diagnostic's guarantees. Snapshot allocations are test-only and separate from the validator/bridge allocation campaign.

## Exact public setup recipes

**S — stockpile blueprint:** `buildings.place_building(stockpile_id,60*128+50,0,1)`; no rooms or occupants. This is the existing STOCKPILE_TILE. For a completed stockpile, open its BUILD project; deliver `(index0,4000)`; `begin_work`; `add_work_mwu(...,60000)`; `commit_completion`. Require ACTIVE, tier1, no building construction reference and `live_project_count()==0` before using it as a demolition subject. Build the subject through the real lifecycle; do not set ACTIVE directly.

**H — active hall:** `place_building(hall_id,59*128+58,0,1)`; `open_build`; deliver index0 wood100000, index1 stone60000, index2 cloth12000; `begin_work`; `add_work_mwu(...,2400000)`; `commit_completion`. This matches `_active_hall()` at `test_construction.gd:105`. Require ACTIVE/tier1, null project back-reference and Construction live count0. Keep the hall free of rooms for upgrade cases.

**F — placed bed:** make H; obtain hall origin through `origin_tile_of_building(hall).value`. Designate DORMITORY with four `PackedInt32Array` tiles `[origin+128+1,origin+128+2,origin+128+3,origin+128+4]`, the existing `_interior_tiles` recipe (`test_construction.gd:641`). Read the first tile through `room_tile_at(room.ref,0)`; `place_furniture(room.ref,bed_id,tile,0)`; then `open_furniture(bed.ref)`. Leave users/occupants empty. Do not set room-valid flags, interior identity or synthetic residents: the public placement fixture needs none, and this test claims no room-service validity.

For every target open, require `subject_ref_of(project)==subject`, `live_project_count()==1`, directory live subject/project and `project_of_subject(subject)==project`. Building targets also require `construction_ref_of_building(subject)==project`; furniture has no equivalent column and uses the public subject scan. All material-container references remain the actual initial null reference; this guide does not invent an Inventory handle merely to exercise clearing.

## Frozen target facts

| purpose | fixture/open API | type | delivery lines, in index order | W milli-WU | max_workers |
|---|---|---:|---|---:|---:|
|BUILD0|S / `open_build(stockpile)`|19|wood4000|60000|4|
|UPGRADE1|H / `open_upgrade(hall)`|12|wood20000; stone40000; cloth8000|1200000|4|
|FURNITURE2|F / `open_furniture(bed)`|0|wood2000; cloth1000|20000|4|
|DEMOLISH3|completed S / `open_demolition(stockpile)`|19|empty|15000|4|

These values agree with `frozen-source-facts.json` and the existing tests; demolition W=60000/4 uses the source construction price. Frozen full ledger vectors after delivery are BUILD `[4000,0,0,0]`, UPGRADE `[20000,40000,8000,0]`, FURNITURE `[2000,1000,0,0]`, DEMOLISH `[0,0,0,0]`. Do not derive expected values by calling the new validator or its COLUMN_* mirrors.

Non-demolition targets open AWAITING_MATERIALS/FULL, remaining W and work_begun0. Deliver their full bill with one `deliver_material(project,index,quantity)` call per index, in order. The final delivery moves to READY; another delivery after that would refuse WRONG_PHASE. Demolition has an empty delivery bill, opens directly READY/DEMOLITION and immediately marks its building DEMOLISHING. Do not call `deliver_material` on it.

## Twelve independent histories

Suffix **C**: from READY, `begin_work`; `add_work_mwu(project,W)`; assert WORK_DONE, remaining0 and begun1; then `commit_completion`. Capture the snapshot immediately after successful retirement.

Suffix **B**: after the complete bill is delivered, remain READY without calling `begin_work`; `begin_refund`; assert REFUNDING, remaining W and begun0; inspect the cancellation manifest for non-demolition; then `close_refund`. This deliberately uses real nonzero delivered ledger entries to distinguish FULL from PARTIAL rather than cancelling an empty bill.

Suffix **A**: from READY, `begin_work`; `add_work_mwu(project,1)`; assert WORKING/remaining W−1/begun1; `begin_refund`; inspect the non-demolition cancellation manifest; then `close_refund`. The1 milli-WU is a legal test contribution, not a production completion timing or rate.

| history | exact target setup | terminal project phase retained | policy retained | pre-close manifest to assert | subject after retirement |
|---|---|---:|---:|---|---|
|BUILD-C|S, open, deliver4000, C|WORK_DONE3|PARTIAL1|none|stockpile alive ACTIVE/tier1; footprint retained|
|BUILD-B|S, open, deliver4000, B|REFUNDING4|FULL0|cancellation wood4000|stockpile destroyed; footprint released|
|BUILD-A|S, open, deliver4000, A|REFUNDING4|PARTIAL1|cancellation wood3200|stockpile destroyed; footprint released|
|UPGRADE-C|H, open, deliver20000/40000/8000, C|WORK_DONE3|PARTIAL1|none|hall alive ACTIVE/tier2|
|UPGRADE-B|H, open, deliver20000/40000/8000, B|REFUNDING4|FULL0|cancellation20000/40000/8000|hall alive ACTIVE/tier1|
|UPGRADE-A|H, open, deliver20000/40000/8000, A|REFUNDING4|PARTIAL1|cancellation16000/32000/6400|hall alive ACTIVE/tier1|
|FURNITURE-C|F, deliver2000/1000, C|WORK_DONE3|PARTIAL1|none|bed, room and hall remain alive|
|FURNITURE-B|F, deliver2000/1000, B|REFUNDING4|FULL0|cancellation2000/1000|bed, room and hall remain alive|
|FURNITURE-A|F, deliver2000/1000, A|REFUNDING4|PARTIAL1|cancellation1600/800|bed, room and hall remain alive|
|DEMOLISH-C|completed S, open, no deliveries, C|WORK_DONE3|DEMOLITION2|`demolition_return_size_into`=1; return wood2000|stockpile destroyed; footprint released|
|DEMOLISH-B|completed S, open, no deliveries, B|REFUNDING4|DEMOLITION2|no cancellation material bill|stockpile alive; ACTIVE restored; tier1|
|DEMOLISH-A|completed S, open, no deliveries, A|REFUNDING4|DEMOLITION2|no cancellation material bill|stockpile alive; ACTIVE restored; tier1|

For DEMOLISH-C read the2000 return manifest at WORK_DONE **before** commit retires its handle. For demolition cancellations, assert `cancellation_refund_milli_into(project,0,out)` refuses `REFUSE_IS_A_DEMOLITION`; do not use the accessible demolition-return reader to mint cancellation goods. Public `begin_refund`/`close_refund` do support demolition cancellation, preserving DEMOLITION policy and restoring ACTIVE. No delivery ledger becomes populated.

Two easily missed actual behaviors: (1) furniture is a committed Buildings row before its project starts; `commit_completion` has no extra furniture-state transition, and `close_refund` does **not** remove the furniture. The12-history test should observe this source-supported lifetime, not add a compensating removal. (2) demolition completion requires a building with no rooms; the stockpile recipe avoids `REFUSE_BUILDING_HAS_ROOMS` without destroying extra subjects. The existing refused-completion test deliberately creates a room for its separate negative witness.

## Every retired field and identity expectation

For each successfully retired target, compare this exact16-field vector in canonical order, using purpose/type/phase/policy from the matrix:

`[present=0, material_container_slot=-1, material_container_generation=0, assigned_count=0, max_workers=4, refund_policy=POLICY, remaining_mwu=0, paused=0, work_begun=0, ref_slot=-1, ref_generation=0, subject_slot=-1, subject_generation=0, purpose=PURPOSE, type_id=TYPE, phase=PHASE]`.

All four delivered cells are0, and Construction `live_count` is0. `max_workers`, purpose, type, phase and policy are retained; these are not clear/never-used rows. In particular successful non-demolition completion retains PARTIAL although retirement cleared work_begun: recomputing refund from cleared work_begun would be wrong. Demolition retains DEMOLITION in all three histories.

Require retirement result `.value==captured_row` and `.ref==NULL_REF`; `directory.is_valid(old_project_ref)==false`; `construction.is_live_project(old_project_ref)==false`; `phase_into` refuses STALE_PROJECT_REF; `subject_ref_of(old_project_ref)==NULL_REF`; public live count0. For surviving subjects, require directory validity and `project_of_subject(subject)==NULL_REF`; surviving buildings' construction reference is null. For removed BUILD/DEMOLISH subjects, require directory invalidity, `is_live_building==false` and `building_at_tile(original_origin)==NULL_REF`. Do not call stale building getters and mistake their default values for a live state. For bed cases require `is_live_furniture`, `is_live_room`, `is_live_building` and valid directory refs after **all** three outcomes.

## Scope of delivery and refund evidence

Construction never owns Inventory. `deliver_material` records an accepted collaborator delivery; `cancellation_refund_milli_into` and `demolition_return_milli_into` calculate manifests; `close_refund` assumes its caller has completed the physical output transaction. The current component tests/probe call those public boundaries directly. Follow that established component seam and label the evidence precisely: actual owner lifecycle and retained-state proof, **not** physical hauling, WIP consumption, refund-lot publication, conservation or player-facing demolition admission. No fabricated container, private mutation or new Inventory fixture is needed for this bounded validator witness. A full inventory transaction test remains separate and cannot be credited by these cases.

## Inspected source identities

- `godot/scripts/core/construction.gd` — `e5d3fd006311c43c3b20b0a3f2209945e5ade12ad08b84ddcaf8d49ef6e3e326`
- `godot/scripts/core/buildings.gd` — `eb6d09a1d80d169fa60795b6e6d22d05dd64329b8ea85f36e805b482ea705dd5`
- `godot/scripts/core/entity_directory.gd` — `0367a5995327721bbd1d467cff494efa1ec9b5d707e5e997949fbac3575c709a`
- `godot/scripts/core/building_definitions.gd` — `eedac020ca29c92d9ffcb60d77d2ab8d0d309beee52b98a44c89795dc63fc074`
- `godot/scripts/core/catalog.gd` — `3fcc06650e93ffd78a973c53a21544ba0d8d31a8095c549820292e2d63926cb1`
- `godot/test/test_construction.gd` — `94238745efb50a2d6a55509ec71b124fddf9e172da5296ce7ee4b4554a42e7f6`
- `docs/planning/construction_component_validation_contract.md` — `89dc302a4835147e2361dbf40811efe87565231da102f90ec140b88d9400033d`
- `docs/validation/evidence/construction-validation-planning-2026-09-20/frozen-source-facts.json` — `9e1fa4710e5e5c56a4e2c0900fd387e9b985ce062440c8ab1042badd32ade298`
- `docs/validation/evidence/construction-validation-planning-2026-09-20/retired-state-probe.gd` — `eb5142d4c5c89e4d7bffb56b91551086c397bfc79d62256a43c76f796a55a150`

## Exact collaborator/lifecycle excerpts

Each numbered line after `|` is copied from the hashed source above. Selected functions are complete; omission between functions is explicit in their line numbers. These excerpts clarify lifetime behavior not observable from retired getters. The existing full test/probe sources remain the setup/decoder references.

### `godot/scripts/core/buildings.gd` — `demolish_building`, lines643–665

```text
  643 | func demolish_building(building_ref: Vector2i) -> OpResult:
  644 | 	"""Remove one exterior structure and release its tiles and directory slot.
  645 | 
  646 | 	REFUSES while the building still owns rooms. Cascading would destroy room and furniture rows
  647 | 	the caller never named, and task 06.2's "Refuse occupied/only-exit destructive edits" is the
  648 | 	contract that will decide demolition of an occupied structure; removing its rooms first is
  649 | 	explicit and leaves every collaborating store byte-identical on refusal.
  650 | 	"""
  651 | 	var row: int = _building_row_of(building_ref)
  652 | 	if row == NO_ROW:
  653 | 		return _refuse(REFUSE_STALE_BUILDING_REF)
  654 | 	if _b_room_count[row] != 0:
  655 | 		return _refuse(REFUSE_BUILDING_HAS_ROOMS)
  656 | 	_clear_footprint(row)
  657 | 	_b_present[row] = 0
  658 | 	_b_ref_slot[row] = EntityDirectory.NULL_SLOT
  659 | 	_b_ref_generation[row] = EntityDirectory.NULL_GENERATION
  660 | 	_b_live_count -= 1
  661 | 	_directory.destroy(building_ref)
  662 | 	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)
  663 | 
  664 | 
  665 | # --- Building accessors and setters ---------------------------------------------------------------
```

### `godot/scripts/core/buildings.gd` — `designate_room`, lines825–847

```text
  825 | func designate_room(building_ref: Vector2i, room_type: int, tiles: PackedInt32Array) -> OpResult:
  826 | 	"""Publish one Room over a set of interior tiles of a managed building.
  827 | 
  828 | 	Every tile must lie inside that building's interior rectangle (its footprint inset by one
  829 | 	tile, §5.9) and belong to no other room: GDD §5.9's "One tile belongs to exactly one room".
  830 | 	Refuses -- writing nothing -- on a stale building, a nonmanaged building, the 17th room, an
  831 | 	unknown room type, an empty or duplicated tile list, an outside or already-owned tile, or a
  832 | 	full RoomTileLinks arena.
  833 | 	"""
  834 | 	var building_row: int = _building_row_of(building_ref)
  835 | 	if building_row == NO_ROW:
  836 | 		return _refuse(REFUSE_STALE_BUILDING_REF)
  837 | 	var code: StringName = _refuse_designate_room(building_row, room_type, tiles)
  838 | 	if code != REFUSE_NONE:
  839 | 		return _refuse(code)
  840 | 	var ref: Vector2i = _directory.create(EntityDirectory.KIND_ROOM)
  841 | 	if ref == NULL_REF:
  842 | 		return _refuse(_directory.last_refusal())
  843 | 	var row: int = _directory.get_typed_row(ref)
  844 | 	_write_room_row(row, ref, building_ref, room_type, tiles)
  845 | 	_link_room(building_row, row)
  846 | 	_r_live_count += 1
  847 | 	return OpResult.new(true, REFUSE_NONE, row, ref)
```

### `godot/scripts/core/buildings.gd` — `_refuse_designate_room`, lines850–863

```text
  850 | func _refuse_designate_room(building_row: int, room_type: int,
  851 | 		tiles: PackedInt32Array) -> StringName:
  852 | 	"""The code blocking a designation, or REFUSE_NONE when every argument is storable."""
  853 | 	if room_type < 0 or room_type >= ROOM_TYPE_COUNT:
  854 | 		return REFUSE_UNKNOWN_ROOM_TYPE
  855 | 	if not _definitions.has_managed_interior(_b_type_id[building_row]):
  856 | 		return REFUSE_NOT_MANAGED_INTERIOR
  857 | 	if _b_room_count[building_row] >= MAX_ROOMS_PER_BUILDING:
  858 | 		return REFUSE_ROOM_LIMIT
  859 | 	if tiles.is_empty():
  860 | 		return REFUSE_EMPTY_TILE_LIST
  861 | 	if _room_tile_used + tiles.size() > ROOM_TILE_LINK_CAPACITY:
  862 | 		return REFUSE_TILE_LINK_ARENA_FULL
  863 | 	return _refuse_room_tiles(building_row, tiles)
```

### `godot/scripts/core/entity_directory.gd` — `destroy`, lines229–253

```text
  229 | func destroy(ref: Vector2i) -> bool:
  230 | 	"""Release a live reference's slot and typed row. False when `ref` is stale."""
  231 | 	if not is_valid(ref):
  232 | 		return false
  233 | 	var slot: int = ref.x
  234 | 	var kind: int = _kind[slot]
  235 | 	var base: int = _kind_base[kind]
  236 | 	var row: int = _typed_row[slot]
  237 | 	_typed_owner_slot[base + row] = NULL_SLOT
  238 | 	_push_free(_heap_index, base, _kind_free_count[kind], row)
  239 | 	_kind_free_count[kind] += 1
  240 | 	_active[slot] = 0
  241 | 	_persistent_id[slot] = 0
  242 | 	_typed_row[slot] = NULL_SLOT
  243 | 	_kind[slot] = KIND_ANY
  244 | 	_live_count -= 1
  245 | 	_kind_live_count[kind] -= 1
  246 | 	if _generation[slot] >= MAX_INT32:
  247 | 		# ARCH-ID-002: generation 2147483647 is used once, then the slot retires
  248 | 		# permanently rather than wrapping into a colliding value.
  249 | 		_retired[slot] = 1
  250 | 		return true
  251 | 	_push_free(_free_heap, 0, _free_count, slot)
  252 | 	_free_count += 1
  253 | 	return true
```

### `godot/scripts/core/construction.gd` — `_apply_completion`, lines901–916

```text
  901 | func _apply_completion(row: int, subject: Vector2i) -> StringName:
  902 | 	"""Make the one Building edit this project's purpose commits, or report why it cannot."""
  903 | 	match _purpose[row]:
  904 | 		PURPOSE_BUILD:
  905 | 			return REFUSE_NONE if _buildings.set_building_state(subject, STATE_ACTIVE).ok \
  906 | 				else REFUSE_NOT_ACTIVE
  907 | 		PURPOSE_UPGRADE:
  908 | 			return REFUSE_NONE if _buildings.set_building_tier(
  909 | 				subject, BuildingDefinitions.TIER_TWO).ok else REFUSE_NO_UPGRADE_PACKAGE
  910 | 		PURPOSE_DEMOLISH:
  911 | 			_buildings.set_building_construction(subject, NULL_REF)
  912 | 			var result: Buildings.OpResult = _buildings.demolish_building(subject)
  913 | 			if not result.ok:
  914 | 				_buildings.set_building_construction(subject, _ref_of_row(row))
  915 | 				return result.error
  916 | 	return REFUSE_NONE
```

### `godot/scripts/core/construction.gd` — `_retire`, lines919–937

```text
  919 | func _retire(row: int, project_ref: Vector2i, subject: Vector2i) -> void:
  920 | 	"""Clear the subject's back-reference, free the row and hand the directory slot back."""
  921 | 	if _purpose[row] != PURPOSE_FURNITURE and _buildings.is_live_building(subject):
  922 | 		_buildings.set_building_construction(subject, NULL_REF)
  923 | 	_present[row] = 0
  924 | 	_work_begun[row] = 0
  925 | 	_ref_slot[row] = EntityDirectory.NULL_SLOT
  926 | 	_ref_generation[row] = EntityDirectory.NULL_GENERATION
  927 | 	_subject_slot[row] = EntityDirectory.NULL_SLOT
  928 | 	_subject_generation[row] = EntityDirectory.NULL_GENERATION
  929 | 	_material_container_slot[row] = EntityDirectory.NULL_SLOT
  930 | 	_material_container_generation[row] = EntityDirectory.NULL_GENERATION
  931 | 	_assigned_count[row] = 0
  932 | 	_paused[row] = 0
  933 | 	_remaining_mwu[row] = 0
  934 | 	for index: int in MATERIAL_SLOTS_PER_PROJECT:
  935 | 		_delivered_milli[row * MATERIAL_SLOTS_PER_PROJECT + index] = 0
  936 | 	_live_count -= 1
  937 | 	_directory.destroy(project_ref)
```

### `godot/scripts/core/construction.gd` — `close_refund`, lines1010–1035

```text
 1010 | func close_refund(project_ref: Vector2i) -> OpResult:
 1011 | 	"""Retire a cancelled project once its refund manifest has been placed.
 1012 | 
 1013 | 	A cancelled BUILD project also removes the blueprint it was building: a cancelled blueprint is
 1014 | 	not a building. If that removal refuses -- a blueprint that somehow owns rooms -- the project
 1015 | 	stays in PHASE_REFUNDING with its ledger intact and the retry spends nothing.
 1016 | 	"""
 1017 | 	var row: int = _row_of(project_ref)
 1018 | 	if row == NO_ROW:
 1019 | 		return _refuse(REFUSE_STALE_PROJECT_REF)
 1020 | 	if _phase[row] != PHASE_REFUNDING:
 1021 | 		return _refuse(REFUSE_WRONG_PHASE)
 1022 | 	var subject: Vector2i = Vector2i(_subject_slot[row], _subject_generation[row])
 1023 | 	if _purpose[row] == PURPOSE_BUILD and _buildings.is_live_building(subject):
 1024 | 		_buildings.set_building_construction(subject, NULL_REF)
 1025 | 		var result: Buildings.OpResult = _buildings.demolish_building(subject)
 1026 | 		if not result.ok:
 1027 | 			_buildings.set_building_construction(subject, project_ref)
 1028 | 			return _refuse(result.error)
 1029 | 	if _purpose[row] == PURPOSE_DEMOLISH and _buildings.is_live_building(subject):
 1030 | 		_buildings.set_building_state(subject, STATE_ACTIVE)
 1031 | 	_retire(row, project_ref, subject)
 1032 | 	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)
 1033 | 
 1034 | 
 1035 | # --- pause, workers and the material container ---------------------------------------------------
```
