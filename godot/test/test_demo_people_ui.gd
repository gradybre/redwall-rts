extends "res://test/framework/test_case.gd"
## Review group T, "residents as people" (decision 0491): the names on every surface and the same person across the
## roster, the party panel, the Work screen and the news; the resident inspector's person (skills as meters, the
## optional About, notable moments that go to their place and person); the spotlight and the season's reflection
## through demo_people.gd and its card; the light evening lines; and dialect only in Tuppen's own spoken lines, never in
## functional text. No scene tree and no staged assets: the cast is placeholder bodies under the demo's cast keys.

const PeopleTest := preload("res://test/test_demo_people.gd")
const PeopleBook := preload("res://demo/people/people_book.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const PeopleScript := preload("res://demo/people/demo_people.gd")
const CardScript := preload("res://demo/people/people_card.gd")
const SectionScript := preload("res://demo/people/person_section.gd")
const Words := preload("res://demo/people/people_text.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const RosterScript := preload("res://demo/ui/demo_roster.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const ResidentRowScript := preload("res://demo/work/work_resident_row.gd")
const ActionCard := preload("res://demo/ui/action_card.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const TunnelWorks := preload("res://demo/tunnel/tunnel_works.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")

const KEEPER: int = 0
const FISHER: int = 5
const MOLE: int = 6
const DAY_TICKS: int = SimClock.TICKS_PER_DAY
const SEASON_TICKS: int = SimClock.TICKS_PER_DAY * SimClock.DAYS_PER_SEASON
## 19:00 of spring day 1 (tick 0 is 06:00).
const EVENING_TICK: int = (PeopleScript.EVENING_HOUR - 6) * SimClock.TICKS_PER_HOUR

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


## The village a test reads: the named cast, its command layer and panel, a shell and roster, a work board over the
## cast's names and keys, the notices and calendar, and the people over them (a rescue log and one skill bound).
class Rig extends RefCounted:
	var cast: DemoCastScript = null
	var command: CommandScript = null
	var shell: UiShell = null
	var roster: RosterScript = null
	var board: BoardScript = BoardScript.new()
	var notices: NoticesScript = NoticesScript.new()
	var calendar: CalendarScript = CalendarScript.new()
	var people: PeopleScript = null
	var rescue: RescueScript = RescueScript.new()
	var felling: PackedInt64Array = PackedInt64Array()


func _rig() -> Rig:
	"""The named village (see Rig), wired as demo_village.gd wires it."""
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new())
	rig.cast.build(PeopleTest.manifest(), [] as Array[Dictionary], [] as Array[Vector3])
	rig.cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	rig.command = _keep(CommandScript.new())
	rig.command.configure(rig.cast, _keep(Camera3D.new()) as Camera3D)
	rig.command.panel().build()
	rig.shell = _keep(UiShell.new())
	rig.shell.build()
	rig.shell.layout_for(1280, 720)
	rig.roster = _keep(RosterScript.new())
	var camera: CameraScript = _keep(CameraScript.new())
	camera.configure(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)), Vector3.ZERO)
	rig.roster.configure(rig.shell, rig.cast, rig.command, camera)
	_bind_board(rig)
	_bind_people(rig)
	return rig


func _bind_board(rig: Rig) -> void:
	"""The work board over the cast's names and keys (demo_work.gd's binding)."""
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for who: int in rig.cast.actor_count():
		var actor := rig.cast.actor(who) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		keys.append(actor.creature_key)
	rig.board.bind(brains, names, keys)


func _bind_people(rig: Rig) -> void:
	"""The people over the rig (demo_village.gd `_build_people`'s binding, the owners a test needs)."""
	rig.people = _keep(PeopleScript.new())
	rig.people.configure(rig.cast, rig.notices, rig.calendar)
	rig.notices.bind_calendar(rig.calendar)
	rig.people.taps.rescue = rig.rescue
	rig.people.board = rig.board
	rig.felling.resize(rig.cast.actor_count())
	rig.people.taps.add_skill("Felling", func(who: int) -> int: return rig.felling[who])
	rig.people.watch()
	rig.command.set_person_info(rig.people.inspector_info, rig.people.stamp_of)
	rig.roster.set_notable(rig.people.is_notable)


func _select(rig: Rig, who: int) -> void:
	"""Select `who` alone and redraw the party panel."""
	rig.command.select(PackedInt32Array([who]))
	rig.command._refresh_panel()


func _section(rig: Rig) -> SectionScript:
	"""The party panel's person section."""
	return rig.command.panel().person_section()


# --- names on every surface -------------------------------------------------------------------------------------

