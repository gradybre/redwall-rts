extends Node3D
## THE ORCHARD IN THE VILLAGE (decisions 0671-0677; feature #20 "orchards and berry bushes" and review group Y's
## ECO-008, 009, 010 and 015). demo_village.gd builds it after the farm (the pantry, the compost) and wires its hooks:
## its two basket stands in the pantry's storage (`stand_provider`), its trunks and stands in the cast's obstacles
## (`land_obstacles`), its trees in the seasons (season_view.gd `add_trees`), its jobs on the work board
## (demo_work.gd `add_orchard`) and its grove in the woods' felling rule (forest_crew.gd `set_protected`).
##
## THE PLAYER'S WAY IN: left-click an orchard tree, a site's pegs, a hedge bush, the baskets, the nursery, the grove's
## stone or the apiary's skep (decision 1601) -- it is selected and the Orchard panel opens in the right column (it has no tab: decision 0671). Right-click
## one with residents selected: the nearest does its most pressing work (a tree: harvest, else tend; an empty site:
## plant its ready sapling or a free one; a bush: pick; the baskets: send them on; the nursery: propagate the first
## waiting plan; the grove: observe). With nobody selected the panel's verbs queue the job for the board's Field crew.
##
## THE DAY: at each midnight the model closes the day just ended (orchard_model.gd `close_day`) at the temperature the
## one weather gave it; the jobs are worked on the cast's clock and the routine's raised each game hour.

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const ViewScript := preload("res://demo/orchard/orchard_view.gd")
const PanelScript := preload("res://demo/orchard/orchard_panel.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const Cards := preload("res://demo/orchard/orchard_cards.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")
const ApiaryViewScript := preload("res://demo/hives/apiary_view.gd")
const FarmSimScript := preload("res://demo/farm/farm_sim.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

const SEL_NONE: int = 0
const SEL_SITE: int = 1
const SEL_BUSH: int = 2
const SEL_STAND: int = 3
const SEL_NURSERY: int = 4
const SEL_GROVE: int = 5
## The apiary's skep (decision 1601, demo/hives/): its panel section and the keeper's verbs.
const SEL_APIARY: int = 6
## How near a click must land to pick each kind of thing (m): a tree's trunk, a bush, the baskets, the nursery, the
## grove's stone.
const PICK_TREE_M: float = 2.6
const PICK_SMALL_M: float = 1.4
## The panel is refreshed this often while it shows (real time: it reads while the village is paused too).
const PANEL_REFRESH_S: float = 0.25
const GROVE_STONE_KEY: StringName = &"mossy_boulder"
const GROVE_STONE_SIZE: float = 0.4

var model: ModelScript = ModelScript.new()
var jobs: JobsScript = JobsScript.new()
var view: ViewScript = null
var apiary_view: ApiaryViewScript = null
var panel: PanelScript = null
var cards: Cards = Cards.new()
var selected_kind: int = SEL_NONE
var selected_id: int = -1

var _services: ServicesScript = null
var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _camera: Camera3D = null
var _stand: StandScript = null
var _show_panel: Callable = Callable()
var _day_seen: int = 0
var _day_temperature: int = 0
var _panel_s: float = 0.0
var _takes: TakesScript = null
var _pantry: PantryScript = null


static func stand_provider() -> Callable:
	"""The two basket stands as pantry storage locations (farm_storage.gd's provider API): gathering places, never a
	harvest's destination (KEY_STAGING), at the covered store's factor."""
	return func() -> Array:
		var out: Array = []
		for group: int in Rules.GROUP_COUNT:
			out.append({StorageScript.KEY_ID: Rules.STAND_IDS[group], StorageScript.KEY_POSITION: Rules.STAND_AT[group],
				StorageScript.KEY_CAPACITY_U: Rules.STAND_CAPACITY_U, StorageScript.KEY_PERMILLE: Rules.STAND_PERMILLE,
				StorageScript.KEY_LABEL: Rules.STAND_LABELS[group], StorageScript.KEY_STAGING: true})
		return out


static func land_obstacles() -> Array[Vector3]:
	"""What the cast walks round (x, radius, z): each site's trunk (or its stake), the hedge's two bushes, the stands,
	the nursery and the grove's stone."""
	var out: Array[Vector3] = []
	for site: int in Rules.SITE_COUNT:
		var at: Vector2 = Rules.site_centre_m(site)
		out.append(Vector3(at.x, TRUNK_RADIUS_M, at.y))
	for bush: int in 2:
		out.append(Vector3(Rules.BUSH_AT[bush].x, BUSH_RADIUS_M, Rules.BUSH_AT[bush].y))
	for at: Vector2 in Rules.STAND_AT:
		out.append(Vector3(at.x, PLACE_RADIUS_M, at.y))
	out.append(Vector3(Rules.NURSERY_AT.x, PLACE_RADIUS_M, Rules.NURSERY_AT.y))
	out.append(Vector3(Rules.GROVE_AT.x, BUSH_RADIUS_M, Rules.GROVE_AT.y))
	for apiary: int in HiveRules.APIARY_COUNT:
		var skep: Vector2 = HiveRules.centre_m(apiary)
		out.append(Vector3(skep.x, HiveRules.SKEP_RADIUS_M, skep.y))
	return out


## The trunk circle (a mature fruit tree's: the woods oak's 1.1 m at the drawn half size), a bush's and a place's.
const TRUNK_RADIUS_M: float = 0.55
const BUSH_RADIUS_M: float = 0.45
const PLACE_RADIUS_M: float = 0.7


func configure(world: DemoWorldScript, cast: DemoCastScript, command: DemoCommandScript, camera: Camera3D,
		services: ServicesScript, pantry: PantryScript) -> void:
	"""Wire the orchard into this village (see the header); `world` makes its trees, `pantry` keeps its fruit."""
	name = "DemoOrchard"
	_services = services
	_cast = cast
	_command = command
	_camera = camera
	model.today_hint = services.calendar.now().absolute_day
	_day_seen = model.today_hint
	jobs.configure(model, cast, pantry, services.stores, services.calendar, services.weather)
	jobs.say = _say
	jobs.grove_trees = grove_trees_standing
	view = ViewScript.new()
	add_child(view)
	view.configure(model, jobs, world.make_piece if world != null else Callable(), services.props, cast, pantry,
		services.calendar, world.is_staged if world != null else Callable())
	_place_grove_stone(world)
	apiary_view = ApiaryViewScript.new()
	add_child(apiary_view)
	apiary_view.configure(model.apiary, world.make_piece if world != null else Callable(), services.calendar,
		cast.clock if cast != null else null)
	_pantry = pantry
	panel = PanelScript.new()
	panel.build()
	add_child(panel)
	panel.action.connect(on_action)
	cards.configure(model, jobs, command)
	if command != null:
		command.add_ground_handlers(on_ground_click, on_ground_order)


func _place_grove_stone(world: DemoWorldScript) -> void:
	"""The grove's stone: its rest and observation spot (ECO-015), and what a click selects it by."""
	if world == null:
		return
	var stone: Node3D = world.make_piece(GROVE_STONE_KEY, Rules.GROVE_AT, 0.4, GROVE_STONE_SIZE)
	if stone != null:
		add_child(stone)


func set_compost(left: Callable, take: Callable) -> void:
	"""The farm's compost store (demo_village.gd `compost_left` / `take_compost`)."""
	jobs.set_compost(left, take)
	cards.compost_left = left


func bind_farm(sim: FarmSimScript, takes: TakesScript) -> void:
	"""The apiary's joins (decision 1601): the field beds' pollination (farm_sim.gd `pollinate`, REQ-SET-082 for the beans
	within 12 m) and the pantry's free honey through the kitchen's reservations (`takes`: a winter feeding and a
	recolonisation never take food the kitchen has set aside)."""
	_takes = takes
	if sim != null:
		sim.pollinate = model.apiary.bed_factor
	jobs.set_honey(free_honey, take_honey)


func free_honey() -> int:
	"""Honey in the pantry nobody has set aside, milli-U."""
	return _takes.free_milli_of_crop(_pantry, Catalog.CAT_HONEY) if _takes != null and _pantry != null else 0


func take_honey(milli: int) -> int:
	"""Withdraw up to `milli` of free honey, the lot that spoils first first; how much was taken."""
	if _takes == null or _pantry == null:
		return 0
	return _takes.withdraw_free(_pantry, Catalog.CAT_HONEY, milli, _services.calendar.hour_index())


func set_woods(stand: StandScript) -> void:
	"""The woods' trees, which the grove counts (its record)."""
	_stand = stand


func set_panel_shower(shower: Callable) -> void:
	"""`shower()` brings the Orchard panel into the right column (demo_detail_zone.gd PANEL_ORCHARD)."""
	_show_panel = shower


# --- the grove's rule (forest_crew.gd's hook) -------------------------------------------------------------------------

func grove_protects(at: Vector2) -> bool:
	"""Whether a woods tree standing at `at` is in the protected grove (forestry may not fell it)."""
	return model.grove_protected and at.distance_to(Rules.GROVE_AT) <= Rules.GROVE_RADIUS_M


func grove_trees_standing() -> int:
	"""The woods' trees standing (mature or young) in the grove."""
	if _stand == null:
		return 0
	var n: int = 0
	for t: int in _stand.count():
		var state: int = _stand.state_of(t)
		if _stand.at[t].distance_to(Rules.GROVE_AT) <= Rules.GROVE_RADIUS_M \
				and (state == StandScript.STATE_MATURE or state == StandScript.STATE_YOUNG):
			n += 1
	return n


# --- each frame ---------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""The day's close at midnight, the jobs on the cast's clock, and the panel a few times a second while shown."""
	if _services == null:
		return
	_follow_day()
	jobs.update(_cast.clock.frame_usec if _cast != null else 0)
	_panel_s += delta
	if panel != null and _panel_s >= PANEL_REFRESH_S:
		_panel_s = 0.0
		panel.follow_hud()
		if panel.is_shown():
			refresh_panel()


func _follow_day() -> void:
	"""Note the day's temperature while it is still that day; at each midnight close the day just ended with it (days
	skipped at once share the last reading)."""
	var day: int = _services.calendar.now().absolute_day
	if day == _day_seen and _services.weather != null:
		_day_temperature = _services.weather.day_temperature_tenths()
	while _day_seen < day:
		model.close_day(_day_seen, _day_temperature)
		for k: int in model.apiary.news.size():
			_say(model.apiary.news[k], model.apiary.news_warning[k] == 1)
		_day_seen += 1


func _say(text: String, warning: bool) -> void:
	"""A line in the village news, the Farm's place."""
	if _services != null:
		_services.notices.post(NoticesScript.SOURCE_FARM,
			NoticesScript.LEVEL_WARNING if warning else NoticesScript.LEVEL_NOTE, text)


# --- selecting and ordering ------------------------------------------------------------------------------------------------

func pick_at(ground: Vector2) -> Vector2i:
	"""What a click at `ground` (x, z metres) lands on: (SEL_*, its id), SEL_NONE when nothing of the orchard's."""
	if not ground.is_finite():
		return Vector2i(SEL_NONE, -1)
	for site: int in Rules.SITE_COUNT:
		if ground.distance_to(Rules.site_centre_m(site)) <= PICK_TREE_M:
			return Vector2i(SEL_SITE, site)
	for bush: int in Rules.BUSH_COUNT:
		if ground.distance_to(Rules.BUSH_AT[bush]) <= PICK_SMALL_M:
			return Vector2i(SEL_BUSH, bush)
	for group: int in Rules.GROUP_COUNT:
		if ground.distance_to(Rules.STAND_AT[group]) <= PICK_SMALL_M:
			return Vector2i(SEL_STAND, group)
	if ground.distance_to(Rules.NURSERY_AT) <= PICK_SMALL_M * 1.5:
		return Vector2i(SEL_NURSERY, 0)
	if ground.distance_to(Rules.GROVE_AT) <= PICK_SMALL_M:
		return Vector2i(SEL_GROVE, 0)
	for apiary: int in HiveRules.APIARY_COUNT:
		if ground.distance_to(HiveRules.centre_m(apiary)) <= PICK_SMALL_M:
			return Vector2i(SEL_APIARY, apiary)
	return Vector2i(SEL_NONE, -1)


func on_ground_click(screen: Vector2) -> bool:
	"""A left click on no resident: on an orchard thing, select it and bring the panel (true: taken)."""
	var hit: Vector2i = pick_at(_ground_at(screen))
	if hit.x == SEL_NONE:
		return false
	select(hit.x, hit.y)
	return true


func on_ground_order(screen: Vector2) -> bool:
	"""A right click with residents selected: on an orchard thing, its most pressing work for the nearest of them."""
	var hit: Vector2i = pick_at(_ground_at(screen))
	if hit.x == SEL_NONE:
		return false
	select(hit.x, hit.y)
	var pressing: StringName = cards.pressing(selected_kind, selected_id)
	if pressing == &"":
		if _command != null:
			_command.say(cards.nothing_to_do(selected_kind, selected_id))
		return true
	on_action(pressing)
	return true


func select(kind: int, id: int) -> void:
	"""Select an orchard thing (SEL_NONE: nothing) and bring the panel for it."""
	selected_kind = kind
	selected_id = id
	if kind != SEL_NONE and _show_panel.is_valid():
		_show_panel.call()
	refresh_panel()


func on_action(action: StringName) -> void:
	"""A panel button (or a right click's pressing work): the policy toggles and plans here, every job through the
	board's own order (orchard_jobs.gd `order`), given to the nearest selected resident who may take it."""
	match action:
		&"timing", &"dest", &"keep":
			_cycle_policy(action)
		&"protect":
			model.set_grove_protected(not model.grove_protected)
		&"plan_apple", &"plan_pear":
			_answer(Text.plant_words(model.add_plan(Rules.APPLE if action == &"plan_apple" else Rules.PEAR, selected_id)))
		&"drop_plan":
			model.drop_plan(model.plan_for_site(selected_id))
		_:
			var job: Vector3i = cards.job_of(action, selected_kind, selected_id)
			if job.x >= 0:
				var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
				_answer(jobs.order(job.x, job.y, job.z, members))
	refresh_panel()


func _cycle_policy(action: StringName) -> void:
	"""The selected thing's group's policy, stepped on (ECO-010)."""
	var group: int = cards.group_of(selected_kind, selected_id)
	if group < 0:
		return
	match action:
		&"timing":
			model.group_timing[group] = (model.group_timing[group] + 1) % Rules.TIMING_NAMES.size()
		&"dest":
			model.group_dest[group] = (model.group_dest[group] + 1) % Rules.DEST_NAMES.size()
		&"keep":
			var at: int = Array(Rules.KEEP_STEPS).find(model.group_keep[group])
			model.group_keep[group] = Rules.KEEP_STEPS[(at + 1) % Rules.KEEP_STEPS.size()]
	model.revision += 1


func _answer(refusal: String) -> void:
	"""Say why an order or a plan was refused (nothing when it went ahead)."""
	if not refusal.is_empty() and _command != null:
		_command.say("Can't: %s" % refusal)


func refresh_panel() -> void:
	"""Fill the panel: the standing line, the selection and its cards, the group, the nursery, the grove, the jobs."""
	if panel == null:
		return
	panel.show_status(cards.status_line(), cards.jobs_line())
	panel.show_selection(cards.title(selected_kind, selected_id), cards.text(selected_kind, selected_id),
		cards.shown_actions(selected_kind, selected_id))
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	for action: StringName in cards.shown_actions(selected_kind, selected_id):
		var refusal: String = cards.refusal(action, selected_kind, selected_id)
		panel.set_card(action, cards.card_text(action, selected_kind, selected_id, members, refusal), refusal.is_empty())
	var group: int = cards.group_of(selected_kind, selected_id)
	panel.show_group(Rules.GROUP_NAMES[group] if group >= 0 else "", cards.group_text(group), cards.timing_word(group),
		cards.dest_word(group), cards.keep_word(group))
	for action: StringName in PanelScript.GROUP_ACTIONS:
		panel.set_card(action, cards.policy_tip(action, group), group >= 0)
	panel.set_card(&"protect", cards.policy_tip(&"protect", -1), true)
	panel.show_nursery("The nursery", cards.nursery_text())
	panel.show_grove(Text.cap(Rules.GROVE_NAME), cards.grove_text(), model.grove_protected)


func _ground_at(screen: Vector2) -> Vector2:
	"""Where a screen point meets the ground plane (x z metres); INF when it does not."""
	if _camera == null:
		return Vector2.INF
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var normal: Vector3 = _camera.project_ray_normal(screen)
	if absf(normal.y) < 1e-5:
		return Vector2.INF
	var t: float = -origin.y / normal.y
	if t <= 0.0:
		return Vector2.INF
	var hit: Vector3 = origin + normal * t
	return Vector2(hit.x, hit.z)
