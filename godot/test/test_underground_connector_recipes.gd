extends "res://test/framework/test_case.gd"
## Synthetic prices exercise an actual immutable catalog/Items/Inventory reader, never active costs.

const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const ConnectorCatalog := preload("res://scripts/core/underground_connector_catalog.gd")
const ConnectorFixture := preload("res://test/test_underground_connector_catalog.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const FRONTIER_HASH: String = "9898989898989898989898989898989898989898989898989898989898989898"
const TEMP: String = "user://test-connector-recipes.bin"


class ObservedCatalog extends ConnectorCatalog:
	"""Exercise source callback reentry and actual registration changes, never fake a valid catalog."""
	var reader_ref: WeakRef = null
	var nested_quote: Contract.Quote = null
	var nested_refusal: StringName = &""
	var rewire_items: Items = null
	var rewire_inventory: Inventory = null
	var reshape_quote: Contract.Quote = null
	var source_fixture: WeakRef = null
	var invalidate_world: bool = false
	var mutation_applied: bool = false
	var delay_hash_reads: int = 0
	var rewired: bool = false
	var armed: bool = false

	func content_hash_into(revision: int, out: PackedByteArray) -> bool:
		"""Only observe after the real catalog read; consume the hook once to bound the test."""
		var accepted: bool = super.content_hash_into(revision, out)
		if armed:
			if delay_hash_reads > 0:
				delay_hash_reads -= 1
				return accepted
			armed = false
			if reader_ref != null:
				nested_refusal = reader_ref.get_ref().recipe_into(0, 1, 0, 7, nested_quote)
			if rewire_items != null:
				rewired = rewire_items.load_default(rewire_inventory).ok
			if reshape_quote != null:
				reshape_quote.input_milli.resize(1)
			if source_fixture != null:
				_mutate_actual_source()
		return accepted

	func _mutate_actual_source() -> void:
		"""Change a real underlying owner only after the selected actual Catalog hash observation."""
		var fixture: ConnectorFixture = source_fixture.get_ref() as ConnectorFixture
		if invalidate_world:
			mutation_applied = fixture._residents.directory().destroy(fixture._world)
			var replacement: Vector2i = fixture._residents.directory().create(Directory.KIND_WORLD)
			mutation_applied = mutation_applied and replacement.x == fixture._world.x and replacement.y != fixture._world.y
		else:
			mutation_applied = fixture._load_profiles(ConnectorFixture.synthetic_profile_image(fixture._identity, 2), 2) == &""


var _fixture: ConnectorFixture = null
var _catalog: ConnectorCatalog = null
var _items: Items = null
var _inventory: Inventory = null
var _reader: Recipes = null
var _quote: Contract.Quote = null


func before_each() -> void:
	"""Reuse only labeled synthetic geometry; all catalog, World and inventory owners are actual."""
	_fixture = ConnectorFixture.new()
	_fixture.before_each()
	_catalog = _fixture._catalog
	assert_equal(_fixture._load(ConnectorFixture.synthetic_image()), &"", "actual catalog loads fixture")
	_inventory = Inventory.new(16, 32)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual registered materials")
	_reader = Recipes.new()
	assert_equal(_reader.configure(256, Recipes.required_bytes(256)), &"", "explicit logical budget")
	assert_equal(_reader.bind_actual(_catalog, _items, _inventory), &"", "exact actual owners")
	_quote = Contract.Quote.new()


func after_each() -> void:
	"""No runtime fixture or reader source is retained after this suite's case."""
	_quote = null
	_reader = null
	_items = null
	_inventory = null
	_catalog = null
	_fixture.after_each()
	_fixture = null
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


func _wire(count: int = 1) -> PackedByteArray:
	"""Independent row-wire encoder: every numeric cost here is explicitly synthetic test data."""
	var bytes: PackedByteArray = "UGRECP01".to_ascii_buffer()
	bytes.resize(Recipes.WIRE_HEADER_BYTES + count * Recipes.WIRE_ROW_BYTES)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, 7)
	bytes.encode_s64(20, _catalog.content_revision())
	bytes.encode_s64(28, 11)
	bytes.encode_s32(36, 0)
	bytes.encode_s64(40, 1)
	bytes.encode_u32(48, count)
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(_catalog.content_hash_into(_catalog.content_revision(), digest), "actual catalog digest")
	for index: int in 32:
		bytes[52 + index] = digest[index]
		bytes[84 + index] = 0x98
	for row: int in count:
		var at: int = Recipes.WIRE_HEADER_BYTES + row * Recipes.WIRE_ROW_BYTES
		bytes.encode_s32(at, row)
		bytes.encode_s32(at + 4, 2)
		bytes.encode_s64(at + 8, 12345 + row)
		_line(bytes, at + 16, "wood", 1001)
		_line(bytes, at + 32, "rope", 501)
	bytes.append_array("UGREND01".to_ascii_buffer())
	return bytes


