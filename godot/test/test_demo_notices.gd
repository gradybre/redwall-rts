extends "res://test/framework/test_case.gd"
## The better notices (decision 0591, feature #39): tiers inferred and named, kinds and subjects, grouping by kind and
## subject within a game day, the snoozed kinds and their game hours, dismissing one, the per-tier toast budget that
## keeps 4x quiet, the posted hook, entry ids for readers (the sound, "Run until"), and the strip's and the history's
## tiers, Go to, Snooze and Dismiss. The existing call sites' behaviour is test_demo_news.gd's and stays green.

const NoticesScript := preload("res://demo/demo_notices.gd")
const SnoozesScript := preload("res://demo/demo_notice_snoozes.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const StripScript := preload("res://demo/ui/demo_news_strip.gd")
const HistoryScript := preload("res://demo/ui/demo_news_history.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const TapsScript := preload("res://demo/sound/sound_taps.gd")
const SoundTable := preload("res://demo/sound/sound_table.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const TimeControlScript := preload("res://demo/session/time_control.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const ClockScript := preload("res://demo/demo_clock.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const HOUR: int = SimClock.TICKS_PER_HOUR
const CROWS: StringName = &"crows"
const CROWS_TEXT: String = "Crows at the barley"

var _nodes: Array[Node] = []
var _game: GameManagerScript = null
var _heard: Array = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if _game != null:
		_game.free()
	_game = null
	_heard.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _feed() -> NoticesScript:
	"""A feed on a calendar and a news clock of its own."""
	var shared := ServicesScript.new()
	return shared.notices


func _crows_on_bed(feed: NoticesScript, bed: int) -> void:
	"""Crows at the barley, a normal notice of kind CROWS, its subject bed `bed`'s target."""
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "", "", NoticesScript.TARGET_BED,
		bed)


func _calendar_of(feed: NoticesScript) -> CalendarScript:
	"""A fresh calendar bound to `feed` (tick 0)."""
	var calendar := CalendarScript.new()
	feed.bind_calendar(calendar)
	return calendar


func _clock_of(feed: NoticesScript) -> NewsClockScript:
	"""A fresh news clock bound to `feed` (time 0)."""
	var clock := NewsClockScript.new()
	feed.bind_clock(clock)
	return clock


# --- tiers ------------------------------------------------------------------------------------------------

func test_tiers_are_inferred_from_the_level_and_may_be_named() -> void:
	"""A warning is normal, a note info; a named tier is kept; a tier out of range is refused, nothing kept."""
	var feed := _feed()
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 2 wet")
	assert_equal(feed.tier(0), NoticesScript.TIER_NORMAL, "a warning: normal")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Beans sown")
	assert_equal(feed.tier(0), NoticesScript.TIER_INFO, "a note: info")
	feed.post(NoticesScript.SOURCE_EVENTS, NoticesScript.LEVEL_WARNING, "Fire", "", NoticesScript.TARGET_NONE, -1,
		NoticesScript.NO_INCIDENT, NoticesScript.TIER_URGENT)
	assert_equal(feed.tier(0), NoticesScript.TIER_URGENT, "named urgent")
	assert_equal(feed.count(), 3, "three kept")
	assert_false(feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "x", "", 0, -1, -1, 3), "tier 3")
	assert_false(feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "x", "", 0, -1, -1, -2), "tier -2")
	assert_equal(feed.count(), 3, "nothing kept for a refusal")
	assert_equal(NoticesScript.infer_tier(NoticesScript.LEVEL_WARNING), NoticesScript.TIER_NORMAL, "static: warning")
	assert_equal(NoticesScript.infer_tier(NoticesScript.LEVEL_NOTE), NoticesScript.TIER_INFO, "static: note")


func test_an_incident_line_takes_its_severity_s_tier_and_its_key_s_kind_and_subject() -> void:
	"""Critical -> urgent, warning -> normal, routine -> info; "tunnel:flooded:4:2" -> kind "tunnel:flooded",
	subject "4:2"; an incident line never groups (its incident does)."""
	var shared := ServicesScript.new()
	shared.incidents.report("water:rescue:7", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "Help!")
	assert_equal(shared.notices.tier(0), NoticesScript.TIER_URGENT, "critical: urgent")
	assert_equal(shared.notices.kind(0), &"water:rescue", "the key's words")
	assert_equal(shared.notices.subject(0), "7", "the key's number")
	shared.incidents.report("tunnel:flooded:4:2", NoticesScript.SOURCE_TUNNELS, IncidentsScript.SEVERITY_WARNING, "Wet")
	assert_equal(shared.notices.tier(0), NoticesScript.TIER_NORMAL, "warning: normal")
	assert_equal(shared.notices.subject(0), "4:2", "both numbers")
	shared.incidents.report("farm:fallow:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "Rest it")
	assert_equal(shared.notices.tier(0), NoticesScript.TIER_INFO, "routine: info")
	shared.incidents.report("farm:fallow:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "Rest it now")
	assert_equal(shared.notices.count(), 4, "a second line of one incident is a row of its own (decision 0331)")
	assert_equal(IncidentsScript.tier_of(IncidentsScript.SEVERITY_CRITICAL), NoticesScript.TIER_URGENT, "tier_of")


func test_a_key_splits_into_its_kind_and_subject_at_its_first_number() -> void:
	"""The words before the first all-digit part are the kind; that part on is the subject."""
	assert_equal(IncidentsScript.kind_of_key("tunnel:flooded:4:2"), "tunnel:flooded", "kind")
	assert_equal(IncidentsScript.subject_of_key("tunnel:flooded:4:2"), "4:2", "subject")
	assert_equal(IncidentsScript.kind_of_key("events:threat"), "events:threat", "no number: all kind")
	assert_equal(IncidentsScript.subject_of_key("events:threat"), "", "no number: no subject")
	assert_equal(IncidentsScript.kind_of_key("farm:stuck:3:x"), "farm:stuck", "a word after the number is subject")
	assert_equal(IncidentsScript.subject_of_key("farm:stuck:3:x"), "3:x", "the rest")
	assert_equal(IncidentsScript.kind_of_key("12:x"), "", "a number first: no kind")
	assert_equal(IncidentsScript.subject_of_key("12:x"), "12:x", "all subject")
	assert_equal(IncidentsScript.kind_of_key("a1:b"), "a1:b", "a part with digits in it is not a number")


func test_the_line_says_the_urgent_tier_in_words() -> void:
	"""Urgent: 'Urgent: ', normal: 'Warning: ', info: nothing -- the word, never the colour alone."""
	var feed := _feed()
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fire", "Fire in the kitchen")
	assert_equal(feed.line(0), "Y1 Spring 1, 06:00 · Urgent: Fire in the kitchen", "urgent")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"cold_home", "A home is cold", "", "Cold home")
	assert_equal(feed.short_line(0), "Y1 Spring 1, 06:00 · Warning: Cold home", "normal, short")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, &"chilled", "Bramble is chilled")
	assert_equal(feed.line(0), "Y1 Spring 1, 06:00 · Bramble is chilled", "info: no word")