func test_the_same_person_on_the_roster_the_panel_work_and_news() -> void:
	"""Wenna Tallowby, cast index 0, is named so on the roster ("— mouse, keeper"), the party panel (her role on the
	species line), the Work screen's resident row (with her role), and the news (her evening line, about index 0); a
	roster pick selects her, and the panel then shows her."""
	var rig := _rig()
	(rig.shell.control_for(UiShell.ID_RESIDENTS) as Button).pressed.emit()
	assert_true(rig.roster.row_text(KEEPER).begins_with("Wenna Tallowby — mouse, keeper · "), rig.roster.row_text(KEEPER))
	assert_true(rig.shell.roster_row(MOLE).text.begins_with("Tuppen Clayholm — mole, digger"), "the roster's own row")
	rig.roster.pick_row(KEEPER)
	assert_equal(rig.command.selected(), PackedInt32Array([KEEPER]), "picked on the roster: selected")
	rig.command._refresh_panel()
	var lines: PackedStringArray = PanelScript.party_lines(rig.command.party_entries())
	assert_equal(rig.command.panel().summary().get_slice(" — ", 0), "Wenna Tallowby", "the panel's summary")
	assert_equal(lines[1], "Mouse, keeper", "her species line names her role")
	assert_equal(rig.board.name_of(KEEPER), "Wenna Tallowby", "the board's name")
	assert_equal(rig.board.label_of(KEEPER), "Wenna Tallowby (mouse keeper)", "and with her role")
	assert_equal(rig.board.label_of(99), BoardScript.UNKNOWN, "nobody")
	var row: ResidentRowScript = _keep(ResidentRowScript.new())
	row.show_resident(KEEPER, rig.board, "wandering", false)
	assert_true(row.title().begins_with("Wenna Tallowby (mouse keeper) — Haulers crew"), row.title())
	rig.calendar.tick = EVENING_TICK
	rig.people.poll()
	assert_true(rig.notices.text(0).begins_with("Wenna Tallowby is carving"), rig.notices.text(0))
	assert_equal([rig.notices.target_kind(0), rig.notices.target_id(0)], [NoticesScript.TARGET_RESIDENT, KEEPER],
		"about the same resident")


func test_names_reach_the_action_cards_crews_and_feeds() -> void:
	"""The owners' own name readers -- the bridge crew's feed, the rescue's, the action cards -- say the person's name."""
	var rig := _rig()
	var crew := BridgeCrewScript.new()
	crew.configure(rig.cast, BridgesScript.new(), null, null, Callable())
	assert_equal(crew.name_of(8), "Elstan Weirholt", "the bridge crew's")
	rig.rescue.configure(rig.cast, _crossings(rig), Callable())
	assert_equal(rig.rescue.name_of(FISHER), "Corra Netley", "the rescue's")
	for who: int in rig.cast.actor_count():
		assert_equal((rig.cast.actor(who) as DemoActorScript).display_name, PeopleTest.NAMES[who], "actor %d" % who)


func _crossings(rig: Rig) -> RefCounted:
	"""A water crossings object the rescue can be configured over (its own state and motion)."""
	var crossings: RefCounted = load("res://demo/waterplay/water_crossings.gd").new()
	crossings.set(&"state", load("res://demo/waterplay/swim_state.gd").new())
	crossings.set(&"motion", load("res://demo/waterplay/swim_motion.gd").new())
	assert_not_null(rig.cast, "a cast")
	return crossings


func test_a_notable_resident_is_starred_on_the_roster_only() -> void:
	"""★ after the name on the roster; the name itself, everywhere else, unchanged."""
	var rig := _rig()
	assert_true(rig.people.pin_notable(FISHER, true), "pinned")
	assert_true(rig.roster.row_text(FISHER).begins_with("Corra Netley" + RosterScript.NOTABLE_MARK + " — otter, fisher"),
		rig.roster.row_text(FISHER))
	assert_equal((rig.cast.actor(FISHER) as DemoActorScript).display_name, "Corra Netley", "the name unchanged")
	rig.people.pin_notable(FISHER, false)
	assert_true(rig.roster.row_text(FISHER).begins_with("Corra Netley — "), "unpinned")


# --- the inspector ------------------------------------------------------------------------------------------------

