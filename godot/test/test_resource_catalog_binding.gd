extends "res://test/framework/test_case.gd"
## READY_07 §2: world generation's resource outputs bound to compiled `ItemDefinition` keys.
##
## NO EXPECTED CATALOG NUMBER APPEARS IN THIS FILE. The planner's handoff printed the ids it
## observed (wood 59, stone 52, iron 19, ...) as DIAGNOSTICS ONLY. Asserting them here would pin
## the suite to one revision of `item_definitions.json` and would prove nothing about the binding:
## what is asserted instead is that each required KEY resolves, and that the id it resolves to is
## the id the catalog itself reports for that key through two independent readers -- the loaded
## `item_definitions.gd` registry and the committed `catalog_ids.json` artifact.
##
## The refusal cases the ruling requires are each their own test: a missing key, a retired key, a
## valid but wrong key (tree -> stone), swapped arrays, wrong array lengths and a stale catalog
## hash. `test_world_init.gd` carries the seventh -- that a refused binding leaves every store
## byte-identical -- because the world fingerprint lives there.

const Binding := preload("res://scripts/core/resource_catalog_binding.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const CatalogIds := preload("res://scripts/core/catalog_ids.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")

## The ruling's own table, transcribed from the document and NOT from the production module, so a
## key edited in `resource_catalog_binding.gd` fails here instead of agreeing with itself.
const RULED_SCALAR_KEYS: Array[StringName] = [&"wood", &"stone", &"iron"]
const RULED_FORAGE_KEYS: Array[StringName] = [
	&"berries", &"nuts", &"mushrooms", &"herb", &"roots",
]
const RULED_FISH_KEYS: Array[StringName] = [
	&"trout", &"dace", &"salmon", &"perch", &"carp",
	&"whitefish", &"herring", &"mackerel", &"mussel",
]
## §5.9's outputs are `wood`, `stone` and `iron`; `fish` is a recipe selector over the nine species
## keys, not a stock item. None of these three words may become an ItemDefinition by accident.
const UNINVENTED_KEYS: Array[StringName] = [&"tree", &"forage", &"fish"]

var _inventory: InventoryScript = null
var _items: ItemDefinitionsScript = null
var _binding: Binding = null
var _fixture_counter: int = 0


func before_each() -> void:
	"""Load the shipped catalog and open one verified boundary over it."""
	_fixture_counter += 1
	_inventory = InventoryScript.new()
	_items = ItemDefinitionsScript.new()
	assert_true(_items.load_default(_inventory).ok, "the shipped item catalog loads")
	var opened: Binding.OpenResult = Binding.open(_items)
	assert_true(opened.ok, "the boundary opens against the committed artifact")
	_binding = opened.boundary as Binding


func after_each() -> void:
	"""Drop the boundary and its registry so no test inherits another's catalog."""
	_binding = null
	_items = null
	_inventory = null


# --- fixtures -------------------------------------------------------------------------------------

func _catalog_document() -> Dictionary:
	"""The shipped item catalog, parsed, as a mutable document a fixture can edit."""
	var text: String = FileAccess.get_file_as_string(ItemDefinitionsScript.DEFAULT_JSON_PATH)
	return JSON.parse_string(text) as Dictionary


func _write_fixture(suffix: String, text: String) -> String:
	"""Write `text` to a fresh `user://` path and return it. Never touches `res://`."""
	var path: String = "user://binding_fixture_%d_%s" % [_fixture_counter, suffix]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "the fixture file opens for writing")
	file.store_string(text)
	file.close()
	return path


func _registry_without(key: String) -> ItemDefinitionsScript:
	"""A loaded registry whose catalog is the shipped one minus `key`.

	`wood` is the ASCII-greatest item key, so removing it leaves every other compiled id exactly
	where it was: the only difference the boundary can see is the missing binding itself.
	"""
	var document: Dictionary = _catalog_document()
	var kept: Array = []
	for raw: Variant in document["items"] as Array:
		if String((raw as Dictionary)["id"]) != key:
			kept.append(raw)
	document["items"] = kept
	document["count"] = kept.size()
	var path: String = _write_fixture("no_%s.json" % key, JSON.stringify(document))
	var registry: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(registry.load_from_file(path, InventoryScript.new()).ok,
		"the reduced catalog still loads")
	return registry