# --- notify, subjects, kinds ------------------------------------------------------------------------------

func test_notify_posts_at_the_tier_s_level_and_names_its_kind() -> void:
	"""Urgent and normal post warnings, info a note; the kind is named; TIER_AUTO, an empty kind and a tier out of
	range are refused."""
	var feed := _feed()
	assert_true(feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"out_of_fuel", "Out of fuel"), "ok")
	assert_equal(feed.level(0), NoticesScript.LEVEL_WARNING, "normal: a warning")
	assert_true(feed.kind_named(0), "named")
	assert_equal(feed.kind(0), &"out_of_fuel", "its kind")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, &"chilled", "Chilled")
	assert_equal(feed.level(0), NoticesScript.LEVEL_NOTE, "info: a note")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_URGENT, &"blaze", "Blaze")
	assert_equal(feed.level(0), NoticesScript.LEVEL_WARNING, "urgent: a warning")
	assert_false(feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_AUTO, &"x", "x"), "auto refused")
	assert_false(feed.notify(NoticesScript.SOURCE_CREW, 3, &"x", "x"), "tier 3 refused")
	assert_false(feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, NoticesScript.NO_KIND, "x"), "no kind")
	assert_equal(feed.count(), 3, "three kept")


func test_a_subject_is_the_poster_s_else_the_target_s_else_none() -> void:
	"""subject_of: given; "bed:3" from a bed target; "" with neither or a target out of range."""
	assert_equal(NoticesScript.subject_of("home:2", NoticesScript.TARGET_BED, 3), "home:2", "the poster's")
	assert_equal(NoticesScript.subject_of("", NoticesScript.TARGET_BED, 3), "bed:3", "the target's")
	assert_equal(NoticesScript.subject_of("", NoticesScript.TARGET_RESIDENT, 0), "resident:0", "resident 0")
	assert_equal(NoticesScript.subject_of("", NoticesScript.TARGET_NONE, 3), "", "none")
	assert_equal(NoticesScript.subject_of("", NoticesScript.TARGET_NAMES.size(), 3), "", "out of range")


func test_an_untagged_line_s_kind_is_its_source_and_words() -> void:
	"""An existing call site names no kind: its kind is "<source>:<summary or text>", and it is not named."""
	var feed := _feed()
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 4 is dry")
	assert_equal(feed.kind(0), &"farm:Bed 4 is dry", "source and text")
	assert_false(feed.kind_named(0), "not named")
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded.", "Tunnel 1 flooded")
	assert_equal(feed.kind(0), &"tunnels:Tunnel 1 flooded", "the summary when there is one")
	assert_equal(feed.kind_title(&"tunnels:Tunnel 1 flooded"), "Tunnel 1 flooded", "its words: the summary")
	assert_equal(feed.kind_title(&"never"), "never", "a kind none is kept of: itself")


# --- grouping ---------------------------------------------------------------------------------------------

func test_repeats_of_a_kind_and_subject_group_with_a_count_and_move_to_the_top() -> void:
	"""Crows at the barley three times, other news between: one entry "(×3)", newest, its id kept, no new row
	written for a repeat; the newest words taken; first and last ticks kept apart."""
	var feed := _feed()
	var calendar := _calendar_of(feed)
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	var id: int = feed.entry_id(0)
	feed.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "A tree felled")
	calendar.tick += HOUR
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	calendar.tick += HOUR
	var rows: int = feed.rows_posted
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_URGENT, CROWS, "Crows back at the barley", "bed:3")
	assert_equal(feed.rows_posted, rows, "a grouped repeat writes no row")
	assert_equal(feed.count(), 3, "three entries: crows, the tree, the rain")
	assert_equal(feed.text(0), "Crows back at the barley", "newest, with the newest words")
	assert_equal(feed.repeats(0), 3, "counted")
	assert_equal(feed.line(0), "Y1 Spring 1, 08:00 · Urgent: Crows back at the barley (×3)", "the count shown")
	assert_equal(feed.tier(0), NoticesScript.TIER_URGENT, "the repeat's tier taken")
	assert_equal(feed.entry_id(0), id, "its id kept")
	assert_equal(feed.first_tick(0), 0, "first said at tick 0")
	assert_equal(feed.said_tick(0), 2 * HOUR, "last said two hours on")
	assert_equal(feed.text(1), "Rain", "the rest in order")
	assert_equal(feed.text(2), "A tree felled", "the oldest")