func test_the_inspector_shows_skills_as_meters_and_keeps_details_optional() -> void:
	"""One resident: its role and why; its skill "Felling · Level 3" with its meter half way; About closed until asked,
	then its interest and its (empty) moments."""
	var rig := _rig()
	rig.felling[3] = (ForestRules.xp_of_level(3) + ForestRules.xp_of_level(4)) / 2
	_select(rig, 3)
	var section := _section(rig)
	assert_true(section.visible, "a person shown")
	assert_equal(section.skill_line(0), "Felling · Level 3", "its skill")
	assert_almost_equal(section.skill_fill(0), 0.5, "half way to level 4")
	assert_false(section.about_open, "details closed")
	assert_equal(section.about_button().text, "About Tobit ▸", "offered")
	section.about_button().pressed.emit()
	assert_true(section.about_open, "opened")
	assert_equal(section.interest_text(), "Interest: sorts a pebble collection by colour", "his interest")
	assert_equal(section.moment_count(), 0, "nothing yet")
	var lines: PackedStringArray = PanelScript.party_lines(rig.command.party_entries())
	assert_true(lines.has(PeopleScript.WHY_FREE), "why: free (%s)" % lines)
	rig.felling[3] = ForestRules.xp_of_level(ForestRules.SKILL_LEVEL_MAX)
	rig.command._refresh_panel()
	assert_equal(section.skill_line(0), "Felling · Level %d (the top)" % ForestRules.SKILL_LEVEL_MAX, "at the top")
	assert_almost_equal(section.skill_fill(0), 1.0, "full")
	_select(rig, 4)
	assert_false(section.about_open, "another resident: closed again")
	rig.command.select(PackedInt32Array([3, 4]))
	rig.command._refresh_panel()
	assert_false(section.visible, "a group shows no one person")


func test_moments_go_to_their_place_and_person() -> void:
	"""A rescue Corra made: her moment reads "Spring 1 · Brought Tuppen Clayholm ashore" and goes to him; Tuppen's
	reads "Brought ashore by Corra Netley"; a bridge goes to the bridge; a meal has nowhere to go."""
	var rig := _rig()
	rig.rescue._log_assist(FISHER, MOLE)
	rig.people.poll()
	_select(rig, FISHER)
	var section := _section(rig)
	section.toggle_about()
	assert_equal(section.moment_count(), 1, "one moment")
	assert_equal(section.moment_text(0), "Spring 1 · Brought Tuppen Clayholm ashore", "her moment")
	assert_false(section.moment_person(0).visible, "its place is the person")
	var went: Array = []
	section.go_to.connect(func(kind: int, id: int) -> void: went.append([kind, id]))
	section.moment_row(0).pressed.emit()
	assert_equal(went, [[NoticesScript.TARGET_RESIDENT, MOLE]], "to him")
	assert_equal(section.relations_text(), "Rescued Tuppen Clayholm", "a light relationship line")
	var ledger: Ledger = rig.people.ledger
	var bridge: int = ledger.record(Ledger.KIND_BRIDGE, FISHER, 30, 0, MOLE, NoticesScript.TARGET_BRIDGE, 2, "neck bridge")
	ledger.record(Ledger.KIND_MEAL, FISHER, 40, 0, -1, NoticesScript.TARGET_NONE, -1, "supper, day 1")
	rig.command._refresh_panel()
	assert_equal(section.moment_count(), 3, "three, newest first")
	assert_equal(section.moment_text(0), "Spring 1 · Cooked supper, day 1 for everyone", "the meal")
	assert_false(section.moment_row(0).visible, "nowhere to go")
	assert_true(section.moment_row(1).visible, "a bridge to go to")
	assert_true(section.moment_person(1).visible and section.moment_person(1).text == "Tuppen Clayholm", "a person")
	section.moment_person(1).pressed.emit()
	section.moment_row(1).pressed.emit()
	assert_equal(went.slice(1), [[NoticesScript.TARGET_RESIDENT, MOLE], [NoticesScript.TARGET_BRIDGE, 2]], "person, place")
	ledger.curate(bridge, Ledger.CURATION_PINNED)
	rig.command._refresh_panel()
	assert_true(section.moment_text(1).ends_with(SectionScript.CHRONICLED), "marked in the chronicle")
	ledger.curate(bridge, Ledger.CURATION_DISMISSED)
	rig.command._refresh_panel()
	assert_equal(section.moment_count(), 2, "a dismissed moment leaves the history")
	_select(rig, MOLE)
	section.toggle_about()
	assert_equal(section.moment_text(0), "Spring 1 · Brought ashore by Corra Netley", "his side")


func test_the_notable_pin_in_the_inspector() -> void:
	"""Pin as notable, then Notable ★ — unpin; the press says who and which way."""
	var rig := _rig()
	_select(rig, KEEPER)
	var section := _section(rig)
	var pressed: Array = []
	section.notable_pressed.connect(func(who: int, on: bool) -> void:
		pressed.append([who, on])
		rig.people.pin_notable(who, on))
	section.toggle_about()
	assert_equal(section.pin_button().text, SectionScript.PIN, "offered")
	section.pin_button().pressed.emit()
	rig.command._refresh_panel()
	assert_equal(section.pin_button().text, SectionScript.UNPIN, "pinned")
	section.pin_button().pressed.emit()
	assert_equal(pressed, [[KEEPER, true], [KEEPER, false]], "both ways")


