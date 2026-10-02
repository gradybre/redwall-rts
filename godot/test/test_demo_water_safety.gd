extends "res://test/framework/test_case.gd"
## Water safety (review group C: F07, F38, F39): the bank recheck before a swim, threshold notices
## for air, and rescue by capability. Real process order throughout -- the Water panel's own toggle
## handler, then the cast and the water stepping to the bank; a real DiveTask, then the Cramp
## command -- over the placeholder cast on the real village water (test_demo_water_play.gd's rig; no
## staged assets). Time to contact and the least air are recorded in the assertions' messages.

const Fixture := preload("res://test/test_demo_water_play.gd")
const Rules := preload("res://demo/waterplay/swim_rules.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const DiveTaskScript := preload("res://demo/waterplay/dive_task.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

const DT: float = 0.1
const WEST_BANK: Vector2 = Vector2(18.5, 10.5)
const EAST_BANK: Vector2 = Vector2(30.5, 10.5)
const POND_CENTRE: Vector2 = Vector2(28.467, 28.672)
## The pond's west shore, where the diver walks from, and a mouse beside it.
const POND_WEST: Vector2 = Vector2(19.0, 28.7)
const MOUSE_BY_POND: Vector2 = Vector2(20.0, 29.8)
## An otter's height in integer units (1.49 m): the pond is deep enough for it to dive.
const OTTER_HEIGHT_U: int = 1526
const OLD_WARNING: String = "Bed 4 (radish) is waterlogged -- Drain it"

var _fx: Fixture = null


func before_each() -> void:
	"""A fresh rig fixture (its own demo services) per test."""
	_fx = Fixture.new()
	_fx.before_each()


func after_each() -> void:
	"""Free what the fixture built."""
	_fx.after_each()


func _notices() -> NoticesScript:
	"""The rig's one notice feed."""
	return _fx._services.notices


func _count_kept(part: String) -> int:
	"""How many times kept feed entries containing `part` were said (a folded repeat counts each time:
	demo_notices.gd REPEATS FOLD)."""
	var n: int = 0
	for k: int in _notices().count():
		n += _notices().repeats(k) if _notices().text(k).contains(part) else 0
	return n


# --- F07: the bank recheck ------------------------------------------------------------------------

func _deep_under(rig: Fixture.Rig, at: Vector2) -> bool:
	"""Whether `at` is in water deeper than a mouse wades (where only a swimmer goes)."""
	return rig.play.map().depth_at(MotionScript.u_of(at)) > WaterRules.wade_max_u(WaterRules.MOUSE_HEIGHT_U)


func test_consent_turned_off_on_the_way_is_rechecked_at_the_bank() -> void:
	"""F07: a swimmer planned across the run by a swim link has swim shortcuts turned off by the Water
	panel's own handler while it walks to the water. At the bank it does not go in: it plans again from
	land, the feed says why, and it gets there round by land."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 1100)
	_fx._place(rig, 0, WEST_BANK)
	var brain: BrainScript = _fx._brain(rig, 0)
	brain.order_move(EAST_BANK)
	assert_true(_fx._has_crossing(brain.path_tunnel), "planned across by a swim: %s" % brain.path_tunnel)
	rig.play.toggle_consent(PackedInt32Array([0]))
	var seen: Array[bool] = [false, false, false]
	var there: bool = _fx._run(rig, func() -> bool:
		seen[0] = seen[0] or brain.in_water or _deep_under(rig, brain.position)
		seen[1] = seen[1] or brain.state == BrainScript.State.CROSS
		seen[2] = seen[2] or (seen[1] and brain.state != BrainScript.State.CROSS and _fx._has_crossing(brain.path_tunnel))
		return brain.state == BrainScript.State.HOLD and brain.position.distance_to(EAST_BANK) < 0.5)
	assert_false(seen[0], "never went in, nor walked where only a swimmer goes")
	assert_false(seen[2], "off the bank, planned again at once: no swim left in its route")
	assert_true(there, "got there by land: %s" % brain.position)
	assert_equal(_count_kept("swim shortcuts are off"), 1, "the reason said once: %s" % _notices().text(0))


func test_a_flood_risen_since_planning_turns_a_weak_swimmer_back_at_the_bank() -> void:
	"""F07: planned across the run when it could hold its line, a 0.7 m/s swimmer finds the stream in
	full flood at the bank (0.8 m/s across). It stays out of the stream, the feed names the current, and
	it plans again from land -- round the pond, whose still water it may still swim."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 700)
	_fx._place(rig, 0, WEST_BANK)
	var brain: BrainScript = _fx._brain(rig, 0)
	brain.order_move(EAST_BANK)
	assert_true(_fx._has_crossing(brain.path_tunnel), "planned across by a swim")
	rig.play.motion.flood_permille = Rules.PERMILLE
	var in_flow: Array[bool] = [false]
	var there: bool = _fx._run(rig, func() -> bool:
		in_flow[0] = in_flow[0] or (brain.in_water and rig.play.motion.flow_m_s(brain.position).length() > 0.0)
		return brain.state == BrainScript.State.HOLD and brain.position.distance_to(EAST_BANK) < 0.5)
	assert_false(in_flow[0], "never went into the flowing stream")
	assert_true(there, "got there another way: %s" % brain.position)
	assert_equal(_count_kept("the current is too strong to swim across"), 1, "the reason said")


func test_the_bank_recheck_names_each_failed_condition() -> void:
	"""F07: `entry_refusal` is the swim rules with the load actually carried, then the link's flow."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 700)
	var brain: BrainScript = _fx._brain(rig, 0)
	var crossings: RefCounted = rig.play.crossings
	assert_equal(crossings.entry_refusal(brain, 0), Rules.REFUSE_NONE, "fit, unloaded, consenting, still water")
	brain.carrying = true
	assert_equal(crossings.entry_refusal(brain, 0), Rules.REFUSE_LOADED, "a load picked up since")
	brain.carrying = false
	rig.play.state.rest[0] = Rules.REST_ENTRY_MIN - 1
	assert_equal(crossings.entry_refusal(brain, 0), Rules.REFUSE_TIRED, "tired since")
	rig.play.state.rest[0] = Rules.REST_MAX
	rig.play.motion.flood_permille = Rules.PERMILLE
	assert_equal(crossings.entry_refusal(brain, 0), Rules.REFUSE_FLOW, "a flood since")
	assert_equal(rig.play.text.bank_refusal_line(0, Rules.REFUSE_LOADED),
		"Placeholder 0 won't swim across: carrying a load — going round by land", "in words")


func test_a_swimmer_already_in_the_stream_is_not_pulled_out() -> void:
	"""F07's safe behaviour for one already swimming: shortcuts turned off mid-stream do not strand or
	turn it -- it swims on to the far bank (MOVE-REQ-007) and climbs out -- and its next trip back is
	planned by land."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 1100)
	_fx._place(rig, 0, WEST_BANK)
	var brain: BrainScript = _fx._brain(rig, 0)
	brain.order_move(EAST_BANK)
	assert_true(_fx._run(rig, func() -> bool: return brain.in_water), "in the water")
	rig.play.toggle_consent(PackedInt32Array([0]))
	var first_dry: Array[Vector2] = [Vector2.INF]
	var there: bool = _fx._run(rig, func() -> bool:
		if not brain.in_water and not first_dry[0].is_finite():
			first_dry[0] = brain.position
		return brain.state == BrainScript.State.HOLD and brain.position.distance_to(EAST_BANK) < 0.5)
	assert_true(there, "swam on and climbed out on the far bank: %s" % brain.position)
	assert_true(first_dry[0].x > 26.0, "out of the water only on the far (east) bank: %s" % first_dry[0])
	assert_equal(_count_kept("won't swim across"), 0, "no refusal: it was already in")
	brain.order_move(WEST_BANK)
	assert_false(_fx._has_crossing(brain.path_tunnel), "the way back is by land: %s" % brain.path_tunnel)


# --- F38: threshold notices ------------------------------------------------------------------------

func _diver_at_the_pond(rig: Fixture.Rig, who: int, from: Vector2) -> DiveTaskScript:
	"""Otter `who` from `from` on a real planned dive at the pond's centre, ordered and walked out to the
	spot (the task ready at the surface); returns the task."""
	_otter(rig, who, from)
	var task := DiveTaskScript.new(rig.play.motion, rig.play.links, POND_CENTRE,
		rig.play.motion.max_dive_m(who, POND_CENTRE), Callable(), Callable())
	_fx._brain(rig, who).order_task(task)
	assert_true(_fx._run(rig, func() -> bool: return task.phase >= DiveTaskScript.PHASE_READY), "out at the spot")
	return task


func _otter(rig: Fixture.Rig, who: int, at: Vector2) -> void:
	"""Placeholder `who` made an otter (1.9 m/s, dives, 1.49 m tall) standing at `at`."""
	_fx._swimmer(rig, who, 1900, true)
	rig.play.state.height_u[who] = OTTER_HEIGHT_U
	_fx._place(rig, who, at)


func _breathless_until_ready(rig: Fixture.Rig, whos: Array[int], lowest: PackedInt32Array) -> bool:
	"""Step until every one of `whos` has finished its dive, holding each one's air at 0 until it is out at
	its spot -- so it treads there, breathing 4 a tick, and HAZ-002 admits it the tick its air first
	reaches T + 300: the least any dive is allowed. `lowest` gets each one's least air once admitted.
	True when every dive finished."""
	var tasks: Array[DiveTaskScript] = []
	for who: int in whos:
		tasks.append(_fx._brain(rig, who).task as DiveTaskScript)
	lowest.resize(whos.size())
	lowest.fill(Rules.AIR_FULL)
	return _fx._run(rig, func() -> bool:
		var over: bool = true
		for k: int in tasks.size():
			if tasks[k].phase < DiveTaskScript.PHASE_READY:
				rig.play.state.air[whos[k]] = 0
			elif tasks[k].phase >= DiveTaskScript.PHASE_DESCEND:
				lowest[k] = mini(lowest[k], rig.play.state.air[whos[k]])
			over = over and _fx._brain(rig, whos[k]).task != tasks[k]
		return over)


func test_one_dive_at_the_air_boundary_posts_one_low_air_notice() -> void:
	"""F38: a real DiveTask admitted with just T + 300 air (the least HAZ-002 allows) crosses the 450
	advisory on its way up. One notice for the whole dive -- not one a tick -- and an older actionable
	warning is still in the feed afterwards."""
	var rig: Fixture.Rig = _fx._rig()
	_otter(rig, 0, POND_WEST)
	_fx._brain(rig, 0).order_task(DiveTaskScript.new(rig.play.motion, rig.play.links, POND_CENTRE,
		rig.play.motion.max_dive_m(0, POND_CENTRE), Callable(), Callable()))
	_notices().post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, OLD_WARNING)
	var before: int = _notices().revision
	var lowest := PackedInt32Array()
	assert_true(_breathless_until_ready(rig, [0], lowest), "the dive is over")
	assert_true(lowest[0] <= Rules.AIR_LOW_ADVISORY, "it did cross the advisory: least air %d" % lowest[0])
	assert_equal(_count_kept("low on air"), 1, "one low-air notice")
	assert_equal(_notices().revision - before, 1, "and nothing else posted")
	assert_true(_notices().has_text(OLD_WARNING), "the older warning survives")


