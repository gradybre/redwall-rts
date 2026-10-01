extends "res://test/framework/test_case.gd"
## Review group T, "residents as people" (decision 0491; P6, SOC-001, SOC-014, SOC-028): the demo cast's names and
## interests from one data file, the ledger of COMMITTED notable deeds, the taps that write it from the owners' committed
## state (a cancelled job leaves no memory; a rescue counts only when it succeeded), skill levels, affinity from shared
## experience by the GDD's own numbers, the spotlight and the season's reflection. No staged assets: casts are the
## placeholder bodies under the demo's real cast keys.

const PeopleBook := preload("res://demo/people/people_book.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const TapsScript := preload("res://demo/people/people_taps.gd")
const PeopleScript := preload("res://demo/people/demo_people.gd")
const Words := preload("res://demo/people/people_text.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const FedScript := preload("res://demo/kitchen/nourishment.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelCrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const WaterPlayTest := preload("res://test/test_demo_water_play.gd")
const GraphTest := preload("res://test/test_demo_graph.gd")
const FarmUiTest := preload("res://test/test_demo_farm_ui.gd")
const KitchenTest := preload("res://test/test_demo_kitchen.gd")
const ForestSkills := preload("res://demo/forestry/forest_skills.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")

## The demo cast in its manifest order (demo/assets/manifest.json), with Brendan's names (2026-10-01).
const KEYS: Array[StringName] = [&"mouse_keeper", &"mouse_fieldworker", &"squirrel_gatherer", &"squirrel_forester",
	&"otter_boatwright", &"otter_fisher", &"mole_digger", &"badger_quarryman", &"beaver_bridgewright"]
const NAMES: Array[String] = ["Wenna Tallowby", "Jory Whitethorn", "Linnet Whinberry", "Tobit Highbough",
	"Tegwin Slipstone", "Corra Netley", "Tuppen Clayholm", "Hulda Slatebrook", "Elstan Weirholt"]
## Molespeak's words (DEC-017's light dialect and the old Foremole's heavy one), as whole words.
const DIALECT_PATTERN: String = "(?i)\\b(hurr|burr|zurr|oi|moi|ee|loik|thurr|yurr|dugged|foine|'azelnuts)\\b"
const HOUR_TICKS: int = SimClock.TICKS_PER_HOUR
const DAY_TICKS: int = SimClock.TICKS_PER_DAY

var _nodes: Array[Node] = []
var _borrowed: Array[RefCounted] = []


func after_each() -> void:
	"""Free what was built; let borrowed suites clean up."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	for suite: RefCounted in _borrowed:
		suite.call(&"after_each")
	_borrowed.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


static func manifest() -> Dictionary:
	"""A manifest naming the demo's nine cast keys, none with a loadable body (placeholders under real keys)."""
	var cast := {}
	for key: StringName in KEYS:
		cast[String(key)] = {"body": "res://no/such/body.tscn"}
	return {"cast": cast}


func _cast() -> DemoCastScript:
	"""The demo's nine residents, as placeholders under their keys."""
	var cast: DemoCastScript = _keep(DemoCastScript.new())
	cast.build(manifest(), [] as Array[Dictionary], [] as Array[Vector3])
	return cast


func _ledger(n: int) -> Ledger:
	"""A ledger for `n` residents."""
	var ledger := Ledger.new()
	ledger.setup(n)
	return ledger


func _taps(n: int) -> TapsScript:
	"""Taps writing a fresh ledger for `n` residents, on a fresh calendar."""
	var taps := TapsScript.new()
	taps.ledger = _ledger(n)
	taps.calendar = CalendarScript.new()
	return taps


static func has_dialect(text: String) -> bool:
	"""Whether `text` carries any dialect word (whole words: "hurry" is no "hurr")."""
	var pattern := RegEx.new()
	pattern.compile(DIALECT_PATTERN)
	return pattern.search(text) != null


# --- the data file -------------------------------------------------------------------------------------------

func test_the_data_file_names_every_demo_resident_as_ruled() -> void:
	"""Nine rows, Brendan's names (option A), each with an interest and a speech; provenance says ORIGINAL."""
	assert_true(PeopleBook.load_from(), "the people file reads")
	for k: int in KEYS.size():
		assert_equal(PeopleBook.name_of(KEYS[k]), NAMES[k], "%s is %s" % [KEYS[k], NAMES[k]])
		assert_false(PeopleBook.interest_of(KEYS[k]).is_empty(), "%s has an interest" % NAMES[k])
		assert_false(PeopleBook.speech_of(KEYS[k]).is_empty(), "%s has a way of speaking" % NAMES[k])
		assert_false(PeopleBook.evening_of(KEYS[k]).is_empty(), "%s has an evening pastime" % NAMES[k])
	assert_equal(PeopleBook.interest_of(&"mouse_keeper"), "carves tiny animal figures for the windowsills", "Wenna")
	assert_equal(PeopleBook.interest_of(&"otter_fisher"), "sings rounds and teaches them to anyone nearby", "Corra")
	assert_true(PeopleBook.provenance().begins_with("ORIGINAL"), "provenance recorded: original, not the books")
	assert_true(PeopleBook.provenance().contains("not Rowan"), "the keeper is not Rowan")
	assert_equal(PeopleBook.first_name_of(&"mouse_keeper"), "Wenna", "first name")
	assert_equal(PeopleBook.name_of(&"placeholder_2"), "", "a placeholder has no person")
	assert_equal(PeopleBook.first_name_of(&"hermit"), "", "nor a key without a row")


func test_two_residents_of_a_species_differ_and_trades_stay_roles() -> void:
	"""Same species, different names, trades and interests; the role is the key's trade, written with the name."""
	assert_true(PeopleBook.name_of(&"mouse_keeper") != PeopleBook.name_of(&"mouse_fieldworker"), "two mice")
	assert_true(PeopleBook.interest_of(&"otter_boatwright") != PeopleBook.interest_of(&"otter_fisher"), "two otters")
	assert_equal(PeopleBook.role_of(&"mouse_keeper"), "keeper", "the keeper's role")
	assert_equal(PeopleBook.species_of(&"beaver_bridgewright"), "beaver", "species")
	assert_equal(PeopleBook.with_role("Wenna Tallowby", &"mouse_keeper"), "Wenna Tallowby (mouse keeper)", "with role")
	assert_equal(PeopleBook.with_role("Placeholder 1", &"placeholder_1"), "Placeholder 1", "none to add")
	assert_equal(PeopleBook.role_of(&"hermit"), "", "a one-word key has no role")
	assert_equal(PeopleBook.species_of(&"placeholder_4"), "", "nor species")


func test_only_the_mole_has_dialect_and_it_is_light() -> void:
	"""DEC-017: Tuppen's light molespeak -- at most two words a tag, one tag a line -- and nobody else's."""
	assert_true(has_dialect("Oi'll dig, hurr.") and has_dialect("Burr aye") and not has_dialect("No hurry, free"),
		"the detector reads whole words")
	for key: StringName in KEYS:
		var tags: PackedStringArray = PeopleBook.dialect_of(key)
		assert_equal(tags.is_empty(), key != &"mole_digger", "%s dialect: %s" % [key, tags])
		for tag: String in tags:
			assert_true(tag.split(" ", false).size() <= PeopleBook.MAX_TAG_WORDS, "a light tag: %s" % tag)
	assert_equal(PeopleBook.spoken(&"mole_digger", "A good day's work.", 0), "A good day's work, hurr.", "one tag")
	assert_equal(PeopleBook.spoken(&"mole_digger", "A good day's work.", 1), "A good day's work, burr aye.", "the next")
	assert_equal(PeopleBook.spoken(&"mole_digger", "Done!", 0), "Done, hurr!", "before its stop")
	assert_equal(PeopleBook.spoken(&"mole_digger", "Done", 0), "Done, hurr.", "a stop added")
	assert_equal(PeopleBook.spoken(&"otter_fisher", "Not bad work, friend!", 0), "Not bad work, friend!", "plain")
	assert_equal(PeopleBook.spoken(&"mole_digger", "", 0), "", "nothing said")


func test_a_dialect_tag_longer_than_two_words_is_dropped() -> void:
	"""A data row's tag of three words is not light dialect: refused; the book read again after."""
	var path: String = "user://test_people_tags.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"people": {"mole_digger": {"name": "T", "dialect": ["hurr", "burr aye oi", " "]}}}))
	file.close()
	assert_true(PeopleBook.load_from(path), "read")
	assert_equal(PeopleBook.dialect_of(&"mole_digger"), PackedStringArray(["hurr"]), "only the light one")
	assert_true(PeopleBook.load_from(), "the demo's own again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_broken_or_missing_file_leaves_trade_labels() -> void:
	"""No file: no person; the default file again: the names are back."""
	assert_false(PeopleBook.load_from("res://no/such/people.json"), "missing")
	assert_equal(DemoActorScript.name_for(&"mouse_keeper"), "Mouse keeper", "its key's label")
	assert_false(PeopleBook.load_from("res://demo/sound/sound_table.json"), "not a people table")
	assert_true(PeopleBook.load_from(), "the demo's own file")
	assert_equal(DemoActorScript.name_for(&"mouse_keeper"), "Wenna Tallowby", "named again")


func test_the_cast_carries_the_names_and_roles() -> void:
	"""Every actor's display_name is its person's; its role and its name with role follow its key."""
	var cast := _cast()
	assert_equal(cast.actor_count(), KEYS.size(), "nine")
	for k: int in KEYS.size():
		var actor := cast.actor(k) as DemoActorScript
		assert_equal(actor.display_name, NAMES[k], "actor %d" % k)
	var keeper := cast.actor(0) as DemoActorScript
	assert_equal([keeper.role(), keeper.name_with_role()], ["keeper", "Wenna Tallowby (mouse keeper)"], "the keeper")
	var placeholders: DemoCastScript = _keep(DemoCastScript.new())
	placeholders.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	var p0 := placeholders.actor(0) as DemoActorScript
	assert_equal([p0.display_name, p0.role(), p0.name_with_role()], ["Placeholder 0", "", "Placeholder 0"], "unnamed")


# --- the ledger ----------------------------------------------------------------------------------------------

func test_a_deed_and_its_events_are_kept_structured() -> void:
	"""A two-builder bridge: one deed, two events, words made when read; a refused deed is none."""
	var ledger := _ledger(3)
	var deed: int = ledger.begin_deed(Ledger.KIND_BRIDGE, 900, 0, 1)
	assert_true(ledger.add_event(deed, Ledger.KIND_BRIDGE, 1, -1, NoticesScript.TARGET_BRIDGE, 2, "neck bridge"), "one")
	assert_true(ledger.add_event(deed, Ledger.KIND_BRIDGE, 2, -1, NoticesScript.TARGET_BRIDGE, 2, "neck bridge"), "two")
	assert_equal([ledger.event_count(), ledger.kind_of(deed), ledger.lead_of(deed)], [2, Ledger.KIND_BRIDGE, 1], "kept")
	assert_equal(Words.event_text(Ledger.KIND_BRIDGE, "neck bridge", "", 0), "Built the neck bridge", "worded")
	assert_equal(ledger.begin_deed(Ledger.KIND_COUNT, 0, 0, 1), -1, "no such kind")
	assert_equal(ledger.begin_deed(Ledger.KIND_BRIDGE, 0, 0, 3), -1, "no such resident")
	assert_false(ledger.add_event(deed + 5, Ledger.KIND_BRIDGE, 1, -1, 0, -1, ""), "no such deed")
	assert_false(ledger.add_event(deed, Ledger.KIND_BRIDGE, 7, -1, 0, -1, ""), "no such resident")
	assert_false(ledger.add_event(deed, -1, 1, -1, 0, -1, ""), "no such kind")
	var rows := PackedInt32Array()
	assert_equal(ledger.events_of_into(2, rows), 1, "resident 2's")
	assert_equal(ledger.event_of_deed(deed), 0, "its lead's row")
	assert_equal(ledger.event_of_deed(deed, 2), 1, "the other's row")
	assert_true(ledger.has_kind(2, Ledger.KIND_BRIDGE) and not ledger.has_kind(0, Ledger.KIND_BRIDGE), "who has it")
	assert_false(ledger.has_kind(2, Ledger.KIND_SKILL), "and which kind")
	assert_false(ledger.has_kind(9, Ledger.KIND_BRIDGE) or ledger.has_kind(2, Ledger.KIND_COUNT), "out of range")
	assert_true(ledger.add_event(deed, Ledger.KIND_BRIDGE, 2, 9, 0, -1, ""), "another person out of range")
	assert_equal(ledger.ev_other[2], Ledger.NOBODY, "kept as nobody")
	assert_false(ledger.add_event(ledger.deed_base + ledger.deed_kind.size(), Ledger.KIND_BRIDGE, 1, -1, 0, -1, ""),
		"one past the last deed")


func test_curation_pins_keeps_private_and_dismisses() -> void:
	"""Pinned deeds are the chronicle; a dismissed deed leaves the resident's history (not the facts)."""
	var ledger := _ledger(2)
	var a: int = ledger.record(Ledger.KIND_SKILL, 0, 10, 0, -1, 0, -1, "Felling", 4)
	var b: int = ledger.record(Ledger.KIND_FIRST_HARVEST, 0, 20, 0, -1, 0, -1, "carrot from bed 3")
	var c: int = ledger.record(Ledger.KIND_MEAL, 1, 30, 0)
	assert_true(ledger.curate(a, Ledger.CURATION_PINNED), "pinned")
	assert_true(ledger.curate(b, Ledger.CURATION_DISMISSED), "dismissed")
	assert_true(ledger.curate(c, Ledger.CURATION_PRIVATE), "private")
	assert_false(ledger.curate(c, 9), "no such curation")
	assert_false(ledger.curate(77, Ledger.CURATION_PINNED), "no such deed")
	var out := PackedInt32Array()
	assert_equal(ledger.chronicle_into(out), 1, "one pinned")
	assert_equal(out[0], a, "the skill")
	assert_equal(ledger.events_of_into(0, out), 1, "the dismissed harvest is not in its history")
	assert_equal(ledger.events_of_into(0, out, true), 2, "though it happened")
	assert_equal(ledger.curation_of(c), Ledger.CURATION_PRIVATE, "kept private")
	assert_equal(ledger.curation_of(99), Ledger.CURATION_NONE, "unknown")


func test_reflection_offers_three_best_uncurated_deeds_of_the_season() -> void:
	"""Ranked rescue, a build, a first harvest, a meal, a skill; only that season; never the rescued side."""
	var ledger := _ledger(4)
	var skill: int = ledger.record(Ledger.KIND_SKILL, 0, 1, 0, -1, 0, -1, "Felling", 3)
	var meal: int = ledger.record(Ledger.KIND_MEAL, 1, 2, 0)
	var harvest: int = ledger.record(Ledger.KIND_FIRST_HARVEST, 2, 3, 0)
	var rescue: int = ledger.begin_deed(Ledger.KIND_RESCUE, 4, 0, 3)
	ledger.add_event(rescue, Ledger.KIND_RESCUE, 3, 0, 0, -1, "")
	ledger.add_event(rescue, Ledger.KIND_RESCUED, 0, 3, 0, -1, "")
	var bridge: int = ledger.record(Ledger.KIND_BRIDGE, 1, 5, 0)
	ledger.record(Ledger.KIND_BRIDGE, 1, DAY_TICKS * 13, 1)
	var out := PackedInt32Array()
	assert_equal(ledger.reflection_into(0, out), Ledger.REFLECTION_SIZE, "three")
	assert_equal(out, PackedInt32Array([rescue, bridge, harvest]), "best first")
	ledger.curate(rescue, Ledger.CURATION_PINNED)
	ledger.reflection_into(0, out)
	assert_equal(out, PackedInt32Array([bridge, harvest, meal]), "an answered one is not offered again")
	ledger.curate(bridge, Ledger.CURATION_DISMISSED)
	ledger.curate(harvest, Ledger.CURATION_PRIVATE)
	ledger.reflection_into(0, out)
	assert_equal(out, PackedInt32Array([meal, skill]), "then the meal and the skill")
	assert_equal(ledger.reflection_into(2, out), 0, "an empty season offers nothing")
	var rescued_only := _ledger(2)
	var d: int = rescued_only.begin_deed(Ledger.KIND_RESCUED, 1, 0, 0)
	rescued_only.add_event(d, Ledger.KIND_RESCUED, 0, 1, 0, -1, "")
	assert_equal(rescued_only.reflection_into(0, out), 0, "being rescued is not offered as a deed")


func test_the_ledger_forgets_its_oldest_past_its_bounds() -> void:
	"""MAX_EVENTS and MAX_DEEDS: the oldest go first, curation with them."""
	var ledger := _ledger(1)
	for k: int in Ledger.MAX_EVENTS + 3:
		ledger.record(Ledger.KIND_SKILL, 0, k, 0, -1, 0, -1, "Felling", 1)
	assert_equal(ledger.event_count(), Ledger.MAX_EVENTS, "events capped")
	assert_equal(ledger.ev_tick[0], 3, "the oldest went")
	for k: int in Ledger.MAX_DEEDS:
		ledger.record(Ledger.KIND_SKILL, 0, k, 0, -1, 0, -1, "Felling", 1)
	assert_equal(ledger.deed_kind.size(), Ledger.MAX_DEEDS, "deeds capped")
	assert_false(ledger.is_deed(0), "the first is forgotten")
	assert_true(ledger.is_deed(ledger.deed_base), "the oldest kept")
	assert_equal(ledger.kind_of(0), -1, "a forgotten deed's kind")
	assert_equal(ledger.lead_of(0), Ledger.NOBODY, "and lead")


func test_a_first_stays_first_after_its_event_is_forgotten() -> void:
	"""`has_kind` outlives the event rows: a first harvest pushed out of the ledger is still had (review H2)."""
	var ledger := _ledger(1)
	ledger.record(Ledger.KIND_FIRST_HARVEST, 0, 0, 0)
	for k: int in Ledger.MAX_EVENTS:
		ledger.record(Ledger.KIND_SKILL, 0, k, 0, -1, 0, -1, "Felling", 1)
	var rows := PackedInt32Array()
	ledger.events_of_into(0, rows)
	for e: int in rows:
		assert_true(ledger.ev_kind[e] != Ledger.KIND_FIRST_HARVEST, "the harvest's row is gone")
	assert_true(ledger.has_kind(0, Ledger.KIND_FIRST_HARVEST), "still its first harvest")


func test_a_forgotten_deed_takes_its_events_with_it() -> void:
	"""MAX_DEEDS: the oldest deed goes, and its events (kept while the events had room) go with it."""
	var ledger := _ledger(1)
	ledger.record(Ledger.KIND_BRIDGE, 0, 0, 0, -1, 0, -1, "neck bridge")
	for k: int in Ledger.MAX_DEEDS:
		ledger.begin_deed(Ledger.KIND_SKILL, k, 0, 0)
	assert_false(ledger.is_deed(0), "forgotten")
	assert_equal(ledger.event_count(), 0, "its event too")


func test_notability_is_a_mark_and_nothing_else() -> void:
	"""REQ-SET-042: pinned and unpinned; no such resident refused."""
	var ledger := _ledger(2)
	assert_true(ledger.pin_notable(1), "pinned")
	assert_true(ledger.is_notable(1) and not ledger.is_notable(0), "one notable")
	assert_true(ledger.pin_notable(1, false), "unpinned")
	assert_false(ledger.is_notable(1), "not now")
	assert_false(ledger.pin_notable(5), "no such resident")
	assert_false(ledger.is_notable(-1), "nobody")


# --- affinity (SOC-014, the GDD's REQ-SET-035..037) ---------------------------------------------------------------

func test_affinity_follows_the_gdd_numbers() -> void:
	"""Everyday contact +2 once a pair a day; a rescue +8 per rescue; friends at 40, cleared below 25."""
	var ledger := _ledger(3)
	assert_true(ledger.everyday_contact(0, 1, 1), "a contact")
	assert_false(ledger.everyday_contact(1, 0, 1), "once a pair a day, either way round")
	assert_equal(ledger.affinity_of(0, 1), Ledger.SOCIAL_GAIN, "+2")
	assert_true(ledger.everyday_contact(0, 1, 2), "the next day")
	assert_equal(ledger.affinity_of(1, 0), 4, "+2 again")
	assert_true(ledger.add_rescue(2, 0, 2), "a rescue")
	assert_true(ledger.add_rescue(2, 0, 2), "another rescue the same day counts: once per rescue")
	assert_equal(ledger.affinity_of(0, 2), 16, "+8 twice")
	assert_false(ledger.add_rescue(1, 1, 2), "no pair with itself")
	assert_false(ledger.everyday_contact(0, 9, 2), "no such resident")
	for day: int in range(3, 21):
		ledger.everyday_contact(0, 1, day)
	assert_equal(ledger.affinity_of(0, 1), 40, "at 40")
	assert_true(ledger.are_friends(0, 1), "friends")
	assert_false(ledger.are_friends(0, 2), "not yet")
	assert_equal(ledger.affinity_of(0, 7), 0, "no pair")


func test_affinity_fades_without_contact_and_friendship_clears_below_25() -> void:
	"""§5.3: three days without contact, one point a midnight toward 0; friendship clears below 25."""
	var ledger := _ledger(2)
	var p: int = ledger.pair(0, 1)
	ledger.affinity[p] = 25
	ledger.friend[p] = 1
	ledger.last_contact_day[p] = 10
	ledger.midnight(12)
	assert_equal(ledger.affinity[p], 25, "two days: kept")
	ledger.midnight(13)
	assert_equal(ledger.affinity[p], 24, "three days: one point")
	assert_false(ledger.are_friends(0, 1), "below 25: no longer friends")
	ledger.affinity[p] = 30
	ledger.friend[p] = 1
	ledger._settle_friend(p)
	assert_true(ledger.are_friends(0, 1), "30, friends already: still friends (cleared only below 25)")
	ledger.friend[p] = 0
	ledger._settle_friend(p)
	assert_false(ledger.are_friends(0, 1), "30, not friends: not yet (friends from 40)")
	ledger.affinity[p] = 25
	ledger.friend[p] = 1
	ledger._settle_friend(p)
	assert_true(ledger.are_friends(0, 1), "exactly 25: kept")
	ledger.affinity[p] = -3
	ledger.midnight(14)
	assert_equal(ledger.affinity[p], -2, "toward 0 from below")
	ledger.affinity[p] = 100
	ledger.last_contact_day[p] = 14
	ledger._gain(p, 8, 14)
	assert_equal(ledger.affinity[p], Ledger.AFFINITY_MAX, "clamped")


func test_shared_work_counts_hours_and_suppers_count_suppers() -> void:
	"""Each whole hour worked together is an hour shared and one everyday contact; a supper is counted too."""
	var ledger := _ledger(2)
	assert_false(ledger.add_shared_work(0, 1, Ledger.SHARED_HOUR_TICKS - 1, 1), "not an hour")
	assert_true(ledger.add_shared_work(0, 1, 1, 1), "an hour")
	assert_equal([ledger.shared_hours[ledger.pair(0, 1)], ledger.affinity_of(0, 1)], [1, 2], "one hour, +2")
	assert_true(ledger.add_shared_work(1, 0, Ledger.SHARED_HOUR_TICKS * 2, 1), "two more")
	assert_equal([ledger.shared_hours[ledger.pair(0, 1)], ledger.affinity_of(0, 1)], [3, 2], "capped a day")
	assert_true(ledger.add_supper(0, 1, 2), "a supper")
	assert_equal([ledger.suppers[ledger.pair(0, 1)], ledger.affinity_of(0, 1)], [1, 4], "counted, +2")
	assert_false(ledger.add_supper(0, 0, 2), "not alone")
	assert_false(ledger.add_shared_work(0, 1, 0, 2), "no time")


func test_relationship_lines_are_light_and_from_what_happened() -> void:
	"""Rescued by, friends, often works with, often at supper: at most three, each person once."""
	var ledger := _ledger(5)
	var names := PackedStringArray(["A", "B", "C", "D", "E"])
	assert_equal(Words.relation_lines(ledger, 0, names), PackedStringArray(), "nothing happened: nothing said")
	var d: int = ledger.begin_deed(Ledger.KIND_RESCUE, 1, 0, 1)
	ledger.add_event(d, Ledger.KIND_RESCUE, 1, 0, 0, -1, "")
	ledger.add_event(d, Ledger.KIND_RESCUED, 0, 1, 0, -1, "")
	ledger.shared_hours[ledger.pair(0, 2)] = Words.OFTEN_HOURS
	ledger.shared_hours[ledger.pair(0, 1)] = 9
	ledger.suppers[ledger.pair(0, 3)] = Words.OFTEN_SUPPERS
	assert_equal(Words.relation_lines(ledger, 0, names), PackedStringArray(["Rescued by B", "Often works with C",
		"Often at supper with D"]), "B is named once, for the rescue")
	assert_equal(Words.relation_lines(ledger, 1, names), PackedStringArray(["Rescued A"]),
		"the rescuer's side: A is named once, though they also work together")
	ledger.friend[ledger.pair(0, 4)] = 1
	assert_equal(Words.relation_lines(ledger, 0, names).size(), Words.MAX_RELATIONS, "at most three")
	assert_equal(Words.relation_lines(ledger, 0, names)[1], "Friends with E", "friends before work")
	ledger.shared_hours[ledger.pair(2, 3)] = 2
	assert_equal(Words.relation_lines(ledger, 3, names), PackedStringArray(["Often at supper with A"]), "two hours: not often")
	ledger.suppers[ledger.pair(1, 4)] = 3
	ledger.friend[ledger.pair(1, 3)] = 1
	ledger.shared_hours[ledger.pair(1, 2)] = 3
	assert_equal(Words.relation_lines(ledger, 1, names).size(), 3, "never more than three lines (four apply)")


# --- the taps: committed deeds only ------------------------------------------------------------------------------

func test_a_rescue_is_remembered_only_when_a_rescuer_succeeds() -> void:
	"""The real water rescue: a swimmer tows the victim ashore -- one deed, the rescuer's and the victim's rows, +8;
	and in the same village a victim nobody reached, washed ashore by the safety net, is no assistance and no memory."""
	var suite: RefCounted = WaterPlayTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var rig: RefCounted = suite.call(&"_rig")
	var play: Node = rig.get(&"play")
	var rescue: RescueScript = play.get(&"rescue")
	var cast: DemoCastScript = rig.get(&"cast")
	var taps := _taps(cast.actor_count())
	taps.rescue = rescue
	taps.watch()
	suite.call(&"_swimmer", rig, 0, 600)
	suite.call(&"_swimmer", rig, 2, 1100)
	var victim: BrainScript = (cast.actor(0) as DemoActorScript).brain
	victim.water_place(WaterPlayTest.RUN_MID, -0.18, 0.0)
	victim.water_in()
	rescue.start_difficulty(0)
	taps.poll()
	assert_equal(taps.ledger.event_count(), 0, "in difficulty, a rescuer on the way: nothing yet")
	assert_true(suite.call(&"_run", rig, func() -> bool: return victim.task is Tasks.RestTask), "brought ashore")
	assert_equal([rescue.assists, rescue.assisted_by, rescue.assisted_victim], [1, PackedInt32Array([2]),
		PackedInt32Array([0])], "the assistance logged")
	assert_equal(taps.poll(), 1, "one deed")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.ev_kind[0], ledger.ev_who[0], ledger.ev_other[0]], [Ledger.KIND_RESCUE, 2, 0], "the rescuer's")
	assert_equal([ledger.ev_kind[1], ledger.ev_who[1], ledger.ev_other[1]], [Ledger.KIND_RESCUED, 0, 2], "the victim's")
	assert_equal(ledger.affinity_of(0, 2), Ledger.RESCUE_GAIN, "REQ-SET-036's +8")
	assert_equal(taps.poll(), 0, "said once")
	var second: BrainScript = (cast.actor(5) as DemoActorScript).brain
	suite.call(&"_swimmer", rig, 5, 600)
	for who: int in range(0, 5):
		(cast.actor(who) as DemoActorScript).brain.water_hold = true
	second.water_place(Vector2(24.4, 14.0), -0.18, 0.0)
	second.water_in()
	rescue.start_difficulty(5)
	rescue.victim_task(5).waited_s = RescueScript.WASH_ASHORE_S
	rescue.update(RescueScript.DISPATCH_S)
	assert_true(second.task is Tasks.RestTask, "washed ashore")
	assert_equal(rescue.assists, 1, "no assistance")
	assert_equal(taps.poll(), 0, "and no memory")
	assert_equal(ledger.event_count(), 2, "only the real rescue")


func test_the_assistance_log_keeps_its_newest_and_counts_all() -> void:
	"""ASSIST_LOG rows at most; the taps read only what is new, even past the log's length."""
	var rescue := RescueScript.new()
	var taps := _taps(3)
	taps.rescue = rescue
	taps.watch()
	for k: int in RescueScript.ASSIST_LOG + 2:
		rescue._log_assist(k % 2, 2)
	assert_equal([rescue.assists, rescue.assisted_by.size()], [RescueScript.ASSIST_LOG + 2, RescueScript.ASSIST_LOG],
		"capped, counted")
	assert_equal(taps.poll(), RescueScript.ASSIST_LOG, "what the log still holds")
	rescue._log_assist(1, 0)
	assert_equal(taps.poll(), 1, "then only the new one")
	assert_equal(taps.ledger.ev_who[taps.ledger.event_count() - 2], 1, "its rescuer")


func test_a_bridge_is_its_builders_deed_only_when_it_opens() -> void:
	"""The real bridge build: nothing while it is built; at the opening, the builder's deed with the bridge's name and
	place. A bridge row freed before it opened (its generation moved on) forgets who worked on it."""
	var suite: RefCounted = WaterPlayTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var rig: RefCounted = suite.call(&"_rig")
	var play: Node = rig.get(&"play")
	var cast: DemoCastScript = rig.get(&"cast")
	(suite.get(&"_services") as RefCounted).get(&"stores").add_planks(6000)
	var taps := _taps(cast.actor_count())
	taps.bridges = play.get(&"bridges")
	taps.bridge_crew = play.get(&"crew")
	taps.watch()
	play.call(&"select_candidate", 0)
	play.call(&"build", 0, PackedInt32Array([3]))
	var seen: Array[int] = [0]
	assert_true(suite.call(&"_run", rig, func() -> bool:
		seen[0] += taps.poll()
		return taps.bridges.is_open(0), 12000), "open")
	seen[0] += taps.poll()
	assert_equal(seen[0], 1, "one deed, at the opening")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.ev_kind[0], ledger.ev_who[0], ledger.ev_place_kind[0], ledger.ev_place_id[0]],
		[Ledger.KIND_BRIDGE, 3, NoticesScript.TARGET_BRIDGE, 0], "Placeholder 3's, at bridge 0")
	assert_equal(ledger.ev_subject[0], taps.bridges.names[0], "named as at its opening")


