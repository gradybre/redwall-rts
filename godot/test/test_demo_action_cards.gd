extends "res://test/framework/test_case.gd"
## The action cards and the assignment preview (decision 0332; review group H, findings F33 and F44). Every demo
## action's button shows a card -- result, cost as have / need, work in game time, who will do it, what that resident
## stops and whether it goes back to it, needs, and refused, the exact reason and its fix -- filled by the SAME
## decision the order then takes. So these tests hold each family to it: the card's cost is what the order spends, its
## refusal is the order's (code and words), its resident is the one the order sends, its work is the work's length.
##
## No scene tree and no staged assets: the placeholder cast in the real village layout (the farm and woods suites'
## rigs), hand-built tunnel spaces (the tunnel suites'), the real water layout (the water suite's).

const CardScript := preload("res://demo/ui/action_card.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
# the farm
const FarmSim := preload("res://demo/farm/farm_sim.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const FarmCrew := preload("res://demo/farm/farm_crew.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const FarmStorage := preload("res://demo/farm/farm_storage.gd")
const FarmPantry := preload("res://demo/farm/farm_pantry.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
# the woods
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const ForestCard := preload("res://demo/forestry/forest_card.gd")
const ForestPanel := preload("res://demo/forestry/forest_panel.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
# the tunnels and the fit-out
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const ActionsScript := preload("res://demo/tunnel/tunnel_actions.gd")
const TunnelJobs := preload("res://demo/tunnel/tunnel_jobs.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const FixtureCard := preload("res://demo/burrow/fixture_card.gd")
const RoomTextScript := preload("res://demo/burrow/room_text.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const ExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const TunnelPanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const BridgeCrew := preload("res://demo/waterplay/bridge_crew.gd")
const InstallTaskScript := preload("res://demo/burrow/install_task.gd")
# the water
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")

const DT: float = 1.0 / 60.0
const WOODS_DT: float = 0.1
const MAX_FRAMES: int = 6000
const BED_LOAM: int = 0
const BED_CARROTS: int = 2
const WOOD: int = 60
const WEST_OAK: int = 33
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
const SEED: int = 9091
const BRIDGE_NOBODY: int = -1

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _said: PackedStringArray = PackedStringArray()


func before_each() -> void:
	"""A fresh set of demo services per test."""
	_services = ServicesScript.new()
	_said.clear()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			if (node as Node).is_inside_tree():
				(node as Node).get_parent().remove_child(node)
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _say(text: String) -> void:
	"""A notice callable."""
	_said.append(text)


# --- the card ------------------------------------------------------------------------------------

func test_a_card_puts_the_refusal_and_its_fix_first() -> void:
	"""Verb; refused: the reason and the fix before anything else; then result, costs (have / need), work, who,
	interrupts, needs -- each on its own line."""
	var card := CardScript.new()
	card.reset("Build a plank footbridge")
	card.result = "Bridged"
	card.add_cost("Planks", 0, 4700)
	card.work_usec = CalendarScript.HOUR_USEC * 3
	card.who = "Queue for the bridgewright"
	card.interrupts = "Interrupts: x — goes back to it after"
	card.prerequisites.append("planks")
	card.refuse("MATERIAL", "it needs 4.7 U planks", "Woods ▸ Saw planks")
	var lines := card.text().split("\n")
	assert_equal(Array(lines), ["Build a plank footbridge", "Can't now: it needs 4.7 U planks", "To fix: Woods ▸ Saw planks",
		"Bridged", "Planks: have 0.0 U · need 4.7 U", "Work: about 3.0 game hours, plus the walk",
		"Who: Queue for the bridgewright", "Interrupts: x — goes back to it after", "Needs: planks"],
		"in order")
	assert_false(card.is_ok(), "refused")
	assert_equal(card.short_row(), 0, "the planks are short")
	card.reset("Again")
	assert_true(card.is_ok() and card.cost_names.is_empty() and card.work_usec == CardScript.NO_WORK and card.who == "",
		"reset empties it")
	assert_equal(card.text(), "Again", "just the verb")


func test_work_is_game_time_on_the_demo_calendar() -> void:
	"""A game hour is HOUR_USEC (25 demo seconds, decision 0421): under an hour the card says whole game minutes, rounded
	up, so a sliver of work is never nothing; from an hour, hours to the tenth, rounded up."""
	assert_equal(CardScript.hours_text(25000000), "about 1 game hour", "one")
	assert_equal(CardScript.hours_text(12000000), "about 29 game minutes", "a compost: 8 WU x 1.5 s, 28.8 minutes")
	assert_equal(CardScript.hours_text(1), "about 1 game minute", "a sliver")
	assert_equal(CardScript.hours_text(416666), "about 1 game minute", "under a minute")
	assert_equal(CardScript.hours_text(416667), "about 2 game minutes", "just past it")
	assert_equal(CardScript.hours_text(24999999), "about 1 game hour", "a microsecond short of the hour")
	assert_equal(CardScript.hours_text(25000001), "about 1.1 game hours", "just past it")
	assert_equal(CardScript.hours_text(60000000), "about 2.4 game hours", "an hour and more, to the tenth")
	assert_equal(CardScript.hours_text(0), "about 0 game minutes", "none")


func test_lines_break_at_word_boundaries() -> void:
	"""No line past LINE_CHARS plus its two-space indent; words kept whole; nothing lost."""
	var long := "Fell the oak: 12.0 U of wood lies ready to haul to the log stack beside the yard"
	var wrapped := CardScript.wrap_lines(PackedStringArray([long, "short"]))
	for line: String in wrapped.split("\n"):
		assert_true(line.length() <= CardScript.LINE_CHARS + 2, "short enough: " + line)
	assert_equal(wrapped.replace("\n  ", " "), long + "\nshort", "the same words")
	assert_true(wrapped.split("\n")[1].begins_with("  "), "continued lines indented")
	var unbroken := "x".repeat(CardScript.LINE_CHARS + 5)
	assert_equal(CardScript.wrap_lines(PackedStringArray([unbroken])).split("\n")[0].length(), CardScript.LINE_CHARS,
		"a word longer than a line is cut")


func test_the_command_grammar_is_one_across_panels() -> void:
	"""Who an order goes to, said the same way everywhere."""
	assert_equal(CardScript.assign_selected("Mouse keeper", 3, 3), "Assign selected: Mouse keeper (nearest of 3)", "nearest")
	assert_equal(CardScript.assign_selected("Mouse keeper", 2, 3), "Assign selected: Mouse keeper (nearest free of 3 selected)",
		"some busy")
	assert_equal(CardScript.assign_selected("Mouse keeper", 1, 1), "Assign selected: Mouse keeper", "alone")
	assert_equal(CardScript.assign_first("Mole", 3, "who can dig"), "Assign selected: Mole (first of 3 who can dig)", "first")
	assert_equal(CardScript.assign_first("Mole", 1, "who can dig"), "Assign selected: Mole", "first, alone")
	assert_equal(CardScript.assign_village("Mole", "why"), "Assign Mole (why)", "the village's pick")
	assert_equal(CardScript.lead_with("Squirrel", 3, 3, 2, "waiting to haul"), "Lead: Squirrel (nearest of 3) + 2 waiting to haul",
		"lead + haulers")
	assert_equal(CardScript.lead_with("Squirrel", 1, 1, 0, "waiting to haul"), "Lead: Squirrel", "lead alone")
	assert_equal(CardScript.queue_for("the field crew", PackedStringArray(["A", "B"]), 0),
		"Queue for the field crew: A or B, whoever is free first", "a crew")
	assert_equal(CardScript.queue_for("the field crew", PackedStringArray(["A"]), 2),
		"Queue for the field crew (no selected resident is free for it): A", "the selected all busy")
	assert_equal(CardScript.queue_for("the field crew", PackedStringArray(), 0),
		"Queue for the field crew: nobody is on it — select residents to do it", "no crew")
	assert_equal(CardScript.specialist("bridgewright", "Beaver", 0), "Queue for the bridgewright: Beaver (specialist)",
		"the specialist")
	assert_equal(CardScript.specialist("bridgewright", "", 1),
		"Queue for the bridgewright (no selected resident can take it): none in the village — select residents to do it",
		"none")
	assert_equal(CardScript.under_way("A"), "Already under way: A is on it", "under way")


# --- what an order interrupts ----------------------------------------------------------------------

## A task that can be called away and (unless `comeback` is off) come back to.
class Errand extends "res://demo/tunnel/tunnel_task.gd":
	var comeback: bool = true

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Never over on its own."""
		return true

	func unfinished() -> RefCounted:
		"""Something to come back to, unless `comeback` is off."""
		return UnfinishedScript.new(func(_b: RefCounted) -> bool: return true, "errand") if comeback else null

	func label() -> String:
		"""Its words."""
		return "on an errand"


func _lone_brain() -> BrainScript:
	"""A resident in an open space with one POI."""
	var space := CastSpaceScript.new()
	var points: Array[Dictionary] = [{"name": &"here", "position": Vector3.ZERO, "face": Vector3(0, 0, 1),
		"activities": [&"collect_object"] as Array[StringName], "capacity": 1}]
	space.setup(points, [] as Array[Vector3])
	var brain := BrainScript.new()
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	brain.configure(space, 0.8, 0.25, SEED, lengths)
	brain.start_at(Vector2(2.0, 2.0), 0.0, -1, -1)
	return brain


func test_the_brains_resuming_rule_says_what_an_order_interrupts() -> void:
	"""Wandering: free. A task with something to come back to resumes; one without does not; asleep, back to bed; a
	work spot is let go; an owner's rule answers for its own resident, NOT_MINE passing to the next."""
	var brain := _lone_brain()
	var no_rules: Array[Callable] = []
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.FREE, "wandering")
	var errand := Errand.new()
	brain.order_task(errand)
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.RESUMES, "a task kept")
	errand.comeback = false
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.DROPS_TASK, "nothing to come back to")
	brain.resting = true
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.BACK_TO_BED, "a sleeper")
	brain.resting = false
	brain.release()
	brain.order = BrainScript.ORDER_WORK
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.DROPS_SPOT, "a work spot")
	brain.order = BrainScript.ORDER_MOVE
	var rules: Array[Callable] = [func(_w: int) -> int: return InterruptScript.NOT_MINE,
		func(w: int) -> int: return InterruptScript.DROPS_BRIDGE if w == 0 else InterruptScript.NOT_MINE]
	assert_equal(InterruptScript.resume_of(brain, rules, 0), InterruptScript.DROPS_BRIDGE, "the owner's answer")
	assert_equal(InterruptScript.resume_of(brain, rules, 1), InterruptScript.FREE, "not its resident: free")


func test_a_dig_resumes_only_once_something_is_dug() -> void:
	"""A digger called away keeps its dig paused when a tick of it is dug; with none dug the route is dropped."""
	var brain := _lone_brain()
	var network: GraphScript = brain.space().tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([0, 0, 8192, 0]), 2, 0, ref), "a route")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	network.start_dig(chain[0], network.generation[chain[0]], 0)
	brain.order = BrainScript.ORDER_DIG
	brain.dig_tunnel = chain[0]
	var no_rules: Array[Callable] = []
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.DROPS_EMPTY_DIG, "nothing dug: dropped")
	network.advance(chain[0], network.generation[chain[0]], 200000)
	assert_equal(InterruptScript.resume_of(brain, no_rules, 0), InterruptScript.RESUMES, "dug a little: kept")
	assert_equal(InterruptScript.text("Digging tunnel — 3%", InterruptScript.RESUMES),
		"Interrupts: Digging tunnel — 3% — goes back to it after", "said")
	assert_equal(InterruptScript.text("Digging tunnel — 0%", InterruptScript.DROPS_EMPTY_DIG),
		"Interrupts: Digging tunnel — 0% — won't go back to it: nothing is dug yet, so the route is dropped", "warned")
	assert_equal(InterruptScript.text("wandering", InterruptScript.FREE), "Free now: wandering", "free")


