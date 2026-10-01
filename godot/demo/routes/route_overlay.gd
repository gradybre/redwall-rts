extends Node3D
## The "Getting there: Routes" map layer: how the selected residents will get where they are going, stretch by stretch,
## and what holds each up and where -- or, with nobody selected, the village's PUBLIC WAYS to its work places and the
## optional shortcuts beside them (review P5's route overlay, ECO-039). Decision 0461. Presentation only: it draws what
## the brains' own routes (resident_brain.gd `path`, `path_tunnel`) and the public estimate (route_estimator.gd) say.
##
## STRETCHES (route_kinds.gd), one ribbon each, coloured by kind and named in the layer's legend: surface, wading (the
## ford), underground (dashed; the level labelled where it goes below), a bridge, swimming, by boat (a crew member
## aboard: the boat's own course, route_kinds.gd BOAT LEGS), the proposed bridge. A group shows EACH MEMBER's own route
## (MOVE-REQ-012: never the lead's for all).
## THE BLOCKING POINT (route_reasons.gd): a post where the reason applies, and its words beside it -- "Wenna Tallowby:
## waiting for mouth" (a wait that ends by itself: brass), "Badger quarryman: load too wide" (clay).
## PUBLIC WAYS: a thin ribbon from the square to each work district for the public walker (carrying, never swimming),
## labelled with its walking time; a narrow body's tunnel shortcut, where its route goes below and the public way does
## not, as a second, fainter ribbon marked optional; and the SWIM LINKS (water_links.gd) as dashed blue bars, labelled
## once as optional crossings for swimmers. Nobody is ever sent to swim by it.
##
## REDRAWN ONLY ON CHANGE, AT MOST A FEW TIMES A SECOND: every REDRAW_S (at once after a new subject or switch) a
## cheap signature of what is drawn (per member its state, waypoint, route size and reason; whether the public estimate
## is done) is compared, and the ribbons are rebuilt only when it moved -- without slicing a route or making an array
## per vertex.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const KindsScript := preload("res://demo/routes/route_kinds.gd")
const ReasonsScript := preload("res://demo/routes/route_reasons.gd")
const EstimatorScript := preload("res://demo/routes/route_estimator.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## Each kind's colour (route_kinds.gd KIND_*): surface, wading, underground, bridge, swimming, by boat, new bridge.
const KIND_COLOURS: Array[Color] = [Color("#F5F0DF"), Color("#E8C64A"), Color("#B88A5A"), Color("#E08A3C"),
	Color("#5BB2E8"), Color("#6F8FD8"), Color("#F2B35C")]
const WAIT_COLOUR: Color = Palette.BRASS
const BLOCK_COLOUR: Color = Palette.CLAY
const PUBLIC_COLOUR: Color = Color(0.96, 0.94, 0.87, 0.75)
const ROUTE_WIDTH_M: float = 0.22
const PUBLIC_WIDTH_M: float = 0.1
const LIFT_M: float = 0.07
const DASH_M: float = 0.5
const MAX_MARKS: int = 16
const LABEL_HEIGHT_M: float = 1.8
const LABEL_FONT_SIZE: int = 24
const LABEL_PIXEL_SIZE: float = 0.00045
const LABEL_OUTLINE: int = 8
const LABEL_RENDER_PRIORITY: int = 40
## How often the signature is looked at (see REDRAWN ONLY ON CHANGE).
const REDRAW_S: float = 0.25
const SWIM_LABEL: String = "Swim links: optional shortcuts for swimmers — nobody is made to swim"

var kinds: KindsScript = KindsScript.new()
## Whom it draws for (cast indices; empty: the public ways).
var members: PackedInt32Array = PackedInt32Array()
## The public ways' estimate (route_estimator.gd, PROPOSE_NONE) and, per district trip, its shortcut's (or null).
var public_estimate: EstimatorScript = null
var shortcut_estimate: EstimatorScript = null
## `(k: int) -> String`: the label for public way `k`, and `(k: int) -> bool`: whether it has a shortcut beside it
## (demo_routes.gd).
var public_label: Callable = Callable()
var public_shortcut: Callable = Callable()
## The swim links' land ends (a pair each), drawn with the public ways (see PUBLIC WAYS).
var swim_a: PackedVector2Array = PackedVector2Array()
var swim_b: PackedVector2Array = PackedVector2Array()
## How many times the ribbons were rebuilt (checks: never per frame unchanged).
var rebuilds: int = 0

var _cast: DemoCastScript = null
var _graph: GraphScript = null
var _mesh: ImmediateMesh = ImmediateMesh.new()
var _ribbons: MeshInstance3D = null
var _labels: Array[Label3D] = []
var _posts: Array[MeshInstance3D] = []
var _shown: bool = false
var _signature: int = 0
var _kinds: PackedInt32Array = PackedInt32Array()
var _levels: PackedInt32Array = PackedInt32Array()
var _where: ReasonsScript.Where = ReasonsScript.Where.new()
var _boat_leg: PackedVector2Array = PackedVector2Array()
var _used_labels: int = 0
var _used_posts: int = 0
var _since: float = 0.0


func configure(cast: DemoCastScript, graph: GraphScript, route_kinds: KindsScript) -> void:
	"""Draw this cast's routes over this network, its stretches read by `route_kinds`."""
	name = "RouteOverlay"
	_cast = cast
	_graph = graph
	kinds = route_kinds
	_ribbons = MeshInstance3D.new()
	_ribbons.mesh = _mesh
	_ribbons.layers = Layers.SURFACE_MARKS
	_ribbons.material_override = _ribbon_material()
	add_child(_ribbons)
	for k: int in MAX_MARKS:
		_labels.append(_label())
		_posts.append(_post())
	visible = false


static func _ribbon_material() -> StandardMaterial3D:
	"""Unshaded vertex colour, drawn over the ground and everything on it."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = LABEL_RENDER_PRIORITY - 2
	return material


func _label() -> Label3D:
	"""A pooled billboard label, hidden."""
	var label := Label3D.new()
	label.layers = Layers.SURFACE_MARKS
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL_SIZE
	label.font_size = LABEL_FONT_SIZE
	label.outline_size = LABEL_OUTLINE
	label.outline_modulate = Color(0.08, 0.1, 0.08)
	label.render_priority = LABEL_RENDER_PRIORITY
	label.outline_render_priority = LABEL_RENDER_PRIORITY - 1
	label.visible = false
	add_child(label)
	return label


func _post() -> MeshInstance3D:
	"""A pooled post marking a blocking point, hidden."""
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.07
	cylinder.height = 1.4
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.layers = Layers.SURFACE_MARKS
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	node.material_override = material
	node.visible = false
	add_child(node)
	return node


func set_swim_links(land_a: PackedVector2Array, land_b: PackedVector2Array) -> void:
	"""The swim links to draw with the public ways (land end to land end)."""
	swim_a = land_a
	swim_b = land_b
	_signature = 0


func set_shown(on: bool) -> void:
	"""The layer's switch (map_lenses.gd)."""
	_shown = on
	visible = on
	_signature = 0


func is_shown() -> bool:
	"""Whether the layer is on."""
	return _shown


func follow(selected: PackedInt32Array) -> void:
	"""Draw for these residents (none: the public ways)."""
	if selected != members:
		members = selected
		_signature = 0


func _process(delta: float) -> void:
	"""Rebuild the ribbons when what they show moved (see REDRAWN ONLY ON CHANGE)."""
	if not _shown or _cast == null:
		return
	_since += delta
	if _signature != 0 and _since < REDRAW_S:
		return
	_since = 0.0
	var now: int = signature()
	if now == _signature:
		return
	_signature = now
	redraw()


func signature() -> int:
	"""A cheap fingerprint of what is drawn (see REDRAWN ONLY ON CHANGE)."""
	var h: int = 17 + members.size()
	for who: int in members:
		var brain: BrainScript = brain_of(who)
		var why: int = ReasonsScript.diagnose(brain, _graph, _where)
		h = h * 31 + brain.state * 7 + brain.path_index * 131 + brain.path.size() * 8191 + why * 524287
		h = h * 31 + roundi(_where.at.x * 10.0) * 3 + roundi(_where.at.y * 10.0) * 5 + brain.trip_outcome
		if kinds.boat_leg_into(who, _boat_leg):
			h = h * 31 + roundi(_boat_leg[0].x * 10.0) * 7 + roundi(_boat_leg[0].y * 10.0) * 11 + _boat_leg.size()
	if members.is_empty() and public_estimate != null:
		h = h * 31 + int(public_estimate.is_done()) + public_estimate.restarts * 1009
		if shortcut_estimate != null:
			h = h * 31 + int(shortcut_estimate.is_done()) + shortcut_estimate.restarts * 1009
	return h if h != 0 else 1


func redraw() -> void:
	"""Every ribbon, post and label afresh."""
	rebuilds += 1
	_mesh.clear_surfaces()
	_used_labels = 0
	_used_posts = 0
	for post: MeshInstance3D in _posts:
		post.visible = false
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var any: bool = false
	if members.is_empty():
		any = _draw_public()
	else:
		for k: int in members.size():
			any = _draw_member(members[k], k) or any
	if not any:
		_quad(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Color(0, 0, 0, 0))
	_mesh.surface_end()
	for k: int in range(_used_labels, _labels.size()):
		_labels[k].visible = false


func _draw_member(who: int, k: int) -> bool:
	"""One member's route from where it is on, and its blocking point; true when anything was drawn."""
	var brain: BrainScript = brain_of(who)
	var why: int = ReasonsScript.diagnose(brain, _graph, _where)
	var drew: bool = false
	if kinds.boat_leg_into(who, _boat_leg):
		var colour: Color = KIND_COLOURS[KindsScript.KIND_BOAT]
		for p: int in range(1, _boat_leg.size()):
			_strip(_boat_leg[p - 1], _boat_leg[p], ROUTE_WIDTH_M, colour)
		drew = true
	elif brain.trip_outcome == BrainScript.TRIP_UNDERWAY and brain.path_index < brain.path.size():
		_ribbon_route(brain.position, brain.path, brain.path_tunnel, brain.path_index, ROUTE_WIDTH_M, 1.0)
		drew = true
	if why != ReasonsScript.NONE and k < MAX_MARKS:
		_mark(_where.at, "%s: %s" % [name_of(who), ReasonsScript.WORDS[why]], ReasonsScript.WAITS[why])
		drew = true
	return drew


func _draw_public() -> bool:
	"""The public ways and their shortcuts (see PUBLIC WAYS)."""
	if public_estimate == null:
		return false
	var drew: bool = false
	for k: int in public_estimate.trip_count:
		if public_estimate.before_known[k] == 0 or public_estimate.before_paths[k].is_empty():
			continue
		_ribbon_route(public_estimate.trip_from[k], public_estimate.before_paths[k], public_estimate.before_legs[k], 0,
			PUBLIC_WIDTH_M, 0.85)
		drew = true
		if public_label.is_valid() and _used_labels < _labels.size():
			_place_label(public_estimate.trip_to[k], String(public_label.call(k)), PUBLIC_COLOUR)
		if shortcut_estimate != null and public_shortcut.is_valid() and bool(public_shortcut.call(k)):
			_ribbon_route(shortcut_estimate.trip_from[k], shortcut_estimate.before_paths[k],
				shortcut_estimate.before_legs[k], 0, PUBLIC_WIDTH_M * 0.7, 0.6)
	return _draw_swim_links() or drew


func _draw_swim_links() -> bool:
	"""Each swim link as a dashed blue bar, and one label for them all (see PUBLIC WAYS)."""
	var colour: Color = KIND_COLOURS[KindsScript.KIND_SWIM]
	colour.a = 0.7
	for k: int in mini(swim_a.size(), swim_b.size()):
		_dashed(swim_a[k], swim_b[k], PUBLIC_WIDTH_M, colour)
	if swim_a.is_empty():
		return false
	_place_label(swim_a[0], SWIM_LABEL, colour.lightened(0.3))
	return true


func _ribbon_route(from: Vector2, path: PackedVector2Array, legs: PackedInt32Array, first: int, width: float,
		alpha: float) -> void:
	"""A route's stretches from waypoint `first` on as ribbons coloured by kind; underground dashed, its level labelled
	where it goes below."""
	kinds.kinds_into(_graph, from, path, legs, _kinds, _levels, first)
	var at := from
	for k: int in _kinds.size():
		var to: Vector2 = path[first + k]
		var colour: Color = KIND_COLOURS[_kinds[k]]
		colour.a = alpha
		if _kinds[k] == KindsScript.KIND_UNDERGROUND:
			_dashed(at, to, width, colour)
			if (k == 0 or _kinds[k - 1] != KindsScript.KIND_UNDERGROUND) and _used_labels < _labels.size():
				_place_label(at, "below, %s" % KindsScript.run_word(_kinds[k], _levels[k]).trim_prefix("underground, "), colour)
		else:
			_strip(at, to, width, colour)
		at = to


func _strip(a: Vector2, b: Vector2, width: float, colour: Color) -> void:
	"""One flat ribbon a -> b."""
	if a.distance_squared_to(b) < 1e-6:
		return
	var side: Vector2 = (b - a).normalized().orthogonal() * width * 0.5
	var ya: float = ground_y(a) + LIFT_M
	var yb: float = ground_y(b) + LIFT_M
	_quad(Vector3(a.x + side.x, ya, a.y + side.y), Vector3(a.x - side.x, ya, a.y - side.y),
		Vector3(b.x - side.x, yb, b.y - side.y), Vector3(b.x + side.x, yb, b.y + side.y), colour)


func _dashed(a: Vector2, b: Vector2, width: float, colour: Color) -> void:
	"""A dashed ribbon a -> b (underground: the plan view of a walk below)."""
	var length: float = a.distance_to(b)
	var dashes: int = maxi(1, floori(length / (2.0 * DASH_M)))
	for d: int in dashes:
		var t0: float = float(d) / float(dashes)
		var t1: float = t0 + 0.5 / float(dashes)
		_strip(a.lerp(b, t0), a.lerp(b, t1), width, colour)


func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, colour: Color) -> void:
	"""Two triangles (p0 p1 p2, p0 p2 p3), each vertex written as it is."""
	_vertex(p0, colour)
	_vertex(p1, colour)
	_vertex(p2, colour)
	_vertex(p0, colour)
	_vertex(p2, colour)
	_vertex(p3, colour)


