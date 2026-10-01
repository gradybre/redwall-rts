extends Node3D
## The demo's underground view (U): a top-down section cutaway by render layer. Decision 0206 (the
## underground revamp's P0; design docs/design/underground_revamp.md §5), replacing decision 0196's
## fading view. Presentation only: it changes what is drawn, never where anyone is (MOVE-REQ-015).
##
## A SWITCH IS TWO WRITES: the camera's `cull_mask` (demo_layers.gd view_mask) and its `environment`.
## Everything either view draws already exists on its own layer -- the village, its labels and crops on
## the surface layers; the cap (underground_cap.gd), the bores, rooms, frames, lanterns, finds and
## residents below on the underground ones, built as they are dug -- so switching allocates nothing,
## builds nothing, fades nothing and changes no material: no pipeline is compiled by a toggle. What the U
## view draws the first time is drawn once at boot instead (`begin_prewarm`, behind the opening pause),
## in its own environment.
##
## THE UNDERGROUND'S ENVIRONMENT (decision 0207; design §5 "Lighting"): its own Environment, set on the
## camera only while the U view is on (null gives the surface's WorldEnvironment back, untouched, so the
## weather's haze and the sky never reach below and nothing below reaches the surface): dark earth behind,
## a low cool-brown ambient, SSAO in the bores' corners, glow so the lantern glows bloom, and a faint warm
## depth haze -- warm lantern pools in dark earth.
##
## PICKING. `ground_at` meets the view's own plane: the ground in the surface view, the level's floor in
## the U view (demo_layers.gd pick_y) -- where the cap shows the floor under the pointer.
##
## THE LEVELS (decision 0212, the revamp's P6). The U view shows one level at a time: PgUp goes up to level 1,
## PgDn down to level 2 (tunnel_control.gd reads the keys in the U view only; on the surface they stay the
## camera's zoom, and U stays the view's switch). A level switch is again ONE cull-mask write
## (demo_layers.gd `level_mask`) and nothing else: each level has its own cap (`caps`, one plane at its own
## section with its own void mask and strata, and a faint OUTLINE of the other level read from that level's
## mask -- no bleed-through), its own layers for everything dug on it, and residents on the other level show
## as markers. Clicks land on the shown level's floor (`pick_y`), and the view's focus is on it. A clear
## LEVEL INDICATOR stands in the top-centre column, under the HUD's alert zone, pause label and error panel (UI-SET-085)
## at their registered sizes, at the HUD's scale (scripts/ui/ui_layout.gd and ui_registry.gd, read), while the U view
## is on -- on a canvas layer under the HUD's, so a grown error panel or the open history covers it, never the other
## way. Level 2's cap, strata and materials are built and registered at boot; the boot prewarm draws every level's
## layers.

