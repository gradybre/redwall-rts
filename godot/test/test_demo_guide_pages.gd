extends "res://test/framework/test_case.gd"
## The village guide's pages (decision 0481; review P1 "Objectives / Help", UX-018, UX-019, UX-020): the searchable
## help that replaced the menu's wall of controls, the field guide built from the demo's own tables (and only what the
## demo has), the practice stories kept apart from the village (its figures unchanged by every story, every choice and
## every restart; the same story twice told the same), and player-named projects completing into the village news
## history once. Off-tree; no staged assets.

const TopicsScript := preload("res://demo/guide/help_topics.gd")
const HelpPageScript := preload("res://demo/guide/help_page.gd")
const SearchScript := preload("res://demo/guide/guide_search.gd")
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")
const FieldPageScript := preload("res://demo/guide/field_guide_page.gd")
const StoriesScript := preload("res://demo/guide/practice_stories.gd")
const PracticePageScript := preload("res://demo/guide/practice_page.gd")
const ProjectsScript := preload("res://demo/guide/projects.gd")
const ProjectsPageScript := preload("res://demo/guide/projects_page.gd")
const WorldScript := preload("res://demo/guide/guide_world.gd")
const FactsScript := preload("res://demo/guide/guide_facts.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const Fixtures := preload("res://demo/burrow/room_fixtures.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const CastRoutines := preload("res://demo/cast/cast_routines.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free what a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


# --- help ----------------------------------------------------------------------------------------------

func _top(topics: TopicsScript, query: String) -> String:
	"""The best topic's heading for `query` ('' for none)."""
	var found: PackedInt32Array = topics.search(query)
	return topics.title_of(found[0]) if not found.is_empty() else ""


func test_help_answers_plain_questions() -> void:
	"""Everyday words find the how-to: 'how do I cross the stream' the bridge, 'eat' the kitchen, 'why is my job
	waiting' the Work screen's topic, 'save' the no-save line; and a query matching nothing says so."""
	var topics := TopicsScript.new()
	assert_equal(_top(topics, "how do I cross the stream?"), "Build a bridge", "cross the stream")
	assert_equal(_top(topics, "eat"), "Feed the village: the kitchen", "eat")
	assert_equal(_top(topics, "why is my job waiting"), "Why is a job waiting?", "job waiting")
	assert_equal(_top(topics, "save"), "Saving", "save")
	assert_equal(_top(topics, "frost"), "Protect beds from frost and wet", "frost")
	assert_equal(_top(topics, "dig"), "Dig a tunnel", "dig")
	assert_equal(topics.search("zzqx").size(), 0, "nothing for nonsense")
	assert_equal(topics.search("").size(), topics.count(), "everything for nothing")


func test_help_keeps_every_key_the_controls_page_had() -> void:
	"""The keys the old Controls wall listed are each a topic, the guide's O and the Work screen's J among them."""
	var topics := TopicsScript.new()
	var keys := PackedStringArray()
	for k: int in topics.count():
		keys.append(topics.keys_of(k))
	for key: String in ["F7", "F8", "Tab / Shift+Tab", "B or T", "K", "Esc", "Space", "U", "V", "N", "O", "J", "L"]:
		assert_true(keys.has(key), "lists %s" % key)


func test_every_linked_help_command_has_its_words() -> void:
	"""A topic's command carries a label; a topic without one shows no button."""
	var topics := TopicsScript.new()
	var linked: int = 0
	for k: int in topics.count():
		var action: StringName = topics.action_of(k)
		if action != TopicsScript.ACTION_NONE:
			linked += 1
			assert_false(TopicsScript.action_label(action).is_empty(), "%s: a label" % topics.title_of(k))
	assert_true(linked >= 10, "most how-tos link their command (%d)" % linked)


func test_the_help_page_searches_as_typed_and_links_commands() -> void:
	"""Typing narrows the page in place (no row made or freed); a linked command's button asks the host."""
	var page: HelpPageScript = _keep(HelpPageScript.new())
	var asked: Array[StringName] = []
	page.action_requested.connect(func(action: StringName) -> void: asked.append(action))
	var rows: int = page.get_child_count()
	page.set_query("pantry")
	assert_true(page.shown().size() > 0 and page.shown().size() < page.topics.count(), "narrowed")
	assert_true(page.count_text().begins_with("%d found" % page.shown().size()), page.count_text())
	assert_equal(page.get_child_count(), rows, "the same rows")
	page.set_query("qqqq")
	assert_true(page.count_text().begins_with("Nothing matches"), page.count_text())
	var button: Button = _first_button(page)
	button.pressed.emit()
	assert_equal(asked.size(), 1, "the host was asked")


func _first_button(node: Node) -> Button:
	"""The first Button under `node`, depth first."""
	for child: Node in node.get_children():
		if child is Button:
			return child
		var inner: Button = _first_button(child)
		if inner != null:
			return inner
	return null


func test_the_menu_s_controls_page_is_the_help_page() -> void:
	"""The game menu's third button is Help; its page holds the search field (its first focus) and the keys."""
	var menu: MenuScript = _keep(MenuScript.new())
	assert_equal(menu.menu_button(2).text, "Help", "Help, not Controls")
	assert_true(menu.help.get_parent() != null, "the help page is on the menu's page")
	var text: String = menu.page_text(MenuScript.PAGE_CONTROLS)
	for key: String in ["F7", "F8", "Saving", "Build a bridge"]:
		assert_true(text.contains(key), "lists %s" % key)


func test_every_word_must_match_before_any_word_does() -> void:
	"""'apple pie' finds the entry with both words alone; with none holding both, those with either, best first."""
	var entries: Array[SearchScript.Entry] = [SearchScript.Entry.new("Apple", "", ""),
		SearchScript.Entry.new("Apple pie", "", ""), SearchScript.Entry.new("Pear", "", "")]
	assert_equal(SearchScript.search(entries, "apple pie"), PackedInt32Array([1]), "both words")
	assert_equal(SearchScript.search(entries, "pie pear"), PackedInt32Array([1, 2]), "either, when none has both")


func test_search_widening_and_stop_words() -> void:
	"""'how do I' adds nothing; 'eat' widens to supper and the kitchen; a plural finds its singular."""
	assert_equal(SearchScript.words_of("How do I cross the stream?"), PackedStringArray(["cross", "stream"]), "stop words")
	assert_true(SearchScript.widen("eat").has("supper"), "eat -> supper")
	assert_true(SearchScript.widen("bridges").has("bridge"), "plural")


# --- the field guide -----------------------------------------------------------------------------------

func test_the_field_guide_has_exactly_the_demo_s_crops_and_dishes() -> void:
	"""One crop entry per farmed item, titled as the catalog; one dish entry per dish the kitchen cooks; each crop's
	uses name the dish that cooks it and no other."""
	var guide := FieldGuideScript.new()
	assert_equal(guide.of_kind(FieldGuideScript.KIND_CROP).size(), Catalog.ITEM_COUNT, "every farmed item")
	assert_equal(guide.of_kind(FieldGuideScript.KIND_DISH).size(), Rules.DISH_COUNT, "the two dishes")
	for item: int in Catalog.ITEM_COUNT:
		var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.crop_id(item)))
		assert_equal(entry.title, Catalog.ITEM_LABELS[item], "titled as the catalog")
		for dish: int in Rules.DISH_COUNT:
			assert_equal(entry.uses.contains(Rules.DISH_NAMES[dish]), Rules.is_input(dish, item),
				"%s and %s" % [entry.title, Rules.DISH_NAMES[dish]])
	for dish: int in Rules.DISH_COUNT:
		var dish_entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.DISH_IDS[dish]))
		assert_equal(dish_entry.title, Rules.DISH_NAMES[dish], "the dish's name")
		assert_true(dish_entry.requires.contains(FarmText.units_text(Rules.INPUT_MILLI[dish])), "its input")