func test_a_bridge_credits_only_hands_that_worked_on_it() -> void:
	"""Two builders who loaded, carried or built are both credited, the lowest first; one only walking to it is not."""
	var taps := _taps(4)
	taps.bridges = BridgesScript.new()
	taps.bridges.phase.resize(BridgesScript.MAX_BRIDGES)
	taps.bridges.generation.resize(BridgesScript.MAX_BRIDGES)
	taps.bridges.names.resize(BridgesScript.MAX_BRIDGES)
	taps.bridges.names[0] = "neck bridge"
	taps.bridge_crew = BridgeCrewScript.new()
	taps.bridge_crew.builder.resize(BridgesScript.MAX_BRIDGES)
	taps.bridge_crew.builder.fill(-1)
	taps.bridge_crew.step.resize(BridgesScript.MAX_BRIDGES)
	taps.watch()
	taps.bridges.phase[0] = BridgesScript.PHASE_PLANNED
	for pair: Array in [[3, BridgeCrewScript.STEP_GO_SOURCE], [2, BridgeCrewScript.STEP_LOAD],
			[1, BridgeCrewScript.STEP_CARRY], [2, BridgeCrewScript.STEP_WORK], [0, BridgeCrewScript.STEP_WAITING]]:
		taps.bridge_crew.builder[0] = pair[0]
		taps.bridge_crew.step[0] = pair[1]
		taps.poll()
	taps.bridges.phase[0] = BridgesScript.PHASE_OPEN
	assert_equal(taps.poll(), 1, "one deed")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.event_count(), ledger.ev_who[0], ledger.ev_who[1]], [2, 1, 2], "1 and 2 built it; 1 leads")
	assert_equal(ledger.lead_of(taps.new_deeds[0]), 1, "told of 1 first")


