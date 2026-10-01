extends Node3D
## THE GUIDE'S MARKER IN THE WORLD (decision 0481; GDD REQ-SET-165: "highlight one actionable element"): a brass ring on
## the ground round the current objective's target -- a resident, a bed, the cauldron, a bridge, a tunnel's mouth --
## and a brass point bobbing over it, so the card's "the brass marker" can be found from anywhere the camera looks.
## Presentation only, on the surface's marks layer (demo_layers.gd SURFACE_MARKS); it follows a moving target each
## frame through `point_of() -> Vector3` (INF: no target, hidden). It bobs on real time, so it is findable paused.

const Marks := preload("res://demo/control/demo_marks.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## The ring's radius by target size (a resident; a bed or a site), metres; the point's height and bob.
const RING_SMALL_M: float = 0.9
const RING_LARGE_M: float = 2.1
const POINT_HEIGHT_M: float = 2.6
const BOB_M: float = 0.18
const BOB_HZ: float = 0.8
const LIFT_M: float = 0.04
const ALPHA: float = 0.85

var _ring: MeshInstance3D = null
var _point: MeshInstance3D = null
var _point_of: Callable = Callable()
var _phase: float = 0.0


func _init() -> void:
	"""The ring and the point, hidden until aimed."""
	name = "GuideBeacon"
	_ring = Marks.make_ring(Palette.BRASS)
	_ring.layers = Layers.SURFACE_MARKS
	_ring.visible = true
	add_child(_ring)
	_point = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.28
	cone.bottom_radius = 0.0
	cone.height = 0.55
	cone.radial_segments = 12
	cone.rings = 1
	_point.mesh = cone
	_point.material_override = _ring.material_override
	_point.layers = Layers.SURFACE_MARKS
	_point.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_point)
	Marks.set_alpha(_ring, Palette.BRASS, ALPHA)
	visible = false


func aim(point_of: Callable, large: bool) -> void:
	"""Follow `point_of() -> Vector3` (INF: hidden); a large ring for a bed or a site, a small one for a resident."""
	_point_of = point_of
	var radius: float = RING_LARGE_M if large else RING_SMALL_M
	_ring.scale = Vector3(radius, 1.0, radius)
	_follow()


func clear() -> void:
	"""No target: hidden."""
	_point_of = Callable()
	visible = false


func _process(delta: float) -> void:
	"""Follow the target and bob the point."""
	_phase = fmod(_phase + delta * BOB_HZ, 1.0)
	_follow()


func _follow() -> void:
	"""Stand on the target now (hidden without one)."""
	var at: Vector3 = _point_of.call() as Vector3 if _point_of.is_valid() else Vector3.INF
	if at == Vector3.INF or not at.is_finite():
		visible = false
		return
	visible = true
	_ring.position = Vector3(at.x, LIFT_M, at.z)
	_point.position = Vector3(at.x, POINT_HEIGHT_M + BOB_M * sin(_phase * TAU), at.z)


func target_point() -> Vector3:
	"""Where the marker stands (INF hidden; checks)."""
	return _ring.position if visible else Vector3.INF
