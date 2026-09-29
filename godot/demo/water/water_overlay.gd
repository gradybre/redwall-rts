extends Node3D
## The water inspection overlay (V): the WADE / SWIM / DIVE zones of the 1.0 m mouse painted on the
## water, every crossing candidate and bank landing, and each fishing site's live habitat stock.
## Decision 0196 (live demo), water foundation. READ-ONLY: it draws what the map and the fishing
## driver say and changes nothing. Debug colours, not art (the zone bands must be told apart at a
## glance).
##
## Built once on `configure()`. The zone paint, spans and posts never change; the site labels are
## re-texted only when the driver's `revision` moves (a day, a catch), never per frame.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterGridScript := preload("res://demo/water/water_grid.gd")
const FishingDriverScript := preload("res://demo/water/fishing_driver.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const ZONE_SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 wade_colour;
uniform vec4 swim_colour;
uniform vec4 dive_colour;
uniform float wade_max_m;
uniform float dive_min_m;
varying float v_depth;
void vertex() { v_depth = COLOR.r * 4.0; }
void fragment() {
	vec4 c = v_depth <= wade_max_m ? wade_colour : (v_depth <= dive_min_m ? swim_colour : dive_colour);
	ALBEDO = c.rgb;
	ALPHA = v_depth > 0.0005 ? c.a : 0.0;
}
"""
const WADE_COLOUR: Color = Color(1.0, 0.86, 0.3, 0.55)
const SWIM_COLOUR: Color = Color(0.3, 0.8, 1.0, 0.5)
const DIVE_COLOUR: Color = Color(0.45, 0.25, 0.9, 0.55)
const FORD_COLOUR: Color = Color(0.4, 0.95, 0.4)
const BRIDGE_COLOUR: Color = Color(1.0, 0.55, 0.2)
const LANDING_COLOUR: Color = Color(1.0, 1.0, 1.0)
const LIFT_M: float = 0.04
const LABEL_HEIGHT_M: float = 3.2
const LABEL_FONT_SIZE: int = 26
const LABEL_PIXEL_SIZE: float = 0.00045
const RENDER_PRIORITY: int = 2

var _driver: FishingDriverScript = null
var _labels: Array[Label3D] = []
var _shown_revision: int = -1
var _preview: FishingDriverScript.Preview = FishingDriverScript.Preview.new()


func configure(map: WaterMapScript, grid: WaterGridScript) -> void:
	"""Build the overlay's zones, spans, landings and legend for this map; hidden until toggled."""
	name = "WaterOverlay"
	visible = false
	add_child(_zone_paint(map, grid))
	for c: int in map.crossing_count():
		var colour: Color = FORD_COLOUR if map.crossing_kind(c) == WaterMapScript.CROSSING_FORD \
			else BRIDGE_COLOUR
		add_child(_bar(map.crossing_a(c), map.crossing_b(c), 0.12, colour))
	for k: int in map.landing_count():
		add_child(_bar(map.landing_water(k), map.landing_land(k), 0.08, LANDING_COLOUR))
		add_child(_post(map.landing_water(k), LANDING_COLOUR))
	_add_legend(map)


func set_driver(driver: FishingDriverScript, map: WaterMapScript) -> void:
	"""Show this fishing driver's sites, one label above each site's bank landing. Once."""
	if _driver != null or driver == null:
		return
	_driver = driver
	_add_site_labels(map)
	_shown_revision = -1


func toggle() -> bool:
	"""Show or hide the overlay; returns whether it is now shown."""
	visible = not visible
	_shown_revision = -1
	return visible


func _process(_delta: float) -> void:
	"""Re-text the site labels when the fishery changed and the overlay is showing."""
	if not visible or _driver == null or _driver.revision == _shown_revision:
		return
	_shown_revision = _driver.revision
	for site: int in _labels.size():
		_labels[site].text = site_text(_driver, site, _preview)


static func site_text(driver: FishingDriverScript, site: int,
		preview: FishingDriverScript.Preview) -> String:
	"""One site's inspection text: habitat, day, and each species' stock, state and hand-net catch."""
	var lines: PackedStringArray = PackedStringArray()
	var habitat: String = "river" if FishingDriverScript.SITE_HABITAT[site] == Fishing.HABITAT_RIVER \
		else "lake"
	lines.append("%s  (%s habitat)  -  season %d day %d" % [FishingDriverScript.SITE_KEYS[site],
		habitat, driver.season(), driver.season_day()])
	for species: int in Fishing.SPECIES_PER_HABITAT:
		driver.preview_into(site, species, Fishing.GEAR_HAND_NET, 0, preview)
		lines.append("%s %.1f / %.0f U  %s  net %.1f U" % [preview.species_key,
			preview.stock_milli / 1000.0, preview.capacity_milli / 1000.0, _state(preview),
			preview.expected_catch_milli / 1000.0])
	lines.append("quota left %.1f / %.1f U   slots %d / %d free" % [
		preview.remaining_quota_milli / 1000.0, preview.quota_milli / 1000.0, preview.slots_free,
		preview.slots_total])
	return "\n".join(lines)


static func _state(preview: FishingDriverScript.Preview) -> String:
	"""A species' state in one word or two: open, why it is shut, and when it reopens."""
	if preview.ok:
		return "depleted" if preview.depleted else "open"
	if preview.closed or preview.availability_per_1000 == 0:
		return "%s (reopens s%d d%d)" % [String(preview.block).to_lower(), preview.reopen_season,
			preview.reopen_day]
	return String(preview.block).to_lower()


func _zone_paint(map: WaterMapScript, grid: WaterGridScript) -> MeshInstance3D:
	"""The water cells, a little above each surface, coloured per fragment by the mouse's zones."""
	var count: int = grid.xs.size() * grid.zs.size()
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	vertices.resize(count)
	colours.resize(count)
	for k: int in count:
		var at: Vector2 = grid.position_m(k % grid.xs.size(), k / grid.xs.size())
		var drop: float = Rules.to_m(map.body_level_drop_u(grid.body[k]))
		vertices[k] = Vector3(at.x, LIFT_M - drop, at.y)
		colours[k] = Color(Rules.to_m(grid.depth_u[k]) / 4.0, 0.0, 0.0, 1.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = _wet_cells(grid)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "ZonePaint"
	node.mesh = mesh
	node.material_override = _zone_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _zone_material() -> ShaderMaterial:
	"""The zone bands at the demo thresholds for the 1.0 m mouse (water_rules.gd)."""
	var shader := Shader.new()
	shader.code = ZONE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = RENDER_PRIORITY
	material.set_shader_parameter(&"wade_colour", WADE_COLOUR)
	material.set_shader_parameter(&"swim_colour", SWIM_COLOUR)
	material.set_shader_parameter(&"dive_colour", DIVE_COLOUR)
	material.set_shader_parameter(&"wade_max_m", Rules.to_m(Rules.wade_max_u(Rules.MOUSE_HEIGHT_U)))
	material.set_shader_parameter(&"dive_min_m", Rules.to_m(Rules.dive_min_u(Rules.MOUSE_HEIGHT_U)))
	return material


static func _wet_cells(grid: WaterGridScript) -> PackedInt32Array:
	"""The triangles of every grid cell with a wet corner."""
	var out := PackedInt32Array()
	var nx: int = grid.xs.size()
	for j: int in grid.zs.size() - 1:
		for i: int in nx - 1:
			var a: int = grid.index(i, j)
			if grid.depth_u[a] <= 0 and grid.depth_u[a + 1] <= 0 and grid.depth_u[a + nx] <= 0 \
					and grid.depth_u[a + nx + 1] <= 0:
				continue
			for k: int in [a + nx + 1, a + nx, a + 1, a + nx, a, a + 1]:
				out.append(k)
	return out


func _bar(a_u: Vector2i, b_u: Vector2i, thickness_m: float, colour: Color) -> MeshInstance3D:
	"""A flat unshaded bar from a to b, just above the ground."""
	var a := Vector3(Rules.to_m(a_u.x), 0.25, Rules.to_m(a_u.y))
	var b := Vector3(Rules.to_m(b_u.x), 0.25, Rules.to_m(b_u.y))
	var box := BoxMesh.new()
	box.size = Vector3(thickness_m, 0.05, maxf(a.distance_to(b), 0.05))
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = _flat(colour)
	node.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	return node


func _post(at_u: Vector2i, colour: Color) -> MeshInstance3D:
	"""A thin post marking a landing's waterline point."""
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.06
	cylinder.height = 1.2
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.material_override = _flat(colour)
	node.position = Vector3(Rules.to_m(at_u.x), 0.4, Rules.to_m(at_u.y))
	return node


static func _flat(colour: Color) -> StandardMaterial3D:
	"""An unshaded, always-visible marker material."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.no_depth_test = true
	return material


func _label(at: Vector3, text: String) -> Label3D:
	"""A billboarded label that stays readable at any zoom."""
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL_SIZE
	label.font_size = LABEL_FONT_SIZE
	label.outline_size = 8
	label.modulate = Color(1.0, 0.97, 0.88)
	label.outline_modulate = Color(0.08, 0.1, 0.08)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)
	return label


func _add_site_labels(map: WaterMapScript) -> void:
	"""One label per fishing site, above its bank landing."""
	var found := IntMath.IntResult.new()
	for site: int in FishingDriverScript.SITE_COUNT:
		var at := Vector3.ZERO
		if map.landing_index_into(FishingDriverScript.SITE_LANDING[site], found):
			var land: Vector2i = map.landing_land(found.value)
			at = Vector3(Rules.to_m(land.x), LABEL_HEIGHT_M, Rules.to_m(land.y))
		_labels.append(_label(at, ""))


func _add_legend(map: WaterMapScript) -> void:
	"""The zone key, floated over the stream's narrowest span (the first bridge candidate)."""
	var at := Vector3(24.0, LABEL_HEIGHT_M, -24.0)
	for c: int in map.crossing_count():
		if map.crossing_kind(c) == WaterMapScript.CROSSING_BRIDGE:
			var mid: Vector2i = (map.crossing_a(c) + map.crossing_b(c)) / 2
			at = Vector3(Rules.to_m(mid.x), LABEL_HEIGHT_M, Rules.to_m(mid.y))
			break
	_label(at, "WATER (V)  zones for a 1.0 m mouse:\nyellow WADE <= %.2f m   blue SWIM <= %.2f m   violet DIVE deeper\ngreen span = ford   orange span = bridge candidate   white = bank landing" % [
		Rules.to_m(Rules.wade_max_u(Rules.MOUSE_HEIGHT_U)), Rules.to_m(Rules.dive_min_u(Rules.MOUSE_HEIGHT_U))])
