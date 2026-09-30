extends RefCounted
## The swept bore: a hand-dug horseshoe tube swept along a tunnel's drawn centreline (bore_curve.gd).
## Decision 0207 (the underground revamp's P1; design docs/design/underground_revamp.md §3 "Geometry",
## §6 "Bores"). Presentation only.
##
## THE PROFILE is PROFILE_VERTS points round a horseshoe: a flat floor FLOOR_HALF_M either side, walls
## that bow out to BULGE times that at the springline (SPRING_SHARE of the crown up), and an elliptical
## arch to the crown (tunnel_rules.gd BORE_CROWNS_U) -- the standard bore 1.0 m floor, 1.1 m at its
## widest, 1.0 m to the crown. Its normals face INWARD and its triangles are wound to face in, so drawn
## with back faces culled the near wall and the roof cull themselves from above: the U view looks down
## into the bore through the cap (underground_cap.gd), seeing its floor and far wall.
##
## RINGS stand every RING_STEP_M of route distance (4 a metre), upright, at the floor's height there, plus
## one at the dig face. Each ring is one of JITTER_VARIANTS pre-jittered copies of the profile (walls
## +-WALL_JITTER_M along their normal, the floor barely, so feet still meet it) picked by a hash of the
## ring's index, slightly widened or narrowed as well: rough, irregular, never a clean tube -- and the same
## ring always looks the same, so a rebuilt bore does not shimmer.
##
## PER VERTEX: UV holds the profile coordinate (across the floor in half-widths, up the wall in crowns),
## which the earth shader (bore_earth.gdshader) uses for the packed floor and its worn path; COLOR the
## ring's state (R flooded, G rubble; B and A spare for P5's hazards); UV2.x the game day the ring was dug
## (the drying hook: fresh walls are dark and damp, and pale over a day).
##
## SPEED. Each ring is one native Transform3D * PackedVector3Array for its points and one for its normals,
## appended whole; the quads' indices are one shared pattern sliced to length. A 32 m bore -- 129 rings,
## 2,064 vertices -- is swept in well under the 2 ms budget (a test times it headless).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const PROFILE_VERTS: int = 16
const RING_STEP_M: float = 0.25
## The floor's half-width per bore class (m), the walls' bow and where it is widest (share of the crown).
const FLOOR_HALF_M: Array[float] = [0.5, 1.0]
const BULGE: float = 1.1
const SPRING_SHARE: float = 0.45
## The hand-dug roughness: along each wall vertex's normal, on the floor, and each ring's width.
const WALL_JITTER_M: float = 0.04
const FLOOR_JITTER_M: float = 0.006
const RING_WIDTH_JITTER: float = 0.035
const JITTER_VARIANTS: int = 8
const JITTER_SEED: int = 207
## Ring colour kinds (COLOR): plain, flooded, rubble.
const PLAIN: int = 0
const FLOODED: int = 1
const RUBBLE: int = 2
const KIND_COLOURS: Array[Color] = [Color(0.0, 0.0, 0.0, 1.0), Color(1.0, 0.0, 0.0, 1.0), Color(0.0, 1.0, 0.0, 1.0)]
## The largest ring count one build holds: a 32 m bore and its face ring, with room to spare (bore_view.gd
## builds 16 m chunks). `add_ring` refuses more.
const MAX_RINGS: int = 160

## Per class: the jittered profile variants, their normals, and the profile's UVs (built once).
static var _variants: Array = []
static var _normals: Array = []
static var _uvs: PackedVector2Array = PackedVector2Array()
static var _quads: PackedInt32Array = PackedInt32Array()
static var _kind_rows: Array[PackedColorArray] = []

var _verts: PackedVector3Array = PackedVector3Array()
var _norms: PackedVector3Array = PackedVector3Array()
var _colours: PackedColorArray = PackedColorArray()
var _uv: PackedVector2Array = PackedVector2Array()
var _uv2: PackedVector2Array = PackedVector2Array()
var _indices: PackedInt32Array = PackedInt32Array()
var _day_row: PackedVector2Array = PackedVector2Array()
var _day_row_value: float = NAN
var _rings: int = 0
var _arrays: Array = []


# --- the profile ----------------------------------------------------------------------------

static func width_share(t: float) -> float:
	"""The profile's half-width at `t` crowns up, in floor half-widths: 1 on the floor, bowing out to
	BULGE at the springline, closing to 0 at the crown; -1 below the floor or over the crown, where no
	point is inside (the cap's void test uses the same shape)."""
	if t < 0.0 or t > 1.0:
		return -1.0
	if t <= SPRING_SHARE:
		return 1.0 + (BULGE - 1.0) * sin(PI * 0.5 * t / SPRING_SHARE)
	var up := (t - SPRING_SHARE) / (1.0 - SPRING_SHARE)
	return BULGE * sqrt(maxf(1.0 - up * up, 0.0))


