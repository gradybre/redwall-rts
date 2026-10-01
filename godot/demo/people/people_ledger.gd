extends RefCounted
## THE RESIDENTS' MEMORY: committed notable deeds, the player's curation of them, notability, and affinity from shared
## experience. Decision 0491 (review group T: P6, SOC-001, SOC-014, SOC-028). Presentation only: the demo's people,
## never the simulation's (the GDD's ChronicleRecord and Relationship rows are not written).
##
## COMMITTED ONLY. Rows are written by people_taps.gd at the moment an owner has COMMITTED the deed -- a bridge or a
## dug piece open, a victim brought ashore by a rescuer, a harvest in store, a skill level reached, a meal eaten by
## everyone. A cancelled job never reaches that moment, so it leaves no memory. A DEED is one committed happening; an
## EVENT is one participant's row of it (a bridge two residents built is one deed, two events; a rescue is the
## rescuer's KIND_RESCUE and the victim's KIND_RESCUED). Events carry structured fields only -- kind, deed, who, the
## other person, the place (demo_notices.gd TARGET_* and id, for "Go to"), the calendar tick, an amount and the
## subject's name at commit -- and people_text.gd words them when read: presentation prose is not stored.
##
## CURATION (SOC-028). Each deed may be PINNED to the chronicle, kept PRIVATE (it stays in the resident's own history,
## out of the chronicle) or DISMISSED (the player's "not worth keeping": hidden from the resident's history, though the
## fact stays here). At a season's end `reflection_into` offers up to three uncurated deeds of that season.
##
## NOTABLE (SOC-001, REQ-SET-040/042). `pin_notable` marks a resident notable on the player's word. It changes no skill,
## need, labour or consumption -- the demo has no stat it could change.
##
## AFFINITY (SOC-014) uses the GDD's adopted numbers, minimally (§5.3, REQ-SET-035..037, docs/game_gdd.md 353-368).
## REQ-SET-035's +2 is for 60 WU of SOCIAL activity; the demo has no social activity, so it ADAPTS that to the everyday
## contacts it has -- an hour (60 WU) worked side by side on the same crew or dig, or a supper eaten together -- adding
## SOCIAL_GAIN (2), at most once a pair a day; a rescue adds RESCUE_GAIN (8), once per rescue
## (REQ-SET-036); a pair is friends from FRIEND_AT (40) until it falls below FRIEND_CLEAR_BELOW (25) (REQ-SET-037);
## affinity is clamped to -100..100 and, at midnight, a pair without contact for DECAY_AFTER_DAYS (3) moves one point
## toward 0 (§5.3). The GDD's feast gain (FEAST_GAIN, 5: REQ-SET-036) is added for every pair who shared the regatta's
## feast (decision 0438), once per feast. The only thing friendship does in
## the GDD -- mentoring as a SOCIAL alternative -- is not built in the demo, so affinity has NO mechanical effect here;
## the inspector shows it lightly in words. The degree cap of 8 cannot bind a nine-resident cast (eight others each).
## The demo cast starts with no relationship: the GDD's starting edges are for its own twelve, not this community.

const SimClock := preload("res://scripts/core/sim_clock.gd")

const KIND_RESCUE: int = 0
const KIND_RESCUED: int = 1
const KIND_BRIDGE: int = 2
const KIND_TUNNEL: int = 3
const KIND_ROOM: int = 4
const KIND_FIRST_HARVEST: int = 5
const KIND_SKILL: int = 6
const KIND_MEAL: int = 7
## The regatta's race won (decision 0438): its winning crew's deed, pinned to the chronicle when the regatta records it.
const KIND_REGATTA: int = 8
const KIND_COUNT: int = 9
## The order a season's reflection offers deeds in (lower first; -1: never offered -- the rescued side of a rescue,
## whose deed the rescuer's event offers).
const REFLECT_RANK: PackedInt32Array = [0, -1, 1, 1, 1, 2, 4, 3, 1]
## The distinctive deeds a spotlight is offered after (SOC-001: a rescue; a bridge, tunnel or room built).
const SPOTLIGHT_KINDS: PackedInt32Array = [KIND_RESCUE, KIND_BRIDGE, KIND_TUNNEL, KIND_ROOM]
## How many moments a season's reflection offers (SOC-028).
const REFLECTION_SIZE: int = 3

