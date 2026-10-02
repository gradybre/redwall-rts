extends Node3D
## One crop bed as drawn: soil and frame, the plants of whatever grows there at its stage, the soil's
## moisture sheen, sowing furrows, a label over it, a selection ring and the map-overlay disc.
## Decision 0196. Presentation only: `show_state()` is handed what to draw (farm_view.gd reads the
## sim); nothing here decides anything.
##
## The plants are the staged card atlases -- each item's own library plant (tools/make_demo_props.py),
## or the old atlas it borrows (tools/make_demo_crop_cards.py) -- in ONE MultiMesh per bed (plus one
## of top-down leaves where the atlas has them), laid out once per visual kind with a seed per bed,
## and only re-transformed and re-celled -- never re-allocated -- when the growth step changes.
## Scale, the cells a stage shows, tint, bleach, blotches, droop and slump come from farm_look.gd. A
## head plant (the lettuce) is drawn filled out and ripe as its close-up mesh instead, in one more
## MultiMesh laid out the same, tinted by one material per bed.
##
## THE GROUND WORKS, each built once per bed and hidden until done (show_works): straw over a covered
## bed; a RAISED bed lifted RAISE_LIFT_M on its spoil inside a frame of planks -- RAISE_BOARDS a side,
## each a little off in tone and height, grained -- with a corner post standing a little proud at each
## corner (was one brown slab); a BANKED bed's rounded soil berm (was four boxes); a DITCHED bed's
## narrow dark trench with its spoil in a low lip outside it (the Drain job). A WATERLOGGED bed shows
## small standing puddles (one MultiMesh of flat ellipses, laid out once per bed) over its darkened
## soil (farm_look.gd).
##
## A KITCHEN GARDEN BED (decision 0883) is the same bed drawn at its one 2 m tile: the whole bed is scaled by
## farm_catalog.gd `bed_half_m` against a field bed's 3 m, its label kept at the field's size. A garden SITE not laid
## out shows only four pegs and a string round its square, and its label (`show_site`).

