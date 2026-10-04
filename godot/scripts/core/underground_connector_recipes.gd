extends RefCounted
## One source-pinned immutable installation bill bank, never placement or contact permission.
## Version1 prices one exact connector variant using existing construction material keys.
## No production prices are supplied by this reader. Decision1102 owns its bounded format.

const Connectors := preload("res://scripts/core/underground_connector_catalog.gd")
const SourceFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const MAX_PARTS: int = Connectors.MAX_PARTS
const MAX_INPUT_ROWS: int = MAX_PARTS * Contract.INPUT_CAPACITY
const BANK_HEADER_BYTES: int = 128
const PART_BYTES: int = 64
const FIXED_BYTES: int = 512
const WIRE_HEADER_BYTES: int = 116
const WIRE_ROW_BYTES: int = 80
const REFUSE_BINDING: StringName = &"CONNECTOR_RECIPE_BINDING"
const REFUSE_CAPACITY: StringName = &"CONNECTOR_RECIPE_CAPACITY"
const REFUSE_SOURCE: StringName = &"CONNECTOR_RECIPE_SOURCE"
const REFUSE_FORMAT: StringName = &"CONNECTOR_RECIPE_FORMAT"
const REFUSE_BILL: StringName = &"CONNECTOR_RECIPE_BILL"
const REFUSE_MISSING: StringName = &"CONNECTOR_RECIPE_UNAUTHORED"
const REFUSE_OUTPUT: StringName = &"CONNECTOR_RECIPE_OUTPUT"

var _header: PackedInt64Array = PackedInt64Array() # recipe/catalog/frontier revisions, row count.
var _digests: PackedByteArray = PackedByteArray() # recipe, catalog, frontier SHA256.
var _part_id: PackedInt32Array = PackedInt32Array()
var _input_count: PackedInt32Array = PackedInt32Array()
var _input_key: PackedInt32Array = PackedInt32Array()
var _work_mwu: PackedInt64Array = PackedInt64Array()
var _quantity: PackedInt64Array = PackedInt64Array()
var _capacity: int = 0
var _input_capacity: int = 0
var _catalog_row: int = -1
var _variant_revision: int = 0
var _configured: bool = false
var _loaded: bool = false
var _busy: bool = false
var _catalog: Connectors = null
var _items: Items = null
var _inventory: Inventory = null
## Reused fixed scratch belongs to FIXED_BYTES, not another bank or per-part object.
var _hash: PackedByteArray = PackedByteArray()
var _part: PackedInt32Array = PackedInt32Array()
var _math: IntMath.IntResult = IntMath.IntResult.new()


static func required_bytes(part_capacity: int) -> int:
	"""Return the complete logical configuration envelope; invalid budgets never silently clamp."""
	return PART_BYTES * part_capacity + BANK_HEADER_BYTES + FIXED_BYTES \
		if part_capacity > 0 and part_capacity <= MAX_PARTS else 0


func configure(part_capacity: int, arena_bytes: int) -> StringName:
	"""Admit the one immutable bank and its finite decoder/query peak before packed allocation."""
	if _configured or required_bytes(part_capacity) == 0 or arena_bytes != required_bytes(part_capacity):
		return REFUSE_CAPACITY
	_capacity = clampi(part_capacity, 0, MAX_PARTS)
	_input_capacity = clampi(_capacity * Contract.INPUT_CAPACITY, 0, MAX_INPUT_ROWS)
	_header.resize(4)
	_digests.resize(96)
	_part_id.resize(_capacity)
	_input_count.resize(_capacity)
	_input_key.resize(_input_capacity)
	_work_mwu.resize(_capacity)
	_quantity.resize(_input_capacity)
	_hash.resize(32)
	_part.resize(9)
	_clear_bank()
	_configured = true
	return &""


func bind_actual(catalog: Connectors, items: Items, inventory: Inventory) -> StringName:
	"""Pin actual immutable content and registration owners once; no foreign numeric IDs suffice."""
	if not _configured or _busy or _catalog != null or catalog == null or items == null \
			or inventory == null or not items.registered_into(inventory) or catalog.content_revision() < 1:
		return REFUSE_BINDING
	_catalog = catalog
	_items = items
	_inventory = inventory
	return &""