static func _line(bytes: PackedByteArray, offset: int, key: String, quantity: int) -> void:
	"""Eight zero-padded ASCII key bytes precede one signed I64 milli quantity."""
	for index: int in 8:
		bytes[offset + index] = key.unicode_at(index) if index < key.length() else 0
	bytes.encode_s64(offset + 8, quantity)


func _load(bytes: PackedByteArray, hash_override: String = "") -> StringName:
	"""Use the public streamed loader with the digest of this exact test source."""
	var digest: String = ConnectorFixture._write(TEMP, bytes)
	return _reader.load_file(TEMP, digest if hash_override.is_empty() else hash_override, 7, FRONTIER_HASH, 11)


func _observed_catalog() -> ObservedCatalog:
	"""Bind an instrumented actual catalog to the same actual stores using its real public protocol."""
	var observed: ObservedCatalog = ObservedCatalog.new()
	assert_equal(observed.configure(ConnectorCatalog.RESERVED_BYTES), &"", "finite observed catalog")
	assert_equal(observed.bind_actual(_fixture._profiles, _fixture._levels, _fixture._movement,
		_fixture._residents, _fixture._transforms, _fixture._domain), &"", "same actual source owners")
	_catalog = observed
	_fixture._catalog = observed
	assert_equal(_fixture._load(ConnectorFixture.synthetic_image()), &"", "actual observed source")
	_reader = Recipes.new()
	assert_equal(_reader.configure(256, Recipes.required_bytes(256)), &"", "one finite bill bank")
	assert_equal(_reader.bind_actual(observed, _items, _inventory), &"", "exact observed catalog")
	return observed


static func _quote_image(quote: Contract.Quote) -> PackedByteArray:
	"""Compare every caller-owned scalar, input key and output metadata field on refusal."""
	return var_to_bytes([quote.subject, quote.operation, quote.quantity_milli, quote.total_mwu,
		quote.remaining_mwu, quote.job_kind, quote.max_workers, quote.input_count, quote.input_keys,
		quote.input_milli, quote.output_count, quote.output_item, quote.output_milli, quote.output_quality,
		quote.output_provenance, quote.output_recipe, quote.output_age, quote.output_remainder])


static func _bank_image(reader: Recipes) -> PackedByteArray:
	"""Test-only cold copy includes every retained source/header field, excluding overwritten scratch."""
	return var_to_bytes([reader._header, reader._digests, reader._part_id, reader._input_count,
		reader._input_key, reader._work_mwu, reader._quantity, reader._catalog_row,
		reader._variant_revision, reader._loaded])


static func _packed_bytes(reader: Recipes) -> int:
	"""Reflect actual allocations independently from the production census formula."""
	var total: int = 0
	for property: Dictionary in reader.get_property_list():
		var value: Variant = reader.get(property.name)
		if value is PackedByteArray:
			total += value.size()
		elif value is PackedInt32Array:
			total += 4 * value.size()
		elif value is PackedInt64Array:
			total += 8 * value.size()
	return total


