extends Node3D
## The tunnel extensions, wired into the demo. Decision 0196 (live demo). Presentation only.
##
## The tunnel tool (tunnel_control.gd) builds this once and hands it the events it does not take
## itself. It owns the works (tunnel_works.gd: weather, ground, stores, crews, jobs, hazards,
## threats), the player's orders on them (tunnel_actions.gd), their drawings (the ground map, the tunnel
## marks, the rooms -- demo/burrow/room_view.gd, decision 0209 -- the threats, the weather) and the
## "Tunnels & burrows (demo)" panel (tunnel_panel.gd), and runs the works every frame on the demo clock.
##
## CONTROLS it adds (everything through the one command layer, demo/control/demo_command.gd):
##   left click a finished tunnel's mouth or route (no resident under the pointer)   select it
##   the panel's buttons on the selected tunnel   Widen · Brace · Hang lanterns · Repair (Pump out /
##                                               Clear the fall)
## (Burrow homes and root cellars are placed with the Dig tool's room tool, room_tool.gd.)
##   left click a dug burrow home or root cellar (below, or its mound)  select it: its fit-out in the panel
##   the panel's fit-out buttons on the selected room   + / − a fixture of each kind · Suggested layout
##
## THE FIT-OUT AND THE NIGHT (decision 0210, demo/burrow/): the rooms' fixtures (room_fixtures.gd, on the network as
## `fit`), who puts them in (fixture_crew.gd), how they look (fixture_view.gd), and the residents' night at home
## (night_routine.gd, on the demo calendar). Residents selected when a fixture is ordered put it in.
## THE CONSTRUCTION THEATRE (decision 0211): the warren's particle budget (warren_particles.gd), the dig faces' lanterns
## and clods (dig_theatre.gd), the crews' baskets (haul_view.gd, spoil_haul.gd), the hazards' warnings (hazard_view.gd)
## and the warren's signs on the surface (warren_signs.gd); tunnel_marks.gd puts braces and lanterns up one at a time
## and fixture_view.gd raises a fixture out of its chalk ring.
##   the panel's "Next weather (demo)" and "Test event (demo)"             run the demo calendar on
##                                                                          to the next weather (the
##                                                                          whole village: farm, date
##                                                                          and weather together) /
##                                                                          bring the next threat
##   a dig started (the Dig tool, B) with a digger AND others selected, or right click where a tunnel
##   being dug starts with residents selected:   they join the Foremole's dig crew
## Residents selected when a tunnel job is ordered become its worker or crew (tunnel_actions.gd).
##
## THE PANEL shares the HUD's right column with the farm's bed panel (demo/ui/demo_detail_zone.gd);
## `panel_wanted` asks for it when the player selects a tunnel or lays a route.
## The weather, the water and the notice feed are the demo's shared ones (demo_services.gd).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const ActionsScript := preload("res://demo/tunnel/tunnel_actions.gd")
const PanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const GroundViewScript := preload("res://demo/tunnel/tunnel_ground_view.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const EventsViewScript := preload("res://demo/events/events_view.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const FindPropsScript := preload("res://demo/tunnel/tunnel_find_props.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const Layers := preload("res://demo/demo_layers.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const FixtureViewScript := preload("res://demo/burrow/fixture_view.gd")
const FixtureCrewScript := preload("res://demo/burrow/fixture_crew.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const RoomTextScript := preload("res://demo/burrow/room_text.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")
const DigTheatreScript := preload("res://demo/tunnel/dig_theatre.gd")
const HazardViewScript := preload("res://demo/tunnel/hazard_view.gd")
const HaulViewScript := preload("res://demo/tunnel/haul_view.gd")
const SignsScript := preload("res://demo/tunnel/warren_signs.gd")
const WarrenKitScript := preload("res://demo/tunnel/warren_kit.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const FixtureCardScript := preload("res://demo/burrow/fixture_card.gd")

## The player did something on the tunnels (selected one, laid a route): show the tunnels panel.
signal panel_wanted

const PANEL_REFRESH_S: float = 0.2
## The hazards' warnings and the surface signs change over game minutes and days, so they are redrawn one frame in
## THEATRE_SLOW_FRAMES each, on different frames -- and at once when the network changes (a tunnel laid, opened or
## closed) -- (decision 0211: ~50 and ~25 us a pass over every segment).
const THEATRE_SLOW_FRAMES: int = 6
const JOB_FOR_ACTION: Dictionary = {&"widen": JobsScript.JOB_WIDEN, &"brace": JobsScript.JOB_BRACE,
	&"lanterns": JobsScript.JOB_LANTERNS}
const BORE_NAMES: Array[String] = ["standard bore (1 m)", "wide bore (2 x 3 m)", "room"]
const SKIPPED: String = "Skipped %d h ahead on the demo calendar: %s"
const NO_SKIP: String = "The weather follows the farm's calendar, which is not running here"

## The mole's pick: the library model lies with its head at -X and its handle out to +X (read off a
## top render). In the right hand bone's frame (+Y along the fingers) it is gripped PICK_GRIP_SHARE of
## its length from the handle's end, the handle across the fist and the head standing up.
const PICK_KEY: StringName = &"mole_pick"
const PICK_GRIP_SHARE: float = 0.14
const PICK_EULER_DEG: Vector3 = Vector3(0.0, 90.0, 90.0)
## The finds shelf's roundel colours for a find with no model icon: a root store, a relic.
const ROOT_STORE_SWATCH: Color = Color(0.45, 0.33, 0.22)
const RELIC_SWATCH: Color = Color(0.62, 0.52, 0.3)

var works: WorksScript = null
## Who can dig, by actor index (see `diggers_of`).
var can_dig: PackedByteArray = PackedByteArray()
var actions: ActionsScript = null
var panel: PanelScript = null
var marks: MarksScript = null
var ground_view: GroundViewScript = null
var room_view: RoomViewScript = null
var events_view: EventsViewScript = null
var find_props: FindPropsScript = null
var weather_view: WeatherViewScript = null
var fixture_view: FixtureViewScript = null
var fixture_crew: FixtureCrewScript = FixtureCrewScript.new()
var night: NightScript = NightScript.new()
## The construction theatre (see THE CONSTRUCTION THEATRE).
var particles: ParticlesScript = null
var dig_theatre: DigTheatreScript = null
var hazard_view: HazardViewScript = null
var haul_view: HaulViewScript = null
var signs: SignsScript = null
## Which of THEATRE_SLOW_FRAMES this frame is, and the network revision the slow ones last saw (a change redraws
## them at once: see THEATRE_SLOW_FRAMES).
var _theatre_frame: int = 0
var _theatre_seen: int = -1
## Where a large bed's nook may not reach (room_fixtures.gd `nook_site`): the water, the buildings, the village.
var nook_site: RoomsScript.Site = RoomsScript.Site.new()
## The room selected for its fit-out (-1: none), as (row, generation).
var selected_room: int = -1
var selected_room_gen: int = 0

var _cast: DemoCastScript = null
## The demo's shared props (demo_services.gd): brace, rubble, lanterns, finds, room furniture.
var _props: PropsScript = null
var _network: GraphScript = null
var _overlay: OverlayScript = null
var _camera: Camera3D = null
## The underground view: its plane is where a click lands, its cap what rooms open (none: the ground).
var _view: ViewScript = null
var _selection: Callable = Callable()
var _mark: Callable = Callable()
var _refresh_in: float = 0.0
var _weather_skip: Callable = Callable()
var _enabled: Dictionary = {}
## The action cards (decision 0332): one card filled per button, each button's card text, what an order would
## interrupt (`interrupt(who) -> String`, demo_command.gd `interrupt_text`; set_interrupt), the residents' names.
var _card: CardScript = CardScript.new()
var _tips: Dictionary = {}
var _interrupt: Callable = Callable()
var _names: PackedStringArray = PackedStringArray()
var _fit_keys: Array[StringName] = []
var _ground: Vector2 = Vector2.ZERO
## The stores' revision the finds shelf was last drawn for.
var _finds_seen: int = -1
## The room template the room tool is placing (underground_rooms.gd TEMPLATE_*), or TEMPLATE_NONE: the panel's
## heading names it (tunnel_control.gd begin_room / end_room keep it).
var placing_room: int = RoomsScript.TEMPLATE_NONE
## The tunnel the marks last drew as selected (-1: none; -2: not drawn yet).
var _marked: int = -2
var _calendar: CalendarScript = null
## `stored(r) -> int`: how much food root cellar row `r` holds, whole units (demo_farm.gd `cellar_stored_u`).
var _stored: Callable = Callable()


func configure(cast: DemoCastScript, camera: Camera3D, overlay: OverlayScript, bounds_u: Rect2i,
		selection: Callable, mark: Callable, notice: Callable, services: ServicesScript = null) -> void:
	"""Wire the extensions for this cast, picking through this camera, drawing beside `overlay`.
	`selection() -> PackedInt32Array`, `mark(at, accepted)` and `notice(text)` are the tunnel tool's;
	`services` the demo's shared weather, water and notice feed (none: a fresh set)."""
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
	var brains: Array[BrainScript] = []
	for i in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		species.append(actor.species)
	works.setup(cast.space(), brains, species, bounds_u, notice, services)
	can_dig = diggers_of(cast)
	actions = ActionsScript.new(works, cast.space(), can_dig, names, bounds_u)
	_props = services.props if services != null else PropsScript.new()
	_arm_diggers(can_dig)
	_build_views()
	_build_theatre()
	_calendar = services.calendar if services != null else CalendarScript.new()
	_start_living(brains, names, bounds_u)


func _start_living(brains: Array[BrainScript], names: PackedStringArray, bounds_u: Rect2i) -> void:
	"""The fit-out's crew and the night (see THE FIT-OUT AND THE NIGHT): beds by the residents' heights, the bedless to
	the hall (its steps are its door), the alarm while a threat is under way. The names are kept for the cards."""
	_names = names
	nook_site.bounds_u = bounds_u
	nook_site.water = works.water.crosses_water
	_network.fit.nook_site = nook_site
	var heights := PackedInt32Array()
	for i in _cast.actor_count():
		heights.append(Rules.to_u((_cast.actor(i) as DemoActorScript).height_m))
	fixture_crew.configure(_network, brains)
	night.configure(_network, brains, names, heights, _calendar, works.notices)
	night.set_incidents(works.incidents)
	night.set_alarm(func() -> bool: return works.events.active)
	var hall: int = _cast.space().poi_names.find(NightScript.HALL_POI)
	if hall >= 0:
		night.set_hall(_cast.space().poi_position[hall])
	fixture_view.set_lit(hearth_lit)


func hearth_lit() -> bool:
	"""Whether it is the hearths' hours on the calendar (night_routine.gd HEARTH_FROM_HOUR..HEARTH_TO_HOUR)."""
	return NightScript.is_hearth_hour(_calendar.now().hour)


func set_stored(stored: Callable) -> void:
	"""`stored(r) -> int`: how much food root cellar row `r` holds (its racks cannot be taken out below it)."""
	_stored = stored


func skill_text(who: int, alone: bool) -> String:
	"""The party panel's digging words for resident `who` (demo_command.gd `add_skill_text`): the long form
	alone ("Digging 3 · XP 45000/80000"), the short one in a list ("dig 3")."""
	var skills := works.crew.skills
	return skills.line_of(who) if alone else skills.short_of(who)


static func diggers_of(cast: DemoCastScript) -> PackedByteArray:
	"""Who can dig, by actor index: every body that fits a standard bore (dig_skills.gd, decision 0208: the
	body decides, not the species)."""
	var out := PackedByteArray()
	for i in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		out.append(1 if Rules.fits_bore(Rules.to_u(actor.height_m), Rules.to_u(actor.brain.radius)) else 0)
	return out


func _arm_diggers(diggers: PackedByteArray) -> void:
	"""Every digger holds the pick while it digs (demo_actor.gd set_tool)."""
	for i in diggers.size():
		if diggers[i] == 1:
			(_cast.actor(i) as DemoActorScript).set_tool(_props.mesh_of(PICK_KEY), pick_fit(_props))


func _build_views() -> void:
	"""The drawings and the panel."""
	marks = MarksScript.new()
	add_child(marks)
	marks.configure(_network, works.hazards, _props, _cast.clock)
	ground_view = GroundViewScript.new()
	add_child(ground_view)
	ground_view.configure(works.ground)
	room_view = RoomViewScript.new()
	add_child(room_view)
	room_view.configure(_network, _props, _cast.space(), marks)
	room_view.set_today(_overlay.bores.today)
	fixture_view = FixtureViewScript.new()
	add_child(fixture_view)
	fixture_view.configure(_network, _props, marks.lights, _cast.clock)
	find_props = FindPropsScript.new()
	add_child(find_props)
	find_props.configure(works, _network, _props)
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


func _build_theatre() -> void:
	"""The construction theatre's pieces (see THE CONSTRUCTION THEATRE), handed what they draw from."""
	particles = ParticlesScript.new()
	add_child(particles)
	particles.configure()
	dig_theatre = DigTheatreScript.new()
	add_child(dig_theatre)
	dig_theatre.configure(_network, _cast.space(), particles, marks.lights, _overlay.mound)
	hazard_view = HazardViewScript.new()
	add_child(hazard_view)
	hazard_view.configure(_network, works.hazards, _overlay.bores, particles)
	haul_view = HaulViewScript.new()
	add_child(haul_view)
	haul_view.configure(_network, _cast, particles)
	signs = SignsScript.new()
	add_child(signs)
	signs.configure(_network, _overlay.bores)
	marks.set_theatre(works.jobs, particles)
	fixture_view.set_particles(particles)
	room_view.add_ground_sampler(ground_samples)


func ground_samples(parent: Node3D) -> void:
	"""One of each piece the theatre draws on the ground, under `parent`, for the rooms' ground prewarm (room_view.gd
	`begin_surface_prewarm`): a seam and a vent, a mouth's gateway with its lantern, a basket and a loaded one, and the
	clods and the dust already flying (a particle system draws instanced, its own pipeline)."""
	signs.sample_into(parent)
	for mesh: Mesh in [MouthScript.gateway_mesh(), WarrenKitScript.basket(), WarrenKitScript.loaded_basket()]:
		var sample := MeshInstance3D.new()
		sample.mesh = mesh
		parent.add_child(sample)
	for mesh: Mesh in [ParticlesScript.clod_mesh(), ParticlesScript.dust_mesh()]:
		var flying := CPUParticles3D.new()
		flying.mesh = mesh
		flying.amount = 1
		parent.add_child(flying)
		flying.preprocess = 0.5
		flying.emitting = true


func set_view(view: ViewScript) -> void:
	"""The underground view (decision 0206): its plane for every click, its cap for the rooms dug, and
	its prewarm registry for everything these drawings show in it."""
	_view = view
	room_view.set_cap(view.cap, view.caps[Rules.LEVEL_2])
	marks.register(view.prewarm)
	marks.lights.follow(func() -> bool: return view.on, view.focus)
	room_view.register(view.prewarm)
	fixture_view.register(view.prewarm)
	find_props.register(view.prewarm)
	dig_theatre.register(view.prewarm)


func set_world(world: Node, under_u: PackedInt32Array) -> void:
	"""The world whose sun and haze the weather dims, whose buildings the actions keep, and whose ground the
	rooms' mounds wear (room_view.gd `set_turf`)."""
	actions.set_under(under_u)
	nook_site.under_u = under_u.duplicate()
	var ground := world.get_node_or_null(^"Ground") as MeshInstance3D
	if ground != null:
		room_view.set_turf(ground.get_active_material(0))
	weather_view.configure(works.weather, _cast.clock, world)


func set_hud(hud_root: Control) -> void:
	"""The HUD whose resident journal the panel keeps clear of."""
	panel.watch_hud(hud_root)


func set_interrupt(interrupt: Callable) -> void:
	"""`interrupt(who) -> String`: what an order would take resident `who` from (the action cards' line)."""
	_interrupt = interrupt


func set_weather_skip(skip: Callable) -> void:
	"""`skip() -> int`: what "Next weather (demo)" does -- run the demo's one calendar on to the next
	weather (demo_farm.gd `skip_to_next_weather`), returning the hours run."""
	_weather_skip = skip


# --- per frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the works on this frame's demo time, keep the drawings in step, and refresh the panel a few
	times a second (real time: the panel works while paused)."""
	works.step(_cast.clock.frame_usec)
	night.step()
	fixture_crew.update(_cast.clock.frame_usec)
	_feed_overlay()
	if _selection_changed():
		marks.select(_marked)
	marks.refresh()
	room_view.refresh()
	fixture_view.refresh(delta)
	find_props.refresh()
	_run_theatre()
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		refresh_panel()
		panel.follow_hud()


func _run_theatre() -> void:
	"""One frame of the construction theatre, on the demo clock."""
	particles.set_speed(float(_cast.clock.speed))
	dig_theatre.refresh()
	haul_view.refresh()
	_theatre_frame = (_theatre_frame + 1) % THEATRE_SLOW_FRAMES
	var changed := _network.revision != _theatre_seen
	_theatre_seen = _network.revision
	if changed or _theatre_frame == 0:
		hazard_view.refresh()
	if changed or _theatre_frame == THEATRE_SLOW_FRAMES / 2:
		signs.refresh()


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
	for slot in Rules.MAX_SEGMENTS:
		var job := jobs.kind[slot] if jobs.has_job(slot) else JobsScript.JOB_NONE
		var digs := job == JobsScript.JOB_WIDEN or job == JobsScript.JOB_CLEAR
		var worker := jobs.worker[slot]
		var at_work := digs and worker >= 0 and works.brain(worker).state == BrainScript.State.TASK
		_overlay.job_digger[slot] = worker if at_work else -1
		_overlay.widen_m[slot] = jobs.along_m(slot) if job == JobsScript.JOB_WIDEN else 0.0


# --- input ----------------------------------------------------------------------------------

func _ground_at(screen: Vector2) -> bool:
	"""The point under a screen point on the view's plane (the ground, or the level's floor in the U
	view), into _ground. False when the ray misses it."""
	var at: Vector2 = _view.ground_at(screen) if _view != null \
			else Layers.pick_ground(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), 0.0)
	if at == Vector2.INF:
		return false
	_ground = at
	return true


func select_at_screen(screen: Vector2) -> bool:
	"""A left click that picked no resident: select the dug room under it (below, or its mound), else the finished
	tunnel under it, if any."""
	if not _ground_at(screen):
		return false
	var level := shown_level()
	var r := room_at(_ground, level)
	if r >= 0:
		select_room(r)
	elif actions.select_at(_ground, level):
		selected_room = -1
	else:
		return false
	_mark.call(Vector3(_ground.x, 0.0, _ground.y), true)
	_refresh_in = 0.0
	panel_wanted.emit()
	return true


func shown_level() -> int:
	"""The level a click picks on (decision 0212): the U view's, or on the surface level 1 (its mounds)."""
	return _view.level if _view != null and _view.on else Rules.TOP_LEVEL


func room_at(at: Vector2, level: int = Rules.TOP_LEVEL) -> int:
	"""The dug room on `level` whose void lies under `at` (m; -1: none)."""
	var rooms: RoomsScript = _network.rooms
	for r in RoomsScript.MAX_ROOMS:
		if rooms.is_done(_network, r) and rooms.level[r] == level and rooms.gap_of(r, Vector2i(Rules.to_u(at.x), Rules.to_u(at.y))) == 0:
			return r
	return -1


func select_room(r: int) -> void:
	"""Select room `r` for its fit-out (a tunnel selected before is let go)."""
	actions.clear_selection()
	selected_room = r
	selected_room_gen = _network.rooms.generation[r]
	_refresh_in = 0.0


func deselect_room() -> void:
	"""Select no room (an empty click, Esc)."""
	selected_room = -1
	_refresh_in = 0.0


func has_room_selected() -> bool:
	"""Whether a room that still stands is selected."""
	return selected_room >= 0 and _network.rooms.is_ref(selected_room, selected_room_gen)


func on_action(name: StringName) -> void:
	"""A panel button (tunnel_panel.gd ACTION_*)."""
	var selection := _selection.call() as PackedInt32Array
	if String(name).begins_with(RoomTextScript.FIT_PREFIX):
		fit_action(name, selection)
		_refresh_in = 0.0
		return
	match name:
		PanelScript.ACTION_NEXT_WEATHER:
			_skip_weather()
		PanelScript.ACTION_EVENT:
			if not works.start_test_event():
				works.tell("A demo event is already under way")
		PanelScript.ACTION_REPAIR:
			actions.order(_repair_job(), selection)
		_:
			actions.order(JOB_FOR_ACTION[name], selection)
	_refresh_in = 0.0


func fit_action(name: StringName, selection: PackedInt32Array) -> int:
	"""A fit-out button on the selected room (room_text.gd FIT_*): add or take out one fixture of a kind, or the
	suggested layout; the selected residents put what was ordered in. REFUSE_NONE, or why not (said in the log)."""
	if not has_room_selected():
		return FixturesScript.REFUSE_NOT_DUG
	var r := selected_room
	var parts := String(name).split(":")
	var code := FixturesScript.REFUSE_NONE
	if parts[1] == RoomTextScript.FIT_SUGGEST:
		code = _network.fit.suggest(_network, r, works.stores)
	elif parts[1] == RoomTextScript.FIT_ADD:
		code = _network.fit.order(_network, r, int(parts[2]), works.stores)
	else:
		var stored: int = int(_stored.call(r)) if _stored.is_valid() else 0
		code = _network.fit.take_out(_network, r, int(parts[2]), works.stores, stored)
	works.tell(RoomTextScript.answer(_network, r, parts, code, works.stores, _stored))
	if code == FixturesScript.REFUSE_NONE and parts[1] != RoomTextScript.FIT_TAKE and not selection.is_empty():
		fixture_crew.give_selected(r, selection)
	return code


func _skip_weather() -> void:
	"""Run the calendar on to the next weather, and say how far; without a calendar, say why not."""
	if not _weather_skip.is_valid():
		works.tell(NO_SKIP)
		return
	var hours: int = int(_weather_skip.call())
	works.tell(SKIPPED % [hours, works.weather.readout()])


func _repair_job() -> int:
	"""The repair the selected tunnel needs: pumping out a flood, else clearing a fall."""
	var flooded := actions.has_selection() and _network.closed[actions.selected] == GraphScript.CLOSED_FLOODED
	return JobsScript.JOB_PUMP if flooded else JobsScript.JOB_CLEAR


# --- the tunnel tool's hooks ------------------------------------------------------------------

func set_planning(on: bool) -> void:
	"""A route is being laid (or no longer): the ground map tints the village (and the panel's legend
	shows, so the panel comes forward)."""
	ground_view.set_planning(on)
	if on:
		panel_wanted.emit()


func crew_on_dig(slot: int, lead: int) -> int:
	"""A dig just ordered with the selection: everyone selected but the Foremole joins its crew."""
	return actions.add_crew(slot, _selection.call() as PackedInt32Array, lead)


func route_ground(points_u: PackedInt32Array, count: int, level: int = Rules.TOP_LEVEL) -> String:
	"""What a route laid so far on `level` runs through, metre by metre (that level's ground, decision 0212): e.g.
	"through loam 6 m, rock 2 m -- rock needs the badger"."""
	var metres := PackedInt32Array([0, 0, 0, 0])
	for k in range(1, count):
		var a := Vector2i(points_u[2 * k - 2], points_u[2 * k - 1])
		var b := Vector2i(points_u[2 * k], points_u[2 * k + 1])
		var steps := maxi(1, Rules.isqrt(Rules.leg_squared_u(points_u, k)) / Rules.QUANTUM_U)
		for s in steps:
			var at := a + (b - a) * (2 * s + 1) / (2 * steps)
			metres[works.ground.type_at_level(at.x, at.y, level)] += 1
	var parts := PackedStringArray()
	for kind in 4:
		if metres[kind] > 0:
			parts.append("%s %d m" % [GroundScript.NAMES[kind], metres[kind]])
	var text := "through " + ", ".join(parts) if not parts.is_empty() else ""
	return text + (" — rock needs the badger" if metres[GroundScript.ROCK] > 0 else "")


# --- the panel ------------------------------------------------------------------------------

static func pick_fit(props: PropsScript) -> Transform3D:
	"""The pick in the hand bone's frame (see PICK_*)."""
	var bound: AABB = props.drawn_bound(PICK_KEY)
	var grip := Vector3(bound.end.x - bound.size.x * PICK_GRIP_SHARE, bound.get_center().y, bound.get_center().z)
	var turn := Basis.from_euler(PICK_EULER_DEG * (PI / 180.0))
	return Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -grip) * props.fit_of(PICK_KEY)


func _show_finds() -> void:
	"""The panel's finds shelf: flint, clay and root stores with their counts, then each relic found
	(up to the shelf's room), each as its model's icon or a roundel."""
	var icons: Array[Texture2D] = []
	var counts := PackedInt32Array()
	var tally: PackedInt32Array = works.stores.finds
	for kind: int in [FindsScript.FIND_FLINT, FindsScript.FIND_CLAY, FindsScript.FIND_ROOT_STORE]:
		if tally[kind] > 0:
			icons.append(_props.icon_of(FindsScript.FIND_MODEL[kind], ROOT_STORE_SWATCH))
			counts.append(tally[kind])
	for relic: int in range(1, tally[FindsScript.FIND_RELIC] + 1):
		if icons.size() >= PanelScript.FIND_SLOTS:
			break
		icons.append(_props.icon_of(FindsScript.model_of(FindsScript.FIND_RELIC, relic), RELIC_SWATCH))
		counts.append(0)
	panel.show_finds(icons, counts)

func _planning_heading() -> String:
	"""The panel's heading while the Dig tool is out: laying a tunnel, or placing the room being placed."""
	if placing_room == RoomsScript.TEMPLATE_NONE:
		return PanelScript.PLANNING
	return PanelScript.PLACING_ROOM % RoomsScript.NAMES[placing_room].to_lower()


func refresh_panel() -> void:
	"""Fill the panel from the works and the selected tunnel."""
	panel.show_status(works.weather.readout(), works.stores.stock_line(), _network.rooms.housing_line(_network),
		works.stores.finds_line(), "\n".join(works.log_lines))
	if works.stores.revision != _finds_seen:
		_finds_seen = works.stores.revision
		_show_finds()
	if ground_view.planning:
		panel.show_room("", "", [], "", false)
		panel.show_tunnel(_planning_heading(), GroundViewScript.LEGEND, "", {})
		return
	if has_room_selected() and not actions.has_selection():
		var rows: Array[Dictionary] = RoomTextScript.palette_rows(_network, selected_room)
		var suggest_ok := _fit_cards(selected_room, rows)
		panel.show_room(RoomTextScript.title(_network, selected_room), RoomTextScript.body(_network, selected_room, night,
			_stored), rows, RoomTextScript.suggest_text(_network, selected_room), suggest_ok)
		panel.show_tunnel("", "", "", {})
		for key: StringName in _tips:
			if String(key).begins_with(RoomTextScript.FIT_PREFIX):
				panel.set_tip(key, _tips[key])
		return
	panel.show_room("", "", [], "", false)
	if not actions.has_selection():
		panel.show_tunnel("", "", "", {})
		return
	var slot := actions.selected
	var kind := "ramp, " if _network.seg_kind[slot] == GraphScript.SEG_RAMP else ""
	panel.show_tunnel("Tunnel %d — %s%s" % [slot + 1, kind, PlanScript.length_text(_network.length_u[slot])],
		tunnel_text(slot), _repair_label(slot), _enabled_actions())
	for key: StringName in PanelScript.TUNNEL_ACTIONS:
		panel.set_tip(key, _tips[key])


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
	var pending := job_list_text()
	if not pending.is_empty():
		lines.append(pending)
	return "\n".join(lines)


func job_list_text() -> String:
	"""THE JOB LIST (underground_graph.gd): every dig with work left, in order, by its first tunnel or its room
	-- e.g. "Digs: Tunnel 4 40%, Burrow home 1 waiting 0%" ("" with none)."""
	var list := PackedInt32Array()
	_network.job_list_into(list)
	if list.is_empty():
		return ""
	var parts := PackedStringArray()
	for p in list:
		var first := _network.first_of_piece(p)
		var who := _network.piece_digger[p]
		var digging := who >= 0 and who < works.resident_count() and works.brain(who).dig_tunnel >= 0
		parts.append("%s %s%d%%" % [piece_name(p, first), "" if digging else "waiting ", _network.piece_percent(p)])
	return "Digs: " + ", ".join(parts)


func piece_name(p: int, first: int) -> String:
	"""How the job list names a dig: its room ("Burrow home 1"), else its first tunnel ("Tunnel 4")."""
	var r: int = _network.piece_room[p]
	if r >= 0:
		return "%s %d" % [RoomsScript.NAMES[_network.rooms.template[r]], r + 1]
	return "Tunnel %d" % (first + 1)


func _fits_text(slot: int) -> String:
	"""Who fits the tunnel's bore, and who fits it hauling."""
	if _network.bore[slot] == Rules.BORE_WIDE:
		return "everybeast (hauling: all but the badger)"
	return "mice, moles, squirrels, hauling too (otters and the badger need it widened)"


func _hazard_text(slot: int) -> String:
	"""The tunnel's hazard state in words."""
	var hazards := works.hazards
	match _network.closed[slot]:
		GraphScript.CLOSED_FLOODED:
			return "FLOODED — closed until pumped out"
		GraphScript.CLOSED_COLLAPSED:
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
		GraphScript.CLOSED_FLOODED:
			return "Pump out"
		GraphScript.CLOSED_COLLAPSED:
			return "Clear the fall"
	return "Repair"


func _enabled_actions() -> Dictionary:
	"""Which of the panel's tunnel actions can be pressed now: each one's ACTION CARD allows it (decision 0332:
	tunnel_actions.gd `preview_into`, the order's own `refusal` -- the tunnel, a worker, the stores), the card kept
	in `_tips` for its tooltip."""
	var selection := _selection.call() as PackedInt32Array
	for key: StringName in PanelScript.TUNNEL_ACTIONS:
		var job: int = _repair_job() if key == PanelScript.ACTION_REPAIR else JOB_FOR_ACTION[key]
		actions.preview_into(_card, job, selection)
		_enabled[key] = _card.is_ok()
		_tips[key] = _card_text()
	return _enabled


func _card_text() -> String:
	"""The filled card's text, with what its resident would stop doing."""
	if _card.worker >= 0 and _interrupt.is_valid():
		_card.interrupts = String(_interrupt.call(_card.worker))
	return _card.text()


func _fit_cards(r: int, rows: Array[Dictionary]) -> bool:
	"""The selected room's fit-out cards (fixture_card.gd), kept in `_tips`: each palette row's "+" and "−" pressable
	when the fit-out's own refusal allows it (written into `rows`, which the panel enables them by). Returns whether
	the suggested layout may be ordered."""
	var selection := _selection.call() as PackedInt32Array
	if _fit_keys.is_empty():
		_build_fit_keys()
	for row: Dictionary in rows:
		var kind: int = row["kind"]
		FixtureCardScript.add_into(_card, _network, r, kind, works.stores, selection, fixture_crew, _names)
		row["add"] = _card.is_ok()
		_tips[_fit_keys[2 * kind]] = _card_text()
		FixtureCardScript.take_into(_card, _network, r, kind, works.stores, _stored)
		row["take"] = _card.is_ok()
		_tips[_fit_keys[2 * kind + 1]] = _card_text()
	FixtureCardScript.suggest_into(_card, _network, r, works.stores, selection, fixture_crew, _names)
	_tips[_fit_keys[_fit_keys.size() - 1]] = _card_text()
	return _card.is_ok()


func _build_fit_keys() -> void:
	"""The fit-out buttons' action names, made once: each kind's "+" and "−" (2 kind, 2 kind + 1), then the
	suggested layout's (tunnel_panel.gd's own keys)."""
	for kind: int in RoomsScript.FIXTURE_NAMES.size():
		_fit_keys.append(StringName("%s%s:%d" % [RoomTextScript.FIT_PREFIX, RoomTextScript.FIT_ADD, kind]))
		_fit_keys.append(StringName("%s%s:%d" % [RoomTextScript.FIT_PREFIX, RoomTextScript.FIT_TAKE, kind]))
	_fit_keys.append(StringName(RoomTextScript.FIT_PREFIX + RoomTextScript.FIT_SUGGEST))
