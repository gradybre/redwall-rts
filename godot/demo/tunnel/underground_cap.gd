extends Node3D
## The underground view's section cap, its backstop and its light. Decision 0206 (the underground
## revamp's P0; design docs/design/underground_revamp.md §5 "The section cap"). Presentation only.
##
## THE CAP is one plane at Layers.CAP_Y_M -- the section plane, at the widened bore's crown (decision
## 0207; P0's was half a bore up) -- on the UNDERGROUND layer, drawn with underground_cap.gdshader: solid
## earth cut through at the level, which the bores and rooms are seen in. It shows, read where the view
## ray meets the FLOOR (so it lies under the floor point a click lands on), in the one earth the bores'
## walls are drawn in (underground_earth.gdshaderinc):
##   * THE STRATA: the ground map (tunnel_ground.gd) -- loam, clay, sand and rock pockets, wet ground
##     tinted -- exactly where they slow or weaken a dig, with a grain;
##   * THE NO-DIG BAND: a blue hatch wherever a bore is refused for water -- within half a bore of it,
##     the tunnel plan's own clearance (tunnel_plan.gd WATER) -- and the water itself darker inside it;
##   * FOOTINGS: the buildings' and the well's circles, widened by the half bore a route keeps off them
##     (tunnel_rules.gd), faintly stone inside and outlined in stone round their union (a signed
##     distance in the marks, so the outline is smooth at 4 px a metre);
##   * ROOTS: a tangle of roots under each mature tree, out to its root skirt (forest_roots.gd reach_m) --
##     the sunk root balls themselves are on the surface layer and never show here;
##   * VOIDS (decision 0207): every dug step of a bore is stamped into a mask as it is dug
##     (`stamp_disc`): G holds each pixel's distance from the nearest bore disc over that disc's floor
##     half-width, B that disc's floor rise over the level's floor (a ramp's is higher), A its crown -- a
##     distance field, so the rim is smooth at any angle. The shader walks each view ray down from the cap
##     to the floor and cuts the cap away where the ray enters a bore's horseshoe at any height: the walls
##     rise to the crown under the section and the far wall shows through it (P0 read the floor point
##     only). A dug room's floor is R (`stamp_rect`), opened where the floor point is dug, as in P0. The
##     cut is edged with a dark band.
## THE BACKSTOP is a dark plane DEEP_Y_M down, so a sliver seen past a bore's wall is deep earth.
## THE LIGHT is a faint directional fill on the UNDERGROUND layer only -- the lanterns are the light below
## (tunnel_lanterns.gd); the sun is on the surface layer, so each view is lit by its own and the U view
## casts no sun shadows (demo_layers.gd).
##
## Built once, at boot; the masks are sized once and only their pixels change. The maps are shared with
## the bores' earth (`share_earth`).
##
## ONE CAP A LEVEL (decision 0212). A cap is built for a LEVEL: its plane at that level's section
## (demo_layers.gd `cap_y`), on that level's layer (`below`), reading at that level's floor; its strata the
## ground of that level (tunnel_ground.gd THE GROUND AT DEPTH); its void mask that level's alone -- a link is
## stamped into each level's mask where its void reaches that level's section (bore_view.gd LEVELS); its rises
## coded over RISE_RANGES_M (level 2's 4.25 m holds a link's whole drop); its backstop DEEP_YS_M under it and its own
## fill light on its own layer. Footings and roots are level 1's (nothing on the surface reaches the second level). The other
## level's mask is handed in (`set_other`), and the shader draws a faint OUTLINE of it (OTHER_STRENGTH).

