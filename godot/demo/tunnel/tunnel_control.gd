extends Node3D
## Player-directed tunnel digging in the live demo. Decision 0196. Presentation only: the tunnels
## shape the demo cast's walks, never the simulation (MOVE-G01..05 are open).
##
## CONTROLS (demo_command.gd hands every event here first):
##   T, or "Dig tunnel" in the Demo party panel   plan a tunnel with the selected mole
##   while planning:  left click   lay a point -- the first is the entrance, the last the exit
##                    Enter / right click         dig it          Backspace   take back the last point
##                    Esc / T                     cancel          (U still toggles the view)
##   right click a paused tunnel's entrance       resume it with the selected mole
##   U                                            underground view (tunnel_view.gd)
## A refused point or route leaves a clay marker and the reason in the panel. Only a mole digs; T
## with no mole selected says so. The camera's own keys and the wheel are never taken.
##
## WHO FITS. At setup each resident's fit to the bore is set from its body -- the height the cast
## draws it at and its body radius, in integer u (tunnel_rules.fits_bore) -- and never changes.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")

## A right click this close to a paused tunnel's entrance resumes it.
const RESUME_PICK_M: float = 1.1
const PLAN_FIRST: String = "Tunnel: click where the entrance opens"
const PLAN_MORE: String = "Tunnel: %d points, %s -- click: add · Enter / right-click: dig · Backspace: undo · Esc: cancel"
const PLAN_CANCELLED: String = "Tunnel plan cancelled"
const DIG_STARTED: String = "Digging a %s tunnel: %d m³ to cut, %d U of spoil, about %d s"
const DIG_RESUMED: String = "Resuming the tunnel at %d%%"
const DIG_OPEN: String = "Tunnel open: mice, moles and squirrels may use it; otters and badgers are too big"
const REFUSED: String = "Can't dig: %s"
const VIEW_ON: String = "Underground view (U to return)"
const VIEW_OFF: String = "Surface view"

var planning: bool = false
var plan: PlanScript = PlanScript.new()
var network: NetworkScript = null
var overlay: OverlayScript = null
var view: ViewScript = null

var _cast: DemoCastScript = null
var _camera: Camera3D = null
var _space: CastSpaceScript = null
var _selection: Callable = Callable()
var _mark: Callable = Callable()
var _notice: Callable = Callable()
var _planner: int = 0
var _bounds_u: Rect2i = Rect2i()
var _circles_u: PackedInt32Array = PackedInt32Array()
var _is_digger: PackedByteArray = PackedByteArray()
var _ground: Vector2 = Vector2.ZERO
var _cursor: Vector2 = Vector2.ZERO
var _has_cursor: bool = false
var _ref: PackedInt32Array = PackedInt32Array([-1, 0])
var _route: PackedVector2Array = PackedVector2Array()
var _seen_open: int = 0


func configure(cast: DemoCastScript, camera: Camera3D, selection: Callable, mark: Callable, notice: Callable) -> void:
	"""Plan and draw tunnels for this cast, picking through this camera. `selection` returns the
	selected actor indices; `mark(at: Vector3, accepted: bool)` drops an order marker; `notice(text)`
	shows a line in the party panel."""
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
	_circles_u = Rules.circles_to_u(_space.obstacles)
	_describe_cast()
	overlay = OverlayScript.new()
	add_child(overlay)
	overlay.configure(network, _space)
	view = ViewScript.new()
	add_child(view)
	view.configure(null, cast, overlay)


func set_world(world: Node3D) -> void:
	"""The world the underground view fades."""
	view.set_world(world)


func _describe_cast() -> void:
	"""Each resident's bore fit (from its drawn height and body radius) and whether it digs."""
	_is_digger.resize(_cast.actor_count())
	for i in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		var fit := Rules.fits_bore(Rules.to_u(actor.height_m), Rules.to_u(actor.brain.radius))
		network.set_fit(actor.brain.index, fit)
		_is_digger[i] = 1 if Rules.is_digger(actor.species) else 0


func is_digger(actor_index: int) -> bool:
	"""Whether this actor digs tunnels."""
	return _is_digger[actor_index] == 1


func _brain(actor_index: int) -> BrainScript:
	"""An actor's brain."""
	return (_cast.actor(actor_index) as DemoActorScript).brain


# --- input ----------------------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	"""Apply one event; true when it was a tunnel input (and so consumed)."""
	if planning:
		return _plan_input(event)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _on_key(event as InputEventKey)
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		return _try_resume(button.position)
	return false


static func key_of(event: InputEventKey) -> Key:
	"""The event's key: its physical key when it has one, else its logical key."""
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


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
	"""Switch the underground view."""
	_notice.call(VIEW_ON if view.toggle() else VIEW_OFF)


# --- planning -------------------------------------------------------------------------------

