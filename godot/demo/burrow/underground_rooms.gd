extends RefCounted
## ROOMS: burrow homes and root cellars, dug as their own structures on the tunnel network. Decision 0209
## (the underground revamp's P3; design docs/design/underground_revamp.md §3 "Room templates", §4 and §8 P3),
## replacing burrow_chambers.gd's 3 x 3 m rooms bolted 2 m off a tunnel. Presentation only: nothing here
## writes into the simulation -- the HUD's Beds are the simulation's, and no food is stored here.
##
## ---------------------------------------------------------------------------------------
## TEMPLATES (demo values; the paid lattice stays ECON-001's 1 m cube):
##   template     shape                        floor quanta  quanta  sockets  its own way in
##   Burrow home  round, 4 m across (2 m radius)      12          24      3        a round FRONT DOOR in a turfed mound
##   Root cellar  barrel vault, 3 m x 4 m             12          24      2        a HATCH over steps
## A room is HIGH_QUANTA quanta high over its floor quanta, and drawn to Rules.ROOM_CROWN_U (2.75 m) --
## HEADROOM: the badger (2.55 m) stands upright in it. Its floor is level 1's (Rules.BORE_FLOOR_DEPTH_U), so
## its passages meet it on the level and its crown rises 1.5 m over the ground: the turfed MOUND over it is
## the room itself (design §3). The walls bow out BULGE_PERMILLE at the springline, as a bore's do.
##
## FRAME. A room stands at a centre (u) turned `turns` quarter turns (rotate_u). In its own frame its door
## (or hatch) is at -Z, and its sockets and fixtures are where the template puts them. Every room carries
## its LEVEL (MOVE-REQ-013); only Rules.BUILDABLE_LEVEL is dug (P6 adds level 2).
##
## ON THE NETWORK (underground_graph.gd `add_room`) a room is one PIECE, laid in the job list like a tunnel:
##   * a MOUTH node on the surface (mouth kind DOOR or HATCH) and its RAMP down (a WIDE bore, so the badger
##     comes in by the front door) to the DOOR node in the room's wall;
##   * the BODY: a ROOM segment from the door node to the room's MIDDLE node, whose dig timeline is the room's
##     quanta (24, cell by cell out from the door; `cell_point_u`), worked by a crew at ROOM_FACES faces;
##   * a WALK: a ROOM segment from the middle to each SOCKET node in its wall, opened with the body.
## A passage joins a room only at a free socket, leaving it straight out (tunnel_rules.gd SOCKET_STRAIGHT_U).
##
## WHERE ONE MAY GO (`refusal`, integer tests on the void -- the room's floor extent bowed out -- its MOUND
## (the void and SKIRT_U of turf) and its door ramp's HOOD):
##   LEVEL the first level only; FULL MAX_ROOMS rooms; NETWORK_FULL the network's rows; OUT_OF_BOUNDS the
##   village; UNDER_WATER the stream, the pond and their no-dig band (half a bore, as tunnels); OVER_CROPS the
##   crop beds; UNDER_BUILDING the buildings and the well; NEAR_ROOM 1 m of earth from every other room;
##   NEAR_TUNNEL 1 m of earth from every tunnel (join one at a socket instead); SURFACE_BLOCKED the mound, the
##   hood and the door clear of trees, heaps, props, work spots and mouths.
##
## THE CELLAR API (the pantry: demo/farm/farm_cellars.gd): `cellars(graph)` lists every dug root cellar with a store
## in it as {"id": Vector2i(slot, generation), "position": Vector3 (its hatch, on the ground), "capacity_u": int,
## "spoilage_permille": int} -- the shape burrow_chambers.gd published -- and `revision` bumps on any change. Since
## the fit-out (decision 0210) the capacity is the cellar's racks' and the spoilage follows the cool rule
## (room_fixtures.gd); the shape is unchanged.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const TEMPLATE_NONE: int = 0
const TEMPLATE_HOME: int = 1
const TEMPLATE_CELLAR: int = 2
const NAMES: Array[String] = ["", "Burrow home", "Root cellar"]
const SHAPE_ROUND: int = 0
const SHAPE_VAULT: int = 1
const SHAPE: Array[int] = [SHAPE_ROUND, SHAPE_ROUND, SHAPE_VAULT]
## A round room's floor radius (both), a vault's floor half-width (X) and half-length (Z), in u.
const HALF_X_U: Array[int] = [0, 2048, 1536]
const HALF_Z_U: Array[int] = [0, 2048, 2048]
const FLOOR_QUANTA: Array[int] = [0, 12, 12]
const HIGH_QUANTA: int = 2
## A room's crew works three faces side by side (design §8 P3).
const ROOM_FACES: int = 3
const MAX_ROOMS: int = 8
const MAX_SOCKETS: int = 3
const BULGE_PERMILLE: int = 1100
## The mound keeps this much turf beyond the void; the door ramp's hood is as wide as the ramp's floor.
const SKIRT_U: int = 512
const HOOD_HALF_U: int = 1024
## The door (hatch) and the sockets in the room's own frame (u; the door at -Z).
const DOOR_LOCAL: Array[Vector2i] = [Vector2i.ZERO, Vector2i(0, -2048), Vector2i(0, -2048)]
const SOCKETS_LOCAL: Array = [[], [Vector2i(2048, 0), Vector2i(0, 2048), Vector2i(-2048, 0)],
	[Vector2i(0, 2048), Vector2i(1536, 0)]]
