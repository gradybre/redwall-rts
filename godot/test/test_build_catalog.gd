extends "res://test/framework/test_case.gd"
## The build panel's cards (UI-BUILD-003/004): which cards each tab lists on each level, what is locked and why in
## words, the least sizes as SET-BUILD-001 §4 states them in cells (quoted here), and the accessible names.
## Decision 1871.

const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
## Decision 2002: built rooms on the surface are locked with these words; the Mound style paints there.
const BUILT_SURFACE_WORDS: String = "Not yet: built rooms on the surface come in a later update; choose the Mound style"

## SET-BUILD-001 §4 "Rule in cells", quoted: least cells per RoomType ordinal (CORRIDOR has a width rule only).
const LEAST_CELLS: Array[int] = [12, 24, 24, 32, 32, 12, 16, 0]
const NAMES: Array[String] = ["Dormitory", "Bedroom", "Kitchen", "Dining room", "Common room", "Infirmary", "Pantry",
	"Passage"]

var _catalog: BuildCatalog = null
var _cards: Array[BuildCatalog.Card] = []


func before_each() -> void:
	"""A fresh catalog at the level pack's clear height."""
	_catalog = BuildCatalog.new()
	_cards.clear()


func test_least_sizes_are_set_build_001_section_4_in_cells() -> void:
	"""GDD §5.9's tiles times four, read from room_catalog.gd."""
	for room_type: int in LEAST_CELLS.size():
		assert_equal(_catalog.minimum_cells(room_type), LEAST_CELLS[room_type], "%s" % NAMES[room_type])
	assert_equal(_catalog.minimum_cells(99), 0, "an unknown type has no minimum")


func test_names_are_the_games_labels_with_corridor_shown_as_passage() -> void:
	"""room_catalog.gd's labels; CORRIDOR reads "Passage"."""
	for room_type: int in NAMES.size():
		assert_equal(BuildCatalog.type_name(room_type), NAMES[room_type], "type %d" % room_type)
	assert_equal(BuildCatalog.type_name(42), "", "an unknown type has no name")


func test_rules_lines_follow_the_docs_example() -> void:
	"""“Needs 1 bench and 1 hearth; at least 24 cells”."""
	assert_equal(_catalog.rules_text(2), "Needs 1 bench and 1 hearth; at least 24 cells", "Kitchen")
	assert_equal(_catalog.rules_text(7), "Needs at least 2 cells wide", "Passage has no area minimum")
	assert_equal(_catalog.rules_text(-1), "", "no type")


func test_rooms_underground_lists_the_eight_types_and_locked_tools() -> void:
	"""Decision 1912: eight paintable room types, Passage (CORRIDOR) among them, then Earth and Remove locked; the old
	tool cards are gone (Brendan's ruling on decision 1911 P-C2 (c))."""
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 1, -1, _cards)
	var names: PackedStringArray = PackedStringArray()
	for card: BuildCatalog.Card in _cards:
		names.append(card.name)
	assert_equal(names, PackedStringArray(["Dormitory", "Bedroom", "Kitchen", "Dining room", "Common room",
		"Infirmary", "Pantry", "Passage", "Way down", "Earth", "Remove"]), "the row")
	for at: int in 8:
		assert_true(_cards[at].usable() and _cards[at].kind == BuildCatalog.CARD_ROOM, "%s paints" % names[at])
	assert_equal(_cards[7].room_type, BuildCatalog.CORRIDOR, "Passage paints CORRIDOR")
	assert_equal(_cards[7].footprint, "at least 2 cells wide", "BUILD-REQ-014")
	assert_true(_cards[8].usable() and _cards[8].kind == BuildCatalog.CARD_WAY_DOWN, "a way down to level 2")
	assert_false(_cards[9].usable(), "Earth is locked")
	assert_false(_cards[10].usable(), "Remove is locked")
	assert_true(_cards[10].locked.begins_with("Not yet: "), "with words: %s" % _cards[10].locked)


