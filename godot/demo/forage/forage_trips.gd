extends RefCounted
## FORAGING TRIPS: a small party sent into the woods for nuts, mushrooms or herbs, back hours later with a haul for the
## pantry. Decision 0681 (feature #22; review ECO-013's lasting roles -- nuts for the loaf, herbs for the infusion -- and
## the smallest of ECO-014's planned outing). Numbers in forage_rules.gd; the ecology is the real forage store's
## (forage_driver.gd). Presentation over integer rules; nothing here writes into the settlement simulation.
##
## A TRIP is authorised for one kind and a party of one to three (the Woods panel's Foraging section): it asks the basin
## for a basket a forager, bounded by what the basin admits now -- its daily quota and the stock above its sustainable
## floor -- and refuses when the kind is dormant this season (§5.5's availability 0: nuts in spring, mushrooms in
## winter) or nothing is left today. Each forager is a SEAT, a work-board task (work/forage_work.gd; the Woods activity),
## to the selected residents first.
##
## A SEAT walks to its kind's spot in the woods and is checked there: still in season, its share still admitted, room
## held in a store for it (decision 0222: a producer reserves first). Then its share is CLAIMED -- a real FORAGE Job's
## claim on the basin (forage.gd `claim_forage`), so quota and stock are spoken for while it works -- and gathered: §5.5's
## work per U at the forager's FORAGE level, at §5.2's base step (80% on a heavy-rain day). Done, the claim is collected
## (stock and today's quota debited) into the forager's hands, and the haul is carried to the store holding its room and
## shelved there as its own item: nuts, mushrooms, herbs or berries, each its own lot that ages as §5.8 says.
##
## INTERRUPTION loses nothing. Called away on the way or at work (an order, the night, a meal), the seat goes back on the
## board with its claim, its room and its work done kept, for whoever takes it next. A haul in hand is carried home
## before the night or a meal takes its forager (`must_finish`); an order that takes it sets the haul down where it
## stands, still in the books, for the next to fetch. CANCEL calls off the seats not yet carrying (their claims and room
## given back); a haul in hand is always brought home.
##
## A PREPARED OUTING (review ECO-014; decision 1721, numbers in forage_rules.gd): the same trip, planned to be HOME
## BEFORE DARK -- not authorised when it could not be, and each forager at its spot claims only what it can gather and
## still walk home by dusk, TURNING BACK when that is too little -- with the village's CARRY KIT (its carrier two baskets)
## and a NAMED LEAD if the player asks; each spot REMEMBERS its latest trip home (when, what, how long, who led). A
## PROTECTED GROVE'S RESERVE (ECO-015): a spot inside a protected grove leaves the grove's share of the woods' stock
## (`reserve_permille`, demo_orchard.gd `grove_reserve_permille`), above §5.5's floor.
##
## THE BOOKS (milli-U, per kind): everything collected from the basin is in a hand (or set down) or in a store --
##     collected == in_hand + stored                                            (`books_balance`)
## at every moment; a load moves between two of them in one step.