func test_another_subject_or_a_day_later_is_a_new_entry() -> void:
	"""Crows at bed 2 are not crows at bed 3; crows at bed 3 again more than GROUP_WINDOW_TICKS later are a new
	entry; exactly at the window they still group."""
	var feed := _feed()
	var calendar := _calendar_of(feed)
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, "Crows at the beans", "bed:2")
	assert_equal(feed.count(), 2, "two subjects, two entries")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, &"rooks", CROWS_TEXT, "bed:3")
	assert_equal(feed.count(), 3, "another kind, another entry")
	calendar.tick = NoticesScript.GROUP_WINDOW_TICKS
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	assert_equal(feed.count(), 3, "exactly a day on: still grouped")
	assert_equal(feed.repeats(0), 2, "counted")
	calendar.tick = 2 * NoticesScript.GROUP_WINDOW_TICKS + 1
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	assert_equal(feed.count(), 4, "more than a day after it was last said: a new entry")
	assert_equal(feed.repeats(0), 1, "said once")


func test_a_target_is_the_subject_when_none_is_named() -> void:
	"""Two crows posts on bed 3's target group; on bed 4's target they do not."""
	var feed := _feed()
	_crows_on_bed(feed, 3)
	_crows_on_bed(feed, 3)
	assert_equal(feed.count(), 1, "same target: grouped")
	assert_equal(feed.subject(0), "bed:3", "its subject")
	_crows_on_bed(feed, 4)
	assert_equal(feed.count(), 2, "another bed: apart")


func test_untagged_lines_still_fold_only_when_said_twice_in_a_row() -> void:
	"""The existing fold (decision 0210) is unchanged: the same line twice folds; anything between keeps them apart."""
	var feed := _feed()
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_NOTE, "Good sticky clay")
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_NOTE, "Good sticky clay")
	assert_equal(feed.count(), 1, "folded")
	assert_equal(feed.repeats(0), 2, "×2")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Beans sown")
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_NOTE, "Good sticky clay")
	assert_equal(feed.count(), 3, "apart once something was said between")


func test_a_named_kind_never_joins_an_untagged_line_that_happens_to_share_it() -> void:
	"""An untagged line's inferred kind "farm:Crows" with a bed target is not a named kind: crows notified with that
	kind and subject start their own entry."""
	var feed := _feed()
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Crows", "", NoticesScript.TARGET_BED, 3)
	assert_equal(feed.kind(0), &"farm:Crows", "inferred")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, &"farm:Crows", "Crows", "", "",
		NoticesScript.TARGET_BED, 3)
	assert_equal(feed.count(), 2, "apart")
	assert_equal(feed.repeats(1), 1, "the untagged line was not counted")


func test_a_grouped_repeat_of_a_snoozed_kind_stays_quiet() -> void:
	"""Crows announced, then snoozed: their next repeat moves to the top but is not announced again."""
	var feed := _feed()
	_calendar_of(feed)
	_crows_on_bed(feed, 3)
	assert_true(feed.is_announced(0), "announced")
	feed.snooze_kind(CROWS, 6)
	_crows_on_bed(feed, 3)
	assert_equal(feed.repeats(0), 2, "grouped")
	assert_false(feed.is_announced(0), "but quiet")
	assert_equal(feed.snoozed_quiet, 1, "counted")


func test_entries_keep_their_first_tick_through_overflow() -> void:
	"""Every column moves together when the oldest goes: each kept entry's first tick is the one it was posted at."""
	var feed := _feed()
	var calendar := _calendar_of(feed)
	for k: int in NoticesScript.CAPACITY + 5:
		calendar.tick = 100 + k
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Report %d" % k)
	assert_equal(feed.count(), NoticesScript.CAPACITY, "full")
	for k: int in [0, 1, NoticesScript.CAPACITY - 1]:
		var said: int = int(feed.text(k).get_slice(" ", 1))
		assert_equal(feed.first_tick(k), 100 + said, "entry %d first said at its own tick" % k)
		assert_equal(feed.said_tick(k), 100 + said, "and last")


func test_a_named_notice_never_joins_an_incident_s_line() -> void:
	"""A notice with an incident line's kind and subject ("farm:wet", "3") starts its own entry; the incident's line
	keeps its serial (so "still open" and the overflow hold still find it)."""
	var shared := ServicesScript.new()
	var serial: int = shared.incidents.report("farm:wet:3", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING,
		"Bed 4 is waterlogged")
	shared.notices.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, &"farm:wet", "Still wet", "3")
	assert_equal(shared.notices.count(), 2, "apart")
	assert_equal(shared.notices.incident(1), serial, "the incident's line keeps its serial")
	assert_equal(shared.notices.repeats(1), 1, "and was not counted")


