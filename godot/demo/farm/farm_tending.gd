extends RefCounted
## TENDING POLICIES WITH WORK BUDGETS (review ECO-007, decision 0885): standing orders a group of beds may follow --
## "protect from forecast frost", "water below the suitable band", "avoid waterlogging", and (Brendan's ruling E5,
## decision 0886) "sow empty beds in season" -- each spending at most the
## group's daily WORK BUDGET, and saying only what it could NOT do (the review: "notify exceptions, not every
## successful cover"). Presentation-side automation of the demo farm's own verbs: it orders the very jobs the bed panel
## orders (farm_crew.gd `order`, ORIGIN_ROUTINE), so the work board, the cook's garden hours and every refusal apply.
##
## THE GROUPS are the field beds (farm_catalog.gd's twelve) and the kitchen garden (its laid beds; farm_garden.gd). Each
## group has its four policies, all OFF here -- the GDD's FieldPolicy default (`auto_rotation=false`, R06-JOB-005) --
## and the LIVE VILLAGE turns the field's SOW on at its start (demo_village.gd `_build_farm`: Brendan's ruling E5, hands-off
## play sows; decision 0886); the garden's stays off, the garden having its own plan -- and one budget: the work its policies may order in a day, in WU -- BUDGET_STEPS, demo values; 0 orders
## nothing.
## The day is the farm calendar's; the budget is spent when a job is ordered (its plan's work, farm_jobs.gd
## `plan_work_usec`: the walks are not counted, as on the action cards) and comes back at midnight.
##
## WHAT EACH POLICY DOES, once an hour (demo_farm.gd `_hourly`), only on a growing crop and only with a job not already
## on the bed:
##   FROST     with a frost due (farm_weather.gd `frost_due`: announced at noon the day before, or under way), Cover a bed
##             not covered and not raised (a raised bed is warm enough: farm_weather.gd RAISED_WARMTH_TENTHS);
##   WATER     Water a bed whose moisture is LOW or DRY against its crop's band (farm_sim.gd BAND_*) and that has not
##             been tended today -- §5.6's tending, at most once a day;
##   WATERLOG  for a WET or WATERLOGGED bed: an outlet fitted over a dry tunnel is set to Drain, a Feed outlet shut (a
##             board moved, no work: farm_sim.gd TUNNEL OUTLETS) -- the only things it changes. A STRUCTURAL answer -- a
##             ditch (Drain), Raise -- is the player's choice (the review: "structural changes still require a chosen
##             project"), and so is the weir's sluice, which serves three beds at once: those are said, not done;
##   SOW       on an EMPTY laid bed, not resting and not booked by the harvest plan (its booking sows it on its day):
##             sow the player's chosen crop, else its rotation's next crop
##             (farm_sowing.gd: GDD §5.6's three-entry cycle, R06-JOB-005's cursor), when its window and soil allow; one
##             waiting for its window is said once a bed and entry.
## EXCEPTIONS are posted to the village news once a day per group and policy (`notice`), naming the beds: a job the
## budget could not pay for, a bed the policy cannot help. THE NEXT DAY's most (`tomorrow_wu`) is shown before the
## player commits: every growing bed watered once, and covered if a frost night falls in the next day -- capped by the
## budget -- with the water it would draw at the well (§5.6: "Tending restores 1000 moisture using water 0.25 U").

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const SowingScript := preload("res://demo/farm/farm_sowing.gd")

const GROUP_FIELD: int = 0
const GROUP_GARDEN: int = 1
const GROUP_COUNT: int = 2
const GROUP_NAMES: Array[String] = ["Field beds", "Kitchen garden"]
const POLICY_FROST: int = 0
const POLICY_WATER: int = 1
const POLICY_WATERLOG: int = 2
const POLICY_SOW: int = 3
const POLICY_COUNT: int = 4
const POLICY_NAMES: Array[String] = ["Protect from forecast frost", "Water below the suitable band", "Avoid waterlogging",
	"Sow empty beds in season"]
const POLICY_KINDS: PackedInt32Array = [JobsScript.KIND_COVER, JobsScript.KIND_WATER, -1, JobsScript.KIND_SOW]
## What a bed a policy could not see to is left (by POLICY_*).
const LEFT_WORDS: Array[String] = ["uncovered with a frost due", "dry", "wet", "unsown"]
## A group's daily work budget, WU (demo values); the default is the fourth step -- four sowings a day (decision 0886).
const BUDGET_STEPS: PackedInt32Array = [0, 4, 8, 16, 32]
const DEFAULT_BUDGET_STEP: int = 3
## §5.6: tending uses 0.25 U of water.
const WATER_PER_TENDING_MILLI: int = 250
const NO_GROUP: int = -1