func test_the_command_layer_words_the_interruption() -> void:
	"""interrupt_text: the party panel's own activity words, and the owners' rules."""
	var cast := DemoCastScript.new()
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var camera := Camera3D.new()
	var command := CommandScript.new()
	_keep(cast)
	_keep(camera)
	_keep(command)
	command.configure(cast, camera)
	command.add_task_text(func(w: int) -> String: return "Felling the oak" if w == 1 else "")
	command.add_resume_rule(func(w: int) -> int: return InterruptScript.RESUMES if w == 1 else InterruptScript.NOT_MINE)
	assert_equal(command.interrupt_text(1), "Interrupts: Felling the oak — goes back to it after", "a woods job")
	assert_equal(command.interrupt_text(0), "Free now: " + command.activity_text(0), "free")
	assert_equal(command.interrupt_text(-1), "", "nobody")
	assert_equal(command.interrupt_text(cast.actor_count()), "", "out of range")


# --- the farm --------------------------------------------------------------------------------------

func _cast() -> DemoCastScript:
	"""The placeholder cast in the real village layout."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	return cast


func _farm_crew(cast: DemoCastScript, sim: FarmSim) -> FarmCrew:
	"""A farm crew; placeholder 0 is its routine crew."""
	var crew := FarmCrew.new()
	crew.configure(cast, sim, FarmPantry.new(FarmStorage.new(DemoFarmScript.store_position(cast))), FarmTunnels.new(),
		DemoFarmScript.well_position(), _say)
	crew.set_crew(PackedInt32Array([0]))
	return crew


func _run_farm(cast: DemoCastScript, crew: FarmCrew, seconds: float, done: Callable) -> bool:
	"""Step the cast and the crew at 60 Hz until `done()` (or `seconds` of demo time)."""
	for frame: int in roundi(seconds / DT):
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
		if done.call():
			return true
	return false


func test_a_farm_card_costs_what_the_order_spends_and_works_as_long() -> void:
	"""Compost on the carrot bed: 2.0 U from the compost store, 8 WU (12 s: 29 game minutes) -- and the order takes exactly
	that, its work step running exactly that long."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var card := CardScript.new()
	crew.preview_into(card, FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array([2]))
	assert_true(card.is_ok(), card.text())
	assert_equal(Array(card.cost_names), [FarmCard.COMPOST_STORE], "from the store")
	assert_equal(card.cost_have[0], sim.compost_milli, "have: the store")
	assert_equal(card.cost_need[0], 2000, "need: a dose")
	assert_equal(card.work_usec, FarmJobs.work_usec_of(FarmJobs.WORK_COMPOST), "the plan's one work step")
	assert_true(card.text().contains("Work: about 29 game minutes, plus the walk"), card.text())
	assert_true(card.result.contains("fertility points"), "the panel's effect words")
	var before: int = sim.compost_milli
	crew.order(FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array([2]), FarmJobs.ORIGIN_PLAYER)
	var longest: Array = [0]
	var done := func() -> bool:
		if crew.jobs.is_live(0) and crew.jobs.current_step(0) >= FarmJobs.STEP_WORK:
			longest[0] = maxi(int(longest[0]), int(crew.jobs.elapsed_usec[0]))
		return crew.jobs.live_count() == 0
	assert_true(_run_farm(cast, crew, 90.0, done), "composted")
	assert_equal(before - sim.compost_milli, int(card.cost_need[0]), "spent what the card said")
	assert_true(int(longest[0]) < card.work_usec and int(longest[0]) + cast.clock.frame_usec >= card.work_usec,
		"worked as long as the card said: its last frame ends it (%d against %d)" % [longest[0], card.work_usec])


func test_a_short_compost_store_is_the_only_compost_cost_and_earth_never_stands_in() -> void:
	"""Decision 0401: compost comes only from the compost store. With it short the card shows that one row, short --
	no spoil heap row (test_demo_earth.gd has heaps full of earth beside it) -- and the refusal the order gives."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	sim.compost_milli = 1000
	var card := CardScript.new()
	crew.preview_into(card, FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array())
	assert_equal(Array(card.cost_names), [FarmCard.COMPOST_STORE], "the compost store only")
	assert_equal([int(card.cost_have[0]), int(card.cost_need[0])], [1000, 2000], "have / need")
	assert_equal(card.short_row(), 0, "the store is short")
	assert_equal(card.reason, "not enough compost: 2.0 U from the compost store", "no heap offered")
	assert_equal(card.code, "NOT_ENOUGH_COMPOST", "the order's code")
	assert_equal(crew.order(FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER),
		"Can't compost: " + card.reason, "the order's words")
	assert_equal(card.fix, FarmCard.fix_for(&"NOT_ENOUGH_COMPOST"), "and how to put it right")


func test_every_farm_refusal_is_the_orders() -> void:
	"""On an empty loam bed each verb that cannot be done says so -- the order's own code and words -- with a fix
	where the player has one."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var card := CardScript.new()
	var refused: int = 0
	for kind: int in [FarmJobs.KIND_WATER, FarmJobs.KIND_HARVEST, FarmJobs.KIND_CLEAR, FarmJobs.KIND_COVER,
			FarmJobs.KIND_RAISE, FarmJobs.KIND_BANK, FarmJobs.KIND_DRAIN, FarmJobs.KIND_SOW]:
		crew.preview_into(card, kind, BED_LOAM, PackedInt32Array([1]))
		var code: StringName = FarmJobs.refusal_for(sim, kind, BED_LOAM, crew.most_earth())
		assert_equal(card.code, String(code), "code of %s" % FarmJobs.KIND_NAMES[kind])
		if code == &"":
			continue
		refused += 1
		assert_false(card.is_ok(), "%s refused" % FarmJobs.KIND_NAMES[kind])
		assert_equal(crew.order(kind, BED_LOAM, PackedInt32Array([1]), FarmJobs.ORIGIN_PLAYER),
			"Can't %s: %s" % [FarmJobs.KIND_NAMES[kind].to_lower(), card.reason], "the order says it")
		assert_equal(card.reason, FarmCard.reason_words(code), "in the player's words")
		assert_true(card.text().replace("\n  ", " ").begins_with(card.verb + "\nCan't now: " + card.reason),
			"first, under the verb: " + card.text())
	assert_equal(refused, 8, "all eight refused on an empty bed with nothing chosen")
	crew.preview_into(card, FarmJobs.KIND_WATER, BED_LOAM, PackedInt32Array())
	assert_equal(card.fix, "Plant… a crop first", "water: plant first")
	crew.preview_into(card, FarmJobs.KIND_RAISE, BED_LOAM, PackedInt32Array())
	assert_true(card.fix.contains("Dig tunnel"), "spoil: dig a tunnel")


func test_the_farm_assignment_preview_is_who_the_order_sends() -> void:
	"""Selected: the nearest free of them; the order sends that one. Again: under way. Nobody selected: queued for
	the field crew -- which then takes it."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var card := CardScript.new()
	var members := PackedInt32Array([1, 2, 3])
	crew.preview_into(card, FarmJobs.KIND_WATER, BED_CARROTS, members)
	assert_true(card.worker in [1, 2, 3], "one of them")
	assert_equal(card.who, CardScript.assign_selected(crew._name_of(card.worker), 3, 3), "the nearest of three")
	crew.order(FarmJobs.KIND_WATER, BED_CARROTS, members, FarmJobs.ORIGIN_PLAYER)
	assert_true(crew.jobs.job_on_bed_into(FarmJobs.KIND_WATER, BED_CARROTS, _read), "queued")
	assert_equal(crew.jobs.worker[_read.value], card.worker, "the order sent the one the card named")
	var sent: int = card.worker
	crew.preview_into(card, FarmJobs.KIND_WATER, BED_CARROTS, members)
	assert_equal(card.who, CardScript.under_way(crew._name_of(sent)), "under way")
	assert_equal(card.worker, CardScript.NOBODY, "nobody new interrupted")
	crew.preview_into(card, FarmJobs.KIND_COMPOST, BED_CARROTS, members)
	assert_true(card.who.contains("(nearest free of 3 selected)") and card.worker != sent, "the busy one passed over")
	crew.preview_into(card, FarmJobs.KIND_COVER, BED_CARROTS, PackedInt32Array())
	assert_equal(card.who, "Queue for the field crew: " + crew._name_of(0), "the crew")
	crew.order(FarmJobs.KIND_COVER, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	crew.update(FarmCrew.PICKUP_USEC)
	assert_true(crew.jobs.job_on_bed_into(FarmJobs.KIND_COVER, BED_CARROTS, _read), "on the board")
	assert_equal(crew.jobs.worker[_read.value], crew.crew()[0], "and the crew took it")
	crew.set_crew(PackedInt32Array([0, 5]))
	crew.preview_into(card, FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array())
	assert_equal(card.who, CardScript.queue_for("the field crew", PackedStringArray([crew._name_of(0), crew._name_of(5)]), 0),
		"a new crew, named anew")


func test_the_bed_panel_shows_each_verbs_card_and_its_interruption() -> void:
	"""Every verb's tooltip is its card; disabled exactly when the card refuses; the card names what the resident
	stops (the interrupt callable); a picker row's card refuses with the picker's own reason."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var panel: BedPanelScript = _keep(BedPanelScript.new()) as BedPanelScript
	panel.configure(sim, crew)
	panel.set_preview(func() -> PackedInt32Array: return PackedInt32Array([2]),
		func(w: int) -> String: return "Interrupts: resident %d" % w)
	panel.show_bed(BED_CARROTS)
	var card := CardScript.new()
	for kind: int in BedPanelScript.VERB_KINDS:
		crew.preview_into(card, kind, BED_CARROTS, PackedInt32Array([2]))
		if card.worker >= 0:
			card.interrupts = "Interrupts: resident %d" % card.worker
		var button: Button = panel.verb_button(kind)
		assert_equal(button.tooltip_text, card.text(), "%s: its card" % FarmJobs.KIND_NAMES[kind])
		assert_equal(button.disabled, not card.is_ok(), "%s: enabled as the card says" % FarmJobs.KIND_NAMES[kind])
	assert_true(panel.verb_button(FarmJobs.KIND_WATER).tooltip_text.contains("Interrupts: resident 2"), "who it takes")
	assert_true(panel.verb_button(FarmJobs.KIND_SOW).disabled, "a crop stands: Plant… refused")
	assert_true(panel.verb_button(FarmJobs.KIND_SOW).tooltip_text.contains("Can't now: the bed is not empty"), "and why")
	panel.show_bed(BED_LOAM)
	assert_false(panel.verb_button(FarmJobs.KIND_SOW).disabled, "an empty bed: Plant…")
	assert_true(panel.verb_button(FarmJobs.KIND_SOW).tooltip_text.contains("Choose a crop"), "says what it does")
	sim.set_fallow(BED_LOAM, true)
	panel.refresh()
	assert_true(panel.verb_button(FarmJobs.KIND_SOW).tooltip_text.contains("Can't now: the bed is resting fallow"), "resting")
	assert_true(panel.verb_button(FarmJobs.KIND_SOW).tooltip_text.contains("To fix: Unrest the bed first"), "its fix")
	sim.set_fallow(BED_LOAM, false)
	panel.open_picker()
	var refused: int = 0
	for item: int in Catalog.ITEM_COUNT:
		var tip: String = panel.picker_button(item).tooltip_text
		var reason: String = FarmText.pick_reason(sim, BED_LOAM, item)
		assert_true(tip.begins_with("Sow bed 1"), "a sowing card")
		assert_equal(panel.picker_button(item).disabled, reason != "", "disabled when the picker refuses")
		assert_equal(tip.contains("Can't now: "), reason != "", "and the card refuses then")
		if reason != "":
			refused += 1
			assert_true(tip.replace("\n  ", " ").contains("Can't now: " + reason), "in the picker's words: " + reason)
	assert_true(refused > 0 and refused < Catalog.ITEM_COUNT, "some sowable, some not")