func _actual_binding_refusal() -> StringName:
	"""Registration rewiring is checked again on every operation, never only during configuration."""
	return &"" if _configured and _catalog != null and _items != null and _inventory != null \
		and _items.registered_into(_inventory) else REFUSE_BINDING


static func _valid_digest(value: String) -> bool:
	"""Only exact SHA256 text enters the bounded source-pin comparison."""
	return value.length() == 64 and value.is_valid_hex_number(false)


func load_file(path: String, expected_sha256: String, revision: int,
		frontier_sha256: String, frontier_revision: int) -> StringName:
	"""Stream one successful immutable load; failed attempts clear unpublished rows and may retry."""
	if _busy or _loaded or _actual_binding_refusal() != &"" or revision < 1 or frontier_revision < 1 \
			or not _valid_digest(expected_sha256) or not _valid_digest(frontier_sha256):
		return REFUSE_SOURCE
	_busy = true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_busy = false
		return REFUSE_SOURCE
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var code: StringName = _decode_header(file, digest, revision, frontier_revision, frontier_sha256)
	if code == &"":
		code = _decode_rows(file, digest)
	var actual: PackedByteArray = digest.finish()
	file.close()
	if code == &"" and actual.hex_encode() != expected_sha256.to_lower():
		code = REFUSE_SOURCE
	if code == &"":
		code = _source_refusal()
	_finish_load(code, actual)
	_busy = false
	return code


func _finish_load(code: StringName, actual: PackedByteArray) -> void:
	"""Publish the one validated bank or clear failed unpublished bytes while entry remains exclusive."""
	if code == &"":
		for index: int in 32:
			_digests[index] = actual[index]
		_loaded = true
	else:
		_clear_bank()


static func _read(file: FileAccess, digest: HashingContext, count: int) -> PackedByteArray:
	"""Hash the exact bounded bytes decoded, not a second file read or unbounded source image."""
	var bytes: PackedByteArray = file.get_buffer(count)
	digest.update(bytes)
	return bytes


func _decode_header(file: FileAccess, digest: HashingContext, revision: int,
		frontier_revision: int, frontier_sha256: String) -> StringName:
	"""All header pins and complete wire size precede the finite row loop."""
	var bytes: PackedByteArray = _read(file, digest, WIRE_HEADER_BYTES)
	if bytes.size() != WIRE_HEADER_BYTES or bytes.slice(0, 8).get_string_from_ascii() != "UGRECP01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_s64(12) != revision \
			or bytes.decode_s64(28) != frontier_revision:
		return REFUSE_FORMAT
	var count: int = bytes.decode_u32(48)
	if count < 1 or count > _capacity:
		return REFUSE_CAPACITY
	if file.get_length() != WIRE_HEADER_BYTES + count * WIRE_ROW_BYTES + 8:
		return REFUSE_FORMAT
	_header[0] = revision
	_header[1] = bytes.decode_s64(20)
	_header[2] = frontier_revision
	_header[3] = count
	_catalog_row = bytes.decode_s32(36)
	_variant_revision = bytes.decode_s64(40)
	for index: int in 64:
		_digests[32 + index] = bytes[52 + index]
	if _catalog_row < 0 or _catalog_row >= Connectors.MAX_VARIANTS or _variant_revision < 1 \
			or bytes.slice(84, 116).hex_encode() != frontier_sha256.to_lower():
		return REFUSE_SOURCE
	return _source_hash_refusal()


func _decode_rows(file: FileAccess, digest: HashingContext) -> StringName:
	"""Read one fixed bill at a time; no full file or second bank coexists with these columns."""
	for row: int in _header[3]:
		var bytes: PackedByteArray = _read(file, digest, WIRE_ROW_BYTES)
		var code: StringName = _decode_row(row, bytes)
		if code != &"":
			return code
	var end: PackedByteArray = _read(file, digest, 8)
	return &"" if end.get_string_from_ascii() == "UGREND01" else REFUSE_FORMAT


