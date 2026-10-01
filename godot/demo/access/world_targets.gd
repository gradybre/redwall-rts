extends RefCounted
## THE WORLD'S INTERACTIVE TARGETS: every thing in the village a click selects, by kind, for the accessible object
## list (object_list.gd) and the "show interactive targets" rings (target_marks.gd). Decision 0471 (review UX-023, P9;
## UI §8.2's world list). Presentation only: it reads the owners' rows through the host's Callables and selects
## through the same calls a click makes.
##
## KINDS (KIND_*): residents (the cast), crop beds (the farm), trees (the woods' stand: standing, young, stumps and
## cleared spots, each a row the Woods panel takes), bridges (planned or open), tunnel mouths, and rooms (burrow homes
## and root cellars, underground). Each is REGISTERED by the host with five Callables:
##   capacity() -> int        how many rows the owner has (ids 0..capacity-1)
##   exists(id) -> bool       whether row `id` holds one now
##   label(id) -> String      its name as its panel says it ("Wenna Tallowby", "the carrot bed", "Young oak")
##   point(id) -> Vector3     where it is (on the ground; a room's centre, below)
##   pick(id)                 select it, as a click on it does (its panel comes forward)
## `collect` lists what exists now, in kind order then id order -- the order the list shows -- into reused columns.

const KIND_RESIDENT: int = 0
const KIND_BED: int = 1
const KIND_TREE: int = 2
const KIND_BRIDGE: int = 3
const KIND_MOUTH: int = 4
const KIND_ROOM: int = 5
const KIND_COUNT: int = 6
const KIND_TITLES: Array[String] = ["Residents", "Crop beds", "Trees", "Bridges", "Tunnel mouths", "Rooms"]
const KIND_WORDS: Array[String] = ["resident", "crop bed", "tree", "bridge", "tunnel mouth", "room"]
## Every kind (a mask with all KIND_COUNT bits set).
const ALL_KINDS: int = 63
## A ring's radius per kind on the ground (m), for the targets' rings.
const RING_M: PackedFloat32Array = [0.75, 1.7, 1.2, 1.5, 0.9, 1.6]


## One kind's owner calls (see KINDS).
class Source:
	var capacity: Callable = Callable()
	var exists: Callable = Callable()
	var label: Callable = Callable()
	var point: Callable = Callable()
	var pick: Callable = Callable()


## The listed targets, in order: each one's kind and id (filled by `collect`).
var kinds: PackedByteArray = PackedByteArray()
var ids: PackedInt32Array = PackedInt32Array()
## `centre(point: Vector3)`: ease the camera over a point (demo_camera.gd `centre_on`).
var centre: Callable = Callable()
## How many targets were selected through the list (checks).
var picks: int = 0

var _sources: Array[Source] = []


func _init() -> void:
	"""No kind registered yet."""
	_sources.resize(KIND_COUNT)


func register(kind: int, capacity: Callable, exists: Callable, label: Callable, point: Callable, pick: Callable) -> void:
	"""How to list, name, find and select targets of `kind` (see KINDS)."""
	if kind < 0 or kind >= KIND_COUNT:
		return
	var source := Source.new()
	source.capacity = capacity
	source.exists = exists
	source.label = label
	source.point = point
	source.pick = pick
	_sources[kind] = source


func has_kind(kind: int) -> bool:
	"""Whether `kind` is registered."""
	return kind >= 0 and kind < KIND_COUNT and _sources[kind] != null


func collect(kind_mask: int = ALL_KINDS) -> int:
	"""List every target that exists now, of the kinds in `kind_mask`, into this registry's own columns (the object
	list's); returns how many."""
	var listed: int = collect_into(kind_mask, kinds, ids)
	kinds.resize(listed)
	ids.resize(listed)
	return listed


func collect_into(kind_mask: int, kinds_out: PackedByteArray, ids_out: PackedInt32Array) -> int:
	"""The same listing into a caller's own columns (the rings': they refresh while the list is open, and must never
	move its rows), which only ever grow; returns how many are listed (the columns may be longer)."""
	var listed: int = 0
	for kind: int in KIND_COUNT:
		if kind_mask & (1 << kind) == 0 or _sources[kind] == null:
			continue
		var source: Source = _sources[kind]
		for id: int in int(source.capacity.call()):
			if not bool(source.exists.call(id)):
				continue
			if listed >= kinds_out.size():
				kinds_out.resize(listed + 16)
				ids_out.resize(listed + 16)
			kinds_out[listed] = kind
			ids_out[listed] = id
			listed += 1
	return listed


func point_at(kind: int, id: int) -> Vector3:
	"""Where target (`kind`, `id`) is (Vector3.INF: an unregistered kind)."""
	if kind < 0 or kind >= KIND_COUNT or _sources[kind] == null:
		return Vector3.INF
	return _sources[kind].point.call(id) as Vector3


func count() -> int:
	"""How many targets the last `collect` listed."""
	return kinds.size()


func label_of(k: int) -> String:
	"""Listed target `k`'s name, as its owner says it."""
	return String(_sources[kinds[k]].label.call(ids[k])) if k >= 0 and k < kinds.size() else ""


func point_of(k: int) -> Vector3:
	"""Where listed target `k` is (Vector3.INF: not listed)."""
	if k < 0 or k >= kinds.size():
		return Vector3.INF
	return _sources[kinds[k]].point.call(ids[k]) as Vector3


func row_text(k: int) -> String:
	"""Listed target `k`'s row in the list: 'Wenna Tallowby — resident'."""
	var name: String = label_of(k)
	if not name.is_empty():
		name = name.substr(0, 1).to_upper() + name.substr(1)
	return "%s — %s" % [name, KIND_WORDS[kinds[k]]]


func pick(k: int) -> bool:
	"""Select listed target `k`, as a click on it does, and centre the camera over it. False: no longer there."""
	if k < 0 or k >= kinds.size():
		return false
	var source: Source = _sources[kinds[k]]
	if not bool(source.exists.call(ids[k])):
		return false
	var at: Vector3 = source.point.call(ids[k]) as Vector3
	source.pick.call(ids[k])
	if centre.is_valid() and at.is_finite():
		centre.call(Vector3(at.x, 0.0, at.z))
	picks += 1
	return true
