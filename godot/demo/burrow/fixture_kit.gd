extends RefCounted
## The fit-out's pieces: how each fixture is drawn. Decision 0210 (the underground revamp's P4). Presentation only.
##
## LIBRARY PROPS where the library has one (demo/props/demo_props.gd sizes them): the bed, the stone hearth, the
## table and stools, the pantry shelf, the wall lantern, and the clay jars and sacks that fill a cellar's racks.
## THE LARGE BED (decision 0211) is the library's bed stretched to LARGE_BED_M for the big residents.
## PROCEDURAL STAND-INS for the four the library does not have yet -- the generated root_bin, hanging_stores and
## rag_rug are P7's swap (decision 0204) -- each in a few shared meshes and materials:
##   * the PANTRY RACK: a timber frame of four posts and two boards, jars on its top board and sacks on its lower one;
##   * the ROOT BIN: a slatted timber box, its roots heaped higher as the cellar fills;
##   * the HANGING STORES: a pole on two posts, strings of onions and bundles of herbs hung from it;
##   * the RAG RUG: a DECAL on the floor, an oval braided in rings of rag colours drawn once into a small texture.
## A PLANNED fixture (paid for, not yet put in) is a chalk ring on the floor where it will stand.
## ON THE GROUND a home with a hearth has a CHIMNEY POT on its mound over the hearth, and SMOKE rising from it while the
## hearth is lit (CPUParticles3D: no GPU process shader to compile; at most SMOKE_AMOUNT puffs a home).
##
## FILL SLOTS. A cellar's storage fixtures carry SLOTS: places a jar, a sack or a string of stores shows once the
## cellar is full enough (fixture_view.gd shows them in order across the cellar as it fills). Every piece here is made
## of the meshes and materials `register` hands the U view's prewarm.

const PropsScript := preload("res://demo/props/demo_props.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")

const TIMBER: Color = Color(0.42, 0.29, 0.17)
const SLAT: Color = Color(0.5, 0.36, 0.22)
const ROOT: Color = Color(0.62, 0.37, 0.2)
const ONION: Color = Color(0.78, 0.6, 0.36)
const HERB: Color = Color(0.36, 0.45, 0.22)
const CHALK: Color = Color(0.93, 0.89, 0.78)
const EMBER: Color = Color(1.0, 0.45, 0.12)
## A braided rag rug in the village's worn rag colours: madder, oat, woad, heather, ochre, moss -- muted.
const RUG_RINGS: Array[Color] = [Color(0.46, 0.24, 0.19), Color(0.62, 0.52, 0.36), Color(0.3, 0.34, 0.38),
	Color(0.42, 0.3, 0.32), Color(0.55, 0.42, 0.26), Color(0.33, 0.36, 0.26)]
## Braids a ring: the rug's radius over them, and a wobble so each braid reads as twisted rag.
const RUG_BRAIDS: float = 11.0
const RUG_WOBBLE: float = 0.12
const RUG_SIZE_M: Vector2 = Vector2(1.7, 1.15)
const RUG_PX: int = 128
## The rack: its width, depth, height, board heights (m) and the slots on its boards.
const RACK_SIZE_M: Vector3 = Vector3(1.1, 1.1, 0.42)
const RACK_BOARDS_M: Array[float] = [0.34, 0.86]
const RACK_SLOTS: int = 6
## The bin: width, height, depth (m); its roots heap to HEAP_TOP_M over its floor when the cellar is full.
const BIN_SIZE_M: Vector3 = Vector3(0.9, 0.55, 0.6)
const BIN_SLATS: int = 4
const HEAP_TOP_M: float = 0.5
## The heap's half-height at scale 1 (a 0.5 m sphere squashed to half), which its y scale multiplies.
const HEAP_HALF_M: float = 0.25
## The hanging stores: pole length and height (m), and its strings.
const POLE_M: float = 1.2
const POLE_Y_M: float = 1.55
const STRINGS: int = 4
## A shelf's slots: sacks at its foot.
const SHELF_SLOTS: int = 2
## The chalk ring round a planned fixture's place (m).
const PLAN_RING_M: float = 0.42
## A large bed's width and length (m; decision 0211, bed_allocation.gd LARGE_BED_LENGTH_U).
const LARGE_BED_M: Vector2 = Vector2(1.2, 2.7)
## The chimney pot and its smoke: the pot's top over the mound (m), and the puffs (SMOKE_AMOUNT a home, eight homes
## at most: 128 live, inside P5's 200).
const STONE: Color = Color(0.52, 0.5, 0.45)
const CLAY: Color = Color(0.5, 0.31, 0.21)
const SOOT: Color = Color(0.08, 0.07, 0.06)
const CHIMNEY_TOP_M: float = 0.55
const SMOKE_AMOUNT: int = 16
const SMOKE_LIFE_S: float = 4.5
const JAR_KEY: StringName = &"clay_jars"
const SACK_KEY: StringName = &"sack_pile"
const JAR_SCALE: float = 0.5

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _rug: ImageTexture = null