static func profile_uv() -> PackedVector2Array:
	"""The PROFILE_VERTS profile points in normalised form (across in floor half-widths, up in crowns),
	going round from the floor's middle: across the floor to its right edge, up the right wall to the
	crown, down the left wall and back along the floor -- anticlockwise seen along the bore."""
	if not _uvs.is_empty():
		return _uvs
	var right: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(1.0, 0.0)]
	for t: float in [0.15, 0.3, SPRING_SHARE]:
		right.append(Vector2(width_share(t), t))
	for degrees: float in [30.0, 60.0]:
		var angle := deg_to_rad(degrees)
		right.append(Vector2(BULGE * cos(angle), SPRING_SHARE + (1.0 - SPRING_SHARE) * sin(angle)))
	for point: Vector2 in right:
		_uvs.append(point)
	_uvs.append(Vector2(0.0, 1.0))
	for k in range(right.size() - 1, 0, -1):
		_uvs.append(Vector2(-right[k].x, right[k].y))
	return _uvs


static func profile(bore: int) -> PackedVector3Array:
	"""The un-jittered profile of a bore class in metres, in its ring's frame: x across (right), y up
	from the floor, z = 0."""
	var out := PackedVector3Array()
	for point: Vector2 in profile_uv():
		out.append(Vector3(point.x * FLOOR_HALF_M[bore], point.y * Rules.crown_m(bore), 0.0))
	return out


static func profile_normals(points: PackedVector3Array) -> PackedVector3Array:
	"""Each profile point's inward normal: its neighbours' chord turned a quarter left (the loop runs
	anticlockwise), straight up on the floor."""
	var out := PackedVector3Array()
	var n := points.size()
	for k in n:
		var chord := points[(k + 1) % n] - points[(k - 1 + n) % n]
		var normal := Vector3(-chord.y, chord.x, 0.0).normalized()
		out.append(Vector3.UP if absf(points[k].y) < 1e-6 and k != 2 and k != n - 2 else normal)
	return out


static func _ensure_tables() -> void:
	"""The jittered variants and shared rows, built once."""
	if not _variants.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = JITTER_SEED
	for bore: int in FLOOR_HALF_M.size():
		var base := profile(bore)
		var normals := profile_normals(base)
		var variants: Array[PackedVector3Array] = []
		for v: int in JITTER_VARIANTS:
			var points := PackedVector3Array(base)
			for k in PROFILE_VERTS:
				var amount := FLOOR_JITTER_M if base[k].y < 1e-6 else WALL_JITTER_M
				points[k] += normals[k] * (rng.randf_range(-1.0, 1.0) * amount)
			variants.append(points)
		_variants.append(variants)
		_normals.append(normals)
	for colour: Color in KIND_COLOURS:
		var row := PackedColorArray()
		row.resize(PROFILE_VERTS)
		row.fill(colour)
		_kind_rows.append(row)
	_build_quads()


static func _build_quads() -> void:
	"""The index pattern of MAX_RINGS - 1 ring-to-ring bands: each quad (ring i vertex k, k + 1 and ring
	i + 1's) as two triangles wound to face inward."""
	_quads.resize((MAX_RINGS - 1) * PROFILE_VERTS * 6)
	var n := 0
	for i in MAX_RINGS - 1:
		for k in PROFILE_VERTS:
			var a := i * PROFILE_VERTS + k
			var b := i * PROFILE_VERTS + (k + 1) % PROFILE_VERTS
			for index: int in [a, a + PROFILE_VERTS, b, b, a + PROFILE_VERTS, b + PROFILE_VERTS]:
				_quads[n] = index
				n += 1


static func variant_of(ring: int) -> int:
	"""Which jittered variant ring `ring` (its index along the bore) is drawn with."""
	return (ring * 5 + (ring / JITTER_VARIANTS) * 3) % JITTER_VARIANTS


static func width_jitter(ring: int) -> float:
	"""Ring `ring`'s width, as a share of its profile's (see RINGS)."""
	return 1.0 + RING_WIDTH_JITTER * sin(float(ring) * 2.39 + 0.7)


# --- a build --------------------------------------------------------------------------------

