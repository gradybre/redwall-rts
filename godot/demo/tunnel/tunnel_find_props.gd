extends Node3D
## Finds lying where they were dug. Decision 0196 (live demo). Presentation only.
##
## tunnel_works.gd keeps a ring of the latest FOUND_RING finds -- where each was cut, what it was, and
## for a relic which one. Each lies on the bore floor at its cut as its own library model, on the
## underground layer, so the U view shows it (tunnel_finds.gd model_of: a flint, a lump of clay, an old
## basket for a root store, a bell, a key or a banner); a relic with no model of its own lies there unseen
## (the panel shows its roundel). Redrawn only when a new find is cut -- never for the view (decision 0206).

const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Layers := preload("res://demo/demo_layers.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")

## Each find turns by this much from the last, so a row of them does not line up.
const TURN_PER_FIND: float = 2.3

var _works: WorksScript = null
var _network: GraphScript = null
var _props: PropsScript = null
var _pieces: Array[MeshInstance3D] = []
var _seen: int = -1


func configure(works: WorksScript, network: GraphScript, props: PropsScript) -> void:
	"""Draw these works' finds in this network with these props. Builds the pool once."""
	name = "TunnelFindProps"
	_works = works
	_network = network
	_props = props
	for k: int in WorksScript.FOUND_RING:
		var piece := MeshInstance3D.new()
		piece.layers = Layers.UNDERGROUND
		piece.visible = false
		add_child(piece)
		_pieces.append(piece)


func register(prewarm: PrewarmScript) -> void:
	"""Every find's model, for the underground view's prewarm (decision 0206)."""
	for model: StringName in FindsScript.FIND_MODEL + FindsScript.RELIC_MODEL:
		if model != &"":
			prewarm.add_mesh(_props.mesh_of(model))


func refresh() -> void:
	"""Redraw when a find was cut."""
	if _works.found_count == _seen:
		return
	_seen = _works.found_count
	for k: int in WorksScript.FOUND_RING:
		_draw(k)


func _draw(k: int) -> void:
	"""Ring entry `k`: its model at its cut, or hidden."""
	var piece: MeshInstance3D = _pieces[k]
	var model: StringName = &""
	if k < _works.found_count:
		model = FindsScript.model_of(_works.found_kind[k], _works.found_relic[k])
	piece.visible = model != &""
	if not piece.visible:
		return
	var at := Vector2(Rules.to_m(_works.found_x_u[k]), Rules.to_m(_works.found_z_u[k]))
	piece.mesh = _props.mesh_of(model)
	var y := floor_y(k, at)
	piece.transform = Transform3D(Basis(Vector3.UP, TURN_PER_FIND * k), Vector3(at.x, y, at.y)) * _props.fit_of(model)
	piece.layers = Layers.below(Layers.level_at(y))


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