func test_the_air_advisory_and_air_out_rearm_only_back_at_the_surface() -> void:
	"""F38: below, 450 raises LOW_AIR once and 0 raises AIR_OUT once, however long it stays; at the
	surface both stay latched until the air is back at AIR_LOW_REARM (600), and the next time below
	raises them again."""
	var state := StateScript.new()
	state.setup(PackedStringArray(["otter"]), PackedInt32Array([OTTER_HEIGHT_U]))
	state.air[0] = 451
	state.set_mode(0, StateScript.MODE_DIVE)
	var bits: int = _ticks(state, 1) | _ticks(state, 1)
	assert_equal(bits, StateScript.EVENT_LOW_AIR, "450: the advisory, once")
	assert_equal(_ticks(state, 460), StateScript.EVENT_AIR_OUT, "0: air out, once, and no advisory again")
	state.set_mode(0, StateScript.MODE_SWIM)
	@warning_ignore("integer_division") _ticks(state, (Rules.AIR_LOW_REARM - 4) / Rules.AIR_RECOVERY_PER_TICK)
	assert_equal(state.air[0], Rules.AIR_LOW_REARM - 4, "breathing: 596")
	assert_equal(state.air_latch[0], StateScript.LATCH_LOW_AIR | StateScript.LATCH_AIR_OUT, "still latched under 600")
	_ticks(state, 1)
	assert_equal(state.air_latch[0], 0, "re-armed at 600")
	state.set_mode(0, StateScript.MODE_DIVE)
	assert_equal(_ticks(state, Rules.AIR_LOW_REARM - Rules.AIR_LOW_ADVISORY), StateScript.EVENT_LOW_AIR, "the next dive warns again")


