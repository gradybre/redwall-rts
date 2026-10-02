extends RefCounted
## ONE SEASON'S TALLY for the village chronicle (decision 0631): what the village news recorded in that season, counted
## as it arrives, and the people's and songs' state at the season's start and end. Pure data, no nodes; demo_chronicle.gd
## feeds it and chronicle_writer.gd reads it when the season's page is written.
##
## FROM THE NEWS, BY ENTRY ID. The owner hands over each row the feed wrote since it last looked (demo_notices.gd
## `is_new_since`: a grouped repeat keeps its id and moves to the top, so "the newest N" would count it twice and miss
## others -- the README's "The notice API"). A row belongs to the season its `first_tick` falls in, so a line said just
## before midnight on a season's last day counts in that season even when it is read a frame later. `read_row` sorts it:
##   * TROUBLES -- an incident's line (its kind is its key's: demo_incidents.gd `kind_of_key`) of a kind in
##     TROUBLE_KINDS. Counted once per distinct SUBJECT (a tree, a tunnel, a resident, a bed: TROUBLE_BY_SUBJECT) or
##     once per distinct DAY (a frost night, a flooded garden, a day without a meal), however many times its line was
##     said -- a merged repeat writes a new history row for each date it was said (decision 0331).
##   * OCCASIONS -- a Village line (SOURCE_VILLAGE) that is a chronicle line: "Chronicle: ..." (the regatta's feast,
##     decision 0438, and any later gathering, arrival or departure that writes one), the first-village guide done
##     (guide_text.gd COMPLETE_TITLE) or a player's project done (projects.gd CHRONICLE). The people's pinned deeds post
##     "Chronicle: ..." under the crew's source; those are read from the people's ledger instead (chronicle_writer.gd),
##     where the player's curation of them is kept, so they are not counted twice.
##   * SUPPER SONGS -- the songs' "At supper ..." line, led with the table joining or sung alone (song_circle.gd
##     SUPPER_LINE, SUPPER_ALONE_LINE), once per day; the page says only that there was singing at supper.
## Anything else is not the chronicle's. Nothing is parsed out of free text but the project's quoted name.
##
## SNAPSHOTS. `begin` copies, at the season's start, which pairs are friends and how many hours each pair has worked
## together (people_ledger.gd), and which songs each resident knows (song_circle.gd); `finish` copies the same at its
## end. The writer compares the two: friendships made and lapsed, the pair who worked together most, songs learned.

