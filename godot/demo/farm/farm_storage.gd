extends RefCounted
## Where the demo pantry keeps food, and how fast each place spoils it. Decision 0196.
##
## ---------------------------------------------------------------------------------------
## THE STORAGE-PROVIDER API (for root cellars and anything else that stores food). A provider is a
## Callable taking no arguments and returning an Array of Dictionaries, one per storage location:
##
##     {"id": StringName or int,           stable while the location exists; its lots follow it
##      "position": Vector2 (x, z) or Vector3 (x, y, z), metres -- where a carrier delivers
##      "capacity_u": int >= 1,            whole units it holds (farm quantities are milli-U)
##      "spoilage_permille": int 1..10000, its store factor: 1000 ages food at the base rate
##      "label": String,                   optional; what the pantry calls it
##      "staging": bool}                   optional; true: a gathering place food is set down at on its way to a
##                                         store (the orchard's basket stands, decision 0674) -- never chosen as a
##                                         harvest's or a delivery's destination (farm_pantry.gd `_best_location_into`)
##
## `spoilage_permille` IS GDD §5.8's store factor -- "open pile 1500, covered store 1000, pantry 750,
## cellar 350" -- so a root cellar that follows the GDD reports 350 (scripts/core/stock_age.gd
## STORE_FACTOR carries the same four). demo_village.gd injects the providers; the lead wires the
## tunnel extension's cellar listing into one with a small adapter. Entries that break the shape
## are REFUSED -- dropped and counted in `refused_entries()` -- never repaired into a guess.
##
## The farm always has one location of its own: the village's covered store, at its work spot, at
## §5.8's covered-store factor, holding STORE_CAPACITY_U (a demo value). It is location 0.
## `refresh()` re-reads every provider; the pantry moves the lots of a location that vanished to
## location 0 (see farm_pantry.gd), so food is never lost to a cellar being filled in.

const StockAge := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const KEY_ID: String = "id"
const KEY_POSITION: String = "position"
const KEY_CAPACITY_U: String = "capacity_u"
const KEY_PERMILLE: String = "spoilage_permille"
const KEY_LABEL: String = "label"
## A gathering place, never a destination (see the header; decision 0674).
const KEY_STAGING: String = "staging"
const MILLI_PER_U: int = 1000
const MAX_PERMILLE: int = 10000
## The covered store (location 0): §5.8's covered-store factor, and a demo capacity.
const STORE_ID: StringName = &"covered_store"
const STORE_LABEL: String = "Covered store"
const STORE_PERMILLE: int = StockAge.STORE_FACTOR[StockAge.STORAGE_COVERED_STORE]
const STORE_CAPACITY_U: int = 400
const MAX_LOCATIONS: int = 16
const REFUSE_GONE: String = "STORAGE_LOCATION_GONE"

var _providers: Array[Callable] = []
var _ids: Array = []
var _labels: PackedStringArray = PackedStringArray()
var _positions: PackedVector2Array = PackedVector2Array()
var _capacity_milli: PackedInt64Array = PackedInt64Array()
var _permille: PackedInt32Array = PackedInt32Array()
## Per location: 1 when it is a gathering place (KEY_STAGING), never a destination.
var _staging: PackedByteArray = PackedByteArray()
var _refused: int = 0
var _store_at: Vector2 = Vector2.ZERO


func _init(store_at: Vector2 = Vector2.ZERO) -> void:
	"""Start with the covered store only, delivered to at `store_at` (x, z)."""
	_store_at = store_at
	refresh()


func add_provider(provider: Callable) -> void:
	"""Take storage locations from `provider` too (see the header), re-reading now."""
	_providers.append(provider)
	refresh()


func refresh() -> void:
	"""Re-read every provider into the location list: the covered store first, then each valid entry
	in provider order (at most MAX_LOCATIONS in all)."""
	_ids = [STORE_ID]
	_labels = PackedStringArray([STORE_LABEL])
	_positions = PackedVector2Array([_store_at])
	_capacity_milli = PackedInt64Array([STORE_CAPACITY_U * MILLI_PER_U])
	_permille = PackedInt32Array([STORE_PERMILLE])
	_staging = PackedByteArray([0])
	_refused = 0
	for provider: Callable in _providers:
		if not provider.is_valid():
			_refused += 1
			continue
		var listed: Variant = provider.call()
		if not listed is Array:
			_refused += 1
			continue
		for entry: Variant in listed:
			_take(entry)


func _take(entry: Variant) -> void:
	"""Add one provider entry, or refuse it (counted) when it breaks the shape."""
	if not entry is Dictionary or _ids.size() >= MAX_LOCATIONS:
		_refused += 1
		return
	var row: Dictionary = entry
	var at: Variant = row.get(KEY_POSITION)
	var capacity: Variant = row.get(KEY_CAPACITY_U)
	var permille: Variant = row.get(KEY_PERMILLE)
	var id: Variant = row.get(KEY_ID)
	var position_ok: bool = at is Vector2 or at is Vector3
	var id_ok: bool = (id is StringName or id is String or id is int) and not _ids.has(id)
	if not (position_ok and id_ok and capacity is int and permille is int):
		_refused += 1
		return
	if int(capacity) < 1 or int(permille) < 1 or int(permille) > MAX_PERMILLE:
		_refused += 1
		return
	_ids.append(id)
	_labels.append(String(row.get(KEY_LABEL, "Store %d" % _ids.size())))
	_positions.append(Vector2(at.x, at.z) if at is Vector3 else at as Vector2)
	_capacity_milli.append(int(capacity) * MILLI_PER_U)
	_permille.append(int(permille))
	_staging.append(1 if row.get(KEY_STAGING, false) == true else 0)


func count() -> int:
	"""How many locations there are (the covered store included)."""
	return _ids.size()


func id_of(location: int) -> Variant:
	"""A location's provider id."""
	return _ids[location]


func index_of_id_into(id: Variant, out: IntMath.IntResult) -> bool:
	"""Where a provider id now stands in the list, into `out`; refuses STORAGE_LOCATION_GONE."""
	var at: int = _ids.find(id)
	if at < 0:
		return out.refuse(REFUSE_GONE)
	return out.succeed(at)


func label_of(location: int) -> String:
	"""A location's name for the pantry view."""
	return _labels[location]


func position_of(location: int) -> Vector2:
	"""Where a carrier delivers to (x, z)."""
	return _positions[location]


func capacity_milli_of(location: int) -> int:
	"""A location's capacity, in milli-U."""
	return _capacity_milli[location]


func permille_of(location: int) -> int:
	"""A location's spoilage multiplier (§5.8 store factor) per 1000."""
	return _permille[location]


func is_staging(location: int) -> bool:
	"""Whether a location is a gathering place food waits at on its way to a store (KEY_STAGING), never a
	destination."""
	return location >= 0 and location < _staging.size() and _staging[location] == 1


func refused_entries() -> int:
	"""How many provider entries the last refresh refused."""
	return _refused