func test_why_names_the_owner_that_has_the_resident() -> void:
	"""Night, the water's hold, an order, a board task of its own crew or a hand lent, free."""
	var rig := _rig()
	var brain: BrainScript = (rig.cast.actor(1) as DemoActorScript).brain
	assert_equal(rig.people.why_of(1), PeopleScript.WHY_FREE, "free")
	brain.order_move(brain.position + Vector2(1.0, 0.0))
	assert_equal(rig.people.why_of(1), PeopleScript.WHY_ORDER, "an order")
	brain.resting = true
	assert_equal(rig.people.why_of(1), PeopleScript.WHY_NIGHT, "asleep")
	brain.resting = false
	brain.water_hold = true
	brain.in_water = true
	assert_equal(rig.people.why_of(1), PeopleScript.WHY_HELD, "in difficulty")
	brain.in_water = false
	assert_equal(rig.people.why_of(1), PeopleScript.WHY_ABOARD, "held on the water out of it: aboard a boat")
	brain.water_hold = false
	var source := PeopleTest.StubSource.new()
	source.id = 0
	source.workers = PackedInt32Array([1, 3])
	rig.board.add_source(source)
	assert_equal(rig.people.why_of(1), "Why: the Field crew's own work (Farm)", "Jory, a fieldworker, on farm work")
	assert_equal(rig.people.why_of(3), "Why: Farm work — the Woods crew lends a hand where needed", "Tobit lends a hand")


# --- the spotlight and the reflection -----------------------------------------------------------------------------

func test_a_distinctive_deed_offers_a_spotlight_once_and_pinning_changes_nothing_else() -> void:
	"""A rescue: Corra is offered (not Tuppen, whom she rescued); Spotlight ★ marks her notable; a second rescue offers
	nothing more; a skill level is no spotlight; Not now drops an offer for good."""
	var rig := _rig()
	rig.rescue._log_assist(FISHER, MOLE)
	rig.people.poll()
	assert_equal(rig.people.offer_who, PackedInt32Array([FISHER]), "Corra")
	assert_equal(rig.people.offer_text(), Words.spotlight_text("Corra Netley brought Tuppen Clayholm ashore", "Corra Netley"),
		"what happened, what pinning does")
	var card: CardScript = _keep(CardScript.new())
	card.configure(rig.people, null)
	assert_true(card.refresh(), "the card shows")
	assert_equal(card.mode(), CardScript.MODE_SPOTLIGHT, "a spotlight")
	var xp_before: int = rig.felling[FISHER]
	card.spotlight_button().pressed.emit()
	assert_true(rig.people.is_notable(FISHER), "notable")
	assert_equal(rig.felling[FISHER], xp_before, "no skill changed")
	assert_false(card.is_shown(), "answered")
	rig.rescue._log_assist(FISHER, MOLE)
	rig.felling[2] = ForestRules.xp_of_level(2)
	rig.calendar.tick += 100
	rig.people.poll()
	assert_false(rig.people.has_offer(), "notable already; a skill level is no spotlight")
	rig.rescue._log_assist(KEEPER, MOLE)
	rig.people.poll()
	assert_true(card.refresh() and card.mode() == CardScript.MODE_SPOTLIGHT, "Wenna's offer")
	assert_true(card.decline(), "not now")
	rig.rescue._log_assist(KEEPER, 1)
	rig.people.poll()
	assert_false(rig.people.has_offer(), "offered once per kind")
	assert_false(rig.people.accept_offer() or rig.people.decline_offer(), "nothing to answer")


func test_offers_queue_and_yield_to_the_incident_card() -> void:
	"""At most MAX_OFFERS wait (the oldest go); the card hides while what it yields to shows."""
	var rig := _rig()
	for who: int in PeopleScript.MAX_OFFERS + 1:
		rig.rescue._log_assist(who, 8)
	rig.people.poll()
	assert_equal(rig.people.offer_who.size(), PeopleScript.MAX_OFFERS, "capped")
	assert_equal(rig.people.offer_who[0], 1, "the oldest went")
	var card: CardScript = _keep(CardScript.new())
	card.configure(rig.people, null)
	var incident: Array[bool] = [true]
	card.hide_while(func() -> bool: return incident[0])
	assert_false(card.refresh(), "an incident first")
	incident[0] = false
	assert_true(card.refresh(), "then the offer")
	assert_false(card.go_to(), "no Go to without a jump")
	assert_true(rig.people.pin_notable(2, true), "pinned from the inspector")
	assert_false(rig.people.offer_who.has(2), "its own offer goes")


