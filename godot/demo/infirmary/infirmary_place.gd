extends Node3D
## PLACING THE INFIRMARY (decision 0623): the cellar building's placing tool (decision 0612, cellar_place.gd) -- the
## woods' zone tool's pattern for one building, since the HUD's Build is locked: ARMED from the Tunnels panel's
## "Build the infirmary…", a ghost of it follows the pointer over the ground, its front turned toward the square, brass
## where it may stand and clay -- with the reason over it -- where it may not; a left click places it
## (infirmary_project.gd `plan_at`: nothing deducted, REQ-SET-124); Esc or a right click puts the tool away. No key is
## added. Presentation only.
##
## WHERE IT MAY STAND (`refusal_at`, the room tool's site, tunnel_control.gd `room_site`, taken afresh only when its
## `site_key` changes, as the room tool does): inside the village, clear of
## every obstacle, work spot and tunnel mouth, every building, the crop beds and the water (its reach, ProjectsScript
## RADIUS_M, from each), not over a tunnel or a dug room -- a room's ramp, body and walks are the network's segments
## too -- (REACH_U beyond its reach). Its DOOR and its material SITE, where the work is done, must be inside the village
## and clear of obstacles and the water too (POINT_M), or nobody could reach them.

const ProjectsScript := preload("res://demo/infirmary/infirmary_project.gd")
const Rules := preload("res://demo/infirmary/infirmary_rules.gd")
const ViewScript := preload("res://demo/infirmary/infirmary_view.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const DemoPick := preload("res://demo/control/demo_pick.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## Earth kept between it and a bore or a room below (a tunnel's pillar, tunnel_rules.gd PILLAR_U).
const REACH_U: int = TunnelRules.PILLAR_U
const REFUSE_OFF: String = "off the village"
const REFUSE_BLOCKED: String = "something stands there"
const REFUSE_SPOT: String = "on a work spot or a tunnel's mouth"
const REFUSE_BUILDING: String = "too near a building"
const REFUSE_BED: String = "over the crop beds"
const REFUSE_WATER: String = "too near the water"
const REFUSE_TUNNEL: String = "over a tunnel"
const REFUSE_DOOR: String = "its door or its building site would be blocked"
const REFUSE_KEEP: String = "over the care shelf, the herb patch or a field-care spot"
## The room a resident needs at the door and the site (m).
const POINT_M: float = 0.5
const PROMPT: String = "Place the infirmary: click where it should stand · Esc or right-click to stop"
const PLACED: String = "Infirmary planned: wood %s, stone %s and cloth %s to fetch, then %d WU of building"
const REFUSED: String = "Can't place the infirmary here: %s"
const GHOST_ALPHA: float = 0.45

var armed: bool = false
var refusal: String = ""
var centre: Vector2 = Vector2.ZERO

var _projects: ProjectsScript = null
var _site: Callable = Callable()
var _site_key: Callable = Callable()
var _site_seen: Vector2i = Vector2i(-1, -1)
var _site_now: RoomsScript.Site = null
var _network: GraphScript = null
var _camera: Camera3D = null
var _say: Callable = Callable()
var _ghost: Node3D = null
var _words: Label3D = null
var _ok: StandardMaterial3D = null
var _bad: StandardMaterial3D = null
## The care desk's own places it must keep clear of (see `set_keep_clear`), as (x, radius, z) circles in u.
var _keep_u: PackedInt32Array = PackedInt32Array()


func configure(projects: ProjectsScript, site: Callable, site_key: Callable, network: GraphScript, camera: Camera3D,
		props: PropsScript, say: Callable) -> void:
	"""Place the infirmary into `projects`, keeping clear of `site()` (an underground_rooms.gd Site, taken again only when
	`site_key() -> Vector2i` changes) and `network`, picking the ground through `camera`; `say(text)` answers in the
	party panel."""
	name = "InfirmaryPlace"
	_projects = projects
	_site = site
	_site_key = site_key
	_network = network
	_camera = camera
	_say = say
	_build_ghost(props)


func _build_ghost(props: PropsScript) -> void:
	"""The ghost: the infirmary's body (infirmary_view.gd) in brass or clay, see-through, with its words over it."""
	_ok = _see_through(Palette.BRASS)
	_bad = _see_through(Palette.CLAY)
	_ghost = ViewScript.body_node(props)
	_ghost.visible = false
	add_child(_ghost)
	_words = Label3D.new()
	_words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_words.no_depth_test = true
	_words.font_size = 40
	_words.pixel_size = 0.01
	_words.visible = false
	add_child(_words)


static func _see_through(colour: Color) -> StandardMaterial3D:
	"""An unshaded see-through material in `colour`."""
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	made.albedo_color = Color(colour, GHOST_ALPHA)
	return made


func set_keep_clear(points: PackedVector2Array) -> void:
	"""The places it must not cover (the review's H1): the care shelf, the herb patch's spot, the field-care spots and
	the stockpile, each with a resident's room (POINT_M)."""
	_keep_u.clear()
	for p: Vector2 in points:
		_keep_u.append_array([TunnelRules.to_u(p.x), TunnelRules.to_u(POINT_M), TunnelRules.to_u(p.y)])


func arm() -> void:
	"""Take the tool up: the ghost follows the pointer from now on."""
	armed = true
	if _say.is_valid():
		_say.call(PROMPT)


func disarm() -> void:
	"""Put the tool away."""
	armed = false
	_ghost.visible = false
	_words.visible = false


func handle_input(event: InputEvent) -> bool:
	"""While armed: motion moves the ghost, a left press places, Esc or a right press puts the tool away. True when the
	event was taken."""
	if not armed:
		return false
	var motion := event as InputEventMouseMotion
	if motion != null:
		hover(motion.position)
		return false
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		hover(button.position)
		place()
		return true
	var key := event as InputEventKey
	var esc: bool = key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE
	if esc or (button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT):
		disarm()
		return true
	return false


func hover(screen: Vector2) -> void:
	"""Stand the ghost on the ground under a screen point and check it there (no camera: nothing)."""
	if _camera == null:
		return
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	var t: float = DemoPick.ray_ground(origin, direction, 0.0)
	if t < 0.0:
		return
	var at: Vector3 = origin + direction * t
	move_to(Vector2(at.x, at.z))


func move_to(at: Vector2) -> void:
	"""Stand the ghost at `at` (m), its front toward the square, and check it there."""
	centre = at
	refusal = refusal_at(at, current_site(), _network, _projects, _keep_u)
	var yaw: float = face_of(at)
	transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.y))
	ViewScript.paint(_ghost, _ok if refusal.is_empty() else _bad)
	_ghost.visible = armed
	_words.text = Rules.LABEL if refusal.is_empty() else refusal
	_words.modulate = Palette.BRASS if refusal.is_empty() else Palette.CLAY
	_words.position = Vector3(0.0, 6.0, 0.0)
	_words.visible = armed


