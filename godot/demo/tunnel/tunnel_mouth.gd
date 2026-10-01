extends RefCounted
## A tunnel's mouth on the surface: a fieldstone-and-timber gateway over the top of its ramp, and the
## ramp's cutting running down into the dark. Decision 0207 (the underground revamp's P1; design
## docs/design/underground_revamp.md §3 "Surface entrances": a timber-and-fieldstone arch). Presentation
## only; procedural until P7 swaps in the generated `tunnel_arch` prop (its doorway is a solid slab today).
##
## In the mouth's own frame +Z runs down the ramp, into the tunnel, and X across it:
##   * THE GATEWAY stands on the ground at the mouth, astride the ramp: two jambs of JAMB_COURSES rough
##     fieldstones each (jittered sizes and tones, repeatably), OPENING_M apart, and a timber lintel
##     across their tops at GATE_HEIGHT_M -- a mouse walks under it upright -- and, since P5 (decision 0211; design
##     §2 "mouth arches with a lantern"), a LANTERN hung from an iron bracket on the lintel's outer face, beside a
##     jamb, clear of the way through: an iron cage round a glowing glass (the mesh's second surface, emissive),
##     so a mouth reads as the warren's door by day and a small light by night.
##   * THE CUTTING is a unit strip along +Z (scaled to the ramp's open length: to where the bore goes under
##     the ground, tunnel_rules.gd portal_m) laid just over the ground, packed earth at the top shading to
##     black where the ramp goes under, with a low earthen bank either side.
## Both are built once and shared by every mouth (built at boot, so their pipelines compile then).

const GATE_HEIGHT_M: float = 1.3
const OPENING_M: float = 1.2
const JAMB_WIDTH_M: float = 0.32
const JAMB_DEPTH_M: float = 0.34
const JAMB_COURSES: int = 5
const LINTEL_M: Vector3 = Vector3(2.05, 0.19, 0.24)
const CUT_WIDTH_M: float = 1.1
const BANK_WIDTH_M: float = 0.22
const BANK_HEIGHT_M: float = 0.07
const LIFT_M: float = 0.05
const STONE_TONES: Array[Color] = [Color(0.52, 0.5, 0.46), Color(0.44, 0.42, 0.38), Color(0.6, 0.57, 0.5), Color(0.38, 0.36, 0.33)]
const TIMBER: Color = Color(0.36, 0.24, 0.14)
const CUT_TOP: Color = Color(0.25, 0.18, 0.12)
const CUT_BOTTOM: Color = Color(0.03, 0.025, 0.02)
const BANK: Color = Color(0.33, 0.25, 0.17)
const SEED: int = 2073
## The lantern: its bracket's reach out from the lintel's face, where it hangs across (m from the middle), its chain,
## its cage and glass, and its glow.
const LANTERN_X_M: float = 0.4
const BRACKET_REACH_M: float = 0.2
const CHAIN_M: float = 0.08
const CAGE_M: Vector3 = Vector3(0.18, 0.27, 0.18)
const IRON: Color = Color(0.16, 0.14, 0.12)
const LANTERN_GLOW: Color = Color(1.0, 0.66, 0.3)
const GLOW_ENERGY: float = 1.8

static var _gate: ArrayMesh = null
static var _cut: ArrayMesh = null


static func gateway_mesh() -> ArrayMesh:
	"""THE gateway (see the header), shared."""
	if _gate != null:
		return _gate
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for side: float in [-1.0, 1.0]:
		_jamb(tool, rng, side * (OPENING_M + JAMB_WIDTH_M) * 0.5)
	var lintel := Basis.from_euler(Vector3(0.0, 0.0, 0.025)).scaled(LINTEL_M)
	_box(tool, Transform3D(lintel, Vector3(0.0, GATE_HEIGHT_M + LINTEL_M.y * 0.5, 0.0)), TIMBER)
	_lantern_iron(tool)
	_gate = tool.commit()
	_gate.surface_set_material(0, _material())
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(glass, Transform3D(Basis.from_scale(CAGE_M * Vector3(0.78, 0.7, 0.78)), lantern_at()), LANTERN_GLOW)
	glass.commit(_gate)
	_gate.surface_set_material(1, _glow_material())
	return _gate


static func lantern_at() -> Vector3:
	"""The middle of the mouth's hung lantern, in the gateway's frame (outward is -Z)."""
	var face := -(LINTEL_M.z * 0.5 + BRACKET_REACH_M)
	return Vector3(LANTERN_X_M, GATE_HEIGHT_M - CHAIN_M - CAGE_M.y * 0.5, face)


