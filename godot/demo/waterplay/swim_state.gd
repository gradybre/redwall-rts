extends RefCounted
## Every resident's standing in the water, as packed integer columns by actor index. Decision 0196
## (live demo). The authoritative part is integer and advances only on fixed ticks of the demo clock:
## air (HAZ-002) and stamina (the resident's rest, HAZ-001/003), so nothing is spent while paused
## (MOVE-REQ-010) and 2x / 4x spend two and four times as fast.
##
## CAPABILITY (MOVE-REQ-005: "Individual eligibility" is per resident): each row records whether this
## resident swims, at what speed, whether it dives and whether it CONSENTS to routine swimming
## (HAZ-001). Rows are seeded from the demo's species table (swim_rules.gd) and can be changed per
## resident; nothing reads the species again.
##
## MODE is what the water is doing to the resident this tick, set by whoever moves it (the crossing
## legs, the dive, the rescue): on LAND (or on a deck), WADING, SWIMMING, TREADING, DIVING
## (submerged), IN DIFFICULTY at the surface, IN DIFFICULTY underwater, TOWED or RESTING after a
## rescue. Each tick applies the mode's rule:
##   * air: submerged modes spend 1 a tick; everything else breathes back 4 (cap 1200). HAZ-002.
##   * rest: swimming, treading and diving spend `drain` (swim_rules.gd: cold and flow); land and
##     wading give it back; resting gives it back three times as fast; a resident in difficulty or
##     towed is floating in its hold pose and neither spends nor gains.
## EVENTS a tick raises are latched as bits (`take_events`), read once by the water's owner:
##   TIRED at rest <= 1500 in the water (HAZ-003's return request), once until rest is back at 4000;
##   EXHAUSTED at rest 0 in the water (HAZ-003: self-propelled swimming stops -- in difficulty);
##   LOW_AIR at air <= 450 submerged (HAZ-002's advisory); AIR_OUT at air 0 submerged. Both are
##   THRESHOLD ENTRIES (review F38, decision 0231): each is raised once as air crosses its line, latched
##   in `air_latch`, and re-armed only by a fresh dive (going down from the surface) or at the surface
##   with air back at AIR_LOW_REARM (600) -- so a dive raises each at most once, the next dive can raise
##   them again, and the air itself is a meter the panels read in place, never a stream of notices.

const Rules := preload("res://demo/waterplay/swim_rules.gd")

const MODE_LAND: int = 0
const MODE_WADE: int = 1
const MODE_SWIM: int = 2
const MODE_TREAD: int = 3
const MODE_DIVE: int = 4
const MODE_DISTRESS: int = 5
const MODE_DISTRESS_UNDER: int = 6
const MODE_TOWED: int = 7
const MODE_RESTING: int = 8
const MODE_WORDS: Array[String] = ["on land", "wading", "swimming", "treading water", "diving",
	"in difficulty", "in difficulty underwater", "being towed ashore", "resting"]

const EVENT_TIRED: int = 1
const EVENT_EXHAUSTED: int = 2
const EVENT_LOW_AIR: int = 4
const EVENT_AIR_OUT: int = 8
## `air_latch` bits: the low-air advisory and the air-out event already raised this time below.
const LATCH_LOW_AIR: int = 1
const LATCH_AIR_OUT: int = 2

