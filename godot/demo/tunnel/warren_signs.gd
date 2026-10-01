extends Node3D
## The warren, seen from the surface. Decision 0211 (the underground revamp's P5; design §2 "Living": "On the surface
## the warren shows itself: mouth arches with a lantern, air vents, turf seams over young tunnels"). Presentation only;
## on the SURFACE layer (demo_layers.gd), so the U view never draws it.
##
## TURF SEAMS. Over every tunnel's stretch under the ground (past its ramps' open cuttings) as far as it is dug -- a dig
## under way shows its seam growing behind its face -- the turf lies cut and relaid: a strip of darker, disturbed turf, ragged at its edges, as wide as the bore. It HEALS: each quarter metre of it
## fades as the grass knits over the SEAM_HEAL_DAYS after that stretch was dug (bore_view.gd's dig days, the demo
## calendar), and a healed seam is gone -- a young tunnel shows, an old one does not. A strip is rebuilt only when its
## tunnel changes or its fade has moved a SEAM_STEP, never per frame; healed and hidden, it costs nothing.
## (The tunnel overlay's old faint earth trace over an open tunnel is gone: the seam is its successor.)
##
## AIR VENTS over every open tunnel at least VENT_MIN_M long: a small dark hole in a ring of fieldstones, one for every
## VENT_SPACING_M of its stretch under the ground, evenly spaced, none within VENT_CLEAR_M of its ends or on a crop bed
## (farm_catalog.gd's beds). They stand as long as the tunnel does: one MultiMesh for every vent, placed again only when
## the network changes. (The mouths' hung lanterns are tunnel_mouth.gd's.)
##
## THE TOP LEVEL ONLY (decision 0212). Seams and vents are the signs of level 1's tunnels (`signed`): a tunnel on the
## second level, or a link down to it, lies too deep to mark the turf, and its signs are never drawn over level 1's.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Layers := preload("res://demo/demo_layers.gd")

const SEAM_HEAL_DAYS: float = 3.0
## A seam is redrawn when its fade has moved this much (a share of fully fresh).
const SEAM_STEP: float = 0.05
const SEAM_LIFT_M: float = 0.028
const SEAM_ALPHA: float = 0.85
const SEAM_TURF: Color = Color(0.25, 0.28, 0.14)
const SEAM_SOIL: Color = Color(0.3, 0.22, 0.15)
const SEAM_STEP_M: float = BoreMeshScript.RING_STEP_M
const VENT_MIN_M: float = 6.0
const VENT_SPACING_M: float = 5.0
const VENT_CLEAR_M: float = 1.5
const MAX_VENTS: int = 160
## A quad's two triangles over its corners (left and right at its near end, then at its far end).
const QUAD_ORDER: PackedInt32Array = [0, 3, 1, 0, 2, 3]
const VENT_STONE: Color = Color(0.5, 0.48, 0.43)
const VENT_HOLE: Color = Color(0.05, 0.04, 0.03)

var _network: GraphScript = null
var _bores: BoreViewScript = null
var _seams: Array[MeshInstance3D] = []
## Per segment: the key its seam was drawn for (-1: none drawn), and how fresh it was then (0 healed .. 1 fresh).
var _seam_key: PackedInt64Array = PackedInt64Array()
var _seam_fresh: PackedFloat32Array = PackedFloat32Array()
## Per segment: the last day any of it was dug, read when its key changed.
var _newest: PackedFloat32Array = PackedFloat32Array()
var _vents: MultiMeshInstance3D = null
var _vents_seen: int = -1
var _material: StandardMaterial3D = null
var _verts: PackedVector3Array = PackedVector3Array()
var _colours: PackedColorArray = PackedColorArray()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
## Scratch for a seam's build, kept between builds: a quad's corners, the normals (all up), the mesh arrays.
var _corners: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
var _normals: PackedVector3Array = PackedVector3Array()
var _arrays: Array = []
## Seam builds so far (checks: nothing is rebuilt while nothing changes).
var seam_builds: int = 0