func _bridge_taps(residents: int) -> TapsScript:
	"""Taps over a bare bridge table and crew (row 0 named), watched."""
	var taps := _taps(residents)
	taps.bridges = BridgesScript.new()
	taps.bridges.phase.resize(BridgesScript.MAX_BRIDGES)
	taps.bridges.generation.resize(BridgesScript.MAX_BRIDGES)
	taps.bridges.names.resize(BridgesScript.MAX_BRIDGES)
	taps.bridges.names[0] = "neck bridge"
	taps.bridge_crew = BridgeCrewScript.new()
	taps.bridge_crew.builder.resize(BridgesScript.MAX_BRIDGES)
	taps.bridge_crew.builder.fill(-1)
	taps.bridge_crew.step.resize(BridgesScript.MAX_BRIDGES)
	taps.watch()
	return taps


func test_a_new_bridge_in_the_row_forgets_the_old_one_s_builders() -> void:
	"""A row's generation moves on while planned (another bridge in it): its opening is not the old builders' deed."""
	var taps := _bridge_taps(3)
	taps.bridges.phase[0] = BridgesScript.PHASE_PLANNED
	taps.bridge_crew.builder[0] = 2
	taps.bridge_crew.step[0] = BridgeCrewScript.STEP_WORK
	taps.poll()
	taps.bridge_crew.builder[0] = -1
	taps.bridges.generation[0] += 1
	taps.poll()
	taps.bridges.phase[0] = BridgesScript.PHASE_OPEN
	assert_equal(taps.poll(), 0, "nobody worked on the new one: no deed")


