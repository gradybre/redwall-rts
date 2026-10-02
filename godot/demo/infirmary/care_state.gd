extends RefCounted
## THE CARE STATE: every demo resident's health and injury, the herbalist's skill, and the care supplies -- integer,
## packed, and run on the demo's one calendar. Decision 0622. Presentation only: the settlement simulation's own stores
## are never written; this owns PRIVATE instances of the real ones.
##
## THE REAL STORES, PRIVATELY. Health and the injury row are not re-implemented here: a private `scripts/core/needs.gd`
## holds each resident's health with GDD §5.2's single health rate (untreated drain, recovery, the infirmary rate,
## starvation and HAZ-002's airless term summed and integrated with the remainder rule), and a private
## `scripts/core/injury.gd` holds GDD §4.2's Injury row (the merge rule, HAZ-004's ordinal dedupe, care progress,
## treatment). One row per demo resident, the actor index as the slot.
##
## THE DEMO'S OWN NEEDS ARE MIRRORED IN. Hunger is the kitchen's (demo/kitchen/nourishment.gd), rest is the water's
## stamina (demo/waterplay/swim_state.gd): before every integrated tick each is written into the private needs row, so
## REQ-SET-017's "hunger/rest >= 4000" and REQ-SET-014's starvation read the demo's real figures, never the private
## row's own decay. Comfort, social and purpose are not read by health and are left to drift. Cold stays NEUTRAL: cold
## damage is the winter owner's, so this adds none (decision 0621).
##
## QUIET TICKS ARE SKIPPED. While every resident is at full health, uninjured, breathing and not starving, no term of
## the health rate is non-zero, so integrating would change nothing: those ticks are counted and skipped. Only while
## someone's health is moving does a tick integrate (each store's `tick_all`; the core API returns a result object from
## each call, freed at once: nothing is retained).
##
## A JUMP. A moving tick costs both stores' sweeps (~130 us). When the calendar jumps (the Lab's Next weather runs up to
## 48 hours in one frame), all but the last CareRules.MAX_TICKS_PER_FRAME ticks are taken in closed form: hunger and
## rest are one figure across the frame, so each resident's health rate is constant over the span, and its health moves
## by that rate in whole points, the fraction dropped (clamped to the floor and 100); the last ticks integrate one by
## one. Nothing is owed to a
## later frame, so an event never lands on old time. The span does not advance the injury row's untreated-hours
## counter (a readout; the core store has no bulk setter). Quiet ticks are skipped all at once.
##
## THE FLOOR (decision 0622 P1). Health never falls below CareRules.HEALTH_FLOOR (16): an incident's immediate loss is
## capped at what lies above it, and a tick that brings health under it is answered by restoring the difference at
## once (a tick moves health by at most one point at these rates, so 0 is never reached). `floor_holds` counts them.
##
## SUPPLIES (REQ-SET-173's herb 1 + cloth 0.5, §5.1's starting 12 + 24 U) are paid once per injury at the treatment's
## WORK START (§5.3: "Input consumption occurs at WORK start"), so a healer called away and replaced never pays twice;
## the care work is the patient's (HAZ-004: "changing helpers retains WIP").
##
## THE CLOTH is the village's one cloth in the stores (tunnel_stores.gd CLOTH; Brendan's ruling on R01, decision 0993),
## shared with the hall's upgrade and the infirmary building. A treatment RESERVES its 0.5 U there when its healer is sent
## (`claim_cloth`), under the treatments' claim, so neither building can carry it off meanwhile; the reservation is lifted
## at work start (`pay_treatment`) or given back when the healer stops unpaid (`release_cloth`). Unbound (`use_cloth`
## never called, as in a unit test), the state keeps private stores of its own holding the same opening 24 U.