func test_a_fresh_dive_rearms_the_advisory_even_short_of_600() -> void:
	"""F38: one up from a dive that crossed 450 and down again before breathing back to 600 -- a fresh
	dive -- is warned again on this dive."""
	var state := StateScript.new()
	state.setup(PackedStringArray(["otter"]), PackedInt32Array([OTTER_HEIGHT_U]))
	state.air[0] = 451
	state.set_mode(0, StateScript.MODE_DIVE)
	assert_equal(_ticks(state, 2), StateScript.EVENT_LOW_AIR, "the first dive's advisory")
	state.set_mode(0, StateScript.MODE_SWIM)
	_ticks(state, 30)
	assert_true(state.air[0] < Rules.AIR_LOW_REARM and state.air_latch[0] != 0, "up, 569 air: still latched")
	state.set_mode(0, StateScript.MODE_DIVE)
	assert_equal(state.air_latch[0], 0, "down again: a fresh dive re-arms")
	assert_equal(_ticks(state, 120), StateScript.EVENT_LOW_AIR, "and it is warned again")
	state.set_mode(0, StateScript.MODE_DISTRESS_UNDER)
	assert_equal(state.air_latch[0], StateScript.LATCH_LOW_AIR, "in difficulty below is the same time down")


func _ticks(state: StateScript, n: int) -> int:
	"""Advance `state` `n` fixed ticks; the events raised meanwhile."""
	var bits: int = 0
	for k: int in n:
		@warning_ignore("integer_division") state.advance_usec(Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND + 1)
		bits |= state.take_events(0)
	return bits