func test_every_column_moves_with_its_entry_through_overflow_and_regroups() -> void:
	"""Mixed tiers, kinds and held-back rows overflow the feed and regroup mid-feed: each kept entry's tier, announced
	flag, kind, subject and id still describe that entry."""
	var feed := _feed()
	_calendar_of(feed)
	for k: int in NoticesScript.CAPACITY + 7:
		var tier: int = k % 3
		feed.notify(NoticesScript.SOURCE_CREW, tier, StringName("kind%d" % (k % 5)), "Entry %d" % k, "s%d" % k)
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"kind3", "Entry again", "s60")
	assert_equal(feed.text(0), "Entry again", "a mid-feed regroup moved to the top")
	assert_equal(feed.subject(0), "s60", "its subject kept")
	for k: int in range(1, feed.count()):
		var said: int = int(feed.text(k).get_slice(" ", 1))
		assert_equal(feed.tier(k), said % 3, "entry %d's tier" % said)
		assert_equal(String(feed.kind(k)), "kind%d" % (said % 5), "entry %d's kind" % said)
		assert_equal(feed.subject(k), "s%d" % said, "entry %d's subject" % said)
		assert_equal(feed.entry_id(k), said + 1, "entry %d's id" % said)
		var urgent: bool = said % 3 == NoticesScript.TIER_URGENT
		assert_true(not urgent or feed.is_announced(k), "entry %d: urgent, announced" % said)
	assert_true(feed.throttled > 0, "some rows were held back, so the announced column was mixed")


func test_readers_find_new_rows_by_id_after_a_group_moves_a_row() -> void:
	"""A new warning and a grouped repeat in one frame: the repeat is newest, but only the warning is new since."""
	var feed := _feed()
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_INFO, CROWS, CROWS_TEXT, "bed:3")
	var seen: int = feed.rows_posted
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_INFO, CROWS, CROWS_TEXT, "bed:3")
	assert_equal(feed.text(0), CROWS_TEXT, "the repeat moved to the top")
	assert_false(feed.is_new_since(0, seen), "but it is not new")
	assert_true(feed.is_new_since(1, seen), "the warning under it is")
	assert_equal(feed.index_of(feed.entry_id(1)), 1, "index_of finds it")
	assert_equal(feed.index_of(9999), -1, "no such id")


func test_the_time_control_counts_a_warning_under_a_grouped_repeat() -> void:
	""""Run until the next warning" counts the new warning, not the moved repeat (time_control.gd by entry id)."""
	_game = GameManagerScript.new()
	_game.start_game()
	var control := TimeControlScript.new()
	_keep(control)
	var feed := NoticesScript.new()
	var incidents := IncidentsScript.new()
	incidents.bind(feed, null, null)
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	control.configure(_game, ClockScript.new(), feed, incidents)
	var before: int = control.warnings_seen()
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	assert_equal(control.warnings_seen(), before, "a note and a grouped repeat: no new warning")
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	assert_equal(control.warnings_seen(), before + 1, "the new warning counted once, under the moved repeat")


func test_run_until_the_next_warning_skips_a_snoozed_kind_but_not_a_held_back_one() -> void:
	"""Brendan's ruling (0591): a warning of a snoozed kind does not count as "the next warning"; one the toast budget
	held back does (the strip's "N more" says why the run stopped); an urgent one of a snoozed kind does."""
	_game = GameManagerScript.new()
	_game.start_game()
	var control := TimeControlScript.new()
	_keep(control)
	var feed := _feed()
	var incidents := IncidentsScript.new()
	incidents.bind(feed, null, null)
	control.configure(_game, ClockScript.new(), feed, incidents)
	feed.snooze_kind(CROWS, 6)
	var before: int = control.warnings_seen()
	_crows_on_bed(feed, 3)
	assert_true(feed.is_snoozed_entry(0), "a snoozed kind's entry")
	assert_equal(control.warnings_seen(), before, "a snoozed kind does not count")
	for k: int in NoticesScript.TOAST_BURST + 1:
		feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel %d flooded" % k)
	assert_false(feed.is_announced(0), "the last was held back")
	assert_false(feed.is_snoozed_entry(0), "but not snoozed")
	assert_equal(control.warnings_seen(), before + NoticesScript.TOAST_BURST + 1, "every one counts, held back too")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_URGENT, CROWS, "Crows tearing the barley up", "bed:9")
	assert_false(feed.is_snoozed_entry(0), "an urgent entry is never snoozed")
	assert_equal(control.warnings_seen(), before + NoticesScript.TOAST_BURST + 2, "an urgent one of the kind counts")


# --- snooze -----------------------------------------------------------------------------------------------

func test_a_snoozed_kind_is_kept_quiet_for_its_game_hours_and_wakes() -> void:
	"""Snoozed for 6 game hours: new crows are kept but not announced, older ones leave the strip; the hours left
	round up; at the sixth hour it wakes by itself."""
	var feed := _feed()
	var calendar := _calendar_of(feed)
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	assert_false(feed.is_quiet(0), "announced")
	assert_true(feed.snooze_kind(CROWS, 6), "snoozed")
	assert_true(feed.is_quiet(0), "the older one leaves the strip")
	assert_equal(feed.snooze_hours_left(CROWS), 6, "six hours")
	calendar.tick = 1
	assert_equal(feed.snooze_hours_left(CROWS), 6, "rounded up")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, "Crows at the beans", "bed:2")
	assert_false(feed.is_announced(0), "a new crows row is kept quiet")
	assert_equal(feed.snoozed_quiet, 1, "counted")
	assert_equal(feed.count(), 2, "but kept")
	calendar.tick = 5 * HOUR + 1
	assert_equal(feed.snooze_hours_left(CROWS), 1, "under an hour left: 1")
	calendar.tick = 6 * HOUR
	assert_false(feed.is_kind_snoozed(CROWS), "awake at the sixth hour")
	assert_equal(feed.snooze_hours_left(CROWS), 0, "no hours left")
	assert_false(feed.is_quiet(1), "the first crows would show again")


