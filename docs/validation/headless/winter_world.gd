extends RefCounted
## Isolated winter model. Matches winter.py; not the complete settlement runtime.

const HOUR: int = 750
const DAY: int = 18000
const DEN: int = 750000
const CAP: int = 10000 * DEN
const COUNT: int = 12
const NEED_NAMES: Array[StringName] = [&"hunger", &"rest", &"comfort", &"social", &"purpose"]
const COUNTER_NAMES: Array[StringName] = [&"work", &"sleep", &"eat", &"social", &"idle", &"travel", &"incap", &"alive", &"starving"]
const KITCHEN: int = 0
const WELL: int = 1
const QUALITY_FACTORS: Array[int] = [900, 1000, 1050, 1100]

var recovery: bool
var size: PackedInt64Array = PackedInt64Array([1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1200, 1200, 1000, 1000])
var need: Dictionary[StringName, PackedInt64Array] = {}
var counters: Dictionary[StringName, PackedInt64Array] = {}
var health: PackedInt64Array
var alive: PackedByteArray
var state: PackedByteArray
var until_tick: PackedInt64Array
var woken: PackedInt64Array
var food_np: PackedInt64Array
var skill_xp: Array[PackedInt64Array] = []
var xp_remainder: Array[PackedInt64Array] = []
var work_numerator: Array[PackedInt64Array] = []
# Two station rows, no job object per resident. Sequence preserves assignment order.
var job_owner: PackedInt32Array = PackedInt32Array([-1, -1])
var job_remaining: PackedInt64Array = PackedInt64Array([0, 0])
var job_np: PackedInt32Array = PackedInt32Array([0, 0])
var job_travel_end: PackedInt64Array = PackedInt64Array([0, 0])
var job_quality: PackedInt32Array = PackedInt32Array([0, 0])
var job_sequence: PackedInt64Array = PackedInt64Array([0, 0])
var next_job_sequence: int = 0
# The 12-portion target can overshoot to 13 portions, at most seven lots.
var meals: Array[PackedInt64Array] = []
var rations: int = 111000
var roots: int = 1800
var grain: int = 600000
var water: int = 60000
var wood: int = 100000
var tick: int = 0
var rng: int = 20260905
var events: Array[Dictionary] = []
var days: Array[Dictionary] = []
var produced: int = 0
var consumed_np: int = 0
var spoiled_np: int = 0
var lost_np: int = 0
var food_surplus: int = 0
var heat_remainder: int = 0
var collapse_tick: int = -1
var stable_count: int = 0
var stable_day: int = -1
var initial_np: int = 267840


func _init(enable_recovery: bool = false) -> void:
	## Allocate columns once; one world owns all actors.
	recovery = enable_recovery
	health = filled(100 * DEN)
	alive.resize(COUNT)
	alive.fill(1)
	state.resize(COUNT)
	until_tick = filled(0)
	woken = filled(-2)
	food_np = filled(0)
	for key: StringName in NEED_NAMES:
		need[key] = filled(7500 * DEN)
	for key: StringName in COUNTER_NAMES:
		counters[key] = filled(0)
	for kind: int in range(2):
		skill_xp.append(filled(20000))
		xp_remainder.append(filled(0))
		work_numerator.append(filled(0))
	for i: int in range(COUNT):
		choose(i)


static func filled(value: int) -> PackedInt64Array:
	## Create one fixed-length actor column.
	var values: PackedInt64Array = PackedInt64Array()
	values.resize(COUNT)
	values.fill(value)
	return values


static func integer_sqrt(value: int) -> int:
	## Exact floor square root with no numeric conversion to floating point.
	assert(value >= 0)
	var result: int = 0
	var bit: int = 1 << 62
	while bit > value:
		bit >>= 2
	while bit != 0:
		if value >= result + bit:
			value -= result + bit
			result = (result >> 1) + bit
		else:
			result >>= 1
		bit >>= 2
	return result


static func sum_column(values: PackedInt64Array) -> int:
	## Sum integer columns for reports only.
	var total: int = 0
	for value: int in values:
		total += value
	return total


func living() -> int:
	## Count occupied living entries in this fixed fixture.
	var total: int = 0
	for value: int in alive:
		total += value
	return total


func ready() -> int:
	## Count edible unheld food; raw grain cannot be eaten.
	var total: int = rations * 2400 / 1000 + roots * 800 / 1000
	for meal: PackedInt64Array in meals:
		total += meal[0] * meal[1] / 1000
	return total


