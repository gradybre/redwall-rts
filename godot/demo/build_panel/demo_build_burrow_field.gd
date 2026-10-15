extends RefCounted
## THE ROUNDED, HAND-DUG WALLS' FIELD (decision 1914; Brendan approved the burrow-walls mockup on 2026-10-15: "Let's
## build this"). Rooms stay on the 1 m cell grid for every rule; only the drawing of dug space changes. For one level
## this holds each cell's kind round the dug cells -- DUG, HARD (kept square: ordered, wet, a stair's head, the cell
## being dug before it is dug) or plain EARTH -- and says how deep the drawn earth is at each point of a lattice
## SAMPLES to a metre:
##   PLAN      the distance from the dug cells (exact: the union of the cells' squares), with a fillet where two dug
##             sides meet round an earth corner (the mockup's polynomial smooth-min, FILLET_M), offset out by
##             OFFSET_M and wobbled by WOBBLE_M of fixed noise (one table, the same every frame and every run);
##   SECTION   a cosine across BAND_M: rounded over at the top lip, curving into the floor at the foot;
##   RULE (a)  every point of a dug cell's closed square is floor, before anything else: the curves carve outward,
##             never into a cell. OFFSET_M exceeds WOBBLE_M, so the wobble never reaches back to a cell's edge;
##   RULE (b)  a HARD cell is never rounded into: what is planned stays square until it is dug;
##   THIN      an earth cell with dug cells on two opposite sides (a one-cell wall) has its section squeezed across
##             it (THIN_SCALE), so its crest still reaches the top and two rooms never read as one.
## A point on a cell edge is judged by every cell it touches (a dug one wins, else the shallowest), so the field is a
## function of the point alone: two patches drawing one edge draw it the same. Earth further than a cell from any dug
## cell is the top. Presentation only.

const EARTH: int = 0
const DUG: int = 1
const HARD: int = 2
## Lattice points to a metre (a cell's side): the mesh's sub-cell resolution (the brief's 6-8; 8 keeps a square
## cell's sharp edge, one lattice step wide, inside its chalk's CHALK_INSET_M).
const SAMPLES: int = 8
const ROW: int = SAMPLES + 1
## The rounding radius: a third of a cell (Brendan's mockup default), and what follows from it as the mockup has it.
const RADIUS_M: float = 1.0 / 3.0
## How far the floor's edge is carried out past the dug cells (convex corners round outward, passage mouths flare).
const OFFSET_M: float = 0.45 * RADIUS_M
## How wide the coved wall is, top lip to floor.
const BAND_M: float = 0.35 + 0.6 * RADIUS_M
## The smooth-min's reach where two dug sides meet round an earth corner.
const FILLET_M: float = 1.8 * RADIUS_M
## The fillet fades out from this far along either side to nothing at the far side of its cell, so it ends on the
## cell's own edges.
const FILLET_FADE_M: float = 0.6
## The wobble's reach either way: under OFFSET_M (rule a), as the mockup's two octaves (0.11 + 0.035) were.
const WOBBLE_M: float = 0.14
## A one-cell wall: its distances stretched so the whole section fits in half a cell.
const THIN_SCALE: float = (OFFSET_M + BAND_M + WOBBLE_M) / 0.5
## What a point is when no distance applies: on a dug cell (floor) or out of reach (the top).
const FLOOR_G: float = -1000.0
const TOP_G: float = 1000.0
## The wobble's noise: one seamless table NOISE_SIZE lattice points (32 m) square, made once.
const NOISE_SIZE: int = 256
const NOISE_SEED: int = 1914
## The neighbour bits of a cell's mask, and their offsets.
const N: int = 1
const NE: int = 2
const E: int = 4
const SE: int = 8
const S: int = 16
const SW: int = 32
const W: int = 64
const NW: int = 128
## How far round a cell its wall patch reads kinds: its own neighbours' neighbours (a lattice point on its edge is
## judged by the cells it touches, each by its own neighbours).
const REACH: int = 2
const AROUND: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