func test_snooze_refuses_nonsense_and_never_quiets_urgent() -> void:
	"""An empty kind or under an hour is refused; an urgent entry cannot be snoozed, and one of a snoozed kind is
	still announced and never quiet; wake_kind and wake_all."""
	var feed := _feed()
	_calendar_of(feed)
	assert_false(feed.snooze_kind(NoticesScript.NO_KIND, 6), "no kind")
	assert_false(feed.snooze_kind(CROWS, 0), "no hours")
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox!")
	assert_false(feed.snooze_entry(0), "urgent: refused")
	assert_false(feed.snooze_entry(5), "out of range")
	assert_true(feed.snooze_kind(&"fox", 6), "the kind itself may be snoozed")
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox again!", "den:2")
	assert_true(feed.is_announced(0), "but an urgent one still announces")
	assert_false(feed.is_quiet(0), "and stays on the strip")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_INFO, CROWS, CROWS_TEXT)
	assert_true(feed.snooze_entry(0), "an info entry snoozes its kind")
	assert_true(feed.is_kind_snoozed(CROWS), "crows asleep")
	assert_true(feed.wake_kind(CROWS), "woken")
	assert_false(feed.wake_kind(CROWS), "not asleep any more")
	feed.snooze_kind(CROWS, 2)
	assert_equal(feed.wake_all(), 2, "fox and crows woken")
	assert_equal(feed.wake_all(), 0, "nothing left")


func test_the_snooze_table_reuses_awake_rows_and_lets_the_soonest_go_when_full() -> void:
	"""MAX_SNOOZES rows: an awake row is reused first; full, the one waking soonest is replaced; kinds_into lists the
	sleeping kinds waking soonest first; a tick not after now is refused."""
	var table := SnoozesScript.new()
	assert_false(table.snooze("x", 10, 10), "not after now")
	assert_false(table.snooze("", 10, 0), "no kind")
	for k: int in SnoozesScript.MAX_SNOOZES:
		assert_true(table.snooze("k%d" % k, 100 + k, 0), "row %d" % k)
	assert_equal(table.count(0), SnoozesScript.MAX_SNOOZES, "full")
	assert_true(table.snooze("late", 500, 0), "full: one goes")
	assert_false(table.is_snoozed("k0", 0), "the soonest to wake went")
	assert_true(table.is_snoozed("k1", 0), "the next stays")
	assert_true(table.snooze("again", 300, 105), "k1..k5 have woken by 105: one is reused")
	assert_true(table.is_snoozed("k6", 105), "k6 still asleep")
	var out := PackedStringArray()
	assert_equal(table.kinds_into(110, out), SnoozesScript.MAX_SNOOZES - 10 + 1, "k11..k15, late, again; then k6..")
	assert_equal(out[0], "k11", "soonest first")
	assert_equal(out[out.size() - 1], "late", "latest last")
	assert_equal(table.until("late"), 500, "until")
	assert_equal(table.until("nope"), -1, "until of none")
	assert_true(table.snooze("late", 50, 0), "a later snooze of a kind replaces its tick")
	assert_equal(table.until("late"), 50, "replaced")


# --- dismiss ----------------------------------------------------------------------------------------------

func test_dismissing_one_takes_it_off_the_strip_and_keeps_it() -> void:
	"""Dismissed: quiet, still kept; twice or out of range: false; by id; a repeat brings it back."""
	var feed := _feed()
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	var revision: int = feed.revision
	assert_true(feed.dismiss(1), "dismissed")
	assert_true(feed.revision > revision, "redrawn")
	assert_true(feed.is_dismissed(1) and feed.is_quiet(1), "off the strip")
	assert_equal(feed.count(), 2, "kept")
	assert_false(feed.dismiss(1), "already")
	assert_false(feed.dismiss(-1) or feed.dismiss(2), "out of range")
	assert_true(feed.dismiss_id(feed.entry_id(0)), "by id")
	assert_false(feed.dismiss_id(9999), "no such id")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	assert_false(feed.is_dismissed(0), "a grouped repeat is shown again")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Sun")
	feed.dismiss(0)
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Sun")
	assert_false(feed.is_dismissed(0), "and so is a folded one")


# --- throttle ---------------------------------------------------------------------------------------------

func test_the_toast_budget_holds_back_a_burst_and_refills_on_the_news_clock() -> void:
	"""TOAST_BURST info rows announce, the next is held back (kept, counted); the normal budget is its own; one more
	each TOAST_REFILL_MSEC; the budget never refills past TOAST_BURST; urgent always announces."""
	var feed := _feed()
	var clock := _clock_of(feed)
	for k: int in NoticesScript.TOAST_BURST:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Report %d" % k)
		assert_true(feed.is_announced(0), "report %d announced" % k)
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "One too many")
	assert_false(feed.is_announced(0), "held back")
	assert_equal(feed.throttled, 1, "counted")
	assert_equal(feed.count(), NoticesScript.TOAST_BURST + 1, "kept")
	feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded")
	assert_true(feed.is_announced(0), "a warning has its own budget")
	clock.advance(NoticesScript.TOAST_REFILL_MSEC - 1)
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Too soon")
	assert_false(feed.is_announced(0), "not yet")
	clock.advance(1)
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Now")
	assert_true(feed.is_announced(0), "one more after a refill")
	clock.advance(1000000)
	var announced: int = 0
	for k: int in NoticesScript.TOAST_BURST + 2:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "After a long while %d" % k)
		announced += 1 if feed.is_announced(0) else 0
	assert_equal(announced, NoticesScript.TOAST_BURST, "the budget tops up to a burst, no more")
	for k: int in 3:
		feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fire", "Fire %d" % k, "hall:%d" % k)
		assert_true(feed.is_announced(0), "urgent %d always" % k)
	assert_equal(feed.held_back(clock.now_msec(), 1000), 2, "two held back lately (the info flood's)")