const Look := preload("res://demo/farm/farm_look.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const AssetsScript := preload("res://demo/farm/farm_assets.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CropCards := preload("res://demo/world/crop_cards.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")

## A library plant's top-down cell for each of its standing cells (full, side, thinned, sparse):
## the tops atlas has full, thinned and sparse.
const TOP_OF_CELL: Array[int] = [0, 0, 1, 2]
## Where the old roots atlas's tops lie, as a share of its card's height.
const OLD_TOP_LIFT: float = 0.55
const JITTER: float = 0.3
const SCALE_JITTER: Vector2 = Vector2(0.85, 1.1)
const FURROWS: int = 5
const FURROW_SIZE: Vector3 = Vector3(1.55, 0.012, 0.07)
const FURROW_COLOR: Color = Color(0.16, 0.11, 0.08)
const LABEL_HEIGHT_M: float = 1.5
const LABEL_PIXEL: float = 0.0042
const LABEL_FONT_PX: int = 44
## The overlay square over a bed, a little inside its 3 m frame.
const OVERLAY_SIZE_M: float = 2.8
## Tunnel spoil under a raised bed lifts it this far.
const RAISE_LIFT_M: float = 0.14
## The raised frame's boards: their centre line this far out from the bed's centre (just outside the
## staged bed's 1.5 m frame), each board RAISE_BOARD long x high x thick before its own length and
## height; RAISE_BOARDS stacked a side with a thin dark gap between them (so they read as two planks),
## the stack (0.162 m) just covering the lift.
const RAISE_FRAME_HALF_M: float = 1.53
const RAISE_BOARD: Vector3 = Vector3(3.06, 0.075, 0.05)
const RAISE_BOARDS: int = 2
const RAISE_BOARD_GAP_M: float = 0.012
## Each board is up to this much taller or shorter than RAISE_BOARD's height (by bed, side, board).
const RAISE_BOARD_JITTER_M: float = 0.008
## Corner posts: square, standing a little proud of the boards (0.25 m against 0.162 m).
const RAISE_POST: Vector3 = Vector3(0.1, 0.25, 0.1)
## Weathered plank tones (grey-brown, to sit with the staged bed's own frame); the last is the posts'.
const WOOD_TONES: Array[Color] = [Color(0.56, 0.47, 0.37), Color(0.5, 0.41, 0.32), Color(0.61, 0.52, 0.41),
	Color(0.42, 0.34, 0.26)]
const WOOD_POST: int = 3
const WOOD_ROUGHNESS: float = 0.85
## The planks' grain: a GRAIN_PX texture of GRAIN_PX.y streaks, scaled onto each board along its length.
const GRAIN_PX: Vector2i = Vector2i(64, 32)
const GRAIN_SEED: int = 4471
const WOOD_GRAIN_SCALE: Vector3 = Vector3(0.35, 2.4, 0.35)
## A bank is a rounded soil berm on each side of the bed: a capsule lying along the side, squashed.
const BANK_LENGTH_M: float = 3.6
const BANK_RADIUS_M: float = 0.22
const BANK_SQUASH: float = 0.6
const BANK_HALF_M: float = 1.72
## Dug earth (the berm, the ditch's lip): a dark loam near the bed's own soil, speckled with clods
## (EARTH_PX of seeded speckle, laid over it in world space every EARTH_TILE_M).
const EARTH_COLOR: Color = Color(0.3, 0.23, 0.17)
const EARTH_PX: int = 32
const EARTH_SEED: int = 5113
const EARTH_TILE_M: float = 0.35
## A ditch (the Drain job): a dark wet trench strip just outside the bed frame, and its spoil in a low
## rounded lip outside that -- narrow, as beds stand only 0.2 m apart across the rows.
const DITCH_HALF_M: float = 1.6
const DITCH_STRIP: Vector3 = Vector3(3.34, 0.012, 0.11)
const DITCH_COLOR: Color = Color(0.11, 0.085, 0.065)
## Matte: a glossy strip catches the low sky and reads as a white line, not a trench.
const DITCH_ROUGHNESS: float = 0.9
const DITCH_LIP_HALF_M: float = 1.73
const DITCH_LIP_LENGTH_M: float = 3.5
const DITCH_LIP_RADIUS_M: float = 0.06
const DITCH_LIP_SQUASH: float = 0.7
const DITCH_LIP_COLOR: Color = Color(0.34, 0.26, 0.19)
## A waterlogged bed's puddles, in bed units: PUDDLES patches of PUDDLE_BLOBS overlapping quads, each
## showing one soft-edged, lobed blob (PUDDLE_PX, made once) turned and stretched its own way, so no
## two read alike and none has a hard round rim; each PUDDLE_RADIUS (min, max) of the soil's inner half
## across, within PUDDLE_SPREAD of it from the centre; seeded by bed.
const PUDDLES: int = 7
const PUDDLE_BLOBS: int = 2
const PUDDLE_RADIUS: Vector2 = Vector2(0.08, 0.18)
const PUDDLE_SPREAD: float = 0.68
const PUDDLE_PX: int = 64
const PUDDLE_SEED: int = 3307
const PUDDLE_LIFT: float = 0.012
## Straw laid over a covered bed for a frost night.
const STRAW_SIZE: Vector3 = Vector3(2.85, 0.04, 2.85)
const STRAW_COLOR: Color = Color(0.83, 0.7, 0.42, 0.88)
const STRAW_Y_M: float = 0.5
## The selection outline: a brass square just outside the bed frame, above it.
const OUTLINE_HALF_M: float = 1.6
const OUTLINE_BAR: Vector3 = Vector3(3.3, 0.05, 0.08)
const OUTLINE_Y_M: float = 0.32
## The Compare view's ring (decision 0451, UX-008's map highlight): cream, just outside the selection's brass one, so a
## compared bed that is also the open one shows both.
const COMPARE_COLOUR: Color = Color(0.96, 0.94, 0.87, 0.9)
const COMPARE_HALF_M: float = 1.74
## A growth change smaller than this (permille) keeps the plants as they stand.
const GROWTH_STEP: int = 25
## A garden site's pegs and string (see A KITCHEN GARDEN BED): peg size, the string's height and thickness, their
## tones (demo values, the raised frame's weathered wood and a pale twine).
const PEG_SIZE: Vector3 = Vector3(0.05, 0.36, 0.05)
const STRING_Y_M: float = 0.24
const STRING_THICK_M: float = 0.012
const PEG_COLOR: Color = Color(0.42, 0.33, 0.24)
const STRING_COLOR: Color = Color(0.86, 0.8, 0.64)

var bed: int = 0
## The scale the plants were last drawn at (0: none drawn).
var shown_scale: float = 0.0
var label: Label3D = null
var ring: Node3D = null
## The Compare view's ring (built the first time a compare shows the bed).
var compare_ring: Node3D = null
var overlay: MeshInstance3D = null
var straw: MeshInstance3D = null
var raised_frame: Node3D = null
var bank: Node3D = null
var ditch: Node3D = null
## A garden site's pegs and string (null for a field bed).
var pegs: Node3D = null

## The wood materials (WOOD_TONES) and the earth speckle, made once for every bed.
static var _wood_cache: Array[StandardMaterial3D] = []
static var _earth_texture: Texture2D = null
static var _puddle_texture: Texture2D = null

var _assets: AssetsScript = null
var _units: Node3D = null
var _base: Node3D = null
var _heads: Node3D = null
var _plants: MultiMeshInstance3D = null
var _tops: MultiMeshInstance3D = null
var _heads_mm: MultiMeshInstance3D = null
var _furrows: MultiMeshInstance3D = null
var _sheen: MeshInstance3D = null
var _puddles: MultiMeshInstance3D = null
var _card_material: Material = null
var _top_material: Material = null
var _kind: int = -1
var _layout: Array[Transform3D] = []
var _shown_key: int = -1
var _heads_item: int = Catalog.NO_ITEM
## The atlas cell each plant shows now (kept here: headless MultiMeshes keep no instance data).
var _cells_shown: PackedInt32Array = PackedInt32Array()


func build(p_bed: int, assets: AssetsScript) -> void:
	"""Build bed `p_bed`'s nodes at its place, bare."""
	bed = p_bed
	_assets = assets
	name = "FarmBed%d" % bed
	var at: Vector2 = Catalog.bed_centre_m(bed)
	position = Vector3(at.x, 0.0, at.y)
	scale = Vector3.ONE * (Catalog.bed_half_m(bed) / Catalog.BED_HALF_M)
	_units = Node3D.new()
	_units.scale = Vector3.ONE * assets.bed_scale
	add_child(_units)
	_base = assets.make_bed()
	_units.add_child(_base)
	_build_marks()
	_furrows = _make_furrows()
	_units.add_child(_furrows)
	_sheen = _make_sheen()
	_units.add_child(_sheen)
	_puddles = _make_puddles()
	_units.add_child(_puddles)
	label = _make_label()
	label.scale = Vector3.ONE / scale.x
	add_child(label)
	_build_works()
	if Catalog.is_garden(bed):
		pegs = _make_pegs()
		add_child(pegs)


func _build_works() -> void:
	"""What the player can do to the ground, each hidden until done: straw, a raised frame, a bank, a
	ditch (see the header)."""
	straw = _box(STRAW_SIZE, STRAW_COLOR, STRAW_Y_M)
	straw.material_override = _flat_material(STRAW_COLOR)
	(straw.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	add_child(straw)
	raised_frame = _make_raised_frame()
	add_child(raised_frame)
	bank = _hidden_node("Bank")
	var berm: CapsuleMesh = _berm_mesh(BANK_LENGTH_M, BANK_RADIUS_M, _earth(EARTH_COLOR))
	for side: int in 4:
		bank.add_child(_side_piece(berm, side, BANK_HALF_M, 0.0, _lying(BANK_SQUASH)))
	add_child(bank)
	ditch = _make_ditch()
	add_child(ditch)


func _make_pegs() -> Node3D:
	"""Four pegs at the site's corners and a string between them, in bed units (hidden)."""
	var group: Node3D = _hidden_node("SitePegs")
	var half: float = Catalog.BED_HALF_M
	var peg_material: StandardMaterial3D = _matte(PEG_COLOR, 1.0)
	var string_material: StandardMaterial3D = _matte(STRING_COLOR, 1.0)
	for side: int in 4:
		var yaw: float = PI * 0.5 * side
		var corner: Vector3 = Basis(Vector3.UP, yaw) * Vector3(half, 0.0, half)
		var peg := MeshInstance3D.new()
		peg.mesh = _box_mesh(PEG_SIZE, peg_material)
		peg.position = corner + Vector3(0.0, PEG_SIZE.y * 0.5, 0.0)
		group.add_child(peg)
		var twine := MeshInstance3D.new()
		twine.mesh = _box_mesh(Vector3(half * 2.0, STRING_THICK_M, STRING_THICK_M), string_material)
		twine.transform = Transform3D(Basis(Vector3.UP, yaw), Basis(Vector3.UP, yaw) * Vector3(0.0, STRING_Y_M, half))
		twine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(twine)
	return group


func show_site(site: bool) -> void:
	"""A garden site not laid out (pegs and string only) or a bed (see A KITCHEN GARDEN BED)."""
	_units.visible = not site
	if pegs != null:
		pegs.visible = site


func showing_site() -> bool:
	"""Whether the bed is drawn as a bare garden site (checks)."""
	return pegs != null and pegs.visible


func _make_raised_frame() -> Node3D:
	"""RAISE_BOARDS stacked planks a side and a post at each corner (hidden)."""
	var frame: Node3D = _hidden_node("RaisedFrame")
	for side: int in 4:
		for k: int in RAISE_BOARDS:
			frame.add_child(_board(side, k))
	var post := _box_mesh(Vector3(RAISE_POST.y, RAISE_POST.x, RAISE_POST.z), _wood_material(WOOD_POST))
	for corner: int in 4:
		var piece := MeshInstance3D.new()
		piece.mesh = post
		var x: float = RAISE_FRAME_HALF_M if corner % 2 == 1 else -RAISE_FRAME_HALF_M
		var z: float = RAISE_FRAME_HALF_M if corner >= 2 else -RAISE_FRAME_HALF_M
		piece.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, RAISE_POST.y * 0.5, z))
		frame.add_child(piece)
	return frame