## A patch's lattice runs from one point before its cell's first to one past its last (SPAN a side). For each of
## those points along an axis: the first cell it lies in (-1, 0, 1 from the patch's) and its index there, and the
## second cell it lies on the edge of (NO_SECOND: none).
const SPAN: int = ROW + 2
const NO_SECOND: int = 9
const FIRST_CELL: Array[int] = [-1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
const FIRST_AT: Array[int] = [7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1]
const SECOND_CELL: Array[int] = [NO_SECOND, 0, NO_SECOND, NO_SECOND, NO_SECOND, NO_SECOND, NO_SECOND, NO_SECOND,
	NO_SECOND, 1, NO_SECOND]

## Each mask's base distances on its cell's ROW × ROW lattice (made on first use) and the wobble's table.
static var _tables: Dictionary = {}
static var _noise: PackedByteArray = PackedByteArray()

## The cells held (absolute cell coordinates of the works) and their kinds; worked out on first read (and again after
## a kind changes): each cell's mask and base distances.
var origin: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ZERO
var _kinds: PackedByteArray = PackedByteArray()
var _masks: PackedInt32Array = PackedInt32Array()
var _cell_tables: Array[PackedFloat32Array] = []
var _stale: bool = true
## A patch's nine cells as `fill_patch` reads them: FLOOR_G (dug), TOP_G (kept square, or out of reach), or 0 and
## their base distances.
var _near_g: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
var _near_tables: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(),
	PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array(),
	PackedFloat32Array()]


func setup(cells: Rect2i) -> void:
	"""Hold `cells`, all EARTH."""
	origin = cells.position
	size = cells.size
	_kinds.resize(size.x * size.y)
	_kinds.fill(EARTH)
	_stale = true


func copy_from(other: RefCounted) -> void:
	"""The same cells and kinds as `other` (another field)."""
	origin = other.get("origin")
	size = other.get("size")
	_kinds = (other.call(&"kinds") as PackedByteArray).duplicate()
	_stale = true


func _refresh() -> void:
	"""Forget every mask and distance worked out (a kind changed)."""
	_stale = false
	_masks.resize(size.x * size.y)
	_masks.fill(-1)
	_cell_tables.resize(size.x * size.y)


func kinds() -> PackedByteArray:
	"""The kinds held, row by row (copy_from)."""
	return _kinds


func set_kind(cell: Vector2i, kind: int) -> void:
	"""`cell` (absolute) is `kind`; outside the cells held, nothing."""
	var local: Vector2i = cell - origin
	if local.x >= 0 and local.y >= 0 and local.x < size.x and local.y < size.y:
		_kinds[local.y * size.x + local.x] = kind
		_stale = true


func kind_of(cell: Vector2i) -> int:
	"""`cell`'s kind (absolute; EARTH outside the cells held)."""
	return _kind(cell.x - origin.x, cell.y - origin.y)


func _kind(x: int, z: int) -> int:
	"""The kind of local cell (x, z) (EARTH outside)."""
	if x < 0 or z < 0 or x >= size.x or z >= size.y:
		return EARTH
	return _kinds[z * size.x + x]


func signature(cell: Vector2i, digging: Vector2i) -> int:
	"""All a wall patch at `cell` depends on: the kinds of the cells within REACH of it (two bits each) and where among
	them `digging` (the cell being dug, absolute; anywhere further off: none) is, as one integer."""
	var x: int = cell.x - origin.x
	var z: int = cell.y - origin.y
	var inside: bool = x >= REACH and z >= REACH and x + REACH < size.x and z + REACH < size.y
	var out: int = 0
	for dz: int in range(-REACH, REACH + 1):
		var row: int = (z + dz) * size.x + x
		for dx: int in range(-REACH, REACH + 1):
			out = (out << 2) | (_kinds[row + dx] if inside else _kind(x + dx, z + dz))
	var off: Vector2i = digging - cell
	var side: int = 2 * REACH + 1
	var near: bool = absi(off.x) <= REACH and absi(off.y) <= REACH
	return (out << 5) | ((off.y + REACH) * side + off.x + REACH + 1 if near else 0)


func near_dug(cell: Vector2i) -> bool:
	"""Whether `cell` (absolute) is not dug and has a dug cell among its eight neighbours: the earth the rounding
	reaches into."""
	var x: int = cell.x - origin.x
	var z: int = cell.y - origin.y
	return _kind(x, z) != DUG and _mask(x, z) != 0


