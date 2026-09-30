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
## (the drying hook: fresh walls are dark and damp, and pale over a day); CUSTOM0 and CUSTOM1 the hubs at
## the segment's two ends (decision 0208: x, z, floor radius, crown; 0 radius for none), constant over the
## mesh, inside which the shader draws nothing -- the hub (`build_hub`) draws there instead.
##
## THE JOIN (decision 0208). Where segments meet at a node the jitter fades out: a ring within CLEAN_M of an
## end at a node underground is the clean profile, one within 2 x CLEAN_M half-jittered (`add_ring`'s
## `jitter`), so two segments meeting in line at a ramp's foot end on the same ring, and a bore meets its
## junction's hub exactly on the hub's surface.
##
## HUBS (`build_hub`): a lathe of the same horseshoe round a junction, HUB_SECTORS round, its floor a disc,
## faces inward; CUSTOM0 its centre and crown, CUSTOM1..3 the angle, floor half-width and crown of each bore
## that opens into it (up to four), so hub_earth.gdshader leaves the wall out where a bore opens.
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
## Jitter levels for a ring (see THE JOIN), and how near an underground end they apply (m).
const JITTER_FULL: int = 2
const JITTER_HALF: int = 1
const JITTER_NONE: int = 0
const CLEAN_M: float = 0.5
## A hub's floor radius per unit of its widest bore's floor half-width (demo: the design's 1.2 left only slivers of
## wall between four openings; decision 0208), and its lathe's sectors.
const HUB_SCALE: float = 1.5
const HUB_SECTORS: int = 32
const HUB_OPENINGS: int = 4
const CUSTOM_FORMAT: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const HUB_FORMAT: int = CUSTOM_FORMAT | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)

## Per class and jitter level: the jittered profile variants (JITTER_NONE: the clean profile once), their
## normals, and the profile's UVs (built once).
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
var _custom_a: PackedFloat32Array = PackedFloat32Array()
var _custom_b: PackedFloat32Array = PackedFloat32Array()
var _cut_a: Vector4 = Vector4.ZERO
var _cut_b: Vector4 = Vector4.ZERO


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
		var full: Array[PackedVector3Array] = []
		var half: Array[PackedVector3Array] = []
		for v: int in JITTER_VARIANTS:
			var offsets := PackedFloat32Array()
			for k in PROFILE_VERTS:
				offsets.append(rng.randf_range(-1.0, 1.0) * (FLOOR_JITTER_M if base[k].y < 1e-6 else WALL_JITTER_M))
			full.append(_jittered(base, normals, offsets, 1.0))
			half.append(_jittered(base, normals, offsets, 0.5))
		_variants.append([[base], half, full])
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


static func _jittered(base: PackedVector3Array, normals: PackedVector3Array, offsets: PackedFloat32Array,
		share: float) -> PackedVector3Array:
	"""The profile with each point moved `share` of its offset along its normal."""
	var points := PackedVector3Array(base)
	for k in PROFILE_VERTS:
		points[k] += normals[k] * (offsets[k] * share)
	return points


static func variant_of(ring: int) -> int:
	"""Which jittered variant ring `ring` (its index along the bore) is drawn with."""
	return (ring * 5 + (ring / JITTER_VARIANTS) * 3) % JITTER_VARIANTS


static func width_jitter(ring: int, jitter: int = JITTER_FULL) -> float:
	"""Ring `ring`'s width, as a share of its profile's (see RINGS), at jitter level `jitter` (see THE JOIN)."""
	return 1.0 + RING_WIDTH_JITTER * sin(float(ring) * 2.39 + 0.7) * float(jitter) / float(JITTER_FULL)


static func jitter_at(along: float, length: float, clean_a: bool, clean_b: bool) -> int:
	"""The jitter level for a ring `along` metres into a segment `length` long whose node A (B) is
	underground when `clean_a` (`clean_b`): see THE JOIN."""
	var near := INF
	if clean_a:
		near = along
	if clean_b:
		near = minf(near, length - along)
	if near < CLEAN_M:
		return JITTER_NONE
	return JITTER_HALF if near < 2.0 * CLEAN_M else JITTER_FULL


# --- a build --------------------------------------------------------------------------------