func test_at_four_x_a_flood_of_reports_toasts_a_few_and_keeps_them_all() -> void:
	"""Forty reports in 20 s of real time (what 4x makes of 80 s of 1x): at most TOAST_BURST + 20000 /
	TOAST_REFILL_MSEC toast; all forty are kept."""
	var feed := _feed()
	var clock := _clock_of(feed)
	var announced: int = 0
	for k: int in 40:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Report %d" % k)
		announced += 1 if feed.is_announced(0) else 0
		clock.advance(500)
	@warning_ignore("integer_division")
	var most: int = NoticesScript.TOAST_BURST + 20000 / NoticesScript.TOAST_REFILL_MSEC
	assert_true(announced <= most, "%d toasted, at most %d" % [announced, most])
	assert_equal(feed.count(), 40, "every one kept")
	assert_equal(feed.throttled, 40 - announced, "the rest counted")


# --- the hook and the filters -----------------------------------------------------------------------------

func _hear(entry_id: int, tier: int, kind: StringName, text: String) -> void:
	"""Record one notice_posted."""
	_heard.append([entry_id, tier, kind, text])


func test_every_accepted_post_is_heard_once_with_its_id_tier_kind_and_text() -> void:
	"""A new row, a folded repeat and a grouped repeat are heard (the crash log's breadcrumbs); a refusal is not."""
	var feed := _feed()
	feed.notice_posted.connect(_hear)
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "")
	assert_equal(_heard.size(), 4, "four accepted, the empty one not")
	assert_equal(_heard[0], [1, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT], "the first")
	assert_equal(_heard[2], [2, NoticesScript.TIER_INFO, &"weather:Rain", "Rain"], "a fold: the same id")
	assert_equal(_heard[3][0], 1, "a grouped repeat: its first id")


func test_the_tier_filter_and_the_severity_filter_s_masks() -> void:
	"""tiers_into by place and tier mask; tier_mask_of maps All, Warnings and Notes."""
	var feed := _feed()
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox!")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 2 wet")
	feed.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "A tree felled")
	var out := PackedInt32Array()
	assert_equal(feed.tiers_into(NoticesScript.ALL_GROUPS, NoticesScript.ALL_TIERS, out), 3, "all")
	assert_equal(feed.tiers_into(NoticesScript.ALL_GROUPS, 1 << NoticesScript.TIER_URGENT, out), 1, "urgent")
	assert_equal(out[0], 2, "the fox, oldest")
	assert_equal(feed.tiers_into(1 << NoticesScript.GROUP_FARM, NoticesScript.ALL_TIERS, out), 1, "the farm's")
	assert_equal(feed.tiers_into(1 << NoticesScript.GROUP_WOODS, 1 << NoticesScript.TIER_NORMAL, out), 0, "none")
	assert_equal(NoticesScript.tier_mask_of(NoticesScript.SHOW_ALL), NoticesScript.ALL_TIERS, "all")
	assert_equal(NoticesScript.tier_mask_of(NoticesScript.SHOW_WARNINGS), 6, "urgent and normal")
	assert_equal(NoticesScript.tier_mask_of(NoticesScript.SHOW_NOTES), 1, "info")


# --- the strip --------------------------------------------------------------------------------------------

func _strip(feed: NoticesScript) -> StripScript:
	"""A news strip over `feed`, built out of the tree."""
	var strip: StripScript = _keep(StripScript.new()) as StripScript
	strip.configure(feed)
	return strip


func _jump_to_beds() -> JumpScript:
	"""A jump that finds beds 0-9 and records the selection in `_heard`."""
	var jump := JumpScript.new()
	jump.register(NoticesScript.TARGET_BED, func(bed: int) -> Vector3: return Vector3(bed, 0.0, 0.0) if bed < 10 \
		else Vector3.INF, func(bed: int) -> void: _heard.append(bed))
	return jump


func test_the_strip_draws_each_tier_at_its_own_weight_and_life() -> void:
	"""Urgent: heading face, clay (at the strip's URGENT_PX); normal: clay; info: ink; an urgent toast lasts a minute."""
	var feed := _feed()
	var strip := _strip(feed)
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Beans sown")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 2 wet")
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox!")
	assert_equal(strip.refresh(feed.now_msec()), 3, "three lines")
	var urgent: Label = strip.find_children("*", "Label", true, false)[1] as Label
	assert_equal(strip.line_tier(0), NoticesScript.TIER_URGENT, "urgent on top")
	assert_equal(urgent.get_theme_font_size(&"font_size"), StripScript.URGENT_PX, "the strip's urgent size")
	assert_equal(urgent.get_theme_font(&"font"), Styles.heading_font(), "the heading face")
	assert_equal(urgent.get_theme_color(&"font_color"), Palette.CLAY, "clay")
	assert_equal(strip.line_tier(1), NoticesScript.TIER_NORMAL, "normal next")
	assert_equal(strip.line_tier(2), NoticesScript.TIER_INFO, "info last")
	assert_equal(StripScript.lifetime_msec(NoticesScript.TIER_URGENT, 1), StripScript.URGENT_MSEC, "urgent: a minute")
	assert_equal(StripScript.lifetime_msec(NoticesScript.TIER_NORMAL, 1), StripScript.WARNING_MSEC, "normal")
	assert_equal(StripScript.lifetime_msec(NoticesScript.TIER_INFO, 0), StripScript.NOTE_MSEC, "info")
	assert_equal(strip.refresh(feed.now_msec() + StripScript.WARNING_MSEC + 1), 1, "the urgent one outlasts the rest")


