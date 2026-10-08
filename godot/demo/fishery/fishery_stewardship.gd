extends RefCounted
## STEWARDSHIP: each water's seasonal record, and the intensive-harvest policy shown before it is accepted. Decision
## 1713 (the fishing revamp, #49; review ECO-025, REQ-SET-048/049). Integer state; nothing here writes into the
## settlement simulation (the policy flag is the demo's private fishing store's, set through fishing_driver.gd).
##
## THE RECORD (review ECO-025: "recent landed catch, recovery trend, current commitment and expected return to the
## chosen safe band"), per water -- the stream (the river habitat: the run and the ford) and the pond (the lake):
##   * landed: the catch its completed cycles took over the last RECORD_DAYS days (PROVISIONAL: one §4.3 season,
##     12 days), kept in a ring of day totals rolled at each new day;
##   * trend: its stock now against the stock at the start of the day (every species summed; midnight's recovery
##     lands at the day's start, so this is the day's fishing);
##   * commitment: its effort slots in use (§5.4: river 4, lake 6);
##   * return: for each species in REQ-SET-048's restocking latch, the days until §5.4's midnight recovery alone lifts
##     it strictly above 40% -- the latch's own exit -- predicted by `days_to_recover`.
##
## THE PREDICTION is §5.4's midnight formula replayed, `P' = min(K, P + floor(r*P*(K-P)/(1000*K)) + floor(K/200))`
## plus salmon's 300 U on autumn day 1, day by day on the real calendar, with no fishing -- fishing.gd's own constants,
## checked against the store's real midnight in test_demo_fishing_revamp.gd. fishing.gd computes none ("§5.4 states no
## horizon for one"), so this horizon -- the 40% exit -- is decision 1713's PROPOSAL P4.
##
## INTENSIVE HARVEST (REQ-SET-049: "show the 10% hard stock floor and predicted recovery time before accepting that
## policy"). The Water panel's Intensive button names the floor and, per species, the days from that 10% floor back
## above 40% in its action card -- shown before it is pressed. The policy is fishing.gd's one flag, per habitat; never
## reset automatically (READY_06 §5); REQ-SET-047 keeps the 30% floor during a closure whatever the flag says.

