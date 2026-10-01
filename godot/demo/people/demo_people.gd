extends Node
## THE VILLAGE'S PEOPLE: residents as recognisable contributors with memories grounded in play. Decision 0491 (review
## group T: P6, SOC-001, SOC-014, SOC-028; Brendan's rulings of 2026-10-01). Presentation only: it reads the village's
## owners and writes its own ledger, the notice feed's chronicle notes and evening lines -- never the simulation.
##
##   names       the cast's own names and interests, from demo_people.json (people_book.gd), through every surface's
##               `display_name` (demo_actor.gd); trades stay roles ("Wenna Tallowby — mouse, keeper").
##   memory      people_taps.gd records each COMMITTED deed into people_ledger.gd; `poll` runs it once a frame on the
##               cast's clock (paused, nothing moves, nothing is recorded).
##   inspector   `inspector_info(who)` is the one-resident inspector's person: identity and role, the current work and
##               why, the skills with their progress, the relationships, and the notable moments with their places
##               and people to go to -- demo_command.gd `set_person_info` hands it to the party panel.
##   spotlight   after a distinctive deed (a rescue, a bridge, tunnel or room built) by a resident not yet notable,
##   (SOC-001)   ONE offer per resident and deed kind: pin the resident as notable (no stat changes), or not now.
##   reflection  at a season's end, up to three of that season's committed deeds (`reflection_deeds`): each pinned
##   (SOC-028)   to the chronicle (posted to the village news' history), kept private, or dismissed.
##   lines       at most ONE light evening line a day (EVENING_HOUR, the GDD's social hours after supper): the next
##               resident in turn who is actually free on the surface then, doing its own pastime where it actually
##               is -- with its pleased line only after a deed of its own committed that day. Never a bark or warning.

