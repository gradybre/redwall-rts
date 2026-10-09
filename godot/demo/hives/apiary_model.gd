extends RefCounted
## THE APIARY'S STATE (decision 1601; review group Y's ECO-011 and ECO-012): each apiary's hive as a REAL Hive row of
## scripts/core/orchard_hive.gd -- §5.6's strength, service day, feed, honey and wax, its day step, its deficits and its
## recolonisation, called and never retyped -- in the ORCHARD'S OWN STORE (orchard_model.gd `store`), so REQ-SET-082's
## pollination links reach the orchard's trees by the store's own synchronous refresh. Round it the demo's own: the books,
## the wax shelf, a recolonisation's wait and §5.8's wildlife roll. Presentation only. Pure logic (no nodes).
##
## THE DAY (`close_day`, at each midnight, after the trees' day): each hive's §5.6 day (`apply_hive_day_into`: produce
## when serviced, -200 when not; winter eats feed or -500), then §5.8's wildlife roll in summer and autumn, then a
## recolonisation whose 3-day wait is over brings the hive back to 8000.
##
## A COLLECTION (`collect`, the keeper's service done): everything the hive made is taken; the WINTER FEED IS PUT BY FIRST
## (ECO-012: the hive's feed topped up to the rest of the coming winter's need, hive_rules.gd `feed_need_milli`), then up
## to `cap_milli` is released for the baskets and anything beyond the cap stays in the hive; the wax goes to the shelf.
##
## THE BOOKS (milli-U), so nothing is made or lost unseen:
##   honey made  == honey in the hive + released + put by as feed from the hive + lost to wildlife
##   feed put by (from the hive and from the pantry) == feed in the hive + eaten in winter
##   wax made    == wax in the hive + on the shelf

const Rules := preload("res://demo/hives/hive_rules.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Rng := preload("res://scripts/core/rng.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const REFUSE_NOT_ABANDONED: String = "NOT_ABANDONED"
const REFUSE_NOT_SPRING: String = "NOT_SPRING"
const REFUSE_UNDER_WAY: String = "UNDER_WAY"

var store: Hive = null
## Per apiary: its Hive reference, and the Building reference §4.2's `Hive.building` names (the inherited apiary's).
var hive_ref: Array[Vector2i] = []
var building_ref: Array[Vector2i] = []
## Per apiary: the day a recolonisation's 3-day wait ends (0: none under way).
var recolonize_day: PackedInt32Array = PackedInt32Array()
## The books (see THE BOOKS).
var honey_made_milli: int = 0
var wax_made_milli: int = 0
var released_milli: int = 0
var fed_from_hive_milli: int = 0
var fed_from_pantry_milli: int = 0
var eaten_milli: int = 0
var lost_milli: int = 0
var wax_shelf_milli: int = 0
## Days a hive went unserviced in its working seasons, and wildlife visits (the readout's tallies).
var missed_days: int = 0
var wildlife_visits: int = 0
## The last midnight's news, one line an event, and whether each is a warning: cleared at the next midnight.
var news: PackedStringArray = PackedStringArray()
var news_warning: PackedByteArray = PackedByteArray()
## Bumped on every change a reader shows.
var revision: int = 0

var _day: Hive.HiveDayResult = Hive.HiveDayResult.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_store: Hive, day: int) -> void:
	"""The village's apiaries as it opens on `day`: each an inherited, colonised hive at §5.6's 8000 in `p_store`."""
	store = p_store
	recolonize_day.resize(Rules.APIARY_COUNT)
	for apiary: int in Rules.APIARY_COUNT:
		var building: Vector2i = store.directory().create(EntityDirectory.KIND_BUILDING)
		var lo: Vector2i = Rules.APIARY_MIN[apiary]
		var hi: Vector2i = Rules.APIARY_MAX[apiary]
		var made: Hive.OpResult = store.create_hive(building, lo.x, lo.y, hi.x, hi.y, day)
		assert(made.ok, "the apiary's footprint is on the map and the store has room")
		building_ref.append(building)
		hive_ref.append(made.ref)


