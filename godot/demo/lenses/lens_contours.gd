extends MeshInstance3D
## The compared layer drawn as OUTLINES over the shown one (decision 0581): each of its areas traced as a line in
## that area's own legend colour, on the area's inside, with an ink core along the boundary -- so a bed reads as
## "filled by the shown layer, ringed by the compared one", and two of the water's zones meet as a two-colour line.
## Presentation only: it asks the compared layer's probe (lens_probe.gd) and draws; it never shows that layer's own
## marks, so no two layers' marks share the map (decision 0292's rule holds).
##
## HOW. The probe's field (`field_bounds_m`) is sampled on a grid of corners `field_cell_m` apart, one area class per
## corner (`Reading.area`), and every class is traced by MARCHING SQUARES: per grid cell, the corners in the class pick
## one of 16 cases, each a segment or two between edge midpoints (the two saddles are split so each in-class corner
## is cut off on its own). Each segment becomes a strip STRIP_M wide on the class's side and an INK_M ink core.
##
## WHEN, AND HOW MUCH. A trace starts on `start` (a new compared layer, its field revision moved) and runs a slice at
## a time (`step`, at most `budget_usec` a frame: sampling rows, then tracing rows, then one mesh commit); the old
## outline stays drawn until the new one is committed. Nothing is allocated per frame while idle; a trace writes into
## buffers kept between traces and grows them only when an outline is longer than any before. Grids larger than
## MAX_CORNERS are sampled coarser.
##
## SEEN AT NIGHT. The material is UNSHADED with fog disabled and no depth test, on the surface's marks layer
## (demo_layers.gd SURFACE_MARKS): the moon, the lamps and the haze do not change it; only the frame's own grade does.

