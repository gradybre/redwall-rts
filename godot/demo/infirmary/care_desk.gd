extends RefCounted
## THE CARE DESK: who is hurt, who rests where, who treats them, who gathers herbs -- on the demo's real brains.
## Decisions 0622, 0623. Presentation only: it moves the cast and keeps its numbers in the care state (care_state.gd);
## the settlement simulation is never written. No scene tree: the tests drive it as the village does (demo_care.gd).
##
## EACH FRAME (`update`): the water's hazards read (HAZ-002/003 from demo/waterplay/swim_state.gd), the herb patch
## regrown at midnight, every tick since the last integrated (care_state.gd), the HEAL and gathering work of the frame
## credited, the infirmary's +4 an hour set for who rests in it, a new injury reported (the news and an incident),
## and every DISPATCH_TICKS the patients, healers and gatherer looked at.
##
## PATIENTS (decision 0623, Brendan's ruling: "The infirmary should be its own place and that's where residents go to
## rest and heal"). A hurt resident that may be taken -- not in the water or held by its rescue, not crossing, not under
## the player's own move or work order, not in an emergency -- is sent to rest (care_tasks.gd BedRest) in the INFIRMARY
## building when it is built and has a free bed (infirmary_project.gd `admit`: 8 patient beds); before that, or when it
## is full, its own bed (the night's allocation), else the field-care spot by the hall's steps (PROPOSAL 0623 P2). It
## rests until treated and back at CareRules.UP_HEALTH (0622 P4).
##
## HEALERS. A resting patient whose treatment can be paid for (care_state.gd `treatment_refusal`) is given the best
## healer that may be taken -- up, unhurt, not treating already, not in an emergency: the highest HEAL level, then the
## nearest, then the lower index (P3: the herbalist first). At most infirmary_rules.gd `healer_slots()` ("Healer 2")
## treat inside the infirmary at once. A sleeper is woken for it (an order wakes a sleeper, as the player's does). The
## treatment's inputs are paid at work start, its work credited only while the healer stands
## beside a patient lying in its bed.
##
## UP AND ABOUT (decision 0622, review H2/H3). A patient does not lie in bed for good: hurt, it gets up while it needs a
## meal (REQ-SET-012's 3500: the kitchen does not take a resident from bed rest) and, with a minor injury, while the
## shelf cannot pay for its treatment (REQ-SET-172 lets it do non-hazardous work); treated, it gets up at
## CareRules.UP_HEALTH or while it cannot recover (hungry or tired). A serious injury rests until treated.
##
## THE HERBALIST GATHERS (P6). By day, at each look, while the shelf holds less than CareRules.HERB_TARGET_MILLI and
## the patch has herb above its floor, an idle herbalist goes to the patch, picks a trip's load at §5.5's work per U
## (REQ-SET-068's roll every 60 WU) and carries it to the shelf at the hall's steps. ONE SHELF, TWO SOURCES (batch 7
## integration, decision 0902): the herb a treatment takes is the pantry's `herb` item, the one the foragers bring in
## (decision 0681) -- at each look, day or night, while the shelf is short, the pantry's free herb is moved onto it
## first (`pantry_herb`), and only what is still short sends the herbalist to the patch.
##
const Rules := preload("res://demo/infirmary/care_rules.gd")
const StateScript := preload("res://demo/infirmary/care_state.gd")
const Tasks := preload("res://demo/infirmary/care_tasks.gd")
const Text := preload("res://demo/infirmary/care_text.gd")
const PaceScript := preload("res://demo/work/work_pace.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const ProjectScript := preload("res://demo/infirmary/infirmary_project.gd")
const InfirmaryRules := preload("res://demo/infirmary/infirmary_rules.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const SwimStateScript := preload("res://demo/waterplay/swim_state.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const Injury := preload("res://scripts/core/injury.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")

@warning_ignore_start("integer_division")

## The patients, healers and gatherer are looked at every this many calendar ticks: CareRules.DISPATCH_USEC (the
## work board's claim period) at 30 ticks a second.
const DISPATCH_TICKS: int = Rules.DISPATCH_USEC * SimClock.TICKS_PER_SECOND / 1000000
const NOBODY: int = -1
const INCIDENT_KEY: String = "care:hurt:%d"

var state: StateScript = StateScript.new()
var pace: PaceScript = PaceScript.new()
## The infirmary building (decision 0623; null: none in this village).
var infirmary: ProjectScript = null
var herbalist: int = NOBODY
## `(milli: int) -> int`: take up to `milli` of the pantry's free herb away for the shelf, answering how much (the
## foragers' herbs: both feed one shelf -- see THE HERBALIST GATHERS; decision 0902). Unset: the patch alone.
var pantry_herb: Callable = Callable()
var revision: int = 0

var _brains: Array[BrainScript] = []
var _names: PackedStringArray = PackedStringArray()
var _night: NightScript = null
var _graph: RefCounted = null
var _notices: NoticesScript = null
var _incidents: IncidentsScript = null
var _rest: Array[Tasks.BedRest] = []
var _treat: Array[Tasks.Treat] = []
var _healer_of: PackedInt32Array = PackedInt32Array()
var _gather: Tasks.Gather = null
var _gather_remainder: int = 0
var _reported: PackedInt64Array = PackedInt64Array()
var _cause: PackedByteArray = PackedByteArray()
var _loss: PackedInt32Array = PackedInt32Array()
## Per resident: the InjuryKind its incident last said (the row is cleared by the time the treatment is told).
var _kind_said: PackedByteArray = PackedByteArray()
## Per resident: 1 while it rests waiting and the last dispatch found nobody to treat it.
var _no_healer: PackedByteArray = PackedByteArray()
## Per resident: 1 when its last trip to the infirmary was lost before it got in -- the next rest is elsewhere (the
## review's M2: an unreachable door never loops).
var _skip_infirmary: PackedByteArray = PackedByteArray()
var _patch: Vector2 = Rules.HERB_PATCH_AT
var _shelf: Vector2 = Vector2.ZERO
var _tick: int = 0
var _next_dispatch: int = 0
## §5.5's work for one U of herb at the patch, worked out once.
var _herb_mwu_per_u: int = Rules.herb_work_mwu(Rules.FORAGE_LEVEL, Rules.PATCH_DANGER)
## `spot(i) -> Vector2`: the field-care spot (see `set_field_spot`).
var _field_spot: Callable = Callable()


func configure(brains: Array[BrainScript], names: PackedStringArray, keys: Array[StringName],
		size_classes: PackedByteArray, night: NightScript, graph: RefCounted) -> void:
	"""The desk for these residents (by actor index), named so, their cast keys (the herbalist's, P3) and §5.2 size
	classes, the night's beds (null: none) and the network's rooms (null: none)."""
	_brains = brains
	_names = names
	_night = night
	_graph = graph
	herbalist = keys.find(Rules.HERBALIST_KEY)
	state.configure(size_classes, herbalist)
	var n: int = brains.size()
	_rest.resize(n)
	_treat.resize(n)
	for column: PackedInt32Array in [_healer_of]:
		column.resize(n)
		column.fill(NOBODY)
	_reported.resize(n)
	_reported.fill(0)
	_cause.resize(n)
	_cause.fill(NoticesScript.SOURCE_CREW)
	_loss.resize(n)
	_loss.fill(0)
	for column: PackedByteArray in [_kind_said, _no_healer, _skip_infirmary]:
		column.resize(n)
		column.fill(0)
	pace.add_factor("health", state.pace_permille)


func bind_news(notices: NoticesScript, incidents: IncidentsScript) -> void:
	"""Say who is hurt and who was treated in this feed, as incidents on these (either null: silent)."""
	_notices = notices
	_incidents = incidents


func set_places(patch: Vector2, shelf: Vector2) -> void:
	"""The herb patch's standing spot and the shelf's (the hall's steps), m."""
	_patch = patch
	_shelf = shelf


func patch_at() -> Vector2:
	"""The herb patch's standing spot (m)."""
	return _patch


func shelf_at() -> Vector2:
	"""The care shelf's spot, where herbs are delivered and cloth is fetched (m)."""
	return _shelf


func use_pace(shared: PaceScript) -> void:
	"""Read and add to the village's one work pace (demo/work/work_pace.gd) instead of a private one."""
	shared.add_factor("health", state.pace_permille)
	pace = shared


func start_at(tick: int, day: int) -> void:
	"""Begin on calendar `tick`, day `day` (nothing before is owed)."""
	_tick = tick
	_next_dispatch = tick
	state.start_at(tick, day)


# --- each frame ---------------------------------------------------------------------------------------------------

func update(tick: int, day: int, season: int, hunger: PackedInt32Array, rest: PackedInt32Array, night: bool) -> void:
	"""One frame on calendar `tick` (see EACH FRAME); `night` true from dusk to dawn."""
	state.regrow_to(day, season)
	state.advance_to(tick, hunger, rest)
	var ticks: int = maxi(tick - _tick, 0)
	_tick = tick
	_credit_care(ticks)
	_credit_gather(ticks)
	_sync_infirmary()
	_report()
	if tick >= _next_dispatch:
		_next_dispatch = tick + DISPATCH_TICKS
		_dispatch_patients()
		_dispatch_healers()
		_shelve_foraged()
		if not night:
			_dispatch_gather()


func watch_water(swim: SwimStateScript) -> void:
	"""HAZ-003 and HAZ-002 from the water's own state: an exhausted swimmer's EXHAUSTION incident (and its re-arm at
	rest 4000 on land), and an airless episode's EXPOSURE incident while it lasts below with no air."""
	if swim == null:
		return
	for i: int in mini(swim.count, _brains.size()):
		var latched: bool = swim.exhausted_latch[i] == 1
		if latched and not state.exhaustion_latched(i) and state.exhaustion(i):
			_cause[i] = NoticesScript.SOURCE_WATER
			_loss[i] = 0
		elif not latched and state.exhaustion_latched(i):
			state.rearm_exhaustion(i, swim.rest[i])
		var below: bool = swim.mode[i] == SwimStateScript.MODE_DIVE or swim.mode[i] == SwimStateScript.MODE_DISTRESS_UNDER
		if state.set_airless(i, below and swim.air[i] == 0) and state.is_airless(i):
			_cause[i] = NoticesScript.SOURCE_WATER
			_loss[i] = 0


func hurt(i: int, kind: int, severity: int, loss: int, source: int) -> bool:
	"""An injury from `source` (demo_notices.gd SOURCE_*) on resident `i` (care_state.gd `hurt`)."""
	var before: int = state.health(i)
	if not state.hurt(i, kind, severity, loss):
		return false
	_cause[i] = source
	_loss[i] = before - state.health(i)
	return true


func test_hurt(members: PackedInt32Array, serious: bool) -> int:
	"""The Demo Lab's test: each resident in `members` takes §5.4's net hazard (a bite, −20, minor) or, `serious`, its
	boat hazard (exposure, −35, serious). How many were hurt."""
	var hurt_count: int = 0
	for i: int in members:
		if serious:
			hurt_count += 1 if hurt(i, Rules.BOAT_HAZARD_KIND, Rules.BOAT_HAZARD_SEVERITY, Rules.BOAT_HAZARD_LOSS,
				NoticesScript.SOURCE_CREW) else 0
		else:
			hurt_count += 1 if hurt(i, Rules.NET_HAZARD_KIND, Rules.NET_HAZARD_SEVERITY, Rules.NET_HAZARD_LOSS,
				NoticesScript.SOURCE_CREW) else 0
	return hurt_count


# --- work ---------------------------------------------------------------------------------------------------------

func _credit_care(ticks: int) -> void:
	"""This frame's HEAL work: each healer working beside its patient, inputs paid at work start (see HEALERS)."""
	if ticks <= 0:
		return
	for p: int in _treat.size():
		var t: Tasks.Treat = _treat[p]
		if t == null or not t.working():
			continue
		var why: String = state.pay_treatment(p)
		if why == StateScript.REFUSE_NOT_HURT:
			continue
		if why != StateScript.REFUSE_NONE:
			_stand_down(t)
			continue
		var factor: int = Rules.care_factor(state.heal_level(t.healer), pace.permille(t.healer))
		if state.care(p, t.healer, ticks, factor):
			_on_treated(p, t.healer)


func _credit_gather(ticks: int) -> void:
	"""This frame's gathering: §5.2's work at the gatherer's pace into §5.5's work per U, REQ-SET-068's rolls."""
	var g: Tasks.Gather = _gather
	if g == null or ticks <= 0 or not g.picking():
		return
	var made: int = _gather_remainder + Rules.MWU_PER_TICK * pace.permille(g.who) * ticks
	var mwu: int = made / Rules.PERMILLE
	_gather_remainder = made - mwu * Rules.PERMILLE
	g.work_mwu += mwu
	while g.work_mwu >= _herb_mwu_per_u and g.load_milli < g.trip_milli:
		g.work_mwu -= _herb_mwu_per_u
		g.load_milli = mini(g.load_milli + Rules.MILLI, g.trip_milli)
	for _k: int in state.forage(g.who, mwu):
		hurt(g.who, Rules.FORAGE_INJURY_KIND, Rules.FORAGE_INJURY_SEVERITY, Rules.FORAGE_INJURY_LOSS,
			NoticesScript.SOURCE_WOODS)


func _stand_down(t: Tasks.Treat) -> void:
	"""A healer beside a patient whose treatment the shelf can no longer pay for: sent back to its work (H1, decision
	0622); the patient waits, saying why."""
	_no_healer[t.patient] = 1
	_brains[t.healer].work_done()


func _on_treated(p: int, h: int) -> void:
	"""A treatment done: said in the news."""
	revision += 1
	if _notices != null:
		_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, Text.treated_notice(name_of(h), name_of(p),
			_kind_said[p], state.health(p)), "", NoticesScript.TARGET_RESIDENT, p)


func _sync_infirmary() -> void:
	"""REQ-SET-017's infirmary rate for whoever rests inside the infirmary now; a patient no longer resting there leaves
	its bed."""
	for i: int in _brains.size():
		var r: Tasks.BedRest = _rest[i]
		var there: bool = resting(i) and r.where == Tasks.WHERE_INFIRMARY
		if infirmary != null and infirmary.is_admitted(i) and not there:
			infirmary.discharge(i)
			_skip_infirmary[i] = 1 if r != null and r.where == Tasks.WHERE_INFIRMARY and not r.arrived_once else 0
		state.set_in_infirmary(i, there and r.in_place() and infirmary != null and infirmary.is_done())


# --- news ---------------------------------------------------------------------------------------------------------

func _report() -> void:
	"""Each new injury said once: the news line and an incident on the resident, kept until it is up again."""
	for i: int in _brains.size():
		var ordinal: int = state.ordinal_of(i)
		if ordinal == _reported[i]:
			continue
		_reported[i] = ordinal
		if not state.is_hurt(i):
			continue
		_kind_said[i] = state.kind(i)
		revision += 1
		if _incidents != null:
			_incidents.report(INCIDENT_KEY % i, _cause[i], IncidentsScript.SEVERITY_WARNING,
				Text.hurt_notice(name_of(i), state.kind(i), state.severity(i), _loss[i], _cause_words(i)),
				Text.hurt_summary(name_of(i), state.kind(i)), NoticesScript.TARGET_RESIDENT, i, incident_state.bind(i))
		elif _notices != null:
			_notices.post(_cause[i], NoticesScript.LEVEL_WARNING, Text.hurt_notice(name_of(i), state.kind(i),
				state.severity(i), _loss[i], _cause_words(i)), "", NoticesScript.TARGET_RESIDENT, i)


func _cause_words(i: int) -> String:
	"""Where it happened, by the source: "in the water", "gathering herbs", "" otherwise."""
	match _cause[i]:
		NoticesScript.SOURCE_WATER:
			return "in the water"
		NoticesScript.SOURCE_WOODS:
			return "gathering herbs"
	return ""


func incident_state(i: int) -> int:
	"""Resident `i`'s incident now: needing a decision while nothing can treat it (no herbs, no cloth, nobody free),
	assigned while it goes to rest, waits for or has a healer, recovering once treated, resolved once up again."""
	if not state.is_hurt(i):
		return IncidentsScript.STATE_RESOLVED if state.is_up(i) else IncidentsScript.STATE_RECOVERING
	var why: String = waiting_for(i)
	if why == Text.WAIT_NO_HERB or why == Text.WAIT_NO_CLOTH or why == Text.WAIT_NO_HEALER:
		return IncidentsScript.STATE_NEEDS_DECISION
	return IncidentsScript.STATE_ASSIGNED


func waiting_for(p: int) -> String:
	"""What patient `p` waits for, in words (care_text.gd WAIT_*); "" while it is being treated."""
	if _healer_of[p] != NOBODY:
		return "" if _treat[p] != null and _treat[p].working() else Text.WAIT_HEALER
	match state.treatment_refusal(p):
		StateScript.REFUSE_NO_HERB:
			return Text.WAIT_NO_HERB
		StateScript.REFUSE_NO_CLOTH:
			return Text.WAIT_NO_CLOTH
	if not resting(p):
		return Text.WAIT_GOING
	return Text.WAIT_NO_HEALER if _no_healer[p] == 1 else Text.WAIT_HEALER


# --- patients -----------------------------------------------------------------------------------------------------

func _dispatch_patients() -> void:
	"""Every hurt resident that wants rest, may be taken and is not resting yet: to a bed (see PATIENTS)."""
	for i: int in _brains.size():
		if wants_rest(i) and not resting(i) and may_take(i):
			send_to_rest(i)


func wants_rest(i: int) -> bool:
	"""Whether hurt resident `i` should rest now (see UP AND ABOUT): not while it needs a meal, nor with a minor injury
	the shelf cannot pay to treat."""
	if not state.is_hurt(i) or state.needs_a_meal(i):
		return false
	if state.severity(i) == Injury.SEVERITY_SERIOUS or state.is_paid(i):
		return true
	var why: String = state.treatment_refusal(i)
	return why != StateScript.REFUSE_NO_HERB and why != StateScript.REFUSE_NO_CLOTH


func may_get_up(i: int) -> bool:
	"""A resting patient's "morning" (see UP AND ABOUT): hurt, once it no longer wants rest and nobody tends it;
	treated, at CareRules.UP_HEALTH, or at once while it cannot recover (hungry or tired: REQ-SET-017's 4000)."""
	if state.is_hurt(i):
		return not wants_rest(i) and _healer_of[i] == NOBODY
	return state.health(i) >= Rules.UP_HEALTH or not state.can_recover(i)


func resting(i: int) -> bool:
	"""Whether resident `i` rests under its BedRest now."""
	return i >= 0 and i < _rest.size() and _rest[i] != null and _brains[i].task == _rest[i]


func may_take(i: int) -> bool:
	"""Whether resident `i` may be given care's task now: not in the water, held or crossing, under none of the
	player's orders (a move, a work spot, a dig) and in no emergency (an urgent task)."""
	var b: BrainScript = _brains[i]
	if b.water_hold or b.in_water or b.state == BrainScript.State.CROSS:
		return false
	if b.task != null:
		return not b.task.urgent()
	return b.order == BrainScript.ORDER_NONE


func send_to_rest(i: int) -> bool:
	"""Resident `i` to rest (see PATIENTS): the infirmary, its own bed, or the field-care spot. False when the brain
	would not take it."""
	var task := Tasks.BedRest.new(i, may_get_up.bind(i), _alarm(), state.is_hurt.bind(i))
	var admitted: bool = infirmary != null and _skip_infirmary[i] == 0 and infirmary.admit(i)
	_skip_infirmary[i] = 0
	if admitted:
		task.in_infirmary(infirmary.door())
	elif not _own_bed(i, task):
		task.in_field(field_spot(i))
	_brains[i].order_task(task)
	if _brains[i].task != task:
		if admitted:
			infirmary.discharge(i)
		return false
	_rest[i] = task
	revision += 1
	return true


func set_field_spot(spot: Callable) -> void:
	"""`spot(i: int) -> Vector2`: where resident `i` lies for field care (P2: by the hall's steps); unset, where it
	stands."""
	_field_spot = spot


func field_spot(i: int) -> Vector2:
	"""Where resident `i` lies for field care (see `set_field_spot`)."""
	return Vector2(_field_spot.call(i)) if _field_spot.is_valid() else _brains[i].position


func _alarm() -> Callable:
	"""The night's alarm (a threat under way), or never."""
	return _night.alarm if _night != null else func() -> bool: return false


func _own_bed(i: int, task: Tasks.BedRest) -> bool:
	"""Resident `i`'s own bed (the night's allocation), set on `task`; false with none, or none it can reach."""
	if _night == null or i >= _night.bed_of.size():
		return false
	var bed: int = _night.bed_of[i]
	if bed == AllocationScript.NO_BED or _bed_taken(bed, i) or not _night.bed_task_at(i, bed, task.sleep):
		return false
	_mark_bed(task, bed)
	return true


func _mark_bed(task: Tasks.BedRest, bed: int) -> void:
	"""Tell `task` which bed it rests in."""
	var r: int = bed / FixturesScript.PLACES
	var node: int = _graph.rooms.middle[r]
	task.in_bed(bed, r, NightScript.room_name(r), node, _graph.node_m(node))


func _bed_taken(bed: int, i: int) -> bool:
	"""Whether another patient rests in `bed`."""
	for j: int in _rest.size():
		if j != i and resting(j) and _rest[j].bed == bed:
			return true
	return false


# --- healers ------------------------------------------------------------------------------------------------------

func _dispatch_healers() -> void:
	"""Every resting patient with no healer, whose treatment the shelf can pay for -- counting the healers already sent
	and not yet paid (H1); their cloth is reserved in the village stores as each is sent (care_state.gd THE CLOTH) --
	is given the best healer (see HEALERS)."""
	var owed: int = _unpaid_sent()
	for p: int in _brains.size():
		_no_healer[p] = 0
		if _healer_of[p] != NOBODY or not state.is_hurt(p) or not resting(p):
			continue
		if not state.is_paid(p) and (state.treatment_refusal(p) != StateScript.REFUSE_NONE
				or not state.affords(owed + 1)):
			continue
		if _rest[p].where == Tasks.WHERE_INFIRMARY and healers_inside() >= InfirmaryRules.healer_slots():
			continue
		var h: int = choose_healer(p)
		if h == NOBODY or not _send_healer(h, p):
			_no_healer[p] = 1
		elif not state.is_paid(p):
			owed += 1


func healers_inside() -> int:
	"""Healers treating patients in the infirmary now ("Healer 2": at most infirmary_rules.gd `healer_slots()`)."""
	var n: int = 0
	for p: int in _healer_of.size():
		n += 1 if _healer_of[p] != NOBODY and _rest[p] != null and _rest[p].where == Tasks.WHERE_INFIRMARY else 0
	return n


func _unpaid_sent() -> int:
	"""Healers sent whose patients' treatments are not paid yet: the shelf's inputs they will take."""
	var owed: int = 0
	for p: int in _healer_of.size():
		owed += 1 if _healer_of[p] != NOBODY and not state.is_paid(p) else 0
	return owed


func choose_healer(p: int) -> int:
	"""The best healer for patient `p`: the highest HEAL level, then the nearest, then the lower index (NOBODY)."""
	var best: int = NOBODY
	var best_level: int = -1
	var best_d: float = INF
	for h: int in _brains.size():
		if h == p or not may_heal(h) or not reaches(h, p):
			continue
		var level: int = state.heal_level(h)
		var d: float = _brains[h].position.distance_squared_to(_brains[p].position)
		if level > best_level or (level == best_level and d < best_d):
			best = h
			best_level = level
			best_d = d
	return best


func reaches(h: int, p: int) -> bool:
	"""Whether healer `h` can get to patient `p`'s bed (its home's middle by the network, as the night tests it); a patient
	at its field-care spot is on the surface, reached by anyone."""
	var r: Tasks.BedRest = _rest[p]
	if r == null or r.where != Tasks.WHERE_BED or _graph == null:
		return true
	var fit_class: int = _graph.walker_class(h, false)
	return fit_class != PathsScript.CLASS_NONE and _graph.paths.nearest_mouth(_graph, r.middle_node, fit_class) >= 0


func may_heal(h: int) -> bool:
	"""Whether resident `h` may treat someone now: up, not treating already, not resting, and may be taken."""
	return state.is_up(h) and not _healer_of.has(h) and not resting(h) and may_take(h)


func _send_healer(h: int, p: int) -> bool:
	"""Healer `h` to patient `p`, its treatment's cloth reserved in the stores first (care_state.gd `claim_cloth`); false
	when the cloth is short or the brain would not take it (the reservation given back)."""
	if not state.claim_cloth(p):
		return false
	var t := Tasks.Treat.new(h, _rest[p], _brains[p], state.is_hurt.bind(p), treat_words.bind(h, p), _on_treat_ended)
	_healer_of[p] = h
	_treat[p] = t
	_brains[h].order_task(t)
	if _brains[h].task != t:
		_healer_of[p] = NOBODY
		_treat[p] = null
		_give_back_cloth(p)
		return false
	revision += 1
	return true


func _give_back_cloth(p: int) -> void:
	"""Patient `p`'s treatment cloth back to the stores while its treatment is unpaid (paid, it was taken)."""
	if not state.is_paid(p):
		state.release_cloth(p)


func _on_treat_ended(h: int, p: int) -> void:
	"""A healer stopped (done or called away): the care work done stays the patient's, an unpaid treatment's cloth goes
	back to the stores; it may be sent again."""
	state.book_care(p)
	if _healer_of[p] == h:
		_healer_of[p] = NOBODY
		_treat[p] = null
		_give_back_cloth(p)
	revision += 1


func healer_of(p: int) -> int:
	"""Who treats patient `p` now (NOBODY)."""
	return _healer_of[p] if p >= 0 and p < _healer_of.size() else NOBODY


func treat_words(h: int, p: int) -> String:
	"""The healer's task in words: "Treating Corra Netley — 40%"."""
	var t: Tasks.Treat = _treat[p] if p < _treat.size() else null
	if t == null or t.healer != h or not t.working():
		return "Going to treat %s" % name_of(p)
	return "Treating %s — %d%%" % [name_of(p), state.care_mwu(p) * 100 / Rules.CARE_WORK_MWU]


# --- the herbalist ------------------------------------------------------------------------------------------------

func _shelve_foraged() -> void:
	"""The pantry's free herb onto the shelf while it is short (see ONE SHELF, TWO SOURCES), said once a move."""
	if not pantry_herb.is_valid() or state.herb_milli >= Rules.HERB_TARGET_MILLI:
		return
	var moved: int = state.shelve_herbs(int(pantry_herb.call(Rules.HERB_TARGET_MILLI - state.herb_milli)))
	if moved > 0 and _notices != null:
		_notices.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "%s U of the foragers' herbs went to the care shelf (%s U)"
			% [Text.units(moved), Text.units(state.herb_milli)])


