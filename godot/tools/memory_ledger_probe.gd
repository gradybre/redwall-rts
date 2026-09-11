extends RefCounted
## Measures the bytes every settlement store actually allocates, so
## `systems_architecture.md` §2.3's ARCH-MEM-010 ledger can be checked against code.
##
## WHAT THIS MEASURES. For every live store instance reachable from an explicitly wired
## world, this reflects over the script's own member variables and, for each packed column,
## reads the array's own `size()`. Payload bytes are `size() * bytes_per_element`, where
## `bytes_per_element` is not a constant taken on trust: `calibrate_element_bytes()`
## allocates a large array of each packed type and divides the process's own
## `OS.get_static_memory_usage()` delta by the element count. The ledger's "a
## PackedInt32Array of N is 4N" model is therefore itself a measured claim here.
##
## ALLOCATED, NOT RESIDENT. What this reports is the payload a store asked its packed
## arrays to hold. It is NOT resident set size and NOT the allocator's total: Godot's
## CowData puts a reference count and a size field ahead of every buffer, the allocator
## rounds, and the OS maps pages lazily. ARCH-MEM-010's rows are allocation arithmetic of
## exactly the same kind, which is what makes the comparison meaningful; the separate
## 8388608-byte "allocator/object reserve" row is what the ledger sets aside for the
## difference. `static_memory_delta` on the report is the closest process-level figure
## available and is reported alongside, never folded into a row.
##
## WHY A TRANSITIVE WALK AND NOT A LIST. Most stores build a private collaborator when
## passed `null` (`jobs.gd` builds its own Residents, `ecology.gd` its own directory). A
## hand-written list of `new()` calls would therefore silently measure four EntityDirectory
## instances of 9162868 bytes each and call the total a world. The walk starts from one
## explicitly wired composition and dedupes by `Object.get_instance_id()`, so a duplicate
## instance shows up as a duplicate instead of quietly inflating a row.
##
## This file allocates freely and reads nothing back into a store. It is diagnostic; no
## simulation state depends on it.