func test_a_season_s_end_offers_its_moments_to_pin_keep_or_dismiss() -> void:
	"""Three committed moments of spring at its end; Pin posts the chronicle line to the news (about the resident);
	Keep private and Dismiss post nothing; answered, the reflection is over. Nothing is offered for an empty season."""
	var rig := _rig()
	rig.rescue._log_assist(FISHER, MOLE)
	rig.felling[2] = ForestRules.xp_of_level(1)
	rig.calendar.tick += 100
	rig.people.poll()
	rig.people.ledger.record(Ledger.KIND_MEAL, KEEPER, 200, 0, -1, 0, -1, "supper, day 1")
	rig.people.ledger.record(Ledger.KIND_SKILL, 3, 210, 0, -1, 0, -1, "Sawing", 2)
	rig.calendar.tick = SEASON_TICKS
	rig.people.poll()
	assert_true(rig.people.has_reflection(), "spring is over")
	assert_equal(rig.people.reflection_title(), "Spring's end: moments to remember", "titled")
	assert_equal(rig.people.reflection_line(0), "Corra Netley brought Tuppen Clayholm ashore", "the rescue first")
	assert_equal(rig.people.reflection_line(1), "Wenna Tallowby cooked supper, day 1 for everyone", "then the meal")
	assert_equal(rig.people.reflection_line(2), "Linnet Whinberry reached Felling · Level 1", "then the earliest skill")
	var card: CardScript = _keep(CardScript.new())
	card.configure(rig.people, null)
	assert_true(card.refresh() and card.mode() == CardScript.MODE_REFLECTION, "the reflection first")
	assert_equal(card.moment_text(0), rig.people.reflection_line(0), "on the card")
	var before: int = rig.notices.count()
	assert_true(card.curate(0, Ledger.CURATION_PINNED), "pinned")
	assert_equal(rig.notices.count(), before + 1, "posted")
	assert_equal(rig.notices.text(0), "Chronicle: Corra Netley brought Tuppen Clayholm ashore (Spring 1)", "the line")
	assert_equal([rig.notices.summary(0), rig.notices.target_id(0)], ["Chronicle", FISHER], "about Corra")
	assert_true(card.curate(0, Ledger.CURATION_PRIVATE), "kept private")
	assert_true(card.curate(0, Ledger.CURATION_DISMISSED), "dismissed")
	assert_equal(rig.notices.count(), before + 1, "nothing else posted")
	assert_false(rig.people.has_reflection(), "answered: over")
	assert_false(rig.people.curate_reflection(0, Ledger.CURATION_PINNED), "nothing left")
	rig.calendar.tick = 2 * SEASON_TICKS
	rig.people.poll()
	assert_false(rig.people.has_reflection(), "an empty summer offers nothing")


func test_later_leaves_the_moments_uncurated() -> void:
	"""Later closes the reflection; its moments stay in each resident's own history."""
	var rig := _rig()
	rig.rescue._log_assist(FISHER, MOLE)
	rig.people.poll()
	rig.calendar.tick = SEASON_TICKS
	rig.people.poll()
	var card: CardScript = _keep(CardScript.new())
	card.configure(rig.people, null)
	assert_true(card.refresh() and card.mode() == CardScript.MODE_REFLECTION, "shown")
	assert_true(card.decline(), "later")
	assert_false(rig.people.has_reflection(), "closed")
	assert_equal(rig.people.ledger.curation_of(0), Ledger.CURATION_NONE, "uncurated")
	assert_equal(rig.people.moments_of(FISHER).size(), 1, "still hers")
	assert_false(rig.people.curate_reflection(0, Ledger.CURATION_NONE), "NONE is no answer")


# --- light lines and dialect --------------------------------------------------------------------------------------

func test_one_evening_line_a_day_from_a_free_resident() -> void:
	"""At 19:00 the next free resident in turn says its pastime -- one line, in the news; the next evening the next
	resident; a resident under an order is passed over; at dusk the lines end."""
	var rig := _rig()
	(rig.cast.actor(KEEPER) as DemoActorScript).brain.order_move(Vector2(3.0, 3.0))
	rig.calendar.tick = EVENING_TICK
	rig.people.poll()
	assert_equal(rig.people.lines_posted, 1, "one line")
	assert_equal(rig.notices.text(0), "Jory Whitethorn is whistling birdcalls", "Wenna is busy: Jory")
	assert_equal(rig.people.evening_lines[1], rig.notices.text(0), "the inspector's evening line")
	rig.people.poll()
	assert_equal(rig.people.lines_posted, 1, "once an evening")
	rig.calendar.tick = EVENING_TICK + SimClock.TICKS_PER_HOUR
	rig.people.poll()
	assert_equal(rig.people.evening_lines[1], "", "dusk: over")
	rig.calendar.tick = EVENING_TICK + DAY_TICKS
	rig.people.poll()
	assert_equal(rig.notices.text(0), "Linnet Whinberry is playing a reed pipe, badly", "the next in turn")