func _mask(x: int, z: int) -> int:
	"""Local cell (x, z)'s dug neighbours as bits (N, NE ... NW), worked out once."""
	if _stale:
		_refresh()
	var inside: bool = x >= 0 and z >= 0 and x < size.x and z < size.y
	if inside and _masks[z * size.x + x] >= 0:
		return _masks[z * size.x + x]
	var mask: int = 0
	for k: int in AROUND.size():
		if _kind(x + AROUND[k].x, z + AROUND[k].y) == DUG:
			mask |= 1 << k
	if inside:
		_masks[z * size.x + x] = mask
		_cell_tables[z * size.x + x] = table(mask) if mask != 0 else PackedFloat32Array()
	return mask


func g_at(gx: int, gz: int) -> float:
	"""The field at lattice point (gx, gz), counted from the NW corner of the cells held: FLOOR_G on any dug cell's
	closed square (rule a), else the shallowest the cells it touches make it (a distance in m; TOP_G out of reach or
	on a HARD cell)."""
	var ix: int = posmod(gx, SAMPLES)
	var iz: int = posmod(gz, SAMPLES)
	@warning_ignore("integer_division") var cx: int = (gx - ix) / SAMPLES
	@warning_ignore("integer_division") var cz: int = (gz - iz) / SAMPLES
	if ix != 0 and iz != 0:
		return _g_in(cx, cz, ix, iz)
	var best: float = FLOOR_G
	for z: int in range(cz - 1 if iz == 0 else cz, cz + 1):
		for x: int in range(cx - 1 if ix == 0 else cx, cx + 1):
			var g: float = _g_in(x, z, gx - x * SAMPLES, gz - z * SAMPLES)
			if g <= FLOOR_G:
				return FLOOR_G
			best = maxf(best, g)
	return best


func _g_in(x: int, z: int, i: int, j: int) -> float:
	"""The field at lattice point (i, j) of local cell (x, z) as that cell alone makes it."""
	var kind: int = _kind(x, z)
	if kind == DUG:
		return FLOOR_G
	if kind == HARD or _mask(x, z) == 0:
		return TOP_G
	if x < 0 or z < 0 or x >= size.x or z >= size.y:
		return table(_mask(x, z))[j * ROW + i]
	return _cell_tables[z * size.x + x][j * ROW + i]


func fill_patch(cell: Vector2i, into: PackedFloat32Array) -> void:
	"""`depth_at` on the SPAN × SPAN lattice from one point north-west of `cell`'s corner (absolute) into `into`, row by
	row: the same numbers, worked out for a whole patch at once (its nine cells read once)."""
	if _stale:
		_refresh()
	var x: int = cell.x - origin.x
	var z: int = cell.y - origin.y
	for k: int in 9:
		@warning_ignore("integer_division") var near: Vector2i = Vector2i(x + k % 3 - 1, z + k / 3 - 1)
		_near_g[k] = _g_in(near.x, near.y, 1, 1) if _kind(near.x, near.y) != EARTH or _mask(near.x, near.y) == 0 else 0.0
		_near_tables[k] = table(_mask(near.x, near.y)) if _near_g[k] == 0.0 else PackedFloat32Array()
	var wx: int = (cell.x * SAMPLES) - 1
	var wz: int = (cell.y * SAMPLES) - 1
	if _noise.is_empty():
		_noise = _make_noise()
	for j: int in SPAN:
		for i: int in SPAN:
			var g: float = _patch_g(i, j)
			var at: int = posmod(wz + j, NOISE_SIZE) * NOISE_SIZE + posmod(wx + i, NOISE_SIZE)
			into[j * SPAN + i] = 1.0 if g <= FLOOR_G else 0.0 if g >= TOP_G \
				else section(g - OFFSET_M + (_noise[at] / 127.5 - 1.0) * WOBBLE_M)


func _patch_g(i: int, j: int) -> float:
	"""The field at point (i, j) of a patch's lattice, from the nine cells `fill_patch` read: the shallowest of the
	cells it lies in, or the floor if one of them is dug."""
	var best: float = FLOOR_G
	for b: int in 2:
		var cz: int = FIRST_CELL[j] if b == 0 else SECOND_CELL[j]
		if cz == NO_SECOND:
			break
		var at_z: int = FIRST_AT[j] if b == 0 else 0
		for a: int in 2:
			var cx: int = FIRST_CELL[i] if a == 0 else SECOND_CELL[i]
			if cx == NO_SECOND:
				break
			var k: int = (cz + 1) * 3 + cx + 1
			var g: float = _near_g[k]
			if g <= FLOOR_G:
				return FLOOR_G
			best = maxf(best, g if g >= TOP_G else _near_tables[k][at_z * ROW + (FIRST_AT[i] if a == 0 else 0)])
	return best