const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const WorkScript := preload("res://scripts/core/work.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const EcologyScript := preload("res://scripts/core/ecology.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const NavigationScript := preload("res://scripts/core/navigation.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")
const MovementScript := preload("res://scripts/core/movement.gd")
const GearScript := preload("res://scripts/core/gear.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const FieldPolicyScript := preload("res://scripts/core/field_policy.gd")
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const ResourceCatalogBindingScript := preload("res://scripts/core/resource_catalog_binding.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")

## Elements used by the calibration allocation. Large enough that CowData's fixed header
## and any allocator rounding are below one part in a million of the measured delta.
const CALIBRATION_ELEMENTS: int = 1 << 21

## The packed Variant types this probe accounts for, and the bytes per element the ledger's
## own arithmetic assumes for each. `calibrate_element_bytes()` checks these against the
## running engine rather than asserting them.
const DECLARED_ELEMENT_BYTES: Dictionary = {
	TYPE_PACKED_BYTE_ARRAY: 1,
	TYPE_PACKED_INT32_ARRAY: 4,
	TYPE_PACKED_INT64_ARRAY: 8,
	TYPE_PACKED_FLOAT32_ARRAY: 4,
	TYPE_PACKED_FLOAT64_ARRAY: 8,
	TYPE_PACKED_VECTOR2_ARRAY: 8,
	TYPE_PACKED_VECTOR3_ARRAY: 12,
	TYPE_PACKED_COLOR_ARRAY: 16,
}

## Human-readable names for the packed types above, for report rows.
const TYPE_NAMES: Dictionary = {
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray",
}

## Scripts that `settlement_system.gd` itself composes into the running autoload world.
## Anything measured outside this set is allocated by the ledger's arithmetic but is not
## resident in the shipped process today.
const COMPOSED_SCRIPTS: Array[String] = [
	"res://scripts/core/entity_directory.gd", "res://scripts/core/needs.gd",
	"res://scripts/core/residents.gd", "res://scripts/core/priorities.gd",
	"res://scripts/core/schedule.gd", "res://scripts/core/jobs.gd",
	"res://scripts/core/work.gd", "res://scripts/core/reservations.gd",
	"res://scripts/core/sim_clock.gd", "res://scripts/core/commands.gd",
	"res://scripts/core/command_dispatch.gd", "res://scripts/core/ecology.gd",
	"res://scripts/core/resource_nodes.gd", "res://scripts/core/forage.gd",
	"res://scripts/core/fishing.gd", "res://scripts/core/orchard_hive.gd",
	"res://scripts/core/rng.gd", "res://scripts/core/crop_weather.gd",
	"res://scripts/core/farming.gd", "res://scripts/core/weather.gd",
	"res://scripts/core/job_planner.gd", "res://scripts/core/presentation_extract.gd",
]


func calibrate_element_bytes() -> Array[Dictionary]:
	"""Measure bytes per element for each packed type from the process's own static memory."""
	var measured: Array[Dictionary] = []
	for type_id: int in DECLARED_ELEMENT_BYTES:
		measured.append(_calibrate_one(type_id))
	return measured


func _calibrate_one(type_id: int) -> Dictionary:
	"""Allocate CALIBRATION_ELEMENTS of one packed type and divide the static-memory delta.

	Refuses rather than reporting a figure when the allocator gives no observable delta:
	a zero would read as "this type costs nothing", which is the opposite of unknown.
	"""
	var before: int = OS.get_static_memory_usage()
	var holder: Variant = _make_packed(type_id)
	holder.resize(CALIBRATION_ELEMENTS)
	var delta: int = OS.get_static_memory_usage() - before
	holder = null
	var row: Dictionary = {
		"type": String(TYPE_NAMES[type_id]), "type_id": type_id, "delta_bytes": delta,
		"elements": CALIBRATION_ELEMENTS, "declared": int(DECLARED_ELEMENT_BYTES[type_id]),
	}
	row["measured"] = delta >= CALIBRATION_ELEMENTS
	row["bytes_per_element"] = delta / CALIBRATION_ELEMENTS if row["measured"] else 0
	return row


func _make_packed(type_id: int) -> Variant:
	"""Return an empty packed array of the requested type."""
	match type_id:
		TYPE_PACKED_BYTE_ARRAY: return PackedByteArray()
		TYPE_PACKED_INT32_ARRAY: return PackedInt32Array()
		TYPE_PACKED_INT64_ARRAY: return PackedInt64Array()
		TYPE_PACKED_FLOAT32_ARRAY: return PackedFloat32Array()
		TYPE_PACKED_FLOAT64_ARRAY: return PackedFloat64Array()
		TYPE_PACKED_VECTOR2_ARRAY: return PackedVector2Array()
		TYPE_PACKED_VECTOR3_ARRAY: return PackedVector3Array()
		TYPE_PACKED_COLOR_ARRAY: return PackedColorArray()
	push_error("memory_ledger_probe: no constructor for packed Variant type %d" % type_id)
	return PackedByteArray()


func element_bytes(type_id: int) -> int:
	"""Bytes per element the ledger's arithmetic assumes for a packed type; 0 if not packed."""
	if DECLARED_ELEMENT_BYTES.has(type_id):
		return int(DECLARED_ELEMENT_BYTES[type_id])
	return 0


func calibrate_string_array_element_bytes() -> Dictionary:
	"""Measure bytes per element of an empty-string `PackedStringArray` from static memory.

	§2.3 has no byte model for this type at all -- `state_registry_coverage.py` writes its
	width as "var" -- so the slot cost is measured here and the characters are counted
	separately. This is the floor: an element holding real text costs this plus that
	String's own buffer.
	"""
	var slots: PackedStringArray = PackedStringArray()
	var before: int = OS.get_static_memory_usage()
	slots.resize(CALIBRATION_ELEMENTS)
	var delta: int = OS.get_static_memory_usage() - before
	slots.clear()
	var ok: bool = delta >= CALIBRATION_ELEMENTS
	return {
		"elements": CALIBRATION_ELEMENTS, "delta_bytes": delta, "measured": ok,
		"bytes_per_empty_element": delta / CALIBRATION_ELEMENTS if ok else 0,
	}


func measure_instance(subject: Object) -> Dictionary:
	"""Reflect over one store's script variables and total its packed-column payload bytes."""
	var columns: Array[Dictionary] = []
	var containers: Array[Dictionary] = []
	var strings: Array[Dictionary] = []
	var total: int = 0
	for property: Dictionary in subject.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = String(property["name"])
		var value: Variant = subject.get(name)
		var bytes: int = _column_bytes(value)
		if bytes >= 0:
			columns.append(_column_row(name, value, bytes))
			total += bytes
		elif value is PackedStringArray:
			strings.append(_string_row(name, value as PackedStringArray))
		elif value is Array or value is Dictionary:
			containers.append(_container_row(name, value))
	return {
		"script": _script_path(subject), "instance_id": subject.get_instance_id(),
		"columns": columns, "containers": containers, "string_columns": strings,
		"packed_bytes": total,
	}


func _string_row(name: String, value: PackedStringArray) -> Dictionary:
	"""Report a PackedStringArray by slot count and current UTF-8 content, never as bytes.

	Its payload has no fixed element width, so folding it into `packed_bytes` would put a
	number the ledger cannot check into a total the ledger is checked against.
	"""
	var content: int = 0
	for text: String in value:
		content += text.to_utf8_buffer().size()
	return {"name": name, "length": value.size(), "utf8_content_bytes": content}


func _column_bytes(value: Variant) -> int:
	"""Payload bytes of a packed column from its own size(); -1 when the value is not packed."""
	var type_id: int = typeof(value)
	if not DECLARED_ELEMENT_BYTES.has(type_id):
		return -1
	return int(value.size()) * int(DECLARED_ELEMENT_BYTES[type_id])


func _column_row(name: String, value: Variant, bytes: int) -> Dictionary:
	"""Build one reported column row from a measured packed array."""
	var type_id: int = typeof(value)
	return {
		"name": name, "type": String(TYPE_NAMES[type_id]), "type_id": type_id,
		"length": int(value.size()), "bytes": bytes,
	}


func _container_row(name: String, value: Variant) -> Dictionary:
	"""Build one reported row for a non-packed Array or Dictionary member."""
	var kind: String = "Array" if value is Array else "Dictionary"
	return {"name": name, "kind": kind, "length": int(value.size())}


func _script_path(subject: Object) -> String:
	"""Resource path of the instance's script, or its class name when it has none."""
	var script: Variant = subject.get_script()
	if script is Script and String(script.resource_path) != "":
		return String(script.resource_path)
	return subject.get_class()


func build_world() -> Dictionary:
	"""Wire exactly one instance of every allocating store, sharing collaborators explicitly.

	Sharing is the whole point: each store below builds a private collaborator when handed
	`null`, so the wiring order here is what keeps the world to one EntityDirectory.
	"""
	var world: Dictionary = {}
	_wire_resident_core(world)
	_wire_command_core(world)
	_wire_ecology_core(world)
	_wire_space_core(world)
	_wire_remaining_stores(world)
	return world


func _wire_resident_core(world: Dictionary) -> void:
	"""Directory, residents, priorities, schedule, jobs and the work leg over them."""
	world["entity_directory"] = EntityDirectoryScript.new()
	world["needs"] = NeedsScript.new()
	world["residents"] = ResidentsScript.new(world["entity_directory"], world["needs"])
	world["priorities"] = PrioritiesScript.new()
	world["schedule"] = ScheduleScript.new(world["needs"])
	world["jobs"] = JobsScript.new(world["residents"], world["priorities"], world["schedule"])
	world["work"] = WorkScript.new(world["jobs"])
	world["reservations"] = ReservationsScript.new()


func _wire_command_core(world: Dictionary) -> void:
	"""The ARCH-CMD-001 queue, its dispatcher and the ARCH-CMD-002 scheduler queue."""
	world["sim_clock"] = SimClockScript.new()
	world["commands"] = CommandsScript.new(world["sim_clock"], world["entity_directory"])
	world["command_dispatch"] = CommandDispatchScript.new(world["commands"],
		world["residents"], world["priorities"], world["schedule"], world["jobs"])
	world["scheduler_events"] = SchedulerEventsScript.new(world["sim_clock"])


func _wire_ecology_core(world: Dictionary) -> void:
	"""Ecology's four stores, the crop/weather composition and the planner over both."""
	world["ecology"] = EcologyScript.new(world["entity_directory"], world["jobs"])
	world["rng"] = RngScript.new()
	world["crop_weather"] = CropWeatherScript.new(world["ecology"], world["rng"])
	var farming: Object = world["crop_weather"].farming()
	var forage: Object = world["ecology"].forage()
	world["job_planner"] = JobPlannerScript.new(farming, world["jobs"], forage,
		world["ecology"].orchard_hive())
	world["field_policy"] = FieldPolicyScript.new(farming, forage)
	world["presentation_extract"] = PresentationExtractScript.new(world["residents"],
		world["jobs"], world["command_dispatch"], forage, world["job_planner"],
		world["crop_weather"].weather())


func _wire_space_core(world: Dictionary) -> void:
	"""The ground map, the A* builder, the transform columns and the motion scratch."""
	world["spatial_world"] = SpatialWorldScript.new()
	world["navigation"] = NavigationScript.new(
		world["entity_directory"], world["spatial_world"])
	world["transforms"] = TransformsScript.new(world["entity_directory"])
	world["movement"] = MovementScript.new(world["entity_directory"], world["spatial_world"],
		world["navigation"], world["transforms"], world["residents"])


func _wire_remaining_stores(world: Dictionary) -> void:
	"""Stores with no collaborator graph of their own, plus the world generator."""
	world["gear"] = GearScript.new()
	world["inventory"] = InventoryScript.new()
	world["resource_catalog_binding"] = ResourceCatalogBindingScript.new()
	world["item_definitions"] = ItemDefinitionsScript.new()
	world["world_init"] = WorldInitScript.new(world["entity_directory"],
		world["ecology"].resource_nodes(), world["ecology"].forage(),
		world["ecology"].fishing(), world["rng"], world["crop_weather"].farming(),
		world["ecology"].orchard_hive(), world["jobs"], world["commands"])


func collect_instances(world: Dictionary) -> Array[Dictionary]:
	"""Measure every distinct store reachable from the wired roots, deduped by instance id."""
	var seen: Dictionary = {}
	var measured: Array[Dictionary] = []
	var queue: Array[Object] = []
	for key: String in world:
		_enqueue(world[key], queue)
	while not queue.is_empty():
		var subject: Object = queue.pop_front()
		if seen.has(subject.get_instance_id()):
			continue
		seen[subject.get_instance_id()] = true
		var row: Dictionary = measure_instance(subject)
		measured.append(row)
		_enqueue_children(subject, queue)
	measured.sort_custom(_by_script_path)
	return measured


func _enqueue_children(subject: Object, queue: Array[Object]) -> void:
	"""Push every store-valued script member of one instance onto the walk queue."""
	for property: Dictionary in subject.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		_enqueue(subject.get(String(property["name"])), queue)


func _enqueue(value: Variant, queue: Array[Object]) -> void:
	"""Enqueue a value when it is a live instance of a project script under scripts/."""
	if not (value is Object) or value == null:
		return
	var subject: Object = value as Object
	if not is_instance_valid(subject):
		return
	if not _script_path(subject).begins_with("res://scripts/"):
		return
	queue.append(subject)


func calibrate_array_element_bytes() -> Dictionary:
	"""Measure bytes per element of a GDScript `Array[StringName]` from static memory.

	`command_dispatch.gd` holds its result store codes in an Array, not a packed column, and
	ARCH-MEM-010 budgets that row at 8 bytes per element on the reasoning that "assigning an
	interned name is a reference copy, not an allocation". A GDScript Array is a vector of
	Variants, so this measures what one element of it actually costs.
	"""
	var names: Array[StringName] = []
	var before: int = OS.get_static_memory_usage()
	names.resize(CALIBRATION_ELEMENTS)
	var delta: int = OS.get_static_memory_usage() - before
	names.clear()
	var ok: bool = delta >= CALIBRATION_ELEMENTS
	return {
		"elements": CALIBRATION_ELEMENTS, "delta_bytes": delta, "measured": ok,
		"bytes_per_element": delta / CALIBRATION_ELEMENTS if ok else 0, "declared": 8,
	}


func column_bytes_named(row: Dictionary, names: Array) -> int:
	"""Total the measured bytes of the named columns of one measured instance row."""
	var total: int = 0
	for column: Dictionary in row["columns"]:
		if names.has(String(column["name"])):
			total += int(column["bytes"])
	return total


func _by_script_path(left: Dictionary, right: Dictionary) -> bool:
	"""Sort measured rows by script path so two runs print in the same order."""
	if String(left["script"]) == String(right["script"]):
		return int(left["instance_id"]) < int(right["instance_id"])
	return String(left["script"]) < String(right["script"])


func total_packed_bytes(measured: Array[Dictionary]) -> int:
	"""Sum the packed payload of every measured instance."""
	var total: int = 0
	for row: Dictionary in measured:
		total += int(row["packed_bytes"])
	return total


func duplicate_instances(measured: Array[Dictionary]) -> Array[String]:
	"""Script paths that the walk found more than one live instance of."""
	var counts: Dictionary = {}
	var repeated: Array[String] = []
	for row: Dictionary in measured:
		var path: String = String(row["script"])
		counts[path] = int(counts.get(path, 0)) + 1
		if int(counts[path]) == 2:
			repeated.append(path)
	return repeated
