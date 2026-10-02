extends "res://test/framework/test_case.gd"
## The hall (decision 0771; Brendan's ruling of 2026-10-01, "the adopted version"): its two stages -- the hall and its
## ONE tier-2 upgrade, REQ-SET-136's package, BAL-SAFE-013's refusal of a second -- and up to four banners, each
## carried in from the stores (REQ-SET-124/125, §5.2 carry capacities at §5.7's masses) and built; REQ-SET-126's refund;
## what the hall gives (seats, the feast's ceil(E / 3), comfort, fuel); the tapestry and its API; the builders' rounds
## on the placeholder cast (out of the tree, stepped at 30 Hz); the work board's adapter; the panel's words; the view.

const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const CrewScript := preload("res://demo/hall/hall_crew.gd")
const TapestryScript := preload("res://demo/hall/tapestry.gd")
const ViewScript := preload("res://demo/hall/hall_view.gd")
const PanelScript := preload("res://demo/hall/hall_panel.gd")
const TapestryPanelScript := preload("res://demo/hall/tapestry_panel.gd")
const HallScript := preload("res://demo/hall/demo_hall.gd")
const HallTaskScript := preload("res://demo/hall/hall_task.gd")
const HallWork := preload("res://demo/work/hall_work.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const UiArt := preload("res://test/fixtures/ui_art_fixture.gd")

const DT: float = 1.0 / 30.0
const UPGRADE: int = Rules.PROJECT_UPGRADE
const BANNER_1: int = Rules.PROJECT_BANNER_FIRST
const WOOD: int = Rules.MAT_WOOD
const STONE: int = Rules.MAT_STONE
const CLOTH: int = Rules.MAT_CLOTH


## The farm crew's harvest log as the hall reads it (farm_crew.gd `harvests`, `harvested_by`, `harvested_bed`).
class FakeFarm extends RefCounted:
	var harvests: int = 0
	var harvested_by: PackedInt32Array = PackedInt32Array()
	var harvested_bed: PackedInt32Array = PackedInt32Array()


var _cast: DemoCastScript = null
var _done: PackedInt32Array = PackedInt32Array()


func after_each() -> void:
	"""Free the cast, if a test built one."""
	if _cast != null:
		_cast.free()
		_cast = null
	_done.clear()


# --- helpers ------------------------------------------------------------------------------------------------------

static func _stores(wood_u: int, stone_u: int) -> StoresScript:
	"""Stores holding exactly this much wood and stone."""
	var stores := StoresScript.new()
	stores.wood_milli_u = wood_u * 1000
	stores.stone_milli_u = stone_u * 1000
	return stores


func _unlocked(stores: StoresScript) -> ProjectsScript:
	"""Projects over `stores`, the upgrade unlocked, every finish recorded in `_done`."""
	var projects := ProjectsScript.new(stores)
	projects.unlocked = true
	projects.set_done_hook(func(p: int) -> void: _done.append(p))
	return projects


static func _deliver_all(projects: ProjectsScript, project: int) -> void:
	"""Carry every material `project` needs straight in (reserve, lift, set down)."""
	for mat: int in Rules.MAT_COUNT:
		var need: int = Rules.need_milli(project, mat)
		if need > 0:
			var got: int = projects.lift(project, mat, projects.reserve(project, mat, need))
			projects.deliver(project, mat, got)


static func _totals(projects: ProjectsScript) -> PackedInt64Array:
	"""Every milli-U the village owns of each material (hall_projects.gd `held_total`)."""
	return PackedInt64Array([projects.held_total(WOOD), projects.held_total(STONE), projects.held_total(CLOTH)])


func _new_cast() -> void:
	"""The placeholder cast in the village's bounds, out of the tree."""
	_cast = DemoCastScript.new()
	_cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	_cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))


func _crew(projects: ProjectsScript) -> CrewScript:
	"""A crew over `projects` on the cast, at the village's own places (the hall's frame, the stockpile)."""
	var view := ViewScript.new()
	var crew := CrewScript.new()
	crew.configure(projects, _cast, null, null)
	crew.set_places(HallScript.store_point(), view.site_point(), view.centre(), view.work_spots(), view.work_faces())
	view.free()
	return crew