const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const GroundViewScript := preload("res://demo/tunnel/tunnel_ground_view.gd")
const WaterScript := preload("res://demo/village_water.gd")
const RootsScript := preload("res://demo/forestry/forest_roots.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const CAP_SHADER := preload("res://demo/tunnel/underground_cap.gdshader")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")

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
const LIGHT_COLOUR: Color = Color(0.86, 0.8, 0.74)
const LIGHT_ENERGY: float = 0.5
## The void mask's channels (see VOIDS): a pixel is written out to RHO_REACH floor half-widths from a
## disc, its rise and crown coded over these ranges.
const VOID_ROOM: int = 0
const VOID_RHO: int = 1
const VOID_RISE: int = 2
const VOID_CROWN: int = 3
const RHO_RANGE: float = 2.0
const RHO_REACH: float = 1.5
const RISE_RANGE_M: float = 1.25
const CROWN_RANGE_M: float = 2.0
## A floor within this of the level's counts as the level's floor (`is_dug`).
const FLOOR_SLACK_M: float = 0.25
const LIGHT_EULER_DEG: Vector3 = Vector3(-62.0, 35.0, 0.0)
## ONE CAP A LEVEL: each level's rise range (m); the other level's outline.
const RISE_RANGES_M: Array[float] = [RISE_RANGE_M, RISE_RANGE_M, 4.25]
## Each level's backstop (m): as far under its floor as level 1's (DEEP_Y_M) is under level 1's.
const DEEP_YS_M: Array[float] = [DEEP_Y_M, DEEP_Y_M, DEEP_Y_M - Rules.LEVEL_SPACING_U / 1024.0]
const OTHER_STRENGTH: float = 0.28

## The level this cap is for (see ONE CAP A LEVEL).
var level: int = Rules.TOP_LEVEL

var _ground_image: Image = null
var _marks: PackedByteArray = PackedByteArray()
var _marks_texture: ImageTexture = null
var _void: PackedByteArray = PackedByteArray()
var _void_side: int = 0
var _void_image: Image = null
var _void_texture: ImageTexture = null
var _void_dirty: bool = false
var _cap: MeshInstance3D = null
var _deep: MeshInstance3D = null
var _light: DirectionalLight3D = null
var _material: ShaderMaterial = null


func configure(ground: GroundScript, water: WaterScript, at_level: int = Rules.TOP_LEVEL, water_from: Image = null) -> void:
	"""Build the cap of `at_level` over this ground and water, its backstop and its light (see the header). A lower
	level's cap reads the water's distance from `water_from` (level 1's ground image) instead of asking it again."""
	level = at_level
	name = "UndergroundCap" if level == Rules.TOP_LEVEL else "UndergroundCap%d" % level
	_ground_image = ground_image(ground, water, level) if water_from == null else deep_image(ground, water_from)
	var side: int = MAP_SIDE_M * MARKS_PX_PER_M
	_marks.resize(side * side * 4)
	_marks_texture = ImageTexture.create_from_image(Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, _marks))
	_void_side = MAP_SIDE_M * VOID_PX_PER_M
	_void.resize(_void_side * _void_side * 4)
	_void_image = Image.create_from_data(_void_side, _void_side, false, Image.FORMAT_RGBA8, _void)
	_void_texture = ImageTexture.create_from_image(_void_image)
	_material = _cap_material()
	_cap = _plane(Layers.cap_y(level), _material)
	_deep = _plane(DEEP_YS_M[level], _deep_material())
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
	material.set_shader_parameter(&"floor_y", Layers.floor_y(level))
	material.set_shader_parameter(&"rise_range", rise_range_m())
	material.set_shader_parameter(&"crown_range", CROWN_RANGE_M)
	material.set_shader_parameter(&"bulge", BoreMeshScript.BULGE)
	material.set_shader_parameter(&"spring_share", BoreMeshScript.SPRING_SHARE)
	material.set_shader_parameter(&"water_line", 0.5 + WATER_CLEARANCE_M / (2.0 * WATER_RANGE_M))
	return material


func rise_range_m() -> float:
	"""The rise (m) the void mask's B channel codes up to on this level (see ONE CAP A LEVEL)."""
	return RISE_RANGES_M[level]


func set_other(other: Node3D) -> void:
	"""The other level's cap, whose voids this cap outlines faintly (see ONE CAP A LEVEL)."""
	_material.set_shader_parameter(&"other_void", other.void_texture())
	_material.set_shader_parameter(&"other_strength", OTHER_STRENGTH)


func void_texture() -> ImageTexture:
	"""This level's void mask (the other level's cap outlines it)."""
	return _void_texture


func commit_other() -> void:
	"""Nothing is drawn on a lower level's marks (footings and roots are level 1's); upload them blank once."""
	_commit_marks()


