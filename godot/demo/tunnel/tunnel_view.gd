extends Node3D
## The demo's underground view (U). Decision 0196 (live demo). Presentation only: it changes what is
## drawn, never where anyone is (MOVE-REQ-015: hiding a layer preserves occupancy).
##
## ON: the grass ground is swapped for a thin dark veil at ground level over deep earth far below,
## everything standing in the village fades to SURFACE_FADE, residents on the surface fade too, and
## residents in tunnels show at bore depth, inside each tunnel's lit trough (tunnel_overlay.gd).
## OFF: all of that is put back exactly. The village's meshes are listed once, on the first toggle.

const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const SURFACE_FADE: float = 0.82
const VEIL_SIZE_M: float = 400.0
const VEIL_COLOUR: Color = Color(0.08, 0.1, 0.08, 0.5)
const DEEP_EARTH_Y_M: float = -4.0
const DEEP_EARTH_COLOUR: Color = Color(0.13, 0.095, 0.07)
const GROUND_NODE: NodePath = ^"Ground"
const VILLAGE_NODE: NodePath = ^"Village"

var on: bool = false

var _world: Node3D = null
var _cast: DemoCastScript = null
var _overlay: OverlayScript = null
var _veil: MeshInstance3D = null
var _deep: MeshInstance3D = null
var _village: Array[GeometryInstance3D] = []
var _listed: bool = false


func configure(world: Node3D, cast: DemoCastScript, overlay: OverlayScript) -> void:
	"""Fade this world and cast, and show this overlay's troughs. `world` may be null (no world to
	fade, as in a scene without the demo village)."""
	name = "TunnelView"
	_world = world
	_cast = cast
	_overlay = overlay
	_veil = _plane(Vector3(0.0, 0.0, 0.0), VEIL_COLOUR, true)
	_deep = _plane(Vector3(0.0, DEEP_EARTH_Y_M, 0.0), DEEP_EARTH_COLOUR, false)


func set_world(world: Node3D) -> void:
	"""The world whose ground and village this view fades."""
	_world = world


func _plane(at: Vector3, colour: Color, see_through: bool) -> MeshInstance3D:
	"""A huge flat unshaded plane, hidden until the view is on."""
	var plane := PlaneMesh.new()
	plane.size = Vector2(VEIL_SIZE_M, VEIL_SIZE_M)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


func toggle() -> bool:
	"""Switch the view; returns whether it is now on."""
	set_on(not on)
	return on


func set_on(value: bool) -> void:
	"""Underground view on or off (see the header)."""
	on = value
	_veil.visible = on
	_deep.visible = on
	_fade_world()
	for i in _cast.actor_count():
		(_cast.actor(i) as DemoActorScript).set_underground_view(on)
	_overlay.set_underground_view(on)


func _fade_world() -> void:
	"""Hide the grass ground and fade everything in the village (or put them back)."""
	if _world == null:
		return
	var ground := _world.get_node_or_null(GROUND_NODE) as Node3D
	if ground != null:
		ground.visible = not on
	if not _listed:
		_listed = true
		var village := _world.get_node_or_null(VILLAGE_NODE)
		if village != null:
			for node in village.find_children("*", "GeometryInstance3D", true, false):
				_village.append(node as GeometryInstance3D)
	for geometry in _village:
		if is_instance_valid(geometry):
			geometry.transparency = SURFACE_FADE if on else 0.0
