extends RefCounted
## The people's words (decision 0491): the ledger's committed deeds, relationships, the spotlight and the season's
## reflection, and the light evening lines -- read from structured rows when shown, never stored as prose
## (people_ledger.gd). Plain throughout: functional text never carries dialect (DEC-017); only a person's own quoted
## line does, through people_book.gd `spoken`.

const Ledger := preload("res://demo/people/people_ledger.gd")
const PeopleBook := preload("res://demo/people/people_book.gd")

## What each deed kind says, as the resident's own history reads it (the subject or the other person in it).
const EVENT_WORDS: Array[String] = [
	"Brought %s ashore",          # KIND_RESCUE: the one rescued
	"Brought ashore by %s",       # KIND_RESCUED: the rescuer
	"Built the %s",               # KIND_BRIDGE: the bridge's name
	"Dug %s",                     # KIND_TUNNEL: "tunnel 3"
	"Dug %s",                     # KIND_ROOM: "Burrow home 1"
	"First harvest: %s",          # KIND_FIRST_HARVEST: "carrot from the carrot bed"
	"Reached %s",                 # KIND_SKILL: "Felling · Level 4"
	"Cooked %s for everyone",     # KIND_MEAL: "supper, day 3"
]
## The same deeds told of the resident, for the chronicle and the spotlight ("Corra Netley brought ... ashore").
const DEED_WORDS: Array[String] = [
	"%s brought %s ashore",
	"%s was brought ashore by %s",
	"%s built the %s",
	"%s dug %s",
	"%s dug %s",
	"%s brought in a first harvest: %s",
	"%s reached %s",
	"%s cooked %s for everyone",
]
## Kinds whose words name another person rather than the subject.
const NAMES_OTHER: PackedInt32Array = [Ledger.KIND_RESCUE, Ledger.KIND_RESCUED]
const SKILL_WORDS: String = "%s · Level %d"
const UNKNOWN_PERSON: String = "someone"
const CHRONICLE: String = "Chronicle: %s (%s)"
const SPOTLIGHT: String = "%s. Spotlight %s as one of the village's notable residents? It changes nothing about the work: the name is marked ★ in the roster."
const REFLECTION_TITLE: String = "%s's end: moments to remember"
const RELATION_RESCUED: String = "Rescued %s"
const RELATION_RESCUED_BY: String = "Rescued by %s"
const RELATION_FRIENDS: String = "Friends with %s"
const RELATION_WORKS: String = "Often works with %s"
const RELATION_SUPPER: String = "Often at supper with %s"
## A pair is "often" together from this many shared hours of work, or shared suppers (demo display thresholds).
const OFTEN_HOURS: int = 3
const OFTEN_SUPPERS: int = 3
## Relationship lines shown at most (light: P6 "show it lightly").
const MAX_RELATIONS: int = 3
const INTEREST: String = "Interest: %s"
const EVENING: String = "%s is %s%s%s"
const EVENING_PLACE: String = " at the %s"
const EVENING_PLEASED: String = " — \"%s\""


static func subject_of(kind: int, subject: String, amount: int) -> String:
	"""A deed's subject in words: a skill's "Felling · Level 4", else its subject as recorded."""
	return SKILL_WORDS % [subject, amount] if kind == Ledger.KIND_SKILL else subject


static func event_text(kind: int, subject: String, other_name: String, amount: int) -> String:
	"""A resident's own history row: "Brought Tobit Highbough ashore", "Built the neck bridge", "Reached Felling ·
	Level 4"."""
	if kind < 0 or kind >= EVENT_WORDS.size():
		return ""
	var what: String = other_name if NAMES_OTHER.has(kind) else subject_of(kind, subject, amount)
	return EVENT_WORDS[kind] % (what if not what.is_empty() else UNKNOWN_PERSON)


static func deed_text(kind: int, name: String, subject: String, other_name: String, amount: int) -> String:
	"""The deed told of `name`: "Corra Netley brought Tobit Highbough ashore"."""
	if kind < 0 or kind >= DEED_WORDS.size():
		return ""
	var what: String = other_name if NAMES_OTHER.has(kind) else subject_of(kind, subject, amount)
	return DEED_WORDS[kind] % [name, what if not what.is_empty() else UNKNOWN_PERSON]


