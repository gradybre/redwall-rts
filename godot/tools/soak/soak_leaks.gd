extends RefCounted
## THE SOAK TEST'S RESTART LEAK WATCH (decision 0921). "Restart demo" frees the village scene and builds a new one
## (demo_village.gd `restart`: `reload_current_scene`). Anything the old village made that is still alive afterwards
## has leaked -- a RefCounted reference cycle is never freed, and a node held outside the tree is an orphan.
##
## WATCH, just before the restart: walk everything reachable from the old village -- its nodes, their script members,
## and those members' own script members, through Arrays, Dictionaries and the objects and bound arguments of Callables
## -- and keep a WEAK reference to each object found (never a strong one: the watch must not keep anything alive). Nodes
## outside the village (autoloads, the HUD's shell), Resources (scripts, meshes, textures: shared with the resource
## cache by design), the main loop and the harness's own nodes are not watched or walked. What a lambda captures is
## not visible to a script, so an object reachable only through a captured variable is neither watched nor counted as
## reachable.
##
## CHECK, once the new village is open (the weak references are let go after it): every watched object still alive is
## a SURVIVOR, labelled by its script's file name (or its class) and sorted into two kinds:
##   * `unreachable` -- nothing alive in the tree reaches it: garbage that will never be freed (a reference cycle, or an
##     orphaned node). Every one is a leak.
##   * `held` -- something alive in the tree (an autoload, the new village), or a script's static member (a cache shared
##     by design), still reaches it: shared state handed to the village, or a leak through a live owner. Judged by
##     whether it grows restart after restart.

## A walk stops past this many objects (a guard; the nine-resident village holds about 14 000 objects in all).
const MAX_OBJECTS: int = 250000
## Scripts under this path are the measuring harness's (the driver, its end mark, the soak's own): never walked.
const HARNESS_PATH: String = "res://tools/"
## Arrays and Dictionaries nested deeper than this are not walked.
const MAX_DEPTH: int = 4

var watched: int = 0
var _refs: Array[WeakRef] = []
var _labels: PackedStringArray = PackedStringArray()
## Every script of a watched object (Scripts are Resources the cache keeps anyway: holding them keeps nothing of the
## village alive). Their static members are walked at the check, so an object a script's static cache holds is held
## even when no instance of that script is left alive (the village freed at the end, with no new one).
var _scripts: Array[Script] = []


func watch(scene: Node) -> int:
	"""Watch everything reachable from `scene` (see WATCH); returns how many objects are watched."""
	release()
	var found: Array[Object] = []
	_walk([scene], scene, found, null)
	var seen: Dictionary = {}
	for object: Object in found:
		_refs.append(weakref(object))
		_labels.append(label_of(object))
		var script: Script = object.get_script() as Script
		if script != null and not seen.has(script.get_instance_id()):
			seen[script.get_instance_id()] = true
			_scripts.append(script)
	watched = found.size()
	found.clear()
	return watched


func check(live_root: Node) -> Dictionary:
	"""The survivors (see CHECK): {watched, survivors, unreachable, held, unreachable_by_label, held_by_label}."""
	var alive: Array[Object] = []
	var alive_labels: PackedStringArray = PackedStringArray()
	for k: int in _refs.size():
		var object: Object = _refs[k].get_ref()
		if object != null:
			alive.append(object)
			alive_labels.append(_labels[k])
	var reachable: Dictionary = reach_of(live_root, alive)
	var out: Dictionary = {"watched": watched, "survivors": alive.size(), "unreachable": 0, "held": 0,
		"unreachable_by_label": {}, "held_by_label": {}}
	for k: int in alive.size():
		var kind: String = "held" if reachable.has(alive[k].get_instance_id()) else "unreachable"
		out[kind] = int(out[kind]) + 1
		var by_label: Dictionary = out[kind + "_by_label"]
		by_label[alive_labels[k]] = int(by_label.get(alive_labels[k], 0)) + 1
	alive.clear()
	release()
	return out


func release() -> void:
	"""Let the weak references go (each is an engine object: thousands of them would read as the village's growth)."""
	_refs.clear()
	_labels.clear()
	_scripts.clear()