func begin(cut_a: Vector4 = Vector4.ZERO, cut_b: Vector4 = Vector4.ZERO) -> void:
	"""Start a new mesh (the scratch arrays keep their capacity), inside the hubs `cut_a` and `cut_b` at its
	ends draws nothing (see PER VERTEX)."""
	_ensure_tables()
	_cut_a = cut_a
	_cut_b = cut_b
	_verts.resize(0)
	_norms.resize(0)
	_colours.resize(0)
	_uv.resize(0)
	_uv2.resize(0)
	_indices.resize(0)
	_rings = 0


func add_ring(ring: int, centre: Vector3, heading: Vector2, bore: int, kind: int, day: float,
		jitter: int = JITTER_FULL) -> void:
	"""One ring: route ring index `ring` (its jitter), standing at `centre` (x, floor y, z), facing along
	`heading` (x, z unit), of class `bore`, coloured by `kind`, dug on game day `day`, at jitter level
	`jitter` (see THE JOIN). Past MAX_RINGS a build holds no more (a warning says so)."""
	if _rings >= MAX_RINGS:
		push_warning("bore_mesh: more than %d rings in one build" % MAX_RINGS)
		return
	var side := Vector3(-heading.y, 0.0, heading.x) * width_jitter(ring, jitter)
	var frame := Transform3D(Basis(side, Vector3.UP, Vector3(heading.x, 0.0, heading.y)), centre)
	var variants: Array = _variants[bore][jitter]
	_verts.append_array(frame * (variants[variant_of(ring) % variants.size()] as PackedVector3Array))
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
	_fill_custom(_custom_a, _cut_a, _verts.size())
	_fill_custom(_custom_b, _cut_b, _verts.size())
	_arrays[Mesh.ARRAY_CUSTOM0] = _custom_a
	_arrays[Mesh.ARRAY_CUSTOM1] = _custom_b
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays, [], {}, CUSTOM_FORMAT)
	return _verts.size()


static func _fill_custom(column: PackedFloat32Array, value: Vector4, count: int) -> void:
	"""A custom channel holding `value` at each of `count` vertices."""
	column.resize(count * 4)
	for i in count:
		column[4 * i] = value.x
		column[4 * i + 1] = value.y
		column[4 * i + 2] = value.z
		column[4 * i + 3] = value.w


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


# --- hubs (decision 0208) -------------------------------------------------------------------

static func hub_rows() -> PackedVector2Array:
	"""The hub's wall profile (see HUBS): the horseshoe's right half, floor edge to crown, in (floor
	half-widths out, crowns up)."""
	var rows := PackedVector2Array()
	var uv := profile_uv()
	for k in range(2, PROFILE_VERTS / 2 + 1):
		rows.append(uv[k])
	return rows


static func build_hub(mesh: ArrayMesh, centre: Vector3, floor_radius: float, crown: float, openings: PackedFloat32Array,
		day: float) -> int:
	"""Write a junction's hub (see HUBS) as `mesh`'s one surface, replacing what it held: centred at `centre`
	(on the level's floor), its floor `floor_radius` out and its crown `crown` up, the bores opening into it
	as `openings` -- (angle of its way out in (x, z), atan2(z, x); floor half-width; crown) each, up to
	HUB_OPENINGS. Returns the vertex count."""
	mesh.clear_surfaces()
	var hub := HubArrays.new()
	_hub_wall(hub, centre, floor_radius, crown, day)
	_hub_floor(hub, centre, floor_radius, day)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = hub.verts
	arrays[Mesh.ARRAY_NORMAL] = hub.norms
	arrays[Mesh.ARRAY_TEX_UV] = hub.uv
	arrays[Mesh.ARRAY_TEX_UV2] = hub.uv2
	arrays[Mesh.ARRAY_COLOR] = _plain_colours(hub.verts.size())
	arrays[Mesh.ARRAY_INDEX] = hub.indices
	_hub_custom(arrays, Vector3(centre.x, floor_radius, centre.z), crown, openings, hub.verts.size())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, HUB_FORMAT)
	return hub.verts.size()


## A hub's arrays while it is built.
class HubArrays extends RefCounted:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	func add(at: Vector3, normal: Vector3, profile_at: Vector2, day_side: Vector2) -> void:
		"""One vertex: its place, normal, profile coordinate and (dig day, wall 1 / floor 0)."""
		verts.append(at)
		norms.append(normal)
		uv.append(profile_at)
		uv2.append(day_side)

	func facing_tri(a: int, b: int, c: int) -> void:
		"""Triangle a, b, c wound so its front faces the way its vertices' normals point (Godot's front face:
		cross(b - a, c - a) points away from the viewer, as the bore's quads are wound)."""
		var cross := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if cross.dot(norms[a] + norms[b] + norms[c]) > 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])


