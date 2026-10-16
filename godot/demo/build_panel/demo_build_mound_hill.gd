extends RefCounted
## THE HILL AS A MESH (decision 2002): the heightfield of demo_build_mound_field.gd drawn over the Surface, from a
## SNAPSHOT of the Mounds taken on the main thread (so a worker may build it while the builder goes on). Two views:
##   OUTSIDE   the hill whole: raw heaped earth, earth once dug and framed, turf with a few flowers once topped
##             (the approved mockup's colours, made linear for the shader);
##   CUTAWAY   the build view (the panel open on the Surface): the hill cut off at the wall's top, the mockup's "Turf
##             off", so the rooms show -- each DUG room cell's floor flat at the ground over its whole square and its
##             walls rounded and hand-dug by decision 1914's field (`demo_build_burrow_field.gd`, rule (a): never hide
##             a usable cell; rule (b): a room cell not yet dug stays square), the cut top in dark earth.
## A lattice point a quarter metre apart (STEP_M); each cell's corners fall on it, so a floor is whole. Presentation only.

const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const Burrow := preload("res://demo/build_panel/demo_build_burrow_field.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")

const STEP_M: float = 0.25
## A dug floor is drawn this far over the ground (the village's ground lies under it).
const FLOOR_LIFT_M: float = 0.012
## The approved mockup's colours (sRGB): raw heaped earth, dug earth, turf, the cut top, a dug floor.
const RAW: Color = Color8(0x7d, 0x58, 0x36)
const DUG_EARTH: Color = Color8(0x6e, 0x4c, 0x2d)
const TURF: Color = Color8(0x5f, 0x8a, 0x3e)
const CUT_TOP: Color = Color8(0x4a, 0x35, 0x24)
const FLOOR: Color = Color8(0xb8, 0x8a, 0x58)
## Turf's own light and dark, by a fixed hash a lattice point (sRGB shares of TURF).
const TURF_LIGHT: float = 0.1


class Snapshot extends RefCounted:
	## What a build reads: the field over the heaped cells, each cell's stage, and decision 1914's field over the dug
	## ones (dug DUG, heaped but not dug HARD).
	var field: Field = Field.new()
	var stages: Dictionary = {}
	var dug: Burrow = Burrow.new()
	var origin: Vector2i = Vector2i.ZERO


static func snapshot(mounds: Mounds, datum_m: Vector2) -> Snapshot:
	"""Read the Mounds now (main thread): the heaped cells, the yards cut, each cell's stage and the dug field."""
	var out: Snapshot = Snapshot.new()
	var heaped: PackedInt32Array = PackedInt32Array()
	mounds.cells_into(Mounds.HEAPED, heaped)
	out.field.setup(heaped, mounds.yards(), datum_m)
	var box: Rect2i = out.field.box()
	out.origin = box.position
	out.dug.setup(box)
	for at: int in range(0, heaped.size(), 2):
		var cell: Vector2i = Vector2i(heaped[at], heaped[at + 1])
		var stage: int = mounds.stage_of(cell)
		out.stages[cell] = stage
		out.dug.set_kind(cell, Burrow.DUG if stage >= Mounds.DUG else Burrow.HARD)
	return out


static func lattice(snap: Snapshot) -> Rect2i:
	"""The lattice points drawn: the field's box at STEP_M (position: first point's index; size: columns, rows)."""
	var box: Rect2i = snap.field.box()
	var per: int = roundi(1.0 / STEP_M)
	return Rect2i(box.position * per, box.size * per)


static func outside(snap: Snapshot, material: Material) -> ArrayMesh:
	"""The hill whole (see OUTSIDE); null with nothing heaped."""
	return MeshKit.mesh_of(build_arrays(snap)[0], material)


static func cutaway(snap: Snapshot, material: Material) -> ArrayMesh:
	"""The hill cut off at the wall's top with the dug rooms open (see CUTAWAY); null with nothing heaped."""
	return MeshKit.mesh_of(build_arrays(snap)[1], material)


static func build_arrays(snap: Snapshot) -> Array:
	"""Both looks' grids as surface arrays [whole, cut away], every lattice point's height worked out once (a worker
	may make them; [[], []] with nothing heaped)."""
	if snap.stages.is_empty():
		return [[], []]
	var grid: Rect2i = lattice(snap)
	var count: int = (grid.size.x + 1) * (grid.size.y + 1)
	var heights: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var colours: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray()]
	for look: int in 2:
		heights[look].resize(count)
		colours[look].resize(count)
	var at: int = 0
	for j: int in grid.size.y + 1:
		for i: int in grid.size.x + 1:
			var point: Vector2 = snap.field.datum_m + Vector2(grid.position + Vector2i(i, j)) * STEP_M
			var h: float = snap.field.height_m(point)
			var stage: int = int(snap.stages.get(snap.field.found_cell(), Mounds.HEAPED))
			var whole: Vector2 = Vector2(h if h > 0.0 else MeshKit.UNDER_M, 0.0)
			var cut: Vector2 = cut_point(snap, h, Vector2i(i, j))
			heights[0][at] = whole.x
			colours[0][at] = _colour(stage, point, whole)
			heights[1][at] = cut.x
			colours[1][at] = _colour(stage, point, cut)
			at += 1
	var origin: Vector2 = snap.field.datum_m + Vector2(grid.position) * STEP_M
	return [MeshKit.grid_arrays(origin, STEP_M, grid.size.x, heights[0], colours[0]),
		MeshKit.grid_arrays(origin, STEP_M, grid.size.x, heights[1], colours[1])]


static func cut_point(snap: Snapshot, whole_m: float, local: Vector2i) -> Vector2:
	"""(height, what it is: 0 slope or ground, 1 the cut top, 2 a wall, 3 a floor) at lattice point `local` where the
	whole hill stands `whole_m` high, with the hill cut off at the wall's top and the dug rooms open."""
	var h: float = minf(whole_m, Field.ROOM_TOP_M)
	var per: int = roundi(Burrow.SAMPLES * STEP_M)
	var depth: float = snap.dug.depth_at(local.x * per, local.y * per)
	if depth >= 1.0:
		return Vector2(FLOOR_LIFT_M, 3.0)
	if depth > 0.0 and h > Field.ROOM_TOP_M * (1.0 - depth):
		return Vector2(Field.ROOM_TOP_M * (1.0 - depth), 2.0)
	if h >= Field.ROOM_TOP_M:
		return Vector2(h, 1.0)
	return Vector2(h if h > 0.0 else MeshKit.UNDER_M, 0.0)


static func _colour(stage: int, point: Vector2, drawn: Vector2) -> Color:
	"""A lattice point's colour (linear; its alpha what it is to the shader), by what it is and the stage of the room
	cell nearest it."""
	match int(drawn.y):
		3:
			return _with(FLOOR, MeshKit.FLOOR)
		2:
			return _with(DUG_EARTH, MeshKit.EARTH)
		1:
			return _with(CUT_TOP, MeshKit.EARTH)
	if stage >= Mounds.TOPPED:
		return _with(TURF.lightened(TURF_LIGHT * hash01(point)), MeshKit.TURF)
	return _with(RAW if stage == Mounds.HEAPED else DUG_EARTH, MeshKit.HEAP)


static func _with(colour: Color, kind: float) -> Color:
	"""`colour` made linear, its alpha `kind`."""
	var linear: Color = colour.srgb_to_linear()
	linear.a = kind
	return linear


static func hash01(point: Vector2) -> float:
	"""A fixed hash of a point, 0-1 (the mockup's)."""
	return fposmod(sin(point.x * 127.1 + point.y * 311.7) * 43758.5453, 1.0)