## The floor cells each quantum is cut in, in the room's frame, nearest the door first (so the dig grows out
## from it): a home's four inner and eight outer cells, a vault's 3 x 4 grid.
const CELLS_LOCAL: Array = [[],
	[Vector2i(-588, -1419), Vector2i(588, -1419), Vector2i(-543, -543), Vector2i(543, -543), Vector2i(-1419, -588),
		Vector2i(1419, -588), Vector2i(-543, 543), Vector2i(543, 543), Vector2i(-1419, 588), Vector2i(1419, 588),
		Vector2i(-588, 1419), Vector2i(588, 1419)],
	[Vector2i(-1024, -1536), Vector2i(0, -1536), Vector2i(1024, -1536), Vector2i(-1024, -512), Vector2i(0, -512),
		Vector2i(1024, -512), Vector2i(-1024, 512), Vector2i(0, 512), Vector2i(1024, 512), Vector2i(-1024, 1536),
		Vector2i(0, 1536), Vector2i(1024, 1536)]]
## FIXTURES: the fit-out's PLACES (decision 0210, P4; the places P3 left, decision 0209), per template, as
## (kind, x, z, facing x, facing z) in the room's frame: where a fixture of that kind stands and the way its front
## faces. A place holds only its own kind, so the palette's fixtures go on these places as on sockets
## (room_fixtures.gd; design §4 "Fit-out"): a home's three bed alcoves, its hearth, table, rag rug, lantern and
## hanging stores; a cellar's two shelves, pantry rack, root bin and hanging stores.
const FIX_BED: int = 0
const FIX_HEARTH: int = 1
const FIX_TABLE: int = 2
const FIX_SHELF: int = 3
const FIX_RUG: int = 4
const FIX_RACK: int = 5
const FIX_BIN: int = 6
const FIX_HANGING: int = 7
const FIX_LANTERN: int = 8
const FIXTURE_KINDS: int = 9
const FIXTURE_NAMES: Array[String] = ["bed", "hearth", "table and stools", "shelf", "rag rug", "pantry rack", "root bin",
	"hanging stores", "lantern"]
const FIXTURE_FIELDS: int = 5
const MAX_PLACES: int = 8
const FIXTURES: Array = [[],
	[FIX_BED, 1273, 1273, -724, -724, FIX_BED, -1273, 1273, 724, -724, FIX_BED, -1273, -1273, 724, 724,
		FIX_HEARTH, 1250, -1250, -724, 724, FIX_TABLE, 640, -640, 724, 724, FIX_RUG, 300, -300, 724, 724,
		FIX_LANTERN, -700, 1925, 342, -962, FIX_HANGING, 1560, -330, -1024, 0],
	[FIX_SHELF, -1080, -900, 1024, 0, FIX_SHELF, -1080, 900, 1024, 0, FIX_RACK, 1000, -1300, -1024, 0,
		FIX_BIN, 1000, 1300, -1024, 0, FIX_HANGING, -520, 0, 1024, 0]]
## THE WALL LANTERN each room is dug with (P3's, decision 0209): not a fixture -- the room's own light by its
## door, one of the pooled lights -- as (x, z, facing x, facing z) in the room's frame.
const WALL_LANTERN: Array = [[], [1040, -1800, -512, 887], [-1460, 0, 1024, 0]]
## THE BED ALCOVES: a home's wall bows out ALCOVE_U more round each bed (room_view.gd), as recesses the
## beds stand in.
const ALCOVE_U: int = 460
## The GDD's starter dormitory holds 12 beds in 40 tiles: a home's 12 floor quanta hold 12 x 12 / 40 = 3 (its
## three bed alcoves; the beds themselves are fixtures now, room_fixtures.gd).
const DORMITORY_BEDS: int = 12
const DORMITORY_TILES: int = 40
const BEDS_PER_HOME: int = 12 * DORMITORY_BEDS / DORMITORY_TILES
## A root cellar: the GDD's cellar store factor when it is COOL, the pantry's when it is not (§5.8; the cool rule
## is room_fixtures.gd's). Its capacity is its racks' (room_fixtures.gd CAPACITY_U), not a flat figure any more.
const CELLAR_SPOILAGE_PERMILLE: int = 350
const WARM_CELLAR_SPOILAGE_PERMILLE: int = 750