## Per group and policy (group * POLICY_COUNT + policy): on or off.
var policy_on: PackedByteArray = PackedByteArray()
## Per group: its BUDGET_STEPS index, and the WU its policies have ordered today.
var budget_step: PackedInt32Array = PackedInt32Array()
var spent_wu: PackedInt32Array = PackedInt32Array()
## Per group and policy: today's exception, as posted ('' when none).
var exception_text: PackedStringArray = PackedStringArray()
## Bumped by every change a reader could see.
var revision: int = 0
## The rotations the SOW policy sows by (farm_sowing.gd).
var sowing: SowingScript = SowingScript.new()

var _sim: SimScript = null
var _crew: CrewScript = null
## `(text: String) -> void`: posts an exception to the village news.
var _notice: Callable = Callable()
var _day: int = -1
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _left: PackedInt32Array = PackedInt32Array()
var _refused: PackedInt32Array = PackedInt32Array()
## `(bed: int) -> bool`: the harvest plan's bookings (`bind_booked`).
var _booked: Callable = Callable()
var _none: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Every policy off (the live village turns the field's sowing on: decision 0886), every budget at its default."""
	policy_on.resize(GROUP_COUNT * POLICY_COUNT)
	exception_text.resize(GROUP_COUNT * POLICY_COUNT)
	budget_step.resize(GROUP_COUNT)
	budget_step.fill(DEFAULT_BUDGET_STEP)
	spent_wu.resize(GROUP_COUNT)


func configure(sim: SimScript, crew: CrewScript, notice: Callable = Callable()) -> void:
	"""Tend this farm through this crew; `notice(text)` posts an exception (none: not posted, only kept)."""
	_sim = sim
	_crew = crew
	_notice = notice


# --- the player's settings ------------------------------------------------------------------------------------------

func set_policy(group: int, policy: int, on: bool) -> void:
	"""Turn one policy of one group on or off."""
	if group < 0 or group >= GROUP_COUNT or policy < 0 or policy >= POLICY_COUNT:
		return
	policy_on[group * POLICY_COUNT + policy] = 1 if on else 0
	revision += 1


func is_on(group: int, policy: int) -> bool:
	"""Whether one policy of one group is on."""
	return policy_on[group * POLICY_COUNT + policy] == 1


func set_budget_step(group: int, step: int) -> void:
	"""A group's daily budget, as a BUDGET_STEPS index (clamped)."""
	if group < 0 or group >= GROUP_COUNT:
		return
	budget_step[group] = clampi(step, 0, BUDGET_STEPS.size() - 1)
	revision += 1


func budget_wu(group: int) -> int:
	"""A group's daily work budget, WU."""
	return BUDGET_STEPS[budget_step[group]]


func left_wu(group: int) -> int:
	"""What is left of a group's budget today, WU."""
	return maxi(budget_wu(group) - spent_wu[group], 0)


static func group_of(bed: int) -> int:
	"""The group a bed belongs to: the kitchen garden's sites, else the field (NO_GROUP: no bed)."""
	if not Catalog.is_bed(bed):
		return NO_GROUP
	return GROUP_GARDEN if Catalog.is_garden(bed) else GROUP_FIELD


static func job_wu(kind: int) -> int:
	"""The work a policy's job takes, WU: its plan's work steps (farm_jobs.gd), the walks not counted."""
	@warning_ignore("integer_division") return JobsScript.plan_work_usec(kind, 0) / JobsScript.DEMO_USEC_PER_WU


# --- each hour --------------------------------------------------------------------------------------------------------

func run_hour() -> void:
	"""Once a farm hour: a new day refills every budget; then each group's policies that are on act (see WHAT EACH
	POLICY DOES), saying their exceptions."""
	if _sim == null or _crew == null:
		return
	if _sim.absolute_day() != _day:
		_day = _sim.absolute_day()
		spent_wu.fill(0)
		exception_text.fill("")
		revision += 1
	for bed: int in Catalog.BED_COUNT:
		sowing.observe(_sim, bed)
	for group: int in GROUP_COUNT:
		if is_on(group, POLICY_FROST):
			_order_policy(group, POLICY_FROST)
		if is_on(group, POLICY_WATER):
			_order_policy(group, POLICY_WATER)
		if is_on(group, POLICY_WATERLOG):
			_waterlog(group)
		if is_on(group, POLICY_SOW):
			_order_policy(group, POLICY_SOW)
			_say_waits(group)


func _order_policy(group: int, policy: int) -> void:
	"""FROST or WATER for one group: order the job on every bed that wants it while the budget lasts; the beds left
	are the exception."""
	var kind: int = POLICY_KINDS[policy]
	var cost: int = job_wu(kind)
	_left.clear()
	_refused.clear()
	var answer: String = ""
	for bed: int in Catalog.BED_COUNT:
		if group_of(bed) != group or not wants(bed, policy):
			continue
		if left_wu(group) < cost:
			_left.append(bed)
			continue
		var said: String = _order(kind, bed)
		if _crew.jobs.job_on_bed_into(kind, bed, _read):
			spent_wu[group] += cost
			revision += 1
		else:
			_refused.append(bed)
			answer = said
	_say_left(group, policy, answer)


func _order(kind: int, bed: int) -> String:
	"""Order one policy job on `bed`; a sowing first chooses the crop the policy sows (farm_sowing.gd `crop_to_sow`),
	and a refused one puts the bed's choice back. Returns the order's answer."""
	if kind != JobsScript.KIND_SOW:
		return _crew.order(kind, bed, _none, JobsScript.ORIGIN_ROUTINE)
	var before: int = _sim.chosen_of(bed)
	_sim.choose(bed, sowing.crop_to_sow(_sim, bed))
	var said: String = _crew.order(kind, bed, _none, JobsScript.ORIGIN_ROUTINE)
	if not _crew.jobs.job_on_bed_into(kind, bed, _read):
		_sim.restore_choice(bed, before)
	return said


func _say_waits(group: int) -> void:
	"""SOW's waits: an empty bed whose crop cannot be sown now is said once a bed and entry (farm_sowing.gd)."""
	for bed: int in Catalog.BED_COUNT:
		if group_of(bed) != group or not _sowable_bed(bed):
			continue
		var words: String = sowing.wait_words(_sim, bed)
		if not words.is_empty() and _notice.is_valid():
			_notice.call("Tending: %s: %s" % [GROUP_NAMES[group], words])


func _say_left(group: int, policy: int, answer: String) -> void:
	"""The exception for the beds a FROST, WATER or SOW run could not see to: the budget spent, or the order refused."""
	var what: String = LEFT_WORDS[policy]
	if not _left.is_empty():
		_except(group, policy, "%s: %s left %s — the day's tending budget (%d WU) is spent" % [GROUP_NAMES[group],
			beds_words(_left), what, budget_wu(group)])
	elif not _refused.is_empty():
		_except(group, policy, "%s: %s left %s — %s" % [GROUP_NAMES[group], beds_words(_refused), what, answer])


func wants(bed: int, policy: int) -> bool:
	"""Whether `policy` would order its job on `bed` now (see WHAT EACH POLICY DOES)."""
	if _crew.jobs.job_on_bed_into(POLICY_KINDS[policy], bed, _read):
		return false
	if policy == POLICY_SOW:
		return _sowable_bed(bed) and not _is_booked(bed) \
			and _sim.sow_refusal(bed, sowing.crop_to_sow(_sim, bed)) == SimScript.REFUSE_NONE
	if not _sim.is_laid(bed) or not _growing(bed):
		return false
	if policy == POLICY_FROST:
		var hour: int = _sim.calendar.calendar_at(_sim.calendar.tick).hour
		return Weather.frost_due(_sim.season(), _sim.season_day(), hour) and not _sim.is_covered(bed) \
			and not _sim.is_raised(bed)
	return _sim.band_of(bed) <= SimScript.BAND_LOW and not _sim.is_tended_today(bed)


func _waterlog(group: int) -> void:
	"""WATERLOG for one group, on growing crops: a fitted outlet over a dry tunnel is set to Drain, one feeding a wet bed
	is shut; every wet bed still without a drain is an exception naming the structural answer the player may choose
	(see WHAT EACH POLICY DOES)."""
	_left.clear()
	for bed: int in Catalog.BED_COUNT:
		if group_of(bed) != group or not _growing(bed) or _sim.band_of(bed) < SimScript.BAND_WET:
			continue
		if _sim.has_outlet(bed) and _sim.dry_tunnel_under(bed):
			_set_outlet(bed, SimScript.OUTLET_DRAIN)
			continue
		if _sim.outlet_of(bed) == SimScript.OUTLET_FEED:
			_set_outlet(bed, SimScript.OUTLET_SHUT)
		_left.append(bed)
	if not _left.is_empty():
		_except(group, POLICY_WATERLOG, "%s: %s too wet with no dry tunnel to drain into — %s" % [GROUP_NAMES[group],
			beds_words(_left), _wet_remedy(_left)])


func _set_outlet(bed: int, mode: int) -> void:
	"""Move a fitted outlet's board to `mode` (no work), unless it is there already."""
	if _sim.outlet_of(bed) != mode and _sim.set_outlet(bed, mode).ok:
		revision += 1


func _wet_remedy(beds: PackedInt32Array) -> String:
	"""The structural answers for wet beds, in words: the sluice when the leat waters one, else a ditch or raising."""
	for bed: int in beds:
		if Sluice.is_watering(_sim.leat_service_of(bed)):
			return "turn the weir's sluice down (it serves three beds: your choice), or Drain (a ditch) or Raise"
	return "Drain (a ditch), Raise, or fit an outlet to a tunnel under it"


func _except(group: int, policy: int, text: String) -> void:
	"""One exception, said once a day per group and policy (a new one replaces the shown text, unsaid)."""
	var k: int = group * POLICY_COUNT + policy
	var first: bool = exception_text[k].is_empty()
	if exception_text[k] != text:
		exception_text[k] = text
		revision += 1
	if first and _notice.is_valid():
		_notice.call("Tending: " + text)


func bind_booked(booked: Callable) -> void:
	"""`booked(bed) -> bool`: whether the harvest plan has booked the bed's sowing (farm_harvest_plan.gd); SOW leaves a
	booked bed to its booking (decision 0886)."""
	_booked = booked


func _is_booked(bed: int) -> bool:
	"""Whether the harvest plan has booked the bed's sowing (none bound: no)."""
	return _booked.is_valid() and bool(_booked.call(bed))


func _sowable_bed(bed: int) -> bool:
	"""Whether SOW looks at a bed: laid, empty and not resting."""
	return _sim.stage_of(bed) == SimScript.STAGE_EMPTY and not _sim.is_fallow(bed)


func _growing(bed: int) -> bool:
	"""Whether a bed holds a growing crop (sprouting, growing or blighted)."""
	var stage: int = _sim.stage_of(bed)
	return stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_GROWING or stage == SimScript.STAGE_BLIGHTED


# --- the next day's most (shown before the player commits) ----------------------------------------------------------

func growing_beds(group: int) -> int:
	"""How many laid beds of a group hold a growing crop now."""
	var count: int = 0
	for bed: int in Catalog.BED_COUNT:
		if group_of(bed) == group and _sim.is_laid(bed) and _growing(bed):
			count += 1
	return count


func frost_in_next_day() -> bool:
	"""Whether a frost night falls within the next day on the one calendar (tonight's or tomorrow night's)."""
	var now: SimClock.Calendar = _sim.calendar.calendar_at(_sim.calendar.tick)
	if Weather.frost_tonight(now.season, now.season_day):
		return true
	var next: Vector2i = Weather.next_day(now.season, now.season_day)
	return Weather.frost_tonight(next.x, next.y)


func tomorrow_wu(group: int) -> int:
	"""The most a group's policies that are on may order in the next day, WU: each growing bed covered (with a frost
	night due) and watered once, and each empty bed that can be sown now sown, capped by the budget."""
	var beds: int = growing_beds(group)
	var most: int = 0
	if is_on(group, POLICY_FROST) and frost_in_next_day():
		most += beds * job_wu(JobsScript.KIND_COVER)
	if is_on(group, POLICY_WATER):
		most += beds * job_wu(JobsScript.KIND_WATER)
	if is_on(group, POLICY_SOW):
		most += sowable_beds(group) * job_wu(JobsScript.KIND_SOW)
	return mini(most, budget_wu(group))


func sowable_beds(group: int) -> int:
	"""How many of a group's beds SOW would sow now."""
	var count: int = 0
	for bed: int in Catalog.BED_COUNT:
		if group_of(bed) == group and wants(bed, POLICY_SOW):
			count += 1
	return count


func tomorrow_water_milli(group: int) -> int:
	"""The well water the next day's waterings may draw, milli-U (§5.6's 0.25 U a tending), within the budget."""
	if not is_on(group, POLICY_WATER):
		return 0
	@warning_ignore("integer_division") var waterings: int = mini(growing_beds(group), budget_wu(group) / maxi(job_wu(JobsScript.KIND_WATER), 1))
	return waterings * WATER_PER_TENDING_MILLI


func tomorrow_text(group: int) -> String:
	"""'In the next day: at most 8 WU of work and 1.0 U of well water (budget 8 WU a day; 2 used today)'."""
	return "In the next day: at most %d WU of work and %s of well water (budget %d WU a day; %d WU used today)" % [
		tomorrow_wu(group), _units(tomorrow_water_milli(group)), budget_wu(group), spent_wu[group]]


static func beds_words(beds: PackedInt32Array) -> String:
	"""'Bed 2', 'Bed 2 and Bed 4', 'Bed 2, Bed 4 and Bed 7'."""
	var names := PackedStringArray()
	for bed: int in beds:
		names.append("Bed %d" % (bed + 1))
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


static func _units(milli: int) -> String:
	"""Tenths of a unit: '1.0 U'."""
	@warning_ignore("integer_division") return "%d.%d U" % [milli / 1000, (milli % 1000) / 100]
