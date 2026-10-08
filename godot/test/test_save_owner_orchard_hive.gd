extends "res://test/framework/test_case.gd"
## Owner 10 (`orchard_hive`) bulk capture/apply bridge tests (ADR 1222 build step 2).
const OrchardHive := preload("res://scripts/core/orchard_hive.gd")
const Bridge := preload("res://scripts/core/save_owner_orchard_hive.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

func _live_store() -> OrchardHive:
	"""A store with live, edited and freed orchard/hive rows, built through the public API only."""
	var store: OrchardHive = OrchardHive.new()
	assert_true(store.plant_orchard(0, 0, OrchardHive.SPECIES_APPLE, 1).ok, "plant apple")
	assert_true(store.plant_orchard(4, 0, OrchardHive.SPECIES_PEAR, 1).ok, "plant pear")
	var directory: EntityDirectory = store.directory()
	var building_a: Vector2i = directory.create(EntityDirectory.KIND_BUILDING)
	var building_b: Vector2i = directory.create(EntityDirectory.KIND_BUILDING)
	assert_true(store.create_hive(building_a, 0, 0, 2, 2, 1).ok, "create hive")
	assert_true(store.create_hive(building_b, 0, 4, 2, 6, 1).ok, "create a second hive")
	var removed: OrchardHive.OpResult = store.plant_orchard(8, 0, OrchardHive.SPECIES_APPLE, 1)
	assert_true(removed.ok, "plant a block to free")
	assert_true(store.remove_orchard(removed.ref).ok, "free that block")
	return store


func _frame(store: OrchardHive) -> Section.FramedOwner:
	"""One owner 10 record captured from `store`, asserting the capture itself succeeds."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(10)
	assert_true(Bridge.capture_into(store, frame).is_ok(), "capture succeeds")
	return frame


func _image(store: OrchardHive) -> OrchardHive.Columns:
	"""The store's 25 columns through the bulk reader."""
	var columns: OrchardHive.Columns = OrchardHive.Columns.new()
	assert_true(store.copy_columns_into(columns), "bulk copy succeeds")
	return columns


func test_capture_then_apply_into_a_fresh_store_is_exact_and_continues_identically() -> void:
	"""The restored store holds the same columns and active-list counts as the source."""
	var source: OrchardHive = _live_store()
	var frame: Section.FramedOwner = _frame(source)
	var target: OrchardHive = OrchardHive.new()
	assert_true(Bridge.apply(frame, target).is_ok(), "apply succeeds")
	assert_true(_image(target).equals(_image(source)), "columns are byte-identical")
	assert_equal(target.orchard_count(), source.orchard_count(), "orchard count is rebuilt")
	assert_equal(target.hive_count(), source.hive_count(), "hive count is rebuilt")
	assert_true(target.plant_orchard(4, 4, OrchardHive.SPECIES_PEAR, 2).ok,
		"the restored store continues normal lifecycle")


func test_empty_store_round_trips() -> void:
	"""An all-zero owner 10 image is a valid empty OrchardHive, matching the header's claim."""
	var source: OrchardHive = OrchardHive.new()
	var frame: Section.FramedOwner = _frame(source)
	var target: OrchardHive = OrchardHive.new()
	assert_true(Bridge.apply(frame, target).is_ok(), "apply of an empty image succeeds")
	assert_true(_image(target).equals(_image(source)), "empty image is byte-identical")
	assert_equal(target.orchard_count(), 0, "no orchard rows")
	assert_equal(target.hive_count(), 0, "no hive rows")


func test_every_column_refusal_leaves_the_target_byte_identical() -> void:
	"""Corrupting one column refuses with its exact code and writes nothing into the target."""
	var target: OrchardHive = _live_store()
	var before: OrchardHive.Columns = _image(target)
	var count: int = target.orchard_count()
	var frame: Section.FramedOwner = _frame(_live_store())
	var species: PackedInt32Array = frame.i32_column(Bridge.FIELD_O_SPECIES_ID)
	species[0] = 99
	assert_true(frame.set_i32(Bridge.FIELD_O_SPECIES_ID, species), "fixture corruption write")
	var refusal: Variant = Bridge.apply(frame, target)
	assert_equal(refusal.code, &"COLUMN_ORCHARD_SPECIES", "exact column code forwarded")
	assert_true(_image(target).equals(before), "no refusal wrote a column")
	assert_equal(target.orchard_count(), count, "no refusal moved the count")


func test_null_and_misshaped_inputs_refuse_without_writing() -> void:
	"""Null stores, null records, a wrong owner and a short bulk buffer all refuse."""
	var target: OrchardHive = _live_store()
	var before: OrchardHive.Columns = _image(target)
	assert_equal(Bridge.apply(_frame(_live_store()), null).code, Bridge.REFUSE_NULL_STORE,
		"null store")
	assert_equal(Bridge.capture_into(null, Section.FramedOwner.new(10)).code,
		Bridge.REFUSE_NULL_STORE, "capture from no store")
	assert_equal(Bridge.capture_into(target, null).code, &"SAVE_COMPONENT_SHAPE", "null record")
	assert_equal(Bridge.capture_into(target, Section.FramedOwner.new(9)).code,
		&"SAVE_COMPONENT_OWNER", "wrong owner")
	var short: OrchardHive.Columns = OrchardHive.Columns.new()
	short.o_present.resize(3)
	assert_false(target.restore_columns(short), "a short column refuses")
	assert_equal(target.last_column_refusal(), OrchardHive.REFUSE_COLUMN_SHAPE, "shape code")
	assert_false(target.copy_columns_into(short), "a short output buffer refuses")
	assert_false(target.restore_columns(null), "null columns refuse")
	assert_true(_image(target).equals(before), "nothing was written")
