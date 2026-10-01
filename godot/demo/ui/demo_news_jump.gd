extends RefCounted
## "Go to": the village news's jump to what a notice or an incident is about. Decision 0331 (review F11).
## DEMO UI: it selects and centres, it changes nothing in the village.
##
## A target is a KIND (demo_notices.gd TARGET_*: a bed, a tree, a tunnel, a resident or a bridge) and an
## ID (the bed's index, the tree's row, the tunnel's segment slot, the resident's actor index, the
## bridge's row). Each kind is REGISTERED by the village (demo_village.gd `_build_news`) with two
## callables: `locate(id) -> Vector3`, where it is on the ground now (Vector3.INF: it is gone -- a tunnel
## filled in, a tree cleared), and `select(id)`, which selects it the way a click on it would and brings
## its panel forward. A jump selects, then eases the camera over the point (demo_camera.gd `centre_on`).
## The static `*_point` helpers are the village's locate callables' arithmetic, testable on their own.

const NoticesScript := preload("res://demo/demo_notices.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")

## Where the last jump went (checks).
var last_point: Vector3 = Vector3.INF
## How many jumps were made (checks).
var jumps: int = 0

var _camera: CameraScript = null
var _locate: Array[Callable] = []
var _select: Array[Callable] = []


func _init() -> void:
	"""One empty slot per TARGET_* kind."""
	_locate.resize(NoticesScript.TARGET_NAMES.size())
	_select.resize(NoticesScript.TARGET_NAMES.size())


func bind_camera(camera: CameraScript) -> void:
	"""Centre this camera rig on each jump (none: select only)."""
	_camera = camera


func register(kind: int, where: Callable, pick: Callable) -> void:
	"""How to find (`where(id) -> Vector3`) and select (`pick(id)`) targets of `kind` (see the header).
	TARGET_NONE cannot be registered."""
	if kind <= NoticesScript.TARGET_NONE or kind >= _locate.size():
		return
	_locate[kind] = where
	_select[kind] = pick


func locate(kind: int, id: int) -> Vector3:
	"""Where target (`kind`, `id`) is now (Vector3.INF: unknown kind, unregistered, or gone)."""
	if kind <= NoticesScript.TARGET_NONE or kind >= _locate.size() or id < 0 or not _locate[kind].is_valid():
		return Vector3.INF
	return _locate[kind].call(id) as Vector3


func can_jump(kind: int, id: int) -> bool:
	"""Whether a "Go to" would find target (`kind`, `id`)."""
	return locate(kind, id).is_finite()


func jump(kind: int, id: int) -> bool:
	"""Select target (`kind`, `id`) and centre the camera over it. False (nothing done) when it cannot be found."""
	var point: Vector3 = locate(kind, id)
	if not point.is_finite():
		return false
	if _select[kind].is_valid():
		_select[kind].call(id)
	if _camera != null:
		_camera.centre_on(point)
	last_point = point
	jumps += 1
	return true


static func bed_point(bed: int) -> Vector3:
	"""A bed's centre on the ground (INF: no such bed)."""
	if bed < 0 or bed >= Catalog.BED_COUNT:
		return Vector3.INF
	var at: Vector2 = Catalog.bed_centre_m(bed)
	return Vector3(at.x, 0.0, at.y)


static func tunnel_point(network: GraphScript, slot: int) -> Vector3:
	"""The middle of a tunnel segment between its two ends, on the ground (INF: no such segment)."""
	if network == null or slot < 0 or slot >= network.generation.size() or not network.is_ref(slot, network.generation[slot]):
		return Vector3.INF
	var mid: Vector2 = (network.end_at(slot, false) + network.end_at(slot, true)) * 0.5
	return Vector3(mid.x, 0.0, mid.y)


static func bridge_point(bridges: BridgesScript, row: int) -> Vector3:
	"""The middle of a bridge's span (INF: no such bridge)."""
	if bridges == null or row < 0 or row >= BridgesScript.MAX_BRIDGES or bridges.phase[row] == BridgesScript.PHASE_FREE:
		return Vector3.INF
	var mid: Vector2 = (bridges.approach(row, false) + bridges.approach(row, true)) * 0.5
	return Vector3(mid.x, 0.0, mid.y)


static func tree_point(stand: StandScript, t: int) -> Vector3:
	"""Where a tree stands (or stood: a blown-down one's spot), on the ground (INF: no such tree)."""
	if stand == null or t < 0 or t >= stand.count():
		return Vector3.INF
	return Vector3(stand.at[t].x, 0.0, stand.at[t].y)
