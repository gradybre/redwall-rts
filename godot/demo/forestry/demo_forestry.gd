extends Node3D
## The live demo's woods: forestry and wood gathering over the settlement's REAL ResourceNode store.
## Decision 0196 (live demo). Presentation only: nothing here writes into the running settlement.
##
## WHAT IS REAL. Every tree the village shows is a row in `scripts/core/resource_nodes.gd` (see
## forest_stand.gd): created full on its GDD §5.1 tile with the compiled `wood` item's id (resolved
## through resource_catalog_binding.gd), felled by the store's single `harvest_all` debit that dates
## its stump (REQ-SET-138), regrown by the store's `regrow` on the day its 48 days are up while its
## stump remains and nothing occupies it (§5.9), uprooted by `destroy`. The skills' arithmetic is
## §5.3's, the retention floor §5.9's, the storm's work factor §5.10's; every other number is a demo
## value named in forest_rules.gd.
##
## PLAYER VERBS (with the demo's selection):
##   right click a mature tree          the nearest selected fells it (axe; the beaver gnaws); the rest
##                                      of the selection wait to haul it
##   right click a felled trunk         every selected resident (up to 3) hauls it to the log stack
##   right click a deadfall pile        gather it (slow, a little wood, no felling)
##   right click a stump / cleared spot grub the stump out / plant a sapling (0.25 U compost, 4 WU)
##   right click the sawhorse           saw 2 U of logs into planks
##   left click a tree, stump or spot   select it: the Woods panel shows it, its zone and its verbs
##   left click inside a zone           select the zone: intensive, auto-fell, unmark
##   Woods panel                        the same verbs with nobody selected queue for the forestry crew
##                                      (the squirrel forester and the beaver); mark zones by dragging
##                                      on the ground; "Storm gust (demo)" brings a gust now
##   V                                  the one overlay cycle ends on "woods": zones and every tree's state
##
## TIME is the demo's one calendar and clock: the calendar's midnights regrow stumps and saplings and
## drop deadfall; a storm day (§5.10's heavy rain) blows a tree down and drops more; work runs on the
## demo clock, so pause and 2x / 4x apply. What happens goes to the one notice feed (source Woods). A
## blown-down tree is also an incident (decision 0331: "woods:windthrow:<tree>", on the tree) until its trunk is
## hauled clear (`windthrow_state`).
##
## THE WOOD goes into the demo's ONE stores (demo_services.gd `stores`, tunnel_stores.gd): the same
## wood the tunnels' bracing and lanterns spend; planks are sawn from it into the same stores.