func _board(side: int, k: int) -> MeshInstance3D:
	"""Board `k` (from the ground up) of side `side`: the x-running sides overlap the corners, the
	z-running ones butt into them; its height and tone vary a little by bed, side and board."""
	var along_x: bool = side % 2 == 0
	var length: float = RAISE_BOARD.x + (RAISE_BOARD.z if along_x else -RAISE_BOARD.z)
	var height: float = RAISE_BOARD.y + RAISE_BOARD_JITTER_M * float((bed + side * 3 + k * 5) % 3 - 1)
	var y: float = k * (RAISE_BOARD.y + RAISE_BOARD_GAP_M) + height * 0.5
	var tone: int = (bed + side * 2 + k) % WOOD_POST
	var mesh := _box_mesh(Vector3(length, height, RAISE_BOARD.z), _wood_material(tone))
	return _side_piece(mesh, side, RAISE_FRAME_HALF_M, y, Basis.IDENTITY)


func _make_ditch() -> Node3D:
	"""The Drain job's ditch: a dark trench strip on each side and its spoil lip outside (hidden)."""
	var ring: Node3D = _hidden_node("Ditch")
	var trench := _box_mesh(DITCH_STRIP, _matte(DITCH_COLOR, DITCH_ROUGHNESS))
	var lip: CapsuleMesh = _berm_mesh(DITCH_LIP_LENGTH_M, DITCH_LIP_RADIUS_M, _earth(DITCH_LIP_COLOR))
	for side: int in 4:
		ring.add_child(_side_piece(trench, side, DITCH_HALF_M, DITCH_STRIP.y * 0.5, Basis.IDENTITY))
		ring.add_child(_side_piece(lip, side, DITCH_LIP_HALF_M, 0.0, _lying(DITCH_LIP_SQUASH)))
	return ring