const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WaterScript := preload("res://demo/village_water.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

## The prewarm's samples stand this far below the camera's focus (under the cap, over the backstop):
## drawn, and hidden by the depth test.
const SAMPLE_DEPTH_M: float = 2.0
## The world's sun, found by name (world_look.gd make_sun).
const SUN_NODE: String = "Sun"
## THE UNDERGROUND'S ENVIRONMENT (see the header).
const BACKGROUND: Color = Color(0.035, 0.028, 0.022)
const AMBIENT: Color = Color(0.42, 0.38, 0.36)
const AMBIENT_ENERGY: float = 0.55
const HAZE: Color = Color(0.16, 0.11, 0.07)
const HAZE_DENSITY: float = 0.006
const GLOW_INTENSITY: float = 0.7
const GLOW_BLOOM: float = 0.04
const GLOW_THRESHOLD: float = 1.0
## The prewarm's cover: a canvas layer over the 3D view (and under the stall banner's), in deep shade.
const COVER_LAYER: int = 1
const COVER_COLOUR: Color = Color(0.12, 0.1, 0.08)
## THE LEVEL INDICATOR (see THE LEVELS): its words (`level_words`); its canvas layer, under the HUD's (hud.tscn's
## CanvasLayer, layer 1) and the prewarm's cover; the HUD elements it stands below in the top-centre column (ui_shell.gd
## stacks them ROW_GAP apart under the alerts: the pause label, then the error panel); and its look.
const LEVEL_FORMAT: String = "Underground · Level %d of %d (floor %s m down) · %s"
const LEVEL_KEYS: Array[String] = ["", "PgDn: level 2", "PgUp: level 1"]
const INDICATOR_LAYER: int = 0
const ABOVE_INDICATOR: Array[int] = [UiShell.ID_PAUSE_LABEL, UiShell.ID_ERROR_PANEL]
const INDICATOR_FONT_PX: int = 17
const INDICATOR_TEXT: Color = Color(0.96, 0.91, 0.78)
const INDICATOR_BACK: Color = Color(0.1, 0.075, 0.055, 0.82)

var on: bool = false
## The level the U view shows (see THE LEVELS).
var level: int = Rules.TOP_LEVEL
## Every material and mesh the U view draws (underground_prewarm.gd): owners register as they build.
var prewarm: PrewarmScript = PrewarmScript.new()
## Level 1's cap, and each level's (`caps[level]`; index 0 unused).
var cap: CapScript = null
var caps: Array[CapScript] = [null, null, null]
## The U view's own environment (see THE UNDERGROUND'S ENVIRONMENT).
var environment: Environment = underground_environment()

var _camera: Camera3D = null
var _samples: Node3D = null
## A plain cover over the screen while the prewarm draws (its frames are not for the player's eyes).
var _cover: CanvasLayer = null
var _indicator: CanvasLayer = null
var _indicator_box: PanelContainer = null
var _indicator_label: Label = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
## `indicator_gap_px`, read once from the registry.
var _indicator_gap: float = indicator_gap_px()


func _ready() -> void:
	"""Follow the viewport's size with the level indicator."""
	get_viewport().size_changed.connect(_place_indicator)
	_place_indicator()


func _notification(what: int) -> void:
	"""Out of the tree or freed: the level shown is level 1 again for everything reading it (demo_layers.gd
	`active_level`)."""
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
		Layers.active_level = Rules.TOP_LEVEL


func configure(camera: Camera3D, ground: GroundScript, water: WaterScript) -> void:
	"""The view through `camera` (surface first), its cap over this ground and water."""
	name = "TunnelView"
	_camera = camera
	for at_level in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		caps[at_level] = CapScript.new()
		add_child(caps[at_level])
		caps[at_level].configure(ground, water, at_level, null if at_level == Rules.TOP_LEVEL else cap_image(caps[Rules.TOP_LEVEL]))
		caps[at_level].register(prewarm)
	cap = caps[Rules.TOP_LEVEL]
	for at_level in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		caps[at_level].set_other(caps[Rules.DEEPEST_LEVEL + Rules.TOP_LEVEL - at_level])
	_indicator = _make_indicator()
	add_child(_indicator)
	set_level(Rules.TOP_LEVEL)
	set_on(false)


static func cap_image(top: CapScript) -> Image:
	"""Level 1's cap's ground image (a lower level's reads its water distances from it)."""
	return top.ground_map()


func set_world(world: Node3D, buildings: Array[Vector3], trees: Array[Dictionary]) -> void:
	"""The world's footings and roots on the cap, and its sun kept to the surface (it already is, by its
	layer; its cull and shadow-caster masks say so too, so nothing underground is drawn into its shadow
	map)."""
	cap.add_footprints(buildings)
	cap.add_roots(trees)
	caps[Rules.LEVEL_2].commit_other()
	var sun := world.find_child(SUN_NODE, true, false) as DirectionalLight3D if world != null else null
	if sun != null:
		sun.light_cull_mask = Layers.SURFACE_VIEW
		sun.shadow_caster_mask = Layers.SURFACE_VIEW


func toggle() -> bool:
	"""Switch the view; returns whether it is now on."""
	set_on(not on)
	return on


func set_on(value: bool) -> void:
	"""Underground view on or off: the camera's cull mask and environment, and the level indicator shown, and
	nothing else (see the header)."""
	on = value
	if _indicator != null:
		_indicator.visible = on
	if _camera != null:
		_camera.cull_mask = Layers.view_mask(on, level)
		_camera.environment = environment if on else null


func set_level(value: int) -> bool:
	"""Show level `value` in the U view (clamped to the levels there are): one cull-mask write while the view is
	on, and the indicator's words (see THE LEVELS). Returns whether the level changed."""
	var to := clampi(value, Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL)
	var changed := to != level
	level = to
	Layers.active_level = to
	if _indicator_label != null:
		_indicator_label.text = level_words(to)
		_centre_indicator()
	if on and _camera != null:
		_camera.cull_mask = Layers.level_mask(to)
	return changed


func step_level(by: int) -> bool:
	"""Go `by` levels down (PgDn: +1) or up (PgUp: -1); returns whether the level changed."""
	return set_level(level + by)


func _make_indicator() -> CanvasLayer:
	"""THE LEVEL INDICATOR: a dark rounded strip in the top-centre column with the level in words, hidden until the U
	view is on; drawn under the prewarm's cover with every level's words (`prewarm_words`), so its glyphs are drawn
	once at boot."""
	var layer := CanvasLayer.new()
	layer.name = "LevelIndicator"
	layer.layer = INDICATOR_LAYER
	var box := PanelContainer.new()
	_indicator_box = box
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = INDICATOR_BACK
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	box.add_theme_stylebox_override(&"panel", style)
	_indicator_label = Label.new()
	_indicator_label.add_theme_font_size_override(&"font_size", INDICATOR_FONT_PX)
	_indicator_label.add_theme_color_override(&"font_color", INDICATOR_TEXT)
	_indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_indicator_label)
	layer.add_child(box)
	return layer


