extends RefCounted
## The build panel's cards (UI-BUILD-003) and the info card's words (UI-BUILD-004), per level and tab (DEC-061;
## SET-BUILD-001; docs/ui_ux_controls.md UI-BUILD-001). Presentation only: a card names what it would build and what
## it costs, and never orders, reserves or unlocks anything.
##
## WHAT EACH TAB LISTS (slice B, decision 1871).
##   Rooms, underground   the seven GDD room types to paint (Dormitory ... Pantry), then Passage, Burrow home and
##                        Root cellar (the old tunnel and template tools, Brendan's ruling 2 of 2026-10-12), then
##                        Earth and Remove, locked.
##   Rooms, surface       the same room types and Outdoor, Clear ground and Remove, LOCKED (surface rooms are
##                        slice G); Passage, Burrow home and Root cellar still open their tools.
##   Rooms, Overview or a level with no way in yet: the room types locked, saying why ("Choose one level to paint
##                        on" -- a PROPOSAL; "No way in: ..." -- BUILD-REQ-013's words); the old tools still open.
##   Furnish              the items the chosen room type allows (room_catalog.gd), locked: furnishing is slice E.
##   Decor                the decoration item, locked.
## A locked card stays inspectable: its info card gives the plain reason (`not_yet` words, a PROPOSAL).
##
## NUMBERS ARE READ, NOT RESTATED: a room type's least size is room_catalog.gd's GDD §5.9 requirement in tiles,
## times 4 cells a tile (SET-BUILD-001 §4); an item's bill and work are its balance §4.3 row (room_catalog.gd
## `furniture`); a cell's cost is build_ledger.gd's.

const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const TAB_ROOMS: int = 0
const TAB_FURNISH: int = 1
const TAB_DECOR: int = 2
const TAB_COUNT: int = 3
const TAB_NAMES: Array[String] = ["Rooms", "Furnish", "Decor"]

const CARD_ROOM: int = 0
const CARD_LEGACY: int = 1
const CARD_ITEM: int = 2
const CARD_TOOL: int = 3

const LEGACY_NONE: int = 0
const LEGACY_PASSAGE: int = 1
const LEGACY_HOME: int = 2
const LEGACY_CELLAR: int = 3

## SET-BUILD-001 §3: one GDD tile is 2 × 2 cells.
const CELLS_PER_TILE: int = 4
const CORRIDOR: int = 7
## The seven room types painted in slice B, in the GDD's RoomType order (CORRIDOR is the Passage card).
const PAINTED_TYPES: Array[int] = [0, 1, 2, 3, 4, 5, 6]
const PASSAGE_NAME: String = "Passage"
## Player-facing purpose of each GDD room type (GDD §5.9), by RoomType ordinal.
const PURPOSES: Array[String] = [
	"Shared sleeping room: beds for many residents",
	"A bedroom for one: a single bed behind its own walls or door",
	"Where meals are cooked: benches and a hearth",
	"Seats where residents sit down to eat together",
	"Seats for resting, talking and gatherings",
	"Patient beds and a shelf, where healers tend the sick; it must be heated",
	"Shelves that keep the settlement's food",
	"A tunnel for walking and hauling between rooms",
]
## What each room type needs besides its area (SET-BUILD-001 §4's furniture column, in words).
const NEEDS: Array[String] = [
	"1 bed per 12 cells", "exactly 1 bed and its own walls or door", "1 bench and 1 hearth",
	"4 seats, 1 per 8 cells", "4 seats", "1 patient bed per 12 cells and 1 shelf; heated", "1 shelf",
	"at least 2 cells wide",
]
## The placeholder pictures' descriptions (no room art exists yet: a PROPOSAL in decision 1871).
const PICTURES: Array[String] = [
	"rows of straw beds in a lamplit room", "a single bed in a small walled room", "a hearth and a long bench",
	"a table with stools around it", "seats around a warm hearth", "two patient beds and a shelf of herbs",
	"shelves of jars and sacks", "a timbered tunnel",
]
const GESTURE_PAINT: String = "Drag to paint; Esc cancels the stroke"
const GESTURE_PLACE: String = "Click to place; R to rotate"
const GESTURE_PASSAGE: String = "Opens the tunnel tool: drag from where it starts to where it ends"
const GESTURE_TEMPLATE: String = "Opens the room tool: move it, R turns it, click to hold, Enter to order"
const NOTHING_CHOSEN: String = "Choose a room type to begin"
const CHOOSE_FIRST: String = "Choose a room type first"
const LATER_SURFACE: String = "rooms on the surface come in a later update"
const LATER_OUTDOOR: String = "outdoor items come in a later update"
const LATER_FURNISH: String = "furnishing comes in a later update"
const LATER_DECOR: String = "decoration comes in a later update"
const LATER_REMOVE: String = "removing rooms comes in a later update"
const LATER_EARTH: String = "filling cells back in comes in a later update"
const LATER_CLEAR: String = "clearing ground comes in a later update"
## The bar's Overview shows every level; painting needs one (a PROPOSAL, decision 1871).
const OVERVIEW_LEVEL: int = 5
const CHOOSE_A_LEVEL: String = "Choose one level to paint on: Overview shows them all"
const LEGACY_NAMES: Array[String] = ["", "Passage", "Burrow home", "Root cellar"]
const LEGACY_PURPOSES: Array[String] = ["",
	"A tunnel for walking and hauling between rooms (the tunnel tool)",
	"A round home with its own front door (the room tool)",
	"A stone-lined cellar with a hatch, for keeping harvests (the room tool)"]