const Ledger := preload("res://demo/people/people_ledger.gd")
const TapsScript := preload("res://demo/people/people_taps.gd")
const PeopleBook := preload("res://demo/people/people_book.gd")
const Words := preload("res://demo/people/people_text.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const BoardScript := preload("res://demo/work/work_board.gd")

## The evening line's hour: supper is over (meal_rules.gd: 17:00-18:59) and dusk (20:00) not yet come.
const EVENING_HOUR: int = 19
const DUSK_HOUR: int = 20
## Spotlight offers waiting at most (the oldest go).
const MAX_OFFERS: int = 4
## The inspector's notable moments shown at most, newest first.
const MAX_MOMENTS: int = 8
const WHY_COOK: String = "Why: the village cook"
const WHY_STAND_IN: String = "Why: standing in as cook"
const WHY_DRAW: String = "Why: keeping the kitchen's water drawn"
const WHY_MEAL: String = "Why: mealtime"
const WHY_NIGHT: String = "Why: night — the village sleeps"
const WHY_HELD: String = "Why: in difficulty in the water — the rescue comes first"
## Held on the water but not in it: aboard a boat (a ferry passenger or crew, a race crew, a fishing or rescue boat).
const WHY_ABOARD: String = "Why: aboard a boat — it lands before it takes an order"
const WHY_URGENT: String = "Why: an emergency comes first (a rescue, a shelter)"
const WHY_OWN: String = "Why: the %s crew's own work (%s)"
const WHY_HELP: String = "Why: %s work — the %s crew lends a hand where needed"
const WHY_ORDER: String = "Why: your order"
const WHY_FREE: String = "Why: free — no task taken yet"
const ROLE_LINE: String = "%s, %s"

## Bumped when an offer, the reflection or an evening line changes (the card and the inspector redraw).
var revision: int = 0
var ledger: Ledger = Ledger.new()
var taps: TapsScript = TapsScript.new()
## The spotlight offers waiting: the resident, and the deed it is offered after.
var offer_who: PackedInt32Array = PackedInt32Array()
var offer_deed: PackedInt32Array = PackedInt32Array()
## The season's reflection on offer (empty: none) and the season it reflects on.
var reflection_deeds: PackedInt32Array = PackedInt32Array()
var reflection_season: int = -1
## Each resident's evening line while it is true (""), and how many evening lines have been posted.
var evening_lines: PackedStringArray = PackedStringArray()
var lines_posted: int = 0
## The work board: why a resident is at what it does (its tasks and crews; null: no board).
var board: BoardScript = null

var _cast: DemoCastScript = null
var _notices: NoticesScript = null
var _calendar: CalendarScript = null
var _kitchen: KitchenScript = null
var _names: PackedStringArray = PackedStringArray()
## Per resident and deed kind: 1 once a spotlight was offered (it is offered once).
var _offered: PackedByteArray = PackedByteArray()
var _season: int = 0
var _hour_seen: int = -1
var _evening_turn: int = 0
var _scratch: PackedInt32Array = PackedInt32Array()


func configure(cast: DemoCastScript, notices: NoticesScript, calendar: CalendarScript) -> void:
	"""The people of this cast, posting to these notices on this calendar; the owners are bound into `taps` after
	(its fields), then `watch()` takes the baseline."""
	name = "DemoPeople"
	_cast = cast
	_notices = notices
	_calendar = calendar
	var n: int = cast.actor_count()
	ledger.setup(n)
	taps.ledger = ledger
	taps.cast = cast
	taps.calendar = calendar
	_names.resize(n)
	for who: int in n:
		_names[who] = (cast.actor(who) as DemoActorScript).display_name
	evening_lines.resize(n)
	_offered.resize(n * Ledger.KIND_COUNT)
	_offered.fill(0)


func bind_kitchen(kitchen: KitchenScript) -> void:
	"""The kitchen: its meals are watched (taps) and its roles say why a resident is at it."""
	_kitchen = kitchen
	taps.kitchen = kitchen


func watch() -> void:
	"""Take the village as it stands as the baseline (nothing already so is a deed)."""
	taps.watch()
	_season = taps.season_index()
	_hour_seen = _calendar.hour_index() if _calendar != null else -1


func names() -> PackedStringArray:
	"""Every resident's name, by cast index."""
	return _names


func _process(_delta: float) -> void:
	"""One frame: the taps, the spotlight, the season's end and the evening."""
	poll()


func poll() -> void:
	"""Record what was committed since the last frame and offer what follows from it."""
	if taps.poll() > 0:
		_offer_spotlights()
	if _calendar == null:
		return
	var season: int = taps.season_index()
	if season != _season:
		_reflect(_season)
		_season = season
	var hour: int = _calendar.hour_index()
	if hour != _hour_seen:
		_hour_seen = hour
		_on_hour(posmod(hour, SimClock.HOURS_PER_DAY))


# --- the spotlight (SOC-001) ------------------------------------------------------------------------------

func _offer_spotlights() -> void:
	"""Each new distinctive deed: one offer per participant not yet notable and not yet offered for its kind."""
	for deed: int in taps.new_deeds:
		var kind: int = ledger.kind_of(deed)
		if not Ledger.is_spotlight_kind(kind):
			continue
		for e: int in ledger.event_count():
			if ledger.ev_deed[e] == deed and ledger.ev_kind[e] == kind:
				_offer(ledger.ev_who[e], deed, kind)


func _offer(who: int, deed: int, kind: int) -> void:
	"""Offer `who` a spotlight after `deed` -- once per resident and kind, never to one already notable."""
	var k: int = who * Ledger.KIND_COUNT + kind
	if ledger.is_notable(who) or _offered[k] == 1:
		return
	_offered[k] = 1
	if offer_who.size() >= MAX_OFFERS:
		offer_who.remove_at(0)
		offer_deed.remove_at(0)
	offer_who.append(who)
	offer_deed.append(deed)
	revision += 1


func has_offer() -> bool:
	"""Whether a spotlight offer waits."""
	return not offer_who.is_empty()


func offer_text() -> String:
	"""The front offer's words ("" with none)."""
	if offer_who.is_empty():
		return ""
	var who: int = offer_who[0]
	return Words.spotlight_text(deed_words(offer_deed[0], who), _names[who])


func accept_offer() -> bool:
	"""The player pins the front offer's resident as notable (REQ-SET-042; nothing else changes)."""
	if offer_who.is_empty():
		return false
	var who: int = offer_who[0]
	_drop_offer()
	return pin_notable(who, true)


func decline_offer() -> bool:
	"""Not now: the front offer goes (it is not asked again for that kind)."""
	if offer_who.is_empty():
		return false
	_drop_offer()
	return true


func _drop_offer() -> void:
	"""The front offer goes."""
	offer_who.remove_at(0)
	offer_deed.remove_at(0)
	revision += 1


func pin_notable(who: int, on: bool) -> bool:
	"""The player pins `who` as notable (or unpins it), from the inspector or an offer; its own offers go then."""
	if not ledger.pin_notable(who, on):
		return false
	for k: int in range(offer_who.size() - 1, -1, -1):
		if on and offer_who[k] == who:
			offer_who.remove_at(k)
			offer_deed.remove_at(k)
	revision += 1
	return true


func record_regatta(winners: PackedInt32Array, subject: String) -> int:
	"""The regatta's race won (decision 0438, through the ledger's own hooks): one KIND_REGATTA deed, each winner's
	event naming the other, PINNED to the chronicle and posted as every pinned deed is. Its serial (-1: none)."""
	if winners.is_empty() or _calendar == null:
		return -1
	var deed: int = ledger.begin_deed(Ledger.KIND_REGATTA, _calendar.tick, taps.season_index(), winners[0])
	if deed < 0:
		return -1
	for k: int in winners.size():
		var other: int = winners[1 - k] if winners.size() == 2 else Ledger.NOBODY
		ledger.add_event(deed, Ledger.KIND_REGATTA, winners[k], other, NoticesScript.TARGET_RESIDENT, winners[k], subject)
	ledger.curate(deed, Ledger.CURATION_PINNED)
	_post_chronicle(deed)
	revision += 1
	return deed


func share_feast(attendees: PackedInt32Array) -> void:
	"""REQ-SET-036: every pair who shared the feast gains FEAST_GAIN, once for this feast."""
	var day: int = _calendar.now().absolute_day if _calendar != null else 0
	for a: int in attendees.size():
		for b: int in range(a + 1, attendees.size()):
			ledger.add_feast(attendees[a], attendees[b], day)
	revision += 1


func is_notable(who: int) -> bool:
	"""Whether the player pinned `who` as notable."""
	return ledger.is_notable(who)


# --- the season's reflection (SOC-028) -----------------------------------------------------------------------

func _reflect(season: int) -> void:
	"""Season `season` is over: offer its best uncurated committed deeds (none: no reflection)."""
	if ledger.reflection_into(season, _scratch) == 0:
		return
	reflection_deeds = _scratch.duplicate()
	reflection_season = season
	revision += 1


func has_reflection() -> bool:
	"""Whether a season's reflection waits."""
	return not reflection_deeds.is_empty()


func reflection_title() -> String:
	"""'Spring's end: moments to remember'."""
	return Words.reflection_title(CalendarScript.SEASON_TITLES[posmod(reflection_season, 4)])


func reflection_line(k: int) -> String:
	"""Reflection moment `k` in words, told of its lead ("" out of range)."""
	if k < 0 or k >= reflection_deeds.size():
		return ""
	return deed_words(reflection_deeds[k], ledger.lead_of(reflection_deeds[k]))


func curate_reflection(k: int, curation: int) -> bool:
	"""The player's answer to moment `k`: PINNED to the chronicle (posted to the news history), PRIVATE or DISMISSED.
	The moment leaves the reflection; with none left, the reflection is over."""
	if k < 0 or k >= reflection_deeds.size() or curation == Ledger.CURATION_NONE:
		return false
	var deed: int = reflection_deeds[k]
	if not ledger.curate(deed, curation):
		return false
	if curation == Ledger.CURATION_PINNED:
		_post_chronicle(deed)
	reflection_deeds.remove_at(k)
	revision += 1
	return true


func close_reflection() -> void:
	"""Later: the moments not answered stay uncurated, in each resident's own history."""
	reflection_deeds.clear()
	revision += 1


func _post_chronicle(deed: int) -> void:
	"""A pinned deed's line in the village news (its history keeps it), about its lead."""
	if _notices == null:
		return
	var lead: int = ledger.lead_of(deed)
	var e: int = ledger.event_of_deed(deed)
	_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, Words.chronicle_line(deed_words(deed, lead),
		day_of(ledger.ev_tick[e] if e >= 0 else -1)), "Chronicle", NoticesScript.TARGET_RESIDENT, lead)


