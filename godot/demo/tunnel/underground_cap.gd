extends Node3D
## The underground view's section cap, its backstop and its light. Decision 0206 (the underground
## revamp's P0; design docs/design/underground_revamp.md §5 "The section cap"). Presentation only.
##
## THE CAP is one plane at Layers.CAP_Y_M on the UNDERGROUND layer, drawn with underground_cap.gdshader:
## solid earth cut through at the level, which the troughs and rooms are seen in. It shows, read where the
## view ray meets the FLOOR (so it lies under the floor point a click lands on):
##   * THE STRATA: the ground map (tunnel_ground.gd) -- loam, clay, sand and rock pockets, wet ground
##     tinted -- exactly where they slow or weaken a dig, with a grain;
##   * THE NO-DIG BAND: a blue hatch wherever a bore is refused for water -- within half a bore of it,
##     the tunnel plan's own clearance (tunnel_plan.gd WATER) -- and the water itself darker inside it;
##   * FOOTINGS: the buildings' and the well's circles, widened by the half bore a route keeps off them
##     (tunnel_rules.gd), faintly stone inside and outlined in stone round their union (a signed
##     distance in the marks, so the outline is smooth at 4 px a metre);
##   * ROOTS: a tangle of roots under each mature tree, out to its root skirt (forest_roots.gd reach_m) --
##     the sunk root balls themselves are on the surface layer and never show here;
##   * VOIDS: every dug metre of bore at full depth and every dug room is stamped into a mask as it is
##     dug (`stamp_disc`, `stamp_rect`; a disc's rim anti-aliased, so the cut edge is smooth at 8 px a
##     metre); the cap is discarded over them, with a dark cut band at the edge.
## THE BACKSTOP is a dark plane DEEP_Y_M down, so a sliver seen past a trough's wall is deep earth.
## THE LIGHT is a directional fill on the UNDERGROUND layer only; the sun is on the surface layer, so each
## view is lit by its own and the U view casts no sun shadows (demo_layers.gd).
##
## Built once, at boot; the masks are sized once and only their pixels change.

const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const GroundViewScript := preload("res://demo/tunnel/tunnel_ground_view.gd")
const WaterScript := preload("res://demo/village_water.gd")
const RootsScript := preload("res://demo/forestry/forest_roots.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const CAP_SHADER := preload("res://demo/tunnel/underground_cap.gdshader")

## The mapped square: MAP_HALF_M either side of the village's centre (the play square, the stream and
## the pond; beyond it the edge texels carry on).
const MAP_HALF_M: float = 40.0
const MAP_SIDE_M: int = 80
const GROUND_PX_PER_M: int = 1
const MARKS_PX_PER_M: int = 4
const VOID_PX_PER_M: int = 8
## The water's signed distance is stored as 0.5 + (margin + clearance) / (2 * WATER_RANGE_M).
const WATER_RANGE_M: float = 4.0
## A bore keeps half its width off water (tunnel_plan.gd WATER): the no-dig band's width.
const WATER_CLEARANCE_M: float = Rules.BORE_WIDTH_U / 2.0 / Rules.QUANTUM_U
const PLANE_SIZE_M: float = 400.0
const DEEP_Y_M: float = -4.0
const DEEP_COLOUR: Color = Color(0.09, 0.065, 0.05)
## The footings' signed distance is stored over +-FOOTING_RANGE_M (the shader's `footing_range_m`).
const FOOTING_RANGE_M: float = 1.0
## Roots: this many from each tree, starting this share of its reach out, bending this much.
const ROOTS_PER_TREE: int = 7
const ROOT_START_SHARE: float = 0.08
const ROOT_BEND_RAD: float = 0.35
const ROOT_BALL_SHARE: float = 0.22
const LIGHT_COLOUR: Color = Color(1.0, 0.9, 0.76)
const LIGHT_ENERGY: float = 0.85
const LIGHT_EULER_DEG: Vector3 = Vector3(-62.0, 35.0, 0.0)

var _ground_image: Image = null
var _marks: PackedByteArray = PackedByteArray()
var _marks_texture: ImageTexture = null
var _void_image: Image = null
var _void_texture: ImageTexture = null
var _void_dirty: bool = false
var _cap: MeshInstance3D = null
var _deep: MeshInstance3D = null
var _light: DirectionalLight3D = null
var _material: ShaderMaterial = null


func configure(ground: GroundScript, water: WaterScript) -> void:
	"""Build the cap over this ground and water, its backstop and its light (see the header)."""
	name = "UndergroundCap"
	_ground_image = ground_image(ground, water)
	var side: int = MAP_SIDE_M * MARKS_PX_PER_M
	_marks.resize(side * side * 4)
	_marks_texture = ImageTexture.create_from_image(Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, _marks))
	var void_side: int = MAP_SIDE_M * VOID_PX_PER_M
	_void_image = Image.create(void_side, void_side, false, Image.FORMAT_R8)
	_void_texture = ImageTexture.create_from_image(_void_image)
	_material = _cap_material()
	_cap = _plane(Layers.CAP_Y_M, _material)
	_deep = _plane(DEEP_Y_M, _deep_material())
	_light = _fill_light()