func share_earth(material: ShaderMaterial) -> void:
	"""Give another earth material (the bores', bore_earth.gdshader) the cap's maps, so a wall and the cut
	it meets are the same soil (underground_earth.gdshaderinc)."""
	for name: StringName in [&"ground_map", &"marks_map", &"grain", &"map_rect"]:
		material.set_shader_parameter(name, _material.get_shader_parameter(name))


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
	node.layers = Layers.below(level)
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
	light.layers = Layers.below(level)
	light.light_cull_mask = Layers.below(level)
	add_child(light)
	return light


# --- the ground map ---------------------------------------------------------------------------

static func ground_image(ground: GroundScript, water: WaterScript, at_level: int = Rules.TOP_LEVEL) -> Image:
	"""The strata of `at_level` and the water's distance, a pixel a metre over the mapped square (see the shader)."""
	var image := Image.create(MAP_SIDE_M * GROUND_PX_PER_M, MAP_SIDE_M * GROUND_PX_PER_M, false, Image.FORMAT_RGBA8)
	for r: int in image.get_height():
		for c: int in image.get_width():
			var at := Vector2i(Rules.to_u(-MAP_HALF_M + float(c) + 0.5), Rules.to_u(-MAP_HALF_M + float(r) + 0.5))
			var margin_m: float = Rules.to_m(water.map().inside_margin_u(at))
			image.set_pixel(c, r, Color(_ground_colour(ground, water, at, at_level), water_code(margin_m)))
	return image


static func deep_image(ground: GroundScript, water_from: Image) -> Image:
	"""A lower level's strata over level 1's ground image's water distances (its alpha): the grid's level-2 cells
	inside it, and outside it loam, wet within the water table's reach (tunnel_ground.gd THE GROUND AT DEPTH)."""
	var image := Image.create(water_from.get_width(), water_from.get_height(), false, Image.FORMAT_RGBA8)
	var table_code: float = water_code(-Rules.to_m(GroundScript.DEEP_WET_REACH_U))
	for r: int in image.get_height():
		for c: int in image.get_width():
			var at := Vector2i(Rules.to_u(-MAP_HALF_M + float(c) + 0.5), Rules.to_u(-MAP_HALF_M + float(r) + 0.5))
			var code: float = water_from.get_pixel(c, r).a
			var byte: int = ground.cell_byte(at.x, at.y, Rules.LEVEL_2) if _in_grid(ground, at) \
					else GroundScript.LOAM | (GroundScript.WET_BIT if code > table_code else 0)
			image.set_pixel(c, r, Color(GroundViewScript.colour_of(byte), code))
	return image


static func _in_grid(ground: GroundScript, at: Vector2i) -> bool:
	"""Whether `at` (u) lies inside the ground's grid."""
	return at.x >= ground.origin_u.x and at.y >= ground.origin_u.y \
			and at.x < ground.origin_u.x + ground.columns * GroundScript.CELL_U \
			and at.y < ground.origin_u.y + ground.rows * GroundScript.CELL_U


func ground_map() -> Image:
	"""This level's ground image (a lower level's cap reads its water distances from level 1's)."""
	return _ground_image


static func _ground_colour(ground: GroundScript, water: WaterScript, at: Vector2i, at_level: int) -> Color:
	"""The ground's colour at `at` (u) on `at_level`: the grid's cell inside it, loam (wet by the water) outside."""
	if _in_grid(ground, at):
		return GroundViewScript.colour_of(ground.cell_byte(at.x, at.y, at_level))
	var wet: bool = water.near_water(at.x, at.y) if at_level == Rules.TOP_LEVEL \
			else water.map().inside_margin_u(at) > -GroundScript.DEEP_WET_REACH_U
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


static func void_centre(x: int, y: int) -> Vector2:
	"""The centre of void pixel (x, y), (x, z) metres."""
	return Vector2((float(x) + 0.5) / VOID_PX_PER_M - MAP_HALF_M, (float(y) + 0.5) / VOID_PX_PER_M - MAP_HALF_M)