static func _hidden_node(node_name: String) -> Node3D:
	"""An empty, hidden group node."""
	var node := Node3D.new()
	node.name = node_name
	node.visible = false
	return node


static func _side_piece(mesh: Mesh, side: int, half_m: float, y: float, own: Basis) -> MeshInstance3D:
	"""`mesh` along side `side` of the bed (0: +z, then round by quarter turns), `half_m` out from the
	centre at height `y`, turned by `own` first."""
	var yaw: float = PI * 0.5 * side
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.transform = Transform3D(Basis(Vector3.UP, yaw) * own, Vector3(sin(yaw) * half_m, y, cos(yaw) * half_m))
	return piece


static func _lying(squash: float) -> Basis:
	"""A capsule (its axis up) laid along x, flattened to `squash` of its height: a rounded berm."""
	return Basis.from_scale(Vector3(1.0, squash, 1.0)) * Basis(Vector3.BACK, PI * 0.5)


static func _berm_mesh(length: float, radius: float, material: Material) -> CapsuleMesh:
	"""A capsule `length` long overall and `radius` round, for a berm (see _lying)."""
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 3
	mesh.material = material
	return mesh


static func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	"""A box of `size` in `material`."""
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


static func _matte(colour: Color, roughness: float) -> StandardMaterial3D:
	"""A plain lit material."""
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


static func _wood_material(tone: int) -> StandardMaterial3D:
	"""Tone `tone` of WOOD_TONES, grained along each board's length (local triplanar: a board's
	length is its local x); made once for every bed."""
	if _wood_cache.is_empty():
		var grain: Texture2D = _grain_texture()
		for colour: Color in WOOD_TONES:
			var material: StandardMaterial3D = _matte(colour, WOOD_ROUGHNESS)
			material.albedo_texture = grain
			material.uv1_triplanar = true
			material.uv1_scale = WOOD_GRAIN_SCALE
			_wood_cache.append(material)
	return _wood_cache[tone]


