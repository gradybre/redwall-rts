extends Node3D
## What the tunnel extensions add to the map. Decisions 0196 (live demo) and 0208 (per SEGMENT of the
## network). Presentation only.
##
## ON THE GROUND, per segment:
##   * SELECTED: a brass line along its route and a brass ring at each end (a mouth, or a junction below),
##     drawn over roofs.
##   * FLOODED: water lying along its route and a blue ring at each end.
##   * COLLAPSED: the fall's rubble (the library's tunnel_rubble) over the section and a clay ring round it.
##   * UNDER A WARNING (seep or strain past half): its ends ringed in clay, so the tunnel the alert names is
##     plain on the map -- in the U view too (decision 0211: the rings are drawn on the level's floor as well).
## The selection line is drawn twice, a node per view (decision 0206): on the ground, and on the level's
## floor for the U view, sharing one mesh.
## UNDERGROUND (the U view's layer; decisions 0206 and 0207), per tunnel: a timber brace frame every
## metre where the bore is wholly underground, once BRACED (the library's tunnel_brace, fitted inside the
## swept bore's horseshoe and drawn with the cutaway shader, cutaway.gdshader: its posts stand, its cap
## beam over a walker's head is cut away), and once LIT (tunnel_jobs.gd) its lanterns spread over the
## stretch under the ground (a ramp's from its portal on; a level bore's whole length): the library's
## wall_lantern hung on the bore's wall, a warm glow in it that
## blooms in the U view's environment, and a real light (tunnel_lanterns.gd: pooled, capped, flickering).
## With nothing staged (demo/props/demo_props.gd) the frame is three timber boxes, the rubble a heap and
## the lantern a box.
##
## Built once per segment slot the first time it opens (MultiMesh for frames and lanterns; never on a view
## switch) and placed when the segment is braced or lit, whatever the view; `refresh()` rebuilds a slot only
## when its state key changes, and otherwise moves nothing -- no per-frame allocation. A view switch
## changes nothing here.
##
## LEVELS (decision 0212). A slot's marks below go on its segment's level (`_put_on_level`, when the slot's level
## changes): its frames, lanterns and glows on that level's layer, its frames' cutaway cut over that level's floor,
## its line and rings on that level's marks layer and floor (a ring at a link's foot on the level below), and its
## dust on its level. A LINK's frames and lanterns stand on BOTH levels' layers, cut over the foot's floor: they are
## seen where the link is seen from the level below (the upper frames, cut, show nothing there).
##
## PUT UP ONE AT A TIME (decision 0211; design §4 "Frames placed per metre and lanterns hung one at a time, each with
## an install pop"). While a BRACE job is at work its frames stand only as far as the work has reached
## (tunnel_jobs.gd `along_m`), and each new one RISES from the floor over RISE_S with a puff of dust (the warren's
## pooled particles); while a LANTERNS job is at work its lanterns hang only as far as the work has reached, each new
## one's glow swelling on over RISE_S as its light blooms (tunnel_lanterns.gd BLOOM). The job done, all stand.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Layers := preload("res://demo/demo_layers.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const LanternsScript := preload("res://demo/tunnel/tunnel_lanterns.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const CUTAWAY_SHADER := preload("res://demo/tunnel/cutaway.gdshader")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")

const LINE_WIDTH_M: float = 0.22
const LINE_LIFT_M: float = 0.06
const WATER: Color = Color(0.3, 0.52, 0.72, 0.7)
const WATER_WIDTH_M: float = 0.9
const RING_M: float = 0.95
const FALL_RADIUS_M: float = 0.9
const FALL_COLOUR: Color = Color(0.2, 0.15, 0.1)
const FRAME_WOOD: Color = Color(0.45, 0.3, 0.17)
## The frame mesh's posts are this tall before scaling.
const FRAME_POST_M: float = 0.7
const LANTERN_GLOW: Color = Color(1.0, 0.78, 0.38)
## The glow blooms in the U view's environment (tunnel_view.gd): emission over 1.
const GLOW_ENERGY: float = 3.0
const MAX_FRAMES: int = Rules.MAX_LENGTH_U / Rules.QUANTUM_U + 1
const MAX_LANTERNS: int = Rules.MAX_LENGTH_U / (JobsScript.LANTERN_SPACING_M * Rules.QUANTUM_U) + 1
## A frame stands as tall as this share of the crown (inside the horseshoe's arch), and is cut away above
## BRACE_CUT_M over the level's floor (a fixed height: on a ramp's deep end less of a post shows) -- under
## its cap beam (see UNDERGROUND).
const FRAME_CROWN_SHARE: float = 0.72
const BRACE_CUT_M: float = 0.62
const BRACE_KEY: StringName = &"tunnel_brace"
const RUBBLE_KEY: StringName = &"tunnel_rubble"
const LANTERN_KEY: StringName = &"wall_lantern"
## A lantern hangs this far up the wall (from the bore floor), its bracket on the wall this share of
## the swept bore's half-width there out from the centre line. The library's wall_lantern has its bracket's wall
## plate at +X and its cage out at -X (read off a top render), so +X is turned to the wall. Its glow
## sits in the cage: GLOW_IN_CAGE of the lantern's drawn width and height from its origin.
const LANTERN_LIFT_M: float = 0.42
const LANTERN_WALL_SHARE: float = 0.9
const GLOW_IN_CAGE: Vector2 = Vector2(-0.28, 0.45)
const GLOW_RADIUS_M: float = 0.045
## The fall's rubble sinks this far into the ground over the collapse.
const RUBBLE_SINK_M: float = 0.06
## A frame rises, and a lantern's glow swells, over this much demo time (see PUT UP ONE AT A TIME).
const RISE_S: float = 0.6
const RISE_NONE: int = 0
const RISE_FRAME: int = 1
const RISE_GLOW: int = 2

