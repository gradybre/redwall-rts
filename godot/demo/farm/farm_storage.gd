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
##      "storage_class": int,              optional; StockAge STORAGE_* (decision 0611, below)
##      "why": String}                     optional; why it keeps food as it does, in words
##
## `spoilage_permille` IS GDD §5.8's store factor -- "open pile 1500, covered store 1000, pantry 750,
## cellar 350" -- so a root cellar that follows the GDD reports 350 (scripts/core/stock_age.gd
## STORE_FACTOR carries the same four). demo_village.gd injects the providers; the lead wires the
## tunnel extension's cellar listing into one with a small adapter. Entries that break the shape
## are REFUSED -- dropped and counted in `refused_entries()` -- never repaired into a guess.
##
## STORAGE CLASS (decision 0611, the cool cellar -- for every later food store: preserving, stockpile zones). A location
## keeps food at one of §5.8's four classes (scripts/core/stock_age.gd STORAGE_*: open pile, covered store, pantry,
## cellar), and its `spoilage_permille` IS that class's store factor. An entry may give the class, the permille or both:
## the class alone takes its factor; the permille alone takes the class whose factor it is (STORAGE_UNDECLARED when none
## is: a demo value outside §5.8's four, kept and aged at its own rate); both must agree, or the entry is REFUSED. The
## class is what the location keeps food LIKE now -- a root cellar that is not cool keeps like a pantry (decision 0210),
## so it says STORAGE_PANTRY. `why_of` is the location's own words for it ("cool: deep, racked and away from any
## hearth"), else the class's (CLASS_WHY), so the Pantry can say why food lasts longer there.
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
const KEY_CLASS: String = "storage_class"
const KEY_WHY: String = "why"
const MILLI_PER_U: int = 1000
const MAX_PERMILLE: int = 10000
## The covered store (location 0): §5.8's covered-store factor, and a demo capacity.
const STORE_ID: StringName = &"covered_store"
const STORE_LABEL: String = "Covered store"
const STORE_CLASS: int = StockAge.STORAGE_COVERED_STORE
const STORE_PERMILLE: int = StockAge.STORE_FACTOR[STORE_CLASS]
const STORE_CAPACITY_U: int = 400
const MAX_LOCATIONS: int = 16
const REFUSE_GONE: String = "STORAGE_LOCATION_GONE"
## Each class's words when a location gives none of its own (see STORAGE CLASS; demo text over §5.8's factors).
const CLASS_WHY: Array[String] = ["kept at its own rate", "in the open: food ages half as fast again",
	"under cover: food ages at the base rate", "a pantry: shaded, food ages at three quarters of the base rate",
	"a cool cellar: food ages at about a third of the base rate"]

var _providers: Array[Callable] = []
var _ids: Array = []
var _labels: PackedStringArray = PackedStringArray()
var _positions: PackedVector2Array = PackedVector2Array()
var _capacity_milli: PackedInt64Array = PackedInt64Array()
var _permille: PackedInt32Array = PackedInt32Array()
var _class: PackedInt32Array = PackedInt32Array()
var _why: PackedStringArray = PackedStringArray()
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
	_class = PackedInt32Array([STORE_CLASS])
	_why = PackedStringArray([CLASS_WHY[STORE_CLASS]])
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
	var id: Variant = row.get(KEY_ID)
	var position_ok: bool = at is Vector2 or at is Vector3
	var id_ok: bool = (id is StringName or id is String or id is int) and not _ids.has(id)
	var kept := class_and_permille_of(row)
	if not (position_ok and id_ok and capacity is int) or kept.x < 0 or int(capacity) < 1:
		_refused += 1
		return
	_ids.append(id)
	_labels.append(String(row.get(KEY_LABEL, "Store %d" % _ids.size())))
	_positions.append(Vector2(at.x, at.z) if at is Vector3 else at as Vector2)
	_capacity_milli.append(int(capacity) * MILLI_PER_U)
	_permille.append(kept.y)
	_class.append(kept.x)
	var why: Variant = row.get(KEY_WHY)
	_why.append(String(why) if why is String and not String(why).is_empty() else CLASS_WHY[kept.x])


static func class_and_permille_of(row: Dictionary) -> Vector2i:
	"""An entry's (storage class, permille) under STORAGE CLASS; x is -1 when they are missing, malformed, out of range
	or disagree."""
	var given_class: Variant = row.get(KEY_CLASS)
	var permille: Variant = row.get(KEY_PERMILLE)
	if given_class == null and permille == null:
		return Vector2i(-1, 0)
	if given_class != null and not (given_class is int and StockAge.is_storage_class(int(given_class))):
		return Vector2i(-1, 0)
	if permille != null and not (permille is int and int(permille) >= 1 and int(permille) <= MAX_PERMILLE):
		return Vector2i(-1, 0)
	if given_class == null:
		return Vector2i(class_of_permille(int(permille)), int(permille))
	var factor: int = StockAge.STORE_FACTOR[int(given_class)]
	if permille != null and int(permille) != factor:
		return Vector2i(-1, 0)
	return Vector2i(int(given_class), factor)


static func class_of_permille(permille: int) -> int:
	"""The §5.8 class whose store factor `permille` is, or STORAGE_UNDECLARED when it is none of the four."""
	var found: int = StockAge.STORE_FACTOR.find(permille)
	return found if found > StockAge.STORAGE_UNDECLARED else StockAge.STORAGE_UNDECLARED


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


func class_of(location: int) -> int:
	"""A location's storage class (StockAge STORAGE_*; see STORAGE CLASS)."""
	return _class[location]


func why_of(location: int) -> String:
	"""Why a location keeps food as it does, in words (see STORAGE CLASS)."""
	return _why[location]


func refused_entries() -> int:
	"""How many provider entries the last refresh refused."""
	return _refused
