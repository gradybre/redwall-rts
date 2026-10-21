extends RefCounted
## The build panel's cards (UI-BUILD-003) and the info card's words (UI-BUILD-004), per level and tab (DEC-061;
## SET-BUILD-001; docs/ui_ux_controls.md UI-BUILD-001). Presentation only: a card names what it would build and what
## it costs, and never orders, reserves or unlocks anything.
##
## WHAT EACH TAB LISTS (slice B, decision 1871; slice C1, decision 1912).
##   Rooms, underground   the eight GDD room types to paint (Dormitory ... Pantry, then Passage, which is CORRIDOR:
##                        BUILD-REQ-014), then Earth and Remove, locked. A level with no way in yet is painted all the
##                        same: each cell then says "No way in" on its ghost (BUILD-REQ-013 per cell, decision 1911
##                        P-C4 (a)). The old Passage / Burrow home / Root cellar tool cards are gone (Brendan's ruling on
##                        decision 1911 P-C2 (c): "remove them now").
##   Rooms, surface       the same room types and Outdoor, Clear ground and Remove; the room types are painted in the
##                        MOUND style (decision 2002: dug into a hill heaped to fit them, BUILD-MOUND-001) and LOCKED
##                        in the Built style (built surface rooms are slice G); underground, the Mound style locks
##                        them "X Not possible: Mound rooms are painted on the Surface" (BUILD-MOUND-028).
##   Rooms, Overview      the room types locked, saying why ("Choose one level to paint on" -- a PROPOSAL).
## THE WAYS DOWN AND UP (decision 1912's proof of concept, per family since decision 2021: Brendan's rulings P-D1-1 (a),
## P-D1-2 (a), P-D1-4 (a)): every level's Rooms tab offers the Burrow mouth, the Hatch with ladder and the Stair-head
## (build_connector_families.gd), then Stone stairs and Spiral stair locked ("Not yet: ..."). On the Surface each goes
## down; on level 4 only up; between, either (the connector card, UI-BUILD-012). Every size and cost is a PLACEHOLDER,
## said so on the card; free for now.
##   Furnish              the items the chosen room type allows (room_catalog.gd) but decoration, placed on the dug
##                        floor of levels 1-4 (decision 1921: Brendan's Furnish-tab rulings of 2026-10-13, a proof of
##                        concept slice E replaces); locked on the surface and Overview, saying why.
##   Decor                the decoration item, placed the same way (UI-BUILD-002 keeps it on its own tab).
## MOUND DOORS AND WINDOWS (decision 2002; BUILD-MOUND-010, -013): the Furnish tab offers the Front door on the Surface
## and the Window everywhere (underground it is refused in words, BUILD-MOUND-020), placed on a Mound room's outer
## edge before or after its rooms are dug; Mound rooms' own furniture is placed on their dug floor on the Surface.
## A locked card stays inspectable: its info card gives the plain reason (`not_yet` words, a PROPOSAL).
##
## NUMBERS ARE READ, NOT RESTATED: a room type's least size is room_catalog.gd's GDD §5.9 requirement in tiles,
## times 4 cells a tile (SET-BUILD-001 §4); an item's bill and work are its balance §4.3 row (room_catalog.gd
## `furniture`); a cell's cost is build_ledger.gd's, at the height actually dug on its level: the clear height capped
## by DEC-054's reachable height (Brendan's ruling on decision 1911 P-C3 (a); the host sets it, `set_level_clear_height`).

const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const Items := preload("res://scripts/ui/build_items.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")

const TAB_ROOMS: int = 0
const TAB_FURNISH: int = 1
const TAB_DECOR: int = 2
const TAB_COUNT: int = 3
const TAB_NAMES: Array[String] = ["Rooms", "Furnish", "Decor"]

const CARD_ROOM: int = 0
## 1 was the old tools' card (decision 1871), removed by decision 1912.
const CARD_ITEM: int = 2
const CARD_TOOL: int = 3
## A way down or up (build_items.gd) of one connector family, `item_type` its family (decision 2021).
const CARD_WAY_DOWN: int = 4
## A Mound's front door or window (decision 2002; build_mound.gd KIND_*).
const CARD_EDGE: int = 5

