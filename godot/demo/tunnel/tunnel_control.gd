extends Node3D
## Player-directed tunnel digging in the live demo. Decision 0196. Presentation only: the tunnels
## shape the demo cast's walks, never the simulation (MOVE-G01..05 are open).
##
## CONTROLS (demo_command.gd hands every event here first; Enter while planning is read in its
## `_input`, before the HUD, so it can never press a focused HUD button):
##   T, or "Dig tunnel" in the Demo party panel   plan a tunnel with the selected mole (again: cancel)
##   while planning:  left click   lay a point -- the first is the entrance, the last the exit
##                    Enter / right click         dig it          Backspace   take back the last point
##                    Esc / T / the panel button  cancel          (U still toggles the view)
##   right click a tunnel's entrance with the mole selected:
##                    the tunnel it is digging    nothing changes: it keeps digging (and says so)
##                    a paused tunnel             it resumes that one -- pausing the one it was
##                                                digging, if any, with all its progress kept
##   U                                            underground view (tunnel_view.gd); U again puts back
##                                                the notice the view replaced
## A refused point or route leaves a clay marker and the reason in the panel. Only a mole digs; T
## with no mole selected says so. The camera's own keys and the wheel are never taken.
##
## WHAT A ROUTE MUST CLEAR (tunnel_rules.gd): the village's edge; obstacles and spoil heaps at each
## mouth; work spots and other tunnels' mouths at each mouth (`_spots_u`); buildings and the well
## along every leg (`_under_u`, from the world); water under every point and leg (the plan asks the
## village's water adapter, tunnel_plan.gd WATER); and, on digging, someone standing on the entrance
## or no walk to it for the mole. Accepted, the tunnel's heaps are placed (tunnel_heaps.gd) and the
## world's grass is cleared from its holes, heaps and route.
##
## THE NOTICE FOLLOWS THE TUNNELS. Every frame the tool compares the network's revision with the one
## it last saw, and says what changed: a tunnel open, paused (at N%, and how to resume it), kept as a
## plan the mole could not reach, or dropped before any ground was broken -- so the panel never keeps
## saying "Digging" about a tunnel that has stopped. A freed slot's heaps stop being obstacles.
##
## WHO FITS. At setup each resident's body is recorded -- the height the cast draws it at and its
## body radius, in integer u -- and its fit is judged per tunnel from it (tunnel_network.set_body).
##
## THE EXTENSIONS (tunnel_ext.gd: weather, hauling, upgrades, hazards, finds, ground, chambers,
## crews, threats) are built here and handed what this tool does not take: a click that picks no
## resident may select a tunnel (`select_tunnel_at`), a chamber being placed takes the clicks, the
## underground view and planning switch their drawings, a laid route's status names its ground,
## and a dig ordered -- or a right click on a tunnel being dug -- puts the other selected residents on
## the Foremole's crew.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")
const ExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const ServicesScript := preload("res://demo/demo_services.gd")

## A right click this close to a tunnel's entrance is about that tunnel.
const RESUME_PICK_M: float = 1.1
## A mouth keeps this far (plus MOUTH_CLEAR_U) from a work spot, and this from another mouth.
const SPOT_KEEP_U: int = 512
const MOUTH_KEEP_U: int = 768
## The grass cleared along a new tunnel's route, either side (the mound's width).
const COVER_CLEAR_M: float = 0.6
const PLAN_FIRST: String = "Tunnel: click where the entrance opens"
const PLAN_MORE: String = "Tunnel: %s, %s -- click: add · Enter / right-click: dig · Backspace: undo · Esc: cancel"
const PLAN_CANCELLED: String = "Tunnel plan cancelled"
## The cut, spoil and time through the tunnel's own ground (at one F1000 worker; a crew is quicker).
const DIG_STARTED: String = "Digging a %s tunnel: %d m³ to cut, %d U of spoil, about %d s"
const DIG_RESUMED: String = "Resuming the tunnel at %d%%"
const DIG_KEPT: String = "Already digging this tunnel (%d%%)"
const DIG_OPEN: String = "Tunnel open: mice, moles and squirrels may use it; otters and badgers are too big"
const DIG_PAUSED: String = "Tunnel paused at %d%% — right-click its entrance with the mole to resume"
const DIG_UNREACHED: String = "The mole couldn't reach the entrance — tunnel paused at %d%%; right-click its entrance with the mole to resume"
const DIG_DROPPED: String = "Dig called off before any ground was broken"
const REFUSED: String = "Can't dig: %s"
const VIEW_ON: String = "Underground view (U to return)"