static func material(colour: Color, emission: bool = false) -> StandardMaterial3D:
	"""A lit, rough material of `colour` (emitting it too), one per colour, shared."""
	var key := "%s|%s" % [colour.to_html(), emission]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = colour
		made.roughness = 1.0
		if emission:
			made.emission_enabled = true
			made.emission = colour
			made.emission_energy_multiplier = 1.4
		_materials[key] = made
	return _materials[key]


static func _box(size: Vector3) -> BoxMesh:
	"""A shared box of `size` (m)."""
	var key := "box|%s" % size
	if not _meshes.has(key):
		var box := BoxMesh.new()
		box.size = size
		_meshes[key] = box
	return _meshes[key]


static func _sphere(radius: float, squash: float) -> SphereMesh:
	"""A shared low sphere of `radius`, its height `squash` of its width."""
	var key := "sphere|%s|%s" % [radius, squash]
	if not _meshes.has(key):
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0 * squash
		sphere.radial_segments = 10
		sphere.rings = 5
		_meshes[key] = sphere
	return _meshes[key]


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	"""A shared thin cylinder."""
	var key := "cylinder|%s|%s" % [radius, height]
	if not _meshes.has(key):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = height
		cylinder.radial_segments = 8
		_meshes[key] = cylinder
	return _meshes[key]


static func _cone(bottom: float, top: float, height: float) -> CylinderMesh:
	"""A shared tapering pot: `bottom` and `top` radii, `height` tall."""
	var key := "cone|%s|%s|%s" % [bottom, top, height]
	if not _meshes.has(key):
		var cone := CylinderMesh.new()
		cone.bottom_radius = bottom
		cone.top_radius = top
		cone.height = height
		cone.radial_segments = 10
		_meshes[key] = cone
	return _meshes[key]


static func _ring() -> TorusMesh:
	"""The chalk ring of a planned place."""
	if not _meshes.has("ring"):
		var ring := TorusMesh.new()
		ring.inner_radius = PLAN_RING_M - 0.03
		ring.outer_radius = PLAN_RING_M
		ring.rings = 24
		ring.ring_segments = 4
		_meshes["ring"] = ring
	return _meshes["ring"]


static func part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, emission: bool = false) -> MeshInstance3D:
	"""One shadowless piece of `mesh` in `colour` at `at` under `parent`."""
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(colour, emission)
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func prop(parent: Node3D, props: PropsScript, key: StringName, at: Transform3D) -> MeshInstance3D:
	"""A library prop at `at` under `parent` (its fit kept), shadowless."""
	var node: MeshInstance3D = props.instance(key)
	node.transform = at * node.transform
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func large_bed(parent: Node3D, props: PropsScript) -> MeshInstance3D:
	"""A LARGE BED (decision 0211): the library's burrow bed drawn LARGE_BED_M long and wide -- the same frame, straw
	and quilt, made for the badger -- under `parent`, its head to -Z as the bed's."""
	var bound: AABB = props.drawn_bound(&"bed")
	var stretch := Vector3(LARGE_BED_M.x / maxf(bound.size.x, 0.01), 1.0, LARGE_BED_M.y / maxf(bound.size.z, 0.01))
	return prop(parent, props, &"bed", Transform3D(Basis.from_scale(stretch), Vector3.ZERO))


static func planned(parent: Node3D) -> void:
	"""A planned fixture: the chalk ring on the floor."""
	part(parent, _ring(), CHALK, Vector3(0.0, 0.03, 0.0), true)


# --- the stand-ins ------------------------------------------------------------------------------

static func rack(parent: Node3D, props: PropsScript, slots: Array[Node3D]) -> void:
	"""The pantry rack (see the header), its RACK_SLOTS slots -- three jars above, three sacks below -- into `slots`,
	hidden."""
	var size := RACK_SIZE_M
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		part(parent, _box(Vector3(0.06, size.y, 0.06)), TIMBER, Vector3(corner.x * (size.x - 0.06) * 0.5, size.y * 0.5,
			corner.y * (size.z - 0.06) * 0.5))
	for board_y: float in RACK_BOARDS_M:
		part(parent, _box(Vector3(size.x, 0.04, size.z)), SLAT, Vector3(0.0, board_y, 0.0))
	for k in RACK_SLOTS:
		var key := JAR_KEY if k < 3 else SACK_KEY
		var x := (float(k % 3) - 1.0) * size.x * 0.3
		var slot := prop(parent, props, key, Transform3D(Basis.from_scale(Vector3.ONE * (JAR_SCALE if k < 3 else 0.55)),
			Vector3(x, RACK_BOARDS_M[1 if k < 3 else 0] + 0.02, 0.0)))
		slot.visible = false
		slots.append(slot)