# --- reading a hive ------------------------------------------------------------------------------------------------------

func slot_of(apiary: int) -> int:
	"""Apiary `apiary`'s Hive typed row."""
	return store.directory().get_typed_row(hive_ref[apiary])


func strength(apiary: int) -> int:
	"""§5.6's strength, 0..10000."""
	return store.hive_strength_of(slot_of(apiary)).value


func honey_in_hive(apiary: int) -> int:
	"""Honey the hive has made and nobody has collected, milli-U."""
	return store.hive_honey_milli_of(slot_of(apiary)).value


func wax_in_hive(apiary: int) -> int:
	"""Wax the hive has made and nobody has collected, milli-U."""
	return store.hive_wax_milli_of(slot_of(apiary)).value


func feed(apiary: int) -> int:
	"""Honey put by in the hive against winter, milli-U."""
	return store.hive_feed_milli_of(slot_of(apiary)).value


func is_healthy(apiary: int) -> bool:
	"""§5.6's healthy line (5000): the hive pollinates."""
	return store.is_hive_healthy(slot_of(apiary))


func is_abandoned(apiary: int) -> bool:
	"""§5.6: a hive at 0 strength is abandoned."""
	return store.is_hive_abandoned(slot_of(apiary))


func service_due(apiary: int, day: int) -> bool:
	"""Whether §5.6's 20 WU of service is owed on `day` (spring to autumn, a live hive not yet serviced that day)."""
	return store.is_service_due(slot_of(apiary), day)


func service_deficit_days(apiary: int, day: int) -> int:
	"""REQ-SET-083's service deficit: days since the hive was last serviced (0: today)."""
	return _read.value if store.service_deficit_days_into(slot_of(apiary), day, _read) else 0


func feed_shortfall_milli(apiary: int, day: int) -> int:
	"""REQ-SET-083's feed deficit, looking ahead: what the hive's feed lacks of the rest of this winter's (0 outside
	winter: the coming winter's feed is put by from its own honey first)."""
	if Hive.season_of_day(day) != Hive.SEASON_WINTER or is_abandoned(apiary):
		return 0
	return maxi(0, Rules.feed_need_milli(day) - feed(apiary))


func releasable_milli(apiary: int, day: int) -> int:
	"""What a collection on `day` would release for the baskets: the hive's honey less the feed still to be put by."""
	var to_feed: int = maxi(0, Rules.feed_need_milli(day) - feed(apiary))
	return maxi(0, honey_in_hive(apiary) - to_feed)


# --- the keeper's work ----------------------------------------------------------------------------------------------------

func service(apiary: int, day: int) -> bool:
	"""§5.6's 20 WU of service done on `day` (refused for an abandoned hive)."""
	var done: bool = store.record_hive_service(hive_ref[apiary], day).ok
	revision += 1 if done else 0
	return done


func collect(apiary: int, day: int, cap_milli: int) -> int:
	"""A collection on `day` (see A COLLECTION): the feed put by first, up to `cap_milli` released, the rest left in the
	hive, the wax shelved (what the shelf cannot hold left in the hive). Returns the honey released, milli-U."""
	var honey: int = store.collect_honey(hive_ref[apiary]).value
	var to_feed: int = mini(honey, maxi(0, Rules.feed_need_milli(day) - feed(apiary)))
	if to_feed > 0 and not store.add_hive_feed(hive_ref[apiary], to_feed).ok:
		push_error("apiary: the hive refused %d milli-U of feed" % to_feed)
		to_feed = 0
	fed_from_hive_milli += to_feed
	var released: int = clampi(honey - to_feed, 0, maxi(0, cap_milli))
	released_milli += released
	_shelve_wax(apiary)
	_set_hive_honey(apiary, honey - to_feed - released)
	revision += 1
	return released


func _shelve_wax(apiary: int) -> void:
	"""The hive's wax onto the shelf, as much as it has room for; the rest stays in the hive."""
	var wax: int = store.collect_wax(hive_ref[apiary]).value
	var shelved: int = mini(wax, maxi(0, Rules.WAX_SHELF_U * Rules.PERMILLE - wax_shelf_milli))
	wax_shelf_milli += shelved
	if wax > shelved:
		_write_state(apiary, honey_in_hive(apiary), wax - shelved)