static func chronicle_line(deed: String, date: String) -> String:
	"""The chronicle's line for a pinned deed: "Chronicle: Corra Netley brought Tobit Highbough ashore (Y1 Spring 4)"."""
	return CHRONICLE % [deed, date]


static func spotlight_text(deed: String, name: String) -> String:
	"""The spotlight's offer after a distinctive deed (SOC-001): what happened, and what pinning does and does not."""
	return SPOTLIGHT % [deed, name]


static func reflection_title(season_title: String) -> String:
	"""'Spring's end: moments to remember'."""
	return REFLECTION_TITLE % season_title


static func relation_lines(ledger: Ledger, who: int, names: PackedStringArray) -> PackedStringArray:
	"""Up to MAX_RELATIONS light lines from what actually happened: the latest rescue either way, friends, the one it
	most often works with, the one it most often shares supper with (each person named once)."""
	var out := PackedStringArray()
	var named := PackedInt32Array()
	_rescue_line(ledger, who, names, out, named)
	_pair_line(ledger, who, names, out, named, RELATION_FRIENDS, ledger.friend, 1)
	_pair_line(ledger, who, names, out, named, RELATION_WORKS, ledger.shared_hours, OFTEN_HOURS)
	_pair_line(ledger, who, names, out, named, RELATION_SUPPER, ledger.suppers, OFTEN_SUPPERS)
	return out


static func _rescue_line(ledger: Ledger, who: int, names: PackedStringArray, out: PackedStringArray,
		named: PackedInt32Array) -> void:
	"""The latest rescue `who` took part in, either way."""
	for e: int in range(ledger.event_count() - 1, -1, -1):
		if ledger.ev_who[e] != who or ledger.ev_other[e] < 0:
			continue
		if ledger.ev_kind[e] == Ledger.KIND_RESCUE or ledger.ev_kind[e] == Ledger.KIND_RESCUED:
			var words: String = RELATION_RESCUED if ledger.ev_kind[e] == Ledger.KIND_RESCUE else RELATION_RESCUED_BY
			out.append(words % _name(names, ledger.ev_other[e]))
			named.append(ledger.ev_other[e])
			return


static func _pair_line(ledger: Ledger, who: int, names: PackedStringArray, out: PackedStringArray,
		named: PackedInt32Array, words: String, column: Variant, least: int) -> void:
	"""The other resident with the most in `column` (at least `least`), not yet named, as `words`."""
	if out.size() >= MAX_RELATIONS:
		return
	var best: int = -1
	var most: int = least - 1
	for other: int in ledger.resident_count():
		var p: int = ledger.pair(who, other)
		if p < 0 or named.has(other):
			continue
		var value: int = int(column[p])
		if value > most:
			most = value
			best = other
	if best >= 0:
		out.append(words % _name(names, best))
		named.append(best)


static func _name(names: PackedStringArray, who: int) -> String:
	"""Resident `who`'s name (UNKNOWN_PERSON out of range)."""
	return names[who] if who >= 0 and who < names.size() else UNKNOWN_PERSON


static func evening_line(key: StringName, name: String, place: String, pleased: bool, turn: int) -> String:
	"""A light, truthful evening line (decision 0491): "Wenna Tallowby is carving a tiny animal figure for a windowsill
	at the hall table" -- with, only on an evening after a deed of theirs committed that day, their own pleased line
	in their own voice (dialect only for a speaker who has it). "" for a key with no person."""
	var doing: String = PeopleBook.evening_of(key)
	if doing.is_empty():
		return ""
	var at: String = EVENING_PLACE % place if not place.is_empty() else ""
	var said: String = ""
	if pleased and not PeopleBook.pleased_of(key).is_empty():
		said = EVENING_PLEASED % PeopleBook.spoken(key, PeopleBook.pleased_of(key), turn)
	return EVENING % [name, doing, at, said]