const ITEM_NAMES: Dictionary = {
	"bed": "Bed", "decoration": "Decoration", "hearth": "Hearth", "interior_door": "Door",
	"interior_partition": "Partition", "kitchen_bench": "Kitchen bench", "patient_bed": "Patient bed",
	"seat": "Seat", "shelf": "Shelf",
}


class Card extends RefCounted:
	## One card: what it is, what it costs, and whether it can be used now (`locked` empty: it can).
	var id: StringName = &""
	var kind: int = 0
	var name: String = ""
	var room_type: int = -1
	var item_type: int = -1
	var legacy: int = 0
	var locked: String = ""
	var cost: String = ""
	var footprint: String = ""
	var purpose: String = ""
	var rules: String = ""
	var gesture: String = ""
	var picture: String = ""

	func usable() -> bool:
		"""Whether choosing the card does something now (an unlocked card)."""
		return locked.is_empty()

	func unlock_state() -> String:
		"""The card's unlock state in words: "available", or the validity line of why not."""
		return "available" if locked.is_empty() else Validity.line(Validity.KIND_BLOCKED, locked)

	func accessible_name() -> String:
		"""UI-BUILD-003's binding: name; cost per cell or per item; footprint in cells; unlock state."""
		return "%s; %s; %s; %s" % [name, cost, footprint, unlock_state()]


var _rooms: RoomCatalog = RoomCatalog.new()
var _clear_height_u: int = Ledger.DEFAULT_CLEAR_HEIGHT_U
## Each level's clear height (index = level; 0 and Overview unused), for a cell's cost on that level.
var _level_heights: PackedInt32Array = PackedInt32Array([4096, 4096, 4096, 4096, 4096, 4096])
var _tally: PackedInt64Array = PackedInt64Array()


func set_clear_height(clear_height_u: int) -> void:
	"""Every level's clear height, which sets a cell's cost (build_ledger.gd)."""
	_clear_height_u = clear_height_u
	_level_heights.fill(clear_height_u)


func set_level_clear_height(level: int, clear_height_u: int) -> void:
	"""One level's clear height (the level actually painted prices its cells)."""
	if level >= 0 and level < _level_heights.size():
		_level_heights[level] = clear_height_u


func clear_height_of(level: int) -> int:
	"""Level `level`'s clear height (the shared one for a level the catalog does not know)."""
	return _level_heights[level] if level >= 0 and level < _level_heights.size() else _clear_height_u


func clear_height() -> int:
	"""The clear height cells are priced at."""
	return _clear_height_u


static func type_name(room_type: int) -> String:
	"""A room type's player-facing name: room_catalog.gd's labels, with CORRIDOR shown as "Passage" (SET-BUILD-001)."""
	if room_type == CORRIDOR:
		return PASSAGE_NAME
	var key: Variant = Catalog.ROOM_TYPE.find_key(room_type)
	return RoomCatalog.ROOM_LABELS[key] if key != null else ""