func _cap_material() -> ShaderMaterial:
	"""The cap's material over its three maps and a grain."""
	var material := ShaderMaterial.new()
	material.shader = CAP_SHADER
	material.set_shader_parameter(&"ground_map", ImageTexture.create_from_image(_ground_image))
	material.set_shader_parameter(&"marks_map", _marks_texture)
	material.set_shader_parameter(&"void_map", _void_texture)
	material.set_shader_parameter(&"grain", _grain())
	material.set_shader_parameter(&"map_rect", Vector3(-MAP_HALF_M, -MAP_HALF_M, 1.0 / float(MAP_SIDE_M)))
	material.set_shader_parameter(&"floor_y", Layers.FLOOR_Y_M)
	material.set_shader_parameter(&"water_line", 0.5 + WATER_CLEARANCE_M / (2.0 * WATER_RANGE_M))
	return material


static func _grain() -> NoiseTexture2D:
	"""A soft seamless grain for the earth."""
	var noise := FastNoiseLite.new()
	noise.seed = 206
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


static func _deep_material() -> StandardMaterial3D:
	"""Deep earth: dark and rough."""
	var material := StandardMaterial3D.new()
	material.albedo_color = DEEP_COLOUR
	material.roughness = 1.0
	return material


func _plane(y: float, material: Material) -> MeshInstance3D:
	"""A wide flat plane at `y` on the UNDERGROUND layer."""
	var plane := PlaneMesh.new()
	plane.size = Vector2(PLANE_SIZE_M, PLANE_SIZE_M)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = material
	node.position.y = y
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = Layers.UNDERGROUND
	add_child(node)
	return node


func _fill_light() -> DirectionalLight3D:
	"""The underground's own light: lights the UNDERGROUND layer only, and is culled with it."""
	var light := DirectionalLight3D.new()
	light.name = "UndergroundLight"
	light.rotation_degrees = LIGHT_EULER_DEG
	light.light_color = LIGHT_COLOUR
	light.light_energy = LIGHT_ENERGY
	light.shadow_enabled = false
	light.layers = Layers.UNDERGROUND
	light.light_cull_mask = Layers.UNDERGROUND
	add_child(light)
	return light


# --- the ground map ---------------------------------------------------------------------------

static func ground_image(ground: GroundScript, water: WaterScript) -> Image:
	"""The strata and the water's distance, a pixel a metre over the mapped square (see the shader)."""
	var image := Image.create(MAP_SIDE_M * GROUND_PX_PER_M, MAP_SIDE_M * GROUND_PX_PER_M, false, Image.FORMAT_RGBA8)
	for r: int in image.get_height():
		for c: int in image.get_width():
			var at := Vector2i(Rules.to_u(-MAP_HALF_M + float(c) + 0.5), Rules.to_u(-MAP_HALF_M + float(r) + 0.5))
			var margin_m: float = Rules.to_m(water.map().inside_margin_u(at))
			image.set_pixel(c, r, Color(_ground_colour(ground, water, at), water_code(margin_m)))
	return image


static func _ground_colour(ground: GroundScript, water: WaterScript, at: Vector2i) -> Color:
	"""The ground's colour at `at` (u): the grid's cell inside it, loam (wet by the water) outside."""
	var inside: bool = at.x >= ground.origin_u.x and at.y >= ground.origin_u.y \
			and at.x < ground.origin_u.x + ground.columns * GroundScript.CELL_U \
			and at.y < ground.origin_u.y + ground.rows * GroundScript.CELL_U
	if inside:
		return GroundViewScript.colour_of(ground.cells[ground.cell_of(at.x, at.y)])
	var wet: bool = water.near_water(at.x, at.y)
	return GroundViewScript.colour_of(GroundScript.LOAM | (GroundScript.WET_BIT if wet else 0))


static func water_code(margin_m: float) -> float:
	"""A water margin (m, > 0 inside) as the ground map's alpha: 0.5 at the no-dig edge."""
	return clampf(0.5 + (margin_m + WATER_CLEARANCE_M) / (2.0 * WATER_RANGE_M), 0.0, 1.0)


# --- marks: footings and roots ----------------------------------------------------------------

