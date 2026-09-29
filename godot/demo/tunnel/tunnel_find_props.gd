extends Node3D
## Finds lying where they were dug. Decision 0196 (live demo). Presentation only.
##
## tunnel_works.gd keeps a ring of the latest FOUND_RING finds -- where each was cut, what it was, and
## for a relic which one. In the underground view each lies on the bore floor at its cut as its own
## library model (tunnel_finds.gd model_of: a flint, a lump of clay, an old basket for a root store, a
## bell, a key or a banner); a relic with no model of its own lies there unseen (the panel shows its
## roundel). Redrawn only when a new find is cut or the view changes.

const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

## Each find turns by this much from the last, so a row of them does not line up.
const TURN_PER_FIND: float = 2.3

var _works: WorksScript = null
var _network: NetworkScript = null
var _props: PropsScript = null
var _pieces: Array[MeshInstance3D] = []
var _underground: bool = false
var _seen: int = -1


func configure(works: WorksScript, network: NetworkScript, props: PropsScript) -> void:
	"""Draw these works' finds in this network with these props. Builds the pool once."""
	name = "TunnelFindProps"
	_works = works
	_network = network
	_props = props
	for k: int in WorksScript.FOUND_RING:
		var piece := MeshInstance3D.new()
		piece.visible = false
		add_child(piece)
		_pieces.append(piece)


func set_underground_view(on: bool) -> void:
	"""Finds show in the underground view only."""
	_underground = on
	_seen = -1


func refresh() -> void:
	"""Redraw when a find was cut or the view changed."""
	var key: int = _works.found_count * 2 + (1 if _underground else 0)
	if key == _seen:
		return
	_seen = key
	for k: int in WorksScript.FOUND_RING:
		_draw(k)


func _draw(k: int) -> void:
	"""Ring entry `k`: its model at its cut, or hidden."""
	var piece: MeshInstance3D = _pieces[k]
	var model: StringName = &""
	if k < _works.found_count:
		model = FindsScript.model_of(_works.found_kind[k], _works.found_relic[k])
	piece.visible = _underground and model != &""
	if not piece.visible:
		return
	var at := Vector2(Rules.to_m(_works.found_x_u[k]), Rules.to_m(_works.found_z_u[k]))
	piece.mesh = _props.mesh_of(model)
	piece.transform = Transform3D(Basis(Vector3.UP, TURN_PER_FIND * k), Vector3(at.x, floor_y(k, at), at.y)) \
			* _props.fit_of(model)


func floor_y(k: int, at: Vector2) -> float:
	"""The bore floor under ring entry `k`'s cut: its tunnel's, while that tunnel still has a route."""
	var slot: int = _works.found_slot[k]
	if slot < 0 or slot >= _network.point_count.size() or _network.point_count[slot] < 2:
		return -Rules.BORE_FLOOR_DEPTH_M
	return _network.floor_y_at(slot, _network.along_of(slot, at))


func shown_count() -> int:
	"""How many finds are drawn now (tests)."""
	var count: int = 0
	for piece: MeshInstance3D in _pieces:
		count += 1 if piece.visible else 0
	return count