var planning: bool = false
var plan: PlanScript = PlanScript.new()
var network: NetworkScript = null
var overlay: OverlayScript = null
var view: ViewScript = null
var ext: ExtScript = null

var _cast: DemoCastScript = null
var _camera: Camera3D = null
var _space: CastSpaceScript = null
var _world: DemoWorldScript = null
var _selection: Callable = Callable()
var _mark: Callable = Callable()
var _notice: Callable = Callable()
var _planner: int = 0
var _bounds_u: Rect2i = Rect2i()
var _circles_u: PackedInt32Array = PackedInt32Array()
var _spots_u: PackedInt32Array = PackedInt32Array()
var _under_u: PackedInt32Array = PackedInt32Array()
var _is_digger: PackedByteArray = PackedByteArray()
var _ground: Vector2 = Vector2.ZERO
var _cursor: Vector2 = Vector2.ZERO
var _has_cursor: bool = false
var _ref: PackedInt32Array = PackedInt32Array([-1, 0])
var _route: PackedVector2Array = PackedVector2Array()
var _last_notice: String = ""
var _before_view: String = ""
var _seen_revision: int = -1
var _seen_phase: PackedByteArray = PackedByteArray()
var _seen_generation: PackedInt32Array = PackedInt32Array()
var _seen_reason: PackedByteArray = PackedByteArray()


func configure(cast: DemoCastScript, camera: Camera3D, selection: Callable, mark: Callable, notice: Callable,
		services: ServicesScript = null) -> void:
	"""Plan and draw tunnels for this cast, picking through this camera. `selection` returns the
	selected actor indices; `mark(at: Vector3, accepted: bool)` drops an order marker; `notice(text)`
	shows a line in the party panel; `services` are the demo's shared weather, water and notice feed
	(none: the extensions make a set of their own)."""
	name = "TunnelControl"
	_cast = cast
	_camera = camera
	_space = cast.space()
	network = _space.tunnels
	_selection = selection
	_mark = mark
	_notice = notice
	var bounds := cast.bounds()
	_bounds_u = Rect2i(Rules.to_u(bounds.position.x), Rules.to_u(bounds.position.y), Rules.to_u(bounds.size.x),
		Rules.to_u(bounds.size.y))
	_refresh_clearances()
	_describe_cast()
	_build_parts(cast, camera, selection, mark, services)
	_seen_phase.resize(Rules.MAX_TUNNELS)
	_seen_generation.resize(Rules.MAX_TUNNELS)
	_seen_reason.resize(Rules.MAX_TUNNELS)
	_sync_seen()


func _build_parts(cast: DemoCastScript, camera: Camera3D, selection: Callable, mark: Callable,
		services: ServicesScript) -> void:
	"""The overlay, the underground view and the extensions."""
	overlay = OverlayScript.new()
	add_child(overlay)
	overlay.configure(network, _space, cast.clock)
	view = ViewScript.new()
	add_child(view)
	view.configure(null, cast, overlay)
	ext = ExtScript.new()
	add_child(ext)
	ext.configure(cast, camera, overlay, _bounds_u, selection, mark, _say, services)
	plan.water_crossing = ext.works.water.crosses_water


func set_world(world: DemoWorldScript) -> void:
	"""The world the underground view fades, whose buildings no tunnel may pass under and whose grass
	a new tunnel clears."""
	_world = world
	view.set_world(world)
	_under_u = Rules.circles_to_u(PackedVector3Array(world.building_obstacles()))
	ext.set_world(world, _under_u)


func _describe_cast() -> void:
	"""Each resident's bore fit (from its drawn height and body radius) and whether it digs."""
	_is_digger.resize(_cast.actor_count())
	for i in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		network.set_body(actor.brain.index, Rules.to_u(actor.height_m), Rules.to_u(actor.brain.radius))
		_is_digger[i] = 1 if Rules.is_digger(actor.species) else 0