func test_budget_precedes_allocation_and_exact_single_bank_census() -> void:
	"""Huge/refused budgets allocate no bank; valid maxima match independently reflected columns."""
	for capacity: int in [0, -1, 257, IntMath.INT64_MAX]:
		var refused: Recipes = Recipes.new()
		assert_equal(Recipes.required_bytes(capacity), 0, "invalid source budget")
		assert_equal(refused.configure(capacity, 1), Recipes.REFUSE_CAPACITY, "no clamp admission")
		assert_equal(_packed_bytes(refused), 0, "no packed allocation")
	for capacity: int in [1, 7, 256]:
		var accepted: Recipes = Recipes.new()
		assert_equal(accepted.configure(capacity, Recipes.required_bytes(capacity) - 1), Recipes.REFUSE_CAPACITY, "one byte short")
		assert_equal(_packed_bytes(accepted), 0, "refused envelope has no bank")
		assert_equal(accepted.configure(capacity, Recipes.required_bytes(capacity)), &"", "complete envelope")
		assert_equal(_packed_bytes(accepted), 64 * capacity + 128 + 68, "source-derived actual packed census")
		assert_equal(accepted.packed_memory_bytes(), _packed_bytes(accepted), "reported payload agrees")
		assert_equal(accepted.configure(capacity, Recipes.required_bytes(capacity)), Recipes.REFUSE_CAPACITY, "cannot allocate second bank")


func test_exact_prices_reset_old_scratch_without_granting_subject_or_outputs() -> void:
	"""Loading prices creates neither a paid Construction subject nor inventory/placement permission."""
	assert_equal(_load(_wire()), &"", "immutable fixture bill")
	_quote.subject = Vector2i(99, 8)
	_quote.output_count = 2
	_quote.output_milli.fill(999)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), &"", "exact source-qualified part")
	assert_equal(_quote.subject, Vector2i(-1, 0), "real owner still must supply subject")
	assert_equal(_quote.refusal(), Contract.REFUSE_QUOTE, "price read is not a valid order")
	assert_equal(_quote.total_mwu, 12345, "test-only work copied exactly")
	assert_equal(_quote.input_keys, [&"wood", &"rope", &"", &""], "canonical original keys")
	assert_equal(_quote.input_milli, PackedInt64Array([1001, 501, 0, 0]), "no unit rounding")
	assert_equal(_quote.output_count, 0, "installation never creates a loose item")
	assert_equal(_quote.max_workers, 4, "existing actual construction worker bound")
	assert_true(_reader.binding_matches(_catalog, _items, _inventory, FRONTIER_HASH, 11), "full source pins")
	var out: PackedByteArray = PackedByteArray()
	out.resize(32)
	assert_true(_reader.content_hash_into(7, out), "recipe digest read")
	assert_equal(out.hex_encode(), ConnectorFixture._write(TEMP, _wire()), "exact hashed source")


func test_missing_and_foreign_variant_reads_preserve_every_quote_byte() -> void:
	"""No neighboring recipe, wrong revision or malformed output can become a free or partial bill."""
	assert_equal(_load(_wire()), &"", "valid source")
	_quote.subject = Vector2i(8, 4)
	_quote.total_mwu = 99
	var before: PackedByteArray = _quote_image(_quote)
	for request: PackedInt32Array in [PackedInt32Array([0, 1, 1, 7]), PackedInt32Array([1, 1, 0, 7]),
			PackedInt32Array([0, 2, 0, 7]), PackedInt32Array([0, 1, 0, 8])]:
		assert_true(_reader.recipe_into(request[0], request[1], request[2], request[3], _quote) != &"", "exact tuple required")
		assert_equal(_quote_image(_quote), before, "all caller fields unchanged")
	_quote.output_remainder.resize(1)
	before = _quote_image(_quote)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_OUTPUT, "exact scratch shape")
	assert_equal(_quote_image(_quote), before, "no shape repair")
	assert_equal(_reader.recipe_into(0, 1, 0, 7, null), Recipes.REFUSE_OUTPUT, "null refused")


