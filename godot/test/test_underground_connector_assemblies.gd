extends "res://test/framework/test_case.gd"
## Actual immutable owners with explicitly synthetic part geometry; no installed entry/profile permission.

const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Fixture := preload("res://test/test_underground_connector_catalog.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const GROUP_PATH: String = "user://test-assembly-groups.bin"
const RECIPE_PATH: String = "user://test-assembly-recipes.bin"
const CATALOG_PATH: String = "user://test-assembly-catalog.bin"
const PROFILE_PATH: String = "user://test-assembly-profiles.bin"
const GROUP_REVISION: int = 17
const RECIPE_REVISION: int = 7

class IsolatedFixture extends Fixture:

	## Do not touch the Catalog suite's temporary paths while another worktree validates it.
	func _load_profiles(bytes: PackedByteArray, revision: int = 1) -> StringName:
		"""Use the same real source loader with a path owned only by this new suite."""
		return _profiles.load_file(PROFILE_PATH, Fixture._write(PROFILE_PATH, bytes), revision)

	func after_each() -> void:
		"""Drop actual fixture owners without deleting another suite's source files."""
		_catalog = null
		_profiles = null
		_levels = null
		_movement = null
		_transforms = null
		_residents = null
		_domain = null

class ObservedRecipes extends Recipes:

	## Observe after the LAST real recipe source check, not only an early callback already rechecked.
	var reader: WeakRef = null
	var fixture: WeakRef = null
	var nested: Assemblies.AssemblyRecord = null
	var nested_refusal: StringName = &""
	var change: int = 0
	var applied: bool = false
	var armed: bool = false
	var foreign_inventory: Inventory = null
	var resize_output: PackedByteArray = PackedByteArray()
	var corrupt_digest: bool = false

	func content_hash_into(revision: int, out: PackedByteArray) -> bool:
		"""A digest observer may resize borrowed scratch after the real source reader has succeeded."""
		var valid: bool = super.content_hash_into(revision, out)
		if corrupt_digest:
			corrupt_digest = false
			out.resize(1)
		return valid

	func binding_matches(catalog: Connectors, items: Items, inventory: Inventory,
			frontier_sha256: String, frontier_revision: int) -> bool:
		"""A real final observer may invalidate a World/source or attempt synchronous reentry."""
		var valid: bool = super.binding_matches(catalog, items, inventory, frontier_sha256, frontier_revision)
		if armed:
			armed = false
			if reader != null:
				var actual: Assemblies = reader.get_ref() as Assemblies
				nested_refusal = actual.assembly_into(0, 1, GROUP_REVISION, 0, nested)
			if change > 0:
				_change_source(items)
			if not resize_output.is_empty():
				resize_output.resize(1)
		return valid

	func _change_source(items: Items) -> void:
		"""Mutate only actual permitted source APIs after their former successful observation."""
		var actual: IsolatedFixture = fixture.get_ref() as IsolatedFixture
		if change == 1:
			applied = actual._load_profiles(Fixture.synthetic_profile_image(actual._identity, 2), 2) == &""
		elif change == 2:
			applied = actual._residents.directory().destroy(actual._world)
			var replacement: Vector2i = actual._residents.directory().create(Directory.KIND_WORLD)
			applied = applied and replacement.x == actual._world.x and replacement.y != actual._world.y
		elif change == 3:
			applied = items.load_default(foreign_inventory).ok

class ObservedCatalog extends Catalog:

	var corrupt_digest: bool = false

	func content_hash_into(revision: int, out: PackedByteArray) -> bool:
		"""The header's real Catalog observer can likewise alter the previously valid output shape."""
		var valid: bool = super.content_hash_into(revision, out)
		if corrupt_digest:
			corrupt_digest = false
			out.resize(1)
		return valid

var _fixture: IsolatedFixture = null
var _catalog: Catalog = null
var _recipes: Recipes = null
var _items: Items = null
var _inventory: Inventory = null
var _reader: Assemblies = null
var _out: Assemblies.AssemblyRecord = null
var _group_hash: String = ""
var _recipe_hash: String = ""


func before_each() -> void:
	"""Every namespace, recipe and generation is real; only the finite geometric source is synthetic."""
	_fixture = IsolatedFixture.new()
	_fixture.before_each()
	_catalog = _fixture._catalog
	assert_equal(_load_catalog(_catalog_wire(4)), &"", "actual Catalog accepts synthetic four-part variant")
	_inventory = Inventory.new(16, 32)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual Inventory registration")
	_out = Assemblies.AssemblyRecord.new()


func after_each() -> void:
	"""Clear every weak-observer fixture and only this suite's own source files."""
	_out = null
	_reader = null
	_recipes = null
	_items = null
	_inventory = null
	_catalog = null
	_fixture.after_each()
	_fixture = null
	for path: String in [GROUP_PATH, RECIPE_PATH, CATALOG_PATH, PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _catalog_wire(parts: int, revision: int = 1) -> PackedByteArray:
	"""Independent one-variant wire reuses actual fixture shapes, not its loader's private row layout."""
	var source: PackedByteArray = Fixture.synthetic_image(revision)
	var bytes: PackedByteArray = source.slice(0, Fixture.VARIANT_BASE)
	var counts: PackedInt32Array = PackedInt32Array([1, 2, 6, parts, parts * 4, 1, 2])
	for index: int in 7:
		bytes.encode_u32(20 + index * 4, counts[index])
	var variant: PackedByteArray = source.slice(Fixture.VARIANT_BASE, Fixture.VARIANT_BASE + 112)
	variant.encode_s32(18 * 4, parts)
	variant.encode_s32(20 * 4, parts * 4)
	bytes.append_array(variant)
	bytes.append_array(source.slice(Fixture.PATH_BASE, Fixture.PATH_BASE + 32))
	bytes.append_array(source.slice(Fixture.REGION_BASE, Fixture.REGION_BASE + 192))
	for index: int in parts:
		var part: PackedByteArray = source.slice(Fixture.PART_BASE, Fixture.PART_BASE + 36)
		part.encode_s32(7 * 4, index * 4)
		bytes.append_array(part)
	for index: int in parts:
		bytes.append_array(source.slice(Fixture.VERTEX_BASE, Fixture.VERTEX_BASE + 48))
	bytes.append_array(source.slice(Fixture.MATERIAL_BASE, Fixture.MATERIAL_BASE + 4))
	bytes.append_array(source.slice(Fixture.PACE_BASE, Fixture.PACE_BASE + 72))
	bytes.append_array("UGCEND01".to_ascii_buffer())
	return bytes


func _load_catalog(bytes: PackedByteArray, revision: int = 1) -> StringName:
	"""All source replacements pass the actual Catalog decoder and exact SHA check."""
	return _catalog.load_file(CATALOG_PATH, Fixture._write(CATALOG_PATH, bytes), revision)


func _group_wire(count: int = 2, parts_per_group: int = 2) -> PackedByteArray:
	"""The grouping has no recipe digest, so its source hash exists before the actual recipe is written."""
	var bytes: PackedByteArray = "UGASMB01".to_ascii_buffer()
	bytes.resize(Assemblies.WIRE_HEADER_BYTES + count * Assemblies.WIRE_ROW_BYTES)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, GROUP_REVISION)
	bytes.encode_s64(20, _catalog.content_revision())
	bytes.encode_s64(28, RECIPE_REVISION)
	bytes.encode_s32(36, 0)
	bytes.encode_s64(40, 1)
	bytes.encode_u32(48, count)
	bytes.encode_u32(52, count * parts_per_group)
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(_catalog.content_hash_into(_catalog.content_revision(), digest), "actual Catalog pin")
	for index: int in 32:
		bytes[56 + index] = digest[index]
	for row: int in count:
		var at: int = Assemblies.WIRE_HEADER_BYTES + row * Assemblies.WIRE_ROW_BYTES
		bytes.encode_s32(at, Assemblies.LANDING if row % 5 == 0 else Assemblies.TREAD)
		bytes.encode_s32(at + 4, row * parts_per_group)
		bytes.encode_s32(at + 8, parts_per_group)
		bytes.encode_s32(at + 12, row * parts_per_group)
	bytes.append_array("UGAEND01".to_ascii_buffer())
	return bytes


func _recipe_wire(group_digest: String, anchors: PackedInt32Array) -> PackedByteArray:
	"""Each canonical group anchor gets one synthetic wood bill; no included part receives another row."""
	var bytes: PackedByteArray = "UGRECP01".to_ascii_buffer()
	bytes.resize(Recipes.WIRE_HEADER_BYTES + anchors.size() * Recipes.WIRE_ROW_BYTES)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, RECIPE_REVISION)
	bytes.encode_s64(20, _catalog.content_revision())
	bytes.encode_s64(28, GROUP_REVISION)
	bytes.encode_s32(36, 0)
	bytes.encode_s64(40, 1)
	bytes.encode_u32(48, anchors.size())
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(_catalog.content_hash_into(_catalog.content_revision(), digest), "actual Catalog pin")
	var groups: PackedByteArray = group_digest.hex_decode()
	for index: int in 32:
		bytes[52 + index] = digest[index]
		bytes[84 + index] = groups[index]
	for row: int in anchors.size():
		var at: int = Recipes.WIRE_HEADER_BYTES + row * Recipes.WIRE_ROW_BYTES
		bytes.encode_s32(at, anchors[row])
		bytes.encode_s32(at + 4, 1)
		bytes.encode_s64(at + 8, 12000 + row)
		for index: int in 4:
			bytes[at + 16 + index] = "wood".unicode_at(index)
		bytes.encode_s64(at + 24, 1000)
	bytes.append_array("UGREND01".to_ascii_buffer())
	return bytes