const ProbeScript := preload("res://demo/lenses/lens_probe.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Palette := preload("res://demo/lenses/lens_palette.gd")

## A strip's width on its area's side, and the ink core's (m).
const STRIP_M: float = 0.16
const INK_M: float = 0.05
## Drawn after the layers' own translucent marks (their priorities are 2..4).
const RENDER_PRIORITY: int = 6
## The most grid corners one trace samples (a bigger field is sampled coarser).
const MAX_CORNERS: int = 40000
## The most area classes traced.
const MAX_CLASSES: int = 16
## A frame's default slice of work.
const BUDGET_USEC: int = 1000
const PHASE_IDLE: int = 0
const PHASE_SAMPLE: int = 1
const PHASE_TRACE: int = 2
## Marching squares: per case (in-class corners c0 1, c1 2, c2 4, c3 8), up to two segments as edge pairs
## (edges: 0 top, 1 right, 2 bottom, 3 left); -1 for none.
const CASES: PackedInt32Array = [
	-1, -1, -1, -1, 3, 0, -1, -1, 0, 1, -1, -1, 3, 1, -1, -1,
	1, 2, -1, -1, 3, 0, 1, 2, 0, 2, -1, -1, 3, 2, -1, -1,
	2, 3, -1, -1, 0, 2, -1, -1, 0, 1, 2, 3, 1, 2, -1, -1,
	3, 1, -1, -1, 0, 1, -1, -1, 3, 0, -1, -1, -1, -1, -1, -1,
]
const SADDLE_A: int = 5
const SADDLE_B: int = 10

## Traces committed so far (checks), and the segments in the last.
var traces: int = 0
var segments: int = 0

var _probe: ProbeScript = null
var _colours: PackedColorArray = PackedColorArray()
var _origin: Vector2 = Vector2.ZERO
var _cell: float = 0.5
var _nx: int = 0
var _nz: int = 0
var _y: float = 0.05
var _classes: PackedInt32Array = PackedInt32Array()
var _present: PackedByteArray = PackedByteArray()
var _phase: int = PHASE_IDLE
var _row: int = 0
var _class: int = 0
var _verts: PackedVector3Array = PackedVector3Array()
var _cols: PackedColorArray = PackedColorArray()
var _used: int = 0
var _reading: ProbeScript.Reading = ProbeScript.Reading.new()
var _mesh: ArrayMesh = ArrayMesh.new()


func _init() -> void:
	"""An empty outline on the surface's marks layer, with its material."""
	name = "LensContours"
	mesh = _mesh
	layers = Layers.SURFACE_MARKS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = make_material()
	_present.resize(MAX_CLASSES)


static func make_material() -> StandardMaterial3D:
	"""Unshaded vertex colour, fog off, drawn over the ground and everything on it."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.disable_fog = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = RENDER_PRIORITY
	return material


func start(probe: ProbeScript, colours: PackedColorArray) -> void:
	"""Trace `probe`'s areas in `colours` (its legend's swatches, by area class); the old outline stays until done."""
	_probe = probe
	_colours = colours
	var bounds: Rect2 = probe.field_bounds_m()
	_cell = maxf(probe.field_cell_m(), sqrt(bounds.get_area() / float(MAX_CORNERS)))
	_origin = bounds.position
	_nx = maxi(int(ceilf(bounds.size.x / _cell)), 1)
	_nz = maxi(int(ceilf(bounds.size.y / _cell)), 1)
	_y = probe.draw_y_m()
	_classes.resize((_nx + 1) * (_nz + 1))
	_present.fill(0)
	_used = 0
	_row = 0
	_class = 0
	segments = 0
	_phase = PHASE_SAMPLE if bounds.has_area() else PHASE_IDLE
	if _phase == PHASE_IDLE:
		clear_outline()


func clear_outline() -> void:
	"""No outline, and no trace running."""
	_phase = PHASE_IDLE
	_probe = null
	_mesh.clear_surfaces()
	segments = 0


func is_working() -> bool:
	"""Whether a trace is under way."""
	return _phase != PHASE_IDLE


func step(budget_usec: int = BUDGET_USEC) -> bool:
	"""Work on the trace for at most `budget_usec` (whole rows); returns whether it is still under way."""
	var until: int = Time.get_ticks_usec() + budget_usec
	while _phase != PHASE_IDLE and Time.get_ticks_usec() < until:
		if _phase == PHASE_SAMPLE:
			_sample_row()
		else:
			_trace_row()
	return _phase != PHASE_IDLE


func finish() -> void:
	"""Run the trace to its end now (checks, and a first draw)."""
	while _phase != PHASE_IDLE:
		step(1000000)


func _sample_row() -> void:
	"""One row of corners: each corner's area class."""
	var row_at: int = _row * (_nx + 1)
	var z: float = _origin.y + float(_row) * _cell
	for i: int in _nx + 1:
		var area: int = -1
		if _probe.read_into(Vector2(_origin.x + float(i) * _cell, z), _reading) and _reading.area < MAX_CLASSES:
			area = _reading.area
		_classes[row_at + i] = area
		if area >= 0:
			_present[area] = 1
	_row += 1
	if _row > _nz:
		_row = 0
		_class = _next_class(0)
		_phase = PHASE_TRACE if _class < MAX_CLASSES else PHASE_IDLE
		if _phase == PHASE_IDLE:
			_commit()


func _next_class(from: int) -> int:
	"""The first class present at or after `from` (MAX_CLASSES: none)."""
	var k: int = from
	while k < MAX_CLASSES and _present[k] == 0:
		k += 1
	return k


func _trace_row() -> void:
	"""One row of cells for the class being traced; then the next class, then the commit."""
	for i: int in _nx:
		var case_index: int = _case_of(i, _row, _class)
		if case_index != 0 and case_index != 15:
			_emit_case(i, _row, case_index)
	_row += 1
	if _row < _nz:
		return
	_row = 0
	_class = _next_class(_class + 1)
	if _class >= MAX_CLASSES:
		_commit()


func _case_of(i: int, j: int, k: int) -> int:
	"""The marching-squares case of cell (i, j) for class `k`."""
	var top: int = j * (_nx + 1) + i
	var bottom: int = top + _nx + 1
	return int(_classes[top] == k) | int(_classes[top + 1] == k) << 1 | int(_classes[bottom + 1] == k) << 2 \
		| int(_classes[bottom] == k) << 3