func test_rooms_on_the_surface_are_locked_but_inspectable() -> void:
	"""No built surface rooms before slice G: in the Built style the room types and Outdoor say why."""
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 0, -1, _cards)
	assert_equal(_cards.size(), 12, "8 types, Outdoor, the Entrance, Clear ground, Remove")
	for at: int in 8:
		assert_false(_cards[at].usable(), "%s locked on the surface" % _cards[at].name)
		assert_equal(_cards[at].locked, BUILT_SURFACE_WORDS, "its reason")
		assert_equal(_cards[at].lock_kind, Validity.KIND_BLOCKED, "a later update: ! Blocked")
		assert_false(_cards[at].purpose.is_empty(), "still inspectable: purpose")
	assert_equal(_cards[8].name, "Outdoor", "Outdoor follows the types")
	assert_true(_cards[9].name == "Entrance" and _cards[9].usable(), "the Entrance can be placed (decision 1912)")
	assert_equal(_cards[10].name, "Clear ground", "Clear ground, not Earth, on the surface")
	for card: BuildCatalog.Card in _cards:
		assert_false(card.locked.contains("slice"), "no slice jargon: %s" % card.locked)


func test_furnish_lists_only_what_the_room_type_allows_and_decor_the_decoration() -> void:
	"""room_catalog.gd's palette: a Kitchen takes a bench; a Dormitory takes beds but no bench; placeable on levels
	1-4 (decision 1921)."""
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, 1, 2, _cards)
	var kitchen: PackedStringArray = PackedStringArray()
	for card: BuildCatalog.Card in _cards:
		kitchen.append(card.name)
		var kind: int = BuildCatalog.CARD_EDGE if card.name == "Window" else BuildCatalog.CARD_ITEM
		assert_true(card.usable() and card.kind == kind, "%s placeable on level 1" % card.name)
	assert_true(kitchen.has("Kitchen bench") and kitchen.has("Hearth"), "kitchen pieces: %s" % ", ".join(kitchen))
	assert_equal(kitchen[0], "Window", "decision 2002: the Window first (refused underground in words), no Front door")
	assert_false(kitchen.has("Bed") or kitchen.has("Decoration"), "no bed, decoration on its own tab")
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, 1, 0, _cards)
	var dormitory: PackedStringArray = PackedStringArray()
	for card: BuildCatalog.Card in _cards:
		dormitory.append(card.name)
	assert_true(dormitory.has("Bed") and not dormitory.has("Kitchen bench"), "dormitory: %s" % ", ".join(dormitory))
	_catalog.cards_into(BuildCatalog.TAB_DECOR, 1, 0, _cards)
	assert_equal(_cards.size(), 1, "one decoration item")
	assert_equal(_cards[0].name, "Decoration", "decoration")
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, 1, -1, _cards)
	assert_equal(_cards.size(), 0, "nothing to furnish before a type is chosen")


func test_furniture_on_the_surface_is_a_mounds_and_overview_is_locked() -> void:
	"""Decision 2002: on the surface the Front door and the Window come first, and the Kitchen's pieces stand on a
	Mound room's dug floor (the validity judges each); Overview shows them all, one level at a time."""
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, 0, 2, _cards)
	assert_true(_cards.size() > 2, "the Kitchen's pieces listed on the surface")
	assert_equal([_cards[0].name, _cards[1].name], ["Front door", "Window"], "the Mound's door and window first")
	assert_equal([_cards[0].edge_kind, _cards[1].edge_kind], [Mound.KIND_DOOR, Mound.KIND_WINDOW], "their kinds")
	for card: BuildCatalog.Card in _cards:
		assert_true(card.usable(), "%s placeable on the surface" % card.name)
	_catalog.cards_into(BuildCatalog.TAB_DECOR, BuildCatalog.OVERVIEW_LEVEL, 2, _cards)
	assert_equal(_cards[0].locked, BuildCatalog.CHOOSE_A_LEVEL, "Overview: one level at a time")
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, BuildCatalog.OVERVIEW_LEVEL, 2, _cards)
	assert_false(_cards[0].kind == BuildCatalog.CARD_EDGE, "no door or window card on Overview")
	for level: int in [0, 1, 2, 3, 4]:
		assert_equal(BuildCatalog.item_lock(level), "", "placeable on level %d" % level)