func configure(network: GraphScript, bores: BoreViewScript) -> void:
	"""Show this network's warren on the surface, its dig days read from `bores`. A seam node per segment and the vents'
	MultiMesh, made once, hidden."""
	name = "WarrenSigns"
	_network = network
	_bores = bores
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.roughness = 1.0
	_material.render_priority = 1
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_seam_key.resize(Rules.MAX_SEGMENTS)
	_seam_key.fill(-1)
	_seam_fresh.resize(Rules.MAX_SEGMENTS)
	_newest.resize(Rules.MAX_SEGMENTS)
	for slot in Rules.MAX_SEGMENTS:
		var seam := MeshInstance3D.new()
		seam.mesh = ArrayMesh.new()
		seam.material_override = _material
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seam.layers = Layers.SURFACE
		seam.visible = false
		add_child(seam)
		_seams.append(seam)
	_arrays.resize(Mesh.ARRAY_MAX)
	_vents = _vent_node()


func _vent_node() -> MultiMeshInstance3D:
	"""The vents' MultiMesh: up to MAX_VENTS of the vent mesh, none shown yet."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = vent_mesh()
	multimesh.instance_count = MAX_VENTS
	multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.layers = Layers.SURFACE
	add_child(node)
	return node


static func vent_mesh() -> ArrayMesh:
	"""An air vent: a dark hole (a disc just over the ground) in a ring of eight low fieldstones."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hole := CylinderMesh.new()
	hole.top_radius = 0.11
	hole.bottom_radius = 0.11
	hole.height = 0.02
	hole.radial_segments = 12
	_coloured(tool, hole, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.012, 0.0)), VENT_HOLE)
	for k in 8:
		var angle := TAU * float(k) / 8.0 + 0.2 * sin(float(k) * 2.3)
		var stone := BoxMesh.new()
		stone.size = Vector3(0.1 + 0.02 * sin(float(k) * 1.7), 0.06, 0.08)
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 0.17 + Vector3(0.0, 0.025, 0.0)
		_coloured(tool, stone, Transform3D(Basis(Vector3.UP, -angle), at), VENT_STONE.darkened(0.12 * float(k % 3)))
	tool.generate_normals()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	mesh.surface_set_material(0, material)
	return mesh


static func _coloured(tool: SurfaceTool, mesh: PrimitiveMesh, at: Transform3D, colour: Color) -> void:
	"""One primitive into `tool`, placed by `at`, every vertex `colour`."""
	var arrays := mesh.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in indices:
		tool.set_color(colour)
		tool.add_vertex(at * points[index])


func seam(slot: int) -> MeshInstance3D:
	"""Segment `slot`'s turf seam (checks)."""
	return _seams[slot]


func vents() -> MultiMeshInstance3D:
	"""The vents (checks)."""
	return _vents


# --- each frame ---------------------------------------------------------------------------------------

func refresh() -> void:
	"""Redraw each seam whose tunnel changed or whose fade moved a SEAM_STEP, and place the vents again when the
	network changed."""
	var today := _bores.today()
	for slot in Rules.MAX_SEGMENTS:
		_refresh_seam(slot, today)
	if _network.revision != _vents_seen:
		_vents_seen = _network.revision
		_place_vents()


func _refresh_seam(slot: int, today: float) -> void:
	"""Segment `slot`'s seam, redrawn when its key or its freshness moved (see TURF SEAMS)."""
	var key := seam_key(slot)
	if key < 0:
		if _seam_key[slot] >= 0:
			_seam_key[slot] = -1
			_seams[slot].visible = false
		return
	if key != _seam_key[slot]:
		_newest[slot] = _last_dug(slot)
	var fresh := freshness(today - _newest[slot])
	if key == _seam_key[slot] and absf(fresh - _seam_fresh[slot]) < SEAM_STEP and (fresh > 0.0) == _seams[slot].visible:
		return
	_seam_key[slot] = key
	_seam_fresh[slot] = fresh
	_seams[slot].visible = fresh > 0.0
	if fresh > 0.0:
		_build_seam(slot, today)