# --- the woods -------------------------------------------------------------------------------------

func _forestry() -> ForestryScript:
	"""The woods over the placeholder cast in the real layout (the woods suite's rig), no routine crew."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	var forestry: ForestryScript = _keep(ForestryScript.new()) as ForestryScript
	forestry.configure(world, cast, null, null, _services, IntMath.IntResult.new(true, WOOD, ""))
	forestry.crew.set_crew(PackedInt32Array())
	return forestry


func _run_woods(forestry: ForestryScript, done: Callable) -> bool:
	"""Step the cast and the woods until `done()` (bounded)."""
	var cast: DemoCastScript = forestry._cast
	for frame: int in MAX_FRAMES:
		if bool(done.call()):
			return true
		cast.advance(WOODS_DT)
		forestry.step(cast.clock.frame_usec)
	return bool(done.call())


func test_a_woods_card_costs_what_sawing_spends_and_works_as_long() -> void:
	"""Saw planks: wood 40.0 U have / 2.0 U need; the order takes exactly 2.0 U, and its saw step lasts the card's
	work at the sawyer's skill."""
	var forestry := _forestry()
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array([3]))
	assert_true(card.is_ok(), card.text())
	assert_equal(card.cost_have[0], _services.stores.wood_milli_u, "have: the stores")
	assert_equal(card.cost_need[0], ForestRules.SAW_BATCH_MILLI, "need: a batch")
	assert_equal(card.work_usec, forestry.crew.plan_usec(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 3), "the plan's work")
	var expected: int = card.work_usec
	var need: int = int(card.cost_need[0])
	var before: int = _services.stores.wood_milli_u
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	var total: Array = [0]
	var seen: Dictionary = {}
	var measure := func() -> bool:
		var jobs: ForestJobs = forestry.crew.jobs
		if jobs.is_live(0) and jobs.current_step(0) >= ForestJobs.STEP_WORK and jobs.issued[0] == 1 \
				and not seen.has(jobs.step[0]):
			seen[jobs.step[0]] = true
			total[0] = int(total[0]) + int(jobs.work_usec[0])
		return jobs.live_count() == 0
	assert_true(_run_woods(forestry, measure), "sawn")
	assert_equal(before - _services.stores.wood_milli_u, need, "took what the card said")
	assert_equal(int(total[0]), expected, "every work step as long as the card's sum")


func test_every_woods_refusal_is_the_orders() -> void:
	"""Sawing short of wood, planting with no compost, a haul on a standing tree nobody fells, gathering with no
	deadfall: each card refuses with the order's own words, and a fix."""
	var forestry := _forestry()
	_services.stores.wood_milli_u = 1999
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array([3]))
	assert_false(card.is_ok(), "short of wood")
	assert_equal(card.code, "NOT_ENOUGH_WOOD", "the code")
	var said: String = forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	assert_equal(said, "Can't saw planks: " + card.reason, "the order's words")
	assert_equal(card.fix, ForestCard.fix_for("NOT_ENOUGH_WOOD"), "and a fix")
	assert_equal(card.short_row(), 0, "the wood row is short")
	forestry.select_tree(WEST_OAK)
	card = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array([3]))
	assert_false(card.is_ok(), "nothing to haul from a standing tree")
	assert_equal(forestry.crew.order_haul(WEST_OAK, PackedInt32Array([3])), "Can't haul logs: " + card.reason, "said")
	card = forestry.action_card(ForestPanel.ACTION_PLANT, PackedInt32Array([3]))
	assert_false(card.is_ok(), "not a cleared spot")
	while forestry.deadfall.nearest_into(Vector2.ZERO, 1000.0, _read):
		forestry.deadfall.take_into(_read.value, forestry.deadfall.generation[_read.value], _read)
	card = forestry.action_card(ForestPanel.ACTION_GATHER, PackedInt32Array([3]))
	assert_false(card.is_ok(), "no deadfall")
	assert_equal(forestry._panel_verb(ForestPanel.ACTION_GATHER, PackedInt32Array([3])),
		"Can't gather deadfall: " + card.reason, "said")
	assert_equal(card.fix, ForestCard.fix_for("NO_DEADFALL_HERE"), "wait for deadfall")


func test_the_woods_assignment_preview_is_who_the_order_sends() -> void:
	"""Felling with three selected: the nearest leads, two wait to haul -- as the order does. Nobody selected: the
	forestry crew's queue, by name."""
	var forestry := _forestry()
	forestry.select_tree(WEST_OAK)
	var members := PackedInt32Array([1, 2, 3])
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_FELL, members)
	assert_true(card.is_ok(), card.text())
	assert_equal(card.who, CardScript.lead_with(forestry.crew.name_of(card.worker), 3, 3, 2, "waiting to haul"), card.who)
	assert_equal(card.work_usec, forestry.crew.step_usec(ForestJobs.WORK_FELL, WEST_OAK, card.worker), "the felling")
	assert_true(card.text().contains("then it is hauled in (2 trips)"), "then the hauling")
	var lead: int = card.worker
	forestry._panel_verb(ForestPanel.ACTION_FELL, members)
	var jobs: ForestJobs = forestry.crew.jobs
	assert_true(jobs.find_into(ForestJobs.KIND_FELL, WEST_OAK, _read), "felling")
	assert_equal(jobs.worker[_read.value], lead, "the lead the card named")
	assert_equal(jobs.on_target(ForestJobs.KIND_HAUL, WEST_OAK), 2, "two haulers, as the card said")
	card = forestry.action_card(ForestPanel.ACTION_FELL, members)
	assert_equal(card.who, CardScript.under_way(forestry.crew.name_of(lead)), "under way")
	card = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array())
	assert_true(card.who.ends_with("nobody is on it — select residents to do it"), "no crew: " + card.who)
	forestry.crew.set_crew(PackedInt32Array([4, 5]))
	card = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array())
	assert_equal(card.who, CardScript.queue_for("the forestry crew",
		PackedStringArray([forestry.crew.name_of(4), forestry.crew.name_of(5)]), 0), card.who)
	assert_equal(card.worker, CardScript.NOBODY, "nobody named")
	forestry.crew.set_crew(PackedInt32Array([5]))
	card = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array())
	assert_equal(card.who, CardScript.queue_for("the forestry crew", PackedStringArray([forestry.crew.name_of(5)]), 0),
		"the crew changed: named anew")
	assert_equal(forestry.crew.point_of(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET), Yard.log_stack_at(),
		"a sawing is at the log stack (its nearest is measured from there)")
	assert_equal(Array(card.prerequisites), ["2.0 U of wood in the stores"], "a saw batch's wood")


# --- the tunnels and the fit-out -------------------------------------------------------------------