func test_a_bridge_counts_only_an_opening_straight_from_planned() -> void:
	"""Planned with hands, then free (same generation), then open: no PLANNED -> OPEN edge, no deed."""
	var taps := _bridge_taps(3)
	taps.bridges.phase[0] = BridgesScript.PHASE_PLANNED
	taps.bridge_crew.builder[0] = 1
	taps.bridge_crew.step[0] = BridgeCrewScript.STEP_CARRY
	taps.poll()
	taps.bridges.phase[0] = BridgesScript.PHASE_FREE
	taps.poll()
	taps.bridges.phase[0] = BridgesScript.PHASE_OPEN
	assert_equal(taps.poll(), 0, "no edge")


## A tunnel network whose cuts and done pieces a test sets (the taps read only these).
class StubGraph extends "res://demo/tunnel/underground_graph.gd":
	var cuts: Dictionary = {}
	var done_pieces: Dictionary = {}
	var reads: int = 0

	func cut_count(slot: int) -> int:
		"""The cuts a test set (each read counted)."""
		reads += 1
		return int(cuts.get(slot, 0))

	func piece_done(p: int) -> bool:
		"""Whether a test said piece `p` is done."""
		return bool(done_pieces.get(p, false))

	func piece_segments_into(p: int, out: PackedInt32Array) -> void:
		"""Every live slot of piece `p`."""
		out.clear()
		for slot: int in TunnelRules.MAX_SEGMENTS:
			if phase[slot] != PHASE_FREE and piece[slot] == p:
				out.append(slot)