func signed(slot: int) -> bool:
	"""Whether segment `slot` shows on the surface (see THE TOP LEVEL ONLY): a tunnel on level 1, not a link."""
	return _network.is_tunnel(slot) and _network.seg_level[slot] == Rules.TOP_LEVEL \
			and _network.seg_kind[slot] != GraphScript.SEG_LINK


func seam_key(slot: int) -> int:
	"""What a segment's seam depends on but its age, as one number (-1: no seam -- no tunnel, or none of it dug): its
	generation, class, length and how far it is dug, by SEAM_STEP_M."""
	if not signed(slot) or _network.done(slot) <= 0:
		return -1
	var steps := floori(dug_m(slot) / SEAM_STEP_M)
	return ((_network.generation[slot] * 4 + int(_network.bore[slot])) * 65536 + _network.length_u[slot]) * 256 + steps % 256


func dug_m(slot: int) -> float:
	"""How much of segment `slot` is dug (m): all of it once open, else to its face."""
	return _network.length_m(slot) if _network.is_open(slot) else _network.face_m(slot)


static func freshness(age_days: float) -> float:
	"""How fresh a seam dug `age_days` ago is: 1 new, fading to 0 -- healed -- at SEAM_HEAL_DAYS."""
	return clampf(1.0 - age_days / SEAM_HEAL_DAYS, 0.0, 1.0)


func _last_dug(slot: int) -> float:
	"""The last day any of segment `slot`'s stretch was dug (its freshest step)."""
	var newest := -INF
	for step in floori(_network.length_m(slot) / SEAM_STEP_M) + 1:
		newest = maxf(newest, _bores.dug_day(slot, step))
	return newest


func _stretch(slot: int) -> Vector2:
	"""The stretch of segment `slot` under the ground and dug (m along it): past a ramp's open cutting, up to its face."""
	var length := _network.length_m(slot)
	var dug := dug_m(slot)
	if _network.seg_kind[slot] != GraphScript.SEG_RAMP:
		return Vector2(0.0, dug)
	var portal := minf(Rules.portal_m(int(_network.bore[slot])), length)
	return Vector2(0.0, minf(length - portal, dug)) if _network.mouth_end_at_b(slot) else Vector2(portal, maxf(dug, portal))


func _build_seam(slot: int, today: float) -> void:
	"""Segment `slot`'s seam as a strip along its drawn centreline over its stretch under the ground, each quarter
	metre's turf as fresh as the day it was dug (see TURF SEAMS)."""
	var span := _stretch(slot)
	var half := BoreMeshScript.FLOOR_HALF_M[int(_network.bore[slot])] * 0.95
	var curve := BoreCurveScript.of(_network, slot)
	_verts.resize(0)
	_colours.resize(0)
	var along := span.x
	while along < span.y - 0.01:
		var next := minf(along + SEAM_STEP_M, span.y)
		var fresh := freshness(today - _bores.dug_day(slot, floori(along / SEAM_STEP_M)))
		_seam_quad(curve, along, next, half, fresh)
		along = next
	var mesh := _seams[slot].mesh as ArrayMesh
	mesh.clear_surfaces()
	if _verts.is_empty():
		return
	if _normals.size() != _verts.size():
		_normals.resize(_verts.size())
		_normals.fill(Vector3.UP)
	_arrays[Mesh.ARRAY_VERTEX] = _verts
	_arrays[Mesh.ARRAY_COLOR] = _colours
	_arrays[Mesh.ARRAY_NORMAL] = _normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	seam_builds += 1