## SET-BUILD-001 §3: one GDD tile is 2 × 2 cells.
const CELLS_PER_TILE: int = 4
const CORRIDOR: int = 7
## The eight GDD room types painted, in RoomType order; CORRIDOR (7) is shown as Passage (BUILD-REQ-014).
const PAINTED_TYPES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
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
const GESTURE_PLACE: String = "Click a dug floor to place; R / Shift+R turn it; Shift+click keeps it for another"
const GESTURE_WAY_DOWN: String = "Click a spot, then choose Down or Up on its card; R / Shift+R turn it; click a built one to remove it"
const FREE_FOR_NOW: String = "free for now (proof of concept)"
const WAY_PURPOSES: Array[String] = [
	"A way from the ground to underground level 1: rooms and passages there connect to it",
	"A way to the next level, down or up, standing on a passage",
	"A way up to level 3, standing on a passage there",
]
## A connector's placeholder cost on its card: "placeholder: 3 logs ...; free for now (proof of concept)".
const WAY_COST: String = "placeholder: %s; %s"
const WAY_FOOTPRINT: String = "%d × %d cells on this level, %d × %d below (placeholder)"
const NOTHING_CHOSEN: String = "Choose a room type to begin"
## Decision 1921: the Furnish and Decor tabs with no piece chosen.
const CHOOSE_PIECE: String = "Choose a piece to place"
const CHOOSE_FIRST: String = "Choose a room type first"
const LATER_SURFACE: String = Mound.LATER_BUILT_SURFACE
const LATER_OUTDOOR: String = "outdoor items come in a later update"
## Decision 1921: furniture stands on dug rooms below; surface rooms come later.
const LATER_FURNISH: String = "furnishing built surface rooms comes in a later update"
## Decision 2002: the Mound style on a room card, the doors' and windows' cards.
const MOUND_RULES: String = "; Mound: dug into a hill heaped to fit it, its door and windows placed by you"
const MOUND_COST: String = " and its heap's earth (free for now)"
const EDGE_GESTURE: String = "Click a Mound room's outer edge; click a placed one to remove it"
const EDGE_PURPOSES: Array[String] = [
	"A round front door, oak by default, in a built front: plaster, timber posts, a turfed eave, a lantern and steps; a yard stays clear before it",
	"A round window lying flush on the turf slope at the wall's top metre; it lights its room",
]
const MOUND_EDGE_RULES: Array[String] = [
	"On two outer edges of a Mound room side by side, with a clear yard 6 cells wide in front of it",
	"On one outer edge of a Mound room; only where a hill face lies beyond the wall",
]
const EDGE_FOOTPRINTS: Array[String] = ["2 cell edges", "1 cell edge"]
const EDGE_PICTURES: Array[String] = ["a round oak door under a turfed timber eave", "a round window set in turf"]
const ITEM_RULES: String = "Stands on the dug floor of a room that uses it (%s), clear of other furniture"
const EDGE_RULES: String = "Stands on 2 cell edges with a dug room floor on both sides (%s); R / Shift+R pick the side"
const ITEM_PURPOSE: String = "Furniture for the room: a resident fits it after Confirm all; %s"
const LATER_REMOVE: String = "removing rooms comes in a later update"
const LATER_EARTH: String = "filling cells back in comes in a later update"
const LATER_CLEAR: String = "clearing ground comes in a later update"
## The bar's Overview shows every level; painting needs one (a PROPOSAL, decision 1871).
const OVERVIEW_LEVEL: int = 5
const CHOOSE_A_LEVEL: String = "Choose one level to paint on: Overview shows them all"
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
	var locked: String = ""
	var cost: String = ""
	var footprint: String = ""
	var purpose: String = ""
	var rules: String = ""
	var gesture: String = ""
	var picture: String = ""
	## Decision 2002: a door's or window's kind (build_mound.gd KIND_*; -1 for any other card), and the kind of a
	## lock's words: "! Blocked" for a later update, "X Not possible" for the Mound style underground.
	var edge_kind: int = -1
	var lock_kind: int = Validity.KIND_BLOCKED

	func usable() -> bool:
		"""Whether choosing the card does something now (an unlocked card)."""
		return locked.is_empty()

	func unlock_state() -> String:
		"""The card's unlock state in words: "available", or the validity line of why not."""
		return "available" if locked.is_empty() else Validity.line(lock_kind, locked)

	func accessible_name() -> String:
		"""UI-BUILD-003's binding: name; cost per cell or per item; footprint in cells; unlock state."""
		return "%s; %s; %s; %s" % [name, cost, footprint, unlock_state()]