func day_of(tick: int) -> String:
	"""A calendar tick's day as the demo prints it ("Spring 4"; "" unknown)."""
	if tick < 0 or _calendar == null:
		return ""
	var at: SimClock.Calendar = _calendar.calendar_at(tick)
	return CalendarScript.day_text(at.season, at.season_day)


# --- words --------------------------------------------------------------------------------------------

func deed_words(deed: int, who: int) -> String:
	"""Deed `deed` told of `who`: "Corra Netley brought Tobit Highbough ashore" ("" when forgotten)."""
	var e: int = ledger.event_of_deed(deed, who)
	if e < 0:
		return ""
	return Words.deed_text(ledger.ev_kind[e], _name(who), ledger.ev_subject[e], _name(ledger.ev_other[e]),
		ledger.ev_amount[e])


func event_words(e: int) -> String:
	"""Event row `e` as its resident's own history reads it."""
	return Words.event_text(ledger.ev_kind[e], ledger.ev_subject[e], _name(ledger.ev_other[e]), ledger.ev_amount[e])


func _name(who: int) -> String:
	"""Resident `who`'s name ("" out of range)."""
	return _names[who] if who >= 0 and who < _names.size() else ""


func voice(who: int, saying: int) -> String:
	"""Resident `who` says the dig's saying SAY_* `saying` under its own name, with its own light dialect if it has
	any (tunnel_works.gd `voice`; DEC-017)."""
	var key: StringName = (_cast.actor(who) as DemoActorScript).creature_key if who >= 0 and who < _names.size() else &""
	var tags: PackedStringArray = PeopleBook.dialect_of(key)
	return CrewScript.spoken(saying, _name(who), tags[posmod(saying, tags.size())] if not tags.is_empty() else "")