func _tunnel_site() -> Array:
	"""A mole, two mice and a badger by an open 12 m tunnel (the tunnel suite's order site): [space, brains, works,
	actions]. Who digs: the mole and the mice."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var species := PackedStringArray(["Mole", "Mouse", "Mouse", "Badger"])
	var spots: Array[Vector2] = [Vector2(-3.0, 0.0), Vector2(-1.0, 1.0), Vector2(6.0, 6.0), Vector2(-2.0, -2.0)]
	var brains: Array[BrainScript] = []
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	for i in spots.size():
		var brain := BrainScript.new()
		brain.configure(space, 1.0, 0.25, SEED, lengths)
		brain.start_at(spots[i], 0.0, -1, -1)
		space.tunnels.set_fit(brain.index, true)
		var tall := 2611 if species[i] == "Badger" else (922 if species[i] == "Mole" else 1024)
		space.tunnels.set_body(brain.index, tall, 574 if species[i] == "Badger" else 225)
		brains.append(brain)
	var works: WorksScript = _keep(WorksScript.new()) as WorksScript
	works.setup(space, brains, species, BOUNDS_U, _say, _services)
	var flat := PackedInt32Array([0, 0, 12288, 0])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(flat, 2, 0, ref), "fixture tunnel stored")
	var chain := PackedInt32Array()
	space.tunnels.piece_segments_into(ref[2], chain)
	for slot in chain:
		space.tunnels.start_dig(slot, space.tunnels.generation[slot], 0)
		space.tunnels.advance(slot, space.tunnels.generation[slot], 1000000000)
	works.step(1)
	var actions := ActionsScript.new(works, space, PackedByteArray([1, 1, 1, 0]),
		PackedStringArray(["Mole digger", "Mouse keeper", "Mouse fieldworker", "Badger"]), BOUNDS_U)
	return [space, brains, works, actions]


func test_a_tunnel_card_costs_what_the_job_pays() -> void:
	"""Brace tunnel 1: its wood and stone, have / need, and its work in game hours; the order's start pays exactly
	that; once paid, a resumed card shows no cost."""
	var site := _tunnel_site()
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	var card := CardScript.new()
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array([2]))
	assert_true(card.is_ok(), card.text())
	var cost := PackedInt32Array([0, 0])
	works.jobs.cost_into(0, TunnelJobs.JOB_BRACE, cost)
	assert_equal(Array(card.cost_names), ["Wood", "Stone"], "wood and stone")
	assert_equal([int(card.cost_need[0]), int(card.cost_need[1])], [cost[0], cost[1]], "the job's price")
	assert_equal([int(card.cost_have[0]), int(card.cost_have[1])], [works.stores.wood_milli_u, works.stores.stone_milli_u],
		"the stores the HUD reads")
	@warning_ignore("integer_division") assert_equal(card.work_usec, works.jobs.ticks_for(0, TunnelJobs.JOB_BRACE) * 1000000 / TunnelRules.TICKS_PER_SECOND,
		"its ticks at the base rate")
	var wood: int = works.stores.wood_milli_u
	var stone: int = works.stores.stone_milli_u
	assert_true(actions.order(TunnelJobs.JOB_BRACE, PackedInt32Array([2])), "ordered")
	assert_true(works.jobs.start(0), "the worker starts: paid")
	assert_equal([wood - works.stores.wood_milli_u, stone - works.stores.stone_milli_u], [cost[0], cost[1]],
		"paid what the card said")
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array([2]))
	assert_true(card.cost_names.is_empty() and card.result.ends_with(ActionsScript.PAID_NOTE), "paid already")


func test_every_tunnel_refusal_is_the_orders() -> void:
	"""No tunnel, already done, closed, the stores short, nobody to do it: each card refuses with the very words the
	order logs, and the fix for it."""
	var site := _tunnel_site()
	var space: CastSpaceScript = site[0]
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	var card := CardScript.new()
	var check := func(job: int, members: PackedInt32Array, code: String, fix: String) -> void:
		actions.preview_into(card, job, members)
		assert_false(card.is_ok(), "refused: " + card.reason)
		assert_equal(card.code, code, "code for " + card.reason)
		assert_equal(card.fix, fix, "fix for " + card.reason)
		assert_false(actions.order(job, members), "the order refuses")
		assert_equal(works.log_lines[-1], ActionsScript.REFUSED % card.reason, "in the card's words")
	check.call(TunnelJobs.JOB_BRACE, PackedInt32Array(), "TUNNEL", ActionsScript.FIX_SELECT)
	actions.select_at(Vector2(1.0, 0.3))
	space.tunnels.set_braced(0)
	check.call(TunnelJobs.JOB_BRACE, PackedInt32Array(), "TUNNEL", "")
	space.tunnels.close(0, GraphScript.CLOSED_FLOODED, 0, 4096)
	check.call(TunnelJobs.JOB_LANTERNS, PackedInt32Array(), "TUNNEL", ActionsScript.FIX_CLOSED)
	space.tunnels.reopen(0)
	works.stores.wood_milli_u = 499
	check.call(TunnelJobs.JOB_LANTERNS, PackedInt32Array(), "STORES_SHORT", ActionsScript.FIX_STORES)
	assert_equal(card.short_row(), 0, "the wood row")
	for b: BrainScript in brains:
		b.order = BrainScript.ORDER_DIG
	check.call(TunnelJobs.JOB_WIDEN, PackedInt32Array(), "NO_WORKER", ActionsScript.FIX_DIGGER)


func test_the_tunnel_assignment_preview_is_who_the_order_sends() -> void:
	"""Brace: the first selected who fits; with nobody selected the nearest free mouse. Widen: the selected mole leads
	and the rest join its crew -- exactly as the order does."""
	var site := _tunnel_site()
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	var card := CardScript.new()
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array([3, 2]))
	assert_equal(card.worker, 2, "the badger does not fit: the mouse")
	assert_equal(card.who, CardScript.assign_first("Mouse fieldworker", 2, ActionsScript.FIRST_FITS), card.who)
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array())
	assert_equal(card.who, CardScript.assign_village("Mouse keeper", ActionsScript.NEAREST_FREE), card.who)
	assert_true(actions.order(TunnelJobs.JOB_BRACE, PackedInt32Array()), "ordered")
	assert_equal(works.jobs.worker[0], card.worker, "the one the card named")
	actions.select(1)
	actions.preview_into(card, TunnelJobs.JOB_WIDEN, PackedInt32Array([0, 2, 3]))
	assert_equal(card.worker, 0, "the mole")
	var crew: int = actions.crew_joining(1, PackedInt32Array([0, 2, 3]), 0)
	assert_equal(crew, 2, "two more")
	assert_true(card.who.ends_with("+ 2 on the crew"), card.who)
	assert_true(actions.order(TunnelJobs.JOB_WIDEN, PackedInt32Array([0, 2, 3])), "ordered")
	assert_equal(works.jobs.worker[1], 0, "the mole leads")
	assert_equal(works.crew.count_of(1), crew, "the crew the card counted")


func test_a_fitout_card_costs_what_the_order_pays_and_refuses_as_it_does() -> void:
	"""A bed in a dug home: 2 planks have / need; the order takes exactly that. Short: the order's own words, and the
	saw as its fix. Taking one out: refused while there is none."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var graph: GraphScript = space.tunnels
	var r: int = _dug_home(graph)
	var stores := StoresScript.new()
	stores.add_planks(3000)
	var card := CardScript.new()
	FixtureCard.add_into(card, graph, r, RoomsScript.FIX_BED, stores, PackedInt32Array(), null, PackedStringArray())
	assert_true(card.is_ok(), card.text())
	assert_equal(Array(card.cost_names), ["Planks"], "planks only")
	assert_equal(int(card.cost_need[0]), FixturesScript.COST_PLANKS_MILLI[RoomsScript.FIX_BED], "2 planks")
	assert_equal(card.work_usec, FixturesScript.install_usec(RoomsScript.FIX_BED), "its install work")
	assert_true(card.who.begins_with("Queue for the nearest free resident"), card.who)
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "ordered")
	assert_equal(stores.plank_milli_u, 1000, "paid what the card said")
	FixtureCard.add_into(card, graph, r, RoomsScript.FIX_BED, stores, PackedInt32Array(), null, PackedStringArray())
	assert_false(card.is_ok(), "short")
	assert_equal(card.code, "STORES_SHORT", "the code")
	var parts := PackedStringArray(["fit", RoomTextScript.FIT_ADD, str(RoomsScript.FIX_BED)])
	var code: int = graph.fit.order(graph, r, RoomsScript.FIX_BED, stores)
	assert_equal(RoomTextScript.answer(graph, r, parts, code, stores, Callable()), "Can't: " + card.reason, "the words")
	assert_true(card.fix.contains("Saw planks"), "the saw")
	FixtureCard.take_into(card, graph, r, RoomsScript.FIX_HEARTH, stores, Callable())
	assert_false(card.is_ok(), "no hearth to take out")
	assert_equal(card.code, "NONE_TO_TAKE", "the code")
	FixtureCard.suggest_into(card, graph, r, stores, PackedInt32Array(), null, PackedStringArray())
	assert_equal(card.code, "STORES_SHORT", "the layout's card refuses")
	assert_equal(graph.fit.suggest(graph, r, stores), FixturesScript.REFUSE_SHORT, "as the layout does")
	stores.add_planks(100000)
	stores.add_wood(100000)
	stores.add_stone(100000)
	FixtureCard.suggest_into(card, graph, r, stores, PackedInt32Array(), null, PackedStringArray())
	var missing: Vector3i = graph.fit.missing_cost(graph, r)
	var planks: int = stores.plank_milli_u
	assert_true(card.is_ok(), card.text())
	assert_equal(int(card.cost_need[0]), missing.x, "the layout's planks")
	assert_equal(graph.fit.suggest(graph, r, stores), FixturesScript.REFUSE_NONE, "planned")
	assert_equal(planks - stores.plank_milli_u, missing.x, "paid what the card said")


func _dug_home(graph: GraphScript) -> int:
	"""A burrow home laid and dug out (the fit-out suite's way)."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(0, 8192), 0, 0, ref), "a home laid")
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		if not graph.is_open(slot):
			graph.start_dig(slot, graph.generation[slot], 0)
			graph.advance(slot, graph.generation[slot], 1000000000)
	assert_true(graph.rooms.is_done(graph, ref[0]), "dug")
	return ref[0]


# --- the water ------------------------------------------------------------------------------------

func _rig(stand: StandScript = null) -> WaterplayScript:
	"""The placeholder cast on the real layout with the water gameplay wired over it (the water suite's rig)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links := WaterplayScript.make_links(_map_cache, circles)
	circles.append_array(links.band)
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), circles, links.area)
	cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	var play: WaterplayScript = _keep(WaterplayScript.new()) as WaterplayScript
	play.configure(cast, null, null, _services, _map_cache, links, null, stand)
	return play