static func _earth(colour: Color) -> StandardMaterial3D:
	"""Dug earth in `colour`, speckled with clods in world space (the speckle made once)."""
	if _earth_texture == null:
		var image := Image.create(EARTH_PX, EARTH_PX, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = EARTH_SEED
		for y: int in EARTH_PX:
			for x: int in EARTH_PX:
				var v: float = rng.randf_range(0.8, 1.0) if rng.randf() > 0.12 else rng.randf_range(0.45, 0.65)
				image.set_pixel(x, y, Color(v, v, v))
		image.generate_mipmaps()
		_earth_texture = ImageTexture.create_from_image(image)
	var material: StandardMaterial3D = _matte(colour, 1.0)
	material.albedo_texture = _earth_texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / EARTH_TILE_M
	return material


static func _grain_texture() -> Texture2D:
	"""GRAIN_PX.y streaks of seeded tone, each speckled a little along its length (made once)."""
	var image := Image.create(GRAIN_PX.x, GRAIN_PX.y, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAIN_SEED
	for y: int in GRAIN_PX.y:
		var streak: float = rng.randf_range(0.62, 1.0)
		for x: int in GRAIN_PX.x:
			var v: float = streak * rng.randf_range(0.9, 1.0)
			image.set_pixel(x, y, Color(v, v, v))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _box(size: Vector3, colour: Color, y: float) -> MeshInstance3D:
	"""A plain box standing at height `y` (hidden)."""
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = y
	instance.visible = false
	return instance


func show_works(covered: bool, raised: bool, banked: bool, ditched: bool) -> void:
	"""Straw over a covered bed; a raised bed lifted onto its spoil in its plank frame; a soil berm
	round a banked one; a ditch round a ditched one."""
	straw.visible = covered
	raised_frame.visible = raised
	_units.position.y = RAISE_LIFT_M if raised else 0.0
	straw.position.y = STRAW_Y_M + _units.position.y
	bank.visible = banked
	ditch.visible = ditched


func _build_marks() -> void:
	"""The selection outline and the overlay disc, both hidden."""
	ring = _make_outline()
	add_child(ring)
	var square := PlaneMesh.new()
	square.size = Vector2(OVERLAY_SIZE_M, OVERLAY_SIZE_M)
	overlay = MeshInstance3D.new()
	overlay.mesh = square
	overlay.material_override = _flat_material(Color(0, 0, 0, 0))
	overlay.position.y = 0.42
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.visible = false
	add_child(overlay)


static func _make_outline() -> Node3D:
	"""Four brass bars round the bed (hidden)."""
	return _outline("Selected", MarksScript.SELECTED, OUTLINE_HALF_M)


static func _outline(node_name: String, colour: Color, half_m: float) -> Node3D:
	"""Four bars of `colour` round the bed, `half_m` from its centre (hidden)."""
	var outline := Node3D.new()
	outline.name = node_name
	outline.visible = false
	var bar := BoxMesh.new()
	bar.size = Vector3(OUTLINE_BAR.x * half_m / OUTLINE_HALF_M, OUTLINE_BAR.y, OUTLINE_BAR.z)
	var material := _flat_material(colour)
	for side: int in 4:
		var piece := MeshInstance3D.new()
		piece.mesh = bar
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var yaw: float = PI * 0.5 * side
		piece.transform = Transform3D(Basis(Vector3.UP, yaw),
			Vector3(sin(yaw), 0.0, cos(yaw)) * half_m + Vector3(0.0, OUTLINE_Y_M, 0.0))
		outline.add_child(piece)
	return outline


static func _flat_material(colour: Color) -> StandardMaterial3D:
	"""An unshaded see-through material that draws over the plants."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.render_priority = 2
	return material


func _make_label() -> Label3D:
	"""The two-line label over the bed, always facing the camera and readable over the plants."""
	var text := Label3D.new()
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.pixel_size = LABEL_PIXEL
	text.font_size = LABEL_FONT_PX
	text.outline_size = 12
	text.outline_modulate = Color(0.08, 0.1, 0.08, 0.85)
	text.position.y = LABEL_HEIGHT_M
	text.render_priority = 3
	text.layers = Layers.SURFACE_MARKS
	text.outline_render_priority = 2
	return text


func _make_furrows() -> MultiMeshInstance3D:
	"""FURROWS dark seed rows across the soil (shown while sowing)."""
	var box := BoxMesh.new()
	box.size = FURROW_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = FURROW_COLOR
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = FURROWS
	for k: int in FURROWS:
		var z: float = lerpf(-0.6, 0.6, float(k) / float(FURROWS - 1))
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(0.0, _assets.soil_y + 0.004, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Furrows"
	instance.multimesh = multimesh
	instance.visible = false
	return instance


func _make_sheen() -> MeshInstance3D:
	"""A flat film over the soil that shows how wet or dry it is."""
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (_assets.inner_half * 2.0)
	var instance := MeshInstance3D.new()
	instance.name = "Sheen"
	instance.mesh = plane
	var material := _flat_material(Color(0, 0, 0, 0))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 0.15
	material.render_priority = 0
	instance.material_override = material
	instance.position.y = _assets.soil_y + 0.006
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _make_puddles() -> MultiMeshInstance3D:
	"""A waterlogged bed's standing puddles over the soil (bed units; hidden): see the constants."""
	var disc := PlaneMesh.new()
	disc.size = Vector2(2.0, 2.0)
	var material: StandardMaterial3D = _matte(Look.PUDDLE_COLOR, Look.PUDDLE_ROUGHNESS)
	material.albedo_texture = _puddle_blob()
	material.metallic_specular = Look.PUDDLE_SPECULAR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 1
	disc.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = disc
	multimesh.instance_count = PUDDLES * PUDDLE_BLOBS
	_lay_puddles(multimesh)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Puddles"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	return instance


static func _puddle_blob() -> Texture2D:
	"""One puddle's shape: white, its alpha a lobed disc (three seeded waves round its rim) fading out
	over its outer edge (made once)."""
	if _puddle_texture != null:
		return _puddle_texture
	var rng := RandomNumberGenerator.new()
	rng.seed = PUDDLE_SEED
	var phase := Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
	var image := Image.create(PUDDLE_PX, PUDDLE_PX, false, Image.FORMAT_RGBA8)
	var half: float = PUDDLE_PX * 0.5
	for y: int in PUDDLE_PX:
		for x: int in PUDDLE_PX:
			var at := Vector2(x + 0.5 - half, y + 0.5 - half) / half
			var angle: float = at.angle()
			var rim: float = 0.72 + 0.12 * sin(2.0 * angle + phase.x) + 0.08 * sin(3.0 * angle + phase.y) \
				+ 0.05 * sin(5.0 * angle + phase.z)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, smoothstep(rim, rim - 0.18, at.length())))
	image.generate_mipmaps()
	_puddle_texture = ImageTexture.create_from_image(image)
	return _puddle_texture