func _stub_taps(residents: int) -> TapsScript:
	"""Taps over a stub network: piece 0 live, segment 3 of it DIGGING, led by resident 0; a crew of their own."""
	var taps := _taps(residents)
	var graph := StubGraph.new()
	graph.piece_live[0] = 1
	graph.phase[3] = GraphScript.PHASE_DIGGING
	graph.piece[3] = 0
	graph.digger[3] = 0
	taps.network = graph
	taps.tunnel_crew = TunnelCrewScript.new()
	for who: int in residents:
		taps.tunnel_crew.set_resident(who, "mouse")
	taps.watch()
	return taps


func _cut(taps: TapsScript, slot: int, cuts: int) -> void:
	"""Segment `slot` cut to `cuts` (its progress moves on with it), one poll."""
	var graph: StubGraph = taps.network
	graph.cuts[slot] = cuts
	graph.dig_usec[slot] += 1000
	taps.poll()


func _finish(taps: TapsScript, p: int) -> int:
	"""Piece `p` done, the graph changed; the poll's deeds."""
	var graph: StubGraph = taps.network
	graph.done_pieces[p] = true
	graph.phase[3] = GraphScript.PHASE_OPEN
	graph.revision += 1
	return taps.poll()


func test_only_hands_at_a_cut_are_a_tunnel_s_and_the_crew_only_at_its_post() -> void:
	"""The lead credited only once a cut is made; a crew member at its post then, yes; one away from it, no."""
	var taps := _stub_taps(4)
	taps.tunnel_crew.member_site[1] = 3
	taps.tunnel_crew.member_present[1] = 1
	taps.tunnel_crew.member_site[2] = 3
	var graph: StubGraph = taps.network
	graph.dig_usec[3] += 1000
	taps.poll()
	assert_equal(taps._piece_hands[0], 0, "progress but no cut: nobody yet")
	_cut(taps, 3, 1)
	assert_equal(taps._piece_hands[0], 0b011, "a cut: the lead and the crew at its post, not the one away")
	assert_equal(_finish(taps, 0), 1, "done: one deed")
	assert_equal([taps.ledger.ev_who[0], taps.ledger.ev_who[1], taps.ledger.event_count()], [0, 1, 2], "theirs")
	assert_equal(taps.ledger.ev_kind[0], Ledger.KIND_TUNNEL, "a tunnel")


func test_cuts_are_read_only_when_a_dig_moved_and_a_new_segment_starts_from_none() -> void:
	"""Review H1: a segment whose progress and phase stand still is not read again. A new segment in the slot (its
	generation moved) counts its own first cut, however far the old one had got."""
	var taps := _stub_taps(3)
	var graph: StubGraph = taps.network
	_cut(taps, 3, 5)
	var reads: int = graph.reads
	taps.poll()
	taps.poll()
	assert_equal(graph.reads, reads, "nothing moved: not read again")
	taps._piece_hands[0] = 0
	graph.generation[3] += 1
	graph.digger[3] = 2
	_cut(taps, 3, 1)
	assert_equal(taps._piece_hands[0], 1 << 2, "the new segment's first cut credits its lead")


