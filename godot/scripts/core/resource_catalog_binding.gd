extends RefCounted
## The checked boundary between world generation's resource outputs and the compiled item catalog.
##
## WHAT THIS SETTLES. `docs/rulings/2026-09-11_ready07_open_item_answers.md` §2 rules that
## `ResourceNode.resource_id` identifies the EXTRACTED OUTPUT'S compiled `ItemDefinition` id, and
## that `ForagePatch.item_id` and each fish stock's item-id field use the SAME domain. Three store
## headers previously recorded that domain as "unstated" and left the ids to the caller; they now
## cite this module. `world_init.gd`'s `Request` therefore carries seventeen bindings -- three
## scalars plus arrays of five and nine -- and this module is the only thing allowed to produce
## them.
##
## | Request field         | ItemDefinition keys, in required consumer order              |
## |-----------------------|--------------------------------------------------------------|
## | tree_resource_id      | wood                                                         |
## | stone_resource_id     | stone                                                        |
## | iron_resource_id      | iron                                                         |
## | forage_item_ids       | berries, nuts, mushrooms, herb, roots                        |
## | fish_species_item_ids | trout, dace, salmon, perch, carp, whitefish, herring,        |
## |                       | mackerel, mussel                                             |
##
## ORDER IS THE CONTRACT, NOT THE IDS. The five forage keys are `forage.gd`'s own `PATCH_KEYS` and
## the nine fish keys are `fishing.gd`'s own `SPECIES_KEYS`, read from those modules and never
## retyped here. The ruling is explicit that "sorting those arrays by compiled IDs would associate
## the wrong quotas, yields and habitats": `PATCH_CAPACITY_U[kind]`, `SPECIES_CAPACITY_U[species]`
## and `SPECIES_HABITAT_TYPE[species]` are all subscripted by ROW, and a compiled item id is a
## different index entirely -- never use one to subscript a nine-row fish table. Because the key
## arrays are borrowed from their owning stores, the produced arrays are in row order BY
## CONSTRUCTION -- there is no second list here to fall out of step -- and `verify_ids()` proves an
## externally built request agrees position by position.
##
## NO NUMERIC CATALOG ID APPEARS ANYWHERE IN THIS FILE. Keys resolve at runtime. The planner's
## handoff printed the ids it observed (wood 59, stone 52, iron 19, ...) as DIAGNOSTICS; compiling
## one of them in would recreate the mirrored-constant defect this boundary exists to remove.
##
## THERE IS NO GENERIC `tree`, `forage` OR `fish` ITEM. §5.9's extraction recipes yield `wood`,
## `stone` and `iron`; `fish` appears in recipes as a SELECTOR over the approved nine species keys
## and is not a runtime stock item. None of those three words is a key in `item_definitions.json`,
## and inventing one would be inventing a contract.
##
## HOW A BINDING IS PROVEN, IN ORDER:
##   1. The item registry must be LOADED. An unloaded `item_definitions.gd` answers every key with
##      §4.2's empty catalog id, which is absence, not an id.
##   2. The COMMITTED ARTIFACT must be canonical, must carry the `ItemDefinition` domain, and must
##      VERIFY. The bytes are read ONCE and `catalog_ids.gd` recompiles every registered domain and
##      compares them exactly (decision 0034). A stale artifact -- an edited byte, a moved id, a
##      changed key set -- refuses here, before a single id is read. GDD §4.2: "loading verifies
##      its hash".
##   3. Each key resolves through the registry that OWNS it, and the artifact's own
##      `ItemDefinition` table must agree with that registry id for id. Step 2 proves the artifact
##      matches a catalog compiled from `DEFAULT_JSON_PATH`; step 3 additionally proves the
##      registry instance handed in was loaded from that same catalog and not a substitute.
##   4. SET-AMEND-001 §3's retired keys refuse with their own code before the generic unknown-key
##      one, so "hunting was retired" is never reported as "typo".
##
## WHY NOT `Catalog.compiled_id_of("ItemDefinition", key)`. The ruling names that call, but it
## cannot serve: `catalog.gd`'s `compiled_enum()` owns four domains (CommandKind, CropFamily,
## EventDefinition, HabitatType) and answers `'ItemDefinition' is not a compiled enum domain` --
## run against 4.7.2, not assumed. `ItemDefinition` keys live in `res://data/item_definitions.json`,
## and `catalog_ids.gd`'s header records why `catalog.gd` must NOT reach them: `item_definitions.gd`
## preloads `catalog.gd`, so the reverse edge is a preload cycle. `compiled_item_id_of()` below is
## that call's ItemDefinition-domain equivalent -- same `ok`/`key`/`id`/`error` shape, resolved
## through the owning registry and cross-checked against the artifact. Decision 0052 records it.
##
## REFUSAL IS THE ONLY FAILURE CHANNEL. Nothing here returns a fallback id, a substituted item or a
## sentinel that looks like an answer, and nothing here writes to any store. Allocate before
## consume is what makes a refused binding cost nothing: `world_init.gd` validates the request
## inside `_prepare()`, before a row is cleared or written, so a refused binding leaves every
## collaborating store byte-identical. (Decision 0052 records that the "decision 0024" citation
## twenty-five comments use for that rule points at an unrelated record.)
##
## GAP -- NAMED, NOT INVENTED. There is no save module in this repository, so the round trip
## "generate a world, save it, reload it, prove the bound ids survive" cannot be exercised.
## `catalog_ids.gd` already produces the header digest and section payload a save writer needs;
## when that module lands, its load path verifies the same artifact this boundary verifies and an
## id bound here is re-checked against it. Until then that round trip is BLOCKED, not passing.