func _lay_puddles(multimesh: MultiMesh) -> void:
	"""Each patch a few ellipses round a seeded point, each its own size and turn."""
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + bed * 17
	var inner: float = _assets.inner_half
	var y: float = _assets.soil_y + PUDDLE_LIFT
	for patch: int in PUDDLES:
		var centre := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * PUDDLE_SPREAD * inner
		for blob: int in PUDDLE_BLOBS:
			var rx: float = rng.randf_range(PUDDLE_RADIUS.x, PUDDLE_RADIUS.y) * inner
			var rz: float = rng.randf_range(PUDDLE_RADIUS.x, PUDDLE_RADIUS.y) * inner
			var at: Vector2 = centre + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * rx
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)) * Basis.from_scale(Vector3(rx, 1.0, rz))
			multimesh.set_instance_transform(patch * PUDDLE_BLOBS + blob, Transform3D(basis, Vector3(at.x, y, at.y)))


# --- the state --------------------------------------------------------------------------------

func show_state(stage: int, item: int, growth: int, band: int, ripe_hours: int, title: String, status: String) -> void:
	"""Draw the bed at this stage (farm_look.gd decides the look)."""
	var heads: bool = Look.shows_heads(stage, item)
	_show_heads(heads, item)
	_furrows.visible = stage == SimScript.STAGE_SOWN
	var sheen_colour: Color = Look.sheen(band)
	var sheen_material := _sheen.material_override as StandardMaterial3D
	sheen_material.albedo_color = sheen_colour
	sheen_material.roughness = Look.sheen_roughness(band)
	_sheen.visible = sheen_colour.a > 0.0 and not heads
	_puddles.visible = Look.shows_puddles(band) and not heads
	_show_plants(stage, item, growth, heads)
	label.text = "%s\n%s" % [title, status]
	label.modulate = Look.urgency(stage, band, ripe_hours)


func _show_plants(stage: int, item: int, growth: int, heads: bool) -> void:
	"""Lay out (once per kind), cell, scale and colour the plants for the stage; none when bare or
	showing heads."""
	var scale_now: float = Look.plant_scale(stage, growth)
	var visible_now: bool = scale_now > 0.0 and not heads and Catalog.is_item(item)
	_show_parts(visible_now, false)
	if not visible_now:
		return
	var kind: int = Catalog.ITEM_VISUAL[item]
	if kind != _kind:
		_rebuild(kind)
	_show_parts(true, _heads_mm != null and Look.shows_head_mesh(stage, growth))
	_paint(stage, item, growth)
	var key: int = stage * 100000 + growth / GROWTH_STEP
	if key != _shown_key:
		_shown_key = key
		_assign_cells(stage, growth)
		_place(scale_now, Look.droop(stage), Look.limp(stage))


func _show_parts(on: bool, heads: bool) -> void:
	"""The cards (and tops), or the head meshes, or nothing."""
	if _plants != null:
		_plants.visible = on and not heads
	if _tops != null:
		_tops.visible = on and not heads
	if _heads_mm != null:
		_heads_mm.visible = on and heads


