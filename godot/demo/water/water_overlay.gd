extends Node3D
## The water inspection overlay (V): the WADE / SWIM / DIVE zones of the 1.0 m mouse painted on the
## water, every crossing candidate and bank landing, and each fishing site's live habitat stock.
## Decision 0196 (live demo), water foundation. READ-ONLY: it draws what the map and the fishing
## driver say and changes nothing. Debug colours, not art (the zone bands must be told apart at a
## glance).
##
## Built once on `configure()`. The zone paint, spans and posts never change; the site labels are
## re-texted only when the driver's `revision` moves (a day, a catch), never per frame.
##
## LABELS THAT NEVER OVERLAP (playtest 2026-09-29, decision 0205). The three fishing sites' landings lie
## along one bank (x 20.4-21.5 m), so from the south their labels stacked on each other and the legend.
## Each site label is now two short lines (the site, its quota and slots; each species' stock and state)
## -- day and season are on the HUD -- and while the overlay shows, every frame, the labels are laid out
## on screen: the lowest on screen stays over its landing and each one above rises just clear of those
## already placed (`stack_lifts_into`; four labels, nothing allocated). A site whose landing the map
## does not have is not labelled at all (it used to fall to the world origin, over the well).
##
## PER RESIDENT (demo/waterplay/). The bands are a body's zones, so `set_body` repaints them for the
## first selected resident's own height (a badger wades where a mouse must swim) -- two shader
## parameters and the legend, only when the selection changes. `show_links` adds the swimmers' links
## across the water (validated bank connections) as thin blue bars.

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
const LINK_COLOUR: Color = Color(0.35, 0.6, 1.0)
const LIFT_M: float = 0.04
const LABEL_HEIGHT_M: float = 3.2
const LABEL_FONT_SIZE: int = 26
const LABEL_PIXEL_SIZE: float = 0.00045
const LABEL_OUTLINE: int = 8
## Screen pixels kept between two laid-out labels.
const LABEL_GAP_PX: float = 6.0
const RENDER_PRIORITY: int = 2
## The labels draw after the zone paint (RENDER_PRIORITY), outline first: at the paint's own priority
## or below it the translucent paint washed the text out wherever a label crossed the water.
const LABEL_RENDER_PRIORITY: int = RENDER_PRIORITY + 2

var _driver: FishingDriverScript = null
var _labels: Array[Label3D] = []
## Every label the layout moves, one row each in the order they were made (the legend at `configure`,
## the sites at `set_driver`), with its anchor (world) and, per frame, its size in label pixels, the
## centre of its text on screen before any lift (a left-aligned Label3D starts its text AT its anchor,
## centred on it only vertically; plus any sideways nudge), whether it shows, the nudge that keeps it
## inside the viewport, and how far it is lifted (px).
var _laid: Array[Label3D] = []
var _anchor: PackedVector3Array = PackedVector3Array()
var _anchored: PackedByteArray = PackedByteArray()
var _size_label_px: PackedVector2Array = PackedVector2Array()
var _screen: PackedVector2Array = PackedVector2Array()
var _screen_size: PackedVector2Array = PackedVector2Array()
var _shown: PackedByteArray = PackedByteArray()
var _lift: PackedFloat32Array = PackedFloat32Array()
var _nudge: PackedFloat32Array = PackedFloat32Array()
var _order: PackedInt32Array = PackedInt32Array()
var _shown_revision: int = -1
var _preview: FishingDriverScript.Preview = FishingDriverScript.Preview.new()
var _zone_material: ShaderMaterial = null
var _legend: Label3D = null
## Whose zones are painted (for the legend), and the body height they are for, in u.
var body_label: String = "a 1.0 m mouse"
var body_height_u: int = Rules.MOUSE_HEIGHT_U


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
	"""While the overlay shows: re-text the site labels when the fishery changed, and lay every label
	out on screen for this frame's camera (LABELS THAT NEVER OVERLAP)."""
	if not visible:
		return
	refresh_text()
	lay_out(get_viewport().get_camera_3d(), get_viewport().get_visible_rect().size)