func _registry_renaming(from_key: String, to_key: String) -> ItemDefinitionsScript:
	"""A loaded registry with one key renamed, which shifts the compiled ids after it."""
	var document: Dictionary = _catalog_document()
	for raw: Variant in document["items"] as Array:
		var record: Dictionary = raw as Dictionary
		if String(record["id"]) == from_key:
			record["id"] = to_key
	var path: String = _write_fixture("renamed.json", JSON.stringify(document))
	var registry: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(registry.load_from_file(path, InventoryScript.new()).ok,
		"the renamed catalog still loads")
	return registry


func _artifact_text() -> String:
	"""The committed artifact's canonical bytes as text."""
	return FileAccess.get_file_as_string(CatalogIds.ARTIFACT_PATH)


func _artifact_without_item_domain() -> String:
	"""The committed artifact with its whole `ItemDefinition` object removed.

	Still canonical: the remaining domain keys are a subsequence of an ascending run, so they stay
	sorted, and no whitespace is introduced. It parses; it simply carries no item domain.
	"""
	var text: String = _artifact_text()
	var opening: String = '"%s":{' % CatalogScript.ITEM_DEFINITION_DOMAIN
	var start: int = text.find(opening)
	assert_true(start >= 0, "the artifact carries an ItemDefinition domain to remove")
	var close: int = text.find("}", start)
	assert_true(close > start, "its object terminates")
	return text.substr(0, start) + text.substr(close + 2)


func _resolved_ids() -> PackedInt32Array:
	"""All seventeen resolved ids in consumer order: scalars, then patch rows, then species rows."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds (error: %s)" % bound.error)
	var ids: PackedInt32Array = PackedInt32Array([bound.binding.tree_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id])
	ids.append_array(bound.binding.forage_item_ids)
	ids.append_array(bound.binding.fish_species_item_ids)
	return ids


# --- the seventeen bindings -----------------------------------------------------------------------

func test_the_ruling_lists_seventeen_bindings_three_five_and_nine() -> void:
	""""three scalars plus arrays of five and nine -- 17 bindings"."""
	assert_equal(Binding.SCALAR_BINDING_COUNT, 3, "wood, stone, iron")
	assert_equal(Binding.FORAGE_BINDING_COUNT, 5, "§5.5's five forage items")
	assert_equal(Binding.FISH_BINDING_COUNT, 9, "§5.4's nine fish species")
	assert_equal(Binding.BINDING_COUNT, 17, "seventeen bindings in total")
	assert_equal(Binding.expected_keys().size(), 17, "and seventeen required keys")


func test_every_required_key_is_the_one_the_ruling_names() -> void:
	"""The exact keys, in the required consumer order, compared against the ruling's own table."""
	assert_equal(Binding.scalar_keys(), RULED_SCALAR_KEYS, "tree, stone and iron outputs")
	assert_equal(Binding.forage_keys(), RULED_FORAGE_KEYS, "berries, nuts, mushrooms, herb, roots")
	assert_equal(Binding.fish_keys(), RULED_FISH_KEYS, "the nine species in §5.4's row order")
	var all_keys: Array[StringName] = RULED_SCALAR_KEYS.duplicate()
	all_keys.append_array(RULED_FORAGE_KEYS)
	all_keys.append_array(RULED_FISH_KEYS)
	assert_equal(Binding.expected_keys(), all_keys, "scalars, then patch rows, then species rows")


func test_all_seventeen_keys_resolve_to_the_id_the_catalog_reports() -> void:
	"""Every binding resolves BY KEY, and each id is the one the registry itself carries."""
	var ids: PackedInt32Array = _resolved_ids()
	var keys: Array[StringName] = Binding.expected_keys()
	assert_equal(ids.size(), keys.size(), "one id per required key")
	for index: int in keys.size():
		var key: StringName = keys[index]
		var lookup: Binding.KeyLookup = _binding.compiled_item_id_of(key)
		assert_true(lookup.ok, "'%s' resolves (error: %s)" % [key, lookup.error])
		assert_equal(lookup.key, key, "the lookup answers about the key it was asked")
		assert_equal(lookup.id, _items.compiled_id(key), "'%s' is the registry's own id" % key)
		assert_equal(ids[index], lookup.id, "position %d carries '%s'" % [index, key])