func test_door_and_window_cards_say_what_they_are_free() -> void:
	"""Decision 2002: an edge card's kind, cost (free for now), footprint, purpose and rules; none before a type."""
	var door: BuildCatalog.Card = _catalog.edge_card(Mound.KIND_DOOR)
	assert_true(door.usable() and door.kind == BuildCatalog.CARD_EDGE and door.id == &"edge:0", door.id)
	assert_equal(door.footprint, "2 cell edges", "a door's two edges")
	assert_true(door.purpose.contains("oak by default") and door.cost == BuildCatalog.FREE_FOR_NOW, door.purpose)
	assert_true(door.rules.contains("6 cells wide"), door.rules)
	var window: BuildCatalog.Card = _catalog.edge_card(Mound.KIND_WINDOW)
	assert_equal(window.footprint, "1 cell edge", "a window's one")
	assert_true(window.rules.contains("hill face"), window.rules)
	assert_equal(window.gesture, BuildCatalog.EDGE_GESTURE, "click an outer edge")
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, 0, -1, _cards)
	assert_equal(_cards.size(), 0, "nothing before a room type is chosen")


func test_the_mound_style_paints_the_surface_and_is_refused_below() -> void:
	"""BUILD-MOUND-001/028: Mound rooms on the surface ("" lock) and in words "X" below; a Mound card's rules and cost
	name its hill."""
	assert_equal(BuildCatalog.room_lock(0, true, Mound.STYLE_MOUND), "", "the surface paints Mound rooms")
	assert_equal(BuildCatalog.room_lock(2, true, Mound.STYLE_MOUND), Mound.TEXT_SURFACE_ONLY, "not below")
	assert_equal(BuildCatalog.room_lock(5, true, Mound.STYLE_MOUND), BuildCatalog.CHOOSE_A_LEVEL, "nor on Overview")
	assert_equal(BuildCatalog.lock_kind_of(2, Mound.STYLE_MOUND), Validity.KIND_NOT_POSSIBLE, "X below")
	assert_equal(BuildCatalog.lock_kind_of(0, Mound.STYLE_BUILT), Validity.KIND_BLOCKED, "! built on the surface")
	assert_equal(BuildCatalog.lock_kind_of(5, Mound.STYLE_MOUND), Validity.KIND_BLOCKED, "! Overview")
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 0, -1, _cards, true, Mound.STYLE_MOUND)
	assert_true(_cards[2].usable(), "the Kitchen paints as a Mound room")
	assert_true(_cards[2].rules.ends_with(BuildCatalog.MOUND_RULES), _cards[2].rules)
	assert_true(_cards[2].cost.ends_with(BuildCatalog.MOUND_COST), _cards[2].cost)
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 1, -1, _cards, true, Mound.STYLE_MOUND)
	assert_false(_cards[2].usable(), "not below")
	assert_equal(_cards[2].lock_kind, Validity.KIND_NOT_POSSIBLE, "in X words")
	assert_true(_cards[2].unlock_state().begins_with("X Not possible: Mound rooms"), _cards[2].unlock_state())


func test_item_cards_say_which_rooms_use_them_and_that_they_are_free() -> void:
	"""Decision 1921: the rules name the room types that use the piece; the purpose says a resident fits it, free."""
	var bed: BuildCatalog.Card = _catalog.item_card(0, "")
	assert_true(bed.rules.contains("(Dormitory or Bedroom)"), bed.rules)
	assert_true(bed.purpose.contains("free for now"), bed.purpose)
	assert_true(_catalog.item_card(2, "").rules.contains("(any room)"), "a hearth: any room")
	assert_true(_catalog.item_card(3, "").rules.begins_with("Stands on 2 cell edges"), "a door stands on edges")
	assert_equal(_catalog.users_of(5), "Kitchen", "the bench: the Kitchen")
	assert_equal(_catalog.item_card(0, "Locked").rules, "Locked", "a locked card's rules are its reason")


func test_item_cards_carry_their_bill_and_footprint() -> void:
	"""A bed: 2 × 2 cells, wood and cloth; a door spans two cell edges (SET-BUILD-001 §6)."""
	var bed: BuildCatalog.Card = _catalog.item_card(0, "")
	assert_equal(bed.footprint, "2 × 2 cells", "bed footprint")
	assert_true(bed.cost.begins_with("per item 2 logs"), bed.cost)
	assert_true(bed.cost.contains("work about"), bed.cost)
	var door: BuildCatalog.Card = _catalog.item_card(3, "")
	assert_equal(door.footprint, "2 cell edges", "door")
	var bench: BuildCatalog.Card = _catalog.item_card(5, "")
	assert_equal(bench.footprint, "4 × 2 cells", "bench")