func begin_plan() -> bool:
	"""Start laying a tunnel for the first selected mole -- or refuse, saying why: no mole selected,
	the mole already digging, or no room for another tunnel."""
	if not _find_digger():
		_refuse(Rules.REFUSE_NOT_A_DIGGER)
		return false
	if _brain(_planner).dig_tunnel >= 0:
		_refuse(Rules.REFUSE_BUSY)
		return false
	if not network.has_room():
		_refuse(Rules.REFUSE_NO_ROOM)
		return false
	planning = true
	plan.clear()
	_has_cursor = false
	overlay.show_plan(plan, _cursor, false)
	_notice.call(PLAN_FIRST)
	return true


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
	var reason := plan.try_add(Rules.to_u(at.x), Rules.to_u(at.y), _bounds_u, _circles_u)
	if reason != Rules.REFUSE_NONE:
		_mark.call(Vector3(at.x, 0.0, at.y), false)
		_notice.call(REFUSED % Rules.reason_text(reason))
	else:
		_notice.call(plan_status())
	overlay.show_plan(plan, _cursor, _has_cursor)
	return reason == Rules.REFUSE_NONE


func plan_status() -> String:
	"""What the panel says while a route is being laid."""
	if plan.count == 0:
		return PLAN_FIRST
	return PLAN_MORE % [plan.count, PlanScript.length_text(plan.length_u())]


func confirm() -> bool:
	"""Dig the route as laid: validate it, check the mole can walk to its entrance, store it and send
	the mole. A refusal keeps planning, marks the point at fault and says why."""
	var reason := plan.route_reason(_bounds_u, _circles_u)
	if reason == Rules.REFUSE_NONE and not _entrance_reachable():
		reason = Rules.REFUSE_UNREACHABLE
	if reason == Rules.REFUSE_NONE and not network.add_into(plan.points_u, plan.count, _brain(_planner).index, _ref):
		reason = Rules.REFUSE_NO_ROOM
	if reason != Rules.REFUSE_NONE:
		_refuse(reason)
		return false
	_brain(_planner).order_dig(_ref[0], _ref[1])
	_mark.call(_mouth3(_ref[0], false), true)
	var cut := network.quanta[_ref[0]] + 2 * Rules.SHAFT_QUANTA
	_notice.call(DIG_STARTED % [PlanScript.length_text(network.length_u[_ref[0]]), cut,
		cut * Rules.SPOIL_PER_QUANTUM_MILLI_U / 1000, Rules.total_ticks(network.quanta[_ref[0]]) / Rules.TICKS_PER_SECOND])
	_end_plan()
	return true


func _entrance_reachable() -> bool:
	"""Whether the mole can walk from where it will stand to the entrance."""
	var brain := _brain(_planner)
	var entrance := plan.point_m(0)
	_space.nav.plan(brain.surface_point(), entrance, brain.radius, PackedVector3Array(), 0, _route)
	return _space.nav.last_found


func undo_point() -> void:
	"""Take back the last point; with none left, stop planning."""
	if not plan.undo():
		cancel_plan()
		return
	_notice.call(plan_status())
	overlay.show_plan(plan, _cursor, _has_cursor)


func cancel_plan() -> void:
	"""Stop planning without digging."""
	_end_plan()
	_notice.call(PLAN_CANCELLED)


func _end_plan() -> void:
	"""Leave planning mode and clear its drawing."""
	planning = false
	overlay.hide_plan()


func _refuse(reason: int) -> void:
	"""Say why, and drop a clay marker where it went wrong (the exit for an exit refusal, the entrance
	for one about the entrance, otherwise the last point laid)."""
	_notice.call(REFUSED % Rules.reason_text(reason))
	if plan.count == 0 or not planning:
		return
	var k := plan.count - 1
	if reason == Rules.REFUSE_ENTRANCE_BLOCKED or reason == Rules.REFUSE_UNREACHABLE:
		k = 0
	var at := plan.point_m(k)
	_mark.call(Vector3(at.x, 0.0, at.y), false)


func _mouth3(slot: int, exit: bool) -> Vector3:
	"""A tunnel mouth as a ground point."""
	var at := network.mouth(slot, exit)
	return Vector3(at.x, 0.0, at.y)


# --- resuming and watching ------------------------------------------------------------------

func _try_resume(screen: Vector2) -> bool:
	"""A right click on a paused tunnel's entrance with a mole selected: the mole goes back to it."""
	if not _ground_at(screen) or not _find_digger() or _brain(_planner).dig_tunnel >= 0:
		return false
	for slot in Rules.MAX_TUNNELS:
		if network.phase[slot] == NetworkScript.PHASE_PAUSED and network.mouth(slot, false).distance_to(_ground) <= RESUME_PICK_M:
			return resume(slot)
	return false


func resume(slot: int) -> bool:
	"""Send the planning mole (_planner) back to dig paused tunnel `slot`."""
	if not network.resume(slot, network.generation[slot], _brain(_planner).index):
		return false
	_brain(_planner).order_dig(slot, network.generation[slot])
	_mark.call(_mouth3(slot, false), true)
	_notice.call(DIG_RESUMED % network.percent(slot))
	return true


func _process(_delta: float) -> void:
	"""Announce a tunnel opening."""
	if network == null:
		return
	var open := network.open_count()
	if open > _seen_open:
		_notice.call(DIG_OPEN)
	_seen_open = open