func add_footprints(circles: Array[Vector3]) -> int:
	"""Stone footings for these circles (x, radius, z), each widened by the half bore a route must keep
	off it: the union's signed distance (inside > 0) into the marks' R, as FOOTING_RANGE_M-scaled code --
	the largest over the circles is the union's -- so the shader draws a smooth outline and a faint fill.
	Returns how many were drawn."""
	var keep: float = Rules.to_m(Rules.BORE_WIDTH_U) * 0.5
	for circle: Vector3 in circles:
		var centre := Vector2(circle.x, circle.z)
		for pixel: Vector2i in _pixels_within(centre, circle.y + keep + FOOTING_RANGE_M):
			var inside: float = circle.y + keep - marks_centre(pixel).distance_to(centre)
			_mark_max(pixel, 0, 0.5 + inside / (2.0 * FOOTING_RANGE_M))
	_commit_marks()
	return circles.size()


func footing_m(at: Vector2) -> float:
	"""How far inside the footings `at` (x, z metres) is, from the marks (< 0 outside; checks)."""
	return (mark_at(at, 0) - 0.5) * 2.0 * FOOTING_RANGE_M


func add_roots(trees: Array[Dictionary]) -> int:
	"""A root tangle under each mature tree placement ({key, at, yaw, size}; saplings have none).
	Returns how many trees were drawn."""
	var drawn: int = 0
	for k: int in trees.size():
		var look: int = StandScript.LOOK_KEYS.find(trees[k]["key"])
		if look < 0:
			continue
		var reach: float = RootsScript.reach_m(look, float(trees[k].get("size", 1.0)))
		_root_tangle(trees[k]["at"], reach, float(trees[k].get("yaw", 0.0)) + float(k))
		drawn += 1
	_commit_marks()
	return drawn


func _root_tangle(centre: Vector2, reach: float, turn: float) -> void:
	"""A root ball and ROOTS_PER_TREE bending roots running out to `reach`, fading as they go."""
	for pixel: Vector2i in _pixels_within(centre, reach * ROOT_BALL_SHARE):
		_mark_max(pixel, 2, 0.55)
	var step: float = 1.0 / float(MARKS_PX_PER_M)
	for r: int in ROOTS_PER_TREE:
		var heading: float = turn + TAU * float(r) / float(ROOTS_PER_TREE)
		var along: float = reach * ROOT_START_SHARE
		while along < reach:
			var t: float = along / reach
			var angle: float = heading + ROOT_BEND_RAD * sin(t * 5.0 + float(r))
			var at: Vector2 = centre + Vector2(cos(angle), sin(angle)) * along
			_mark_max(marks_pixel(at), 2, 1.0 - 0.75 * t)
			along += step


static func marks_pixel(at: Vector2) -> Vector2i:
	"""The marks pixel holding the point `at` (x, z metres)."""
	return Vector2i(floori((at.x + MAP_HALF_M) * MARKS_PX_PER_M), floori((at.y + MAP_HALF_M) * MARKS_PX_PER_M))


static func marks_centre(pixel: Vector2i) -> Vector2:
	"""The centre of a marks pixel, (x, z) metres."""
	return Vector2((float(pixel.x) + 0.5) / MARKS_PX_PER_M - MAP_HALF_M, (float(pixel.y) + 0.5) / MARKS_PX_PER_M - MAP_HALF_M)


static func _pixels_within(centre: Vector2, reach: float) -> Array[Vector2i]:
	"""The marks pixels of the square round `centre` out to `reach` (clipped to the map)."""
	var lo: Vector2i = marks_pixel(centre - Vector2(reach, reach)).maxi(0)
	var hi: Vector2i = marks_pixel(centre + Vector2(reach, reach)).mini(MAP_SIDE_M * MARKS_PX_PER_M - 1)
	var out: Array[Vector2i] = []
	for y: int in range(lo.y, hi.y + 1):
		for x: int in range(lo.x, hi.x + 1):
			out.append(Vector2i(x, y))
	return out


func _mark_max(pixel: Vector2i, channel: int, value: float) -> void:
	"""Raise one channel of one marks pixel to `value` (0..1), if it lies on the map."""
	var side: int = MAP_SIDE_M * MARKS_PX_PER_M
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= side or pixel.y >= side:
		return
	var i: int = (pixel.y * side + pixel.x) * 4 + channel
	_marks[i] = maxi(_marks[i], roundi(clampf(value, 0.0, 1.0) * 255.0))


func _commit_marks() -> void:
	"""Upload the marks (boot only)."""
	var side: int = MAP_SIDE_M * MARKS_PX_PER_M
	_marks_texture.update(Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, _marks))


# --- voids ----------------------------------------------------------------------------------