func minimum_cells(room_type: int) -> int:
	"""SET-BUILD-001 §4: the least cells a room type needs, from GDD §5.9's tiles (room_catalog.gd) times 4; 0 for
	a type with no area rule (CORRIDOR's is its width) or an unknown type."""
	var needs: RoomCatalog.ServiceRequirements = _rooms.service_requirements(room_type)
	if not needs.ok:
		return 0
	var tiles: int = needs.minimum_tiles
	if needs.area_per_kind >= 0:
		tiles = maxi(tiles, needs.minimum_counts[needs.area_per_kind] * needs.tiles_per_piece)
	return tiles * CELLS_PER_TILE


func rules_text(room_type: int) -> String:
	"""The info card's rules line: "Needs 1 bench and 1 hearth; at least 24 cells"."""
	if room_type < 0 or room_type >= NEEDS.size():
		return ""
	var least: int = minimum_cells(room_type)
	if least <= 0:
		return "Needs %s" % NEEDS[room_type]
	return "Needs %s; at least %d cells" % [NEEDS[room_type], least]


func cell_cost_text(level: int = 1) -> String:
	"""What one painted cell on `level` costs, in natural measures (build_ledger.gd)."""
	Ledger.per_cell_into(clear_height_of(level), _tally)
	return "per cell %s" % Ledger.cost_words(_tally)


func cards_into(tab: int, level: int, chosen_type: int, out: Array[Card], reachable: bool = true) -> void:
	"""The cards a tab shows on `level` (0: the surface; 1-4 underground; 5: Overview), given the chosen room type
	(-1: none) and whether the level has a way in, into `out` (cleared first). Cold path: called when the tab, the level
	or the chosen type changes."""
	out.clear()
	match tab:
		TAB_ROOMS:
			_room_cards(level, room_lock(level, reachable), out)
		TAB_FURNISH:
			_item_cards(chosen_type, false, out)
		TAB_DECOR:
			_item_cards(chosen_type, true, out)


static func room_lock(level: int, reachable: bool) -> String:
	"""Why the room types cannot be painted on `level` ("" when they can): the surface (a later update), Overview
	(one level at a time), or a level with no way in yet (BUILD-REQ-013)."""
	if level <= 0:
		return Validity.not_yet(LATER_SURFACE)
	if level >= OVERVIEW_LEVEL:
		return CHOOSE_A_LEVEL
	return "" if reachable else Validity.no_way_in()


func _room_cards(level: int, lock: String, out: Array[Card]) -> void:
	"""Rooms: the painted types, then the old tools, then the locked tools (see WHAT EACH TAB LISTS)."""
	var surface: bool = level <= 0
	for room_type: int in PAINTED_TYPES:
		out.append(room_card(room_type, lock, clampi(level, 1, 4)))
	if surface:
		out.append(_tool_card(&"tool:outdoor", "Outdoor", LATER_OUTDOOR, "Wells, fences, paths and other things built in the open"))
	for legacy: int in [LEGACY_PASSAGE, LEGACY_HOME, LEGACY_CELLAR]:
		out.append(legacy_card(legacy))
	if surface:
		out.append(_tool_card(&"tool:clear", "Clear ground", LATER_CLEAR, "Paint over a surface room to take it down"))
	else:
		out.append(_tool_card(&"tool:earth", "Earth", LATER_EARTH, "Paint earth back over dug cells to fill them in"))
	out.append(_tool_card(&"tool:remove", "Remove", LATER_REMOVE, "Click a placed room or item to review its removal"))


func room_card(room_type: int, locked_reason: String, level: int = 1) -> Card:
	"""A room type's card on `level`: paint it there, priced at that level's clear height (or locked with
	`locked_reason`)."""
	var card: Card = Card.new()
	card.id = StringName("room:%d" % room_type)
	card.kind = CARD_ROOM
	card.name = type_name(room_type)
	card.room_type = room_type
	card.locked = locked_reason
	card.cost = cell_cost_text(level)
	card.footprint = "at least %d cells" % minimum_cells(room_type) if minimum_cells(room_type) > 0 else "at least 2 cells wide"
	card.purpose = PURPOSES[room_type]
	card.rules = rules_text(room_type)
	card.gesture = GESTURE_PAINT
	card.picture = PICTURES[room_type]
	return card