func _brain(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func _run(seconds: float, until: Callable = Callable()) -> void:
	"""Step every brain for `seconds` of demo time, or until `until()` is true."""
	for f: int in roundi(seconds / DT):
		for who: int in _cast.actor_count():
			_brain(who).step(DT)
		if until.is_valid() and bool(until.call()):
			return


# --- the rules ----------------------------------------------------------------------------------------------------

func test_the_upgrade_is_req_set_136s_package_and_a_banner_is_the_decoration_row() -> void:
	"""Stone 40 + wood 20 + cloth 8, 1200 WU, four builders; a banner wood 1 (decision 0210's wax substitution), 12 WU."""
	assert_equal(Rules.need_milli(UPGRADE, STONE), 40000, "stone 40")
	assert_equal(Rules.need_milli(UPGRADE, WOOD), 20000, "wood 20")
	assert_equal(Rules.need_milli(UPGRADE, CLOTH), 8000, "cloth 8")
	assert_equal(Rules.work_wu(UPGRADE), 1200, "1200 WU")
	assert_equal(Rules.places_of(UPGRADE), 4, "§5.9: at most 4 builders")
	assert_equal(Rules.need_milli(BANNER_1, WOOD), 1000, "a banner: wood 1")
	assert_equal(Rules.need_milli(BANNER_1, STONE) + Rules.need_milli(BANNER_1, CLOTH), 0, "nothing else")
	assert_equal(Rules.work_wu(BANNER_1), 12, "12 WU")
	assert_equal(Rules.places_of(BANNER_1), 1, "one hand a banner")
	assert_equal(Rules.need_milli(-1, WOOD) + Rules.need_milli(UPGRADE, 3) + Rules.work_wu(9), 0, "unknowns are nothing")
	assert_equal(Rules.STAGE_COUNT, 2, "two stages: tier 3 is absent")


func test_rows_map_to_projects_and_back() -> void:
	"""Rows 0-3 are the upgrade's places, 4-7 one banner each; out of range is no project."""
	assert_equal(Rules.ROWS, 8, "eight places")
	for row: int in 4:
		assert_equal(Rules.row_project(row), UPGRADE, "row %d: the upgrade" % row)
	for k: int in 4:
		assert_equal(Rules.row_project(4 + k), BANNER_1 + k, "row %d: banner %d" % [4 + k, k + 1])
		assert_equal(Rules.first_row(BANNER_1 + k), 4 + k, "and back")
	assert_equal(Rules.first_row(UPGRADE), 0, "the upgrade's first place")
	assert_equal(Rules.row_project(-1), -1, "below")
	assert_equal(Rules.row_project(8), -1, "above")
	assert_equal(Rules.first_row(5), -1, "no project 5")
	assert_true(Rules.is_banner(4) and not Rules.is_banner(UPGRADE) and not Rules.is_banner(5), "which are banners")


func test_a_load_is_the_carriers_capacity_at_the_materials_mass() -> void:
	"""§5.2's 12000 / 16000 / 24000 g at §5.7's wood and stone 5000 g, cloth 250 g a unit."""
	assert_equal(Rules.load_milli(MealRules.SIZE_SMALL, STONE), 2400, "a mouse: 2.4 U of stone")
	assert_equal(Rules.load_milli(MealRules.SIZE_MEDIUM, WOOD), 3200, "an otter: 3.2 U of wood")
	assert_equal(Rules.load_milli(MealRules.SIZE_LARGE, STONE), 4800, "a badger: 4.8 U of stone")
	assert_equal(Rules.load_milli(MealRules.SIZE_SMALL, CLOTH), 48000, "cloth is light: 48 U")
	assert_equal(Rules.load_milli(MealRules.SIZE_SMALL, 7), 0, "no such material")
	assert_equal(Rules.load_milli(99, WOOD), 4800, "an unknown size clamps to large")


func test_req_set_126_refunds_all_before_work_and_eighty_percent_after_floored() -> void:
	"""All of it before work begins; after, 80% rounded down to milli-U."""
	assert_equal(Rules.refund_milli(12345, false), 12345, "before: all")
	assert_equal(Rules.refund_milli(12345, true), 9876, "after: 9876 (80% of 12345 = 9876.0)")
	assert_equal(Rules.refund_milli(1, true), 0, "after: 0.8 rounds down to 0")
	assert_equal(Rules.refund_milli(5, true), 4, "after: 4")
	assert_equal(Rules.refund_milli(0, false) + Rules.refund_milli(-3, true), 0, "nothing back for nothing")


func test_comfort_fuel_and_the_feasts_seats() -> void:
	"""Comfort 7500 +1000 at tier 2 +250 a banner up to 1000; fuel x1.00 / x0.75; seats >= ceil(E / 3)."""
	assert_equal(Rules.comfort_target(1, 0), 7500, "the heated common room")
	assert_equal(Rules.comfort_target(2, 0), 8500, "tier 2: +1000")
	assert_equal(Rules.comfort_target(1, 3), 8250, "three banners")
	assert_equal(Rules.comfort_target(2, 4), 9500, "tier 2 and four banners")
	assert_equal(Rules.comfort_target(2, 9), 9500, "decorations cap at 1000")
	assert_equal(Rules.comfort_target(1, -2), 7500, "no negative banners")
	assert_equal(Rules.fuel_permille(1), 1000, "tier 1")
	assert_equal(Rules.fuel_permille(2), 750, "tier 2: x0.75")
	assert_equal(Rules.fuel_permille(7), 750, "clamped")
	for pair: Vector2i in [Vector2i(0, 0), Vector2i(-4, 0), Vector2i(1, 1), Vector2i(3, 1), Vector2i(4, 2),
			Vector2i(9, 3), Vector2i(36, 12), Vector2i(37, 13)]:
		assert_equal(Rules.seats_needed(pair.x), pair.y, "E=%d needs %d seats" % [pair.x, pair.y])
	assert_equal(Rules.gathering_capacity(Rules.SEATS), 36, "12 seats serve 36")
	assert_equal(Rules.gathering_capacity(-1), 0, "no seats serve nobody")


func test_the_unlock_is_one_data_constant_the_first_harvest() -> void:
	"""The first harvest opens the upgrade (Brendan's ruling, decision 0771), and its words say so."""
	assert_equal(Rules.UNLOCK_CONDITION, Rules.UNLOCK_FIRST_HARVEST, "the first harvest")
	assert_true(Rules.UNLOCK_WORDS[Rules.UNLOCK_CONDITION].contains("harvest"), "worded")
	assert_false(ProjectsScript.new(_stores(0, 0)).unlocked, "locked at the start")


# --- the projects -------------------------------------------------------------------------------------------------

func test_the_upgrade_is_refused_while_locked_then_planned_once() -> void:
	"""Locked: refused in words; unlocked: planned; again: refused as planned."""
	var projects := ProjectsScript.new(_stores(40, 40))
	assert_true(projects.plan_upgrade().begins_with("The upgrade opens"), "locked")
	assert_equal(projects.phase[UPGRADE], ProjectsScript.PHASE_NONE, "nothing planned")
	projects.unlocked = true
	assert_equal(projects.plan_upgrade(), "", "planned")
	assert_equal(projects.phase[UPGRADE], ProjectsScript.PHASE_DELIVERING, "its materials to carry in")
	assert_equal(projects.plan_upgrade(), ProjectsScript.REFUSE_PLANNED, "planned already")


func test_building_starts_only_once_everything_is_delivered() -> void:
	"""REQ-SET-125: work credited while delivering does nothing; the last load starts the building."""
	var projects := _unlocked(_stores(40, 40))
	projects.plan_upgrade()
	assert_false(projects.add_work(UPGRADE, 1000000, 0), "no work before delivery")
	assert_equal(projects.work_usec[UPGRADE], 0, "none credited")
	projects.deliver(UPGRADE, STONE, projects.lift(UPGRADE, STONE, projects.reserve(UPGRADE, STONE, 40000)))
	projects.deliver(UPGRADE, WOOD, projects.lift(UPGRADE, WOOD, projects.reserve(UPGRADE, WOOD, 20000)))
	assert_equal(projects.phase[UPGRADE], ProjectsScript.PHASE_DELIVERING, "the cloth is still to come")
	projects.deliver(UPGRADE, CLOTH, projects.lift(UPGRADE, CLOTH, projects.reserve(UPGRADE, CLOTH, 8000)))
	assert_equal(projects.phase[UPGRADE], ProjectsScript.PHASE_BUILDING, "building")
	assert_equal(projects.cloth_milli, 16000, "8 of the village's 24 cloth taken")


func test_the_upgrade_raises_tier_2_once_and_a_second_is_refused() -> void:
	"""1200 WU of work raises tier 2 and tells the hook once; BAL-SAFE-013: a second application is refused."""
	var projects := _unlocked(_stores(40, 40))
	projects.plan_upgrade()
	_deliver_all(projects, UPGRADE)
	assert_false(projects.add_work(UPGRADE, 1199 * Rules.USEC_PER_WU, 5), "1199 WU: not yet")
	assert_equal(projects.tier, 1, "still tier 1")
	assert_true(projects.add_work(UPGRADE, Rules.USEC_PER_WU * 3, 7), "the 1200th WU raises it")
	assert_equal(projects.tier, Rules.TIER_GREAT, "tier 2")
	assert_equal(projects.done_tick[UPGRADE], 7, "dated")
	assert_equal(_done, PackedInt32Array([UPGRADE]), "told once")
	assert_true(projects.add_work(UPGRADE, 1000, 9), "done stays done")
	assert_equal(_done.size(), 1, "and is not told again")
	assert_equal(projects.plan_upgrade(), ProjectsScript.REFUSE_SECOND, "no tier 3")
	assert_equal(projects.upgrade_refusal(), ProjectsScript.REFUSE_SECOND, "refused in words")
	assert_equal(projects.comfort_target(), 8500, "warmer")
	assert_equal(projects.fuel_permille(), 750, "a hearth burns a quarter less")


func test_a_cancel_before_work_gives_everything_back() -> void:
	"""REQ-SET-126: cancelled before work begins, 100% of the delivered materials come back to the stores."""
	var stores := _stores(40, 40)
	var projects := _unlocked(stores)
	projects.plan_upgrade()
	_deliver_all(projects, UPGRADE)
	assert_equal(stores.stone_milli_u, 0, "the stone carried in")
	assert_equal(projects.cancel(UPGRADE), "", "cancelled")
	assert_equal(Vector3i(stores.wood_milli_u, stores.stone_milli_u, projects.cloth_milli), Vector3i(40000, 40000, 24000),
		"all of it back")
	assert_equal(projects.phase[UPGRADE], ProjectsScript.PHASE_NONE, "not planned")
	assert_equal(projects.cancel(UPGRADE), ProjectsScript.REFUSE_NOTHING, "nothing to cancel twice")


func test_a_cancel_after_work_gives_eighty_percent_back() -> void:
	"""REQ-SET-126: after work begins, 80% rounded down; the rest is lost in the work."""
	var stores := _stores(20, 40)
	var projects := _unlocked(stores)
	projects.plan_upgrade()
	_deliver_all(projects, UPGRADE)
	projects.add_work(UPGRADE, 1, 0)
	projects.cancel(UPGRADE)
	assert_equal(Vector3i(stores.wood_milli_u, stores.stone_milli_u, projects.cloth_milli), Vector3i(16000, 32000,
		16000 + 6400), "wood 16, stone 32, cloth 6.4 back")
	assert_true(projects.last_refund.contains("32.0 U stone"), "said: %s" % projects.last_refund)
	assert_equal(projects.cancel(-1), ProjectsScript.REFUSE_NOTHING, "no project")


func test_a_cancel_brings_back_a_load_still_in_arms() -> void:
	"""Cancelled with a load counted in arms (never delivered): it comes back whole, whatever the release order."""
	var stores := _stores(0, 10)
	var projects := _unlocked(stores)
	projects.plan_upgrade()
	var got: int = projects.lift(UPGRADE, STONE, projects.reserve(UPGRADE, STONE, 2400))
	assert_equal(got, 2400, "lifted")
	projects.cancel(UPGRADE)
	assert_equal(stores.stone_milli_u, 10000, "the load back whole")
	projects.return_load(UPGRADE, STONE, got)
	assert_equal(stores.stone_milli_u, 10000, "and not twice when the carrier lets go after")


func test_a_finished_project_cannot_be_cancelled() -> void:
	"""Done is done."""
	var projects := _unlocked(_stores(5, 0))
	var p: int = projects.plan_banner()
	_deliver_all(projects, p)
	projects.add_work(p, Rules.BANNER_WU * Rules.USEC_PER_WU, 0)
	assert_equal(projects.cancel(p), ProjectsScript.REFUSE_DONE, "refused")
	assert_equal(projects.banners_hung(), 1, "still hung")


func test_reservations_never_take_from_the_stores_and_lifting_takes_what_is_there() -> void:
	"""REQ-SET-124: a reservation leaves the stores whole; lifting takes as much as is there, never more than reserved."""
	var stores := _stores(0, 3)
	var projects := _unlocked(stores)
	projects.plan_upgrade()
	assert_equal(projects.reserve(UPGRADE, STONE, 2400), 2400, "a mouse sets off for 2.4 U")
	assert_equal(stores.stone_milli_u, 3000, "nothing taken yet")
	assert_equal(projects.in_stock(STONE), 600, "but only 0.6 U is free for others")
	assert_equal(projects.reserve(UPGRADE, STONE, 2400), 600, "a second carrier: the rest")
	assert_equal(projects.fetchable(UPGRADE, STONE), 0, "nothing left to set off for")
	assert_equal(projects.next_material(UPGRADE), CLOTH, "no wood in the stores: the cloth next")
	stores.stone_milli_u = 1000
	assert_equal(projects.lift(UPGRADE, STONE, 2400), 400, "1 U left, 0.6 of it the second carrier's: it lifts 0.4")
	assert_equal(projects.transit[projects.cell(UPGRADE, STONE)], 400, "in arms")
	assert_equal(projects.lift(UPGRADE, STONE, 600), 600, "the second lifts its own 0.6")
	assert_equal(stores.stone_milli_u, 0, "the stores emptied, never below")
	assert_equal(projects.reserved[projects.cell(UPGRADE, STONE)], 0, "both reservations gone")
	assert_equal(projects.lift(UPGRADE, STONE, 600), 0, "nothing more to lift")
	assert_equal(projects.reserve(UPGRADE, WOOD, 1000), 0, "no wood to reserve")


func test_what_is_reserved_is_no_longer_outstanding() -> void:
	"""With the stores full, a material whose remainder is all reserved by carriers on their way is not fetched again."""
	var projects := _unlocked(_stores(100, 100))
	var p: int = projects.plan_banner()
	assert_equal(projects.outstanding(p, WOOD), 1000, "a banner's wood")
	assert_equal(projects.reserve(p, WOOD, 4800), 1000, "a carrier sets off for all of it")
	assert_equal(projects.outstanding(p, WOOD), 0, "nothing outstanding")
	assert_equal(projects.fetchable(p, WOOD), 0, "nothing to fetch though the stores are full")
	assert_equal(projects.next_material(p), -1, "nothing for another carrier")
	assert_equal(projects.reserve(p, WOOD, 1000), 0, "a second reservation gets nothing")


func test_every_milli_u_is_conserved_through_a_round_and_a_return() -> void:
	"""Stores + arms + delivered stay constant through reserve, lift, deliver and a load put back."""
	var projects := _unlocked(_stores(30, 50))
	projects.plan_upgrade()
	var before: PackedInt64Array = _totals(projects)
	var got: int = projects.lift(UPGRADE, STONE, projects.reserve(UPGRADE, STONE, 2400))
	assert_equal(_totals(projects), before, "lifted")
	projects.deliver(UPGRADE, STONE, got)
	assert_equal(_totals(projects), before, "delivered")
	got = projects.lift(UPGRADE, WOOD, projects.reserve(UPGRADE, WOOD, 3200))
	projects.return_load(UPGRADE, WOOD, got)
	assert_equal(_totals(projects), before, "put back")
	assert_equal(projects.transit[projects.cell(UPGRADE, WOOD)], 0, "nothing in arms")
	projects.return_load(UPGRADE, WOOD, 999)
	projects.deliver(UPGRADE, WOOD, 999)
	assert_equal(_totals(projects), before, "a load that is not in arms moves nothing")


func test_four_banners_at_most_and_their_comfort() -> void:
	"""Four banners, the fifth refused; comfort +250 each, the latest planned cancelled first."""
	var projects := _unlocked(_stores(10, 0))
	for k: int in 4:
		assert_equal(projects.plan_banner(), BANNER_1 + k, "banner %d" % (k + 1))
	assert_equal(projects.plan_banner(), -1, "a fifth is refused")
	assert_equal(projects.free_banner(), -1, "none free")
	assert_equal(projects.banners_planned(), 4, "four planned")
	assert_equal(projects.last_planned_banner(), BANNER_1 + 3, "the latest")
	for k: int in 3:
		_deliver_all(projects, BANNER_1 + k)
		projects.add_work(BANNER_1 + k, Rules.BANNER_WU * Rules.USEC_PER_WU, 0)
	assert_equal(projects.banners_hung(), 3, "three hung")
	assert_equal(projects.comfort_target(), 8250, "+750")
	assert_equal(projects.cancel(projects.last_planned_banner()), "", "the fourth cancelled")
	assert_equal(projects.free_banner(), BANNER_1 + 3, "free again")


func test_progress_reads_delivery_then_work() -> void:
	"""Percent is the delivery by mass while delivering, then the work."""
	var projects := _unlocked(_stores(20, 40))
	projects.plan_upgrade()
	assert_equal(projects.percent(UPGRADE), 0, "nothing yet")
	projects.deliver(UPGRADE, STONE, projects.lift(UPGRADE, STONE, projects.reserve(UPGRADE, STONE, 40000)))
	assert_equal(projects.delivered_permille(UPGRADE), 662, "200 kg of 302 kg")
	assert_equal(projects.percent(UPGRADE), 66, "66%")
	_deliver_all(projects, UPGRADE)
	projects.add_work(UPGRADE, 300 * Rules.USEC_PER_WU, 0)
	assert_equal(projects.percent(UPGRADE), 25, "300 of 1200 WU")
	assert_equal(projects.work_done_wu(UPGRADE), 300, "in WU")
	assert_equal(projects.work_left_usec(UPGRADE), 900 * Rules.USEC_PER_WU, "900 WU left")
	assert_equal(projects.percent(BANNER_1), 0, "an unplanned banner")


# --- the tapestry -------------------------------------------------------------------------------------------------

func test_the_tapestry_weaves_entries_in_date_order() -> void:
	"""add_entry dates now; add_entry_at weaves by date (ties after the ones there); reading is oldest first."""
	var calendar := CalendarScript.new()
	var tapestry := TapestryScript.new(calendar)
	calendar.tick = 18000
	assert_equal(tapestry.add_entry(TapestryScript.KIND_HARVEST, "First harvest", "Bed 2"), 0, "the first")
	assert_equal(tapestry.add_entry_at(0, TapestryScript.KIND_STAGE, "The hall"), 0, "an older one goes first")
	assert_equal(tapestry.add_entry_at(18000, TapestryScript.KIND_EVENT, "Same day"), 2, "a tie goes after")
	assert_equal(tapestry.count(), 3, "three")
	assert_equal(tapestry.title_of(0), "The hall", "oldest first")
	assert_equal(tapestry.text_of(1), "Bed 2", "its text")
	assert_equal(tapestry.kind_of(1), TapestryScript.KIND_HARVEST, "its kind")
	assert_equal(tapestry.tick_of(2), 18000, "its date")
	assert_equal(tapestry.date_of(0), "Y1 Spring 1", "tick 0 is spring 1")
	assert_equal(tapestry.date_of(1), "Y1 Spring 2", "a day later")
	assert_equal(tapestry.revision, 3, "each woven bumps it")


func test_the_tapestry_refuses_in_words() -> void:
	"""Empty title, unknown kind, a negative date, a once-only key woven already, and a full tapestry."""
	var tapestry := TapestryScript.new(null)
	assert_equal(tapestry.add_entry(TapestryScript.KIND_EVENT, "  "), TapestryScript.REFUSED_EMPTY, "no title")
	assert_equal(tapestry.add_entry(TapestryScript.KIND_COUNT, "x"), TapestryScript.REFUSED_KIND, "no such kind")
	assert_equal(tapestry.add_entry(-1, "x"), TapestryScript.REFUSED_KIND, "below")
	assert_equal(tapestry.add_entry_at(-1, 0, "x"), TapestryScript.REFUSED_TICK, "before tick 0")
	assert_equal(tapestry.add_entry(TapestryScript.KIND_MILESTONE, "A", "", &"m1"), 0, "once")
	assert_equal(tapestry.add_entry(TapestryScript.KIND_MILESTONE, "A", "", &"m1"), TapestryScript.REFUSED_DUPLICATE,
		"not twice")
	assert_true(tapestry.has_key(&"m1") and not tapestry.has_key(&"") and not tapestry.has_key(&"m2"), "keys")
	assert_equal(tapestry.index_of_key(&"m1"), 0, "where")
	assert_equal(tapestry.index_of_key(&""), -1, "no key")
	for k: int in TapestryScript.CAPACITY - 1:
		tapestry.add_entry(TapestryScript.KIND_CHRONICLE, "Entry %d" % k)
	assert_equal(tapestry.count(), TapestryScript.CAPACITY, "full")
	assert_equal(tapestry.add_entry(TapestryScript.KIND_CHRONICLE, "One more"), TapestryScript.REFUSED_FULL, "refused")
	assert_equal(tapestry.title_of(0), "A", "the beginning is kept")
	assert_true(TapestryScript.refusal_text(TapestryScript.REFUSED_FULL).contains("full"), "worded")
	assert_equal(TapestryScript.refusal_text(3), "", "an index is no refusal")
	assert_equal(TapestryScript.refusal_text(-99), "", "an unknown code")
	assert_equal(tapestry.date_of(0), "Y1 Spring 1", "undated without a calendar")


func test_the_tapestry_cuts_long_words() -> void:
	"""A title is cut at TITLE_MAX, a text at TEXT_MAX, both trimmed."""
	var tapestry := TapestryScript.new(null)
	tapestry.add_entry(TapestryScript.KIND_EVENT, " %s " % "t".repeat(100), "x".repeat(400))
	assert_equal(tapestry.title_of(0).length(), TapestryScript.TITLE_MAX, "title cut")
	assert_equal(tapestry.text_of(0).length(), TapestryScript.TEXT_MAX, "text cut")
	assert_equal(TapestryScript.KIND_COLOURS.size(), TapestryScript.KIND_COUNT, "a thread for each kind")
	assert_equal(TapestryScript.KIND_NAMES.size(), TapestryScript.KIND_COUNT, "a name for each kind")


# --- the builders, on the cast -------------------------------------------------------------------------------------

func test_builders_carry_the_upgrade_in_and_raise_the_great_hall() -> void:
	"""Four residents fetch every material from the stockpile in loads, set them down at the hall, then build: tier 2,
	every unit conserved until it is built in, the stores drawn down by exactly the package."""
	_new_cast()
	var stores := _stores(30, 50)
	var projects := _unlocked(stores)
	var crew := _crew(projects)
	projects.plan_upgrade()
	var before: PackedInt64Array = _totals(projects)
	assert_equal(crew.give_selected(UPGRADE, PackedInt32Array([0, 1, 2, 3])), 4, "four places taken")
	assert_equal(crew.give_selected(UPGRADE, PackedInt32Array([4])), 0, "no fifth place (§5.9)")
	var conserved := [true]
	_run(900.0, func() -> bool:
		if projects.phase[UPGRADE] != ProjectsScript.PHASE_DONE and _totals(projects) != before:
			conserved[0] = false
		return projects.phase[UPGRADE] == ProjectsScript.PHASE_DONE)
	assert_true(conserved[0], "conserved at every frame until built")
	assert_equal(projects.tier, Rules.TIER_GREAT, "raised")
	assert_equal(Vector3i(stores.wood_milli_u, stores.stone_milli_u, projects.cloth_milli), Vector3i(10000, 10000, 16000),
		"the stores drawn down by the package exactly")
	assert_equal(_done, PackedInt32Array([UPGRADE]), "finished once")
	_run(2.0)
	assert_equal(crew.builders_on(UPGRADE), 0, "everyone let go")


func test_a_place_waits_only_while_there_is_something_to_do() -> void:
	"""No stores: nothing waits; stone in the stores: a place waits; a place taken does not; out of range never."""
	_new_cast()
	var stores := _stores(0, 0)
	var projects := _unlocked(stores)
	var crew := _crew(projects)
	assert_false(crew.waiting(0), "nothing planned")
	projects.plan_upgrade()
	projects.cloth_milli = 0
	assert_false(crew.waiting(0), "the stores hold none of it")
	assert_false(crew.give(0, 0), "so it cannot be given")
	stores.stone_milli_u = 5000
	assert_true(crew.waiting(0) and crew.waiting(3), "stone to fetch")
	assert_true(crew.give(0, 0), "given")
	assert_false(crew.waiting(0), "taken")
	assert_equal(crew.worker[0], 0, "by resident 0")
	assert_equal(crew.eligibility(0), CrewScript.OTHER_PLACE, "who has a place already")
	assert_equal(crew.eligibility(-1), CrewScript.NOT_YOURS, "nobody")
	assert_false(crew.waiting(-1) or crew.waiting(Rules.ROWS), "no such places")
	assert_true(crew.doing_text(0).begins_with("Going to the stockpile for stone"), crew.doing_text(0))


func test_a_carrier_called_away_puts_its_load_back_and_comes_back_to_it() -> void:
	"""Ordered away with stone in its arms: the load goes back into the stores whole, the place is free, and the
	resident keeps the project to come back to -- which takes it up again."""
	_new_cast()
	var stores := _stores(0, 20)
	var projects := _unlocked(stores)
	var crew := _crew(projects)
	projects.plan_upgrade()
	crew.give(0, 0)
	_run(120.0, func() -> bool: return crew.carrying(0))
	assert_true(crew.carrying(0), "carrying")
	assert_true(crew.doing_text(0).begins_with("Carrying"), crew.doing_text(0))
	var held: int = stores.stone_milli_u
	var carried: int = crew.load_milli[0]
	_brain(0).order_move(Vector2(-10.0, 10.0))
	assert_equal(stores.stone_milli_u, held + carried, "the load back in the stores")
	assert_equal(crew.worker[0], CrewScript.NOBODY, "the place free")
	assert_equal(projects.transit[projects.cell(UPGRADE, STONE)], 0, "nothing in arms")
	assert_true(_brain(0).take_up_unfinished(), "it comes back to the hall")
	assert_true(crew.worker.has(0), "on a place again")


func test_a_carrier_that_finds_the_stores_empty_carries_nothing() -> void:
	"""The stone gone between setting off and lifting: nothing is lifted, nothing carried, and the place ends."""
	_new_cast()
	var stores := _stores(0, 3)
	var projects := _unlocked(stores)
	projects.cloth_milli = 0
	var crew := _crew(projects)
	projects.plan_upgrade()
	crew.give(0, 0)
	stores.stone_milli_u = 0
	var carried := [false]
	_run(120.0, func() -> bool:
		carried[0] = carried[0] or crew.step[0] == CrewScript.STEP_CARRY
		return crew.worker[0] == CrewScript.NOBODY)
	assert_false(carried[0], "never set off carrying nothing")
	assert_equal(crew.worker[0], CrewScript.NOBODY, "the place ended")
	assert_equal(projects.reserved[projects.cell(UPGRADE, STONE)], 0, "its reservation given up")


func _sent_back_with_a_record(crew: CrewScript, who: int) -> void:
	"""Resident `who` takes the upgrade's first place, is called away (keeping a resume record), and is put back on the
	upgrade by selection -- so it holds both a place and an older record for the same project."""
	crew.give(0, who)
	_brain(who).order_move(Vector2(-10.0, 10.0))
	assert_equal(crew.give_selected(UPGRADE, PackedInt32Array([who])), 1, "sent back by selection")


func test_letting_a_builder_go_never_hands_it_the_project_again() -> void:
	"""A builder with an older resume record for the project, paused or reassigned: it is let go, not handed another
	place on the same project from that record (review H1)."""
	_new_cast()
	var projects := _unlocked(_stores(0, 40))
	var crew := _crew(projects)
	projects.plan_upgrade()
	_sent_back_with_a_record(crew, 0)
	var row: int = crew.worker.find(0)
	assert_equal(crew.pause(row, true), "", "paused")
	assert_equal(crew.builders_on(UPGRADE), 0, "nobody on the upgrade")
	_sent_back_with_a_record(crew, 1)
	row = crew.worker.find(1)
	assert_equal(crew.reassign(row, 2), "", "reassigned")
	assert_equal(crew.worker[row], 2, "the place is 2's")
	assert_false(crew.worker.has(1), "1 was let go, not given another place")


func test_a_cancelled_project_is_not_taken_back_after_it_is_planned_again() -> void:
	"""Cancel and plan again: an old resume record names the old planning, so it is refused; a task of the old planning
	stops at once."""
	_new_cast()
	var services := ServicesScript.new()
	services.stores.stone_milli_u = 40000
	var hall: HallScript = _hall(services)
	hall.projects.unlocked = true
	hall.plan_upgrade()
	hall.crew.give(0, 0)
	_brain(0).order_move(Vector2(-10.0, 10.0))
	hall.crew.give(0, 0)
	hall.cancel_upgrade()
	assert_equal(hall.crew.builders_on(UPGRADE), 0, "everyone let go by the cancel")
	hall.plan_upgrade()
	assert_false(_brain(0).take_up_unfinished(), "the old planning's record is refused")
	assert_false(hall.crew.worker.has(0), "no place from it")
	hall.free()


func test_the_players_pause_and_reassign() -> void:
	"""Pause lets the builder go with nothing to come back to; resume makes the place wait; reassign hands it over."""
	_new_cast()
	var projects := _unlocked(_stores(0, 20))
	var crew := _crew(projects)
	projects.plan_upgrade()
	crew.give(1, 2)
	assert_equal(crew.pause(1, true), "", "paused")
	assert_equal(crew.worker[1], CrewScript.NOBODY, "let go")
	assert_true(crew.is_paused(1) and not crew.waiting(1), "paused, not waiting")
	assert_false(_brain(2).take_up_unfinished(), "nothing to come back to")
	assert_equal(crew.pause(1, true), WorkIds.PAUSED_ALREADY, "already")
	assert_equal(crew.pause(1, false), "", "resumed")
	assert_true(crew.waiting(1), "waits again")
	assert_equal(crew.reassign(1, 4), "", "given to resident 4")
	assert_equal(crew.worker[1], 4, "who has it")
	assert_equal(crew.reassign(1, 5), "", "and on to 5")
	assert_equal(crew.worker[1], 5, "5 has it, 4 let go")
	assert_equal(crew.reassign(1, 5), "", "the same: nothing to do")
	assert_equal(crew.reassign(1, -1), CrewScript.NOT_YOURS, "nobody")
	assert_equal(crew.pause(5, true), WorkIds.NOT_FOUND, "a banner not planned")
	assert_equal(crew.reassign(5, 1), WorkIds.NOT_FOUND, "nor reassigned")


func test_releasing_a_project_returns_every_load() -> void:
	"""Cancelling: every builder let go, loads back whole, then REQ-SET-126 on what was delivered."""
	_new_cast()
	var stores := _stores(10, 20)
	var projects := _unlocked(stores)
	var crew := _crew(projects)
	projects.plan_upgrade()
	var before: PackedInt64Array = _totals(projects)
	crew.give_selected(UPGRADE, PackedInt32Array([0, 1]))
	_run(60.0)
	crew.release_project(UPGRADE)
	assert_equal(crew.builders_on(UPGRADE), 0, "everyone let go")
	for mat: int in Rules.MAT_COUNT:
		assert_equal(projects.transit[projects.cell(UPGRADE, mat)] + projects.reserved[projects.cell(UPGRADE, mat)], 0,
			"nothing in arms or reserved")
	projects.cancel(UPGRADE)
	assert_equal(_totals(projects), before, "no work begun: everything back")


func test_a_builder_in_the_water_or_held_is_not_eligible() -> void:
	"""GDD §5.3's fit: on land, free of the rescue."""
	_new_cast()
	var crew := _crew(_unlocked(_stores(0, 0)))
	_brain(3).in_water = true
	assert_equal(crew.eligibility(3), WorkIds.IN_WATER, "in the water")
	_brain(3).water_hold = true
	assert_equal(crew.eligibility(3), WorkIds.HELD, "held")


# --- the board's adapter ------------------------------------------------------------------------------------------

func test_the_work_board_lists_the_hall_and_hands_it_out() -> void:
	"""A project's first place always shows; a place waits, is claimed, is filled with its step; Cancel sends to the
	panel."""
	_new_cast()
	var projects := _unlocked(_stores(0, 20))
	var crew := _crew(projects)
	var source := HallWork.new(crew, projects, Vector2(0.0, -13.0))
	assert_equal(source.id, WorkIds.SOURCE_HALL, "its source")
	assert_equal(source.capacity(), Rules.ROWS, "eight places")
	assert_false(source.live(0), "nothing planned")
	projects.plan_upgrade()
	assert_true(source.live(0) and source.live(3), "four places, all waiting")
	assert_true(source.waiting(2), "one waits")
	assert_equal(source.activity(0), WorkIds.ACT_BUILD, "building")
	assert_equal(source.point(1), Vector2(0.0, -13.0), "at the hall")
	assert_true(source.claim(2, 5), "claimed")
	assert_equal(source.worker(2), 5, "by 5")
	var task := TaskScript.new()
	source.fill(task, 2)
	assert_equal(task.action, "Raise the great hall", "its action")
	assert_equal(task.target, "the hall", "its target")
	assert_equal(task.state, WorkIds.STATE_TRAVELLING, "on its way to the stockpile")
	assert_equal(task.remaining_usec, Rules.UPGRADE_WU * Rules.USEC_PER_WU, "all the work left")
	assert_equal(source.cancel(2), HallWork.CANCEL_IN_PANEL, "cancel in the panel")
	assert_equal(task.cancel_refusal, HallWork.CANCEL_IN_PANEL, "and the Work screen's button says so")
	assert_equal(source.eligibility(2, 5), CrewScript.OTHER_PLACE, "5 is on a place")
	assert_equal(source.key(2), crew.key(2), "the crew's key")
	assert_equal(source.worker(-1), -1, "no row")


func test_a_place_with_nothing_to_do_shows_why_on_the_board() -> void:
	"""The stores out of stone: the first place is listed BLOCKED, the others not at all."""
	_new_cast()
	var projects := _unlocked(_stores(0, 0))
	projects.cloth_milli = 0
	var crew := _crew(projects)
	var source := HallWork.new(crew, projects, Vector2.ZERO)
	projects.plan_upgrade()
	assert_true(source.live(0), "the first place shows")
	assert_false(source.live(1), "the others do not")
	var task := TaskScript.new()
	source.fill(task, 0)
	assert_equal(task.state, WorkIds.STATE_BLOCKED, "blocked")
	assert_true(task.reason.contains("the stores have none to spare"), task.reason)
	var banner: int = projects.plan_banner()
	source.fill(task, Rules.first_row(banner))
	assert_equal(task.target, "banner 1", "a banner's target")
	assert_equal(task.action, "Hang a banner", "its action")


# --- the panel's words and the view ---------------------------------------------------------------------------------

func test_the_panel_says_what_the_hall_gives_and_where_the_upgrade_stands() -> void:
	"""Seats and the feast's 36, floor sleep and who, comfort, fuel; locked, ready, carrying in, building, raised."""
	var projects := ProjectsScript.new(_stores(20, 40))
	var gives: String = PanelScript.gives_text(projects, "Wenna Tallowby")
	assert_true(gives.contains("12 seats") and gives.contains("up to 36"), gives)
	assert_true(gives.contains("Without a bed now: Wenna Tallowby."), gives)
	assert_true(gives.contains("target is 7500") and gives.contains("×1.00"), gives)
	assert_false(PanelScript.gives_text(projects, "").contains("Without a bed"), "nobody bedless")
	assert_false(gives.contains("its hearth"), "no hearth bound: the line names none")
	assert_true(PanelScript.gives_text(projects, "", "heated, 18.0 °C").contains(
		"Heat: its hearth is heated, 18.0 °C; a hearth here burns fuel ×1.00"), "the winter's words for its hearth")
	assert_true(PanelScript.upgrade_text(projects, null).begins_with("Opens once the first harvest"), "locked")
	projects.unlocked = true
	assert_true(PanelScript.upgrade_text(projects, null).begins_with("Ready to plan"), "ready")
	projects.plan_upgrade()
	projects.deliver(UPGRADE, STONE, projects.lift(UPGRADE, STONE, projects.reserve(UPGRADE, STONE, 4800)))
	assert_true(PanelScript.upgrade_text(projects, null).contains("stone 4.8 / 40.0 U"), PanelScript.upgrade_text(
		projects, null))
	assert_equal(PanelScript.cancel_terms(projects, UPGRADE), PanelScript.CANCEL_BEFORE, "before work")
	_deliver_all(projects, UPGRADE)
	projects.add_work(UPGRADE, 340 * Rules.USEC_PER_WU, 0)
	assert_true(PanelScript.upgrade_text(projects, null).begins_with("Building: 340 of 1200 WU"), "building")
	assert_equal(PanelScript.cancel_terms(projects, UPGRADE), PanelScript.CANCEL_AFTER, "after work")
	projects.add_work(UPGRADE, 1200 * Rules.USEC_PER_WU, 0)
	assert_true(PanelScript.upgrade_text(projects, null).contains("there is no stage 3"), "raised")
	assert_true(PanelScript.gives_text(projects, "").contains("×0.75"), "fuel at tier 2")
	assert_equal(PanelScript.permille_text(1000) + PanelScript.permille_text(750) + PanelScript.permille_text(5),
		"1.000.750.00", "multipliers")


func test_the_panels_buttons_follow_the_projects() -> void:
	"""Plan dimmed with the refusal while locked; Cancel only while under way; the actions answer on the panel."""
	var stores := _stores(5, 40)
	var projects := ProjectsScript.new(stores)
	var panel := PanelScript.new()
	panel.configure(projects, CrewScript.new(), stores, TapestryScript.new(null))
	panel.set_actions({&"plan_upgrade": func() -> String: return projects.plan_upgrade()})
	panel.open()
	assert_true(panel.button(&"plan_upgrade").disabled, "locked")
	assert_true(panel.button(&"plan_upgrade").tooltip_text.begins_with("The upgrade opens"), "says why")
	assert_true(panel.button(&"cancel_upgrade").disabled, "nothing to cancel")
	assert_equal(panel.title_text(), "Community hall", "stage 1")
	projects.unlocked = true
	projects.revision += 1
	panel.refresh()
	assert_false(panel.button(&"plan_upgrade").disabled, "unlocked")
	assert_equal(panel.press(&"plan_upgrade"), "", "planned (its answer is empty)")
	assert_false(panel.button(&"cancel_upgrade").disabled, "can be cancelled")
	assert_equal(panel.button(&"cancel_upgrade").tooltip_text, PanelScript.CANCEL_BEFORE, "with its terms")
	assert_equal(panel.press(&"nothing"), "", "an unknown action does nothing")
	assert_true(panel.is_open(), "open")
	panel.close_window()
	assert_false(panel.is_open(), "closed")
	panel.free()


func test_the_open_panel_follows_the_work_and_its_cancel_terms() -> void:
	"""The panel redraws as the building goes on: the WU done, and Cancel's terms turning to 80% once work begins (review
	H2)."""
	var stores := _stores(20, 40)
	var projects := _unlocked(stores)
	var panel := PanelScript.new()
	panel.configure(projects, CrewScript.new(), stores, TapestryScript.new(null))
	projects.plan_upgrade()
	_deliver_all(projects, UPGRADE)
	panel.open()
	assert_equal(panel.button(&"cancel_upgrade").tooltip_text, PanelScript.CANCEL_BEFORE, "before work")
	projects.add_work(UPGRADE, 75000, 0)
	assert_true(panel.refresh(), "work begun: redrawn")
	assert_equal(panel.button(&"cancel_upgrade").tooltip_text, PanelScript.CANCEL_AFTER, "the 80% terms")
	projects.add_work(UPGRADE, 37500, 0)
	assert_false(panel.refresh(), "no whole WU more: not redrawn")
	projects.add_work(UPGRADE, Rules.USEC_PER_WU, 0)
	assert_true(panel.refresh(), "a WU more: redrawn")
	panel.free()


func test_the_banner_and_stock_lines() -> void:
	"""Banners hung and their comfort; the stores' wood, stone and the village's cloth."""
	var stores := _stores(7, 3)
	var projects := _unlocked(stores)
	assert_equal(PanelScript.banner_text(projects, null), "0 of 4 hung (comfort +0)", "none")
	var p: int = projects.plan_banner()
	assert_true(PanelScript.banner_text(projects, null).contains("banner 1: materials being carried in, 0%"), "planned")
	_deliver_all(projects, p)
	projects.add_work(p, Rules.BANNER_WU * Rules.USEC_PER_WU, 0)
	assert_true(PanelScript.banner_text(projects, null).begins_with("1 of 4 hung (comfort +250)"), "hung")
	assert_equal(PanelScript.stock_text(projects, stores),
		"Stores by the stockpile: wood 6.0 U · stone 3.0 U · cloth 24.0 U", "the stores")


func test_the_view_shows_each_stage() -> void:
	"""The site pile while carried in, the work rail while built, the great hall's additions at tier 2, one banner a
	banner hung; redrawn only when the projects change."""
	var projects := _unlocked(_stores(21, 40))
	var view := ViewScript.new()
	view.build(null, null)
	assert_true(view.sync(projects), "drawn")
	assert_false(view.sync(projects), "not again unchanged")
	assert_false(view.pile_shown(STONE) or view.scaffold_shown() or view.great_shown(), "a plain hall")
	projects.plan_upgrade()
	projects.deliver(UPGRADE, STONE, projects.lift(UPGRADE, STONE, projects.reserve(UPGRADE, STONE, 4800)))
	view.sync(projects)
	assert_true(view.pile_shown(STONE) and not view.pile_shown(WOOD), "the stone pile, no wood yet")
	_deliver_all(projects, UPGRADE)
	view.sync(projects)
	assert_true(view.scaffold_shown(), "the work rail while building")
	projects.add_work(UPGRADE, Rules.UPGRADE_WU * Rules.USEC_PER_WU, 0)
	var p: int = projects.plan_banner()
	_deliver_all(projects, p)
	projects.add_work(p, Rules.BANNER_WU * Rules.USEC_PER_WU, 0)
	view.sync(projects)
	assert_true(view.great_shown() and not view.scaffold_shown() and not view.pile_shown(STONE), "the great hall")
	assert_equal(view.shown_banners(), 1, "one banner")
	assert_true(view.bounds().has_point(Vector3(0.0, 3.0, -13.0)), "the hall's box holds its middle")
	assert_equal(view.work_spots().size(), Rules.ROWS, "a spot per place")
	view.free()


func test_the_tapestry_panel_draws_every_entry() -> void:
	"""A row per entry, oldest first; new entries picked up on refresh."""
	var tapestry := TapestryScript.new(null)
	var panel := TapestryPanelScript.new()
	panel.configure(tapestry, Callable())
	panel.open()
	assert_equal(panel.shown_entries(), 0, "nothing woven")
	tapestry.add_entry(TapestryScript.KIND_STAGE, "Stage 1")
	tapestry.add_entry(TapestryScript.KIND_HARVEST, "First harvest", "Bed 3")
	assert_true(panel.refresh(), "redrawn")
	assert_false(panel.refresh(), "not again")
	assert_equal(panel.shown_entries(), 2, "two")
	assert_equal(panel.entry_title(1), "First harvest", "in order")
	panel.back_to_hall()
	assert_false(panel.is_open(), "closed going back")
	panel.free()


func test_with_no_art_staged_the_tapestry_keeps_its_drawn_cloth() -> void:
	"""CI's case (an empty manifest): the oat ground, no emblems, every kind's knot a diamond."""
	var panel := TapestryPanelScript.new()
	panel.configure(TapestryScript.new(null), Callable())
	panel.set_art(UiArt.empty())
	assert_false(panel.is_woven(), "not woven")
	assert_true(panel.find_child("Cloth", true, false).get_theme_stylebox(&"panel") is StyleBoxFlat, "the oat ground")
	for kind: int in TapestryScript.KIND_COUNT:
		assert_null(panel.emblem_of(kind), "kind %d: a diamond" % kind)
	panel.set_art(null)
	assert_false(panel.is_woven(), "no props: not woven")
	panel.free()


func test_the_staged_ground_is_the_cloth_and_each_kind_wears_its_emblem() -> void:
	"""Staged: the half ground as a nine-patch on the manifest's margins, the rows inside its border; an emblem per kind
	in tapestry.gd's order (the hall's for KIND_STAGE), a kind not staged keeping its diamond; entries still drawn."""
	var tapestry := TapestryScript.new(null)
	var panel := TapestryPanelScript.new()
	panel.configure(tapestry, Callable())
	panel.set_art(UiArt.staged([]))
	assert_true(panel.is_woven(), "woven")
	var box := panel.find_child("Cloth", true, false).get_theme_stylebox(&"panel") as StyleBoxTexture
	assert_not_null(box, "a textured ground")
	assert_equal(box.texture.get_size(), Vector2(448.0, 600.0), "the half ground")
	assert_equal([box.texture_margin_left, box.texture_margin_top, box.texture_margin_right, box.texture_margin_bottom],
		[90.0, 113.0, 89.0, 116.0], "the manifest's margins")
	assert_true(box.content_margin_left > box.texture_margin_left, "rows inside the left border")
	assert_true(box.content_margin_top >= box.texture_margin_top, "inside the top border")
	assert_true(box.content_margin_bottom >= box.texture_margin_bottom, "inside the bottom border")
	assert_true(box.content_margin_right >= box.texture_margin_right, "inside the right border")
	assert_false(box.draw_center, "the field is drawn stretched, not tiled by the box")
	assert_equal(box.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT, "the border tiled down")
	assert_equal(panel._thread_x(), 90.0 + TapestryPanelScript.ART_THREAD_X, "the thread inside the left border")
	assert_true(panel._thread_x() + TapestryPanelScript.EMBLEM_PX * 0.5 <= box.content_margin_left, "an emblem clears the rows")
	assert_equal(TapestryPanelScript.EMBLEM_KEYS.size(), TapestryScript.KIND_COUNT, "a key per kind")
	assert_equal(TapestryPanelScript.EMBLEM_KEYS[TapestryScript.KIND_STAGE], "hall", "the hall's stage")
	for kind: int in TapestryScript.KIND_COUNT - 1:
		assert_equal(panel.emblem_of(kind).get_width(), TapestryPanelScript.EMBLEM_PX, "kind %d: its 24 px emblem" % kind)
	assert_null(panel.emblem_of(TapestryScript.KIND_EVENT), "not staged: a diamond")
	assert_null(panel.emblem_of(-1), "no kind -1")
	panel.open()
	tapestry.add_entry(TapestryScript.KIND_HARVEST, "First harvest", "Bed 3")
	assert_true(panel.refresh(), "redrawn")
	assert_equal(panel.entry_title(0), "First harvest", "drawn on the woven cloth")
	panel.free()


func test_the_field_is_the_area_inside_the_border_on_the_picture_and_the_cloth() -> void:
	"""field_rects: the source is the picture inside its border, the destination the cloth inside the same border."""
	var border := PackedFloat32Array([90.0, 113.0, 89.0, 116.0])
	var rects: Array[Rect2] = TapestryPanelScript.field_rects(Vector2(448.0, 600.0), border, Vector2(520.0, 900.0))
	assert_equal(rects[0], Rect2(90.0, 113.0, 269.0, 371.0), "the picture's field")
	assert_equal(rects[1], Rect2(90.0, 113.0, 341.0, 671.0), "the cloth's field")
	var plain: TapestryPanelScript = TapestryPanelScript.new()
	plain.configure(TapestryScript.new(null), Callable())
	assert_equal(plain._thread_x(), TapestryPanelScript.THREAD_X, "unwoven: the drawn thread's place")
	plain.free()


# --- the hall node ------------------------------------------------------------------------------------------------

func _hall(services: ServicesScript) -> HallScript:
	"""A hall over the cast and `services`, out of the tree (no world, no camera)."""
	var hall := HallScript.new()
	hall.configure(_cast, services, null, null)
	return hall


func test_the_hall_weaves_its_history_and_opens_with_the_first_harvest() -> void:
	"""Stage 1 at the start; the first harvest woven once and the upgrade unlocked; the first winter at Y1 Winter 1."""
	_new_cast()
	var services := ServicesScript.new()
	var hall: HallScript = _hall(services)
	var farm := FakeFarm.new()
	hall.bind_farm(farm)
	assert_equal(hall.tapestry.count(), 1, "stage 1 woven")
	assert_true(hall.tapestry.has_key(HallScript.KEY_STAGE_1), "keyed")
	hall.watch()
	assert_false(hall.projects.unlocked, "locked before the first harvest")
	farm.harvests = 1
	farm.harvested_by.append(2)
	farm.harvested_bed.append(4)
	hall.watch()
	hall.watch()
	assert_true(hall.projects.unlocked, "unlocked")
	assert_equal(hall.tapestry.count(), 2, "the first harvest, once")
	assert_true(hall.tapestry.text_of(1).contains("bed 5"), hall.tapestry.text_of(1))
	services.calendar.tick = HallScript.FIRST_WINTER_TICK - 1
	hall.watch()
	assert_equal(hall.tapestry.count(), 2, "not yet winter")
	services.calendar.tick = HallScript.FIRST_WINTER_TICK
	hall.watch()
	assert_equal(hall.tapestry.date_of(2), "Y1 Winter 1", "the first winter")
	assert_true(services.notices.count() >= 3, "each told")
	hall.free()


func test_the_hall_plans_cancels_and_answers_the_gathering_query() -> void:
	"""Plan refused locked; planned with the selected sent; cancelled with its refund told; feasts' seats."""
	_new_cast()
	var services := ServicesScript.new()
	services.stores.stone_milli_u = 40000
	var hall: HallScript = _hall(services)
	assert_true(hall.plan_upgrade().begins_with("Can't plan the upgrade: The upgrade opens"), "locked")
	hall.projects.unlocked = true
	hall.set_selection(func() -> PackedInt32Array: return PackedInt32Array([0, 1]))
	assert_equal(hall.plan_upgrade(), "Upgrade planned. 2 selected residents set off.", "planned and sent")
	assert_equal(hall.crew.builders_on(UPGRADE), 2, "two on it")
	assert_true(hall.cancel_upgrade().begins_with("The upgrade cancelled"), "cancelled")
	assert_equal(hall.cancel_upgrade(), "Nothing to cancel", "once")
	hall.set_selection(Callable())
	assert_equal(hall.plan_banner(), "Banner 1 planned. The work board sends builders.", "a banner")
	assert_true(hall.cancel_banner().begins_with("Banner 1 cancelled"), "and cancelled")
	assert_equal(hall.gathering_seats(), 12, "12 seats")
	assert_equal(hall.seats_needed(9), 3, "nine residents: 3 seats")
	assert_true(hall.can_gather(36) and not hall.can_gather(37), "36 at most")
	assert_equal(hall.gathering_capacity(), 36, "36")
	assert_equal(hall.tier(), 1, "tier 1")
	assert_equal(hall.comfort_target(), 7500, "comfort")
	assert_equal(hall.fuel_permille(), 1000, "fuel")
	assert_false(hall.hits(Vector2(10.0, 10.0)), "no camera: no clicks")
	assert_false(hall.is_open(), "closed")
	hall.open_tapestry()
	assert_true(hall.tapestry_panel.is_open() and not hall.panel.is_open(), "the tapestry stands in for the panel")
	hall.open()
	assert_true(hall.panel.is_open() and not hall.tapestry_panel.is_open(), "and back")
	hall.free()


func test_cancelling_puts_a_load_in_arms_back() -> void:
	"""Cancel with a builder carrying stone: the builders are let go first, so the load comes back whole."""
	_new_cast()
	var services := ServicesScript.new()
	services.stores.stone_milli_u = 40000
	services.stores.wood_milli_u = 0
	var hall: HallScript = _hall(services)
	hall.projects.unlocked = true
	hall.set_selection(func() -> PackedInt32Array: return PackedInt32Array([0]))
	hall.plan_upgrade()
	_run(120.0, func() -> bool: return hall.crew.carrying(0))
	assert_true(hall.crew.carrying(0), "carrying")
	hall.cancel_upgrade()
	assert_equal(hall.crew.builders_on(UPGRADE), 0, "the builder let go")
	assert_false(_brain(0).task is HallTaskScript, "and not handed the project again")
	assert_equal(services.stores.stone_milli_u, 40000, "every unit of stone back")
	assert_equal(hall.projects.cloth_milli, Rules.START_CLOTH_MILLI, "and the cloth")
	hall.free()


func test_the_hall_tells_a_finished_project() -> void:
	"""Stage 2 raised and a banner hung are woven (kinds stage and dressing) and told in the village news."""
	_new_cast()
	var services := ServicesScript.new()
	services.stores.stone_milli_u = 40000
	var hall: HallScript = _hall(services)
	hall.projects.unlocked = true
	hall.plan_upgrade()
	_deliver_all(hall.projects, UPGRADE)
	hall.projects.add_work(UPGRADE, Rules.UPGRADE_WU * Rules.USEC_PER_WU, 0)
	var p: int = hall.projects.plan_banner()
	_deliver_all(hall.projects, p)
	hall.projects.add_work(p, Rules.BANNER_WU * Rules.USEC_PER_WU, 0)
	assert_true(hall.tapestry.has_key(HallScript.KEY_STAGE_2), "stage 2 woven")
	assert_equal(hall.tapestry.kind_of(1), TapestryScript.KIND_STAGE, "a stage")
	assert_true(hall.tapestry.text_of(1).contains("8500"), hall.tapestry.text_of(1))
	assert_equal(hall.tapestry.kind_of(2), TapestryScript.KIND_DRESSING, "the banner")
	assert_true(hall.tapestry.text_of(2).contains("8750"), hall.tapestry.text_of(2))
	assert_equal(hall.panel.title_text(), "", "the panel is drawn only when opened")
	hall.open()
	assert_equal(hall.panel.title_text(), "Great hall", "stage 2's name")
	hall.free()


func test_watching_allocates_nothing_once_settled() -> void:
	"""The per-frame watch and an unchanged view keep no new objects."""
	_new_cast()
	var services := ServicesScript.new()
	var hall: HallScript = _hall(services)
	hall.bind_farm(FakeFarm.new())
	hall.watch()
	hall.view.sync(hall.projects)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 500:
		hall.watch()
		hall.view.sync(hall.projects)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object made")
	hall.free()