static func root_bin(parent: Node3D, slots: Array[Node3D]) -> void:
	"""The root bin (see the header): slatted sides round a heap of roots, the heap its one slot (`slots`), scaled by
	fixture_view.gd to the cellar's fill."""
	var size := BIN_SIZE_M
	for k in BIN_SLATS:
		var y := size.y * (float(k) + 0.5) / float(BIN_SLATS)
		for side: float in [-1.0, 1.0]:
			part(parent, _box(Vector3(size.x, 0.08, 0.03)), SLAT, Vector3(0.0, y, side * size.z * 0.5))
			part(parent, _box(Vector3(0.03, 0.08, size.z)), SLAT, Vector3(side * size.x * 0.5, y, 0.0))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		part(parent, _box(Vector3(0.05, size.y + 0.04, 0.05)), TIMBER, Vector3(corner.x * size.x * 0.5, size.y * 0.5,
			corner.y * size.z * 0.5))
	var heap := part(parent, _sphere(0.5, 0.5), ROOT, Vector3(0.0, 0.02, 0.0))
	heap.scale = Vector3(size.x * 0.95, 0.0, size.z * 0.95)
	heap.visible = false
	slots.append(heap)


static func hanging(parent: Node3D, slots: Array[Node3D]) -> void:
	"""The hanging stores (see the header): a pole on two posts and STRINGS strings hung from it, into `slots`,
	hidden -- onions and garlic on some, herb bundles on the others."""
	for side: float in [-1.0, 1.0]:
		part(parent, _box(Vector3(0.05, POLE_Y_M + 0.08, 0.05)), TIMBER, Vector3(side * POLE_M * 0.5, (POLE_Y_M + 0.08) * 0.5, 0.0))
	var pole := part(parent, _cylinder(0.025, POLE_M), TIMBER, Vector3(0.0, POLE_Y_M, 0.0))
	pole.rotation.z = PI * 0.5
	for k in STRINGS:
		var string := Node3D.new()
		string.position = Vector3((float(k) + 0.5) / float(STRINGS) * POLE_M - POLE_M * 0.5, POLE_Y_M, 0.0)
		for bead in 4:
			var herb := k % 2 == 1
			part(string, _sphere(0.06 if not herb else 0.05, 1.0 if not herb else 1.9), HERB if herb else ONION,
				Vector3(0.0, -0.1 - 0.11 * float(bead), 0.0))
		string.visible = false
		parent.add_child(string)
		slots.append(string)


static func shelf_slots(parent: Node3D, props: PropsScript, depth: float, slots: Array[Node3D]) -> void:
	"""A shelf's SHELF_SLOTS sacks at its foot, before it (`depth`: the shelf's own depth, m), into `slots`, hidden."""
	for k in SHELF_SLOTS:
		var slot := prop(parent, props, SACK_KEY, Transform3D(Basis(Vector3.UP, 0.4 * float(k)) * Basis.from_scale(Vector3.ONE * 0.8),
			Vector3((float(k) - 0.5) * 0.5, 0.0, depth * 0.5 + 0.25)))
		slot.visible = false
		slots.append(slot)


static func rug(parent: Node3D) -> Decal:
	"""The rag rug: a decal pressed down onto the floor (see the header)."""
	var decal := Decal.new()
	decal.texture_albedo = rug_texture()
	decal.size = Vector3(RUG_SIZE_M.x, 0.5, RUG_SIZE_M.y)
	decal.position = Vector3(0.0, 0.1, 0.0)
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	parent.add_child(decal)
	return decal


static func rug_texture() -> ImageTexture:
	"""The rug's texture, drawn once: an oval in rings of RUG_RINGS, clear outside it."""
	if _rug == null:
		var image := Image.create_empty(RUG_PX, RUG_PX, false, Image.FORMAT_RGBA8)
		var middle := Vector2(RUG_PX, RUG_PX) * 0.5
		for y in RUG_PX:
			for x in RUG_PX:
				image.set_pixel(x, y, rug_pixel((Vector2(x + 0.5, y + 0.5) - middle) / middle))
		image.generate_mipmaps()
		_rug = ImageTexture.create_from_image(image)
	return _rug


static func rug_pixel(at: Vector2) -> Color:
	"""The rug at `at` (-1..1 across): clear outside the oval; inside, the braid's colour, darker between braids."""
	var d := at.length()
	if d > 0.97:
		return Color(0, 0, 0, 0)
	var along := d * RUG_BRAIDS + RUG_WOBBLE * sin(atan2(at.y, at.x) * 14.0 + d * 30.0)
	var colour: Color = RUG_RINGS[int(along) % RUG_RINGS.size()]
	var seam := absf(fmod(along, 1.0) - 0.5) * 2.0
	return colour.darkened(0.35 * seam * seam)