# --- the evening's line -------------------------------------------------------------------------------------

func _on_hour(hour: int) -> void:
	"""EVENING_HOUR: one resident's line (see the header); dusk: the evening's lines are over."""
	if hour == EVENING_HOUR:
		_evening()
	elif hour == DUSK_HOUR or hour == 0:
		for who: int in evening_lines.size():
			evening_lines[who] = ""
		revision += 1


func _evening() -> void:
	"""The next resident in turn who is free on the surface now says its line (none free: no line tonight)."""
	var n: int = _names.size()
	for step: int in n:
		var who: int = posmod(_evening_turn + step, n)
		var line: String = evening_line_of(who)
		if line.is_empty():
			continue
		_evening_turn = who + 1
		evening_lines[who] = line
		lines_posted += 1
		revision += 1
		if _notices != null:
			_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, line, "", NoticesScript.TARGET_RESIDENT, who)
		return


func evening_line_of(who: int) -> String:
	"""Resident `who`'s evening line now, if it is free on the surface ("" otherwise, or with no person)."""
	var actor := _cast.actor(who) as DemoActorScript
	var brain: BrainScript = actor.brain
	if not is_free(brain):
		return ""
	var place: String = String(_cast.space().poi_names[brain.poi]).replace("_", " ") if brain.poi >= 0 else ""
	return Words.evening_line(actor.creature_key, actor.display_name, place, deed_today(who), lines_posted)


static func is_free(brain: BrainScript) -> bool:
	"""Whether a resident is on its own time on the surface: wandering (which no order allows), no task, not below, in
	the water, held, asleep or indoors."""
	return brain.activity() == BrainScript.ACTIVITY_WANDERING \
		and brain.task == null and not brain.underground and not brain.in_water and not brain.water_hold \
		and not brain.resting and not brain.lying and not brain.indoors


func deed_today(who: int) -> bool:
	"""Whether a deed of `who`'s own (not one done to it) was committed today."""
	if _calendar == null:
		return false
	var today: int = _calendar.now().absolute_day
	for e: int in range(ledger.event_count() - 1, -1, -1):
		if ledger.ev_who[e] == who and ledger.ev_kind[e] != Ledger.KIND_RESCUED \
				and _calendar.calendar_at(ledger.ev_tick[e]).absolute_day == today:
			return true
	return false


# --- the inspector's person (P6) ------------------------------------------------------------------------------


func inspector_info(who: int) -> Dictionary:
	"""Resident `who`'s person for the one-resident inspector (demo_party_panel.gd's person section): its first name,
	role line, why it does what it does, its skills (name, level, progress per mille, at the top), and -- shown only
	when the player opens "About" -- its interest, its evening line, relationships and notable moments."""
	var actor := _cast.actor(who) as DemoActorScript
	var key: StringName = actor.creature_key
	var info: Dictionary = {"who": who, "first": PeopleBook.first_name_of(key), "notable": ledger.is_notable(who),
		"role": ROLE_LINE % [actor.species, actor.role()] if not actor.role().is_empty() else actor.species,
		"why": why_of(who), "skills": skill_rows(who), "relations": Words.relation_lines(ledger, who, _names),
		"evening": evening_lines[who] if who < evening_lines.size() else "", "moments": moments_of(who)}
	var interest: String = PeopleBook.interest_of(key)
	info["interest"] = Words.INTEREST % interest if not interest.is_empty() else ""
	return info


