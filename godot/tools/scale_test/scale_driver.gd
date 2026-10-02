extends Node
## THE SCALE TEST'S PER-SYSTEM TIMER (decision 0561). It times every scripted node's `_process` without touching their
## code: once the village is open it takes over each processing script node in the tree -- turns its processing off
## and calls its `_process` itself, in the engine's own order (process priority, then tree order), timing each call.
## A node added later is taken over on the next frame. Nothing in the game is changed but who calls `_process`, and
## the order among the script nodes is the engine's; only engine nodes (AnimationPlayer, skeletons) now run after
## every script rather than between them, which shifts nothing by more than a frame.
##
## Each call's time is booked to a SYSTEM, named from the script's path (`system_of`), and to the script itself.
## Per frame the driver keeps one sample per system in `frame_usec` (cleared by `begin_frame`). The engine's own
## monitors (process, physics, render) are read by the harness.
##
## Only the demo's process modes are honoured (`can_process`): a node that would not process while the tree is paused
## is not called.

## The systems, in report order. A script's path picks one by its first matching prefix (SYSTEM_RULES).
const SYSTEM_RULES: Array = [
	["res://demo/cast/", &"cast"],
	["res://scripts/systems/game_manager.gd", &"settlement_clock"],
	["res://scripts/systems/", &"settlement_systems"],
	["res://demo/work/work_screen.gd", &"ui"],
	["res://demo/work/", &"work_board"],
	["res://demo/kitchen/kitchen_view.gd", &"overlays"],
	["res://demo/kitchen/", &"kitchen"],
	["res://demo/people/people_card.gd", &"ui"],
	["res://demo/people/", &"people"],
	["res://demo/songs/", &"songs"],
	["res://demo/sound/", &"sound"],
	["res://demo/routes/route_overlay.gd", &"overlays"],
	["res://demo/routes/", &"route_previews"],
	["res://demo/water/water_overlay.gd", &"overlays"],
	["res://demo/tunnel/tunnel_overlay.gd", &"overlays"],
	["res://demo/tunnel/tunnel_lanterns.gd", &"overlays"],
	["res://demo/farm/farm_view.gd", &"overlays"],
	["res://demo/farm/farm_planner.gd", &"ui"],
	["res://demo/tunnel/tunnel_control.gd", &"ui"],
	["res://demo/tunnel/", &"tunnels_and_night"],
	["res://demo/events/", &"tunnels_and_night"],
	["res://demo/farm/", &"farm"],
	["res://demo/forestry/", &"woods"],
	["res://demo/waterplay/swim_view.gd", &"overlays"],
	["res://demo/waterplay/", &"waterplay"],
	["res://demo/fishery/", &"fishery"],
	["res://demo/water/", &"water"],
	["res://demo/weather/", &"weather"],
	["res://demo/camera/", &"camera"],
	["res://demo/ui/", &"ui"],
	["res://demo/control/", &"ui"],
	["res://demo/access/", &"ui"],
	["res://demo/guide/", &"ui"],
	["res://demo/session/", &"ui"],
	["res://scripts/ui/", &"ui"],
	["res://scripts/presentation/", &"presentation"],
	["res://demo/", &"demo_other"],
]
const OTHER: StringName = &"other"
const EndMark := preload("res://tools/scale_test/scale_end_mark.gd")

## Per frame: microseconds per system (by its index in `systems`). Per node, the whole run's sum (`script_totals`).
var frame_usec: PackedInt64Array = PackedInt64Array()
var systems: Array[StringName] = []
## Whether the driver has taken over (the harness turns it on once the village is open).
var active: bool = false
## Called first thing every frame with the frame's delta (the harness books the frame before here).
var on_frame: Callable = Callable()
## When this frame's processing began (the driver runs first) and when the frame before's ended (`_end`, a node that
## runs last), real microseconds.
var frame_start_usec: int = 0
var process_end_usec: int = 0

var _end: Node = Node.new()

var _system_index: Dictionary = {}
var _nodes: Array[Node] = []
var _node_system: PackedInt32Array = PackedInt32Array()
var _node_path: PackedStringArray = PackedStringArray()
var _node_usec: PackedInt64Array = PackedInt64Array()
var _pending: Array[Node] = []
var _dirty: bool = false


func _init() -> void:
	"""Run first in the frame, whatever the game pauses."""
	process_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_end.name = "ScaleDriverEnd"
	_end.process_priority = 100000
	_end.process_mode = Node.PROCESS_MODE_ALWAYS
	_end.set_script(EndMark)
	for rule: Array in SYSTEM_RULES:
		_system(rule[1] as StringName)
	_system(OTHER)


