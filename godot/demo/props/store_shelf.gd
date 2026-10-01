extends Node3D
## A food store's shelf, filled as the store fills. Decision 0196 (live demo). Presentation only.
##
## A pantry_shelf with a row of clay_jars on the floor beside it and SLOTS places for goods set out on
## the ground before it, in two rows (demo/props/demo_props.gd draws all of them, staged or as boxes;
## the library's shelf carries its own pots and cheeses on its boards, where the goods were lost).
## `show_stock()` is handed how full the store is and which goods are in it, most first; it shows one
## jar per started third of fullness and one good per slot, each the harvested item's own model,
## until the goods or the slots run out. The farm's covered store and every root cellar room have one (farm/farm_stock_view.gd).
##
## Built once; `show_stock()` only swaps meshes and visibility when what it is handed changed.

const PropsScript := preload("res://demo/props/demo_props.gd")

const SHELF_KEY: StringName = &"pantry_shelf"
const JARS_KEY: StringName = &"clay_jars"
## The goods' places before the shelf: three across (fractions of its width from its centre), in two
## rows this far out from its front (metres), each good turned a little from the last.
const PLACES_ACROSS: Array[float] = [-0.36, 0.0, 0.36]
const ROWS_OUT_M: Array[float] = [0.42, 0.78]
const GOOD_TURN: float = 0.9
const SLOTS: int = 6
## Goods are set out at this share of their carried size (a sheaf or a leek lies on the ground).
const GOOD_SCALE: float = 0.8
## Jars stand this far to the shelf's right (metres), one per started third of fullness.
const JARS: int = 3
const JAR_STEP_M: float = 0.42
const JAR_OFFSET_M: float = 0.55
const PERMILLE: int = 1000

var _props: PropsScript = null
var _shelf: MeshInstance3D = null
var _goods: Array[MeshInstance3D] = []
var _slot_at: Array[Vector3] = []
var _jars: Array[MeshInstance3D] = []
var _shown_fill: int = -1
var _shown_keys: Array[StringName] = []


func build(props: PropsScript) -> void:
	"""Build the shelf, its empty slots and its jars (hidden until stocked)."""
	_props = props
	_shelf = props.instance(SHELF_KEY)
	add_child(_shelf)
	var bound: AABB = props.drawn_bound(SHELF_KEY)
	for slot: int in SLOTS:
		var good := MeshInstance3D.new()
		good.name = "Good%d" % slot
		good.visible = false
		_slot_at.append(Vector3(PLACES_ACROSS[slot % PLACES_ACROSS.size()] * bound.size.x, 0.0,
			bound.end.z + ROWS_OUT_M[slot / PLACES_ACROSS.size()]))
		add_child(good)
		_goods.append(good)
		_shown_keys.append(&"")
	for k: int in JARS:
		var jar: MeshInstance3D = props.instance(JARS_KEY)
		jar.position += Vector3(bound.size.x * 0.5 + JAR_OFFSET_M + JAR_STEP_M * k, 0.0, 0.0)
		jar.visible = false
		add_child(jar)
		_jars.append(jar)


static func jars_for(fill_permille: int) -> int:
	"""How many jars stand for this fullness: one per started third, none when empty."""
	if fill_permille <= 0:
		return 0
	return mini(JARS, (fill_permille * JARS + PERMILLE - 1) / PERMILLE)


func show_stock(fill_permille: int, keys: Array[StringName]) -> void:
	"""Show this fullness and these goods (prop keys, most first; &"" for a good with no model)."""
	if fill_permille != _shown_fill:
		_shown_fill = fill_permille
		var jars: int = jars_for(fill_permille)
		for k: int in JARS:
			_jars[k].visible = k < jars
	var slot: int = 0
	for key: StringName in keys:
		if slot >= SLOTS:
			break
		if key == &"" or not PropsScript.is_known(key):
			continue
		_put(slot, key)
		slot += 1
	for rest: int in range(slot, SLOTS):
		_put(rest, &"")


func _put(slot: int, key: StringName) -> void:
	"""Slot `slot` shows `key` (or nothing); touches the node only when that changes."""
	if _shown_keys[slot] == key:
		return
	_shown_keys[slot] = key
	var good: MeshInstance3D = _goods[slot]
	good.visible = key != &""
	if key == &"":
		return
	good.mesh = _props.mesh_of(key)
	var fit: Transform3D = _props.fit_of(key)
	var turn := Basis(Vector3.UP, GOOD_TURN * slot)
	good.transform = Transform3D(turn * fit.basis.scaled(Vector3.ONE * GOOD_SCALE), _slot_at[slot] + turn * fit.origin * GOOD_SCALE)


func shown_goods() -> int:
	"""How many slots show a good (tests)."""
	var count: int = 0
	for good: MeshInstance3D in _goods:
		count += 1 if good.visible else 0
	return count


func shown_jars() -> int:
	"""How many jars stand (tests)."""
	var count: int = 0
	for jar: MeshInstance3D in _jars:
		count += 1 if jar.visible else 0
	return count


func good_key(slot: int) -> StringName:
	"""The key slot `slot` shows (&"": none; tests)."""
	return _shown_keys[slot]