func stamp_disc(centre: Vector2, radius: float, cut: Vector2 = Vector2.ZERO, rise_m: float = 0.0,
		crown_m: float = 1.0, cut_ahead_m: float = 0.0) -> void:
	"""Mark a bore's cross-section dug (one step along it; see VOIDS): a disc of floor half-width `radius`
	whose floor lies `rise_m` over the level's and whose crown is `crown_m`. Each pixel out to RHO_REACH
	keeps the nearest disc's distance (and that disc's rise and crown), never a farther one. A non-zero
	unit `cut` keeps only what lies behind the line across it `cut_ahead_m` ahead of the centre (a dig face:
	at the centre for the face's own disc, further on for a disc behind it). Uploaded by `commit_void`."""
	var reach: int = ceili(radius * RHO_REACH * VOID_PX_PER_M) + 1
	var middle: Vector2i = void_pixel(centre)
	var rise: int = roundi(clampf(rise_m / rise_range_m(), 0.0, 1.0) * 255.0)
	var crown: int = roundi(clampf(crown_m / CROWN_RANGE_M, 0.0, 1.0) * 255.0)
	for y: int in range(maxi(middle.y - reach, 0), mini(middle.y + reach + 1, _void_side)):
		for x: int in range(maxi(middle.x - reach, 0), mini(middle.x + reach + 1, _void_side)):
			var offset: Vector2 = void_centre(x, y) - centre
			if cut != Vector2.ZERO and offset.dot(cut) > cut_ahead_m:
				continue
			var rho: float = offset.length() / radius
			if rho <= RHO_REACH:
				_raise_rho((y * _void_side + x) * 4, roundi((1.0 - rho / RHO_RANGE) * 255.0), rise, crown)


func _raise_rho(i: int, code: int, rise: int, crown: int) -> void:
	"""Keep a nearer disc's distance code at byte `i`, with its rise and crown."""
	if code <= _void[i + VOID_RHO]:
		return
	_void[i + VOID_RHO] = code
	_void[i + VOID_RISE] = rise
	_void[i + VOID_CROWN] = crown
	_void_dirty = true


func stamp_rect(centre: Vector2, half_m: float) -> void:
	"""Mark a square room's floor dug. Uploaded by `commit_void`."""
	stamp_box(centre, Vector2(half_m, half_m))


func stamp_box(centre: Vector2, half_m: Vector2) -> void:
	"""Mark a room's floor dug over a box on the world's axes, `half_m` (x, z) either side of `centre` (a vault's
	floor, decision 0209). Uploaded by `commit_void`."""
	var lo: Vector2i = void_pixel(centre - half_m)
	var hi: Vector2i = void_pixel(centre + half_m)
	for y: int in range(maxi(lo.y, 0), mini(hi.y, _void_side)):
		for x: int in range(maxi(lo.x, 0), mini(hi.x, _void_side)):
			_void[(y * _void_side + x) * 4 + VOID_ROOM] = 255
			_void_dirty = true


func commit_void() -> bool:
	"""Upload the void mask if anything was stamped since the last upload. True when it was."""
	if not _void_dirty:
		return false
	_void_dirty = false
	_void_image.set_data(_void_side, _void_side, false, Image.FORMAT_RGBA8, _void)
	_void_texture.update(_void_image)
	return true


func void_at(at: Vector2, channel: int) -> float:
	"""One channel (VOID_*) of the void mask's pixel holding `at` (x, z metres), 0..1; 0 off the map."""
	var p: Vector2i = void_pixel(at)
	if p.x < 0 or p.y < 0 or p.x >= _void_side or p.y >= _void_side:
		return 0.0
	return float(_void[(p.y * _void_side + p.x) * 4 + channel]) / 255.0


func is_dug(at: Vector2) -> bool:
	"""Whether the floor at `at` (x, z metres) is dug at the level's floor: a room's, or inside a bore's
	floor whose floor there is within FLOOR_SLACK_M of the level's (a ramp's higher end is not; checks)."""
	if void_at(at, VOID_ROOM) > 0.5:
		return true
	return void_at(at, VOID_RHO) > 1.0 - 1.0 / RHO_RANGE and void_at(at, VOID_RISE) * rise_range_m() <= FLOOR_SLACK_M


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