func test_a_bridge_card_costs_what_the_build_pays() -> void:
	"""The neck's plank footbridge: refused short of planks with the build's own words and the saw as its fix; with
	planks, its planks have / need -- and the build takes exactly that."""
	var play := _rig()
	play.select_candidate(0)
	var card: CardScript = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_false(card.is_ok(), "no planks")
	assert_equal(card.code, "MATERIAL", "the material")
	var said: String = play.build(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_true(said.begins_with("Can't build a plank footbridge: " + card.reason + " -- "), "the build's words: " + said)
	assert_false(card.reason.contains(" -- "), "its fix on its own line, not twice")
	assert_equal(card.fix, WaterplayScript.build_fix(SwimRules.KIND_PLANK), "saw planks")
	assert_true(card.fix.ends_with("(2.0 U wood makes 2.0 U planks)"), "the saw's batch: " + card.fix)
	assert_true(card.text().contains("Planks: have 0.0 U · need 4."), card.text())
	_services.stores.add_planks(6000)
	card = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_true(card.is_ok(), card.text())
	var need: int = int(card.cost_need[0])
	assert_true(card.work_usec > 0, "its building work")
	play.build(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_equal(6000 - _services.stores.plank_milli_u, need, "took what the card said")
	play.select_candidate(1)
	_services.stores.wood_milli_u = 1000
	card = play.build_card(SwimRules.KIND_LOG, PackedInt32Array())
	assert_false(card.is_ok(), "no log")
	assert_true(play.build(SwimRules.KIND_LOG, PackedInt32Array()).begins_with("Can't build a log bridge: " + card.reason),
		"the build's words")


func test_the_bridge_assignment_preview_is_who_builds_it() -> void:
	"""Selected: the nearest to the material, as `start` picks. Nobody selected: queued for the bridgewright by name
	(the specialist), who then takes it up."""
	var play := _rig()
	_services.stores.add_planks(12000)
	play.select_candidate(0)
	play.crew.set_crew(PackedInt32Array([4]))
	var card: CardScript = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_equal(card.who, CardScript.specialist("bridgewright", play.name_of(4), 0), card.who)
	assert_equal(card.work_usec, play.crew.build_usec(SwimRules.KIND_PLANK, play.survey_site(SwimRules.KIND_PLANK).deck_u,
		play.survey_site(SwimRules.KIND_PLANK).piers, 4), "at the bridgewright's skill")
	play.build(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_equal(play.crew.builder[0], BRIDGE_NOBODY, "waiting")
	play.crew.update(1000000)
	assert_equal(play.crew.builder[0], 4, "the bridgewright took it up")
	play.select_candidate(1)
	var members := PackedInt32Array([1, 2])
	card = play.build_card(SwimRules.KIND_PLANK, members)
	assert_true(card.is_ok(), card.text())
	assert_true(card.worker in [1, 2], "one of the selected")
	play.build(SwimRules.KIND_PLANK, members)
	assert_true(play.crew.builder.has(card.worker), "the one the card named builds it")
	assert_equal(play.crew.resume_rule(card.worker), InterruptScript.DROPS_BRIDGE, "and called away, leaves it")
	assert_equal(play.crew.resume_rule(3), InterruptScript.NOT_MINE, "not a builder")



func test_the_dive_card_names_the_divers_the_order_sends() -> void:
	"""Nobody selected, or only a non-diver: refused with the order's own words. An otter selected with a mouse: the
	otter dives (named, with what it stops), the mouse is named as refused -- as `order_dive` answers."""
	var play := _rig()
	var spot: Vector2 = play.pond_dive_spot()
	var card: CardScript = play.dive_card(PackedInt32Array(), spot)
	assert_false(card.is_ok(), "nobody")
	assert_equal("Can't: " + card.reason, play.order_dive(PackedInt32Array(), spot), "the order's words")
	card = play.dive_card(PackedInt32Array([1]), spot)
	assert_false(card.is_ok(), "a non-diver")
	assert_equal("Can't: " + card.reason, play.order_dive(PackedInt32Array([1]), spot), "named, as the order says")
	assert_equal(card.fix, WaterplayScript.DIVE_FIX, "select an otter")
	play.state.swim_mm_s[0] = 1100
	play.state.dives[0] = 1
	play.state.height_u[0] = 1526
	card = play.dive_card(PackedInt32Array([1, 0]), spot)
	assert_true(card.is_ok(), card.text())
	assert_equal(card.worker, 0, "the otter")
	assert_true(card.who.begins_with("Assign selected: " + play.name_of(0) + " (not: "), card.who)
	var said: String = play.order_dive(PackedInt32Array([1, 0]), spot)
	assert_true(said.begins_with("1 diving"), said)
	assert_true(play.brain_of(0).task != null, "the otter went")
	play.brain_of(0).release()


func test_the_dig_tools_card_names_the_digger_confirm_sends() -> void:
	"""The Dig tool's card: the first selected who can dig (and the crew the rest make) -- `choose_digger`, whom
	`confirm` sends; nobody selected: the most skilled free digger; nobody able: says to select one."""
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, [] as Array[Dictionary], [Vector3(0.0, 1.0, 0.0)] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	var selection: Array = [PackedInt32Array([1, 2])]
	var tool: ControlScript = _keep(ControlScript.new()) as ControlScript
	tool.configure(cast, _keep(Camera3D.new()) as Camera3D, func() -> PackedInt32Array: return selection[0],
		func(_at: Vector3, _ok: bool) -> void: pass, _say)
	var card := CardScript.new()
	tool.tool_card_into(card, "Dig tunnel (B)", "the Dig tool")
	assert_equal(card.worker, tool.choose_digger(), "confirm's digger")
	assert_equal(card.who, CardScript.assign_first((cast.actor(1) as DemoActorScript).display_name, 2, "who can dig")
		+ " + 1 on the crew", card.who)
	assert_true(card.text().contains(ControlScript.TOOL_NEEDS.left(20)), "no stores; the readout")
	selection[0] = PackedInt32Array()
	tool.tool_card_into(card, "Dig tunnel (B)", "the Dig tool")
	assert_equal(card.worker, 0, "the mole")
	assert_equal(card.who, CardScript.assign_village((cast.actor(0) as DemoActorScript).display_name, ControlScript.TOOL_FREE),
		card.who)
	tool.ext.can_dig.fill(0)
	tool.tool_card_into(card, "Dig tunnel (B)", "the Dig tool")
	assert_equal(card.who, ControlScript.TOOL_NOBODY, "nobody can dig")
	assert_equal(card.worker, CardScript.NOBODY, "nobody named")


func test_a_card_button_wears_the_huds_tooltip() -> void:
	"""dress: the HUD skin's tooltip piece and ink at the card's size, once; a button with a theme of its own is left."""
	var button: Button = _keep(Button.new()) as Button
	CardScript.dress(button)
	var theme: Theme = button.theme
	assert_true(theme != null and theme.has_stylebox(&"panel", &"TooltipPanel"), "the tooltip's piece")
	assert_equal(theme.get_color(&"font_color", &"TooltipLabel"), CardScript.Palette.INK, "ink")
	assert_equal(theme.get_font_size(&"font_size", &"TooltipLabel"), CardScript.TIP_PX, "its size")
	CardScript.dress(button)
	assert_true(button.theme == theme and theme == CardScript.tooltip_theme(), "one theme, kept")
	var own: Button = _keep(Button.new()) as Button
	var mine := Theme.new()
	own.theme = mine
	CardScript.dress(own)
	assert_true(own.theme == mine, "its own theme left alone")


func test_a_full_farm_board_refuses_a_new_job_but_joins_a_queued_one() -> void:
	"""With all 24 rows taken, a new verb is refused with the board's words -- card and order alike -- while one
	already queued is still taken up."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var opened: int = 0
	for bed: int in Catalog.BED_COUNT:
		for kind: int in FarmJobs.KIND_COUNT:
			if kind != FarmJobs.KIND_WATER and opened < FarmJobs.MAX_JOBS:
				opened += 1 if crew.jobs.open_into(kind, bed, FarmJobs.ORIGIN_ROUTINE, _read) else 0
	assert_equal(crew.jobs.live_count(), FarmJobs.MAX_JOBS, "full")
	var card := CardScript.new()
	crew.preview_into(card, FarmJobs.KIND_WATER, BED_CARROTS, PackedInt32Array([1]))
	assert_equal(card.code, "JOB_BOARD_FULL", "the board's refusal")
	assert_equal(crew.order(FarmJobs.KIND_WATER, BED_CARROTS, PackedInt32Array([1]), FarmJobs.ORIGIN_PLAYER),
		"Can't water: " + card.reason, "the order's")
	assert_equal(card.fix, "Cancel jobs on a bed", "its fix")
	crew.preview_into(card, FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array([1]))
	assert_true(card.is_ok() and card.worker == 1, "a queued compost is joined, not refused")


func test_the_woods_panel_buttons_are_their_cards() -> void:
	"""After a refresh each verb's tooltip is its card and it is pressable exactly when the card allows it; Cancel
	says its scope -- every woods job -- and is disabled with none."""
	var forestry := _forestry()
	forestry.select_tree(WEST_OAK)
	forestry.refresh_panel()
	for action_name: StringName in ForestryScript.ACTION_KINDS:
		var button: Button = forestry.panel.button(action_name)
		var card: CardScript = forestry.action_card(action_name, PackedInt32Array())
		assert_equal(button.tooltip_text, card.text(), "%s: its card" % action_name)
		assert_equal(button.disabled, not card.is_ok(), "%s: enabled by it" % action_name)
		assert_true(button.theme == CardScript.tooltip_theme(), "%s: the HUD's tooltip" % action_name)
	var cancel: Button = forestry.panel.button(ForestPanel.ACTION_CANCEL)
	assert_true(cancel.disabled and cancel.tooltip_text == ForestryScript.CANCEL_TIP % 0, "nothing to cancel")
	forestry._panel_verb(ForestPanel.ACTION_FELL, PackedInt32Array())
	forestry.refresh_panel()
	assert_false(cancel.disabled, "a job to cancel")
	assert_true(cancel.tooltip_text.begins_with("Cancel ALL woods jobs (1 on the board)"), cancel.tooltip_text)


func _tool_with_tunnel() -> Array:
	"""A tunnel tool over the placeholder cast (placeholder 0 a mole), an open 12 m tunnel and a dug burrow home:
	[tool, cast, home row]."""
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	var selection: Array = [PackedInt32Array()]
	var tool: ControlScript = _keep(ControlScript.new()) as ControlScript
	tool.configure(cast, _keep(Camera3D.new()) as Camera3D, func() -> PackedInt32Array: return selection[0],
		func(_at: Vector3, _ok: bool) -> void: pass, _say)
	var network: GraphScript = tool.network
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([-6144, -8192, 6144, -8192]), 2, 0, ref), "a tunnel")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	return [tool, cast, _dug_home(network)]


func test_the_tunnels_panel_buttons_are_their_cards() -> void:
	"""A selected tunnel: each job's tooltip is its card (the repair one too), pressable by it. A selected room: each
	"+", "−" and the Suggested layout carry their fit-out cards and are pressable exactly as those allow."""
	var parts := _tool_with_tunnel()
	var tool: ControlScript = parts[0]
	var ext: ExtScript = tool.ext
	var card := CardScript.new()
	ext.actions.select(0)
	ext.refresh_panel()
	for key: StringName in [&"widen", &"brace", &"lanterns", &"repair"]:
		var job: int = TunnelJobs.JOB_CLEAR if key == &"repair" else ExtJobs[key]
		ext.actions.preview_into(card, job, PackedInt32Array())
		var button: Button = ext.panel.button(key)
		assert_equal(button.tooltip_text, card.text(), "%s: its card" % key)
		assert_equal(button.disabled, not card.is_ok(), "%s: enabled by it" % key)
	assert_true(ext.panel.button(&"repair").tooltip_text.contains("has no fall to clear"), "nothing to repair")
	tool.network.close(0, GraphScript.CLOSED_FLOODED, 0, 4096)
	ext.refresh_panel()
	assert_true(ext.panel.button(&"repair").tooltip_text.begins_with("Pump out tunnel 1"), "a flood: the pump")
	ext.actions.clear_selection()
	var r: int = parts[2]
	ext.select_room(r)
	ext.works.stores.plank_milli_u = 0
	ext.refresh_panel()
	var add: Button = ext.panel.button(StringName("fit:add:%d" % RoomsScript.FIX_BED))
	assert_true(add.disabled, "no planks: no bed")
	assert_true(add.tooltip_text.contains("Planks: have 0.0 U · need 2.0 U"), add.tooltip_text)
	var take: Button = ext.panel.button(StringName("fit:take:%d" % RoomsScript.FIX_BED))
	assert_true(take.disabled and take.tooltip_text.contains("Can't now: "), "none to take out")
	var suggest: Button = ext.panel.button(&"fit:suggest")
	assert_true(suggest.disabled and suggest.tooltip_text.begins_with("Suggested layout for "), suggest.tooltip_text)
	ext.works.stores.add_planks(100000)
	ext.works.stores.add_wood(100000)
	ext.works.stores.add_stone(100000)
	ext.refresh_panel()
	assert_false(add.disabled or suggest.disabled, "paid for: both may be ordered")


const ExtJobs: Dictionary = {&"widen": TunnelJobs.JOB_WIDEN, &"brace": TunnelJobs.JOB_BRACE,
	&"lanterns": TunnelJobs.JOB_LANTERNS}


func test_the_party_panels_tool_buttons_carry_their_cards() -> void:
	"""The command layer's refresh puts each tool's card -- its digger and what it stops -- on Dig tunnel and the
	room tools while they show."""
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var command: CommandScript = _keep(CommandScript.new()) as CommandScript
	command.configure(cast, _keep(Camera3D.new()) as Camera3D)
	command.panel().build()
	var dig: Button = command.panel().dig_button()
	dig.visible = false
	var before: String = dig.tooltip_text
	command._refresh_tool_cards()
	assert_equal(dig.tooltip_text, before, "hidden: left alone")
	dig.visible = true
	command._refresh_tool_cards()
	var tool: ControlScript = command.tunnels()
	var card := CardScript.new()
	var tip: String = dig.tooltip_text
	assert_true(tip.begins_with("Dig tunnel (B)\n"), tip)
	tool.tool_card_into(card, "Dig tunnel (B)", "x")
	assert_true(tip.contains("Who: " + card.who.left(20)), "its digger")
	assert_true(tip.contains(command.interrupt_text(card.worker).left(12)), "and what it stops")
	assert_true(command.panel().room_button(0).tooltip_text.begins_with("Burrow home (H)\n"), "the room tools too")



# --- the edges (mutation-tested, decision 0332) ---------------------------------------------------

func test_a_cards_edges() -> void:
	"""Have equal to need is enough; zero work is still said; a requirement is stated exactly (hundredths when it has
	them); a long line keeps every continuation indented; a refusal can be cleared."""
	var card := CardScript.new()
	card.reset("v")
	card.add_cost("X", 2000, 2000)
	assert_equal(card.short_row(), -1, "have == need: not short")
	card.add_cost("Compost", 100, 250)
	assert_equal(card.cost_line(1), "Compost: have 0.1 U · need 0.25 U", "a quarter unit, exactly")
	assert_equal(CardScript.need_text(4700), "4.7 U", "tenths as the HUD prints them")
	card.work_usec = 0
	assert_true(card.text().contains("Work: about 0 game minutes"), "no work is still work said")
	var words := PackedStringArray()
	for k: int in 30:
		words.append("word")
	var lines := CardScript.wrap_lines(PackedStringArray([" ".join(words)])).split("\n")
	assert_true(lines.size() >= 3, "three lines and more")
	for k: int in range(1, lines.size()):
		assert_true(lines[k].begins_with("  ") and not lines[k].begins_with("   "), "line %d indented" % k)
	assert_true(CardScript.queue_for("the crew", PackedStringArray(["A"]), 1).contains("(no selected resident is free"),
		"one selected, busy")
	card.refuse("X", "no", "fix")
	card.clear_refusal()
	assert_true(card.is_ok() and card.code == "" and card.fix == "", "cleared")


func test_a_free_resident_at_night_goes_back_to_bed_and_a_lost_rule_is_skipped() -> void:
	"""Resting with nothing to do: back to bed after. A rule whose owner is gone is passed over."""
	var brain := _lone_brain()
	brain.resting = true
	var rules: Array[Callable] = [Callable(), func(_w: int) -> int: return InterruptScript.NOT_MINE]
	assert_equal(InterruptScript.resume_of(brain, rules, 0), InterruptScript.BACK_TO_BED, "night, free")


func test_the_farm_plans_work_steps_only() -> void:
	"""A plan's work is its work steps' WU (sowing's first step too), a raise's dig included, from a step on."""
	assert_equal(FarmJobs.plan_work_usec(FarmJobs.KIND_SOW, 0), FarmJobs.work_usec_of(FarmJobs.WORK_SOW), "sowing")
	assert_equal(FarmJobs.plan_work_usec(FarmJobs.KIND_COMPOST, 0), FarmJobs.work_usec_of(FarmJobs.WORK_COMPOST),
		"compost: the work at the bed, no dig (decision 0401)")
	assert_equal(FarmJobs.plan_work_usec(FarmJobs.KIND_RAISE, 0),
		FarmJobs.work_usec_of(FarmJobs.WORK_DIG) + FarmJobs.work_usec_of(FarmJobs.WORK_RAISE), "dig, then raise")
	assert_equal(FarmJobs.plan_work_usec(FarmJobs.KIND_WATER, 2), FarmJobs.work_usec_of(FarmJobs.WORK_TEND),
		"from the carry on: the watering")


func test_a_farm_card_counts_the_work_already_done_and_the_step_reached() -> void:
	"""A job called away keeps its work: its card shows what is left -- the compost's dose less the work done, or a
	watering past its fetch only the watering. The resident called away resumes it (the farm's rule)."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	crew.order(FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array([2]), FarmJobs.ORIGIN_PLAYER)
	assert_true(_run_farm(cast, crew, 60.0, func() -> bool: return crew.jobs.elapsed_usec[0] >= 3000000), "half done")
	assert_equal(crew.resume_rule(2), InterruptScript.RESUMES, "its worker would come back to it")
	assert_equal(crew.resume_rule(3), InterruptScript.NOT_MINE, "not a farm worker")
	(cast.actor(2) as DemoActorScript).brain.order_move(Vector2(-6.0, -6.0))
	crew.update(1)
	var kept: int = crew.jobs.elapsed_usec[0]
	assert_true(kept >= 3000000 and crew.jobs.worker[0] == FarmJobs.NOBODY, "on the board with its work")
	var card := CardScript.new()
	crew.preview_into(card, FarmJobs.KIND_COMPOST, BED_CARROTS, PackedInt32Array())
	assert_equal(card.work_usec, FarmJobs.work_usec_of(FarmJobs.WORK_COMPOST) - kept, "what is left")
	crew.order(FarmJobs.KIND_WATER, BED_LOAM + 3, PackedInt32Array([4]), FarmJobs.ORIGIN_PLAYER)
	assert_true(crew.jobs.job_on_bed_into(FarmJobs.KIND_WATER, BED_LOAM + 3, _read), "watering")
	var row: int = _read.value
	assert_true(_run_farm(cast, crew, 120.0, func() -> bool: return crew.jobs.current_step(row) == FarmJobs.STEP_CARRY_BED),
		"carrying the water")
	(cast.actor(4) as DemoActorScript).brain.order_move(Vector2(6.0, -6.0))
	crew.update(1)
	crew.preview_into(card, FarmJobs.KIND_WATER, BED_LOAM + 3, PackedInt32Array())
	assert_equal(card.work_usec, FarmJobs.work_usec_of(FarmJobs.WORK_TEND), "only the watering is left")


func test_a_raise_card_shows_the_heap_it_needs() -> void:
	"""Raise and Bank take earth from one heap or the stores: the card's row is the fullest source against the job's
	dose (decision 0332's have / need), and it says earth adds no fertility (decision 0401)."""
	var cast := _cast()
	var crew := _farm_crew(cast, FarmSim.new())
	var card := CardScript.new()
	for kind: int in [FarmJobs.KIND_RAISE, FarmJobs.KIND_BANK]:
		crew.preview_into(card, kind, BED_LOAM, PackedInt32Array())
		assert_equal(Array(card.cost_names), [FarmCard.EARTH], "earth")
		assert_equal([int(card.cost_have[0]), int(card.cost_need[0])], [crew.most_earth(), FarmJobs.EARTH_PER_JOB_MILLI],
			"the fullest source against a dose")
		assert_true(card.prerequisites[0].begins_with("2.0 U of earth on one heap or in the stores"), "needs, from the dose")
		assert_true(card.result.contains("earth adds no fertility"), card.result)
	assert_equal(card.reason, "no spoil heap or store holds 2.0 U of earth", "the dose in the refusal")


func test_the_bed_panels_buttons_dim_name_resident_0_and_scope_cancel() -> void:
	"""A disabled verb is dimmed, an enabled one not; resident 0 can be the one named; Cancel says its scope only
	while there are jobs."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var panel: BedPanelScript = _keep(BedPanelScript.new()) as BedPanelScript
	panel.configure(sim, crew)
	panel.set_preview(func() -> PackedInt32Array: return PackedInt32Array([0]),
		func(w: int) -> String: return "Interrupts: resident %d" % w)
	panel.show_bed(BED_CARROTS)
	var water: Button = panel.verb_button(FarmJobs.KIND_WATER)
	var harvest: Button = panel.verb_button(FarmJobs.KIND_HARVEST)
	assert_true(water.tooltip_text.contains("Interrupts: resident 0"), "resident 0 named")
	assert_equal([water.modulate.a, harvest.modulate.a], [1.0, 0.5], "enabled bright, disabled dim")
	assert_true(panel._cancel.disabled and panel._cancel.tooltip_text == BedPanelScript.NO_JOBS_TIP, "no jobs")
	crew.order(FarmJobs.KIND_WATER, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	panel.refresh()
	assert_false(panel._cancel.disabled, "a job to cancel")
	assert_equal(panel._cancel.tooltip_text, BedPanelScript.CANCEL_TIP, "this bed's jobs only")
	assert_true(BedPanelScript.CANCEL_TIP.contains("earth in hand goes back to its heap"), "and earth goes back (0401)")


func test_a_picker_row_refused_by_the_board_keeps_the_boards_words() -> void:
	"""A crop the bed can take, with the farm's board full: the row is disabled with the board's refusal, not left
	enabled for an order that will refuse."""
	var cast := _cast()
	var sim := FarmSim.new()
	var crew := _farm_crew(cast, sim)
	var opened: int = 0
	for bed: int in Catalog.BED_COUNT:
		for kind: int in FarmJobs.KIND_COUNT:
			if bed != BED_LOAM and opened < FarmJobs.MAX_JOBS:
				opened += 1 if crew.jobs.open_into(kind, bed, FarmJobs.ORIGIN_ROUTINE, _read) else 0
	var panel: BedPanelScript = _keep(BedPanelScript.new()) as BedPanelScript
	panel.configure(sim, crew)
	panel.show_bed(BED_LOAM)
	panel.open_picker()
	var checked: int = 0
	for item: int in Catalog.ITEM_COUNT:
		if sim.sow_refusal(BED_LOAM, item) == &"":
			checked += 1
			assert_true(panel.picker_button(item).disabled, "disabled")
			assert_true(panel.picker_button(item).tooltip_text.contains("Can't now: the farm's job board is full"), "why")
	assert_true(checked > 0, "some crop could be sown")


# --- the woods' edges ------------------------------------------------------------------------------

func _fill_woods_board(forestry: ForestryScript) -> void:
	"""Every row of the woods' board taken (sawings: any number may queue)."""
	while forestry.crew.jobs.live_count() < ForestJobs.MAX_JOBS:
		forestry.crew.jobs.open_into(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, ForestJobs.ORIGIN_ROUTINE, _read)


func test_the_woods_board_and_the_trunks_hands_refuse_as_the_orders_do() -> void:
	"""A full board refuses a new sawing; a trunk with three hands on it refuses another hauler; a selected haul with
	everyone selected busy is refused -- each card in its order's words."""
	var forestry := _forestry()
	var crew = forestry.crew
	crew.order(ForestJobs.KIND_FELL, WEST_OAK, 0, PackedInt32Array([1, 2, 3]), ForestJobs.ORIGIN_PLAYER)
	assert_equal(crew.jobs.on_target(ForestJobs.KIND_HAUL, WEST_OAK), 2, "a feller and two haulers")
	forestry.select_tree(WEST_OAK)
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array())
	assert_equal(card.code, ForestJobs.REFUSE_ENOUGH_HANDS, "three hands: enough")
	assert_equal(crew.order_haul(WEST_OAK, PackedInt32Array()), "Can't haul logs: " + card.reason, card.reason)
	card = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array([1, 2]))
	assert_equal(card.code, ForestJobs.REFUSE_ENOUGH_HANDS, "the trunk is full before anyone is asked")
	_fill_woods_board(forestry)
	card = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array([4]))
	assert_equal(card.code, ForestJobs.REFUSE_FULL, "the board")
	assert_equal(forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([4])), "Can't saw planks: " + card.reason, "said")
	assert_equal(card.fix, ForestCard.fix_for(ForestJobs.REFUSE_FULL), "cancel some")


func test_a_selected_haul_counts_its_hands_and_refuses_when_all_are_busy() -> void:
	"""Fell with two: one waits to haul. Then three more selected for the haul: the trunk takes one more, the card
	says the lead and one more, and the order puts two on it. Everyone selected busy: refused."""
	var forestry := _forestry()
	var crew = forestry.crew
	forestry.select_tree(WEST_OAK)
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_FELL, PackedInt32Array([1, 2]))
	assert_true(card.who.ends_with("+ 1 waiting to haul"), card.who)
	forestry._panel_verb(ForestPanel.ACTION_FELL, PackedInt32Array([1]))
	card = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array([3, 4, 5]))
	assert_true(card.is_ok(), card.text())
	assert_equal(card.who, CardScript.lead_with(crew.name_of(card.worker), 3, 3, 1, "more hauling"), card.who)
	assert_equal(crew.order_haul(WEST_OAK, PackedInt32Array([3, 4, 5])), "Haul logs: 2 on it", "two, as the card said")
	card = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array([1, 3]))
	assert_equal(card.code, ForestJobs.REFUSE_ENOUGH_HANDS, "three hands now")
	crew.cancel_all()
	crew.order(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array([1]), ForestJobs.ORIGIN_PLAYER)
	crew.order(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array([2]), ForestJobs.ORIGIN_PLAYER)
	crew.order(ForestJobs.KIND_FELL, WEST_OAK, 0, PackedInt32Array([3]), ForestJobs.ORIGIN_PLAYER)
	card = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array([1, 2]))
	assert_equal(card.code, "EVERYONE_SELECTED_BUSY", "both sawing")
	assert_equal(crew.order_haul(WEST_OAK, PackedInt32Array([1, 2])), "Can't haul logs: " + card.reason, card.reason)
	assert_equal(card.fix, ForestCard.fix_for("EVERYONE_SELECTED_BUSY"), "its fix")