func test_two_divers_at_the_boundary_say_low_air_once_each_and_the_history_survives() -> void:
	"""F38 with more than one swimmer: two otters sent by the real dive order, each admitted with just
	T + 300, each posts one advisory; the older warning is still there, and each one's latch is re-armed
	once it is home breathing."""
	var rig: Fixture.Rig = _fx._rig()
	_otter(rig, 0, POND_WEST)
	_otter(rig, 3, POND_WEST + Vector2(0.0, 1.5))
	_notices().post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, OLD_WARNING)
	assert_equal(rig.play.order_dive(PackedInt32Array([0, 3]), POND_CENTRE), "2 diving", "sent")
	var lowest := PackedInt32Array()
	assert_true(_breathless_until_ready(rig, [0, 3], lowest), "both dives over")
	assert_true(lowest[0] <= Rules.AIR_LOW_ADVISORY and lowest[1] <= Rules.AIR_LOW_ADVISORY, "both crossed: %s" % lowest)
	assert_equal(_count_kept("Placeholder 0 is low on air"), 1, "one for the first")
	assert_equal(_count_kept("Placeholder 3 is low on air"), 1, "one for the second")
	assert_true(_notices().has_text(OLD_WARNING), "the older warning survives")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.state.air_latch[0] + rig.play.state.air_latch[3] == 0, 200), "re-armed home")