func reach_of(root: Node, also_scripts_of: Array[Object] = []) -> Dictionary:
	"""Every object id reachable from `root`'s whole tree -- nodes, their script members, walked as in WATCH -- and from
	the STATIC members of every script met on the way and of the scripts of `also_scripts_of` (a script's own cache,
	such as forest_root_field.gd's baked fields, is held, not leaked)."""
	var start: Array = [root]
	var scripts: Dictionary = {}
	for object: Object in also_scripts_of:
		_push_statics(object, start, scripts)
	for script: Script in _scripts:
		_push_script_statics(script, start, scripts)
	var found: Array[Object] = []
	_walk(start, root, found, scripts)
	var ids: Dictionary = {}
	for object: Object in found:
		ids[object.get_instance_id()] = true
	found.clear()
	return ids


func _walk(start: Array, scene: Node, found: Array[Object], scripts: Variant) -> void:
	"""Every object reachable from `start` into `found` (each once): nodes under `scene` or outside any tree, and
	non-Resource objects (see WATCH). With a `scripts` Dictionary, the static members of each script met are walked too
	(each script once)."""
	var seen: Dictionary = {}
	var stack: Array = start.duplicate()
	while not stack.is_empty() and found.size() < MAX_OBJECTS:
		var object: Object = stack.pop_back()
		if object == null or not is_instance_valid(object) or seen.has(object.get_instance_id()):
			continue
		seen[object.get_instance_id()] = true
		if not _walkable(object, scene):
			continue
		found.append(object)
		if object is Node:
			for child: Node in (object as Node).get_children(true):
				stack.append(child)
		_push_members(object, stack)
		if scripts is Dictionary:
			_push_statics(object, stack, scripts)


static func _push_statics(object: Object, stack: Array, scripts: Dictionary) -> void:
	"""Push what the static members of `object`'s script (and the scripts it extends) hold, once per script."""
	_push_script_statics(object.get_script() as Script, stack, scripts)


static func _push_script_statics(from: Script, stack: Array, scripts: Dictionary) -> void:
	"""Push what the static members of `from` (and the scripts it extends) hold, once per script."""
	var script: Script = from
	while script != null and not scripts.has(script.get_instance_id()):
		scripts[script.get_instance_id()] = true
		for property: Dictionary in script.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_push_value(script.get(property["name"]), stack, 0)
		script = script.get_base_script()


static func _walkable(object: Object, scene: Node) -> bool:
	"""Whether `object` is watched and walked: not a Resource, not the main loop or anything else of the harness (a
	Callable on the SceneTree reaches the main loop; the per-system driver's list holds every script node it took over,
	so walking it would count an orphaned node of the old village as held); a node only under `scene` or outside any
	tree."""
	if object is Resource or object is MainLoop:
		return false
	var script: Script = object.get_script() as Script
	if script != null and script.resource_path.begins_with(HARNESS_PATH):
		return false
	if object is Node:
		var node: Node = object
		return node == scene or not node.is_inside_tree() or scene.is_ancestor_of(node)
	return true


static func _push_members(object: Object, stack: Array) -> void:
	"""Push every object `object`'s script members hold."""
	if object.get_script() == null:
		return
	for property: Dictionary in object.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_push_value(object.get(property["name"]), stack, 0)


static func _push_value(value: Variant, stack: Array, depth: int) -> void:
	"""Push the objects `value` holds: itself, an Array's or a Dictionary's items, a Callable's object and bindings."""
	match typeof(value):
		TYPE_OBJECT:
			if value != null:
				stack.append(value)
		TYPE_ARRAY:
			if depth < MAX_DEPTH:
				for item: Variant in value:
					_push_value(item, stack, depth + 1)
		TYPE_DICTIONARY:
			if depth < MAX_DEPTH:
				for key: Variant in value:
					_push_value(key, stack, depth + 1)
					_push_value(value[key], stack, depth + 1)
		TYPE_CALLABLE:
			_push_callable(value, stack, depth)


static func _push_callable(callable: Callable, stack: Array, depth: int) -> void:
	"""A Callable's object (a lambda's self) and its bound arguments."""
	if callable.is_null():
		return
	var object: Object = callable.get_object()
	if object != null:
		stack.append(object)
	if depth < MAX_DEPTH:
		for item: Variant in callable.get_bound_arguments():
			_push_value(item, stack, depth + 1)


static func label_of(object: Object) -> String:
	"""A survivor's label: its script's file name, else its class (nodes say so)."""
	var script: Script = object.get_script() as Script
	var name: String = script.resource_path.get_file() if script != null and not script.resource_path.is_empty() \
		else object.get_class()
	return ("node " + name) if object is Node else name
