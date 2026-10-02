extends Node3D
## THE HALL (decision 0771; Brendan's ruling of 2026-10-01, "the adopted version"): the village's community hall as a
## building that grows -- STAGE 1, the hall the village starts with; STAGE 2, its one tier-2 upgrade (REQ-SET-136's
## package; BAL-SAFE-013's single application); the optional banners -- each a construction project carried in and
## built by the residents through the work board; and THE VILLAGE TAPESTRY, its history woven in the hall.
## Presentation only: nothing here writes into the settlement simulation.
##
##   projects        hall_projects.gd -- the tier, the projects, their materials and work (integer, packed)
##   crew            hall_crew.gd -- the builders' rounds (one hall_task.gd each)
##   tapestry        tapestry.gd -- the history and ITS API (add_entry; see tapestry.gd THE API)
##   view            hall_view.gd -- the site pile, the scaffold, the great hall's additions, the banners
##   panel           hall_panel.gd -- opened by clicking the hall; tapestry_panel.gd -- opened from it
##
## THE GATHERING QUERY (for the feasts, #9): `gathering_seats()` -- the hall's 12 seat places; `seats_needed(E)` --
## §5.7's ceil(E / 3); `can_gather(E)`; `gathering_capacity()` -- the most a feast can be planned for (36). And
## `comfort_target()`, `fuel_permille()` (x0.75 at tier 2: for a hearth lit here) and `tier()`.
##
## WHAT IS WOVEN BY THE HALL ITSELF, each once (tapestry.gd once-only keys): stage 1 at the village's first day; the
## first harvest gathered into store (the farm crew's harvest log, decision 0491); the first winter setting in (Y1
## Winter 1); stage 2 raised; each banner hung. Each is also posted to the village news.
##
## INPUT: a left click on the hall opens the panel (a ground handler, asked after the farm's, the woods' and the
## water's); a right click on it with residents selected sends them to a project under way. No key is added.

