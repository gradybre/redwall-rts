extends Node3D
## The live demo's farm: individual pantry ingredients grown on the six crop beds by the settlement's
## own crop arithmetic, worked by the residents, stored and spoiling in the pantry, and helped by the
## moles' tunnels. Decision 0196. Presentation-only: it writes nothing into the running settlement.
##
## PLAYER VERBS (all by mouse, with the demo's selection):
##   left click a bed                 open its panel (the resident selection is kept)
##   right click a bed, residents     the nearest selected resident does the bed's most pressing work
##     selected                       (clear > harvest > water a dry bed > cover before frost > sow)
##   bed panel buttons                Plant… (the crop picker), Water, Harvest, Clear, Compost, Cover,
##                                    Raise and Bank (tunnel spoil), Rest (fallow), Cancel jobs --
##                                    given to the selected residents, or queued for the field crew
##   V                                map overlay: off -> moisture -> ripeness
##   K, or the HUD's Food command     the Pantry: stock per ingredient, freshness, dishes it feeds
##   Esc                              close the Pantry, then the bed panel
## The routine crew (the fieldworker and the gatherer) take queued jobs and the farm's own harvest
## and clearing jobs whenever they are wandering.
##
## TIME. Everything runs on the demo clock the cast advances first each frame (demo_clock.gd):
## `frame_usec` drives the farm calendar (farm_calendar.gd) and the crew's work, so the HUD's pause
## freezes the farm and 2x / 4x speed it up.
##
## Wiring (demo_village.gd `_build_farm`): the world, the cast, the command layer (for the selection,
## order marks, click hooks and the tunnel tool), the HUD shell, the storage providers (root cellars)
## as Callables -- see farm_storage.gd for the provider API -- and the one water query
## (farm_water.gd `edge_query()`).

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const AlertsScript := preload("res://demo/farm/farm_alerts.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const HudScript := preload("res://demo/farm/farm_hud.gd")
const ViewScript := preload("res://demo/farm/farm_view.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const Water := preload("res://demo/farm/farm_water.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const TunnelControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const STORE_POI: StringName = &"store_front"
const STORE_ID: StringName = &"store"
const WELL_ID: StringName = &"well"
const PANEL_REFRESH_S: float = 0.25
const NO_BED: int = -1

var sim: SimScript = SimScript.new()
var tunnels: TunnelsScript = TunnelsScript.new()
var crew: CrewScript = CrewScript.new()
var alerts: AlertsScript = AlertsScript.new()
var recipes: RecipesScript = RecipesScript.new()
var hud: HudScript = HudScript.new()
var storage: StorageScript = null
var pantry: PantryScript = null
var view: ViewScript = null
var bed_panel: BedPanelScript = null
var pantry_panel: PantryPanelScript = null
var selected_bed: int = NO_BED

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _camera: Camera3D = null
var _refresh_in: float = 0.0
var _events: PackedInt32Array = PackedInt32Array()
var _spoiled: PackedInt32Array = PackedInt32Array()
var _lines: PackedStringArray = PackedStringArray()
var _water: PackedByteArray = PackedByteArray([0, 0])
var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(manifest: Dictionary, world: DemoWorldScript, cast: DemoCastScript, command: DemoCommandScript,
		camera: Camera3D, shell: UiShell, providers: Array[Callable], water_edge: Callable) -> void:
	"""Build the farm over this village (see the header on the wiring). `water_edge(x_u, z_u) -> bool`
	is the one water query (farm_water.gd)."""
	name = "DemoFarm"
	_cast = cast
	_command = command
	_camera = camera
	storage = StorageScript.new(store_position(cast))
	for provider: Callable in providers:
		storage.add_provider(provider)
	pantry = PantryScript.new(storage)
	tunnels.water_edge = water_edge
	crew.configure(cast, sim, pantry, tunnels, well_position(), _say)
	recipes.load_index()
	_build_view(manifest, world, command)
	_build_panels()
	hud.bind(shell)
	hud.unlock_food_command(toggle_pantry)
	command.set_ground_handlers(on_ground_click, on_ground_order)
	command.set_task_text(crew.task_text)


func _build_view(manifest: Dictionary, world: DemoWorldScript, command: DemoCommandScript) -> void:
	"""The beds and the pond, over the world's hidden crop pieces; heaps shrink with spoil taken."""
	view = ViewScript.new()
	add_child(view)
	view.build(manifest, sim)
	var village: Node = world.get_node_or_null(^"Village") if world != null else null
	if village != null:
		ViewScript.hide_world_beds(village)
	if world != null:
		_build_placeholder_pond(world)
	var tool: TunnelControlScript = command.tunnels() if command != null else null
	if tool != null:
		view.follow_tunnels(tunnels, _cast.space().tunnels, tool.overlay, func() -> bool: return tool.view != null and tool.view.on)


func _build_placeholder_pond(world: DemoWorldScript) -> void:
	"""PLACEHOLDER (farm_water.gd): the reed pond's disc, and no grass or mushrooms in it. Delete this
	and its call when the village's real water (feat/demo-water) merges."""
	world.add_child(Water.build_placeholder())
	world.hide_cover(PackedVector2Array(), 0.0, PackedVector3Array([Water.placeholder_obstacle()]))


func _build_panels() -> void:
	"""The bed panel and the Pantry, wired to the farm's verbs."""
	bed_panel = BedPanelScript.new()
	bed_panel.configure(sim, crew)
	add_child(bed_panel)
	bed_panel.verb_requested.connect(func(kind: int) -> void: order(kind, selected_bed))
	bed_panel.crop_picked.connect(plant)
	bed_panel.fallow_toggled.connect(func() -> void: sim.set_fallow(selected_bed, not sim.is_fallow(selected_bed)))
	bed_panel.cancel_requested.connect(func() -> void: crew.cancel_bed(selected_bed))
	bed_panel.close_requested.connect(func() -> void: select_bed(NO_BED))
	pantry_panel = PantryPanelScript.new()
	pantry_panel.configure(sim, pantry, recipes)
	add_child(pantry_panel)
	pantry_panel.compost_requested.connect(compost_spoiled)
	pantry_panel.close_requested.connect(toggle_pantry)


static func store_position(cast: DemoCastScript) -> Vector2:
	"""Where harvests are delivered: the covered store's work spot, or the store itself in a village
	laid out without that spot."""
	var space := cast.space()
	var poi: int = space.poi_names.find(STORE_POI)
	if poi >= 0:
		return space.poi_position[poi]
	return _building_at(STORE_ID)


static func well_position() -> Vector2:
	"""Where water is fetched: the well."""
	return _building_at(WELL_ID)


static func _building_at(id: StringName) -> Vector2:
	"""A layout building's position. Both ids the farm asks for are in world_layout.gd BUILDINGS
	(test_demo_farm_ui.gd checks), so a missing one is a programming error."""
	for entry: Dictionary in Layout.BUILDINGS:
		if entry["id"] == id:
			return entry["at"]
	assert(false, "the farm needs the %s building" % id)
	return Vector2.INF


# --- per frame ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the farm on this frame's demo time; keep the HUD's Food figure and the panels current."""
	step(_cast.clock.frame_usec if _cast != null else 0)
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		bed_panel.refresh()
		pantry_panel.refresh()


func step(usec: int) -> void:
	"""Advance the farm by `usec` demo microseconds: calendar, pantry ageing, the crew's work."""
	var hours: int = sim.advance_usec(usec)
	for hour: int in hours:
		pantry.age_hour(sim.season())
	if hours > 0:
		_hourly()
	crew.update(usec)
	hud.sync(pantry.total_units())


func _hourly() -> void:
	"""Once per farm hour: storage providers, tunnel water, the routine jobs, and the alerts."""
	pantry.refresh_locations()
	var network: NetworkScript = _cast.space().tunnels
	for bed: int in Catalog.BED_COUNT:
		tunnels.water_of_into(network, bed, _water)
		sim.set_tunnel_water(bed, _water[0] == 1, _water[1] == 1)
	crew.raise_routine_jobs()
	_events.clear()
	sim.take_events_into(_events)
	_spoiled.clear()
	pantry.take_spoiled_items_into(_spoiled)
	_lines.clear()
	alerts.collect_into(sim, _events, _spoiled, _lines)
	for line: String in _lines:
		bed_panel.push_news(line)
		HudScript.alert(line)


# --- the player's verbs -----------------------------------------------------------------------------

func order(kind: int, bed: int) -> String:
	"""Order `kind` on `bed`: to the selected residents, or queued for the crew. Says what happened."""
	if not Catalog.is_bed(bed):
		return ""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	var said: String = crew.order(kind, bed, members, JobsScript.ORIGIN_PLAYER)
	bed_panel.show_message(said)
	bed_panel.refresh()
	return said


func plant(item: int) -> String:
	"""The picker's choice: this bed grows `item` next, and its sowing is ordered."""
	var chosen: bool = sim.choose(selected_bed, item).ok
	bed_panel.close_picker()
	return order(JobsScript.KIND_SOW, selected_bed) if chosen else ""


func pressing_kind_into(bed: int, out: IntMath.IntResult) -> bool:
	"""The bed's most pressing verb into `out` (clear, harvest, water when dry, cover before frost,
	sow the chosen crop, else water a growing crop); refuses NOTHING_TO_DO."""
	var spoil: int = crew.max_heap_spoil()
	var frost: bool = Weather.frost_tonight(sim.season(), sim.season_day())
	var dry: bool = sim.band_of(bed) <= SimScript.BAND_LOW
	var candidates: Array[int] = [JobsScript.KIND_CLEAR, JobsScript.KIND_HARVEST]
	if dry:
		candidates.append(JobsScript.KIND_WATER)
	if frost:
		candidates.append(JobsScript.KIND_COVER)
	candidates.append_array([JobsScript.KIND_SOW, JobsScript.KIND_WATER])
	for kind: int in candidates:
		if JobsScript.refusal_for(sim, kind, bed, spoil) == &"":
			return out.succeed(kind)
	return out.refuse("NOTHING_TO_DO")


func select_bed(bed: int) -> void:
	"""Open a bed's panel and ring it (NO_BED: close)."""
	selected_bed = bed
	view.select_bed(bed)
	if Catalog.is_bed(bed):
		bed_panel.show_bed(bed)
	else:
		bed_panel.show_nothing()


func toggle_pantry() -> void:
	"""Open or close the Pantry."""
	pantry_panel.toggle()


func compost_spoiled() -> void:
	"""Spoiled food to the compost store, at §5.7's 4 : 2."""
	sim.compost_milli += pantry.compost_spoiled()
	pantry_panel.refresh()


# --- input ------------------------------------------------------------------------------------------

func _bed_under_into(screen: Vector2, out: IntMath.IntResult) -> bool:
	"""The bed under a screen point, into `out`; refuses when the ray misses every bed."""
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	var t: float = PickScript.ray_ground(origin, direction, 0.0)
	if t < 0.0:
		return out.refuse(Catalog.REFUSE_NO_BED)
	var at: Vector3 = origin + direction * t
	return Catalog.bed_at_into(Vector2(at.x, at.z), out)


func on_ground_click(screen: Vector2) -> bool:
	"""A left click that hit no resident: on a bed, open it (keeping the selection); elsewhere close
	the bed panel and let the command layer clear the selection as usual."""
	if _bed_under_into(screen, _read):
		select_bed(_read.value)
		return true
	select_bed(NO_BED)
	return false


func on_ground_order(screen: Vector2) -> bool:
	"""A right click with residents selected: on a bed, its most pressing work; elsewhere not ours."""
	if not _bed_under_into(screen, _read):
		return false
	var bed: int = _read.value
	select_bed(bed)
	var at: Vector2 = Catalog.bed_centre_m(bed)
	if not pressing_kind_into(bed, _read):
		bed_panel.show_message("Nothing to do on bed %d now — choose a crop with Plant…" % (bed + 1))
		_command.mark(Vector3(at.x, 0.0, at.y), false)
		return true
	var said: String = order(_read.value, bed)
	_command.mark(Vector3(at.x, 0.0, at.y), not said.begins_with("Can't"))
	return true


func _unhandled_input(event: InputEvent) -> void:
	"""V: overlays; K (open_food): the Pantry; Esc: close the Pantry, then the bed panel."""
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if handle_key(event as InputEventKey) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_key(event: InputEventKey) -> bool:
	"""Apply one key press; true when it was the farm's."""
	if event.physical_keycode == KEY_V:
		var mode: int = view.cycle_overlay()
		_say("Map overlay: %s" % ViewScript.OVERLAY_NAMES[mode])
		return true
	if event.is_action_pressed(&"open_food") or event.physical_keycode == KEY_K:
		toggle_pantry()
		return true
	if event.is_action_pressed(&"ui_cancel") or event.physical_keycode == KEY_ESCAPE:
		if pantry_panel.visible:
			toggle_pantry()
			return true
		if Catalog.is_bed(selected_bed):
			select_bed(NO_BED)
			return true
	return false


func _say(text: String) -> void:
	"""What the crew reports (a job taken, done or given up), and the overlay switching: the demo party
	panel's notice. An order's own answer shows in the bed panel (order()); threats go to the HUD's
	alert card (_hourly)."""
	if _command != null and _command.panel() != null:
		_command.panel().show_notice(text)