func test_a_room_is_a_room_and_a_dead_or_new_piece_is_nobody_s() -> void:
	"""A room's piece is KIND_ROOM; a piece no longer live is no deed; a new generation forgets the hands."""
	var taps := _stub_taps(2)
	var graph: StubGraph = taps.network
	graph.piece_room[0] = 0
	_cut(taps, 3, 1)
	assert_equal(_finish(taps, 0), 1, "a deed")
	assert_equal(taps.ledger.ev_kind[0], Ledger.KIND_ROOM, "a room")
	var dead := _stub_taps(2)
	_cut(dead, 3, 1)
	(dead.network as StubGraph).piece_live[0] = 0
	assert_equal(_finish(dead, 0), 0, "not live: nobody's")
	var renewed := _stub_taps(2)
	_cut(renewed, 3, 1)
	var g: StubGraph = renewed.network
	g.piece_gen[0] += 1
	g.revision += 1
	renewed.poll()
	assert_equal(_finish(renewed, 0), 0, "a new piece in the row: the old hands forgotten")


func test_a_piece_done_before_the_watch_is_no_deed() -> void:
	"""The baseline: a piece already done at `watch()` is not recorded when the graph next changes."""
	var taps := _taps(1)
	var graph := StubGraph.new()
	graph.piece_live[0] = 1
	graph.phase[3] = GraphScript.PHASE_OPEN
	graph.piece[3] = 0
	graph.done_pieces[0] = true
	taps.network = graph
	taps._piece_hands.resize(TunnelRules.MAX_PIECES)
	taps.watch()
	taps._piece_hands[0] = 1
	graph.revision += 1
	assert_equal(taps.poll(), 0, "already done")


func test_a_tunnel_dug_through_is_its_diggers_and_a_paused_one_is_nobodys() -> void:
	"""The real network: a dig called away part dug is PAUSED -- no memory; dug through later, the digger's deed, with
	the tunnel's place. A piece dropped before any ground was broken leaves none either."""
	var graph_suite: RefCounted = GraphTest.new()
	var space := CastSpaceScript.new()
	space.setup([], [])
	var graph: GraphScript = space.tunnels
	var brain: BrainScript = graph_suite.call(&"_walker", space, Vector2(-1.0, -1.0))
	var taps := _taps(1)
	taps.network = graph
	taps.watch()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(GraphTest._route([Vector2i(0, 0), Vector2i(8192, 0)]), 2, brain.index, ref), "laid")
	brain.order_dig(ref[0], ref[1])
	for f: int in 600:
		brain.step(GraphTest.DT)
		taps.poll()
	assert_false(graph.piece_done(ref[2]), "part dug")
	assert_true(graph.piece_percent(ref[2]) > 0, "some ground broken: %d%%" % graph.piece_percent(ref[2]))
	brain.release()
	graph.stop_digging(ref[0], ref[1])
	taps.poll()
	assert_equal(taps.ledger.event_count(), 0, "called away, paused: no memory")
	assert_true(graph.start_dig(ref[0], graph.generation[ref[0]], brain.index), "resumed")
	brain.order_dig(ref[0], graph.generation[ref[0]])
	for f: int in roundi(150.0 / GraphTest.DT):
		brain.step(GraphTest.DT)
		taps.poll()
		if graph.piece_done(ref[2]):
			break
	taps.poll()
	assert_true(graph.piece_done(ref[2]), "dug through")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.event_count(), ledger.ev_kind[0], ledger.ev_who[0]], [1, Ledger.KIND_TUNNEL, 0], "its digger's")
	assert_equal([ledger.ev_place_kind[0], ledger.ev_place_id[0]], [NoticesScript.TARGET_TUNNEL, ref[0]], "its place")
	assert_equal(ledger.ev_subject[0], "tunnel %d" % (ref[0] + 1), "named")
	var other := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(GraphTest._route([Vector2i(0, 4096), Vector2i(8192, 4096)]), 2, brain.index, other),
		"a second laid")
	graph.stop_digging(other[0], other[1])
	taps.poll()
	assert_equal(graph.piece_live[other[2]], 0, "dropped unbroken")
	assert_equal(taps.ledger.event_count(), 1, "no memory of it")


func test_piece_words_name_rooms_tunnels_and_ways_down() -> void:
	"""A room by its name and number; a tunnel by its first segment; a link as the way down it is."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var taps := _taps(1)
	taps.network = space.tunnels
	var graph: GraphScript = space.tunnels
	assert_equal(taps.piece_words(0, 4), "tunnel 5", "a tunnel")
	graph.seg_kind[4] = GraphScript.SEG_LINK
	graph.seg_link[4] = 2
	assert_equal(taps.piece_words(0, 4), "the stairs down (tunnel 5)", "stairs")


func test_a_first_harvest_is_remembered_once_and_a_cancelled_one_not_at_all() -> void:
	"""The real farm: a harvest stored is logged and is its worker's first harvest (once); a harvest cancelled after
	it was cut is carried in as its delivery and logged as no harvest."""
	var suite: RefCounted = FarmUiTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var cast: DemoCastScript = suite.call(&"_cast")
	var sim: RefCounted = FarmUiTest.SimScript.new()
	var pantry: RefCounted = suite.call(&"_pantry", cast)
	var crew: FarmCrewScript = suite.call(&"_crew", cast, sim, pantry)
	var taps := _taps(cast.actor_count())
	taps.farm_crew = crew
	taps.watch()
	sim.call(&"advance_usec", 24 * CalendarScript.HOUR_USEC)
	crew.order(FarmUiTest.JobsScript.KIND_HARVEST, FarmUiTest.BED_CARROTS, PackedInt32Array([3]),
		FarmUiTest.JobsScript.ORIGIN_PLAYER)
	assert_true(suite.call(&"_run", cast, crew, 180.0, func() -> bool: return crew.harvests > 0), "stored")
	assert_equal([crew.harvested_by, crew.harvested_bed, crew.harvested_item], [PackedInt32Array([3]),
		PackedInt32Array([FarmUiTest.BED_CARROTS]), PackedInt32Array([FarmUiTest.CARROT])], "logged")
	assert_equal(taps.poll(), 1, "a first harvest")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.ev_kind[0], ledger.ev_who[0], ledger.ev_place_kind[0], ledger.ev_place_id[0]],
		[Ledger.KIND_FIRST_HARVEST, 3, NoticesScript.TARGET_BED, FarmUiTest.BED_CARROTS], "Placeholder 3's, its bed")
	assert_equal(ledger.ev_subject[0], "carrot from bed %d" % (FarmUiTest.BED_CARROTS + 1), "what and where")
	crew.harvests += 1
	crew.harvested_by.append(3)
	crew.harvested_bed.append(FarmUiTest.BED_CARROTS)
	crew.harvested_item.append(FarmUiTest.CARROT)
	assert_equal(taps.poll(), 0, "a second harvest is no first")
	crew.harvests += 1
	crew.harvested_by.append(5)
	crew.harvested_bed.append(0)
	crew.harvested_item.append(-1)
	assert_equal(taps.poll(), 1, "another resident's first")
	assert_equal(ledger.ev_subject[1], "a crop from bed 1", "an unknown item")


func test_a_harvest_cancelled_after_it_was_cut_is_no_harvest() -> void:
	"""Decision 0222's delivery: carried in and stored, but the cancelled job leaves no memory."""
	var suite: RefCounted = FarmUiTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var cast: DemoCastScript = suite.call(&"_cast")
	var sim: RefCounted = FarmUiTest.SimScript.new()
	var pantry: RefCounted = suite.call(&"_pantry", cast)
	var crew: FarmCrewScript = suite.call(&"_crew", cast, sim, pantry)
	var taps := _taps(cast.actor_count())
	taps.farm_crew = crew
	taps.watch()
	sim.call(&"advance_usec", 24 * CalendarScript.HOUR_USEC)
	crew.order(FarmUiTest.JobsScript.KIND_HARVEST, FarmUiTest.BED_CARROTS, PackedInt32Array([3]),
		FarmUiTest.JobsScript.ORIGIN_PLAYER)
	assert_true(suite.call(&"_run", cast, crew, 90.0, func() -> bool:
		return crew.jobs.current_step(0) == FarmUiTest.JobsScript.STEP_CARRY_STORE), "cut and carrying")
	assert_equal(crew.cancel_bed(FarmUiTest.BED_CARROTS), 1, "cancelled")
	assert_true(suite.call(&"_run", cast, crew, 90.0, func() -> bool: return crew.jobs.live_count() == 0), "delivered")
	assert_true(int(pantry.call(&"milli_of", FarmUiTest.CARROT)) > 0, "in store")
	assert_equal(crew.harvests, 0, "no harvest logged")
	taps.poll()
	assert_equal(taps.ledger.event_count(), 0, "no memory")