const CatalogScript := preload("res://scripts/core/catalog.gd")
const CatalogIds := preload("res://scripts/core/catalog_ids.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")

## The domain all seventeen keys resolve in. `catalog.gd` declares the name; it is not spelled here.
const ITEM_DEFINITION_DOMAIN: String = CatalogScript.ITEM_DEFINITION_DOMAIN
## The committed artifact whose hash this boundary verifies. `catalog_ids.gd` owns the path.
const DEFAULT_ARTIFACT_PATH: String = CatalogIds.ARTIFACT_PATH
## GDD §4.2's "empty catalog IDs are -1": absence, read from catalog.gd rather than mirrored.
const ABSENT_ITEM_ID: int = CatalogScript.EMPTY_CATALOG_ID

## §5.9's extraction outputs, in the order `world_init.Request` declares its three scalar fields.
const TREE_ITEM_KEY: StringName = &"wood"
const STONE_ITEM_KEY: StringName = &"stone"
const IRON_ITEM_KEY: StringName = &"iron"

## The size of each group, taken from the stores that own the rows. A store that gained or lost a
## row without this boundary being revisited fails `_init()` rather than binding the wrong count.
const SCALAR_BINDING_COUNT: int = 3
const FORAGE_BINDING_COUNT: int = ForageScript.PATCHES_PER_ZONE
const FISH_BINDING_COUNT: int = FishingScript.SPECIES_COUNT
## The ruling's own total: "three scalars plus arrays of five and nine -- 17 bindings".
const BINDING_COUNT: int = SCALAR_BINDING_COUNT + FORAGE_BINDING_COUNT + FISH_BINDING_COUNT

# --- refusal codes (StringName; never a clamped id and never a sentinel) -------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_NO_REGISTRY: StringName = &"ITEM_BINDING_NO_REGISTRY"
const REFUSE_REGISTRY_NOT_LOADED: StringName = &"ITEM_BINDING_REGISTRY_NOT_LOADED"
const REFUSE_ARTIFACT: StringName = &"ITEM_BINDING_CATALOG_ARTIFACT"
const REFUSE_ARTIFACT_DOMAIN: StringName = &"ITEM_BINDING_CATALOG_DOMAIN_MISSING"
const REFUSE_NOT_OPEN: StringName = &"ITEM_BINDING_NOT_OPEN"
const REFUSE_RETIRED_KEY: StringName = &"ITEM_BINDING_RETIRED_KEY"
const REFUSE_UNKNOWN_KEY: StringName = &"ITEM_BINDING_UNKNOWN_KEY"
const REFUSE_ARTIFACT_DISAGREES: StringName = &"ITEM_BINDING_ARTIFACT_DISAGREES"
const REFUSE_SET_SIZE: StringName = &"ITEM_BINDING_SET_SIZE"
const REFUSE_ID_NOT_BOUND: StringName = &"ITEM_BINDING_ID_NOT_BOUND"


class KeyLookup:
	"""One key's resolution, in the `ok`/`key`/`id`/`error` shape `Catalog.EnumLookup` uses.

	`.ok` MUST be inspected first. A refusal carries `code` and no usable id: `id` stays at
	`ABSENT_ITEM_ID`, which is §4.2's absence marker, never an `ItemDefinition` id, and never
	written to a store.
	"""
	var ok: bool
	var key: StringName
	var id: int
	var code: StringName
	var error: String

	func _init(p_ok: bool, p_key: StringName, p_id: int, p_code: StringName,
			p_error: String) -> void:
		"""Store the outcome fields for one key lookup."""
		ok = p_ok
		key = p_key
		id = p_id
		code = p_code
		error = p_error