func test_a_woods_card_works_at_the_named_residents_skill_and_hauls_by_the_trip() -> void:
	"""A skilled sawyer saws faster than base, and the card says so; a haul's work is every trip's loading and
	stacking (a 12 U trunk: two trips); the sawing goes to the selected resident nearest the log stack."""
	var forestry := _forestry()
	var crew = forestry.crew
	crew.skills.xp[3 * ForestRules.SKILL_COUNT + ForestRules.SKILL_SAWING] = ForestRules.xp_of_level(2)
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_SAW, PackedInt32Array([3]))
	assert_true(card.work_usec < crew.plan_usec(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, -1), "quicker than base")
	assert_equal(card.work_usec, crew.plan_usec(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 3), "at its level")
	assert_equal([ForestCard.trips(6000), ForestCard.trips(6001), ForestCard.trips(12000)], [1, 2, 2], "trips")
	assert_true(forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read), "a trunk lies")
	forestry.select_tree(WEST_OAK)
	card = forestry.action_card(ForestPanel.ACTION_HAUL, PackedInt32Array())
	var trip: int = crew.step_usec(ForestJobs.WORK_LOAD, WEST_OAK, -1) + crew.step_usec(ForestJobs.WORK_DROP, WEST_OAK, -1)
	assert_equal(card.work_usec, ForestCard.trips(forestry.stand.trunk_milli[WEST_OAK]) * trip, "every trip")
	assert_true(card.text().replace("\n  ", " ").contains(ForestCard.HAUL_NOTE.trim_prefix(", ")), "shared by its haulers")
	var members := PackedInt32Array([1, 2, 3, 4, 5])
	var nearest: int = -1
	for who: int in members:
		var d: float = crew.brain_of(who).surface_point().distance_to(Yard.log_stack_at())
		if nearest < 0 or d < crew.brain_of(nearest).surface_point().distance_to(Yard.log_stack_at()):
			nearest = who
	card = forestry.action_card(ForestPanel.ACTION_SAW, members)
	assert_equal(card.worker, nearest, "nearest the log stack")
	assert_equal(crew.resume_rule(nearest), InterruptScript.NOT_MINE, "no woods job yet")
	forestry._panel_verb(ForestPanel.ACTION_SAW, members)
	assert_equal(crew.resume_rule(nearest), InterruptScript.RESUMES, "sawing: it would come back to it")


