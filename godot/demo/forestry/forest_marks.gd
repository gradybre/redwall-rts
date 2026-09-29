extends Node3D
## The woods' marks on the ground. Decision 0196 (live demo). Presentation only.
##
##   zone outlines   every forestry zone edged in brass, every conservation zone in sage, always shown
##                   (a thin band on the ground; the selected zone's band is wider); redrawn only when
##                   the zones or the selection change
##   the overlay     V's one overlay cycle (demo_farm.gd add_overlay) gains "woods": each zone washed in
##                   its colour, and a disc at every tree -- leaf mature, brass young, umber stump,
##                   clay cleared -- drawn over the canopies (no depth test), so a zone's floor reads
##                   at a glance from above the woods
##   the selection   a brass ring round the selected tree
##   the zone tool   the rectangle being dragged, snapped to whole tiles, clay when it would be refused
## The overlay's discs are one MultiMesh; the outlines and the drag rectangle one ImmediateMesh each,
## a surface per colour with its own flat material (the tunnels' overlay's way: no vertex colours).

const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")

const LIFT_M: float = 0.06
const BAND_M: float = 0.18
const SELECTED_BAND_M: float = 0.34
const WASH_ALPHA: float = 0.22
const DISC_RADIUS_M: float = 1.2
const DISC_LIFT_M: float = 0.08
const RING_EXTRA_M: float = 0.5
## A young tree's or a cleared spot's ring is this wide before RING_EXTRA_M.
const SPOT_RING_M: float = 0.4
const FORESTRY_COLOUR: Color = Palette.BRASS
const CONSERVATION_COLOUR: Color = Palette.SAGE
const STATE_COLOURS: Array[Color] = [Palette.CLAY, Palette.LEAF, Palette.UMBER, Palette.BRASS]

var overlay_shown: bool = false
var selected_zone: int = -1

var _zones: ZonesScript = null
var _stand: StandScript = null
var _outline: MeshInstance3D = null
var _wash: MeshInstance3D = null
var _preview: MeshInstance3D = null
var _discs: MultiMeshInstance3D = null
var _ring: MeshInstance3D = null
var _seen_zones: int = -1
var _seen_stand: int = -1
var _seen_selected: int = -2
## Flat materials by colour, made once.
var _materials: Dictionary = {}


func configure(zones: ZonesScript, stand: StandScript) -> void:
	"""Draw these zones and trees' marks."""
	name = "ForestMarks"
	_zones = zones
	_stand = stand
	_outline = _mesh_node("ZoneOutlines")
	_wash = _mesh_node("ZoneWash")
	_preview = _mesh_node("ZonePreview")
	_wash.visible = false
	_preview.visible = false
	_discs = MultiMeshInstance3D.new()
	_discs.name = "TreeDiscs"
	_discs.multimesh = _disc_multimesh()
	_discs.visible = false
	add_child(_discs)
	_ring = MarksScript.make_ring(MarksScript.SELECTED)
	_ring.visible = false
	add_child(_ring)


func _mesh_node(node_name: String) -> MeshInstance3D:
	"""A shadowless ground mesh node (its surfaces carry their own materials)."""
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = ImmediateMesh.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _flat(colour: Color, on_top: bool = false) -> StandardMaterial3D:
	"""The shared flat, see-through, double-sided material of one colour -- drawn over everything when
	`on_top` (the overlay)."""
	var key := Color(colour.r, colour.g, colour.b, -colour.a) if on_top else colour
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = colour
		material.render_priority = 2 if on_top else 1
		material.no_depth_test = on_top
		_materials[key] = material
	return _materials[key]


func _disc_multimesh() -> MultiMesh:
	"""One flat disc per tree slot, coloured per instance."""
	var disc := CylinderMesh.new()
	disc.top_radius = DISC_RADIUS_M
	disc.bottom_radius = DISC_RADIUS_M
	disc.height = 0.04
	disc.radial_segments = 16
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.no_depth_test = true
	material.render_priority = 3
	disc.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = disc
	multimesh.instance_count = StandScript.MAX_TREES
	multimesh.visible_instance_count = 0
	return multimesh


func refresh() -> void:
	"""Redraw what changed: the outlines and wash on the zones or the selection, the discs on the trees."""
	if _zones.revision != _seen_zones or selected_zone != _seen_selected:
		_seen_zones = _zones.revision
		_seen_selected = selected_zone
		_draw_zones()
	if overlay_shown and _stand.revision != _seen_stand:
		_seen_stand = _stand.revision
		_draw_discs()


func set_overlay(on: bool) -> void:
	"""V's woods overlay on or off."""
	overlay_shown = on
	_wash.visible = on
	_discs.visible = on
	_seen_stand = -1
	refresh()