func is_digger(actor_index: int) -> bool:
	"""Whether this actor digs tunnels."""
	return _is_digger[actor_index] == 1


func _brain(actor_index: int) -> BrainScript:
	"""An actor's brain."""
	return (_cast.actor(actor_index) as DemoActorScript).brain


func _say(text: String) -> void:
	"""Show a line in the party panel, and remember it (the underground view puts it back)."""
	_last_notice = text
	_notice.call(text)


func notice() -> String:
	"""The line this tool last showed."""
	return _last_notice


# --- input ----------------------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	"""Apply one event; true when it was a tunnel input (and so consumed)."""
	if planning:
		return _plan_input(event)
	if ext.handle_input(event):
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _on_key(event as InputEventKey)
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		return _try_resume(button.position)
	return false


static func key_of(event: InputEventKey) -> Key:
	"""The event's key: its physical key when it has one, else its logical key."""
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


static func is_confirm_key(event: InputEvent) -> bool:
	"""Whether `event` presses Enter (either one) -- what digs the route being laid."""
	var key := event as InputEventKey
	return key != null and key.is_pressed() and not key.is_echo() \
			and (key_of(key) == KEY_ENTER or key_of(key) == KEY_KP_ENTER)


static func _modified(event: InputEventKey) -> bool:
	"""Whether a modifier is held (T and U are plain keys)."""
	return event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed


func _on_key(event: InputEventKey) -> bool:
	"""T plans a tunnel; U switches the underground view."""
	if _modified(event):
		return false
	if key_of(event) == KEY_T:
		begin_plan()
		return true
	if key_of(event) == KEY_U:
		toggle_view()
		return true
	return false


func _plan_input(event: InputEvent) -> bool:
	"""While planning: points, confirm, undo and cancel (see CONTROLS). Motion is only watched."""
	if event is InputEventMouseMotion:
		_hover((event as InputEventMouseMotion).position)
		return false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			lay_at(button.position)
		return true
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			confirm()
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _plan_key(event as InputEventKey)
	return false


func _plan_key(event: InputEventKey) -> bool:
	"""Enter digs, Backspace takes a point back, Esc or T cancels, U switches the view."""
	match key_of(event):
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
		KEY_BACKSPACE:
			undo_point()
		KEY_ESCAPE, KEY_T:
			cancel_plan()
		KEY_U:
			toggle_view()
		_:
			return false
	return true


func _ground_at(screen: Vector2) -> bool:
	"""The ground point under a screen point, into _ground. False when the ray misses the ground."""
	var origin := _camera.project_ray_origin(screen)
	var direction := _camera.project_ray_normal(screen)
	var t := PickScript.ray_ground(origin, direction, 0.0)
	if t < 0.0:
		return false
	var at := origin + direction * t
	_ground = Vector2(at.x, at.z)
	return true


func _hover(screen: Vector2) -> void:
	"""Follow the pointer with the preview."""
	_has_cursor = _ground_at(screen)
	_cursor = _ground
	overlay.show_plan(plan, _cursor, _has_cursor)


func toggle_view() -> void:
	"""Switch the underground view; switched back, the notice it replaced returns."""
	if view.toggle():
		_before_view = _last_notice
		_say(VIEW_ON)
	elif _last_notice == VIEW_ON:
		_say(_before_view)
	ext.set_underground_view(view.on)


# --- planning -------------------------------------------------------------------------------

func toggle_plan() -> bool:
	"""The panel's "Dig tunnel" button: start planning -- or, while planning, cancel, as T does.
	Returns whether it is planning now."""
	if planning:
		cancel_plan()
	else:
		begin_plan()
	return planning