const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const CrewScript := preload("res://demo/forestry/forest_crew.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const ViewScript := preload("res://demo/forestry/forest_view.gd")
const YardViewScript := preload("res://demo/forestry/forest_yard_view.gd")
const MarksScript := preload("res://demo/forestry/forest_marks.gd")
const PanelScript := preload("res://demo/forestry/forest_panel.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
const ZoneToolScript := preload("res://demo/forestry/forest_zone_tool.gd")
const TextScript := preload("res://demo/forestry/forest_text.gd")
const LiftScript := preload("res://demo/forestry/forest_lift.gd")
const RootFieldScript := preload("res://demo/forestry/forest_root_field.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const DemoPick := preload("res://demo/control/demo_pick.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const CatalogBinding := preload("res://scripts/core/resource_catalog_binding.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const ForestCard := preload("res://demo/forestry/forest_card.gd")

## The player did something in the woods: show the Woods panel (demo/ui/demo_detail_zone.gd).
signal panel_wanted

const PANEL_REFRESH_S: float = 0.25
## The panel's job verbs and the job each orders (see `action_card`).
const ACTION_KINDS: Dictionary = {&"fell": JobsScript.KIND_FELL, &"haul": JobsScript.KIND_HAUL,
	&"gather": JobsScript.KIND_GATHER, &"saw": JobsScript.KIND_SAW, &"plant": JobsScript.KIND_PLANT, &"grub": JobsScript.KIND_GRUB}
const NO_DEADFALL: String = "Can't gather deadfall: none is lying in the woods"
const NO_TREE: String = "Select a tree first"
const CANCEL_TIP: String = "Cancel ALL woods jobs (%d on the board), not just the selected tree's; loads in hand go into store"
## The demo's two zones at the start (demo values): the north stand to work, the old grove to keep.
const SEED_ZONES: Array[Array] = [
	[ZonesScript.KIND_FORESTRY, Vector2(-16.0, -30.0), Vector2(14.0, -18.0), "North stand"],
	[ZonesScript.KIND_CONSERVATION, Vector2(-30.0, -30.0), Vector2(-18.5, -8.0), "Old grove"],
]
## Deadfall lying when the demo opens (demo).
const OPENING_DEADFALL: int = 3
## A spot is occupied for regrowth by a tunnel mouth or spoil heap within this of it (m).
const OCCUPIED_M: float = 1.5
## Deadfall lies where it keeps this clear of every obstacle (m).
const DEADFALL_CLEAR_M: float = 0.8
const STORM_SEED: int = 19871
const OVERLAY_NAME: String = "woods: zones and trees"
## Chips fly this far in front of the one chopping (m).
const CHIP_AHEAD_M: float = 0.55

var stand: StandScript = StandScript.new()
var zones: ZonesScript = ZonesScript.new()
var deadfall: DeadfallScript = DeadfallScript.new()
var crew: CrewScript = CrewScript.new()
var tool: ZoneToolScript = ZoneToolScript.new()
var picker: PickScript = PickScript.new()
var view: ViewScript = null
var yard_view: YardViewScript = null
var marks: MarksScript = null
var panel: PanelScript = null
var text: TextScript = TextScript.new()
var lift: LiftScript = LiftScript.new()
var services: ServicesScript = null
var selected_tree: int = -1
## Why the woods are off, when they are ("" while they run).
var disabled_reason: String = ""

var _world: DemoWorldScript = null
var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _camera: Camera3D = null
var _day: int = 0
var _hour_index: int = -1
var _storm_day: int = 0
var _refresh_in: float = 0.0
var _storm_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _matured: PackedInt32Array = PackedInt32Array()
var _sources: PackedVector2Array = PackedVector2Array()
var _chip_trees: PackedInt32Array = PackedInt32Array()
var _chip_at: PackedVector3Array = PackedVector3Array()
var _ground: Vector2 = Vector2.ZERO
## The Woods panel's action cards (decision 0332): the one card filled per button, and a job's target.
var _card: CardScript = CardScript.new()
var _target: Vector2i = Vector2i.ZERO
var _allowed: Dictionary = {}


static func extra_obstacles(world: DemoWorldScript) -> Array[Vector3]:
	"""The circles the cast must also walk round for the woods' work: the woods' trees, stumps and
	rocks out to the forestry reach, the wood yard's pieces, and the staged trees' proud roots (decision
	0301: forest_root_field.gd) -- demo_village.gd merges them in before the cast is built."""
	var reach: float = Rules.REACH_M + Rules.WORK_MARGIN_M + 3.0
	var out: Array[Vector3] = world.woods_obstacles(reach)
	out.append_array(Yard.obstacles())
	out.append_array(RootFieldScript.root_obstacles(world.trees(), world.tree_node, reach))
	return out


func configure(world: DemoWorldScript, cast: DemoCastScript, command: DemoCommandScript, camera: Camera3D,
		shared: ServicesScript, wood: IntMath.IntResult) -> void:
	"""Bind the world's trees to real rows and wire the woods into this village: its cast, command
	layer, camera and shared services (null: a fresh set). `wood` carries the compiled `wood` item's id
	(`resolve_wood_id_into`); refused, no tree is bound and the woods say why."""
	name = "DemoForestry"
	services = shared if shared != null else ServicesScript.new()
	_world = world
	_cast = cast
	_command = command
	_camera = camera
	_storm_rng.seed = STORM_SEED
	_day = services.calendar.now().absolute_day
	if not wood.ok or not stand.bind_into(world.trees(), wood.value, _day, _read):
		disabled_reason = "the wood item did not bind (%s); no tree is bound" % (wood.error if not wood.ok else _read.error)
		push_warning("demo woods: " + disabled_reason)
	_seed_zones()
	crew.configure(cast, stand, zones, deadfall, services.stores, services.calendar, services.weather, services.props)
	crew.set_notice(services.notices.poster(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE))
	text.configure(stand, zones, deadfall, crew, services)
	_build_views()
	_hook_command()
	deadfall.spawn(OPENING_DEADFALL, _deadfall_sources(), _standable)


static func resolve_wood_id_into(out: IntMath.IntResult) -> bool:
	"""The compiled `wood` ItemDefinition id through the verified catalog boundary
	(resource_catalog_binding.gd, READY_07 §2), into `out`; refuses with the boundary's reason."""
	var items := ItemDefinitionsScript.new()
	if not items.load_from_file(ItemDefinitionsScript.DEFAULT_JSON_PATH, InventoryScript.new()).ok:
		return out.refuse("ITEM_DEFINITIONS")
	var opened: CatalogBinding.OpenResult = CatalogBinding.open(items)
	if not opened.ok:
		return out.refuse(String(opened.error))
	var bound: CatalogBinding.BindResult = (opened.boundary as CatalogBinding).resolve()
	if not bound.ok:
		return out.refuse(String(bound.error))
	return out.succeed(bound.binding.tree_resource_id)


func _seed_zones() -> void:
	"""The demo's opening zones (SEED_ZONES)."""
	for seed_zone: Array in SEED_ZONES:
		var a: bool = Rules.tile_of_into(seed_zone[1], _read)
		var from: int = _read.value
		var b: bool = Rules.tile_of_into(seed_zone[2], _read)
		if a and b:
			zones.add_into(seed_zone[0], _tile_xz(from), _tile_xz(_read.value), seed_zone[3], _read)


static func _tile_xz(tile: int) -> Vector2i:
	"""A tile index as its (x, z)."""
	return Vector2i(tile % ResourceNodes.MAP_TILES_X, tile / ResourceNodes.MAP_TILES_X)


func _build_views() -> void:
	"""The trees, the yard and deadfall, the marks, and the Woods panel."""
	view = ViewScript.new()
	add_child(view)
	view.configure(stand, _world.tree_node, _world.make_piece, services.props)
	view.set_occupied(_occupied)
	yard_view = YardViewScript.new()
	add_child(yard_view)
	yard_view.configure(services.stores, deadfall, services.props, _world.make_piece)
	marks = MarksScript.new()
	add_child(marks)
	marks.configure(zones, stand)
	panel = PanelScript.new()
	add_child(panel)
	panel.build()
	panel.action.connect(on_action)
	view.sync(_day, services.calendar.now().hour)
	lift.configure(stand, _cast)
	lift.use_fields(view.root_fields(), view.mound_scale)
	lift.enabled = view.staged


func _hook_command() -> void:
	"""The woods' clicks, orders, zone tool, "doing" words and skills in the command layer."""
	if _command == null:
		return
	_command.add_ground_handlers(on_ground_click, on_ground_order)
	_command.add_task_text(crew.task_text)
	_command.add_resume_rule(crew.resume_rule)
	_command.add_input_hook(handle_tool_input)
	_command.set_skill_text(skill_text, true)


# --- per frame ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the woods on this frame's demo time, keep the drawings in step, and refresh the panel a few
	times a second (real time: it works while paused)."""
	var usec: int = _cast.clock.frame_usec if _cast != null else 0
	step(usec)
	view.advance(float(usec) / 1000000.0)
	view.fx.set_speed(float(_cast.clock.speed) if _cast != null else 1.0)
	_feed_chips()
	lift.apply()
	marks.refresh()
	yard_view.refresh()
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		refresh_panel()
		panel.follow_hud()


func step(usec: int) -> void:
	"""Advance the woods by `usec` demo microseconds: the calendar's days and hours (read, never
	advanced -- the farm owns the calendar), then the crew's work."""
	_follow_calendar()
	crew.update(usec)
	view.sync(_day, services.calendar.now().hour)


func _follow_calendar() -> void:
	"""Each midnight the calendar crossed runs the day's sweep; each hour, the storm and routine jobs."""
	var hour_index: int = services.calendar.hour_index()
	if hour_index == _hour_index:
		return
	_hour_index = hour_index
	var day: int = services.calendar.now().absolute_day
	while _day < day:
		_day += 1
		daily(_day)
	if services.weather.event() == WeatherCore.EVENT_HEAVY_RAIN and _storm_day != _day:
		_storm_day = _day
		storm("A storm")
	crew.raise_routine_jobs()


func daily(day: int) -> void:
	"""A midnight: regrow every stump and sapling whose 48 days are up and whose spot is free (the
	store's `regrow`), and drop the day's deadfall."""
	_matured.clear()
	var held: int = stand.regrow_due(day, _occupied, _matured)
	if not _matured.is_empty():
		_post(NoticesScript.LEVEL_NOTE, text.matured_line(_matured))
	if held > 0:
		_post(NoticesScript.LEVEL_NOTE, "%d stump%s could not regrow: something stands on the spot" % [held, "" if held == 1 else "s"])
	deadfall.spawn(Rules.DEADFALL_PER_DAY, _deadfall_sources(), _standable)


func storm(what: String) -> int:
	"""A gale: one mature tree within reach, not being felled, blows down (uprooted -- its wood lies
	free for the clearing; no stump), and deadfall comes down. Returns the tree, or -1 when none could
	fall."""
	deadfall.spawn(Rules.DEADFALL_PER_STORM, _deadfall_sources(), _standable)
	var t: int = _storm_victim()
	var wind: Vector2 = Vector2.from_angle(_storm_rng.randf_range(-PI, PI))
	if t < 0 or not stand.blow_down_into(t, _day, wind, _read):
		_post(NoticesScript.LEVEL_NOTE, "%s shook the woods: deadfall is down" % what)
		return -1
	services.incidents.report("woods:windthrow:%d" % t, NoticesScript.SOURCE_WOODS, IncidentsScript.SEVERITY_WARNING,
		"%s blew down %s: %s of wood lie across the ground — clear it" % [what, text.where_tree(t),
		Rules.units_text(_read.value)], "A tree blew down — haul it clear", NoticesScript.TARGET_TREE, t,
		windthrow_state.bind(t))
	crew.raise_routine_jobs()
	return t


func windthrow_state(t: int) -> int:
	"""A blown-down tree's incident (decision 0331): RESOLVED once its trunk is hauled clear, ASSIGNED while a
	haul is on it."""
	if not stand.is_tree(t) or stand.trunk_milli[t] <= 0:
		return IncidentsScript.STATE_RESOLVED
	return IncidentsScript.STATE_ASSIGNED if crew.jobs.on_target(JobsScript.KIND_HAUL, t) > 0 \
		else IncidentsScript.STATE_NEEDS_DECISION


func _storm_victim() -> int:
	"""The seeded pick among mature trees within reach that nobody is felling (-1: none)."""
	var candidates := PackedInt32Array()
	for t: int in stand.count():
		if stand.state_of(t) == StandScript.STATE_MATURE and _in_reach(stand.at[t]) \
				and crew.jobs.on_target(JobsScript.KIND_FELL, t) == 0:
			candidates.append(t)
	if candidates.is_empty():
		return -1
	return candidates[_storm_rng.randi_range(0, candidates.size() - 1)]


static func _in_reach(at: Vector2) -> bool:
	"""Whether a point lies within the forestry reach of the square."""
	return absf(at.x) <= Rules.REACH_M and absf(at.y) <= Rules.REACH_M


func _deadfall_sources() -> PackedVector2Array:
	"""The mature trees within reach: deadfall falls under them."""
	_sources.clear()
	for t: int in stand.count():
		if stand.state_of(t) == StandScript.STATE_MATURE and _in_reach(stand.at[t]):
			_sources.append(stand.at[t])
	return _sources


func _standable(at: Vector2) -> bool:
	"""Whether deadfall may lie at `at`: within reach and clear of every obstacle."""
	if not _in_reach(at):
		return false
	return _cast == null or _cast.space().obstacle_clearance(at) >= DEADFALL_CLEAR_M


func _occupied(at: Vector2) -> bool:
	"""§5.9's "no building occupies the tile", as the demo can see it: a tunnel's mouth or spoil heap
	standing on the spot (the village's buildings stand clear of the woods)."""
	if _cast == null:
		return false
	var network: GraphScript = _cast.space().tunnels
	if _cast.space().on_mouth(at, OCCUPIED_M):
		return true
	for heap: int in network.heap_at.size():
		if network.heap_radius_m[heap] > 0.0 and network.heap_at[heap].distance_to(at) < network.heap_radius_m[heap] + OCCUPIED_M:
			return true
	return false


func _feed_chips() -> void:
	"""Chips fly at every tree being chopped, gnawed or grubbed right now."""
	_chip_trees.clear()
	_chip_at.clear()
	var jobs: JobsScript = crew.jobs
	for row: int in JobsScript.MAX_JOBS:
		if not jobs.is_live(row) or jobs.issued[row] == 0 or jobs.worker[row] == JobsScript.NOBODY:
			continue
		var code: int = jobs.current_step(row)
		if code == JobsScript.STEP_WORK + JobsScript.WORK_FELL or code == JobsScript.STEP_WORK + JobsScript.WORK_GRUB:
			var brain: BrainScript = crew.brain_of(jobs.worker[row])
			var ahead: Vector2 = brain.position + Vector2(sin(brain.yaw), cos(brain.yaw)) * CHIP_AHEAD_M
			_chip_trees.append(jobs.target[row])
			_chip_at.append(Vector3(ahead.x, brain.ground_y_m, ahead.y))
	view.fx.chip_at(_chip_trees, _chip_at)


func _post(level: int, line: String, summary: String = "") -> void:
	"""Post a line to the demo's one notice feed, from the woods."""
	services.notices.post(NoticesScript.SOURCE_WOODS, level, line, summary)


# --- input ----------------------------------------------------------------------------------------

func _ground_at(screen: Vector2) -> bool:
	"""The ground point under a screen point, into `_ground`. False when the ray misses it."""
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	var t: float = DemoPick.ray_ground(origin, direction, 0.0)
	if t < 0.0:
		return false
	var at: Vector3 = origin + direction * t
	_ground = Vector2(at.x, at.z)
	return true


func pick_at(screen: Vector2) -> int:
	"""What the pointer is on in the woods (PickScript.KIND_*; `picker.index`)."""
	return picker.pick(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), stand, deadfall)


func on_ground_click(screen: Vector2) -> bool:
	"""A left click on no resident: a tree, a trunk or a spot selects its tree; inside a zone selects
	the zone. Anything else is not the woods' (the tree and zone are let go)."""
	var kind: int = pick_at(screen)
	if kind == PickScript.KIND_TREE or kind == PickScript.KIND_TRUNK:
		select_tree(picker.index)
		return true
	select_tree(-1)
	if _ground_at(screen) and Rules.tile_of_into(_ground, _read) and zones.zone_at_tile_into(_read.value, _read):
		select_zone(_read.value)
		return true
	select_zone(-1)
	return false


func on_ground_order(screen: Vector2) -> bool:
	"""A right click with residents selected, on something of the woods': its verb (see the header).
	Anything else is not the woods'."""
	var kind: int = pick_at(screen)
	if kind == PickScript.KIND_NONE:
		return false
	var said: String = order_on(kind, picker.index, _command.selected())
	var at: Vector2 = _order_point(kind, picker.index)
	_command.mark(Vector3(at.x, 0.0, at.y), not said.begins_with("Can't"))
	_answer(said)
	return true


func order_on(kind: int, index: int, members: PackedInt32Array) -> String:
	"""The verb for what was clicked, given to `members` (none: queued for the crew). Says what happened."""
	match kind:
		PickScript.KIND_TRUNK:
			return crew.order_haul(index, members)
		PickScript.KIND_PILE:
			return crew.order(JobsScript.KIND_GATHER, index, deadfall.generation[index], members, JobsScript.ORIGIN_PLAYER)
		PickScript.KIND_SAW:
			return crew.order(JobsScript.KIND_SAW, JobsScript.NO_TARGET, 0, members, JobsScript.ORIGIN_PLAYER)
	select_tree(index)
	return tree_verb(index, members)


func tree_verb(t: int, members: PackedInt32Array) -> String:
	"""A tree's verb by its state: fell a mature one (haul, if it is already being felled), grub a
	stump, plant a cleared spot; a young tree is left to grow."""
	match stand.state_of(t):
		StandScript.STATE_MATURE:
			if crew.jobs.on_target(JobsScript.KIND_FELL, t) > 0:
				return crew.order_haul(t, members)
			return crew.order(JobsScript.KIND_FELL, t, 0, members, JobsScript.ORIGIN_PLAYER)
		StandScript.STATE_STUMP:
			return crew.order(JobsScript.KIND_GRUB, t, 0, members, JobsScript.ORIGIN_PLAYER)
		StandScript.STATE_CLEARED:
			return crew.order(JobsScript.KIND_PLANT, t, 0, members, JobsScript.ORIGIN_PLAYER)
	return "Can't fell: the young oak must grow first (%d days left)" % stand.days_left(t, _day)


func _order_point(kind: int, index: int) -> Vector2:
	"""Where an order's marker goes."""
	match kind:
		PickScript.KIND_PILE:
			return deadfall.at[index]
		PickScript.KIND_SAW:
			return Yard.at(Yard.SAWHORSE)
	return stand.at[index]


func _answer(said: String) -> void:
	"""An order's answer: beside the selection (the party panel's notice), and the Woods panel comes
	forward."""
	if _command != null and _command.panel() != null:
		_command.say(said)
	text.remember(said)
	_refresh_in = 0.0
	panel_wanted.emit()


func handle_tool_input(event: InputEvent) -> bool:
	"""The zone tool, while armed: a left press starts the rectangle on the ground, motion grows it,
	the release marks it; Esc or a right click puts the tool away. True when the event was taken."""
	if not tool.is_armed():
		return false
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and _ground_at(button.position):
			tool.press(_ground)
		elif not button.pressed and tool.phase == ZoneToolScript.PHASE_DRAGGING:
			_finish_zone()
		return true
	var motion := event as InputEventMouseMotion
	if motion != null and tool.phase == ZoneToolScript.PHASE_DRAGGING and _ground_at(motion.position) and tool.move(_ground):
		marks.show_preview(tool.rect_m(), tool.would_mark(zones))
		return true
	var key := event as InputEventKey
	var cancel: bool = key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE
	if cancel or (button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT):
		disarm_tool()
		return true
	return false


func _finish_zone() -> void:
	"""The drag is released: the zone is marked (and selected), or the refusal is said."""
	var kind: int = tool.zone_kind
	marks.hide_preview()
	panel.set_tool_armed(&"")
	if tool.release(zones, "", _read):
		select_zone(_read.value)
		_answer("%s marked: %s" % [zones.names[_read.value], zones.floor_text(stand, _read.value)])
		return
	_answer("Can't mark the %s zone: %s" % ["forestry" if kind == ZonesScript.KIND_FORESTRY else "conservation",
		_read.error.to_lower().replace("_", " ")])


func disarm_tool() -> void:
	"""Put the zone tool away."""
	tool.disarm()
	marks.hide_preview()
	panel.set_tool_armed(&"")


func select_tree(t: int) -> void:
	"""Select tree `t` for the Woods panel and ring it (-1: none)."""
	selected_tree = t if stand.is_tree(t) else -1
	marks.select_tree(selected_tree)
	if selected_tree >= 0:
		_refresh_in = 0.0
		panel_wanted.emit()


func select_zone(z: int) -> void:
	"""Select zone `z` for the Woods panel (-1: none)."""
	marks.selected_zone = z if zones.is_zone(z) else -1
	if marks.selected_zone >= 0:
		_refresh_in = 0.0
		panel_wanted.emit()


# --- the panel ------------------------------------------------------------------------------------

func on_action(action_name: StringName) -> void:
	"""A Woods panel button (forest_panel.gd ACTION_*)."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	match action_name:
		PanelScript.ACTION_FORESTRY_ZONE, PanelScript.ACTION_CONSERVATION_ZONE:
			_arm_zone_tool(action_name)
		PanelScript.ACTION_INTENSIVE:
			zones.set_intensive(marks.selected_zone, zones.intensive[maxi(marks.selected_zone, 0)] == 0)
		PanelScript.ACTION_AUTO:
			zones.set_auto(marks.selected_zone, zones.auto_fell[maxi(marks.selected_zone, 0)] == 0)
		PanelScript.ACTION_REMOVE_ZONE:
			if zones.remove(marks.selected_zone):
				select_zone(-1)
		PanelScript.ACTION_STORM:
			storm("A storm gust (demo)")
		PanelScript.ACTION_CANCEL:
			var cancelled: int = crew.cancel_all()
			_answer("Cancelled %d woods job%s" % [cancelled, "" if cancelled == 1 else "s"])
		_:
			_answer(_panel_verb(action_name, members))
	_refresh_in = 0.0


func _arm_zone_tool(action_name: StringName) -> void:
	"""Arm (or, pressed again, put away) the zone tool for the button's kind."""
	var kind: int = ZonesScript.KIND_FORESTRY if action_name == PanelScript.ACTION_FORESTRY_ZONE else ZonesScript.KIND_CONSERVATION
	var armed: bool = tool.arm(kind)
	panel.set_tool_armed(action_name if armed else &"")
	marks.hide_preview()
	if armed:
		_answer("Drag a rectangle on the ground to mark the %s zone (Esc: cancel)" % ("forestry" if kind == ZonesScript.KIND_FORESTRY else "conservation"))


func _panel_verb(action_name: StringName, members: PackedInt32Array) -> String:
	"""The selected tree's verb, deadfall gathering or sawing, given to the selection or queued -- on the target its
	card was shown for (`_target_into`)."""
	var refused: String = _target_into(action_name)
	if not refused.is_empty():
		return refused
	var kind: int = ACTION_KINDS[action_name]
	if kind == JobsScript.KIND_HAUL:
		return crew.order_haul(_target.x, members)
	return crew.order(kind, _target.x, _target.y, members, JobsScript.ORIGIN_PLAYER)


func _target_into(action_name: StringName) -> String:
	"""The target a panel verb acts on, into `_target` (index, generation): the nearest deadfall to the log stack, no
	target for sawing, else the selected tree. '' when there is one, else the refusal in words."""
	_target = Vector2i(JobsScript.NO_TARGET, 0)
	if action_name == PanelScript.ACTION_GATHER:
		if not deadfall.nearest_into(Yard.log_stack_at(), 2.0 * Rules.REACH_M, _read):
			return NO_DEADFALL
		_target = Vector2i(_read.value, deadfall.generation[_read.value])
	elif action_name != PanelScript.ACTION_SAW:
		if selected_tree < 0:
			return NO_TREE
		_target = Vector2i(selected_tree, 0)
	return ""


func action_card(action_name: StringName, members: PackedInt32Array) -> CardScript:
	"""A panel verb's action card (decision 0332): the crew's own preview on the target the order would take, and
	what the named resident would stop doing. Reused: read it before the next call."""
	var kind: int = ACTION_KINDS[action_name]
	var refused: String = _target_into(action_name)
	if not refused.is_empty():
		_card.reset(ForestCard.verb_text(kind, ""))
		_card.refuse(DeadfallScript.REFUSE_NO_PILE if kind == JobsScript.KIND_GATHER else "NO_TREE",
			refused.substr(refused.find(": ") + 2) if refused.contains(": ") else refused,
			ForestCard.fix_for(DeadfallScript.REFUSE_NO_PILE) if kind == JobsScript.KIND_GATHER else "")
		return _card
	crew.preview_into(_card, kind, _target.x, _target.y, members)
	if _card.worker >= 0 and _command != null:
		_card.interrupts = _command.interrupt_text(_card.worker)
	return _card


func _show_cards() -> Dictionary:
	"""Every verb's card on its button: its tooltip, pressable only when the card allows it. Returns which may be
	pressed ({action: bool}), for the tree section's own enabling (the same answer, so nothing flips)."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	for action_name: StringName in ACTION_KINDS:
		var card: CardScript = action_card(action_name, members)
		_allowed[action_name] = card.is_ok()
		panel.set_card(action_name, card.text(), card.is_ok())
	panel.set_card(PanelScript.ACTION_CANCEL, CANCEL_TIP % crew.jobs.live_count(), crew.jobs.live_count() > 0)
	return _allowed


func refresh_panel() -> void:
	"""Fill the Woods panel from the stand, the zones, the stores, the board and the feed."""
	panel.show_status(text.stores_line(), text.counts_line(), text.season_line(), text.queue_text(), text.log_text())
	panel.show_tree(text.tree_title(selected_tree, _day), text.tree_text(selected_tree), _show_cards())
	var z: int = marks.selected_zone
	panel.show_zone(text.zone_title(z), text.zone_text(z), text.zone_actions(z),
		zones.is_zone(z) and zones.intensive[z] == 1, zones.is_zone(z) and zones.auto_fell[z] == 1)


func skill_text(who: int, alone: bool) -> String:
	"""A resident's felling and sawing, for the party panel (the command layer's skill text)."""
	return crew.skills.line_of(who) if alone else crew.skills.short_of(who)


func set_overlay(on: bool) -> void:
	"""V's woods overlay (demo_farm.gd add_overlay)."""
	marks.set_overlay(on)


func day() -> int:
	"""The calendar day the woods last ran."""
	return _day