func test_a_pleased_line_follows_only_a_deed_of_that_day() -> void:
	"""Tuppen's pleased line (with his light dialect) only on the evening of a day he did something; his rescue of
	another the day before is not today's."""
	var rig := _rig()
	assert_false(rig.people.deed_today(MOLE), "nothing yet")
	rig.calendar.tick = EVENING_TICK - 100
	rig.people.ledger.record(Ledger.KIND_TUNNEL, MOLE, rig.calendar.tick, 0, -1, NoticesScript.TARGET_TUNNEL, 0, "tunnel 1")
	assert_true(rig.people.deed_today(MOLE), "a deed today")
	var line: String = rig.people.evening_line_of(MOLE)
	assert_equal(line, "Tuppen Clayholm is sorting a box of odd keys and buttons — \"A good day's work, hurr.\"", line)
	rig.people.ledger.record(Ledger.KIND_RESCUED, KEEPER, rig.calendar.tick, 0, MOLE)
	assert_false(rig.people.deed_today(KEEPER), "being rescued is no deed of hers")
	rig.calendar.tick += DAY_TICKS
	assert_false(rig.people.deed_today(MOLE), "yesterday's")
	assert_false(rig.people.evening_line_of(MOLE).contains("\""), "no pleased line")


func test_dialect_only_in_tuppen_s_own_lines_never_in_functional_text() -> void:
	"""DEC-017: every other resident's evening, pleased and dig lines are plain; Tuppen's spoken lines carry his
	light molespeak, his roster row, inspector, why line and spotlight never do; the rock warning is plain."""
	var rig := _rig()
	for who: int in rig.cast.actor_count():
		var key: StringName = (rig.cast.actor(who) as DemoActorScript).creature_key
		var name: String = PeopleTest.NAMES[who]
		var evening: String = Words.evening_line(key, name, "hall steps", true, 0)
		assert_equal(PeopleTest.has_dialect(evening), who == MOLE, "%s's evening: %s" % [name, evening])
		for saying: int in CrewScript.SAYINGS.size():
			var said: String = rig.people.voice(who, saying)
			assert_true(said.begins_with(name + ": \""), said)
			assert_equal(PeopleTest.has_dialect(said), who == MOLE, "%s says: %s" % [name, said])
		assert_false(PeopleTest.has_dialect(Words.evening_line(key, name, "", false, 0)), "no deed today: plain")
	for saying: String in CrewScript.SAYINGS:
		assert_false(PeopleTest.has_dialect(saying), "a saying itself is plain: %s" % saying)
	assert_false(PeopleTest.has_dialect(CrewScript.LINE_ROCK_ALONE), "the rock warning")
	assert_false(PeopleTest.has_dialect(rig.roster.row_text(MOLE)), "his roster row")
	assert_false(PeopleTest.has_dialect(rig.people.why_of(MOLE)), "his why")
	rig.rescue._log_assist(MOLE, KEEPER)
	rig.people.poll()
	assert_false(PeopleTest.has_dialect(rig.people.offer_text()), "his spotlight")
	_select(rig, MOLE)
	for line: String in PanelScript.party_lines(rig.command.party_entries()):
		assert_false(PeopleTest.has_dialect(line), "his panel: %s" % line)
	assert_equal(rig.people.voice(-1, 0), CrewScript.spoken(0, "", ""), "nobody: the unnamed lead, plain")


func test_the_dig_lead_speaks_through_the_works() -> void:
	"""tunnel_works.gd `speak`: the voice bound, the lead's own; unbound, plain under the unnamed lead."""
	var works: TunnelWorks = _keep(TunnelWorks.new())
	works.notices = NoticesScript.new()
	works.speak(CrewScript.SAY_START, 0)
	assert_equal(works.notices.text(0), "%s: \"%s\"" % [CrewScript.UNNAMED_SPEAKER, CrewScript.SAYINGS[0]], "unbound")
	var rig := _rig()
	works.voice = rig.people.voice
	works.speak(CrewScript.SAY_OPEN, MOLE)
	assert_equal(works.notices.text(0), "Tuppen Clayholm: \"There it is: a fine tunnel, clear through, burr aye.\"", "his")
	works.speak(CrewScript.SAY_ROCK_BADGER, 7)
	assert_equal(works.notices.text(0), "Hulda Slatebrook: \"The rock cracks now the badger is here. Onward!\"", "hers")
	assert_equal(CrewScript.spoken(CrewScript.SAY_ROCK_BADGER, "X", "hurr"), "X: \"The rock cracks now the badger is here. Onward, hurr!\"", "before a !")
	assert_equal(CrewScript.spoken(99, "X", ""), "X: \"\"", "no such saying")