func add_feed(apiary: int, milli: int) -> bool:
	"""Honey carried from the pantry put by in the hive (a winter feeding)."""
	if milli <= 0 or not store.add_hive_feed(hive_ref[apiary], milli).ok:
		return false
	fed_from_pantry_milli += milli
	revision += 1
	return true


func take_wax(milli: int) -> int:
	"""Take up to `milli` of wax off the shelf (a later candle-maker's); how much was taken."""
	var taken: int = clampi(milli, 0, wax_shelf_milli)
	wax_shelf_milli -= taken
	revision += 1 if taken > 0 else 0
	return taken


# --- recolonising (§5.6) ----------------------------------------------------------------------------------------------------

func recolonize_refusal(apiary: int, day: int) -> String:
	"""Why apiary `apiary` cannot start a recolonisation on `day` ("" when it can): its hive is still alive, one is
	under way, or the 3-day wait would not end in spring."""
	if not is_abandoned(apiary):
		return REFUSE_NOT_ABANDONED
	if recolonize_day[apiary] != 0:
		return REFUSE_UNDER_WAY
	return "" if Rules.recolonize_ends_in_spring(day) else REFUSE_NOT_SPRING


func start_recolonize(apiary: int, day: int) -> bool:
	"""The 60 WU are done on `day` (its honey and wood already paid): the hive is back after the 3-day wait."""
	if not recolonize_refusal(apiary, day).is_empty():
		return false
	recolonize_day[apiary] = day + Rules.RECOLONIZE_WAIT_DAYS
	revision += 1
	return true


# --- the day ------------------------------------------------------------------------------------------------------------------

func close_day(day: int) -> void:
	"""Midnight: day `day` is over (see THE DAY)."""
	news.clear()
	news_warning.clear()
	for apiary: int in Rules.APIARY_COUNT:
		_hive_day(apiary, day)
		if wildlife_strikes(apiary, day):
			_wildlife(apiary)
		if recolonize_day[apiary] != 0 and recolonize_day[apiary] <= day + 1:
			_recolonized(apiary, day + 1)
	revision += 1


func _hive_day(apiary: int, day: int) -> void:
	"""One hive's §5.6 day, booked; a hive just abandoned is news."""
	var was_abandoned: bool = is_abandoned(apiary)
	if not store.apply_hive_day_into(hive_ref[apiary], day, _day):
		return
	honey_made_milli += _day.honey_milli
	wax_made_milli += _day.wax_milli
	eaten_milli += _day.feed_consumed_milli
	var working: bool = Hive.season_of_day(day) != Hive.SEASON_WINTER
	if working and not _day.serviced and not was_abandoned:
		missed_days += 1
	if _day.abandoned and not was_abandoned:
		_say("The bees have left %s: the hive is abandoned (recolonise it in spring)" % Rules.APIARY_NAMES[apiary], true)


func wildlife_strikes(apiary: int, day: int) -> bool:
	"""§5.8's midnight roll for the day just ended, `day`: only when that day was in summer or autumn, a hit when the
	seeded draw (rng.gd `hash_pair(day, WILDLIFE_SEED + apiary)`, 0..9999) falls under the apiary's chance."""
	if not Rules.is_wildlife_season(Hive.season_of_day(day)):
		return false
	return Rng.hash_pair(day, Rules.WILDLIFE_SEED + apiary) % Rules.WILDLIFE_DENOMINATOR < Rules.wildlife_chance(apiary)


func _wildlife(apiary: int) -> void:
	"""A hit: min(2 U, the apiary's honey) is taken, and the advisory said either way (§5.8; nobody is hurt)."""
	var taken: int = mini(Rules.WILDLIFE_TAKE_MILLI, honey_in_hive(apiary))
	wildlife_visits += 1
	_set_hive_honey(apiary, honey_in_hive(apiary) - taken)
	lost_milli += taken
	if taken > 0:
		_say("Something got into %s in the night: %s of honey gone" % [Rules.APIARY_NAMES[apiary], Rules.units(taken)], true)
	else:
		_say("Something got into %s in the night, but found no honey" % Rules.APIARY_NAMES[apiary], true)