func test_every_resolved_id_matches_the_committed_artifact() -> void:
	"""The second independent reader: `catalog_ids.json`'s own ItemDefinition table."""
	var parsed: CatalogIds.ParseResult = CatalogIds.parse_canonical(
		_artifact_text().to_utf8_buffer())
	assert_true(parsed.ok, "the committed artifact parses")
	var table: Dictionary = parsed.domains[CatalogScript.ITEM_DEFINITION_DOMAIN] as Dictionary
	var ids: PackedInt32Array = _resolved_ids()
	var keys: Array[StringName] = Binding.expected_keys()
	for index: int in keys.size():
		var name: String = String(keys[index])
		assert_true(table.has(name), "the artifact carries '%s'" % name)
		assert_equal(ids[index], int(table[name]), "'%s' agrees with the artifact" % name)


func test_no_generic_tree_forage_or_fish_item_is_invented() -> void:
	"""There is no generic `tree`, `forage` or `fish` ItemDefinition, and none is substituted."""
	for key: StringName in UNINVENTED_KEYS:
		assert_equal(_items.compiled_id(key), Binding.ABSENT_ITEM_ID,
			"'%s' is not an item key" % key)
		var lookup: Binding.KeyLookup = _binding.compiled_item_id_of(key)
		assert_false(lookup.ok, "'%s' does not resolve" % key)
		assert_equal(lookup.code, Binding.REFUSE_UNKNOWN_KEY, "it refuses instead")
		assert_equal(lookup.id, Binding.ABSENT_ITEM_ID, "carrying no usable id")


# --- row order is the contract ----------------------------------------------------------------

func test_the_forage_and_fish_keys_are_the_owning_stores_own_arrays() -> void:
	"""The key lists are borrowed from `forage.gd` and `fishing.gd`, never a second copy here."""
	assert_equal(Binding.forage_keys(), ForageScript.PATCH_KEYS, "PATCH_KEYS row order")
	assert_equal(Binding.fish_keys(), FishingScript.SPECIES_KEYS, "SPECIES_KEYS row order")
	assert_equal(Binding.FORAGE_BINDING_COUNT, ForageScript.PATCHES_PER_ZONE, "five patch rows")
	assert_equal(Binding.FISH_BINDING_COUNT, FishingScript.SPECIES_COUNT, "nine species rows")


func test_resolved_arrays_are_in_row_order_and_not_sorted_by_compiled_id() -> void:
	"""Sorting by compiled id would associate the wrong quotas, yields and habitats.

	Both shipped orders genuinely differ from ascending id order, so this is a real discriminator
	rather than a coincidence: the assertion below would be vacuous if they happened to agree.
	"""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var forage: PackedInt32Array = bound.binding.forage_item_ids
	var fish: PackedInt32Array = bound.binding.fish_species_item_ids
	var sorted_forage: PackedInt32Array = forage.duplicate()
	sorted_forage.sort()
	var sorted_fish: PackedInt32Array = fish.duplicate()
	sorted_fish.sort()
	assert_false(forage == sorted_forage, "the patch ids are NOT in ascending id order")
	assert_false(fish == sorted_fish, "the species ids are NOT in ascending id order")
	for index: int in ForageScript.PATCH_KEYS.size():
		assert_equal(forage[index], _items.compiled_id(ForageScript.PATCH_KEYS[index]),
			"patch row %d holds its own key's id" % index)
	for index: int in FishingScript.SPECIES_KEYS.size():
		assert_equal(fish[index], _items.compiled_id(FishingScript.SPECIES_KEYS[index]),
			"species row %d holds its own key's id" % index)


