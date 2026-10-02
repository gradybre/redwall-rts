extends Node3D
## The foraging trips drawn (decision 0681): a forager carrying its haul home holds the fishery's basket (the props'
## `basket`, staged library art; no new asset) in its hands. Presentation only; one pass over the seat rows a frame, a
## model changed only when it changes (the fishery view's rule).
##
## THE SPOTS (the food art, decision 0941; wired by the batch 8 integration, decision 0903): where it is staged, each
## spot is drawn by its own model beside where the forager stands -- three hazel bushes round the hazel brake, ceps and
## chanterelles in the beech hollow (the woods' own mushroom clusters stay as dressing), the herb patch on the herb
## bank and the blackberry bramble at the bramble edge. Nothing is drawn at a spot whose model is not staged (CI: as
## before). The hazels and the bramble are season trees (season_view.gd OTHER OWNERS' TREES; kind fruit, as the
## orchard's hedge): the bramble's modelled berries hidden as the berry patch runs down and while it is dormant
## (season_leaves.gdshaderinc `berry_hide`), the hazels' nuts left as modelled (brown as their bark: no mask tells
## them apart, measured).

const TripsScript := preload("res://demo/forage/forage_trips.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")

## Each spot's models (see THE SPOTS): its kind (an index into Rules.KINDS), model, offset from the spot (m: x, z),
## yaw and size (a share of the model's prescaled height).
const PIECE_KIND: PackedInt32Array = [0, 0, 0, 1, 1, 2, 3, 3]
const PIECE_KEY: Array[StringName] = [&"hazel_bush", &"hazel_bush", &"hazel_bush", &"mushroom_forage",
	&"mushroom_forage", &"herb_patch", &"bramble_blackberry", &"bramble_blackberry"]
const PIECE_OFFSET: PackedVector2Array = [Vector2(-2.3, -0.7), Vector2(1.9, -1.5), Vector2(0.4, 2.3), Vector2(1.0, 0.7),
	Vector2(-0.9, -0.8), Vector2(1.5, 0.3), Vector2(1.3, -0.6), Vector2(-1.1, 1.0)]
const PIECE_YAW: PackedFloat32Array = [0.4, 2.1, 4.0, 0.0, 2.6, 1.1, 0.7, 3.3]
const PIECE_SIZE: PackedFloat32Array = [1.0, 0.85, 1.1, 1.0, 0.8, 1.0, 1.0, 0.85]
## The bramble's leaf colour, painted over its hidden berries (orchard_view.gd BUSH_LEAF's, the same model).
const BRAMBLE_LEAF: Color = Color(0.051, 0.105, 0.025)
const PARAM_BERRY_HIDE: StringName = &"berry_hide"
const BERRIES: int = 3

var _trips: TripsScript = null
var _props: PropsScript = null
## What each resident holds for the trips (&"": nothing), and which carry a haul this frame.
var _held: Array[StringName] = []
var _carrying: PackedByteArray = PackedByteArray()
## The spots' models drawn (THE SPOTS), each piece's index into the PIECE_ tables, and its season slot's revision.
var _pieces: Array[Node3D] = []
var _piece_of: PackedInt32Array = PackedInt32Array()
var _season_revision: int = 0


func configure(trips: TripsScript, props: PropsScript, residents: int) -> void:
	"""Draw these trips with these props for `residents` residents."""
	name = "ForageView"
	_trips = trips
	_props = props
	_held.resize(residents)
	_held.fill(&"")
	_carrying.resize(residents)


func refresh() -> void:
	"""Each seat's forager holds what the trips say it carries; one who held a basket and no longer carries drops it.
	One pass over the seat rows and one over the residents, flags in a column sized once (no allocation a frame)."""
	if _trips == null or _props == null:
		return
	_carrying.fill(0)
	for j: int in Rules.MAX_JOBS:
		var who: int = _trips.j_worker[j]
		if _trips.j_live[j] == 1 and who >= 0 and who < _held.size() and _trips.held_key_of_job(j) != &"":
			_carrying[who] = 1
	for who: int in _held.size():
		_show_held(who, TripsScript.BASKET_KEY if _carrying[who] == 1 else &"")


func _show_held(who: int, key: StringName) -> void:
	"""Resident `who` holds the model `key` (&"": nothing)."""
	if _held[who] == key:
		return
	var actor: DemoActorScript = _trips.cast_actor(who)
	if key == &"":
		actor.drop_held()
	else:
		var bound: AABB = _props.drawn_bound(key)
		actor.hold(_props.mesh_of(key), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key))
	_held[who] = key


func place_spots(make: Callable, staged: Callable, at: PackedVector2Array) -> int:
	"""Draw each spot's models (THE SPOTS) with the world's `make(key, at, yaw, size) -> Node3D`, those `staged(key)`
	says the world has, beside the spots `at` (the trips' snapped ones, by kind). Returns how many were drawn."""
	for k: int in PIECE_KEY.size():
		if PIECE_KIND[k] >= at.size() or not staged.is_valid() or not bool(staged.call(PIECE_KEY[k])):
			continue
		var node: Node3D = make.call(PIECE_KEY[k], at[PIECE_KIND[k]] + PIECE_OFFSET[k], PIECE_YAW[k], PIECE_SIZE[k])
		if node == null:
			continue
		add_child(node)
		_pieces.append(node)
		_piece_of.append(k)
	_season_revision += 1
	return _pieces.size()


func show_berries(share: float) -> void:
	"""The bramble's modelled berries shown at `share` (0..1: the berry patch above its floor; 0 while dormant)."""
	for p: int in _pieces.size():
		if PIECE_KIND[_piece_of[p]] == BERRIES:
			_write(_pieces[p], PARAM_BERRY_HIDE, Color(BRAMBLE_LEAF.r, BRAMBLE_LEAF.g, BRAMBLE_LEAF.b, 1.0 - share))


static func _write(node: Node, param: StringName, value: Color) -> void:
	"""An instance parameter on every mesh at or under `node`."""
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).set_instance_shader_parameter(param, value)
	for child: Node in node.get_children():
		_write(child, param, value)


func piece_count() -> int:
	"""How many spot models are drawn (checks)."""
	return _pieces.size()


# --- the season's trees (season_view.gd OTHER OWNERS' TREES): the hazels and the bramble -----------------------------

func season_tree_count() -> int:
	"""Every spot model (the ground cover ones answer no node: the season leaves them)."""
	return _pieces.size()


func season_tree_node(i: int) -> Node3D:
	"""Piece `i`'s node, when it is a bush (the mushrooms and herbs are not season trees)."""
	var key: StringName = PIECE_KEY[_piece_of[i]]
	return _pieces[i] if key == &"hazel_bush" or key == &"bramble_blackberry" else null


func season_tree_kind(_i: int) -> int:
	"""Fruiting bushes, as the orchard's hedge (season_look.gd KIND_FRUIT)."""
	return LookScript.KIND_FRUIT


func season_tree_at(i: int) -> Vector2:
	"""Where piece `i` stands (its own pace through the seasons)."""
	return Vector2(_pieces[i].position.x, _pieces[i].position.z)


func season_trees_revision() -> int:
	"""Bumped when the spots are drawn."""
	return _season_revision


func holding(who: int) -> StringName:
	"""What resident `who` holds for the trips (&"": nothing; the checks)."""
	return _held[who] if who >= 0 and who < _held.size() else &""