func _bind_source(bytes: PackedByteArray, anchors: PackedInt32Array,
		observed: bool = false, capacity: int = 256) -> void:
	"""Use actual immutable Recipe loading first; its expected grouping SHA is already deterministic."""
	_group_hash = _write_group(bytes)
	_recipes = ObservedRecipes.new() if observed else Recipes.new()
	assert_equal(_recipes.configure(256, Recipes.required_bytes(256)), &"", "actual recipe arena")
	assert_equal(_recipes.bind_actual(_catalog, _items, _inventory), &"", "actual recipe owners")
	_recipe_hash = Fixture._write(RECIPE_PATH, _recipe_wire(_group_hash, anchors))
	assert_equal(_recipes.load_file(RECIPE_PATH, _recipe_hash, RECIPE_REVISION, _group_hash, GROUP_REVISION),
		&"", "actual recipe with grouping pin")
	_reader = Assemblies.new()
	assert_equal(_reader.configure(capacity, Assemblies.required_bytes(capacity)), &"", "actual group arena")
	assert_equal(_reader.bind_actual(_catalog, _recipes, _items, _inventory), &"", "same actual source owners")


static func _write_group(bytes: PackedByteArray) -> String:
	"""Hash an intentionally empty corrupt fixture without invoking the engine's invalid empty update."""
	var file: FileAccess = FileAccess.open(GROUP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		digest.update(bytes)
	return digest.finish().hex_encode()


func _load_source() -> StringName:
	"""Call the public source protocol without bypassing its independent Recipe digest."""
	return _reader.load_file(GROUP_PATH, _group_hash, GROUP_REVISION, _recipe_hash, RECIPE_REVISION)


static func _record_image(record: Assemblies.AssemblyRecord) -> PackedInt64Array:
	"""Observe all output fields independently of the source decoder."""
	return PackedInt64Array([record.kind, record.first_part, record.part_count, record.recipe_anchor])


func test_two_groups_cover_four_actual_parts_with_one_anchor_each() -> void:
	"""A tread and included bearer are one group; visual primitives never each acquire a bill."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]))
	assert_equal(_load_source(), &"", "complete exact partition")
	assert_equal(_reader.assembly_into(0, 1, GROUP_REVISION, 1, _out), &"", "second group")
	assert_equal(_record_image(_out), PackedInt64Array([Assemblies.TREAD, 2, 2, 2]), "one bill for two parts")
	_out.part_count = 999
	assert_equal(_reader.assembly_into(0, 1, GROUP_REVISION, 0, _out), &"", "copy independent of caller")
	assert_equal(_record_image(_out), PackedInt64Array([Assemblies.LANDING, 0, 2, 0]), "exact first group")
	assert_true(_reader.binding_matches(_catalog, _recipes, _items, _inventory, _group_hash, GROUP_REVISION), "exact binding")
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(_reader.content_hash_into(GROUP_REVISION, digest), "accepted source digest")
	assert_equal(digest.hex_encode(), _group_hash, "same bytes, not a second file hash")
	assert_equal(_reader.assembly_count(GROUP_REVISION), 2, "current exact census")
	assert_equal(_reader.assembly_count(GROUP_REVISION + 1), 0, "wrong revision is refusal, not empty content")


func test_unknown_empty_gap_overlap_and_outside_anchor_refuse() -> void:
	"""Corruptions carry correct SHA pins; refusal comes from complete ownership semantics."""
	var cases: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, Assemblies.KIND_COUNT),
		Vector2i(4, 1), Vector2i(8, 0), Vector2i(8, -1), Vector2i(8, 2147483647),
		Vector2i(12, 2), Vector2i(20, 1), Vector2i(20, 3), Vector2i(28, 0)]
	for mutation: Vector2i in cases:
		var bytes: PackedByteArray = _group_wire()
		bytes.encode_s32(Assemblies.WIRE_HEADER_BYTES + mutation.x, mutation.y)
		_bind_source(bytes, PackedInt32Array([0, 2]))
		assert_equal(_load_source(), Assemblies.REFUSE_PARTITION, "invalid exact group partition")
		assert_equal(_reader.content_revision(), 0, "failed source stays unpublished")


func test_actual_catalog_census_prevents_missing_or_invented_parts() -> void:
	"""Neither a smaller caller part count nor a truncated last group excuses missing real geometry."""
	for count: int in [2, 3, 5, 257]:
		var bytes: PackedByteArray = _group_wire()
		bytes.encode_u32(52, count)
		_bind_source(bytes, PackedInt32Array([0, 2]))
		assert_equal(_load_source(), Assemblies.REFUSE_PARTITION, "exact actual Catalog census")
	var missing_last: PackedByteArray = _group_wire()
	missing_last.encode_s32(Assemblies.WIRE_HEADER_BYTES + 24, 1)
	_bind_source(missing_last, PackedInt32Array([0, 2]))
	assert_equal(_load_source(), Assemblies.REFUSE_PARTITION, "last actual part cannot disappear")


func test_extra_included_part_bill_missing_group_and_wrong_anchor_refuse() -> void:
	"""The actual recipe rows are a bijection with groups, never merely a superset containing anchors."""
	for anchors: PackedInt32Array in [PackedInt32Array([0, 1, 2]), PackedInt32Array([0]), PackedInt32Array([0, 3])]:
		_bind_source(_group_wire(), anchors)
		assert_equal(_load_source(), Assemblies.REFUSE_RECIPE, "no second bearer bill or absent assembly bill")
		assert_equal(_reader.content_revision(), 0, "no partial grouping published")


func test_refused_reads_preserve_every_output_and_successful_load_is_immutable() -> void:
	"""Caller packets remain unchanged across wrong source revisions, ordinals and repeated load attempts."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]))
	assert_equal(_load_source(), &"", "valid")
	_out.kind = 77
	_out.first_part = 88
	_out.part_count = 99
	_out.recipe_anchor = 100
	var before: PackedInt64Array = _record_image(_out)
	for request: PackedInt32Array in [PackedInt32Array([1, 1, 17, 0]), PackedInt32Array([0, 2, 17, 0]),
		PackedInt32Array([0, 1, 18, 0]), PackedInt32Array([0, 1, 17, -1]), PackedInt32Array([0, 1, 17, 2])]:
		assert_true(_reader.assembly_into(request[0], request[1], request[2], request[3], _out) != &"", "invalid query")
		assert_equal(_record_image(_out), before, "all fields preserved")
	assert_equal(_reader.assembly_into(0, 1, 17, 0, null), Assemblies.REFUSE_OUTPUT, "null output")
	assert_equal(_load_source(), Assemblies.REFUSE_SOURCE, "no successful replacement/reload")
	assert_equal(_reader.content_revision(), GROUP_REVISION, "prior source remains")


func test_failed_first_hash_load_clears_bank_and_can_retry() -> void:
	"""Refused loading cannot expose partly validated source bytes or make recovery allocate a second bank."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]))
	var allocated: int = _reader.packed_memory_bytes()
	assert_equal(_reader.load_file(GROUP_PATH, "00".repeat(32), 17, _recipe_hash, 7), Assemblies.REFUSE_SOURCE, "wrong grouping pin")
	assert_equal(_reader._header, PackedInt64Array([0, 0, 0, 0, 0, 0, 0]), "header cleared")
	assert_equal(_reader._recipe_anchor[0], -1, "unpublished group cleared")
	assert_equal(_reader.packed_memory_bytes(), allocated, "same admitted bank")
	assert_equal(_load_source(), &"", "retry exact source succeeds")


func test_wire_truncation_tail_version_counts_and_recipe_digest_refuse() -> void:
	"""Wire extent and capacities fail before row loops, even when their external hashes are correct."""
	var valid: PackedByteArray = _group_wire()
	for size: int in [0, 8, 87, valid.size() - 1, valid.size() + 1]:
		var bytes: PackedByteArray = valid.duplicate()
		bytes.resize(size)
		_bind_source(bytes, PackedInt32Array([0, 2]))
		assert_true(_load_source() != &"", "invalid exact wire size")
	for change: Vector2i in [Vector2i(8, 2), Vector2i(48, 0), Vector2i(48, 257)]:
		var bytes: PackedByteArray = valid.duplicate()
		bytes.encode_u32(change.x, change.y)
		_bind_source(bytes, PackedInt32Array([0, 2]))
		assert_true(_load_source() != &"", "unsupported version or capacity")
	_bind_source(valid, PackedInt32Array([0, 2]))
	assert_equal(_reader.load_file(GROUP_PATH, _group_hash, 17, "11".repeat(32), 7), Assemblies.REFUSE_SOURCE, "exact Recipe pin")


func test_allocation_preflight_and_independent_packed_census() -> void:
	"""Each actual column is counted independently; capacities are engineering refusals, never truncation."""
	var reader: Assemblies = Assemblies.new()
	assert_equal(reader.packed_memory_bytes(), 0, "no premature arrays")
	assert_equal(reader.assembly_count(GROUP_REVISION), 0, "unconfigured source refuses")
	for count: int in [-1, 0, 257, 9223372036854775807]:
		assert_equal(reader.configure(count, 1), Assemblies.REFUSE_CAPACITY, "invalid capacity")
		assert_equal(reader.packed_memory_bytes(), 0, "still no allocation")
	assert_equal(reader.configure(256, Assemblies.required_bytes(256) - 1), Assemblies.REFUSE_CAPACITY, "short admission")
	assert_equal(reader.configure(256, Assemblies.required_bytes(256)), &"", "complete finite bank")
	var bytes: int = 0
	var columns: int = 0
	for property: Dictionary in reader.get_property_list():
		if property.type == TYPE_PACKED_BYTE_ARRAY or property.type == TYPE_PACKED_INT32_ARRAY or property.type == TYPE_PACKED_INT64_ARRAY:
			columns += 1
			bytes += reader.get(property.name).size() * (1 if property.type == TYPE_PACKED_BYTE_ARRAY else 4 if property.type == TYPE_PACKED_INT32_ARRAY else 8)
	assert_equal(columns, 8, "every declared packed column")
	assert_equal(bytes, 16 * 256 + 152 + 68, "real bank plus fixed packed scratch")
	assert_equal(reader.packed_memory_bytes(), bytes, "reader census agrees")
	assert_equal(reader.configure(1, Assemblies.required_bytes(1)), Assemblies.REFUSE_CAPACITY, "no reallocation")


func test_exact_generic_maximum_and_twenty_six_candidate_groups() -> void:
	"""The engineering maximum does not force a26-group gameplay limit or one bill per prism."""
	for count: int in [26, 256]:
		assert_equal(_load_catalog(_catalog_wire(count, count), count), &"", "actual finite Catalog")
		var anchors: PackedInt32Array = PackedInt32Array()
		for ordinal: int in count:
			anchors.append(ordinal)
		_bind_source(_group_wire(count, 1), anchors, false, count)
		assert_equal(_load_source(), &"", "full generic group partition")
		assert_equal(_reader.assembly_count(GROUP_REVISION), count, "exact source-owned prefix maximum")
		for ordinal: int in count:
			assert_equal(_reader.assembly_into(0, 1, 17, ordinal, _out), &"", "every exact group")
			assert_equal(_out.recipe_anchor, ordinal, "one real bill anchor")


func test_foreign_actual_recipe_inventory_and_rebinding_refuse() -> void:
	"""Equal item and Catalog ordinals in another owner cannot satisfy an existing source composition."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]))
	var foreign: Inventory = Inventory.new(16, 32)
	var other_items: Items = Items.new()
	assert_true(other_items.load_default(foreign).ok, "actual foreign namespace")
	var reader: Assemblies = Assemblies.new()
	assert_equal(reader.configure(2, Assemblies.required_bytes(2)), &"", "finite bank")
	assert_equal(reader.bind_actual(_catalog, _recipes, _items, foreign), Assemblies.REFUSE_BINDING, "foreign Inventory")
	assert_equal(reader.bind_actual(_catalog, _recipes, other_items, foreign), Assemblies.REFUSE_BINDING, "foreign actual Items")
	assert_equal(reader.bind_actual(_catalog, _recipes, _items, _inventory), &"", "refused attempt did not bind")
	assert_equal(reader.bind_actual(_catalog, _recipes, _items, _inventory), Assemblies.REFUSE_BINDING, "once bound")


func test_current_catalog_replacement_invalidates_grouping_without_output_writes() -> void:
	"""Unchanged part ordinals in new Catalog bytes cannot inherit an earlier grouping or bill."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]))
	assert_equal(_load_source(), &"", "valid")
	var before: PackedInt64Array = _record_image(_out)
	assert_equal(_load_catalog(_catalog_wire(4, 2), 2), &"", "actual replacement")
	assert_equal(_reader.assembly_into(0, 1, 17, 0, _out), Assemblies.REFUSE_SOURCE, "old source invalid")
	assert_equal(_record_image(_out), before, "no stale answer")
	assert_false(_reader.binding_matches(_catalog, _recipes, _items, _inventory, _group_hash, 17), "source unavailable")
	assert_equal(_reader.assembly_count(GROUP_REVISION), 0, "changed Catalog cannot appear complete")


func _arm_final(change: int, reader: bool = false) -> ObservedRecipes:
	"""The callback runs after actual Recipe.binding_matches has returned successfully."""
	var observed: ObservedRecipes = _recipes as ObservedRecipes
	observed.fixture = weakref(_fixture)
	observed.change = change
	observed.armed = true
	if reader:
		observed.reader = weakref(_reader)
		observed.nested = Assemblies.AssemblyRecord.new()
	if change == 3:
		observed.foreign_inventory = Inventory.new(16, 32)
	return observed


func test_final_recipe_callback_cannot_reenter_or_replace_current_source() -> void:
	"""The final source observer is followed by pure full World/Profile/Items/Catalog checks."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]), true)
	assert_equal(_load_source(), &"", "valid")
	var observed: ObservedRecipes = _arm_final(0, true)
	assert_equal(_reader.assembly_count(GROUP_REVISION), 2, "count uses pure actual leaf")
	assert_true(observed.armed, "count called no overridable source observer")
	assert_equal(_reader.assembly_into(0, 1, 17, 0, _out), &"", "outer legitimate read")
	assert_equal(observed.nested_refusal, Assemblies.REFUSE_SOURCE, "reentry refused")
	var before: PackedInt64Array = _record_image(_out)
	observed = _arm_final(1)
	assert_equal(_reader.assembly_into(0, 1, 17, 1, _out), Assemblies.REFUSE_SOURCE, "late actual Profile reload")
	assert_true(observed.applied, "actual mutation happened after final observer")
	assert_equal(_record_image(_out), before, "no stale output")
	assert_equal(_reader.assembly_count(GROUP_REVISION), 0, "changed Profile is not an empty successful grouping")


func test_last_observer_world_retirement_refuses_initial_publication() -> void:
	"""A World with the same slot but new generation cannot publish a decoded grouping."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]), true)
	var observed: ObservedRecipes = _arm_final(2)
	assert_equal(_load_source(), Assemblies.REFUSE_SOURCE, "late World invalidation")
	assert_true(observed.applied, "World retired and slot reused")
	assert_equal(_reader.content_revision(), 0, "nothing published")


func test_last_observer_registration_rewire_preserves_hash_output() -> void:
	"""The same Catalog and Recipe digests do not validate a new actual Inventory registration target."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]), true)
	assert_equal(_load_source(), &"", "valid")
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	digest.fill(91)
	var before: PackedByteArray = digest.duplicate()
	var observed: ObservedRecipes = _arm_final(3)
	assert_false(_reader.content_hash_into(17, digest), "late actual Items rewire")
	assert_true(observed.applied, "registration actually changed")
	assert_equal(digest, before, "hash output unchanged")


func test_last_callback_output_resize_is_not_a_partial_hash_success() -> void:
	"""A caller-owned output changed by the final observer cannot trigger an out-of-range copy."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]), true)
	assert_equal(_load_source(), &"", "valid")
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	digest.fill(44)
	var observed: ObservedRecipes = _arm_final(0)
	observed.resize_output = digest
	assert_false(_reader.content_hash_into(17, digest), "resized after observer")
	assert_equal(digest, PackedByteArray([44]), "only callback mutation, no partial reader write")


func test_recipe_digest_callback_resize_refuses_before_any_hash_index() -> void:
	"""A successful source callback is not proof that its borrowed output retained the required shape."""
	_bind_source(_group_wire(), PackedInt32Array([0, 2]), true)
	assert_equal(_load_source(), &"", "valid initial bank")
	var observed: ObservedRecipes = _recipes as ObservedRecipes
	observed.corrupt_digest = true
	var before: PackedInt64Array = _record_image(_out)
	assert_equal(_reader.assembly_into(0, 1, 17, 0, _out), Assemblies.REFUSE_SOURCE, "resized recipe hash")
	assert_equal(_reader._hash.size(), 1, "callback actually altered borrowed scratch")
	assert_equal(_record_image(_out), before, "no partial result or out-of-range hash read")


func test_catalog_digest_callback_resize_refuses_unpublished_header() -> void:
	"""A malformed Catalog digest observation cannot publish a partially decoded grouping."""
	var observed: ObservedCatalog = ObservedCatalog.new()
	assert_equal(observed.configure(Catalog.RESERVED_BYTES), &"", "actual finite Catalog bank")
	assert_equal(observed.bind_actual(_fixture._profiles, _fixture._levels, _fixture._movement,
		_fixture._residents, _fixture._transforms, _fixture._domain), &"", "same actual composition")
	_catalog = observed
	assert_equal(_load_catalog(_catalog_wire(4)), &"", "actual Catalog bytes")
	_bind_source(_group_wire(), PackedInt32Array([0, 2]))
	observed.corrupt_digest = true
	assert_equal(_load_source(), Assemblies.REFUSE_SOURCE, "resized Catalog hash")
	assert_equal(_reader._hash.size(), 1, "callback actually altered borrowed scratch")
	assert_equal(_reader.content_revision(), 0, "source remains unpublished")
