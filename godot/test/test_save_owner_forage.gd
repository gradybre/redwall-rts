extends "res://test/framework/test_case.gd"
## `save_owner_forage.gd`: the section 4 validator and the joint section 4 + 5 pair (ADR 1222).
##
## Two zones with patches and overlapping tiles, one tile removed (a recycled link on the free
## list) and one zone destroyed (a retired row with history) are captured, carried through the
## real section 5 codec, applied into a DIFFERENT store over a separately restored Directory, and
## then section 1 is restored and cross-checked; every corruption must refuse unwritten.

const Forage := preload("res://scripts/core/forage.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Bridge := preload("res://scripts/core/save_owner_forage.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")

var _store: Forage = null


func before_each() -> void:
	"""Two live zones (one with patches), shared tiles, a freed link and a destroyed zone."""
	_store = Forage.new()
	var first: Vector2i = _zone(true)
	var second: Vector2i = _zone(false)
	var gone: Vector2i = _zone(false)
	for tile: int in [10, 11, 12, 300]:
		assert_true(_store.add_tile(first, tile).ok, "first covers %d" % tile)
	for tile: int in [11, 40]:
		assert_true(_store.add_tile(second, tile).ok, "second covers %d" % tile)
	assert_true(_store.add_tile(gone, 99).ok, "a doomed zone's tile")
	assert_true(_store.remove_tile(first, 12).ok, "a link returns to the free list")
	assert_true(_store.create_patch(first, 0, 7).ok, "a patch")
	assert_true(_store.create_patch(first, 3, 9).ok, "another patch")
	assert_true(_store.destroy_zone(gone).ok, "a retired zone row")


func _zone(protect: bool) -> Vector2i:
	"""One FORAGE zone."""
	var made: Forage.OpResult = _store.create_zone(Forage.ZONE_TYPE_FORAGE, 1, 0, protect, true)
	assert_true(made.ok, "a zone (%s)" % made.error)
	return made.ref


func _target() -> Forage:
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
	return Forage.new(directory)


func _captured() -> Array:
	"""[record, section 5 block] from the source, the block re-decoded through its codec."""
	var record: Section.FramedOwner = Section.FramedOwner.new(Bridge.OWNER_INDEX)
	var state: ChildSection.State = ChildSection.State.new()
	var refusal: Variant = Bridge.capture_into(_store, record,
		state.block(Bridge.CHILD_OWNER_INDEX))
	assert_true(refusal.is_ok(), "capture: %s %s" % [refusal.code, refusal.detail])
	var out: ChildSection.EncodeResult = ChildSection.EncodeResult.new()
	assert_true(ChildSection.encode_section(state, out), "section 5 encodes")
	var decoded: ChildSection.State = ChildSection.State.new()
	assert_true(ChildSection.decode_section(out.bytes, 0, out.bytes.size(), decoded).is_ok(),
		"section 5 decodes")
	return [record, decoded.block(Bridge.CHILD_OWNER_INDEX)]


func _image(store: Forage) -> Array:
	"""[Columns, Links] of a store."""
	var columns: Forage.Columns = Forage.Columns.new()
	var links: Forage.Links = Forage.Links.new()
	assert_true(store.copy_columns_into(columns, links), "bulk copy")
	return [columns, links]


func _same(a: Forage, b: Forage) -> bool:
	"""Both images byte-identical and the live counts equal."""
	var left: Array = _image(a)
	var right: Array = _image(b)
	for field: String in ["zone_present", "patch_present", "zone_type", "zone_ref_slot",
			"zone_basin_generation", "patch_stock_milli", "zone_quota_mode"]:
		if left[0].get(field) != right[0].get(field):
			return false
	for field: String in ["link_bump", "link_free_head", "link_used", "zone_link_head",
			"link_tile", "link_zone", "link_tile_next", "link_zone_next", "zone_patch_count"]:
		if left[1].get(field) != right[1].get(field):
			return false
	return a.zone_count() == b.zone_count() and a.link_count() == b.link_count()


func test_capture_then_apply_into_a_different_store_matches_and_cross_checks() -> void:
	"""Sections 4 and 5 come back exactly; section 1 then restores and cross-checks clean."""
	var parts: Array = _captured()
	assert_true(Bridge.framed_refusal(parts[0]).is_ok(), "the record is accepted")
	var target: Forage = _target()
	var refusal: Variant = Bridge.apply(parts[0], parts[1], target)
	assert_true(refusal.is_ok(), "apply: %s %s" % [refusal.code, refusal.detail])
	assert_true(_same(_store, target), "the stores agree")
	var heads: PackedInt32Array = PackedInt32Array()
	heads.resize(Forage.TILE_COUNT)
	assert_true(_store.copy_section_1_columns_into(heads), "section 1 copies")
	assert_true(target.restore_section_1_columns(heads), "section 1 restores")
	assert_equal(target.section_1_cross_check_refusal(), Forage.REFUSE_NONE, "chains agree")
	var first: Vector2i = target.zone_ref_of(target.live_zone_slot_at(0).value)
	assert_true(target.add_tile(first, 12).ok, "the restored free list hands a link back out")


func test_link_and_column_corruptions_refuse_and_write_nothing() -> void:
	"""Each corruption refuses with its exact code; the target stays empty."""
	var target: Forage = _target()
	var cases: Array = [[Bridge.CHILD_LINK_USED, -1, Forage.REFUSE_COLUMN_LINKS, "used count"],
		[Bridge.CHILD_LINK_FREE_HEAD, -1, Forage.REFUSE_COLUMN_LINKS, "a lost free list"]]
	for case: Array in cases:
		var parts: Array = _captured()
		var value: int = parts[1].scalar(case[0]) + case[1]
		assert_true(parts[1].set_scalar(case[0], value).is_ok(), "corrupt")
		assert_equal(Bridge.apply(parts[0], parts[1], target).code, case[2], case[3])
	var chain: Array = _captured()
	var counts: PackedInt32Array = chain[1].i32_column(Bridge.CHILD_ZONE_TILE_COUNT)
	counts[0] += 1
	assert_true(chain[1].set_i32_column(Bridge.CHILD_ZONE_TILE_COUNT, counts).is_ok(), "x")
	assert_equal(Bridge.apply(chain[0], chain[1], target).code, Forage.REFUSE_COLUMN_ZONE_CHAIN,
		"a tile count the chain does not reach")
	var patch: Array = _captured()
	var stock: PackedInt64Array = patch[0].i64_column(Bridge.FIELD_PATCH_STOCK_MILLI)
	stock[0] = 1 << 40
	assert_true(patch[0].set_i64(Bridge.FIELD_PATCH_STOCK_MILLI, stock), "overfull patch")
	assert_equal(Bridge.framed_refusal(patch[0]).code, Forage.REFUSE_COLUMN_PATCH, "framed")
	assert_equal(target.zone_count(), 0, "no refusal wrote a zone")


func test_a_directory_that_does_not_hold_the_zones_refuses() -> void:
	"""Applying into a store whose Directory never saw the zones refuses COLUMN_DIRECTORY."""
	var parts: Array = _captured()
	var target: Forage = Forage.new()
	assert_equal(Bridge.apply(parts[0], parts[1], target).code, Forage.REFUSE_COLUMN_DIRECTORY,
		"unresolved zone references")
	assert_equal(Bridge.apply(parts[0], parts[1], null).code, Bridge.REFUSE_NULL_STORE, "null")
	assert_equal(Bridge.apply(parts[0], ChildSection.State.new().block(0), target).code,
		Bridge.REFUSE_BLOCK_SHAPE, "another owner's block")