func test_header_hash_length_and_terminal_refusals_clear_unpublished_bank() -> void:
	"""Every rejected first load leaves the whole source bank empty and a valid retry available."""
	var pristine: PackedByteArray = _bank_image(_reader)
	for offset: int in [0, 8, 12, 20, 28, 36, 40, 48, 52, 84, 196]:
		var bytes: PackedByteArray = _wire()
		bytes[offset] ^= 0x40
		assert_true(_load(bytes) != &"", "corrupted source offset %d" % offset)
		assert_equal(_bank_image(_reader), pristine, "no partial source escaped")
	var short: PackedByteArray = _wire()
	short.resize(short.size() - 1)
	assert_equal(_load(short), Recipes.REFUSE_FORMAT, "short stream")
	assert_equal(_load(_wire(), FRONTIER_HASH), Recipes.REFUSE_SOURCE, "wrong external recipe hash")
	assert_equal(_bank_image(_reader), pristine, "whole failed source cleared")
	assert_equal(_load(_wire()), &"", "valid retry")


func test_empty_duplicate_unknown_and_hidden_materials_refuse_without_partial_bank() -> void:
	"""An authored price must have actual distinct inputs; unused slots cannot smuggle a bill."""
	var pristine: PackedByteArray = _bank_image(_reader)
	for count: int in [0, -1, 5]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s32(120, count)
		assert_equal(_load(bytes), Recipes.REFUSE_BILL, "input count domain")
	for key: String in ["wood", "earth", "missing"]:
		var bytes: PackedByteArray = _wire()
		_line(bytes, 148, key, 501)
		assert_equal(_load(bytes), Recipes.REFUSE_BILL, "duplicate or unavailable key")
	var hidden: PackedByteArray = _wire()
	_line(hidden, 164, "stone", 1)
	assert_equal(_load(hidden), Recipes.REFUSE_BILL, "unused line canonical")
	hidden = _wire()
	hidden[136] = 1
	assert_equal(_load(hidden), Recipes.REFUSE_FORMAT, "key padding canonical")
	assert_equal(_bank_image(_reader), pristine, "all source bytes preserved")


func test_negative_work_quantity_and_mass_or_refund_overflow_refuse() -> void:
	"""Integer-only prices cannot reach an unpayable or unrefundable overflowing operation."""
	for work: int in [0, -1]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s64(124, work)
		assert_equal(_load(bytes), Recipes.REFUSE_BILL, "positive work required")
	for quantity: int in [0, -1, IntMath.INT64_MAX]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s64(140, quantity)
		assert_equal(_load(bytes), Recipes.REFUSE_BILL, "positive bounded material amount")
	assert_equal(_reader.content_revision(), 0, "no price published")


func test_catalog_replacement_and_profile_source_drift_invalidate_old_prices() -> void:
	"""Current catalog hashes and their actual source bindings are checked beyond immutable row IDs."""
	assert_equal(_load(_wire()), &"", "valid source")
	var before: PackedByteArray = _quote_image(_quote)
	assert_equal(_fixture._load(ConnectorFixture.synthetic_image(2), 2), &"", "real replacement catalog")
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "old geometry bytes refuse")
	assert_equal(_quote_image(_quote), before, "quote unchanged")
	assert_false(_reader.binding_matches(_catalog, _items, _inventory, FRONTIER_HASH, 11), "old recipe binding unavailable")


func test_actual_world_retirement_invalidates_price_read_without_output_writes() -> void:
	"""Keeping catalog bytes cannot resurrect the actual World generation it describes."""
	assert_equal(_load(_wire()), &"", "valid source")
	var before: PackedByteArray = _quote_image(_quote)
	assert_true(_fixture._residents.directory().destroy(_fixture._world), "retire actual World")
	var replacement: Vector2i = _fixture._residents.directory().create(Directory.KIND_WORLD)
	assert_equal(replacement.x, _fixture._world.x, "same numeric slot")
	assert_true(replacement.y != _fixture._world.y, "different World generation")
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "retired actual source refuses")
	assert_equal(_quote_image(_quote), before, "quote preserved")