func daily_demand() -> int:
	## Winter demand uses actual size of every living resident.
	var total: int = 0
	for i: int in range(COUNT):
		if alive[i] == 1:
			total += 7200 * size[i] / 1000
	return total


func mood(i: int) -> int:
	## Baseline weighted mood; this control intentionally omits memories.
	return (3 * (need[&"hunger"][i] / DEN) + 2 * (need[&"rest"][i] / DEN) + 2 * (need[&"comfort"][i] / DEN) + need[&"social"][i] / DEN + 2 * (need[&"purpose"][i] / DEN)) / 10


func factor(i: int, kind: int) -> int:
	## Frozen recipe lead level is distinct from changing productive speed.
	var level: int = mini(10, integer_sqrt(skill_xp[kind][i] / 5000))
	var current_mood: int = mood(i)
	var mf: int = 1150
	if current_mood < 2000:
		mf = 600
	elif current_mood < 4000:
		mf = 800
	elif current_mood < 7000:
		mf = 1000
	elif current_mood < 8500:
		mf = 1100
	var hp: int = health[i] / DEN
	var hf: int = 600 if hp < 40 else (850 if hp < 70 else 1000)
	return clampi((1000 + 50 * level) * mf * hf / 1000000, 300, 1800)


func start_eat(i: int) -> bool:
	## Remove one portion into held meal state; consume after 150 full intervals.
	var nutrition: int = 0
	if not meals.is_empty() and meals[0][0] >= 1000:
		meals[0][0] -= 1000
		nutrition = meals[0][1]
		if meals[0][0] == 0:
			meals.remove_at(0)
	elif rations >= 1000:
		rations -= 1000
		nutrition = 2400
	elif need[&"hunger"][i] <= 1500 * DEN and roots > 0:
		var quantity: int = mini(roots, 3000000 / 800)
		roots -= quantity
		nutrition = quantity * 800 / 1000
	if nutrition == 0:
		return false
	state[i] = 1
	until_tick[i] = tick + 150
	food_np[i] = nutrition
	return true


func choose(i: int) -> void:
	## Needs and schedule precede optional conversion work.
	var hour: int = (tick / HOUR) % 24
	var day: int = tick / DAY
	var sleep_window: int = day if hour >= 22 else day - 1
	if need[&"hunger"][i] <= 3500 * DEN and start_eat(i):
		return
	if need[&"rest"][i] <= 2500 * DEN or ((hour >= 22 or hour < 6) and woken[i] != sleep_window):
		state[i] = 2
		return
	if hour >= 18 and hour < 20 and living() > 1:
		state[i] = 3
		return
	if not recovery:
		return
	if job_owner[WELL] == -1 and water < 10000:
		var speed: int = 4096 if size[i] == 1200 else 3277
		var travel: int = 2 * ((20 * 1024 * 30 + speed - 1) / speed)
		assign_job(WELL, i, 10000000, 0, tick + travel, 0)
		return
	var portions: int = 0
	for meal: PackedInt64Array in meals:
		portions += meal[0]
	if job_owner[KITCHEN] == -1 and portions < 12000:
		try_cooking(i)


func assign_job(kind: int, i: int, work: int, nutrition: int, travel_end: int, quality: int) -> void:
	## Preserve assignment ordering without allocating a per-worker job object.
	next_job_sequence += 1
	job_owner[kind] = i
	job_remaining[kind] = work
	job_np[kind] = nutrition
	job_travel_end[kind] = travel_end
	job_quality[kind] = quality
	job_sequence[kind] = next_job_sequence
	state[i] = 4


func try_cooking(i: int) -> void:
	## Bind inputs and quality once; source assumption consumes inputs at assignment.
	var level: int = mini(10, integer_sqrt(skill_xp[KITCHEN][i] / 5000))
	var quantity: int = 2000 * (1000 - 10 * level) / 1000
	if grain < quantity or water < 2000 or wood < 100:
		return
	grain -= quantity
	water -= 2000
	wood -= 100
	rng = (rng ^ ((rng << 13) & 0xffffffff)) & 0xffffffff
	rng = (rng ^ (rng >> 17)) & 0xffffffff
	rng = (rng ^ ((rng << 5) & 0xffffffff)) & 0xffffffff
	var age_fraction: int = tick * 500 * 10000 / (750 * 720000)
	var score: int = clampi(40 + 4 * level + 10 + 5 - age_fraction * 20 / 10000 + rng % 21 - 10, 0, 100)
	var quality: int = 0 if score < 40 else (1 if score < 65 else (2 if score < 85 else 3))
	var nutrition: int = 1800 * QUALITY_FACTORS[quality] / 1000
	assign_job(KITCHEN, i, 12000000, nutrition, tick, quality)


