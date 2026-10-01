extends "res://test/framework/test_case.gd"
## The live demo's water gameplay, part A (decision 0196): wading, swimming, diving, rescue and
## bridges (`godot/demo/waterplay/`), and the hooks it adds to the cast, the router, the command layer,
## the panels and the overlay. Built over the placeholder cast in the real village layout and the real
## village water -- no staged assets, no scene tree. Every expected number is restated from its
## source: HAZ-001/002/003 (docs/underground_economy_hazard_amendment.md) for air and stamina, GDD §5.3
## for skill, swim_rules.gd's named demo values, and the village water's authored layout.

const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/waterplay/swim_rules.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const CrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const SwimTaskScript := preload("res://demo/waterplay/swim_task.gd")
const DiveTaskScript := preload("res://demo/waterplay/dive_task.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const PanelScript := preload("res://demo/waterplay/water_panel.gd")
const TextScript := preload("res://demo/waterplay/waterplay_text.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const OverlayScript := preload("res://demo/water/water_overlay.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const HookScript := preload("res://demo/cast/crossing_hook.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const DemoWaterScript := preload("res://demo/water/demo_water.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const PartyPanelScript := preload("res://demo/control/demo_party_panel.gd")
const DetailZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const LiftScript := preload("res://demo/forestry/forest_lift.gd")
const SwimViewScript := preload("res://demo/waterplay/swim_view.gd")
const BridgeViewScript := preload("res://demo/waterplay/bridge_view.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 4000
## The village water, restated from water_layout.gd (metres).
const RUN_MID: Vector2 = Vector2(24.4, 11.0)          # the run: 1.4 m deep by the fisher shelter
const FORD_MID: Vector2 = Vector2(25.7, -0.8)         # the ford: 0.20-0.22 m deep where the road crosses
const POND_CENTRE: Vector2 = Vector2(28.467, 28.672)  # the pond's first circle: 1.9 m deep
const WEST_BANK: Vector2 = Vector2(18.5, 10.5)
const EAST_BANK: Vector2 = Vector2(30.5, 10.5)

## The water rig a test drives: the placeholder cast on the village water, and the gameplay node.
class Rig:
	var cast: DemoCastScript = null
	var play: WaterplayScript = null

static var _map_cache: WaterMapScript = null
static var _links_cache: LinksScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""A fresh set of demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			if (node as Node).is_inside_tree():
				(node as Node).get_parent().remove_child(node)
			node.free()
	_nodes.clear()


# --- fixtures -----------------------------------------------------------------------------------

func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _map() -> WaterMapScript:
	"""The village's water (water_layout.gd), built once for the suite (immutable once finalised)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


static func _links() -> LinksScript:
	"""The band, links and connections over the village water with no obstacles (built once)."""
	if _links_cache == null:
		_links_cache = LinksScript.new()
		var none: Array[Vector3] = []
		_links_cache.build(_map(), none)
	return _links_cache


func _rig() -> Rig:
	"""The placeholder cast (six 1 m capsules) on the real layout, walking round the water's band inside
	the widened area, and the water gameplay wired over it as demo_village.gd wires it (no command
	layer, no water node, no woods). Placeholders swim at nothing until a test says otherwise."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links := WaterplayScript.make_links(_map(), circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	rig.play = _keep(WaterplayScript.new()) as WaterplayScript
	rig.play.configure(rig.cast, null, null, _services, _map(), links)
	return rig


func _swimmer(rig: Rig, who: int, mm_s: int, dives: bool = false) -> void:
	"""Make placeholder `who` a swimmer at `mm_s` (a diver when `dives`)."""
	rig.play.state.swim_mm_s[who] = mm_s
	rig.play.state.dives[who] = 1 if dives else 0


func _brain(rig: Rig, who: int) -> BrainScript:
	"""Placeholder `who`'s brain."""
	return (rig.cast.actor(who) as DemoActorScript).brain


func _place(rig: Rig, who: int, at: Vector2) -> void:
	"""Stand placeholder `who` at `at`, holding (its slot given up)."""
	var brain := _brain(rig, who)
	brain.release_slot()
	brain.start_at(at, 0.0, -1, -1)
	brain.order_move(at)


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step the cast and the water until `done()` answers true (bounded). True when it did."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		rig.cast.advance(DT)
		rig.play.step(rig.cast.clock.frame_usec)
	return bool(done.call())


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from `p` to the segment a-b (the test's own)."""
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _band_blocks(from: Vector2, to: Vector2) -> bool:
	"""Whether a walker's line from -> to meets a band circle."""
	for circle: Vector3 in _links().band:
		if _segment_distance(Vector2(circle.x, circle.z), from, to) < circle.y:
			return true
	return false


# --- the rules ----------------------------------------------------------------------------------

func test_who_swims_is_the_demo_table_by_species() -> void:
	"""Otters 1.90 m/s and dive; the beaver 1.40; mice 0.84, squirrels 0.77, moles 0.70 (decision 0205's
	pace); the badger and anything unlisted do not swim; only otters dive. Each stroke clip reads right at
	part A's speeds (1.10, 0.90, 0.60, 0.55, 0.50) and plays at the swim speed over them."""
	var cases: Dictionary = {"Otter": 1900, "beaver": 1400, "Mouse": 840, "squirrel": 770, "Mole": 700, "Badger": 0, "dragon": 0}
	var strokes: Dictionary = {"Otter": 1100, "beaver": 900, "Mouse": 600, "squirrel": 550, "Mole": 500, "Badger": 0, "dragon": 0}
	for species: String in cases:
		assert_equal(Rules.swim_mm_s_of(species), cases[species], "%s swims" % species)
		assert_equal(Rules.stroke_mm_s_of(species), strokes[species], "%s strokes" % species)
	assert_almost_equal(Rules.stroke_rate(1900, 1100), 1900.0 / 1100.0, "an otter strokes faster than part A's")
	assert_almost_equal(Rules.stroke_rate(550, 1100), 0.5, "half speed, half the stroke")
	assert_almost_equal(Rules.stroke_rate(700, 0), 1.0, "no stroke speed: the clip as it is")
	assert_true(Rules.dives_of("otter") and not Rules.dives_of("beaver") and not Rules.dives_of("dragon"), "otters dive")
	assert_equal(Rules.swim_words("Badger"), "wades only", "the badger wades only")
	assert_equal(Rules.swim_words("dragon"), "wades only", "unlisted: wades")


func test_fixed_ticks_keep_their_remainder_and_stop_while_paused() -> void:
	"""30 ticks a demo second: 50 ms is 1.5 ticks -- 1, then 2 with the half carried; paused, none."""
	var carry := PackedInt64Array([0])
	assert_equal(Rules.ticks_for_usec(50000, carry), 1, "1.5 ticks: one now")
	assert_equal(Rules.ticks_for_usec(50000, carry), 2, "the carried half makes two")
	assert_equal(Rules.ticks_for_usec(0, carry), 0, "paused: none")
	assert_equal(Rules.ticks_for_usec(1000000, carry), 30, "a second: 30")


func test_stamina_drain_counts_cold_and_flow() -> void:
	"""3 a tick; twice that in cold water; plus the flow's share of the swimmer's speed, rounded up."""
	assert_equal(Rules.rest_drain_per_tick(600, 0, false), 3, "still water")
	assert_equal(Rules.rest_drain_per_tick(600, 0, true), 6, "cold")
	assert_equal(Rules.rest_drain_per_tick(600, 400, false), 5, "3 x 1000 / 600")
	assert_equal(Rules.rest_drain_per_tick(600, 400, true), 10, "6 x 1000 / 600")
	assert_equal(Rules.rest_drain_per_tick(1100, 400, false), 5, "ceil(3 x 1500 / 1100)")
	assert_equal(Rules.rest_drain_per_tick(0, 400, false), 3, "no speed: the base")
	assert_true(Rules.cold_water(99) and not Rules.cold_water(100), "cold below 10.0 C")


func test_a_swimmer_makes_good_what_its_speed_leaves_across_the_flow() -> void:
	"""sqrt(s^2 - across^2) plus the flow along; nothing when the flow across is its speed or more."""
	assert_equal(Rules.ground_speed_mm_s(600, 400, 0), 447, "isqrt(200000)")
	assert_equal(Rules.ground_speed_mm_s(1100, 400, 0), 1024, "isqrt(1050000)")
	assert_equal(Rules.ground_speed_mm_s(400, 400, 0), 0, "equal: swept")
	assert_equal(Rules.ground_speed_mm_s(400, 400, 100), 0, "swept: the flow along does not save it")
	assert_equal(Rules.ground_speed_mm_s(600, -700, 0), 0, "either side")
	assert_equal(Rules.ground_speed_mm_s(600, 0, 100), 700, "with the flow")
	assert_equal(Rules.ground_speed_mm_s(600, 0, -700), 0, "never backwards")
	assert_equal(Rules.flow_mm_s(410, 0), 400, "the stream's 0.4 m/s")
	assert_equal(Rules.flow_mm_s(410, 1000), 800, "full flood: twice")
	assert_equal(Rules.flow_mm_s(410, 500), 600, "half a flood")


func test_a_ferry_heading_angles_into_the_flow_to_hold_its_line() -> void:
	"""Across a 0.4 m/s flow at 0.6 m/s the heading leans upstream so heading x speed + flow runs along
	the line at 0.447 m/s; with no way to hold it, straight at the line."""
	var heading: Vector2 = MotionScript.ferry_heading(Vector2(1.0, 0.0), Vector2(0.0, 0.4), 0.6)
	var ground: Vector2 = heading * 0.6 + Vector2(0.0, 0.4)
	assert_almost_equal(heading.length(), 1.0, "a unit heading")
	assert_almost_equal(ground.y, 0.0, "no drift off the line")
	assert_almost_equal(ground.x, sqrt(0.2), "sqrt(0.36 - 0.16)")
	assert_equal(MotionScript.ferry_heading(Vector2(1.0, 0.0), Vector2(0.0, 0.7), 0.6), Vector2(1.0, 0.0), "swept")


func test_a_planned_dive_is_admitted_only_with_its_air_and_reserve() -> void:
	"""HAZ-002: T = down + 240 ticks searching + up (0.8 m at 0.5 m/s: 48 ticks each way) = 336;
	admitted with air >= T + 300 = 636; turn back at air <= B + 300; a zero plan is invalid."""
	assert_equal(Rules.dive_ticks(800), 336, "48 + 240 + 48")
	assert_true(Rules.admits_dive(636, 336), "exactly the budget")
	assert_false(Rules.admits_dive(635, 336), "one short")
	assert_false(Rules.admits_dive(1200, 0), "a zero plan")
	assert_true(Rules.must_return(348, 48), "equality turns back")
	assert_false(Rules.must_return(349, 48), "one more: not yet")
	assert_true(Rules.admits_swim(4000) and not Rules.admits_swim(3999), "HAZ-001: rest >= 4000")


func test_bridge_arithmetic_spans_decks_piers_costs_and_work() -> void:
	"""Deck = span + 2 x 614 u; a pier every started 2560 u of a span over 3584 u (none for a log);
	planks 1.0 U a metre rounded up to 0.1 U; WU per stage; §5.3's skill factor."""
	assert_equal(Rules.deck_u(3492), 4720, "3492 + 1228")
	assert_equal(Rules.piers_for(Rules.KIND_PLANK, 3584), 0, "3.5 m: none")
	assert_equal(Rules.piers_for(Rules.KIND_PLANK, 3585), 1, "just over: one")
	assert_equal(Rules.piers_for(Rules.KIND_PLANK, 5120), 1, "two gaps: one")
	assert_equal(Rules.piers_for(Rules.KIND_PLANK, 5121), 2, "just over two gaps")
	assert_equal(Rules.piers_for(Rules.KIND_LOG, 5000), 0, "a log: none")
	assert_equal(Rules.plank_milli(4720), 4700, "ceil(4609.4) to the tenth")
	assert_equal(Rules.plank_milli(1024), 1000, "a metre, exactly")
	assert_equal(Rules.stage_wu(Rules.KIND_PLANK, Rules.STAGE_PIERS, 4720, 2), 80, "2 x 40")
	assert_equal(Rules.stage_wu(Rules.KIND_PLANK, Rules.STAGE_BEAMS, 4720, 0), 116, "ceil(25 x 4720 / 1024)")
	assert_equal(Rules.stage_wu(Rules.KIND_PLANK, Rules.STAGE_DECK, 4720, 0), 93, "ceil(20 x 4720 / 1024)")
	assert_equal(Rules.stage_wu(Rules.KIND_LOG, Rules.STAGE_BEAMS, 4720, 0), 123, "30 + 93")
	assert_equal(Rules.stage_wu(Rules.KIND_LOG, Rules.STAGE_DECK, 4720, 0), 47, "ceil(10 x 4720 / 1024)")
	assert_equal(Rules.work_usec(10, 0), 1000000, "10 WU at 0.1 s")
	assert_equal(Rules.work_usec(10, 6), 769230, "/ 1.300")
	assert_equal(Rules.max_deck_u(Rules.KIND_LOG), 5632, "a 5.5 m log")
	assert_equal(Rules.max_deck_u(Rules.KIND_PLANK), 8192, "8 m of planks")


# --- the swim state -------------------------------------------------------------------------------

func _state() -> StateScript:
	"""A mouse, an otter and a badger (1.0, 1.49, 2.55 m)."""
	var state := StateScript.new()
	state.setup(PackedStringArray(["Mouse", "Otter", "Badger"]), PackedInt32Array([1024, 1526, 2611]))
	return state


func test_swim_rows_are_seeded_by_species_full_and_on_land() -> void:
	"""Capability from the table; full air (1200) and rest (10000); on land; consenting."""
	var state := _state()
	assert_equal(state.swim_mm_s, PackedInt32Array([840, 1900, 0]), "speeds")
	assert_equal(state.stroke_mm_s, PackedInt32Array([600, 1100, 0]), "the strokes' own speeds")
	assert_true(state.can_dive(1) and not state.can_dive(0) and not state.can_swim(2), "who dives, who wades")
	assert_equal(state.air, PackedInt32Array([1200, 1200, 1200]), "full air")
	assert_equal(state.rest, PackedInt32Array([10000, 10000, 10000]), "full rest")
	assert_equal(state.mode[0], StateScript.MODE_LAND, "on land")
	assert_equal(state.consent[2], 1, "consenting")


func test_air_is_spent_below_and_breathed_back_above_on_fixed_ticks() -> void:
	"""A second of diving: 30 ticks of air (1170) and of stamina at 3 (9910); paused, nothing; a third of
	a second at the surface breathes back 4 a tick, capped at 1200."""
	var state := _state()
	state.set_mode(1, StateScript.MODE_DIVE)
	assert_equal(state.advance_usec(1000000), 30, "30 ticks")
	assert_equal(state.air[1], 1170, "1 a tick below")
	assert_equal(state.rest[1], 9910, "3 a tick diving")
	state.advance_usec(0)
	assert_equal(state.air[1], 1170, "paused: none")
	state.set_mode(1, StateScript.MODE_SWIM)
	state.advance_usec(333334)
	assert_equal(state.air[1], 1200, "1170 + 4 x 10, capped")
	assert_equal(state.air[0], 1200, "on land: full")


func test_rest_comes_back_on_land_three_times_as_fast_resting() -> void:
	"""6 a tick on land (wading too), 18 resting, nothing in difficulty or towed."""
	var state := _state()
	state.rest = PackedInt32Array([5000, 5000, 5000])
	state.set_mode(0, StateScript.MODE_WADE)
	state.set_mode(1, StateScript.MODE_RESTING)
	state.set_mode(2, StateScript.MODE_DISTRESS)
	state.advance_usec(100000)
	assert_equal(state.rest, PackedInt32Array([5018, 5054, 5000]), "3 ticks: 6, 18 and 0 a tick")


func test_tired_and_exhausted_are_latched_once_and_rearm_at_4000() -> void:
	"""HAZ-003: rest 1500 raises TIRED once; 0 raises EXHAUSTED once; back to 4000 on land re-arms both."""
	var state := _state()
	state.rest[0] = 1503
	state.set_mode(0, StateScript.MODE_SWIM)
	state.advance_usec(33334)
	assert_equal(state.rest[0], 1500, "3 a tick")
	assert_equal(state.take_events(0), StateScript.EVENT_TIRED, "tired at 1500")
	assert_equal(state.take_events(0), 0, "read once")
	state.rest[0] = 3
	state.advance_usec(33333)
	assert_equal(state.take_events(0), StateScript.EVENT_EXHAUSTED, "exhausted at 0, tired not again")
	state.set_mode(0, StateScript.MODE_LAND)
	state.rest[0] = 3995
	state.advance_usec(33333)
	assert_equal(state.tired_latch[0] + state.exhausted_latch[0], 0, "re-armed at 4001")


func test_low_air_and_air_out_are_raised_below_the_surface() -> void:
	"""HAZ-002's advisory at air <= 450 while submerged, and AIR_OUT at 0."""
	var state := _state()
	state.air[1] = 452
	state.set_mode(1, StateScript.MODE_DIVE)
	state.advance_usec(33334)
	assert_equal(state.take_events(1) & StateScript.EVENT_LOW_AIR, 0, "451: not yet")
	state.advance_usec(33333)
	assert_equal(state.take_events(1) & StateScript.EVENT_LOW_AIR, StateScript.EVENT_LOW_AIR, "450: low")
	state.air[1] = 1
	state.set_mode(1, StateScript.MODE_DISTRESS_UNDER)
	state.advance_usec(33333)
	assert_equal(state.air[1], 0, "spent")
	assert_equal(state.take_events(1) & StateScript.EVENT_AIR_OUT, StateScript.EVENT_AIR_OUT, "air out")


func test_a_swim_is_refused_naming_its_failed_condition() -> void:
	"""MOVE-REQ-005 / HAZ-001: no swimming; a load; no consent; rest under 4000; in difficulty."""
	var state := _state()
	assert_equal(state.swim_refusal(2, false), Rules.REFUSE_CANNOT_SWIM, "the badger")
	assert_equal(state.swim_refusal(0, true), Rules.REFUSE_LOADED, "loads cannot swim")
	state.set_consent(0, false)
	assert_equal(state.swim_refusal(0, false), Rules.REFUSE_NO_CONSENT, "no consent")
	state.set_consent(0, true)
	state.rest[0] = 3999
	assert_equal(state.swim_refusal(0, false), Rules.REFUSE_TIRED, "tired")
	state.rest[0] = 4000
	assert_equal(state.swim_refusal(0, false), Rules.REFUSE_NONE, "fit to swim")
	state.set_mode(0, StateScript.MODE_TOWED)
	assert_equal(state.swim_refusal(0, false), Rules.REFUSE_TIRED, "being towed")
	assert_equal(state.meter_text(1), "breath 1200/1200 · stamina 100%", "the meters")


# --- the band, links and connections ------------------------------------------------------------

func test_blocked_width_is_the_radius_less_the_mouse_wade_ramp() -> void:
	"""Water deeper than the 0.25 m a mouse wades is blocked: a 2.0 m half-width at a 1.0 m bed on a
	1.2 m ramp is blocked 2.0 - 0.25 x 1.2 / 1.0 = 1.7 m out; a bed the mouse wades is not blocked."""
	var links := _links()
	assert_almost_equal(links.blocked_width_m(2.0, 1.0, 1.2), 1.7, "2.0 - 0.3")
	assert_almost_equal(links.blocked_width_m(2.0, 0.2, 1.2), 0.0, "a wadeable bed")
	assert_almost_equal(links.blocked_width_m(0.2, 1.0, 1.2), 0.0, "never below zero")


func test_the_band_walls_off_deep_water_and_leaves_the_ford_open() -> void:
	"""A walker's line across the run meets the band; the one across the ford where the road crosses
	does not; the band runs past the planning area's north edge; no circle is over a metre."""
	assert_true(_band_blocks(WEST_BANK, EAST_BANK), "across the run: walled")
	assert_false(_band_blocks(Vector2(19.0, -0.8), Vector2(31.0, -0.8)), "across the ford: open")
	assert_true(_band_blocks(Vector2(19.0, 28.7), Vector2(36.0, 28.7)), "across the pond: walled")
	var beyond: bool = false
	for circle: Vector3 in _links().band:
		assert_true(circle.y > 0.0 and circle.y <= LinksScript.BAND_R_M, "radius at (%.1f, %.1f)" % [circle.x, circle.z])
		beyond = beyond or circle.z < -LinksScript.AREA_HALF_M
	assert_true(beyond, "the band reaches past the area's north edge")
	assert_true(_links().blocked_margin_m(RUN_MID) > 0.0 and _links().blocked_margin_m(FORD_MID) < 0.0, "run in, ford out")


func test_swim_links_cross_deep_water_between_dry_land_ends() -> void:
	"""Every link's middle is in water, its land ends dry; none crosses the ford (walked); with no
	obstacles the pond has three of its four chords -- the north-south one's north end would stand in
	the stream's mouth, which is not dry land."""
	var links := _links()
	var map := _map()
	var chords: int = 0
	for k: int in links.link_count:
		var mid: Vector2 = (links.link_water_a[k] + links.link_water_b[k]) * 0.5
		assert_true(map.is_water(MotionScript.u_of(mid)), "link %d's middle is water" % k)
		assert_false(map.is_water(MotionScript.u_of(links.link_land_a[k])) or map.is_water(MotionScript.u_of(links.link_land_b[k])), "link %d's land ends are dry" % k)
		assert_true(map.depth_at(MotionScript.u_of(mid)) > WaterRules.wade_max_u(WaterRules.MOUSE_HEIGHT_U), "link %d is too deep to wade" % k)
		chords += links.link_kind[k]
	assert_equal(chords, 3, "three pond chords")
	assert_true(links.link_count > 3, "and links across the stream")


func test_a_link_whose_land_end_is_blocked_is_not_published() -> void:
	"""An obstacle standing on every stream link's west land end removes those links; the chords stay."""
	var blockers: Array[Vector3] = []
	var open := _links()
	for k: int in open.link_count:
		if open.link_kind[k] == LinksScript.KIND_ACROSS:
			blockers.append(Vector3(open.link_land_a[k].x, 0.3, open.link_land_a[k].y))
	var links := LinksScript.new()
	links.build(_map(), blockers)
	assert_equal(links.link_count, 3, "only the chords are left")


func test_the_way_in_weighs_the_walk_against_the_swim() -> void:
	"""For the pond's centre, from the village's side, the connection taken is on the west shore; from
	the east, on the east shore; a dry spot has no way in."""
	var links := _links()
	assert_true(links.connection_for_into(POND_CENTRE, Vector2(15.0, 28.0), _read), "a way in from the west")
	assert_true(links.conn_land[_read.value].x < POND_CENTRE.x, "on the west shore")
	assert_true(links.connection_for_into(POND_CENTRE, Vector2(40.0, 28.0), _read), "and from the east")
	assert_true(links.conn_land[_read.value].x > POND_CENTRE.x, "on the east shore")
	assert_false(links.connection_for_into(Vector2(0.0, 0.0), Vector2(1.0, 0.0), _read), "the square: no water")


# --- bridges ---------------------------------------------------------------------------------------

func _bridges(obstacles: Array[Vector3] = []) -> BridgesScript:
	"""Bridges over the village water, among `obstacles`, in the planning area."""
	var bridges := BridgesScript.new()
	bridges.configure(_map(), obstacles, _links().area)
	return bridges


func test_the_bridge_candidates_are_the_maps_spans_inside_the_area() -> void:
	"""The water map publishes four bridge spans on the stream above the neck (z -25.6, -31.9, -38.3,
	-44.6 m); the fourth lies past the area's -44 m edge."""
	var bridges := _bridges()
	assert_equal(bridges.candidate_count(), 3, "three inside")
	var neck: PackedVector2Array = bridges.candidate_ends(0)
	assert_true(neck[0].y > -26.0 and neck[0].y < -25.0, "the first is the neck")
	assert_equal(bridges.candidate_ends(3), PackedVector2Array(), "no fourth")


func test_the_neck_takes_a_plank_footbridge_without_piers() -> void:
	"""The neck is 3.4 m of water: a 4.6 m deck, no piers (a span of at most 3.5 m), planks for it at
	1.0 U a metre, rounded up; its log bridge is one 6 U log."""
	var bridges := _bridges()
	var plank := BridgesScript.Survey.new()
	assert_true(bridges.survey_candidate_into(0, Rules.KIND_PLANK, plank), plank.reason)
	assert_true(plank.span_u > 3380 and plank.span_u < 3600, "about 3.4 m: %d u" % plank.span_u)
	assert_equal(plank.deck_u, plank.span_u + 1228, "the overhangs")
	assert_equal(plank.piers, 0, "no piers")
	assert_equal(plank.planks_milli, Rules.plank_milli(plank.deck_u), "the planks")
	assert_equal(plank.wood_milli, 0, "no pier wood")
	var log := BridgesScript.Survey.new()
	assert_true(bridges.survey_candidate_into(0, Rules.KIND_LOG, log), log.reason)
	assert_equal(log.wood_milli, 6000, "one log")


func test_a_line_over_two_waters_is_not_one_span() -> void:
	"""Two streams 5 m apart: a line across both crosses dry ground between them -- refused."""
	var map := WaterMapScript.new(1229)
	assert_true(map.add_stream(&"a", PackedInt32Array([0, 0, 1024, 512, 0, 20480, 1024, 512]), 184, 512, 400).ok, "a")
	assert_true(map.add_stream(&"b", PackedInt32Array([6144, 0, 1024, 512, 6144, 20480, 1024, 512]), 184, 512, 400).ok, "b")
	assert_true(map.finalize().ok, "finalised")
	var bridges := BridgesScript.new()
	var none: Array[Vector3] = []
	bridges.configure(map, none, Rect2(-50.0, -50.0, 100.0, 100.0))
	var out := BridgesScript.Survey.new()
	assert_false(bridges.survey_into(Vector2(-3.0, 10.0), Vector2(9.0, 10.0), Rules.KIND_PLANK, out), "two waters")
	assert_equal(out.reason, "the line crosses dry ground between two waters", "said")
	assert_true(bridges.survey_into(Vector2(-3.0, 10.0), Vector2(3.0, 10.0), Rules.KIND_PLANK, out), "one of them: " + out.reason)


func test_a_survey_says_why_a_bridge_cannot_stand() -> void:
	"""An end in the water; no water; the pond; a log over 5.5 m; a footing in something; a deck through
	something; too near another bridge -- each in words."""
	var bridges := _bridges()
	var out := BridgesScript.Survey.new()
	assert_false(bridges.survey_into(RUN_MID, EAST_BANK, Rules.KIND_PLANK, out), "from the water")
	assert_equal(out.reason, "both ends must be on a bank, not in the water", "in the water")
	assert_false(bridges.survey_into(Vector2(0.0, 0.0), Vector2(5.0, 0.0), Rules.KIND_PLANK, out), "the square")
	assert_equal(out.reason, "the line crosses no water", "no water")
	assert_false(bridges.survey_into(Vector2(19.0, 28.7), Vector2(36.0, 28.7), Rules.KIND_PLANK, out), "the pond")
	assert_equal(out.reason, "only the stream is bridged -- the pond is too wide", "the pond")
	assert_false(bridges.survey_into(Vector2(19.0, -0.8), Vector2(31.0, -0.8), Rules.KIND_LOG, out), "a log over the ford")
	assert_true(out.reason.begins_with("a log bridge spans at most 5.5 m of deck; this needs "), out.reason)
	assert_true(bridges.survey_into(Vector2(19.0, -0.8), Vector2(31.0, -0.8), Rules.KIND_PLANK, out), "planks over the ford")
	assert_equal(out.piers, 2, "6.4 m of water: two piers")


func test_footings_and_decks_keep_clear_and_bridges_apart() -> void:
	"""A tree on the neck's west footing, or the weir in the deck's way, is named; a second bridge within
	3 m of the first is too close."""
	var neck: PackedVector2Array = _bridges().candidate_ends(0)
	var dir: Vector2 = (neck[1] - neck[0]).normalized()
	var footing: Vector2 = neck[0] - dir * 0.6
	var tree: Array[Vector3] = [Vector3(footing.x, 0.3, footing.y)]
	var out := BridgesScript.Survey.new()
	assert_false(_bridges(tree).survey_candidate_into(0, Rules.KIND_PLANK, out), "a tree on the footing")
	assert_true(out.reason.begins_with("a footing is not clear: something stands at ("), out.reason)
	var mid: Vector2 = (neck[0] + neck[1]) * 0.5
	var weir: Array[Vector3] = [Vector3(mid.x, 0.5, mid.y)]
	assert_false(_bridges(weir).survey_candidate_into(0, Rules.KIND_PLANK, out), "something in the water")
	assert_true(out.reason.begins_with("the deck would run into something at ("), out.reason)
	var bridges := _bridges()
	bridges.survey_candidate_into(0, Rules.KIND_PLANK, out)
	assert_true(bridges.plan_into(out, "neck bridge", _read), "planned")
	assert_false(bridges.survey_candidate_into(0, Rules.KIND_LOG, out), "the same span again")
	assert_equal(out.reason, "too close to the neck bridge", "too close")


func test_a_bridge_is_built_stage_by_stage_and_opens_with_its_last_wu() -> void:
	"""Planned with its stages' WU; work is credited in order and never past a stage; it opens with the
	deck's last WU; an open bridge takes no more."""
	var bridges := _bridges()
	var out := BridgesScript.Survey.new()
	bridges.survey_into(Vector2(19.0, -0.8), Vector2(31.0, -0.8), Rules.KIND_PLANK, out)
	assert_true(bridges.plan_into(out, "ford bridge", _read), "planned")
	var row: int = _read.value
	assert_true(bridges.is_planned(row) and not bridges.is_open(row), "planned, not open")
	assert_equal(bridges.stage_total_wu[row * 3], 80, "two piers: 80 WU")
	assert_equal(bridges.stage_of(row), Rules.STAGE_PIERS, "piers first")
	assert_equal(bridges.add_work(row, 100), 80, "no further than the piers")
	assert_equal(bridges.stage_of(row), Rules.STAGE_BEAMS, "then the beams")
	assert_equal(bridges.pier_points(row).size(), 2, "two piers drawn")
	var left: int = bridges.stage_left_wu(row, Rules.STAGE_BEAMS) + bridges.stage_left_wu(row, Rules.STAGE_DECK)
	assert_equal(bridges.add_work(row, bridges.stage_left_wu(row, Rules.STAGE_BEAMS)) + bridges.add_work(row, 1000), left, "the rest")
	assert_true(bridges.is_open(row), "open with the last WU")
	assert_equal(bridges.percent(row), 100, "all done")
	assert_equal(bridges.add_work(row, 5), 0, "an open bridge takes no work")


func test_a_deck_stands_on_its_footings_and_a_plank_deck_arches() -> void:
	"""The deck's walking height is the footing's ground plus the model's top: 0.26 of 1.2 m at the ends
	of a plank deck, 0.39 at its middle; a hewn log 0.84 of 0.7 m all along."""
	var bridges := _bridges()
	var out := BridgesScript.Survey.new()
	bridges.survey_candidate_into(0, Rules.KIND_PLANK, out)
	bridges.plan_into(out, "neck bridge", _read)
	var ground_a: float = bridges.footing_y_a[0]
	assert_almost_equal(bridges.deck_y_m(0, 0.0), ground_a + 0.26 * 1.2, "the near end")
	var mid_ground: float = (bridges.footing_y_a[0] + bridges.footing_y_b[0]) * 0.5
	assert_almost_equal(bridges.deck_y_m(0, 0.5), mid_ground + 0.39 * 1.2, "the middle")
	assert_true(bridges.approach(0, false).distance_to(bridges.deck_end(0, false)) > 0.89, "the approach stands back")


# --- the router, the planning area and the hook ---------------------------------------------------

func test_crossings_have_their_own_leg_codes_and_a_cap() -> void:
	"""A crossing's leg slot is MAX_SEGMENTS + its row: row 18 walked a to b is code (96 + 18) x 2 = 228,
	b to a 229; a segment's code, even the last segment's reversed, never is one. At most
	MAX_CROSSING_PAIRS crossings are offered to a plan (`crossing_count`), no mouth among them."""
	assert_equal(RouterScript.crossing_code(18, false), (TunnelRules.MAX_SEGMENTS + 18) * 2, "a to b")
	assert_equal(RouterScript.crossing_code(18, true), (TunnelRules.MAX_SEGMENTS + 18) * 2 + 1, "b to a")
	for reversed: bool in [false, true]:
		var code := RouterScript.crossing_code(18, reversed)
		assert_true(RouterScript.is_crossing_code(code) and RouterScript.crossing_row(code) == 18, "row 18 (%d)" % code)
		assert_equal(RouterScript.leg_reversed(code), reversed, "its way across")
	assert_false(RouterScript.is_crossing_code(RouterScript.leg_code(TunnelRules.MAX_SEGMENTS - 1, true)), "a segment")
	assert_false(RouterScript.is_crossing_code(-1), "the surface")
	var router := RouterScript.new()
	for k: int in RouterScript.MAX_CROSSING_PAIRS:
		assert_true(router.add_crossing(k, Vector2(0.0, float(k)), Vector2(1.0, float(k)), 1.0), "crossing %d" % k)
	assert_false(router.add_crossing(99, Vector2.ZERO, Vector2.ONE, 1.0), "one too many")
	assert_equal(router.crossing_count, RouterScript.MAX_CROSSING_PAIRS, "the cap")
	assert_equal(router.mouth_count, 0, "and no mouth offered")
	router.clear_pairs()
	assert_equal(router.crossing_count, 0, "cleared")


func test_the_planning_area_keeps_every_node_inside_it() -> void:
	"""cast_nav.gd's area: a point outside it is never open."""
	var nav := CastNavScript.new()
	var none := PackedVector3Array()
	nav.setup(none)
	nav.area = Rect2(-10.0, -10.0, 20.0, 20.0)
	assert_true(nav.point_open(Vector2(9.0, 0.0), 0.3), "inside")
	assert_false(nav.point_open(Vector2(11.0, 0.0), 0.3), "outside")


func test_the_base_hook_offers_nothing_and_changes_no_walk() -> void:
	"""A cast without the water plans and walks as before: no offer, flat ground, full pace."""
	var hook := HookScript.new()
	assert_false(hook.offers_for(0, Vector2.ZERO, Vector2.ONE, false), "no offer")
	assert_equal(hook.ground_y_m(Vector2(25.0, 0.0)), 0.0, "flat")
	assert_equal(hook.wade_permille(0, Vector2(25.0, 0.0)), 1000, "full pace")
	assert_true(hook.step_leg(null, 0.1), "a leg is over at once")


func test_a_swimmer_is_offered_the_links_and_plans_across_the_run() -> void:
	"""From the west bank by the fisher shelter to the east bank opposite, a swimmer's route takes a swim
	link (a crossing leg); the same trip loaded, or tired, is offered none and walks round by land -- the
	fisher shelter and the store wall the west bank off from the ford, so round the pond's south end."""
	var rig := _rig()
	_swimmer(rig, 0, 1100)
	var space: CastSpaceScript = rig.cast.space()
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.22, path, legs)
	assert_true(space.nav.last_found, "a route")
	assert_true(_has_crossing(legs), "across by a swim link: %s" % legs)
	assert_false(rig.play.crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "loaded: no swim")
	assert_false(rig.play.crossings.offers_for(0, Vector2(0.0, 0.0), Vector2(8.0, 6.0), false), "a trip in the village: nothing")
	rig.play.state.rest[0] = 3999
	assert_false(rig.play.crossings.offers_for(0, WEST_BANK, EAST_BANK, false), "tired: no swim")
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.22, path, legs, true, true)
	assert_false(_has_crossing(legs), "the load walks")
	assert_true(_max_z(path) > 35.0, "round the pond (past z 35)")


func _has_crossing(legs: PackedInt32Array) -> bool:
	"""Whether a route's leg codes cross a crossing."""
	for code: int in legs:
		if RouterScript.is_crossing_code(code):
			return true
	return false


static func _max_z(path: PackedVector2Array) -> float:
	"""The greatest z a route reaches."""
	var most: float = -INF
	for at: Vector2 in path:
		most = maxf(most, at.y)
	return most


func test_a_non_swimmer_walks_round_until_a_bridge_opens_then_takes_it() -> void:
	"""The badger's way from the west bank at the neck to the east bank goes by the ford; once a bridge
	at the neck is open it is offered and taken -- by a carrier too."""
	var rig := _rig()
	var space: CastSpaceScript = rig.cast.space()
	var from := Vector2(19.0, -25.5)
	var to := Vector2(28.0, -25.5)
	assert_false(rig.play.crossings.offers_for(1, from, to, false), "no bridge yet: nothing")
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(1, from, to, 0.22, path, legs)
	assert_true(path.size() > 2 and not _has_crossing(legs), "round by land")
	var out := BridgesScript.Survey.new()
	rig.play.bridges.survey_candidate_into(0, Rules.KIND_PLANK, out)
	rig.play.bridges.plan_into(out, "neck bridge", _read)
	rig.play.bridges.add_work(_read.value, 1000)
	rig.play.bridges.add_work(_read.value, 1000)
	rig.play.bridges.add_work(_read.value, 1000)
	rig.play.crossings.bump()
	assert_true(rig.play.bridges.is_open(_read.value), "open")
	space.plan_path(1, from, to, 0.22, path, legs, true, true)
	assert_true(_has_crossing(legs), "loaded, over the bridge: %s" % legs)


func test_wading_slows_the_walk_and_puts_the_feet_on_the_bed() -> void:
	"""In the ford a walker's pace is 55% and its feet are on the bed (below the surface); on dry ground,
	full pace on the datum."""
	var rig := _rig()
	var crossings: CrossingsScript = rig.play.crossings
	assert_equal(crossings.wade_permille(0, FORD_MID), 550, "wading")
	assert_equal(crossings.wade_permille(0, Vector2(0.0, 0.0)), 1000, "dry")
	assert_true(crossings.ground_y_m(FORD_MID) < -0.18 - 0.19, "the bed, 0.2 m under the 0.18 m surface")
	assert_equal(crossings.ground_y_m(Vector2(0.0, 0.0)), 0.0, "the datum")
	assert_equal(rig.play.state.mode[0], StateScript.MODE_LAND, "back on land")


func test_a_swimmer_crosses_on_its_link_in_the_water_and_climbs_out() -> void:
	"""Ordered from the west bank to the east bank, a swimmer goes down, swims at the surface (in the
	water, off the walking surface, on the swim clip) and holds on the far side, dry."""
	var rig := _rig()
	_swimmer(rig, 0, 1100)
	_place(rig, 0, WEST_BANK)
	var brain := _brain(rig, 0)
	brain.order_move(EAST_BANK)
	var seen := {"water": false, "surface": false, "clip": false, "waded": false, "bed": false}
	var done: bool = _run(rig, func() -> bool:
		if brain.state == BrainScript.State.CROSS and rig.play.state.mode[0] == StateScript.MODE_WADE \
				and rig.play.crossings._leg_phase[0] == CrossingsScript.PHASE_ACROSS:
			seen["waded"] = seen["waded"] or brain.in_water
			seen["bed"] = seen["bed"] or brain.ground_y_m < -0.19
		if brain.in_water:
			seen["water"] = true
			seen["surface"] = seen["surface"] or (absf(brain.ground_y_m + 0.18) < 0.01 and rig.cast.space().resident_in_water[0] == 1)
			seen["clip"] = seen["clip"] or brain.clip == MotionScript.CLIP_SWIM
		return brain.state == BrainScript.State.HOLD and brain.position.distance_to(EAST_BANK) < 0.5)
	assert_true(done, "across and holding: %s" % brain.position)
	assert_true(seen["water"] and seen["surface"] and seen["clip"], "swam at the surface: %s" % seen)
	assert_true(seen["waded"] and seen["bed"], "in the water, waded the shallows on the bed before swimming: %s" % seen)
	assert_false(brain.in_water or rig.cast.space().resident_underground[0] == 1, "out, on the surface")


# --- swims, dives and rescue ----------------------------------------------------------------------

func test_a_swim_order_treads_the_spot_then_tires_home() -> void:
	"""A swimmer sent into the run treads its spot; at rest 1500 (HAZ-003) it swims back and climbs out."""
	var rig := _rig()
	_swimmer(rig, 0, 1100)
	_place(rig, 0, WEST_BANK)
	var said: String = rig.play.order_swim(PackedInt32Array([0]), RUN_MID)
	assert_equal(said, "1 swimming out", said)
	var brain := _brain(rig, 0)
	assert_true(_run(rig, func() -> bool: return brain.task_label() == "treading water"), "treading")
	assert_true(brain.position.distance_to(RUN_MID) < 0.1, "at its spot")
	rig.play.state.rest[0] = 1510
	assert_true(_run(rig, func() -> bool: return brain.order == BrainScript.ORDER_NONE), "home")
	assert_false(brain.in_water, "out of the water")
	assert_false(brain.water_hold, "not rescued: it made it")


func test_a_swim_order_refuses_a_non_swimmer_by_name_and_a_tired_one_at_the_water() -> void:
	"""The badger-like placeholder is refused outright; a tired swimmer walks down and back up, never in."""
	var rig := _rig()
	var said: String = rig.play.order_swim(PackedInt32Array([1]), RUN_MID)
	assert_equal(said, "Can't: Placeholder 1 doesn't swim (it wades only)", said)
	_swimmer(rig, 0, 600)
	_place(rig, 0, WEST_BANK)
	var task := SwimTaskScript.new(rig.play.motion, rig.play.links, RUN_MID)
	_brain(rig, 0).order_task(task)
	rig.play.state.rest[0] = 100
	var wet: Array[bool] = [false]
	var done: bool = _run(rig, func() -> bool:
		wet[0] = wet[0] or _brain(rig, 0).in_water
		return _brain(rig, 0).order == BrainScript.ORDER_NONE)
	assert_true(done, "the swim ended")
	assert_equal(task.refusal, Rules.REFUSE_TIRED, "refused at the water: tired")
	assert_false(wet[0], "never in")


func test_a_planned_dive_waits_for_its_air_goes_down_and_brings_up_a_find() -> void:
	"""An otter at the pond short of air treads until HAZ-002 admits the plan, dives below the surface
	(air spent a tick at a time), searches, surfaces, and hands its find over on the bank."""
	var rig := _rig()
	_swimmer(rig, 0, 1100, true)
	rig.play.state.height_u[0] = 1526
	_place(rig, 0, Vector2(19.0, 28.7))
	var down: float = rig.play.motion.max_dive_m(0, POND_CENTRE)
	assert_true(down > 0.5, "deep enough to dive: %.2f m" % down)
	var got: Array[int] = [-2]
	var task := DiveTaskScript.new(rig.play.motion, rig.play.links, POND_CENTRE, down,
		func(_b: RefCounted) -> int: return 3, func(_b: RefCounted, find: int) -> void: got[0] = find)
	_brain(rig, 0).order_task(task)
	assert_true(_run(rig, func() -> bool: return task.phase >= DiveTaskScript.PHASE_READY), "at the spot")
	task.phase = DiveTaskScript.PHASE_READY
	rig.play.state.air[0] = task.planned_ticks + Rules.AIR_CONTINGENCY_TICKS - 1
	task.step(_brain(rig, 0), 0.01)
	assert_equal(task.refusal, Rules.REFUSE_AIR, "one short: waiting for air")
	assert_equal(task.phase, DiveTaskScript.PHASE_READY, "still at the surface")
	rig.play.state.air[0] += 1
	task.step(_brain(rig, 0), 0.01)
	assert_equal(task.phase, DiveTaskScript.PHASE_DESCEND, "admitted: down")
	var lowest: Array[float] = [0.0]
	var done: bool = _run(rig, func() -> bool:
		lowest[0] = minf(lowest[0], _brain(rig, 0).ground_y_m)
		return got[0] != -2)
	assert_true(done, "home")
	assert_equal(got[0], 3, "the find handed over")
	assert_true(lowest[0] < -0.18 - down + 0.05, "below the surface: %.2f" % lowest[0])
	assert_false(task.cut_short, "the whole search")


func test_a_dive_turns_back_when_the_air_says_so() -> void:
	"""Below with air at B + 300, the diver surfaces without finishing the search (HAZ-002)."""
	var rig := _rig()
	_swimmer(rig, 0, 1100, true)
	var task := DiveTaskScript.new(rig.play.motion, rig.play.links, POND_CENTRE, 1.0, Callable(), Callable())
	var brain := _brain(rig, 0)
	brain.water_place(POND_CENTRE, -0.18, 0.0)
	brain.water_in()
	task.phase = DiveTaskScript.PHASE_SEARCH
	task.down_m = 1.0
	rig.play.state.air[0] = task.back_ticks() + Rules.AIR_CONTINGENCY_TICKS
	task.step(brain, 0.01)
	assert_equal(task.phase, DiveTaskScript.PHASE_ASCEND, "surfacing")
	assert_true(task.cut_short, "cut short")
	assert_equal(task.back_ticks(), 60, "1.0 m at 0.5 m/s: 60 ticks")


func test_a_swimmer_in_difficulty_is_rescued_at_a_landing_and_rests() -> void:
	"""Exhausted in the run it is held, drifting; the nearest free swimmer tows it to a landing, where it
	climbs out, rests, and is free again. Nobody dies."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	_swimmer(rig, 2, 1100)
	var victim := _brain(rig, 0)
	victim.water_place(RUN_MID, -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	assert_true(victim.water_hold and victim.task is Tasks.VictimTask, "held in difficulty")
	assert_true(_brain(rig, 2).task is Tasks.SwimRescue, "the swimmer goes")
	victim.order_move(Vector2.ZERO)
	assert_true(victim.task is Tasks.VictimTask, "an order does not take it from the rescue")
	assert_true(_run(rig, func() -> bool: return victim.task is Tasks.RestTask), "brought ashore")
	assert_equal(rig.play.rescue.rescued, 1, "one rescue")
	assert_true(_run(rig, func() -> bool: return victim.order == BrainScript.ORDER_NONE), "rested")
	assert_false(victim.in_water or victim.water_hold, "free on land")
	assert_true(_feed_has("Placeholder 0 is in difficulty in the stream!", NoticesScript.LEVEL_WARNING), "warned")


func test_with_no_swimmer_free_a_line_is_thrown_from_the_landing() -> void:
	"""Nobody else swims: the nearest resident on land runs to the pond's west landing, throws a line to
	the victim 1.7 m out in the still pond and hauls it in; it rests there."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	var victim := _brain(rig, 0)
	victim.water_place(Vector2(22.5, 29.8), -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var thrower: int = -1
	for who: int in range(1, 6):
		if _brain(rig, who).task is Tasks.LineRescue:
			thrower = who
	assert_true(thrower > 0, "a thrower")
	var line: Array[bool] = [false]
	assert_true(_run(rig, func() -> bool:
		line[0] = line[0] or rig.play.rescue.line_of(_brain(rig, thrower)) != null
		return victim.task is Tasks.RestTask), "hauled in")
	assert_true(line[0], "on the line")
	assert_true(victim.position.distance_to(Vector2(20.8, 29.8)) < 2.0, "at the pond's west landing: %s" % victim.position)


func test_the_rescuer_is_the_nearest_by_route_not_by_straight_line() -> void:
	"""NEAREST BY ROUTE: in the pond 1.8 m off its west landing, a swimmer 16.5 m away in a straight line
	but east of the stream (its way in is the pond's west bank, across the stream: a 28.7 m route and
	swim) loses to one 17.5 m away on the west side (a 17.6 m route and swim). The east swimmer's bound
	(21.5 m) already exceeds that, so only one route is planned."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	var victim := _brain(rig, 0)
	var at := Vector2(22.5, 29.8)
	victim.water_place(at, -0.18, 0.0)
	victim.water_in()
	_swimmer(rig, 1, 1100)
	_place(rig, 1, Vector2(34.0, 18.0))
	_swimmer(rig, 2, 1100)
	_place(rig, 2, Vector2(5.0, 29.0))
	assert_true(Vector2(34.0, 18.0).distance_to(at) < Vector2(5.0, 29.0).distance_to(at), "east is nearer by line")
	assert_true(rig.play.rescue.nearest_free_into(at, 0, true, _read), "a swimmer is free")
	assert_equal(_read.value, 2, "the west swimmer, nearer by route")
	assert_equal(rig.play.rescue.last_plans, 1, "the east one's bound spared its plan")
	var west_in: PackedVector2Array = rig.play.rescue._entry_for(at, Vector2(5.0, 29.0))
	assert_almost_equal(rig.play.rescue.last_cost_m, rig.play.rescue.route_cost_m(2, west_in[0]) + 2.0 * west_in[1].distance_to(at),
		"its way: the route to where it goes in and twice the swim on (water_links.gd SWIM_WEIGHT 2)")
	var east_in: PackedVector2Array = rig.play.rescue._entry_for(at, Vector2(34.0, 18.0))
	assert_true(rig.play.rescue.route_cost_m(1, east_in[0]) > Vector2(34.0, 18.0).distance_to(east_in[0]) + 5.0,
		"the east swimmer's way in is a long way round")
	rig.play.rescue.start_difficulty(0)
	assert_true(_brain(rig, 2).task is Tasks.SwimRescue, "and it is the one sent")
	assert_false(_brain(rig, 1).task is Tasks.SwimRescue, "not the east one")


func test_a_rescuer_the_straight_bound_favours_still_loses_on_its_route() -> void:
	"""The bound only prunes, it never ranks: the east swimmer's bound (21.5 m) is below a west swimmer's
	whole way (24.9 m, 24.5 m by line from its spot at (0, 20)), so the east one is planned too -- and
	its 28.7 m route loses. Two plans."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	var victim := _brain(rig, 0)
	var at := Vector2(22.5, 29.8)
	victim.water_place(at, -0.18, 0.0)
	victim.water_in()
	_swimmer(rig, 1, 1100)
	_place(rig, 1, Vector2(34.0, 18.0))
	_swimmer(rig, 2, 1100)
	_place(rig, 2, Vector2(0.0, 20.0))
	assert_true(rig.play.rescue.nearest_free_into(at, 0, true, _read), "a swimmer is free")
	assert_equal(_read.value, 2, "the west swimmer: 24.9 m against 28.7 m")
	assert_equal(rig.play.rescue.last_plans, 2, "both planned: the east bound did not beat the west route")


func test_a_thrower_is_ranked_by_its_route_to_the_landing_and_the_boxed_in_lose() -> void:
	"""With no swimmer, throwers are ranked by their route to the landing the line is thrown from (not a
	swimmer's way in). One standing inside the hall's footprint has the least straight walk there but no
	route at all: it is planned first, and loses to one farther off who can walk it."""
	var rig := _rig()
	for who: int in rig.cast.actor_count():
		_brain(rig, who).water_hold = who == 0 or who >= 3
	_place(rig, 1, Vector2(0.0, -13.0))
	_place(rig, 2, Vector2(-11.0, 0.0))
	var landing: Vector2 = rig.play.rescue.nearest_landing(RUN_MID)[0]
	assert_true(Vector2(0.0, -13.0).distance_to(landing) < Vector2(-11.0, 0.0).distance_to(landing), "the boxed-in one is nearer by line")
	assert_equal(rig.play.rescue.route_cost_m(1, landing), INF, "and has no route")
	assert_true(rig.play.rescue.nearest_free_into(RUN_MID, 0, false, _read), "a thrower is free")
	assert_equal(_read.value, 2, "the one who can walk there")
	assert_equal(rig.play.rescue.last_plans, 2, "both planned")
	assert_almost_equal(rig.play.rescue.last_cost_m, rig.play.rescue.route_cost_m(2, landing), "its route to the landing")
	assert_true(rig.play.rescue._entry_for(RUN_MID, Vector2(-11.0, 0.0))[0].distance_to(landing) > 1.0, "a swimmer's way in would differ")


func test_route_length_sums_the_legs_from_the_start() -> void:
	"""cast_nav.gd path_length: from the start through each waypoint (the plan's out excludes its start);
	an empty route is 0 long."""
	assert_almost_equal(CastNavScript.path_length(Vector2.ZERO, PackedVector2Array([Vector2(3, 0), Vector2(3, 4)])), 7.0, "3 + 4")
	assert_almost_equal(CastNavScript.path_length(Vector2(1, 1), PackedVector2Array()), 0.0, "no legs")


func test_a_victim_nobody_reaches_washes_ashore_unhurt() -> void:
	"""Past WASH_ASHORE_S with no one coming, the water carries it to the nearest landing."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	var victim := _brain(rig, 0)
	victim.water_place(RUN_MID, -0.18, 0.0)
	victim.water_in()
	for who: int in range(1, 6):
		_brain(rig, who).water_hold = true
	rig.play.rescue.start_difficulty(0)
	var task: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	assert_false(task.engaged, "nobody free")
	var second := _brain(rig, 5)
	_swimmer(rig, 5, 600)
	second.water_hold = false
	second.water_place(Vector2(24.4, 14.0), -0.18, 0.0)
	second.water_in()
	for who: int in range(1, 5):
		_brain(rig, who).water_hold = true
	rig.play.rescue.start_difficulty(5)
	task.waited_s = RescueScript.WASH_ASHORE_S
	rig.play.rescue.victim_task(5).waited_s = RescueScript.WASH_ASHORE_S
	rig.play.rescue.update(RescueScript.DISPATCH_S)
	assert_true(victim.task is Tasks.RestTask, "ashore, resting")
	assert_true(second.task is Tasks.RestTask, "both, in one sweep")
	assert_true(_feed_has("Placeholder 0 washed ashore at the landing, unhurt", NoticesScript.LEVEL_WARNING), "said")


func test_tiring_on_a_link_turns_back_to_the_nearer_bank() -> void:
	"""HAZ-003's return on a crossing leg: short of halfway, the swimmer makes for where it went in and
	plans again from there."""
	var rig := _rig()
	_swimmer(rig, 0, 1100)
	var crossings: CrossingsScript = rig.play.crossings
	var brain := _brain(rig, 0)
	var k: int = 0
	brain.path = PackedVector2Array([rig.play.links.link_land_b[k]])
	brain.path_tunnel = PackedInt32Array([RouterScript.crossing_code(CrossingsScript.LINK_ROW0 + k, false)])
	brain.path_index = 0
	crossings.begin_leg(brain, CrossingsScript.LINK_ROW0 + k, false)
	brain.water_place(rig.play.links.link_water_a[k].lerp(rig.play.links.link_water_b[k], 0.2), -0.18, 0.0)
	crossings.step_leg(brain, 0.0)
	crossings._leg_phase[0] = CrossingsScript.PHASE_ACROSS
	assert_true(crossings.turn_back(brain), "turned")
	assert_equal(brain.path[0], rig.play.links.link_land_a[k], "back to where it went in")


func _feed_has(text: String, level: int) -> bool:
	"""Whether the shared feed holds this full text at this level, from the water."""
	for k: int in _services.notices.count():
		if _services.notices.text(k) == text and _services.notices.level(k) == level \
				and _services.notices.source(k) == NoticesScript.SOURCE_WATER:
			return true
	return false


# --- building bridges ------------------------------------------------------------------------------

func test_building_pays_from_the_one_stores_all_or_nothing() -> void:
	"""A plank footbridge at the neck is refused with the stores short (nothing taken, the way to put it
	right said), and planned when they hold its planks -- which are taken."""
	var rig := _rig()
	rig.play.select_candidate(0)
	var said: String = rig.play.build(Rules.KIND_PLANK, PackedInt32Array())
	assert_true(said.begins_with("Can't build a plank footbridge: it needs 4."), said)
	assert_true(said.ends_with("saw planks at the sawhorse (Woods)"), said)
	assert_equal(_services.stores.plank_milli_u, 0, "nothing taken")
	_services.stores.add_planks(6000)
	said = rig.play.build(Rules.KIND_PLANK, PackedInt32Array())
	assert_equal(said, "Neck bridge planned: waiting for the bridgewright", said)
	var survey := BridgesScript.Survey.new()
	rig.play.bridges.survey_candidate_into(0, Rules.KIND_LOG, survey)
	assert_equal(_services.stores.plank_milli_u, 6000 - Rules.plank_milli(rig.play.bridges.deck_u[0]), "planks taken")
	assert_equal(rig.play.bridges.names[0], "neck bridge", "named for the neck")


func test_a_log_bridge_takes_a_log_from_the_log_stack_without_a_trunk() -> void:
	"""With no woods bound, the 6 U log comes from the stores' wood; short of it, refused."""
	var rig := _rig()
	rig.play.select_candidate(0)
	var before: int = _services.stores.wood_milli_u
	var said: String = rig.play.build(Rules.KIND_LOG, PackedInt32Array([0]))
	assert_equal(said, "Neck bridge: Placeholder 0 goes for the log stack", said)
	assert_equal(_services.stores.wood_milli_u, before - 6000, "6 U of wood")
	_services.stores.wood_milli_u = 1000
	rig.play.select_candidate(1)
	said = rig.play.build(Rules.KIND_LOG, PackedInt32Array())
	assert_true(said.begins_with("Can't build a log bridge: it needs a 6.0 U log"), said)


func test_the_builder_fetches_carries_and_builds_to_open() -> void:
	"""Given the job, a builder walks to the plank stack, carries the planks to the near end and works
	the stages until the bridge is open; its skill XP grows at 10 a WU."""
	var rig := _rig()
	_services.stores.add_planks(6000)
	rig.play.select_candidate(0)
	rig.play.build(Rules.KIND_PLANK, PackedInt32Array([3]))
	var carried: Array[bool] = [false]
	var actor := rig.cast.actor(3) as DemoActorScript
	var done: bool = _run(rig, func() -> bool:
		carried[0] = carried[0] or (rig.play.crew.step[0] == CrewScript.STEP_CARRY and actor.holding())
		return rig.play.bridges.is_open(0), 12000)
	assert_true(done, "open: %d%%" % rig.play.bridges.percent(0))
	assert_true(carried[0], "carried the planks")
	var wu: int = rig.play.bridges.stage_total_wu[1] + rig.play.bridges.stage_total_wu[2]
	assert_equal(rig.play.crew.xp[3], wu * 10, "10 XP a WU")
	assert_equal(rig.play.crew.builder[0], CrewScript.NOBODY, "the builder is free")
	assert_true(_feed_has("The neck bridge is open: Placeholder 3 built it; anyone may cross it now, carrying or not", NoticesScript.LEVEL_NOTE), "said")


func test_the_bridgewright_starts_skilled_and_skill_only_changes_the_time() -> void:
	"""LORE-P12 / DEC-041: the beaver starts at level 6 (180000 XP), anybeast at 0; §5.3's factor only."""
	var rig := _rig()
	var crew: CrewScript = rig.play.crew
	crew.xp[0] = Rules.BRIDGEWRIGHT_XP
	assert_equal(crew.level_of(0), 6, "level 6")
	assert_equal(crew.level_of(1), 0, "level 0")
	assert_equal(crew.line_of(0), "Bridging 6 · XP 180000/245000", "the panel's line")
	assert_equal(crew.short_of(1), "bridge 0", "the list's")
	assert_equal(Rules.work_usec(100, 6), 7692307, "10 s / 1.300, floored")
	assert_equal(Rules.work_usec(100, 0), 10000000, "10 s at level 0")
	assert_equal(CrewScript.stage_clip(Rules.STAGE_BEAMS), &"pull_radish", "beams hauled")


# --- finds, bounds and obstacles -------------------------------------------------------------------

func test_the_sunken_finds_follow_the_dives_deterministically() -> void:
	"""FIND_SEED 92: the first eight dives bring up a stone, a hook, silt, a relic, silt, a float, a cup,
	silt; a relic goes to the stores' finds, a stone 0.25 U to its stone."""
	var finds: Array[int] = []
	for dive: int in range(1, 9):
		finds.append(WaterplayScript.find_of(dive))
	assert_equal(finds, [1, 3, 0, 5, 0, 2, 4, 0] as Array[int], "the sequence")
	var rig := _rig()
	var stone: int = _services.stores.stone_milli_u
	rig.play.find_home(_brain(rig, 0), WaterplayScript.FIND_RELIC)
	rig.play.find_home(_brain(rig, 0), WaterplayScript.FIND_STONE)
	assert_equal(_services.stores.finds[FindsScript.FIND_RELIC], 1, "a relic in the finds")
	assert_equal(_services.stores.stone_milli_u, stone + 250, "a stone")
	assert_equal(rig.play.finds[WaterplayScript.FIND_RELIC], 1, "tallied")


func test_the_walking_area_widens_over_the_water() -> void:
	"""x -20..36 m and z -34..42 m: the stream from above the neck, the far bank and round the pond."""
	var walk: AABB = WaterplayScript.walk_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	assert_almost_equal(walk.position.x, -20.0, "west")
	assert_almost_equal(walk.end.x, 36.0, "east")
	assert_almost_equal(walk.position.z, -34.0, "north")
	assert_almost_equal(walk.end.z, 42.0, "south")


func test_the_mill_and_the_bank_props_become_obstacles_on_the_widened_ground() -> void:
	"""The mill (27.9, -19.5) stood beyond the old square's reach: its footprint is now walked round, as
	are the rod, the net and the rack on the bank."""
	var circles: Array[Vector3] = WaterplayScript.land_obstacles()
	var mill: bool = false
	for circle: Vector3 in circles:
		mill = mill or Vector2(circle.x, circle.z).distance_to(Vector2(27.9, -19.5)) < 3.0
	assert_true(mill, "the mill")
	for prop: Vector3 in [Vector3(21.3, 0.3, 9.7), Vector3(21.0, 0.45, 5.2), Vector3(20.9, 0.6, 11.6)]:
		assert_true(circles.has(prop), "the bank prop at %s" % prop)


# --- the panels, the overlay and the hooks ---------------------------------------------------------

func test_the_right_column_has_a_water_tab_and_the_feed_a_water_source() -> void:
	"""A fourth tab, "Water"; showing it hides the others; the feed names the water's lines "Water"."""
	var zone: DetailZoneScript = _keep(DetailZoneScript.new()) as DetailZoneScript
	zone.build()
	var panels: Array[PanelScript] = []
	for k: int in 4:
		var panel: PanelScript = _keep(PanelScript.new()) as PanelScript
		panel.build()
		zone.add_panel(k, panel)
		panels.append(panel)
	zone.show_panel(DetailZoneScript.PANEL_WATER)
	assert_true(panels[3].is_shown() and not panels[0].is_shown() and not panels[2].is_shown(), "the water alone")
	assert_equal(DetailZoneScript.TAB_TEXT[DetailZoneScript.PANEL_WATER], "Water", "its tab")
	assert_equal(NoticesScript.SOURCE_NAMES[NoticesScript.SOURCE_WATER], "Water", "the feed's source")


func test_the_water_panel_shows_the_site_and_disables_what_cannot_be_built() -> void:
	"""The neck's site lists its span and both kinds' cost; a kind the stores cannot pay for is disabled (its action
	card, decision 0331); with a bridge standing there it says so and neither kind can be built; consent shows on its
	button."""
	var rig := _rig()
	rig.play.select_candidate(0)
	rig.play.refresh_panel()
	var panel: PanelScript = rig.play.panel
	assert_equal(panel.line(&"site_title"), "Bridge site 1 of 3: the neck, the stream's narrowest", "title")
	assert_true(panel.line(&"site").contains("Plank footbridge: 4.") and panel.line(&"site").contains("Log bridge: one 6.0 U log (from the log stack)"), panel.line(&"site"))
	assert_true(panel.button(PanelScript.ACTION_BUILD_PLANK).disabled, "plank: no planks in the stores (decision 0331)")
	assert_true(panel.button(PanelScript.ACTION_BUILD_PLANK).tooltip_text.contains("Planks: have 0.0 U"), "its card says why")
	_services.stores.add_planks(6000)
	rig.play.refresh_panel()
	assert_false(panel.button(PanelScript.ACTION_BUILD_PLANK).disabled, "plank: may, once the planks are in")
	rig.play.build(Rules.KIND_PLANK, PackedInt32Array())
	rig.play.refresh_panel()
	assert_equal(panel.line(&"site"), "Neck bridge, a plank footbridge: 0% built — waiting for a builder", panel.line(&"site"))
	assert_true(panel.button(PanelScript.ACTION_BUILD_PLANK).disabled and panel.button(PanelScript.ACTION_BUILD_LOG).disabled, "none")
	assert_equal(panel.button(PanelScript.ACTION_CONSENT).text, "Swim shortcuts: on", "consent on")
	assert_equal(rig.play.toggle_consent(PackedInt32Array()), "Swim shortcuts off for everyone", "toggled")


func test_the_party_panel_shows_each_owners_skills_a_line_apiece() -> void:
	"""Alone, each provider's words (and each line of them) is a line of the panel."""
	var lines: PackedStringArray = PartyPanelScript.party_lines([{"name": "Otter", "species": "Otter", "state": "diving",
		"skills": "Felling 0\nBridging 0\nBreath 900/1200 · stamina 80%"}] as Array[Dictionary])
	assert_equal(lines, PackedStringArray(["Otter", "Otter", "diving", "Felling 0", "Bridging 0", "Breath 900/1200 · stamina 80%"]), "a line each")
	assert_equal(PartyPanelScript.state_text(BrainScript.ACTIVITY_CROSSING, &"swim", ""), "crossing the water", "crossing")


func test_the_overlay_paints_the_zones_for_the_selected_body() -> void:
	"""Selecting the 2.55 m badger shows its zones: wade to 0.64 m, dive past 2.55 m."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	world.build({"world": {}, "cast": {}})
	var water: DemoWaterScript = _keep(DemoWaterScript.new()) as DemoWaterScript
	water.build({"world": {}, "cast": {}}, world)
	var overlay: OverlayScript = water.overlay()
	overlay.set_body("Badger quarryman (2.55 m)", 2611)
	assert_equal(overlay.body_height_u, 2611, "the badger's height")
	assert_true(OverlayScript.legend_text("Badger quarryman (2.55 m)", 2611).contains("WADE <= 0.64 m   blue SWIM <= 2.55 m"), "its thresholds")


func test_the_actor_loads_the_water_clips() -> void:
	"""swim and tread_water for everyone, dive for the otters (decision 0203's clips)."""
	for clip: StringName in [&"swim", &"tread_water", &"dive"]:
		assert_true(DemoActorScript.CLIPS.has(clip), "%s is loaded" % clip)


func test_an_emergency_takes_a_resident_off_its_crossing_where_it_is() -> void:
	"""interrupt_to_task: no walk first, the task runs from here; the route is dropped."""
	var rig := _rig()
	var brain := _brain(rig, 0)
	var before: Vector2 = brain.position
	var task := Tasks.VictimTask.new(rig.play.motion, 0.0)
	brain.interrupt_to_task(task)
	assert_equal(brain.state, BrainScript.State.TASK, "at once")
	assert_equal(brain.position, before, "where it was")
	assert_true(brain.water_hold and brain.path.is_empty(), "held, no route")


# --- more of the movement ---------------------------------------------------------------------------

func test_a_walker_wades_the_ford_on_its_bed_at_its_wading_pace() -> void:
	"""Walking across the ford, a resident's feet go down onto the bed (under the 0.18 m surface) and it
	covers ground at 55% of its walk, the clip slowed to match (55% of its walk's own rate over its gait,
	decision 0205); it is marked wading, never swimming."""
	var rig := _rig()
	_place(rig, 1, Vector2(19.5, -0.8))
	var brain := _brain(rig, 1)
	brain.order_move(Vector2(30.5, -0.8))
	var seen := {"bed": false, "pace": false, "wading": false, "swam": false}
	var done: bool = _run(rig, func() -> bool:
		if absf(brain.position.x - FORD_MID.x) < 1.0:
			seen["bed"] = seen["bed"] or brain.ground_y_m < -0.3
			seen["pace"] = seen["pace"] or (brain.state == BrainScript.State.WALK and absf(brain.clip_speed - 0.55 * brain.gait_rate()) < 0.01)
			seen["wading"] = seen["wading"] or rig.play.state.mode[1] == StateScript.MODE_WADE
		seen["swam"] = seen["swam"] or brain.in_water
		return brain.state == BrainScript.State.HOLD and brain.position.distance_to(Vector2(30.5, -0.8)) < 0.5)
	assert_true(done, "across: %s" % brain.position)
	assert_true(seen["bed"] and seen["pace"] and seen["wading"], "waded: %s" % seen)
	assert_false(seen["swam"], "never in the water")


func test_an_order_in_the_water_swims_ashore_first() -> void:
	"""A swimmer treading in the run, ordered to a point in the village, swims to its nearest connection,
	climbs out there and carries the order out from the bank (MOVE-REQ-007's reading for a swim)."""
	var rig := _rig()
	_swimmer(rig, 0, 1100)
	_place(rig, 0, WEST_BANK)
	rig.play.order_swim(PackedInt32Array([0]), RUN_MID)
	var brain := _brain(rig, 0)
	assert_true(_run(rig, func() -> bool: return brain.task_label() == "treading water"), "out treading")
	brain.order_move(Vector2(12.0, 12.0))
	assert_equal(brain.state, BrainScript.State.CROSS, "a leg of its own")
	assert_equal(rig.play.crossings.leg_text(brain), "swimming ashore", "ashore first")
	assert_true(_run(rig, func() -> bool: return brain.state == BrainScript.State.HOLD), "then the order")
	assert_true(brain.position.distance_to(Vector2(12.0, 12.0)) < 0.6 and not brain.in_water, "there, dry")


func test_a_flood_sweeps_the_weaker_swimmers_off_their_links() -> void:
	"""In full flood the stream runs 0.8 m/s: a mouse (0.6 m/s) cannot hold a line across it -- no link
	is costed for it -- while an otter (1.1 m/s) still can."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	_swimmer(rig, 2, 1100)
	var crossings: CrossingsScript = rig.play.crossings
	var k: int = 0
	assert_true(crossings.link_cost_m(0, k) < INF, "the mouse, before the flood")
	rig.play.motion.flood_permille = 1000
	assert_equal(crossings.link_cost_m(0, k), INF, "the mouse, in flood")
	assert_true(crossings.link_cost_m(2, k) < INF, "the otter, in flood")


func test_treading_holds_the_spot_and_drifting_never_goes_ashore() -> void:
	"""A swimmer faster than the flow treads its spot still; one in difficulty drifts downstream with the
	flow, but a step that would put it on dry land is not taken."""
	var rig := _rig()
	_swimmer(rig, 0, 1100)
	var brain := _brain(rig, 0)
	brain.water_place(RUN_MID, -0.18, 0.0)
	rig.play.motion.tread(brain, RUN_MID, 1.0)
	assert_equal(brain.position, RUN_MID, "held")
	assert_equal(brain.clip, MotionScript.CLIP_TREAD, "treading")
	rig.play.motion.drift(brain, 1.0)
	assert_true(brain.position != RUN_MID, "carried by the flow")
	assert_equal(rig.play.motion._keep_wet(RUN_MID, WEST_BANK), RUN_MID, "a step onto land is not taken")
	assert_equal(rig.play.motion._keep_wet(RUN_MID, FORD_MID), FORD_MID, "a step in the water is")


func test_the_stream_turning_cold_is_announced_once_by_the_day() -> void:
	"""The water follows the day's temperature: cold below 10.0 C doubles the drain, and the feed says so
	once when it turns (and when it turns mild again)."""
	var rig := _rig()
	_services.weather._day_tenths = 120
	rig.play.step(0)
	assert_false(rig.play.motion.cold, "12.0 C: mild")
	_services.weather._day_tenths = 55
	rig.play.step(0)
	rig.play.step(0)
	assert_true(rig.play.motion.cold, "5.5 C: cold")
	assert_true(_feed_has("The water is cold today (5.5 °C): swimmers tire twice as fast", NoticesScript.LEVEL_WARNING), "warned")
	var posts: int = _services.notices.count()
	rig.play.step(0)
	assert_equal(_services.notices.count(), posts, "said once")
	assert_equal(TextScript.sent_line(0, "diving", PackedStringArray(["X doesn't dive"])), "Can't: X doesn't dive", "refused")
	assert_equal(TextScript.sent_line(2, "diving", PackedStringArray(["X doesn't dive"])), "2 diving — X doesn't dive", "partly")
	assert_equal(rig.play.text.cold_line(true).begins_with("The water is cold today ("), true, "the cold line")


func test_an_otter_is_refused_a_dive_where_the_water_is_not_deeper_than_it_is_tall() -> void:
	"""The run is 1.40 m deep: a swim zone for a 1.49 m otter, not a dive -- refused with the depths; the
	pond's 1.9 m is a dive; a non-diver is refused by name."""
	var rig := _rig()
	_swimmer(rig, 0, 1100, true)
	rig.play.state.height_u[0] = 1526
	assert_equal(rig.play.dive_refusal(0, RUN_MID), Rules.REFUSE_TOO_SHALLOW, "the run")
	assert_true(rig.play.text.refusal_words(0, Rules.REFUSE_TOO_SHALLOW, RUN_MID).ends_with("(1.40 m deep; a dive needs over 1.49 m)"),
		rig.play.text.refusal_words(0, Rules.REFUSE_TOO_SHALLOW, RUN_MID))
	assert_equal(rig.play.dive_refusal(0, POND_CENTRE), Rules.REFUSE_NONE, "the pond")
	assert_equal(rig.play.dive_refusal(1, POND_CENTRE), Rules.REFUSE_CANNOT_DIVE, "a non-diver")
	assert_true(rig.play.wants_dive(PackedInt32Array([1, 0]), POND_CENTRE), "a click there dives")
	assert_false(rig.play.wants_dive(PackedInt32Array([0]), RUN_MID), "a click on the run swims")


func test_a_held_resident_takes_no_order_or_release() -> void:
	"""While the rescue holds it, move, work, dig, task and release orders are not taken."""
	var rig := _rig()
	var brain := _brain(rig, 0)
	brain.water_hold = true
	var order: int = brain.order
	brain.order_move(Vector2(5.0, 5.0))
	brain.order_work(0, 0)
	brain.order_task(TaskScript.new())
	brain.order_dig(0, 1)
	brain.release()
	assert_equal(brain.order, order, "nothing taken")
	brain.water_hold = false
	brain.order_move(Vector2(5.0, 5.0))
	assert_equal(brain.order, BrainScript.ORDER_MOVE, "free again: taken")


func test_in_the_water_is_off_the_walking_surface_but_not_in_a_bore() -> void:
	"""set_in_water: nobody separates from or plans round a swimmer, and it holds no place in a bore."""
	var rig := _rig()
	var space: CastSpaceScript = rig.cast.space()
	space.set_in_water(0, true)
	assert_equal(space.resident_in_water[0], 1, "in the water")
	assert_equal(space.resident_underground[0], 1, "off the surface")
	assert_equal(space.resident_tunnel[0], -1, "in no bore")
	space.set_in_water(0, false)
	assert_equal(space.resident_underground[0] + space.resident_in_water[0], 0, "back")


func test_a_waiting_bridge_is_taken_by_the_routine_bridgewright() -> void:
	"""Planned with nobody selected, a bridge waits; a wandering member of the routine crew takes it up."""
	var rig := _rig()
	_services.stores.add_planks(6000)
	rig.play.crew.set_crew(PackedInt32Array([4]))
	rig.play.select_candidate(0)
	rig.play.build(Rules.KIND_PLANK, PackedInt32Array())
	assert_equal(rig.play.crew.builder[0], CrewScript.NOBODY, "waiting")
	assert_true(_run(rig, func() -> bool: return rig.play.crew.builder[0] == 4, 200), "taken up")
	assert_true(_feed_has("Placeholder 4 takes up the neck bridge", NoticesScript.LEVEL_NOTE), "said")


func test_a_builder_called_away_leaves_the_bridge_where_it_got_to() -> void:
	"""Ordered elsewhere mid-job, the builder drops it: no builder, its work kept, waiting again."""
	var rig := _rig()
	_services.stores.add_planks(6000)
	rig.play.select_candidate(0)
	rig.play.build(Rules.KIND_PLANK, PackedInt32Array([3]))
	rig.play.bridges.add_work(0, 20)
	assert_true(_run(rig, func() -> bool: return rig.play.crew.issued[0] == 1, 50), "under way")
	_brain(rig, 3).order_move(Vector2(0.0, 0.0))
	rig.play.step(100000)
	assert_equal(rig.play.crew.builder[0], CrewScript.NOBODY, "dropped")
	assert_equal(rig.play.crew.step[0], CrewScript.STEP_WAITING, "waiting")
	assert_equal(rig.play.bridges.stage_done_wu[1], 20, "its work kept")


# --- nothing stands on the water --------------------------------------------------------------------

func test_nothing_is_sent_to_stand_in_the_water() -> void:
	"""Playtest: "animals were walking on the water idle". Every work slot of the village and the water
	is on dry ground; the clearance every spot chooser asks counts the water's edge (negative in the
	water, the formation, a job's spot, deadfall, heaps and tunnel step-outs all ask it); an order to
	the ford stands its residents on dry ground; the ford is an ordinary move, not a swim."""
	var rig := _rig()
	var space: CastSpaceScript = rig.cast.space()
	for poi: int in space.poi_position.size():
		for slot: int in space.poi_capacity[poi]:
			var at: Vector2 = space.slot_position(poi, slot)
			assert_false(_map().is_water(MotionScript.u_of(at)), "%s slot %d is dry" % [space.poi_names[poi], slot])
	assert_true(space.obstacle_clearance(FORD_MID) < 0.0, "in the ford: inside the water")
	assert_true(space.obstacle_clearance(RUN_MID) < 0.0, "in the run: inside the water")
	var spots: Dictionary = rig.cast.order_move(PackedInt32Array([1, 3]), Vector3(FORD_MID.x, 0.0, FORD_MID.y))
	assert_true(bool(spots["ok"]), "the order snaps")
	for who: int in [1, 3]:
		var goal: Vector2 = _brain(rig, who).goal()
		assert_true(space.crossings.water_clearance_m(goal) >= _brain(rig, who).radius, "%d stands dry at %s" % [who, goal])
	assert_false(rig.play.is_swim_water(FORD_MID), "the ford: a move")
	assert_true(rig.play.is_swim_water(RUN_MID), "the run: a swim")


func test_a_resident_let_down_off_a_root_mound_stands_on_the_carved_bank() -> void:
	"""forest_lift.gd lets a resident down onto the ground where it stands -- the bank's carved slope,
	not the datum over the water's edge."""
	var rig := _rig()
	var bank := Vector2(21.8, 12.0)
	var carved: float = rig.play.crossings.ground_y_m(bank)
	assert_true(carved < -0.05, "a bank slope below the datum: %.3f" % carved)
	var lift := LiftScript.new()
	var stand := StandScript.new()
	lift.configure(stand, rig.cast)
	lift.enabled = true
	lift._lifted[0] = 1
	_brain(rig, 0).water_place(bank, 0.3, 0.0)
	lift.apply()
	assert_almost_equal(_brain(rig, 0).ground_y_m, carved, "on the carved bank")


# --- the drawings -----------------------------------------------------------------------------------

func test_a_bridge_is_drawn_stage_by_stage() -> void:
	"""Planned: nothing but its holder; piers rise with the piers stage; beams with the beams; loose
	planks while the deck is laid; finished, the model's segments -- one between each pair of piers --
	and no beams (unstaged: boxes)."""
	var rig := _rig()
	var view: BridgeViewScript = rig.play.bridge_view
	var bridges: BridgesScript = rig.play.bridges
	var out := BridgesScript.Survey.new()
	bridges.survey_into(Vector2(19.0, -0.8), Vector2(31.0, -0.8), Rules.KIND_PLANK, out)
	bridges.plan_into(out, "ford bridge", _read)
	view.refresh()
	var holder: Node3D = view.get_child(0) as Node3D
	assert_true(holder.visible and holder.get_child_count() == 0, "planned: an empty site")
	bridges.add_work(0, 80)
	view.refresh()
	assert_equal(_live_children(holder), 2, "two piers up")
	bridges.add_work(0, bridges.stage_left_wu(0, Rules.STAGE_BEAMS))
	view.refresh()
	assert_equal(_live_children(holder), 4, "two piers, two beams")
	bridges.add_work(0, bridges.stage_total_wu[2] / 2)
	view.refresh()
	assert_true(_live_children(holder) > 10, "loose planks laid: %d" % _live_children(holder))
	bridges.add_work(0, 1000)
	view.refresh()
	assert_equal(_live_children(holder), 5, "two piers and three deck segments, a joint on each pier")
	var piers: PackedVector2Array = bridges.pier_points(0)
	for pier: Vector2 in piers:
		assert_true(_map().is_water(MotionScript.u_of(pier)), "a pier in the water at %s" % pier)


func _live_children(node: Node) -> int:
	"""Children not queued for deletion."""
	var n: int = 0
	for child: Node in node.get_children():
		n += 0 if child.is_queued_for_deletion() else 1
	return n


func test_swimmers_show_ripples_divers_bubbles_and_a_thrower_its_line() -> void:
	"""At the surface a ripple ring; below it bubbles and a ring over it; on land neither."""
	var rig := _rig()
	var view: SwimViewScript = rig.play.swim_view
	var actor := rig.cast.actor(0) as DemoActorScript
	view._place(0, actor, 1.0)
	assert_false(view.ripple_shown(0) or view.bubbles_shown(0), "on land: nothing")
	actor.brain.water_place(RUN_MID, -0.18, 0.0)
	actor.brain.water_in()
	rig.play.state.set_mode(0, StateScript.MODE_SWIM)
	view._place(0, actor, 1.0)
	assert_true(view.ripple_shown(0) and not view.bubbles_shown(0), "swimming: a ripple")
	rig.play.state.set_mode(0, StateScript.MODE_DIVE)
	view._place(0, actor, 1.0)
	assert_true(view.bubbles_shown(0) and view.ripple_shown(0), "diving: bubbles, and a ring over it")
	assert_false(view.line_shown(0), "no line out")


func test_a_route_through_the_ford_costs_its_wading() -> void:
	"""A leg across the ford costs its wet stretch again at 1000 / 550 - 1 of its length -- about 6.4 m of
	water, so 5.2 m more; a dry leg costs nothing more; the router adds it to a route's length."""
	var rig := _rig()
	var crossings: CrossingsScript = rig.play.crossings
	var extra: float = crossings.wade_extra_m(Vector2(19.0, -0.8), Vector2(31.0, -0.8))
	assert_true(extra > 4.8 and extra < 5.8, "the ford: %.2f m more" % extra)
	assert_equal(crossings.wade_extra_m(Vector2(0.0, 0.0), Vector2(10.0, 0.0)), 0.0, "dry: nothing")
	var router := RouterScript.new()
	var route := PackedVector2Array([Vector2(31.0, -0.8)])
	assert_almost_equal(router._route_cost(Vector2(19.0, -0.8), route), 12.0, "no hook: its length")
	router.wade_cost = crossings.wade_extra_m
	assert_almost_equal(router._route_cost(Vector2(19.0, -0.8), route), 12.0 + extra, "with the ford's wading")


func test_a_tow_goes_to_a_landing_it_can_reach_against_the_flow() -> void:
	"""From the run, a slow tow (a squirrel's 0.33 m/s) cannot make headway up the 0.4 m/s stream to the
	ford's west landing, so it goes down to the pond's west landing; a strong one (an otter's 0.66 m/s)
	takes the nearer landing upstream. (The fisher shelter's and the boathouse's landings stand in their
	buildings' footprints on the widened ground and are not used.)"""
	var rig := _rig()
	var map := _map()
	var weak: PackedVector2Array = rig.play.rescue.tow_landing(RUN_MID, 330)
	var strong: PackedVector2Array = rig.play.rescue.tow_landing(RUN_MID, 660)
	assert_true(map.landing_index_into(&"pond_west", _read), "the pond's west landing")
	var pond: Vector2 = Vector2(WaterRules.to_m(map.landing_land(_read.value).x), WaterRules.to_m(map.landing_land(_read.value).y))
	assert_true(map.landing_index_into(&"ford_west", _read), "the ford's west landing")
	var ford: Vector2 = Vector2(WaterRules.to_m(map.landing_land(_read.value).x), WaterRules.to_m(map.landing_land(_read.value).y))
	assert_true(weak[0].distance_to(pond) < 0.01, "slow: downstream to the pond (%s)" % weak[0])
	assert_true(strong[0].distance_to(ford) < 0.01, "strong: up to the ford (%s)" % strong[0])
	assert_equal(rig.play.links.landing_ok, PackedByteArray([0, 1, 1, 1, 0, 1]), "shelter and boathouse landings unused")


func test_a_site_is_surveyed_again_when_it_or_the_bridges_change() -> void:
	"""The panel's surveys are kept between refreshes: the same site answers alike, another site answers
	for itself, and a bridge planned at the site makes it too close to build again."""
	var rig := _rig()
	rig.play.select_candidate(0)
	var neck: int = rig.play.survey_site(Rules.KIND_PLANK).span_u
	assert_true(rig.play.survey_site(Rules.KIND_PLANK).ok, "the neck takes a plank footbridge")
	rig.play.select_candidate(1)
	assert_true(rig.play.survey_site(Rules.KIND_PLANK).span_u > neck, "the upper site is its own, wider span")
	rig.play.select_candidate(0)
	assert_equal(rig.play.survey_site(Rules.KIND_PLANK).span_u, neck, "the neck again")
	_services.stores.add_planks(6000)
	rig.play.build(Rules.KIND_PLANK, PackedInt32Array())
	var after: BridgesScript.Survey = rig.play.survey_site(Rules.KIND_LOG)
	assert_false(after.ok, "a bridge stands there now")
	assert_equal(after.reason, "too close to the neck bridge", after.reason)


func test_the_water_panel_is_filled_only_while_it_is_shown() -> void:
	"""Its surveys cost milliseconds, so a hidden panel is left alone; shown, it fills in its first frame
	(not a refresh beat later: never an empty or stale panel)."""
	var rig := _rig()
	rig.play.panel.set_zone(false, 0.0)
	var first: String = rig.play.panel.line(&"site_title")
	rig.play.select_candidate(1)
	rig.play._process(1.0)
	assert_equal(rig.play.panel.line(&"site_title"), first, "hidden: left as it was")
	rig.play.panel.set_zone(true, 0.0)
	rig.play._process(0.01)
	assert_true(rig.play.panel.line(&"site_title").begins_with("Bridge site 2 of 3"), rig.play.panel.line(&"site_title"))
	rig.play.rescue.rescued = 5
	rig.play._process(0.01)
	assert_equal(rig.play.panel.line(&"swimmers_title"), "Swimmers — 0 in the water", "then on its beat, not every frame")
	rig.play._process(WaterplayScript.PANEL_REFRESH_S)
	assert_equal(rig.play.panel.line(&"swimmers_title"), "Swimmers — 0 in the water · 5 rescues so far", "the next beat")


func test_lookups_refuse_when_there_is_nothing_to_find() -> void:
	"""No bridge, no trunk, no free rescuer and no listed species are refusals, never a -1 index."""
	var rig := _rig()
	rig.play.select_candidate(0)
	assert_false(rig.play.bridge_at_into(Vector2.ZERO, _read), "no bridge here")
	assert_equal(_read.error, "NO_BRIDGE_HERE", _read.error)
	assert_false(rig.play.bridge_on_site_into(_read), "none on the site")
	assert_false(rig.play.ready_trunk_into(Vector2.ZERO, _read), "no woods bound")
	assert_equal(_read.error, "NO_WOODS", _read.error)
	_services.stores.add_planks(6000)
	rig.play.build(Rules.KIND_PLANK, PackedInt32Array())
	assert_true(rig.play.bridge_on_site_into(_read) and _read.value == 0, "row 0 on the site")
	var mid: Vector2 = (rig.play.bridges.shore_a[0] + rig.play.bridges.shore_b[0]) * 0.5
	assert_true(rig.play.bridge_at_into(mid, _read) and _read.value == 0, "row 0 under the pointer")
	for who: int in rig.cast.actor_count():
		_brain(rig, who).water_hold = true
	assert_false(rig.play.rescue.nearest_free_into(Vector2.ZERO, -1, false, _read), "everyone held")
	assert_equal(_read.error, "NO_FREE_RESCUER", _read.error)
	_brain(rig, 4).water_hold = false
	assert_true(rig.play.rescue.nearest_free_into(Vector2.ZERO, -1, false, _read) and _read.value == 4, "the one free")
	assert_false(rig.play.rescue.nearest_free_into(Vector2.ZERO, -1, true, _read), "and it does not swim")
	assert_equal([Rules.has_species("Dragon"), Rules.swim_mm_s_of("Dragon"), Rules.swim_words("Dragon")],
		[false, 0, "wades only"], "an unlisted species wades only")


func test_a_rescuer_stands_down_once_its_victim_is_ashore() -> void:
	"""A victim a swimmer is on its way to is given WASH_ASHORE_ENGAGED_S, not WASH_ASHORE_S, and then
	still washes ashore (the rescuer never got there); the swimmer then gives up, never entering the
	water, and the rescue is counted once."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	_swimmer(rig, 2, 1100)
	var victim := _brain(rig, 0)
	victim.water_place(RUN_MID, -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var rescuer := _brain(rig, 2)
	assert_true(rescuer.task is Tasks.SwimRescue and rig.play.rescue.victim_task(0).engaged, "engaged")
	rig.play.rescue.victim_task(0).waited_s = RescueScript.WASH_ASHORE_S
	rig.play.rescue.update(RescueScript.DISPATCH_S)
	assert_true(victim.task is Tasks.VictimTask, "a rescuer is coming: not yet")
	rig.play.rescue.victim_task(0).waited_s = RescueScript.WASH_ASHORE_ENGAGED_S
	rig.play.rescue.update(RescueScript.DISPATCH_S)
	assert_true(victim.task is Tasks.RestTask, "washed ashore though a rescuer was coming")
	var wet: Array[bool] = [false]
	assert_true(_run(rig, func() -> bool:
		wet[0] = wet[0] or rescuer.in_water
		return not (rescuer.task is Tasks.SwimRescue), 50), "stood down")
	assert_false(wet[0], "never went in")
	assert_equal(rig.play.rescue.rescued, 1, "counted once")


func test_a_line_thrower_stands_down_once_its_victim_is_ashore() -> void:
	"""The thrower running to the landing arrives to find the victim washed ashore: it throws nothing and
	hauls nobody (the resting victim is never towed again)."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	var victim := _brain(rig, 0)
	victim.water_place(Vector2(22.5, 29.8), -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	rig.play.rescue.victim_task(0).waited_s = RescueScript.WASH_ASHORE_ENGAGED_S
	rig.play.rescue.update(RescueScript.DISPATCH_S)
	assert_true(victim.task is Tasks.RestTask, "washed ashore")
	var towed: Array[bool] = [false]
	assert_true(_run(rig, func() -> bool:
		towed[0] = towed[0] or rig.play.state.mode[0] == StateScript.MODE_TOWED
		for who: int in range(1, 6):
			if _brain(rig, who).task is Tasks.LineRescue:
				return false
		return true, 1200), "every thrower stood down")
	assert_false(towed[0], "the resting victim was not hauled")
	assert_equal(rig.play.rescue.rescued, 1, "counted once")


func test_a_tow_names_its_landing_at_the_tow_speed() -> void:
	"""The landing is asked for from where the victim is taken in hand, at TOW_PERMILLE of the rescuer's
	own speed (an otter's 1100 mm/s: 660)."""
	var rig := _rig()
	_swimmer(rig, 2, 1100)
	var asked: Array[int] = []
	var landing_for := func(_at: Vector2, mm_s: int) -> PackedVector2Array:
		asked.append(mm_s)
		return PackedVector2Array([Vector2(20.0, 11.0), Vector2(22.0, 11.0)])
	var task := Tasks.SwimRescue.new(rig.play.motion, _brain(rig, 0), Tasks.VictimTask.new(rig.play.motion, 0.0),
		PackedVector2Array([WEST_BANK, RUN_MID]), Callable(), landing_for)
	task._start_tow(_brain(rig, 2))
	assert_equal(asked, [660] as Array[int], "asked at the tow's speed")
	assert_equal([task.landing_land, task.landing_water, task.phase],
		[Vector2(20.0, 11.0), Vector2(22.0, 11.0), Tasks.SwimRescue.PHASE_TOW], "towing there")


func test_the_nearest_landing_is_one_that_can_be_stood_on() -> void:
	"""From the fisher shelter's own landing (in the shelter's footprint: unused) the nearest landing is
	another, one whose land point is clear."""
	var rig := _rig()
	var map := _map()
	var shelter_water: Vector2 = Vector2(WaterRules.to_m(map.landing_water(0).x), WaterRules.to_m(map.landing_water(0).y))
	var shelter_land: Vector2 = Vector2(WaterRules.to_m(map.landing_land(0).x), WaterRules.to_m(map.landing_land(0).y))
	var got: PackedVector2Array = rig.play.rescue.nearest_landing(shelter_water)
	assert_true(got[0].distance_to(shelter_land) > 1.0, "not the shelter's: %s" % got[0])
	var usable: bool = false
	for k: int in map.landing_count():
		var land: Vector2 = Vector2(WaterRules.to_m(map.landing_land(k).x), WaterRules.to_m(map.landing_land(k).y))
		usable = usable or (land.distance_to(got[0]) < 0.01 and rig.play.links.landing_ok[k] == 1)
	assert_true(usable, "a landing clear to stand on")


func test_the_router_is_handed_the_wading_cost_when_it_plans_with_the_water() -> void:
	"""A plan the water's crossings join gives the router the ford's wading cost."""
	var rig := _rig()
	_swimmer(rig, 0, 600)
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var space: CastSpaceScript = rig.cast.space()
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.3, out, legs)
	assert_true(space.tunnels.router.wade_cost.is_valid(), "handed a cost")
	assert_equal(space.tunnels.router.wade_cost, Callable(rig.play.crossings, &"wade_extra_m"), "the water's")


func test_a_selection_ring_sits_on_the_ground_and_never_below_the_surface() -> void:
	"""On a bank's rise, over a wading bed, on a deck; a swimmer's and a diver's ring at the surface; an
	underground resident's at the datum."""
	var lift: float = 0.035
	assert_almost_equal(CommandScript.ring_y_m(false, 0.3), 0.3 + lift, "on a bank")
	assert_almost_equal(CommandScript.ring_y_m(false, -0.1), -0.1 + lift, "a wading bed")
	assert_almost_equal(CommandScript.ring_y_m(false, -1.5), -0.2 + lift, "a diver: the surface")
	assert_almost_equal(CommandScript.ring_y_m(true, -2.0), lift, "underground: the datum")


func test_piers_stand_evenly_along_the_deck() -> void:
	"""A 6.4 m span takes two piers; they split the 7.6 m deck (0.6 m past each waterline) into three
	equal bays, each pier under a joint of the deck."""
	var bridges := _bridges()
	var survey := BridgesScript.Survey.new()
	survey.ok = true
	survey.shore_a = Vector2(-10.0, 0.0)
	survey.shore_b = Vector2(-3.6, 0.0)
	survey.span_u = 6554
	survey.deck_u = Rules.deck_u(6554)
	survey.piers = Rules.piers_for(Rules.KIND_PLANK, 6554)
	assert_equal(survey.piers, 2, "two piers")
	assert_true(bridges.plan_into(survey, "test bridge", _read), "planned")
	var at: PackedVector2Array = bridges.pier_points(_read.value)
	var a: Vector2 = bridges.deck_end(_read.value, false)
	var b: Vector2 = bridges.deck_end(_read.value, true)
	var bays: Array[float] = [a.distance_to(at[0]), at[0].distance_to(at[1]), at[1].distance_to(b)]
	for bay: float in bays:
		assert_almost_equal(bay, a.distance_to(b) / 3.0, "an equal bay: %s" % str(bays))


func test_a_rescue_task_whose_victim_is_no_longer_held_ends_where_it_is() -> void:
	"""Stepped after its victim left the water's hold (the victim's task is another), a swim rescue ends
	without a stroke and a line rescue without a throw."""
	var rig := _rig()
	_swimmer(rig, 2, 1100)
	var victim := _brain(rig, 0)
	var held := Tasks.VictimTask.new(rig.play.motion, 0.0)
	var rescuer := _brain(rig, 2)
	var from: Vector2 = rescuer.position
	var swim := Tasks.SwimRescue.new(rig.play.motion, victim, held, PackedVector2Array([WEST_BANK, RUN_MID]),
		Callable(), rig.play.rescue.tow_landing)
	assert_false(swim.step(rescuer, 0.1), "the swim is over")
	assert_equal(rescuer.position, from, "not a step taken")
	var line := Tasks.LineRescue.new(rig.play.motion, victim, held, PackedVector2Array([WEST_BANK, RUN_MID]),
		Callable(), rig.play.rescue.nearest_landing)
	line.arrived(rescuer)
	assert_false(line.step(rescuer, 0.1), "the line is over")
	assert_equal(line.phase, Tasks.LineRescue.PHASE_THROW, "nothing thrown or hauled")


func test_a_selection_ring_is_put_at_its_residents_ground() -> void:
	"""The command lays a resident's ring by `ring_y_m`: a diver's at the surface, a wader's on the bed."""
	var rig := _rig()
	var command := _keep(CommandScript.new()) as CommandScript
	var ring := _keep(MeshInstance3D.new()) as MeshInstance3D
	var brain := _brain(rig, 0)
	brain.water_place(RUN_MID, -1.5, 0.0)
	command._put_ring(ring, Vector3(RUN_MID.x, -1.5, RUN_MID.y), brain, 1.0)
	assert_almost_equal(ring.position.y, CommandScript.ring_y_m(false, -1.5), "a diver's: at the surface")
	assert_almost_equal(ring.position.x, RUN_MID.x, "over it")
	brain.water_place(FORD_MID, -0.12, 0.0)
	command._put_ring(ring, Vector3(FORD_MID.x, -0.12, FORD_MID.y), brain, 1.0)
	assert_almost_equal(ring.position.y, -0.12 + 0.035, "a wader's: on the bed")


func test_the_rescue_tally_is_a_heading_note_and_not_an_alert() -> void:
	"""With nobody in difficulty the alert line is empty; the swimmers' heading counts the rescues."""
	var rig := _rig()
	assert_equal(rig.play.text.swimmers_title(), "Swimmers — 0 in the water", "none yet")
	rig.play.rescue.rescued = 1
	assert_equal(rig.play.text.swimmers_title(), "Swimmers — 0 in the water · 1 rescue so far", "one")
	rig.play.rescue.rescued = 2
	assert_equal(rig.play.text.alert_line(), "", "no alert")
	assert_equal(rig.play.text.swimmers_title(), "Swimmers — 0 in the water · 2 rescues so far", "the tally")


func test_the_site_text_names_the_piers_once() -> void:
	"""A plank footbridge's cost names its piers and their wood once; a span with none says so."""
	var plank := BridgesScript.Survey.new()
	plank.ok = true
	plank.span_u = 5222
	plank.deck_u = Rules.deck_u(5222)
	plank.piers = 2
	plank.planks_milli = 6400
	plank.wood_milli = 2000
	var log := BridgesScript.Survey.new()
	log.kind = Rules.KIND_LOG
	log.reason = "too long"
	assert_equal(TextScript.site_text(plank, log, false),
		"5.1 m of water · 6.3 m of deck\nPlank footbridge: 6.4 U planks and 2.0 U wood for 2 piers\nLog bridge: can't — too long", "two piers")
	plank.piers = 0
	plank.wood_milli = 0
	assert_true(TextScript.site_text(plank, log, false).contains("Plank footbridge: 6.4 U planks, no piers"), "none")


func test_a_ranking_with_nobody_routable_plans_at_most_its_cap() -> void:
	"""Review M5 (decision 0205): with every thrower boxed in (no route), the ranking plans at most
	MAX_PLANS routes, not the whole cast, and still names the least bound."""
	var rig := _rig()
	_brain(rig, 0).water_hold = true
	for who: int in range(1, rig.cast.actor_count()):
		_place(rig, who, Vector2(0.0, -13.0) + Vector2(0.05 * who, 0.0))
	var landing: Vector2 = rig.play.rescue.nearest_landing(RUN_MID)[0]
	assert_equal(rig.play.rescue.route_cost_m(1, landing), INF, "boxed in")
	assert_true(rig.cast.actor_count() - 1 > RescueScript.MAX_PLANS, "more candidates than the cap")
	assert_true(rig.play.rescue.nearest_free_into(RUN_MID, 0, false, _read), "someone is named")
	assert_equal(rig.play.rescue.last_plans, RescueScript.MAX_PLANS, "no more plans than the cap")
