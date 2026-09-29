extends RefCounted
## The staged art the farm's beds are drawn with, loaded once. Decision 0196. Presentation only.
##
## Everything comes from the demo manifest's world rows that tools/make_demo_crop_cards.py writes:
## the bare bed (`crop_roots_ripe.path`, crop_bed.glb), the wheat atlas (`crop_grain_ripe.cards`),
## the roots atlas with its top-down tops (`crop_roots_ripe.cards`) and the ripe cabbage bed
## (`crop_cabbage_ripe.path`) whose heads a ripe leaf crop shows. With nothing staged (CI, a fresh
## clone) every piece has a placeholder of the same size: a soil box and plain green cards.
## No new art is generated.

const Sizes := preload("res://demo/world/world_sizes.gd")
const CropCards := preload("res://demo/world/crop_cards.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

const BED_KEY: StringName = &"crop_roots_ripe"
const WHEAT_KEY: StringName = &"crop_grain_ripe"
const HEADS_KEY: StringName = &"crop_cabbage_ripe"
## Placeholder sizes, in bed units (the staged bed is ~1.9 units wide, drawn 1.9 m).
const PLACEHOLDER_CELL: Vector2 = Vector2(0.2, 0.3)
const PLACEHOLDER_SOIL_Y: float = 0.14
const PLACEHOLDER_GREEN: Color = Color(0.36, 0.55, 0.3)
const PLACEHOLDER_SOIL: Color = Color(0.3, 0.22, 0.15)
const PLACEHOLDER_INNER: float = 0.86

var bed_scene: PackedScene = null
## The bare bed's `cards` block (its soil height and inner area), for the soil underlay.
var bed_cards: Dictionary = {}
var heads_scene: PackedScene = null
var bed_scale: float = 1.0
var heads_scale: float = 1.0
var soil_y: float = PLACEHOLDER_SOIL_Y
var inner_half: float = PLACEHOLDER_INNER
## Per visual kind (farm_catalog VIS_*): the card atlas, its cell size, its variants, which cells
## the kind uses, and the tops atlas (null: none).
var card_texture: Array[Texture2D] = [null, null, null]
var top_texture: Array[Texture2D] = [null, null, null]
var card_cell: Array[Vector2] = [PLACEHOLDER_CELL, PLACEHOLDER_CELL, PLACEHOLDER_CELL]
var top_cell: Array[float] = [0.0, 0.0, 0.0]
var variants: PackedInt32Array = PackedInt32Array([1, 1, 1])
var top_variants: PackedInt32Array = PackedInt32Array([1, 1, 1])
var cells: Array[PackedInt32Array] = [PackedInt32Array([0]), PackedInt32Array([0]), PackedInt32Array([0])]


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


func is_staged() -> bool:
	"""Whether the real bed is staged (else everything is a placeholder)."""
	return bed_scene != null


func _take_cards(kind: int, cards: Dictionary, cell_kind: String) -> void:
	"""One visual kind's atlas, cells and tops from a manifest `cards` block."""
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