func test_a_compiled_item_id_is_never_a_species_row_index() -> void:
	"""Patch kind, species row and item id are different indexes; the ids overflow the tables."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var out_of_range: int = 0
	for id: int in bound.binding.fish_species_item_ids:
		if id >= FishingScript.SPECIES_COUNT:
			out_of_range += 1
	assert_true(out_of_range > 0,
		"at least one species item id is not a legal nine-row subscript")
	assert_equal(bound.binding.fish_species_item_ids.size(), FishingScript.SPECIES_COUNT,
		"the ARRAY is nine long; its CONTENTS are not row indexes")


func test_a_resolved_binding_hands_back_copies_a_caller_cannot_alias() -> void:
	"""Mutating a returned array must not reach the next resolution."""
	var first: Binding.BindResult = _binding.resolve()
	assert_true(first.ok, "the first resolution succeeds")
	var original: int = first.binding.forage_item_ids[0]
	first.binding.forage_item_ids[0] = original + 1000
	var second: Binding.BindResult = _binding.resolve()
	assert_true(second.ok, "the second resolution succeeds")
	assert_equal(second.binding.forage_item_ids[0], original, "the boundary is unchanged")


# --- refusal 1: a missing key ---------------------------------------------------------------------

func test_a_missing_key_refuses_and_nothing_is_substituted() -> void:
	"""A catalog with no `wood` cannot bind the tree output; no other item stands in for it."""
	var reduced: ItemDefinitionsScript = _registry_without("wood")
	assert_equal(reduced.compiled_id(&"wood"), Binding.ABSENT_ITEM_ID, "the key really is gone")
	var opened: Binding.OpenResult = Binding.open(reduced)
	assert_true(opened.ok, "the committed artifact still verifies")
	var boundary: Binding = opened.boundary as Binding
	var lookup: Binding.KeyLookup = boundary.compiled_item_id_of(Binding.TREE_ITEM_KEY)
	assert_false(lookup.ok, "the missing key does not resolve")
	assert_equal(lookup.code, Binding.REFUSE_UNKNOWN_KEY, "with the unknown-key code")
	var bound: Binding.BindResult = boundary.resolve()
	assert_false(bound.ok, "and the whole binding refuses")
	assert_equal(bound.error, Binding.REFUSE_UNKNOWN_KEY, "propagating that code")
	assert_null(bound.binding, "producing no partial binding")


func test_a_missing_key_refuses_the_group_without_binding_its_siblings() -> void:
	"""A refusal produces nothing at all, not sixteen of seventeen ids with one hole in it.

	Only `wood` can be removed without renumbering anything else -- it is the ASCII-greatest item
	key -- so this fixture isolates "one binding is missing" from "the catalog was renumbered",
	which has its own refusal code.
	"""
	var reduced: ItemDefinitionsScript = _registry_without("wood")
	var opened: Binding.OpenResult = Binding.open(reduced)
	assert_true(opened.ok, "the boundary still opens")
	var boundary: Binding = opened.boundary as Binding
	for key: StringName in RULED_FORAGE_KEYS:
		assert_true(boundary.compiled_item_id_of(key).ok, "'%s' still resolves alone" % key)
	for key: StringName in RULED_FISH_KEYS:
		assert_true(boundary.compiled_item_id_of(key).ok, "'%s' still resolves alone" % key)
	var bound: Binding.BindResult = boundary.resolve()
	assert_false(bound.ok, "but the binding refuses as a whole")
	assert_equal(bound.error, Binding.REFUSE_UNKNOWN_KEY, "naming the unknown key")
	assert_null(bound.binding, "and hands back no ids at all")


# --- refusal 2: a retired key ---------------------------------------------------------------------

func test_every_retired_key_refuses_with_its_own_code() -> void:
	"""SET-AMEND-001 §3's retired keys are rejected, never substituted (REQ-ADM-003)."""
	assert_true(ItemDefinitionsScript.RETIRED_KEYS.size() > 0, "there are retired keys to test")
	for raw: Variant in ItemDefinitionsScript.RETIRED_KEYS.keys():
		var key: StringName = raw as StringName
		var lookup: Binding.KeyLookup = _binding.compiled_item_id_of(key)
		assert_false(lookup.ok, "retired '%s' does not resolve" % key)
		assert_equal(lookup.code, Binding.REFUSE_RETIRED_KEY, "with the retired-key code")
		assert_equal(lookup.id, Binding.ABSENT_ITEM_ID, "and no usable id")


func test_a_retired_key_is_refused_as_retired_not_as_a_typo() -> void:
	"""The retired code is distinct from the unknown code, so the reason is never mistaken."""
	var retired: Binding.KeyLookup = _binding.compiled_item_id_of(&"raw_game")
	var unknown: Binding.KeyLookup = _binding.compiled_item_id_of(&"not_an_item_key")
	assert_equal(retired.code, Binding.REFUSE_RETIRED_KEY, "hunting was retired")
	assert_equal(unknown.code, Binding.REFUSE_UNKNOWN_KEY, "this one was never a key")
	assert_false(retired.code == unknown.code, "the two refusals are distinguishable")


