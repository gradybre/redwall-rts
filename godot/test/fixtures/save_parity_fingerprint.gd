extends RefCounted
## ARCH-SAVE-006's per-tick comparison: one integer per completed tick over every canonical field.
##
## A whole save captures 57 MB and takes about 33 s, so ARCH-SAVE-006's "compare every tick
## 3001-18000" cannot recapture the world each tick. This fingerprint reads the SAME members the
## save does -- the canonical registry's declared fields (`canonical_state_hash.gd`'s generated
## FIELD_KEYS per owner, minus the hash=false ones) -- straight off the live owners, and folds each
## member's native Variant hash into one integer. Two runs whose fingerprints agree at a tick agree
## on every resolved canonical member at that tick, up to a 64-bit fold of 32-bit content hashes;
## the parity test also compares whole saves byte for byte at the ends of its windows, so a
## collision cannot hide a difference there.
##
## An owner the settlement does not compose (the underground wire owners while nothing is mounted)
## has no live object; its fields are counted as unresolved, and `resolved_count()` reports how
## many declared fields the fingerprint actually covers.
##
## THE TWO QUEUES ARE READ AS THE SAVE WRITES THEM, NOT AS THEIR SLOTS HAPPEN TO LIE. Both are rings
## whose save writes only the live rows from a canonical head, so a loaded queue holds the same rows
## at other slots and none of the residue an executed row leaves behind:
##   * the scheduler queue: its per-slot columns are hashed over the live rows in logical order;
##     `_head` is a position, not a value, and is left out;
##   * the command queue: each live row (through `_order`) contributes every column and its own
##     payload bytes; `_order`'s slot positions, `_payload_offset` and `_payload_used` locate
##     bytes in the arena rather than state anything, so the payload CONTENT stands for them.
## Every other member is hashed whole.

const Canonical := preload("res://scripts/core/canonical_state_hash.gd")
const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")

## Command-queue members the live-row view stands for (see the header).
const COMMAND_LOCATORS: Array[StringName] = [&"_head", &"_payload_offset", &"_payload_used", &"_payload"]

var _objects: Array[Object] = []
var _fields: Array[StringName] = []
var _hashes: PackedInt64Array = PackedInt64Array()
var _declared: int = 0
var _viewed: int = 0
var _unresolved: Dictionary = {}
var _events: Object = null
var _event_fields: Array[StringName] = []
var _commands: Object = null
var _command_fields: Array[StringName] = []
var _scratch: PackedInt64Array = PackedInt64Array()
var _payload: PackedByteArray = PackedByteArray()


func bind(world: SaveWorld.World) -> int:
	"""Resolve every hashed declared field to the live member that holds it. Returns how many."""
	_objects.clear()
	_fields.clear()
	_event_fields.clear()
	_command_fields.clear()
	_unresolved.clear()
	_events = world.scheduler_events()
	_commands = world.commands
	_declared = 0
	_viewed = 0
	var owners: Dictionary = _owner_objects(world)
	var index: int = 0
	for owner: int in Canonical.OWNER_KEYS.size():
		var candidates: Array = owners.get(String(Canonical.OWNER_KEYS[owner]), [])
		for field: int in int(Canonical.OWNER_FIELD_COUNTS[owner]):
			if not Canonical.FIELD_EXCLUDED_INDEXES.has(index):
				_declared += 1
				if not _resolve(candidates, StringName(Canonical.FIELD_KEYS[index])):
					var key: String = String(Canonical.OWNER_KEYS[owner])
					_unresolved[key] = int(_unresolved.get(key, 0)) + 1
			index += 1
	_hashes.resize(_fields.size())
	return resolved_count()


func _resolve(candidates: Array, field: StringName) -> bool:
	"""Bind `field` to the first candidate object that declares it as a value (an Object member's
	hash is its instance id, which two worlds never share, so none is bound)."""
	for candidate: Variant in candidates:
		var object: Object = candidate as Object
		var value: Variant = object.get(field) if object != null else null
		if value == null or typeof(value) == TYPE_OBJECT:
			continue
		if _viewed_field(object, field, value):
			return true
		_objects.append(object)
		_fields.append(field)
		return true
	return false