func _emit_case(i: int, j: int, case_index: int) -> void:
	"""The case's one or two segments, each a strip on the class's side and an ink core."""
	var base: int = case_index * 4
	for s: int in 2:
		var a: int = CASES[base + s * 2]
		if a < 0:
			return
		var b: int = CASES[base + s * 2 + 1]
		var inside: Vector2 = _inside_of(i, j, case_index, a, b)
		_emit_segment(_edge_point(i, j, a), _edge_point(i, j, b), inside)


func _edge_point(i: int, j: int, edge: int) -> Vector2:
	"""The midpoint of a cell edge (0 top, 1 right, 2 bottom, 3 left), metres."""
	var x: float = float(i) + (0.5 if edge == 0 or edge == 2 else (1.0 if edge == 1 else 0.0))
	var z: float = float(j) + (0.5 if edge == 1 or edge == 3 else (1.0 if edge == 2 else 0.0))
	return _origin + Vector2(x, z) * _cell


func _inside_of(i: int, j: int, case_index: int, a: int, b: int) -> Vector2:
	"""A point on the class's side of segment a-b: in a saddle, the corner the segment cuts off; else the middle of the
	cell's in-class corners."""
	if case_index == SADDLE_A or case_index == SADDLE_B:
		return _corner(i, j, shared_corner(a, b))
	var sum := Vector2.ZERO
	var n: int = 0
	for c: int in 4:
		if case_index & (1 << c):
			sum += _corner(i, j, c)
			n += 1
	return sum / float(n)


static func shared_corner(a: int, b: int) -> int:
	"""The corner two adjacent edges share (edges 3 and 0 share corner 0, 0 and 1 corner 1, and so on)."""
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	return 0 if low == 0 and high == 3 else high


func _corner(i: int, j: int, c: int) -> Vector2:
	"""Corner c (0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left) of cell (i, j), metres."""
	var x: float = float(i) + (1.0 if c == 1 or c == 2 else 0.0)
	var z: float = float(j) + (1.0 if c >= 2 else 0.0)
	return _origin + Vector2(x, z) * _cell


func _emit_segment(p: Vector2, q: Vector2, inside: Vector2) -> void:
	"""The class's strip from p to q on the side of `inside`, then the ink core along it."""
	var along: Vector2 = (q - p).normalized()
	var normal := Vector2(-along.y, along.x)
	if normal.dot(inside - (p + q) * 0.5) < 0.0:
		normal = -normal
	_quad(p, q, normal * STRIP_M, Vector2.ZERO, _colours[_class] if _class < _colours.size() else Palette.OUTLINE_INK)
	_quad(p, q, normal * (INK_M * 0.5), -normal * (INK_M * 0.5), Palette.OUTLINE_INK)
	segments += 1


func _quad(p: Vector2, q: Vector2, out_side: Vector2, in_side: Vector2, colour: Color) -> void:
	"""Two triangles: p and q moved by `in_side` and by `out_side`, in one opaque colour."""
	if _used + 6 > _verts.size():
		_verts.resize(maxi(_verts.size() * 2, 1536))
		_cols.resize(_verts.size())
	var a := Vector3(p.x + in_side.x, _y, p.y + in_side.y)
	var b := Vector3(q.x + in_side.x, _y, q.y + in_side.y)
	var c := Vector3(q.x + out_side.x, _y, q.y + out_side.y)
	var d := Vector3(p.x + out_side.x, _y, p.y + out_side.y)
	var solid := Color(colour, 1.0)
	_put(a, solid)
	_put(b, solid)
	_put(c, solid)
	_put(a, solid)
	_put(c, solid)
	_put(d, solid)


func _put(v: Vector3, colour: Color) -> void:
	"""One vertex into the kept buffers."""
	_verts[_used] = v
	_cols[_used] = colour
	_used += 1


func _commit() -> void:
	"""The traced outline replaces the drawn one."""
	_phase = PHASE_IDLE
	_mesh.clear_surfaces()
	traces += 1
	if _used == 0:
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts.slice(0, _used)
	arrays[Mesh.ARRAY_COLOR] = _cols.slice(0, _used)
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func vertex_count() -> int:
	"""Vertices in the drawn outline (checks)."""
	return 0 if _mesh.get_surface_count() == 0 else _mesh.surface_get_array_len(0)