func test_one_resident_s_skills_are_meters_not_words_and_a_group_keeps_its_short_forms() -> void:
	"""With the people's meters bound, one resident's skill-only providers step aside (the meters say it) and the
	others stay; a group still reads every provider's short form; without the people, every provider speaks."""
	var rig := _rig()
	rig.command.set_skill_text(func(_who: int, alone: bool) -> String: return "Felling 3" if alone else "fell 3", true)
	rig.command.add_skill_text(func(_who: int, alone: bool) -> String: return "Swims" if alone else "swims")
	rig.command.select(PackedInt32Array([KEEPER]))
	assert_equal(rig.command.skills_text(KEEPER), "Swims", "alone: the meters say the felling")
	rig.command.select(PackedInt32Array([KEEPER, 1]))
	assert_equal(rig.command.skills_text(KEEPER), "fell 3 · swims", "a group: every short form")
	rig.command.set_person_info(Callable(), Callable())
	rig.command.select(PackedInt32Array([KEEPER]))
	assert_equal(rig.command.skills_text(KEEPER), "Felling 3\nSwims", "no people: the words")


func test_the_water_s_words_split_into_bridging_and_swimming() -> void:
	"""waterplay_text.gd: the old skill line is the bridge line and the swim line together, alone and in a list."""
	var suite: RefCounted = load("res://test/test_demo_water_play.gd").new()
	suite.call(&"before_each")
	var rig: RefCounted = suite.call(&"_rig")
	var text: RefCounted = (rig.get(&"play") as Node).get(&"text")
	var alone: PackedStringArray = String(text.call(&"skill_line", 0, true)).split("\n")
	assert_equal(alone.size(), 3, "alone, as before the split: bridging, swimming, breath (%s)" % alone)
	assert_true(alone[0].begins_with("Bridging ") and alone[2].begins_with("Breath "), "in that order")
	assert_equal(text.call(&"skill_line", 0, false), "bridge 0", "a list on land with full air: bridging alone")
	assert_equal(text.call(&"swim_line", 0, false), "", "and no swimming words")
	(rig.get(&"play") as Node).get(&"state").air[0] = 600
	assert_true(String(text.call(&"skill_line", 0, false)).begins_with("bridge 0 · breath "), "short of air: its breath")
	suite.call(&"after_each")


func test_a_dug_through_tunnel_is_said_by_its_own_lead() -> void:
	"""tunnel_works.gd: the piece dug through, SAY_OPEN is spoken by its digger (piece_digger), through the voice."""
	var suite: RefCounted = load("res://test/test_demo_tunnel_ext_world.gd").new()
	suite.call(&"before_each")
	var space: RefCounted = suite.call(&"_space", [] as Array[Vector3])
	var species := PackedStringArray(["Mole", "Mole"])
	var brains: Array[BrainScript] = suite.call(&"_cast_of", space, [Vector2(0.0, 0.0), Vector2(1.0, 0.0)] as Array[Vector2],
		species)
	var works: TunnelWorks = suite.call(&"_works", space, brains, species)
	works.voice = func(who: int, saying: int) -> String: return "lead %d says %d" % [who, saying]
	var graph: RefCounted = space.get(&"tunnels")
	var ref := PackedInt32Array([-1, 0, -1])
	graph.call(&"add_into", PackedInt32Array([3072, 2867, 9830, -2540]), 2, 1, ref)
	var chain := PackedInt32Array()
	graph.call(&"piece_segments_into", ref[2], chain)
	for slot: int in chain:
		if int(graph.get(&"phase")[slot]) != 3:
			graph.call(&"start_dig", slot, graph.get(&"generation")[slot], 1)
		graph.call(&"set_rate", slot, 1000)
		graph.call(&"advance", slot, graph.get(&"generation")[slot], 1000000000000)
		works.step(1)
	assert_true(bool(graph.call(&"piece_done", ref[2])), "dug through")
	var notices: NoticesScript = (suite.get(&"_services") as RefCounted).get(&"notices")
	assert_true(notices.has_text("lead 1 says %d" % CrewScript.SAY_OPEN), "its own digger said it")
	suite.call(&"after_each")


func test_the_water_registers_bridging_as_skill_only() -> void:
	"""demo_waterplay.gd's wiring: one resident's bridging is a meter, so its words step aside; its swimming stays."""
	var rig := _rig()
	var suite: RefCounted = load("res://test/test_demo_water_play.gd").new()
	suite.call(&"before_each")
	var water: RefCounted = suite.call(&"_rig")
	var play: Node = water.get(&"play")
	play.set(&"_command", rig.command)
	rig.command.set_skill_text(func(_who: int, _alone: bool) -> String: return "")
	play.call(&"_hook_command")
	rig.command.select(PackedInt32Array([KEEPER]))
	var said: String = rig.command.skills_text(KEEPER)
	assert_false(said.contains("Bridging"), "no bridging words alone: %s" % said)
	assert_true(said.begins_with("Swim") or said.contains("wade") or said.contains("Wade"), "the swimming stays: %s" % said)
	rig.command.select(PackedInt32Array([KEEPER, 1]))
	assert_true(rig.command.skills_text(KEEPER).contains("bridge "), "a group keeps the short bridging")
	suite.call(&"after_each")