func depth_at(gx: int, gz: int) -> float:
	"""How far down the drawn earth is at lattice point (gx, gz): 0 the top, 1 the dug floor."""
	var g: float = g_at(gx, gz)
	if g <= FLOOR_G:
		return 1.0
	if g >= TOP_G:
		return 0.0
	return section(g - OFFSET_M + wobble(origin.x * SAMPLES + gx, origin.y * SAMPLES + gz))


static func section(g: float) -> float:
	"""The coved wall: 1 (floor) at or inside g = 0, 0 (top) at or past BAND_M, a cosine between (rounded at the lip,
	curving into the floor)."""
	if g <= 0.0:
		return 1.0
	if g >= BAND_M:
		return 0.0
	return 0.5 + 0.5 * cos(PI * g / BAND_M)


static func warm() -> void:
	"""Make every mask's table and the wobble's noise now, on the main thread, so a build on a worker only reads them
	(review M-e: the statics are never written from a worker)."""
	for mask: int in 256:
		table(mask)
	wobble(0, 0)


static func table(mask: int) -> PackedFloat32Array:
	"""Mask `mask`'s base distances on its cell's lattice (made once)."""
	if not _tables.has(mask):
		var values: PackedFloat32Array = PackedFloat32Array()
		values.resize(ROW * ROW)
		for j: int in ROW:
			for i: int in ROW:
				values[j * ROW + i] = base_g(mask, float(i) / SAMPLES, float(j) / SAMPLES)
		_tables[mask] = values
	return _tables[mask]


static func base_g(mask: int, u: float, v: float) -> float:
	"""The distance from point (u, v) of an earth cell (u east, v south, 0-1) to its dug neighbours in `mask`: exact to
	the sides and corners, a one-cell wall's stretched (THIN_SCALE), less each earth corner's fillet."""
	var sx: float = THIN_SCALE if mask & W and mask & E else 1.0
	var sz: float = THIN_SCALE if mask & N and mask & S else 1.0
	var sides: PackedFloat32Array = PackedFloat32Array([
		v * sz if mask & N else INF, (1.0 - u) * sx if mask & E else INF,
		(1.0 - v) * sz if mask & S else INF, u * sx if mask & W else INF])
	var d: float = minf(minf(sides[0], sides[1]), minf(sides[2], sides[3]))
	var corners: Array[Vector2] = [Vector2(1.0 - u, v), Vector2(1.0 - u, 1.0 - v), Vector2(u, 1.0 - v), Vector2(u, v)]
	for k: int in 4:
		if mask & (NE << (2 * k)):
			d = minf(d, Vector2(corners[k].x * sx, corners[k].y * sz).length())
		var a: float = sides[k]
		var b: float = sides[(k + 1) % 4]
		if a < INF and b < INF:
			d = minf(d, fillet(a, b))
	return d


static func fillet(a: float, b: float) -> float:
	"""The mockup's polynomial smooth-min of two side distances meeting round an earth corner, faded out from
	FILLET_FADE_M to nothing at the cell's far sides."""
	var h: float = maxf(FILLET_M - absf(a - b), 0.0) / FILLET_M
	var fade: float = 1.0 - smoothstep(FILLET_FADE_M, 1.0, maxf(a, b))
	return minf(a, b) - h * h * FILLET_M * 0.25 * fade


static func wobble(wx: int, wz: int) -> float:
	"""The fixed wobble at world lattice point (wx, wz) (-WOBBLE_M to WOBBLE_M): one seamless noise table, made once
	from a fixed seed, so it is the same every frame and every run."""
	if _noise.is_empty():
		_noise = _make_noise()
	return (_noise[posmod(wz, NOISE_SIZE) * NOISE_SIZE + posmod(wx, NOISE_SIZE)] / 127.5 - 1.0) * WOBBLE_M


static func _make_noise() -> PackedByteArray:
	"""Two octaves of value noise, as the mockup's (1.7 and 4.3 to a metre, weighted 0.22 and 0.07), as bytes."""
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = NOISE_SEED
	noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	noise.frequency = 1.7 / SAMPLES
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	noise.fractal_lacunarity = 4.3 / 1.7
	noise.fractal_gain = 0.07 / 0.22
	return noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE, false, false, 0.1, true).get_data()