const REFUSE_NONE: int = 0
const REFUSE_FULL: int = 1
const REFUSE_NETWORK_FULL: int = 2
const REFUSE_LEVEL: int = 3
const REFUSE_OUT_OF_BOUNDS: int = 4
const REFUSE_UNDER_WATER: int = 5
const REFUSE_OVER_CROPS: int = 6
const REFUSE_UNDER_BUILDING: int = 7
const REFUSE_NEAR_ROOM: int = 8
const REFUSE_NEAR_TUNNEL: int = 9
const REFUSE_SURFACE_BLOCKED: int = 10
const REASONS: Array[String] = [
	"",
	"no more rooms can be dug in this demo (8 at most)",
	"the tunnel network is full in this demo",
	"only the first level can be dug in this demo (the second comes later)",
	"that is too near the edge of the village",
	"a room cannot be dug under the stream or the pond, or the no-dig band beside them",
	"a room cannot be dug under the crop beds",
	"a room cannot be dug under a building or the well",
	"too near another room: keep 1 m of earth between them",
	"too near a tunnel: keep 1 m of earth from it, or join it at a socket",
	"its mound or its door would stand on a tree, a heap, a prop or a work spot",
]


## What a room must keep clear of, gathered by the tool (tunnel_control.gd) once per placement: the village's
## bounds, obstacle circles (x, radius, z), work spots and mouths (likewise), buildings' footprints (likewise),
## the crop beds as squares (x, half-width, z), all in u, and the water query (village_water.gd
## `crosses_water`: `(a: Vector2i, b: Vector2i, clearance_u: int) -> bool`; unset: no water).
class Site extends RefCounted:
	var bounds_u: Rect2i = Rect2i(-65536, -65536, 131072, 131072)
	var circles_u: PackedInt32Array = PackedInt32Array()
	var spots_u: PackedInt32Array = PackedInt32Array()
	var under_u: PackedInt32Array = PackedInt32Array()
	var beds_u: PackedInt32Array = PackedInt32Array()
	var water: Callable = Callable()


var template: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var level: PackedByteArray = PackedByteArray()
var turns: PackedByteArray = PackedByteArray()
## (x, z) centre in u, per room.
var centre_u: PackedInt32Array = PackedInt32Array()
## Its rows in the network (underground_graph.gd): its piece, mouth row, middle, door and socket nodes, and
## its ramp, body and walk segments (MAX_SOCKETS sockets and walks a room; -1 none).
var piece: PackedInt32Array = PackedInt32Array()
var mouth: PackedInt32Array = PackedInt32Array()
var middle: PackedInt32Array = PackedInt32Array()
var door: PackedInt32Array = PackedInt32Array()
var ramp: PackedInt32Array = PackedInt32Array()
var body: PackedInt32Array = PackedInt32Array()
var socket_node: PackedInt32Array = PackedInt32Array()
var walk: PackedInt32Array = PackedInt32Array()
## Bumped on any change.
var revision: int = 0


func _init() -> void:
	"""Size every column once."""
	for column: PackedByteArray in [template, level, turns]:
		column.resize(MAX_ROOMS)
	for column: PackedInt32Array in [generation, piece, mouth, middle, door, ramp, body]:
		column.resize(MAX_ROOMS)
	centre_u.resize(2 * MAX_ROOMS)
	socket_node.resize(MAX_ROOMS * MAX_SOCKETS)
	walk.resize(MAX_ROOMS * MAX_SOCKETS)
	for column: PackedInt32Array in [piece, mouth, middle, door, ramp, body, socket_node, walk]:
		column.fill(-1)


static func reason_text(code: int) -> String:
	"""The words for a refusal (REFUSE_*)."""
	return REASONS[code]


# --- the templates (static) -----------------------------------------------------------------

static func total_quanta(kind: int) -> int:
	"""The quanta a room of template `kind` cuts: its floor quanta, HIGH_QUANTA high (24 for both)."""
	return FLOOR_QUANTA[kind] * HIGH_QUANTA


static func socket_count(kind: int) -> int:
	"""How many sockets template `kind` has in its wall."""
	return (SOCKETS_LOCAL[kind] as Array).size()