static func embers(parent: Node3D, at: Vector3) -> MeshInstance3D:
	"""The hearth's embers: a glowing heap in its firebox at `at`, shown while it is lit."""
	var heap := part(parent, _sphere(0.09, 0.4), EMBER, at, true)
	heap.visible = false
	return heap


# --- the chimney (on the ground) ----------------------------------------------------------------

static func chimney(parent: Node3D) -> void:
	"""A home's chimney pot on its mound, over the hearth: a clay pot on a stone collar (a stand-in until P7's
	chimney_pot), casting its shadow on the turf. Its top is CHIMNEY_TOP_M over `parent`."""
	part(parent, _cylinder(0.24, 0.16), STONE, Vector3(0.0, 0.08, 0.0))
	part(parent, _cone(0.12, 0.17, CHIMNEY_TOP_M - 0.22), CLAY, Vector3(0.0, 0.16 + (CHIMNEY_TOP_M - 0.22) * 0.5, 0.0))
	part(parent, _cylinder(0.19, 0.06), CLAY, Vector3(0.0, CHIMNEY_TOP_M - 0.03, 0.0))
	part(parent, _cylinder(0.12, 0.02), SOOT, Vector3(0.0, CHIMNEY_TOP_M + 0.005, 0.0))
	for piece: Node in parent.get_children():
		(piece as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func smoke() -> CPUParticles3D:
	"""Chimney smoke: SMOKE_AMOUNT soft grey puffs rising and spreading from the pot for SMOKE_LIFE_S each, not
	emitting until lit (fixture_view.gd). Its speed follows the demo clock (paused, the smoke stands still)."""
	var puffs := CPUParticles3D.new()
	puffs.amount = SMOKE_AMOUNT
	puffs.lifetime = SMOKE_LIFE_S
	puffs.emitting = false
	puffs.local_coords = false
	puffs.mesh = smoke_mesh()
	puffs.direction = Vector3.UP
	puffs.spread = 12.0
	puffs.gravity = Vector3(0.12, 0.25, 0.05)
	puffs.initial_velocity_min = 0.35
	puffs.initial_velocity_max = 0.55
	puffs.scale_amount_min = 0.5
	puffs.scale_amount_max = 0.8
	puffs.scale_amount_curve = grow_curve()
	puffs.color_ramp = _fade_ramp()
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return puffs


static func smoke_mesh() -> QuadMesh:
	"""One smoke puff: a soft round billboard in the smoke's own material."""
	if not _meshes.has("smoke"):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8)
		var puff := StandardMaterial3D.new()
		puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		puff.vertex_color_use_as_albedo = true
		puff.albedo_texture = _puff_texture()
		quad.material = puff
		_meshes["smoke"] = quad
	return _meshes["smoke"]


static func _puff_texture() -> ImageTexture:
	"""A soft white disc fading to clear at its edge."""
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := (Vector2(x + 0.5, y + 0.5) - Vector2(16, 16)).length() / 16.0
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	return ImageTexture.create_from_image(image)


static func grow_curve() -> Curve:
	"""A puff grows from a third of its size to all of it as it rises."""
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


static func _fade_ramp() -> Gradient:
	"""A puff's colour over its life: grey smoke thickening in, then thinning away."""
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.7, 0.68, 0.0))
	ramp.set_color(1, Color(0.8, 0.79, 0.77, 0.0))
	ramp.add_point(0.15, Color(0.62, 0.6, 0.58, 0.75))
	return ramp


static func register_ground(parent: Node3D) -> void:
	"""One of each piece the fit-out draws on the ground -- the chimney's stone and clay, and smoke already rising (a
	particle system draws instanced, its own pipeline) -- under `parent`, for the rooms' ground prewarm (room_view.gd
	`begin_surface_prewarm`)."""
	chimney(parent)
	var puffs := smoke()
	parent.add_child(puffs)
	puffs.preprocess = SMOKE_LIFE_S
	puffs.emitting = true


static func register(prewarm: PrewarmScript, props: PropsScript) -> void:
	"""Every mesh and material the fit-out draws below, for the U view's prewarm (decision 0206)."""
	for key: StringName in [&"bed", &"hearth", &"table_stools", &"pantry_shelf", &"wall_lantern", JAR_KEY, SACK_KEY]:
		prewarm.add_mesh(props.mesh_of(key))
	for colour: Color in [TIMBER, SLAT, ROOT, ONION, HERB]:
		prewarm.add_mesh(_box(Vector3.ONE * 0.1), material(colour))
	prewarm.add_mesh(_ring(), material(CHALK, true))
	prewarm.add_mesh(_sphere(0.09, 0.4), material(EMBER, true))