func test_a_meal_for_everyone_is_its_cooks_first_and_a_supper_is_shared() -> void:
	"""The real kitchen, 14:00 to supper's end on day 0: every batch is the cook's; supper fed all four, so the cook's
	first meal for everyone is remembered (once), and every pair at it shared a supper."""
	var suite: RefCounted = KitchenTest.new()
	var v: RefCounted = suite.call(&"_village", 4, KitchenTest.tick_at(0, 14))
	suite.call(&"_stock", v, KitchenTest.OATS, 20000)
	suite.call(&"_stock", v, KitchenTest.CARROT, 30000)
	suite.call(&"_open", v)
	var kitchen: KitchenScript = v.get(&"kitchen")
	var taps := _taps(4)
	taps.kitchen = kitchen
	taps.calendar = v.get(&"calendar")
	taps.watch()
	var deeds: Array[int] = [0]
	suite.call(&"_run", v, 6 * KitchenTest.FRAMES_PER_HOUR, func() -> bool:
		deeds[0] += taps.poll()
		return not kitchen.meal_keys.is_empty())
	assert_false(kitchen.meal_keys.is_empty(), "supper served and over")
	assert_equal(kitchen.cooked_by.size(), kitchen.cooked_keys.size(), "who cooked each batch")
	for b: int in kitchen.cooked_by.size():
		assert_equal(kitchen.cooked_by[b], kitchen.designated, "batch %d: the village cook" % b)
	assert_equal(kitchen.meal_without[-1], 0, "nobody went without")
	assert_equal(deeds[0], 1, "one deed")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.ev_kind[0], ledger.ev_who[0]], [Ledger.KIND_MEAL, kitchen.designated], "the cook's")
	assert_equal(ledger.ev_subject[0], "supper, day 1", "which meal")
	for a: int in 4:
		for b: int in range(a + 1, 4):
			assert_equal(ledger.suppers[ledger.pair(a, b)], 1, "%d and %d shared supper" % [a, b])
			assert_equal(ledger.affinity_of(a, b), Ledger.SOCIAL_GAIN, "+2")
	kitchen.meal_keys.append(kitchen.meal_keys[-1] + 1)
	kitchen.meal_ate.append(4)
	kitchen.meal_raw.append(0)
	kitchen.meal_without.append(0)
	kitchen.cooked_keys.append(kitchen.meal_keys[-1])
	kitchen.cooked_by.append(kitchen.designated)
	assert_equal(taps.poll(), 0, "a second meal for everyone is no first")


func test_a_meal_someone_went_without_is_no_deed() -> void:
	"""meal_without > 0: nobody's deed; a breakfast is not a supper shared."""
	var kitchen := KitchenScript.new()
	kitchen.fed.configure(PackedStringArray(["mouse", "mouse"]))
	var taps := _taps(2)
	taps.kitchen = kitchen
	taps.watch()
	kitchen.meal_keys.append(2)
	kitchen.meal_ate.append(1)
	kitchen.meal_raw.append(0)
	kitchen.meal_without.append(1)
	kitchen.cooked_keys.append(2)
	kitchen.cooked_by.append(0)
	for who: int in 2:
		kitchen.fed.last_meal[who] = 2
		kitchen.fed.last_outcome[who] = FedScript.OUTCOME_ATE
	assert_equal(taps.poll(), 0, "one went without: no deed")
	assert_equal(taps.ledger.suppers[taps.ledger.pair(0, 1)], 0, "a breakfast (key 2) shares no supper")
	kitchen.meal_keys.append(3)
	kitchen.meal_ate.append(1)
	kitchen.meal_raw.append(0)
	kitchen.meal_without.append(0)
	kitchen.fed.last_meal[0] = 3
	kitchen.fed.last_meal[1] = 3
	kitchen.fed.last_outcome[0] = FedScript.OUTCOME_SKIPPED
	assert_equal(taps.poll(), 0, "fed all but nobody cooked it: no deed")
	assert_equal(taps.ledger.suppers[taps.ledger.pair(0, 1)], 0, "one skipped it: not shared")
	kitchen.meal_keys.append(4)
	kitchen.meal_ate.append(0)
	kitchen.meal_raw.append(2)
	kitchen.meal_without.append(0)
	kitchen.cooked_keys.append(4)
	kitchen.cooked_by.append(1)
	assert_equal(taps.poll(), 0, "nobody ate a portion (raw food only): no meal for everyone")


func test_a_skill_level_reached_by_real_work_is_a_deed_and_a_starting_level_is_not() -> void:
	"""The woods' real skills: a forester starting at level 3 is no deed; work that lifts a novice to level 1, and a
	jump of two levels, are one deed a level, at the resident."""
	var skills := ForestSkills.new()
	skills.setup([&"squirrel_forester", &"mouse_keeper"] as Array[StringName], PackedStringArray(["squirrel", "mouse"]))
	var taps := _taps(2)
	taps.add_skill("Felling", func(who: int) -> int: return skills.xp_of(who, ForestRules.SKILL_FELLING))
	taps.watch()
	taps.calendar.tick += TapsScript.SKILL_POLL_TICKS
	assert_equal(taps.poll(), 0, "level 3 to start: nothing")
	assert_true(skills.add_work(1, ForestRules.SKILL_FELLING, ForestRules.xp_of_level(1) / ForestRules.XP_PER_WU), "a level")
	assert_equal(taps.poll(), 0, "looked at only every SKILL_POLL_TICKS")
	taps.calendar.tick += TapsScript.SKILL_POLL_TICKS
	assert_equal(taps.poll(), 1, "level 1")
	var ledger: Ledger = taps.ledger
	assert_equal([ledger.ev_kind[0], ledger.ev_who[0], ledger.ev_subject[0], ledger.ev_amount[0]],
		[Ledger.KIND_SKILL, 1, "Felling", 1], "the novice's first level")
	assert_equal(Words.event_text(Ledger.KIND_SKILL, "Felling", "", 1), "Reached Felling · Level 1", "worded")
	skills.add_work(1, ForestRules.SKILL_FELLING, (ForestRules.xp_of_level(3) - ForestRules.xp_of_level(1)) / ForestRules.XP_PER_WU)
	taps.calendar.tick += TapsScript.SKILL_POLL_TICKS
	assert_equal(taps.poll(), 2, "levels 2 and 3")
	assert_equal([ledger.ev_amount[1], ledger.ev_amount[2]], [2, 3], "each level")