const Fishing := preload("res://scripts/core/fishing.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## The two waters: the stream (river habitat) and the pond (lake habitat).
const WATER_STREAM: int = 0
const WATER_POND: int = 1
const WATER_COUNT: int = 2
const WATER_NAMES: Array[String] = ["The stream", "The pond"]
## The site each water's figures are read at (fishing_driver.gd SITE_*).
const WATER_SITE: Array[int] = [Driver.SITE_RUN, Driver.SITE_POND]
## Days of landed catch kept (PROVISIONAL: one season).
const RECORD_DAYS: int = SimClock.DAYS_PER_SEASON
## A prediction gives up after this many days (two years: never reached by §5.4's recruitment term, 0.5% K a day).
const PREDICT_MAX_DAYS: int = 2 * SimClock.DAYS_PER_YEAR
const PERCENT: int = 100

## Per water: the landed ring (RECORD_DAYS slots, milli-U), the stock at the day's start (milli-U).
var landed: PackedInt64Array = PackedInt64Array()
var stock_at_dawn: PackedInt64Array = PackedInt64Array()
## Bumped when the record changes.
var revision: int = 0

var _day: int = -1
var _scan: SimClock.Calendar = SimClock.Calendar.new(0)


func _init() -> void:
	"""Empty records."""
	landed.resize(WATER_COUNT * RECORD_DAYS)
	stock_at_dawn.resize(WATER_COUNT)


static func water_of_site(site: int) -> int:
	"""The water a fishing site is on."""
	return WATER_POND if Driver.SITE_HABITAT[site] == Fishing.HABITAT_LAKE else WATER_STREAM


func follow(driver: Driver) -> void:
	"""Each new day: the ring moves on (the day's slot cleared) and each water's stock is noted."""
	if driver == null:
		return
	var day: int = SimClock.day_index_at(driver.completed_tick())
	if day == _day:
		return
	var steps: int = mini(day - _day, RECORD_DAYS) if _day >= 0 else RECORD_DAYS
	for k: int in steps:
		var slot: int = posmod(day - k, RECORD_DAYS)
		for w: int in WATER_COUNT:
			landed[w * RECORD_DAYS + slot] = 0
	_day = day
	for w: int in WATER_COUNT:
		stock_at_dawn[w] = stock_now(driver, w)
	revision += 1


func record(site: int, milli: int) -> void:
	"""A completed cycle's catch, on today's slot of its water."""
	if milli <= 0 or _day < 0:
		return
	landed[water_of_site(site) * RECORD_DAYS + posmod(_day, RECORD_DAYS)] += milli
	revision += 1


func landed_recent(water: int) -> int:
	"""The water's catch over the last RECORD_DAYS days, milli-U."""
	var total: int = 0
	for k: int in RECORD_DAYS:
		total += landed[water * RECORD_DAYS + k]
	return total


func stock_now(driver: Driver, water: int) -> int:
	"""Every species of the water summed, milli-U."""
	var slot: int = driver.store().habitat_slot_of(driver.habitat_ref_of_site(WATER_SITE[water])).value
	return driver.store().population_total_milli_of(slot).value


static func grow_milli(species: int, p: int, k: int, season: int, season_day: int) -> int:
	"""§5.4's midnight for one stock of `species` at P = `p`, K = `k` (milli-U): the population after it."""
	if p >= k:
		return k
	var r: int = Fishing.SPECIES_RECOVERY_PER_1000[species]
	@warning_ignore("integer_division") var logistic: int = r * p * (k - p) / (Fishing.RECOVERY_DENOMINATOR * k)
	@warning_ignore("integer_division") var grown: int = logistic + k / Fishing.RECRUITMENT_DIVISOR
	if species == Fishing.SPECIES_SALMON and season == Fishing.SEASON_AUTUMN \
			and season_day == Fishing.SALMON_RUN_FIRST_DAY:
		grown += Fishing.SALMON_AUTUMN_RESTOCK_U * Fishing.MILLI_PER_UNIT
	return mini(k, p + grown)


func days_to_recover(species: int, from_milli: int, k: int, from_tick: int) -> int:
	"""Midnights, with no fishing, until a stock at `from_milli` stands strictly above 40% of `k` (REQ-SET-048's exit),
	starting from `from_tick`: 0 when it already does, -1 past PREDICT_MAX_DAYS."""
	var p: int = from_milli
	for day: int in PREDICT_MAX_DAYS + 1:
		if PERCENT * p > Fishing.RESTOCK_RECOVERY_PERCENT * k:
			return day
		_scan.set_tick((SimClock.day_index_at(from_tick) + day + 1) * SimClock.TICKS_PER_DAY
			- SimClock.CALENDAR_OFFSET_TICKS)
		p = grow_milli(species, p, k, _scan.season, _scan.season_day)
	return -1


func from_floor_days(driver: Driver, site: int, species_index: int) -> int:
	"""REQ-SET-049's predicted recovery: days from the 10% hard floor back above 40%, for a site's species, from now."""
	var row: int = driver.stock_row(site, species_index)
	var k: int = driver.store().stock_capacity_milli_of(row).value
	@warning_ignore("integer_division") var floor_milli: int = k * Fishing.HARD_FLOOR_PERCENT / PERCENT
	return days_to_recover(driver.species_row_of(site, species_index), floor_milli, k, driver.completed_tick())


static func days_words(days: int) -> String:
	"""A prediction in words: 'in about 5 days', or 'not within two years' for `days_to_recover`'s -1."""
	return "in about %d days" % days if days >= 0 else "not within two years"


func record_line(driver: Driver, water: int, units: Callable) -> String:
	"""One water's record: 'The stream: landed 24.0 U in 12 days · stock 1680.0 U (+12.0 U today) · 1 of 4 places in
	use · intensive off · trout restocking: above 40% in about 5 days'. `units(milli)` formats a quantity."""
	var site: int = WATER_SITE[water]
	var store: Fishing = driver.store()
	var slot: int = store.habitat_slot_of(driver.habitat_ref_of_site(site)).value
	var now: int = stock_now(driver, water)
	var change: int = now - stock_at_dawn[water]
	var parts := PackedStringArray(["%s: landed %s in %d days" % [WATER_NAMES[water], units.call(landed_recent(water)),
		RECORD_DAYS], "stock %s (%s%s today)" % [units.call(now), "+" if change >= 0 else "−", units.call(absi(change))],
		"%d of %d places in use" % [store.effort_slots_used_of(slot).value, store.effort_slots_of(slot).value],
		"intensive %s" % ("ON (10% floor)" if driver.intensive(site) else "off")])
	for s: int in Fishing.SPECIES_PER_HABITAT:
		var row: int = driver.stock_row(site, s)
		if store.is_restocking(row):
			var days: int = days_to_recover(driver.species_row_of(site, s), store.population_milli_of(row).value,
				store.stock_capacity_milli_of(row).value, driver.completed_tick())
			parts.append("%s restocking: above 40%% %s" % [String(driver.species_key_of(site, s)), days_words(days)])
	return " · ".join(parts)


func intensive_lines(driver: Driver, site: int) -> PackedStringArray:
	"""REQ-SET-049's figures for the intensive card: the floor and each species' days from it back above 40%."""
	var lines := PackedStringArray(["Fish may be taken down to the 10% hard floor instead of 30% (never in a closure, " \
		+ "never past the day's quota)"])
	var each := PackedStringArray()
	for s: int in Fishing.SPECIES_PER_HABITAT:
		each.append("%s %s" % [String(driver.species_key_of(site, s)), days_words(from_floor_days(driver, site, s))])
	lines.append("From that floor, back above 40%% (no fishing): %s" % ", ".join(each))
	return lines