func _decode_row(row: int, bytes: PackedByteArray) -> StringName:
	"""Unique exact part ownership and a nonempty positive bill are mandatory, never inferred."""
	if bytes.size() != WIRE_ROW_BYTES:
		return REFUSE_FORMAT
	var part_id: int = bytes.decode_s32(0)
	var count: int = bytes.decode_s32(4)
	var work_mwu: int = bytes.decode_s64(8)
	if part_id < 0 or part_id >= MAX_PARTS or row > 0 and _part_id[row - 1] >= part_id \
			or count < 1 or count > Contract.INPUT_CAPACITY or work_mwu <= 0:
		return REFUSE_BILL
	if _catalog.part_into(_catalog_row, _variant_revision, _header[1], part_id, _part) != &"":
		return REFUSE_SOURCE
	_part_id[row] = part_id
	_input_count[row] = count
	_work_mwu[row] = work_mwu
	for line: int in Contract.INPUT_CAPACITY:
		var code: StringName = _decode_input(row, line, bytes)
		if code != &"":
			return code
	return _bill_refusal(row)


func _decode_input(row: int, line: int, bytes: PackedByteArray) -> StringName:
	"""Eight padded ASCII bytes name an existing construction key; never trust compiled wire IDs."""
	var offset: int = 16 + line * 16
	var length: int = 0
	while length < 8 and bytes[offset + length] != 0:
		if bytes[offset + length] < 97 or bytes[offset + length] > 122:
			return REFUSE_FORMAT
		length += 1
	for index: int in range(length, 8):
		if bytes[offset + index] != 0:
			return REFUSE_FORMAT
	var quantity: int = bytes.decode_s64(offset + 8)
	if line >= _input_count[row]:
		return &"" if length == 0 and quantity == 0 else REFUSE_BILL
	var key: StringName = StringName(bytes.slice(offset, offset + length).get_string_from_ascii())
	var key_index: int = Construction.MATERIAL_KEYS.find(key)
	if key_index < 0 or quantity <= 0:
		return REFUSE_BILL
	var at: int = row * Contract.INPUT_CAPACITY + line
	_input_key[at] = key_index
	_quantity[at] = quantity
	return &""


func _bill_refusal(row: int) -> StringName:
	"""Validate exact registration, unique keys, refund multiplication and aggregate mass overflow."""
	var total_mass: int = 0
	for line: int in _input_count[row]:
		var at: int = row * Contract.INPUT_CAPACITY + line
		var item: int = _items.compiled_id(Construction.MATERIAL_KEYS[_input_key[at]])
		if not _inventory.is_item_registered(item) \
				or not IntMath.checked_mul_into(_quantity[at], Construction.REFUND_PARTIAL_NUM, _math) \
				or not IntMath.checked_mul_into(_quantity[at], _inventory.item_mass_g(item), _math) \
				or not IntMath.ceil_div_into(_math.value, Inventory.MILLI_PER_UNIT, _math) \
				or not IntMath.checked_add_into(total_mass, _math.value, _math):
			return REFUSE_BILL
		total_mass = _math.value
		for previous: int in line:
			if _input_key[row * Contract.INPUT_CAPACITY + previous] == _input_key[at]:
				return REFUSE_BILL
	return &""


func _source_hash_refusal() -> StringName:
	"""A same-number variant in replacement catalog bytes cannot inherit an older material bill."""
	if _actual_binding_refusal() != &"" or not _catalog.content_hash_into(_header[1], _hash):
		return REFUSE_SOURCE
	for index: int in 32:
		if _hash[index] != _digests[32 + index]:
			return REFUSE_SOURCE
	if _actual_binding_refusal() != &"":
		return REFUSE_SOURCE
	return SourceFacts.refusal(_catalog, _catalog_row, _variant_revision, _header[1], _digests, 32)


func _source_refusal() -> StringName:
	"""The real catalog also proves current profile/Level/World binding and exact variant ownership."""
	var code: StringName = _source_hash_refusal()
	if code != &"" or _header[3] < 1:
		return REFUSE_SOURCE
	if _catalog.part_into(_catalog_row, _variant_revision, _header[1], _part_id[0], _part) != &"":
		return REFUSE_SOURCE
	return _source_hash_refusal()


func binding_matches(catalog: Connectors, items: Items, inventory: Inventory,
		frontier_sha256: String, frontier_revision: int) -> bool:
	"""Compare actual owners and frontier source pins; this does not attest frontier geometry."""
	if _busy or not _loaded or catalog != _catalog or items != _items or inventory != _inventory \
			or frontier_revision != _header[2] or not _valid_digest(frontier_sha256):
		return false
	_busy = true
	var result: bool = _source_refusal() == &"" \
		and _digests.slice(64, 96).hex_encode() == frontier_sha256.to_lower()
	_busy = false
	return result


