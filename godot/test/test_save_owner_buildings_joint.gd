extends "res://test/framework/test_case.gd"
## Buildings' joint sections 4 + 5 + section-6-flag pair (ADR 1222 step 3).
##
## A starter hall with four rooms and furniture -- then one room and one piece removed, so the
## arena is compacted and retired rows keep history -- is captured, carried through the real
## section 5 codec, and applied into a DIFFERENT store over a separately restored Directory. The
## restored store must answer exactly like the source; every refusal must write nothing.

const Buildings := preload("res://scripts/core/buildings.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Bridge := preload("res://scripts/core/save_owner_buildings.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")
const AuxSection := preload("res://scripts/core/save_section_auxiliary.gd")

const HALL_ORIGIN: int = 59 * 128 + 58
const INTERIOR_X: int = 59
const INTERIOR_Z: int = 60
const START_MASK: int = 1

var _store: Buildings = null


func before_each() -> void:
	"""The starter hall, a retired middle room, four live rooms, furniture and a retired bed."""
	_store = Buildings.new()
	var hall: Vector2i = _store.place_building(int(CatalogScript.BUILDING_DEFINITION["hall"]),
		HALL_ORIGIN, 0, START_MASK).ref
	var dormitory: Vector2i = _room(hall, "DORMITORY", 0, 0, 4, 7)
	var kitchen: Vector2i = _room(hall, "KITCHEN", 5, 0, 9, 1)
	var corridor: Vector2i = _room(hall, "CORRIDOR", 5, 7, 9, 7)
	var common: Vector2i = _room(hall, "COMMON", 5, 2, 9, 6)
	assert_true(_store.remove_room(corridor).ok, "retire a middle run, compacting the arena")
	_room(hall, "PANTRY", 5, 7, 9, 7)
	var bed: Vector2i = _piece(dormitory, "bed", 0, 0)
	_piece(dormitory, "bed", 2, 0)
	_piece(kitchen, "hearth", 8, 0)
	_piece(common, "seat", 6, 2)
	assert_true(_store.remove_furniture(bed).ok, "retire one bed")
	assert_true(_store.set_room_valid(kitchen, true).ok, "a validated room")


func _room(hall: Vector2i, key: String, x0: int, z0: int, x1: int, z1: int) -> Vector2i:
	"""Designate one room over an inclusive interior rectangle."""
	var tiles: PackedInt32Array = PackedInt32Array()
	for z: int in range(z0, z1 + 1):
		for x: int in range(x0, x1 + 1):
			tiles.append((INTERIOR_Z + z) * 128 + INTERIOR_X + x)
	var room: Buildings.OpResult = _store.designate_room(hall,
		int(CatalogScript.ROOM_TYPE[key]), tiles)
	assert_true(room.ok, "designate %s (%s)" % [key, room.error])
	return room.ref


func _piece(room: Vector2i, key: String, x: int, z: int) -> Vector2i:
	"""Place one furniture piece at an interior cell."""
	var placed: Buildings.OpResult = _store.place_furniture(room,
		int(CatalogScript.FURNITURE_DEFINITION[key]), (INTERIOR_Z + z) * 128 + INTERIOR_X + x, 0)
	assert_true(placed.ok, "place %s (%s)" % [key, placed.error])
	return placed.ref


func _target() -> Buildings:
	"""A different store over a Directory restored from the source's section 3 columns."""
	var active: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var generation: PackedInt32Array = PackedInt32Array()
	var persistent_id: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var typed_row: PackedInt32Array = PackedInt32Array()
	active.resize(EntityDirectory.DIRECTORY_CAPACITY)
	retired.resize(EntityDirectory.DIRECTORY_CAPACITY)
	generation.resize(EntityDirectory.DIRECTORY_CAPACITY)
	persistent_id.resize(EntityDirectory.DIRECTORY_CAPACITY)
	kind.resize(EntityDirectory.DIRECTORY_CAPACITY)
	typed_row.resize(EntityDirectory.DIRECTORY_CAPACITY)
	_store.directory().copy_columns_into(active, generation, retired, persistent_id, kind,
		typed_row)
	var directory: EntityDirectory = EntityDirectory.new()
	assert_true(directory.restore_columns(active, generation, retired, persistent_id, kind,
		typed_row), "section 3 restores")
	return Buildings.new(directory)


func _captured() -> Array:
	"""[record, section 5 block, section 6 block] captured from the source; section 5 re-decoded."""
	var record: Section.FramedOwner = Section.FramedOwner.new(Bridge.OWNER_INDEX)
	var links_state: ChildSection.State = ChildSection.State.new()
	var flags: AuxSection.Block = AuxSection.State.new().block(Bridge.AUX_OWNER_INDEX)
	var refusal: Variant = Bridge.capture_into(_store, record,
		links_state.block(Bridge.CHILD_OWNER_INDEX), flags)
	assert_true(refusal.is_ok(), "capture: %s %s" % [refusal.code, refusal.detail])
	var out: ChildSection.EncodeResult = ChildSection.EncodeResult.new()
	assert_true(ChildSection.encode_section(links_state, out), "section 5 encodes")
	var decoded: ChildSection.State = ChildSection.State.new()
	assert_true(ChildSection.decode_section(out.bytes, 0, out.bytes.size(), decoded).is_ok(),
		"section 5 decodes")
	return [record, decoded.block(Bridge.CHILD_OWNER_INDEX), flags]


func _image(store: Buildings) -> Array:
	"""[Columns, Links] snapshot of a store."""
	var columns: Buildings.Columns = Buildings.Columns.new()
	var links: Buildings.Links = Buildings.Links.new()
	assert_true(store.copy_columns_into(columns, links), "bulk copy")
	return [columns, links]


func _same(a: Buildings, b: Buildings) -> bool:
	"""Both images equal and every derived counter agrees."""
	var left: Array = _image(a)
	var right: Array = _image(b)
	var columns_equal: bool = true
	for field: String in ["b_present", "r_present", "f_present", "r_tile_offset", "r_tile_count",
			"r_furniture_mask", "r_valid", "f_type_id", "f_room_slot", "b_state"]:
		columns_equal = columns_equal and left[0].get(field) == right[0].get(field)
	return columns_equal and left[1].equals(right[1]) \
		and a.live_building_count() == b.live_building_count() \
		and a.live_room_count() == b.live_room_count() \
		and a.live_furniture_count() == b.live_furniture_count()


func test_capture_then_apply_into_a_different_store_matches_and_continues() -> void:
	"""The restored store equals the source, its derived counters agree, and it keeps working."""
	var parts: Array = _captured()
	var target: Buildings = _target()
	var refusal: Variant = Bridge.apply(parts[0], parts[1], parts[2], target)
	assert_true(refusal.is_ok(), "apply: %s %s" % [refusal.code, refusal.detail])
	assert_true(_same(_store, target), "the stores agree")
	var bed: int = int(CatalogScript.FURNITURE_DEFINITION["bed"])
	assert_equal(target.live_furniture_of_kind(bed), _store.live_furniture_of_kind(bed),
		"the per-kind counter was rebuilt")
	var building_slot: PackedInt32Array = PackedInt32Array()
	var room_slot: PackedInt32Array = PackedInt32Array()
	var furniture_slot: PackedInt32Array = PackedInt32Array()
	building_slot.resize(Buildings.TILE_COUNT)
	room_slot.resize(Buildings.TILE_COUNT)
	furniture_slot.resize(Buildings.TILE_COUNT)
	assert_true(_store.copy_section_1_columns_into(building_slot, room_slot, furniture_slot),
		"section 1 copies")
	assert_true(target.restore_section_1_columns(building_slot, room_slot, furniture_slot),
		"section 1 restores")
	assert_equal(target.section_1_cross_check_refusal(), Buildings.REFUSE_NONE,
		"the tile maps agree with the restored rows")


func test_each_link_corruption_refuses_with_its_code_and_writes_nothing() -> void:
	"""Chains, arena, flags and free-row canon each refuse exactly; the target is untouched."""
	var target: Buildings = _target()
	var before: Array = _image(target)
	var counts: PackedInt32Array = _captured()[1].i32_column(9)
	var furnished: int = 0
	while counts[furnished] == 0:
		furnished += 1
	var cases: Array = [[2, 0, 999, Buildings.REFUSE_COLUMN_ROOM_CHAIN, "a head on a free room"],
		[14, 80, 5, Buildings.REFUSE_COLUMN_ROOM_TILES, "an arena entry past the used prefix"],
		[9, furnished, counts[furnished] + 1, Buildings.REFUSE_COLUMN_FURNITURE_CHAIN,
			"a furniture count the chain does not reach"],
		[0, 1000, 3, Buildings.REFUSE_COLUMN_LINK_FREE, "a free building with a ref"]]
	for case: Array in cases:
		var parts: Array = _captured()
		var column: PackedInt32Array = parts[1].i32_column(case[0])
		column[case[1]] = case[2]
		assert_true(parts[1].set_i32_column(case[0], column).is_ok(), "corrupt")
		assert_equal(Bridge.apply(parts[0], parts[1], parts[2], target).code, case[3], case[4])
	var spatial: Array = _captured()
	var kinds: PackedByteArray = spatial[2].u8_column(Bridge.AUX_R_SPATIAL_KIND)
	kinds[0] = 1
	assert_true(spatial[2].set_u8_column(Bridge.AUX_R_SPATIAL_KIND, kinds).is_ok(), "flag")
	assert_equal(Bridge.apply(spatial[0], spatial[1], spatial[2], target).code,
		Buildings.REFUSE_COLUMN_SPATIAL, "spatial rooms are refused until the underground step")
	var after: Array = _image(target)
	assert_true(after[1].equals(before[1]) and after[0].b_present == before[0].b_present,
		"no refusal wrote anything")


func test_a_directory_that_does_not_hold_the_rows_refuses() -> void:
	"""Applying into a store over an EMPTY Directory refuses COLUMN_DIRECTORY."""
	var parts: Array = _captured()
	var target: Buildings = Buildings.new(EntityDirectory.new())
	assert_equal(Bridge.apply(parts[0], parts[1], parts[2], target).code,
		Buildings.REFUSE_COLUMN_DIRECTORY, "unresolved references")
	assert_equal(target.live_building_count(), 0, "nothing was installed")


func test_wrong_blocks_and_a_null_store_refuse_before_the_store() -> void:
	"""Another owner's blocks and a null store refuse with their exact codes."""
	var parts: Array = _captured()
	var target: Buildings = _target()
	assert_equal(Bridge.apply(parts[0], ChildSection.State.new().block(1), parts[2], target).code,
		Bridge.REFUSE_BLOCK_SHAPE, "a section 5 block of construction")
	assert_equal(Bridge.apply(parts[0], parts[1], AuxSection.State.new().block(1), target).code,
		Bridge.REFUSE_BLOCK_SHAPE, "a section 6 block of command_dispatch")
	assert_equal(Bridge.apply(parts[0], parts[1], parts[2], null).code, Bridge.REFUSE_NULL_STORE,
		"no store")
	assert_equal(target.live_building_count(), 0, "nothing was installed")