func _ready() -> void:
	"""The end mark beside the driver: it runs last in every frame's processing (the tree frees it at exit)."""
	_end.set(&"driver", self)
	get_parent().add_child.call_deferred(_end)


func _system(system: StringName) -> int:
	"""The column of `system`, made on first use."""
	var at: int = _system_index.get(system, -1)
	if at < 0:
		at = systems.size()
		_system_index[system] = at
		systems.append(system)
		frame_usec.append(0)
	return at


static func system_of(path: String) -> StringName:
	"""The system a script at `path` is booked to (SYSTEM_RULES; OTHER when none matches)."""
	for rule: Array in SYSTEM_RULES:
		if path.begins_with(String(rule[0])):
			return rule[1] as StringName
	return OTHER


func take_over(root: Node) -> void:
	"""Take over every processing script node under `root`, and watch for new ones."""
	active = true
	_collect(root)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	_dirty = true


func _collect(at: Node) -> void:
	"""Take over `at` and its subtree."""
	_take(at)
	for child: Node in at.get_children():
		_collect(child)


func _take(node: Node) -> void:
	"""Take over one node when it is a processing script node (not this driver)."""
	if node == self or node == _end or node.get_script() == null or not node.is_processing():
		return
	var path: String = (node.get_script() as Script).resource_path
	node.set_process(false)
	_nodes.append(node)
	_node_system.append(_system(system_of(path)))
	_node_path.append(path)
	_node_usec.append(0)
	_dirty = true


func _on_node_added(node: Node) -> void:
	"""A node joined the tree: look at it next frame, once it is ready."""
	_pending.append(node)


func begin_frame() -> void:
	"""Clear this frame's columns (the per-script sums run on)."""
	frame_usec.fill(0)


func _process(delta: float) -> void:
	"""Call every taken-over node's `_process`, in the engine's order, timing each."""
	frame_start_usec = Time.get_ticks_usec()
	if on_frame.is_valid():
		on_frame.call(delta)
	if not active:
		return
	_take_pending()
	if _dirty:
		_sort()
	for k: int in _nodes.size():
		if not is_instance_valid(_nodes[k]):
			_dirty = true
			continue
		var node: Node = _nodes[k]
		if not node.is_inside_tree() or not node.can_process():
			continue
		var before: int = Time.get_ticks_usec()
		node.call(&"_process", delta)
		var spent: int = Time.get_ticks_usec() - before
		frame_usec[_node_system[k]] += spent
		_node_usec[k] += spent


func _take_pending() -> void:
	"""Take over the nodes added since last frame that are processing scripts."""
	for k: int in _pending.size():
		if is_instance_valid(_pending[k]) and _pending[k].is_inside_tree() and not _nodes.has(_pending[k]):
			_take(_pending[k])
	_pending.clear()


func _sort() -> void:
	"""Order the nodes as the engine would: process priority, then tree order. Freed nodes are dropped."""
	var order: Array[int] = []
	for k: int in _nodes.size():
		if is_instance_valid(_nodes[k]):
			order.append(k)
	order.sort_custom(_before)
	var nodes: Array[Node] = []
	var node_system := PackedInt32Array()
	var node_path := PackedStringArray()
	var node_usec := PackedInt64Array()
	for k: int in order:
		nodes.append(_nodes[k])
		node_system.append(_node_system[k])
		node_path.append(_node_path[k])
		node_usec.append(_node_usec[k])
	_nodes = nodes
	_node_system = node_system
	_node_path = node_path
	_node_usec = node_usec
	_dirty = false


func _before(a: int, b: int) -> bool:
	"""Whether node `a` processes before node `b` (priority, then tree order)."""
	var na: Node = _nodes[a]
	var nb: Node = _nodes[b]
	if na.process_priority != nb.process_priority:
		return na.process_priority < nb.process_priority
	if not na.is_inside_tree() or not nb.is_inside_tree():
		return na.is_inside_tree()
	return nb.is_greater_than(na)


func script_totals() -> Dictionary:
	"""Each script path's whole-run microseconds (its nodes summed; a node freed before the last sort is dropped)."""
	var out: Dictionary = {}
	for k: int in _node_path.size():
		out[_node_path[k]] = int(out.get(_node_path[k], 0)) + _node_usec[k]
	return out


func managed_count() -> int:
	"""How many nodes the driver calls."""
	return _nodes.size()
