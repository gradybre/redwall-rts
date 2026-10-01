extends RefCounted
## The construction theatre's props. Decisions 0211 (the underground revamp's P5) and 0371 (P7). Presentation only.
##
##   * THE HAND LANTERN a digger sets down beside it at the face. Staged, the library's candle lantern
##     (make_demo_derived_props.py `hand_lantern_lit`: its frame, horn panes and candle, the panes and candle a surface
##     of their own that glows here, `lit`), 0.3 m tall with its handle. Unstaged, the procedural stand-in: an iron base
##     and cap on four posts round a warm glass with a candle's glow, a ring to carry it by, 0.2 m tall.
##   * THE HAULING BASKET: staged, the library's wicker `basket`, drawn BASKET_SIZE_M tall to its handle's top; unstaged,
##     a woven, flared basket with a rim and two grips. A heap of damp spoil in it (`load`: the heap's height, 0..1),
##     drawn at a filler's feet and carried between a hauler's hands (haul_view.gd).
## Each is a few shared meshes and materials, built once a props table, registered for the U view's prewarm
## (`register`). Every function takes the demo's props table (null or nothing staged: the stand-ins).

const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

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
## The staged props: the lantern (its panes and candle glow GLASS_ENERGY times their own colour) and the basket, drawn
## this tall to its handle's top, its rim at BASKET_RIM_SHARE of that (measured off the library model, a handle half
## again as tall as the basket).
const LANTERN_KEY: StringName = &"hand_lantern_lit"
const GLOW_SURFACE: String = "glow"
const BASKET_KEY: StringName = &"basket"
const BASKET_SIZE_M: float = 0.38
const BASKET_RIM_SHARE: float = 0.55

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

static func hand_lantern(props: PropsScript = null) -> ArrayMesh:
	"""THE HAND LANTERN (see the header), its base on the floor at its origin: the staged lantern lit (`lit`), else the
	stand-in's iron, then its glowing glass."""
	var staged := props.fitted(LANTERN_KEY) if props != null else null
	if staged != null:
		var kept: Variant = props.derived(&"hand_lantern/lit")
		return kept if kept != null else props.keep(&"hand_lantern/lit", lit(staged))
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


static func lit(mesh: ArrayMesh) -> ArrayMesh:
	"""A copy of a staged lantern whose GLOW_SURFACE surface (its panes and candle) glows its own colour: its material
	copied with emission from its albedo map, GLASS_ENERGY strong. The other surfaces keep their materials."""
	var out := mesh.duplicate() as ArrayMesh
	for surface: int in out.get_surface_count():
		var own := out.surface_get_material(surface) as BaseMaterial3D
		if own != null and own.resource_name.contains(GLOW_SURFACE):
			var glowing := own.duplicate() as BaseMaterial3D
			glowing.emission_enabled = true
			glowing.emission = Color.WHITE
			glowing.emission_texture = own.albedo_texture
			glowing.emission_energy_multiplier = GLASS_ENERGY
			out.surface_set_material(surface, glowing)
	return out


static func glows(mesh: Mesh) -> bool:
	"""Whether some surface of `mesh` emits light (the lantern's glass; checks)."""
	for surface: int in mesh.get_surface_count():
		var own := mesh.surface_get_material(surface) as BaseMaterial3D
		if own != null and own.emission_enabled:
			return true
	return false


# --- the basket ----------------------------------------------------------------------------------

static func basket(props: PropsScript = null) -> ArrayMesh:
	"""THE HAULING BASKET, empty (see the header), its bottom at its origin: the staged wicker basket at BASKET_SIZE_M,
	else the stand-in's wicker, then its rim and grips."""
	var staged := _staged_basket(props)
	if staged != null:
		return staged
	if not _meshes.has("basket"):
		_meshes["basket"] = _basket_into(ArrayMesh.new())
	return _meshes["basket"]


static func _staged_basket(props: PropsScript) -> ArrayMesh:
	"""The library basket at BASKET_SIZE_M to its handle's top, its base at its origin (null: not staged)."""
	var staged := props.fitted(BASKET_KEY) if props != null else null
	if staged == null:
		return null
	var kept: Variant = props.derived(&"basket/sized")
	if kept != null:
		return kept
	var tall := maxf(staged.get_aabb().size.y, 0.01)
	return props.keep(&"basket/sized", PropsScript.transformed(staged,
		Transform3D(Basis.from_scale(Vector3.ONE * BASKET_SIZE_M / tall), Vector3.ZERO)))


static func rim_m(props: PropsScript = null) -> float:
	"""How high the basket's rim stands over its base (m): where its spoil heaps."""
	return BASKET_SIZE_M * BASKET_RIM_SHARE if _staged_basket(props) != null else BASKET_TALL_M


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


static func loaded_basket(props: PropsScript = null) -> ArrayMesh:
	"""The basket with a full heap of spoil in it, one mesh (a hauler holds one model: demo_actor.gd `hold`)."""
	var staged := _staged_basket(props)
	if staged != null and props.derived(&"basket/loaded") != null:
		return props.derived(&"basket/loaded")
	if staged == null and _meshes.has("loaded"):
		return _meshes["loaded"]
	var mesh := _basket_into(ArrayMesh.new()) if staged == null else (staged.duplicate() as ArrayMesh)
	var rim := rim_m(props)
	var heap := SurfaceTool.new()
	heap.begin(Mesh.PRIMITIVE_TRIANGLES)
	heap.append_from(spoil_heap(), 0, Transform3D(Basis.from_scale(Vector3(1.0, SPOIL_OVER_M / (BASKET_TOP_M * 0.46), 1.0)),
		Vector3(0.0, rim - 0.02, 0.0)))
	heap.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material(SPOIL))
	if staged != null:
		return props.keep(&"basket/loaded", mesh)
	_meshes["loaded"] = mesh
	return mesh


static func basket_fit(props: PropsScript = null) -> Transform3D:
	"""How a hauler holds the loaded basket: its middle on the hands' midpoint (demo_actor.gd `hold`)."""
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -rim_m(props), 0.0))


static func register(prewarm: PrewarmScript, props: PropsScript = null) -> void:
	"""Every mesh and material the theatre draws below, for the U view's prewarm (decision 0206)."""
	for mesh: Mesh in [hand_lantern(props), basket(props), spoil_heap(), loaded_basket(props)]:
		prewarm.add_mesh(mesh)