var _network: GraphScript = null
var _hazards: HazardsScript = null
var _selected: int = -1
var _key: PackedInt64Array = PackedInt64Array()
## Per segment slot (built when it first opens; see the header).
var _lines: Array[MeshInstance3D] = []
## The selection lines as the U view draws them, on the level's floor (sharing each line's mesh).
var _lines_below: Array[MeshInstance3D] = []
var _waters: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
## The same rings as the U view draws them, on the level's floor (decision 0211: a warning reads in both views).
var _rings_below: Array[MeshInstance3D] = []
var _falls: Array[MeshInstance3D] = []
var _fall_rings: Array[MeshInstance3D] = []
var _frames: Array[MultiMeshInstance3D] = []
var _lanterns: Array[MultiMeshInstance3D] = []
var _glows: Array[MultiMeshInstance3D] = []
var _props: PropsScript = null
## The frame mesh's fit to a unit-wide, FRAME_POST_M-tall frame; the lantern's and rubble's fit.
var _frame_fit: Transform3D = Transform3D.IDENTITY
var _lantern_fit: Transform3D = Transform3D.IDENTITY
var _rubble_fit: Transform3D = Transform3D.IDENTITY
## The lanterns' light (pooled; tunnel_lanterns.gd).
var lights: LanternsScript = null
var _verts: PackedVector3Array = PackedVector3Array()
## The frame and glow meshes, built once and shared by every slot (one material each to prewarm).
var _brace_mesh: Mesh = null
var _brace_material: ShaderMaterial = null
## Each level's brace cutaway (index 0 unused), and the level each slot's marks were last put on (see LEVELS).
var _brace_materials: Array[ShaderMaterial] = [null, null, null]
var _slot_level: PackedInt32Array = PackedInt32Array()
var _glow: Mesh = null
## The ribbons' materials by colour and depth test, shared by every slot (so the prewarm's one line
## material is every selection line's).
var _ribbon_materials: Dictionary = {}
var _spots: PackedVector3Array = PackedVector3Array()
## Scratch for a sample of a bore's drawn centreline (point, heading).
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
## The jobs whose frames and lanterns go up one at a time, and the dust they raise (none: all at once).
var _jobs: JobsScript = null
var _particles: ParticlesScript = null
## Per segment slot: how many frames and lanterns stand (see PUT UP ONE AT A TIME), and the one rising -- its kind
## (RISE_*), its index and when it began (the lights' demo clock).
var _frames_up: PackedInt32Array = PackedInt32Array()
var _lanterns_up: PackedInt32Array = PackedInt32Array()
var _rise_kind: PackedByteArray = PackedByteArray()
var _rise_index: PackedInt32Array = PackedInt32Array()
var _rise_from: PackedFloat32Array = PackedFloat32Array()