func test_field_guide_figures_are_the_tables_own() -> void:
	"""A bed's planks, a hearth's stone, a footbridge's planks a metre, the cellar's and covered store's rates and the
	species' swimming are the figures in the demo's tables."""
	var guide := FieldGuideScript.new()
	var planks: String = guide.entry(guide.index_of(&"material_planks")).uses
	assert_true(planks.contains(FarmText.units_text(Fixtures.COST_PLANKS_MILLI[RoomsScript.FIX_BED])), planks)
	assert_true(planks.contains(FarmText.units_text(SwimRules.PLANK_MILLI_PER_M)), planks)
	assert_true(guide.entry(guide.index_of(&"material_stone")).uses.contains(
		FarmText.units_text(Fixtures.COST_STONE_MILLI[RoomsScript.FIX_HEARTH])), "the hearth's stone")
	assert_true(guide.entry(guide.index_of(&"station_cellar")).uses.contains(
		str(StockAge.STORE_FACTOR[StockAge.STORAGE_CELLAR])), "the cellar's rate")
	var swim: String = guide.entry(guide.index_of(&"skill_swimming")).requires
	for k: int in SwimRules.SPECIES.size():
		assert_true(swim.contains("%s %s" % [SwimRules.SPECIES[k], SwimRules.SWIM_WORDS[k]]), SwimRules.SPECIES[k])


