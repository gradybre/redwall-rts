extends RefCounted
## Who sleeps in which bed: REQ-SET-132's order. Decisions 0210 (the underground revamp's P4) and 0211 (P5: large beds
## for the big residents). Presentation only.
##
## REQ-SET-132 (docs/game_gdd.md §5.9): "When allocating beds, the system shall prefer the resident's current valid
## bed, then the nearest free permitted bed, ties building ID/furniture ID." So, in two passes over the residents in
## index order:
##   1. each keeps its CURRENT bed while that bed still stands and it is permitted there;
##   2. each still without one takes the NEAREST free permitted bed -- by squared distance in u, exactly -- and on a
##      tie the lower bed ID, which is room * PLACES + place (room_fixtures.gd `beds_into`): the lower room (the
##      building), then the lower place (the furniture).
## PERMITTED (decision 0211): a bed sized for the body lying in it. Every resident is of a SIZE by its height:
##   SMALL  up to BIG_BODY_U (1.3 m): the moles, the mice, the squirrels -- a BURROW BED, drawn BED_LENGTH_U (1.6 m)
##          long (demo_props.gd), with a hand's room at its head and foot;
##   BIG    over that, up to LARGE_BED_LENGTH_U: the beaver (1.40 m), the otters (1.49 m) and the badger (2.55 m) -- a
##          LARGE BED, 2.7 m long (the badger's height and a pillow's room, as the burrow bed is the otters' 1.49 m and
##          0.11 m), in a home's alcove dug into a nook (underground_rooms.gd THE BED NOOK);
##   NONE   longer than a large bed: no bed (none in the demo's cast).
## A resident is permitted only beds of its own size -- the big ones' beds are theirs, and a mouse never lies in the
## badger's -- so the matching is exact, and REQ-SET-132's order holds within each size.
## Integer throughout, and nothing here reads a float.

const BED_LENGTH_U: int = 1638
const LARGE_BED_LENGTH_U: int = 2765
const BIG_BODY_U: int = 1331
const NO_BED: int = -1
## A resident's size, and a bed's (room_fixtures.gd BED_SIZE_*).
const SIZE_NONE: int = 0
const SIZE_SMALL: int = 1
const SIZE_BIG: int = 2


static func size_of(height_u: int) -> int:
	"""The size of a body `height_u` tall (see PERMITTED)."""
	if height_u <= BIG_BODY_U:
		return SIZE_SMALL
	return SIZE_BIG if height_u <= LARGE_BED_LENGTH_U else SIZE_NONE


static func fits(height_u: int) -> bool:
	"""Whether a body `height_u` tall is permitted a burrow bed (a SMALL one; see PERMITTED)."""
	return size_of(height_u) == SIZE_SMALL


static func allocate(current: PackedInt32Array, at_u: PackedInt32Array, permitted: PackedByteArray,
		beds: PackedInt32Array, out: PackedInt32Array) -> void:
	"""REQ-SET-132 into `out` (one bed ID or NO_BED per resident): `current` each resident's bed now (NO_BED: none),
	`at_u` its (x, z) in u, `permitted` its size (SIZE_*: the beds it may have), `beds` every bed standing as (id, x, z,
	size) quads in u, ids ascending. A resident permitted none (SIZE_NONE) is given none: no bed is of that size."""
	var residents := current.size()
	out.resize(residents)
	out.fill(NO_BED)
	for i in residents:
		if permitted[i] != SIZE_NONE and current[i] != NO_BED and _size_of_bed(beds, current[i]) == permitted[i] \
				and not out.has(current[i]):
			out[i] = current[i]
	for i in residents:
		if out[i] == NO_BED:
			out[i] = nearest_free(beds, out, Vector2i(at_u[2 * i], at_u[2 * i + 1]), permitted[i])


static func _size_of_bed(beds: PackedInt32Array, id: int) -> int:
	"""The size of bed `id` among `beds` (SIZE_NONE: it does not stand)."""
	for k in beds.size() / 4:
		if beds[4 * k] == id:
			return beds[4 * k + 3]
	return SIZE_NONE


static func nearest_free(beds: PackedInt32Array, taken: PackedInt32Array, at: Vector2i, size: int) -> int:
	"""The bed of `size` nearest `at` (u) that is not in `taken`: squared distance, exactly, the lower ID on a tie
	(`beds` come in ID order, so the first found wins it). NO_BED when every such bed is taken."""
	var best := NO_BED
	var best_d := 0
	for k in beds.size() / 4:
		var id := beds[4 * k]
		if beds[4 * k + 3] != size or taken.has(id):
			continue
		var dx := beds[4 * k + 1] - at.x
		var dz := beds[4 * k + 2] - at.y
		var d := dx * dx + dz * dz
		if best == NO_BED or d < best_d:
			best = id
			best_d = d
	return best
