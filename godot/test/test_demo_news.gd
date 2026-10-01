extends "res://test/framework/test_case.gd"
## The village news (decision 0331; review F11, F37, UX-011): the feed's history with its filters and "Go to",
## the news clock that stops toasts ageing while paused, incidents through their whole lifecycle (merge,
## recurrence, pin, snooze, dismiss, the sound hook), the top-centre card, the farm's standing conditions
## re-alerting after a genuine resolution (wet and dry), the farm's, woods' and tunnels' incidents, and the
## water's rescue incident beside C's latched air notices. No staged assets: placeholders throughout.

const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const StripScript := preload("res://demo/ui/demo_news_strip.gd")
const HistoryScript := preload("res://demo/ui/demo_news_history.gd")
const CardsScript := preload("res://demo/ui/demo_incident_cards.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const AlertsScript := preload("res://demo/farm/farm_alerts.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WaterFixture := preload("res://test/test_demo_water_play.gd")
const SafetyFixture := preload("res://test/test_demo_water_safety.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const DiveTaskScript := preload("res://demo/waterplay/dive_task.gd")
const TunnelWorld := preload("res://test/test_demo_tunnel_ext_world.gd")
const ForestryFixture := preload("res://test/test_demo_forestry.gd")
const NightFixture := preload("res://test/test_demo_night.gd")
const IntegrationFixture := preload("res://test/test_demo_integration.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const RADISH: int = 0
## Bed 4, the opening radish bed (decision 0205's F37 probe: 9800 -> 6000 -> 9800).
const BED_RADISH: int = 3
const BED_CLAY: int = 1
const BED_LOAM: int = 0
const WHEAT: int = 13
const WET: String = "Bed 4 (radish) is waterlogged and has stopped growing — Drain it"
const DRY: String = "Bed 4 (radish) is too dry to grow — water it"

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _services() -> ServicesScript:
	"""A fresh set of demo services: the feed and the incidents on one calendar and one news clock."""
	return ServicesScript.new()


# --- the feed: history, filters, targets, overflow ----------------------------------------------------

func test_the_feed_keeps_targets_and_filters_by_place_and_severity() -> void:
	"""Entries carry their target and incident; the history's place filter groups weather, threats and the crew as
	the Village; the severity filter splits warnings from notes; newest first."""
	var feed := NoticesScript.new()
	assert_equal(NoticesScript.CAPACITY, 128, "the feed grew from 32 to 128")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 2 wet", "", NoticesScript.TARGET_BED, 1, 7)
	feed.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "A tree felled", "", NoticesScript.TARGET_TREE, 4)
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	feed.post(NoticesScript.SOURCE_EVENTS, NoticesScript.LEVEL_WARNING, "A fox!")
	feed.post(NoticesScript.SOURCE_WATER, NoticesScript.LEVEL_WARNING, "In difficulty", "", NoticesScript.TARGET_RESIDENT, 2)
	assert_equal([feed.target_kind(4), feed.target_id(4), feed.incident(4)], [NoticesScript.TARGET_BED, 1, 7], "kept")
	assert_equal(feed.incident(0), NoticesScript.NO_INCIDENT, "no incident by default")
	var out := PackedInt32Array()
	assert_equal(feed.filtered_into(1 << NoticesScript.GROUP_VILLAGE, NoticesScript.SHOW_ALL, out), 2, "rain and the fox")
	assert_equal(feed.text(out[0]), "A fox!", "newest first")
	assert_equal(feed.filtered_into(NoticesScript.ALL_GROUPS, NoticesScript.SHOW_WARNINGS, out), 3, "three warnings")
	assert_equal(feed.filtered_into(NoticesScript.ALL_GROUPS, NoticesScript.SHOW_NOTES, out), 2, "two notes")
	var mask: int = (1 << NoticesScript.GROUP_FARM) | (1 << NoticesScript.GROUP_WOODS)
	assert_equal(feed.filtered_into(mask, NoticesScript.SHOW_NOTES, out), 1, "farm or woods, notes: the tree")
	assert_equal(feed.text(out[0]), "A tree felled", "the tree")
	assert_false(feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "x", "", 9, 0), "no unknown target")


func test_overflow_keeps_unresolved_and_pinned_incidents_and_lets_the_rest_go() -> void:
	"""The feed full of crew chatter keeps the newest entry of each incident still open or pinned; a resolved,
	unpinned incident's entry goes like any other."""
	var shared := _services()
	var feed: NoticesScript = shared.notices
	var incidents: IncidentsScript = shared.incidents
	var open: int = incidents.report("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 2 wet")
	var pinned: int = incidents.report("woods:windthrow:3", NoticesScript.SOURCE_WOODS, IncidentsScript.SEVERITY_WARNING,
		"A tree blew down")
	var settled: int = incidents.report("farm:dry:0", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 1 dry")
	incidents.pin(pinned, true)
	incidents.resolve("woods:windthrow:3")
	incidents.resolve("farm:dry:0")
	for k: int in NoticesScript.CAPACITY * 2:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "chatter %d" % k)
	assert_equal(feed.count(), NoticesScript.CAPACITY, "still full, no fuller")
	assert_true(feed.has_text("Bed 2 wet"), "the unresolved incident's entry kept")
	assert_true(feed.has_text("A tree blew down"), "the pinned one's kept, resolved or not")
	assert_false(feed.has_text("Bed 1 dry"), "the resolved, unpinned one went")
	assert_equal(feed.text(0), "chatter %d" % (NoticesScript.CAPACITY * 2 - 1), "the newest is newest")
	assert_false(feed.has_text("chatter %d" % (NoticesScript.CAPACITY + 1)), "the oldest chatter went first")
	incidents.resolve("farm:wet:1")
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "one more")
	assert_false(feed.has_text("Bed 2 wet"), "resolved now, it goes at the next overflow")
	assert_true(open != settled, "distinct serials")


func test_an_incident_holds_only_its_newest_entry() -> void:
	"""A merged repeat posts again; overflow keeps only the newest entry of the incident, not every one."""
	var shared := _services()
	var feed: NoticesScript = shared.notices
	for night: int in 3:
		shared.incidents.report("village:no_bed", NoticesScript.SOURCE_CREW, IncidentsScript.SEVERITY_WARNING,
			"No bed, night %d" % night)
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "dusk %d" % night)
	for k: int in NoticesScript.CAPACITY:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "chatter %d" % k)
	assert_true(feed.has_text("No bed, night 2"), "the newest kept")
	assert_false(feed.has_text("No bed, night 0"), "an older one let go")