func current_site() -> RoomsScript.Site:
	"""The site as it stands, taken afresh only when its key changed (the room tool's rule)."""
	var key: Vector2i = _site_key.call() if _site_key.is_valid() else Vector2i(-1, -1)
	if _site_now == null or key != _site_seen or not _site_key.is_valid():
		_site_now = _site.call() as RoomsScript.Site
		_site_seen = key
	return _site_now


func place() -> bool:
	"""Place the infirmary where the ghost stands; the answer is said. False when refused."""
	if not refusal.is_empty():
		_answer(REFUSED % refusal)
		return false
	if not _projects.plan_at(centre, face_of(centre)):
		_answer(REFUSED % ProjectsScript.REFUSE_EXISTS)
		return false
	disarm()
	_answer(PLACED % [ProjectsScript.units_text(Rules.cost_milli(Rules.MAT_WOOD)),
		ProjectsScript.units_text(Rules.cost_milli(Rules.MAT_STONE)), ProjectsScript.units_text(Rules.cost_milli(Rules.MAT_CLOTH)),
		Rules.work_wu()])
	return true


func _answer(text: String) -> void:
	"""Say `text` in the party panel."""
	if _say.is_valid():
		_say.call(text)


static func face_of(at: Vector2) -> float:
	"""The yaw that turns the infirmary at `at` to face the square (the village's middle): its front is +Z."""
	var toward: Vector2 = -at
	return atan2(toward.x, toward.y) if toward.length_squared() > 0.0001 else 0.0