func _recolonized(apiary: int, day: int) -> void:
	"""The wait is over on `day`: §5.6's recolonisation (strength 8000, serviced that day)."""
	recolonize_day[apiary] = 0
	if store.recolonize_hive(hive_ref[apiary], day).ok:
		_say("A swarm has settled in %s: the hive is alive again" % Rules.APIARY_NAMES[apiary], false)
	else:
		push_error("apiary: a paid recolonisation was refused on day %d" % day)


func _say(line: String, warning: bool) -> void:
	"""One line of the midnight's news."""
	news.append(line)
	news_warning.append(1 if warning else 0)


func _set_hive_honey(apiary: int, milli: int) -> void:
	"""The hive's uncollected honey set to `milli` (everything else kept)."""
	if milli != honey_in_hive(apiary):
		_write_state(apiary, milli, wax_in_hive(apiary))


func _write_state(apiary: int, honey: int, wax: int) -> void:
	"""Rewrite the hive's honey and wax through the store's validated state writer, every other field as it is."""
	var slot: int = slot_of(apiary)
	if not store.restore_hive_state(hive_ref[apiary], strength(apiary), feed(apiary), honey, wax,
			store.hive_serviced_day_of(slot).value).ok:
		push_error("apiary: the hive refused honey %d and wax %d (the books are wrong)" % [honey, wax])


# --- pollination (REQ-SET-082; ECO-011) ------------------------------------------------------------------------------------

func bed_factor(farm_row: int, tile: Vector2i, crop: int) -> int:
	"""REQ-SET-082's factor for the crop on a field bed (its FarmPlot row and tile): the bed's slice refreshed against the
	hives as they are now -- the join ARCH-SYS-006 leaves to the owner of both -- then read. Neutral for any crop but
	beans, and for a bed the store cannot link."""
	if not store.refresh_farm_links(farm_row, tile.x, tile.y).ok:
		return Hive.POLLINATION_FACTOR_NEUTRAL
	return _read.value if store.farm_pollination_factor_into(farm_row, crop, _read) else Hive.POLLINATION_FACTOR_NEUTRAL


func reaches(apiary: int, lo: Vector2i, hi: Vector2i) -> bool:
	"""Whether apiary `apiary`'s footprint centre is within REQ-SET-082's 12 m of the centre of the tiles `lo`..`hi` (a
	crop tile has lo == hi, an orchard block its 4x4) -- ruling §3's geometry, the readout's "which crops benefit"."""
	var slot: int = slot_of(apiary)
	if not Hive.squared_distance_into(store.hive_center_x_of(slot).value, store.hive_center_z_of(slot).value,
			store.footprint_center_units(lo.x, hi.x).value, store.footprint_center_units(lo.y, hi.y).value, _read):
		return false
	return Hive.is_in_pollination_range(_read.value)


# --- the books -------------------------------------------------------------------------------------------------------------

func honey_accounted_milli() -> int:
	"""Where the honey made is now: in the hives, released, put by from the hive, lost (THE BOOKS' first line)."""
	var held: int = 0
	for apiary: int in Rules.APIARY_COUNT:
		held += honey_in_hive(apiary)
	return held + released_milli + fed_from_hive_milli + lost_milli


func feed_accounted_milli() -> int:
	"""Where the feed put by is now: in the hives, or eaten (THE BOOKS' second line)."""
	var held: int = 0
	for apiary: int in Rules.APIARY_COUNT:
		held += feed(apiary)
	return held + eaten_milli


func wax_accounted_milli() -> int:
	"""Where the wax made is now: in the hives or on the shelf (THE BOOKS' third line)."""
	var held: int = 0
	for apiary: int in Rules.APIARY_COUNT:
		held += wax_in_hive(apiary)
	return held + wax_shelf_milli