func configure(network: GraphScript, hazards: HazardsScript, props: PropsScript = null, clock: DemoClockScript = null) -> void:
	"""Mark this network's tunnels, reading their hazards, with these props (none: boxes), the lanterns
	flickering on `clock`. Builds every node once."""
	name = "TunnelMarks"
	_network = network
	_hazards = hazards
	_props = props if props != null else PropsScript.new()
	_frame_fit = frame_fit(_props)
	_lantern_fit = _props.fit_of(LANTERN_KEY)
	_rubble_fit = _props.fit_of(RUBBLE_KEY)
	_brace_mesh = _props.mesh_of(BRACE_KEY) if _props.is_staged(BRACE_KEY) else _frame_mesh()
	for level in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		_brace_materials[level] = cutaway_of(_brace_mesh.surface_get_material(0), level)
	_brace_material = _brace_materials[Rules.TOP_LEVEL]
	_glow = _glow_mesh()
	lights = LanternsScript.new()
	add_child(lights)
	lights.configure(clock)
	_key.resize(Rules.MAX_SEGMENTS)
	_key.fill(-1)
	for column: Array in [_lines, _lines_below, _waters, _falls, _fall_rings, _frames, _lanterns, _glows]:
		column.resize(Rules.MAX_SEGMENTS)
	_rings.resize(2 * Rules.MAX_SEGMENTS)
	_rings_below.resize(2 * Rules.MAX_SEGMENTS)
	for column: Variant in [_frames_up, _lanterns_up, _rise_index, _rise_from, _rise_kind, _slot_level]:
		column.resize(Rules.MAX_SEGMENTS)
	_slot_level.fill(-1)
	_ensure(0)


func set_theatre(jobs: JobsScript, particles: ParticlesScript) -> void:
	"""The jobs whose frames and lanterns go up one at a time, and the warren's particles their dust comes from
	(warren_particles.gd; see PUT UP ONE AT A TIME)."""
	_jobs = jobs
	_particles = particles


func _ensure(slot: int) -> void:
	"""Build segment slot `slot`'s marks the first time it needs them, hidden (slot 0's at setup, so the
	prewarm has one of each)."""
	if _lines[slot] != null:
		return
	_lines[slot] = _ribbon_node(Color(Palette.BRASS, 0.9), true)
	_lines[slot].layers = Layers.SURFACE_MARKS
	_lines_below[slot] = _line_below(_lines[slot])
	_waters[slot] = _ribbon_node(WATER, false)
	for end in 2:
		var ring := MarksScript.make_ring(Palette.BRASS)
		ring.visible = false
		add_child(ring)
		_rings[2 * slot + end] = ring
		var below := MarksScript.make_ring(Palette.BRASS)
		below.material_override = _ring_below_material(Palette.BRASS)
		below.layers = Layers.UNDERGROUND_MARKS
		below.visible = false
		add_child(below)
		_rings_below[2 * slot + end] = below
	_falls[slot] = _fall_node()
	var fall_ring := MarksScript.make_ring(Palette.CLAY)
	fall_ring.visible = false
	add_child(fall_ring)
	_fall_rings[slot] = fall_ring
	_frames[slot] = _multi(_brace_mesh, MAX_FRAMES)
	_frames[slot].material_override = _brace_material
	_lanterns[slot] = _multi(_props.mesh_of(LANTERN_KEY), MAX_LANTERNS)
	_glows[slot] = _multi(_glow, MAX_LANTERNS)


func _fall_node() -> MeshInstance3D:
	"""A fall's rubble (the library's, else a dark heap), hidden."""
	var fall := MeshInstance3D.new()
	fall.mesh = _props.mesh_of(RUBBLE_KEY)
	if not _props.is_staged(RUBBLE_KEY):
		fall.mesh = OverlayScript.heap_mesh()
		fall.material_override = _plain(FALL_COLOUR)
	fall.visible = false
	add_child(fall)
	return fall


func _line_below(line: MeshInstance3D) -> MeshInstance3D:
	"""The U view's copy of a selection line: its mesh and material, on the level's floor, hidden."""
	var below := MeshInstance3D.new()
	below.mesh = line.mesh
	below.material_override = line.material_override
	below.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	below.layers = Layers.UNDERGROUND_MARKS
	below.position.y = Layers.FLOOR_Y_M
	below.visible = false
	add_child(below)
	return below


func _ribbon_node(colour: Color, on_top: bool) -> MeshInstance3D:
	"""A ribbon along a route, hidden, wearing the one shared material of its colour."""
	var node := MeshInstance3D.new()
	node.mesh = ImmediateMesh.new()
	node.material_override = _ribbon_material(colour, on_top)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


func _ribbon_material(colour: Color, on_top: bool) -> StandardMaterial3D:
	"""The ribbons' shared material of this colour, drawn over everything or not (made once)."""
	var key := "%s/%s" % [colour.to_html(), on_top]
	if _ribbon_materials.has(key):
		return _ribbon_materials[key]
	var material := _plain(colour)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = on_top
	material.render_priority = 3 if on_top else 1
	_ribbon_materials[key] = material
	return material


