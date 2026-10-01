extends Node3D
## The live demo's farm: individual pantry ingredients grown on the six crop beds by the settlement's
## own crop arithmetic, worked by the residents, stored and spoiling in the pantry, and helped by the
## moles' tunnels. Decision 0196. Presentation-only: it writes nothing into the running settlement.
##
## PLAYER VERBS (all by mouse, with the demo's selection):
##   left click a bed                 open its panel (the resident selection is kept)
##   right click a bed, residents     the nearest selected resident does the bed's most pressing work
##     selected                       (clear > harvest > drain a waterlogged bed > water a dry bed >
##                                    cover before frost > sow)
##   bed panel buttons                Plant… (the crop picker), Water, Drain (a ditch round a wet bed),
##                                    Harvest, Clear, Compost, Cover, Raise and Bank (tunnel earth),
##                                    Rest (fallow), Cancel jobs -- given to the selected residents, or
##                                    queued for the field crew
##   V                                the map layers (map_lenses.gd, decision 0292): off -> Growing:
##                                    soil moisture -> Growing: ripeness -> each added by the village
##                                    (Getting there: water range, Woods; add_overlay) -> off -- the same
##                                    one active layer the Map layer picker (demo/ui/demo_lens_picker.gd)
##                                    selects directly
##   K, or the HUD's Food command     the Pantry: Stocks (what is in store, where, incoming, next to
##                                    spoil) and Recipe ideas (not cookable yet)
##   left click the weir              the weir sluice's controls in the bed panel (farm_leat.gd, decision 0441;
##                                    `on_weir_click`, asked after the water's play):
##   (or a bed's Sluice…)             Close / Half / Open, each card previewing the beds it changes
##   G, or the Farm panel's            the seasonal planner (farm_planner.gd, decision 0451): every bed at a
##     "Planner (G)"                  glance, the season's calendar, soil plans and the after-action record
##   Esc                              close the Pantry, then the bed panel
## The routine crew (the fieldworker and the gatherer) take queued jobs and the farm's own harvest
## and clearing jobs whenever they are wandering.
##
## TIME. Everything runs on the demo clock the cast advances first each frame (demo_clock.gd):
## `frame_usec` drives the demo's ONE calendar (demo_calendar.gd, shared through demo_services.gd --
## the farm's model is what advances it) and the crew's work, so the HUD's pause freezes the farm and
## 2x / 4x speed it up. After each advance the demo's ONE weather (demo/weather/demo_weather.gd) is
## re-read from the farm's real §5.10 row -- the same rain that wets the beds slows the walkers -- and
## a change of weather is posted to the notice feed.
##
## THE RECORD (farm_record.gd, decision 0451): at each farm hour the hour's lost crops are noted and every day that has
## ended is closed from the ledgers -- the pantry's stored, withdrawn and spoiled food, the kitchen's portions and meals
## (`bind_kitchen`) -- and posted to the notice feed as the day's record (and at a season's last day, the season's).
##
## WHAT IT SAYS goes to the demo's ONE notice feed (demo_notices.gd): the farm's warnings (farm_alerts.gd,
## WARNING or NOTE) and the crew's reports, which the HUD's news strip shows; the bed panel shows only
## its own bed (its Needs line, farm_text.gd). Only the answer to a click or key (an order, the
## overlay) is shown where the player looks -- the bed panel's message line, or the party panel's
## notice. No HUD alert card is raised.
##
## Wiring (demo_village.gd `_build_farm`): the world, the cast, the command layer (for the selection,
## order marks, click hooks and the tunnel tool), the HUD shell, the storage providers (root cellars,
## demo/farm/farm_cellars.gd) as Callables -- see farm_storage.gd for the provider API -- and the shared
## services (demo_services.gd): the calendar, the weather, the one water adapter (village_water.gd,
## whose `edge_query()` is the farm's water query, over the real stream and pond) and the notice feed.

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
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const LensesScript := preload("res://demo/map_lenses.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const CarryViewScript := preload("res://demo/farm/farm_carry_view.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const TunnelControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const LeatScript := preload("res://demo/farm/farm_leat.gd")
const WeirView := preload("res://demo/water/weir_gate_view.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const PlannerScript := preload("res://demo/farm/farm_planner.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const RecordText := preload("res://demo/farm/farm_record_text.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")

## A bed was opened: the right column should show the farm's panel (demo/ui/demo_detail_zone.gd).
signal panel_wanted

const STORE_POI: StringName = &"store_front"
const STORE_ID: StringName = &"store"
const WELL_ID: StringName = &"well"
const PANEL_REFRESH_S: float = 0.25
const NO_BED: int = -1
## "Next weather" skips the calendar ahead at most this many hours looking for a change (demo value).
const MAX_WEATHER_SKIP_HOURS: int = 48

var sim: SimScript = SimScript.new()
var tunnels: TunnelsScript = TunnelsScript.new()
var crew: CrewScript = CrewScript.new()
var alerts: AlertsScript = AlertsScript.new()
## The weir's sluice and the garden leat it feeds (decision 0441).
var leat: LeatScript = LeatScript.new()
## farm_alerts.gd COND_DRY, COND_WET, COND_WORN, COND_BLIGHT -> the job that answers it.
const REMEDY_KINDS: PackedInt32Array = [JobsScript.KIND_WATER, JobsScript.KIND_DRAIN, JobsScript.KIND_COMPOST,
	JobsScript.KIND_CLEAR]
var _remedy_read: IntMath.IntResult = IntMath.IntResult.new()
var recipes: RecipesScript = RecipesScript.new()
var hud: HudScript = HudScript.new()
var storage: StorageScript = null
var pantry: PantryScript = null
var view: ViewScript = null
var bed_panel: BedPanelScript = null
var pantry_panel: PantryPanelScript = null
var selected_bed: int = NO_BED
var services: ServicesScript = null
## The harvested goods' models and icons, and who is drawn carrying which (presentation).
var goods: GoodsScript = null
var carry_view: CarryViewScript = CarryViewScript.new()
## The seasonal planner and the after-action record it shows (decision 0451).
var planner: PlannerScript = null
var record: RecordScript = RecordScript.new()

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _camera: Camera3D = null
var _refresh_in: float = 0.0
var _events: PackedInt32Array = PackedInt32Array()
var _spoiled: PackedInt32Array = PackedInt32Array()
var _lines: PackedStringArray = PackedStringArray()
var _levels: PackedByteArray = PackedByteArray()
## The village's map layers: the farm's two first, then the village's (add_overlay). V steps them.
var lenses: LensesScript = LensesScript.new()
var _shown_hour: int = 0
var _water: PackedByteArray = PackedByteArray([0, 0])
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _rooms: RoomsScript = null
## The fit-out's revision the pantry's stores were last read at.
var _seen_fit: int = -1
## `jump(bed) -> bool`: select a bed and ease the camera over it (the village news' "Go to"; none: select only).
var _bed_jump: Callable = Callable()


func configure(manifest: Dictionary, world: DemoWorldScript, cast: DemoCastScript, command: DemoCommandScript,
		camera: Camera3D, shell: UiShell, providers: Array[Callable], shared: ServicesScript = null) -> void:
	"""Build the farm over this village (see the header on the wiring); `shared` is the demo's services
	(none: a fresh set of its own)."""
	name = "DemoFarm"
	_cast = cast
	_command = command
	_camera = camera
	_bind_services(shared if shared != null else ServicesScript.new())
	storage = StorageScript.new(store_position(cast))
	for provider: Callable in providers:
		storage.add_provider(provider)
	pantry = PantryScript.new(storage)
	crew.configure(cast, sim, pantry, tunnels, well_position(), services.notices.poster(
		NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE))
	alerts.bind_incidents(services.incidents, remedy_on)
	leat.configure(sim, services.incidents, services.notices)
	crew.set_incidents(services.incidents)
	recipes.load_index()
	goods = GoodsScript.new(services.props)
	_build_view(manifest, world, command)
	_add_farm_lenses()
	_build_panels()
	_build_planner()
	hud.bind(shell)
	hud.unlock_food_command(toggle_pantry)
	command.set_ground_handlers(on_ground_click, on_ground_order)
	command.set_task_text(crew.task_text)
	command.add_resume_rule(crew.resume_rule)
	bed_panel.set_preview(command.selected, command.interrupt_text)


func _bind_services(shared: ServicesScript) -> void:
	"""Advance the shared calendar, drive the shared weather from this farm's real row, and ask the
	shared water adapter where the water's edge is."""
	services = shared
	var adopted: bool = sim.share_calendar(services.calendar).ok
	assert(adopted, "the farm must adopt the demo calendar before either has run")
	services.weather.bind(services.calendar, sim.crop_weather().weather())
	tunnels.water_edge = services.water.edge_query()


func _build_view(manifest: Dictionary, world: DemoWorldScript, command: DemoCommandScript) -> void:
	"""The beds, over the world's hidden crop pieces; heaps shrink with spoil taken."""
	view = ViewScript.new()
	add_child(view)
	view.build(manifest, sim)
	view.stock.configure(pantry, goods)
	if _cast != null:
		carry_view.configure(_cast, crew.jobs, goods)
	var village: Node = world.get_node_or_null(^"Village") if world != null else null
	if village != null:
		ViewScript.hide_world_beds(village)
	var tool: TunnelControlScript = command.tunnels() if command != null else null
	if tool != null:
		view.follow_tunnels(tunnels, _cast.space().tunnels, tool.overlay)
		view.stock.register(tool.view.prewarm)


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
	bed_panel.pantry_requested.connect(open_pantry)
	bed_panel.sluice_requested.connect(show_weir)
	bed_panel.sluice_chosen.connect(set_sluice)
	bed_panel.set_leat(leat)
	pantry_panel = PantryPanelScript.new()
	pantry_panel.configure(sim, pantry, recipes)
	pantry_panel.set_goods(goods)
	bed_panel.set_goods(goods)
	add_child(pantry_panel)
	pantry_panel.compost_requested.connect(compost_spoiled)
	pantry_panel.close_requested.connect(toggle_pantry)
	pantry_panel.bed_requested.connect(open_bed_from_pantry)


func _build_planner() -> void:
	"""The after-action record from this hour on, and the seasonal planner over the farm, its crew and the record --
	opened by G and the bed panel's "Planner (G)"; the bed panel's Compare view marks the map (decision 0451)."""
	record.bind(pantry, sim.crop_weather().weather())
	record.start(services.calendar.hour_index())
	planner = PlannerScript.new()
	planner.configure(sim, crew, record)
	add_child(planner)
	planner.close_requested.connect(toggle_planner)
	planner.bed_wanted.connect(open_bed_from_planner)
	bed_panel.planner_requested.connect(toggle_planner)
	bed_panel.compare_changed.connect(func() -> void: view.set_compare(bed_panel.compare_marks()))
	bed_panel.compare_bed_picked.connect(select_bed)


func bind_kitchen(kitchen: KitchenScript) -> void:
	"""The kitchen whose portions and meals the record counts and whose plans the calendar shows."""
	record.set_kitchen(kitchen)
	planner.set_kitchen(kitchen)


func set_bed_jump(jump: Callable) -> void:
	"""`jump(bed) -> bool`: how the planner's rows show a bed -- selected and the camera eased over it."""
	_bed_jump = jump


func toggle_planner() -> void:
	"""Open or close the seasonal planner."""
	planner.toggle()


func open_bed_from_planner(bed: int) -> void:
	"""A planner row: close the planner, open the bed and centre the camera on it (select only, without a jump)."""
	if planner.visible:
		planner.close()
	if not (_bed_jump.is_valid() and bool(_bed_jump.call(bed))):
		select_bed(bed)


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


func follow_rooms(rooms: RoomsScript) -> void:
	"""Know the root cellars' rooms, for how full each is (demo_village.gd wires it; `cellar_fill`)."""
	_rooms = rooms


func cellar_fill(r: int) -> int:
	"""How full root cellar row `r` is, per mille of its capacity (0 when it is no store): its racks fill with it
	(demo/burrow/fixture_view.gd, decision 0210)."""
	var location := _cellar_location(r)
	return view.stock.fill_permille(location) if location > 0 else 0


func cellar_stored_u(r: int) -> int:
	"""How much food root cellar row `r` holds, in whole units rounded up (0 when it is no store): its racks cannot be
	taken out below it (room_fixtures.gd `take_out`)."""
	var location := _cellar_location(r)
	return (pantry.used_milli_of(location) + StorageScript.MILLI_PER_U - 1) / StorageScript.MILLI_PER_U if location > 0 else 0


func _cellar_location(r: int) -> int:
	"""The pantry location of root cellar row `r` (0: none -- the covered store is location 0)."""
	if _rooms == null or not _rooms.is_room(r):
		return 0
	var id := StringName(FarmCellars.ID_FORMAT % [r, _rooms.generation[r]])
	return _read.value if storage.index_of_id_into(id, _read) else 0


# --- per frame ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the farm on this frame's demo time; keep the panels current -- at
	once when the calendar's hour turns, so the panel's date never trails the HUD's."""
	step(_cast.clock.frame_usec if _cast != null else 0)
	leat.follow_flood(flood_running())
	if _cast != null:
		carry_view.refresh()
		_follow_fit_out()
	_refresh_in -= delta
	var hour: int = services.calendar.hour_index()
	if _refresh_in <= 0.0 or hour != _shown_hour:
		_shown_hour = hour
		_refresh_in = PANEL_REFRESH_S
		bed_panel.refresh()
		pantry_panel.refresh()
		view.stock.refresh()


func _follow_fit_out() -> void:
	"""A cellar's racks put in or taken out change its store at once, not at the next hour (decision 0210)."""
	var fit: RefCounted = _cast.space().tunnels.fit
	if fit.revision != _seen_fit:
		_seen_fit = fit.revision
		pantry.refresh_locations()


func step(usec: int) -> void:
	"""Advance the farm by `usec` demo microseconds: the calendar and everything on it, then the crew's
	work. (The top bar reads the pantry's total itself: demo/ui/demo_hud_model.gd.)"""
	advance_calendar(usec)
	crew.update(usec)


func advance_calendar(usec: int) -> int:
	"""The calendar part of a step: every hour crossed (pantry ageing, the hourly jobs and alerts), then
	the weather re-read and a change of it posted. Returns the hours crossed."""
	var hours: int = sim.advance_usec(usec)
	var first: int = sim.calendar.hour_index() - hours + 1
	for hour: int in hours:
		pantry.age_hour(PantryScript.season_of_hour(first + hour))
	if hours > 0:
		_hourly()
	if services.weather.sync():
		var weather := services.weather
		services.notices.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE,
			"Weather: %s" % weather.readout(), "Weather: %s" % weather.alert_line())
	return hours


func skip_to_next_weather() -> int:
	"""The panel's "Next weather (demo)": run the ONE calendar -- farm, weather and date together --
	ahead an hour at a time until the weather changes, at most MAX_WEATHER_SKIP_HOURS. The crew's work
	is not skipped. Returns the hours run."""
	var before: int = services.weather.revision
	for hour: int in MAX_WEATHER_SKIP_HOURS:
		advance_calendar(CalendarScript.HOUR_USEC)
		if services.weather.revision != before:
			return hour + 1
	return MAX_WEATHER_SKIP_HOURS


func _hourly() -> void:
	"""Once per farm hour: storage providers, tunnel water, the routine jobs, and the alerts."""
	pantry.refresh_locations()
	var network: GraphScript = _cast.space().tunnels
	for bed: int in Catalog.BED_COUNT:
		tunnels.water_of_into(network, bed, _water)
		sim.set_tunnel_water(bed, _water[0] == 1, _water[1] == 1)
	crew.raise_routine_jobs()
	_events.clear()
	sim.take_events_into(_events)
	_spoiled.clear()
	pantry.take_spoiled_items_into(_spoiled)
	_lines.clear()
	_levels.clear()
	alerts.collect_into(sim, _events, _spoiled, _lines, _levels)
	for k: int in _lines.size():
		var bed: int = alerts.targets[k]
		services.notices.post(NoticesScript.SOURCE_FARM, _levels[k], _lines[k], "",
			NoticesScript.TARGET_BED if bed >= 0 else NoticesScript.TARGET_NONE, bed, alerts.serials[k])
	_keep_record()


func _keep_record() -> void:
	"""The hour's lost crops into the record, then each day that has ended closed and posted (THE RECORD)."""
	record.note_events(_events)
	record.note_weather(services.calendar.hour_index())
	var closed: int = record.close_through(services.calendar.hour_index())
	for n: int in closed:
		var k: int = record.day_count() - closed + n
		services.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, RecordText.day_line(record, k),
			RecordText.day_summary(record, k))
		var day: int = record.value(k, RecordScript.F_DAY)
		if day % RecordScript.DAYS_PER_SEASON == RecordScript.DAYS_PER_SEASON - 1:
			services.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Season's record, "
				+ RecordText.season_line(record, day / RecordScript.DAYS_PER_SEASON))