const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const CrewScript := preload("res://demo/hall/hall_crew.gd")
const TapestryScript := preload("res://demo/hall/tapestry.gd")
const ViewScript := preload("res://demo/hall/hall_view.gd")
const PanelScript := preload("res://demo/hall/hall_panel.gd")
const TapestryPanelScript := preload("res://demo/hall/tapestry_panel.gd")
const HallWork := preload("res://demo/work/hall_work.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## The stockpile's work spot: where the stores are fetched from (world_layout.gd POINTS).
const STORE_POI: StringName = &"stockpile"
## Winter's first tick in year 1 (the offset calendar: day d starts at d x 18000 - 4500).
const WINTER: int = 3
const FIRST_WINTER_TICK: int = WINTER * SimClock.DAYS_PER_SEASON * SimClock.TICKS_PER_DAY \
	- SimClock.CALENDAR_OFFSET_TICKS
const KEY_STAGE_1: StringName = &"hall_stage_1"
const KEY_STAGE_2: StringName = &"hall_stage_2"
const KEY_FIRST_HARVEST: StringName = &"first_harvest"
const KEY_FIRST_WINTER: StringName = &"first_winter"

var projects: ProjectsScript = null
var crew: CrewScript = CrewScript.new()
var tapestry: TapestryScript = null
var view: ViewScript = null
var panel: PanelScript = null
var tapestry_panel: TapestryPanelScript = null

var _services: ServicesScript = null
var _cast: DemoCastScript = null
var _camera: Camera3D = null
## The farm's crew (demo/farm/farm_crew.gd): its harvest log, read for the first harvest (none: never seen).
var _farm_crew: RefCounted = null
## `() -> PackedInt32Array`: the residents selected now.
var _selection: Callable = Callable()
var _harvest_seen: bool = false
var _winter_seen: bool = false


func configure(cast: DemoCastScript, services: ServicesScript, world: Node3D, camera: Camera3D) -> void:
	"""The hall over this cast and the village's stores, calendar and props; its pieces drawn with `world`'s models
	(none: unseen); clicks picked through `camera` (none: no clicks)."""
	name = "DemoHall"
	_cast = cast
	_services = services
	_camera = camera
	projects = ProjectsScript.new(services.stores)
	projects.set_done_hook(_on_done)
	tapestry = TapestryScript.new(services.calendar)
	view = ViewScript.new()
	add_child(view)
	view.build(world, services.props)
	crew.configure(projects, cast, services.props, services.calendar)
	crew.set_places(store_point(), view.site_point(), view.centre(), view.work_spots(), view.work_faces())
	_build_panels()
	tapestry.add_entry_at(0, TapestryScript.KIND_STAGE, "Stage 1: the community hall",
		"It stood when the village came: twelve seats for its meals, songs and gatherings, and a dry floor for anyone "
		+ "without a bed.", KEY_STAGE_1)
	view.sync(projects)


func _build_panels() -> void:
	"""The hall's panel and the tapestry's, each standing in for the other."""
	panel = PanelScript.new()
	add_child(panel)
	panel.configure(projects, crew, _services.stores, tapestry)
	panel.set_actions({&"plan_upgrade": plan_upgrade, &"cancel_upgrade": cancel_upgrade, &"plan_banner": plan_banner,
		&"cancel_banner": cancel_banner, &"tapestry": open_tapestry})
	tapestry_panel = TapestryPanelScript.new()
	add_child(tapestry_panel)
	tapestry_panel.configure(tapestry, open)


static func store_point() -> Vector2:
	"""The stockpile's work spot (world_layout.gd POINTS), where the builders fetch the stores."""
	for point: Dictionary in Layout.points_of_interest_for(Layout.placements()):
		if point["name"] == STORE_POI:
			var at: Vector3 = point["position"]
			return Vector2(at.x, at.z)
	return Vector2.ZERO


func bind_farm(farm_crew: RefCounted) -> void:
	"""Read this farm crew's harvest log (farm_crew.gd `harvests`) for the first harvest."""
	_farm_crew = farm_crew


func bind_board(board: RefCounted) -> void:
	"""List the hall's places on the village's work board (work/hall_work.gd), which hands them out."""
	board.call(&"add_source", HallWork.new(crew, projects, view.centre()))


func set_selection(selection: Callable) -> void:
	"""`selection() -> PackedInt32Array`: the residents selected now (sent when a project is planned)."""
	_selection = selection


func set_bedless(names: Callable) -> void:
	"""`names() -> String`: who has no bed (they sleep on the hall's floor; the panel names them)."""
	panel.set_bedless(names)


func set_hearth(words: Callable, stamp: Callable) -> void:
	"""`words() -> String`: the hall's hearth now (the winter's, decision 0571); `stamp() -> int` changes when it may have.
	The panel's Heat line says it."""
	panel.set_hearth(words, stamp)


# --- each frame ---------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Watch for what the tapestry weaves and what opens the upgrade; redraw the hall when its projects changed."""
	if projects == null:
		return
	watch()
	view.sync(projects)


func watch() -> void:
	"""The first harvest, the first winter and the unlock, each noticed once (plain integer reads; no allocation until
	one is first seen)."""
	if not _harvest_seen and _farm_crew != null and int(_farm_crew.get(&"harvests")) > 0:
		_harvest_seen = true
		_weave_first_harvest()
	if not _winter_seen and _services.calendar.tick >= FIRST_WINTER_TICK:
		_winter_seen = true
		tapestry.add_entry(TapestryScript.KIND_WINTER, "The first winter set in",
			"The village's first winter came on; the hall kept its doors open to anyone in from the cold.", KEY_FIRST_WINTER)
		_say("The first winter set in: woven into the hall's tapestry")
	if not projects.unlocked and unlock_met():
		projects.unlocked = true
		projects.revision += 1
		_say("The hall can be raised now: plan its upgrade in the hall's panel (click the hall)")


func unlock_met() -> bool:
	"""Whether hall_rules.gd UNLOCK_CONDITION (Brendan's ruling, decision 0771) holds now."""
	match Rules.UNLOCK_CONDITION:
		Rules.UNLOCK_FIRST_HARVEST:
			return _harvest_seen
		Rules.UNLOCK_FIRST_WINTER:
			return _winter_seen
	return true


func _weave_first_harvest() -> void:
	"""The first harvest in store, woven: who brought it in, and from which bed."""
	var by: PackedInt32Array = _farm_crew.get(&"harvested_by")
	var beds: PackedInt32Array = _farm_crew.get(&"harvested_bed")
	var k: int = maxi(by.size() - int(_farm_crew.get(&"harvests")), 0)
	var text: String = "The first crop came in from the beds."
	if k < by.size() and by[k] >= 0 and by[k] < _cast.actor_count():
		text = "%s brought the first crop in from bed %d." % [(_cast.actor(by[k]) as DemoActorScript).display_name,
			beds[k] + 1]
	tapestry.add_entry(TapestryScript.KIND_HARVEST, "The first harvest gathered", text, KEY_FIRST_HARVEST)
	_say("The first harvest is gathered: woven into the hall's tapestry")


func _on_done(project: int) -> void:
	"""A project finished (hall_projects.gd's done hook): woven, and told."""
	var names: String = crew.names_on(project)
	var by: String = " by %s" % names if not names.is_empty() else ""
	if project == Rules.PROJECT_UPGRADE:
		tapestry.add_entry(TapestryScript.KIND_STAGE, "Stage 2: the great hall raised",
			"Raised%s: stone 40, wood 20 and cloth 8 built in. A hearth here burns a quarter less, and the common room's "
			% by + "comfort target is now %d." % projects.comfort_target(), KEY_STAGE_2)
		_say("The great hall is raised%s: warmer, a hearth burns a quarter less (stage 2 of 2)" % by)
		return
	var n: int = project - Rules.PROJECT_BANNER_FIRST + 1
	tapestry.add_entry(TapestryScript.KIND_DRESSING, "Banner %d hung in the hall" % n,
		"Hung%s. The common room's comfort target is now %d." % [by, projects.comfort_target()])
	_say("A banner is hung in the hall%s (%d of %d)" % [by, projects.banners_hung(), Rules.BANNERS_MAX])


func _say(text: String) -> void:
	"""Post to the village news."""
	if _services != null:
		_services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text)


