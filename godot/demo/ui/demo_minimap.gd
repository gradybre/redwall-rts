extends Control
## THE VILLAGE MAP, drawn in the HUD's minimap (UI-SET-021's view). Decision 0251 (review group E, finding F14).
## Presentation only: it reads the authored layout, the water, the woods, the tunnels, the bridges, the cast and
## the camera, and writes nothing but the camera's focus when the player clicks it.
##
## THE PROBLEM. The shell's minimap reads the settlement's generated-world session, which the demo never creates,
## so it said "No world generated" over a clearly visible village.
##
## WHAT IT DRAWS, north up (the camera's home view faces north, -Z), on a square of the village that takes in
## everything the camera may look at (`map_rect_for`, the camera's bounds plus MARGIN_M):
##   the meadow, the stream and pond (the water map's own capsules), the worn paths, the crop beds, the buildings
##   (their footprints turned as they stand), the water-side buildings, the trees still standing, the dug tunnels,
##   their mouths (ink rings), burrow homes (clay) and root cellars (flint), and the bridges (brass; thin while
##   only planned) -- then, over that, the camera's view on the ground (its four corner rays) and every resident as
##   a dot in its party-panel colour (hollow while underground, ringed brass when selected).
##
## CHEAP. Two child canvas items. The BASE is drawn once and again only when the tunnels, the bridges or the woods
## change (their revision counters, compared each frame); Godot keeps its draw list, so an unchanged map costs
## nothing. The MARKS redraw every frame: four rays, a polyline into a reused array and one circle per resident --
## no node, array or string is made per frame.
##
## A CLICK or a drag on the map centres the camera there (demo_camera.gd `centre_on`); the map takes the event,
## so the shell's tile picker (a settlement tile) never sees it.

const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## Ground kept round the camera's bounds, so nothing it can see sits on the map's edge.
const MARGIN_M: float = 2.0
## How far a view ray that never meets the ground (above the horizon) is followed.
const FAR_M: float = 200.0
const MEADOW: Color = Color("#7E9166")
const PATH: Color = Color("#CDB98E")
const WATER: Color = Color("#4F6E8F")
const BED: Color = Color("#6B5236")
const ROOF: Color = Palette.TIMBER
const TREE: Color = Color("#3A5A3D")
const TUNNEL: Color = Palette.UMBER
const VIEW: Color = Palette.CREAM
const DOT_EDGE: Color = Palette.INK
const DOT_PX: float = 3.5
const TREE_M: float = 0.9
## The six beds stand edge to edge; drawn this much narrower, each reads as its own bed.
const BED_GAP_M: float = 0.5
const TUNNEL_PX: float = 2.0
const DESCRIPTION: String = "Village map, north up: paths, buildings, crop beds, the stream and pond, trees, " \
		+ "tunnels (brown) with their mouths (dark rings), burrow homes (clay), root cellars (grey), bridges (brass), " \
		+ "the camera's view (the pale frame) and residents (coloured dots, hollow underground). Click or drag to " \
		+ "move the camera there."

var world_rect: Rect2 = Rect2(-20.0, -20.0, 40.0, 40.0)
var _cast: DemoCastScript = null
var _rig: CameraScript = null
var _command: CommandScript = null
var _water: WaterMapScript = null
var _network: GraphScript = null
var _bridges: BridgesScript = null
var _stand: StandScript = null
var _base: Control = null
var _marks: Control = null
var _seen: PackedInt32Array = PackedInt32Array([-1, -1, -1])
var _quad: PackedVector2Array = PackedVector2Array()
## Per-frame scratch, written in place (see CHEAP).
var _dot: Vector2 = Vector2.ZERO
var _corner: Vector2 = Vector2.ZERO
var _ground: Vector2 = Vector2.ZERO


func _init() -> void:
	"""The base and the marks, filling this control; the marks take the mouse."""
	name = "DemoVillageMap"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_quad.resize(5)
	_base = _layer("Base", Control.MOUSE_FILTER_IGNORE, _draw_base)
	_marks = _layer("Marks", Control.MOUSE_FILTER_STOP, _draw_marks)
	_marks.gui_input.connect(_on_marks_input)
	_marks.tooltip_text = DESCRIPTION
	_marks.accessibility_description = DESCRIPTION


