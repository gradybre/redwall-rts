extends RefCounted
## Who sleeps in which bed: REQ-SET-132's order. Decision 0210 (the underground revamp's P4). Presentation only.
##
## REQ-SET-132 (docs/game_gdd.md §5.9): "When allocating beds, the system shall prefer the resident's current valid
## bed, then the nearest free permitted bed, ties building ID/furniture ID." So, in two passes over the residents in
## index order:
##   1. each keeps its CURRENT bed while that bed still stands and it is permitted there;
##   2. each still without one takes the NEAREST free permitted bed -- by squared distance in u, exactly -- and on a
##      tie the lower bed ID, which is room * PLACES + place (room_fixtures.gd `beds_into`): the lower room (the
##      building), then the lower place (the furniture).
## PERMITTED: the bed is long enough for the body lying in it. The demo's burrow bed is drawn BED_LENGTH_U long
## (demo_props.gd), so everybeast up to the otters (1.49 m) fits and the badger (2.55 m) does not: it sleeps on the
## hall's floor (REQ-SET-133).
## Integer throughout, and nothing here reads a float.

const BED_LENGTH_U: int = 1638
const NO_BED: int = -1


static func fits(height_u: int) -> bool:
	"""Whether a body `height_u` tall is permitted a burrow bed (see PERMITTED)."""
	return height_u <= BED_LENGTH_U


static func allocate(current: PackedInt32Array, at_u: PackedInt32Array, permitted: PackedByteArray,
		beds: PackedInt32Array, out: PackedInt32Array) -> void:
	"""REQ-SET-132 into `out` (one bed ID or NO_BED per resident): `current` each resident's bed now (NO_BED: none),
	`at_u` its (x, z) in u, `permitted` 1 where it may have a bed, `beds` every bed standing as (id, x, z) triples in
	u, ids ascending."""
	var residents := current.size()
	out.resize(residents)
	out.fill(NO_BED)
	for i in residents:
		if permitted[i] == 1 and current[i] != NO_BED and _stands(beds, current[i]) and not out.has(current[i]):
			out[i] = current[i]
	for i in residents:
		if permitted[i] == 1 and out[i] == NO_BED:
			out[i] = nearest_free(beds, out, Vector2i(at_u[2 * i], at_u[2 * i + 1]))


static func _stands(beds: PackedInt32Array, id: int) -> bool:
	"""Whether bed `id` is among `beds`."""
	for k in beds.size() / 3:
		if beds[3 * k] == id:
			return true
	return false


static func nearest_free(beds: PackedInt32Array, taken: PackedInt32Array, at: Vector2i) -> int:
	"""The bed nearest `at` (u) that is not in `taken`: squared distance, exactly, the lower ID on a tie (`beds` come
	in ID order, so the first found wins it). NO_BED when every bed is taken."""
	var best := NO_BED
	var best_d := 0
	for k in beds.size() / 3:
		var id := beds[3 * k]
		if taken.has(id):
			continue
		var dx := beds[3 * k + 1] - at.x
		var dz := beds[3 * k + 2] - at.y
		var d := dx * dx + dz * dz
		if best == NO_BED or d < best_d:
			best = id
			best_d = d
	return best