func remedy_on(bed: int, cond: int) -> bool:
	"""Whether a job answering a bed's condition (farm_alerts.gd COND_*) is on it: Water a dry bed, Drain a
	waterlogged one, Compost a worn-out one, Clear a blighted one (decision 0331: the incident's ASSIGNED)."""
	var kind: int = REMEDY_KINDS[cond] if cond >= 0 and cond < REMEDY_KINDS.size() else -1
	return kind >= 0 and crew.jobs.job_on_bed_into(kind, bed, _remedy_read)


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
	"""The bed's most pressing verb into `out` (clear, harvest, drain when waterlogged, water when dry,
	cover when a frost is due on a bed not raised above it -- farm_weather.gd `frost_due` -- sow the
	chosen crop, else water a growing crop); refuses NOTHING_TO_DO. The bed panel's Needs line names
	the same (farm_text.gd)."""
	var earth: int = crew.most_earth()
	var hour: int = sim.calendar.calendar_at(sim.calendar.tick).hour
	var frost: bool = Weather.frost_due(sim.season(), sim.season_day(), hour) and not sim.is_raised(bed)
	var dry: bool = sim.band_of(bed) <= SimScript.BAND_LOW
	var candidates: Array[int] = [JobsScript.KIND_CLEAR, JobsScript.KIND_HARVEST]
	if sim.band_of(bed) == SimScript.BAND_WATERLOGGED:
		candidates.append(JobsScript.KIND_DRAIN)
	if dry:
		candidates.append(JobsScript.KIND_WATER)
	if frost:
		candidates.append(JobsScript.KIND_COVER)
	candidates.append_array([JobsScript.KIND_SOW, JobsScript.KIND_WATER])
	for kind: int in candidates:
		if JobsScript.refusal_for(sim, kind, bed, earth) == &"":
			return out.succeed(kind)
	return out.refuse("NOTHING_TO_DO")