func _ring_below_material(colour: Color) -> StandardMaterial3D:
	"""The U view's ring of `colour`, drawn over the cap (no depth test), one material a colour, shared (the prewarm
	registers each: `register`)."""
	var key := "below/%s" % colour.to_html()
	if not _ribbon_materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.no_depth_test = true
		material.render_priority = 3
		material.albedo_color = colour
		_ribbon_materials[key] = material
	return _ribbon_materials[key]


static func _plain(colour: Color) -> StandardMaterial3D:
	"""A rough material of one colour."""
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


func _multi(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	"""A MultiMesh node for up to `count` copies of `mesh`, none shown yet."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = Layers.UNDERGROUND
	node.visible = false
	add_child(node)
	return node


func _frame_mesh() -> Mesh:
	"""One timber frame across the bore: two posts and the cap beam across their tops -- seen from
	above, a rung across the trough, one every metre."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Transform3D in [Transform3D(Basis.from_scale(Vector3(1.04, 0.09, 0.14)), Vector3(0.0, FRAME_POST_M, 0.0)),
			Transform3D(Basis.from_scale(Vector3(0.1, FRAME_POST_M, 0.12)), Vector3(-0.47, FRAME_POST_M * 0.5, 0.0)),
			Transform3D(Basis.from_scale(Vector3(0.1, FRAME_POST_M, 0.12)), Vector3(0.47, FRAME_POST_M * 0.5, 0.0))]:
		tool.append_from(BoxMesh.new(), 0, part)
	tool.generate_normals()
	var mesh := tool.commit()
	mesh.surface_set_material(0, _plain(FRAME_WOOD))
	return mesh


static func cutaway_of(source: Material, level: int = Rules.TOP_LEVEL) -> ShaderMaterial:
	"""The cutaway material (cutaway.gdshader) for a prop drawn with `source`: its albedo map, tint and
	roughness, cut BRACE_CUT_M over `level`'s floor."""
	var material := ShaderMaterial.new()
	material.shader = CUTAWAY_SHADER
	material.set_shader_parameter(&"cut_y", Layers.floor_y(level) + BRACE_CUT_M)
	var standard := source as BaseMaterial3D
	if standard != null:
		material.set_shader_parameter(&"albedo_colour", standard.albedo_color)
		material.set_shader_parameter(&"roughness", standard.roughness)
		if standard.albedo_texture != null:
			material.set_shader_parameter(&"albedo_texture", standard.albedo_texture)
	return material


static func frame_fit(props: PropsScript) -> Transform3D:
	"""How the brace model fits the unit frame _bore_transform scales (1 m wide, FRAME_POST_M tall,
	centred, its base at 0); the box frame already is that."""
	if not props.is_staged(BRACE_KEY):
		return Transform3D.IDENTITY
	var bound: AABB = props.drawn_bound(BRACE_KEY)
	var squeeze := Vector3(1.0 / bound.size.x, FRAME_POST_M / bound.size.y, 1.0 / bound.size.x)
	return Transform3D(Basis.from_scale(squeeze), -bound.get_center() * squeeze + Vector3(0.0, FRAME_POST_M * 0.5, 0.0)) \
			* props.fit_of(BRACE_KEY)


func _glow_mesh() -> Mesh:
	"""The small warm glow inside a lantern."""
	var sphere := SphereMesh.new()
	sphere.radius = GLOW_RADIUS_M
	sphere.height = GLOW_RADIUS_M * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LANTERN_GLOW
	material.emission_enabled = true
	material.emission = LANTERN_GLOW
	material.emission_energy_multiplier = GLOW_ENERGY
	sphere.material = material
	return sphere


func select(slot: int) -> void:
	"""Mark tunnel `slot` as selected (-1: none)."""
	_selected = slot
	_key.fill(-1)


func register(prewarm: PrewarmScript) -> void:
	"""What these marks draw in the U view -- frames (with their cutaway), lanterns, their glows, the
	selection line through the cap -- for its prewarm (decision 0206)."""
	for node: MultiMeshInstance3D in [_frames[0], _lanterns[0], _glows[0]]:
		prewarm.add_multimesh(node.multimesh.mesh, node.material_override)
	prewarm.add_multimesh(_brace_mesh, _brace_materials[Rules.LEVEL_2])
	for colour: Color in [Palette.BRASS, Palette.CLAY, WATER]:
		prewarm.add_mesh(MarksScript.ring_mesh(), _ring_below_material(colour))
	prewarm.add_mesh(OverlayScript.immediate_sample(), _lines_below[0].material_override)


