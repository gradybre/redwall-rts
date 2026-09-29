extends Node3D
## The wood yard and the deadfall, drawn. Decision 0196 (live demo). Presentation only.
##
## The yard (forest_yard.gd): the staged sawhorse, chopping block and sapling baskets stand where the
## yard puts them; the plank stack's height follows the demo stores' planks (hidden at none, full at
## PLANK_STACK_FULL_MILLI); beside the log stack a second woodpile stands as tall as the stores' wood
## (forest_yard.gd `log_pile_share`). Deadfall piles (forest_deadfall.gd) lie as small fallen logs, a pool made once and
## shown row by row. Redrawn only when the stores' or the deadfall's revision changes.

const Yard := preload("res://demo/forestry/forest_yard.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const LOG_KEY: StringName = &"log_stack"
const DEADFALL_KEY: StringName = &"fallen_log"
## A deadfall pile is drawn this share of the world's fallen log, bigger with more wood in it.
const DEADFALL_SIZE_MIN: float = 0.42
const DEADFALL_SIZE_MAX: float = 0.6
## The plank stack is never drawn thinner than this share of its height while it holds any.
const PLANK_MIN_SHARE: float = 0.18

var _stores: StoresScript = null
var _deadfall: DeadfallScript = null
var _props: PropsScript = null
var _pieces: Array[Node3D] = []
var _pile: Node3D = null
var _piles: Array[Node3D] = []
var _pile_base: PackedFloat32Array = PackedFloat32Array()
var _seen_stores: int = -1
var _seen_deadfall: int = -1


func configure(stores: StoresScript, deadfall: DeadfallScript, props: PropsScript, make: Callable) -> void:
	"""Build the yard's pieces, the log pile and the deadfall pool; `make(key, at, yaw, size)` makes a
	world model (the fallen logs)."""
	name = "ForestYard"
	_stores = stores
	_deadfall = deadfall
	_props = props
	for piece: int in Yard.PIECES.size():
		var node := Node3D.new()
		node.transform = Transform3D(Basis(Vector3.UP, Yard.yaw(piece)), Vector3(Yard.at(piece).x, 0.0, Yard.at(piece).y))
		node.add_child(props.instance(Yard.key(piece)))
		add_child(node)
		_pieces.append(node)
	_pile = make.call(LOG_KEY, Yard.LOG_PILE_AT, deg_to_rad(Yard.LOG_PILE_YAW_DEG), Yard.LOG_PILE_SIZE) as Node3D
	add_child(_pile)
	_build_piles(make)
	refresh()


func _build_piles(make: Callable) -> void:
	"""One hidden fallen log per deadfall row."""
	_pile_base.resize(Rules.DEADFALL_MAX)
	for pile: int in Rules.DEADFALL_MAX:
		var node: Node3D = make.call(DEADFALL_KEY, Vector2.ZERO, 0.0, 1.0) as Node3D
		_pile_base[pile] = node.transform.basis.get_scale().x
		node.visible = false
		add_child(node)
		_piles.append(node)


func refresh() -> void:
	"""Redraw the stock's logs and planks and the deadfall, when either changed."""
	if _stores.revision != _seen_stores:
		_seen_stores = _stores.revision
		_draw_stock()
	if _deadfall.revision != _seen_deadfall:
		_seen_deadfall = _deadfall.revision
		_draw_piles()


func _draw_stock() -> void:
	"""The woodpile's and the plank stack's heights from the demo stores."""
	var logs: float = Yard.log_pile_share(_stores.wood_milli_u)
	_pile.visible = logs > 0.0
	_pile.scale.y = _pile.scale.x * maxf(logs, 0.01)
	var stack: Node3D = _pieces[Yard.PLANK_STACK]
	var share: float = clampf(float(_stores.plank_milli_u) / float(Yard.PLANK_STACK_FULL_MILLI), PLANK_MIN_SHARE, 1.0)
	stack.visible = _stores.plank_milli_u > 0
	stack.scale = Vector3(1.0, share, 1.0)


func _draw_piles() -> void:
	"""Each lying deadfall pile as a fallen log at its spot, sized by its wood."""
	for pile: int in Rules.DEADFALL_MAX:
		var node: Node3D = _piles[pile]
		node.visible = _deadfall.live[pile] == 1
		if not node.visible:
			continue
		var share: float = float(_deadfall.milli[pile] - Rules.DEADFALL_MIN_MILLI) / float(Rules.DEADFALL_MAX_MILLI - Rules.DEADFALL_MIN_MILLI)
		var size: float = lerpf(DEADFALL_SIZE_MIN, DEADFALL_SIZE_MAX, share) * _pile_base[pile]
		var at: Vector2 = _deadfall.at[pile]
		node.transform = Transform3D(Basis(Vector3.UP, _deadfall.yaw[pile]).scaled(Vector3.ONE * size), Vector3(at.x, 0.0, at.y))


func log_pile_share() -> float:
	"""The woodpile's drawn height share, 0 when hidden (checks)."""
	return _pile.scale.y / _pile.scale.x if _pile.visible else 0.0


func plank_stack_share() -> float:
	"""The plank stack's drawn height share, 0 when hidden (checks)."""
	var stack: Node3D = _pieces[Yard.PLANK_STACK]
	return stack.scale.y if stack.visible else 0.0


func piles_visible() -> int:
	"""How many deadfall piles are drawn (checks)."""
	var n: int = 0
	for node: Node3D in _piles:
		n += 1 if node.visible else 0
	return n
