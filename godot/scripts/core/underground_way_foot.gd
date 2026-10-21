extends RefCounted
## Decision 2054 (slice D2 phase 2): THE FOOT OF THE FINISHED M5 FLIGHT, derived from the entry's own record and the
## live Locations, so the host binds the way in when the entry finishes and again after every load with no save field
## (decision 2052 §2.1, E1). Stateless and cold; it reads the entry runtime's public state only (`step`, `origin`,
## `crew`) and the stair path's `classify` (M5's files are not edited).
##
## THE FOOT (the 2054 probe, at the flight's finish, tick 92,559): F'(5) stands on level 1's floor (y origin - 5,120),
## 850 u from the run-out's end wall on the slot's centre line; its surveyed air is one body facing down the flight
## (x -485..479, z -521..412, 930 high), it has no ground join (decision 2052 finding 4) and no all-yaw row can turn
## on it beside the sill. The run-out is the slot's last 1,536 u (ADR 1209 D2: `RUN_OUT`), two cells wide, open from
## the floor up. So, in that floor air, measured from the end wall on the slot's centre line (x, z) (the 2054 layout,
## each point held by a clearance test against the walls and the sill):
## - the hub, where the all-yaw ground row 42 (x/z +-712) turns between the walls and the sill: (0, 768);
## - the parking, joined to the hub on the bound retreat row's family (45 and 49, facing up the flight): (0, 948);
## - the store and its grip stand, the stand 576 u east of the stock (`Grip.stock_offset`), where both carry rows'
##   held loads clear the end wall (32's reach 714 u), so the one CARRY span from the hub runs down the flight to the
##   stand's line and then -X into it on the grip heading (P-2091-7 (a)): store (-832, 714), stand (-256, 714);
## - the spoil pile, east, clear of the stair: (600, 1088).
## The rows are content 12's claw rows (decision 1972): the wall rows 67 (yaw 0, down the flight: the end wall), 68
## and 70 (the side walls), their READY forward 43/44/46 and backward 47/48/50 rows, the all-yaw ground WALK 42, the
## retreat row 49 the room contacts bind, and the grip and carry rows 30-37 (decision 1981; no new motion).