func refresh() -> void:
	"""Redraw each segment whose state changed, and raise what is rising (see PUT UP ONE AT A TIME)."""
	for slot in Rules.MAX_SEGMENTS:
		var key := _state_key(slot)
		if key != _key[slot]:
			_key[slot] = key
			_ensure(slot)
			_draw_slot(slot)
		if _rise_kind[slot] != RISE_NONE:
			_raise(slot)


func _state_key(slot: int) -> int:
	"""Everything a slot's marks depend on, as one number (-1: nothing to draw: not open, or a room's own
	segment -- room_view.gd draws a room's ribs and lantern)."""
	if not _network.is_open(slot) or _network.seg_kind[slot] == GraphScript.SEG_ROOM:
		return -1
	var warned := 1 if _warned(slot) else 0
	var bits := int(_network.closed[slot]) + 4 * int(_network.braced[slot]) + 8 * int(_network.lit[slot]) + 16 * warned
	var going_up := _going_up(slot, JobsScript.JOB_BRACE) + 64 * _going_up(slot, JobsScript.JOB_LANTERNS)
	return bits + 32 * (1 if slot == _selected else 0) + 128 * int(_network.bore[slot]) + 256 * _network.generation[slot] \
			+ 65536 * _network.length_u[slot] + (going_up << 40)


func _going_up(slot: int, job: int) -> int:
	"""How many of segment `slot`'s frames (a BRACE job) or lanterns (LANTERNS) stand while that job is at work --
	as far as the work has reached, and 1 more than that (a key never 0 while it works) -- else 0."""
	if _jobs == null or not _jobs.has_job(slot) or _jobs.kind[slot] != job or _jobs.paid[slot] == 0:
		return 0
	var reached := _jobs.along_m(slot)
	var count := 0
	if job == JobsScript.JOB_BRACE:
		for k in range(_first_frame(slot), mini(floori(_network.length_m(slot)) + 1, MAX_FRAMES)):
			count += 1 if float(k) <= reached and _deep_enough(slot, float(k)) else 0
	else:
		var total := _lantern_count(slot)
		for k in total:
			count += 1 if lantern_along(slot, k, total) <= reached else 0
	return count + 1


func _warned(slot: int) -> bool:
	"""Whether a seep or strain warning stands on tunnel `slot` (past half, not yet struck)."""
	return _hazards != null and _network.closed[slot] == GraphScript.CLOSED_NONE \
			and (_hazards.seep_permille(slot) >= HazardsScript.WARN_PERMILLE or _hazards.strain_permille(slot) >= HazardsScript.WARN_PERMILLE)


func _draw_slot(slot: int) -> void:
	"""Every mark of one slot, from its state."""
	_put_on_level(slot)
	var open := _network.is_open(slot)
	var closed := _network.closed[slot] if open else GraphScript.CLOSED_NONE
	_draw_line(_lines[slot], slot, LINE_WIDTH_M, open and slot == _selected)
	_lines_below[slot].visible = _lines[slot].visible
	_draw_line(_waters[slot], slot, WATER_WIDTH_M, closed == GraphScript.CLOSED_FLOODED)
	_place_rings(slot, open)
	_place_fall(slot, closed == GraphScript.CLOSED_COLLAPSED)
	_place_frames(slot, open and _network.braced[slot] == 1, _going_up(slot, JobsScript.JOB_BRACE) - 1)
	_place_lanterns(slot, open and _network.lit[slot] == 1, _going_up(slot, JobsScript.JOB_LANTERNS) - 1)


func _put_on_level(slot: int) -> void:
	"""Slot `slot`'s marks below on its segment's level (see LEVELS) -- a link's on both its levels, as it is selected
	from either -- rewritten only when that changed."""
	var level: int = _network.seg_level[slot]
	var link := _network.seg_kind[slot] == GraphScript.SEG_LINK
	var placed := level * 2 + (1 if link else 0)
	if placed == _slot_level[slot]:
		return
	_slot_level[slot] = placed
	var below := Layers.below(level) | (Layers.below(level + 1) if link else 0)
	for node: MultiMeshInstance3D in [_frames[slot], _lanterns[slot], _glows[slot]]:
		node.layers = below
	_frames[slot].material_override = _brace_materials[level + 1 if link else level]
	_lines_below[slot].layers = Layers.marks(level) | (Layers.marks(level + 1) if link else 0)
	_lines_below[slot].position.y = Layers.floor_y(level)