func test_field_guide_links_resolve_and_nothing_absent_is_described() -> void:
	"""Every link opens an entry; no entry speaks of what the demo lacks; every entry has its four sections."""
	var guide := FieldGuideScript.new()
	for k: int in guide.count():
		var entry: FieldGuideScript.Entry = guide.entry(k)
		for link: StringName in entry.links:
			assert_true(guide.index_of(link) >= 0, "%s -> %s" % [entry.id, link])
		for section: String in [entry.uses, entry.requires, entry.alternatives, entry.here]:
			assert_false(section.is_empty(), "%s: a section" % entry.id)
		var all: String = (entry.title + entry.uses + entry.requires + entry.alternatives + entry.here).to_lower()
		for absent: String in ["mead", "hunt", "mill ", "boat", "feast", "charter", "fish stew"]:
			assert_false(all.contains(absent), "%s mentions %s" % [entry.id, absent])


func test_field_guide_search_and_live_stock() -> void:
	"""'what makes soup' finds the soup and roots; a crop's entry reads the pantry live."""
	var guide := FieldGuideScript.new()
	var found: PackedInt32Array = guide.search("soup")
	assert_equal(guide.entry(found[0]).id, FieldGuideScript.DISH_IDS[Rules.DISH_SOUP], "soup first")
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	pantry.add_into(2, 5100, 0, _read)
	guide.bind_pantry(pantry)
	assert_equal(guide.live_line(guide.index_of(FieldGuideScript.crop_id(2))), "In the pantry now: 5.1 U.", "live")


func test_the_field_guide_page_opens_entries_and_links() -> void:
	"""Opening an entry shows its sections; a link opens the linked entry; Back returns to the list."""
	var page: FieldPageScript = _keep(FieldPageScript.new())
	var soup: int = page.guide.index_of(FieldGuideScript.DISH_IDS[Rules.DISH_SOUP])
	page.open_entry(soup)
	assert_equal(page.open_index(), soup, "the soup open")
	assert_true(page.entry_text().contains("Requires") and page.entry_text().contains("Available here"), "its sections")
	page.open_entry(page.guide.index_of(&"station_kitchen"))
	assert_true(page.entry_text().begins_with("The kitchen"), page.entry_text().left(40))
	page.search("")
	assert_equal(page.open_index(), -1, "back to the list")


# --- practice stories ----------------------------------------------------------------------------------

func _main_village() -> Array:
	"""A village's own figures: its services (stores, calendar, notices, incidents), a pantry with stock, a farm."""
	var services := ServicesScript.new()
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	pantry.add_into(2, 7000, 0, _read)
	var sim := SimScript.new()
	sim.share_calendar(services.calendar)
	return [services, pantry, sim]