func recipe_into(catalog_row: int, variant_revision: int, part_id: int,
		revision: int, out: Contract.Quote) -> StringName:
	"""Copy a source-bound bill; refusal preserves the entire quote and success grants no subject."""
	if _busy or not _loaded or revision != _header[0] or catalog_row != _catalog_row \
			or variant_revision != _variant_revision:
		return REFUSE_SOURCE
	if not _quote_shape_valid(out):
		return REFUSE_OUTPUT
	_busy = true
	var row: int = _find_part(part_id)
	var code: StringName = REFUSE_MISSING if row < 0 else _source_refusal()
	if code == &"":
		code = _bill_refusal(row)
	if code == &"":
		code = _source_hash_refusal()
	if code == &"" and not _quote_shape_valid(out):
		code = REFUSE_OUTPUT
	if code == &"":
		_write_quote(row, out)
	_busy = false
	return code


static func _quote_shape_valid(out: Contract.Quote) -> bool:
	"""A caller cannot resize one scratch field and turn a partial copy into a successful read."""
	return out != null and out.input_keys.size() == Contract.INPUT_CAPACITY \
		and out.input_milli.size() == Contract.INPUT_CAPACITY and out.output_item.size() == Contract.OUTPUT_CAPACITY \
		and out.output_milli.size() == Contract.OUTPUT_CAPACITY and out.output_quality.size() == Contract.OUTPUT_CAPACITY \
		and out.output_provenance.size() == Contract.OUTPUT_CAPACITY and out.output_recipe.size() == Contract.OUTPUT_CAPACITY \
		and out.output_age.size() == Contract.OUTPUT_CAPACITY and out.output_remainder.size() == Contract.OUTPUT_CAPACITY


func _find_part(part_id: int) -> int:
	"""A bounded sorted search returns absence; no neighboring part supplies an unauthored recipe."""
	var low: int = 0
	var high: int = _header[3]
	while low < high:
		@warning_ignore("integer_division") var middle: int = (low + high) / 2
		if _part_id[middle] < part_id:
			low = middle + 1
		else:
			high = middle
	return low if low < _header[3] and _part_id[low] == part_id else -1


func _write_quote(row: int, out: Contract.Quote) -> void:
	"""Write only after all fallible reads; the future actual owner must supply its real subject."""
	out.reset()
	out.operation = _part_id[row]
	out.total_mwu = _work_mwu[row]
	out.remaining_mwu = _work_mwu[row]
	out.job_kind = int(Catalog.JOB_KIND["BUILD"])
	out.max_workers = Construction.MAX_BUILDERS
	out.input_count = _input_count[row]
	for line: int in _input_count[row]:
		var at: int = row * Contract.INPUT_CAPACITY + line
		out.input_keys[line] = Construction.MATERIAL_KEYS[_input_key[at]]
		out.input_milli[line] = _quantity[at]


func content_revision() -> int:
	"""Expose metadata only; recipe reads still perform actual source and registration checks."""
	return _header[0] if _loaded else 0


func content_hash_into(revision: int, out: PackedByteArray) -> bool:
	"""Copy the exact immutable recipe digest without exposing the retained bank."""
	if _busy or not _loaded or revision != _header[0] or out.size() != 32:
		return false
	_busy = true
	var valid: bool = _source_refusal() == &""
	if valid:
		for index: int in 32:
			out[index] = _digests[index]
	_busy = false
	return valid


func packed_memory_bytes() -> int:
	"""Report the one64P+128 bank plus68 fixed digest/part scratch bytes, never native RAM."""
	return PART_BYTES * _capacity + BANK_HEADER_BYTES + 68 if _configured else 0


func _clear_bank() -> void:
	"""Unpublished failed source data never survives a retry or appears as a partial loaded recipe."""
	_header.fill(0)
	_digests.fill(0)
	_part_id.fill(-1)
	_input_count.fill(0)
	_input_key.fill(-1)
	_work_mwu.fill(0)
	_quantity.fill(0)
	_catalog_row = -1
	_variant_revision = 0
	_loaded = false