func test_a_victim_held_below_says_air_out_once() -> void:
	"""F38: an otter cramped below with nobody able to come (everyone else held) runs out of air: the
	feed says so once, not once a tick, and the water still brings it ashore unhurt."""
	var rig: Fixture.Rig = _fx._rig()
	var task: DiveTaskScript = _diver_at_the_pond(rig, 0, POND_WEST)
	assert_true(_fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	for who: int in range(1, 6):
		_fx._brain(rig, who).water_hold = true
	rig.play.cramp(PackedInt32Array([0]))
	var victim: BrainScript = _fx._brain(rig, 0)
	assert_true(_fx._run(rig, func() -> bool: return victim.task is Tasks.RestTask), "washed ashore")
	assert_equal(_count_kept("air ran out"), 1, "air out said once")
	assert_equal(_count_kept("low on air"), 0, "no advisory for one already in difficulty")


# --- F39: rescue by capability ---------------------------------------------------------------------

func test_a_submerged_victim_gets_the_farther_diver_not_the_nearer_swimmer() -> void:
	"""F39: an otter cramped on the bed of the pond mid-search (the real DiveTask, then the Cramp
	command), a mouse swimmer on the shore beside it and a second otter on the far west bank. The otter
	is sent -- it can fetch from below -- and takes hold before the victim's air runs out."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 1, 840)
	_fx._place(rig, 1, MOUSE_BY_POND)
	_fx._swimmer(rig, 2, 1900, true)
	_fx._place(rig, 2, WEST_BANK)
	var task: DiveTaskScript = _diver_at_the_pond(rig, 0, POND_WEST)
	assert_true(_fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	assert_equal(rig.play.cramp(PackedInt32Array([0])), "Cramp (demo): 1 swimmer in difficulty", "cramped")
	assert_true(_fx._brain(rig, 2).task is Tasks.SwimRescue, "the diver is sent")
	assert_false(_fx._brain(rig, 1).task is Tasks.SwimRescue, "not the nearer mouse")
	var contact: Vector2i = _until_contact(rig, 0, rig.play.rescue.victim_task(0))
	assert_true(contact.x > 0 and contact.y > 0, "in hand before the air ran out: at %.1f s, least air %d (before the fix: the mouse, 40.0 s, air 0)" % [contact.x * DT, contact.y])


func _cramped_below(rig: Fixture.Rig, who: int, from: Vector2) -> Tasks.VictimTask:
	"""Otter `who` on a real dive from `from`, cramped by the Cramp command once it is on the bed."""
	var task: DiveTaskScript = _diver_at_the_pond(rig, who, from)
	assert_true(_fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	rig.play.cramp(PackedInt32Array([who]))
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(who)
	assert_true(held != null and held.down_m > 0.0, "held below")
	return held


func _until_contact(rig: Fixture.Rig, who: int, held: Tasks.VictimTask) -> Vector2i:
	"""Step until the victim is in a rescuer's hands (`towed`), or its rescue is over. Returns (frames to
	contact, or -1 without it; the least air it had meanwhile)."""
	var lowest: Array[int] = [rig.play.state.air[who]]
	var frames: Array[int] = [0]
	var touched: bool = _fx._run(rig, func() -> bool:
		lowest[0] = mini(lowest[0], rig.play.state.air[who])
		frames[0] += 1
		return held.towed or rig.play.rescue.victim_task(who) != held)
	return Vector2i(frames[0] if touched and held.towed else -1, lowest[0])


func test_a_rescuer_called_away_frees_the_victim_for_the_next_diver() -> void:
	"""F39: the diver on its way is called away by the player: the victim is released at once (never left
	reserved by nobody), and the next look sends the other diver, which takes hold before the air runs
	out."""
	var rig: Fixture.Rig = _fx._rig()
	_otter(rig, 2, WEST_BANK)
	_otter(rig, 3, Vector2(2.0, 24.0))
	var held: Tasks.VictimTask = _cramped_below(rig, 0, POND_WEST)
	var first: int = held.responder
	assert_true((first == 2 or first == 3) and held.response == Tasks.RESPONSE_DIVE, "a diver: %d" % first)
	_fx._brain(rig, first).order_move(Vector2(0.0, -10.0))
	assert_equal(held.responder, -1, "released the moment it was called away")
	assert_true(_fx._run(rig, func() -> bool: return held.responder == 5 - first, 20), "the next look sends the other")
	assert_equal(held.response, Tasks.RESPONSE_DIVE, "a diver")
	var contact: Vector2i = _until_contact(rig, 0, held)
	assert_true(contact.x > 0 and contact.y > 0, "in hand at %.1f s, least air %d" % [contact.x * DT, contact.y])


func test_a_second_victim_gets_a_stated_fallback_and_nobody_answers_two() -> void:
	"""F39: two otters cramped below, one diver and one mouse free. The diver goes to the first; the
	second is answered by the mouse treading above it, with the reason said. No rescuer holds two, and
	both come ashore; the first is in hand before its air runs out."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 1, 840)
	_fx._place(rig, 1, MOUSE_BY_POND)
	_otter(rig, 2, WEST_BANK)
	var first: Tasks.VictimTask = _cramped_below(rig, 0, POND_WEST)
	var second: Tasks.VictimTask = _cramped_below(rig, 3, POND_WEST + Vector2(0.0, 1.5))
	assert_equal([first.responder, first.response], [2, Tasks.RESPONSE_DIVE], "the diver to the first")
	assert_equal([second.responder, second.response, second.why], [1, Tasks.RESPONSE_WATCH, "no diver is free"], "the mouse above the second")
	assert_equal(_count_kept("No diver is free: Placeholder 1 swims out to tread above Placeholder 3, ready to tow"), 1, "said why")
	var contact: Vector2i = _until_contact(rig, 0, first)
	assert_true(contact.x > 0 and contact.y > 0, "the first in hand at %.1f s, least air %d" % [contact.x * DT, contact.y])
	assert_true(second.responder != first.responder, "nobody answers two")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.rescue.victims.is_empty()), "both ashore")
	assert_equal(rig.play.rescue.rescued, 2, "two rescues")