func flood_running() -> bool:
	"""Whether the tunnels' threat is a flood under way now (demo/events/demo_events.gd; none without tunnels)."""
	var tool: TunnelControlScript = _command.tunnels() if _command != null else null
	if tool == null or tool.ext == null or tool.ext.works == null:
		return false
	var events: EventsScript = tool.ext.works.events
	return events != null and events.active and events.kind == EventsScript.KIND_FLOOD


func show_weir() -> void:
	"""The weir's sluice in the bed panel (decision 0441): no bed selected."""
	selected_bed = NO_BED
	view.select_bed(NO_BED)
	bed_panel.show_weir()
	panel_wanted.emit()


func set_sluice(setting: int) -> String:
	"""THE SLUICE ORDER (farm_leat.gd `set_sluice`): its answer shows on the panel's message line."""
	var said: String = leat.set_sluice(setting)
	bed_panel.show_message(said)
	bed_panel.refresh()
	return said


func select_bed(bed: int) -> void:
	"""Open a bed's panel and ring it (NO_BED: close)."""
	selected_bed = bed
	view.select_bed(bed)
	if Catalog.is_bed(bed):
		bed_panel.show_bed(bed)
		panel_wanted.emit()
	else:
		bed_panel.show_nothing()


func toggle_pantry() -> void:
	"""Open or close the Pantry."""
	pantry_panel.toggle()