# --- the news clock and the strip ----------------------------------------------------------------------

func test_the_news_clock_stands_still_while_paused() -> void:
	"""Real time counts only while unpaused; the first sync only starts it; a clock going back counts nothing."""
	var clock := NewsClockScript.new()
	clock.sync(1000, false)
	assert_equal(clock.now_msec(), 0, "the first sync starts it")
	clock.sync(4000, false)
	assert_equal(clock.now_msec(), 3000, "3 s unpaused")
	clock.sync(64000, true)
	assert_equal(clock.now_msec(), 3000, "a minute paused counts nothing")
	clock.sync(65000, false)
	assert_equal(clock.now_msec(), 4000, "on again from where it stood")
	clock.sync(60000, false)
	assert_equal(clock.now_msec(), 4000, "backwards counts nothing")


func test_toasts_do_not_expire_while_paused() -> void:
	"""F11: a warning posted, then a long pause: the strip still shows it when play resumes; it goes only after
	WARNING_MSEC of unpaused time. The strip's own clock tick (`tick_news`, what its frame calls) on given real times."""
	var shared := _services()
	var paused: Array[bool] = [false]
	var strip: StripScript = _keep(StripScript.new()) as StripScript
	strip.configure(shared.notices)
	strip.bind_news(shared.incidents, shared.news_clock, func() -> bool: return paused[0])
	strip.tick_news(1000)
	shared.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Frost tonight")
	paused[0] = true
	strip.tick_news(1000 + 120000)
	assert_equal(strip.refresh(shared.notices.now_msec()), 1, "two minutes paused: still shown")
	paused[0] = false
	strip.tick_news(1000 + 120000 + StripScript.WARNING_MSEC - 1000)
	assert_equal(strip.refresh(shared.notices.now_msec()), 1, "resumed: it has its time left")
	strip.tick_news(1000 + 120000 + StripScript.WARNING_MSEC + 1000)
	assert_equal(strip.refresh(shared.notices.now_msec()), 0, "then it goes, unpaused")
	assert_true(shared.notices.has_text("Frost tonight"), "and is still in the history")


func test_the_strip_counts_what_needs_attention_and_opens_the_history() -> void:
	"""With no fresh toast the strip stays up while an incident is unresolved, saying how many; its button asks
	for the history; resolved, the strip goes."""
	var shared := _services()
	var strip: StripScript = _keep(StripScript.new()) as StripScript
	strip.configure(shared.notices)
	strip.bind_news(shared.incidents, shared.news_clock, Callable())
	shared.incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 2 wet")
	assert_equal(strip.refresh(shared.notices.now_msec()), 0, "no toast")
	assert_true(strip.is_shown(), "but shown")
	assert_equal(strip.history_button().text, "1 needs attention — Village news history (N)", "the count")
	var asked: Array[int] = [0]
	strip.history_wanted.connect(func() -> void: asked[0] += 1)
	strip.history_button().pressed.emit()
	assert_equal(asked[0], 1, "the history asked for")
	shared.incidents.resolve("farm:wet:1")
	strip.refresh(shared.notices.now_msec())
	assert_false(strip.is_shown(), "resolved: hidden")


# --- incidents: lifecycle, merge, recurrence, pin, snooze, dismiss, cues ------------------------------

func test_an_incident_runs_needs_decision_assigned_recovering_resolved() -> void:
	"""The watch moves the state on each sweep; RESOLVED resolves it once, with one resolved cue; the critical
	raise cued once."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var cues: Array[Vector2i] = []
	incidents.incident_cue.connect(func(cue: int, serial: int, _severity: int) -> void: cues.append(Vector2i(cue, serial)))
	var state: Array[int] = [IncidentsScript.STATE_NEEDS_DECISION]
	var serial: int = incidents.raise("water:rescue:2", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL,
		"Otter in difficulty", NoticesScript.TARGET_RESIDENT, 2, func() -> int: return state[0])
	assert_equal(incidents.last_raise, IncidentsScript.RAISE_NEW, "new")
	assert_equal(incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "needs a decision")
	for next: int in [IncidentsScript.STATE_ASSIGNED, IncidentsScript.STATE_RECOVERING]:
		state[0] = next
		assert_equal(incidents.sweep(), 1, "one changed")
		assert_equal(incidents.state_of(serial), next, IncidentsScript.STATE_WORDS[next])
	assert_equal(incidents.sweep(), 0, "nothing changed")
	state[0] = IncidentsScript.STATE_RESOLVED
	incidents.sweep()
	assert_false(incidents.is_unresolved(serial), "resolved")
	assert_false(incidents.resolve("water:rescue:2"), "only once")
	assert_equal(cues, [Vector2i(IncidentsScript.CUE_CRITICAL_RAISED, serial), Vector2i(IncidentsScript.CUE_RESOLVED, serial)],
		"one raised cue, one resolved cue")
	assert_equal(incidents.card_title(serial), "Critical · Water · Resolved", "worded")


func test_repeats_merge_into_one_card_and_a_recurrence_reopens_it() -> void:
	"""Raised again while open: merged (count up, newest text, no cue, still dismissed if dismissed). Raised after
	it resolved: the same card back needing a decision, counted, undismissed, cued again."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var cues: Array[int] = [0]
	incidents.incident_cue.connect(func(cue: int, _serial: int, _severity: int) -> void:
		cues[0] += 1 if cue == IncidentsScript.CUE_CRITICAL_RAISED else 0)
	var serial: int = incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "A fox")
	incidents.acknowledge(serial)
	assert_equal(incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "A fox, closer"),
		serial, "the same incident")
	assert_equal(incidents.last_raise, IncidentsScript.RAISE_MERGED, "merged")
	assert_equal(incidents.count_of(serial), 2, "counted")
	assert_equal(incidents.text_of(serial), "A fox, closer", "the newest words")
	assert_true(incidents.is_acknowledged(serial), "a repeat is no change: still dismissed")
	assert_equal(cues[0], 1, "no cue for a repeat")
	incidents.resolve("threat")
	incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "A fox again")
	assert_equal(incidents.last_raise, IncidentsScript.RAISE_AGAIN, "a recurrence")
	assert_equal(incidents.count_of(serial), 3, "counted on the same card")
	assert_equal(incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "needs a decision again")
	assert_false(incidents.is_acknowledged(serial), "undismissed")
	assert_equal(cues[0], 2, "cued again")
	assert_equal(incidents.card_title(serial), "Critical · Threat · Needs a decision (×3)", "the count worded")
	assert_equal(incidents.raise("", NoticesScript.SOURCE_FARM, 0, "x"), IncidentsScript.NO_SERIAL, "no key, refused")
	assert_equal(incidents.raise("k", NoticesScript.SOURCE_FARM, 3, "x"), IncidentsScript.NO_SERIAL, "no such severity")


