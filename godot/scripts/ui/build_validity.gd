extends RefCounted
## UI-BUILD-001 "Validity in words" (docs/ui_ux_controls.md, DEC-061): every ghost, card and refusal states its
## result as a GLYPH AND A WORD, never by colour alone (MOVE-REQ-018, REQ-UX-005).
##
##     ✓ Can build              GOLD     every condition met
##     ! Blocked: <reason>      WARNING  valid here once the player fixes something
##     X Not possible: <reason> DANGER   never valid here
##
## The canonical reasons are the section's table, word for word; each builder below returns one and names the
## glyph it carries (`REASON_KINDS`). A reason the table does not hold is marked PROPOSAL where it is defined
## (decision 1871): the shape words the planner already shows, "Outside the planning area" and the locked cards'
## "Not yet: ..."; decision 1912 (slice C1) adds "Nothing to erase" and retires "Joins two planned rooms" (a stroke
## joining two pending rooms of its type now merges them: P-B2 (b)). Pure and static; nothing here reads game state.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

const KIND_CAN_BUILD: int = 0
const KIND_BLOCKED: int = 1
const KIND_NOT_POSSIBLE: int = 2
const KIND_COUNT: int = 3
const GLYPHS: Array[String] = ["✓", "!", "X"]
const WORDS: Array[String] = ["Can build", "Blocked", "Not possible"]
## §2.1 tokens per kind: GOLD, WARNING, DANGER.
const TOKENS: Array[int] = [UiTheme.TOKEN_GOLD, UiTheme.TOKEN_WARNING, UiTheme.TOKEN_DANGER]

## The canonical reason ids, in the table's order; then this slice's proposals.
const REASON_NONE: int = 0
const REASON_TOO_NARROW: int = 1
const REASON_TOO_SMALL: int = 2
const REASON_NEEDS: int = 3
const REASON_NO_WAY_IN: int = 4
const REASON_OVERLAPS: int = 5
const REASON_CANNOT_DIG: int = 6
const REASON_TOO_STEEP: int = 7
const REASON_UNEVEN: int = 8
const REASON_WRONG_ROOM: int = 9
const REASON_NEEDS_WALL: int = 10
const REASON_ACCESS_BLOCKED: int = 11
const REASON_LOCKED: int = 12
const REASON_NO_LEVEL_ABOVE: int = 13
const REASON_NO_LEVEL_BELOW: int = 14
const REASON_CUT_OFF: int = 15
const REASON_OUTSIDE: int = 16
const REASON_SHAPE: int = 17
## Slot 18 was "Joins two planned rooms" (decision 1871), retired by decision 1912: BUILD-REQ-006's removal words.
const REASON_NARROW_REMOVAL: int = 18
const REASON_NOT_YET: int = 19
const REASON_REFUSED: int = 20
const REASON_NOTHING_NEW: int = 21
const REASON_NOTHING_TO_ERASE: int = 22
const REASON_WAY_DOWN_CLASH: int = 23
const REASON_NEEDS_FLOOR: int = 24
## Decision 1921 (the Furnish tab's proof of concept): where a piece of furniture may not stand.
const REASON_NOT_DUG: int = 25
const REASON_NOT_ON_ROOM: int = 26
const REASON_TWO_ROOMS: int = 27
const REASON_PIECE_OVERLAPS: int = 28
const REASON_NOT_BETWEEN_FLOORS: int = 29
const REASON_CUTS_PIECE: int = 30
const REASON_ON_WAY_DOWN: int = 31
## Decision 2021 (slice D1; Brendan's ruling P-D1-12 (a), "as worded"): where a connector may stand.
const REASON_NEEDS_PASSAGE: int = 32
const REASON_NOT_IN_ROOM: int = 33
const REASON_COUNT: int = 34
## The glyph each reason carries, by REASON_* id (the table's Glyph column; proposals as decision 1871 says).
const REASON_KINDS: Array[int] = [
	KIND_CAN_BUILD, KIND_NOT_POSSIBLE, KIND_BLOCKED, KIND_BLOCKED, KIND_BLOCKED, KIND_NOT_POSSIBLE,
	KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE,
	KIND_BLOCKED, KIND_BLOCKED, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE,
	KIND_NOT_POSSIBLE, KIND_BLOCKED, KIND_NOT_POSSIBLE, KIND_BLOCKED, KIND_BLOCKED, KIND_NOT_POSSIBLE,
	KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_BLOCKED, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE,
	KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_NOT_POSSIBLE, KIND_BLOCKED, KIND_NOT_POSSIBLE,
]