func begin() -> void:
	"""Start a new mesh (the scratch arrays keep their capacity)."""
	_ensure_tables()
	_verts.resize(0)
	_norms.resize(0)
	_colours.resize(0)
	_uv.resize(0)
	_uv2.resize(0)
	_indices.resize(0)
	_rings = 0


func add_ring(ring: int, centre: Vector3, heading: Vector2, bore: int, kind: int, day: float) -> void:
	"""One ring: route ring index `ring` (its jitter), standing at `centre` (x, floor y, z), facing along
	`heading` (x, z unit), of class `bore`, coloured by `kind`, dug on game day `day`. Past MAX_RINGS a
	build holds no more (a warning says so)."""
	if _rings >= MAX_RINGS:
		push_warning("bore_mesh: more than %d rings in one build" % MAX_RINGS)
		return
	var side := Vector3(-heading.y, 0.0, heading.x) * width_jitter(ring)
	var frame := Transform3D(Basis(side, Vector3.UP, Vector3(heading.x, 0.0, heading.y)), centre)
	var variants: Array = _variants[bore]
	_verts.append_array(frame * (variants[variant_of(ring)] as PackedVector3Array))
	_norms.append_array(Transform3D(Basis(side.normalized(), Vector3.UP, frame.basis.z), Vector3.ZERO) * (_normals[bore] as PackedVector3Array))
	_colours.append_array(_kind_rows[kind])
	_uv.append_array(profile_uv())
	_uv2.append_array(_day_row_of(day))
	_rings += 1


func _day_row_of(day: float) -> PackedVector2Array:
	"""A ring's UV2 row for dig day `day` (reused while the day repeats)."""
	if day != _day_row_value:
		_day_row_value = day
		_day_row = PackedVector2Array()
		_day_row.resize(PROFILE_VERTS)
		_day_row.fill(Vector2(day, 0.0))
	return _day_row


func add_face(centre: Vector3, heading: Vector2, bore: int) -> void:
	"""Close the bore with a face wall at the last ring: its points again, and a hub on the bore's axis
	half a crown up, all facing back down the bore, fanned hub to rim."""
	var last := (_rings - 1) * PROFILE_VERTS
	var hub := _verts.size()
	var back := Vector3(-heading.x, 0.0, -heading.y)
	_verts.append(centre + Vector3(0.0, Rules.crown_m(bore) * 0.5, 0.0))
	_verts.append_array(_verts.slice(last, last + PROFILE_VERTS))
	for k in PROFILE_VERTS + 1:
		_norms.append(back)
	_colours.append_array(_kind_rows[PLAIN])
	_colours.append(KIND_COLOURS[PLAIN])
	_uv.append(Vector2(0.0, 0.5))
	_uv.append_array(profile_uv())
	_uv2.append_array(_uv2.slice(_uv2.size() - PROFILE_VERTS))
	_uv2.append(_uv2[_uv2.size() - 1])
	for k in PROFILE_VERTS:
		for index: int in [hub, hub + 1 + (k + 1) % PROFILE_VERTS, hub + 1 + k]:
			_indices.append(index)


func commit(mesh: ArrayMesh) -> int:
	"""Write the rings (and a face wall) as `mesh`'s one surface, replacing what it held. Returns the
	vertex count (0: nothing to draw, the mesh left empty)."""
	mesh.clear_surfaces()
	if _rings < 2:
		return 0
	var band := _quads.slice(0, (_rings - 1) * PROFILE_VERTS * 6)
	band.append_array(_indices)
	if _arrays.is_empty():
		_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = _verts
	_arrays[Mesh.ARRAY_NORMAL] = _norms
	_arrays[Mesh.ARRAY_COLOR] = _colours
	_arrays[Mesh.ARRAY_TEX_UV] = _uv
	_arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	_arrays[Mesh.ARRAY_INDEX] = band
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	return _verts.size()


func ring_count() -> int:
	"""Rings added since `begin`."""
	return _rings


static func sample_mesh() -> ArrayMesh:
	"""A two-ring bore in the builds' vertex format, for the U view's prewarm."""
	var builder: RefCounted = (load("res://demo/tunnel/bore_mesh.gd") as GDScript).new()
	builder.begin()
	for ring in 2:
		builder.add_ring(ring, Vector3(0.0, 0.0, float(ring) * RING_STEP_M), Vector2(0.0, 1.0), Rules.BORE_STANDARD, PLAIN, 0.0)
	builder.add_face(Vector3(0.0, 0.0, RING_STEP_M), Vector2(0.0, 1.0), Rules.BORE_STANDARD)
	var mesh := ArrayMesh.new()
	builder.commit(mesh)
	return mesh