func _end_level(slot: int, at_b: bool) -> int:
	"""The level an end of segment `slot` lies on: its node's (a mouth is the segment's own level's)."""
	var level: int = _network.node_level[_network.end_node(slot, at_b)]
	return level if level > Rules.LEVEL_SURFACE else int(_network.seg_level[slot])


func _draw_line(node: MeshInstance3D, slot: int, width: float, show: bool) -> void:
	"""A ribbon along tunnel `slot`'s route, or hidden."""
	node.visible = show
	var mesh := node.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if not show:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_set_normal(Vector3.UP)
	for k in range(1, _network.point_count[slot]):
		var a := _network.point(slot, k - 1)
		var b := _network.point(slot, k)
		var across := (b - a).normalized().orthogonal() * (width * 0.5)
		for v in [a - across, a + across, b + across, a - across, b + across, b - across]:
			mesh.surface_add_vertex(Vector3(v.x, LINE_LIFT_M, v.y))
	mesh.surface_end()


func _place_rings(slot: int, open: bool) -> void:
	"""Rings at the mouths: brass when selected, blue when flooded, clay under a warning."""
	var colour := Palette.BRASS
	var show := open and slot == _selected
	if open and _network.closed[slot] == GraphScript.CLOSED_FLOODED:
		colour = WATER
		show = true
	elif open and _warned(slot):
		colour = Palette.CLAY
		show = true
	for end in 2:
		var at := _network.end_at(slot, end == 1)
		var ring := _rings[2 * slot + end]
		var below := _rings_below[2 * slot + end]
		ring.visible = show
		below.visible = show
		if show:
			ring.position = Vector3(at.x, MarksScript.LIFT_M, at.y)
			ring.scale = Vector3(RING_M, 1.0, RING_M)
			MarksScript.set_alpha(ring, colour, 1.0)
			var level := _end_level(slot, end == 1)
			below.position = Vector3(at.x, Layers.floor_y(level) + Layers.MARK_LIFT_M, at.y)
			below.layers = Layers.marks(level)
			below.scale = ring.scale
			below.material_override = _ring_below_material(colour)


func _place_fall(slot: int, show: bool) -> void:
	"""A sunken patch of fallen earth, ringed in clay, over a collapsed section."""
	_falls[slot].visible = show
	_fall_rings[slot].visible = show
	if not show:
		return
	var mid_m := Rules.to_m((_network.closed_from_u[slot] + _network.closed_to_u[slot]) / 2)
	var at := _network.point_at(slot, mid_m)
	if _props.is_staged(RUBBLE_KEY):
		_falls[slot].transform = Transform3D(Basis(Vector3.UP, float(slot)), Vector3(at.x, -RUBBLE_SINK_M, at.y)) * _rubble_fit
	else:
		_falls[slot].position = Vector3(at.x, -0.02, at.y)
		_falls[slot].scale = Vector3(FALL_RADIUS_M, 0.12, FALL_RADIUS_M)
	_fall_rings[slot].position = Vector3(at.x, MarksScript.LIFT_M, at.y)
	_fall_rings[slot].scale = Vector3(FALL_RADIUS_M + 0.3, 1.0, FALL_RADIUS_M + 0.3)


func _bore_transform(slot: int, along: float, lift: float) -> Transform3D:
	"""A frame across tunnel `slot` `along` metres in on its drawn centreline (bore_curve.gd), `lift` above
	its floor, as wide as its bore's floor and FRAME_CROWN_SHARE of its crown tall -- inside the swept
	horseshoe's arch."""
	BoreCurveScript.of(_network, slot).sample(along, _sample)
	var at := _sample[0]
	var ahead := _sample[1]
	var bore := int(_network.bore[slot])
	var width := BoreMeshScript.FLOOR_HALF_M[bore] * 2.0
	var tall := Rules.crown_m(bore) * FRAME_CROWN_SHARE
	var basis := Basis(Vector3.UP, atan2(ahead.x, ahead.y)).scaled(Vector3(width, tall / FRAME_POST_M, 1.0))
	return Transform3D(basis, Vector3(at.x, _network.floor_y_at(slot, along) + lift, at.y))


func _deep_enough(slot: int, along: float) -> bool:
	"""Whether the bore `along` metres in lies wholly under the ground (a frame there stays under it):
	past the ramp's open cutting."""
	return _network.floor_y_at(slot, along) + Rules.crown_m(int(_network.bore[slot])) <= 0.0