func _layer(layer_name: String, filter: Control.MouseFilter, painter: Callable) -> Control:
	"""One full-size child canvas item drawn by `painter`."""
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = filter
	layer.draw.connect(painter)
	add_child(layer)
	return layer


func configure(cast: DemoCastScript, rig: CameraScript, command: CommandScript, water: WaterMapScript) -> void:
	"""Map the village the camera may look at, with these residents, this selection and this water."""
	_cast = cast
	_rig = rig
	_command = command
	_water = water
	if rig != null:
		world_rect = map_rect_for(rig.bounds(), MARGIN_M)
	_base.queue_redraw()


func watch(network: GraphScript, bridges: BridgesScript, stand: StandScript) -> void:
	"""Also draw the tunnels and homes, the bridges and the standing trees (any may be null), redrawn on a change."""
	_network = network
	_bridges = bridges
	_stand = stand
	_base.queue_redraw()


# --- the transforms (pure; test_demo_hud_truth.gd) -------------------------------------------------

static func map_rect_for(bounds: AABB, margin_m: float) -> Rect2:
	"""The square of ground (x, z) the map shows: centred on `bounds`' x/z extent, as wide as its longer side
	plus `margin_m` all round."""
	var side: float = maxf(bounds.size.x, bounds.size.z) + 2.0 * margin_m
	var centre := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.z + bounds.size.z * 0.5)
	return Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side))


static func world_to_map(p: Vector2, world: Rect2, map_size: Vector2) -> Vector2:
	"""A ground point (x, z) as a point on a map of `map_size` px showing `world`: north (-z) up, east right."""
	return Vector2((p.x - world.position.x) / world.size.x * map_size.x,
		(p.y - world.position.y) / world.size.y * map_size.y)


static func map_to_world(m: Vector2, world: Rect2, map_size: Vector2) -> Vector2:
	"""A point on the map back to the ground (x, z) it shows (the inverse of `world_to_map`)."""
	return Vector2(world.position.x + m.x / map_size.x * world.size.x, world.position.y + m.y / map_size.y * world.size.y)


static func ground_hit(origin: Vector3, direction: Vector3) -> Vector2:
	"""Where a view ray meets the ground (y = 0), as (x, z); a ray that never does is followed FAR_M (one from below
	the ground stops where it starts)."""
	var t: float = -origin.y / direction.y if direction.y < 0.0 else FAR_M
	t = clampf(t, 0.0, FAR_M)
	return Vector2(origin.x + direction.x * t, origin.z + direction.z * t)


func _px(p: Vector2) -> Vector2:
	"""A ground point on this map, in its pixels."""
	return world_to_map(p, world_rect, size)


func _m_px(metres: float) -> float:
	"""A length on the ground, in this map's pixels."""
	return metres / world_rect.size.x * size.x


# --- per frame --------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Redraw the base when the tunnels, bridges or woods changed; the marks every frame while shown."""
	if not is_visible_in_tree():
		return
	var tunnels: int = _network.revision if _network != null else -1
	var bridges: int = _bridges.revision if _bridges != null else -1
	var woods: int = _stand.revision if _stand != null else -1
	if tunnels != _seen[0] or bridges != _seen[1] or woods != _seen[2]:
		_seen[0] = tunnels
		_seen[1] = bridges
		_seen[2] = woods
		_base.queue_redraw()
	_marks.queue_redraw()


func _notification(what: int) -> void:
	"""A new size redraws the base (its draw list is in pixels)."""
	if what == NOTIFICATION_RESIZED and _base != null:
		_base.queue_redraw()


func _on_marks_input(event: InputEvent) -> void:
	"""A left click, or a left drag, centres the camera on that ground; the map takes the event."""
	var at: Vector2 = Vector2.ZERO
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		at = button.position
	elif motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = motion.position
	else:
		return
	centre_camera_at(at)
	if _marks.is_inside_tree():
		_marks.accept_event()