const TEXT_TOO_NARROW: String = "Too narrow: rooms need at least 2 × 2 cells"
const FORMAT_TOO_SMALL: String = "Too small: %s needs at least %d cells (has %d)"
const FORMAT_NEEDS: String = "Needs %s"
const TEXT_NO_WAY_IN: String = "No way in: connect to a finished Passage or entrance"
const FORMAT_OVERLAPS: String = "Overlaps %s: remove these cells first; a room's purpose cannot change"
const FORMAT_CANNOT_DIG: String = "Cannot dig here: %s"
const TEXT_TOO_STEEP: String = "Too steep: slope over 8°"
const TEXT_UNEVEN: String = "Uneven ground: over 0.5 m height difference"
const FORMAT_WRONG_ROOM: String = "Wrong room: %s belongs in %s"
const TEXT_NEEDS_WALL: String = "Needs a wall behind it"
const TEXT_ACCESS_BLOCKED: String = "Access blocked: keep one access tile free"
const FORMAT_LOCKED: String = "Locked: needs %s"
const TEXT_NO_LEVEL_ABOVE: String = "No level above the surface"
const TEXT_NO_LEVEL_BELOW: String = "No level below level 4"
const FORMAT_CUT_OFF: String = "Would cut off %s: build another way in first"
## BUILD-REQ-006 as amended by decision 1880 Q3 (canonical): here an Erase that would leave a pending room part one
## cell wide (the review that adds those cells comes with slice F's removals).
const FORMAT_NARROW_REMOVAL: String = "Too narrow: this would leave part of %s under 2 × 2 cells; remove those cells too"
## PROPOSAL (decision 1871): a stroke past the planning area's edge is refused whole, never clipped (ADR 1055).
const TEXT_OUTSIDE: String = "Outside the planning area: keep the whole room inside it"
## PROPOSAL: the planner's own shape refusals (modular_editor.gd `_words`), prefixed so they read as a reason.
const FORMAT_SHAPE: String = "Shape: %s"
## PROPOSAL: a card for a later part of the build model, inspectable but not usable yet.
const FORMAT_NOT_YET: String = "Not yet: %s"
## PROPOSAL: a stroke wholly inside its own planned room adds nothing (it is dropped, no Undo step).
const TEXT_NOTHING_NEW: String = "Nothing to add: these cells are already planned for this room"
## PROPOSAL (decision 1912): an Erase stroke over no pending cell of the chosen room type takes nothing out.
const FORMAT_NOTHING_TO_ERASE: String = "Nothing to erase: no planned %s cells here"
## PROPOSAL (decision 1912, the proof of concept's ways down): two ways down on the same cells.
const FORMAT_WAY_DOWN_CLASH: String = "Overlaps another %s: undo it first"
## PROPOSAL (decision 1912): a way down below the surface stands on a planned or dug passage or room.
const FORMAT_NEEDS_FLOOR: String = "%s needs a passage or room under it: paint one there first"
## PROPOSAL (decision 1921): furniture stands only on cells the mole has dug (Brendan's "Footprint + rotation").
const TEXT_NOT_DUG: String = "Not dug yet: furniture stands on a dug room's floor"
## PROPOSAL (decision 1921): a piece over earth, or over a way's landing, is in no room.
const TEXT_NOT_ON_ROOM: String = "Not in a room: place it on a dug room's floor"
## PROPOSAL (decision 1921): a piece's footprint lies inside one room (BUILD-REQ-010).
const TEXT_TWO_ROOMS: String = "Spans two rooms: keep it inside one room"
## PROPOSAL (decision 1921): furniture cannot overlap (GDD §5.9).
const FORMAT_PIECE_OVERLAPS: String = "Overlaps a %s: place it clear of other furniture"
## PROPOSAL (decision 1921): a door or partition stands on cell edges with dug floor on both sides and a room on one.
const FORMAT_NOT_BETWEEN_FLOORS: String = "Not between dug floors: a %s needs dug floor on both sides and a room on one"
## PROPOSAL (decision 1921): a door or partition may not split one piece of furniture.
const FORMAT_CUTS_PIECE: String = "Cuts through a %s: put it between pieces"
## PROPOSAL (decision 1921): furniture keeps a way down's stairs and landing clear.
const TEXT_ON_WAY_DOWN: String = "On a way down: keep its stairs clear"
## Decision 2021 P-D1-5 (a) and P-D1-12 (a): below the Surface a connector stands on a Passage (SET-BUILD-001 §9).
const FORMAT_NEEDS_PASSAGE: String = "%s needs a passage under it: paint one there first"
## Decision 2021 P-D1-12 (a): a connector partly on a Mound room's floor (BUILD-MOUND-021's "refused with its reason").
const FORMAT_NOT_IN_ROOM: String = "%s does not fit in this room: it needs %d × %d cells"
## UI-BUILD-012's card: where a connector leads (decision 2021).
const FORMAT_CONNECTS: String = "Connects to %s"