func refresh_text() -> void:
	"""Re-text the site labels (and re-measure them) when the fishery's revision moved since."""
	if _driver == null or _driver.revision == _shown_revision:
		return
	_shown_revision = _driver.revision
	for site: int in _labels.size():
		_labels[site].text = site_text(_driver, site, _preview)
		_size_label_px[site_row(site)] = label_size_px(_labels[site])


static func site_text(driver: FishingDriverScript, site: int,
		preview: FishingDriverScript.Preview) -> String:
	"""One site's label, two short lines: the site, its habitat quota left and free slots; then each
	species' stock and state (hand net)."""
	var species_words: PackedStringArray = PackedStringArray()
	for species: int in Fishing.SPECIES_PER_HABITAT:
		driver.preview_into(site, species, Fishing.GEAR_HAND_NET, 0, preview)
		species_words.append("%s %.0f %s" % [preview.species_key, preview.stock_milli / 1000.0,
			_state(preview)])
	return "%s  quota %.1f / %.1f U  slots %d / %d\n%s" % [FishingDriverScript.SITE_KEYS[site],
		preview.remaining_quota_milli / 1000.0, preview.quota_milli / 1000.0, preview.slots_free,
		preview.slots_total, "   ".join(species_words)]


static func _state(preview: FishingDriverScript.Preview) -> String:
	"""A species' state in a word or three: open, depleted, shut until it reopens, or why it is shut."""
	if preview.ok:
		return "depleted" if preview.depleted else "open"
	if preview.closed or preview.availability_per_1000 == 0:
		return "shut to s%d d%d" % [preview.reopen_season, preview.reopen_day]
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
	_zone_material = _make_zone_material()
	node.material_override = _zone_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _make_zone_material() -> ShaderMaterial:
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
	label.outline_size = LABEL_OUTLINE
	label.modulate = Color(1.0, 0.97, 0.88)
	label.outline_modulate = Color(0.08, 0.1, 0.08)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.render_priority = LABEL_RENDER_PRIORITY
	label.outline_render_priority = LABEL_RENDER_PRIORITY - 1
	add_child(label)
	return label


func _add_site_labels(map: WaterMapScript) -> void:
	"""One label per fishing site, above its bank landing. A site whose landing the map does not have
	gets a label that never shows (the layout skips it), and a warning -- never one at the origin."""
	var found := IntMath.IntResult.new()
	for site: int in FishingDriverScript.SITE_COUNT:
		var label := _label(Vector3.ZERO, "")
		if map.landing_index_into(FishingDriverScript.SITE_LANDING[site], found):
			var land: Vector2i = map.landing_land(found.value)
			_lay(label, Vector3(Rules.to_m(land.x), LABEL_HEIGHT_M, Rules.to_m(land.y)), true)
		else:
			push_warning("water overlay: site %s's landing %s: %s; not labelled" % [
				FishingDriverScript.SITE_KEYS[site], FishingDriverScript.SITE_LANDING[site], found.error])
			label.visible = false
			_lay(label, Vector3.ZERO, false)
		_labels.append(label)


func _add_legend(map: WaterMapScript) -> void:
	"""The zone key, floated over the stream's narrowest span (the first bridge candidate)."""
	var at := Vector3(24.0, LABEL_HEIGHT_M, -24.0)
	for c: int in map.crossing_count():
		if map.crossing_kind(c) == WaterMapScript.CROSSING_BRIDGE:
			var mid: Vector2i = (map.crossing_a(c) + map.crossing_b(c)) / 2
			at = Vector3(Rules.to_m(mid.x), LABEL_HEIGHT_M, Rules.to_m(mid.y))
			break
	_legend = _label(at, legend_text(body_label, body_height_u))
	_lay(_legend, at, true)


func _lay(label: Label3D, at: Vector3, anchored: bool) -> void:
	"""Hand `label` (anchored at `at`, or never shown) to the layout, one row each in every column."""
	label.position = at
	_laid.append(label)
	_anchor.append(at)
	_anchored.append(1 if anchored else 0)
	_size_label_px.append(label_size_px(label))
	_screen.append(Vector2.ZERO)
	_screen_size.append(Vector2.ZERO)
	_shown.append(0)
	_lift.append(0.0)
	_nudge.append(0.0)
	_order.append(0)


func label_shown(k: int) -> bool:
	"""Whether layout row `k` is placed at an anchor (a site whose landing is missing is not)."""
	return _anchored[k] == 1