const CURATION_NONE: int = 0
const CURATION_PINNED: int = 1
const CURATION_PRIVATE: int = 2
const CURATION_DISMISSED: int = 3

## The GDD's affinity numbers (see AFFINITY).
const SOCIAL_GAIN: int = 2
const RESCUE_GAIN: int = 8
const FEAST_GAIN: int = 5
const FRIEND_AT: int = 40
const FRIEND_CLEAR_BELOW: int = 25
const AFFINITY_MIN: int = -100
const AFFINITY_MAX: int = 100
const DECAY_AFTER_DAYS: int = 3
## 60 WU -- a game hour -- of calendar ticks worked together.
const SHARED_HOUR_TICKS: int = SimClock.TICKS_PER_HOUR

## Events kept at most (the oldest go first); deeds kept at most (the oldest forgotten with their events' curation).
const MAX_EVENTS: int = 512
const MAX_DEEDS: int = 1024
const NOBODY: int = -1
const NO_TARGET: int = 0

## Bumped on every change a reader shows.
var revision: int = 0

# --- events, oldest first ------------------------------------------------------------------------------
var ev_deed: PackedInt32Array = PackedInt32Array()
var ev_kind: PackedInt32Array = PackedInt32Array()
var ev_who: PackedInt32Array = PackedInt32Array()
var ev_other: PackedInt32Array = PackedInt32Array()
var ev_place_kind: PackedInt32Array = PackedInt32Array()
var ev_place_id: PackedInt32Array = PackedInt32Array()
var ev_amount: PackedInt32Array = PackedInt32Array()
var ev_tick: PackedInt64Array = PackedInt64Array()
var ev_subject: PackedStringArray = PackedStringArray()

# --- deeds, by serial - deed_base ---------------------------------------------------------------------
var deed_kind: PackedInt32Array = PackedInt32Array()
var deed_season: PackedInt32Array = PackedInt32Array()
var deed_tick: PackedInt64Array = PackedInt64Array()
## The resident the deed is told of first (its first participant) -- the chronicle's subject.
var deed_lead: PackedInt32Array = PackedInt32Array()
var deed_curation: PackedByteArray = PackedByteArray()
var deed_base: int = 0

# --- residents -------------------------------------------------------------------------------------
var notable: PackedByteArray = PackedByteArray()
## Per resident: one bit per KIND_* it has ever had an event of -- never forgotten with its events, so a "first" deed
## (a first harvest, a first meal for everyone) stays first however long the session.
var firsts: PackedInt32Array = PackedInt32Array()
## Pair columns, row `a * count + b` with a < b.
var affinity: PackedInt32Array = PackedInt32Array()
var friend: PackedByteArray = PackedByteArray()
var shared_ticks: PackedInt32Array = PackedInt32Array()
var shared_hours: PackedInt32Array = PackedInt32Array()
var suppers: PackedInt32Array = PackedInt32Array()
var last_gain_day: PackedInt32Array = PackedInt32Array()
var last_contact_day: PackedInt32Array = PackedInt32Array()

var _count: int = 0