func _dispatch_gather() -> void:
	"""The idle herbalist to the patch while the shelf is short (see THE HERBALIST GATHERS)."""
	if _gather != null or herbalist == NOBODY or state.herb_milli >= Rules.HERB_TARGET_MILLI:
		return
	var available: int = state.patch_available_milli()
	var b: BrainScript = _brains[herbalist]
	if available < Rules.MILLI or b.task != null or b.order != BrainScript.ORDER_NONE or b.resting or b.in_water \
			or b.water_hold or not state.is_up(herbalist) or _healer_of.has(herbalist):
		return
	var trip: int = mini(Rules.HERB_TRIP_MILLI, available / Rules.MILLI * Rules.MILLI)
	var g := Tasks.Gather.new(herbalist, _patch, _shelf, trip, _deliver, _on_gather_ended)
	b.order_task(g)
	if b.task == g:
		_gather = g
		_gather_remainder = 0
		revision += 1


func _deliver(who: int, milli: int) -> void:
	"""A load at the shelf: booked (care_state.gd `deliver_herbs`) and said."""
	var moved: int = state.deliver_herbs(milli)
	if moved > 0 and _notices != null:
		_notices.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "%s brought %s U of herbs to the shelf (%s U)"
			% [name_of(who), Text.units(moved), Text.units(state.herb_milli)], "", NoticesScript.TARGET_RESIDENT, who)


