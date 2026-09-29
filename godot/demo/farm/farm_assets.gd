extends RefCounted
## The staged art the farm's beds are drawn with, loaded once. Decision 0196. Presentation only.
##
## From the demo manifest's world rows:
##   * the bare bed (`crop_roots_ripe.path`, crop_bed.glb) and the ripe cabbage bed whose heads a
##     ripe cabbage or spinach bed shows (`crop_cabbage_ripe.path`) -- tools/make_demo_crop_cards.py;
##   * the OLD card atlases: wheat (`crop_grain_ripe.cards`) and the roots bed's turnips and carrots
##     with their tops (`crop_roots_ripe.cards`), which the items without a plant of their own
##     borrow (farm_catalog.gd VISUAL KINDS);
##   * one card set per LIBRARY PLANT (`plant_*.cards`, tools/make_demo_props.py): four cells -- full,
##     side, thinned, sparse -- and, for rosettes, their tops. A plant's cells are rendered in its
##     source's units; they are converted here to bed units at the plant's demo height
##     (farm_catalog.gd PLANT_HEIGHT_M), and each plant kind gets a planting grid spaced by its width.
##     A plant's atlases are read from disk the first time a bed shows it (`ensure_loaded`), not all
##     eleven up front: the demo's textures are held uncompressed, ~7 MB a plant.
## With nothing staged (CI, a fresh clone) every piece has a placeholder of the same size: a soil box
## and plain green cards.