func step() -> void:
	## Integrate one interval, complete jobs, then select activity for the next interval.
	heat_remainder += 4000
	wood -= heat_remainder / DAY
	heat_remainder %= DAY
	assert(wood >= 0, "Warm-boundary fixture exhausted heating fuel")
	for i: int in range(COUNT):
		if alive[i] == 1:
			integrate_actor(i)
	var first: int = KITCHEN if job_sequence[KITCHEN] <= job_sequence[WELL] else WELL
	advance_job(first)
	advance_job(1 - first)
	tick += 1
	expire_meals()
	for i: int in range(COUNT):
		select_next_interval(i)
	if living() == 0 and collapse_tick == -1:
		collapse_tick = tick
	if tick % DAY == 0:
		snapshot()


func count_activity(i: int, previous_state: int) -> void:
	## Every alive interval belongs to exactly one exclusive activity column.
	counters[&"alive"][i] += 1
	var key: StringName = &"idle"
	if health[i] <= 15 * DEN:
		key = &"incap"
	elif previous_state == 1:
		key = &"eat"
	elif previous_state == 2:
		key = &"sleep"
	elif previous_state == 3:
		key = &"social"
	elif previous_state == 4:
		var kind: int = KITCHEN if job_owner[KITCHEN] == i else WELL
		assert(job_owner[kind] == i)
		key = &"travel" if tick < job_travel_end[kind] else &"work"
	counters[key][i] += 1


func integrate_actor(i: int) -> void:
	## Needs use exact integer numerators; cap overflow is discarded.
	var previous_state: int = state[i]
	count_activity(i, previous_state)
	var starving: bool = need[&"hunger"][i] == 0
	need[&"hunger"][i] = maxi(0, need[&"hunger"][i] - 300 * size[i])
	need[&"rest"][i] = clampi(need[&"rest"][i] + (1200000 if previous_state == 2 else -375000), 0, CAP)
	var target: int = (6000 if previous_state == 2 else 7500) * DEN
	var decayed: int = maxi(0, need[&"comfort"][i] - 100000)
	need[&"comfort"][i] = decayed + mini(300000, maxi(0, target - decayed))
	need[&"social"][i] = clampi(need[&"social"][i] + (1100000 if previous_state == 3 else -100000), 0, CAP)
	need[&"purpose"][i] = clampi(need[&"purpose"][i] + (245000 if previous_state == 4 else -75000), 0, CAP)
	if starving:
		health[i] = maxi(0, health[i] - 4000)
		counters[&"starving"][i] += 1
	elif health[i] < 100 * DEN and need[&"hunger"][i] >= 4000 * DEN and need[&"rest"][i] >= 4000 * DEN:
		health[i] = mini(100 * DEN, health[i] + 2000)
	if health[i] == 0:
		retire_actor(i, previous_state)
	elif health[i] > 15 * DEN:
		complete_activity(i, previous_state)


func retire_actor(i: int, previous_state: int) -> void:
	## Retain authoritative death time and account for lost held food.
	if previous_state == 1:
		lost_np += food_np[i]
	alive[i] = 0
	events.append({"tick": tick + 1, "resident": i + 1, "cause": "starvation"})


func complete_activity(i: int, previous_state: int) -> void:
	## Commit meal nutrition or complete scheduled sleep at the interval boundary.
	if previous_state == 1 and tick + 1 >= until_tick[i]:
		var before: int = need[&"hunger"][i]
		need[&"hunger"][i] = mini(CAP, before + food_np[i] * DEN)
		consumed_np += food_np[i]
		food_surplus += maxi(0, food_np[i] - (CAP - before) / DEN)
		state[i] = 0
		food_np[i] = 0
		need[&"social"][i] = mini(CAP, need[&"social"][i] + 200 * DEN)
	elif previous_state == 2 and need[&"rest"][i] >= 9000 * DEN:
		var hour: int = (tick / HOUR) % 24
		var day: int = tick / DAY
		woken[i] = day if hour >= 22 else day - 1
		state[i] = 0


