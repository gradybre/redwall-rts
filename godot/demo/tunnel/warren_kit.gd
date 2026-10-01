extends RefCounted
## The construction theatre's props, procedural. Decision 0211 (the underground revamp's P5). Presentation only.
##
##   * THE HAND LANTERN a digger sets down beside it at the face: an iron base and cap on four posts round a warm
##     glass with a candle's glow, a ring to carry it by, 0.2 m tall -- a stand-in until P7's generated hand candle
##     lantern (decision 0204).
##   * THE HAULING BASKET: a woven, flared basket with a rim and two grips, and a heap of damp spoil in it (`load`: the
##     heap's height, 0..1), drawn at a filler's feet and carried between a hauler's hands (haul_view.gd).
## Each is a few shared meshes and materials, built once, registered for the U view's prewarm (`register`).

const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")

const IRON: Color = Color(0.17, 0.15, 0.13)
const GLASS: Color = Color(1.0, 0.8, 0.5)
const GLASS_ENERGY: float = 2.6
const WICKER: Color = Color(0.56, 0.41, 0.23)
const WICKER_DARK: Color = Color(0.4, 0.28, 0.15)
const SPOIL: Color = Color(0.24, 0.18, 0.13)
## The lantern's height, and where its glass's middle stands (m).
const LANTERN_TALL_M: float = 0.2
const GLASS_MID_M: float = 0.085
## The basket: its bottom and top radii and height (m); its spoil heaps this far over the rim when full.
const BASKET_BOTTOM_M: float = 0.15
const BASKET_TOP_M: float = 0.21
const BASKET_TALL_M: float = 0.22
const SPOIL_OVER_M: float = 0.07

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func material(colour: Color, energy: float = 0.0) -> StandardMaterial3D:
	"""A lit, rough material of `colour` (glowing `energy` times it when over 0), one per pair, shared."""
	var key := "%s|%s" % [colour.to_html(), energy]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = colour
		made.roughness = 0.95
		if energy > 0.0:
			made.emission_enabled = true
			made.emission = colour
			made.emission_energy_multiplier = energy
		_materials[key] = made
	return _materials[key]


static func _append(tool: SurfaceTool, mesh: PrimitiveMesh, at: Transform3D) -> void:
	"""One primitive into `tool`, placed by `at`."""
	tool.append_from(mesh, 0, at)


static func _cylinder(bottom: float, top: float, tall: float, sides: int = 10) -> CylinderMesh:
	"""A cylinder (a cone when the radii differ) for building with."""
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom
	cylinder.top_radius = top
	cylinder.height = tall
	cylinder.radial_segments = sides
	cylinder.rings = 1
	return cylinder


# --- the hand lantern ---------------------------------------------------------------------------

static func hand_lantern() -> ArrayMesh:
	"""THE HAND LANTERN (see the header), its base on the floor at its origin: the iron, then the glowing glass."""
	if _meshes.has("lantern"):
		return _meshes["lantern"]
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(iron, _cylinder(0.058, 0.058, 0.022), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.011, 0.0)))
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var post := BoxMesh.new()
		post.size = Vector3(0.012, 0.13, 0.012)
		_append(iron, post, Transform3D(Basis.IDENTITY, Vector3(corner.x * 0.035, 0.087, corner.y * 0.035)))
	_append(iron, _cylinder(0.062, 0.012, 0.045), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.17, 0.0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.016
	ring.outer_radius = 0.024
	_append(iron, ring, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, LANTERN_TALL_M - 0.005, 0.0)))
	iron.generate_normals()
	var mesh := iron.commit()
	mesh.surface_set_material(0, material(IRON))
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(glass, _cylinder(0.042, 0.042, 0.115), Transform3D(Basis.IDENTITY, Vector3(0.0, GLASS_MID_M, 0.0)))
	glass.generate_normals()
	glass.commit(mesh)
	mesh.surface_set_material(1, material(GLASS, GLASS_ENERGY))
	_meshes["lantern"] = mesh
	return mesh


# --- the basket ----------------------------------------------------------------------------------

static func basket() -> ArrayMesh:
	"""THE HAULING BASKET, empty (see the header), its bottom at its origin: the wicker, then its rim and grips."""
	if not _meshes.has("basket"):
		_meshes["basket"] = _basket_into(ArrayMesh.new())
	return _meshes["basket"]


static func _basket_into(mesh: ArrayMesh) -> ArrayMesh:
	"""The basket's two surfaces -- the flared wicker body, its rim and grips -- added to `mesh`."""
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shell := _cylinder(BASKET_BOTTOM_M, BASKET_TOP_M, BASKET_TALL_M, 14)
	shell.cap_top = false
	_append(body, shell, Transform3D(Basis.IDENTITY, Vector3(0.0, BASKET_TALL_M * 0.5, 0.0)))
	body.generate_normals()
	body.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material(WICKER))
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoop := TorusMesh.new()
	hoop.inner_radius = BASKET_TOP_M - 0.012
	hoop.outer_radius = BASKET_TOP_M + 0.012
	hoop.rings = 20
	_append(rim, hoop, Transform3D(Basis.IDENTITY, Vector3(0.0, BASKET_TALL_M, 0.0)))
	for side: float in [-1.0, 1.0]:
		var grip := TorusMesh.new()
		grip.inner_radius = 0.03
		grip.outer_radius = 0.042
		_append(rim, grip, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * (BASKET_TOP_M + 0.02), BASKET_TALL_M - 0.02, 0.0)))
	rim.generate_normals()
	rim.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material(WICKER_DARK))
	return mesh


static func spoil_heap() -> SphereMesh:
	"""The damp spoil heaped in a basket: a squashed half-sphere, scaled by the load (haul_view.gd)."""
	if not _meshes.has("spoil"):
		var heap := SphereMesh.new()
		heap.radius = BASKET_TOP_M * 0.92
		heap.height = heap.radius
		heap.is_hemisphere = true
		heap.radial_segments = 10
		heap.rings = 3
		heap.material = material(SPOIL)
		_meshes["spoil"] = heap
	return _meshes["spoil"]


static func loaded_basket() -> ArrayMesh:
	"""The basket with a full heap of spoil in it, one mesh (a hauler holds one model: demo_actor.gd `hold`)."""
	if _meshes.has("loaded"):
		return _meshes["loaded"]
	var mesh := _basket_into(ArrayMesh.new())
	var heap := SurfaceTool.new()
	heap.begin(Mesh.PRIMITIVE_TRIANGLES)
	heap.append_from(spoil_heap(), 0, Transform3D(Basis.from_scale(Vector3(1.0, SPOIL_OVER_M / (BASKET_TOP_M * 0.46), 1.0)),
		Vector3(0.0, BASKET_TALL_M - 0.02, 0.0)))
	heap.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material(SPOIL))
	_meshes["loaded"] = mesh
	return mesh


static func basket_fit() -> Transform3D:
	"""How a hauler holds the loaded basket: its middle on the hands' midpoint (demo_actor.gd `hold`)."""
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -BASKET_TALL_M * 0.55, 0.0))


static func register(prewarm: PrewarmScript) -> void:
	"""Every mesh and material the theatre draws below, for the U view's prewarm (decision 0206)."""
	for mesh: Mesh in [hand_lantern(), basket(), spoil_heap(), loaded_basket()]:
		prewarm.add_mesh(mesh)