static func _hub_wall(hub: HubArrays, centre: Vector3, floor_radius: float, crown: float, day: float) -> void:
	"""The hub's wall: every profile row round HUB_SECTORS angles (a seam column repeated to close it), its
	normals inward, its triangles wound to face in."""
	var rows := hub_rows()
	var row_normals := _row_normals(rows, floor_radius, crown)
	for r in rows.size():
		for sector in HUB_SECTORS + 1:
			var angle := TAU * float(sector) / float(HUB_SECTORS)
			var out := Vector3(cos(angle), 0.0, sin(angle))
			hub.add(centre + out * (rows[r].x * floor_radius) + Vector3.UP * (rows[r].y * crown),
				(out * row_normals[r].x + Vector3.UP * row_normals[r].y).normalized(), rows[r], Vector2(day, 1.0))
	for r in rows.size() - 1:
		for sector in HUB_SECTORS:
			var a := r * (HUB_SECTORS + 1) + sector
			hub.facing_tri(a, a + HUB_SECTORS + 1, a + 1)
			hub.facing_tri(a + 1, a + HUB_SECTORS + 1, a + HUB_SECTORS + 2)


static func _row_normals(rows: PackedVector2Array, floor_radius: float, crown: float) -> PackedVector2Array:
	"""Each wall row's inward normal in (out, up) at the hub's own size: its neighbours' chord, going up the
	wall, turned a quarter toward the axis."""
	var out := PackedVector2Array()
	var size := Vector2(floor_radius, crown)
	for r in rows.size():
		var chord := (rows[mini(r + 1, rows.size() - 1)] - rows[maxi(r - 1, 0)]) * size
		out.append(Vector2(-chord.y, chord.x).normalized())
	return out


static func _hub_floor(hub: HubArrays, centre: Vector3, floor_radius: float, day: float) -> void:
	"""The hub's floor: a disc fanned from its centre, facing up."""
	var first := hub.verts.size()
	hub.add(centre, Vector3.UP, Vector2.ZERO, Vector2(day, 0.0))
	for sector in HUB_SECTORS:
		var angle := TAU * float(sector) / float(HUB_SECTORS)
		hub.add(centre + Vector3(cos(angle), 0.0, sin(angle)) * floor_radius, Vector3.UP, Vector2(1.0, 0.0), Vector2(day, 0.0))
	for sector in HUB_SECTORS:
		hub.facing_tri(first, first + 1 + sector, first + 1 + (sector + 1) % HUB_SECTORS)


static func _plain_colours(count: int) -> PackedColorArray:
	"""COLOR for `count` plain vertices."""
	var out := PackedColorArray()
	out.resize(count)
	out.fill(KIND_COLOURS[PLAIN])
	return out


static func _hub_custom(arrays: Array, centre_radius: Vector3, crown: float, openings: PackedFloat32Array, count: int) -> void:
	"""The hub's custom channels (see HUBS): centre and crown; the openings' angles, half-widths and crowns."""
	var channels: Array[Vector4] = [Vector4(centre_radius.x, centre_radius.z, centre_radius.y, crown), Vector4.ZERO,
		Vector4.ZERO, Vector4.ZERO]
	for k in mini(openings.size() / 3, HUB_OPENINGS):
		for c in 3:
			channels[1 + c][k] = openings[3 * k + c]
	for c in 4:
		var column := PackedFloat32Array()
		_fill_custom(column, channels[c], count)
		arrays[Mesh.ARRAY_CUSTOM0 + c] = column


static func sample_hub() -> ArrayMesh:
	"""A hub in the builds' vertex format, for the U view's prewarm."""
	var mesh := ArrayMesh.new()
	build_hub(mesh, Vector3.ZERO, FLOOR_HALF_M[Rules.BORE_STANDARD] * HUB_SCALE, Rules.crown_m(Rules.BORE_STANDARD),
		PackedFloat32Array([0.0, FLOOR_HALF_M[Rules.BORE_STANDARD], Rules.crown_m(Rules.BORE_STANDARD)]), 0.0)
	return mesh