func begin_plan() -> bool:
	"""Start laying a tunnel for the first selected mole -- or refuse, saying why: no mole selected,
	the mole already digging, or no room for another tunnel. Any HUD button's focus is released, so
	nothing but the tool hears the Enter that digs."""
	if not _find_digger():
		_refuse(Rules.REFUSE_NOT_A_DIGGER)
		return false
	if _brain(_planner).dig_tunnel >= 0:
		_refuse(Rules.REFUSE_BUSY)
		return false
	if not network.has_room():
		_refuse(Rules.REFUSE_NO_ROOM)
		return false
	if is_inside_tree():
		get_viewport().gui_release_focus()
	planning = true
	ext.set_planning(true)
	plan.clear()
	_refresh_clearances()
	_has_cursor = false
	overlay.show_plan(plan, _cursor, false)
	_say(PLAN_FIRST)
	return true


func _refresh_clearances() -> void:
	"""What a new route's mouths must clear now: every obstacle and heap, and every work spot and
	planned mouth (see WHAT A ROUTE MUST CLEAR)."""
	_circles_u = Rules.circles_to_u(_space.obstacles)
	_spots_u.clear()
	for poi in _space.poi_position.size():
		for k in _space.poi_capacity[poi]:
			var at := _space.slot_position(poi, k)
			_spots_u.append_array(PackedInt32Array([Rules.to_u(at.x), SPOT_KEEP_U, Rules.to_u(at.y)]))
	for slot in Rules.MAX_TUNNELS:
		if network.phase[slot] != NetworkScript.PHASE_FREE:
			for end in 2:
				var mouth := network.mouth(slot, end == 1)
				_spots_u.append_array(PackedInt32Array([Rules.to_u(mouth.x), MOUTH_KEEP_U, Rules.to_u(mouth.y)]))


func _find_digger() -> bool:
	"""The first selected mole, into _planner. False when the selection has none."""
	for i in _selection.call() as PackedInt32Array:
		if is_digger(i):
			_planner = i
			return true
	return false


func lay_at(screen: Vector2) -> void:
	"""Lay the next point on the ground under a screen point."""
	if _ground_at(screen):
		lay_ground(_ground)


func lay_ground(at: Vector2) -> bool:
	"""Lay the next point at (x, z) metres; a refused point is marked clay with its reason."""
	var reason := plan.try_add(Rules.to_u(at.x), Rules.to_u(at.y), _bounds_u, _circles_u, _spots_u, _under_u)
	if reason != Rules.REFUSE_NONE:
		_mark.call(Vector3(at.x, 0.0, at.y), false)
		_say(REFUSED % Rules.reason_text(reason))
	else:
		_say(plan_status())
	overlay.show_plan(plan, _cursor, _has_cursor)
	return reason == Rules.REFUSE_NONE


func plan_status() -> String:
	"""What the panel says while a route is being laid."""
	if plan.count == 0:
		return PLAN_FIRST
	var points := "1 point" if plan.count == 1 else "%d points" % plan.count
	var status := PLAN_MORE % [points, PlanScript.length_text(plan.length_u())]
	return status if plan.count < 2 else "%s · %s" % [status, ext.route_ground(plan.points_u, plan.count)]


func confirm() -> bool:
	"""Dig the route as laid: validate it, check nobody stands on its entrance and the mole can walk
	there, store it, place its heaps and send the mole. A refusal keeps planning, marks the point at
	fault and says why."""
	var reason := plan.route_reason(_bounds_u, _circles_u, _spots_u, _under_u)
	if reason == Rules.REFUSE_NONE and _entrance_occupied():
		reason = Rules.REFUSE_ENTRANCE_OCCUPIED
	if reason == Rules.REFUSE_NONE and not _entrance_reachable():
		reason = Rules.REFUSE_UNREACHABLE
	if reason == Rules.REFUSE_NONE and not network.add_into(plan.points_u, plan.count, _brain(_planner).index, _ref):
		reason = Rules.REFUSE_NO_ROOM
	if reason != Rules.REFUSE_NONE:
		_refuse(reason)
		return false
	_accept(_ref[0])
	_brain(_planner).order_dig(_ref[0], _ref[1])
	ext.works.say(CrewScript.LINE_START)
	ext.crew_on_dig(_ref[0], _brain(_planner).index)
	_sync_seen()
	_mark.call(_mouth3(_ref[0], false), true)
	_say(DIG_STARTED % [PlanScript.length_text(network.length_u[_ref[0]]), network.timeline_count(_ref[0]),
		_finished_spoil_u(_ref[0]), network.total_ticks(_ref[0]) / Rules.TICKS_PER_SECOND])
	_end_plan()
	return true