func centre_camera_at(map_point: Vector2) -> Vector2:
	"""Centre the camera on the ground under `map_point` (px on this map); returns that ground point (x, z)."""
	var ground: Vector2 = map_to_world(map_point, world_rect, size)
	if _rig != null:
		_rig.centre_on(Vector3(ground.x, 0.0, ground.y))
	return ground


# --- the marks: the camera's view and the residents ---------------------------------------------------

func _draw_marks() -> void:
	"""The camera's view on the ground, then a dot per resident (cached vectors, written in place)."""
	if _rig != null and _rig.camera() != null and _rig.camera().is_inside_tree():
		view_quad_into(_rig.camera(), _quad)
		_marks.draw_polyline(_quad, VIEW, 1.5, true)
	if _cast == null:
		return
	for i: int in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		# world_to_map inline, into a cached vector (tested against it: test_demo_hud_truth.gd).
		_dot.x = (actor.brain.position.x - world_rect.position.x) / world_rect.size.x * size.x
		_dot.y = (actor.brain.position.y - world_rect.position.y) / world_rect.size.y * size.y
		if _command != null and _command.is_selected(i):
			_marks.draw_circle(_dot, DOT_PX + 2.5, Palette.BRASS, true, -1.0, true)
		_marks.draw_circle(_dot, DOT_PX + 1.0, DOT_EDGE, true, -1.0, true)
		if actor.brain.underground:
			_marks.draw_circle(_dot, DOT_PX, actor.chip_colour, false, 1.5, true)
		else:
			_marks.draw_circle(_dot, DOT_PX, actor.chip_colour, true, -1.0, true)


func view_quad_into(camera: Camera3D, out: PackedVector2Array) -> void:
	"""The camera's view on the ground as a closed quad on this map (5 points, the first repeated), into `out`:
	each screen corner's ray to the ground (`ground_hit`), written into cached vectors."""
	var screen: Vector2 = camera.get_viewport().get_visible_rect().size
	for k: int in 4:
		_corner.x = screen.x if k == 1 or k == 2 else 0.0
		_corner.y = screen.y if k >= 2 else 0.0
		_ground = ground_hit(camera.project_ray_origin(_corner), camera.project_ray_normal(_corner))
		out[k] = world_to_map(_ground, world_rect, size)
	out[4] = out[0]


# --- the base: the village as it lies ------------------------------------------------------------------

func _draw_base() -> void:
	"""Everything that stays put between changes (see WHAT IT DRAWS), bottom up."""
	_base.draw_rect(Rect2(Vector2.ZERO, size), MEADOW)
	_draw_water()
	for k: int in Layout.PATH_SEGMENTS.size():
		var seg: Vector4 = Layout.PATH_SEGMENTS[k]
		_capsule(Vector2(seg.x, seg.y), Vector2(seg.z, seg.w), Layout.PATH_RADII[k], Layout.PATH_RADII[k], PATH)
	for entry: Dictionary in Layout.CROPS:
		_footprint(Layout.normalised(entry), Sizes.CROP_BED_WIDTH_M - BED_GAP_M, BED)
	for entry: Dictionary in Layout.BUILDINGS:
		_footprint(Layout.normalised(entry), 0.0, ROOF)
	for circle: Vector3 in WaterDressing.footprint_circles():
		_base.draw_circle(_px(Vector2(circle.x, circle.y)), _m_px(circle.z), ROOF)
	_draw_trees()
	_draw_tunnels()
	_draw_rooms()
	_draw_bridges()


func _draw_water() -> void:
	"""The stream and the pond: every capsule of the water map, as it is measured."""
	if _water == null:
		return
	for i: int in _water.segment_count():
		var seg: PackedInt32Array = _water.segment(i)
		_capsule(Vector2(Rules.to_m(seg[0]), Rules.to_m(seg[1])), Vector2(Rules.to_m(seg[2]), Rules.to_m(seg[3])),
			Rules.to_m(seg[4]), Rules.to_m(seg[5]), WATER)