func advance_job(kind: int) -> void:
	## Work/XP carry independent integer remainders; no assignment-tick credit.
	var i: int = job_owner[kind]
	if i < 0 or alive[i] == 0 or health[i] <= 15 * DEN or tick < job_travel_end[kind]:
		return
	var work: int = mini(job_remaining[kind], 80 * factor(i, kind))
	job_remaining[kind] -= work
	work_numerator[kind][i] += work
	xp_remainder[kind][i] += work
	skill_xp[kind][i] += xp_remainder[kind][i] / 100000
	xp_remainder[kind][i] %= 100000
	if job_remaining[kind] > 0:
		return
	if kind == WELL:
		water += 10000
	else:
		meals.append(PackedInt64Array([2000, job_np[kind], tick + 1, job_quality[kind]]))
		produced += 2 * job_np[kind]
	state[i] = 0
	job_owner[kind] = -1


func expire_meals() -> void:
	## Expire prepared lots using heated-pantry effective age.
	for index: int in range(meals.size() - 1, -1, -1):
		if (tick - meals[index][2]) * 750 >= 24 * 1000 * HOUR:
			spoiled_np += meals[index][0] * meals[index][1] / 1000
			meals.remove_at(index)


func select_next_interval(i: int) -> void:
	## Apply social-window and urgent-sleep interruption at the completed boundary.
	if alive[i] == 0 or health[i] <= 15 * DEN:
		return
	var hour: int = (tick / HOUR) % 24
	if state[i] == 3 and not (hour >= 18 and hour < 20):
		state[i] = 0
	if state[i] == 2 and need[&"hunger"][i] <= 1500 * DEN:
		start_eat(i)
	if state[i] == 0:
		choose(i)


func verify_ledgers() -> void:
	## Reconcile per-actor elapsed time and the nutrition transformation ledger.
	var pending: int = 0
	for i: int in range(COUNT):
		if state[i] == 1 and alive[i] == 1:
			pending += food_np[i]
		var total: int = 0
		for key: StringName in COUNTER_NAMES:
			if key != &"alive" and key != &"starving":
				total += counters[key][i]
		assert(total == counters[&"alive"][i], "Activity partition mismatch")
	assert(initial_np + produced == ready() + consumed_np + spoiled_np + pending + lost_np, "Nutrition ledger mismatch")


func snapshot() -> void:
	## Emit the same cumulative numeric row as the independent Python model.
	var demand: int = daily_demand()
	var food_days: int = 100 * ready() / demand if demand > 0 else 0
	var starving: int = 0
	var minimum_health: int = 100 if living() > 0 else 0
	for i: int in range(COUNT):
		if alive[i] == 1:
			starving += int(need[&"hunger"][i] == 0)
			minimum_health = mini(minimum_health, health[i] / DEN)
	var stable: bool = living() == COUNT and food_days >= 200 and wood >= 8000 and starving == 0
	stable_count = stable_count + 1 if stable else 0
	if stable_count >= 3 and stable_day == -1:
		stable_day = tick / DAY
	var row: Dictionary = basic_row(food_days, starving, minimum_health)
	for key: StringName in COUNTER_NAMES:
		if key != &"starving":
			var label: String = "incapacitated" if key == &"incap" else String(key)
			row[label + "_ticks_total"] = sum_column(counters[key])
	row["cook_work_numerator"] = sum_column(work_numerator[KITCHEN])
	row["haul_work_numerator"] = sum_column(work_numerator[WELL])
	days.append(row)
	verify_ledgers()


func basic_row(food_days: int, starving: int, minimum_health: int) -> Dictionary:
	## Snapshot allocation occurs only on a reporting boundary.
	return {"day": tick / DAY, "tick": tick, "living": living(), "ready_np": ready(),
		"food_days_centi": food_days, "grain_milli": grain, "water_milli": water, "wood_milli": wood,
		"deaths": COUNT - living(), "starving": starving, "prepared_np_total": produced,
		"consumed_np_total": consumed_np, "spoiled_np_total": spoiled_np, "lost_np_total": lost_np,
		"minimum_health": minimum_health}


func result() -> Dictionary:
	## Final reporting uses JSON null for absent collapse/stabilization boundaries.
	if days.is_empty() or days[-1]["tick"] != tick:
		snapshot()
	return {"mode": "conversion_enabled" if recovery else "conversion_disabled", "completed_tick": tick,
		"collapse_tick": null if collapse_tick == -1 else collapse_tick, "deaths": COUNT - living(),
		"stable_day": null if stable_day == -1 else stable_day, "daily": days, "events": events}
