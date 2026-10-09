extends RefCounted
## THE CELLAR BUILDINGS (decision 0612): where each stands, how far its building has got, and -- once built -- the
## pantry store it is. Presentation only; the numbers are cellar_rules.gd's.
##
## A CELLAR is a row: NONE (free), DELIVERING (placed: its materials are being fetched), BUILDING (all delivered,
## REQ-SET-125: the work is on) or DONE (a store). Placing one deducts nothing (REQ-SET-124). Per material it keeps what
## is DELIVERED to its site, what is RESERVED by a carrier on its way to the stores for it, and what is IN TRANSIT in a
## carrier's arms; all three count against what it still needs, so nothing is fetched twice (the review's H1). The
## village stores (tunnel_stores.gd) lose a material only when a carrier LIFTS it (`lift`: reserved becomes in transit),
## and a load a carrier puts back goes back into them (`return_load`). Only a cellar still DELIVERING may be lifted for or
## delivered to. So every milli-U is in the stores, a carrier's arms, or a cellar's site -- until it is built in. CANCEL (REQ-SET-126) returns 100% of what was delivered before the work began, 80% floored after, into the
## stores (the hall's ruled refund, decision 0771 P4).
##
## THE STORE. A DONE cellar is a storage-provider entry (farm_storage.gd): id "cellar_building:<row>:<generation>",
## delivered to at its door, cellar_rules.gd's capacity in U, the CELLAR class (350 per mille) and its why. Nothing
## else in the pantry, the haul or the Pantry treats it specially.