func test_the_retired_check_runs_before_the_registry_is_consulted() -> void:
	"""A retired key refuses even against a boundary that was never opened, so no catalog that
	re-added one could bypass it. `item_definitions.gd` refuses such a catalog outright as well."""
	var unopened: Binding = Binding.new()
	assert_false(unopened.is_open(), "this boundary never came from open()")
	assert_equal(unopened.compiled_item_id_of(&"bow").code, Binding.REFUSE_NOT_OPEN,
		"an unopened boundary refuses before anything else")
	assert_equal(_binding.compiled_item_id_of(&"bow").code, Binding.REFUSE_RETIRED_KEY,
		"and an opened one refuses the retired key by name")


# --- refusal 3: a valid but wrong key -------------------------------------------------------------

func test_the_tree_field_holding_the_stone_id_refuses() -> void:
	"""Both ids are perfectly valid catalog ids; only one of them belongs in that field."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var wrong: Binding.BindResult = _binding.verify_ids(bound.binding.stone_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id,
		bound.binding.forage_item_ids, bound.binding.fish_species_item_ids)
	assert_false(wrong.ok, "tree -> stone refuses")
	assert_equal(wrong.error, Binding.REFUSE_ID_NOT_BOUND, "with the not-bound code")
	assert_true(wrong.detail.contains("wood"), "naming the key that field must carry")
	assert_null(wrong.binding, "and producing no binding")


func test_each_scalar_field_is_checked_against_its_own_key() -> void:
	"""A rotation of the three scalars refuses on the first field that is wrong."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var rotated: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
		bound.binding.iron_resource_id, bound.binding.stone_resource_id,
		bound.binding.forage_item_ids, bound.binding.fish_species_item_ids)
	assert_false(rotated.ok, "stone and iron exchanged refuses")
	assert_equal(rotated.error, Binding.REFUSE_ID_NOT_BOUND, "with the not-bound code")
	assert_true(rotated.detail.contains("stone"), "naming position 1's required key")


func test_the_exact_bound_values_are_accepted() -> void:
	"""The positive case: the boundary's own output verifies against the boundary."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var proved: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id,
		bound.binding.forage_item_ids, bound.binding.fish_species_item_ids)
	assert_true(proved.ok, "a correctly bound request verifies (error: %s)" % proved.error)
	assert_not_null(proved.binding, "and hands back the seventeen ids")


# --- refusal 4: swapped arrays --------------------------------------------------------------------

func test_the_two_arrays_exchanged_refuses() -> void:
	"""Handing the fish ids to the forage field and vice versa never generates a world."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var swapped: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id,
		bound.binding.fish_species_item_ids, bound.binding.forage_item_ids)
	assert_false(swapped.ok, "the exchanged arrays refuse")
	assert_equal(swapped.error, Binding.REFUSE_SET_SIZE, "on their lengths, which cannot match")
	assert_null(swapped.binding, "and produce no binding")


func test_a_forage_array_sorted_by_compiled_id_refuses() -> void:
	"""The ruling's named defect: sorting associates the wrong quota with every patch row."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var sorted_forage: PackedInt32Array = bound.binding.forage_item_ids.duplicate()
	sorted_forage.sort()
	assert_false(sorted_forage == bound.binding.forage_item_ids, "sorting really reorders them")
	var refused: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id, sorted_forage,
		bound.binding.fish_species_item_ids)
	assert_false(refused.ok, "the sorted patch ids refuse")
	assert_equal(refused.error, Binding.REFUSE_ID_NOT_BOUND, "with the not-bound code")


func test_a_fish_array_sorted_by_compiled_id_refuses() -> void:
	"""The same defect on the nine-row species table, which carries habitats and capacities."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var sorted_fish: PackedInt32Array = bound.binding.fish_species_item_ids.duplicate()
	sorted_fish.sort()
	assert_false(sorted_fish == bound.binding.fish_species_item_ids, "sorting really reorders them")
	var refused: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id,
		bound.binding.forage_item_ids, sorted_fish)
	assert_false(refused.ok, "the sorted species ids refuse")
	assert_equal(refused.error, Binding.REFUSE_ID_NOT_BOUND, "with the not-bound code")