const NoticesScript := preload("res://demo/demo_notices.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const CircleScript := preload("res://demo/songs/song_circle.gd")
const GuideText := preload("res://demo/guide/guide_text.gd")
const ProjectsScript := preload("res://demo/guide/projects.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const TROUBLE_WINDTHROW: int = 0
const TROUBLE_GARDEN_FLOOD: int = 1
const TROUBLE_TUNNEL_FLOODED: int = 2
const TROUBLE_TUNNEL_COLLAPSED: int = 3
const TROUBLE_THREAT: int = 4
const TROUBLE_IN_WATER: int = 5
const TROUBLE_FROST: int = 6
const TROUBLE_BLIGHT: int = 7
const TROUBLE_NO_MEAL: int = 8
const TROUBLE_NO_BED: int = 9
const TROUBLE_COUNT: int = 10
## The incident kinds told of, by TROUBLE_* (the owners' keys: forestry, the leat, the tunnels, the events, the rescue,
## the farm's alerts, the kitchen, the night).
const TROUBLE_KINDS: Array[StringName] = [&"woods:windthrow", &"leat:flood", &"tunnel:flooded", &"tunnel:collapsed",
	&"threat", &"water:rescue", &"farm:frost", &"farm:blight", &"kitchen:no_meal", &"village:no_bed"]
## By TROUBLE_*: 1 -- counted once per distinct subject; 0 -- once per distinct day.
const TROUBLE_BY_SUBJECT: PackedByteArray = [1, 0, 1, 1, 0, 1, 0, 1, 0, 0]
## The distinct-key slot the supper songs count their days in (after the troubles').
const SUPPER_SLOT: int = TROUBLE_COUNT

const OCCASION_CHRONICLE: int = 0
const OCCASION_GUIDE: int = 1
const OCCASION_PROJECT: int = 2
const CHRONICLE_PREFIX: String = "Chronicle: "
## A season's occasions kept at most (the first ones: a page stays short).
const MAX_OCCASIONS: int = 6
## Distinct (trouble, subject or day) keys a season remembers at most; past it nothing new is counted.
const MAX_SEEN: int = 512
## A distinct key: the slot times this, plus the subject's hash or the day.
const SLOT_STRIDE: int = 1 << 40
const NO_SEASON: int = -1

## The absolute season tallied (0: the first spring).
var season: int = NO_SEASON
## By TROUBLE_*: how many distinct subjects or days.
var troubles: PackedInt32Array = PackedInt32Array()
var occasion_text: PackedStringArray = PackedStringArray()
var occasion_kind: PackedByteArray = PackedByteArray()
var supper_song_days: int = 0
## Rows read into this tally (checks).
var rows_read: int = 0
## Whether `finish` has taken the end snapshots.
var ended: bool = false
var friend_start: PackedByteArray = PackedByteArray()
var friend_end: PackedByteArray = PackedByteArray()
var hours_start: PackedInt32Array = PackedInt32Array()
var hours_end: PackedInt32Array = PackedInt32Array()
var knows_start: PackedInt32Array = PackedInt32Array()
var knows_end: PackedInt32Array = PackedInt32Array()

var _seen: PackedInt64Array = PackedInt64Array()
## The owners' prefixes, made once (see `supper_prefix`, `project_prefix`).
static var _supper_prefix: String = ""
static var _project_prefix: String = ""


func _init(p_season: int = NO_SEASON) -> void:
	"""An empty tally of absolute season `p_season`."""
	season = p_season
	troubles.resize(TROUBLE_COUNT)
	troubles.fill(0)


static func season_of_tick(at_tick: int) -> int:
	"""The absolute season a calendar tick falls in (0: the first spring). Integer division: whole days and seasons."""
	@warning_ignore("integer_division")
	var day: int = maxi(at_tick + SimClock.CALENDAR_OFFSET_TICKS, 0) / SimClock.TICKS_PER_DAY
	@warning_ignore("integer_division")
	return day / SimClock.DAYS_PER_SEASON


static func day_of_tick(at_tick: int) -> int:
	"""The calendar day index a tick falls in (0: spring day 1 of year 1). Integer division: whole days."""
	@warning_ignore("integer_division")
	return maxi(at_tick + SimClock.CALENDAR_OFFSET_TICKS, 0) / SimClock.TICKS_PER_DAY


static func supper_prefix() -> String:
	"""What every supper-song line begins with: song_circle.gd SUPPER_LINE up to its first slot ("At supper ")."""
	if _supper_prefix.is_empty():
		_supper_prefix = CircleScript.SUPPER_LINE.substr(0, CircleScript.SUPPER_LINE.find("%s"))
	return _supper_prefix


static func project_prefix() -> String:
	"""What a done project's line begins with: projects.gd CHRONICLE up to its name (`Project complete: "`)."""
	if _project_prefix.is_empty():
		_project_prefix = ProjectsScript.CHRONICLE.substr(0, ProjectsScript.CHRONICLE.find("%s"))
	return _project_prefix


# --- snapshots ----------------------------------------------------------------------------------------------------

func begin(ledger: Ledger, circle: CircleScript) -> void:
	"""The season's start: which pairs are friends, their hours together, and the songs each resident knows."""
	friend_start = ledger.friend.duplicate() if ledger != null else PackedByteArray()
	hours_start = ledger.shared_hours.duplicate() if ledger != null else PackedInt32Array()
	knows_start = circle.knows.duplicate() if circle != null else PackedInt32Array()


func finish(ledger: Ledger, circle: CircleScript) -> void:
	"""The season's end: the same three, now (see SNAPSHOTS)."""
	friend_end = ledger.friend.duplicate() if ledger != null else PackedByteArray()
	hours_end = ledger.shared_hours.duplicate() if ledger != null else PackedInt32Array()
	knows_end = circle.knows.duplicate() if circle != null else PackedInt32Array()
	ended = true


# --- reading the news ---------------------------------------------------------------------------------------------

func read_row(notices: NoticesScript, k: int) -> bool:
	"""Count feed entry `k` into this tally (see FROM THE NEWS) -- the caller has checked it is new and of this season.
	Returns whether it was the chronicle's at all."""
	rows_read += 1
	var trouble: int = TROUBLE_KINDS.find(notices.kind(k)) if notices.kind_named(k) else -1
	if trouble >= 0:
		var value: int = notices.subject(k).hash() if TROUBLE_BY_SUBJECT[trouble] == 1 \
			else day_of_tick(notices.first_tick(k))
		if _count_once(trouble, value):
			troubles[trouble] += 1
		return true
	if notices.source(k) == NoticesScript.SOURCE_VILLAGE:
		return _read_occasion(notices.text(k))
	if notices.source(k) == NoticesScript.SOURCE_CREW and notices.text(k).begins_with(supper_prefix()):
		if _count_once(SUPPER_SLOT, day_of_tick(notices.first_tick(k))):
			supper_song_days += 1
		return true
	return false


func _read_occasion(words: String) -> bool:
	"""A Village line: a chronicle line, the guide done or a project done, kept (see OCCASIONS)."""
	if words.begins_with(CHRONICLE_PREFIX):
		return add_occasion(OCCASION_CHRONICLE, words.substr(CHRONICLE_PREFIX.length()))
	if words.begins_with(GuideText.COMPLETE_TITLE):
		return add_occasion(OCCASION_GUIDE, "")
	var prefix: String = project_prefix()
	if words.begins_with(prefix):
		var rest: String = words.substr(prefix.length())
		var close: int = rest.rfind("\" -- ")
		return add_occasion(OCCASION_PROJECT, rest.substr(0, close) if close >= 0 else rest)
	return false


func add_occasion(kind: int, words: String) -> bool:
	"""Keep one occasion (OCCASION_*) and its words; false once MAX_OCCASIONS are kept or the kind is unknown."""
	if kind < OCCASION_CHRONICLE or kind > OCCASION_PROJECT or occasion_kind.size() >= MAX_OCCASIONS:
		return false
	occasion_kind.append(kind)
	occasion_text.append(words)
	return true


func _count_once(slot: int, value: int) -> bool:
	"""Whether (slot, value) is new this season (and now remembered). Past MAX_SEEN keys, nothing is new."""
	var key: int = slot * SLOT_STRIDE + posmod(value, SLOT_STRIDE)
	if _seen.has(key) or _seen.size() >= MAX_SEEN:
		return false
	_seen.append(key)
	return true


func seen_count() -> int:
	"""Distinct keys remembered (checks)."""
	return _seen.size()


func occasion_count() -> int:
	"""Occasions kept."""
	return occasion_kind.size()


func any_trouble() -> bool:
	"""Whether any trouble was counted."""
	for count: int in troubles:
		if count > 0:
			return true
	return false