func test_gathering_aims_at_the_piles_generation_and_names_resident_0() -> void:
	"""Gather deadfall's card is for the nearest pile as it is now (its generation), and with a command layer the
	resident named -- resident 0 too -- has what it stops said."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	var cast: DemoCastScript = _keep(DemoCastScript.new()) as DemoCastScript
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	var command: CommandScript = _keep(CommandScript.new()) as CommandScript
	command.configure(cast, _keep(Camera3D.new()) as Camera3D)
	var forestry: ForestryScript = _keep(ForestryScript.new()) as ForestryScript
	forestry.configure(world, cast, command, null, _services, IntMath.IntResult.new(true, WOOD, ""))
	assert_true(forestry.deadfall.nearest_into(Yard.log_stack_at(), 2.0 * ForestRules.REACH_M, _read), "a pile")
	forestry.deadfall.generation[_read.value] = 7
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_GATHER, PackedInt32Array([0]))
	assert_true(card.is_ok(), card.text())
	assert_equal(forestry._target.y, 7, "its generation")
	assert_equal(card.worker, 0, "resident 0")
	assert_equal(card.interrupts, command.interrupt_text(0), "what it stops")


# --- the tunnels' edges ----------------------------------------------------------------------------

func test_a_tunnel_card_counts_work_done_and_its_crew() -> void:
	"""A brace half worked: its card's work is what is left. A mole job's card counts the crew as add_crew will: not
	the lead, nobody digging, nobody on it already, no more than its room; and says a crew is quicker."""
	var site := _tunnel_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	works.jobs.post(0, TunnelJobs.JOB_BRACE, 2, 0, 4096)
	assert_true(works.jobs.start(0), "paid")
	works.jobs.work(0, 1000000)
	var done: int = works.jobs.done_ticks(0)
	assert_true(done > 0, "some done")
	var card := CardScript.new()
	actions.preview_into(card, TunnelJobs.JOB_BRACE, PackedInt32Array([2]))
	@warning_ignore("integer_division") assert_equal(card.work_usec, (works.jobs.ticks_for(0, TunnelJobs.JOB_BRACE) - done) * 1000000 / TunnelRules.TICKS_PER_SECOND,
		"what is left")
	actions.select(1)
	actions.preview_into(card, TunnelJobs.JOB_WIDEN, PackedInt32Array([0, 2, 3]))
	assert_equal(card.work_note, ActionsScript.MOLE_NOTE, "a crew is quicker")
	brains[2].order = BrainScript.ORDER_DIG
	assert_equal(actions.crew_joining(1, PackedInt32Array([0, 2, 3]), 0), 1, "the digger left off")
	brains[2].order = BrainScript.ORDER_NONE
	for i: int in [1, 2, 3]:
		works.crew.join(i, 1)
	assert_equal(actions.crew_joining(1, PackedInt32Array([0, 2, 3, 1]), 0), 0, "the crew is full")


func test_the_tunnel_panel_names_what_the_mole_stops() -> void:
	"""With the interrupt line wired, a mole job's card names what its lead -- resident 0, the mole -- would stop."""
	var parts := _tool_with_tunnel()
	var tool: ControlScript = parts[0]
	var ext: ExtScript = tool.ext
	ext.set_interrupt(func(w: int) -> String: return "Interrupts: resident %d" % w)
	ext.actions.select(1)
	ext.refresh_panel()
	assert_true(ext.panel.button(&"widen").tooltip_text.contains("Interrupts: resident 0"), ext.panel.button(&"widen").tooltip_text)


func test_the_dig_tool_sends_the_digger_its_card_names() -> void:
	"""A piece laid and confirmed with two selected: the card's digger is the one digging it, with the other on its
	crew as the card counted."""
	var parts := _tool_with_tunnel()
	var tool: ControlScript = parts[0]
	var cast: DemoCastScript = parts[1]
	var selected := PackedInt32Array([2, 3])
	tool._selection = func() -> PackedInt32Array: return selected
	var card := CardScript.new()
	tool.tool_card_into(card, "Dig tunnel (B)", "x")
	assert_equal(card.worker, 2, "the first selected who can dig")
	assert_true(card.who.ends_with("+ 1 on the crew"), card.who)
	assert_true(tool.begin_plan(), "planning")
	tool.lay_ground(Vector2(-12.0, 12.0))
	tool.lay_ground(Vector2(-4.0, 12.0))
	assert_true(tool.confirm(), "dug: " + tool.notice())
	var digging: int = -1
	for i: int in cast.actor_count():
		if (cast.actor(i) as DemoActorScript).brain.dig_tunnel >= 0 or (cast.actor(i) as DemoActorScript).brain.order == BrainScript.ORDER_DIG:
			digging = i
	assert_equal(digging, card.worker, "the digger the card named")
	tool.cancel_plan()


# --- the fit-out's edges ---------------------------------------------------------------------------