const Rules := preload("res://demo/infirmary/care_rules.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Injury := preload("res://scripts/core/injury.gd")
const Rng := preload("res://scripts/core/rng.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

@warning_ignore_start("integer_division")

## What `pay_treatment` refuses for.
const REFUSE_NONE: String = ""
const REFUSE_NO_HERB: String = "NO_HERB"
const REFUSE_NO_CLOTH: String = "NO_CLOTH"
const REFUSE_NOT_HURT: String = "NOT_HURT"

## Bumped whenever anything a reader shows changes (an injury, a treatment, the supplies, the infirmary).
var revision: int = 0
## Ticks integrated and skipped as quiet, treatments completed, incidents applied, and floor catches so far.
var ticks_integrated: int = 0
var ticks_quiet: int = 0
var treated: int = 0
var incidents: int = 0
var floor_holds: int = 0
## Ticks taken in closed form (see A JUMP).
var ticks_fast: int = 0
## The care supplies, milli-U (§5.1's starting stocks), and the herb patch's stock (§5.5).
var herb_milli: int = Rules.START_HERB_MILLI
var patch_milli: int = Rules.HERB_START_MILLI
## The stores whose cloth the treatments draw on (see THE CLOTH).
var cloth_store: StoresScript = StoresScript.new()
## The village's cloth now, milli-U: the stores' one cloth, read and written through (see THE CLOTH).
var cloth_milli: int:
	get:
		return cloth_store.cloth_milli_u
	set(value):
		cloth_store.cloth_milli_u = value
## Per resident: HEAL XP (§5.3), the incident ordinal last used (HAZ-004), the inputs paid for the open injury, whether
## it lies in an infirmary bed, whether it is airless (HAZ-002), its healer's retained work remainder and total HEAL
## work (milli-WU), care work not yet booked to the patient's injury row, and its foraging work total (milli-WU).
var heal_xp: PackedInt32Array = PackedInt32Array()
var _ordinal: PackedInt64Array = PackedInt64Array()
var _paid: PackedByteArray = PackedByteArray()
var _infirmary: PackedByteArray = PackedByteArray()
var _airless: PackedByteArray = PackedByteArray()
var _work_remainder: PackedInt64Array = PackedInt64Array()
var _heal_mwu: PackedInt64Array = PackedInt64Array()
var _pending_mwu: PackedInt64Array = PackedInt64Array()
## Care work booked into the patient's injury row (its `care_progress_mwu`, mirrored so no reader allocates).
var _booked_mwu: PackedInt64Array = PackedInt64Array()
## The injury row's severity, mirrored at each incident and treatment so the per-frame readers allocate nothing.
var _severity: PackedByteArray = PackedByteArray()
var _forage_mwu: PackedInt64Array = PackedInt64Array()
## Per resident: the cloth its treatment holds reserved in the stores (see THE CLOTH), milli-U.
var _cloth_claim: PackedInt64Array = PackedInt64Array()

var _needs: Needs = Needs.new()
var _injury: Injury = Injury.new()
var _rng: Rng = Rng.new()
var _count: int = 0
var _tick: int = 0
var _day: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(size_classes: PackedByteArray, herbalist: int) -> void:
	"""One row per resident (its §5.2 size class), at full health and uninjured; `herbalist` (-1: none) starts at
	CareRules.HERBALIST_LEVEL in HEAL (P3)."""
	_count = size_classes.size()
	for column: PackedInt64Array in [_ordinal, _work_remainder, _heal_mwu, _pending_mwu, _booked_mwu, _forage_mwu,
			_cloth_claim]:
		column.resize(_count)
		column.fill(0)
	for column: PackedByteArray in [_paid, _infirmary, _airless, _severity]:
		column.resize(_count)
		column.fill(0)
	heal_xp.resize(_count)
	heal_xp.fill(0)
	for i: int in _count:
		_needs.spawn(i, clampi(size_classes[i], 0, Needs.SIZE_COUNT - 1))
		_injury.spawn(i)
	if herbalist >= 0 and herbalist < _count:
		heal_xp[herbalist] = Rules.xp_of_level(Rules.HERBALIST_LEVEL)
	_rng.seed_world(Rules.WORLD_SEED)
	revision += 1


func use_cloth(stores: StoresScript) -> void:
	"""Draw the treatments' cloth from these village stores (see THE CLOTH); before any treatment is sent."""
	if stores != null:
		cloth_store = stores


func resident_count() -> int:
	"""How many residents have rows."""
	return _count


func start_at(tick: int, day: int) -> void:
	"""Begin integrating from calendar `tick` (nothing before it is owed) on calendar `day`."""
	_tick = tick
	_day = day


# --- the clock ----------------------------------------------------------------------------------------------------

func advance_to(tick: int, hunger: PackedInt32Array, rest: PackedInt32Array) -> int:
	"""Bring health up to calendar `tick` (see QUIET TICKS, A JUMP and THE FLOOR) with the demo's own hunger and rest
	mirrored in; returns how many ticks were integrated one by one."""
	if _tick >= tick:
		return 0
	if _quiet(hunger):
		ticks_quiet += tick - _tick
		_tick = tick
		return 0
	if tick - _tick > Rules.MAX_TICKS_PER_FRAME:
		_fast_forward(tick - _tick - Rules.MAX_TICKS_PER_FRAME, hunger, rest)
	var ran: int = 0
	while _tick < tick:
		_tick += 1
		_mirror_all(hunger, rest)
		if _injury.injured_count() > 0:
			_injury.tick_all(_needs)
		_needs.tick_all()
		_hold_the_floor()
		ticks_integrated += 1
		ran += 1
	return ran


func _fast_forward(ticks: int, hunger: PackedInt32Array, rest: PackedInt32Array) -> void:
	"""A JUMP's span: each resident's health moved by its constant rate over `ticks`, in whole points, clamped to the
	floor and 100 (the inputs are one figure across the span, so the rate is too)."""
	_mirror_all(hunger, rest)
	for i: int in _count:
		var now: int = health(i)
		var target: int = clampi(now + rate_per_hour(i) * ticks / Needs.TICKS_PER_HOUR, Rules.HEALTH_FLOOR, Rules.HEALTH_MAX)
		if target != now:
			_needs.apply_health_event(i, target - now)
	_tick += ticks
	ticks_fast += ticks
	revision += 1


func _quiet(hunger: PackedInt32Array) -> bool:
	"""Whether no term of anyone's health rate is non-zero: full health, no injury, breathing, not starving."""
	if _injury.injured_count() > 0:
		return false
	for i: int in _count:
		if _airless[i] == 1 or _hunger_of(hunger, i) == 0:
			return false
		if not _needs.health_into(i, _read) or _read.value < Rules.HEALTH_MAX:
			return false
	return true


func _hunger_of(hunger: PackedInt32Array, i: int) -> int:
	"""Resident `i`'s demo hunger (fed, 10000, when the kitchen has no row for it)."""
	return hunger[i] if i < hunger.size() else Needs.NEED_MAX


func _mirror_all(hunger: PackedInt32Array, rest: PackedInt32Array) -> void:
	"""Write the demo's hunger and rest into every private needs row (see THE DEMO'S OWN NEEDS)."""
	for i: int in _count:
		sync_needs(i, _hunger_of(hunger, i), rest[i] if i < rest.size() else Needs.NEED_MAX)


func sync_needs(i: int, hunger: int, rest: int) -> void:
	"""Mirror one resident's demo hunger and rest into its private needs row (no change: no call)."""
	_mirror(i, Needs.NEED_HUNGER, hunger)
	_mirror(i, Needs.NEED_REST, rest)


func _mirror(i: int, need: int, value: int) -> void:
	"""Move one private need to `value` (clamped 0..10000) when it differs."""
	if not _needs.need_into(i, need, _read):
		return
	var delta: int = clampi(value, Needs.NEED_MIN, Needs.NEED_MAX) - _read.value
	if delta != 0:
		_needs.apply_need_event(i, need, delta)


func _hold_the_floor() -> void:
	"""Lift anyone a tick brought under the floor back onto it (see THE FLOOR)."""
	for i: int in _count:
		if _needs.health_into(i, _read) and _read.value < Rules.HEALTH_FLOOR:
			_needs.apply_health_event(i, Rules.HEALTH_FLOOR - _read.value)
			floor_holds += 1
			revision += 1


func regrow_to(day: int, season: int) -> int:
	"""§5.5's daily regrowth of the herb patch for every midnight up to calendar `day`, in `season`; the milli-U grown."""
	var grown: int = 0
	while _day < day:
		_day += 1
		var add: int = Rules.herb_regrowth_milli(patch_milli, season)
		patch_milli += add
		grown += add
	if grown > 0:
		revision += 1
	return grown


# --- injuries -----------------------------------------------------------------------------------------------------

func hurt(i: int, injury_kind: int, injury_severity: int, loss: int) -> bool:
	"""One injury incident on resident `i` (GDD §4.2's merge) of `injury_kind` and `injury_severity`, its immediate `loss`
	capped at the floor. False when the core refuses it (no such row, a bad kind or severity)."""
	if not _valid(i):
		return false
	_needs.health_into(i, _read)
	var capped: int = clampi(mini(loss, _read.value - Rules.HEALTH_FLOOR), 0, Rules.HEALTH_MAX)
	var applied: Needs.OpResult = _injury.apply_incident(i, injury_kind, injury_severity, capped, _ordinal[i] + 1, _needs)
	_take_ordinal(i, applied.ok)
	return _counted(applied.ok)


func exhaustion(i: int) -> bool:
	"""HAZ-003's exhaustion incident (EXHAUSTION, severity 1, no immediate loss), latched until `rearm_exhaustion`."""
	if not _valid(i) or _injury.exhaustion_latched(i):
		return false
	var ok: bool = _injury.apply_exhaustion_incident(i, _ordinal[i] + 1, _needs).ok
	_take_ordinal(i, ok)
	return _counted(ok)


func rearm_exhaustion(i: int, rest: int) -> bool:
	"""HAZ-003's re-arm at rest 4000 on safe support (the caller's): `rest` mirrored in first."""
	if not _valid(i) or not _injury.exhaustion_latched(i):
		return false
	_mirror(i, Needs.NEED_REST, rest)
	return _injury.rearm_exhaustion(i, _needs).ok


func set_airless(i: int, airless: bool) -> bool:
	"""HAZ-002: entering an airless episode is ONE exposure incident (severity 2, no immediate loss) and the −125 an
	hour term; leaving it ends both. True when the state changed."""
	if not _valid(i) or (_airless[i] == 1) == airless:
		return false
	_airless[i] = 1 if airless else 0
	_needs.set_airless(i, airless)
	if airless:
		var ok: bool = _injury.begin_airless_episode(i, _ordinal[i] + 1, _needs).ok
		_take_ordinal(i, ok)
		_counted(ok)
	else:
		_injury.end_airless_episode(i)
	revision += 1
	return true


func _take_ordinal(i: int, ok: bool) -> void:
	"""HAZ-004's incident ordinal moves on only for an incident the core accepted (a refused one leaves it); the
	severity mirror follows the merge."""
	if ok:
		_ordinal[i] += 1
		_severity[i] = _injury.severity_of(i).value


func _counted(ok: bool) -> bool:
	"""Count an applied incident; pass `ok` on."""
	if ok:
		incidents += 1
		revision += 1
	return ok


func _valid(i: int) -> bool:
	"""Whether `i` is a resident row."""
	return i >= 0 and i < _count


# --- treatment ----------------------------------------------------------------------------------------------------

func treatment_refusal(i: int) -> String:
	"""Why resident `i`'s treatment cannot start now (REFUSE_NONE: it can): not hurt, or the supplies short."""
	if not is_hurt(i):
		return REFUSE_NOT_HURT
	if _paid[i] == 1:
		return REFUSE_NONE
	if herb_milli < Rules.CARE_HERB_MILLI:
		return REFUSE_NO_HERB
	if _cloth_claim[i] >= Rules.CARE_CLOTH_MILLI:
		return REFUSE_NONE
	return REFUSE_NO_CLOTH if cloth_store.cloth_free() < Rules.CARE_CLOTH_MILLI else REFUSE_NONE


func affords(treatments: int) -> bool:
	"""Whether the shelf holds the herb of `treatments` more treatments (healers sent but not yet paid count). Their
	cloth is reserved in the stores as each healer is sent (`claim_cloth`; see THE CLOTH)."""
	return herb_milli >= Rules.CARE_HERB_MILLI * treatments


func claim_cloth(i: int) -> bool:
	"""Reserve resident `i`'s treatment cloth in the stores (see THE CLOTH): true when it holds it now -- reserved now,
	or already, or its treatment paid -- false when the stores' free cloth is short (nothing reserved)."""
	if not _valid(i):
		return false
	if _paid[i] == 1 or _cloth_claim[i] >= Rules.CARE_CLOTH_MILLI:
		return true
	if cloth_store.cloth_free() < Rules.CARE_CLOTH_MILLI - _cloth_claim[i]:
		return false
	_cloth_claim[i] += cloth_store.reserve_cloth(StoresScript.CLOTH_TREATMENT, Rules.CARE_CLOTH_MILLI - _cloth_claim[i])
	revision += 1
	return true


func release_cloth(i: int) -> void:
	"""Give resident `i`'s unpaid treatment cloth reservation back to the stores (its healer stopped before work)."""
	if not _valid(i) or _cloth_claim[i] <= 0:
		return
	cloth_store.release_cloth(StoresScript.CLOTH_TREATMENT, _cloth_claim[i])
	_cloth_claim[i] = 0
	revision += 1


func cloth_claim_of(i: int) -> int:
	"""The cloth resident `i`'s treatment holds reserved in the stores, milli-U."""
	return _cloth_claim[i] if _valid(i) else 0


func pay_treatment(i: int) -> String:
	"""Pay resident `i`'s treatment inputs at work start, once per injury (see SUPPLIES): the herb off the shelf, the
	cloth its reservation lifted from the stores (reserved now when it had none; see THE CLOTH). REFUSE_NONE when paid
	now or already."""
	var why: String = treatment_refusal(i)
	if why != REFUSE_NONE or _paid[i] == 1:
		return why
	claim_cloth(i)
	release_cloth(i)
	if not cloth_store.take_cloth(Rules.CARE_CLOTH_MILLI):
		return REFUSE_NO_CLOTH
	herb_milli -= Rules.CARE_HERB_MILLI
	_paid[i] = 1
	revision += 1
	return REFUSE_NONE


func is_paid(i: int) -> bool:
	"""Whether resident `i`'s open injury's treatment inputs are paid."""
	return _valid(i) and _paid[i] == 1


func care(patient: int, healer: int, ticks: int, factor: int) -> bool:
	"""`ticks` work ticks of HEAL by `healer` on `patient` at work factor `factor` (§5.2: 80 milli-WU x factor / 1000 a
	tick, the remainder kept by the healer); 10 XP a whole WU. True when the treatment completed: the injury cleared
	and +10 health (REQ-SET-173). Needs the inputs paid."""
	if not _valid(patient) or not _valid(healer) or ticks <= 0 or _paid[patient] == 0 or not is_hurt(patient):
		return false
	var made: int = _work_remainder[healer] + Rules.MWU_PER_TICK * maxi(factor, 0) * ticks
	var mwu: int = made / Rules.MILLI
	_work_remainder[healer] = made - mwu * Rules.MILLI
	var before: int = _heal_mwu[healer] / Rules.MILLI
	_heal_mwu[healer] += mwu
	heal_xp[healer] += (_heal_mwu[healer] / Rules.MILLI - before) * Rules.XP_PER_WU
	_pending_mwu[patient] += mwu
	if care_mwu(patient) < Rules.CARE_WORK_MWU:
		return false
	return _complete(patient)


func _complete(patient: int) -> bool:
	"""Book the patient's care work into its injury row and complete the treatment (REQ-SET-173)."""
	book_care(patient)
	var done: Needs.OpResult = _injury.complete_treatment(patient, Rules.CARE_WORK_MWU, _needs)
	if not done.ok:
		return false
	_paid[patient] = 0
	_booked_mwu[patient] = 0
	_severity[patient] = Injury.SEVERITY_NONE
	treated += 1
	revision += 1
	return true


func book_care(patient: int) -> void:
	"""Move care work done but not yet booked into the patient's injury row (a healer stopping, or a treatment
	completing): the work is the patient's, whoever does the rest (HAZ-004)."""
	if not _valid(patient) or _pending_mwu[patient] <= 0:
		return
	if _injury.add_care_work(patient, _pending_mwu[patient], _needs).ok:
		_booked_mwu[patient] += _pending_mwu[patient]
		_pending_mwu[patient] = 0


func set_in_infirmary(i: int, inside: bool) -> void:
	"""Whether resident `i` lies in an infirmary bed now: REQ-SET-017's +4 an hour instead of +2."""
	if not _valid(i) or (_infirmary[i] == 1) == inside:
		return
	_infirmary[i] = 1 if inside else 0
	_needs.set_infirmary(i, inside)
	revision += 1


# --- herbs --------------------------------------------------------------------------------------------------------

func patch_available_milli() -> int:
	"""Herb the patch can give above its sustainable floor (§5.5: 20% K)."""
	return maxi(patch_milli - Rules.HERB_FLOOR_MILLI, 0)


func shelve_herbs(milli: int) -> int:
	"""Herb from the pantry (the foragers' `herb`: decision 0902) put on the shelf, all of `milli`; the milli-U shelved."""
	if milli <= 0:
		return 0
	herb_milli += milli
	revision += 1
	return milli


func deliver_herbs(milli: int) -> int:
	"""A gathered load reaches the shelf: up to `milli` taken from the patch above its floor onto the shelf (the patch
	is debited only now, so a trip called away takes nothing). The milli-U delivered."""
	var moved: int = clampi(milli, 0, patch_available_milli())
	patch_milli -= moved
	herb_milli += moved
	if moved > 0:
		revision += 1
	return moved


func forage(i: int, mwu: int) -> int:
	"""`mwu` more foraging work by resident `i`; REQ-SET-068's roll for every 60 WU it completes (one FORAGE draw
	each, at the patch's danger); returns the injuries rolled (each one the caller's `hurt`)."""
	if not _valid(i) or mwu <= 0:
		return 0
	var segment: int = Rules.FORAGE_SEGMENT_WU * Rules.MILLI
	var before: int = _forage_mwu[i] / segment
	_forage_mwu[i] += mwu
	var chance: int = Rules.forage_injury_chance(Rules.PATCH_DANGER, Rules.FORAGE_LEVEL)
	var injuries: int = 0
	for _s: int in _forage_mwu[i] / segment - before:
		if _rng.draw_below_into(Rng.STREAM_FORAGE, Rules.ROLL_DENOMINATOR, _read) and _read.value < chance:
			injuries += 1
	return injuries


# --- readers ------------------------------------------------------------------------------------------------------

func health(i: int) -> int:
	"""Resident `i`'s health 0..100 (0 out of range)."""
	return _read.value if _valid(i) and _needs.health_into(i, _read) else 0


func is_hurt(i: int) -> bool:
	"""Whether resident `i` carries an injury (every injury is untreated until its treatment clears it)."""
	return _valid(i) and _injury.is_injured(i)


func kind(i: int) -> int:
	"""Resident `i`'s InjuryKind (KIND_NONE when unhurt)."""
	return _injury.kind_of(i).value if is_hurt(i) else Injury.KIND_NONE


func severity(i: int) -> int:
	"""Resident `i`'s injury severity, 1 or 2 (0 when unhurt)."""
	return _severity[i] if _valid(i) else Injury.SEVERITY_NONE


func untreated_hours(i: int) -> int:
	"""Whole hours resident `i`'s injury has gone untreated (GDD §4.2 `untreated_hours`)."""
	return _injury.untreated_hours_of(i).value if is_hurt(i) else 0


func care_mwu(i: int) -> int:
	"""Treatment work done on resident `i`'s injury, booked and not yet booked (milli-WU)."""
	if not is_hurt(i):
		return 0
	return _booked_mwu[i] + _pending_mwu[i]


func ordinal_of(i: int) -> int:
	"""The last incident ordinal used on resident `i` (HAZ-004): it moves once per incident applied."""
	return _ordinal[i] if _valid(i) else 0


func is_starving(i: int) -> bool:
	"""Whether resident `i`'s mirrored hunger is 0 (REQ-SET-014)."""
	return _valid(i) and _needs.need_into(i, Needs.NEED_HUNGER, _read) and _read.value == 0


func in_infirmary(i: int) -> bool:
	"""Whether resident `i` recovers at the infirmary's rate now."""
	return _valid(i) and _infirmary[i] == 1


func is_airless(i: int) -> bool:
	"""Whether resident `i` is in an airless episode (HAZ-002)."""
	return _valid(i) and _airless[i] == 1


func exhaustion_latched(i: int) -> bool:
	"""Whether resident `i`'s exhaustion incident is latched (HAZ-003)."""
	return _valid(i) and _injury.exhaustion_latched(i)


func is_up(i: int) -> bool:
	"""Whether resident `i` may be up and working (P4): no injury and health at least CareRules.UP_HEALTH."""
	return not is_hurt(i) and health(i) >= Rules.UP_HEALTH


func can_recover(i: int) -> bool:
	"""REQ-SET-017's need half: whether resident `i`'s mirrored hunger and rest are both at least 4000."""
	if not _valid(i) or not _needs.need_into(i, Needs.NEED_HUNGER, _read) or _read.value < Rules.RECOVERY_NEED_FLOOR:
		return false
	return _needs.need_into(i, Needs.NEED_REST, _read) and _read.value >= Rules.RECOVERY_NEED_FLOOR


func needs_a_meal(i: int) -> bool:
	"""Whether resident `i`'s mirrored hunger is at the eating threshold (REQ-SET-012: 3500 or lower)."""
	return _valid(i) and _needs.need_into(i, Needs.NEED_HUNGER, _read) and _read.value <= Rules.EAT_AT_HUNGER


func status(i: int) -> int:
	"""Resident `i`'s §5.2 status (Needs.STATUS_*)."""
	return _needs.status_of(i).value if _valid(i) else Needs.STATUS_ACTIVE


func heal_level(i: int) -> int:
	"""Resident `i`'s HEAL level (§5.3)."""
	return Rules.level_of(heal_xp[i]) if _valid(i) else 0


func pace_permille(i: int) -> int:
	"""Resident `i`'s §5.2 health factor per mille: the infirmary's work-pace factor (demo/work/work_pace.gd)."""
	return Rules.health_factor(health(i)) if _valid(i) else Rules.PERMILLE


func rate_per_hour(i: int) -> int:
	"""Resident `i`'s health rate an hour by the injury, airless, starvation and recovery terms the demo models (a
	readout: the integration is needs.gd's), for the card."""
	if not _valid(i):
		return 0
	var sev: int = severity(i)
	var rate: int = -Rules.UNTREATED_DRAIN_PER_HOUR[sev]
	if _airless[i] == 1:
		rate -= Rules.AIRLESS_DRAIN_PER_HOUR
	_needs.need_into(i, Needs.NEED_HUNGER, _read)
	var hunger: int = _read.value
	if hunger == 0:
		rate -= Rules.STARVATION_DRAIN_PER_HOUR
	_needs.need_into(i, Needs.NEED_REST, _read)
	var rested: int = _read.value
	var recovers: bool = health(i) < Rules.HEALTH_MAX and sev != Injury.SEVERITY_SERIOUS \
		and hunger >= Rules.RECOVERY_NEED_FLOOR and rested >= Rules.RECOVERY_NEED_FLOOR
	if recovers:
		rate += Rules.RECOVERY_INFIRMARY_PER_HOUR if _infirmary[i] == 1 else Rules.RECOVERY_PER_HOUR
	return rate


func needs_store() -> Needs:
	"""The private needs store (tests read it)."""
	return _needs


func injury_store() -> Injury:
	"""The private injury store (tests read it)."""
	return _injury