func _viewed_field(object: Object, field: StringName, value: Variant) -> bool:
	"""Whether `field` is read through one queue's live-row view instead of whole."""
	var column: bool = typeof(value) >= TYPE_PACKED_BYTE_ARRAY
	if object == _events and (field == &"_head" or column):
		if field != &"_head":
			_event_fields.append(field)
	elif object == _commands and (COMMAND_LOCATORS.has(field) or column):
		if not COMMAND_LOCATORS.has(field):
			_command_fields.append(field)
	else:
		return false
	_viewed += 1
	return true


func _owner_objects(w: SaveWorld.World) -> Dictionary:
	"""Each registry owner key to the live objects that may hold its members."""
	return {
		"buildings": [w.buildings], "entity_directory": [w.directory], "farming": [w.farming],
		"forage": [w.forage], "resource_nodes": [w.resource_nodes], "spatial_world": [w.absent_spatial_world],
		"underground_space_owner": [w.space_owner], "weather": [w.weather], "world_init": [w.world_init],
		"world_runtime": [w.clock(), w.rng, w.settlement], "movement": [w.movement],
		"construction": [w.construction], "construction_extension": [w.construction],
		"construction_paid_ledger": [w.construction], "field_policy": [w.absent_field_policy],
		"fishing": [w.fishing], "injury": [w.absent_injury], "jobs": [w.jobs], "needs": [w.needs],
		"orchard_hive": [w.orchard_hive], "priorities": [w.priorities], "residents": [w.residents],
		"schedule": [w.schedule], "transforms": [w.transforms], "work": [w.work],
		"command_dispatch": [w.dispatch], "crop_weather": [w.crop_weather],
		"demolition_admissions": [w.admissions], "demolition_work": [w.demolition_work],
		"ecology": [w.ecology], "haul_planner": [w.haul_planner], "inventory": [w.inventory],
		"store_policy": [w.store_policy], "gear": [w.gear], "reservations": [w.reservations],
		"stock_age": [w.stock_age], "job_planner": [w.planner], "navigation": [w.movement._navigation],
		"rng": [w.rng], "event_schedule": [w.absent_event_schedule], "commands": [w.commands],
		"scheduler_events": [w.scheduler_events()], "chronicle": [w.absent_chronicle],
	}


func fingerprint() -> int:
	"""One integer over every resolved member's current content."""
	for index: int in _fields.size():
		_hashes[index] = hash(_objects[index].get(_fields[index]))
	var whole: int = hash(_hashes) * 4294967296 + hash(_hashes.to_byte_array())
	return whole ^ (_event_hash() * 65537) ^ _command_hash()


func _event_hash() -> int:
	"""The scheduler queue's live rows, in logical order, over every per-slot column."""
	var count: int = _events.get(&"_count")
	var head: int = _events.get(&"_head")
	_scratch.resize(count * _event_fields.size())
	var at: int = 0
	for field: StringName in _event_fields:
		var column: Variant = _events.get(field)
		for row: int in count:
			_scratch[at] = column[(head + row) % column.size()]
			at += 1
	return hash(_scratch)


func _command_hash() -> int:
	"""The command queue's live rows in order: every column of each row, then its payload bytes."""
	var count: int = _commands.get(&"_count")
	var head: int = _commands.get(&"_head")
	var order: PackedInt32Array = _commands.get(&"_order")
	var arena: PackedByteArray = _commands.get(&"_payload")
	var offsets: PackedInt32Array = _commands.get(&"_payload_offset")
	var lengths: PackedInt32Array = _commands.get(&"_payload_length")
	_scratch.resize(count * _command_fields.size())
	_payload.clear()
	for position: int in count:
		var row: int = order[(head + position) % order.size()]
		for field: int in _command_fields.size():
			_scratch[position * _command_fields.size() + field] = _commands.get(_command_fields[field])[row]
		_payload.append_array(arena.slice(offsets[row], offsets[row] + lengths[row]))
	return hash(_scratch) * 31 + hash(_payload)


func resolved_count() -> int:
	"""How many declared, hashed fields this fingerprint covers (whole, or through a queue view)."""
	return _fields.size() + _viewed


func declared_count() -> int:
	"""How many declared, hashed fields the registry lists."""
	return _declared


func unresolved_owners() -> Dictionary:
	"""Owner key to how many of its declared fields no live member holds."""
	return _unresolved