const Sizes := preload("res://demo/world/world_sizes.gd")
const CropCards := preload("res://demo/world/crop_cards.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const BED_KEY: StringName = &"crop_roots_ripe"
const WHEAT_KEY: StringName = &"crop_grain_ripe"
const HEADS_KEY: StringName = &"crop_cabbage_ripe"
## Placeholder sizes, in bed units (the staged bed is ~1.9 units wide, drawn 1.9 m).
const PLACEHOLDER_CELL: Vector2 = Vector2(0.2, 0.3)
const PLACEHOLDER_SOIL_Y: float = 0.14
const PLACEHOLDER_GREEN: Color = Color(0.36, 0.55, 0.3)
const PLACEHOLDER_SOIL: Color = Color(0.3, 0.22, 0.15)
const PLACEHOLDER_INNER: float = 0.86
## Plants per bed (rows x columns) for the old atlases, as they were laid out before.
const OLD_GRID: Array[Vector2i] = [Vector2i(14, 14), Vector2i(4, 6), Vector2i(5, 8)]
## A library plant stands its kind's share of its card's width (farm_catalog.gd PLANT_SPACING) from
## the next one, in a grid of at least MIN_GRID and at most MAX_GRID a side.
const MIN_GRID: int = 3
const MAX_GRID: int = 14

var bed_scene: PackedScene = null
## The bare bed's `cards` block (its soil height and inner area), for the soil underlay.
var bed_cards: Dictionary = {}
var heads_scene: PackedScene = null
var bed_scale: float = 1.0
var heads_scale: float = 1.0
var soil_y: float = PLACEHOLDER_SOIL_Y
var inner_half: float = PLACEHOLDER_INNER
## Per visual kind (farm_catalog VIS_*): the card atlas, its cell size in bed units, its variants,
## which cells the kind uses (old atlases), the tops atlas (null: none), the planting grid.
var card_texture: Array[Texture2D] = []
var top_texture: Array[Texture2D] = []
var card_cell: Array[Vector2] = []
var top_cell: Array[float] = []
var variants: PackedInt32Array = PackedInt32Array()
var top_variants: PackedInt32Array = PackedInt32Array()
var cells: Array[PackedInt32Array] = []
var grid: Array[Vector2i] = []
## Per visual kind: a head plant's close-up mesh (null: none, or not staged) and its fit into bed units.
var head_mesh: Array[Mesh] = []
var head_fit: Array[Transform3D] = []
## Plant kinds whose atlases are staged but not yet read: kind -> its `cards` block.
var _deferred: Dictionary = {}


func _init() -> void:
	"""Every kind starts as a placeholder."""
	for kind: int in Catalog.VIS_COUNT:
		card_texture.append(null)
		top_texture.append(null)
		card_cell.append(PLACEHOLDER_CELL)
		top_cell.append(0.0)
		variants.append(1)
		top_variants.append(1)
		cells.append(PackedInt32Array([0]))
		head_mesh.append(null)
		head_fit.append(Transform3D.IDENTITY)
		grid.append(OLD_GRID[kind] if kind < Catalog.VIS_PLANT_FIRST else Vector2i(MIN_GRID + 3, MIN_GRID + 3))


func load_from(manifest: Dictionary) -> void:
	"""Read what is staged; leave placeholders for what is not."""
	var world: Dictionary = manifest.get("world", {})
	var bed: Dictionary = world.get(String(BED_KEY), {})
	bed_scene = _scene(bed.get("path", ""))
	if bed_scene != null:
		bed_scale = _scale(BED_KEY, bed)
	var heads: Dictionary = world.get(String(HEADS_KEY), {})
	heads_scene = _scene(heads.get("path", ""))
	if heads_scene != null:
		heads_scale = _scale(HEADS_KEY, heads)
	var wheat: Dictionary = world.get(String(WHEAT_KEY), {})
	if wheat.has("cards"):
		_take_cards(Catalog.VIS_WHEAT, wheat["cards"], "wheat")
	if bed.has("cards"):
		bed_cards = bed["cards"]
		_take_cards(Catalog.VIS_TURNIP, bed["cards"], "turnip")
		_take_cards(Catalog.VIS_CARROT, bed["cards"], "carrot")
	for kind: int in range(Catalog.VIS_PLANT_FIRST, Catalog.VIS_COUNT):
		var plant: Dictionary = world.get(String(Catalog.plant_key_of(kind)), {})
		if plant.has("cards"):
			_take_plant(kind, plant["cards"])
			_take_head(kind, plant)


func is_staged() -> bool:
	"""Whether the real bed is staged (else everything is a placeholder)."""
	return bed_scene != null


func has_cards(kind: int) -> bool:
	"""Whether a visual kind's real cards are staged (loaded, or waiting to be)."""
	return card_texture[kind] != null or _deferred.has(kind)


func _take_cards(kind: int, cards: Dictionary, cell_kind: String) -> void:
	"""One old visual kind's atlas, cells and tops from a manifest `cards` block."""
	var texture: Texture2D = _texture(String(cards.get("texture", "")))
	if texture == null:
		return
	card_texture[kind] = texture
	var cell_m: Array = cards["cell_m"]
	card_cell[kind] = Vector2(float(cell_m[0]), float(cell_m[1]))
	variants[kind] = int(cards["variants"])
	cells[kind] = PackedInt32Array((cards["kinds"] as Dictionary).get(cell_kind, [0]))
	soil_y = float(cards.get("soil_y", soil_y))
	inner_half = absf(float((cards["inner"] as Array)[0]))
	if cards.has("tops"):
		var tops: Dictionary = cards["tops"]
		top_texture[kind] = _texture(String(tops.get("texture", "")))
		top_cell[kind] = float((tops["cell_m"] as Array)[0])
		top_variants[kind] = int(tops["variants"])


func _take_plant(kind: int, cards: Dictionary) -> void:
	"""A library plant's cards, converted from its source's units to bed units at its demo height; its
	atlases are read later (`ensure_loaded`)."""
	if String(cards.get("texture", "")).is_empty():
		return
	var cell_m: Array = cards["cell_m"]
	var to_bed: float = plant_units(kind, float(cell_m[1]), bed_scale)
	card_cell[kind] = Vector2(float(cell_m[0]), float(cell_m[1])) * to_bed
	variants[kind] = int(cards["variants"])
	cells[kind] = PackedInt32Array(range(variants[kind]))
	grid[kind] = plant_grid(card_cell[kind].x, inner_half, Catalog.PLANT_SPACING[kind - Catalog.VIS_PLANT_FIRST])
	if cards.has("tops"):
		var tops: Dictionary = cards["tops"]
		top_cell[kind] = float((tops["cell_m"] as Array)[0]) * to_bed
		top_variants[kind] = int(tops["variants"])
	_deferred[kind] = cards


func ensure_loaded(kind: int) -> void:
	"""Read a staged plant's atlases now if they have not been (a bed is about to show it). One that
	will not load leaves the kind drawn as placeholders."""
	if not _deferred.has(kind):
		return
	var cards: Dictionary = _deferred[kind]
	_deferred.erase(kind)
	card_texture[kind] = _texture(String(cards["texture"]))
	if cards.has("tops"):
		top_texture[kind] = _texture(String((cards["tops"] as Dictionary).get("texture", "")))


func _take_head(kind: int, row: Dictionary) -> void:
	"""A head plant's close-up mesh (its row's model), in bed units at the plant's demo height: the
	model's soil line is at its origin, as the cards'."""
	if not Catalog.PLANT_HEAD_MESH[kind - Catalog.VIS_PLANT_FIRST] or not has_cards(kind):
		return
	var scene: PackedScene = _scene(String(row.get("path", "")))
	if scene == null:
		return
	var root: Node = scene.instantiate()
	var found: Array = PropsScript.first_mesh(root, Transform3D.IDENTITY)
	root.free()
	if found.is_empty():
		return
	head_mesh[kind] = found[0]
	var to_bed: float = plant_units(kind, float((row["cards"]["cell_m"] as Array)[1]), bed_scale)
	head_fit[kind] = Transform3D(Basis.from_scale(Vector3.ONE * to_bed), Vector3.ZERO) * (found[1] as Transform3D)


static func plant_units(kind: int, cell_height: float, p_bed_scale: float) -> float:
	"""Bed units per source unit for a plant kind: its card, `cell_height` source units tall, drawn
	at the plant's demo height in a bed drawn at `p_bed_scale` metres per bed unit."""
	var height_m: float = Catalog.PLANT_HEIGHT_M[kind - Catalog.VIS_PLANT_FIRST]
	return height_m / (cell_height * p_bed_scale)


static func plant_grid(cell_width: float, p_inner_half: float, spacing: float) -> Vector2i:
	"""The planting grid for plants `cell_width` wide (bed units), `spacing` of their width apart,
	over a bed's inner area."""
	var span: float = (p_inner_half - 0.08) * 2.0
	var side: int = clampi(floori(span / (cell_width * spacing)), MIN_GRID, MAX_GRID)
	return Vector2i(side, side)


static func _scene(path: String) -> PackedScene:
	"""A staged model, or null."""
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


static func _scale(key: StringName, entry: Dictionary) -> float:
	"""The world's own scale for a crop model (world_sizes.gd: 1.9 m wide)."""
	var lo: Array = entry["aabb_min"]
	var hi: Array = entry["aabb_max"]
	return Sizes.uniform_scale(key, Vector3(lo[0], lo[1], lo[2]), Vector3(hi[0], hi[1], hi[2]))


static func _texture(path: String) -> Texture2D:
	"""A staged atlas with mipmaps (as demo_world loads it), or null."""
	if path.is_empty():
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func card_material(kind: int, tint: Vector3) -> Material:
	"""A bed's own plant material for a visual kind: the atlas shader tinted, or plain green."""
	if card_texture[kind] == null:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(PLACEHOLDER_GREEN.r * tint.x, PLACEHOLDER_GREEN.g * tint.y, PLACEHOLDER_GREEN.b * tint.z)
		plain.cull_mode = BaseMaterial3D.CULL_DISABLED
		return plain
	var material: ShaderMaterial = CropCards.card_material(card_texture[kind], variants[kind], false)
	material.set_shader_parameter(&"tint", tint)
	return material


func top_material(kind: int, tint: Vector3) -> Material:
	"""A bed's top-down leaf material for a visual kind (only when staged)."""
	var material: ShaderMaterial = CropCards.card_material(top_texture[kind], top_variants[kind], true)
	material.set_shader_parameter(&"tint", tint)
	return material


static func set_tint(material: Material, tint: Vector3) -> void:
	"""Re-tint a material made by card_material/top_material."""
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(&"tint", tint)
	elif material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color = Color(PLACEHOLDER_GREEN.r * tint.x,
			PLACEHOLDER_GREEN.g * tint.y, PLACEHOLDER_GREEN.b * tint.z)


static func set_blight(material: Material, bleach: float, spots: float) -> void:
	"""Bleach and blotch a card material (crop_card.gdshader); a placeholder shows neither."""
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(&"bleach", bleach)
		(material as ShaderMaterial).set_shader_parameter(&"spots", spots)


func make_bed() -> Node3D:
	"""A bare bed in bed units: the staged frame and soil, or a soil box."""
	if bed_scene != null:
		var staged := bed_scene.instantiate() as Node3D
		if not bed_cards.is_empty():
			staged.add_child(CropCards.soil_underlay(bed_cards))
		return staged
	var box := BoxMesh.new()
	box.size = Vector3(1.9, PLACEHOLDER_SOIL_Y, 1.9)
	var material := StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_SOIL
	box.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position.y = PLACEHOLDER_SOIL_Y * 0.5
	return instance