func _digest(village: Array) -> Array:
	"""Every figure of the village a story could touch."""
	var services: ServicesScript = village[0]
	var pantry: PantryScript = village[1]
	var sim: SimScript = village[2]
	return [services.stores.wood_milli_u, services.stores.stone_milli_u, services.stores.plank_milli_u,
		services.stores.water_milli_u, services.stores.earth_milli_u, services.calendar.tick, services.notices.count(),
		services.notices.revision, pantry.total_milli(), pantry.delivered_milli, pantry.spoiled_milli,
		sim.revision, sim.stage_of(2), sim.growth_permille(2), sim.compost_milli]


func test_practice_stories_never_touch_the_village() -> void:
	"""Every story, every choice, and a restart between: the village's figures are exactly as before."""
	var village: Array = _main_village()
	var before: Array = _digest(village)
	var map: RefCounted = WaterLayout.make_map()
	var shape: Array = _shape(map)
	var stories := StoriesScript.new()
	stories.water_map = map
	for s: int in StoriesScript.STORY_COUNT:
		stories.start(s)
		for c: int in (StoriesScript.CHOICES[s] as Array).size():
			stories.choose(c)
			assert_false(stories.outcome.is_empty(), "story %d choice %d told" % [s, c])
			stories.restart()
	assert_equal(_digest(village), before, "the village unchanged")
	assert_equal(_shape(map), shape, "and the one thing a story is handed, the stream's shape, unchanged")


func _shape(map: RefCounted) -> Array:
	"""The water map's crossings and shore, as a story could change them."""
	var out: Array = [map.call(&"crossing_count"), map.call(&"shore_count"), map.call(&"landing_count")]
	for c: int in int(map.call(&"crossing_count")):
		out.append([map.call(&"crossing_kind", c), map.call(&"crossing_a", c), map.call(&"crossing_b", c)])
	for k: int in mini(int(map.call(&"shore_count")), 64):
		out.append(map.call(&"shore_point", k))
	return out


func test_a_story_restarts_to_the_same_start() -> void:
	"""The same choice from a restart tells the same story, word for word; restart clears the run."""
	var stories := StoriesScript.new()
	for s: int in StoriesScript.STORY_COUNT:
		stories.start(s)
		stories.choose(1)
		var first: PackedStringArray = stories.log_lines.duplicate()
		var debrief: PackedStringArray = stories.debrief.duplicate()
		stories.restart()
		assert_equal([stories.choice, stories.log_lines.size(), stories.debrief.size()], [-1, 0, 0], "cleared")
		stories.choose(1)
		assert_equal(stories.log_lines, first, "story %d the same" % s)
		assert_equal(stories.debrief, debrief, "debrief %d the same" % s)


func test_the_stories_teach_by_their_real_rules() -> void:
	"""A loaded crew is refused at the water; a full store keeps the harvest out until room is made; a cellar feeds the
	household through winter where the covered store does not."""
	var stories := StoriesScript.new()
	stories.start(StoriesScript.STORY_CROSSING)
	stories.choose(0)
	assert_true(stories.outcome.begins_with("refused"), stories.outcome)
	stories.choose(2)
	assert_true(stories.outcome.contains("of planks spent"), stories.outcome)
	stories.start(StoriesScript.STORY_DELIVERY)
	stories.choose(0)
	assert_true(stories.outcome.begins_with("0 U stored"), stories.outcome)
	stories.choose(2)
	assert_true(stories.outcome.contains("root cellar"), stories.outcome)
	stories.start(StoriesScript.STORY_PANTRY)
	stories.choose(0)
	var covered: String = stories.outcome
	stories.choose(1)
	assert_true(stories.outcome.begins_with("%d of %d days fed in full" % [StoriesScript.DAYS, StoriesScript.DAYS]),
		stories.outcome)
	assert_false(covered.begins_with("%d of" % StoriesScript.DAYS), "the covered store falls short: " + covered)
	assert_equal(stories.debrief.size(), 4, "three choices compared and the lesson")
	var outcomes := PackedStringArray()
	for c: int in 3:
		stories.choose(c)
		outcomes.append(stories.outcome)
	assert_equal(outcomes, PackedStringArray(["17 of 24 days fed in full; 90.0 U spoiled",
		"24 of 24 days fed in full; 0 U spoiled", "23 of 24 days fed in full; 15.0 U spoiled"]),
		"the winter pantry by the pantry's own ageing and the kitchen's order (soonest to spoil eaten first)")


