extends RefCounted
## The village chronicle's words (decision 0631): a light record-keeper's voice over facts the village really recorded.
## Pure constants and static functions; chronicle_writer.gd chooses which line to say, this file only how to say it.
##
## THE VOICE. A keeper setting down the season (setting_bible.md CULT-002, "a keeper records the season's most
## consequential events"; the Chronicle row of §13.3, "record the real event before interpretation"). Every line states
## a recorded fact first; the colour is in the framing only ("Into store came 8 baskets of food..."). Original wording throughout:
## no line, name or phrase from any book (the setting's lore rule), and plain enough to read at a glance (DEC-017 keeps
## dialect for a resident's own quoted words, never for the record).
##
## VARIETY, DETERMINISTICALLY. Most lines have two or three wordings. Which one a page uses is `pick(seed, season,
## slot, n)`: a pure integer hash of the village's seed, the absolute season and the line's slot, so the same village
## writes the same page every time, and two seasons rarely read alike. Nothing here draws from an Rng.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const BOOK_TITLE: String = "The village chronicle"
## A written page's title: "Spring, in the village's first year".
const PAGE_TITLE: String = "%s, in the village's %s year"
const DRAFT_TITLE: String = "%s, in the village's %s year — being written"
const DRAFT_NOTE: String = "This page is still being written: it holds what has been recorded so far (%s)."
const DRAFT_NO_DAYS: String = "no day of it closed yet"
const YEAR_WORDS: Array[String] = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
	"tenth"]
const YEAR_NUMBER: String = "%dth"

## The page's sections (chronicle_book.gd SECTION_*), as headed.
const SECTION_TITLES: Array[String] = ["", "The harvest and the table", "Weather and trouble", "Deeds",
	"Friends and neighbours", "Songs and gatherings", ""]

## Openings by mood (chronicle_writer.gd MOOD_*). Each wording claims no more than its mood's own condition: an occasion
## (whatever it was: a gathering, and one day perhaps a departure), hunger recorded, crops lost, adverse weather, other
## trouble, a steady season with no trouble, a bare one.
const OPENINGS: Array = [
	["This season has an occasion to record.",
		"Something out of the ordinary happened this season, and it is set down below."],
	["It was a hard season, and this record says so plainly.",
		"Not every bowl was filled this season."],
	["Not every bed came to harvest this season.",
		"Some of the season's crops were lost in the beds."],
	["The weather tried the village this season.",
		"It was a season of hard weather."],
	["The season had its troubles, and they are set down here.",
		"Not every day of this season went to plan."],
	["A steady season: the work went on, day after day.",
		"The days ran on quietly, and the work with them.",
		"A working season, set down here in brief."],
	["Little is set down for this season: the village kept its days."],
]
const CLOSINGS: Array[String] = ["So ends the record of %s.", "Here ends the page for %s.",
	"Thus passed %s; the next page waits."]

# --- the harvest and the table ----------------------------------------------------------------------------------------
const HARVEST: Array[String] = ["Into store came %s: %s.", "The stores took in %s: %s.", "The village brought %s into store: %s."]
const HARVEST_NONE: String = "Nothing was brought into store."
const FIRST_HARVEST: String = "For the first time, food from the village's own work came into store."
const PORTIONS: Array[String] = ["At table, the village ate %s.", "The kitchen fed the village %s.",
	"%s went down at the hall's tables."]
const PORTION_NOUNS: Array = ["one portion", "portions"]
const FIRST_MEALS: String = "The village's first cooked meals were served this season."
const NONE_WITHOUT: String = "Nobody went without a meal."
## Who went without: the record counts each resident's missed meal, so a count is meals missed, not residents.
const WENT_WITHOUT_ONCE: String = "Once, a resident went without a meal."
const WENT_WITHOUT: String = "A meal was missed %d times, counting each resident who went without."
const CROPS_LOST: String = "%s withered in the beds."
const CROP_NOUNS: Array = ["A crop", "crops"]
const DAY_NOUNS: Array = ["a day", "days"]
const EVENING_NOUNS: Array = ["one evening", "evenings"]
const DAYS_RECORDED: String = "%s recorded"
const DAYS_RECORDED_NOUNS: Array = ["one day", "days"]
const MORE_KINDS: String = "%d more"