func setup(residents: int) -> void:
	"""Empty memory for this many residents (by cast index)."""
	_count = maxi(residents, 0)
	for column: PackedInt32Array in [ev_deed, ev_kind, ev_who, ev_other, ev_place_kind, ev_place_id, ev_amount,
			deed_kind, deed_season, deed_lead]:
		column.clear()
	ev_tick.clear()
	ev_subject.clear()
	deed_tick.clear()
	deed_curation.clear()
	deed_base = 0
	notable.resize(_count)
	notable.fill(0)
	firsts.resize(_count)
	firsts.fill(0)
	var pairs: int = _count * _count
	for column: PackedInt32Array in [affinity, shared_ticks, shared_hours, suppers]:
		column.resize(pairs)
		column.fill(0)
	friend.resize(pairs)
	friend.fill(0)
	last_gain_day.resize(pairs)
	last_gain_day.fill(-1)
	last_contact_day.resize(pairs)
	last_contact_day.fill(-1)
	revision += 1


func resident_count() -> int:
	"""How many residents the memory is sized for."""
	return _count


func is_resident(who: int) -> bool:
	"""Whether `who` names a resident."""
	return who >= 0 and who < _count


# --- deeds and events -------------------------------------------------------------------------------

func begin_deed(kind: int, tick: int, season: int, lead: int) -> int:
	"""A committed deed of KIND_* `kind` at calendar `tick` in absolute season `season`, told of `lead` first; its
	serial (-1: refused -- an unknown kind or resident)."""
	if kind < 0 or kind >= KIND_COUNT or not is_resident(lead):
		return -1
	if deed_kind.size() >= MAX_DEEDS:
		_forget_oldest_deed()
	deed_kind.append(kind)
	deed_season.append(season)
	deed_tick.append(tick)
	deed_lead.append(lead)
	deed_curation.append(CURATION_NONE)
	revision += 1
	return deed_base + deed_kind.size() - 1


func add_event(deed: int, kind: int, who: int, other: int, place_kind: int, place_id: int, subject: String,
		amount: int = 0) -> bool:
	"""`who`'s row of deed `deed`: KIND_* `kind` (the deed's own, or KIND_RESCUED for a rescue's victim), with the
	other person (NOBODY), the place to go to (TARGET_*, id), the subject's name and an amount (a skill's level)."""
	var d: int = deed - deed_base
	if d < 0 or d >= deed_kind.size() or not is_resident(who) or kind < 0 or kind >= KIND_COUNT:
		return false
	if ev_deed.size() >= MAX_EVENTS:
		_drop_event(0)
	ev_deed.append(deed)
	ev_kind.append(kind)
	ev_who.append(who)
	ev_other.append(other if is_resident(other) else NOBODY)
	ev_place_kind.append(place_kind)
	ev_place_id.append(place_id)
	ev_amount.append(amount)
	ev_tick.append(deed_tick[d])
	ev_subject.append(subject)
	firsts[who] |= 1 << kind
	revision += 1
	return true


func record(kind: int, who: int, tick: int, season: int, other: int = NOBODY, place_kind: int = NO_TARGET,
		place_id: int = -1, subject: String = "", amount: int = 0) -> int:
	"""A one-participant deed and its event (see begin_deed, add_event); its serial (-1: refused)."""
	var deed: int = begin_deed(kind, tick, season, who)
	if deed >= 0:
		add_event(deed, kind, who, other, place_kind, place_id, subject, amount)
	return deed


func _drop_event(e: int) -> void:
	"""Forget event row `e` (each column by name: no list made per drop)."""
	ev_deed.remove_at(e)
	ev_kind.remove_at(e)
	ev_who.remove_at(e)
	ev_other.remove_at(e)
	ev_place_kind.remove_at(e)
	ev_place_id.remove_at(e)
	ev_amount.remove_at(e)
	ev_tick.remove_at(e)
	ev_subject.remove_at(e)


func _forget_oldest_deed() -> void:
	"""Forget the oldest deed (and any of its events still kept)."""
	var oldest: int = deed_base
	deed_kind.remove_at(0)
	deed_season.remove_at(0)
	deed_lead.remove_at(0)
	deed_tick.remove_at(0)
	deed_curation.remove_at(0)
	deed_base += 1
	for e: int in range(ev_deed.size() - 1, -1, -1):
		if ev_deed[e] == oldest:
			_drop_event(e)