func test_with_no_swimmer_free_a_line_waits_and_a_diver_come_free_takes_over() -> void:
	"""F39's fallback and its re-evaluation: nobody free can swim, so a resident takes a line to the bank
	to wait (the reason said); the moment a diver is free it takes over, the thrower stands down, and the
	diver takes hold."""
	var rig: Fixture.Rig = _fx._rig()
	_otter(rig, 2, WEST_BANK)
	_fx._brain(rig, 2).water_hold = true
	var held: Tasks.VictimTask = _cramped_below(rig, 0, POND_WEST)
	var thrower: int = held.responder
	assert_true(thrower > 0 and held.response == Tasks.RESPONSE_LINE, "a line: %d" % thrower)
	assert_equal(_count_kept("No swimmer is free: Placeholder %d takes a line to the bank to wait for Placeholder 0 to come up" % thrower), 1, "said why")
	_fx._brain(rig, 2).water_hold = false
	assert_true(_fx._run(rig, func() -> bool: return held.responder == 2, 20), "the diver takes over")
	assert_equal(held.response, Tasks.RESPONSE_DIVE, "to fetch it from below")
	assert_false(_fx._brain(rig, thrower).task is Tasks.LineRescue, "the thrower stood down")
	assert_equal(_count_kept("Placeholder 2 dives to fetch Placeholder 0 from below (taking over from Placeholder %d)" % thrower), 1, "said")
	var contact: Vector2i = _until_contact(rig, 0, held)
	assert_true(contact.x > 0, "in hand at %.1f s, least air %d" % [contact.x * DT, contact.y])


func test_with_nobody_able_to_swim_the_safety_net_still_brings_it_ashore() -> void:
	"""F39 with no capable swimmer at all: a line waits on the bank with its reason, the victim's air runs
	out and it floats up, and it is brought ashore unhurt -- hauled in, or carried by the water -- never
	lost (DEC-040)."""
	var rig: Fixture.Rig = _fx._rig()
	var held: Tasks.VictimTask = _cramped_below(rig, 0, POND_WEST)
	assert_equal([held.response, held.why], [Tasks.RESPONSE_LINE, "no swimmer is free"], "a line, and why")
	var contact: Vector2i = _until_contact(rig, 0, held)
	var victim: BrainScript = _fx._brain(rig, 0)
	assert_true(_fx._run(rig, func() -> bool: return rig.play.state.mode[0] == StateScript.MODE_RESTING), "ashore, resting")
	assert_true(victim.task is Tasks.RestTask and not victim.in_water, "unhurt, out of the water")
	assert_equal(contact.y, 0, "its air ran out first (contact %.1f s, least air %d)" % [contact.x * DT, contact.y])


func test_a_diver_short_of_air_is_passed_over_with_the_reason_until_it_has_breathed() -> void:
	"""F39: the free otter has just surfaced, short of the air to go down and back with HAZ-002's reserve;
	the mouse goes to tread above, and the Water panel's incident says who, how and why. Once the otter
	has breathed enough it takes over, and the incident names it."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 1, 840)
	_fx._place(rig, 1, MOUSE_BY_POND)
	_otter(rig, 2, WEST_BANK)
	var task: DiveTaskScript = _diver_at_the_pond(rig, 0, POND_WEST)
	assert_true(_fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	rig.play.state.air[2] = Rules.AIR_CONTINGENCY_TICKS
	rig.play.cramp(PackedInt32Array([0]))
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	assert_equal([held.responder, held.response, held.why], [1, Tasks.RESPONSE_WATCH, "no free diver has the air to go down"], "the mouse")
	var line: String = rig.play.text.alert_line()
	assert_true(line.begins_with("In difficulty: Placeholder 0, underwater, breath ") and line.contains("— Placeholder 1: ")
		and line.ends_with("(no free diver has the air to go down)"), line)
	assert_true(_fx._run(rig, func() -> bool: return held.responder == 2, 100), "the otter, breathed, takes over")
	assert_true(rig.play.text.alert_line().contains("— Placeholder 2: "), rig.play.text.alert_line())
	assert_true(_fx._run(rig, func() -> bool: return rig.play.text.alert_line().contains(" landing"), 600), "the landing named once towing")


func test_a_reservation_is_released_only_by_the_rescuer_that_holds_it() -> void:
	"""F39's atomic reservation: `reserve` names who, how and why at once; a release by anyone else (one
	stood down after another took over) leaves it; the holder's own release frees it and remembers it."""
	var held := Tasks.VictimTask.new(null, 1.0)
	held.reserve(2, Tasks.RESPONSE_DIVE, "")
	assert_true(held.engaged, "engaged")
	assert_false(held.release(1), "not 1's to release")
	assert_equal([held.responder, held.response], [2, Tasks.RESPONSE_DIVE], "still 2's")
	assert_true(held.release(2), "2 lets go")
	assert_equal([held.responder, held.response, held.why, held.let_go], [-1, Tasks.RESPONSE_NONE, "", 2], "free, 2 remembered")
	assert_false(held.engaged, "nobody coming")


