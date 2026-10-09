extends Node3D
## THE FERRY in the village (decision 0437): ferry.gd wired to the cast, the boat core's fleet and the fishery's skills
## and ice, the one stores, calendar and weather, the water's crossings (its passenger row), the Water panel's Ferry
## section, the work board, the incidents and its drawing. Presentation over integer rules; nothing writes into the
## simulation.
##
## PLAYER VERBS (the Water panel's Ferry section; every button's tooltip is its ACTION CARD from the order's own
## decision, decision 0332):
##   Gather the far copse   every windfall pile lying there goes on the work board -- to the selected residents first
##   Send the ferry         a crossing now, ahead of the timetable (something must wait to be carried)
##   Cancel crossing        the crossing called off before its crew is aboard; afloat, it finishes
##
## THE BENEFIT (P's preview, decision 0461's words): the far copse to the village's log stack carried by land -- over the
## ford -- against carried to the far stage, ferried and carried on from the ferry stage, both on the cast's
## own surface planner at a carrier's pace, in game hours (the wait for a departure added as at most its two hours).
##
## TIME. The ferry runs on this frame's demo time (paused, nothing moves; at 4x four times as fast); the panel and the
## incident follow on real time (they work paused), the panel only while shown.
##
## THE INCIDENT (decision 0331). CARGO STRANDED -- the ferry closed while wood waits at the far stage or aboard, or its
## boat held there -- is a WARNING, "water:ferry_stranded", resolved once the ferry is open again.