func test_foreign_registration_and_late_rebinding_never_reuse_material_ids() -> void:
	"""Coincident IDs in a different Inventory do not supply this exact World's bill."""
	var foreign: Inventory = Inventory.new(16, 32)
	var other: Items = Items.new()
	assert_true(other.load_default(foreign).ok, "same numbers in foreign owner")
	var unbound: Recipes = Recipes.new()
	assert_equal(unbound.configure(1, Recipes.required_bytes(1)), &"", "small own arena")
	assert_equal(unbound.bind_actual(_catalog, _items, foreign), Recipes.REFUSE_BINDING, "foreign registration target")
	assert_equal(_load(_wire()), &"", "valid exact source")
	assert_false(_reader.binding_matches(_catalog, other, foreign, FRONTIER_HASH, 11), "exact object identities required")
	var fresh: Inventory = Inventory.new(16, 32)
	assert_true(_items.load_default(fresh).ok, "actual Items rewired outside reader")
	var before: PackedByteArray = _quote_image(_quote)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "late wiring refused")
	assert_equal(_quote_image(_quote), before, "no foreign material values copied")


func test_success_is_immutable_and_frontier_metadata_never_guesses_replacement() -> void:
	"""Reader replacement is explicit; source pins alone still grant no entry/profile permission."""
	assert_equal(_load(_wire()), &"", "one source admitted")
	var before: PackedByteArray = _bank_image(_reader)
	var changed: PackedByteArray = _wire()
	changed.encode_s64(124, 1)
	assert_equal(_load(changed), Recipes.REFUSE_SOURCE, "no second live/load bank")
	assert_equal(_bank_image(_reader), before, "entire original recipe retained")
	assert_false(_reader.binding_matches(_catalog, _items, _inventory, FRONTIER_HASH, 12), "exact frontier revision")
	assert_false(_reader.binding_matches(_catalog, _items, _inventory, "00".repeat(32), 11), "exact frontier content")
	var short: PackedByteArray = PackedByteArray([4, 5])
	assert_false(_reader.content_hash_into(7, short), "exact digest output size")
	assert_equal(short, PackedByteArray([4, 5]), "no output resizing")


static func _many_parts_catalog(parts: int) -> PackedByteArray:
	"""Construct one actual finite variant with independently repeated synthetic primitive rows."""
	var source: PackedByteArray = ConnectorFixture.synthetic_image()
	var bytes: PackedByteArray = source.slice(0, ConnectorFixture.VARIANT_BASE)
	var counts: PackedInt32Array = PackedInt32Array([1, 2, 6, parts, 4 * parts, 1, 2])
	for index: int in 7:
		bytes.encode_u32(20 + 4 * index, counts[index])
	var variant: PackedByteArray = source.slice(ConnectorFixture.VARIANT_BASE, ConnectorFixture.VARIANT_BASE + 112)
	variant.encode_s32(18 * 4, parts)
	variant.encode_s32(20 * 4, parts * 4)
	bytes.append_array(variant)
	bytes.append_array(source.slice(ConnectorFixture.PATH_BASE, ConnectorFixture.PATH_BASE + 32))
	bytes.append_array(source.slice(ConnectorFixture.REGION_BASE, ConnectorFixture.REGION_BASE + 192))
	for ordinal: int in parts:
		var part: PackedByteArray = source.slice(ConnectorFixture.PART_BASE, ConnectorFixture.PART_BASE + 36)
		part.encode_s32(7 * 4, ordinal * 4)
		bytes.append_array(part)
	for ordinal: int in parts:
		bytes.append_array(source.slice(ConnectorFixture.VERTEX_BASE, ConnectorFixture.VERTEX_BASE + 48))
	bytes.append_array(source.slice(ConnectorFixture.MATERIAL_BASE, ConnectorFixture.MATERIAL_BASE + 4))
	bytes.append_array(source.slice(ConnectorFixture.PACE_BASE, ConnectorFixture.PACE_BASE + 72))
	bytes.append_array("UGCEND01".to_ascii_buffer())
	return bytes