# --- the player's actions -----------------------------------------------------------------------------------------

func plan_upgrade() -> String:
	"""Plan the tier-2 upgrade; the residents selected go at once. The answer, in words."""
	var why: String = projects.plan_upgrade()
	if not why.is_empty():
		return "Can't plan the upgrade: %s" % why
	var sent: int = crew.give_selected(Rules.PROJECT_UPGRADE, _selected())
	_say("The hall's upgrade is planned: stone 40, wood 20 and cloth 8 to carry in from the stores, then 1200 WU")
	return "Upgrade planned. %s" % _sent_words(sent)


func plan_banner() -> String:
	"""Plan one more banner; a selected resident goes at once. The answer, in words."""
	var p: int = projects.plan_banner()
	if p < 0:
		return "Can't hang another banner: %s" % ProjectsScript.REFUSE_BANNERS_FULL
	var sent: int = crew.give_selected(p, _selected())
	return "Banner %d planned. %s" % [p - Rules.PROJECT_BANNER_FIRST + 1, _sent_words(sent)]


func cancel_upgrade() -> String:
	"""Cancel the upgrade under way (REQ-SET-126). The answer, in words."""
	return _cancel(Rules.PROJECT_UPGRADE, "The upgrade")


func cancel_banner() -> String:
	"""Cancel the latest banner not yet hung (REQ-SET-126). The answer, in words."""
	var p: int = projects.last_planned_banner()
	return _cancel(p, "Banner %d" % (p - Rules.PROJECT_BANNER_FIRST + 1))


func _cancel(project: int, what: String) -> String:
	"""Cancel `project` -- REQ-SET-126's share of what was delivered comes back, and any load in arms whole -- then let its
	builders go: cancelled first, nobody can be handed a place on it again while they are let go. The answer, in
	words."""
	if not projects.is_active(project):
		return "Nothing to cancel"
	var why: String = projects.cancel(project)
	if not why.is_empty():
		return why
	crew.release_project(project)
	var said: String = "%s cancelled: %s came back to the stores" % [what, projects.last_refund]
	_say(said)
	return said


func _selected() -> PackedInt32Array:
	"""The residents selected now (none without a selection reader)."""
	if not _selection.is_valid():
		return PackedInt32Array()
	var out: PackedInt32Array = _selection.call()
	return out


static func _sent_words(sent: int) -> String:
	"""Who went: the selected residents, or the work board."""
	if sent <= 0:
		return "The work board sends builders."
	return "%d selected resident%s set off." % [sent, "" if sent == 1 else "s"]


# --- clicks -------------------------------------------------------------------------------------------------------

func hits(screen: Vector2) -> bool:
	"""Whether a click at `screen` lands on the hall (its box, ground to roof)."""
	if _camera == null:
		return false
	return view.bounds().intersects_ray(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen)) != null


func on_click(screen: Vector2) -> bool:
	"""A left click on the hall opens its panel (taken: the selection is kept)."""
	if not hits(screen):
		return false
	open()
	return true


func on_order(screen: Vector2) -> bool:
	"""A right click on the hall with residents selected: they take places on a project under way (the upgrade first,
	else the banner being hung). Not taken when nothing is under way -- an ordinary move then."""
	if not hits(screen):
		return false
	var p: int = Rules.PROJECT_UPGRADE if projects.is_active(Rules.PROJECT_UPGRADE) else projects.last_planned_banner()
	if p < 0:
		return false
	var sent: int = crew.give_selected(p, _selected())
	_say("%s: %s" % [CrewScript.project_verb(p), _sent_words(sent)] if sent > 0 else "No free place at the hall now")
	return true


func open() -> void:
	"""Show the hall's panel (the tapestry closed)."""
	tapestry_panel.close_window()
	panel.open()


func open_tapestry() -> void:
	"""Show the tapestry (the hall's panel closed)."""
	panel.close_window()
	tapestry_panel.open()


func is_open() -> bool:
	"""Whether the hall's panel or the tapestry is open (a planning surface)."""
	return panel.is_open() or tapestry_panel.is_open()


# --- the gathering query (#9) and the hall's readouts -------------------------------------------------------------

func gathering_seats() -> int:
	"""The hall's seat places for meals, songs and feasts: the starter interior's 12, the same at both stages."""
	return Rules.SEATS


func seats_needed(eligible: int) -> int:
	"""§5.7: the seats a feast for `eligible` residents needs, ceil(E / 3)."""
	return Rules.seats_needed(eligible)


func can_gather(eligible: int) -> bool:
	"""Whether the hall seats a feast for `eligible` residents."""
	return seats_needed(eligible) <= gathering_seats()


func gathering_capacity() -> int:
	"""The most residents a feast in the hall can be planned for (36)."""
	return Rules.gathering_capacity(gathering_seats())


func tier() -> int:
	"""The hall's tier: 1, or 2 once raised."""
	return projects.tier


func comfort_target() -> int:
	"""The common room's comfort target now."""
	return projects.comfort_target()


func fuel_permille() -> int:
	"""A hearth's fuel use here, per mille of the ordinary (750 at tier 2)."""
	return projects.fuel_permille()