func test_the_queue_holds_critical_and_pinned_cards_in_order() -> void:
	"""Critical incidents queue (earliest first); a warning joins only when pinned, and a pinned card goes to the
	front; dismissed leaves; resolved lingers RESOLVED_LINGER_MSEC then leaves -- unless pinned."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var first: int = incidents.raise("water:rescue:1", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "One")
	shared.news_clock.advance(10)
	var second: int = incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "Fox")
	var warning: int = incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Wet")
	var queue := PackedInt32Array()
	assert_equal(incidents.queue_into(queue), 2, "the two critical")
	assert_equal(queue, PackedInt32Array([first, second]), "earliest first")
	incidents.pin(warning, true)
	incidents.queue_into(queue)
	assert_equal(queue, PackedInt32Array([warning, first, second]), "the pinned warning first")
	incidents.acknowledge(first)
	incidents.queue_into(queue)
	assert_equal(queue, PackedInt32Array([warning, second]), "dismissed: out")
	incidents.resolve("threat")
	incidents.resolve("farm:wet:1")
	assert_equal(incidents.queue_into(queue), 2, "both linger: the resolved critical, the pinned")
	shared.news_clock.advance(IncidentsScript.RESOLVED_LINGER_MSEC + 1)
	incidents.queue_into(queue)
	assert_equal(queue, PackedInt32Array([warning]), "the linger over; the pinned one stays")
	var attention := PackedInt32Array()
	assert_equal(incidents.attention_into(attention), 2, "needs attention: the dismissed one (still open), the pinned")
	assert_equal(incidents.unresolved_count(), 1, "one open")


func test_a_snooze_hides_a_card_for_unpaused_time_only() -> void:
	"""Snoozed, the card leaves the queue; a pause does not run the snooze down; SNOOZE_MSEC unpaused later it is
	back while still open."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var serial: int = incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "Fox")
	assert_true(incidents.snooze(serial), "snoozed")
	assert_false(incidents.in_queue(serial), "out of the queue")
	shared.news_clock.sync(0, false)
	shared.news_clock.sync(IncidentsScript.SNOOZE_MSEC * 3, true)
	assert_true(incidents.is_snoozed(serial), "still snoozed after a long pause")
	shared.news_clock.advance(IncidentsScript.SNOOZE_MSEC)
	assert_true(incidents.in_queue(serial), "back")
	assert_false(incidents.snooze(serial, 0), "no zero snooze")


func test_rows_are_reused_from_the_longest_resolved_and_never_from_open_or_pinned() -> void:
	"""Every row full: a new incident takes the row resolved longest ago and unpinned; with none, it is refused."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	for k: int in IncidentsScript.MAX_INCIDENTS:
		incidents.raise("k%d" % k, NoticesScript.SOURCE_CREW, IncidentsScript.SEVERITY_ROUTINE, "x")
	assert_equal(incidents.raise("more", NoticesScript.SOURCE_CREW, 0, "x"), IncidentsScript.NO_SERIAL, "all open: refused")
	incidents.pin(incidents.serial_of("k0"), true)
	incidents.resolve("k0")
	shared.news_clock.advance(5)
	incidents.resolve("k1")
	shared.news_clock.advance(5)
	incidents.resolve("k2")
	assert_true(incidents.raise("more", NoticesScript.SOURCE_CREW, 0, "x") != IncidentsScript.NO_SERIAL, "taken")
	assert_equal(incidents.serial_of("k1"), IncidentsScript.NO_SERIAL, "the longest resolved, unpinned row reused")
	assert_true(incidents.serial_of("k0") != IncidentsScript.NO_SERIAL, "the pinned one kept")
	assert_true(incidents.serial_of("k2") != IncidentsScript.NO_SERIAL, "the later resolved one kept")


# --- the top-centre card ------------------------------------------------------------------------------

func test_the_card_shows_the_front_of_the_queue_and_its_verbs_work() -> void:
	"""One card, "1 of 2"; Pin, Snooze and Dismiss on it; yields while asked; Go to selects through the jump."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var jump := JumpScript.new()
	var picked: Array[int] = [-1]
	jump.register(NoticesScript.TARGET_RESIDENT, func(who: int) -> Vector3: return Vector3(who, 0.0, 1.0),
		func(who: int) -> void: picked[0] = who)
	var cards: CardsScript = _keep(CardsScript.new()) as CardsScript
	cards.configure(incidents, jump)
	assert_false(cards.refresh(), "nothing queued: hidden")
	var victim: int = incidents.report("water:rescue:2", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL,
		"Otter in difficulty", "", NoticesScript.TARGET_RESIDENT, 2)
	incidents.report("water:rescue:2", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "Otter, breath 40%",
		"", NoticesScript.TARGET_RESIDENT, 2)
	shared.news_clock.advance(10)
	var fox: int = incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "A fox")
	assert_true(cards.refresh(), "shown")
	assert_equal(cards.shown_serial(), victim, "the earliest first")
	assert_equal(cards.title_text(), "Critical · Water · Needs a decision (×2)", "merged repeat counted")
	assert_equal(cards.queue_text(), "1 of 2", "the queue")
	assert_true(cards.body_text().ends_with("Otter, breath 40%"), "the newest words")
	assert_true(cards.go_to(), "go to")
	assert_equal(picked[0], 2, "the resident selected")
	assert_true(cards.snooze(), "snoozed")
	assert_equal(cards.shown_serial(), fox, "the next one")
	assert_true(cards.toggle_pin(), "pinned")
	assert_true(incidents.is_pinned(fox), "pinned")
	assert_true(cards.dismiss(), "dismissed")
	assert_false(cards.is_shown(), "nothing left showing")
	incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "Fox, still")
	assert_false(cards.refresh(), "a repeat of a dismissed card stays dismissed")
	incidents.resolve("threat")
	incidents.raise("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "Fox again")
	var yielding: Array[bool] = [true]
	cards.hide_while(func() -> bool: return yielding[0])
	assert_false(cards.refresh(), "yields to what it is told to")
	yielding[0] = false
	assert_true(cards.refresh(), "then shows")


# --- the history window --------------------------------------------------------------------------------

func _history_rig(shared: ServicesScript, jump: JumpScript) -> HistoryScript:
	"""A history window over these services, built out of the tree."""
	var history: HistoryScript = _keep(HistoryScript.new()) as HistoryScript
	history.configure(shared.notices, shared.incidents, jump)
	return history


func test_the_history_filters_by_place_and_severity_and_lists_what_needs_attention() -> void:
	"""Every kept entry, placed and dated; the place filter (All, then one place, then another added, then the
	last one off shows All); the severity filter; "still open" on an open incident's entry; the attention list
	filtered by place, with "No active problems" when empty."""
	var shared := _services()
	var history := _history_rig(shared, null)
	shared.incidents.report("farm:wet:3", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, WET, "",
		NoticesScript.TARGET_BED, 3)
	shared.notices.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_NOTE, "A tree felled")
	shared.notices.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "Rain")
	history.open()
	assert_true(history.is_open(), "open")
	assert_equal(history.history_count(), 3, "all three")
	assert_equal(history.history_text(2), "Y1 Spring 1, 06:00 · Farm · Warning: %s — still open" % WET,
		"dated, placed, worded, still open")
	assert_equal(history.attention_count(), 1, "one needs attention")
	history.set_group_filter(NoticesScript.GROUP_WOODS)
	assert_equal(history.history_count(), 1, "woods alone")
	assert_equal(history.attention_count(), 0, "no woods incident")
	history.set_group_filter(NoticesScript.GROUP_VILLAGE)
	assert_equal(history.history_count(), 2, "woods and village")
	history.set_group_filter(NoticesScript.GROUP_WOODS)
	history.set_group_filter(NoticesScript.GROUP_VILLAGE)
	assert_equal(history.group_mask(), NoticesScript.ALL_GROUPS, "the last place off: All")
	history.set_severity_filter(NoticesScript.SHOW_WARNINGS)
	assert_equal(history.history_count(), 1, "the one warning")
	history.set_severity_filter(NoticesScript.SHOW_NOTES)
	assert_equal(history.history_count(), 2, "the two notes")
	shared.incidents.resolve("farm:wet:3")
	history.set_severity_filter(NoticesScript.SHOW_ALL)
	assert_equal(history.attention_count(), 0, "resolved: no active problems")
	assert_equal(history.history_text(2), "Y1 Spring 1, 06:00 · Farm · Warning: " + WET, "resolved: the entry stays, not open")