func open_pantry() -> void:
	"""Open the Pantry (the bed panel's "Make room…"); already open, it stays open."""
	if not pantry_panel.visible:
		toggle_pantry()


func open_bed_from_pantry(bed: int) -> void:
	"""The empty Pantry's suggestion: close the Pantry and open the bed it names."""
	if pantry_panel.visible:
		toggle_pantry()
	select_bed(bed)


func compost_spoiled() -> void:
	"""Spoiled food to the compost store, at §5.7's 4 : 2."""
	sim.compost_milli += pantry.compost_spoiled()
	pantry_panel.refresh()


# --- input ------------------------------------------------------------------------------------------

func bed_at_into(screen: Vector2, out: IntMath.IntResult) -> bool:
	"""The bed under a screen point, into `out` (the work board's Shift+right-click queue, decision 0411); refuses when
	the ray misses every bed."""
	return _bed_under_into(screen, out)


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


func on_weir_click(screen: Vector2) -> bool:
	"""A left click on the weir (decision 0441): its sluice in the bed panel. The village asks it AFTER the water's
	play, so a bridge at the weir's landing is that play's click, not the sluice's."""
	if _camera == null or not WeirView.ray_hits_weir(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen)):
		return false
	show_weir()
	return true


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
	"""V: overlays; K (open_food): the Pantry; G: the planner; Esc: close the planner, the Pantry, then the bed panel."""
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if handle_key(event as InputEventKey) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_key(event: InputEventKey) -> bool:
	"""Apply one key press; true when it was the farm's."""
	if event.physical_keycode == KEY_V:
		_say("Map layer: %s" % cycle_overlays())
		return true
	if event.is_action_pressed(&"open_food") or event.physical_keycode == KEY_K:
		toggle_pantry()
		return true
	if GateScript.key_of(event) == PlannerScript.KEY and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
		toggle_planner()
		return true
	if event.is_action_pressed(&"ui_cancel") or event.physical_keycode == KEY_ESCAPE:
		if planner.visible:
			toggle_planner()
			return true
		if pantry_panel.visible:
			toggle_pantry()
			return true
		if Catalog.is_bed(selected_bed) or bed_panel.showing_weir:
			select_bed(NO_BED)
			return true
	return false