func event_count() -> int:
	"""Events kept."""
	return ev_deed.size()


func has_kind(who: int, kind: int) -> bool:
	"""Whether `who` has ever had an event of KIND_* `kind` (the "first" deeds are recorded once each) -- `firsts`,
	which outlives the events themselves."""
	return is_resident(who) and kind >= 0 and kind < KIND_COUNT and firsts[who] & (1 << kind) != 0


func events_of_into(who: int, out: PackedInt32Array, include_dismissed: bool = false) -> int:
	"""`who`'s event rows, NEWEST first, into `out` -- without those the player dismissed unless asked. Returns how
	many."""
	out.clear()
	for e: int in range(ev_deed.size() - 1, -1, -1):
		if ev_who[e] == who and (include_dismissed or curation_of(ev_deed[e]) != CURATION_DISMISSED):
			out.append(e)
	return out.size()


func is_deed(deed: int) -> bool:
	"""Whether deed `deed` is still remembered."""
	return deed >= deed_base and deed < deed_base + deed_kind.size()


func kind_of(deed: int) -> int:
	"""Deed `deed`'s kind (-1: forgotten)."""
	return deed_kind[deed - deed_base] if is_deed(deed) else -1


func lead_of(deed: int) -> int:
	"""Deed `deed`'s lead resident (NOBODY: forgotten)."""
	return deed_lead[deed - deed_base] if is_deed(deed) else NOBODY


func event_of_deed(deed: int, who: int = NOBODY) -> int:
	"""The event row of deed `deed` -- `who`'s, else its lead's (-1: none kept)."""
	var want: int = who if who != NOBODY else lead_of(deed)
	for e: int in ev_deed.size():
		if ev_deed[e] == deed and ev_who[e] == want:
			return e
	return -1


func curation_of(deed: int) -> int:
	"""How the player curated deed `deed` (CURATION_*; NONE when forgotten)."""
	return deed_curation[deed - deed_base] if is_deed(deed) else CURATION_NONE


func curate(deed: int, curation: int) -> bool:
	"""The player pins deed `deed` to the chronicle, keeps it private or dismisses it (CURATION_*)."""
	if not is_deed(deed) or curation < CURATION_NONE or curation > CURATION_DISMISSED:
		return false
	deed_curation[deed - deed_base] = curation
	revision += 1
	return true


func chronicle_into(out: PackedInt32Array) -> int:
	"""The pinned deeds, oldest first (SOC-028's chronicle). Returns how many."""
	out.clear()
	for d: int in deed_kind.size():
		if deed_curation[d] == CURATION_PINNED:
			out.append(deed_base + d)
	return out.size()


func reflection_into(season: int, out: PackedInt32Array) -> int:
	"""Season `season`'s offer (SOC-028): up to REFLECTION_SIZE uncurated deeds committed in it, best first by
	REFLECT_RANK, then earliest -- only deeds that were committed (nothing else is ever a deed). Returns how many."""
	out.clear()
	for rank: int in range(0, REFLECT_RANK.size()):
		for d: int in deed_kind.size():
			if out.size() >= REFLECTION_SIZE:
				return out.size()
			if deed_season[d] == season and deed_curation[d] == CURATION_NONE and REFLECT_RANK[deed_kind[d]] == rank:
				out.append(deed_base + d)
	return out.size()


static func is_spotlight_kind(kind: int) -> bool:
	"""Whether a deed of `kind` is distinctive enough to offer a spotlight after (SPOTLIGHT_KINDS)."""
	return SPOTLIGHT_KINDS.has(kind)


# --- notability ---------------------------------------------------------------------------------------

func pin_notable(who: int, on: bool = true) -> bool:
	"""The player marks `who` notable (or not). Nothing else changes (see NOTABLE)."""
	if not is_resident(who):
		return false
	notable[who] = 1 if on else 0
	revision += 1
	return true


func is_notable(who: int) -> bool:
	"""Whether the player has pinned `who` as notable."""
	return is_resident(who) and notable[who] == 1


