extends "res://test/framework/test_case.gd"
## The build panel's cards (UI-BUILD-003/004): which cards each tab lists on each level, what is locked and why in
## words, the least sizes as SET-BUILD-001 §4 states them in cells (quoted here), and the accessible names.
## Decision 1871.

const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

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


func test_rooms_underground_lists_types_old_tools_and_locked_tools() -> void:
	"""Seven paintable room types, Passage / Burrow home / Root cellar, then Earth and Remove locked."""
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 1, -1, _cards)
	var names: PackedStringArray = PackedStringArray()
	for card: BuildCatalog.Card in _cards:
		names.append(card.name)
	assert_equal(names, PackedStringArray(["Dormitory", "Bedroom", "Kitchen", "Dining room", "Common room",
		"Infirmary", "Pantry", "Passage", "Burrow home", "Root cellar", "Earth", "Remove"]), "the row")
	for at: int in 7:
		assert_true(_cards[at].usable() and _cards[at].kind == BuildCatalog.CARD_ROOM, "%s paints" % names[at])
	for at: int in [7, 8, 9]:
		assert_true(_cards[at].usable() and _cards[at].kind == BuildCatalog.CARD_LEGACY, "%s opens its tool" % names[at])
	assert_false(_cards[10].usable(), "Earth is locked")
	assert_false(_cards[11].usable(), "Remove is locked")
	assert_true(_cards[11].locked.begins_with("Not yet: "), "with words: %s" % _cards[11].locked)


func test_rooms_on_the_surface_are_locked_but_inspectable() -> void:
	"""No surface painting in slice B: the room types and Outdoor say why; the old tools still open."""
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 0, -1, _cards)
	assert_equal(_cards.size(), 13, "7 types, Outdoor, 3 old tools, Clear ground, Remove")
	for at: int in 7:
		assert_false(_cards[at].usable(), "%s locked on the surface" % _cards[at].name)
		assert_equal(_cards[at].locked, "Not yet: rooms on the surface come in a later update", "its reason")
		assert_false(_cards[at].purpose.is_empty(), "still inspectable: purpose")
	assert_equal(_cards[7].name, "Outdoor", "Outdoor follows the types")
	assert_true(_cards[8].usable() and _cards[8].legacy == BuildCatalog.LEGACY_PASSAGE, "Passage opens")
	assert_equal(_cards[11].name, "Clear ground", "Clear ground, not Earth, on the surface")
	for card: BuildCatalog.Card in _cards:
		assert_false(card.locked.contains("slice"), "no slice jargon: %s" % card.locked)


func test_furnish_lists_only_what_the_room_type_allows_and_decor_the_decoration() -> void:
	"""room_catalog.gd's palette: a Kitchen takes a bench; a Dormitory takes beds but no bench; all locked."""
	_catalog.cards_into(BuildCatalog.TAB_FURNISH, 1, 2, _cards)
	var kitchen: PackedStringArray = PackedStringArray()
	for card: BuildCatalog.Card in _cards:
		kitchen.append(card.name)
		assert_false(card.usable(), "%s locked" % card.name)
		assert_equal(card.locked, "Not yet: furnishing comes in a later update", "its words")
	assert_true(kitchen.has("Kitchen bench") and kitchen.has("Hearth"), "kitchen pieces: %s" % ", ".join(kitchen))
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


func test_legacy_cards_open_their_tools_and_say_so() -> void:
	"""Passage names the tunnel tool; the homes the room tool."""
	var passage: BuildCatalog.Card = _catalog.legacy_card(BuildCatalog.LEGACY_PASSAGE)
	assert_equal(passage.room_type, 7, "Passage is CORRIDOR")
	assert_true(passage.gesture.contains("tunnel tool"), passage.gesture)
	var home: BuildCatalog.Card = _catalog.legacy_card(BuildCatalog.LEGACY_HOME)
	assert_equal(home.room_type, -1, "a template is no room type")
	assert_true(home.gesture.contains("room tool"), home.gesture)


func test_overview_and_a_level_with_no_way_in_lock_the_room_types_saying_why() -> void:
	"""Overview: one level at a time (a PROPOSAL); no way in: BUILD-REQ-013's words; the old tools still open."""
	assert_equal(BuildCatalog.room_lock(1, true), "", "level 1 paints")
	assert_equal(BuildCatalog.room_lock(0, true), "Not yet: rooms on the surface come in a later update", "surface")
	assert_equal(BuildCatalog.room_lock(5, true), BuildCatalog.CHOOSE_A_LEVEL, "Overview")
	assert_equal(BuildCatalog.room_lock(3, false), Validity.no_way_in(), "level 3 without a way in")
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, 3, -1, _cards, false)
	assert_false(_cards[2].usable(), "the Kitchen is locked there")
	assert_equal(_cards[2].locked, Validity.no_way_in(), "in the canonical words")
	assert_true(_cards[7].usable() and _cards[7].kind == BuildCatalog.CARD_LEGACY, "Passage still opens its tool")
