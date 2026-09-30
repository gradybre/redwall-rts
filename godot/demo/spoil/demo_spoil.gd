extends Node3D
## Spoil heaps you can select and clear. Decision 0205 (the playtest of 2026-09-29). DEMO: presentation
## over the farm's spoil books (spoil_crew.gd says where the spoil goes and why).
##
##   Left click a heap          select it: a brass ring round it, and the party panel's notice says how
##                              much spoil it holds and how to clear it (the selection is kept)
##   Right click a heap         with residents selected: they dig it out and haul it away (Clear)
##   C                          with a heap selected and residents selected: the same
##
## Its ground handlers are asked after the farm's and before the woods' (a heap may stand inside a
## forestry zone), so a click on a heap is the heap's.

const CrewScript := preload("res://demo/spoil/spoil_crew.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")

## A click this far beyond a heap's drawn rim still picks it (metres; demo value).
const PICK_SLACK_M: float = 0.3
## The ring stands this far outside the drawn heap.
const RING_GAP_M: float = 0.15
const NOTHING: int = -1
const DROP_POI: StringName = &"stockpile"
const SELECTED_TEXT: String = "Spoil heap: %.1f U of spoil. Right-click it (or C) with residents selected to dig it out and haul it to the compost"
const EMPTY_TEXT: String = "Spoil heap: cleared"
const CLEARING_TEXT: String = "Clearing a spoil heap"
const HAULING_TEXT: String = "Hauling spoil to the compost"

var crew: CrewScript = CrewScript.new()
## The selected heap (2 x tunnel slot + end), or NOTHING.
var selected_heap: int = NOTHING

var _cast: DemoCastScript = null
var _command: DemoCommandScript = null
var _camera: Camera3D = null
var _network: NetworkScript = null
var _tunnels: FarmTunnels = null
var _ring: MeshInstance3D = null


func configure(cast: DemoCastScript, command: DemoCommandScript, camera: Camera3D, network: NetworkScript,
		tunnels: FarmTunnels, props: PropsScript, deliver: Callable) -> void:
	"""Clear heaps with this cast, through the command layer's ground handlers; spoil goes by `deliver`."""
	name = "DemoSpoil"
	_cast = cast
	_command = command
	_camera = camera
	_network = network
	_tunnels = tunnels
	crew.configure(cast, network, tunnels, props, deliver, drop_point(cast))
	_ring = MarksScript.make_ring(MarksScript.SELECTED)
	_ring.visible = false
	add_child(_ring)
	command.add_ground_handlers(on_ground_click, on_ground_order)
	command.add_input_hook(on_input)
	command.add_task_text(task_text)


static func drop_point(cast: DemoCastScript) -> Vector2:
	"""Where cleared spoil is tipped: by the open stockpile (the village's bulk store), else the middle."""
	var space := cast.space()
	var poi: int = space.poi_names.find(DROP_POI)
	return space.poi_position[poi] if poi >= 0 else Vector2.ZERO


func task_text(actor_index: int) -> String:
	"""What a resident clearing a heap is doing, for the party panel ("" for one not clearing)."""
	var row: int = crew.row_of(actor_index)
	if row < 0:
		return ""
	return HAULING_TEXT if crew.step[row] >= CrewScript.STEP_CARRY else CLEARING_TEXT


func heap_at_point(at: Vector2) -> int:
	"""The heap with spoil on it under ground point `at` (x z metres), nearest first, or NOTHING."""
	var best: int = NOTHING
	var best_d: float = INF
	for h: int in FarmTunnels.HEAPS:
		var left: int = crew.spoil_left(h)
		if left <= 0:
			continue
		var d: float = _network.heap_at[h].distance_to(at)
		if d <= drawn_radius_m(left) + PICK_SLACK_M and d < best_d:
			best_d = d
			best = h
	return best


static func drawn_radius_m(spoil_milli: int) -> float:
	"""How wide a heap of this much spoil is drawn (tunnel_overlay.gd heap_radius_m)."""
	return OverlayScript.heap_radius_m(spoil_milli)


func _ground_at(screen: Vector2) -> Vector2:
	"""Where a screen point meets the ground plane (x z metres); INF when it does not."""
	if _camera == null:
		return Vector2.INF
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var normal: Vector3 = _camera.project_ray_normal(screen)
	if absf(normal.y) < 1e-5:
		return Vector2.INF
	var t: float = -origin.y / normal.y
	if t <= 0.0:
		return Vector2.INF
	var hit: Vector3 = origin + normal * t
	return Vector2(hit.x, hit.z)


func on_ground_click(screen: Vector2) -> bool:
	"""A left click on no resident: on a heap, select it (the selection is kept); elsewhere let go of it."""
	var h: int = heap_at_point(_ground_at(screen))
	select(h)
	return h != NOTHING


func on_ground_order(screen: Vector2) -> bool:
	"""A right click with residents selected: on a heap, clear it with them."""
	var h: int = heap_at_point(_ground_at(screen))
	if h == NOTHING:
		return false
	select(h)
	clear_selected()
	return true


func on_input(event: InputEvent) -> bool:
	"""C with a heap and residents selected: clear it."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_C or selected_heap == NOTHING:
		return false
	if _command.selection_count() == 0:
		return false
	clear_selected()
	return true


func select(h: int) -> void:
	"""Select heap `h` (NOTHING lets go): its ring, and its words in the party panel's notice."""
	selected_heap = h
	_ring.visible = h != NOTHING
	if h == NOTHING:
		return
	var r: float = drawn_radius_m(crew.spoil_left(h)) + RING_GAP_M
	_ring.position = Vector3(_network.heap_at[h].x, MarksScript.LIFT_M, _network.heap_at[h].y)
	_ring.scale = Vector3(r, 1.0, r)
	_command.say(SELECTED_TEXT % (crew.spoil_left(h) / 1000.0))


func clear_selected() -> String:
	"""Clear the selected heap with the selected residents; the answer goes to the party panel."""
	var said: String = crew.order(selected_heap, _command.selected())
	var at: Vector2 = _network.heap_at[selected_heap]
	_command.mark(Vector3(at.x, 0.0, at.y), not said.begins_with("Can't"))
	_command.say(said)
	return said


func _process(_delta: float) -> void:
	"""Work the heaps on the demo clock; let go of a heap once it is empty."""
	crew.update(_cast.clock.frame_usec)
	if selected_heap != NOTHING and crew.spoil_left(selected_heap) <= 0:
		select(NOTHING)
		_command.say(EMPTY_TEXT)