var count: int = 0
var swim_mm_s: PackedInt32Array = PackedInt32Array()
## The speed each swimmer's stroke clip reads right at rate 1.0 (swim_rules.gd STROKE_MM_S).
var stroke_mm_s: PackedInt32Array = PackedInt32Array()
var dives: PackedByteArray = PackedByteArray()
var consent: PackedByteArray = PackedByteArray()
var height_u: PackedInt32Array = PackedInt32Array()
var mode: PackedByteArray = PackedByteArray()
var air: PackedInt32Array = PackedInt32Array()
var rest: PackedInt32Array = PackedInt32Array()
## The stamina a swimming tick costs each resident now (set by the owner from cold and flow).
var drain: PackedInt32Array = PackedInt32Array()
var events: PackedInt32Array = PackedInt32Array()
## HAZ-003's latches: tired and exhausted episodes, re-armed at rest 4000 on land.
var tired_latch: PackedByteArray = PackedByteArray()
var exhausted_latch: PackedByteArray = PackedByteArray()
## HAZ-002's latches (LATCH_* bits), re-armed at AIR_LOW_REARM at the surface.
var air_latch: PackedByteArray = PackedByteArray()
## Bumped whenever something a panel shows changes (a mode, a latch, a capability).
var revision: int = 0

var _carry: PackedInt64Array = PackedInt64Array([0])


func setup(species: PackedStringArray, heights_u: PackedInt32Array) -> void:
	"""One row per resident by actor index, seeded from each one's species (swim_rules.gd)."""
	count = species.size()
	swim_mm_s.resize(count)
	stroke_mm_s.resize(count)
	height_u.resize(count)
	air.resize(count)
	rest.resize(count)
	drain.resize(count)
	events.resize(count)
	dives.resize(count)
	consent.resize(count)
	mode.resize(count)
	tired_latch.resize(count)
	exhausted_latch.resize(count)
	air_latch.resize(count)
	for who: int in count:
		_seed(who, species[who], heights_u[who])
	revision += 1


func _seed(who: int, kind: String, h_u: int) -> void:
	"""A fresh row: the species' capability, full air and rest, on land, consenting."""
	swim_mm_s[who] = Rules.swim_mm_s_of(kind)
	stroke_mm_s[who] = Rules.stroke_mm_s_of(kind)
	dives[who] = 1 if Rules.dives_of(kind) else 0
	consent[who] = 1
	height_u[who] = h_u
	mode[who] = MODE_LAND
	air[who] = Rules.AIR_FULL
	rest[who] = Rules.REST_MAX
	drain[who] = Rules.REST_SWIM_PER_TICK
	events[who] = 0
	tired_latch[who] = 0
	exhausted_latch[who] = 0
	air_latch[who] = 0


func has(who: int) -> bool:
	"""Whether `who` has a row."""
	return who >= 0 and who < count


func can_swim(who: int) -> bool:
	"""Whether this resident swims at all."""
	return has(who) and swim_mm_s[who] > 0


func can_dive(who: int) -> bool:
	"""Whether this resident dives."""
	return has(who) and swim_mm_s[who] > 0 and dives[who] == 1


func in_water(who: int) -> bool:
	"""Whether this resident is in the water now (any mode but land and resting)."""
	return has(who) and mode[who] != MODE_LAND and mode[who] != MODE_RESTING and mode[who] != MODE_WADE


func in_difficulty(who: int) -> bool:
	"""Whether this resident is in difficulty (at the surface or underwater) or being towed."""
	return has(who) and (mode[who] == MODE_DISTRESS or mode[who] == MODE_DISTRESS_UNDER or mode[who] == MODE_TOWED)


func set_mode(who: int, value: int) -> void:
	"""What the water is doing to `who` from this tick on. Going down from the surface is a fresh dive:
	HAZ-002's latches re-arm (see EVENTS)."""
	if mode[who] == value:
		return
	if value == MODE_DIVE and mode[who] != MODE_DISTRESS_UNDER:
		air_latch[who] = 0
	mode[who] = value
	revision += 1


func set_consent(who: int, on: bool) -> void:
	"""Whether `who` takes swims of its own accord (HAZ-001's consent)."""
	consent[who] = 1 if on else 0
	revision += 1


func advance_usec(usec: int) -> int:
	"""Advance every row by the whole ticks in `usec` demo microseconds (the remainder is kept);
	returns how many ticks ran."""
	var ticks: int = Rules.ticks_for_usec(maxi(usec, 0), _carry)
	for tick: int in ticks:
		for who: int in count:
			_tick(who)
	return ticks