# --- where it may stand (see WHERE IT MAY STAND) --------------------------------------------------------

static func refusal_at(at: Vector2, site: RoomsScript.Site, network: GraphScript, projects: ProjectsScript,
		keep_u: PackedInt32Array = PackedInt32Array()) -> String:
	"""Why the infirmary may not stand at `at` (m), in words ("" when it may)."""
	var c := Vector2i(TunnelRules.to_u(at.x), TunnelRules.to_u(at.y))
	var reach: int = TunnelRules.to_u(ProjectsScript.RADIUS_M)
	var inner := site.bounds_u.grow(-reach)
	if not inner.has_point(c):
		return REFUSE_OFF
	if _near_circle(site.circles_u, c, reach):
		return REFUSE_BLOCKED
	if _near_circle(site.spots_u, c, reach):
		return REFUSE_SPOT
	if _near_circle(site.under_u, c, reach):
		return REFUSE_BUILDING
	if _near_circle(keep_u, c, reach):
		return REFUSE_KEEP
	if _over_bed(site.beds_u, c, reach):
		return REFUSE_BED
	if site.water.is_valid() and bool(site.water.call(c, c, reach)):
		return REFUSE_WATER
	if not _workable(site, ProjectsScript.door_point(at, face_of(at))) \
			or not _workable(site, ProjectsScript.site_point(at, face_of(at))):
		return REFUSE_DOOR
	if projects != null and projects.state != ProjectsScript.STATE_NONE:
		return ProjectsScript.REFUSE_EXISTS
	return _below_refusal(c, reach, network) if network != null else ""


static func _workable(site: RoomsScript.Site, point: Vector2) -> bool:
	"""Whether a resident could stand at `point` to work: inside the village, clear of obstacles and the water."""
	var p := Vector2i(TunnelRules.to_u(point.x), TunnelRules.to_u(point.y))
	var room: int = TunnelRules.to_u(POINT_M)
	if not site.bounds_u.grow(-room).has_point(p) or _near_circle(site.circles_u, p, room):
		return false
	return not (site.water.is_valid() and bool(site.water.call(p, p, room)))


static func _below_refusal(c: Vector2i, reach: int, network: GraphScript) -> String:
	"""Whether a tunnel or a dug room (its segments) lies under the infirmary at `c` (u): its words, else ""."""
	for slot: int in TunnelRules.MAX_SEGMENTS:
		if network.phase[slot] == GraphScript.PHASE_FREE:
			continue
		var a: Vector2i = network.node_at(network.node_a[slot])
		var b: Vector2i = network.node_at(network.node_b[slot])
		if TunnelRules.point_leg_u(c, a, b) < reach + REACH_U:
			return REFUSE_TUNNEL
	return ""


static func _near_circle(circles: PackedInt32Array, c: Vector2i, reach: int) -> bool:
	"""Whether any circle (x, radius, z in u) comes within `reach` of `c`."""
	for k: int in range(0, circles.size(), 3):
		var d := Vector2(circles[k] - c.x, circles[k + 2] - c.y)
		if d.length() < float(circles[k + 1] + reach):
			return true
	return false


static func _over_bed(beds: PackedInt32Array, c: Vector2i, reach: int) -> bool:
	"""Whether a bed (x, half-width, z in u; a square) comes within `reach` of `c`."""
	for k: int in range(0, beds.size(), 3):
		if absi(beds[k] - c.x) < beds[k + 1] + reach and absi(beds[k + 2] - c.y) < beds[k + 1] + reach:
			return true
	return false