func _on_gather_ended(who: int) -> void:
	"""The gatherer stopped (delivered or called away)."""
	if _gather != null and _gather.who == who:
		_gather = null
		revision += 1


func gatherer() -> Tasks.Gather:
	"""The gathering trip under way (null: none)."""
	return _gather


# --- words --------------------------------------------------------------------------------------------------------

func name_of(i: int) -> String:
	"""Resident `i`'s name."""
	return _names[i] if i >= 0 and i < _names.size() else "someone"


func card_text(i: int, alone: bool) -> String:
	"""The party panel's lines for resident `i` (demo_command.gd `add_skill_text`): alone, its injury or recovery, a
	slowed pace and its healing skill, a line each; in a group, one short word."""
	if i < 0 or i >= _brains.size():
		return ""
	if not alone:
		return Text.short_word(state.is_hurt(i), state.kind(i), state.health(i))
	var lines := PackedStringArray()
	if state.is_hurt(i):
		lines.append_array(Text.hurt_lines(state.health(i), state.kind(i), state.severity(i), state.untreated_hours(i),
			state.rate_per_hour(i), _care_line(i)))
	elif state.health(i) < Rules.HEALTH_MAX:
		var rate: int = state.rate_per_hour(i)
		lines.append(Text.recovering_line(state.health(i), rate, state.in_infirmary(i), resting(i)) if rate >= 0
			else Text.health_line(state.health(i), rate, state.is_starving(i)))
	var slow: String = pace.slowed_text(i)
	if not slow.is_empty():
		lines.append(slow.left(1).to_upper() + slow.substr(1))
	if state.heal_xp[i] > 0:
		lines.append(Text.skill_line(state.heal_level(i)))
	return "\n".join(lines)