static func level_words(at: int) -> String:
	"""The indicator's words for level `at`: which of how many, its floor's depth and the key to the other."""
	return LEVEL_FORMAT % [at, Rules.DEEPEST_LEVEL, String.num(-Rules.level_floor_m(at), 2), LEVEL_KEYS[at]]


func _place_indicator() -> void:
	"""The indicator placed for the viewport's size (in the tree only)."""
	if is_inside_tree():
		place_indicator_for(get_viewport().get_visible_rect().size)


func place_indicator_for(size_px: Vector2) -> void:
	"""The HUD's layout for a screen of `size_px` at the interface scale (demo_ui_scale.gd, decision 0391), and the
	indicator placed by it."""
	if not _layout.compute_into(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), DemoUiScale.percent, false, _geometry):
		_geometry.scale = 1.0
	_centre_indicator()


func _centre_indicator() -> void:
	"""The indicator centred under the HUD's alert zone and pause label, at the HUD's scale (see THE LEVELS); its words'
	width changes with the level, the layout only with the screen."""
	if _indicator_box == null:
		return
	var alerts: Rect2 = _geometry.alerts
	var width: float = _indicator_box.get_combined_minimum_size().x
	_indicator_box.size = Vector2(width, 0.0)
	_indicator_box.scale = Vector2(_geometry.scale, _geometry.scale)
	var x: float = alerts.position.x + (alerts.size.x - width) / 2.0
	_indicator_box.position = Vector2(x, alerts.end.y + _indicator_gap) * _geometry.scale


static func indicator_gap_px() -> float:
	"""How far under the alert zone the indicator stands (logical px): below each HUD element ui_shell.gd stacks there
	(ABOVE_INDICATOR) at its registered least height (ui_registry.gd), ROW_GAP apart, and ROW_GAP more."""
	var registry := UiRegistry.new()
	var size := UiRegistry.Size.new()
	var gap := UiShell.ROW_GAP
	for id in ABOVE_INDICATOR:
		if registry.size_into(id, size):
			gap += float(size.min_height) + UiShell.ROW_GAP
	return gap


func indicator_layer() -> int:
	"""The indicator's canvas layer (checks)."""
	return _indicator.layer


func indicator_scale() -> float:
	"""The indicator's scale (checks)."""
	return _indicator_box.scale.x


func indicator_rect() -> Rect2:
	"""Where the indicator stands on the screen, scaled (checks)."""
	return Rect2(_indicator_box.position, _indicator_box.size * _indicator_box.scale)


func indicator_text() -> String:
	"""What the level indicator says now (checks)."""
	return _indicator_label.text


func indicator_shown() -> bool:
	"""Whether the level indicator is shown (checks)."""
	return _indicator.visible