static func is_kind(kind: int) -> bool:
	"""Whether `kind` is one of the three results."""
	return kind >= KIND_CAN_BUILD and kind < KIND_COUNT


static func glyph(kind: int) -> String:
	"""The kind's glyph: ✓, ! or X ("" for an unknown kind)."""
	return GLYPHS[kind] if is_kind(kind) else ""


static func word(kind: int) -> String:
	"""The kind's word: "Can build", "Blocked" or "Not possible"."""
	return WORDS[kind] if is_kind(kind) else ""


static func token(kind: int) -> int:
	"""The §2.1 colour token the kind is drawn in; the words never depend on it."""
	return TOKENS[kind] if is_kind(kind) else UiTheme.TOKEN_MUTED


static func line(kind: int, reason: String) -> String:
	"""The whole result in words: "✓ Can build", "! Blocked: <reason>", "X Not possible: <reason>"."""
	if not is_kind(kind):
		return ""
	if kind == KIND_CAN_BUILD or reason.is_empty():
		return "%s %s" % [GLYPHS[kind], WORDS[kind]]
	return "%s %s: %s" % [GLYPHS[kind], WORDS[kind], reason]


static func kind_of(reason_id: int) -> int:
	"""The glyph a canonical reason carries (KIND_CAN_BUILD for REASON_NONE or an unknown id)."""
	return REASON_KINDS[reason_id] if reason_id >= 0 and reason_id < REASON_COUNT else KIND_CAN_BUILD


static func too_narrow() -> String:
	"""BUILD-REQ-002's refusal (X)."""
	return TEXT_TOO_NARROW


static func too_small(type_name: String, needed_cells: int, has_cells: int) -> String:
	"""SET-BUILD-001 §4's area minimum in cells (!)."""
	return FORMAT_TOO_SMALL % [type_name, needed_cells, has_cells]


static func needs(missing: String) -> String:
	"""GDD §5.9 room validity: a missing piece of furniture, e.g. "1 hearth" (!)."""
	return FORMAT_NEEDS % missing


static func no_way_in() -> String:
	"""BUILD-REQ-013 (!)."""
	return TEXT_NO_WAY_IN


static func overlaps(room: String) -> String:
	"""BUILD-REQ-005 (X)."""
	return FORMAT_OVERLAPS % room


static func cannot_dig(what: String) -> String:
	"""ECON-003: water / protected ground / occupied / protected route (X)."""
	return FORMAT_CANNOT_DIG % what


static func too_steep() -> String:
	"""REQ-SET-122's slope rule (X)."""
	return TEXT_TOO_STEEP


static func uneven() -> String:
	"""REQ-SET-122's height-spread rule (X)."""
	return TEXT_UNEVEN


static func wrong_room(item: String, types: String) -> String:
	"""SET-BUILD-001 §5.2, §6: an item in a room type that does not allow it (X)."""
	return FORMAT_WRONG_ROOM % [item, types]