func test_the_history_s_go_to_selects_and_centres_and_closes() -> void:
	"""Go to on an entry with a target selects it, eases the camera over it and closes the window; an entry with
	no target, or one that is gone, offers none."""
	var shared := _services()
	var camera: CameraScript = _keep(CameraScript.new()) as CameraScript
	camera.configure(AABB(Vector3(-40.0, 0.0, -40.0), Vector3(80.0, 0.0, 80.0)), Vector3.ZERO)
	var jump := JumpScript.new()
	jump.bind_camera(camera)
	var selected: Array[int] = [-1]
	jump.register(NoticesScript.TARGET_BED, func(bed: int) -> Vector3: return JumpScript.bed_point(bed),
		func(bed: int) -> void: selected[0] = bed)
	var history := _history_rig(shared, jump)
	shared.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, WET, "", NoticesScript.TARGET_BED, BED_RADISH)
	shared.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Gone", "", NoticesScript.TARGET_BED, 99)
	shared.notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Dusk")
	history.open()
	assert_false(history.history_can_go(0), "no target: no Go to")
	assert_false(history.history_can_go(1), "no such bed: no Go to")
	assert_true(history.history_can_go(2), "the bed")
	history.press_history_go(2)
	assert_equal(selected[0], BED_RADISH, "the bed selected")
	var centre: Vector2 = Catalog.bed_centre_m(BED_RADISH)
	assert_equal(camera.target_focus(), Vector3(centre.x, 0.0, centre.y), "the camera eases over it")
	assert_false(history.is_open(), "closed so the bed is not under it")


func test_the_hud_history_command_toggles_the_village_news() -> void:
	"""Routed from the shell: its history just opened -> the window toggles and the shell's is to close; its history
	just closed (from a settlement card) -> the window closes too."""
	var shared := _services()
	var history := _history_rig(shared, null)
	assert_true(history.take_trigger(true), "N: close the shell's")
	assert_true(history.is_open(), "the village news opened")
	assert_true(history.take_trigger(true), "N again")
	assert_false(history.is_open(), "toggled shut")
	history.open()
	assert_false(history.take_trigger(false), "the shell's closed: nothing to close")
	assert_false(history.is_open(), "the window closed with it")
	var asked: Array[int] = [0]
	history.set_settlement(func() -> void: asked[0] += 1)
	history.open()
	history._on_settlement()
	assert_equal(asked[0], 1, "Settlement notices opens the shell's")
	assert_false(history.is_open(), "and this closes")


func test_the_jump_points_and_refusals() -> void:
	"""Each kind's point helper, INF for what is not there, and no jump without a registered kind."""
	var jump := JumpScript.new()
	assert_false(jump.jump(NoticesScript.TARGET_BED, 1), "unregistered")
	assert_false(jump.can_jump(NoticesScript.TARGET_NONE, 0), "no target")
	assert_false(JumpScript.bed_point(Catalog.BED_COUNT).is_finite(), "no such bed")
	var network := GraphScript.new()
	assert_false(JumpScript.tunnel_point(network, 0).is_finite(), "no tunnel there")
	assert_false(JumpScript.tunnel_point(network, -1).is_finite(), "no slot -1")
	assert_false(JumpScript.bridge_point(BridgesScript.new(), 0).is_finite(), "no bridge planned")
	assert_false(JumpScript.tree_point(null, 0).is_finite(), "no stand")
	jump.register(NoticesScript.TARGET_TREE, func(t: int) -> Vector3: return Vector3(t, 0.0, 0.0), Callable())
	assert_true(jump.jump(NoticesScript.TARGET_TREE, 5), "a tree")
	assert_equal(jump.last_point, Vector3(5.0, 0.0, 0.0), "there")


# --- F37: the farm's standing conditions re-alert after a genuine resolution --------------------------

func _radish_farm() -> SimScript:
	"""The opening farm with radish standing in bed 4 (growing)."""
	var sim := SimScript.new()
	sim.choose(BED_RADISH, RADISH)
	return sim


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