func test_paint_tier_sets_and_clears_the_urgent_face() -> void:
	"""A label repainted from urgent to normal loses the heading face and size; info is ink."""
	var label := Label.new()
	StripScript.paint_tier(label, NoticesScript.TIER_URGENT, 14, 15)
	assert_true(label.has_theme_font_override(&"font"), "urgent face")
	assert_equal(label.get_theme_font_size(&"font_size"), 15, "the urgent size (the history's 15 px)")
	StripScript.paint_tier(label, NoticesScript.TIER_NORMAL, 14, 15)
	assert_false(label.has_theme_font_override(&"font"), "cleared")
	assert_equal(label.get_theme_font_size(&"font_size"), 14, "body size")
	StripScript.paint_tier(label, NoticesScript.TIER_INFO, 14, 15)
	assert_equal(label.get_theme_color(&"font_color"), Palette.INK, "info: ink")
	label.free()


func test_the_strip_leaves_out_quiet_lines_and_counts_them() -> void:
	"""Held back, snoozed and dismissed lines are not drawn; the title counts the held back and snoozed."""
	var feed := _feed()
	_calendar_of(feed)
	var strip := _strip(feed)
	for k: int in NoticesScript.TOAST_BURST + 2:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Report %d" % k)
	assert_equal(strip.refresh(feed.now_msec()), StripScript.LINES, "three drawn")
	assert_equal(strip.line_text(0), "Y1 Spring 1, 06:00 · Report %d" % (NoticesScript.TOAST_BURST - 1),
		"the newest announced")
	assert_equal(strip.held_shown(), 2, "two held back")
	assert_true(feed.snooze_entry(2), "the newest announced report's kind snoozed")
	strip.refresh(feed.now_msec())
	assert_equal(strip.held_shown(), 3, "the snoozed one too")
	assert_true(strip.line_text(0).ends_with("Report %d" % (NoticesScript.TOAST_BURST - 2)), strip.line_text(0))
	assert_true(strip.dismiss(0), "dismissed from the strip")
	assert_true(strip.line_text(0).ends_with("Report %d" % (NoticesScript.TOAST_BURST - 3)), strip.line_text(0))
	assert_true(feed.is_dismissed(3), "the feed's entry")
	assert_equal(strip.held_shown(), 3, "a dismissed one is not counted as held back")
	assert_false(strip.dismiss(StripScript.LINES - 1), "a hidden line has nothing to dismiss")


func test_the_strip_s_go_to_selects_and_its_buttons_take_no_focus() -> void:
	"""Go to shows only where the subject is found, and selects and centres it; × and Go to never take focus."""
	var feed := _feed()
	var strip := _strip(feed)
	strip.bind_jump(_jump_to_beds())
	_crows_on_bed(feed, 3)
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 99 wet", "", NoticesScript.TARGET_BED, 99)
	strip.refresh(feed.now_msec())
	assert_false(strip.line_can_go(0), "bed 99 is not found: no Go to")
	assert_true(strip.line_can_go(1), "bed 3 is")
	assert_true(strip.go_to(1), "gone to")
	assert_equal(_heard, [3], "bed 3 selected")
	assert_false(strip.go_to(0), "nothing to go to")
	assert_false(strip.go_to(StripScript.LINES - 1), "a hidden line")
	for slot: int in StripScript.LINES:
		for close: bool in [false, true]:
			assert_equal(strip.line_button(slot, close).focus_mode, Control.FOCUS_NONE, "no focus %d %s" % [slot, close])


func test_when_few_lines_fit_the_most_urgent_are_kept_newest_on_top() -> void:
	"""Room for one: the urgent line, though two newer ones came after it; room for two: the urgent and the newest
	warning over the info, drawn newest on top; a new post lets every line try again."""
	var feed := _feed()
	var strip := _strip(feed)
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox!")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 2 wet")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Beans sown")
	strip.refresh(feed.now_msec())
	strip.set("_fit_lines", 1)
	assert_equal(strip.refresh(feed.now_msec()), 1, "one line")
	assert_true(strip.line_text(0).contains("Urgent: A fox!"), strip.line_text(0))
	assert_equal(strip.lines_fitting(), 1, "one fits")
	strip.set("_fit_lines", 2)
	assert_equal(strip.refresh(feed.now_msec()), 2, "two lines")
	assert_true(strip.line_text(0).contains("Bed 2 wet"), "the newer warning on top: %s" % strip.line_text(0))
	assert_true(strip.line_text(1).contains("A fox!"), "the urgent under it: %s" % strip.line_text(1))
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Peas up")
	assert_equal(strip.refresh(feed.now_msec()), StripScript.LINES, "news: every line tries again")
	assert_equal(strip.lines_fitting(), StripScript.LINES, "reset")


# --- the history ------------------------------------------------------------------------------------------

func _history(shared: ServicesScript) -> HistoryScript:
	"""A history window over these services, built out of the tree."""
	var history: HistoryScript = _keep(HistoryScript.new()) as HistoryScript
	history.configure(shared.notices, shared.incidents, null)
	return history