func laid_count() -> int:
	"""How many labels the layout moves (the legend and the sites')."""
	return _laid.size()


func site_row(site: int) -> int:
	"""The layout row of fishing site `site`'s label."""
	return _laid.find(_labels[site])


func lift_px(k: int) -> float:
	"""How far the last layout lifted label `k` up the screen, pixels."""
	return _lift[k]


func screen_rect(k: int) -> Rect2:
	"""Label `k`'s rectangle on screen after the last layout: its text as drawn, lifted."""
	return Rect2(_screen[k] - Vector2(0.0, _lift[k]) - _screen_size[k] * 0.5, _screen_size[k])


static func label_size_px(label: Label3D) -> Vector2:
	"""A label's text block in its own pixels (font size, outline included), before pixel_size."""
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var size: Vector2 = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		label.font_size)
	return size + Vector2(2.0, 2.0) * float(label.outline_size)


static func screen_px_per_label_px(viewport_height: float, fov_degrees: float) -> float:
	"""How many screen pixels one label pixel covers: a fixed-size label keeps LABEL_PIXEL_SIZE per pixel
	at one metre of depth, and the camera's vertical field of view spreads tan(fov / 2) of depth over half
	the viewport's height."""
	return LABEL_PIXEL_SIZE * viewport_height * 0.5 / tan(deg_to_rad(fov_degrees) * 0.5)


func lay_out(camera: Camera3D, viewport_size: Vector2) -> void:
	"""Place every label for this frame's `camera` over a viewport `viewport_size` across."""
	if camera == null or not camera.is_inside_tree():
		return
	lay_out_view(camera.global_transform, camera.get_camera_projection(), viewport_size, camera.fov)


func lay_out_view(eye: Transform3D, lens: Projection, viewport_size: Vector2, fov_degrees: float) -> void:
	"""Place every label for a camera at `eye` with projection `lens` (LABELS THAT NEVER OVERLAP): its
	anchor on screen (`project_px`, Camera3D.unproject_position's own arithmetic), its drawn size, a
	sideways nudge that keeps a label whose landing is on screen inside the viewport, and the lift that
	keeps it clear of the others -- nudge and lift applied as its offset. Allocates nothing."""
	var scale: float = screen_px_per_label_px(viewport_size.y, fov_degrees)
	var to_view: Transform3D = eye.affine_inverse()
	for k: int in _laid.size():
		var local: Vector3 = to_view * _anchor[k]
		var on: bool = _anchored[k] == 1 and _laid[k].text != "" and local.z < 0.0
		_shown[k] = 1 if on else 0
		_screen_size[k] = _size_label_px[k] * scale
		var at: Vector2 = project_px(lens, local, viewport_size) if on else Vector2.ZERO
		_nudge[k] = inside_nudge_px(at.x, _screen_size[k].x, viewport_size.x) if on else 0.0
		_screen[k] = at + Vector2(_nudge[k] + _screen_size[k].x * 0.5, 0.0)
	stack_lifts_into(_screen, _screen_size, _shown, LABEL_GAP_PX, _order, _lift)
	for k: int in _laid.size():
		var offset := Vector2(_nudge[k], _lift[k]) / scale
		if _laid[k].offset != offset:
			_laid[k].offset = offset  # re-meshes the label: only when it moved


static func inside_nudge_px(left: float, width: float, viewport_width: float) -> float:
	"""How far (px, negative is left) a label starting at `left` and `width` across slides to stay
	LABEL_GAP_PX inside the viewport -- only when its anchor is on screen (one whose landing is off
	screen stays off it, rather than piling up at the edge); a label wider than the view keeps its left."""
	if left < 0.0 or left > viewport_width:
		return 0.0
	var nudge: float = minf(0.0, viewport_width - LABEL_GAP_PX - (left + width))
	return maxf(nudge, LABEL_GAP_PX - left)


static func project_px(lens: Projection, local: Vector3, viewport_size: Vector2) -> Vector2:
	"""Where a point in the camera's own space (in front of it: z < 0) lands on screen, pixels from the
	top left -- clip space through `lens`, divided by w, then the viewport's y-down pixels."""
	var clip: Vector4 = lens * Vector4(local.x, local.y, local.z, 1.0)
	var ndc := Vector2(clip.x, clip.y) / clip.w
	return Vector2((ndc.x * 0.5 + 0.5) * viewport_size.x, (0.5 - ndc.y * 0.5) * viewport_size.y)