class Binding:
	"""The seventeen resolved ids, in the exact order `world_init.Request`'s consumers read them.

	The arrays are in `Forage.PATCH_KEYS` and `Fishing.SPECIES_KEYS` row order, never sorted. Only
	a fully successful `resolve()` produces one; there is no half-filled `Binding`.
	"""
	var tree_resource_id: int
	var stone_resource_id: int
	var iron_resource_id: int
	var forage_item_ids: PackedInt32Array
	var fish_species_item_ids: PackedInt32Array

	func _init(p_tree: int, p_stone: int, p_iron: int, p_forage: PackedInt32Array,
			p_fish: PackedInt32Array) -> void:
		"""Store the three scalar ids and copy both arrays so no caller can alias them."""
		tree_resource_id = p_tree
		stone_resource_id = p_stone
		iron_resource_id = p_iron
		forage_item_ids = p_forage.duplicate()
		fish_species_item_ids = p_fish.duplicate()


class BindResult:
	"""Outcome of one binding attempt. `.ok` MUST be inspected first; a refusal has `binding` null.

	There is deliberately no partially bound result and no placeholder id to mistake for one.
	"""
	var ok: bool
	var error: StringName
	var detail: String
	var binding: Binding

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_binding: Binding) -> void:
		"""Store the outcome fields for one binding attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		binding = p_binding


class OpenResult:
	"""Outcome of opening a boundary: the verified boundary, or the refusal that stopped it.

	`boundary` is declared `RefCounted` because a script without `class_name` cannot name itself in
	an annotation; callers hold it through their own `preload` const and downcast.
	"""
	var ok: bool
	var error: StringName
	var detail: String
	var boundary: RefCounted

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_boundary: RefCounted) -> void:
		"""Store the outcome fields for one open attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		boundary = p_boundary


# --- state: a verified artifact table and the registry it was checked against --------------------

var _items: ItemDefinitionsScript = null
var _artifact_ids: Dictionary = {}
var _artifact_path: String = ""
var _opened: bool = false


func _init() -> void:
	"""Prove the seventeen bindings are still seventeen before any of them can be resolved."""
	assert(ForageScript.PATCH_KEYS.size() == FORAGE_BINDING_COUNT,
		"forage.gd's PATCH_KEYS must still hold one key per patch row")
	assert(FishingScript.SPECIES_KEYS.size() == FISH_BINDING_COUNT,
		"fishing.gd's SPECIES_KEYS must still hold one key per species row")
	assert(BINDING_COUNT == 17, "ruling §2: three scalars plus arrays of five and nine")


# --- the required keys, borrowed from the modules that own the rows ------------------------------

static func scalar_keys() -> Array[StringName]:
	"""The three extraction-output keys, in `Request`'s tree/stone/iron field order."""
	return [TREE_ITEM_KEY, STONE_ITEM_KEY, IRON_ITEM_KEY] as Array[StringName]


static func forage_keys() -> Array[StringName]:
	"""`Forage.PATCH_KEYS` in patch-row order: berries, nuts, mushrooms, herb, roots."""
	return ForageScript.PATCH_KEYS.duplicate()


static func fish_keys() -> Array[StringName]:
	"""`Fishing.SPECIES_KEYS` in species-row order, which is NOT ascending compiled-id order."""
	return FishingScript.SPECIES_KEYS.duplicate()


static func expected_keys() -> Array[StringName]:
	"""All seventeen required keys: scalars, then patch rows, then species rows."""
	var keys: Array[StringName] = scalar_keys()
	keys.append_array(ForageScript.PATCH_KEYS)
	keys.append_array(FishingScript.SPECIES_KEYS)
	return keys


# --- opening the boundary ------------------------------------------------------------------------

