extends RefCounted
## Which library dishes each farmed ingredient feeds. Decision 0196. Groundwork for cooking: the
## demo has no cooking system, so these are shown as the content library's CANDIDATES -- every one
## NOT_RUNTIME_ACTIVE (CONTENT-LIB-001 LIB-008), with no quantities, yields or work.
##
## The data is godot/demo/farm/pantry_index.json, built once from
## docs/redwall-content-library/shared/pantry.json by tools/make_demo_pantry_index.py (the handoff's
## "resolve at build time", §6): per ingredient, how many production-candidate dishes use it directly
## and how many through a prepared component (oats through oat drink, say), and up to 40 of them.

const Catalog := preload("res://demo/farm/farm_catalog.gd")

const INDEX_PATH: String = "res://demo/farm/pantry_index.json"
const USE_DIRECT: String = "direct"

var _direct: PackedInt32Array = PackedInt32Array()
var _component: PackedInt32Array = PackedInt32Array()
var _dishes: Array[PackedStringArray] = []
var _loaded: bool = false


func load_index(path: String = INDEX_PATH) -> bool:
	"""Read the index; false (nothing loaded) when it is missing or does not list the farm's items in
	the catalog's order."""
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("items") is Array:
		return false
	var items: Array = (parsed as Dictionary)["items"]
	if items.size() != Catalog.ITEM_COUNT:
		return false
	_direct.resize(Catalog.ITEM_COUNT)
	_component.resize(Catalog.ITEM_COUNT)
	_dishes.clear()
	for item: int in Catalog.ITEM_COUNT:
		var entry: Dictionary = items[item]
		if String(entry.get("leaf_id", "")) != Catalog.ITEM_LEAVES[item]:
			return false
		_direct[item] = int(entry.get("direct_count", 0))
		_component[item] = int(entry.get("component_count", 0))
		_dishes.append(_labels(entry.get("dishes", [])))
	_loaded = true
	return true


static func _labels(dishes: Array) -> PackedStringArray:
	"""The dish labels, a direct use plain and a use through a component marked '(via …)'."""
	var out := PackedStringArray()
	for dish: Variant in dishes:
		var row: Dictionary = dish
		var suffix: String = "" if String(row.get("use", "")) == USE_DIRECT else " (in a prepared part)"
		out.append(String(row.get("label", "")) + suffix)
	return out


func is_loaded() -> bool:
	"""Whether the index loaded."""
	return _loaded


func direct_count(item: int) -> int:
	"""Dishes using the ingredient directly."""
	return _direct[item]


func component_count(item: int) -> int:
	"""Further dishes using it only inside a prepared component."""
	return _component[item]


func dishes_of(item: int) -> PackedStringArray:
	"""The listed dishes (at most 40, direct uses first)."""
	return _dishes[item]