const Rules := preload("res://demo/stores/cellar_rules.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const MAX_CELLARS: int = 2
const NONE: int = -1
const STATE_NONE: int = 0
const STATE_DELIVERING: int = 1
const STATE_BUILDING: int = 2
const STATE_DONE: int = 3
const STATE_WORDS: Array[String] = ["", "materials being fetched", "being built", "built"]
## The drawn building's reach from its centre (m): the library cellar model at its 2.0 m envelope height is about
## 4.1 x 4.5 m (demo value; demo/props/demo_props.gd BUILDINGS). Its door is on its front (+Z turned by `face`).
const RADIUS_M: float = 2.4
const DOOR_M: float = 2.9
## Where carriers set materials down: beside it, to its right (m).
const SITE_SIDE_M: float = 3.2
const ID_FORMAT: String = "cellar_building:%d:%d"
const REFUSE_FULL: String = "two cellars are planned or built already"
const REFUSE_BUILT: String = "it is built"
const REFUSE_NOT_PLANNED: String = "that cellar is not planned"

var state: PackedByteArray = PackedByteArray()
var at: PackedVector2Array = PackedVector2Array()
## Its yaw (radians): the way its front faces. Presentation.
var face: PackedFloat32Array = PackedFloat32Array()
var generation: PackedInt32Array = PackedInt32Array()
## Per cellar per material (row * MAT_COUNT + mat), milli-U.
var delivered: PackedInt64Array = PackedInt64Array()
var reserved: PackedInt64Array = PackedInt64Array()
var in_transit: PackedInt64Array = PackedInt64Array()
## Builders' demo time put in, microseconds.
var work_usec: PackedInt64Array = PackedInt64Array()
var built_count: int = 0
var revision: int = 0

var _stores: StoresScript = null


func _init(stores: StoresScript) -> void:
	"""No cellars yet, over the village stores."""
	_stores = stores
	state.resize(MAX_CELLARS)
	at.resize(MAX_CELLARS)
	face.resize(MAX_CELLARS)
	generation.resize(MAX_CELLARS)
	work_usec.resize(MAX_CELLARS)
	delivered.resize(MAX_CELLARS * Rules.MAT_COUNT)
	reserved.resize(MAX_CELLARS * Rules.MAT_COUNT)
	in_transit.resize(MAX_CELLARS * Rules.MAT_COUNT)


func is_active(c: int) -> bool:
	"""Whether cellar `c` is being fetched for or built."""
	return c >= 0 and c < MAX_CELLARS and (state[c] == STATE_DELIVERING or state[c] == STATE_BUILDING)


func is_done(c: int) -> bool:
	"""Whether cellar `c` is built."""
	return c >= 0 and c < MAX_CELLARS and state[c] == STATE_DONE


func free_row() -> int:
	"""A row for a new cellar, or NONE."""
	var c: int = state.find(STATE_NONE)
	return c if c >= 0 else NONE


func plan_at(centre: Vector2, yaw: float) -> int:
	"""Place a cellar here (REQ-SET-124: nothing deducted); its row, or NONE with no free row."""
	var c: int = free_row()
	if c == NONE:
		return NONE
	state[c] = STATE_DELIVERING
	at[c] = centre
	face[c] = yaw
	generation[c] += 1
	work_usec[c] = 0
	_clear_cells(c)
	revision += 1
	return c


func _clear_cells(c: int) -> void:
	"""Nothing delivered, reserved or in transit for cellar `c`."""
	for mat: int in Rules.MAT_COUNT:
		delivered[_cell(c, mat)] = 0
		reserved[_cell(c, mat)] = 0
		in_transit[_cell(c, mat)] = 0


func _cell(c: int, mat: int) -> int:
	"""Cellar `c`'s column cell for material `mat`."""
	return c * Rules.MAT_COUNT + mat


func delivered_milli(c: int, mat: int) -> int:
	"""What of a material is at cellar `c`'s site, milli-U."""
	return delivered[_cell(c, mat)]


func reserved_milli(c: int, mat: int) -> int:
	"""What of a material carriers are on their way to fetch for cellar `c`, milli-U."""
	return reserved[_cell(c, mat)]


func outstanding(c: int, mat: int) -> int:
	"""What of a material cellar `c` still needs that nobody is fetching, milli-U."""
	if state[c] != STATE_DELIVERING:
		return 0
	var cell: int = _cell(c, mat)
	return maxi(0, Rules.cost_milli(mat) - delivered[cell] - reserved[cell] - in_transit[cell])


func in_stock(mat: int) -> int:
	"""What of a material the village stores hold, milli-U."""
	return _stores.wood_milli_u if mat == Rules.MAT_WOOD else _stores.stone_milli_u


func held_total(mat: int) -> int:
	"""What of a material every cellar's carriers have reserved in the stores, milli-U."""
	var held: int = 0
	for c: int in MAX_CELLARS:
		held += reserved[_cell(c, mat)]
	return held


func fetchable(c: int, mat: int) -> int:
	"""What of a material a carrier could set off for now: still needed, and in the stores unreserved, milli-U."""
	return mini(outstanding(c, mat), maxi(0, in_stock(mat) - held_total(mat)))


func next_material(c: int) -> int:
	"""The first material (MAT_*) cellar `c` needs that the stores can give now, or NONE."""
	for mat: int in Rules.MAT_COUNT:
		if fetchable(c, mat) > 0:
			return mat
	return NONE


func reserve(c: int, mat: int, want_milli: int) -> int:
	"""Reserve up to `want_milli` of a material for a carrier setting off; how much."""
	var amount: int = mini(want_milli, fetchable(c, mat))
	if amount > 0:
		reserved[_cell(c, mat)] += amount
		revision += 1
	return amount


func unreserve(c: int, mat: int, milli: int) -> void:
	"""Give a reservation back (a carrier called away before it lifted)."""
	reserved[_cell(c, mat)] = maxi(0, reserved[_cell(c, mat)] - milli)
	revision += 1


func lift(c: int, mat: int, reserved_amount: int) -> int:
	"""A carrier at the stores lifts what it reserved -- as much as the stores hold, all or nothing per lift (REQ-SET-124:
	taken from the stores only now) -- and it is in transit; only for a cellar still DELIVERING. Its reservation is spent
	either way; how much it carries."""
	unreserve(c, mat, reserved_amount)
	var amount: int = mini(reserved_amount, in_stock(mat))
	if state[c] != STATE_DELIVERING or amount <= 0:
		return 0
	if not _stores.pay(amount if mat == Rules.MAT_WOOD else 0, amount if mat == Rules.MAT_STONE else 0):
		return 0
	in_transit[_cell(c, mat)] += amount
	return amount


func deliver(c: int, mat: int, milli: int) -> bool:
	"""A load in transit set down at cellar `c`'s site -- only while it is DELIVERING; with everything delivered the
	building begins (REQ-SET-125). False, nothing changed, otherwise (the carrier puts it back: `return_load`)."""
	if state[c] != STATE_DELIVERING or milli <= 0:
		return false
	in_transit[_cell(c, mat)] = maxi(0, in_transit[_cell(c, mat)] - milli)
	delivered[_cell(c, mat)] += milli
	if all_delivered(c):
		state[c] = STATE_BUILDING
	revision += 1
	return true


func return_load(c: int, mat: int, milli: int) -> void:
	"""A load a carrier did not deliver to cellar `c` goes back into the stores whole, and is no longer in transit."""
	if milli > 0:
		in_transit[_cell(c, mat)] = maxi(0, in_transit[_cell(c, mat)] - milli)
		_stores.refund(milli if mat == Rules.MAT_WOOD else 0, milli if mat == Rules.MAT_STONE else 0, 0)
		revision += 1


func all_delivered(c: int) -> bool:
	"""Whether every material cellar `c` costs is at its site."""
	for mat: int in Rules.MAT_COUNT:
		if delivered[_cell(c, mat)] < Rules.cost_milli(mat):
			return false
	return true


func add_work(c: int, usec: int) -> bool:
	"""A builder's demo time on cellar `c` (only while it is being built); whether that finished it."""
	if state[c] != STATE_BUILDING or usec <= 0:
		return false
	var before: int = percent(c)
	work_usec[c] += usec
	if work_usec[c] < Rules.work_usec():
		if percent(c) != before:
			revision += 1
		return false
	work_usec[c] = Rules.work_usec()
	state[c] = STATE_DONE
	built_count += 1
	revision += 1
	return true


func cancel(c: int) -> String:
	"""Take a planned cellar away (REQ-SET-126): what was delivered goes back into the stores, all of it before the work
	began, 80% floored after. "" when done, else why not. Carriers on their way are the builders' to let go first."""
	if c < 0 or c >= MAX_CELLARS or state[c] == STATE_NONE:
		return REFUSE_NOT_PLANNED
	if state[c] == STATE_DONE:
		return REFUSE_BUILT
	var begun: bool = work_usec[c] > 0
	_stores.refund(Rules.refund_milli(delivered[_cell(c, Rules.MAT_WOOD)], begun),
		Rules.refund_milli(delivered[_cell(c, Rules.MAT_STONE)], begun), 0)
	state[c] = STATE_NONE
	_clear_cells(c)
	work_usec[c] = 0
	revision += 1
	return ""


func refund_text(c: int) -> String:
	"""What a cancel would return now, in words ('returns 8 logs and 12 blocks of stone'; goods_measures.gd, decision
	1801)."""
	var begun: bool = work_usec[c] > 0
	return "returns %s and %s%s" % [Measures.amount(&"wood", Rules.refund_milli(delivered[_cell(c, Rules.MAT_WOOD)], begun)),
		Measures.amount(&"stone", Rules.refund_milli(delivered[_cell(c, Rules.MAT_STONE)], begun)),
		" (80%: the work has begun)" if begun else ""]


func percent(c: int) -> int:
	"""How far cellar `c` has got, 0-100: the delivery is the first half, the work the second."""
	if state[c] == STATE_DONE:
		return 100
	var need: int = Rules.cost_milli(Rules.MAT_WOOD) + Rules.cost_milli(Rules.MAT_STONE)
	var got: int = delivered[_cell(c, Rules.MAT_WOOD)] + delivered[_cell(c, Rules.MAT_STONE)]
	@warning_ignore("integer_division")  # whole percent by intent
	var part: int = got * 50 / maxi(need, 1) + work_usec[c] * 50 / maxi(Rules.work_usec(), 1)
	return mini(99, part)


func status_text(c: int) -> String:
	"""'Cellar 1: materials being fetched — wood 8 of 20 logs, stone 12 of 60 blocks (13%)', or '… built — holds 400
	baskets of food' (a capacity: no weight, decision 1011 P5)."""
	var label: String = Rules.LABEL % (c + 1)
	if state[c] == STATE_DONE:
		return "%s: built — holds %s, food keeps as in a cool cellar" % [label, capacity_words()]
	return "%s: %s — wood %s, stone %s (%d%%)" % [label, STATE_WORDS[state[c]],
		Measures.have_need(&"wood", delivered[_cell(c, Rules.MAT_WOOD)], Rules.cost_milli(Rules.MAT_WOOD)),
		Measures.have_need(&"stone", delivered[_cell(c, Rules.MAT_STONE)], Rules.cost_milli(Rules.MAT_STONE)), percent(c)]


static func capacity_words() -> String:
	"""What a cellar building holds, in baskets of mixed food ("400 baskets of food"): cellar_rules.gd's capacity in
	its own U (CAPACITY IN U, decision 0612), worded as a capacity, with no weight."""
	return Measures.exact(&"food", Rules.capacity_u() * Measures.MILLI_PER_U)


func door_of(c: int) -> Vector2:
	"""Where food is carried in: before its front."""
	return door_point(at[c], face[c])


func site_of(c: int) -> Vector2:
	"""Where its materials are set down: beside it."""
	return site_point(at[c], face[c])


static func door_point(centre: Vector2, yaw: float) -> Vector2:
	"""A cellar's door, standing at `centre` turned `yaw`: before its front (+Z turned)."""
	return centre + Vector2(sin(yaw), cos(yaw)) * DOOR_M


static func site_point(centre: Vector2, yaw: float) -> Vector2:
	"""A cellar's material site, standing at `centre` turned `yaw`: beside it."""
	return centre + Vector2(cos(yaw), -sin(yaw)) * SITE_SIDE_M


func entries() -> Array:
	"""Every built cellar as a storage-provider entry (see THE STORE; allocates: the pantry asks hourly)."""
	var out: Array = []
	for c: int in MAX_CELLARS:
		if state[c] == STATE_DONE:
			out.append({StorageScript.KEY_ID: StringName(ID_FORMAT % [c, generation[c]]),
				StorageScript.KEY_POSITION: door_of(c), StorageScript.KEY_CAPACITY_U: Rules.capacity_u(),
				StorageScript.KEY_CLASS: Rules.STORE_CLASS, StorageScript.KEY_WHY: Rules.WHY,
				StorageScript.KEY_LABEL: Rules.LABEL % (c + 1)})
	return out


func provider() -> Callable:
	"""The storage provider over the built cellars: `() -> Array` of entries."""
	return entries