func legacy_card(legacy: int) -> Card:
	"""The Passage, Burrow home or Root cellar card: it opens the old tool, which has its own confirm."""
	var card: Card = Card.new()
	card.id = StringName("legacy:%d" % legacy)
	card.kind = CARD_LEGACY
	card.name = LEGACY_NAMES[legacy]
	card.legacy = legacy
	card.room_type = CORRIDOR if legacy == LEGACY_PASSAGE else -1
	card.cost = "costs shown by its tool as you lay it"
	card.footprint = "at least 2 cells wide" if legacy == LEGACY_PASSAGE else "a fixed room shape"
	card.purpose = LEGACY_PURPOSES[legacy]
	card.rules = rules_text(CORRIDOR) if legacy == LEGACY_PASSAGE else "Dug by the village's diggers; it needs a passage in"
	card.gesture = GESTURE_PASSAGE if legacy == LEGACY_PASSAGE else GESTURE_TEMPLATE
	card.picture = PICTURES[CORRIDOR] if legacy == LEGACY_PASSAGE else "a round door in an earth bank"
	return card


func _tool_card(id: StringName, title: String, later: String, purpose: String) -> Card:
	"""A locked tool card (Outdoor, Clear ground, Earth, Remove): inspectable, with its reason."""
	var card: Card = Card.new()
	card.id = id
	card.kind = CARD_TOOL
	card.name = title
	card.locked = Validity.not_yet(later)
	card.cost = "no cost shown yet"
	card.footprint = "painted cells"
	card.purpose = purpose
	card.rules = card.locked
	card.gesture = GESTURE_PAINT
	card.picture = "no picture yet"
	return card


func _item_cards(room_type: int, decor: bool, out: Array[Card]) -> void:
	"""Furnish: the items `room_type` allows but decoration; Decor: decoration. Every one locked in slice B."""
	if room_type < 0:
		return
	var later: String = Validity.not_yet(LATER_DECOR if decor else LATER_FURNISH)
	for key: String in ITEM_NAMES:
		var item: int = int(Catalog.FURNITURE_DEFINITION[key])
		if (key == "decoration") != decor or _rooms.compatibility_error(room_type, item) != &"":
			continue
		out.append(item_card(item, later))


func item_card(item: int, locked_reason: String) -> Card:
	"""A furniture item's card: its balance §4.3 bill and work, its footprint in cells (SET-BUILD-001 §6)."""
	var facts: RoomCatalog.FurnitureFacts = _rooms.furniture(item)
	var card: Card = Card.new()
	card.id = StringName("item:%d" % item)
	card.kind = CARD_ITEM
	card.item_type = item
	card.name = ITEM_NAMES.get(String(facts.key), String(facts.key))
	card.locked = locked_reason
	card.cost = "per item %s" % _bill_words(facts)
	card.footprint = _footprint_words(facts)
	card.purpose = "Furniture for the room"
	card.rules = locked_reason
	card.gesture = GESTURE_PLACE
	card.picture = "no picture yet"
	return card


static func _bill_words(facts: RoomCatalog.FurnitureFacts) -> String:
	"""An item's bill and work in natural measures: "2 logs of wood, 1 length of cloth; work about 30 minutes"."""
	var parts: PackedStringArray = PackedStringArray()
	for at: int in facts.material_keys.size():
		parts.append(Measures.need(StringName(facts.material_keys[at]), facts.quantity_milli[at]))
	return "%s; work %s" % [", ".join(parts), Ledger.work_text(facts.work_mwu)]


static func _footprint_words(facts: RoomCatalog.FurnitureFacts) -> String:
	"""SET-BUILD-001 §6: a tile is 2 × 2 cells; an edge item spans 2 cell edges."""
	if facts.edge_placement or facts.footprint_units == Vector2i.ZERO:
		return "2 cell edges"
	@warning_ignore("integer_division") var x: int = facts.footprint_units.x / 1024
	@warning_ignore("integer_division") var z: int = facts.footprint_units.y / 1024
	return "%d × %d cells" % [x, z]