func _seam_quad(curve: BoreCurveScript, from_m: float, to_m: float, half: float, fresh: float) -> void:
	"""One quarter metre of seam from `from_m` to `to_m`: its edges ragged (a repeatable wobble by the distance along),
	its turf `fresh` -- darker soil showing through when new, alpha fading as it heals."""
	_seam_end(curve, from_m, half, 0)
	_seam_end(curve, to_m, half, 2)
	var colour := SEAM_TURF.lerp(SEAM_SOIL, fresh * 0.7)
	colour.a = SEAM_ALPHA * sqrt(fresh)
	for k in QUAD_ORDER:
		_verts.append(_corners[k])
		_colours.append(colour)


func _seam_end(curve: BoreCurveScript, at: float, half: float, first: int) -> void:
	"""The seam's two edge corners `at` metres along, wobbled, into _corners[first] (left) and [first + 1] (right)."""
	curve.sample(at, _sample)
	var across := Vector2(-_sample[1].y, _sample[1].x) * half * (1.0 + 0.16 * sin(at * 7.3) + 0.09 * sin(at * 17.9 + 1.1))
	_corners[first] = Vector3(_sample[0].x - across.x, SEAM_LIFT_M, _sample[0].y - across.y)
	_corners[first + 1] = Vector3(_sample[0].x + across.x, SEAM_LIFT_M, _sample[0].y + across.y)


# --- the vents ---------------------------------------------------------------------------------------

func _place_vents() -> void:
	"""Every open tunnel's vents (see AIR VENTS)."""
	var count := 0
	for slot in Rules.MAX_SEGMENTS:
		if not signed(slot) or not _network.is_open(slot) or _network.length_m(slot) < VENT_MIN_M:
			continue
		var span := _stretch(slot)
		var usable := span.y - span.x - 2.0 * VENT_CLEAR_M
		var n := maxi(floori(usable / VENT_SPACING_M) + 1, 0) if usable >= 0.0 else 0
		for k in n:
			var along := span.x + VENT_CLEAR_M + usable * (float(k) + 0.5) / float(n)
			BoreCurveScript.of(_network, slot).sample(along, _sample)
			if count < MAX_VENTS and not on_crop_bed(_sample[0]):
				_vents.multimesh.set_instance_transform(count, Transform3D(Basis(Vector3.UP, along * 1.7), Vector3(_sample[0].x, 0.0, _sample[0].y)))
				count += 1
	_vents.multimesh.visible_instance_count = count


static func on_crop_bed(at: Vector2) -> bool:
	"""Whether `at` (x, z m) lies on a crop bed or within a hand of one (farm_catalog.gd's beds)."""
	for bed in Catalog.BED_COUNT:
		var d := (at - Catalog.bed_centre_m(bed)).abs()
		if d.x <= Catalog.BED_HALF_M + 0.3 and d.y <= Catalog.BED_HALF_M + 0.3:
			return true
	return false


func vent_count() -> int:
	"""How many vents stand (checks)."""
	return _vents.multimesh.visible_instance_count


func sample_into(parent: Node3D) -> void:
	"""One of each piece drawn on the ground -- a seam's quad in its material, a vent -- under `parent`, for the rooms'
	ground prewarm (room_view.gd `begin_surface_prewarm`)."""
	var seam_sample := MeshInstance3D.new()
	seam_sample.mesh = _seams[0].mesh if (_seams[0].mesh as ArrayMesh).get_surface_count() > 0 else QuadMesh.new()
	seam_sample.material_override = _material
	parent.add_child(seam_sample)
	var vent := MeshInstance3D.new()
	vent.mesh = _vents.multimesh.mesh
	parent.add_child(vent)
	var multi := MultiMeshInstance3D.new()
	multi.multimesh = MultiMesh.new()
	multi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multi.multimesh.mesh = _vents.multimesh.mesh
	multi.multimesh.instance_count = 1
	parent.add_child(multi)