func _place_frames(slot: int, braced: bool, going_up: int) -> void:
	"""A timber frame every metre of a braced bore -- but none at its start inside the network (a ramp's foot,
	a junction): the segment arriving there frames that metre, so a frame is never doubled. While it is being braced,
	the first `going_up` of them, the newest rising with a puff (see PUT UP ONE AT A TIME)."""
	var node := _frames[slot]
	var limit := MAX_FRAMES if braced else maxi(going_up, 0)
	node.visible = limit > 0
	var count := 0
	for k in range(_first_frame(slot), mini(floori(_network.length_m(slot)) + 1, MAX_FRAMES)):
		if count < limit and _deep_enough(slot, float(k)):
			node.multimesh.set_instance_transform(count, _bore_transform(slot, float(k), 0.0) * _frame_fit)
			count += 1
	node.multimesh.visible_instance_count = count
	var grew := not braced and count > _frames_up[slot]
	_frames_up[slot] = count
	if grew:
		_start_rise(slot, RISE_FRAME, count - 1)
		_puff(_bore_transform(slot, _frame_along(slot, count - 1), 0.3).origin)


func _first_frame(slot: int) -> int:
	"""The metre segment `slot`'s first frame stands at: 0 at a mouth, else 1 (see `_place_frames`)."""
	return 0 if _network.node_mouth[_network.node_a[slot]] >= 0 else 1


func _frame_along(slot: int, index: int) -> float:
	"""Where segment `slot`'s frame `index` stands (m along it; frames stand every metre under the ground)."""
	var n := -1
	for k in range(_first_frame(slot), mini(floori(_network.length_m(slot)) + 1, MAX_FRAMES)):
		if _deep_enough(slot, float(k)):
			n += 1
			if n == index:
				return float(k)
	return 0.0


func _lantern_count(slot: int) -> int:
	"""How many lanterns light segment `slot` once lit: one for every started LANTERN_SPACING_M (the job's count)."""
	return mini(ceili(_network.length_m(slot) / float(JobsScript.LANTERN_SPACING_M)), MAX_LANTERNS)


func _place_lanterns(slot: int, lit: bool, going_up: int) -> void:
	"""A wall lantern for every LANTERN_SPACING_M of a lit bore (the job's count), spread evenly over the
	stretch under the ground, on alternate walls, a glow in each and its light handed to the pool. While they are
	being hung, the first `going_up` of them, the newest's glow swelling on (see PUT UP ONE AT A TIME)."""
	var node := _lanterns[slot]
	var total := _lantern_count(slot)
	var count := total if lit else clampi(going_up, 0, total)
	node.visible = count > 0
	_glows[slot].visible = count > 0
	_spots.resize(0)
	if count > 0:
		for k in count:
			var hung := lantern_transform(slot, lantern_along(slot, k, total), k % 2 == 0)
			node.multimesh.set_instance_transform(k, hung * _lantern_fit)
			var size: Vector3 = _props.drawn_bound(LANTERN_KEY).size
			var glow_at: Vector3 = hung * Vector3(size.x * GLOW_IN_CAGE.x, size.y * GLOW_IN_CAGE.y, 0.0)
			_glows[slot].multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, glow_at))
			_spots.append(glow_at)
	node.multimesh.visible_instance_count = count
	_glows[slot].multimesh.visible_instance_count = count
	lights.set_spots(slot, _spots.duplicate())
	if not lit and count > _lanterns_up[slot]:
		_start_rise(slot, RISE_GLOW, count - 1)
	_lanterns_up[slot] = count


# --- going up (see PUT UP ONE AT A TIME) ---------------------------------------------------------------

func _start_rise(slot: int, kind: int, index: int) -> void:
	"""Segment `slot`'s `index`th frame (or glow) starts rising now."""
	_rise_kind[slot] = kind
	_rise_index[slot] = index
	_rise_from[slot] = lights.time_now()
	_raise(slot)


func _raise(slot: int) -> void:
	"""The rising frame of segment `slot` stands `rise_share` of its height, or its rising glow swells; done, it stands
	whole."""
	var t := clampf((lights.time_now() - _rise_from[slot]) / RISE_S, 0.0, 1.0)
	var index := _rise_index[slot]
	if _rise_kind[slot] == RISE_FRAME and index < _frames[slot].multimesh.visible_instance_count:
		var grow := Transform3D(Basis.from_scale(Vector3(1.0, maxf(rise_share(t), 0.02), 1.0)), Vector3.ZERO)
		_frames[slot].multimesh.set_instance_transform(index, _bore_transform(slot, _frame_along(slot, index), 0.0) * grow * _frame_fit)
	elif _rise_kind[slot] == RISE_GLOW and index < _glows[slot].multimesh.visible_instance_count:
		var glow := _glows[slot].multimesh.get_instance_transform(index)
		_glows[slot].multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * maxf(swell_share(t), 0.02)), glow.origin))
	if t >= 1.0:
		_rise_kind[slot] = RISE_NONE