func test_any_two_exchanged_entries_refuse_and_name_the_position() -> void:
	"""Every position is checked, not just the first: each adjacent swap is caught in turn."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	for index: int in FishingScript.SPECIES_COUNT - 1:
		var mangled: PackedInt32Array = bound.binding.fish_species_item_ids.duplicate()
		var held: int = mangled[index]
		mangled[index] = mangled[index + 1]
		mangled[index + 1] = held
		var refused: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
			bound.binding.stone_resource_id, bound.binding.iron_resource_id,
			bound.binding.forage_item_ids, mangled)
		assert_equal(refused.error, Binding.REFUSE_ID_NOT_BOUND,
			"species rows %d and %d exchanged refuse" % [index, index + 1])
		assert_true(refused.detail.contains(String(FishingScript.SPECIES_KEYS[index])),
			"naming row %d's own species key" % index)


# --- refusal 5: wrong array lengths ---------------------------------------------------------------

func test_a_short_or_long_array_refuses_rather_than_being_padded() -> void:
	"""Five patch rows and nine species rows: no other length is accepted or truncated."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var short_forage: PackedInt32Array = bound.binding.forage_item_ids.duplicate()
	short_forage.remove_at(short_forage.size() - 1)
	assert_equal(_short_refusal(bound, short_forage, bound.binding.fish_species_item_ids),
		Binding.REFUSE_SET_SIZE, "four forage ids refuse")
	var long_forage: PackedInt32Array = bound.binding.forage_item_ids.duplicate()
	long_forage.append(bound.binding.forage_item_ids[0])
	assert_equal(_short_refusal(bound, long_forage, bound.binding.fish_species_item_ids),
		Binding.REFUSE_SET_SIZE, "six forage ids refuse")
	var short_fish: PackedInt32Array = bound.binding.fish_species_item_ids.duplicate()
	short_fish.remove_at(0)
	assert_equal(_short_refusal(bound, bound.binding.forage_item_ids, short_fish),
		Binding.REFUSE_SET_SIZE, "eight species ids refuse")
	assert_equal(_short_refusal(bound, PackedInt32Array(), PackedInt32Array()),
		Binding.REFUSE_SET_SIZE, "and two empty arrays refuse")


func _short_refusal(bound: Binding.BindResult, forage: PackedInt32Array,
		fish: PackedInt32Array) -> StringName:
	"""Verify a request built from correct scalars and the given arrays; return its refusal code."""
	var result: Binding.BindResult = _binding.verify_ids(bound.binding.tree_resource_id,
		bound.binding.stone_resource_id, bound.binding.iron_resource_id, forage, fish)
	assert_null(result.binding, "a refused verification produces no binding")
	return result.error


# --- refusal 6: a stale catalog hash --------------------------------------------------------------

func test_an_artifact_with_a_moved_id_refuses_to_open() -> void:
	"""A single moved id in `catalog_ids.json` is a stale catalog, and the boundary refuses it."""
	var text: String = _artifact_text()
	var wood_entry: String = '"wood":%d' % _items.compiled_id(&"wood")
	assert_true(text.contains(wood_entry), "the artifact records wood's id")
	var unused: int = _items.item_count()
	assert_false(text.contains('":%d,' % unused), "the substitute id is used by no item key")
	var path: String = _write_fixture("moved_id.json",
		text.replace(wood_entry, '"wood":%d' % unused))
	var opened: Binding.OpenResult = Binding.open(_items, path)
	assert_false(opened.ok, "the stale artifact refuses")
	assert_equal(opened.error, Binding.REFUSE_ARTIFACT, "with the artifact code")
	assert_true(opened.detail.contains("CATALOG_IDS_ID_MISMATCH"),
		"diagnosed as a moved id, not as a missing file: %s" % opened.detail)
	assert_null(opened.boundary, "and no boundary is produced")


func test_an_artifact_with_a_flipped_byte_refuses_to_open() -> void:
	"""The digest covers bytes: a renamed key is as fatal as a renumbered one."""
	var text: String = _artifact_text()
	assert_true(text.contains('"mussel"'), "the artifact records the mussel key")
	var path: String = _write_fixture("flipped.json", text.replace('"mussel"', '"musse1"'))
	var opened: Binding.OpenResult = Binding.open(_items, path)
	assert_false(opened.ok, "the edited artifact refuses")
	assert_equal(opened.error, Binding.REFUSE_ARTIFACT, "with the artifact code")