static func needs_wall() -> String:
	"""SET-BUILD-001 §6's wall-behind rule (X)."""
	return TEXT_NEEDS_WALL


static func access_blocked() -> String:
	"""SET-BUILD-001 §6's access rule (!)."""
	return TEXT_ACCESS_BLOCKED


static func locked(milestone: String) -> String:
	"""REQ-UX-015 (!)."""
	return FORMAT_LOCKED % milestone


static func no_level_above() -> String:
	"""BUILD-REQ-016/018 (X)."""
	return TEXT_NO_LEVEL_ABOVE


static func no_level_below() -> String:
	"""BUILD-REQ-016/018 (X)."""
	return TEXT_NO_LEVEL_BELOW


static func cut_off(names: String) -> String:
	"""BUILD-REQ-017 (X)."""
	return FORMAT_CUT_OFF % names


static func outside() -> String:
	"""PROPOSAL (decision 1871): a stroke past the planning area (X)."""
	return TEXT_OUTSIDE


static func shape(words: String) -> String:
	"""PROPOSAL: the planner's shape refusal in its own words (!)."""
	return FORMAT_SHAPE % words


static func narrow_removal(room: String) -> String:
	"""BUILD-REQ-006 (decision 1880 Q3): taking cells out would leave part of `room` one cell wide (X)."""
	return FORMAT_NARROW_REMOVAL % room


static func not_yet(what: String) -> String:
	"""PROPOSAL: a card for a later update, e.g. "furnishing comes in a later update" (!)."""
	return FORMAT_NOT_YET % what


static func nothing_new() -> String:
	"""PROPOSAL: a stroke wholly inside its own planned room (X: dropped, nothing to undo)."""
	return TEXT_NOTHING_NEW


static func nothing_to_erase(type_name: String) -> String:
	"""PROPOSAL (decision 1912): an Erase stroke over no pending cell of `type_name` (X: dropped, nothing to undo)."""
	return FORMAT_NOTHING_TO_ERASE % type_name


static func overlaps_way_down(name: String) -> String:
	"""PROPOSAL (decision 1912): a way down over another on the same level (X)."""
	return FORMAT_WAY_DOWN_CLASH % name


static func needs_floor(name: String) -> String:
	"""PROPOSAL (decision 1912): a way down below the surface with no passage or room under it (!)."""
	return FORMAT_NEEDS_FLOOR % name


static func not_dug() -> String:
	"""PROPOSAL (decision 1921): a piece over cells still waiting for the mole (X)."""
	return TEXT_NOT_DUG


static func not_on_room() -> String:
	"""PROPOSAL (decision 1921): a piece over earth or a way's landing (X)."""
	return TEXT_NOT_ON_ROOM


static func two_rooms() -> String:
	"""PROPOSAL (decision 1921): a piece across two rooms (X)."""
	return TEXT_TWO_ROOMS


static func piece_overlaps(name: String) -> String:
	"""PROPOSAL (decision 1921): a piece over another, `name` (X)."""
	return FORMAT_PIECE_OVERLAPS % name


static func not_between_floors(name: String) -> String:
	"""PROPOSAL (decision 1921): a door or partition without dug floor on both sides and a room on one (X)."""
	return FORMAT_NOT_BETWEEN_FLOORS % name


static func cuts_piece(name: String) -> String:
	"""PROPOSAL (decision 1921): a door or partition through one piece, `name` (X)."""
	return FORMAT_CUTS_PIECE % name


static func on_way_down() -> String:
	"""PROPOSAL (decision 1921): a piece over a way down's cells (X)."""
	return TEXT_ON_WAY_DOWN


static func needs_passage(name: String) -> String:
	"""Decision 2021 P-D1-5 (a): a connector below the Surface with no passage under it (!)."""
	return FORMAT_NEEDS_PASSAGE % name


static func not_in_room(name: String, across: int, along: int) -> String:
	"""Decision 2021 P-D1-12 (a): a connector only partly on a Mound room's floor (X)."""
	return FORMAT_NOT_IN_ROOM % [name, across, along]


static func connects(level_name: String) -> String:
	"""UI-BUILD-012: "Connects to Underground level 2" (the card's line after "✓")."""
	return FORMAT_CONNECTS % level_name