func _finished_spoil_u(slot: int) -> int:
	"""The whole units of spoil tunnel `slot` will heap, through its ground (tunnel_ground.gd)."""
	var spoil := PackedInt64Array([0, 0])
	network.finished_spoil_into(slot, 0, spoil)
	return (spoil[0] + spoil[1]) / 1000


func _accept(slot: int) -> void:
	"""A tunnel just stored: place its heaps (obstacles from now on) and clear the grass from its
	holes, heaps and route."""
	HeapsScript.place(network, _space, slot)
	_circles_u = Rules.circles_to_u(_space.obstacles)
	if _world == null:
		return
	var route := PackedVector2Array()
	for k in network.point_count[slot]:
		route.append(network.point(slot, k))
	var circles := PackedVector3Array()
	for k in 2:
		var at := network.heap_at[2 * slot + k]
		circles.append(Vector3(at.x, network.heap_radius_m[2 * slot + k], at.y))
		var mouth := network.mouth(slot, k == 1)
		circles.append(Vector3(mouth.x, Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR, mouth.y))
	_world.hide_cover(route, COVER_CLEAR_M, circles)


func _entrance_occupied() -> bool:
	"""Whether someone other than the mole stands on the entrance: closer than their radius plus the
	mole's plus the planning margin (so the mole could never step into the hole to dig)."""
	var mole := _brain(_planner)
	var at := plan.point_m(0)
	for j in _space.resident_position.size():
		if j == mole.index or _space.resident_underground[j] != 0 or _space.resident_walking[j] != 0:
			continue
		var reach := _space.resident_radius[j] + mole.radius + CastNavScript.PLAN_MARGIN_M
		if _space.resident_position[j].distance_to(at) < reach:
			return true
	return false


func _entrance_reachable() -> bool:
	"""Whether the mole can walk from where it will stand to the entrance, round everyone standing."""
	var brain := _brain(_planner)
	_space.plan_path(brain.index, brain.surface_point(), plan.point_m(0), brain.radius, _route)
	return _space.nav.last_found


func undo_point() -> void:
	"""Take back the last point; with none left, stop planning."""
	if not plan.undo():
		cancel_plan()
		return
	_say(plan_status())
	overlay.show_plan(plan, _cursor, _has_cursor)


func cancel_plan() -> void:
	"""Stop planning without digging."""
	_end_plan()
	_say(PLAN_CANCELLED)


func _end_plan() -> void:
	"""Leave planning mode and clear its drawing."""
	planning = false
	ext.set_planning(false)
	overlay.hide_plan()


func _refuse(reason: int) -> void:
	"""Say why, and drop a clay marker where it went wrong (the exit for an exit refusal, the entrance
	for one about the entrance, otherwise the last point laid)."""
	_say(REFUSED % Rules.reason_text(reason))
	if plan.count == 0 or not planning:
		return
	var k := plan.count - 1
	if reason == Rules.REFUSE_ENTRANCE_BLOCKED or reason == Rules.REFUSE_UNREACHABLE \
			or reason == Rules.REFUSE_ENTRANCE_OCCUPIED:
		k = 0
	var at := plan.point_m(k)
	_mark.call(Vector3(at.x, 0.0, at.y), false)


func _mouth3(slot: int, exit: bool) -> Vector3:
	"""A tunnel mouth as a ground point."""
	var at := network.mouth(slot, exit)
	return Vector3(at.x, 0.0, at.y)


# --- resuming and watching ------------------------------------------------------------------

func _try_resume(screen: Vector2) -> bool:
	"""A right click, on the ground under a screen point (see resume_at)."""
	return _ground_at(screen) and resume_at(_ground)