func test_a_rescuer_fetches_only_with_the_air_for_down_up_and_the_reserve() -> void:
	"""F39: to fetch one held 1.0 m below takes 60 ticks down and 60 up (swim_rules.gd `fetch_ticks`),
	so a diver needs 120 + 300 air; one less, or a swimmer that does not dive, treads above instead."""
	var rig: Fixture.Rig = _fx._rig()
	_otter(rig, 2, WEST_BANK)
	_fx._swimmer(rig, 1, 840)
	var held := Tasks.VictimTask.new(rig.play.motion, 1.0)
	var rescue := Tasks.SwimRescue.new(rig.play.motion, _fx._brain(rig, 0), held,
		PackedVector2Array([WEST_BANK, WEST_BANK]), Callable(), Callable())
	assert_equal(Rules.fetch_ticks(1000), 120, "60 down, 60 up")
	rig.play.state.air[2] = 420
	assert_true(rescue.can_fetch(2), "420: enough")
	rig.play.state.air[2] = 419
	assert_false(rescue.can_fetch(2), "419: one short")
	assert_false(rescue.can_fetch(1), "the mouse does not dive")


func test_a_line_hauling_in_is_not_replaced_by_a_swimmer_come_free() -> void:
	"""F39's re-evaluation never takes a victim off a line already hauling it in (it is nearly ashore)."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 600)
	var victim: BrainScript = _fx._brain(rig, 0)
	victim.water_place(Vector2(22.5, 29.8), -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	var thrower: int = held.responder
	assert_true(thrower > 0 and held.response == Tasks.RESPONSE_LINE, "a line")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.rescue.line_of(_fx._brain(rig, thrower)) != null), "hauling")
	var swimmer: int = 1 if thrower != 1 else 2
	_fx._swimmer(rig, swimmer, 840)
	_fx._run(rig, func() -> bool: return false, 15)
	assert_true(held.responder == thrower or victim.task is Tasks.RestTask, "the line keeps it: %d" % held.responder)
	assert_false(_fx._brain(rig, swimmer).task is Tasks.SwimRescue, "the swimmer is not sent")


func test_one_waiting_above_is_kept_while_the_victim_floats_up() -> void:
	"""F39: with two mice free and no diver, one treads above (never swapped for the other each look);
	when the victim's air runs out and it floats up, a diver come free does not take over from the one
	already there -- it tows it in."""
	var rig: Fixture.Rig = _fx._rig()
	for who: int in [1, 4]:
		_fx._swimmer(rig, who, 840)
		_fx._place(rig, who, MOUSE_BY_POND + Vector2(0.0, 0.8 * who))
	_otter(rig, 2, WEST_BANK)
	_fx._brain(rig, 2).water_hold = true
	var held: Tasks.VictimTask = _cramped_below(rig, 0, POND_WEST)
	var watcher: int = held.responder
	assert_true((watcher == 1 or watcher == 4) and held.response == Tasks.RESPONSE_WATCH, "a mouse above")
	_fx._run(rig, func() -> bool: return false, 30)
	assert_equal(held.responder, watcher, "not swapped for the other mouse")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.state.air[0] == 0), "its air ran out")
	_fx._brain(rig, 2).water_hold = false
	_fx._run(rig, func() -> bool: return false, 15)
	assert_equal(held.responder, watcher, "the diver does not take over from the one above it")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.rescue.victims.is_empty()), "towed ashore")
	assert_equal(rig.play.rescue.rescued, 1, "rescued")


func test_a_watcher_that_dives_is_promoted_once_it_has_breathed_not_relieved() -> void:
	"""F39 (review H1): an otter by the pond, short of the air to fetch when the victim is cramped, is sent
	to tread above it; once it has breathed enough it is promoted to fetch where it is -- a farther otter
	come free then does not relieve it."""
	var rig: Fixture.Rig = _fx._rig()
	_otter(rig, 2, MOUSE_BY_POND)
	_otter(rig, 3, WEST_BANK)
	_fx._brain(rig, 3).water_hold = true
	var task: DiveTaskScript = _diver_at_the_pond(rig, 0, POND_WEST)
	assert_true(_fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	rig.play.state.air[2] = Rules.AIR_CONTINGENCY_TICKS
	rig.play.cramp(PackedInt32Array([0]))
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	assert_equal([held.responder, held.response], [2, Tasks.RESPONSE_WATCH], "sent to watch, short of air")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.rescue.has_fetch_air(2, 0), 60), "it has breathed enough")
	_fx._brain(rig, 3).water_hold = false
	assert_true(_fx._run(rig, func() -> bool: return held.response == Tasks.RESPONSE_DIVE, 60), "promoted")
	assert_equal([held.responder, held.why], [2, ""], "the same otter, no fallback reason left")
	assert_false(_fx._brain(rig, 3).task is Tasks.SwimRescue, "the farther otter is not sent")
	var contact: Vector2i = _until_contact(rig, 0, held)
	assert_true(contact.x > 0 and contact.y > 0, "in hand at %.1f s, least air %d" % [contact.x * DT, contact.y])


func test_a_thrower_called_away_mid_haul_frees_the_victim() -> void:
	"""F39 / DEC-040: a thrower hauling a victim in is called away by the player: the victim is let go at
	once -- not left marked in hand with nobody holding it -- and someone else is sent, or the water
	brings it ashore."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 600)
	var victim: BrainScript = _fx._brain(rig, 0)
	victim.water_place(Vector2(22.5, 29.8), -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	var thrower: int = held.responder
	assert_true(_fx._run(rig, func() -> bool: return held.towed), "hauling")
	_fx._brain(rig, thrower).order_move(Vector2(0.0, -10.0))
	assert_equal([held.towed, held.responder], [false, -1], "let go at once")
	assert_true(_fx._run(rig, func() -> bool: return held.responder >= 0, 20), "the next look sends another")
	assert_true(held.responder != thrower, "not the one called away")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.rescue.victims.is_empty()), "ashore")
	assert_equal(rig.play.rescue.rescued, 1, "rescued once")