func showing_cards() -> bool:
	"""Whether the bed draws its plants as cards now (tests)."""
	return _plants != null and _plants.visible


func showing_puddles() -> bool:
	"""Whether the bed shows standing puddles now (tests)."""
	return _puddles.visible


func sheen_colour() -> Color:
	"""The soil sheen's colour now (tests)."""
	return (_sheen.material_override as StandardMaterial3D).albedo_color


func showing_head_meshes() -> bool:
	"""Whether the bed draws its plants as head meshes now (tests)."""
	return _heads_mm != null and _heads_mm.visible


func _paint(stage: int, item: int, growth: int) -> void:
	"""Tint, bleach and blotch the bed's card materials for the stage; tint the head meshes."""
	var tint: Vector3 = Look.plant_tint(stage, item, growth)
	if _heads_mm != null:
		(_heads_mm.material_override as BaseMaterial3D).albedo_color = Color(tint.x, tint.y, tint.z)
	for material: Material in [_card_material, _top_material]:
		if material != null:
			AssetsScript.set_tint(material, tint)
			AssetsScript.set_blight(material, Look.bleach(stage), Look.spots(stage))


func cells_for(stage: int, growth: int) -> PackedInt32Array:
	"""The atlas cells this bed's plants show at a stage: a library plant's stage subset
	(farm_look.gd stage_cells), or every cell of an old atlas's kind."""
	if Catalog.is_plant_kind(_kind):
		return PackedInt32Array(Look.stage_cells(stage, growth))
	return _assets.cells[_kind]


func _assign_cells(stage: int, growth: int) -> void:
	"""Give each plant (and its top) a cell of the stage's subset, spread by a per-bed stride."""
	var shown: PackedInt32Array = cells_for(stage, growth)
	var plant_kind: bool = Catalog.is_plant_kind(_kind)
	for i: int in _layout.size():
		var cell: int = shown[(i * 7 + bed) % shown.size()]
		_cells_shown[i] = cell
		_plants.multimesh.set_instance_custom_data(i, Color(float(cell), 0.0, 0.0, 0.0))
		if _tops != null:
			var top: int = TOP_OF_CELL[cell] if plant_kind else cell
			_tops.multimesh.set_instance_custom_data(i, Color(float(top), 0.0, 0.0, 0.0))


func _rebuild(kind: int) -> void:
	"""New plant MultiMeshes and a new layout for a visual kind (only when the kind changes)."""
	_assets.ensure_loaded(kind)
	_kind = kind
	_shown_key = -1
	for node: Node in [_plants, _tops, _heads_mm]:
		if node == null:
			continue
		_units.remove_child(node)
		node.queue_free()
	_layout = _layout_for(kind)
	_cells_shown.resize(_layout.size())
	_heads_mm = _head_node(kind)
	var cell: Vector2 = _assets.card_cell[kind]
	var mesh: ArrayMesh = CropCards.card_mesh(cell)
	_card_material = _assets.card_material(kind, Vector3.ONE)
	mesh.surface_set_material(0, _card_material)
	_plants = _multimesh(mesh, _layout.size(), "Plants")
	_units.add_child(_plants)
	_tops = null
	_top_material = null
	if _assets.top_texture[kind] != null:
		var top: ArrayMesh = CropCards.top_mesh(_assets.top_cell[kind])
		_top_material = _assets.top_material(kind, Vector3.ONE)
		top.surface_set_material(0, _top_material)
		_tops = _multimesh(top, _layout.size(), "Tops")
		_units.add_child(_tops)


func _head_node(kind: int) -> MultiMeshInstance3D:
	"""A head plant's mesh for every plant of the layout, with the bed's own tinted copy of its
	material; null when the kind has no staged head mesh."""
	var mesh: Mesh = _assets.head_mesh[kind]
	if mesh == null:
		return null
	var node: MultiMeshInstance3D = _multimesh(mesh, _layout.size(), "Heads")
	var source := mesh.surface_get_material(0) as BaseMaterial3D
	node.material_override = source.duplicate() if source != null else StandardMaterial3D.new()
	node.visible = false
	_units.add_child(node)
	return node