func resume_at(at: Vector2) -> bool:
	"""A right click at (x, z) with a mole selected (see CONTROLS): on the entrance of the tunnel it is
	digging, nothing changes; on a paused one's, it goes to resume that. False (the click is an
	order) anywhere else, or with no mole selected."""
	if not _find_digger():
		return _join_crew_at(at)
	var slot := entrance_near(at)
	if slot < 0:
		return false
	if slot == _brain(_planner).dig_tunnel:
		_mark.call(_mouth3(slot, false), true)
		ext.crew_on_dig(slot, _brain(_planner).index)
		_say(DIG_KEPT % network.percent(slot))
		return true
	return network.phase[slot] == NetworkScript.PHASE_PAUSED and resume(slot)


func _join_crew_at(at: Vector2) -> bool:
	"""A right click at (x, z) with no mole selected: on the entrance of a tunnel being dug, the
	selected residents join its crew. False (the click is an order) anywhere else, or when nobody
	joined."""
	var slot := entrance_near(at)
	if slot < 0 or network.phase[slot] != NetworkScript.PHASE_DIGGING:
		return false
	if ext.actions.add_crew(slot, _selection.call() as PackedInt32Array, network.digger[slot]) == 0:
		return false
	_mark.call(_mouth3(slot, false), true)
	return true


func select_tunnel_at(screen: Vector2) -> bool:
	"""A left click that picked no resident: select the finished tunnel under it (tunnel_ext.gd)."""
	return ext.select_at_screen(screen)


func entrance_near(at: Vector2) -> int:
	"""The unfinished tunnel whose entrance is nearest `at` within RESUME_PICK_M, or -1."""
	var best := -1
	var best_d := RESUME_PICK_M
	for slot in Rules.MAX_TUNNELS:
		var phase := network.phase[slot]
		if phase != NetworkScript.PHASE_DIGGING and phase != NetworkScript.PHASE_PAUSED:
			continue
		var d := network.mouth(slot, false).distance_to(at)
		if d <= best_d:
			best_d = d
			best = slot
	return best


func resume(slot: int) -> bool:
	"""Send the planning mole (_planner) back to dig paused tunnel `slot`; a tunnel it was digging is
	paused with its progress (resident_brain.order_dig)."""
	if not network.resume(slot, network.generation[slot], _brain(_planner).index):
		return false
	_brain(_planner).order_dig(slot, network.generation[slot])
	_sync_seen()
	_mark.call(_mouth3(slot, false), true)
	_say(DIG_RESUMED % network.percent(slot))
	return true


func _process(_delta: float) -> void:
	"""Say what changed in the tunnels (see THE NOTICE FOLLOWS THE TUNNELS)."""
	if network == null or network.revision == _seen_revision:
		return
	_seen_revision = network.revision
	for slot in Rules.MAX_TUNNELS:
		var phase := network.phase[slot]
		if phase == _seen_phase[slot] and network.generation[slot] == _seen_generation[slot] \
				and network.pause_reason[slot] == _seen_reason[slot]:
			continue
		_announce(slot, _seen_phase[slot], phase)
		_seen_phase[slot] = phase
		_seen_generation[slot] = network.generation[slot]
		_seen_reason[slot] = network.pause_reason[slot]


func _announce(slot: int, was: int, now: int) -> void:
	"""The notice for tunnel `slot` going from phase `was` to `now`; a freed slot's heaps are cleared."""
	if now == NetworkScript.PHASE_OPEN:
		_say(DIG_OPEN)
	elif now == NetworkScript.PHASE_PAUSED and network.pause_reason[slot] == NetworkScript.PAUSED_UNREACHED:
		_say(DIG_UNREACHED % network.percent(slot))
	elif now == NetworkScript.PHASE_PAUSED:
		_say(DIG_PAUSED % network.percent(slot))
	elif now == NetworkScript.PHASE_FREE:
		HeapsScript.clear(network, _space, slot)
		_circles_u = Rules.circles_to_u(_space.obstacles)
		if was == NetworkScript.PHASE_DIGGING:
			_say(DIG_DROPPED)


func _sync_seen() -> void:
	"""Take the network as it stands as seen: changes the tool made itself need no second notice."""
	_seen_revision = network.revision
	for slot in Rules.MAX_TUNNELS:
		_seen_phase[slot] = network.phase[slot]
		_seen_generation[slot] = network.generation[slot]
		_seen_reason[slot] = network.pause_reason[slot]