func test_a_rescuer_whose_consent_is_withdrawn_does_not_go_in() -> void:
	"""F07 for a rescue: the swimmer sent to a victim has swim shortcuts turned off on its way. At the
	water it does not go in; it lets the victim go and another is sent."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 600)
	_fx._swimmer(rig, 2, 1100)
	var victim: BrainScript = _fx._brain(rig, 0)
	victim.water_place(Vector2(24.4, 11.0), -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	assert_equal([held.responder, held.response], [2, Tasks.RESPONSE_SWIM], "the swimmer")
	rig.play.toggle_consent(PackedInt32Array([2]))
	var wet: Array[bool] = [false]
	assert_true(_fx._run(rig, func() -> bool:
		wet[0] = wet[0] or _fx._brain(rig, 2).in_water
		return held.responder != 2), "it let the victim go")
	assert_false(wet[0], "never went in")
	assert_true(_fx._run(rig, func() -> bool: return rig.play.rescue.victims.is_empty()), "brought ashore another way")


func test_a_rescue_task_no_longer_holding_its_victim_ends() -> void:
	"""F39's authoritative reservation: a thrower or a swimmer still running its rescue after the victim
	was reserved for another (relieved, but kept on by an unfinished job it took up) stops when it gets
	there -- it never hauls, goes in for or tows a victim that is someone else's."""
	var rig: Fixture.Rig = _fx._rig()
	_fx._swimmer(rig, 0, 600)
	var victim: BrainScript = _fx._brain(rig, 0)
	victim.water_place(Vector2(22.5, 29.8), -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var held: Tasks.VictimTask = rig.play.rescue.victim_task(0)
	var thrower: int = held.responder
	assert_true(_fx._brain(rig, thrower).task is Tasks.LineRescue, "a line")
	held.reserve(5 if thrower != 5 else 4, Tasks.RESPONSE_LINE, "")
	var touched: Array[bool] = [false, false]
	assert_true(_fx._run(rig, func() -> bool:
		touched[0] = touched[0] or held.towed
		return not (_fx._brain(rig, thrower).task is Tasks.LineRescue), 600), "the thrower stopped at the landing")
	_fx._swimmer(rig, 2, 1100)
	var swim := Tasks.SwimRescue.new(rig.play.motion, victim, held, rig.play.rescue._entry_for(victim.position,
		_fx._brain(rig, 2).surface_point()), Callable(), rig.play.rescue.tow_landing)
	_fx._brain(rig, 2).order_task(swim)
	assert_true(_fx._run(rig, func() -> bool:
		touched[1] = touched[1] or _fx._brain(rig, 2).in_water
		return not (_fx._brain(rig, 2).task is Tasks.SwimRescue), 600), "a swimmer not holding it stops too")
	assert_equal(touched, [false, false] as Array[bool], "neither hauled it nor went in")
	var holder: int = held.responder
	_fx._brain(rig, 2).order_task(Tasks.SwimRescue.new(rig.play.motion, victim, held, rig.play.rescue._entry_for(
		victim.position, _fx._brain(rig, 2).surface_point()), Callable(), rig.play.rescue.tow_landing))
	_fx._brain(rig, 2).order_move(Vector2(0.0, -10.0))
	assert_equal(held.responder, holder, "called away, it does not release what it does not hold")