func _multimesh(mesh: Mesh, count: int, node_name: String) -> MultiMeshInstance3D:
	"""A MultiMesh of `count` plants, each showing the atlas cell in its custom data red (set by
	_assign_cells)."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


func _layout_for(kind: int) -> Array[Transform3D]:
	"""Where each plant stands (bed units) and its own yaw and size: a jittered grid, seeded by bed."""
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + bed * 31 + kind
	var grid: Vector2i = _assets.grid[kind]
	var span: float = (_assets.inner_half - 0.08) * 2.0
	var out: Array[Transform3D] = []
	for row: int in grid.x:
		for column: int in grid.y:
			var u: float = (column + 0.5 + rng.randf_range(-JITTER, JITTER)) / grid.y
			var v: float = (row + 0.5 + rng.randf_range(-JITTER, JITTER) * 0.5) / grid.x
			var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * rng.randf_range(SCALE_JITTER.x, SCALE_JITTER.y))
			out.append(Transform3D(basis, Vector3((u - 0.5) * span, _assets.soil_y - 0.01, (v - 0.5) * span)))
	return out


func _place(scale_now: float, lean: float, slump: float) -> void:
	"""Scale every plant (and its top) to the stage, drooping and slumping when withered."""
	shown_scale = scale_now
	var top_height: float = _assets.card_cell[_kind].y * top_lift(_kind) * slump
	var top_scale: float = scale_now * top_size(_kind)
	for i: int in _layout.size():
		_plants.multimesh.set_instance_transform(i, plant_transform(i, scale_now, lean, slump))
		if _heads_mm != null:
			_heads_mm.multimesh.set_instance_transform(i, plant_transform(i, scale_now, lean, slump) * _assets.head_fit[_kind])
		if _tops != null:
			var t: Transform3D = _layout[i]
			var up: Vector3 = t.origin + Vector3(0.0, top_height * scale_now, 0.0)
			_tops.multimesh.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3.ONE * top_scale), up))


static func top_lift(kind: int) -> float:
	"""Where a kind's top card lies, as a share of its standing card's height (the old atlases: 0.55)."""
	return Catalog.PLANT_TOP_LIFT[kind - Catalog.VIS_PLANT_FIRST] if Catalog.is_plant_kind(kind) else OLD_TOP_LIFT


static func top_size(kind: int) -> float:
	"""How much larger than the standing cards a kind's top card is drawn (the old atlases: as large)."""
	return Catalog.PLANT_TOP_SCALE[kind - Catalog.VIS_PLANT_FIRST] if Catalog.is_plant_kind(kind) else 1.0


func plant_transform(i: int, scale_now: float, lean: float, slump: float = 1.0) -> Transform3D:
	"""Plant `i` at `scale_now` of its own size, leaning `lean` radians and keeping `slump` of its
	height (bed units)."""
	var t: Transform3D = _layout[i]
	var basis: Basis = (Basis(Vector3.RIGHT, lean) * t.basis).scaled(Vector3.ONE * scale_now)
	return Transform3D(Basis.from_scale(Vector3(1.0, slump, 1.0)) * basis, t.origin)


func _show_heads(on: bool, item: int) -> void:
	"""The staged cabbage heads in place of bed and plants for a ripe leaf crop, tinted per item."""
	_base.visible = not on or _assets.heads_scene == null
	if not on or _assets.heads_scene == null:
		if _heads != null:
			_heads.visible = false
		return
	if _heads == null:
		_heads = _assets.heads_scene.instantiate() as Node3D
		_heads.scale = Vector3.ONE * (_assets.heads_scale / _assets.bed_scale)
		_units.add_child(_heads)
	_heads.visible = true
	if item != _heads_item:
		_heads_item = item
		_tint_heads(Catalog.ITEM_TINT[item])


func _tint_heads(tint: Color) -> void:
	"""Tint the heads' own materials (duplicated per bed, once per item change)."""
	for node: Node in _heads.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var copy := source.duplicate() as BaseMaterial3D
			copy.albedo_color = source.albedo_color * tint
			mesh_instance.set_surface_override_material(surface, copy)


func set_selected(on: bool) -> void:
	"""Show the brass outline round a selected bed."""
	ring.visible = on


func set_compared(on: bool) -> void:
	"""Show the Compare view's cream ring round the bed (decision 0451)."""
	if on and compare_ring == null:
		compare_ring = _outline("Compared", COMPARE_COLOUR, COMPARE_HALF_M)
		add_child(compare_ring)
	if compare_ring != null:
		compare_ring.visible = on


func show_overlay(colour: Color) -> void:
	"""Show the map-overlay disc in `colour` (alpha 0 hides it)."""
	overlay.visible = colour.a > 0.0
	(overlay.material_override as StandardMaterial3D).albedo_color = colour


func plant_count() -> int:
	"""How many plants the bed draws (0 with none laid out)."""
	return _layout.size() if _plants != null and _plants.visible else 0


func cell_shown(i: int) -> int:
	"""The atlas cell plant `i` shows (tests)."""
	return _cells_shown[i]


func visual_kind() -> int:
	"""The visual kind the bed's plants are laid out for (-1: none yet; tests)."""
	return _kind


func layout_scale(i: int) -> float:
	"""Plant `i`'s own size in the layout (its jitter; tests)."""
	return _layout[i].basis.get_scale().x