static func stack_lifts_into(centres: PackedVector2Array, sizes: PackedVector2Array, shown: PackedByteArray,
		gap: float, order: PackedInt32Array, lifts: PackedFloat32Array) -> void:
	"""Into `lifts`: how far (px, up the screen) each shown rectangle -- centred on `centres`, `sizes`
	across -- must rise so that no two shown ones come within `gap`. The lowest on screen stays put;
	going up, each rises just clear of every one already placed. `order` is scratch as long as the rest.
	Each rise clears one placed rectangle for good (lifts only grow), so it settles in n^2 steps."""
	var count: int = _order_lowest_first(centres, shown, order)
	for k: int in lifts.size():
		lifts[k] = 0.0
	for i: int in count:
		var me: int = order[i]
		for attempt: int in i + 1:
			var clash: int = _first_clash(centres, sizes, lifts, gap, order, i)
			if clash < 0:
				break
			lifts[me] = centres[me].y + sizes[me].y * 0.5 - (centres[clash].y - lifts[clash] - sizes[clash].y * 0.5) + gap


static func _order_lowest_first(centres: PackedVector2Array, shown: PackedByteArray, order: PackedInt32Array) -> int:
	"""Fill `order` with the shown indices, lowest on screen (largest y) first, ties by index; returns
	how many (an insertion sort: a handful of labels)."""
	var count: int = 0
	for k: int in centres.size():
		if shown[k] == 0:
			continue
		var at: int = count
		while at > 0 and centres[order[at - 1]].y < centres[k].y:
			order[at] = order[at - 1]
			at -= 1
		order[at] = k
		count += 1
	return count


static func _first_clash(centres: PackedVector2Array, sizes: PackedVector2Array, lifts: PackedFloat32Array,
		gap: float, order: PackedInt32Array, i: int) -> int:
	"""The first of order[0 .. i - 1] whose lifted rectangle comes within `gap` of order[i]'s, or -1."""
	var me: int = order[i]
	for j: int in i:
		var other: int = order[j]
		var dx: float = absf(centres[me].x - centres[other].x)
		var dy: float = absf((centres[me].y - lifts[me]) - (centres[other].y - lifts[other]))
		if dx < (sizes[me].x + sizes[other].x) * 0.5 + gap and dy < (sizes[me].y + sizes[other].y) * 0.5 + gap:
			return other
	return -1


static func legend_text(who: String, height_u: int) -> String:
	"""The zone key for a body `height_u` tall."""
	return "WATER (V)  zones for %s:\nyellow WADE <= %.2f m   blue SWIM <= %.2f m   violet DIVE deeper\ngreen span = ford   orange span = bridge candidate   blue bars = swim links   white = bank landing" % [
		who, Rules.to_m(Rules.wade_max_u(height_u)), Rules.to_m(Rules.dive_min_u(height_u))]


func set_body(label: String, height_u: int) -> void:
	"""Paint the zones for a body `height_u` tall (> 0), named `label` in the legend."""
	if height_u <= 0 or (label == body_label and height_u == body_height_u):
		return
	body_label = label
	body_height_u = height_u
	_zone_material.set_shader_parameter(&"wade_max_m", Rules.to_m(Rules.wade_max_u(height_u)))
	_zone_material.set_shader_parameter(&"dive_min_m", Rules.to_m(Rules.dive_min_u(height_u)))
	if _legend != null:
		_legend.text = legend_text(label, height_u)
		_size_label_px[_laid.find(_legend)] = label_size_px(_legend)


func show_links(water_a: PackedVector2Array, water_b: PackedVector2Array) -> void:
	"""Draw every swim link's water part a -> b, metres (demo/waterplay/water_links.gd), once."""
	for k: int in mini(water_a.size(), water_b.size()):
		add_child(_bar(Vector2i(Rules.to_u(water_a[k].x), Rules.to_u(water_a[k].y)),
			Vector2i(Rules.to_u(water_b[k].x), Rules.to_u(water_b[k].y)), 0.05, LINK_COLOUR))