static func rotate_u(v: Vector2i, quarter_turns: int) -> Vector2i:
	"""`v` (x, z) turned `quarter_turns` quarter turns, exactly: one turn takes +X to +Z."""
	match posmod(quarter_turns, 4):
		1:
			return Vector2i(-v.y, v.x)
		2:
			return Vector2i(-v.x, -v.y)
		3:
			return Vector2i(v.y, -v.x)
	return v


static func door_at(kind: int, at: Vector2i, quarter_turns: int) -> Vector2i:
	"""Where a room of `kind` centred at `at`, turned so, has its door's foot in its wall (u)."""
	return at + rotate_u(DOOR_LOCAL[kind], quarter_turns)


static func mouth_at(kind: int, at: Vector2i, quarter_turns: int) -> Vector2i:
	"""Where its door (or hatch) opens on the surface: a ramp's run straight out from its door's foot (u)."""
	return door_at(kind, at, quarter_turns) + rotate_u(Vector2i(0, -Rules.RAMP_RUN_U), quarter_turns)


static func socket_at(kind: int, at: Vector2i, quarter_turns: int, k: int) -> Vector2i:
	"""Where socket `k` of a room of `kind` centred at `at`, turned so, stands in its wall (u)."""
	return at + rotate_u((SOCKETS_LOCAL[kind] as Array)[k], quarter_turns)


static func outward(kind: int, quarter_turns: int, k: int) -> Vector2i:
	"""The way straight out of socket `k` (any length): from the room's middle through the socket."""
	return rotate_u((SOCKETS_LOCAL[kind] as Array)[k], quarter_turns)


static func cell_local(kind: int, k: int) -> Vector2i:
	"""The floor cell quantum `k` of the room's timeline is cut in, in its own frame (HIGH_QUANTA a cell)."""
	var cells: Array = CELLS_LOCAL[kind]
	return cells[clampi(k / HIGH_QUANTA, 0, cells.size() - 1)]


static func void_half(kind: int) -> Vector2i:
	"""The void's half extents in its own frame (u): the floor bowed out BULGE_PERMILLE -- all round a round
	room; across a vault, whose end walls stand straight."""
	var x := HALF_X_U[kind] * BULGE_PERMILLE / Rules.PERMILLE
	var z := x if SHAPE[kind] == SHAPE_ROUND else HALF_Z_U[kind]
	return Vector2i(x, z)


static func fixture_count(kind: int) -> int:
	"""How many fixture places template `kind` has."""
	return (FIXTURES[kind] as Array).size() / FIXTURE_FIELDS


static func fixture_field(kind: int, f: int, field: int) -> int:
	"""Field `field` (0 kind, 1 x, 2 z, 3 facing x, 4 facing z) of fixture place `f` of template `kind`."""
	return (FIXTURES[kind] as Array)[f * FIXTURE_FIELDS + field]


# --- the void's distances (static, exact integers) -----------------------------------------

static func gap_u(kind: int, at: Vector2i, quarter_turns: int, p: Vector2i) -> int:
	"""How far point `p` lies outside the void of a room of `kind` at `at`, turned so (u; 0 inside it)."""
	var half := void_half(kind)
	var d := p - at
	if SHAPE[kind] == SHAPE_ROUND:
		return maxi(Rules.isqrt(d.x * d.x + d.y * d.y) - half.x, 0)
	var local := rotate_u(d, -quarter_turns)
	return _box_gap(local, half)


static func _box_gap(local: Vector2i, half: Vector2i) -> int:
	"""How far a point in a box's own frame lies outside it (box centred on the origin, `half` extents)."""
	var dx := maxi(absi(local.x) - half.x, 0)
	var dz := maxi(absi(local.y) - half.y, 0)
	return Rules.isqrt(dx * dx + dz * dz)


static func leg_gap_u(kind: int, at: Vector2i, quarter_turns: int, a: Vector2i, b: Vector2i) -> int:
	"""How far leg a-b stays outside the void of a room of `kind` at `at`, turned so (u; 0 when it enters)."""
	var half := void_half(kind)
	if SHAPE[kind] == SHAPE_ROUND:
		return maxi(Rules.point_leg_u(at, a, b) - half.x, 0)
	var la := rotate_u(a - at, -quarter_turns)
	var lb := rotate_u(b - at, -quarter_turns)
	if _box_gap(la, half) == 0 or _box_gap(lb, half) == 0 or _leg_crosses_box(la, lb, half):
		return 0
	var best := mini(_box_gap(la, half), _box_gap(lb, half))
	for corner: Vector2i in [half, Vector2i(-half.x, half.y), -half, Vector2i(half.x, -half.y)]:
		best = mini(best, Rules.point_leg_u(corner, la, lb))
	return best