const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const Landings := preload("res://scripts/core/underground_way_landings.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const WayIn := preload("res://scripts/core/underground_way_in.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const LAYOUT: int = Flight.LAYOUT_M5
const LEVEL: int = 1
const REFUSE_NOT_DONE: StringName = &"WAY_FOOT_NOT_DONE"
## The finished flight's bottom stop F'(5) is not live where the flight's geometry puts it.
const REFUSE_NO_STAIR: StringName = &"WAY_FOOT_NO_STAIR"
## The 2054 layout, in u from the end wall on the slot's centre line, on F''s floor.
## F'(5): FLOOR_WALK_OFF beyond the last sill's far edge, which is RUN_OUT from the end wall.
const STAIR: Vector2i = Vector2i(0, Flight.RUN_OUT - Flight.FLOOR_WALK_OFF)
const HUB: Vector2i = Vector2i(0, 768)
const PARKING: Vector2i = Vector2i(0, 948)
const STORE: Vector2i = Vector2i(-832, 714)
const PILE: Vector2i = Vector2i(600, 1088)
## The run-out's floor air: the slot's width, RUN_OUT long, one cube high.
const AIR_HEIGHT: int = Flight.QUANTUM
const CLAW_CONTENT: int = 12
const GROUND_ROW: int = 42
const RETREAT_ROW: int = 49
const WALL_ROWS: PackedInt32Array = [67, 68, 70]
const FORWARD_ROWS: PackedInt32Array = [43, 44, 46]
const BACKWARD_ROWS: PackedInt32Array = [47, 48, 50]
const HUB_ROWS: PackedInt32Array = [42, 43, 45, 47, 49]
const PARKING_ROWS: PackedInt32Array = [45, 49]
const STORE_ROWS: PackedInt32Array = [34, 36]
const STAND_ROWS: PackedInt32Array = [30, 31, 32, 34, 36, 37]


static func end_wall(origin: Vector3i) -> Vector3i:
	"""The run-out's end wall on the slot's centre line, on level 1's floor (the flight's own geometry)."""
	return origin + Vector3i(0, -Flight.LEVEL_DROP, Flight.layout_end_wall_z(LAYOUT))


static func at(origin: Vector3i, offset: Vector2i) -> Vector3i:
	"""A point of the 2054 layout: `offset` (x, z) from the end wall on the centre line, on the floor."""
	return end_wall(origin) + Vector3i(offset.x, 0, offset.y)


static func stair_of(locations: Locations, origin: Vector3i) -> Vector2i:
	"""The live bottom stop F'(5): the one Location at the flight's last walk-off point that the stair path files as
	F' of the last landing; NULL_REF when there is none."""
	var expected: Vector3i = at(origin, STAIR)
	if StairPath.classify(expected - origin) != Vector2i(StairPath.KIND_FP, StairPath.MODULES): return NULL_REF
	var stride: int = locations._capacity
	for row: int in stride:
		if locations._live.present[row] != 1: continue
		if Vector3i(locations._get32(locations._live, Locations.X, row), locations._get32(locations._live, Locations.Y,
				row), locations._get32(locations._live, Locations.Z, row)) != expected: continue
		return Vector2i(row, locations._get32(locations._live, Locations.GENERATION, row))
	return NULL_REF


static func derive_into(entry: EntryRuntime, locations: Locations, content: int, out: WayIn.Foot) -> StringName:
	"""The foot of the finished flight (see the header); refused while the entry is not done or F'(5) is not live."""
	if entry == null or locations == null or out == null or entry.step() != EntryRuntime.STEP_DONE:
		return REFUSE_NOT_DONE
	var origin: Vector3i = entry.origin()
	out.stair = stair_of(locations, origin)
	if out.stair == NULL_REF: return REFUSE_NO_STAIR
	out.level = LEVEL; out.content = content; out.travel = RETREAT_ROW; out.ground = GROUND_ROW
	out.wall_rows = WALL_ROWS; out.forward_rows = FORWARD_ROWS; out.backward_rows = BACKWARD_ROWS
	out.hub_point = at(origin, HUB); out.hub_rows = HUB_ROWS
	out.parking_point = at(origin, PARKING); out.parking_rows = PARKING_ROWS
	out.store_point = at(origin, STORE); out.store_rows = STORE_ROWS; out.stand_rows = STAND_ROWS
	out.pile_point = at(origin, PILE)
	out.join_containers = false
	out.staging = entry.crew().output if entry.crew() != null else NULL_REF
	var wall: Vector3i = end_wall(origin)
	out.open = PackedInt32Array([wall.x - Flight.HALF_WIDTH, wall.y, wall.z, wall.x + Flight.HALF_WIDTH,
		wall.y + AIR_HEIGHT, wall.z + Flight.RUN_OUT])
	return &""


static func landings_into(entry: EntryRuntime, level: int, datum: Vector3i, out: PackedInt32Array) -> bool:
	"""Decision 2052 §2.3 (P-D1-9): the cells where the real way opens onto `level`, while the entry is confirmed
	(P-D1-7 (a): a confirmed way counts as a way in) and once it is done; false, `out` untouched, otherwise."""
	if not _confirmed(entry): return false
	return Landings.landings_into(LAYOUT, level, entry.origin(), datum, out)


static func shapes_into(entry: EntryRuntime, level: int, datum: Vector3i, out: PackedInt32Array) -> bool:
	"""The real way standing on `level` as (x, z, family, turn), on the same terms as `landings_into`."""
	if not _confirmed(entry): return false
	return Landings.shape_into(LAYOUT, level, entry.origin(), datum, out)


static func _confirmed(entry: EntryRuntime) -> bool:
	"""The entry's Placement is confirmed: being built, or done."""
	return entry != null and entry.step() >= EntryRuntime.STEP_CONFIRMED