func test_the_history_filters_by_tier_and_maps_the_severity_filter() -> void:
	"""All; Urgent alone; Info added; Urgent taken off; the last off shows All; Warnings and Notes as tier masks."""
	var shared := ServicesScript.new()
	var history := _history(shared)
	shared.notices.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox!")
	shared.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 2 wet")
	shared.notices.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "A tree felled")
	history.open()
	assert_equal(history.history_count(), 3, "all")
	history.set_tier_filter(NoticesScript.TIER_URGENT)
	assert_equal(history.history_count(), 1, "urgent alone")
	assert_equal(history.history_tier(0), NoticesScript.TIER_URGENT, "drawn urgent")
	history.set_tier_filter(NoticesScript.TIER_INFO)
	assert_equal(history.history_count(), 2, "urgent and info")
	history.set_tier_filter(NoticesScript.TIER_URGENT)
	assert_equal(history.tier_mask(), 1 << NoticesScript.TIER_INFO, "urgent off")
	history.set_tier_filter(NoticesScript.TIER_INFO)
	assert_equal(history.tier_mask(), NoticesScript.ALL_TIERS, "the last off: All")
	history.set_tier_filter(NoticesScript.TIER_NORMAL)
	history.set_tier_filter(-1)
	assert_equal(history.tier_mask(), NoticesScript.ALL_TIERS, "All pressed")
	history.set_severity_filter(NoticesScript.SHOW_WARNINGS)
	assert_equal(history.history_count(), 2, "warnings: urgent and normal")
	history.set_severity_filter(NoticesScript.SHOW_NOTES)
	assert_equal(history.history_count(), 1, "notes: info")


func test_the_history_s_snooze_wake_and_dismiss() -> void:
	"""A row's Snooze quiets its kind ("Wake" then, and the snoozed line names it with its hours); its Wake undoes it;
	Wake all; Dismiss marks the row and hides itself; an urgent row has no Snooze."""
	var shared := ServicesScript.new()
	var history := _history(shared)
	shared.notices.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox!")
	shared.notices.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, CROWS_TEXT, "bed:3")
	history.open()
	assert_false(history.history_verb(1, 2).visible, "no Snooze on the urgent row")
	assert_equal(history.history_verb(0, 2).text, "Snooze 6 h", "Snooze on the crows")
	assert_true(history.snooze_row(0), "snoozed")
	assert_equal(history.history_verb(0, 2).text, "Wake", "now Wake")
	assert_equal(history.snoozed_text(), "Snoozed: Crows at the barley (6 h)", "named, with its hours")
	var calendar := CalendarScript.new()
	shared.notices.bind_calendar(calendar)
	calendar.tick = 2 * HOUR
	history.refresh()
	assert_equal(history.snoozed_text(), "Snoozed: Crows at the barley (4 h)", "the hours left follow the game hour")
	assert_true(history.snooze_row(0), "woken")
	assert_equal(history.snoozed_text(), "", "nothing snoozed")
	history.snooze_row(0)
	assert_equal(history.wake_all(), 1, "Wake all")
	assert_true(history.dismiss_row(0), "dismissed")
	assert_true(history.history_text(0).ends_with(" — dismissed"), history.history_text(0))
	assert_false(history.history_verb(0, 3).visible, "no second Dismiss")
	assert_false(history.dismiss_row(0), "already")


# --- the sound --------------------------------------------------------------------------------------------

func _taps(feed: NoticesScript) -> TapsScript:
	"""An event map watching `feed` alone, with the shipped table's cues."""
	var taps := TapsScript.new()
	var table := SoundTable.new()
	table.load_from()
	taps.bind_table(table)
	taps.notices = feed
	taps.watch()
	return taps


func _warnings(taps: TapsScript) -> int:
	"""How many warning chimes this frame's events hold."""
	var n: int = 0
	for k: int in taps.event_count:
		n += 1 if taps.event_row[k] == taps.cue_row(TapsScript.C_WARNING) else 0
	return n


func test_the_tiers_sound_apart() -> void:
	"""Info: silent. Normal: one chime. Urgent: a chime, and a second URGENT_ECHO_MSEC later, once. A snoozed or
	grouped repeat: silent."""
	var feed := _feed()
	_calendar_of(feed)
	var taps := _taps(feed)
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, &"chilled", "Chilled")
	taps.poll(1000, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "info: silent")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"cold_home", "Cold home")
	taps.poll(1100, Vector2.ZERO)
	assert_equal(_warnings(taps), 1, "normal: one")
	taps.poll(1100 + TapsScript.URGENT_ECHO_MSEC, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "and no second")
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fire", "Fire")
	taps.poll(5000, Vector2.ZERO)
	assert_equal(_warnings(taps), 1, "urgent: the first")
	taps.poll(5000 + TapsScript.URGENT_ECHO_MSEC - 1, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "not yet")
	taps.poll(5000 + TapsScript.URGENT_ECHO_MSEC, Vector2.ZERO)
	assert_equal(_warnings(taps), 1, "the second")
	taps.poll(9000, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "once")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"cold_home", "Cold home")
	taps.poll(9100, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "a grouped repeat: silent")
	feed.snooze_kind(&"smoke", 6)
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"smoke", "Smoke")
	taps.poll(9200, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "a snoozed kind: silent")


func test_a_critical_incident_sounds_urgent_and_watching_again_forgets_the_echo() -> void:
	"""A critical incident raised: the urgent pair; a watch() before the second clears it."""
	var shared := ServicesScript.new()
	var taps := _taps(shared.notices)
	taps.incidents = shared.incidents
	taps.watch()
	shared.incidents.raise("water:rescue:1", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "Help!")
	taps.poll(1000, Vector2.ZERO)
	assert_equal(_warnings(taps), 1, "the first")
	taps.watch()
	taps.poll(1000 + TapsScript.URGENT_ECHO_MSEC, Vector2.ZERO)
	assert_equal(_warnings(taps), 0, "forgotten")


func test_polling_the_notices_allocates_no_objects() -> void:
	"""The per-frame notices poll, with rows to read and without, makes no Object."""
	var feed := _feed()
	var taps := _taps(feed)
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_WARNING, "Warm up")
	taps.poll(0, Vector2.ZERO)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for frame: int in 200:
		if frame % 50 == 0:
			feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_WARNING, "Warning %d" % frame)
		taps.poll(frame * 16, Vector2.ZERO)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), before, "no object made")