static func _lantern_iron(tool: SurfaceTool) -> void:
	"""The lantern's iron: a bracket out from the lintel's face, a chain down, a cap and a base round the glass."""
	var at := lantern_at()
	var face := -LINTEL_M.z * 0.5
	var arm_mid := Vector3(LANTERN_X_M, GATE_HEIGHT_M + 0.06, (face + at.z) * 0.5)
	_box(tool, Transform3D(Basis.from_scale(Vector3(0.025, 0.025, BRACKET_REACH_M)), arm_mid), IRON)
	_box(tool, Transform3D(Basis.from_scale(Vector3(0.015, CHAIN_M + 0.06, 0.015)), Vector3(at.x, GATE_HEIGHT_M - CHAIN_M * 0.5 + 0.03, at.z)), IRON)
	for y: float in [CAGE_M.y * 0.5, -CAGE_M.y * 0.5]:
		_box(tool, Transform3D(Basis.from_scale(Vector3(CAGE_M.x, 0.025, CAGE_M.z)), at + Vector3(0.0, y, 0.0)), IRON)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var post := at + Vector3(corner.x * CAGE_M.x * 0.45, 0.0, corner.y * CAGE_M.z * 0.45)
		_box(tool, Transform3D(Basis.from_scale(Vector3(0.018, CAGE_M.y, 0.018)), post), IRON)


static func _glow_material() -> StandardMaterial3D:
	"""The hung lantern's glass: its glow, lit from within."""
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.emission_enabled = true
	material.emission = LANTERN_GLOW
	material.emission_energy_multiplier = GLOW_ENERGY
	return material


static func _jamb(tool: SurfaceTool, rng: RandomNumberGenerator, x: float) -> void:
	"""One jamb: JAMB_COURSES rough stones stacked to the lintel, each a little off square."""
	var course := GATE_HEIGHT_M / float(JAMB_COURSES)
	for k in JAMB_COURSES:
		var size := Vector3(JAMB_WIDTH_M * rng.randf_range(0.9, 1.12), course * rng.randf_range(0.9, 1.0), JAMB_DEPTH_M * rng.randf_range(0.85, 1.1))
		var turn := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.05)))
		var at := Vector3(x + rng.randf_range(-0.025, 0.025), course * (float(k) + 0.5), rng.randf_range(-0.02, 0.02))
		_box(tool, Transform3D(turn.scaled(size), at), STONE_TONES[rng.randi() % STONE_TONES.size()])


static func _box(tool: SurfaceTool, xform: Transform3D, colour: Color) -> void:
	"""A unit box put by `xform`, in one colour, into `tool`."""
	var arrays := BoxMesh.new().get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xform.basis.inverse().transposed()
	for index: int in indices:
		tool.set_color(colour)
		tool.set_normal((normal_basis * normals[index]).normalized())
		tool.add_vertex(xform * points[index])


static func cutting_mesh() -> ArrayMesh:
	"""THE cutting, a unit long along +Z (see the header), shared."""
	if _cut != null:
		return _cut
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := CUT_WIDTH_M * 0.5
	_quad(tool, [Vector3(-half, LIFT_M, 0.0), Vector3(half, LIFT_M, 0.0), Vector3(half, LIFT_M, 1.0), Vector3(-half, LIFT_M, 1.0)],
		[CUT_TOP, CUT_TOP, CUT_BOTTOM, CUT_BOTTOM])
	for side: float in [-1.0, 1.0]:
		var inner := side * half
		var crest := side * (half + BANK_WIDTH_M * 0.4)
		var outer := side * (half + BANK_WIDTH_M)
		for band: Array in [[inner, LIFT_M, crest, LIFT_M + BANK_HEIGHT_M], [crest, LIFT_M + BANK_HEIGHT_M, outer, 0.0]]:
			_bank(tool, band, side)
	tool.generate_normals()
	_cut = tool.commit()
	_cut.surface_set_material(0, _material())
	return _cut


static func _bank(tool: SurfaceTool, band: Array, side: float) -> void:
	"""One slope of a bank along the cutting: from (x0, y0) to (x1, y1) across, the whole length."""
	var a := Vector3(band[0], band[1], 0.0)
	var b := Vector3(band[2], band[3], 0.0)
	var corners := [a, b, b + Vector3(0.0, 0.0, 1.0), a + Vector3(0.0, 0.0, 1.0)]
	if side < 0.0:
		corners = [b, a, a + Vector3(0.0, 0.0, 1.0), b + Vector3(0.0, 0.0, 1.0)]
	_quad(tool, corners, [BANK, BANK, BANK.darkened(0.3), BANK.darkened(0.3)])


static func _quad(tool: SurfaceTool, corners: Array, colours: Array) -> void:
	"""Two triangles over four corners, wound clockwise seen from above (Godot's front face, facing up)."""
	for k: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(colours[k])
		tool.add_vertex(corners[k])


static func _material() -> StandardMaterial3D:
	"""Rough, coloured by its vertices."""
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	return material
