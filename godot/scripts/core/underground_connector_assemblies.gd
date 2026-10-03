extends RefCounted
## Immutable billable part partition, not a physical construction frontier (decision1104).
## One group selects one real Recipe anchor; it never creates contact, support, payment or presence.

const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const SourceFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const MAX_GROUPS: int = Catalog.MAX_PARTS
const LANDING: int = 0
const TREAD: int = 1
const KIND_COUNT: int = 2
const GROUP_BYTES: int = 16
const BANK_HEADER_BYTES: int = 152
const FIXED_BYTES: int = 512
const WIRE_HEADER_BYTES: int = 88
const WIRE_ROW_BYTES: int = 16
const REFUSE_BINDING: StringName = &"CONNECTOR_ASSEMBLY_BINDING"
const REFUSE_CAPACITY: StringName = &"CONNECTOR_ASSEMBLY_CAPACITY"
const REFUSE_SOURCE: StringName = &"CONNECTOR_ASSEMBLY_SOURCE"
const REFUSE_FORMAT: StringName = &"CONNECTOR_ASSEMBLY_FORMAT"
const REFUSE_PARTITION: StringName = &"CONNECTOR_ASSEMBLY_PARTITION"
const REFUSE_RECIPE: StringName = &"CONNECTOR_ASSEMBLY_RECIPE_PARTITION"
const REFUSE_OUTPUT: StringName = &"CONNECTOR_ASSEMBLY_OUTPUT"

class AssemblyRecord extends RefCounted:

	## One caller-owned 32-byte numeric packet; ordinal is the immutable query argument.
	var kind: int = -1
	var first_part: int = -1
	var part_count: int = 0
	var recipe_anchor: int = -1

var _header: PackedInt64Array = PackedInt64Array() # group/catalog/recipe rev, row/variant, group/part count.
var _digests: PackedByteArray = PackedByteArray() # grouping, Catalog, actual Recipe SHA256.
var _kind: PackedInt32Array = PackedInt32Array()
var _first_part: PackedInt32Array = PackedInt32Array()
var _part_count: PackedInt32Array = PackedInt32Array()
var _recipe_anchor: PackedInt32Array = PackedInt32Array()
var _hash: PackedByteArray = PackedByteArray()
var _part: PackedInt32Array = PackedInt32Array()
var _capacity: int = 0
var _configured: bool = false
var _loaded: bool = false
var _busy: bool = false
var _catalog: Catalog = null
var _recipes: Recipes = null
var _items: Items = null
var _inventory: Inventory = null


static func required_bytes(group_capacity: int) -> int:
	"""Admit the complete single bank and fixed reader peak before any packed allocation."""
	return GROUP_BYTES * group_capacity + BANK_HEADER_BYTES + FIXED_BYTES \
		if group_capacity > 0 and group_capacity <= MAX_GROUPS else 0


func configure(group_capacity: int, arena_bytes: int) -> StringName:
	"""A caller supplies a finite engineering allocation, never a silently truncated part policy."""
	if _configured or group_capacity < 1 or group_capacity > MAX_GROUPS \
			or arena_bytes != required_bytes(group_capacity):
		return REFUSE_CAPACITY
	_capacity = clampi(group_capacity, 0, MAX_GROUPS)
	_header.resize(7)
	_digests.resize(96)
	_kind.resize(_capacity)
	_first_part.resize(_capacity)
	_part_count.resize(_capacity)
	_recipe_anchor.resize(_capacity)
	_hash.resize(32)
	_part.resize(9)
	_clear_bank()
	_configured = true
	return &""


func bind_actual(catalog: Catalog, recipes: Recipes, items: Items, inventory: Inventory) -> StringName:
	"""Bind exact source/registration objects once, including the actual Recipe owner composition."""
	if not _configured or _busy or _catalog != null or catalog == null or recipes == null \
			or items == null or inventory == null or recipes._catalog != catalog \
			or recipes._items != items or recipes._inventory != inventory \
			or not items._loaded or items._registered_inventory == null \
			or items._registered_inventory.get_ref() != inventory:
		return REFUSE_BINDING
	_catalog = catalog
	_recipes = recipes
	_items = items
	_inventory = inventory
	return &""


static func _valid_digest(value: String) -> bool:
	"""Only a complete SHA256 text value can pin an external immutable source."""
	return value.length() == 64 and value.is_valid_hex_number(false)


func load_file(path: String, expected_sha256: String, revision: int,
		recipe_sha256: String, recipe_revision: int) -> StringName:
	"""Stream the acyclic grouping source, then bind the Recipe which already pins this exact digest."""
	if _busy or _loaded or not _owners_match() or revision < 1 or recipe_revision < 1 \
			or not _valid_digest(expected_sha256) or not _valid_digest(recipe_sha256):
		return REFUSE_SOURCE
	_busy = true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_busy = false
		return REFUSE_SOURCE
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var code: StringName = _decode_header(file, digest, revision, recipe_revision)
	if code == &"":
		code = _decode_rows(file, digest)
	var actual: PackedByteArray = digest.finish()
	file.close()
	if code == &"":
		code = _finish_source(actual, expected_sha256, recipe_sha256)
	if code != &"":
		_clear_bank()
	else:
		_loaded = true
	_busy = false
	return code