func test_a_truncated_artifact_refuses_and_names_the_parse_failure() -> void:
	"""There is no fallback artifact and no rebuild-on-mismatch path.

	The DETAIL is asserted, not only the code: every artifact problem shares REFUSE_ARTIFACT, so
	the code alone cannot tell "this file is not there" from "this file is not canonical", and a
	refusal nobody can diagnose is barely better than a silent one.
	"""
	var truncated: String = _write_fixture("truncated.json", _artifact_text().substr(0, 64))
	var opened: Binding.OpenResult = Binding.open(_items, truncated)
	assert_false(opened.ok, "a truncated artifact refuses")
	assert_equal(opened.error, Binding.REFUSE_ARTIFACT, "with the artifact code")
	assert_true(opened.detail.contains("CATALOG_IDS_"),
		"naming the canonical-reader's own refusal: %s" % opened.detail)


func test_an_absent_artifact_refuses_as_absent_and_is_not_created() -> void:
	"""A missing artifact is diagnosed as missing, and nothing is written in its place."""
	var absent: String = "user://binding_fixture_%d_absent.json" % _fixture_counter
	assert_false(FileAccess.file_exists(absent), "the fixture path must not exist")
	var opened: Binding.OpenResult = Binding.open(_items, absent)
	assert_false(opened.ok, "a missing artifact refuses")
	assert_equal(opened.error, Binding.REFUSE_ARTIFACT, "with the artifact code")
	assert_true(opened.detail.contains("artifact not found"),
		"diagnosed as absent, not as unreadable or unparseable: %s" % opened.detail)
	assert_true(opened.detail.contains(absent), "naming the path it looked at")
	assert_false(FileAccess.file_exists(absent), "nothing was written in its place")


func test_an_artifact_carrying_no_item_domain_refuses_with_its_own_code() -> void:
	"""A canonical artifact that simply has no `ItemDefinition` object is named as such.

	This refusal is checked BEFORE the byte comparison on purpose: "the artifact has no item
	domain" and "the artifact disagrees with the installed catalog" are different diagnoses, and
	a missing domain would otherwise be reported as a generic mismatch.
	"""
	var stripped: String = _artifact_without_item_domain()
	var parsed: CatalogIds.ParseResult = CatalogIds.parse_canonical(stripped.to_utf8_buffer())
	assert_true(parsed.ok, "the fixture is still canonical and parses (error: %s)" % parsed.error)
	assert_false(parsed.domains.has(CatalogScript.ITEM_DEFINITION_DOMAIN),
		"and really carries no item domain")
	var path: String = _write_fixture("no_item_domain.json", stripped)
	var opened: Binding.OpenResult = Binding.open(_items, path)
	assert_false(opened.ok, "it refuses to open")
	assert_equal(opened.error, Binding.REFUSE_ARTIFACT_DOMAIN, "naming the missing domain")
	assert_null(opened.boundary, "and produces no boundary")


func test_a_key_the_artifact_never_carried_never_resolves() -> void:
	"""A registry key absent from the VERIFIED artifact refuses, even when its id would match.

	`aaa_beans` sorts first, so the substitute registry compiles it to id 0 -- the same value a
	missing-key lookup would degrade to. Only an explicit membership check catches it, which is
	why comparing the ids alone is not enough.
	"""
	var renamed: ItemDefinitionsScript = _registry_renaming("beans", "aaa_beans")
	assert_equal(renamed.compiled_id(&"aaa_beans"), 0, "the substitute key compiles to id 0")
	var opened: Binding.OpenResult = Binding.open(renamed)
	assert_true(opened.ok, "the committed artifact itself still verifies")
	var boundary: Binding = opened.boundary as Binding
	var lookup: Binding.KeyLookup = boundary.compiled_item_id_of(&"aaa_beans")
	assert_false(lookup.ok, "the key the artifact never carried does not resolve")
	assert_equal(lookup.code, Binding.REFUSE_ARTIFACT_DISAGREES, "with the disagreement code")
	assert_equal(lookup.id, Binding.ABSENT_ITEM_ID, "and no usable id")