func _tick(who: int) -> void:
	"""One fixed tick of one row (see the header)."""
	var m: int = mode[who]
	var submerged: bool = m == MODE_DIVE or m == MODE_DISTRESS_UNDER
	if submerged:
		air[who] = maxi(air[who] - Rules.AIR_PER_SUBMERGED_TICK, 0)
		_air_events(who)
	else:
		air[who] = mini(air[who] + Rules.AIR_RECOVERY_PER_TICK, Rules.AIR_FULL)
		if air[who] >= Rules.AIR_LOW_REARM and air_latch[who] != 0:
			air_latch[who] = 0
			revision += 1
	if m == MODE_SWIM or m == MODE_TREAD or m == MODE_DIVE:
		_spend(who)
	elif m == MODE_LAND or m == MODE_WADE or m == MODE_RESTING:
		_recover(who, Rules.REST_RESTING_FACTOR if m == MODE_RESTING else 1)


func _air_events(who: int) -> void:
	"""HAZ-002's advisory and air-out, each raised once as air crosses its line (see EVENTS)."""
	if air[who] <= Rules.AIR_LOW_ADVISORY and (air_latch[who] & LATCH_LOW_AIR) == 0:
		air_latch[who] |= LATCH_LOW_AIR
		events[who] |= EVENT_LOW_AIR
		revision += 1
	if air[who] == 0 and (air_latch[who] & LATCH_AIR_OUT) == 0:
		air_latch[who] |= LATCH_AIR_OUT
		events[who] |= EVENT_AIR_OUT
		revision += 1


func _spend(who: int) -> void:
	"""A swimming tick's stamina, and HAZ-003's tired and exhausted latches."""
	rest[who] = maxi(rest[who] - drain[who], 0)
	if rest[who] <= Rules.REST_RETURN and tired_latch[who] == 0:
		tired_latch[who] = 1
		events[who] |= EVENT_TIRED
		revision += 1
	if rest[who] == 0 and exhausted_latch[who] == 0:
		exhausted_latch[who] = 1
		events[who] |= EVENT_EXHAUSTED
		revision += 1


func _recover(who: int, factor: int) -> void:
	"""Stamina back on safe support; the latches re-arm at REST_REARM."""
	rest[who] = mini(rest[who] + Rules.REST_LAND_PER_TICK * factor, Rules.REST_MAX)
	if rest[who] >= Rules.REST_REARM and (tired_latch[who] == 1 or exhausted_latch[who] == 1):
		tired_latch[who] = 0
		exhausted_latch[who] = 0
		revision += 1


func take_events(who: int) -> int:
	"""This row's latched events (EVENT_* bits), cleared as they are read."""
	var bits: int = events[who]
	events[who] = 0
	return bits


func swim_refusal(who: int, loaded: bool) -> StringName:
	"""Why `who` may not start a routine swim now (Rules.REFUSE_NONE: it may): capability, a load,
	consent, rest (HAZ-001), or already in difficulty."""
	if not can_swim(who):
		return Rules.REFUSE_CANNOT_SWIM
	if loaded:
		return Rules.REFUSE_LOADED
	if consent[who] == 0:
		return Rules.REFUSE_NO_CONSENT
	if not Rules.admits_swim(rest[who]) or in_difficulty(who):
		return Rules.REFUSE_TIRED
	return Rules.REFUSE_NONE


func rest_percent(who: int) -> int:
	"""Stamina as a whole percentage (floored)."""
	@warning_ignore("integer_division") return rest[who] * 100 / Rules.REST_MAX


func meter_text(who: int) -> String:
	"""The party panel's meters: "breath 1200/1200 · stamina 100%"."""
	return "breath %d/%d · stamina %d%%" % [air[who], Rules.AIR_FULL, rest_percent(who)]