func _care_line(p: int) -> String:
	"""A patient's treatment line: its healer and progress, or what it waits for."""
	var h: int = _healer_of[p]
	if h != NOBODY and _treat[p] != null and _treat[p].working():
		return Text.care_words(name_of(h), state.care_mwu(p) * 100 / Rules.CARE_WORK_MWU, "")
	return Text.care_words("", 0, waiting_for(p))


func infirmary_lines() -> String:
	"""The Tunnels panel's infirmary section lines: the building's state, the supplies, the herb patch, the patients."""
	var lines := PackedStringArray()
	lines.append(infirmary.status_text() if infirmary != null else "No infirmary")
	lines.append(Text.supplies_line(state.herb_milli, state.cloth_milli))
	lines.append(Text.patch_line(state.patch_milli, Rules.HERB_FLOOR_MILLI))
	lines.append(patients_line())
	return "\n".join(lines)


func patients_line() -> String:
	"""Who is hurt or resting now: "Patients: Corra Netley (bite)" or "No patients"."""
	var who := PackedStringArray()
	for i: int in _brains.size():
		if state.is_hurt(i) or resting(i):
			who.append("%s (%s)" % [name_of(i), Text.short_word(state.is_hurt(i), state.kind(i), state.health(i))])
	return "No patients" if who.is_empty() else "Patients: " + ", ".join(who)