const FerryScript := preload("res://demo/ferry/ferry.gd")
const Rules := preload("res://demo/ferry/ferry_rules.gd")
const ViewScript := preload("res://demo/ferry/ferry_view.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const FisheryNodeScript := preload("res://demo/fishery/demo_fishery.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const PanelScript := preload("res://demo/waterplay/water_panel.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CastNav := preload("res://demo/cast/cast_nav.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const PANEL_REFRESH_S: float = 0.25
const STRANDED_KEY: String = "water:ferry_stranded"
## The body the benefit's walks are planned for (the widest resident's, as the fishery's places are snapped).
const BENEFIT_BODY_M: float = 0.5
## The far copse at a line's start.
const COPSE_TITLE: String = "The far copse"
## Demo seconds a game hour (decision 0421).
const HOUR_S: float = float(CalendarScript.HOUR_USEC) / 1000000.0

var ferry: FerryScript = FerryScript.new()
var view: ViewScript = null
var services: ServicesScript = null
## What the last frame's ferry and drawing cost on the main thread, microseconds (the performance check).
var last_usec: int = 0
## The benefit's two ways, metres (INF: no way found), planned once and again when the bridges change.
var land_m: float = INF
var ferry_walk_m: float = INF

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _waterplay: WaterplayScript = null
var _card: CardScript = CardScript.new()
var _refresh_in: float = 0.0
var _bridges_seen: int = -1


func configure(cast: DemoCastScript, command: DemoCommandScript, shared: ServicesScript, waterplay: WaterplayScript,
		fishery: FisheryNodeScript) -> void:
	"""Wire the ferry into this village (`command` and `waterplay` may be null in a check)."""
	name = "DemoFerry"
	_cast = cast
	_command = command
	_waterplay = waterplay
	services = shared
	var f: RefCounted = fishery.fishery
	ferry.configure(cast, f.get(&"fleet"), f.get(&"skills"), f.get(&"ice"), shared.stores, shared.calendar, shared.weather,
		f.get(&"map"))
	ferry.say = _say
	if waterplay != null:
		ferry.flooded = func() -> bool: return waterplay.motion.flood_permille > 0
		waterplay.crossings.ferry = ferry
		waterplay.panel.action.connect(on_action)
	view = ViewScript.new()
	add_child(view)
	view.configure(ferry, shared.props)
	if command != null:
		command.add_task_text(task_text)


func task_text(who: int) -> String:
	"""What `who` does for the ferry, in words ("" when nothing)."""
	var j: int = ferry.job_of_worker(who)
	return ferry.doing_text(j, ferry.j_serial[j]) if j >= 0 else ""


func course_m() -> PackedVector2Array:
	"""The ferry's route, stage to stage, in metres (for the Routes layer)."""
	var out := PackedVector2Array([ferry.stage_land(FerryScript.NEAR), Routes.jetty_end_m(1)])
	for k: int in Routes.route_points(Routes.FERRY_BOAT):
		out.append(Routes.m_of(Routes.route_point(Routes.FERRY_BOAT, k)))
	out.append(Routes.jetty_end_m(2))
	out.append(ferry.stage_land(FerryScript.FAR))
	return out


func status_text() -> String:
	"""The Routes layer's ferry line."""
	return ferry.status_line()


# --- per frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Run the ferry on this frame's demo time; the view follows; the panel and the incident on real time."""
	if view == null:
		return
	var started: int = Time.get_ticks_usec()
	var usec: int = _cast.clock.frame_usec if _cast != null else 0
	ferry.update(usec)
	view.refresh()
	last_usec = Time.get_ticks_usec() - started
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = PANEL_REFRESH_S
		sync_incident()
		if _waterplay != null and _waterplay.panel.is_shown():
			refresh_panel()


func _say(text: String, warning: bool) -> void:
	"""Post a line to the one notice feed, from the water."""
	services.notices.post(NoticesScript.SOURCE_WATER, NoticesScript.LEVEL_WARNING if warning else NoticesScript.LEVEL_NOTE, text)


func sync_incident() -> void:
	"""CARGO STRANDED while closed (see THE INCIDENT), raised once, its words kept current, resolved when open."""
	var incidents: IncidentsScript = services.incidents
	var words: String = stranded_words()
	if words.is_empty():
		incidents.resolve(STRANDED_KEY)
	elif not incidents.update(STRANDED_KEY, IncidentsScript.STATE_NEEDS_DECISION, words):
		incidents.raise(STRANDED_KEY, NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_WARNING, words)


func stranded_words() -> String:
	"""'The ferry is closed (a storm): 3 logs at the far stage' ('' when nothing is stranded)."""
	if ferry.is_open():
		return ""
	var parts := PackedStringArray()
	if ferry.far_stack_milli > 0:
		parts.append("%s at %s" % [Measures.amount(&"wood", ferry.far_stack_milli), Routes.FAR_STAGE_NAME])
	if ferry.aboard_milli > 0:
		parts.append("%s aboard" % Measures.amount(&"wood", ferry.aboard_milli))
	if ferry.x_state == FerryScript.X_HELD:
		parts.append("the boat is held at %s" % Routes.FAR_STAGE_NAME)
	if parts.is_empty():
		return ""
	return "The ferry is %s: %s" % [ferry.closed_words(), "; ".join(parts)]


# --- the orders ------------------------------------------------------------------------------------

func on_action(action_name: StringName) -> void:
	"""A Water panel button of the ferry's (others are the water's own)."""
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	match action_name:
		PanelScript.ACTION_FERRY_GATHER:
			_answer(_ordered(ferry.order_gather(members), "Gather the far copse: on the work board"))
		PanelScript.ACTION_FERRY_SEND:
			_answer(_ordered(ferry.order_send(members), "The ferry is called: on the work board"))
		PanelScript.ACTION_FERRY_CANCEL:
			_answer(_ordered(ferry.cancel_crossing(), "The ferry crossing is called off"))
		_:
			return
	_refresh_in = 0.0


func _ordered(why: String, done: String) -> String:
	"""An order's answer: done, or why not."""
	return done if why.is_empty() else "Can't: %s" % why


func _answer(said: String) -> void:
	"""An order's answer beside the selection; the Water panel comes forward."""
	if _command != null and _command.panel() != null:
		_command.say(said)
	if _waterplay != null:
		_waterplay.panel_wanted.emit()


# --- the panel ---------------------------------------------------------------------------------------

func refresh_panel() -> void:
	"""Fill the Ferry section and set its buttons' cards (only while shown)."""
	var panel: PanelScript = _waterplay.panel
	var members: PackedInt32Array = _command.selected() if _command != null else PackedInt32Array()
	panel.show_ferry(panel_lines())
	var card: CardScript = gather_card(members)
	panel.set_card(PanelScript.ACTION_FERRY_GATHER, card.text(), card.is_ok())
	card = send_card(members)
	panel.set_card(PanelScript.ACTION_FERRY_SEND, card.text(), card.is_ok())
	card = cancel_card()
	panel.set_card(PanelScript.ACTION_FERRY_CANCEL, card.text(), card.is_ok())


func panel_lines() -> Dictionary:
	"""The section's text (water_panel.gd FERRY_LINES)."""
	return {&"ferry_status": status_lines(), &"ferry_cargo": cargo_line(), &"ferry_copse": copse_line(),
		&"ferry_benefit": benefit_line()}


func status_lines() -> String:
	"""The ferry's state, its timetable and its crew."""
	var lines := PackedStringArray([ferry.status_line()])
	lines.append("Departures %02d:00–%02d:00 every %d game hours while staffed; at once when %s waits at %s" % [
		Rules.FIRST_DEPARTURE_HOUR, Rules.LAST_DEPARTURE_HOUR, Rules.EVERY_HOURS, Measures.exact(&"wood", Rules.THRESHOLD_MILLI),
		Routes.FAR_STAGE_NAME])
	var crew: int = ferry.fleet.crew_of(Routes.FERRY_BOAT, FleetScript.HELM) if ferry.fleet != null else -1
	var rider: int = ferry.fleet.crew_of(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT) if ferry.fleet != null else -1
	if crew >= 0:
		lines.append("At the helm: %s%s" % [ferry.name_of(crew), (" · passenger: " + ferry.name_of(rider)) if rider >= 0 else ""])
	lines.append("Crossings so far: %d · passengers: %d" % [ferry.crossings_done, ferry.passengers_carried])
	return "\n".join(lines)


func cargo_line() -> String:
	"""'Far stage: 3 logs · aboard: none · ferry stage: 1 log · ferried in all: 9 logs, stored: 9 logs'."""
	return "Far stage: %s · aboard: %s · ferry stage: %s · ferried in all: %s, stored: %s" % [
		Measures.amount_cell(&"wood", ferry.far_stack_milli), Measures.amount_cell(&"wood", ferry.aboard_milli),
		Measures.amount_cell(&"wood", ferry.near_stack_milli), Measures.amount_cell(&"wood", ferry.ferried_milli),
		Measures.amount_cell(&"wood", ferry.stored_milli)]


func copse_line() -> String:
	"""The far copse's windfall: the piles lying and what is being gathered."""
	return "%s: %d piles lying (%s) · in hands: %s · a pile falls each midnight" % [COPSE_TITLE,
		ferry.pile_count(), Measures.amount_cell(&"wood", ferry.lying_milli()),
		Measures.amount_cell(&"wood", ferry.in_hand_milli())]


func benefit_line() -> String:
	"""THE BENEFIT (see the header), planned again when the bridges change."""
	_plan_benefit()
	if land_m == INF or ferry_walk_m == INF:
		return "Benefit: no way planned yet"
	var pace: float = _carry_pace()
	var land_h: float = land_m / pace / HOUR_S
	var row_s: float = Rules.row_seconds(Routes.route_length_u(Routes.FERRY_BOAT))
	var ferry_h: float = (ferry_walk_m / pace + row_s) / HOUR_S
	var saving: int = roundi(100.0 * (land_h - ferry_h) / maxf(land_h, 0.001))
	return "Benefit: %s to the log stack, carried — by land over the ford about %.1f game hours; by ferry about %.1f (%d%% quicker), plus the wait for a departure (at most %d h). The router offers it to anyone crossing while it is open." % [
		COPSE_TITLE, land_h, ferry_h, saving, Rules.EVERY_HOURS]


func _carry_pace() -> float:
	"""A carrier's pace (m/s): the first resident's walk at the carry fraction."""
	var walk: float = (_cast.actor(0) as DemoActorScript).brain.walk_speed if _cast != null and _cast.actor_count() > 0 else 0.8
	return maxf(walk * BrainScript.CARRY_WALK_FRACTION, 0.1)


func _plan_benefit() -> void:
	"""The two ways on the cast's surface planner, once, and again when a bridge opens or closes."""
	var bridges: int = _waterplay.bridges.revision if _waterplay != null else 0
	if bridges == _bridges_seen or _cast == null or _cast.actor_count() == 0:
		return
	_bridges_seen = bridges
	var copse: Vector2 = ferry.copse_at[0]
	land_m = _way(copse, ferry.log_drop())
	ferry_walk_m = _way(copse, ferry.stack_at(FerryScript.FAR)) + _way(ferry.stack_at(FerryScript.NEAR), ferry.log_drop())


func _way(from: Vector2, to: Vector2) -> float:
	"""A surface walk's length (m; INF when the planner finds none)."""
	var out := PackedVector2Array()
	_cast.space().nav.plan(from, to, BENEFIT_BODY_M, PackedVector3Array(), 0, out)
	if out.is_empty() or out[out.size() - 1].distance_to(to) > 1.0:
		return INF
	return CastNav.path_length(from, out)


# --- the cards (decision 0332: each from its order's own decision) -------------------------------------

func gather_card(members: PackedInt32Array) -> CardScript:
	"""Gather the far copse's card: `ferry.gather_refusal`, the windfall, the work, who."""
	_card.reset("Gather the far copse's windfall")
	_card.result = "Gathered and carried to %s: %s (%d piles); the ferry rows it to %s, a hauler stacks it" % [
		Routes.FAR_STAGE_NAME, Measures.amount(&"wood", ferry.lying_milli()), ferry.pile_count(), Routes.FERRY_STAGE_NAME]
	_card.prerequisites.append("windfall lying in %s (a pile a day); the far bank is reached over the ford or by ferry" % Rules.COPSE_NAME)
	var why: String = ferry.gather_refusal()
	if not why.is_empty():
		_card.refuse("NO_WINDFALL" if ferry.pile_count() == 0 else "ON_BOARD", why, "wait for the next windfall (midnight)")
		return _card
	_card.work_usec = FisheryRules.work_usec(Rules.gather_mwu(ferry.lying_milli()), 0)
	_card.work_note = " for all of it, plus the walks"
	_who_for(members, func(who: int) -> bool: return ferry.job_of_worker(who) < 0, "the Woods crew, then anyone free")
	return _card


func send_card(members: PackedInt32Array) -> CardScript:
	"""Send the ferry's card: `ferry.send_refusal`, the crossing, the helm."""
	_card.reset("Send the ferry now")
	_card.result = "A round trip: %s loaded at %s (up to %s), passengers in the second seat; the boat back at %s" % [
		Measures.amount(&"wood", mini(ferry.far_stack_milli, Rules.BOAT_CARGO_MILLI)), Routes.FAR_STAGE_NAME,
		Measures.exact(&"wood", Rules.BOAT_CARGO_MILLI), Routes.FERRY_STAGE_NAME]
	_card.prerequisites.append("open water (no storm, hard freeze, flood or ice), a helm with fishing 1, the ferry boat free")
	var why: String = ferry.send_refusal()
	if not why.is_empty():
		_card.refuse("CANT_SEND", why, "wait for the next departure (%s)" % ferry.hour_words(ferry.next_departure))
		return _card
	var row_s: float = Rules.row_seconds(Routes.route_length_u(Routes.FERRY_BOAT))
	_card.work_usec = int(2.0 * row_s * 1000000.0)
	_card.work_note = " rowing, plus loading and the walk to the stage"
	_who_for(members, func(who: int) -> bool: return ferry.skills.can_helm(who) and ferry.job_of_worker(who) < 0,
		"a helm (fishing 1)")
	return _card


func cancel_card() -> CardScript:
	"""Cancel crossing's card: `ferry.cancel_crossing`'s refusal, read without calling it off."""
	_card.reset("Call the ferry crossing off")
	_card.result = "Nothing is aboard before its crew is: the wood stays on its stack, a waiting passenger goes by land"
	if ferry.x_serial == 0:
		_card.refuse("NO_CROSSING", "no crossing is out", "")
	elif ferry.x_job != FerryScript.NONE and FerryScript.DECK_STEPS.has(ferry.j_step[ferry.x_job]):
		_card.refuse("AFLOAT", "the ferry is on the water — it finishes the crossing", "")
	elif ferry.x_state == FerryScript.X_HELD:
		_card.refuse("HELD", "the boat is held at %s until the ferry opens" % Routes.FAR_STAGE_NAME, "")
	return _card


func _who_for(members: PackedInt32Array, can: Callable, crew_words: String) -> void:
	"""The card's Who: the first selected resident who may go, else the work board's queue; and what it stops."""
	var going: int = -1
	var able: int = 0
	for who: int in members:
		if bool(can.call(who)):
			able += 1
			if going < 0:
				going = who
	if going >= 0:
		_card.worker = going
		_card.who = CardScript.assign_selected(ferry.name_of(going), able, members.size())
		if _command != null:
			_card.interrupts = _command.interrupt_text(going)
		return
	_card.who = "Queue on the work board (J) for %s" % crew_words