static func _read(file: FileAccess, digest: HashingContext, count: int) -> PackedByteArray:
	"""Hash the bounded bytes actually decoded; no full source image or second hashing read exists."""
	var bytes: PackedByteArray = file.get_buffer(count)
	if not bytes.is_empty():
		digest.update(bytes)
	return bytes


func _decode_header(file: FileAccess, digest: HashingContext, revision: int,
		recipe_revision: int) -> StringName:
	"""Validate complete wire length and finite table dimensions before reading any group row."""
	var bytes: PackedByteArray = _read(file, digest, WIRE_HEADER_BYTES)
	if bytes.size() != WIRE_HEADER_BYTES or bytes.slice(0, 8).get_string_from_ascii() != "UGASMB01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_s64(12) != revision \
			or bytes.decode_s64(28) != recipe_revision:
		return REFUSE_FORMAT
	var count: int = bytes.decode_u32(48)
	if count < 1 or count > _capacity:
		return REFUSE_CAPACITY
	if file.get_length() != WIRE_HEADER_BYTES + count * WIRE_ROW_BYTES + 8:
		return REFUSE_FORMAT
	_header[0] = revision
	_header[1] = bytes.decode_s64(20)
	_header[2] = recipe_revision
	_header[3] = bytes.decode_s32(36)
	_header[4] = bytes.decode_s64(40)
	_header[5] = count
	_header[6] = bytes.decode_u32(52)
	for index: int in 32:
		_digests[32 + index] = bytes[56 + index]
	if _header[6] < count or _header[6] > Catalog.MAX_PARTS:
		return REFUSE_PARTITION
	return _catalog_refusal()


func _decode_rows(file: FileAccess, digest: HashingContext) -> StringName:
	"""Ordered contiguous ranges make full ownership and unique recipe anchors a bounded proof."""
	for row: int in _header[5]:
		var code: StringName = _decode_row(row, _read(file, digest, WIRE_ROW_BYTES))
		if code != &"":
			return code
	var last: int = _header[5] - 1
	if _first_part[last] + _part_count[last] != _header[6]:
		return REFUSE_PARTITION
	return &"" if _read(file, digest, 8).get_string_from_ascii() == "UGAEND01" else REFUSE_FORMAT


func _decode_row(row: int, bytes: PackedByteArray) -> StringName:
	"""Each nonempty group owns actual variant-relative parts and exactly one contained bill anchor."""
	if bytes.size() != WIRE_ROW_BYTES:
		return REFUSE_FORMAT
	var kind: int = bytes.decode_s32(0)
	var first: int = bytes.decode_s32(4)
	var count: int = bytes.decode_s32(8)
	var anchor: int = bytes.decode_s32(12)
	var expected: int = 0 if row == 0 else _first_part[row - 1] + _part_count[row - 1]
	if kind < 0 or kind >= KIND_COUNT or first != expected or count < 1 \
			or count > _header[6] - first or anchor < first or anchor >= first + count:
		return REFUSE_PARTITION
	if _catalog.part_into(_header[3], _header[4], _header[1], anchor, _part) != &"":
		return REFUSE_SOURCE
	_kind[row] = kind
	_first_part[row] = first
	_part_count[row] = count
	_recipe_anchor[row] = anchor
	return &""


func _finish_source(actual: PackedByteArray, expected_sha256: String, recipe_sha256: String) -> StringName:
	"""The external Recipe pin avoids a source-file hash cycle while closing both immutable directions."""
	if actual.hex_encode() != expected_sha256.to_lower():
		return REFUSE_SOURCE
	var recipe_digest: PackedByteArray = recipe_sha256.hex_decode()
	for index: int in 32:
		_digests[index] = actual[index]
		_digests[64 + index] = recipe_digest[index]
	return _source_refusal()


func _catalog_refusal() -> StringName:
	"""Actual Catalog callbacks precede the final non-observing variant/World/source attestation."""
	if not _owners_match() or not _catalog.content_hash_into(_header[1], _hash) or _hash.size() != 32:
		return REFUSE_SOURCE
	for index: int in 32:
		if _hash[index] != _digests[32 + index]:
			return REFUSE_SOURCE
	return _catalog_leaf_refusal()


func _catalog_leaf_refusal() -> StringName:
	"""Use the actual exact variant part census; a caller cannot claim a shorter or longer Catalog."""
	if SourceFacts.refusal(_catalog, _header[3], _header[4], _header[1], _digests, 32) != &"" \
			or _catalog._live.variants.size() != Catalog.VARIANT_FIELDS * Catalog.MAX_VARIANTS:
		return REFUSE_SOURCE
	var at: int = Catalog.V_PART_COUNT * Catalog.MAX_VARIANTS + _header[3]
	return &"" if _catalog._live.variants[at] == _header[6] else REFUSE_PARTITION