const Rules := preload("res://demo/forage/forage_rules.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const DriverScript := preload("res://demo/forage/forage_driver.gd")
const SkillsScript := preload("res://demo/forage/forage_skills.gd")
const TaskScript := preload("res://demo/forage/forage_task.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

const NONE: int = -1
const NULL_REF: Vector2i = DriverScript.NULL_REF
## A seat's steps.
const S_TO_SPOT: int = 0
const S_GATHER: int = 1
const S_TO_STORE: int = 2
const STEP_WORDS: Array[String] = ["going to", "gathering at", "carrying home from"]
## Places are snapped for the widest resident (the fishery's), on rings this far apart.
const SPOT_BODY_M: float = 0.56
const SPOT_RING_M: float = 0.3
const SPOT_RINGS: int = 12
const CLIP_WORK: StringName = &"pull_radish"
## The model a forager carries its haul in (the fishery's basket).
const BASKET_KEY: StringName = &"basket"

## The village's parts.
var driver: DriverScript = null
var skills: SkillsScript = SkillsScript.new()
var pantry: PantryScript = null
var calendar: CalendarScript = null
var weather: DemoWeatherScript = null
## `say(text, warning)`: the notice feed (the Woods source).
var say: Callable = Callable()
## Bumped whenever anything a panel shows changes.
var revision: int = 0
## Where each kind is gathered (snapped), by index into Rules.KINDS.
var spot_at: PackedVector2Array = PackedVector2Array()
## Decision 1721: `reserve_permille(at: Vector2) -> int`, a protected grove's forage reserve at an authored spot, per
## mille of the kind's capacity (invalid: none).
var reserve_permille: Callable = Callable()
## THE PLACES REMEMBERED (decision 1721), per kind index: the calendar tick its latest trip came home (-1: never), what it
## brought, how long it was out (ticks), and who led it ("": nobody named).
var note_tick: PackedInt64Array = PackedInt64Array([-1, -1, -1, -1])
var note_milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var note_ticks: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var note_lead: PackedStringArray = PackedStringArray(["", "", "", ""])

## THE BOOKS, per kind index: collected from the basin, and shelved in a store.
var collected_milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var stored_milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var trips_done: int = 0

## The trips (structure of arrays): kind index, party, what was asked, when, and how many seats are still out.
var t_live: PackedByteArray = PackedByteArray()
var t_serial: PackedInt32Array = PackedInt32Array()
var t_kind: PackedInt32Array = PackedInt32Array()
var t_party: PackedInt32Array = PackedInt32Array()
var t_asked: PackedInt64Array = PackedInt64Array()
var t_got: PackedInt64Array = PackedInt64Array()
var t_seats: PackedInt32Array = PackedInt32Array()
var t_posted: PackedInt64Array = PackedInt64Array()
## Decision 1721: whether the trip has the carry kit, its named lead (NONE), and how many of it turned back for the dark.
var t_kit: PackedByteArray = PackedByteArray()
var t_lead: PackedInt32Array = PackedInt32Array()
var t_turned: PackedInt32Array = PackedInt32Array()

## The seats (structure of arrays).
var j_live: PackedByteArray = PackedByteArray()
var j_serial: PackedInt32Array = PackedInt32Array()
var j_trip: PackedInt32Array = PackedInt32Array()
var j_step: PackedInt32Array = PackedInt32Array()
var j_worker: PackedInt32Array = PackedInt32Array()
var j_share: PackedInt64Array = PackedInt64Array()
var j_claimed: PackedInt64Array = PackedInt64Array()
var j_claim_slot: PackedInt32Array = PackedInt32Array()
var j_claim_gen: PackedInt32Array = PackedInt32Array()
var j_hold: PackedInt32Array = PackedInt32Array()
var j_load: PackedInt64Array = PackedInt64Array()
var j_load_at: PackedVector2Array = PackedVector2Array()
var j_goal: PackedVector2Array = PackedVector2Array()
var j_issued: PackedByteArray = PackedByteArray()
var j_at: PackedByteArray = PackedByteArray()
var j_num: PackedInt64Array = PackedInt64Array()
var j_mwu: PackedInt64Array = PackedInt64Array()
var j_need: PackedInt64Array = PackedInt64Array()
var j_wait_usec: PackedInt64Array = PackedInt64Array()
var j_tries: PackedInt32Array = PackedInt32Array()
var j_failed: PackedInt32Array = PackedInt32Array()
var j_paused: PackedByteArray = PackedByteArray()
var j_words: PackedStringArray = PackedStringArray()

var _cast: DemoCastScript = null
var _tasks: Array = []
var _next_serial: int = 1
var _driving: int = NONE
var _read: IntMath.IntResult = IntMath.IntResult.new()
## Set by `_claim_share` when the refusal was a full store (the seat waits for room) rather than the woods.
var _room_short: bool = false
## Set by `_claim_share` when the seat turns back for the dark (decision 1721).
var _turned_back: bool = false
## One reused calendar instant (a note's date).
var _when: SimClock.Calendar = SimClock.Calendar.new(0)


func configure(p_cast: DemoCastScript, p_driver: DriverScript, p_pantry: PantryScript, p_calendar: CalendarScript,
		p_weather: DemoWeatherScript) -> void:
	"""Wire the trips into the village: its cast, the forage driver, the pantry, the calendar and the weather."""
	_cast = p_cast
	driver = p_driver
	pantry = p_pantry
	calendar = p_calendar
	weather = p_weather
	skills.setup(p_cast.actor_count() if p_cast != null else 0)
	_size_rows()
	spot_at.clear()
	for k: int in Rules.KIND_COUNT:
		spot_at.append(_standable(Rules.SPOT_AT[k], spot_at))


func _size_rows() -> void:
	"""Every column sized once."""
	for column: PackedInt32Array in [t_serial, t_kind, t_party, t_seats, t_lead, t_turned]:
		column.resize(Rules.MAX_TRIPS)
	t_kit.resize(Rules.MAX_TRIPS)
	for column: PackedInt64Array in [t_asked, t_got, t_posted]:
		column.resize(Rules.MAX_TRIPS)
	t_live.resize(Rules.MAX_TRIPS)
	for column: PackedInt32Array in [j_serial, j_trip, j_step, j_worker, j_claim_slot, j_claim_gen, j_hold, j_tries, j_failed]:
		column.resize(Rules.MAX_JOBS)
	for column: PackedInt64Array in [j_share, j_claimed, j_load, j_num, j_mwu, j_need, j_wait_usec]:
		column.resize(Rules.MAX_JOBS)
	for column: PackedByteArray in [j_live, j_issued, j_at, j_paused]:
		column.resize(Rules.MAX_JOBS)
	j_load_at.resize(Rules.MAX_JOBS)
	j_goal.resize(Rules.MAX_JOBS)
	j_words.resize(Rules.MAX_JOBS)
	j_worker.fill(NONE)
	_tasks.resize(Rules.MAX_JOBS)


func _standable(target: Vector2, taken: PackedVector2Array) -> Vector2:
	"""The spot nearest `target` on rings round it that the widest resident may stand at and reaches from where the first
	resident stands (the fishery's rule; the target itself without a cast)."""
	if _cast == null or _cast.actor_count() == 0:
		return target
	var from: Vector2 = brain_of(0).surface_point()
	var none := PackedVector3Array()
	for ring: int in SPOT_RINGS:
		for k: int in (1 if ring == 0 else 12):
			var at: Vector2 = target + Vector2.from_angle(TAU * k / 12.0) * SPOT_RING_M * ring
			if CastOrdersScript.spot_ok(_cast.space(), at, SPOT_BODY_M, _cast.bounds(), none, taken, from):
				return at
	return target


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func cast_actor(who: int) -> DemoActorScript:
	"""Resident `who`'s actor (its drawing)."""
	return _cast.actor(who) as DemoActorScript


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name if who >= 0 and _cast != null else "nobody"


func _note(text: String, warning: bool) -> void:
	"""Post to the notice feed."""
	if say.is_valid():
		say.call(text, warning)


static func item_of(kind_index: int) -> int:
	"""The pantry item kind index `kind_index` (into Rules.KINDS) is gathered as."""
	return Catalog.item_of_patch(Rules.KINDS[kind_index])


# --- the books -------------------------------------------------------------------------------------------

func in_hand_milli(kind_index: int) -> int:
	"""Forage of `kind_index` in a forager's hands, or set down for the next to fetch."""
	var total: int = 0
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 1 and t_kind[j_trip[j]] == kind_index:
			total += j_load[j]
	return total


func books_balance() -> bool:
	"""THE BOOKS: everything collected is in a hand or in a store, once, for every kind."""
	for k: int in Rules.KIND_COUNT:
		if collected_milli[k] != in_hand_milli(k) + stored_milli[k]:
			return false
	return true


# --- time --------------------------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance by `usec` demo microseconds: the basin to the calendar's tick, the work, the retries."""
	if calendar != null:
		driver.follow(calendar.tick)
	_credit_work(usec)
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 1 and j_wait_usec[j] > 0:
			j_wait_usec[j] = maxi(0, j_wait_usec[j] - usec)


func _credit_work(usec: int) -> void:
	"""Every forager at its work does §5.2's base step (80% in heavy rain); a seat completes at its need. Its FORAGE XP
	grows by the WU done (§5.3)."""
	var event: int = weather.event() if weather != null else WeatherScript.EVENT_NONE
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 0 or j_at[j] == 0 or j_worker[j] == NONE or j_step[j] != S_GATHER:
			continue
		j_num[j] += Rules.mwu_numerator(usec, event)
		@warning_ignore("integer_division") var done: int = j_num[j] / Rules.MWU_DENOMINATOR
		j_num[j] -= done * Rules.MWU_DENOMINATOR
		j_mwu[j] += done
		skills.add_work(j_worker[j], done)
		if j_mwu[j] >= j_need[j]:
			j_at[j] = 0
			_gathered(j)


# --- the player's order (the Woods panel's Foraging section; its card runs the same decision) -----------------

func trip_refusal(kind_index: int, party: int) -> String:
	"""Why a trip for `kind_index` with `party` foragers may not be authorised now ("" when it may)."""
	if not Rules.is_kind(kind_index) or party < Rules.PARTY_MIN or party > Rules.PARTY_MAX:
		return "choose what to gather and a party of %d to %d" % [Rules.PARTY_MIN, Rules.PARTY_MAX]
	var kind: int = Rules.KINDS[kind_index]
	if driver.availability(kind) == 0:
		return "%s are out of season now (they come in %s)" % [Rules.KIND_WORDS[kind_index], season_words(kind_index)]
	if harvestable_milli(kind_index) < Rules.MIN_SHARE_MILLI:
		return nothing_left_words(kind_index)
	if t_live.count(0) == 0:
		return "%d foraging trips are out already" % Rules.MAX_TRIPS
	if j_live.count(0) < party:
		return "the work board has no room for %d more foragers" % party
	return ""


func nothing_left_words(kind_index: int) -> String:
	"""Why nothing more may be gathered today: the day's quota, or the stock at its floor -- and a protected grove's
	reserve (decision 1721) -- or all of it claimed."""
	if driver.quota_left_milli() < Rules.MIN_SHARE_MILLI:
		return "the woods' daily quota is gathered (%s a day this season) — it opens again at midnight" % \
			Rules.units_text(driver.quota_today_milli())
	var floor_words: String = Rules.units_text(driver.floor_milli(Rules.KINDS[kind_index]))
	var reserve: int = reserve_milli(kind_index)
	if reserve > 0:
		floor_words += " and %s more in the protected grove" % Rules.units_text(reserve)
	return "the woods keep their last %s (the sustainable floor), and the rest is spoken for" % floor_words


func harvestable_milli(kind_index: int) -> int:
	"""What a trip may still take of `kind_index` now: the basin's own bound (forage_driver.gd: today's quota, the stock
	above §5.5's floor not claimed), less a protected grove's reserve at its spot (decision 1721)."""
	var kind: int = Rules.KINDS[kind_index]
	var bound: int = driver.harvestable_milli(kind)
	var reserve: int = reserve_milli(kind_index)
	if reserve <= 0:
		return bound
	var above: int = driver.stock_milli(kind) - driver.floor_milli(kind) - reserve - claimed_milli(kind_index)
	return clampi(above, 0, bound)


func reserve_milli(kind_index: int) -> int:
	"""A protected grove's reserve at `kind_index`'s authored spot, milli-U (0: none)."""
	if not reserve_permille.is_valid() or not Rules.is_kind(kind_index):
		return 0
	var permille: int = int(reserve_permille.call(Rules.SPOT_AT[kind_index]))
	@warning_ignore("integer_division") var milli: int = driver.capacity_milli(Rules.KINDS[kind_index]) * permille / 1000
	return milli


func claimed_milli(kind_index: int) -> int:
	"""What the seats out for `kind_index` hold claimed and not yet collected."""
	var total: int = 0
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 1 and t_kind[j_trip[j]] == kind_index:
			total += j_claimed[j]
	return total


func trip_milli(kind_index: int, party: int, kit: bool = false) -> int:
	"""What a trip would bring home: a basket a forager (the kit's carrier two), bounded by what it may take now."""
	return mini(Rules.ask_with_kit(party, kit), harvestable_milli(kind_index))


func order_trip(kind_index: int, party: int, members: PackedInt32Array) -> String:
	"""Authorise a plain trip (no kit, nobody named to lead): `order_outing`."""
	return order_outing(kind_index, party, members, false, false)


func order_outing(kind_index: int, party: int, members: PackedInt32Array, kit: bool, lead: bool) -> String:
	"""Authorise a trip (decision 1721: with the carry kit, led by the first selected resident): its seats on the work
	board, to the selected residents first. "" when authorised, else why not."""
	var why: String = outing_refusal(kind_index, party, members, kit, lead)
	if not why.is_empty():
		return why
	var t: int = t_live.find(0)
	var total: int = trip_milli(kind_index, party, kit)
	_open_trip(t, kind_index, party, total, kit)
	var given := PackedInt32Array()
	for seat: int in party:
		var j: int = _open_seat(t, Rules.seat_share_milli(total, party, seat, kit))
		_give_first(j, members, given)
		if seat == 0 and lead and j_worker[j] == members[0]:
			t_lead[t] = members[0]
	_note("A foraging trip for %s is authorised: %d to %s%s" % [Rules.KIND_WORDS[kind_index], party,
		Rules.SPOT_NAMES[kind_index], outing_words(t)], false)
	revision += 1
	return ""


func _open_trip(t: int, kind_index: int, party: int, total: int, kit: bool) -> void:
	"""Trip row `t` opened for `party` foragers after `total` of `kind_index` (its kit noted; no lead yet)."""
	t_live[t] = 1
	t_serial[t] = _next_serial
	_next_serial += 1
	t_kind[t] = kind_index
	t_party[t] = party
	t_asked[t] = total
	t_got[t] = 0
	t_seats[t] = party
	t_posted[t] = calendar.tick if calendar != null else 0
	t_kit[t] = 1 if kit else 0
	t_lead[t] = NONE
	t_turned[t] = 0


func outing_refusal(kind_index: int, party: int, members: PackedInt32Array, kit: bool, lead: bool) -> String:
	"""Why an outing may not be authorised now ("" when it may): the trip's own refusal, the dark, the kit lent, the
	lead (decision 1721)."""
	var why: String = trip_refusal(kind_index, party)
	if why.is_empty():
		why = daylight_refusal(kind_index)
	if why.is_empty() and kit and kit_trip() != NONE:
		why = "the carry kit is out with the trip to %s" % Rules.SPOT_NAMES[t_kind[kit_trip()]]
	if why.is_empty() and lead:
		why = lead_refusal(members)
	return why


func lead_refusal(members: PackedInt32Array) -> String:
	"""Why the first selected resident may not lead a trip ("" when they may): someone selected, free of a foraging seat,
	on land and above ground."""
	if members.is_empty() or _cast == null:
		return "select the resident who is to lead it"
	var who: int = members[0]
	if job_of_worker(who) != NONE:
		return "%s is on another foraging trip" % name_of(who)
	var unfit: String = _unfit(who)
	return "" if unfit.is_empty() else "%s %s" % [name_of(who), unfit]


func kit_trip() -> int:
	"""The trip out with the carry kit (NONE: it is at home)."""
	for t: int in Rules.MAX_TRIPS:
		if t_live[t] == 1 and t_kit[t] == 1:
			return t
	return NONE


func outing_words(t: int) -> String:
	"""', led by Wenna, with the carry kit' -- trip `t`'s lead and kit, as the news says them."""
	var words: String = ""
	if t_lead[t] != NONE:
		words += ", led by %s" % name_of(t_lead[t])
	if t_kit[t] == 1:
		words += ", with the carry kit"
	return words


# --- home before dark (decision 1721) -------------------------------------------------------------------------

func walk_home_ticks(kind_index: int) -> int:
	"""Calendar ticks from `kind_index`'s spot back to the village square at the slowest pace (and as long out)."""
	return Rules.walk_ticks(spot_at[kind_index].length() if spot_at.size() > kind_index else Rules.SPOT_AT[kind_index].length())


func daylight_left_ticks() -> int:
	"""Calendar ticks until dusk now (0 at night; a day's worth without a calendar)."""
	return Rules.daylight_ticks(calendar.now().tick_of_day) if calendar != null else SimClock.TICKS_PER_DAY


func daylight_refusal(kind_index: int) -> String:
	"""Why a party could not go to `kind_index`'s spot, gather the least worth a trip and be home by dusk ("": it can)."""
	var left: int = daylight_left_ticks()
	if left <= 0:
		return "it is night: foraging parties go out from %02d:00" % Rules.DAWN_HOUR
	var need: int = 2 * walk_home_ticks(kind_index) + _gather_ticks(kind_index, Rules.MIN_SHARE_MILLI)
	if left < need:
		return "too late in the day: a party could not gather and be home by dusk (%02d:00)" % Rules.DUSK_HOUR
	return ""


func _gather_ticks(kind_index: int, milli: int) -> int:
	"""Calendar ticks one forager at FORAGE 0 takes to gather `milli` of `kind_index` today (rounded up)."""
	var mwu: int = Rules.work_mwu(milli, driver.work_per_u_wu(Rules.KINDS[kind_index], 0))
	var per_tick: int = maxi(1, Rules.MWU_PER_TICK * _weather_permille())
	@warning_ignore("integer_division") var ticks: int = (mwu * 1000 + per_tick - 1) / per_tick
	return ticks


func _weather_permille() -> int:
	"""§5.10's share of the work rate today (80% in heavy rain)."""
	return ForestRules.weather_permille(weather.event() if weather != null else WeatherScript.EVENT_NONE)


func daylight_cap_milli(kind_index: int, level: int) -> int:
	"""The most a forager at `kind_index`'s spot (FORAGE `level`) may gather now and still walk home by dusk."""
	var left: int = daylight_left_ticks() - walk_home_ticks(kind_index)
	return Rules.gatherable_milli(left, driver.work_per_u_wu(Rules.KINDS[kind_index], level), _weather_permille())


func home_by_text(kind_index: int, party: int, kit: bool) -> String:
	"""'home by about 11:40' -- when a trip authorised now would be home (out, gathering its biggest share, back)."""
	if calendar == null:
		return ""
	var share: int = Rules.seat_share_milli(trip_milli(kind_index, party, kit), party, 0, kit)
	var ticks: int = 2 * walk_home_ticks(kind_index) + _gather_ticks(kind_index, share)
	return "home by about %s (dusk %02d:00)" % [Rules.clock_text(calendar.now().tick_of_day + ticks), Rules.DUSK_HOUR]


# --- the places remembered (decision 1721) ---------------------------------------------------------------------

func _remember(t: int) -> void:
	"""Trip `t` home with a haul: its spot's note is now this trip's (the latest only: never a stacking bonus)."""
	var k: int = t_kind[t]
	var now: int = calendar.tick if calendar != null else 0
	note_tick[k] = now
	note_milli[k] = t_got[t]
	note_ticks[k] = now - t_posted[t]
	note_lead[k] = name_of(t_lead[t]) if t_lead[t] != NONE else ""


func note_line(kind_index: int) -> String:
	"""What the village remembers of `kind_index`'s spot ("": nothing yet): 'Remembered (Y1 Summer 2): 8.0 U of nuts,
	out 2 h 10 min, led by Wenna'."""
	if note_tick[kind_index] < 0:
		return ""
	var when: SimClock.Calendar = _when
	when.set_tick(note_tick[kind_index])
	@warning_ignore("integer_division") var hours: int = note_ticks[kind_index] / SimClock.TICKS_PER_HOUR
	@warning_ignore("integer_division") var minutes: int = (note_ticks[kind_index] % SimClock.TICKS_PER_HOUR) * 60 / SimClock.TICKS_PER_HOUR
	var led: String = ", led by %s" % note_lead[kind_index] if not note_lead[kind_index].is_empty() else ""
	return "Remembered (Y%d %s %d): %s of %s, out %d h %02d min%s" % [when.year, CalendarScript.SEASON_TITLES[when.season],
		when.season_day, Rules.units_text(note_milli[kind_index]), Rules.KIND_WORDS[kind_index], hours, minutes, led]


func _give_first(j: int, members: PackedInt32Array, given: PackedInt32Array) -> void:
	"""Seat `j` to the first selected resident not given one yet who may take it."""
	for who: int in members:
		if not given.has(who) and eligibility(j, who).is_empty() and claim(j, who):
			given.append(who)
			return


func cancel_trip(t: int) -> String:
	"""Call trip `t` off: every seat not carrying ends (its claim and room given back); a haul in hand comes home. ""
	when called off."""
	if t < 0 or t >= Rules.MAX_TRIPS or t_live[t] == 0:
		return "no such trip is out"
	var carrying: int = 0
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 1 and j_trip[j] == t:
			if j_load[j] > 0:
				carrying += 1
			else:
				_end_seat(j)
	_note("The foraging trip to %s is called off%s" % [Rules.SPOT_NAMES[t_kind[t]],
		(": %d bring their haul home" % carrying) if carrying > 0 else ""], false)
	return ""


func cancel_refusal(t: int) -> String:
	"""Why trip `t` may not be called off ("" when it may): every seat is carrying home."""
	if t < 0 or t >= Rules.MAX_TRIPS or t_live[t] == 0:
		return "no foraging trip is out"
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 1 and j_trip[j] == t and j_load[j] == 0:
			return ""
	return "every forager is carrying the haul home — a load in hand is always delivered"


func trip_count() -> int:
	"""Trips out."""
	return t_live.count(1)


func first_trip() -> int:
	"""The earliest trip out (NONE: none)."""
	var best: int = NONE
	for t: int in Rules.MAX_TRIPS:
		if t_live[t] == 1 and (best == NONE or t_serial[t] < t_serial[best]):
			best = t
	return best


# --- the seats: opening, claiming and releasing (work/forage_work.gd reads these) ------------------------------

func job_count() -> int:
	"""Live seat rows."""
	return j_live.count(1)


func is_job(j: int, serial: int) -> bool:
	"""Whether row `j` still holds the seat opened with `serial`."""
	return j >= 0 and j < Rules.MAX_JOBS and j_live[j] == 1 and j_serial[j] == serial


func _open_seat(t: int, share: int) -> int:
	"""A fresh seat row of trip `t` for `share` (the trip's caller made sure a row is free)."""
	var j: int = j_live.find(0)
	j_live[j] = 1
	j_serial[j] = _next_serial
	_next_serial += 1
	j_trip[j] = t
	j_step[j] = S_TO_SPOT
	j_worker[j] = NONE
	j_share[j] = share
	j_claimed[j] = 0
	j_claim_slot[j] = NULL_REF.x
	j_claim_gen[j] = NULL_REF.y
	j_hold[j] = NONE
	j_load[j] = 0
	j_load_at[j] = Vector2.INF
	j_goal[j] = spot_at[t_kind[t]]
	for column: PackedInt64Array in [j_num, j_mwu, j_need, j_wait_usec]:
		column[j] = 0
	for column: PackedByteArray in [j_issued, j_at, j_paused]:
		column[j] = 0
	j_tries[j] = 0
	j_failed[j] = NONE
	j_words[j] = ""
	return j


func job_of_worker(who: int) -> int:
	"""The seat `who` is on (NONE)."""
	for j: int in Rules.MAX_JOBS:
		if j_live[j] == 1 and j_worker[j] == who:
			return j
	return NONE


func waiting(j: int) -> bool:
	"""Whether seat `j` waits for a forager and may be taken now."""
	return j_live[j] == 1 and j_worker[j] == NONE and j_paused[j] == 0 and j_wait_usec[j] <= 0


func eligibility(j: int, who: int) -> String:
	"""Why `who` may not take seat `j` ("" when it may): one foraging seat at a time, on land and on the surface, and not
	the one who could not reach it last time. Anybeast forages (LORE-P12)."""
	if job_of_worker(who) != NONE and j_worker[j] != who:
		return "is on another foraging trip"
	if who == j_failed[j] and j_worker[j] != who:
		return "could not reach %s last time" % place_words(j)
	return _unfit(who)


func _unfit(who: int) -> String:
	"""Why `who` may not set out now ("" when they may): in the water, or below ground."""
	var brain: BrainScript = brain_of(who)
	if brain.water_hold or brain.in_water:
		return "in the water"
	if brain.underground:
		return "is below ground"
	return ""


func claim(j: int, who: int) -> bool:
	"""Hand waiting seat `j` to `who`, who sets off at once. False when it may not."""
	if not waiting(j) or not eligibility(j, who).is_empty():
		return false
	var task := TaskScript.new(self, j, j_serial[j])
	j_worker[j] = who
	j_issued[j] = 1
	j_at[j] = 0
	_tasks[j] = task
	var brain: BrainScript = brain_of(who)
	brain.order_task(task)
	if brain.task != task:
		j_worker[j] = NONE
		_tasks[j] = null
		return false
	revision += 1
	return true


func _end_seat(j: int) -> void:
	"""Close seat `j`: its claim and room given back, its forager free (from outside `drive`, sent back to its routine);
	its trip told."""
	var who: int = j_worker[j]
	driver.close(_claim_ref(j))
	pantry.release(j_hold[j])
	j_live[j] = 0
	j_worker[j] = NONE
	_tasks[j] = null
	if who != NONE and j != _driving:
		brain_of(who).work_done()
	_seat_over(j_trip[j])
	revision += 1


func _seat_over(t: int) -> void:
	"""One of trip `t`'s seats is over: the last one home ends the trip, said with its haul."""
	t_seats[t] -= 1
	if t_seats[t] > 0:
		return
	t_live[t] = 0
	trips_done += 1
	var k: int = t_kind[t]
	if t_got[t] > 0:
		_remember(t)
		_note("The foraging party is back from %s: %s of %s in the stores%s" % [Rules.SPOT_NAMES[k],
			Rules.units_text(t_got[t]), Rules.KIND_WORDS[k], outing_words(t)], false)


func _let_go(j: int) -> void:
	"""Seat `j` loses its forager but stays on the board -- its claim, room and work kept; a haul in hand set down where
	it is, for the next to fetch."""
	var who: int = j_worker[j]
	j_worker[j] = NONE
	j_issued[j] = 0
	j_at[j] = 0
	_tasks[j] = null
	if j_load[j] > 0 and not j_load_at[j].is_finite() and who != NONE:
		j_load_at[j] = brain_of(who).surface_point()
	revision += 1


func _claim_ref(j: int) -> Vector2i:
	"""Seat `j`'s claim's FORAGE Job (NULL_REF: none)."""
	return Vector2i(j_claim_slot[j], j_claim_gen[j])


# --- the task's callbacks (forage_task.gd) -----------------------------------------------------------------

func first_site(j: int, serial: int) -> Vector2:
	"""Where a new forager of seat `j` walks first: its step's place (or a set-down haul's)."""
	if not is_job(j, serial):
		return Vector2.ZERO
	j_goal[j] = _goal_of(j)
	return j_goal[j]


func goal_point(j: int) -> Vector2:
	"""Where seat `j` is now (the board's distance)."""
	return j_goal[j] if j_worker[j] != NONE else _goal_of(j)


func arrived(j: int, serial: int, brain: BrainScript) -> void:
	"""The forager reached where it was sent: handled on its next frame (`drive`)."""
	if is_job(j, serial) and j_worker[j] == brain.index:
		j_issued[j] = 2


func drive(j: int, serial: int, brain: BrainScript, delta: float) -> bool:
	"""One frame of seat `j` for its forager: an arrival handled, then the step's frame. False once its part is over."""
	if not is_job(j, serial) or j_worker[j] != brain.index:
		return false
	_driving = j
	if j_issued[j] == 2:
		j_issued[j] = 0
		_on_arrival(j, brain)
	if is_job(j, serial) and j_worker[j] == brain.index:
		_frame(j, brain, delta)
	_driving = NONE
	return is_job(j, serial) and j_worker[j] == brain.index


func called_away(j: int, serial: int, brain: BrainScript) -> void:
	"""The brain gave the seat up: a walk it could not finish, or an order, the night, a meal or a release."""
	if not is_job(j, serial) or j_worker[j] != brain.index:
		return
	if brain.trip_failed() and j_step[j] != S_GATHER:
		_unreached(j, brain)
		return
	_let_go(j)


func must_finish(j: int, serial: int) -> bool:
	"""Whether the night and a meal call must wait: a haul in hand."""
	return is_job(j, serial) and j_load[j] > 0 and not j_load_at[j].is_finite()


func _unreached(j: int, brain: BrainScript) -> void:
	"""The forager could not get there: the seat waits RETRY_USEC and is offered again (not to it); after MAX_TRIES a
	seat with nothing in hand is given up (its claim and room given back)."""
	j_tries[j] += 1
	j_failed[j] = brain.index
	j_words[j] = "can't reach %s — %s" % [place_words(j), brain.route_refusal()]
	_let_go(j)
	j_wait_usec[j] = Rules.RETRY_USEC
	if j_tries[j] >= Rules.MAX_TRIES and j_load[j] == 0:
		_note("%s could not reach %s: the seat is given up" % [name_of(brain.index), place_words(j)], true)
		_end_seat(j)


# --- the steps -----------------------------------------------------------------------------------------------

func _goal_of(j: int) -> Vector2:
	"""Where seat `j`'s step is (a set-down haul first: it must be picked up)."""
	if j_load[j] > 0 and j_load_at[j].is_finite():
		return j_load_at[j]
	if j_step[j] == S_TO_STORE and pantry.hold_location_into(j_hold[j], _read):
		return pantry.storage.position_of(_read.value)
	return spot_at[t_kind[j_trip[j]]]


func _begin_walk(j: int, brain: BrainScript) -> void:
	"""Order the walk to seat `j`'s goal (loaded while it carries its haul)."""
	j_at[j] = 0
	j_goal[j] = _goal_of(j)
	j_issued[j] = 1
	if j_load[j] > 0 and not j_load_at[j].is_finite():
		brain.task_carry_to(j_goal[j])
	else:
		brain.task_walk_to(j_goal[j])


func _on_arrival(j: int, brain: BrainScript) -> void:
	"""The forager is where it was sent (only if it stands there): a set-down haul taken up, the spot, or the store."""
	if not brain.arrived_near(j_goal[j], Rules.ARRIVE_M):
		_unreached(j, brain)
		return
	j_tries[j] = 0
	j_words[j] = ""
	if j_load[j] > 0 and j_load_at[j].is_finite():
		j_load_at[j] = Vector2.INF
		_begin_walk(j, brain)
	elif j_step[j] == S_TO_SPOT:
		_at_spot(j, brain)
	elif j_step[j] == S_TO_STORE:
		_deliver(j, brain)


func _frame(j: int, brain: BrainScript, delta: float) -> void:
	"""One frame of a step that is not a planner walk: the work, or a lapsed walk re-ordered."""
	if j_step[j] == S_GATHER:
		_work_frame(j, brain, delta)
	elif j_issued[j] == 0 and j_wait_usec[j] <= 0 and _room_for_haul(j, brain):
		_begin_walk(j, brain)


func _room_for_haul(j: int, brain: BrainScript) -> bool:
	"""Whether seat `j` may walk on: anything but a haul in hand with no room held -- for which room is sought again
	(none: it waits RETRY_USEC where it stands, saying why)."""
	if j_step[j] != S_TO_STORE or j_load[j] <= 0 or j_load_at[j].is_finite() or pantry.is_hold(j_hold[j]):
		return true
	var k: int = t_kind[j_trip[j]]
	if pantry.reserve_near_into(item_of(k), j_load[j], brain.surface_point(), _read):
		j_hold[j] = _read.value
		j_words[j] = ""
		return true
	j_wait_usec[j] = Rules.RETRY_USEC
	return false


func _work_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""At its work: standing at its spot (off it, it walks back and nothing is credited), facing it, the clip playing."""
	if not brain.arrived_near(j_goal[j], Rules.ARRIVE_M):
		j_step[j] = S_TO_SPOT
		_begin_walk(j, brain)
		return
	j_at[j] = 1
	brain.task_face(j_goal[j] + Vector2(0.0, -0.6), delta)
	brain.task_play(CLIP_WORK)


func _at_spot(j: int, brain: BrainScript) -> void:
	"""At the spot: a claim already held (a seat taken over) goes straight to work; else the check -- in season, a share
	still admitted, room in a store -- and the claim."""
	if j_claimed[j] > 0:
		j_step[j] = S_GATHER
		return
	var why: String = _claim_share(j, brain)
	if why.is_empty():
		j_step[j] = S_GATHER
		return
	j_words[j] = why
	if _turned_back:
		t_turned[j_trip[j]] += 1
		_note("%s turned back at %s: %s" % [name_of(brain.index), place_words(j), why], false)
		_end_seat(j)
		return
	if _room_short:
		j_wait_usec[j] = Rules.RETRY_USEC
		_let_go(j)
		return
	_note("%s found nothing to gather at %s: %s" % [name_of(brain.index), place_words(j), why], false)
	_end_seat(j)


func _claim_share(j: int, brain: BrainScript) -> String:
	"""Claim seat `j`'s share (or what the basin still admits of it) and hold its room: "" when claimed, else why not."""
	var k: int = t_kind[j_trip[j]]
	var kind: int = Rules.KINDS[k]
	_room_short = false
	_turned_back = false
	if driver.availability(kind) == 0:
		return "%s are out of season now" % Rules.KIND_WORDS[k]
	var amount: int = mini(j_share[j], harvestable_milli(k))
	if amount < Rules.MIN_SHARE_MILLI:
		return nothing_left_words(k)
	amount = mini(amount, daylight_cap_milli(k, skills.level_of(brain.index)))
	if amount < Rules.MIN_SHARE_MILLI:
		_turned_back = true
		return "too little daylight left to gather and be home by dusk (%02d:00)" % Rules.DUSK_HOUR
	return _hold_and_claim(j, k, amount, brain)


func _hold_and_claim(j: int, k: int, amount: int, brain: BrainScript) -> String:
	"""Seat `j`'s room held for `amount` of kind index `k` and its claim opened on the basin: "" when both are, else why
	not (nothing left held)."""
	var kind: int = Rules.KINDS[k]
	if not pantry.reserve_near_into(item_of(k), amount, brain.surface_point(), _read):
		_room_short = true
		return "no store has room for %s of %s — make room in the Pantry (K)" % [Rules.units_text(amount), Rules.KIND_WORDS[k]]
	j_hold[j] = _read.value
	var job: Vector2i = driver.open_claim(kind, amount)
	if job == NULL_REF:
		pantry.release(j_hold[j])
		j_hold[j] = NONE
		return "the woods refused it (%s)" % String(driver.last_refusal)
	j_claim_slot[j] = job.x
	j_claim_gen[j] = job.y
	j_claimed[j] = amount
	j_need[j] = Rules.work_mwu(amount, driver.work_per_u_wu(kind, skills.level_of(brain.index)))
	j_mwu[j] = 0
	j_num[j] = 0
	return ""


func _gathered(j: int) -> void:
	"""The share gathered: the claim collected (stock and today's quota debited) into the forager's hands, its room
	trimmed to it, and home to the store."""
	var k: int = t_kind[j_trip[j]]
	var got: int = driver.collect(_claim_ref(j), Rules.KINDS[k], j_claimed[j])
	driver.close(_claim_ref(j))
	j_claim_slot[j] = NULL_REF.x
	j_claim_gen[j] = NULL_REF.y
	j_claimed[j] = 0
	collected_milli[k] += got
	j_load[j] = got
	revision += 1
	if got <= 0:
		_end_seat(j)
		return
	if got < pantry.hold_milli(j_hold[j]):
		pantry.resize_hold(j_hold[j], got)
	j_step[j] = S_TO_STORE
	if j_worker[j] != NONE:
		_begin_walk(j, brain_of(j_worker[j]))


func _deliver(j: int, brain: BrainScript) -> void:
	"""The haul put down at its store: what fits stored against its room; the rest carried on to another store with
	room, or held while none has (decision 0222)."""
	var k: int = t_kind[j_trip[j]]
	var item: int = item_of(k)
	var stored: int = 0
	if pantry.hold_location_into(j_hold[j], _read) and pantry.store_upto_into(item, j_load[j], _read.value, j_hold[j], _read):
		stored = _read.value
	pantry.release(j_hold[j])
	j_hold[j] = NONE
	j_load[j] -= stored
	stored_milli[k] += stored
	t_got[j_trip[j]] += stored
	revision += 1
	if j_load[j] <= 0:
		_end_seat(j)
		return
	if _room_for_haul(j, brain):
		_begin_walk(j, brain)
		return
	j_words[j] = "no store has room for %s of %s — make room in the Pantry (K)" % [Rules.units_text(j_load[j]),
		Rules.KIND_WORDS[k]]
	j_wait_usec[j] = Rules.RETRY_USEC


# --- the board's words and commands ---------------------------------------------------------------------------

func place_words(j: int) -> String:
	"""Where seat `j`'s step is, in words."""
	if j_step[j] == S_TO_STORE and pantry.hold_location_into(j_hold[j], _read):
		return pantry.storage.label_of(_read.value)
	return Rules.SPOT_NAMES[t_kind[j_trip[j]]]


func doing_text(j: int, serial: int) -> String:
	"""What seat `j`'s forager is doing, for the party panel and the roster."""
	if not is_job(j, serial):
		return ""
	var k: int = t_kind[j_trip[j]]
	match j_step[j]:
		S_GATHER:
			return "gathering %s at %s" % [Rules.KIND_WORDS[k], Rules.SPOT_NAMES[k]]
		S_TO_STORE:
			return "carrying %s of %s home to %s" % [Rules.units_text(j_load[j]), Rules.KIND_WORDS[k], place_words(j)]
	return "foraging: going to %s for %s" % [Rules.SPOT_NAMES[k], Rules.KIND_WORDS[k]]


func task_words(j: int) -> String:
	"""The Work screen's action words: 'Forage nuts'."""
	return "Forage %s" % Rules.KIND_WORDS[t_kind[j_trip[j]]]


func hold_refusal(j: int) -> String:
	"""Why seat `j`'s forager may not be stopped or swapped now ("" when it may): a haul in hand is delivered (0222)."""
	var who: int = j_worker[j]
	if who != NONE and j_load[j] > 0 and not j_load_at[j].is_finite():
		return "%s is carrying the haul — it finishes the delivery first" % name_of(who)
	return ""


func pause_job(j: int, on: bool) -> String:
	"""Pause seat `j` (its forager stood down, the seat kept) or resume it: "" when done, else why not."""
	if not on:
		j_paused[j] = 0
		revision += 1
		return ""
	if j_paused[j] == 1:
		return "it is paused already"
	var why: String = hold_refusal(j)
	if not why.is_empty():
		return why
	var who: int = j_worker[j]
	_let_go(j)
	j_paused[j] = 1
	if who != NONE:
		brain_of(who).work_done()
	return ""


func reassign_job(j: int, who: int) -> String:
	"""Give seat `j` to `who` instead: "" when done, else why not."""
	var why: String = hold_refusal(j)
	if why.is_empty():
		why = eligibility(j, who)
	if not why.is_empty():
		return why
	var was: int = j_worker[j]
	if was != NONE:
		_let_go(j)
		brain_of(was).work_done()
	j_paused[j] = 0
	j_wait_usec[j] = 0
	return "" if claim(j, who) else "it could not be handed over"


func cancel_job(j: int) -> String:
	"""Cancel seat `j` alone: not while its haul is in hand. "" when done."""
	if j_load[j] > 0:
		return "a delivery always finishes: the haul is already gathered"
	_end_seat(j)
	return ""


func remaining_usec(j: int) -> int:
	"""Demo microseconds of gathering seat `j` has left (-1: not gathering)."""
	if j_step[j] != S_GATHER:
		return -1
	return FisheryRules.work_usec(maxi(j_need[j] - j_mwu[j], 0), 0)


func is_walking(j: int) -> bool:
	"""Whether seat `j`'s forager is on a planner walk."""
	return j_step[j] != S_GATHER


func held_key_of_job(j: int) -> StringName:
	"""The model seat `j`'s forager carries (&"": nothing): the basket while it carries its haul."""
	return BASKET_KEY if j_load[j] > 0 and not j_load_at[j].is_finite() else &""


# --- the readouts ------------------------------------------------------------------------------------------------

func season_words(kind_index: int) -> String:
	"""'summer, autumn, winter' -- the seasons of §5.5's availability row the kind is gathered in."""
	var kind: int = Rules.KINDS[kind_index]
	var parts := PackedStringArray()
	for season: int in CalendarScript.SEASON_TITLES.size():
		if driver.forage.availability_per_1000(kind, season).value > 0:
			parts.append(CalendarScript.SEASON_TITLES[season].to_lower())
	return ", ".join(parts)


func trip_line(t: int) -> String:
	"""'Nuts from the hazel brake: 2 foragers, 8.0 U asked, 4.0 U home'."""
	var k: int = t_kind[t]
	var out: int = 0
	for j: int in Rules.MAX_JOBS:
		out += 1 if j_live[j] == 1 and j_trip[j] == t and j_worker[j] != NONE else 0
	var turned: String = " · %d turned back for the dark" % t_turned[t] if t_turned[t] > 0 else ""
	return "%s from %s: %d foragers (%d out), %s asked, %s home%s%s" % [Rules.KIND_WORDS[k].capitalize(),
		Rules.SPOT_NAMES[k], t_party[t], out, Rules.units_text(t_asked[t]), Rules.units_text(t_got[t]), outing_words(t),
		turned]


func status_line() -> String:
	"""The Routes layer's and the panel's line: 'Foraging: 1 trip out · today's quota 9.8 of 21.1 U left'."""
	return "Foraging: %d trip%s out · the woods' quota today %s of %s left" % [trip_count(),
		"" if trip_count() == 1 else "s", Rules.units_text(driver.quota_left_milli()), Rules.units_text(driver.quota_today_milli())]
