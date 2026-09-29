extends Node3D
## The tunnel extensions, wired into the demo. Decision 0196 (live demo). Presentation only.
##
## The tunnel tool (tunnel_control.gd) builds this once and hands it the events it does not take
## itself. It owns the works (tunnel_works.gd: weather, ground, stores, crews, jobs, hazards,
## chambers, threats), the player's orders on them (tunnel_actions.gd), their drawings (the ground
## map, the tunnel marks, the chambers, the threats, the weather) and the "Tunnels & burrows (demo)"
## panel (tunnel_panel.gd), and runs the works every frame on the demo clock.
##
## CONTROLS it adds (everything through the one command layer, demo/control/demo_command.gd):
##   left click a finished tunnel's mouth or route (no resident under the pointer)   select it
##   the panel's buttons on the selected tunnel   Widen · Brace · Hang lanterns · Repair (Pump out /
##                                               Clear the fall) · Burrow home · Root cellar
##   after Burrow home / Root cellar: left click on or beside the tunnel   place the chamber there
##                                   Esc or right click                    cancel the placement
##   the panel's "Next weather (demo)" and "Test event (demo)"             skip the weather on /
##                                                                          bring the next threat
##   T with the mole AND others selected, or right click a tunnel being dug with residents selected:
##                                               they join the Foremole's dig crew
## Residents selected when a tunnel job is ordered become its worker or crew (tunnel_actions.gd).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const ActionsScript := preload("res://demo/tunnel/tunnel_actions.gd")
const PanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const GroundViewScript := preload("res://demo/tunnel/tunnel_ground_view.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const BurrowViewScript := preload("res://demo/burrow/burrow_view.gd")
const EventsViewScript := preload("res://demo/events/events_view.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")

const PANEL_REFRESH_S: float = 0.2
const JOB_FOR_ACTION: Dictionary = {&"widen": JobsScript.JOB_WIDEN, &"brace": JobsScript.JOB_BRACE,
	&"lanterns": JobsScript.JOB_LANTERNS}
const BORE_NAMES: Array[String] = ["standard bore (1 m)", "wide bore (2 x 3 m)"]

var works: WorksScript = null
var actions: ActionsScript = null
var panel: PanelScript = null
var marks: MarksScript = null
var ground_view: GroundViewScript = null
var burrow_view: BurrowViewScript = null
var events_view: EventsViewScript = null
var weather_view: WeatherViewScript = null

var _cast: DemoCastScript = null
var _network: NetworkScript = null
var _overlay: OverlayScript = null
var _camera: Camera3D = null
var _selection: Callable = Callable()
var _mark: Callable = Callable()
var _refresh_in: float = 0.0
var _enabled: Dictionary = {}
var _ground: Vector2 = Vector2.ZERO
## The tunnel the marks last drew as selected (-1: none; -2: not drawn yet).
var _marked: int = -2


func configure(cast: DemoCastScript, camera: Camera3D, overlay: OverlayScript, bounds_u: Rect2i,
		selection: Callable, mark: Callable, notice: Callable) -> void:
	"""Wire the extensions for this cast, picking through this camera, drawing beside `overlay`.
	`selection() -> PackedInt32Array`, `mark(at, accepted)` and `notice(text)` are the tunnel tool's."""
	name = "TunnelExt"
	_cast = cast
	_camera = camera
	_overlay = overlay
	_network = cast.space().tunnels
	_selection = selection
	_mark = mark
	works = WorksScript.new()
	add_child(works)
	var names := PackedStringArray()
	var species := PackedStringArray()
	var moles := PackedByteArray()
	var brains: Array[BrainScript] = []
	for i in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		species.append(actor.species)
		moles.append(1 if Rules.is_digger(actor.species) else 0)
	works.setup(cast.space(), brains, species, bounds_u, notice, Callable())
	actions = ActionsScript.new(works, cast.space(), moles, names, bounds_u)
	_build_views()


func _build_views() -> void:
	"""The drawings and the panel."""
	marks = MarksScript.new()
	add_child(marks)
	marks.configure(_network, works.hazards)
	ground_view = GroundViewScript.new()
	add_child(ground_view)
	ground_view.configure(works.ground)
	burrow_view = BurrowViewScript.new()
	add_child(burrow_view)
	burrow_view.configure(works.chambers)
	events_view = EventsViewScript.new()
	add_child(events_view)
	events_view.configure(works.events, _cast.clock)
	weather_view = WeatherViewScript.new()
	add_child(weather_view)
	weather_view.configure(works.weather, _cast.clock, null)
	panel = PanelScript.new()
	add_child(panel)
	panel.build()
	panel.action.connect(on_action)


func set_world(world: Node, under_u: PackedInt32Array) -> void:
	"""The world whose sun and haze the weather dims, and whose buildings no chamber is dug under."""
	actions.set_under(under_u)
	weather_view.configure(works.weather, _cast.clock, world)


func set_hud(hud_root: Control, alert: Callable) -> void:
	"""The HUD the panel keeps clear of, and where alerts are raised (UIManager.push_alert in the demo)."""
	panel.watch_hud(hud_root)
	works.set_alert(alert)


# --- per frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the works on this frame's demo time, keep the drawings in step, and refresh the panel a few
	times a second (real time: the panel works while paused)."""
	works.step(_cast.clock.frame_usec)
	_feed_overlay()
	if _selection_changed():
		marks.select(_marked)
	marks.refresh()
	burrow_view.refresh()
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		refresh_panel()
		panel.follow_hud()


func _selection_changed() -> bool:
	"""Whether the selected tunnel changed since the marks last drew it."""
	var now := actions.selected if actions.has_selection() else -1
	if now == _marked:
		return false
	_marked = now
	return true


func _feed_overlay() -> void:
	"""Tell the overlay where each widening has reached and which mole is digging at each job (only
	while it is at the work below -- not while it walks there)."""
	var jobs := works.jobs
	for slot in Rules.MAX_TUNNELS:
		var job := jobs.kind[slot] if jobs.has_job(slot) else JobsScript.JOB_NONE
		var digs := job == JobsScript.JOB_WIDEN or job == JobsScript.JOB_CLEAR or job == JobsScript.JOB_CHAMBER
		var worker := jobs.worker[slot]
		var at_work := digs and worker >= 0 and works.brain(worker).state == BrainScript.State.TASK
		_overlay.job_digger[slot] = worker if at_work else -1
		_overlay.widen_m[slot] = jobs.along_m(slot) if job == JobsScript.JOB_WIDEN else 0.0


# --- input ----------------------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	"""While a chamber is being placed: a left click places it, Esc or a right click cancels. True when
	the event was taken."""
	if actions.placing == ChambersScript.KIND_NONE:
		return false
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if _ground_at(button.position):
			place_chamber_at(_ground)
		return true
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		actions.cancel_chamber()
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		actions.cancel_chamber()
		return true
	return false


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


func select_at_screen(screen: Vector2) -> bool:
	"""A left click that picked no resident: select the finished tunnel under it, if any."""
	if not _ground_at(screen) or not actions.select_at(_ground):
		return false
	_mark.call(Vector3(_ground.x, 0.0, _ground.y), true)
	_refresh_in = 0.0
	return true


func place_chamber_at(at: Vector2) -> bool:
	"""Place the armed chamber near `at` (see tunnel_actions.gd CHAMBERS)."""
	var placed := actions.place_chamber(at, _selection.call() as PackedInt32Array)
	_mark.call(Vector3(at.x, 0.0, at.y), placed)
	_refresh_in = 0.0
	return placed


func on_action(name: StringName) -> void:
	"""A panel button (tunnel_panel.gd ACTION_*)."""
	var selection := _selection.call() as PackedInt32Array
	match name:
		PanelScript.ACTION_NEXT_WEATHER:
			works.weather.next_spell()
			works.say(WorksScript.WEATHER_ALERT % works.weather.readout(),
				WorksScript.ALERT_WEATHER % works.weather.alert_line())
		PanelScript.ACTION_EVENT:
			if not works.start_test_event():
				works.say("A demo event is already under way")
		PanelScript.ACTION_REPAIR:
			actions.order(_repair_job(), selection)
		PanelScript.ACTION_HOME:
			actions.begin_chamber(ChambersScript.KIND_HOME, selection)
		PanelScript.ACTION_CELLAR:
			actions.begin_chamber(ChambersScript.KIND_CELLAR, selection)
		_:
			actions.order(JOB_FOR_ACTION[name], selection)
	_refresh_in = 0.0


func _repair_job() -> int:
	"""The repair the selected tunnel needs: pumping out a flood, else clearing a fall."""
	var flooded := actions.has_selection() and _network.closed[actions.selected] == NetworkScript.CLOSED_FLOODED
	return JobsScript.JOB_PUMP if flooded else JobsScript.JOB_CLEAR


# --- the tunnel tool's hooks ------------------------------------------------------------------

func set_underground_view(on: bool) -> void:
	"""The underground view: strata, frames and lanterns, rooms; the weather's ground veil hides."""
	ground_view.set_underground_view(on)
	marks.set_underground_view(on)
	burrow_view.set_underground_view(on)
	weather_view.set_underground_view(on)


func set_planning(on: bool) -> void:
	"""A route is being laid (or no longer): the ground map tints the village."""
	ground_view.set_planning(on)


func crew_on_dig(slot: int, lead: int) -> int:
	"""A dig just ordered with the selection: everyone selected but the Foremole joins its crew."""
	return actions.add_crew(slot, _selection.call() as PackedInt32Array, lead)


func route_ground(points_u: PackedInt32Array, count: int) -> String:
	"""What a route laid so far runs through, metre by metre: e.g. "through loam 6 m, rock 2 m -- rock
	needs the badger"."""
	var metres := PackedInt32Array([0, 0, 0, 0])
	for k in range(1, count):
		var a := Vector2i(points_u[2 * k - 2], points_u[2 * k - 1])
		var b := Vector2i(points_u[2 * k], points_u[2 * k + 1])
		var steps := maxi(1, Rules.isqrt(Rules.leg_squared_u(points_u, k)) / Rules.QUANTUM_U)
		for s in steps:
			var at := a + (b - a) * (2 * s + 1) / (2 * steps)
			metres[works.ground.type_at(at.x, at.y)] += 1
	var parts := PackedStringArray()
	for kind in 4:
		if metres[kind] > 0:
			parts.append("%s %d m" % [GroundScript.NAMES[kind], metres[kind]])
	var text := "through " + ", ".join(parts) if not parts.is_empty() else ""
	return text + (" — rock needs the badger" if metres[GroundScript.ROCK] > 0 else "")


# --- the panel ------------------------------------------------------------------------------

func refresh_panel() -> void:
	"""Fill the panel from the works and the selected tunnel."""
	panel.show_status(works.weather.readout(), works.stores.stock_line() + " — the HUD's Wood and Stone are the settlement's",
		works.chambers.housing_line() + " — demo beds, not the HUD's Beds", works.stores.finds_line(), "\n".join(works.log_lines))
	if ground_view.planning:
		panel.show_tunnel(PanelScript.PLANNING, GroundViewScript.LEGEND, "", {})
		return
	if not actions.has_selection():
		panel.show_tunnel("", "", "", {})
		return
	var slot := actions.selected
	panel.show_tunnel("Tunnel %d — %s" % [slot + 1, PlanScript.length_text(_network.length_u[slot])],
		tunnel_text(slot), _repair_label(slot), _enabled_actions(slot))


func tunnel_text(slot: int) -> String:
	"""The selected tunnel's state, in lines."""
	var lines := PackedStringArray()
	lines.append("%s · %s · %s" % [BORE_NAMES[_network.bore[slot]], "braced" if _network.braced[slot] == 1 else "unbraced",
		"lit" if _network.lit[slot] == 1 else "unlit"])
	lines.append("Fits: " + _fits_text(slot))
	lines.append(_hazard_text(slot))
	var job := works.jobs.label(slot)
	if not job.is_empty():
		lines.append("Job: " + job)
	return "\n".join(lines)


func _fits_text(slot: int) -> String:
	"""Who fits the tunnel's bore, and who fits it hauling."""
	if _network.bore[slot] == Rules.BORE_WIDE:
		return "everybeast (hauling: all but the badger)"
	return "mice, moles, squirrels, hauling too (otters and the badger need it widened)"


func _hazard_text(slot: int) -> String:
	"""The tunnel's hazard state in words."""
	var hazards := works.hazards
	match _network.closed[slot]:
		NetworkScript.CLOSED_FLOODED:
			return "FLOODED — closed until pumped out"
		NetworkScript.CLOSED_COLLAPSED:
			return "ROOF FALLEN — closed until the fall is cleared"
	if _network.braced[slot] == 1:
		return "Safe: braced"
	if not hazards.exposed(slot):
		return "Safe ground (no wet or sandy stretch)"
	return "Wet ground: seep %d%% · sand: strain %d%% — bracing prevents both" % [hazards.seep_permille(slot) / 10,
		hazards.strain_permille(slot) / 10]


func _repair_label(slot: int) -> String:
	"""The repair button's words for the tunnel's state."""
	match _network.closed[slot]:
		NetworkScript.CLOSED_FLOODED:
			return "Pump out"
		NetworkScript.CLOSED_COLLAPSED:
			return "Clear the fall"
	return "Repair"


func _enabled_actions(slot: int) -> Dictionary:
	"""Which of the panel's tunnel actions can be pressed now (a pressed one still says why not)."""
	var closed := _network.closed[slot] != NetworkScript.CLOSED_NONE
	var busy := works.jobs.has_job(slot)
	_enabled[PanelScript.ACTION_WIDEN] = not closed and _network.bore[slot] == Rules.BORE_STANDARD
	_enabled[PanelScript.ACTION_BRACE] = not closed and _network.braced[slot] == 0
	_enabled[PanelScript.ACTION_LANTERNS] = not closed and _network.lit[slot] == 0
	_enabled[PanelScript.ACTION_REPAIR] = closed
	_enabled[PanelScript.ACTION_HOME] = not closed and not busy
	_enabled[PanelScript.ACTION_CELLAR] = not closed and not busy
	return _enabled