# --- affinity (see AFFINITY) --------------------------------------------------------------------------

func pair(a: int, b: int) -> int:
	"""The pair row of residents `a` and `b` (-1: not two residents)."""
	if a == b or not is_resident(a) or not is_resident(b):
		return -1
	return mini(a, b) * _count + maxi(a, b)


func affinity_of(a: int, b: int) -> int:
	"""The pair's affinity (0 for no pair)."""
	var p: int = pair(a, b)
	return affinity[p] if p >= 0 else 0


func are_friends(a: int, b: int) -> bool:
	"""Whether the pair are friends (REQ-SET-037)."""
	var p: int = pair(a, b)
	return p >= 0 and friend[p] == 1


func _gain(p: int, amount: int, day: int) -> void:
	"""Add `amount` to pair row `p`'s affinity, clamped, with friendship following REQ-SET-037; a contact today."""
	affinity[p] = clampi(affinity[p] + amount, AFFINITY_MIN, AFFINITY_MAX)
	last_contact_day[p] = day
	_settle_friend(p)
	revision += 1


func _settle_friend(p: int) -> void:
	"""REQ-SET-037: friends from FRIEND_AT; no longer once below FRIEND_CLEAR_BELOW."""
	if affinity[p] >= FRIEND_AT:
		friend[p] = 1
	elif affinity[p] < FRIEND_CLEAR_BELOW:
		friend[p] = 0


func everyday_contact(a: int, b: int, day: int) -> bool:
	"""An everyday contact on `day` (an hour worked together, a supper shared): SOCIAL_GAIN, at most once a pair a day
	(REQ-SET-035). True when it counted."""
	var p: int = pair(a, b)
	if p < 0:
		return false
	last_contact_day[p] = maxi(last_contact_day[p], day)
	if last_gain_day[p] == day:
		return false
	last_gain_day[p] = day
	_gain(p, SOCIAL_GAIN, day)
	return true


func add_shared_work(a: int, b: int, ticks: int, day: int) -> bool:
	"""`ticks` calendar ticks worked together on the same crew or job; each whole SHARED_HOUR_TICKS is an hour shared
	and an everyday contact. True when an hour was completed."""
	var p: int = pair(a, b)
	if p < 0 or ticks <= 0:
		return false
	shared_ticks[p] += ticks
	var hour: bool = false
	while shared_ticks[p] >= SHARED_HOUR_TICKS:
		shared_ticks[p] -= SHARED_HOUR_TICKS
		shared_hours[p] += 1
		hour = true
		everyday_contact(a, b, day)
	return hour


func add_supper(a: int, b: int, day: int) -> bool:
	"""A supper eaten together on `day`: counted, and an everyday contact."""
	var p: int = pair(a, b)
	if p < 0:
		return false
	suppers[p] += 1
	everyday_contact(a, b, day)
	return true


func add_rescue(rescuer: int, victim: int, day: int) -> bool:
	"""A rescue completed: RESCUE_GAIN, once per rescue (REQ-SET-036)."""
	var p: int = pair(rescuer, victim)
	if p < 0:
		return false
	_gain(p, RESCUE_GAIN, day)
	return true


func add_feast(a: int, b: int, day: int) -> bool:
	"""A feast shared (REQ-SET-036): FEAST_GAIN, once per feast (the caller's), and an everyday contact."""
	var p: int = pair(a, b)
	if p < 0:
		return false
	_gain(p, FEAST_GAIN, day)
	return true


func midnight(day: int) -> void:
	"""Day `day` begins: a pair with affinity and no contact for DECAY_AFTER_DAYS moves one point toward 0 (§5.3)."""
	for p: int in affinity.size():
		if affinity[p] == 0 or day - last_contact_day[p] < DECAY_AFTER_DAYS:
			continue
		affinity[p] -= signi(affinity[p])
		_settle_friend(p)
		revision += 1