func test_a_fitout_card_names_the_first_selected_who_can_reach_and_what_it_puts_in_first() -> void:
	"""Selected [0, 1]: resident 0 is named and given the bed. A bed already waiting: the next "+" card says the
	resident puts that in first. The suggested layout's work is every fixture's."""
	var parts := _tool_with_tunnel()
	var tool: ControlScript = parts[0]
	var ext: ExtScript = tool.ext
	var r: int = parts[2]
	var graph: GraphScript = tool.network
	var stores: StoresScript = ext.works.stores
	stores.add_planks(100000)
	stores.add_wood(100000)
	stores.add_stone(100000)
	var names := PackedStringArray()
	for i: int in (parts[1] as DemoCastScript).actor_count():
		names.append(((parts[1] as DemoCastScript).actor(i) as DemoActorScript).display_name)
	var card := CardScript.new()
	FixtureCard.add_into(card, graph, r, RoomsScript.FIX_BED, stores, PackedInt32Array([0, 1]), ext.fixture_crew, names)
	assert_equal(card.worker, 0, "resident 0 can reach it")
	assert_equal(card.who, CardScript.assign_first(names[0], 2, FixtureCard.WHO_CAN), card.who)
	ext.select_room(r)
	ext.fit_action(StringName("fit:add:%d" % RoomsScript.FIX_BED), PackedInt32Array([0, 1]))
	assert_true((parts[1].actor(0) as DemoActorScript).brain.task is InstallTaskScript, "and is given it")
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "another bed, waiting")
	var later: int = RoomsScript.FIX_HEARTH
	FixtureCard.add_into(card, graph, r, later, stores, PackedInt32Array([1]), ext.fixture_crew, names)
	if graph.fit.place_for(graph, r, later) > graph.fit.place_for(graph, r, RoomsScript.FIX_BED):
		assert_true(card.who.ends_with(FixtureCard.FIRST_WAITING % "bed"), card.who)
	else:
		assert_false(card.who.contains("already waiting"), card.who)
	FixtureCard.suggest_into(card, graph, r, stores, PackedInt32Array(), ext.fixture_crew, names)
	var layout := PackedInt32Array()
	graph.fit.layout_into(graph, r, layout)
	var usec: int = 0
	var count: int = 0
	for kind: int in layout:
		if kind >= 0:
			usec += FixturesScript.install_usec(kind)
			count += 1
	assert_true(count >= 2, "a layout of several")
	assert_equal(card.work_usec, usec, "every fixture's work")


# --- the bridges' edges ----------------------------------------------------------------------------

func test_a_bridge_card_works_at_its_builders_skill_and_counts_who_is_able() -> void:
	"""The bridgewright's card works at its level, loading planks included; a selected resident in the water is not
	able, so the one on land is the nearest free of two."""
	var play := _rig()
	_services.stores.add_planks(12000)
	play.select_candidate(0)
	play.crew.set_crew(PackedInt32Array([4]))
	play.crew.xp[4] = SwimRules.BRIDGEWRIGHT_XP
	var survey = play.survey_site(SwimRules.KIND_PLANK)
	var wu: int = BridgeCrew.LOAD_WU
	for stage: int in SwimRules.STAGE_COUNT:
		wu += SwimRules.stage_wu(SwimRules.KIND_PLANK, stage, survey.deck_u, survey.piers)
	var card: CardScript = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_true(play.crew.level_of(4) > 0, "skilled")
	assert_equal(card.work_usec, wu * play.crew._usec_per_wu(play.crew.level_of(4)), "at its level, the load too")
	assert_true(card.work_usec < wu * play.crew._usec_per_wu(0), "quicker than base")
	play.brain_of(1).in_water = true
	card = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array([1, 2]))
	assert_equal(card.worker, 2, "the one on land")
	assert_equal(card.who, CardScript.assign_selected(play.name_of(2), 1, 2), card.who)
	play.brain_of(1).in_water = false


func test_a_bridge_card_refuses_short_pier_wood_and_no_free_row() -> void:
	"""A span with piers and no wood: refused on the material. Every bridge row taken: refused on the rows, with no
	saw to send the player to."""
	var play := _rig()
	_services.stores.add_planks(30000)
	play.site_custom = true
	play.custom_a = Vector2(19.0, -0.8)
	play.custom_b = Vector2(31.0, -0.8)
	var survey = play.survey_site(SwimRules.KIND_PLANK)
	assert_true(survey.ok and survey.piers > 0, "a ford span with piers")
	_services.stores.wood_milli_u = 0
	var card: CardScript = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_equal(card.code, "MATERIAL", "the pier wood")
	assert_equal(card.short_row(), 1, "the wood row")
	_services.stores.wood_milli_u = 40000
	play.site_custom = false
	play.select_candidate(1)
	var far = BridgesScript.Survey.new()
	play.bridges.survey_candidate_into(2, SwimRules.KIND_PLANK, far)
	assert_true(far.ok, "a site to fill the rows with")
	while play.bridges.has_free_row():
		assert_true(play.bridges.plan_into(far, "x", _read), "a row taken")
	card = play.build_card(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_equal(card.code, "NO_FREE_ROW", card.text())
	assert_equal(card.fix, "", "no saw for a full set of rows")
	assert_equal(play.build(SwimRules.KIND_PLANK, PackedInt32Array()), "Can't build: " + card.reason, "the build's words")


func test_a_log_card_off_a_ready_trunk_says_so() -> void:
	"""With a felled trunk lying ready, the log bridge's card says its log comes off it -- no stores spent."""
	var stand := StandScript.new()
	var placements: Array[Dictionary] = [{"key": &"oak_mature", "at": Vector2(10.0, 4.0), "yaw": 0.0, "size": 1.0}]
	assert_true(stand.bind_into(placements, WOOD, 1, _read), "a tree")
	assert_true(stand.blow_down_into(0, 1, Vector2.UP, _read), "felled by the wind")
	var play := _rig(stand)
	play.select_candidate(0)
	var card: CardScript = play.build_card(SwimRules.KIND_LOG, PackedInt32Array())
	assert_true(card.is_ok(), card.text())
	assert_true(card.result.ends_with(WaterplayScript.TRUNK_NOTE), card.result)
	assert_true(card.cost_names.is_empty(), "no stores row")


func test_the_dive_card_names_the_first_diver() -> void:
	"""Two divers: the first selected is named (its spread spot judged as the order judges it: `dive_spot`)."""
	var play := _rig()
	var spot: Vector2 = play.pond_dive_spot()
	for who: int in [0, 1]:
		play.state.swim_mm_s[who] = 1100
		play.state.dives[who] = 1
		play.state.height_u[who] = 1526
	var card: CardScript = play.dive_card(PackedInt32Array([0, 1]), spot)
	assert_equal(card.worker, 0, "the first")



func test_a_crew_joins_only_as_far_as_its_room() -> void:
	"""Six residents: with one on the crew already, a mole job's crew takes two more of four candidates (4 builders)."""
	var parts := _tool_with_tunnel()
	var tool: ControlScript = parts[0]
	var ext: ExtScript = tool.ext
	ext.works.crew.join(1, 1)
	assert_equal(ext.actions.crew_joining(1, PackedInt32Array([0, 2, 3, 4, 5]), 0), 2, "the crew's room")


func test_a_planting_card_needs_a_quarter_unit_of_compost() -> void:
	"""Planting's need is stated exactly: 0.25 U of compost, not the floored 0.2."""
	var forestry := _forestry()
	assert_true(forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read), "felled")
	forestry.select_tree(WEST_OAK)
	var card: CardScript = forestry.action_card(ForestPanel.ACTION_PLANT, PackedInt32Array())
	assert_equal(Array(card.prerequisites), ["a cleared spot within reach; 0.25 U of compost"], "its need")


func test_a_fixture_card_skips_who_cannot_reach_and_names_a_later_waiting_fixture_only_if_first() -> void:
	"""One selected resident too big for any bore cannot reach the room: the next is named. A lantern already waiting
	(a later place) is not what a hearth's installer puts in first; a bed waiting earlier is -- for resident 0 too."""
	var parts := _tool_with_tunnel()
	var tool: ControlScript = parts[0]
	var ext: ExtScript = tool.ext
	var cast: DemoCastScript = parts[1]
	var graph: GraphScript = tool.network
	var r: int = parts[2]
	var stores: StoresScript = ext.works.stores
	stores.add_planks(100000)
	stores.add_wood(100000)
	stores.add_stone(100000)
	var names := PackedStringArray()
	for i: int in cast.actor_count():
		names.append((cast.actor(i) as DemoActorScript).display_name)
	graph.set_body((cast.actor(1) as DemoActorScript).brain.index, 6000, 2500)
	assert_false(ext.fixture_crew.can_reach(1, r), "too big for any bore")
	var card := CardScript.new()
	FixtureCard.add_into(card, graph, r, RoomsScript.FIX_HEARTH, stores, PackedInt32Array([1, 2]), ext.fixture_crew, names)
	assert_equal(card.worker, 2, "the one who can")
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_LANTERN, stores), FixturesScript.REFUSE_NONE, "a lantern waits")
	FixtureCard.add_into(card, graph, r, RoomsScript.FIX_HEARTH, stores, PackedInt32Array([0]), ext.fixture_crew, names)
	var lantern_later: bool = graph.fit.place_for(graph, r, RoomsScript.FIX_HEARTH) < _place_of_kind(graph, r, RoomsScript.FIX_LANTERN)
	assert_equal(card.who.contains("already waiting"), not lantern_later, card.who)
	assert_equal(graph.fit.order(graph, r, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "a bed waits")
	FixtureCard.add_into(card, graph, r, RoomsScript.FIX_HEARTH, stores, PackedInt32Array([0]), ext.fixture_crew, names)
	assert_equal(card.worker, 0, "resident 0")
	assert_true(card.who.ends_with(FixtureCard.FIRST_WAITING % "bed"), "the bed first: " + card.who)


func _place_of_kind(graph: GraphScript, r: int, kind: int) -> int:
	"""The place a planned fixture of `kind` stands in (-1: none)."""
	for f: int in RoomsScript.fixture_count(graph.rooms.template[r]):
		if graph.fit.phase_of(graph, r, f) == FixturesScript.PLANNED and graph.fit.kind_at(graph, r, f) == kind:
			return f
	return -1



func test_a_refresh_leaves_the_room_rows_shown_as_they_were() -> void:
	"""Showing the same room again changes no row's visibility (a hide-and-show would drop the pointer's hover and
	close a "+" card's tooltip every refresh); a kind that leaves the palette is hidden."""
	var panel := TunnelPanelScript.new()
	_keep(panel)
	panel.build()
	var rows: Array[Dictionary] = [{"kind": RoomsScript.FIX_BED, "text": "Bed", "add": true, "take": false},
		{"kind": RoomsScript.FIX_HEARTH, "text": "Hearth", "add": true, "take": false}]
	panel.show_room("Burrow home 1", "", rows, "Suggested layout", true)
	var flips: Array = [0]
	for row: HBoxContainer in panel._fit_rows:
		row.visibility_changed.connect(func() -> void: flips[0] = int(flips[0]) + 1)
	panel.show_room("Burrow home 1", "", rows, "Suggested layout", true)
	assert_equal(int(flips[0]), 0, "nothing hidden and shown again")
	assert_true(panel._fit_rows[RoomsScript.FIX_BED].visible and panel._fit_rows[RoomsScript.FIX_HEARTH].visible, "both shown")
	assert_false(panel._fit_rows[RoomsScript.FIX_LANTERN].visible, "a kind not in the palette: hidden")
	rows.pop_back()
	panel.show_room("Burrow home 1", "", rows, "Suggested layout", true)
	assert_false(panel._fit_rows[RoomsScript.FIX_HEARTH].visible, "a kind gone: hidden")
	assert_equal(int(flips[0]), 1, "only that one changed")