func test_working_together_grows_affinity_and_working_apart_does_not() -> void:
	"""Two on the same crew's tasks share their ticks; one on another crew's task does not; an hour together is +2."""
	var taps := _taps(3)
	var board := BoardScript.new()
	var brains: Array[BrainScript] = [BrainScript.new(), BrainScript.new(), BrainScript.new()]
	board.bind(brains, PackedStringArray(["a", "b", "c"]), [&"mouse_fieldworker", &"squirrel_gatherer",
		&"squirrel_forester"] as Array[StringName])
	var source := StubSource.new()
	source.id = WorkIds.SOURCE_FARM
	source.workers = PackedInt32Array([0, 1, 2])
	board.add_source(source)
	taps.board = board
	taps.watch()
	assert_equal(board.crews.crew_of[0], board.crews.crew_of[1], "0 and 1 on the Field crew")
	assert_true(board.crews.crew_of[2] != board.crews.crew_of[0], "2 on the Woods crew")
	for k: int in Ledger.SHARED_HOUR_TICKS / TapsScript.SHARE_POLL_TICKS:
		taps.calendar.tick += TapsScript.SHARE_POLL_TICKS
		taps.poll()
	var ledger: Ledger = taps.ledger
	assert_equal(ledger.shared_hours[ledger.pair(0, 1)], 1, "an hour together")
	assert_equal(ledger.affinity_of(0, 1), Ledger.SOCIAL_GAIN, "+2")
	assert_equal(ledger.shared_hours[ledger.pair(0, 2)], 0, "different crews, different tasks: apart")
	taps.calendar.tick += TapsScript.SHARE_POLL_TICKS * 2
	taps.poll()
	assert_equal(ledger.shared_ticks[ledger.pair(0, 1)], TapsScript.SHARE_POLL_TICKS * 2, "the time that passed")
	taps.calendar.tick += TapsScript.SHARE_POLL_TICKS - 1
	taps.poll()
	assert_equal(ledger.shared_ticks[ledger.pair(0, 1)], TapsScript.SHARE_POLL_TICKS * 2, "not looked at yet")
	brains[1].position = Vector2(TapsScript.NEAR_M + 1.0, 0.0)
	taps.calendar.tick += 1
	taps.poll()
	assert_false(taps.together(0, 1), "the same crew far apart: not together")
	brains[1].position = Vector2.ZERO
	source.workers = PackedInt32Array([2, -1, 2])
	taps.calendar.tick += TapsScript.SHARE_POLL_TICKS
	taps.poll()
	assert_false(taps.together(0, 1), "0 is off the board now")
	assert_false(taps.together(0, 2), "and not with 2")


func test_two_at_the_same_dig_work_together() -> void:
	"""The dig's lead and a crew member at its post on that segment share; one at another dig does not."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var taps := _taps(3)
	taps.network = space.tunnels
	taps.tunnel_crew = TunnelCrewScript.new()
	for who: int in 3:
		taps.tunnel_crew.set_resident(who, "mouse")
	taps.watch()
	space.tunnels.phase[5] = GraphScript.PHASE_DIGGING
	space.tunnels.digger[5] = 0
	taps.tunnel_crew.member_site[1] = 5
	taps.tunnel_crew.member_present[1] = 1
	taps.tunnel_crew.member_site[2] = 6
	taps.tunnel_crew.member_present[2] = 1
	taps.calendar.tick += TapsScript.SHARE_POLL_TICKS
	taps.poll()
	assert_true(taps.together(0, 1), "lead and crew at segment 5")
	assert_false(taps.together(0, 2), "segment 6 is another dig")
	taps.tunnel_crew.member_present[1] = 0
	taps.calendar.tick += TapsScript.SHARE_POLL_TICKS
	taps.poll()
	assert_false(taps.together(0, 1), "not at its post")
	taps.tunnel_crew.member_present[1] = 1
	space.tunnels.phase[5] = GraphScript.PHASE_PAUSED
	taps.calendar.tick += TapsScript.SHARE_POLL_TICKS
	taps.poll()
	assert_false(taps.together(0, 1), "a paused dig's lead is not at work there")


func test_midnight_runs_the_daily_fade_through_the_taps() -> void:
	"""A new calendar day: the ledger's midnight."""
	var taps := _taps(2)
	taps.watch()
	var p: int = taps.ledger.pair(0, 1)
	taps.ledger.affinity[p] = 5
	taps.ledger.last_contact_day[p] = -10
	taps.calendar.tick += DAY_TICKS
	taps.poll()
	assert_equal(taps.ledger.affinity[p], 4, "faded a point")
	taps.calendar.tick += DAY_TICKS * 2
	taps.poll()
	assert_equal(taps.ledger.affinity[p], 2, "two midnights in one look: two points")


## A work board source whose rows are its workers (row r held by workers[r]; -1 none), every row live.
class StubSource extends "res://demo/work/work_source.gd":
	var workers: PackedInt32Array = PackedInt32Array()

	func capacity() -> int:
		"""One row per worker."""
		return workers.size()

	func live(row: int) -> bool:
		"""A row with a worker is live."""
		return workers[row] >= 0

	func worker(row: int) -> int:
		"""Row `row`'s worker."""
		return workers[row]

	func activity(_row: int) -> int:
		"""Farm work."""
		return WorkIds.ACT_FARM


func test_a_batch_is_logged_with_its_own_cook() -> void:
	"""kitchen.gd `_finish_batch`: the cook at the cauldron as it finished (whoever it is), beside its meal."""
	var kitchen := KitchenScript.new()
	kitchen.cook = 2
	kitchen._wip_key = 5
	kitchen._wip_dish = 1
	kitchen._finish_batch()
	assert_equal([kitchen.cooked_keys, kitchen.cooked_by], [PackedInt32Array([5]), PackedInt32Array([2])], "cook 2's")


func test_an_ashore_with_nobody_holding_the_victim_is_no_assistance() -> void:
	"""rescue.gd `ashore` logs only the responder that holds the victim: none, nothing; and a victim a rescuer was
	still on its way to, washed ashore by the safety net, is no assistance either."""
	var suite: RefCounted = WaterPlayTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var rig: RefCounted = suite.call(&"_rig")
	var rescue: RescueScript = (rig.get(&"play") as Node).get(&"rescue")
	var cast: DemoCastScript = rig.get(&"cast")
	suite.call(&"_swimmer", rig, 0, 600)
	for who: int in range(1, cast.actor_count()):
		(cast.actor(who) as DemoActorScript).brain.water_hold = true
	var victim: BrainScript = (cast.actor(0) as DemoActorScript).brain
	victim.water_place(WaterPlayTest.RUN_MID, -0.18, 0.0)
	victim.water_in()
	rescue.start_difficulty(0)
	assert_false(rescue.victim_task(0).engaged, "nobody holds it")
	rescue.ashore(victim, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]))
	assert_equal(rescue.assists, 0, "no responder: no assistance")


func test_a_victim_washed_ashore_while_a_rescuer_was_coming_is_no_assistance() -> void:
	"""The safety net's wash ashore stands the rescuer down and logs nothing."""
	var suite: RefCounted = WaterPlayTest.new()
	suite.call(&"before_each")
	_borrowed.append(suite)
	var rig: RefCounted = suite.call(&"_rig")
	var rescue: RescueScript = (rig.get(&"play") as Node).get(&"rescue")
	var cast: DemoCastScript = rig.get(&"cast")
	suite.call(&"_swimmer", rig, 0, 600)
	suite.call(&"_swimmer", rig, 2, 1100)
	var victim: BrainScript = (cast.actor(0) as DemoActorScript).brain
	victim.water_place(WaterPlayTest.RUN_MID, -0.18, 0.0)
	victim.water_in()
	rescue.start_difficulty(0)
	assert_true(rescue.victim_task(0).engaged, "a rescuer is coming")
	rescue.victim_task(0).waited_s = RescueScript.WASH_ASHORE_ENGAGED_S
	rescue.update(RescueScript.DISPATCH_S)
	assert_true(victim.task is Tasks.RestTask, "washed ashore")
	assert_equal(rescue.assists, 0, "no assistance")


func test_the_harvest_log_keeps_its_newest() -> void:
	"""HARVEST_LOG rows at most; `harvests` counts every one."""
	var crew := FarmCrewScript.new()
	crew.jobs.kind.resize(1)
	crew.jobs.worker.resize(1)
	crew.jobs.bed.resize(1)
	crew.jobs.load_item.resize(1)
	for k: int in FarmCrewScript.HARVEST_LOG + 2:
		crew.jobs.worker[0] = k
		crew._log_harvest(0)
	assert_equal([crew.harvests, crew.harvested_by.size(), crew.harvested_by[0]], [FarmCrewScript.HARVEST_LOG + 2,
		FarmCrewScript.HARVEST_LOG, 2], "capped, the oldest gone")