func test_the_practice_page_runs_a_story_with_debrief_and_restart() -> void:
	"""Start, a choice (the others locked), what happened and the debrief, Restart back to the choices."""
	var page: PracticePageScript = _keep(PracticePageScript.new())
	page.start_button(StoriesScript.STORY_DELIVERY).pressed.emit()
	page.choice_button(2).pressed.emit()
	assert_true(page.result_text().contains("Debrief"), "debriefed")
	assert_true(page.choice_button(0).disabled, "one choice a run")
	page.restart_button().pressed.emit()
	assert_false(page.choice_button(0).disabled, "choices again")


# --- projects --------------------------------------------------------------------------------------------

func _project_world() -> WorldScript:
	"""A world over the village's stores and a pantry."""
	var world := WorldScript.new()
	world.stores = ServicesScript.new().stores
	world.pantry = PantryScript.new(StorageScript.new(Vector2.ZERO))
	return world


func test_a_project_completes_into_the_chronicle_once() -> void:
	"""'Wood for winter': wood in store reaches 60.0 U. Below it, nothing; reached, it is done and one Village entry
	goes into the history with its before and after; looked at again, no second entry."""
	var world := _project_world()
	var facts := FactsScript.new()
	var notices := NoticesScript.new()
	var projects := ProjectsScript.new()
	projects.post = func(text: String, kind: int, id: int) -> void: notices.post(NoticesScript.SOURCE_VILLAGE,
		NoticesScript.LEVEL_NOTE, text, "", kind, id)
	assert_equal(projects.add("Wood for winter", ProjectsScript.MEASURE_WOOD, 60000, world, facts,
		[Vector3i(NoticesScript.TARGET_BED, 2, 0)], PackedStringArray(["the carrot bed"])), "", "pinned")
	projects.update(world, facts)
	assert_equal(notices.count(), 0, "not yet")
	world.stores.add_wood(60000 - world.stores.wood_milli_u)
	projects.update(world, facts)
	projects.update(world, facts)
	assert_true(projects.projects[0].done, "done")
	assert_equal(notices.count(), 1, "one entry")
	assert_equal(notices.repeats(0), 1, "posted once, not folded twice")
	assert_equal(notices.source(0), NoticesScript.SOURCE_VILLAGE, "the Village's")
	assert_equal(notices.target_kind(0), NoticesScript.TARGET_BED, "Go to its place")
	assert_true(notices.text(0).begins_with("Project complete: \"Wood for winter\" -- wood in store, 40.0 U -> 60.0 U"),
		notices.text(0))


func test_projects_are_three_named_and_from_now_counts_from_the_pin() -> void:
	"""No name, a fourth, a zero target: refused in words. 'Harvested from now' counts only what comes after it."""
	var world := _project_world()
	var facts := FactsScript.new()
	var projects := ProjectsScript.new()
	assert_equal(projects.add("  ", 0, 1000, world, facts), ProjectsScript.REFUSE_NAME, "a name")
	assert_equal(projects.add("x", 0, 0, world, facts), ProjectsScript.REFUSE_TARGET, "a target")
	world.pantry.delivered_milli = 9000
	projects.add("Bring in more", ProjectsScript.MEASURE_HARVESTED, 5000, world, facts)
	assert_equal(projects.progress(projects.projects[0], world, facts), 0, "from now: nothing yet")
	world.pantry.delivered_milli = 14000
	projects.update(world, facts)
	assert_true(projects.projects[0].done, "5.0 U since the pin")
	projects.add("b", 0, 1000, world, facts)
	projects.add("c", 0, 1000, world, facts)
	assert_equal(projects.add("d", 0, 1000, world, facts), ProjectsScript.REFUSE_FULL, "three at most")
	projects.remove(0)
	assert_equal(projects.add("d", 0, 1000, world, facts), "", "room again")