static func rise_share(t: float) -> float:
	"""A rising frame's height share at `t` (0..1 of RISE_S): up quickly, a little past, and settling."""
	return 1.0 + 0.08 * sin(t * PI) - pow(1.0 - t, 3.0)


static func swell_share(t: float) -> float:
	"""A new lantern's glow's size at `t` (0..1 of RISE_S): swelling past full and settling, as its light blooms."""
	return sin(t * PI * 0.5) + 0.35 * sin(t * PI)


func _puff(at: Vector3) -> void:
	"""A puff of dust at `at`, below on the level its height lies on (none without the theatre)."""
	if _particles != null:
		_particles.puff(at, Layers.below(Layers.level_at(at.y)))


func frames_up(slot: int) -> int:
	"""How many of segment `slot`'s frames were last drawn standing (checks)."""
	return _frames_up[slot]


func lanterns_up(slot: int) -> int:
	"""How many of segment `slot`'s lanterns were last drawn hanging (checks)."""
	return _lanterns_up[slot]


func lantern_along(slot: int, k: int, count: int) -> float:
	"""Where lantern `k` of `count` hangs along segment `slot` (m): evenly over the stretch under the ground --
	a ramp's from its portal (where the bore goes under) to its foot, a level bore's whole length."""
	var length := _network.length_m(slot)
	var from := 0.0
	var to := length
	if _network.seg_kind[slot] == GraphScript.SEG_RAMP:
		var portal := minf(Rules.portal_m(int(_network.bore[slot])), length)
		if _network.mouth_end_at_b(slot):
			to = length - portal
		else:
			from = portal
	return from + (float(k) + 0.5) * (to - from) / float(count)


func lantern_transform(slot: int, along: float, left: bool) -> Transform3D:
	"""A lantern `along` metres into tunnel `slot`, its bracket on its left (or right) wall and its cage
	out over the bore, LANTERN_LIFT_M up from the floor: the model's +X turned to the wall."""
	BoreCurveScript.of(_network, slot).sample(along, _sample)
	var at := _sample[0]
	var ahead := _sample[1]
	var across := Vector2(-ahead.y, ahead.x) * (1.0 if left else -1.0)
	var bore := int(_network.bore[slot])
	var half := BoreMeshScript.FLOOR_HALF_M[bore] * BoreMeshScript.width_share(LANTERN_LIFT_M / Rules.crown_m(bore)) * LANTERN_WALL_SHARE
	var inward := -across
	var reach: float = _props.drawn_bound(LANTERN_KEY).size.x * 0.5
	var origin := at + across * half + inward * reach
	return Transform3D(Basis(Vector3.UP, atan2(inward.y, -inward.x)),
		Vector3(origin.x, _network.floor_y_at(slot, along) + LANTERN_LIFT_M, origin.y))


func line(slot: int) -> MeshInstance3D:
	"""The selection line of tunnel `slot` (for checks)."""
	return _lines[slot]


func water(slot: int) -> MeshInstance3D:
	"""The flood water of tunnel `slot` (for checks)."""
	return _waters[slot]


func fall(slot: int) -> MeshInstance3D:
	"""The fallen earth over tunnel `slot`'s collapse (for checks)."""
	return _falls[slot]


func frames(slot: int) -> MultiMeshInstance3D:
	"""Tunnel `slot`'s timber frames (for checks)."""
	return _frames[slot]


func lanterns(slot: int) -> MultiMeshInstance3D:
	"""Tunnel `slot`'s lanterns (for checks)."""
	return _lanterns[slot]


func glows(slot: int) -> MultiMeshInstance3D:
	"""The glows in tunnel `slot`'s lanterns (for checks)."""
	return _glows[slot]


func line_below(slot: int) -> MeshInstance3D:
	"""The selection line of tunnel `slot` as the U view draws it (for checks)."""
	return _lines_below[slot]


func brace_mesh() -> Mesh:
	"""The brace frame mesh every frame is drawn with (the library's tunnel_brace, else a box frame): the rooms'
	timber ribs too (room_view.gd)."""
	return _brace_mesh


func glow_mesh() -> Mesh:
	"""The warm glow inside a lantern (the rooms' lanterns too)."""
	return _glow


func frame_mesh_fit() -> Transform3D:
	"""The fit every brace frame is drawn with (for checks)."""
	return _frame_fit