static func _leg_crosses_box(a: Vector2i, b: Vector2i, half: Vector2i) -> bool:
	"""Whether leg a-b (in the box's frame) crosses any of its four sides."""
	var corners: Array[Vector2i] = [half, Vector2i(-half.x, half.y), -half, Vector2i(half.x, -half.y)]
	for k in 4:
		if Rules.legs_cross(a, b, corners[k], corners[(k + 1) % 4]):
			return true
	return false


static func legs_gap_u(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> int:
	"""How far apart legs a-b and c-d stay (u; 0 when they cross)."""
	if Rules.legs_cross(a, b, c, d):
		return 0
	return mini(mini(Rules.point_leg_u(a, c, d), Rules.point_leg_u(b, c, d)),
		mini(Rules.point_leg_u(c, a, b), Rules.point_leg_u(d, a, b)))


static func voids_gap_u(kind_a: int, at_a: Vector2i, turns_a: int, kind_b: int, at_b: Vector2i, turns_b: int) -> int:
	"""How much earth stands between two rooms' voids (u; 0 when they meet): exact for round and round, a round
	room and a vault, and two vaults (quarter turns keep a vault's sides on the axes)."""
	if SHAPE[kind_a] == SHAPE_ROUND:
		return maxi(gap_u(kind_b, at_b, turns_b, at_a) - void_half(kind_a).x, 0)
	if SHAPE[kind_b] == SHAPE_ROUND:
		return maxi(gap_u(kind_a, at_a, turns_a, at_b) - void_half(kind_b).x, 0)
	var ha := _world_half(kind_a, turns_a)
	var hb := _world_half(kind_b, turns_b)
	var dx := maxi(absi(at_a.x - at_b.x) - ha.x - hb.x, 0)
	var dz := maxi(absi(at_a.y - at_b.y) - ha.y - hb.y, 0)
	return Rules.isqrt(dx * dx + dz * dz)


static func _world_half(kind: int, quarter_turns: int) -> Vector2i:
	"""A void's half extents along the world's axes, turned so."""
	var half := void_half(kind)
	return half if posmod(quarter_turns, 2) == 0 else Vector2i(half.y, half.x)


static func world_box(kind: int, at: Vector2i, quarter_turns: int, grow: int) -> Rect2i:
	"""The void's box on the world's axes, grown by `grow` (u)."""
	var half := _world_half(kind, quarter_turns) + Vector2i(grow, grow)
	return Rect2i(at - half, 2 * half)


# --- a room's rows ------------------------------------------------------------------------

func is_room(r: int) -> bool:
	"""Whether row `r` holds a room."""
	return r >= 0 and r < MAX_ROOMS and template[r] != TEMPLATE_NONE


func is_ref(r: int, gen: int) -> bool:
	"""Whether (r, gen) names a room that still stands (EntityRef validation)."""
	return is_room(r) and generation[r] == gen


func has_free_row() -> bool:
	"""Whether another room may be laid."""
	return template.has(TEMPLATE_NONE)


func take(kind: int, at: Vector2i, quarter_turns: int, room_level: int) -> int:
	"""A free row for a room of `kind` at `at`, turned so, on `room_level` (-1: none free)."""
	var r := template.find(TEMPLATE_NONE)
	if r < 0:
		return -1
	template[r] = kind
	level[r] = room_level
	turns[r] = posmod(quarter_turns, 4)
	centre_u[2 * r] = at.x
	centre_u[2 * r + 1] = at.y
	for k in MAX_SOCKETS:
		socket_node[r * MAX_SOCKETS + k] = -1
		walk[r * MAX_SOCKETS + k] = -1
	revision += 1
	return r


func release(r: int) -> void:
	"""Row `r`'s room is gone (never dug): free the row and retire its generation."""
	template[r] = TEMPLATE_NONE
	generation[r] += 1
	for column: PackedInt32Array in [piece, mouth, middle, door, ramp, body]:
		column[r] = -1
	revision += 1


func centre(r: int) -> Vector2i:
	"""Room `r`'s centre (u)."""
	return Vector2i(centre_u[2 * r], centre_u[2 * r + 1])


func centre_m(r: int) -> Vector2:
	"""Room `r`'s centre in metres (x, z), for drawing."""
	return Vector2(Rules.to_m(centre_u[2 * r]), Rules.to_m(centre_u[2 * r + 1]))


func socket_u(r: int, k: int) -> Vector2i:
	"""Where room `r`'s socket `k` stands (u)."""
	return socket_at(template[r], centre(r), turns[r], k)


func door_u(r: int) -> Vector2i:
	"""Where room `r`'s door ramp meets its wall (u)."""
	return door_at(template[r], centre(r), turns[r])


func mouth_u(r: int) -> Vector2i:
	"""Where room `r`'s door or hatch opens on the surface (u)."""
	return mouth_at(template[r], centre(r), turns[r])


func cell_point_u(r: int, k: int) -> Vector2i:
	"""Where quantum `k` of room `r`'s timeline is cut (u): its floor cell's middle."""
	return centre(r) + rotate_u(cell_local(template[r], k), turns[r])


func to_world_u(r: int, local: Vector2i) -> Vector2i:
	"""A point in room `r`'s own frame, in the world (u)."""
	return centre(r) + rotate_u(local, turns[r])


func socket_of(r: int, k: int) -> int:
	"""Room `r`'s socket `k`'s node."""
	return socket_node[r * MAX_SOCKETS + k]


func walk_of(r: int, k: int) -> int:
	"""Room `r`'s walk segment to socket `k`."""
	return walk[r * MAX_SOCKETS + k]


func gap_of(r: int, p: Vector2i) -> int:
	"""How far `p` lies outside room `r`'s void (u)."""
	return gap_u(template[r], centre(r), turns[r], p)


func leg_gap_of(r: int, a: Vector2i, b: Vector2i) -> int:
	"""How far leg a-b stays outside room `r`'s void (u)."""
	return leg_gap_u(template[r], centre(r), turns[r], a, b)


# --- where a room may go ------------------------------------------------------------------

func refusal(graph: RefCounted, site: Site, kind: int, at: Vector2i, quarter_turns: int, room_level: int) -> int:
	"""REFUSE_NONE, or why a room of `kind` may not be dug at `at`, turned so, on `room_level` (see WHERE ONE
	MAY GO), in that order. `graph` is the network (underground_graph.gd)."""
	if room_level != Rules.BUILDABLE_LEVEL:
		return REFUSE_LEVEL
	if not has_free_row():
		return REFUSE_FULL
	if not graph.has_rows_for_room(socket_count(kind)):
		return REFUSE_NETWORK_FULL
	var door_foot := door_at(kind, at, quarter_turns)
	var hole := mouth_at(kind, at, quarter_turns)
	for check: Callable in [_bounds_reason.bind(site, kind, at, quarter_turns, hole),
			_water_reason.bind(site, kind, at, quarter_turns, hole, door_foot),
			_crops_reason.bind(site, kind, at, quarter_turns, hole, door_foot),
			_building_reason.bind(site, kind, at, quarter_turns, hole, door_foot),
			_rooms_reason.bind(graph, kind, at, quarter_turns, hole, door_foot),
			_tunnels_reason.bind(graph, kind, at, quarter_turns, hole, door_foot),
			_surface_reason.bind(site, kind, at, quarter_turns, hole, door_foot)]:
		var reason: int = check.call()
		if reason != REFUSE_NONE:
			return reason
	return REFUSE_NONE


static func _bounds_reason(site: Site, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i) -> int:
	"""The mound and the door inside the village."""
	var box := world_box(kind, at, quarter_turns, SKIRT_U)
	if not site.bounds_u.encloses(box) or not Rules.in_bounds(hole.x, hole.y, site.bounds_u):
		return REFUSE_OUT_OF_BOUNDS
	return REFUSE_NONE


static func _water_reason(site: Site, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> int:
	"""No part of the void or the door ramp under water or within half a bore of it (the no-dig band)."""
	if not site.water.is_valid():
		return REFUSE_NONE
	var band := Rules.BORE_WIDTH_U / 2
	if bool(site.water.call(hole, door_foot, HOOD_HALF_U + band)):
		return REFUSE_UNDER_WATER
	var half := void_half(kind)
	if SHAPE[kind] == SHAPE_ROUND:
		return REFUSE_UNDER_WATER if bool(site.water.call(at, at, half.x + band)) else REFUSE_NONE
	var corners: Array[Vector2i] = [half, Vector2i(-half.x, half.y), -half, Vector2i(half.x, -half.y)]
	for k in 4:
		var a := at + rotate_u(corners[k], quarter_turns)
		var b := at + rotate_u(corners[(k + 1) % 4], quarter_turns)
		if bool(site.water.call(a, b, band)):
			return REFUSE_UNDER_WATER
	return REFUSE_UNDER_WATER if bool(site.water.call(at, at, mini(half.x, half.y))) else REFUSE_NONE


static func _crops_reason(site: Site, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> int:
	"""The mound and the hood off every crop bed (squares: x, half-width, z)."""
	var mound := world_box(kind, at, quarter_turns, SKIRT_U)
	for i in site.beds_u.size() / 3:
		var bed := Vector2i(site.beds_u[3 * i], site.beds_u[3 * i + 2])
		var half := Vector2i(site.beds_u[3 * i + 1], site.beds_u[3 * i + 1])
		var over := _box_gap(at - bed, half) < void_half(kind).x + SKIRT_U if SHAPE[kind] == SHAPE_ROUND \
				else mound.intersects(Rect2i(bed - half, 2 * half))
		if over or _leg_box_gap(hole, door_foot, bed, half) < HOOD_HALF_U:
			return REFUSE_OVER_CROPS
	return REFUSE_NONE


static func _leg_box_gap(a: Vector2i, b: Vector2i, at: Vector2i, half: Vector2i) -> int:
	"""How far leg a-b stays outside the box `half` either side of `at` on the world's axes (u)."""
	var la := a - at
	var lb := b - at
	if _box_gap(la, half) == 0 or _box_gap(lb, half) == 0 or _leg_crosses_box(la, lb, half):
		return 0
	var best := mini(_box_gap(la, half), _box_gap(lb, half))
	for corner: Vector2i in [half, Vector2i(-half.x, half.y), -half, Vector2i(half.x, -half.y)]:
		best = mini(best, Rules.point_leg_u(corner, la, lb))
	return best


static func _building_reason(site: Site, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> int:
	"""The mound and the hood off every building's footprint circle."""
	for i in site.under_u.size() / 3:
		var c := Vector2i(site.under_u[3 * i], site.under_u[3 * i + 2])
		var reach := site.under_u[3 * i + 1]
		if gap_u(kind, at, quarter_turns, c) < reach + SKIRT_U or Rules.point_leg_u(c, hole, door_foot) < reach + HOOD_HALF_U:
			return REFUSE_UNDER_BUILDING
	return REFUSE_NONE


func _rooms_reason(graph: RefCounted, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> int:
	"""1 m of earth between this room's void and every other room's, its ramp and every other room's void, and
	its ramp and every other room's ramp."""
	for r in MAX_ROOMS:
		if not is_room(r):
			continue
		if voids_gap_u(kind, at, quarter_turns, template[r], centre(r), turns[r]) < Rules.PILLAR_U:
			return REFUSE_NEAR_ROOM
		if leg_gap_of(r, hole, door_foot) < Rules.PILLAR_U + Rules.BORE_WIDTHS_U[Rules.BORE_WIDE] / 2:
			return REFUSE_NEAR_ROOM
		if legs_gap_u(hole, door_foot, mouth_u(r), door_u(r)) < Rules.pillar_gap_u(Rules.BORE_WIDE, Rules.BORE_WIDE):
			return REFUSE_NEAR_ROOM
		var other_ramp: int = ramp[r]
		if other_ramp >= 0 and _segment_near_void(graph, other_ramp, kind, at, quarter_turns):
			return REFUSE_NEAR_ROOM
	return REFUSE_NONE


func _tunnels_reason(graph: RefCounted, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> int:
	"""1 m of earth between this room's void (and its ramp) and every tunnel of the network."""
	var box := world_box(kind, at, quarter_turns, Rules.PILLAR_U + Rules.BORE_WIDTHS_U[Rules.BORE_WIDE])
	box = box.expand(hole).grow(Rules.pillar_gap_u(Rules.BORE_WIDE, Rules.BORE_WIDE))
	for slot in Rules.MAX_SEGMENTS:
		if not graph.is_tunnel(slot) or not box.intersects(graph.route_box(slot)):
			continue
		if _segment_near_void(graph, slot, kind, at, quarter_turns) or _segment_near_leg(graph, slot, hole, door_foot):
			return REFUSE_NEAR_TUNNEL
	return REFUSE_NONE


static func _segment_near_void(graph: RefCounted, slot: int, kind: int, at: Vector2i, quarter_turns: int) -> bool:
	"""Whether any leg of segment `slot` comes within the pillar and its half-width of a room's void."""
	var reach: int = Rules.PILLAR_U + Rules.BORE_WIDTHS_U[graph.bore[slot]] / 2
	var base: int = 2 * slot * Rules.MAX_POINTS
	for k in range(1, graph.point_count[slot]):
		var a := Vector2i(graph.points_u[base + 2 * k - 2], graph.points_u[base + 2 * k - 1])
		var b := Vector2i(graph.points_u[base + 2 * k], graph.points_u[base + 2 * k + 1])
		if leg_gap_u(kind, at, quarter_turns, a, b) < reach:
			return true
	return false


static func _segment_near_leg(graph: RefCounted, slot: int, hole: Vector2i, door_foot: Vector2i) -> bool:
	"""Whether any leg of segment `slot` comes within a pillar of the door ramp (a wide bore)."""
	var reach := Rules.pillar_gap_u(Rules.BORE_WIDE, graph.bore[slot])
	var base: int = 2 * slot * Rules.MAX_POINTS
	for k in range(1, graph.point_count[slot]):
		var a := Vector2i(graph.points_u[base + 2 * k - 2], graph.points_u[base + 2 * k - 1])
		var b := Vector2i(graph.points_u[base + 2 * k], graph.points_u[base + 2 * k + 1])
		if legs_gap_u(a, b, hole, door_foot) < reach:
			return true
	return false


static func _surface_reason(site: Site, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> int:
	"""The door off every tree, heap, prop, work spot and mouth; the mound and the hood off them too."""
	if Rules.mouth_blocked(hole.x, hole.y, site.circles_u) or Rules.mouth_blocked(hole.x, hole.y, site.spots_u):
		return REFUSE_SURFACE_BLOCKED
	if _covers(site.circles_u, kind, at, quarter_turns, hole, door_foot) or _covers(site.spots_u, kind, at, quarter_turns, hole, door_foot):
		return REFUSE_SURFACE_BLOCKED
	return REFUSE_NONE


static func _covers(circles: PackedInt32Array, kind: int, at: Vector2i, quarter_turns: int, hole: Vector2i,
		door_foot: Vector2i) -> bool:
	"""Whether the mound (the void and SKIRT_U) or the hood (HOOD_HALF_U either side of the ramp) comes over any
	of `circles` (x, reach, z in u)."""
	for i in circles.size() / 3:
		var c := Vector2i(circles[3 * i], circles[3 * i + 2])
		var reach := circles[3 * i + 1]
		if gap_u(kind, at, quarter_turns, c) < reach + SKIRT_U or Rules.point_leg_u(c, hole, door_foot) < reach + HOOD_HALF_U:
			return true
	return false


# --- what is dug --------------------------------------------------------------------------

func is_done(graph: RefCounted, r: int) -> bool:
	"""Whether room `r` is dug out (its body open)."""
	return is_room(r) and body[r] >= 0 and graph.is_open(body[r])


func dug_permille(graph: RefCounted, r: int) -> int:
	"""How much of room `r`'s own quanta are dug, per mille (its body's ticks)."""
	if not is_room(r) or body[r] < 0:
		return 0
	return graph.done(body[r]) * Rules.PERMILLE / maxi(graph.total_ticks(body[r]), 1)


func count_done(graph: RefCounted, kind: int) -> int:
	"""How many rooms of template `kind` are dug out."""
	var n := 0
	for r in MAX_ROOMS:
		if template[r] == kind and is_done(graph, r):
			n += 1
	return n


func beds(graph: RefCounted) -> int:
	"""Demo beds installed in every dug burrow home (the fit-out's, decision 0210)."""
	return graph.fit.installed_beds(graph)


func cellar_count(graph: RefCounted) -> int:
	"""How many root cellars are dug out."""
	return count_done(graph, TEMPLATE_CELLAR)


func cellars(graph: RefCounted) -> Array[Dictionary]:
	"""Every dug root cellar with a store in it (see THE CELLAR API), at its hatch: its capacity its racks' and its
	spoilage the GDD's cellar factor while it is cool, the pantry's while it is not (room_fixtures.gd, decision 0210).
	A bare cellar holds nothing and is left out. Allocates; call on change, not per frame."""
	var out: Array[Dictionary] = []
	for r in MAX_ROOMS:
		if template[r] != TEMPLATE_CELLAR or not is_done(graph, r) or graph.fit.capacity_u(graph, r) <= 0:
			continue
		var hatch := mouth_u(r)
		var cool: bool = graph.fit.is_cool(graph, r)
		out.append({"id": Vector2i(r, generation[r]), "position": Vector3(Rules.to_m(hatch.x), 0.0, Rules.to_m(hatch.y)),
			"capacity_u": graph.fit.capacity_u(graph, r),
			"spoilage_permille": CELLAR_SPOILAGE_PERMILLE if cool else WARM_CELLAR_SPOILAGE_PERMILLE})
	return out


func housing_line(graph: RefCounted) -> String:
	"""The panel's housing readout."""
	return "Burrow homes: %d (%d demo beds) · Root cellars: %d" % [count_done(graph, TEMPLATE_HOME), beds(graph),
		cellar_count(graph)]