static func void_pixel(at: Vector2) -> Vector2i:
	"""The void mask pixel holding the point `at` (x, z metres)."""
	return Vector2i(floori((at.x + MAP_HALF_M) * VOID_PX_PER_M), floori((at.y + MAP_HALF_M) * VOID_PX_PER_M))


func stamp_disc(centre: Vector2, radius: float, cut: Vector2 = Vector2.ZERO) -> void:
	"""Mark a disc of floor dug (a bore's cross-section at a step along it): each void pixel by how much
	of it the disc covers (its centre's distance inside the rim, in pixels, clamped to 0..1), raised,
	never lowered -- so the mask's 0.5 is the rim to a fraction of a pixel. A non-zero unit `cut` keeps
	only the half behind the line through the centre across it (a dig face). Uploaded by `commit_void`."""
	var reach: int = ceili(radius * VOID_PX_PER_M) + 1
	var middle: Vector2i = void_pixel(centre)
	var side: int = _void_image.get_width()
	for y: int in range(maxi(middle.y - reach, 0), mini(middle.y + reach + 1, side)):
		for x: int in range(maxi(middle.x - reach, 0), mini(middle.x + reach + 1, side)):
			var at := Vector2((float(x) + 0.5) / VOID_PX_PER_M - MAP_HALF_M, (float(y) + 0.5) / VOID_PX_PER_M - MAP_HALF_M)
			var inside: float = minf(radius - at.distance_to(centre), -(at - centre).dot(cut) if cut != Vector2.ZERO else radius)
			var cover: float = clampf(inside * VOID_PX_PER_M + 0.5, 0.0, 1.0)
			if cover > _void_image.get_pixel(x, y).r:
				_void_image.set_pixel(x, y, Color(cover, 0.0, 0.0))
				_void_dirty = true


func stamp_rect(centre: Vector2, half_m: float) -> void:
	"""Mark a square room's floor dug. Uploaded by `commit_void`."""
	var lo: Vector2i = void_pixel(centre - Vector2(half_m, half_m))
	var hi: Vector2i = void_pixel(centre + Vector2(half_m, half_m))
	for y: int in range(lo.y, hi.y):
		_fill_row(lo.x, hi.x - 1, y)


func _fill_row(x0: int, x1: int, y: int) -> void:
	"""Fill void pixels x0..x1 of row y (clipped to the mask)."""
	var side: int = _void_image.get_width()
	var a: int = maxi(x0, 0)
	var b: int = mini(x1, side - 1)
	if y < 0 or y >= side or b < a:
		return
	_void_image.fill_rect(Rect2i(a, y, b - a + 1, 1), Color(1.0, 0.0, 0.0))
	_void_dirty = true


func commit_void() -> bool:
	"""Upload the void mask if anything was stamped since the last upload. True when it was."""
	if not _void_dirty:
		return false
	_void_dirty = false
	_void_texture.update(_void_image)
	return true


func is_dug(at: Vector2) -> bool:
	"""Whether the floor at `at` (x, z metres) is stamped dug (tests and checks)."""
	var p: Vector2i = void_pixel(at)
	var side: int = _void_image.get_width()
	return p.x >= 0 and p.y >= 0 and p.x < side and p.y < side and _void_image.get_pixel(p.x, p.y).r > 0.5


# --- registry and checks ----------------------------------------------------------------------

func register(prewarm: PrewarmScript) -> void:
	"""What the cap draws, for the underground view's prewarm."""
	prewarm.add_mesh(_cap.mesh, _material)
	prewarm.add_mesh(_deep.mesh, _deep.material_override)


func cap() -> MeshInstance3D:
	"""The cap plane."""
	return _cap


func deep() -> MeshInstance3D:
	"""The deep-earth backstop."""
	return _deep


func light() -> DirectionalLight3D:
	"""The underground's fill light."""
	return _light


func mark_at(at: Vector2, channel: int) -> float:
	"""One channel (0 footings' distance code, 2 roots) of the marks at `at` (x, z metres), 0..1 (checks)."""
	var p: Vector2i = marks_pixel(at)
	var side: int = MAP_SIDE_M * MARKS_PX_PER_M
	if p.x < 0 or p.y < 0 or p.x >= side or p.y >= side:
		return 0.0
	return float(_marks[(p.y * side + p.x) * 4 + channel]) / 255.0


func water_code_at(at: Vector2) -> float:
	"""The ground map's water code at `at` (x, z metres): > 0.5 where no bore may go (checks)."""
	var p := Vector2i(clampi(floori(at.x + MAP_HALF_M), 0, MAP_SIDE_M - 1), clampi(floori(at.y + MAP_HALF_M), 0, MAP_SIDE_M - 1))
	return _ground_image.get_pixel(p.x, p.y).a