func stamp_of(who: int) -> int:
	"""A number that changes whenever `who`'s inspector would (the party panel redraws only then)."""
	var stamp: int = ledger.revision * 31 + revision
	for s: int in taps.skill_count():
		stamp = stamp * 7 + taps.skill_xp(s, who)
	return stamp * 3 + (1 if ledger.is_notable(who) else 0)


func skill_rows(who: int) -> Array[Dictionary]:
	"""Every watched skill: {"name", "level", "permille" (toward the next level), "top" (at the curve's top)}."""
	var rows: Array[Dictionary] = []
	for s: int in taps.skill_count():
		var xp: int = taps.skill_xp(s, who)
		var level: int = ForestRules.level_of(xp)
		var top: bool = level >= ForestRules.SKILL_LEVEL_MAX
		var from: int = ForestRules.xp_of_level(level)
		var span: int = maxi(ForestRules.xp_of_level(level + 1) - from, 1) if not top else 1
		rows.append({"name": taps.skill_name(s), "level": level, "top": top,
			"permille": 1000 if top else clampi((xp - from) * 1000 / span, 0, 1000)})
	return rows


func moments_of(who: int) -> Array[Dictionary]:
	"""`who`'s notable moments, newest first (MAX_MOMENTS; none the player dismissed): the words, the day, the place
	and the other person to go to, and whether it is in the chronicle."""
	var out: Array[Dictionary] = []
	ledger.events_of_into(who, _scratch)
	for e: int in _scratch:
		if out.size() >= MAX_MOMENTS:
			break
		var other: int = ledger.ev_other[e]
		out.append({"text": event_words(e), "day": day_of(ledger.ev_tick[e]), "place_kind": ledger.ev_place_kind[e],
			"place_id": ledger.ev_place_id[e], "other": other, "other_name": _name(other),
			"chronicled": ledger.curation_of(ledger.ev_deed[e]) == Ledger.CURATION_PINNED})
	return out


func why_of(who: int) -> String:
	"""Why `who` is at what it is doing, from the owner that has it: the kitchen, the night, the water, the work board
	(its crew's own work, or a hand lent), the player's order -- or free."""
	var brain: BrainScript = (_cast.actor(who) as DemoActorScript).brain
	if brain.water_hold:
		return WHY_HELD if brain.in_water else WHY_ABOARD
	if brain.task != null and brain.task.urgent():
		return WHY_URGENT
	var kitchen: String = _kitchen_why(who)
	if not kitchen.is_empty():
		return kitchen
	if brain.resting or brain.lying:
		return WHY_NIGHT
	var work: String = _board_why(who)
	if not work.is_empty():
		return work
	return WHY_ORDER if brain.order != BrainScript.ORDER_NONE else WHY_FREE


func _kitchen_why(who: int) -> String:
	"""The kitchen's part `who` has ("" none)."""
	if _kitchen == null:
		return ""
	match _kitchen.role_of(who):
		KitchenScript.ROLE_COOK:
			return WHY_COOK if who == _kitchen.designated else WHY_STAND_IN
		KitchenScript.ROLE_DRAW:
			return WHY_DRAW
		KitchenScript.ROLE_EAT:
			return WHY_MEAL
	return ""


func _board_why(who: int) -> String:
	"""The work board's task `who` holds, as its crew's own work or a hand lent ("" none)."""
	if board == null:
		return ""
	var crews: CrewsScript = board.crews
	for id: int in WorkIds.SOURCE_COUNT:
		var src: SourceScript = board.source(id)
		if src == null or id == WorkIds.SOURCE_KITCHEN:
			continue
		for row: int in src.capacity():
			if src.live(row) and src.worker(row) == who:
				var crew: int = crews.crew_of[who]
				var activity: int = src.activity(row)
				var what: String = WorkIds.ACT_NAMES[activity]
				if activity == CrewsScript.PREFERRED[crew]:
					return WHY_OWN % [CrewsScript.CREW_NAMES[crew], what]
				return WHY_HELP % [what, CrewsScript.CREW_NAMES[crew]]
	return ""