# --- weather and trouble ---------------------------------------------------------------------------------------------
## By the §5.10 event id (scripts/core/weather.gd EVENT_KEYS order): what the season's event was, for how long.
const WEATHER_EVENTS: Array[String] = [
	"Blight was in the air for %s.",
	"Calm weather held for %s.",
	"Drought held for %s.",
	"An early frost came, and lay for %s.",
	"A hard freeze held for %s.",
	"Heavy rain fell for %s.",
	"A spell of fine growing weather lasted %s.",
]
## By chronicle_tally.gd TROUBLE_*: how each recorded trouble is told ("%s" is its count, worded).
const TROUBLES: Array[String] = [
	"The wind brought down %s.",
	"The stream rose over the garden on %s.",
	"%s flooded.",
	"%s fell in.",
	"Danger came near, and the village took shelter on %s.",
	"%s got into difficulty in the water.",
	"Frost came on %s.",
	"Blight struck %s.",
	"No meal could be served on %s.",
	"Somebody slept without a bed on %s.",
]
## By TROUBLE_*: the noun each count names, singular and plural.
const TROUBLE_NOUNS: Array = [["a tree", "trees"], ["one day", "days"], ["A tunnel", "tunnels"],
	["A tunnel", "tunnels"], ["one day", "days"], ["A resident", "residents"], ["one night", "nights"], ["a bed", "beds"],
	["one day", "days"], ["one night", "nights"]]
const NO_TROUBLE: String = "No trouble worth the ink."

# --- deeds, friends, songs -------------------------------------------------------------------------------------------
const DEED: String = "%s."
const VILLAGE_FIRST: String = "%s — the village's first."
const BECAME_FRIENDS: Array[String] = ["%s and %s became friends.", "A friendship was made: %s and %s.",
	"%s and %s are friends now."]
const DRIFTED: String = "%s and %s drifted apart: a friendship let lapse."
const WORKED_TOGETHER: Array[String] = ["%s and %s worked side by side for %d hours.",
	"No two worked together more than %s and %s: %d hours, side by side."]
const LEARNED_SONG: String = "%s learned “%s”."
## Any supper song, led with the table joining or sung alone (song_circle.gd SUPPER_LINE, SUPPER_ALONE_LINE): neither
## wording says the table sang together.
const SUPPER_SONGS: Array[String] = ["There was singing at supper on %s.", "Songs were sung at supper on %s."]
const GUIDE_DONE: String = "The first village stood: a harvest in, a supper served, and the village readied for the frost."
const PROJECT_DONE: String = "The village finished a project of its own: “%s”."

## The news line when a page is written, and its kind (so its repeats group, and it can be snoozed).
const PAGE_NOTICE: String = "The chronicle's page for %s is written — open it from Village news (N) or the village guide (O)."
const PAGE_NOTICE_BRIEF: String = "A chronicle page is written"
const PAGE_KIND: StringName = &"chronicle_page"


static func mix(seed_value: int, season: int, slot: int) -> int:
	"""A non-negative integer hash of (seed, season, slot): the same three always give the same number."""
	var h: int = (seed_value * 73856093) ^ (season * 19349663) ^ (slot * 83492791)
	h &= 0x7FFFFFFF
	h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0x7FFFFFFF
	h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0x7FFFFFFF
	return h ^ (h >> 16)


static func pick(seed_value: int, season: int, slot: int, count: int) -> int:
	"""Which of `count` wordings a page uses for a slot (0 when there is at most one)."""
	return 0 if count <= 1 else mix(seed_value, season, slot) % count


static func season_word(absolute_season: int) -> String:
	"""'Spring', the absolute season's name."""
	return CalendarScript.SEASON_TITLES[posmod(absolute_season, SimClock.SEASONS_PER_YEAR)]


static func year_word(absolute_season: int) -> String:
	"""'first', 'second', ... 'tenth', then '11th' -- the village's year an absolute season falls in."""
	@warning_ignore("integer_division")
	var year: int = maxi(absolute_season, 0) / SimClock.SEASONS_PER_YEAR
	return YEAR_WORDS[year] if year < YEAR_WORDS.size() else YEAR_NUMBER % (year + 1)


static func page_title(absolute_season: int, draft: bool) -> String:
	"""'Spring, in the village's first year' (and '— being written' on the season still under way)."""
	return (DRAFT_TITLE if draft else PAGE_TITLE) % [season_word(absolute_season), year_word(absolute_season)]


static func short_name(absolute_season: int) -> String:
	"""A page's tab: 'Spring Y1'."""
	@warning_ignore("integer_division")
	return "%s Y%d" % [season_word(absolute_season), maxi(absolute_season, 0) / SimClock.SEASONS_PER_YEAR + 1]


static func count_words(count: int, nouns: Array) -> String:
	"""'a day', '3 days' -- a count with its noun (`nouns` is [singular, plural])."""
	return String(nouns[0]) if count == 1 else "%d %s" % [count, String(nouns[1])]


static func list_words(parts: PackedStringArray) -> String:
	"""'a', 'a and b', 'a, b and c'."""
	if parts.size() <= 1:
		return "" if parts.is_empty() else parts[0]
	return "%s and %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[parts.size() - 1]]


static func capitalised(words: String) -> String:
	"""`words` with its first letter in capitals ('a tunnel flooded' -> 'A tunnel flooded')."""
	return words if words.is_empty() else words.substr(0, 1).to_upper() + words.substr(1)