var _rooms: RoomCatalog = RoomCatalog.new()
var _clear_height_u: int = Ledger.DEFAULT_CLEAR_HEIGHT_U
## Each level's dug height (index = level; 0 and Overview unused): the clear height, capped by DEC-054.
var _level_heights: PackedInt32Array = PackedInt32Array([4096, 4096, 4096, 4096, 4096, 4096])
var _tally: PackedInt64Array = PackedInt64Array()


func set_clear_height(clear_height_u: int) -> void:
	"""Every level's clear height, which sets a cell's cost (build_ledger.gd)."""
	_clear_height_u = clear_height_u
	_level_heights.fill(clear_height_u)


func set_level_clear_height(level: int, clear_height_u: int) -> void:
	"""One level's dug height: the clear height, or less where DEC-054 caps it (the level painted prices its cells)."""
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


func cards_into(tab: int, level: int, chosen_type: int, out: Array[Card], reachable: bool = true,
		style: int = Mound.STYLE_BUILT) -> void:
	"""The cards a tab shows on `level` (0: the surface; 1-4 underground; 5: Overview), given the chosen room type
	(-1: none), whether the level has a way in and the style chosen (build_mound.gd STYLE_*), into `out` (cleared
	first). Cold path: called when the tab, the level, the style or the chosen type changes."""
	out.clear()
	match tab:
		TAB_ROOMS:
			_room_cards(level, room_lock(level, reachable, style), out, style)
		TAB_FURNISH:
			_edge_cards(chosen_type, level, out)
			_item_cards(chosen_type, false, item_lock(level), out)
		TAB_DECOR:
			_item_cards(chosen_type, true, item_lock(level), out)


static func room_lock(level: int, _reachable: bool = true, style: int = Mound.STYLE_BUILT) -> String:
	"""Why the room types cannot be painted on `level` in `style` ("" when they can): built rooms on the surface (a
	later update), Mound rooms below it (BUILD-MOUND-028), or Overview (one level at a time). A level with no way in yet
	is painted all the same; its cells say "No way in" (decision 1912)."""
	if level >= OVERVIEW_LEVEL:
		return CHOOSE_A_LEVEL
	if level <= 0:
		return "" if style == Mound.STYLE_MOUND else Validity.not_yet(LATER_SURFACE)
	return Mound.TEXT_SURFACE_ONLY if style == Mound.STYLE_MOUND else ""


static func lock_kind_of(level: int, style: int) -> int:
	"""The kind of `room_lock`'s words: "X" for the Mound style below the Surface, else "!"."""
	return Validity.KIND_NOT_POSSIBLE if style == Mound.STYLE_MOUND and level >= 1 and level < OVERVIEW_LEVEL \
		else Validity.KIND_BLOCKED


static func item_lock(level: int) -> String:
	"""Why furniture cannot be placed on `level` ("" when it can): Overview (one level at a time). Decision 1921; on
	the surface it stands on a Mound room's dug floor (decision 2002)."""
	if level >= OVERVIEW_LEVEL:
		return CHOOSE_A_LEVEL
	return ""


func _room_cards(level: int, lock: String, out: Array[Card], style: int = Mound.STYLE_BUILT) -> void:
	"""Rooms: the painted types in `style`, then the locked tools (see WHAT EACH TAB LISTS)."""
	var surface: bool = level <= 0
	for room_type: int in PAINTED_TYPES:
		var card: Card = room_card(room_type, lock, clampi(level, 0, 4), style)
		card.lock_kind = lock_kind_of(level, style)
		out.append(card)
	if surface:
		out.append(_tool_card(&"tool:outdoor", "Outdoor", LATER_OUTDOOR, "Wells, fences, paths and other things built in the open"))
	if level < OVERVIEW_LEVEL:
		for family: int in Families.CARD_ORDER:
			out.append(way_card(family, level))
	if surface:
		out.append(_tool_card(&"tool:clear", "Clear ground", LATER_CLEAR, "Paint over a surface room to take it down"))
	else:
		out.append(_tool_card(&"tool:earth", "Earth", LATER_EARTH, "Paint earth back over dug cells to fill them in"))
	out.append(_tool_card(&"tool:remove", "Remove", LATER_REMOVE, "Click a placed room or item to review its removal"))