func _add_farm_lenses() -> void:
	"""The farm's three layers, first on V's cycle: soil moisture, ripeness and the garden leat's water service
	(decision 0441), each with its legend in the beds' own overlay colours (farm_look.gd)."""
	var moisture: int = lenses.add("Growing", "Soil moisture", "Which beds are too dry or too wet?",
		_farm_overlay.bind(ViewScript.OVERLAY_MOISTURE))
	lenses.set_legend(moisture, PackedColorArray(Look.BAND_OVERLAY), PackedStringArray(SimScript.BAND_NAMES))
	var ripeness: int = lenses.add("Growing", "Ripeness", "Which beds are ready to harvest?",
		_farm_overlay.bind(ViewScript.OVERLAY_RIPENESS))
	lenses.set_legend(ripeness, PackedColorArray([Look.UNRIPE_OVERLAY, Look.RIPE_OVERLAY, Look.LATE_OVERLAY,
		Look.NO_OVERLAY]), PackedStringArray(["growing", "ripe", "past its best or lost", "empty"]))
	var service: int = lenses.add("Growing", "Water service", "Which beds does the weir's garden leat water?",
		_farm_overlay.bind(ViewScript.OVERLAY_WATER))
	lenses.set_legend(service, PackedColorArray(Look.SERVICE_OVERLAY), PackedStringArray(["not served",
		"dry (leat empty)", "normal", "wet"]))


func _farm_overlay(on: bool, mode: int) -> void:
	"""Show the beds' overlay `mode`, or clear it. The two farm layers share the beds' one overlay; that is
	safe because `lenses.select` switches every other layer off BEFORE it switches the chosen one on."""
	view.set_overlay(mode if on else ViewScript.OVERLAY_OFF)


func add_overlay(group: String, label: String, question: String, show: Callable) -> int:
	"""Put another map layer on V's cycle, after the farm's own: `show(on: bool)` switches it (the
	village's water range, the woods). One active layer for V and the picker alike. Returns its row in
	`lenses`."""
	return lenses.add(group, label, question, show)


func cycle_overlays() -> String:
	"""V: off -> each layer on V's cycle -> off (map_lenses.gd `cycle`), after adopting an outside switch
	(U). Returns the title of what now shows."""
	lenses.sync()
	return lenses.title_of(lenses.cycle())


func _say(text: String) -> void:
	"""The answer to a key the player pressed (the overlay switching): the demo party panel's notice.
	An order's own answer shows in the bed panel (order()); the crew's reports and the farm's warnings
	go to the notice feed (configure, _hourly)."""
	if _command != null and _command.panel() != null:
		_command.say(text)