func _vertex(p: Vector3, colour: Color) -> void:
	"""One coloured vertex."""
	_mesh.surface_set_color(colour)
	_mesh.surface_add_vertex(p)


func _mark(at: Vector2, words: String, waits: bool) -> void:
	"""A post and its words where a route is held up."""
	var colour: Color = WAIT_COLOUR if waits else BLOCK_COLOUR
	if _used_posts >= _posts.size():
		return
	var post: MeshInstance3D = _posts[_used_posts]
	_used_posts += 1
	post.position = Vector3(at.x, ground_y(at) + 0.7, at.y)
	(post.material_override as StandardMaterial3D).albedo_color = colour
	post.visible = true
	_place_label(at, words, colour.lightened(0.35))


func _place_label(at: Vector2, words: String, colour: Color) -> void:
	"""The next pooled label, at `at`."""
	if _used_labels >= _labels.size():
		return
	var label: Label3D = _labels[_used_labels]
	label.text = words
	label.modulate = colour
	label.position = Vector3(at.x, ground_y(at) + LABEL_HEIGHT_M, at.y)
	label.visible = true
	_used_labels += 1


func label_texts() -> PackedStringArray:
	"""The words shown now (checks)."""
	var out := PackedStringArray()
	for k: int in _used_labels:
		out.append(_labels[k].text)
	return out


func ground_y(at: Vector2) -> float:
	"""The ground's height at `at` (the water's carved banks; flat without water)."""
	return _cast.space().crossings.ground_y_m(at) if _cast != null else 0.0


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name
