extends RefCounted
## The farm's harvested goods as things you can see: each item's model, its icon, and how it sits in a
## carrier's arms. Decision 0196 (live demo). Presentation only.
##
## Over demo/props/demo_props.gd, by farm_catalog.gd ITEM_PROP: eleven items have their own library
## model (tools/make_demo_props.py) and its 128 px icon; the five without one (parsnip, cabbage,
## spinach, broad bean, wheat) carry and shelve nothing. An item's ICON is read by its key first
## (`item_<pantry key>`: the food art's apple, pear, berries, nuts, mushrooms, herb, potato, honey,
## flour and dried fish, decision 0941), then its model's; with neither -- and for every item while
## nothing is staged -- a roundel in the item's own colour (ITEM_SWATCH).

const PropsScript := preload("res://demo/props/demo_props.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

var props: PropsScript = null
## Each pantry item's icon key, `item_<its pantry key>` (demo_props.gd ICONS BY KEY, decision 0903): made once.
var _icon_keys: Array[StringName] = []


func _init(p_props: PropsScript = null) -> void:
	"""Over this props table (a fresh, unstaged one when none is given)."""
	props = p_props if p_props != null else PropsScript.new()
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		_icon_keys.append(icon_key_of(item))


static func icon_key_of(item: int) -> StringName:
	"""The icon key a pantry item is drawn by: `item_` and its pantry key (never its number; decision 0903)."""
	return StringName("item_" + String(Catalog.ITEM_KEYS[item]))


func has_model(item: int) -> bool:
	"""Whether `item` has a model of its own (staged or not)."""
	return Catalog.is_pantry_item(item) and Catalog.ITEM_PROP[item] != &""


func icon_of(item: int) -> Texture2D:
	"""`item`'s icon: its own staged icon by key (`icon_key_of`), else its model's, else a roundel in its colour."""
	if props.has_icon(_icon_keys[item]):
		return props.icon_of(_icon_keys[item], Catalog.ITEM_SWATCH[item])
	return props.icon_of(Catalog.ITEM_PROP[item], Catalog.ITEM_SWATCH[item])


func has_staged_icon(item: int) -> bool:
	"""Whether `item`'s icon is a staged render (not the fallback roundel)."""
	return props.has_icon(_icon_keys[item]) or (has_model(item) and props.has_icon(Catalog.ITEM_PROP[item]))


func hand_fit(item: int) -> Transform3D:
	"""How `item`'s model sits between two hands: at its drawn size, centred on the hands' midpoint.
	Only for an item with a model (has_model)."""
	var key: StringName = Catalog.ITEM_PROP[item]
	var bound: AABB = props.drawn_bound(key)
	return Transform3D(Basis.IDENTITY, -bound.get_center()) * props.fit_of(key)


func shelf_keys(item_order: PackedInt32Array, count: int, out: Array[StringName]) -> void:
	"""The model keys of the first `count` items of `item_order`, into `out` (cleared first)."""
	out.clear()
	for k: int in mini(count, item_order.size()):
		out.append(Catalog.ITEM_PROP[item_order[k]])