func room_card(room_type: int, locked_reason: String, level: int = 1, style: int = Mound.STYLE_BUILT) -> Card:
	"""A room type's card on `level` in `style`: paint it there, priced at that level's clear height (a Mound's with
	its heap, free for now), or locked with `locked_reason`."""
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
	if style == Mound.STYLE_MOUND:
		card.rules += MOUND_RULES
		card.cost += MOUND_COST
	return card


func way_card(family: int, level: int) -> Card:
	"""A connector family's card on `level` (decision 2021): placed down from the Surface, up only from level 4, either
	way between; Stone and Spiral locked for a later update. Every number on it is a placeholder."""
	var card: Card = Card.new()
	card.id = StringName("way:%d:%d" % [family, level])
	card.kind = CARD_WAY_DOWN
	card.item_type = family
	card.name = Families.name_of(family)
	card.locked = "" if Families.offered(family) else Validity.not_yet(Families.LATER)
	_tally.resize(Ledger.SLOTS)
	_tally.fill(0)
	Families.bill_into(family, _tally)
	card.cost = WAY_COST % [Ledger.cost_words(_tally), FREE_FOR_NOW]
	card.footprint = WAY_FOOTPRINT % [Families.ACROSS[family], Families.TOP_OPEN[family], Families.ACROSS[family],
		Families.ALONG[family] - Families.LOW_FROM[family]]
	card.purpose = WAY_PURPOSES[0 if level == 0 else (2 if level >= 4 else 1)]
	card.rules = Families.PLACEHOLDER + (". " + Families.CLIMBERS_ONLY if family == Families.LADDER_HATCH else "")
	card.gesture = GESTURE_WAY_DOWN
	card.picture = Families.PICTURES[family]
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


func _edge_cards(room_type: int, level: int, out: Array[Card]) -> void:
	"""Furnish's Mound edge items (decision 2002): the Front door on the Surface, the Window on any level up to the
	deepest (refused in words below the Surface); none before a room type is chosen, nor on Overview."""
	if room_type < 0 or level >= OVERVIEW_LEVEL:
		return
	if level == Mound.SURFACE:
		out.append(edge_card(Mound.KIND_DOOR))
	out.append(edge_card(Mound.KIND_WINDOW))


func edge_card(kind: int) -> Card:
	"""A Mound front door's or window's card: free for now, placed on outer edges (see the header)."""
	var card: Card = Card.new()
	card.id = StringName("edge:%d" % kind)
	card.kind = CARD_EDGE
	card.edge_kind = kind
	card.name = Mound.kind_name(kind)
	card.cost = FREE_FOR_NOW
	card.footprint = EDGE_FOOTPRINTS[kind]
	card.purpose = EDGE_PURPOSES[kind]
	card.rules = MOUND_EDGE_RULES[kind]
	card.gesture = EDGE_GESTURE
	card.picture = EDGE_PICTURES[kind]
	return card


func _item_cards(room_type: int, decor: bool, lock: String, out: Array[Card]) -> void:
	"""Furnish: the items `room_type` allows but decoration; Decor: decoration; each locked with `lock` ("" places
	it)."""
	if room_type < 0:
		return
	for key: String in ITEM_NAMES:
		var item: int = int(Catalog.FURNITURE_DEFINITION[key])
		if (key == "decoration") != decor or _rooms.compatibility_error(room_type, item) != &"":
			continue
		out.append(item_card(item, lock))


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
	card.purpose = ITEM_PURPOSE % FREE_FOR_NOW
	card.rules = (EDGE_RULES if facts.edge_placement else ITEM_RULES) % users_of(item) if locked_reason.is_empty() \
		else locked_reason
	card.gesture = GESTURE_PLACE
	card.picture = "no picture yet"
	return card


func users_of(item: int) -> String:
	"""The room types that use `item`, in words: "Dormitory or Bedroom", or "any room" for a shared fitting."""
	return users_in(_rooms, item)


static func users_in(rooms: RoomCatalog, item: int) -> String:
	"""`users_of` read through `rooms` (room_catalog.gd `compatibility_error`)."""
	var names: PackedStringArray = PackedStringArray()
	for room_type: int in PAINTED_TYPES:
		if rooms.compatibility_error(room_type, item) == &"":
			names.append(type_name(room_type))
	return " or ".join(names) if names.size() < PAINTED_TYPES.size() else "any room"


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