func test_a_binding_copies_the_arrays_it_is_constructed_from() -> void:
	"""`Binding` is public: a caller that keeps its own array must not reach inside a built one."""
	var bound: Binding.BindResult = _binding.resolve()
	assert_true(bound.ok, "the shipped catalog binds")
	var forage: PackedInt32Array = bound.binding.forage_item_ids.duplicate()
	var fish: PackedInt32Array = bound.binding.fish_species_item_ids.duplicate()
	var held: Binding.Binding = Binding.Binding.new(1, 2, 3, forage, fish)
	var original_forage: int = forage[0]
	var original_fish: int = fish[0]
	forage[0] = original_forage + 1000
	fish[0] = original_fish + 1000
	assert_equal(held.forage_item_ids[0], original_forage, "the patch ids were copied")
	assert_equal(held.fish_species_item_ids[0], original_fish, "and so were the species ids")


func test_the_committed_artifact_is_what_the_boundary_verifies_by_default() -> void:
	"""The default path is `catalog_ids.gd`'s own, never a second copy of the string."""
	assert_equal(Binding.DEFAULT_ARTIFACT_PATH, CatalogIds.ARTIFACT_PATH, "one path, one owner")
	assert_equal(_binding.artifact_path(), CatalogIds.ARTIFACT_PATH, "and it is what was verified")
	assert_true(CatalogIds.verify_file().ok, "which verifies against the installed catalog")


func test_a_registry_that_disagrees_with_the_artifact_refuses() -> void:
	"""A registry loaded from a different catalog compiles different ids, and is caught.

	Renaming the ASCII-first key to one that sorts after `wood` shifts every later id down by one,
	so the registry and the verified artifact disagree about a key they both carry.
	"""
	var renamed: ItemDefinitionsScript = _registry_renaming("beans", "zzz_beans")
	assert_false(renamed.compiled_id(&"wood") == _items.compiled_id(&"wood"),
		"the substitute catalog really does renumber wood")
	var opened: Binding.OpenResult = Binding.open(renamed)
	assert_true(opened.ok, "the committed artifact itself still verifies")
	var boundary: Binding = opened.boundary as Binding
	var lookup: Binding.KeyLookup = boundary.compiled_item_id_of(Binding.TREE_ITEM_KEY)
	assert_false(lookup.ok, "but the key does not resolve")
	assert_equal(lookup.code, Binding.REFUSE_ARTIFACT_DISAGREES, "registry and artifact disagree")
	assert_equal(boundary.resolve().error, Binding.REFUSE_ARTIFACT_DISAGREES,
		"and the whole binding refuses")


# --- opening the boundary at all ------------------------------------------------------------------

func test_opening_without_a_registry_refuses() -> void:
	"""No registry means no key can be resolved; there is no implicit global catalog."""
	var opened: Binding.OpenResult = Binding.open(null)
	assert_false(opened.ok, "a null registry refuses")
	assert_equal(opened.error, Binding.REFUSE_NO_REGISTRY, "with its own code")
	assert_null(opened.boundary, "and produces no boundary")


func test_opening_over_an_unloaded_registry_refuses() -> void:
	"""An unloaded registry answers every key with absence, which is not an id."""
	var empty: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_false(empty.is_loaded(), "the registry has loaded nothing")
	var opened: Binding.OpenResult = Binding.open(empty)
	assert_false(opened.ok, "an unloaded registry refuses")
	assert_equal(opened.error, Binding.REFUSE_REGISTRY_NOT_LOADED, "with its own code")


func test_a_boundary_that_never_opened_resolves_nothing() -> void:
	"""`new()` alone is not a verified boundary, and says so rather than answering."""
	var unopened: Binding = Binding.new()
	assert_false(unopened.is_open(), "it is not open")
	assert_equal(unopened.artifact_path(), "", "it verified no artifact")
	var bound: Binding.BindResult = unopened.resolve()
	assert_false(bound.ok, "it resolves nothing")
	assert_equal(bound.error, Binding.REFUSE_NOT_OPEN, "with the not-open code")
	assert_null(bound.binding, "and hands back no ids")


func test_absence_is_catalogs_own_empty_id_and_never_a_stored_value() -> void:
	"""§4.2's empty catalog id is read from catalog.gd, not mirrored, and marks absence only."""
	assert_equal(Binding.ABSENT_ITEM_ID, CatalogScript.EMPTY_CATALOG_ID, "one definition of -1")
	var lookup: Binding.KeyLookup = _binding.compiled_item_id_of(&"no_such_key")
	assert_equal(lookup.id, CatalogScript.EMPTY_CATALOG_ID, "a refusal carries absence")
	assert_false(lookup.code == Binding.REFUSE_NONE, "and a code that is not success")