func _collect(sim: SimScript, alerts: AlertsScript) -> PackedStringArray:
	"""One hourly alert pass's lines."""
	var lines := PackedStringArray()
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	return lines


func test_wet_drained_wet_again_in_the_same_season_re_alerts() -> void:
	"""F37, the review's own probe (9800 -> 6000 -> 9800 on bed 4) with time between: the first waterlogging
	warns; drained, it is recovering; once it has stayed back in band REARM_HOURS it resolves and re-arms; wet
	again the same season warns again, and its incident comes back counted."""
	var shared := _services()
	var sim := _radish_farm()
	var alerts := AlertsScript.new()
	alerts.bind_incidents(shared.incidents)
	_set_moisture(sim, BED_RADISH, 9800)
	assert_equal(_collect(sim, alerts), PackedStringArray([WET]), "waterlogged: warned")
	var serial: int = alerts.serials[0]
	assert_equal(alerts.targets[0], BED_RADISH, "on its bed")
	assert_equal(_collect(sim, alerts), PackedStringArray(), "still wet: not said again")
	_set_moisture(sim, BED_RADISH, 6000)
	assert_equal(_collect(sim, alerts), PackedStringArray(), "drained: nothing said")
	assert_equal(alerts.condition_state(BED_RADISH, AlertsScript.COND_WET), IncidentsScript.STATE_RECOVERING, "recovering")
	shared.incidents.sweep()
	assert_equal(shared.incidents.state_of(serial), IncidentsScript.STATE_RECOVERING, "the card says so")
	sim.advance_usec(AlertsScript.REARM_HOURS * HOUR_USEC)
	_set_moisture(sim, BED_RADISH, 6000)
	_collect(sim, alerts)
	assert_false(shared.incidents.is_unresolved(serial), "back in band long enough: resolved")
	assert_equal(alerts.condition_phase(BED_RADISH, AlertsScript.COND_WET), AlertsScript.PHASE_IDLE, "re-armed")
	sim.advance_usec(HOUR_USEC)
	_set_moisture(sim, BED_RADISH, 9800)
	assert_equal(_collect(sim, alerts), PackedStringArray([WET]), "wet again, same season: warned again")
	assert_equal(alerts.serials[0], serial, "the same card")
	assert_equal(shared.incidents.count_of(serial), 2, "counted twice")
	assert_equal(sim.season(), 0, "all in the first season")


func test_a_bed_hovering_at_its_band_edge_does_not_flap() -> void:
	"""Back to wet within REARM_HOURS of draining is the same occurrence: active again, nothing said, the card not
	resolved."""
	var shared := _services()
	var sim := _radish_farm()
	var alerts := AlertsScript.new()
	alerts.bind_incidents(shared.incidents)
	_set_moisture(sim, BED_RADISH, 9800)
	_collect(sim, alerts)
	var serial: int = alerts.serials[0]
	_set_moisture(sim, BED_RADISH, 6000)
	_collect(sim, alerts)
	sim.advance_usec((AlertsScript.REARM_HOURS - 1) * HOUR_USEC)
	_set_moisture(sim, BED_RADISH, 9800)
	assert_equal(_collect(sim, alerts), PackedStringArray(), "within the cooldown: quiet")
	assert_true(shared.incidents.is_unresolved(serial), "never resolved")
	assert_equal(shared.incidents.count_of(serial), 1, "one occurrence")
	assert_equal(alerts.condition_state(BED_RADISH, AlertsScript.COND_WET), IncidentsScript.STATE_NEEDS_DECISION, "active")


func test_drought_dry_watered_dry_again_re_alerts_and_a_remedy_job_assigns() -> void:
	"""F37 for drought: too dry warns (ASSIGNED once a Water job is on the bed); watered back into band for
	REARM_HOURS it resolves; dry again warns again. A bed that stops growing ends the condition at once."""
	var shared := _services()
	var sim := _radish_farm()
	var alerts := AlertsScript.new()
	var watering: Array[bool] = [false]
	alerts.bind_incidents(shared.incidents, func(bed: int, cond: int) -> bool:
		return watering[0] and bed == BED_RADISH and cond == AlertsScript.COND_DRY)
	_set_moisture(sim, BED_RADISH, 0)
	assert_equal(_collect(sim, alerts), PackedStringArray([DRY]), "too dry: warned")
	var serial: int = alerts.serials[0]
	watering[0] = true
	shared.incidents.sweep()
	assert_equal(shared.incidents.state_of(serial), IncidentsScript.STATE_ASSIGNED, "a Water job on it: assigned")
	_set_moisture(sim, BED_RADISH, 5000)
	_collect(sim, alerts)
	sim.advance_usec(AlertsScript.REARM_HOURS * HOUR_USEC)
	_set_moisture(sim, BED_RADISH, 5000)
	_collect(sim, alerts)
	assert_false(shared.incidents.is_unresolved(serial), "resolved")
	_set_moisture(sim, BED_RADISH, 0)
	assert_equal(_collect(sim, alerts), PackedStringArray([DRY]), "dry again: warned again")
	assert_equal(shared.incidents.count_of(serial), 2, "the same card, counted")


func test_a_worn_out_bed_sown_ends_the_condition_at_once() -> void:
	"""Worn out is a routine incident on its bed; sown, the condition no longer applies and resolves without the
	cooldown."""
	var shared := _services()
	var sim := SimScript.new()
	var alerts := AlertsScript.new()
	alerts.bind_incidents(shared.incidents)
	sim.farming()._set_tile_fertility(sim.farming().tile_of(sim.slot_of(BED_LOAM)).value, 3900)
	assert_equal(_collect(sim, alerts), PackedStringArray(["Bed 1 is worn out (fertility 39%) — compost it or rest it fallow"]),
		"worn out")
	var serial: int = alerts.serials[0]
	assert_equal(shared.incidents.severity_of(serial), IncidentsScript.SEVERITY_ROUTINE, "routine")
	sim.choose(BED_LOAM, WHEAT)
	assert_true(sim.sow_start(BED_LOAM).ok and sim.sow_finish(BED_LOAM).ok, "sown")
	_collect(sim, alerts)
	assert_false(shared.incidents.is_unresolved(serial), "resolved at once")