func test_full_256_part_bank_streams_exact_distinct_owned_rows() -> void:
	"""The maximum consumes one bank and each concrete catalog part receives only its own bill."""
	assert_equal(_fixture._load(_many_parts_catalog(256), 1), &"CONNECTOR_CATALOG_SOURCE", "existing revision cannot replace")
	var catalog_wire: PackedByteArray = _many_parts_catalog(256)
	catalog_wire.encode_s64(12, 2)
	assert_equal(_fixture._load(catalog_wire, 2), &"", "actual maximum variant source")
	assert_equal(_load(_wire(256)), &"", "stream maximum independent recipe rows")
	for ordinal: int in 256:
		assert_equal(_reader.recipe_into(0, 1, ordinal, 7, _quote), &"", "real fixed part")
		assert_equal(_quote.total_mwu, 12345 + ordinal, "part-specific authored fixture work")
	assert_equal(_packed_bytes(_reader), 16580, "one16512 bank and68 scratch; no load bank")
	assert_equal(_reader.recipe_into(0, 1, 256, 7, _quote), Recipes.REFUSE_MISSING, "no missing row fallback")


func test_duplicate_or_foreign_part_rows_and_oversize_stream_refuse() -> void:
	"""Capacity and real variant ownership are distinct from a syntactically valid row ordinal."""
	var duplicate: PackedByteArray = _wire(2)
	duplicate.encode_s32(Recipes.WIRE_HEADER_BYTES + Recipes.WIRE_ROW_BYTES, 0)
	assert_equal(_load(duplicate), Recipes.REFUSE_BILL, "duplicate part does not price twice")
	assert_equal(_load(_wire(2)), Recipes.REFUSE_SOURCE, "second part absent from exact actual variant")
	var too_many: PackedByteArray = _wire()
	too_many.encode_u32(48, 257)
	assert_equal(_load(too_many), Recipes.REFUSE_CAPACITY, "capacity before payload walk")
	assert_equal(_load(_wire()), &"", "failed complete streams leave retry clean")


func test_source_callbacks_cannot_reenter_or_publish_after_actual_registration_rewire() -> void:
	"""Exact exclusion and final actual-owner checks preserve caller output even after a valid source read."""
	var observed: ObservedCatalog = _observed_catalog()
	assert_equal(_load(_wire()), &"", "actual observed source loaded")
	observed.reader_ref = weakref(_reader)
	observed.nested_quote = Contract.Quote.new()
	observed.nested_quote.total_mwu = 888
	var nested_before: PackedByteArray = _quote_image(observed.nested_quote)
	observed.armed = true
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), &"", "outer source read remains valid")
	assert_equal(observed.nested_refusal, Recipes.REFUSE_SOURCE, "recursive price read refused")
	assert_equal(_quote_image(observed.nested_quote), nested_before, "recursive caller output unchanged")
	observed.reader_ref = null
	observed.rewire_items = _items
	observed.rewire_inventory = Inventory.new(16, 32)
	observed.armed = true
	var before: PackedByteArray = _quote_image(_quote)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "late actual rewire refused")
	assert_true(observed.rewired, "actual Items registration moved after digest copy")
	assert_equal(_quote_image(_quote), before, "no partial quote after collaborator changed")


func test_actual_profile_replacement_invalidates_old_source_bound_recipe() -> void:
	"""Catalog hash equality does not excuse changed actual profile content behind that catalog."""
	assert_equal(_load(_wire()), &"", "original actual sources")
	var before: PackedByteArray = _quote_image(_quote)
	assert_equal(_fixture._load_profiles(ConnectorFixture.synthetic_profile_image(_fixture._identity, 2), 2),
		&"", "actual profile owner replaced its immutable source")
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "old catalog binding is stale")
	assert_equal(_quote_image(_quote), before, "entire caller quote preserved")


