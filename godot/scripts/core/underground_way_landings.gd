extends RefCounted
## Decision 2052 §2.3 (slice D2; Brendan, 2026-10-20, "Approve, start phase 1"): WHAT THE BUILD PANEL READS OF THE
## REAL WAY DOWN, from the entry's origin and the flight's own geometry. Two readers the batch binds
## (`build_batch.gd`): `landings_into`, the cells where the way opens onto the level below (`bind_landings`, decision
## 2021: built, or confirmed and being built, P-D1-7 (a)), and `shape_into`, the way standing on its level as an
## (x, z, family, turn) quad (`bind_way_host`). Stateless and cold; the host (phase 2) calls them with the finished or
## running entry's origin, the Sites domain's datum and the mounted layout. The game's panel binds them in slice G
## (ruling 1871); the demo at D2's phase 3.
##
## THE FRAME. `flight_geometry.gd`: the stair top's walking surface is the origin, the flight descends along -Z, the
## slot is two cells wide (x in [-1024, 1024] from the origin) and row r spans z in [-1024(r + 1), -1024r]. The panel's
## 1 m cells are whole Sites quanta from the datum (SET-BUILD-001 §3). So the Stair-head stands at turn 0 (descending
## north, decision 2022), its north-west cell the last row's west cell, and its foot is that last row: the same cells
## D1's `build_connector_families.gd` gives a Stair-head at that anchor (a test holds the two equal).
##
## A layout whose last row's floor is not one level down (the M2 interim, 2,048 u) reaches no level: it lands nowhere.
## Only the surface's real way is read (P-2052-4 (b): the other families stay the proof of concept's).

const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const CELL_U: int = Flight.QUANTUM
const SURFACE: int = 0
const TURN: int = 0 # Rotation 0 only (decision 2041 P-DF-6 (a)).


static func reaches_level(layout: int) -> bool:
	"""Whether the layout's last row's floor lies one whole level below its top (M5 does; M2 does not)."""
	if not Flight.layout_valid(layout): return false
	var last: int = Flight.layout_row_count(layout) - 1
	return Flight.layout_floor_depth(layout, last) * CELL_U == Flight.LEVEL_DROP


static func anchor_of(layout: int, origin: Vector3i, datum: Vector3i) -> Vector2i:
	"""The way's north-west cell from the datum: the slot's west cell on its last row."""
	var rows: int = Flight.layout_row_count(layout)
	return Vector2i(_floor_div(origin.x - Flight.HALF_WIDTH - datum.x, CELL_U),
		_floor_div(origin.z - rows * CELL_U - datum.z, CELL_U))


static func landings_into(layout: int, level: int, origin: Vector3i, datum: Vector3i, out: PackedInt32Array) -> bool:
	"""The cells (pairs, by z then x) where the way opens onto `level`: its last row, on the level below the surface
	only. False, `out` untouched, when the layout reaches no level or it is another level."""
	if level != SURFACE + 1 or not reaches_level(layout): return false
	var anchor: Vector2i = anchor_of(layout, origin, datum)
	for across: int in Flight.WIDTH_CUBES:
		out.append_array(PackedInt32Array([anchor.x + across, anchor.y]))
	return true


static func shape_into(layout: int, level: int, origin: Vector3i, datum: Vector3i, out: PackedInt32Array) -> bool:
	"""The way standing on `level` as (anchor x, anchor z, family, turn): the earth/timber Stair-head on the surface.
	False, `out` untouched, on any other level or an invalid layout."""
	if level != SURFACE or not Flight.layout_valid(layout): return false
	var anchor: Vector2i = anchor_of(layout, origin, datum)
	out.append_array(PackedInt32Array([anchor.x, anchor.y, Connectors.EARTH_TIMBER, TURN]))
	return true


static func _floor_div(a: int, b: int) -> int:
	"""Integer division rounded toward negative infinity (cells left of or below the datum)."""
	@warning_ignore("integer_division") var q: int = a / b
	return q - 1 if a % b != 0 and (a < 0) != (b < 0) else q