func test_the_frost_incident_lasts_the_night_and_blight_lasts_until_cleared() -> void:
	"""Frost tonight is an incident from the warning until no frost is due; a blight outbreak's incident resolves
	when the bed is no longer blighted."""
	var shared := _services()
	var sim := SimScript.new()
	var alerts := AlertsScript.new()
	alerts.bind_incidents(shared.incidents)
	sim.advance_usec((24 * 9 + 6) * HOUR_USEC)
	var lines := _collect(sim, alerts)
	assert_true(lines.has(AlertsScript.frost_text(0, 10)), "the frost warning: %s" % lines)
	var frost: int = shared.incidents.serial_of(AlertsScript.FROST_KEY)
	assert_true(shared.incidents.is_unresolved(frost), "an open incident")
	sim.advance_usec(12 * HOUR_USEC)
	_collect(sim, alerts)
	assert_true(shared.incidents.is_unresolved(frost), "midnight before the frost: still due")
	sim.advance_usec(6 * HOUR_USEC)
	_collect(sim, alerts)
	assert_false(shared.incidents.is_unresolved(frost), "past the frost hours: resolved")
	sim = _radish_farm()
	sim.infect_for_test(BED_RADISH)
	alerts.collect_into(sim, PackedInt32Array([SimScript.EVENT_BLIGHT, BED_RADISH]), PackedInt32Array(), PackedStringArray())
	var blight: int = shared.incidents.serial_of("farm:blight:%d" % BED_RADISH)
	assert_true(shared.incidents.is_unresolved(blight), "blight raised")
	assert_equal(alerts.targets[0], BED_RADISH, "on its bed")
	assert_equal(alerts.blight_state(BED_RADISH), IncidentsScript.STATE_NEEDS_DECISION, "needs a Clear")
	_collect(sim, alerts)
	assert_true(shared.incidents.is_unresolved(blight), "still blighted: open")
	assert_true(sim.clear(BED_RADISH).ok, "cleared")
	_collect(sim, alerts)
	assert_false(shared.incidents.is_unresolved(blight), "cleared: resolved")
	sim.choose(BED_RADISH, RADISH)
	assert_true(sim.sow_start(BED_RADISH).ok and sim.sow_finish(BED_RADISH).ok, "sown again")
	sim.infect_for_test(BED_RADISH)
	var again := PackedStringArray()
	alerts.collect_into(sim, PackedInt32Array([SimScript.EVENT_BLIGHT, BED_RADISH]), PackedInt32Array(), again)
	assert_equal(again, PackedStringArray(), "blight back the same day: today's line already said")
	assert_true(shared.incidents.is_unresolved(blight), "but the incident is open again")


# --- the water's rescue incident and C's latched air notices ------------------------------------------