func test_a_notable_resident_is_not_offered_and_unpinning_keeps_offers() -> void:
	"""Pinned already: a rescue offers no spotlight. Unpinning someone leaves another's offer alone."""
	var rig := _rig()
	rig.people.pin_notable(FISHER, true)
	rig.rescue._log_assist(FISHER, MOLE)
	rig.people.poll()
	assert_false(rig.people.has_offer(), "notable already")
	rig.rescue._log_assist(KEEPER, MOLE)
	rig.people.poll()
	rig.people.pin_notable(KEEPER, false)
	assert_equal(rig.people.offer_who, PackedInt32Array([KEEPER]), "unpinning does not drop an offer")


func test_only_a_resident_on_its_own_time_on_the_surface_is_free() -> void:
	"""is_free: wandering, no order or task, not below, in the water, held, asleep, lying or indoors."""
	var rig := _rig()
	var brain: BrainScript = (rig.cast.actor(2) as DemoActorScript).brain
	assert_true(PeopleScript.is_free(brain), "free")
	for flag: StringName in [&"underground", &"in_water", &"water_hold", &"resting", &"lying", &"indoors"]:
		brain.set(flag, true)
		assert_false(PeopleScript.is_free(brain), "not while %s" % flag)
		brain.set(flag, false)
	brain.task = UrgentTask.new()
	assert_false(PeopleScript.is_free(brain), "not on a task")
	assert_equal(rig.people.why_of(2), PeopleScript.WHY_URGENT, "an emergency's why")
	brain.task = null
	brain.order = BrainScript.ORDER_WORK
	assert_false(PeopleScript.is_free(brain), "not under an order")


func test_the_kitchen_says_why() -> void:
	"""The cook (the village's or one standing in), a water drawer, a diner."""
	var rig := _rig()
	var kitchen := KitchenScript.new()
	kitchen._role.resize(rig.cast.actor_count())
	kitchen.designated = KEEPER
	rig.people.bind_kitchen(kitchen)
	kitchen._role[KEEPER] = KitchenScript.ROLE_COOK
	kitchen._role[1] = KitchenScript.ROLE_COOK
	kitchen._role[2] = KitchenScript.ROLE_DRAW
	kitchen._role[3] = KitchenScript.ROLE_EAT
	assert_equal([rig.people.why_of(KEEPER), rig.people.why_of(1), rig.people.why_of(2), rig.people.why_of(3)],
		[PeopleScript.WHY_COOK, PeopleScript.WHY_STAND_IN, PeopleScript.WHY_DRAW, PeopleScript.WHY_MEAL], "each part")
	assert_equal(rig.people.why_of(4), PeopleScript.WHY_FREE, "no part")


func test_moments_are_capped_and_an_empty_season_changes_nothing() -> void:
	"""At most MAX_MOMENTS moments; a season with no deed leaves no reflection and no redraw."""
	var rig := _rig()
	for k: int in PeopleScript.MAX_MOMENTS + 2:
		rig.people.ledger.record(Ledger.KIND_SKILL, KEEPER, k, 0, -1, 0, -1, "Felling", 1)
	assert_equal(rig.people.moments_of(KEEPER).size(), PeopleScript.MAX_MOMENTS, "capped")
	var quiet := _rig()
	var revision: int = quiet.people.revision
	quiet.calendar.tick = SEASON_TICKS
	quiet.people.poll()
	assert_equal([quiet.people.revision, quiet.people.reflection_season], [revision, -1], "nothing offered, nothing redrawn")


## A task that is an emergency (as a rescue or a shelter is).
class UrgentTask extends "res://demo/tunnel/tunnel_task.gd":
	func urgent() -> bool:
		"""An emergency."""
		return true


func test_a_group_carries_no_person_and_the_panel_shows_none() -> void:
	"""Only one resident's entry carries its person; a group's panel hides the section even if an entry carried one."""
	var rig := _rig()
	rig.command.select(PackedInt32Array([KEEPER, 1]))
	for entry: Dictionary in rig.command.party_entries():
		assert_false(entry.has("person"), "no person in a group's entry")
	var panel: PanelScript = rig.command.panel()
	var entries: Array[Dictionary] = [{"index": 0, "name": "A", "species": "Mouse", "state": "holding",
		"person": rig.people.inspector_info(KEEPER)}, {"index": 1, "name": "B", "species": "Mouse", "state": "holding"}]
	panel.show_party(entries)
	assert_false(_section(rig).visible, "a group: no person shown")