static func underground_environment() -> Environment:
	"""The U view's environment (see THE UNDERGROUND'S ENVIRONMENT)."""
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 2.2
	env.ssao_power = 1.5
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = HAZE
	env.fog_density = HAZE_DENSITY
	env.fog_sky_affect = 0.0
	return env


func pick_y() -> float:
	"""The plane this view picks on (the ground, or the shown level's floor)."""
	return Layers.pick_y(on, level)


func ground_at(screen: Vector2) -> Vector2:
	"""The point (x, z) of this view's plane under a screen point; INF when the ray misses it."""
	if _camera == null:
		return Vector2.INF
	return ground_along(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen))


func ground_along(origin: Vector3, direction: Vector3) -> Vector2:
	"""Where a unit ray meets this view's plane, (x, z); INF when it misses it."""
	return Layers.pick_ground(origin, direction, pick_y())


# --- the boot prewarm -----------------------------------------------------------------------

func begin_prewarm() -> void:
	"""Draw the U view with one sample of everything registered (underground_prewarm.gd), from now until
	`end_prewarm` (demo_prewarm.gd runs it for PrewarmScript.FRAMES frames behind the opening pause)."""
	end_prewarm()
	_samples = Node3D.new()
	_samples.name = "PrewarmSamples"
	add_child(_samples)
	var focus: Vector3 = _focus()
	prewarm.build_samples(_samples, Vector3(focus.x, Layers.FLOOR_Y_M - SAMPLE_DEPTH_M * 0.5, focus.z))
	_cover = _make_cover()
	add_child(_cover)
	_indicator.visible = true
	_indicator_label.text = prewarm_words()
	if _camera != null:
		_camera.cull_mask = Layers.UNDERGROUND_VIEW
		_camera.environment = environment


func end_prewarm() -> void:
	"""Free the samples and give the camera back its view."""
	for node: Node in [_samples, _cover]:
		if node != null:
			remove_child(node)
			node.queue_free()
	_samples = null
	_cover = null
	if _indicator_label != null:
		_indicator_label.text = level_words(level)
		_centre_indicator()
	set_on(on)


static func prewarm_words() -> String:
	"""Every level's indicator words, one a line: drawn under the prewarm's cover so every glyph a switch shows is in the
	font's atlas before the first switch (a glyph first drawn at a switch is rasterised and uploaded in that frame)."""
	var lines := PackedStringArray()
	for at in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		lines.append(level_words(at))
	return "\n".join(lines)


static func _make_cover() -> CanvasLayer:
	"""An opaque screen-wide cover in the demo's deep shade, over everything but the HUD's own layers."""
	var cover := CanvasLayer.new()
	cover.name = "PrewarmCover"
	cover.layer = COVER_LAYER
	var fill := ColorRect.new()
	fill.color = COVER_COLOUR
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(fill)
	return cover


func _focus() -> Vector3:
	"""Where the camera looks: a point in front of it on the ground, or the origin without one."""
	if _camera == null or not _camera.is_inside_tree():
		return Vector3.ZERO
	var at: Vector2 = Layers.pick_ground(_camera.global_position, -_camera.global_basis.z, 0.0)
	return Vector3.ZERO if at == Vector2.INF else Vector3(at.x, 0.0, at.y)


func focus() -> Vector3:
	"""Where the U view looks: where the camera's forward ray meets the shown level's floor (the origin without a
	camera)."""
	if _camera == null or not _camera.is_inside_tree():
		return Vector3(0.0, Layers.floor_y(level), 0.0)
	return floor_focus(_camera.global_position, -_camera.global_basis.z, Layers.floor_y(level))


static func floor_focus(origin: Vector3, forward: Vector3, floor_y: float = Layers.FLOOR_Y_M) -> Vector3:
	"""Where a camera at `origin` looking along unit `forward` meets the floor at `floor_y` (the origin below when
	it looks level or up)."""
	var at: Vector2 = Layers.pick_ground(origin, forward, floor_y)
	return Vector3(at.x if at != Vector2.INF else 0.0, floor_y, at.y if at != Vector2.INF else 0.0)


func is_prewarming() -> bool:
	"""Whether the prewarm's samples are up (checks)."""
	return _samples != null