func _draw_zones() -> void:
	"""Every zone's band -- a surface per kind -- and, for the overlay, its wash."""
	var lines := _outline.mesh as ImmediateMesh
	var wash := _wash.mesh as ImmediateMesh
	lines.clear_surfaces()
	wash.clear_surfaces()
	for kind: int in [ZonesScript.KIND_FORESTRY, ZonesScript.KIND_CONSERVATION]:
		if not _has_kind(kind):
			continue
		var colour: Color = FORESTRY_COLOUR if kind == ZonesScript.KIND_FORESTRY else CONSERVATION_COLOUR
		lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _flat(colour))
		wash.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _flat(Color(colour, WASH_ALPHA), true))
		for z: int in ZonesScript.MAX_ZONES:
			if _zones.is_zone(z) and _zones.kind[z] == kind:
				band_rect(lines, _zones.rect_m(z), SELECTED_BAND_M if z == selected_zone else BAND_M)
				_quad(wash, _zones.rect_m(z))
		lines.surface_end()
		wash.surface_end()


func _has_kind(kind: int) -> bool:
	"""Whether any zone of this kind is marked."""
	for z: int in ZonesScript.MAX_ZONES:
		if _zones.is_zone(z) and _zones.kind[z] == kind:
			return true
	return false


static func band_rect(mesh: ImmediateMesh, rect: Rect2, band: float) -> void:
	"""A rectangle's edge as four flat bands `band` wide, just inside it."""
	var inner: Rect2 = rect.grow(-band)
	_quad(mesh, Rect2(rect.position, Vector2(rect.size.x, band)))
	_quad(mesh, Rect2(Vector2(rect.position.x, inner.end.y), Vector2(rect.size.x, band)))
	_quad(mesh, Rect2(Vector2(rect.position.x, inner.position.y), Vector2(band, inner.size.y)))
	_quad(mesh, Rect2(Vector2(inner.end.x, inner.position.y), Vector2(band, inner.size.y)))


static func _quad(mesh: ImmediateMesh, rect: Rect2) -> void:
	"""One flat quad on the ground over `rect` (x, z), as two triangles, facing up."""
	var a := Vector3(rect.position.x, LIFT_M, rect.position.y)
	var b := Vector3(rect.end.x, LIFT_M, rect.position.y)
	var c := Vector3(rect.end.x, LIFT_M, rect.end.y)
	var d := Vector3(rect.position.x, LIFT_M, rect.end.y)
	for p: Vector3 in [a, b, c, a, c, d]:
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_add_vertex(p)


func _draw_discs() -> void:
	"""A disc at every tree in its state's colour."""
	var multimesh: MultiMesh = _discs.multimesh
	multimesh.visible_instance_count = _stand.count()
	for t: int in _stand.count():
		var at: Vector2 = _stand.at[t]
		multimesh.set_instance_transform(t, Transform3D(Basis.IDENTITY, Vector3(at.x, DISC_LIFT_M, at.y)))
		multimesh.set_instance_color(t, STATE_COLOURS[_stand.state_of(t)])


func select_tree(t: int) -> void:
	"""Ring tree `t` (-1: none)."""
	_ring.visible = _stand.is_tree(t)
	if not _ring.visible:
		return
	var standing: bool = _stand.state_of(t) == StandScript.STATE_MATURE or _stand.state_of(t) == StandScript.STATE_STUMP
	var r: float = (_stand.radius_m[t] if standing else SPOT_RING_M) + RING_EXTRA_M
	_ring.position = Vector3(_stand.at[t].x, MarksScript.LIFT_M, _stand.at[t].y)
	_ring.scale = Vector3(r, 1.0, r)


func show_preview(rect: Rect2, ok: bool) -> void:
	"""The zone being dragged, brass when it would be marked, clay when refused."""
	var mesh := _preview.mesh as ImmediateMesh
	var colour: Color = Palette.BRASS if ok else Palette.CLAY
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _flat(colour))
	band_rect(mesh, rect, SELECTED_BAND_M)
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _flat(Color(colour, WASH_ALPHA)))
	_quad(mesh, rect.grow(-SELECTED_BAND_M))
	mesh.surface_end()
	_preview.visible = true


func hide_preview() -> void:
	"""No zone is being dragged."""
	_preview.visible = false


func preview_shown() -> bool:
	"""Whether a zone is being dragged (checks)."""
	return _preview.visible


func ring_shown() -> bool:
	"""Whether a tree is ringed (checks)."""
	return _ring.visible


func discs_shown() -> int:
	"""How many tree discs the overlay draws (0 when it is off; checks)."""
	return _discs.multimesh.visible_instance_count if _discs.visible else 0