static func open(items: ItemDefinitionsScript,
		artifact_path: String = DEFAULT_ARTIFACT_PATH) -> OpenResult:
	"""Verify the committed catalog artifact and return a boundary bound to `items`, or refuse.

	Cold path, called once per world construction: it reads and recompiles the whole catalog. This
	verification is the ruling's "verify the already adopted catalog artifact/hash" -- a stale or
	edited artifact refuses here, before a key is resolved and before any store is touched.
	"""
	if items == null:
		return OpenResult.new(false, REFUSE_NO_REGISTRY, "no item registry was supplied", null)
	if not items.is_loaded():
		return OpenResult.new(false, REFUSE_REGISTRY_NOT_LOADED,
			"the item registry has not loaded a catalog", null)
	var bytes: PackedByteArray = PackedByteArray()
	var readable: OpenResult = _read_artifact(artifact_path, bytes)
	if readable != null:
		return readable
	var parsed: CatalogIds.ParseResult = CatalogIds.parse_canonical(bytes)
	var shaped: OpenResult = _refuse_artifact_shape(artifact_path, parsed)
	if shaped != null:
		return shaped
	var verified: CatalogIds.VerifyResult = CatalogIds.verify_bytes(bytes)
	if not verified.ok:
		return OpenResult.new(false, REFUSE_ARTIFACT,
			"%s: %s (%s)" % [artifact_path, verified.error, verified.detail], null)
	var boundary := new()
	boundary._items = items
	boundary._artifact_ids = parsed.domains[ITEM_DEFINITION_DOMAIN]
	boundary._artifact_path = artifact_path
	boundary._opened = true
	return OpenResult.new(true, REFUSE_NONE, "", boundary)


static func _read_artifact(path: String, out: PackedByteArray) -> OpenResult:
	"""Fill `out` with the artifact's bytes ONCE, or return the refusal that stopped it.

	One read, one parse, one comparison. Reading the file twice -- once to verify and once to
	extract -- would leave a window in which the second read could differ from the verified one.
	"""
	if not FileAccess.file_exists(path):
		return OpenResult.new(false, REFUSE_ARTIFACT, "artifact not found: %s" % path, null)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return OpenResult.new(false, REFUSE_ARTIFACT, "could not open %s" % path, null)
	out.append_array(file.get_buffer(file.get_length()))
	file.close()
	return null


static func _refuse_artifact_shape(path: String, parsed: CatalogIds.ParseResult) -> OpenResult:
	"""Refuse an artifact that is not canonical, or that carries no ItemDefinition domain.

	Both checks run BEFORE `verify_bytes()`, which is what keeps them reachable: an artifact whose
	domains object omits `ItemDefinition` entirely is still canonical JSON and still parses, and
	must be named as a missing domain rather than as a generic catalog mismatch.
	"""
	if not parsed.ok:
		return OpenResult.new(false, REFUSE_ARTIFACT,
			"%s: %s (%s)" % [path, parsed.error, parsed.detail], null)
	if not parsed.domains.has(ITEM_DEFINITION_DOMAIN):
		return OpenResult.new(false, REFUSE_ARTIFACT_DOMAIN,
			"%s carries no '%s' domain" % [path, ITEM_DEFINITION_DOMAIN], null)
	return null


func is_open() -> bool:
	"""True once `open()` has verified an artifact and a loaded registry for this boundary."""
	return _opened


func artifact_path() -> String:
	"""The artifact path this boundary verified, for a caller that must report its provenance."""
	return _artifact_path


# --- resolving one key ---------------------------------------------------------------------------

func compiled_item_id_of(key: StringName) -> KeyLookup:
	"""The compiled `ItemDefinition` id one key carries, or the exact refusal that stopped it.

	The ItemDefinition-domain equivalent of `Catalog.compiled_id_of()`, which owns four enum
	domains and not this one (see the header). A retired key refuses with its own code before the
	generic unknown-key one, and the verified artifact must agree with the registry id for id.
	"""
	if not _opened:
		return KeyLookup.new(false, key, ABSENT_ITEM_ID, REFUSE_NOT_OPEN,
			"this boundary did not come from a successful open()")
	if ItemDefinitionsScript.RETIRED_KEYS.has(key):
		return KeyLookup.new(false, key, ABSENT_ITEM_ID, REFUSE_RETIRED_KEY,
			"SET-AMEND-001 §3 retired '%s'; it is never substituted" % key)
	var registry_id: int = _items.compiled_id(key)
	if registry_id == ABSENT_ITEM_ID:
		return KeyLookup.new(false, key, ABSENT_ITEM_ID, REFUSE_UNKNOWN_KEY,
			"'%s' has no key '%s'" % [ITEM_DEFINITION_DOMAIN, key])
	return _agreed_lookup(key, registry_id)


func _agreed_lookup(key: StringName, registry_id: int) -> KeyLookup:
	"""Accept a registry id only when the verified artifact records the same id for the same key."""
	var name: String = String(key)
	if not _artifact_ids.has(name):
		return KeyLookup.new(false, key, ABSENT_ITEM_ID, REFUSE_ARTIFACT_DISAGREES,
			"the verified artifact has no '%s' key '%s'" % [ITEM_DEFINITION_DOMAIN, name])
	var artifact_id: int = int(_artifact_ids[name])
	if artifact_id != registry_id:
		return KeyLookup.new(false, key, ABSENT_ITEM_ID, REFUSE_ARTIFACT_DISAGREES,
			"'%s' is %d in the registry and %d in the artifact" % [name, registry_id, artifact_id])
	return KeyLookup.new(true, key, registry_id, REFUSE_NONE, "")