func test_the_projects_page_pins_with_the_places_selected() -> void:
	"""A name typed, the measure and target stepped, Pin: the project carries the places selected now."""
	var page: ProjectsPageScript = _keep(ProjectsPageScript.new())
	page.projects = ProjectsScript.new()
	page.world = _project_world()
	page.facts = FactsScript.new()
	page.places_into = func(kinds: Array[Vector3i], names: PackedStringArray) -> void:
		kinds.append(Vector3i(NoticesScript.TARGET_RESIDENT, 3, 0))
		names.append("Mole digger")
	page.name_field().text = "Planks for beds"
	page.step_measure(1)
	page.step_target(1)
	page.pin()
	assert_equal(page.said(), "", "pinned")
	var project: ProjectsScript.Project = page.projects.projects[0]
	assert_equal([project.name, project.measure, project.target], ["Planks for beds", ProjectsScript.MEASURE_PLANKS,
		ProjectsScript.FIRST_TARGETS[ProjectsScript.MEASURE_PLANKS] + ProjectsScript.STEPS[ProjectsScript.MEASURE_PLANKS]],
		"as the form said")
	assert_equal(project.place_names, PackedStringArray(["Mole digger"]), "its place")


# --- typing inside a modal ------------------------------------------------------------------------------

func _key(code: Key, shift: bool = false, echo: bool = false) -> InputEventKey:
	"""A key press."""
	var key := InputEventKey.new()
	key.keycode = code
	key.shift_pressed = shift
	key.echo = echo
	key.pressed = true
	return key


func test_a_text_field_in_the_top_modal_takes_the_keys() -> void:
	"""In a modal (its own close key K), a focused text field gets letters, K, Space, Enter, Backspace and their repeats;
	Esc still closes and Tab still moves. Focus on a button there, a letter is swallowed as before."""
	var gate: GateScript = _keep(GateScript.new())
	var layer: CanvasLayer = _keep(CanvasLayer.new())
	var field := LineEdit.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	layer.add_child(field)
	layer.add_child(button)
	gate.watch_modal(layer, layer, Callable(), [&"open_food"] as Array[StringName])
	var focus := GateScript.Focus.new()
	focus.control = field
	assert_true(gate.typing(field), "typing")
	for code: Key in [KEY_A, KEY_K, KEY_SPACE, KEY_BACKSPACE, KEY_O]:
		assert_equal(gate.route(_key(code), focus), GateScript.ROUTE_PASS, "%s types" % OS.get_keycode_string(code))
	for code: Key in [KEY_ENTER, KEY_KP_ENTER]:
		assert_equal(gate.route(_key(code), focus), GateScript.ROUTE_CONSUME,
			"%s is swallowed: no field submits, and it must not reach the Dig tool" % OS.get_keycode_string(code))
	assert_equal(gate.route(_key(KEY_BACKSPACE, false, true), focus), GateScript.ROUTE_PASS, "a held Backspace repeats")
	assert_equal(gate.route(_key(KEY_ESCAPE), focus), GateScript.ROUTE_CLOSE, "Esc closes")
	assert_equal(gate.route(_key(KEY_TAB), focus), GateScript.ROUTE_NEXT, "Tab moves on")
	assert_equal(gate.route(_key(KEY_TAB, true), focus), GateScript.ROUTE_PREVIOUS, "Shift+Tab moves back")
	focus.control = button
	focus.button = true
	assert_equal(gate.route(_key(KEY_A), focus), GateScript.ROUTE_CONSUME, "a letter on a button is swallowed")
	assert_equal(gate.route(_key(KEY_K), focus), GateScript.ROUTE_CLOSE, "K closes from a button")
	var ring: Array[Control] = GateScript.focusables([layer] as Array[Node])
	assert_true(ring.has(field), "a text field is a Tab stop")
	field.editable = false
	assert_false(gate.typing(field), "a read-only field does not type")
	field.editable = true
	var outside := LineEdit.new()
	_keep(outside)
	assert_false(gate.typing(outside), "a field outside the top modal does not type")
	focus.control = outside
	focus.button = false
	assert_equal(gate.route(_key(KEY_A), focus), GateScript.ROUTE_CONSUME, "so its letters are swallowed")
