extends Node3D
## The ground map, drawn. Decision 0196 (live demo). Presentation only.
##
## One texture, a pixel per ground cell (tunnel_ground.gd), drawn two ways:
##   * PLANNING: while a tunnel route is being laid, a see-through tint over the village's ground, so
##     the player sees the clay, sand, rock and wet ground a route would cross before digging it
##     (plain dry loam is left clear).
##   * UNDERGROUND (U): opaque, as the strata below the bores -- the tunnels are seen cut through it.
## Built once from the grid; showing and hiding it changes nothing else.

const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

## Per ground type (LOAM, CLAY, SAND, ROCK), muted earth colours, and the tint wet ground takes.
const COLOURS: Array[Color] = [Color(0.33, 0.24, 0.16), Color(0.55, 0.31, 0.21), Color(0.74, 0.64, 0.42),
	Color(0.47, 0.48, 0.47)]
const WET_TINT: Color = Color(0.30, 0.45, 0.62)
const WET_MIX: float = 0.45
## What the colours mean, for the tunnel panel while a route is laid.
const LEGEND: String = "Ground: rust is clay (slow), pale is sand (weak), grey is rock (needs the badger), blue is wet (floods)"
const PLAN_ALPHA: float = 0.72
const PLAN_LIFT_M: float = 0.03
const STRATA_Y_M: float = -1.9

var planning: bool = false
var underground: bool = false

var _plan: MeshInstance3D = null
var _strata: MeshInstance3D = null


func configure(ground: GroundScript) -> void:
	"""Build both drawings of `ground`, hidden."""
	name = "GroundView"
	var size := Vector2(Rules.to_m(ground.columns * GroundScript.CELL_U), Rules.to_m(ground.rows * GroundScript.CELL_U))
	var centre := Vector2(Rules.to_m(ground.origin_u.x), Rules.to_m(ground.origin_u.y)) + size * 0.5
	_plan = _plane(ImageTexture.create_from_image(image_of(ground, 0.0)), size, Vector3(centre.x, PLAN_LIFT_M, centre.y),
		PLAN_ALPHA)
	_strata = _plane(ImageTexture.create_from_image(image_of(ground, 1.0)), size, Vector3(centre.x, STRATA_Y_M, centre.y),
		1.0)


static func colour_of(cell: int) -> Color:
	"""A cell's colour: its type's, blue-tinted when wet."""
	var colour := COLOURS[cell & GroundScript.TYPE_MASK]
	return colour.lerp(WET_TINT, WET_MIX) if cell & GroundScript.WET_BIT != 0 else colour


static func image_of(ground: GroundScript, loam_alpha: float) -> Image:
	"""The ground as an image, one pixel per cell (row z, column x); plain loam at `loam_alpha`, so the
	planning tint shows only the ground that matters."""
	var image := Image.create(ground.columns, ground.rows, false, Image.FORMAT_RGBA8)
	for r in ground.rows:
		for c in ground.columns:
			var cell := ground.cells[r * ground.columns + c]
			var colour := colour_of(cell)
			var plain := cell & GroundScript.TYPE_MASK == GroundScript.LOAM and cell & GroundScript.WET_BIT == 0
			image.set_pixel(c, r, Color(colour, loam_alpha if plain else 1.0))
	return image


func _plane(texture: Texture2D, size: Vector2, at: Vector3, alpha: float) -> MeshInstance3D:
	"""A flat unshaded plane showing the ground texture, softly blended cell to cell, hidden."""
	var plane := PlaneMesh.new()
	plane.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.render_priority = 1
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


func set_planning(on: bool) -> void:
	"""Show the tint over the ground while a route is being laid."""
	planning = on
	_refresh()


func set_underground_view(on: bool) -> void:
	"""Show the strata below the bores in the underground view."""
	underground = on
	_refresh()


func _refresh() -> void:
	"""The planning tint shows only above ground; the strata only below."""
	_plan.visible = planning and not underground
	_strata.visible = underground


func plan_tint() -> MeshInstance3D:
	"""The planning tint (for checks)."""
	return _plan


func strata() -> MeshInstance3D:
	"""The strata below the bores (for checks)."""
	return _strata