func test_a_rescue_is_a_critical_incident_and_air_out_is_still_said_once() -> void:
	"""Decision 0231's held-below victim with nobody able to come: one CRITICAL incident on the resident, needing
	a decision while nobody answers, resolved when the water brings it ashore -- one raised cue, one resolved
	cue -- while the feed still says "air ran out" once (the latch is untouched)."""
	var safety := SafetyFixture.new()
	safety.before_each()
	var rig: WaterFixture.Rig = safety._fx._rig()
	var play := rig.play
	var cues := PackedInt32Array()
	play.services.incidents.incident_cue.connect(func(cue: int, _serial: int, _severity: int) -> void: cues.append(cue))
	var task: DiveTaskScript = safety._diver_at_the_pond(rig, 0, SafetyFixture.POND_WEST)
	assert_true(safety._fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	for who: int in range(1, 6):
		safety._fx._brain(rig, who).water_hold = true
	play.cramp(PackedInt32Array([0]))
	play.sync_incidents()
	var serial: int = play.services.incidents.serial_of("water:rescue:0")
	assert_equal(play.services.incidents.severity_of(serial), IncidentsScript.SEVERITY_CRITICAL, "critical")
	assert_equal(play.services.incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "nobody answering")
	assert_equal([play.services.incidents.target_kind_of(serial), play.services.incidents.target_id_of(serial)],
		[NoticesScript.TARGET_RESIDENT, 0], "on the resident")
	assert_true(play.services.incidents.text_of(serial).begins_with("Placeholder 0"), "C's incident line")
	var ashore: bool = safety._fx._run(rig, func() -> bool:
		play.sync_incidents()
		return safety._fx._brain(rig, 0).task is Tasks.RestTask)
	play.sync_incidents()
	assert_true(ashore, "washed ashore")
	assert_false(play.services.incidents.is_unresolved(serial), "resolved")
	assert_equal(cues, PackedInt32Array([IncidentsScript.CUE_CRITICAL_RAISED, IncidentsScript.CUE_RESOLVED]), "two cues")
	assert_equal(safety._count_kept("air ran out"), 1, "air out said once")
	assert_equal(safety._count_kept("low on air"), 0, "no advisory for one already in difficulty")
	safety.after_each()


# --- the modules' incidents: tunnels, threats, woods, beds, the farm crew ------------------------------

func test_a_flooded_tunnel_stays_an_incident_until_reopened_and_a_threat_until_it_is_over() -> void:
	"""A flood closes a dug tunnel: a WARNING incident on the tunnel, its feed entry linked, needing a decision
	until a job is on it, resolved once reopened. The test threat is a CRITICAL incident, assigned while it lasts
	(everyone is sent to shelter) and resolved when it is over."""
	var fx := TunnelWorld.new()
	fx.before_each()
	var space: CastSpaceScript = fx._space([])
	var species := PackedStringArray(["Mouse"])
	var brains: Array[BrainScript] = fx._cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works: WorksScript = fx._works(space, brains, species)
	var incidents: IncidentsScript = fx._services.incidents
	var bore: int = fx._open_tunnel(space, [Vector2i(512, 512), Vector2i(12800, 512)])[1]
	works._act_on(bore, HazardsScript.EVENT_FLOODED)
	var serial: int = incidents.serial_of("tunnel:flooded:%d:%d" % [bore, space.tunnels.generation[bore]])
	assert_true(incidents.is_unresolved(serial), "an open incident")
	assert_equal([incidents.target_kind_of(serial), incidents.target_id_of(serial)], [NoticesScript.TARGET_TUNNEL, bore],
		"on the tunnel")
	assert_equal(fx._services.notices.incident(0), serial, "the feed's entry reports it")
	incidents.sweep()
	assert_equal(incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "closed, nobody on it")
	space.tunnels.reopen(bore)
	incidents.sweep()
	assert_false(incidents.is_unresolved(serial), "reopened: resolved")
	assert_true(works.start_test_event(), "a threat")
	var threat: int = incidents.serial_of(WorksScript.THREAT_KEY)
	assert_equal(incidents.severity_of(threat), IncidentsScript.SEVERITY_CRITICAL, "critical")
	incidents.sweep()
	assert_equal(incidents.state_of(threat), IncidentsScript.STATE_ASSIGNED, "everyone sent to shelter")
	works.step(EventsScript.DURATION_USEC)
	incidents.sweep()
	assert_false(incidents.is_unresolved(threat), "over: resolved")
	fx.after_each()


func test_a_blown_down_tree_is_an_incident_until_hauled_clear() -> void:
	"""The woods' storm: a WARNING incident on the tree, assigned while the haul is on it, resolved once the trunk is
	in the stores."""
	var fx := ForestryFixture.new()
	fx.before_each()
	var forestry: ForestryScript = fx._forestry()
	var t: int = forestry.storm("A test gust")
	var serial: int = fx._services.incidents.serial_of("woods:windthrow:%d" % t)
	assert_equal([fx._services.incidents.target_kind_of(serial), fx._services.incidents.target_id_of(serial)],
		[NoticesScript.TARGET_TREE, t], "on the tree")
	fx._services.incidents.sweep()
	assert_equal(fx._services.incidents.state_of(serial), IncidentsScript.STATE_ASSIGNED, "a haul job on it")
	forestry.crew.set_crew(PackedInt32Array([4]))
	assert_true(fx._run(forestry, func() -> bool: return forestry.stand.trunk_milli[t] == 0), "hauled")
	fx._services.incidents.sweep()
	assert_false(fx._services.incidents.is_unresolved(serial), "resolved")
	fx.after_each()


func test_no_bed_is_one_incident_counting_the_nights_until_everyone_has_a_bed() -> void:
	"""Two residents, one bed: at dusk the no-bed incident on the bedless one; the next dusk merges into it; with a
	second bed fitted, the allocation at the next dusk resolves it."""
	var fx := NightFixture.new()
	var v: NightFixture.Village = fx._village([NightFixture.MOUSE_U, NightFixture.MOUSE_U] as Array[int], 1)
	var incidents := IncidentsScript.new()
	incidents.bind(v.notices, v.calendar, null)
	v.night.set_incidents(incidents)
	v.calendar.tick = NightFixture.TICK_DUSK
	fx._run(v, 1)
	var serial: int = incidents.serial_of(NightScript.NO_BED_KEY)
	assert_true(incidents.is_unresolved(serial), "raised at dusk")
	assert_equal(incidents.target_kind_of(serial), NoticesScript.TARGET_RESIDENT, "on a resident")
	assert_equal(incidents.target_id_of(serial), v.night.first_bedless(), "the one without a bed")
	assert_equal(incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "needs a decision")
	v.night.bed_of.fill(0)
	assert_equal(v.night.bed_state(), IncidentsScript.STATE_RESOLVED, "everyone bedded: resolved")
	incidents.sweep()
	assert_false(incidents.is_unresolved(serial), "swept: resolved")
	var silent := NightScript.new()
	assert_equal(silent.first_bedless(), -1, "nobody, nobody bedless")


func test_a_stuck_farm_job_and_a_full_store_are_incidents_on_their_beds() -> void:
	"""A job nobody could reach is an incident on its bed: needing a decision while the bed still wants it, ASSIGNED
	once it is on the board again, resolved once the bed no longer wants it. A full store resolves once there is
	room."""
	var fx := IntegrationFixture.new()
	fx.before_each()
	var farm: DemoFarmScript = fx._village(false)
	var incidents: IncidentsScript = fx._services.incidents
	farm.advance_calendar(30 * HOUR_USEC)
	var carrots: int = 2
	assert_equal(farm.crew.stuck_state(carrots, FarmJobs.KIND_HARVEST), IncidentsScript.STATE_ASSIGNED,
		"ripe carrots: the farm's own harvest job is on the board")
	var row := IntMath.IntResult.new()
	assert_true(farm.crew.jobs.job_on_bed_into(FarmJobs.KIND_HARVEST, carrots, row), "the job")
	farm.crew._raise_stuck(row.value)
	var serial: int = incidents.serial_of("farm:stuck:%d:%d" % [carrots, FarmJobs.KIND_HARVEST])
	assert_equal([incidents.target_kind_of(serial), incidents.target_id_of(serial)], [NoticesScript.TARGET_BED, carrots],
		"on the bed")
	farm.crew.jobs.close(row.value)
	incidents.sweep()
	assert_equal(incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "off the board, still wanted")
	assert_true(farm.sim.harvest(carrots).ok, "harvested by hand")
	incidents.sweep()
	assert_false(incidents.is_unresolved(serial), "no longer wanted: resolved")
	farm.crew._raise_store_full()
	var full: int = incidents.serial_of(farm.crew.STORE_FULL_KEY)
	assert_true(incidents.is_unresolved(full), "a full store raised")
	assert_equal(farm.crew.store_state(), IncidentsScript.STATE_RESOLVED, "the stores have room")
	incidents.sweep()
	assert_false(incidents.is_unresolved(full), "room in the store: resolved")
	fx.after_each()


func test_a_rescue_incident_is_assigned_then_recovering_as_the_responder_works() -> void:
	"""Decision 0231's farther-diver rescue: the victim's incident goes NEEDS A DECISION or ASSIGNED as the otter is
	sent, RECOVERING once it has the victim in hand, and RESOLVED ashore; its text is C's line, kept current."""
	var safety := SafetyFixture.new()
	safety.before_each()
	var rig: WaterFixture.Rig = safety._fx._rig()
	var play := rig.play
	safety._fx._swimmer(rig, 2, 1900, true)
	safety._fx._place(rig, 2, SafetyFixture.WEST_BANK)
	var task: DiveTaskScript = safety._diver_at_the_pond(rig, 0, SafetyFixture.POND_WEST)
	assert_true(safety._fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	play.cramp(PackedInt32Array([0]))
	var seen: Dictionary = {}
	var texts: Dictionary = {}
	var incidents: IncidentsScript = play.services.incidents
	var ashore: bool = safety._fx._run(rig, func() -> bool:
		if safety._fx._brain(rig, 0).task is Tasks.RestTask:
			return true
		play.sync_incidents()
		var serial: int = incidents.serial_of("water:rescue:0")
		seen[incidents.state_of(serial)] = true
		texts[incidents.text_of(serial)] = true
		return safety._fx._brain(rig, 0).task is Tasks.RestTask)
	incidents.sweep()
	assert_false(incidents.is_unresolved(incidents.serial_of("water:rescue:0")), "its own watch resolves it ashore")
	play.sync_incidents()
	assert_true(ashore, "brought ashore")
	assert_true(seen.has(IncidentsScript.STATE_ASSIGNED), "assigned: %s" % str(seen.keys()))
	assert_true(seen.has(IncidentsScript.STATE_RECOVERING), "recovering, in hand: %s" % str(seen.keys()))
	assert_true(texts.size() > 2, "the line kept current in place (%d versions)" % texts.size())
	assert_false(incidents.is_unresolved(incidents.serial_of("water:rescue:0")), "resolved ashore")
	safety.after_each()



# --- review follow-ups (code review of decision 0331) ---------------------------------------------------

func test_a_reused_row_never_keeps_the_last_incident_s_watch() -> void:
	"""Every row used, one resolved: an incident raised with no watch into that row is not swept by the old watch."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	for k: int in IncidentsScript.MAX_INCIDENTS:
		incidents.raise("k%d" % k, NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "x",
			NoticesScript.TARGET_NONE, -1, func() -> int: return IncidentsScript.STATE_RESOLVED)
	incidents.resolve("k0")
	var rescue: int = incidents.raise("water:rescue:7", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "In difficulty")
	assert_true(rescue != IncidentsScript.NO_SERIAL, "the resolved row taken")
	incidents.sweep()
	assert_true(incidents.is_unresolved(rescue), "not resolved by the row's old watch")


func test_a_full_table_still_posts_the_warning() -> void:
	"""Every row open: `report` is refused an incident but the feed still gets the line."""
	var shared := _services()
	for k: int in IncidentsScript.MAX_INCIDENTS:
		shared.incidents.raise("k%d" % k, NoticesScript.SOURCE_CREW, IncidentsScript.SEVERITY_WARNING, "x")
	var serial: int = shared.incidents.report("threat", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL,
		"A fox is near the village!")
	assert_equal(serial, IncidentsScript.NO_SERIAL, "no incident")
	assert_true(shared.notices.has_text("A fox is near the village!"), "the line posted all the same")
	assert_equal(shared.notices.incident(0), NoticesScript.NO_INCIDENT, "unlinked")


func test_queue_order_severity_and_ties_and_a_snoozed_pin() -> void:
	"""Severity before age in the queue and the attention list; equal times break by the older serial; a pinned card
	snoozed is out of the queue; a recurrence clears a snooze."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var routine: int = incidents.raise("a", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "a")
	var warning: int = incidents.raise("b", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "b")
	var first: int = incidents.raise("c", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "c")
	var second: int = incidents.raise("d", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "d")
	var list := PackedInt32Array()
	incidents.attention_into(list)
	assert_equal(list, PackedInt32Array([first, second, warning, routine]), "critical, then warning, then routine; ties by serial")
	incidents.pin(warning, true)
	incidents.snooze(warning)
	incidents.queue_into(list)
	assert_equal(list, PackedInt32Array([first, second]), "a snoozed pin is out of the queue")
	incidents.snooze(first)
	incidents.resolve("c")
	incidents.raise("c", NoticesScript.SOURCE_EVENTS, IncidentsScript.SEVERITY_CRITICAL, "c again")
	assert_false(incidents.is_snoozed(first), "a recurrence is unsnoozed")


func test_routine_reports_are_notes_and_fold_only_within_one_incident() -> void:
	"""A routine incident's line is a NOTE; the same words for two incidents are two entries, for one incident one."""
	var shared := _services()
	shared.incidents.report("farm:worn:0", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "Worn out")
	assert_equal(shared.notices.level(0), NoticesScript.LEVEL_NOTE, "a note")
	shared.incidents.report("farm:worn:0", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "Worn out")
	assert_equal(shared.notices.count(), 1, "one incident said twice: folded")
	shared.incidents.report("farm:worn:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "Worn out")
	assert_equal(shared.notices.count(), 2, "another incident: its own entry")


func test_a_dismissed_routine_incident_stops_asking_and_only_queueable_rows_snooze() -> void:
	"""Dismissed, a routine incident leaves the count and the attention list (UI §7: an advisory's acknowledgement
	hides it until it changes); a dismissed warning stays until resolved. Snooze is offered only where a card would
	queue."""
	var shared := _services()
	var incidents: IncidentsScript = shared.incidents
	var worn: int = incidents.raise("farm:worn:0", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_ROUTINE, "Worn out")
	var wet: int = incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Wet")
	incidents.acknowledge(worn)
	incidents.acknowledge(wet)
	assert_equal(incidents.unresolved_count(), 1, "the warning still counts")
	var list := PackedInt32Array()
	assert_equal(incidents.attention_into(list), 1, "the routine one has gone from the list")
	assert_false(incidents.can_queue(wet), "a warning does not queue: no snooze")
	var history := _history_rig(shared, null)
	history.open()
	assert_false(history.attention_can_snooze(0), "no Snooze on the warning's row")
	incidents.pin(wet, true)
	assert_true(incidents.can_queue(wet), "pinned, it does")


func test_the_history_s_go_to_uses_the_row_it_drew_and_pages_older_rows() -> void:
	"""A post after drawing does not move a row's Go to onto another entry's target; the history draws PAGE rows and
	"Show older" draws more; N is left to the HUD while its own history is open."""
	var shared := _services()
	var jump := JumpScript.new()
	var picked: Array[int] = [-1]
	jump.register(NoticesScript.TARGET_BED, func(bed: int) -> Vector3: return JumpScript.bed_point(bed),
		func(bed: int) -> void: picked[0] = bed)
	var history := _history_rig(shared, jump)
	for k: int in HistoryScript.PAGE + 10:
		shared.notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "chatter %d" % k)
	shared.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 1 dry", "", NoticesScript.TARGET_BED, 0)
	history.open()
	assert_equal(history.drawn_count(), HistoryScript.PAGE, "a page drawn")
	shared.notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Bed 5 wet", "", NoticesScript.TARGET_BED, 4)
	history.press_history_go(0)
	assert_equal(picked[0], 0, "the row drawn as bed 1 goes to bed 1")
	history.open()
	history.show_older()
	assert_equal(history.drawn_count(), HistoryScript.PAGE + 12, "all drawn")
	var shell_open: Array[bool] = [true]
	history.defer_keys_while(func() -> bool: return shell_open[0])
	assert_true(history._deferring(), "N is the HUD's while its history is open")
	shell_open[0] = false
	assert_false(history._deferring(), "then the window's")