func test_accessible_names_bind_name_cost_footprint_and_unlock_state() -> void:
	"""UI-BUILD-003: Name; cost; footprint; unlock state."""
	var kitchen: BuildCatalog.Card = _catalog.room_card(2, "")
	var spoken: String = kitchen.accessible_name()
	assert_true(spoken.begins_with("Kitchen; per cell "), spoken)
	assert_true(spoken.contains("at least 24 cells"), spoken)
	assert_true(spoken.ends_with("; available"), spoken)
	var locked: BuildCatalog.Card = _catalog.room_card(2, Validity.not_yet("rooms on the surface come in a later update"))
	assert_true(locked.accessible_name().ends_with("! Blocked: Not yet: rooms on the surface come in a later update"),
		locked.accessible_name())


func test_the_cell_cost_is_the_ledgers() -> void:
	"""One cell: a log, a block, about 17 minutes, 4 baskets; a taller level costs more."""
	var words: String = _catalog.cell_cost_text()
	assert_true(words.begins_with("per cell a log") or words.begins_with("per cell 1 log"), words)
	assert_true(words.contains("about 17 minutes") and words.contains("4 baskets"), words)
	_catalog.set_clear_height(5120)
	assert_true(_catalog.cell_cost_text().contains("5 baskets"), _catalog.cell_cost_text())


func test_overview_locks_the_room_types_and_a_level_with_no_way_in_does_not() -> void:
	"""Overview: one level at a time (a PROPOSAL). A level with no way in is painted all the same: its cells say "No
	way in" on the ghost (BUILD-REQ-013 per cell; decision 1911 P-C4 (a))."""
	assert_equal(BuildCatalog.room_lock(1, true), "", "level 1 paints")
	assert_equal(BuildCatalog.room_lock(0, true), BUILT_SURFACE_WORDS, "surface, built")
	assert_equal(BuildCatalog.room_lock(5, true), BuildCatalog.CHOOSE_A_LEVEL, "Overview")
	assert_equal(BuildCatalog.room_lock(3, false), "", "level 3 without a way in still paints")
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 3, -1, _cards, false)
	assert_true(_cards[2].usable(), "the Kitchen paints there")
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 5, -1, _cards)
	assert_false(_cards[2].usable(), "not on Overview")


func test_a_card_prices_a_cell_at_its_own_level_s_clear_height() -> void:
	"""Review LOW: each level's clear height prices its cards; an unknown level falls back to the shared height."""
	_catalog.set_clear_height(4096)
	_catalog.set_level_clear_height(2, 8192)
	assert_equal(_catalog.clear_height_of(2), 8192, "level 2's own")
	assert_equal(_catalog.clear_height_of(1), 4096, "level 1 unchanged")
	assert_equal(_catalog.clear_height_of(9), 4096, "an unknown level: the shared height")
	assert_true(_catalog.cell_cost_text(2) != _catalog.cell_cost_text(1), "a taller level costs more a cell")
	assert_equal(_catalog.room_card(2, "", 2).cost, _catalog.cell_cost_text(2), "its card says so")
	_catalog.set_level_clear_height(9, 1)
	assert_equal(_catalog.clear_height_of(9), 4096, "an unknown level is never set")


func test_the_way_down_cards_are_the_entrance_above_and_a_way_down_below() -> void:
	"""Decision 1912: the surface offers the Entrance, levels 1-3 a Way down, free for now; level 4's is locked."""
	var entrance: BuildCatalog.Card = _catalog.way_down_card(0)
	assert_equal(entrance.name, "Entrance", "the surface's")
	assert_equal(entrance.cost, BuildCatalog.FREE_FOR_NOW, "free for now")
	assert_equal(entrance.footprint, "2 × 2 cells", "its size")
	assert_true(entrance.usable(), "usable")
	assert_equal(_catalog.way_down_card(2).name, "Way down", "below")
	assert_equal(_catalog.way_down_card(4).locked, Validity.no_level_below(), "level 4 has no level below")
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 5, -1, _cards)
	for card: BuildCatalog.Card in _cards:
		assert_true(card.kind != BuildCatalog.CARD_WAY_DOWN, "none on Overview")