# --- resolving all seventeen ---------------------------------------------------------------------

func resolve() -> BindResult:
	"""Resolve all seventeen bindings by key, in consumer order, or refuse without producing any.

	The arrays come out in `PATCH_KEYS` and `SPECIES_KEYS` row order because they are filled by
	walking those arrays: nothing here sorts, and a compiled id never becomes a row index.
	"""
	var scalars: PackedInt32Array = PackedInt32Array()
	var failure: BindResult = _resolve_into(scalar_keys(), scalars)
	if failure != null:
		return failure
	var forage: PackedInt32Array = PackedInt32Array()
	failure = _resolve_into(ForageScript.PATCH_KEYS, forage)
	if failure != null:
		return failure
	var fish: PackedInt32Array = PackedInt32Array()
	failure = _resolve_into(FishingScript.SPECIES_KEYS, fish)
	if failure != null:
		return failure
	return BindResult.new(true, REFUSE_NONE, "",
		Binding.new(scalars[0], scalars[1], scalars[2], forage, fish))


func _resolve_into(keys: Array[StringName], out: PackedInt32Array) -> BindResult:
	"""Append one key group's ids to `out` in the given order; return the refusal, or null."""
	for key: StringName in keys:
		var lookup: KeyLookup = compiled_item_id_of(key)
		if not lookup.ok:
			return BindResult.new(false, lookup.code, lookup.error, null)
		out.append(lookup.id)
	return null


# --- proving a request someone else built --------------------------------------------------------

func verify_ids(tree_id: int, stone_id: int, iron_id: int, forage_ids: PackedInt32Array,
		fish_ids: PackedInt32Array) -> BindResult:
	"""Prove five already-built request fields are EXACTLY the seventeen bindings, in order.

	This is what makes "an arbitrary valid-looking integer" insufficient: every position is
	compared against the id its own key resolves to, so a swapped tree/stone pair, an array sorted
	by compiled id, two arrays exchanged, a foreign catalog's id and a wrong-length set each refuse.
	"""
	var bound: BindResult = resolve()
	if not bound.ok:
		return bound
	if forage_ids.size() != FORAGE_BINDING_COUNT or fish_ids.size() != FISH_BINDING_COUNT:
		return BindResult.new(false, REFUSE_SET_SIZE, _size_detail(forage_ids, fish_ids), null)
	var mismatch: BindResult = _refuse_scalars(tree_id, stone_id, iron_id, bound.binding)
	if mismatch != null:
		return mismatch
	mismatch = _refuse_mismatch(ForageScript.PATCH_KEYS, forage_ids,
		bound.binding.forage_item_ids)
	if mismatch != null:
		return mismatch
	mismatch = _refuse_mismatch(FishingScript.SPECIES_KEYS, fish_ids,
		bound.binding.fish_species_item_ids)
	if mismatch != null:
		return mismatch
	return bound


func _refuse_scalars(tree_id: int, stone_id: int, iron_id: int, expected: Binding) -> BindResult:
	"""Compare the three scalar fields against wood/stone/iron, naming the first that is wrong."""
	var actual: PackedInt32Array = PackedInt32Array([tree_id, stone_id, iron_id])
	var wanted: PackedInt32Array = PackedInt32Array([expected.tree_resource_id,
		expected.stone_resource_id, expected.iron_resource_id])
	return _refuse_mismatch(scalar_keys(), actual, wanted)


func _size_detail(forage_ids: PackedInt32Array, fish_ids: PackedInt32Array) -> String:
	"""Name both actual lengths, so a caller sees which set is wrong without guessing."""
	return "forage %d/%d and fish %d/%d item ids" % [forage_ids.size(), FORAGE_BINDING_COUNT,
		fish_ids.size(), FISH_BINDING_COUNT]


func _refuse_mismatch(keys: Array[StringName], actual: PackedInt32Array,
		expected: PackedInt32Array) -> BindResult:
	"""Return the refusal naming the first position whose id is not its key's id, or null."""
	for index: int in keys.size():
		if actual[index] == expected[index]:
			continue
		var detail: String = "position %d must be '%s' (%d), not %d"
		return BindResult.new(false, REFUSE_ID_NOT_BOUND,
			detail % [index, keys[index], expected[index], actual[index]], null)
	return null