func test_late_source_callback_resizing_caller_quote_never_partially_resets_it() -> void:
	"""The final shape guard follows every source callback before writing any price or clearing outputs."""
	var observed: ObservedCatalog = _observed_catalog()
	assert_equal(_load(_wire()), &"", "actual observed source")
	_quote.subject = Vector2i(8, 4)
	_quote.operation = 55
	_quote.total_mwu = 99
	_quote.input_milli.resize(1)
	var expected: PackedByteArray = _quote_image(_quote)
	_quote.input_milli.resize(Contract.INPUT_CAPACITY)
	observed.reshape_quote = _quote
	observed.armed = true
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_OUTPUT, "late malformed shape refused")
	assert_equal(_quote_image(_quote), expected, "only callback's resize occurred; reader wrote nothing")
	_quote.input_milli.resize(Contract.INPUT_CAPACITY)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), &"", "caller can restore shape and retry")


func _invalidate_at_final_hash(observed: ObservedCatalog, delay: int, world: bool = false) -> void:
	"""Recipe/load make three hash observations, binding/digest make two; mutate on the final one."""
	observed.source_fixture = weakref(_fixture)
	observed.invalidate_world = world
	observed.delay_hash_reads = delay
	observed.armed = true


func test_final_hash_profile_replacement_refuses_without_any_quote_write() -> void:
	"""Same Catalog revision/hash cannot attest its former Profile bank after the LAST observer."""
	var observed: ObservedCatalog = _observed_catalog()
	assert_equal(_load(_wire()), &"", "initial source")
	var before: PackedByteArray = _quote_image(_quote)
	_invalidate_at_final_hash(observed, 2)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "final profile drift")
	assert_true(observed.mutation_applied, "actual Profile replacement ran last")
	assert_equal(_quote_image(_quote), before, "no stale recipe fields published")


func test_final_hash_world_reuse_refuses_without_any_quote_write() -> void:
	"""The retained Catalog digest cannot keep a retired/reused real World valid after observation."""
	var observed: ObservedCatalog = _observed_catalog()
	assert_equal(_load(_wire()), &"", "initial source")
	var before: PackedByteArray = _quote_image(_quote)
	_invalidate_at_final_hash(observed, 2, true)
	assert_equal(_reader.recipe_into(0, 1, 0, 7, _quote), Recipes.REFUSE_SOURCE, "final World drift")
	assert_true(observed.mutation_applied, "actual World slot reused last")
	assert_equal(_quote_image(_quote), before, "no stale price publication")


func test_final_source_profile_replacement_refuses_load_and_clears_bank() -> void:
	"""First load cannot expose a complete bank after its final observed source became stale."""
	var observed: ObservedCatalog = _observed_catalog()
	var wire: PackedByteArray = _wire()
	var before: PackedByteArray = _bank_image(_reader)
	_invalidate_at_final_hash(observed, 2)
	assert_equal(_load(wire), Recipes.REFUSE_SOURCE, "last load source observation invalidated")
	assert_true(observed.mutation_applied, "actual Profile replacement happened")
	assert_equal(_bank_image(_reader), before, "no stale immutable bank committed")


func test_final_source_profile_replacement_refuses_binding_attestation() -> void:
	"""A metadata comparison cannot report a bound recipe after underlying source replacement."""
	var observed: ObservedCatalog = _observed_catalog()
	assert_equal(_load(_wire()), &"", "initial source")
	_invalidate_at_final_hash(observed, 1)
	assert_false(_reader.binding_matches(_catalog, _items, _inventory, FRONTIER_HASH, 11), "last observer invalidated")
	assert_true(observed.mutation_applied, "actual Profile replacement happened")


func test_final_source_world_reuse_refuses_digest_without_caller_writes() -> void:
	"""The caller's hash buffer is preserved when the final observer invalidates actual World."""
	var observed: ObservedCatalog = _observed_catalog()
	assert_equal(_load(_wire()), &"", "initial source")
	var out: PackedByteArray = PackedByteArray()
	out.resize(32)
	out.fill(42)
	_invalidate_at_final_hash(observed, 1, true)
	assert_false(_reader.content_hash_into(7, out), "last observer invalidated actual World")
	assert_true(observed.mutation_applied, "actual World replacement happened")
	for value: int in out:
		assert_equal(value, 42, "no digest copied after stale source")