func _source_refusal() -> StringName:
	"""Observe actual immutable sources first; the final leaf never calls another source provider."""
	if not _owners_match() or not _recipes.content_hash_into(_header[2], _hash) or _hash.size() != 32:
		return REFUSE_SOURCE
	for index: int in 32:
		if _hash[index] != _digests[64 + index]:
			return REFUSE_SOURCE
	if not _recipes.binding_matches(_catalog, _items, _inventory, _digests.slice(0, 32).hex_encode(), _header[0]):
		return REFUSE_SOURCE
	return _source_leaf_refusal()


func _owners_match() -> bool:
	"""Read current concrete registration/wiring without an overridable observer after the final callback."""
	return _configured and _catalog != null and _recipes != null and _items != null and _inventory != null \
		and _recipes._catalog == _catalog and _recipes._items == _items and _recipes._inventory == _inventory \
		and _items._loaded and _items._registered_inventory != null \
		and _items._registered_inventory.get_ref() == _inventory


func _source_leaf_refusal() -> StringName:
	"""Require exact current Recipes, Catalog and world facts after every possible observation callback."""
	if not _owners_match() or not _recipes._loaded or _recipes._busy or _recipes._header.size() != 4 \
			or _recipes._digests.size() != 96 or _recipes._part_id.size() != _recipes._capacity \
			or _recipes._capacity < _header[5] or _recipes._capacity > Recipes.MAX_PARTS:
		return REFUSE_SOURCE
	if _recipes._header[0] != _header[2] or _recipes._header[1] != _header[1] \
			or _recipes._header[2] != _header[0] or _recipes._catalog_row != _header[3] \
			or _recipes._variant_revision != _header[4]:
		return REFUSE_SOURCE
	if _recipes._header[3] != _header[5]:
		return REFUSE_RECIPE
	for index: int in 32:
		if _recipes._digests[index] != _digests[64 + index] \
				or _recipes._digests[32 + index] != _digests[32 + index] \
				or _recipes._digests[64 + index] != _digests[index]:
			return REFUSE_SOURCE
	for row: int in _header[5]:
		if _recipes._part_id[row] != _recipe_anchor[row]:
			return REFUSE_RECIPE
	return _catalog_leaf_refusal()


func assembly_into(catalog_row: int, variant_revision: int, revision: int, ordinal: int,
		out: AssemblyRecord) -> StringName:
	"""Read grouping metadata only; failure preserves all caller fields and creates no installation permission."""
	if _busy or not _loaded or catalog_row != _header[3] or variant_revision != _header[4] or revision != _header[0]:
		return REFUSE_SOURCE
	if out == null or ordinal < 0 or ordinal >= _header[5]:
		return REFUSE_OUTPUT
	_busy = true
	var code: StringName = _source_refusal()
	if code == &"":
		out.kind = _kind[ordinal]
		out.first_part = _first_part[ordinal]
		out.part_count = _part_count[ordinal]
		out.recipe_anchor = _recipe_anchor[ordinal]
	_busy = false
	return code


func binding_matches(catalog: Catalog, recipes: Recipes, items: Items, inventory: Inventory,
		expected_sha256: String, revision: int) -> bool:
	"""Bind the exact group source and actual owner namespace, not a copied hash or numeric row alone."""
	if _busy or not _loaded or catalog != _catalog or recipes != _recipes or items != _items \
			or inventory != _inventory or revision != _header[0] or not _valid_digest(expected_sha256):
		return false
	_busy = true
	var valid: bool = _digests.slice(0, 32).hex_encode() == expected_sha256.to_lower() and _source_refusal() == &""
	_busy = false
	return valid


func content_revision() -> int:
	"""This revision is metadata only; source-bound reads still validate the actual composition."""
	return _header[0] if _loaded else 0


func assembly_count(expected_grouping_revision: int) -> int:
	"""Return a current positive census without callbacks; zero is refusal, never a completed prefix."""
	if _busy or not _loaded or expected_grouping_revision != _header[0] or _source_leaf_refusal() != &"":
		return 0
	return _header[5]


func content_hash_into(revision: int, out: PackedByteArray) -> bool:
	"""Copy only after fresh sources and final output shape; refusal leaves prior bytes unchanged."""
	if _busy or not _loaded or revision != _header[0] or out.size() != 32:
		return false
	_busy = true
	var valid: bool = _source_refusal() == &"" and out.size() == 32
	if valid:
		for index: int in 32:
			out[index] = _digests[index]
	_busy = false
	return valid


func packed_memory_bytes() -> int:
	"""Return actual allocated packed payload, separately from fixed frames and native owner overhead."""
	return GROUP_BYTES * _capacity + BANK_HEADER_BYTES + 68 if _configured else 0


func _clear_bank() -> void:
	"""Failed first loads publish no partial grouping, source pin or row; allocated capacity is retained."""
	_header.fill(0)
	_digests.fill(0)
	_kind.fill(-1)
	_first_part.fill(-1)
	_part_count.fill(0)
	_recipe_anchor.fill(-1)
	_loaded = false