func _capsule(a: Vector2, b: Vector2, radius_a: float, radius_b: float, colour: Color) -> void:
	"""A tapered capsule from `a` (radius_a) to `b` (radius_b), in metres: two discs and the band between."""
	var pa: Vector2 = _px(a)
	var pb: Vector2 = _px(b)
	_base.draw_circle(pa, _m_px(radius_a), colour)
	_base.draw_circle(pb, _m_px(radius_b), colour)
	if pa.is_equal_approx(pb):
		return
	var side: Vector2 = (pb - pa).orthogonal().normalized()
	_base.draw_colored_polygon(PackedVector2Array([pa + side * _m_px(radius_a), pb + side * _m_px(radius_b),
		pb - side * _m_px(radius_b), pa - side * _m_px(radius_a)]), colour)


func _footprint(p: Dictionary, square_m: float, colour: Color) -> void:
	"""A placement's footprint turned as it stands: its model's rectangle, or a `square_m` square (a crop bed)."""
	var rect := Rect2(Vector2(-square_m, -square_m) * 0.5, Vector2(square_m, square_m))
	if square_m <= 0.0:
		rect = Sizes.scaled_rect(p["key"], p["size"])
	var corners := PackedVector2Array()
	for local: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		corners.append(_px((p["at"] as Vector2) + Layout.rotate_xz(local, p["yaw"])))
	_base.draw_colored_polygon(corners, colour)


func _draw_trees() -> void:
	"""Every tree standing now (mature or young), a dark disc; a stump or cleared ground draws nothing."""
	if _stand == null:
		return
	for t: int in _stand.count():
		var state: int = _stand.state_of(t)
		if state == StandScript.STATE_MATURE or state == StandScript.STATE_YOUNG:
			_base.draw_circle(_px(_stand.at[t]), _m_px(TREE_M if state == StandScript.STATE_MATURE else TREE_M * 0.5), TREE)


func _draw_tunnels() -> void:
	"""Every tunnel dug open, along its route; every mouth a dark ring."""
	if _network == null:
		return
	for slot: int in Rules.MAX_SEGMENTS:
		if not _network.is_open(slot) or _network.seg_room[slot] >= 0:
			continue
		var base: int = slot * Rules.MAX_POINTS
		for k: int in range(1, _network.point_count[slot]):
			_base.draw_line(_px(_route_m(base + k - 1)), _px(_route_m(base + k)), TUNNEL, TUNNEL_PX, true)
	for node: int in Rules.MAX_NODES:
		if _network.node_kind[node] == GraphScript.NODE_MOUTH:
			_base.draw_arc(_px(_network.node_m(node)), 3.0, 0.0, TAU, 12, DOT_EDGE, 1.5, true)


func _route_m(point: int) -> Vector2:
	"""A tunnel route's point (the graph's flat columns), in metres."""
	return Vector2(Rules.to_m(_network.points_u[2 * point]), Rules.to_m(_network.points_u[2 * point + 1]))


func _draw_rooms() -> void:
	"""Every dug room at its centre: a burrow home a clay disc, a root cellar a grey square."""
	if _network == null:
		return
	var rooms: RoomsScript = _network.rooms
	for r: int in RoomsScript.MAX_ROOMS:
		if not rooms.is_done(_network, r):
			continue
		var at: Vector2 = _px(rooms.centre_m(r))
		if rooms.template[r] == RoomsScript.TEMPLATE_HOME:
			_base.draw_circle(at, 4.5, Palette.CLAY)
			_base.draw_arc(at, 4.5, 0.0, TAU, 16, DOT_EDGE, 1.0, true)
		else:
			_base.draw_rect(Rect2(at - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), Palette.FLINT)


func _draw_bridges() -> void:
	"""Every bridge across the water, bank to bank: brass when open, a thin line while only planned."""
	if _bridges == null:
		return
	for row: int in BridgesScript.MAX_BRIDGES:
		if _bridges.is_open(row) or _bridges.is_planned(row):
			var open: bool = _bridges.is_open(row)
			_base.draw_line(_px(_bridges.shore_a[row]), _px(_bridges.shore_b[row]), Palette.BRASS, 3.0 if open else 1.0, true)
