extends RefCounted
## THE INFIRMARY BUILDING (decision 0623): where it stands, how far its building has got, and -- once built -- the place
## the hurt go to rest and heal. One infirmary at most. Presentation only; the numbers are infirmary_rules.gd's. The
## cellar building's books (decision 0612, cellar_projects.gd), for three materials from two sources.
##
## STATE: NONE, DELIVERING (placed: its materials are being fetched), BUILDING (all delivered, REQ-SET-125) or DONE.
## Placing deducts nothing (REQ-SET-124). Per material it keeps what is DELIVERED to its site, RESERVED by a carrier on
## its way to fetch it, and IN TRANSIT in a carrier's arms; all three count against what it still needs, so nothing is
## fetched twice. A material leaves its SOURCE -- the village stores for wood and stone, the care shelf for cloth --
## only when a carrier LIFTS it, and a load put back goes back there whole. Only an infirmary still DELIVERING may be lifted
## for or delivered to: every milli-U is in its source, a carrier's arms or the site, until it is built in. CANCEL
## (REQ-SET-126) returns 100% of what was delivered before the work began, 80% floored after.
##
## THE BEDS. Built, it holds infirmary_rules.gd PATIENT_BEDS patients; `admit` / `discharge` keep who lies in it.

const Rules := preload("res://demo/infirmary/infirmary_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const StateScript := preload("res://demo/infirmary/care_state.gd")

const NONE: int = -1
const STATE_NONE: int = 0
const STATE_DELIVERING: int = 1
const STATE_BUILDING: int = 2
const STATE_DONE: int = 3
const STATE_WORDS: Array[String] = ["", "materials being fetched", "being built", "built"]
## The drawn building's reach from its centre (m), its door before its front (+Z turned by `face`), and where carriers
## set its materials down: beside it (demo values; the residence model at the infirmary's envelope, infirmary_view.gd).
const RADIUS_M: float = 2.9
const DOOR_M: float = 3.4
const SITE_SIDE_M: float = 3.8
const REFUSE_EXISTS: String = "the village has its infirmary already"
const REFUSE_BUILT: String = "it is built"
const REFUSE_NOT_PLANNED: String = "no infirmary is planned"

var state: int = STATE_NONE
var at: Vector2 = Vector2.ZERO
## Its yaw (radians): the way its front faces. Presentation.
var face: float = 0.0
var generation: int = 0
## Per material (MAT_*), milli-U.
var delivered: PackedInt64Array = PackedInt64Array()
var reserved: PackedInt64Array = PackedInt64Array()
var in_transit: PackedInt64Array = PackedInt64Array()
## Builders' demo time put in, microseconds.
var work_usec: int = 0
## Per resident: 1 while admitted to a bed (see THE BEDS).
var admitted: PackedByteArray = PackedByteArray()
var revision: int = 0

var _stores: StoresScript = null
var _care: StateScript = null
## `() -> int`: cloth the treatments already sent will take (milli-U), kept back from the building (the review's M1).
var cloth_held: Callable = Callable()


func _init(stores: StoresScript, care: StateScript, residents: int) -> void:
	"""No infirmary yet, fetched for from the village `stores` (wood, stone) and the `care` shelf (cloth), for this many
	residents."""
	_stores = stores
	_care = care
	for column: PackedInt64Array in [delivered, reserved, in_transit]:
		column.resize(Rules.MAT_COUNT)
	admitted.resize(residents)


func is_active() -> bool:
	"""Whether it is being fetched for or built."""
	return state == STATE_DELIVERING or state == STATE_BUILDING


func is_done() -> bool:
	"""Whether it is built."""
	return state == STATE_DONE


func plan_at(centre: Vector2, yaw: float) -> bool:
	"""Place it here (REQ-SET-124: nothing deducted); false when one is planned or built already."""
	if state != STATE_NONE:
		return false
	state = STATE_DELIVERING
	at = centre
	face = yaw
	generation += 1
	work_usec = 0
	_clear_books()
	revision += 1
	return true


func _clear_books() -> void:
	"""Nothing delivered, reserved, in transit or admitted."""
	for column: PackedInt64Array in [delivered, reserved, in_transit]:
		column.fill(0)
	admitted.fill(0)


# --- the sources ----------------------------------------------------------------------------------

func in_stock(mat: int) -> int:
	"""What of a material its source holds, milli-U."""
	match mat:
		Rules.MAT_WOOD:
			return _stores.wood_milli_u
		Rules.MAT_STONE:
			return _stores.stone_milli_u
	return _care.cloth_milli if _care != null else 0


func _take(mat: int, milli: int) -> bool:
	"""Take `milli` of a material from its source, all or nothing."""
	if mat == Rules.MAT_CLOTH:
		if _care == null or _care.cloth_milli < milli:
			return false
		_care.cloth_milli -= milli
		_care.revision += 1
		return true
	return _stores.pay(milli if mat == Rules.MAT_WOOD else 0, milli if mat == Rules.MAT_STONE else 0)


func _give(mat: int, milli: int) -> void:
	"""Put `milli` of a material back into its source."""
	if milli <= 0:
		return
	if mat == Rules.MAT_CLOTH:
		if _care != null:
			_care.cloth_milli += milli
			_care.revision += 1
		return
	_stores.refund(milli if mat == Rules.MAT_WOOD else 0, milli if mat == Rules.MAT_STONE else 0, 0)


# --- fetching ------------------------------------------------------------------------------------

func outstanding(mat: int) -> int:
	"""What of a material it still needs that nobody is fetching, milli-U."""
	if state != STATE_DELIVERING:
		return 0
	return maxi(0, Rules.cost_milli(mat) - delivered[mat] - reserved[mat] - in_transit[mat])


func fetchable(mat: int) -> int:
	"""What of a material a carrier could set off for now: still needed, and in its source unreserved, milli-U."""
	var held: int = int(cloth_held.call()) if mat == Rules.MAT_CLOTH and cloth_held.is_valid() else 0
	return mini(outstanding(mat), maxi(0, in_stock(mat) - reserved[mat] - held))


func next_material() -> int:
	"""The first material it needs that its source can give now, or NONE."""
	for mat: int in Rules.MAT_COUNT:
		if fetchable(mat) > 0:
			return mat
	return NONE


func reserve(mat: int, want_milli: int) -> int:
	"""Reserve up to `want_milli` of a material for a carrier setting off; how much."""
	var amount: int = mini(want_milli, fetchable(mat))
	if amount > 0:
		reserved[mat] += amount
		revision += 1
	return amount


func unreserve(mat: int, milli: int) -> void:
	"""Give a reservation back (a carrier called away before it lifted)."""
	reserved[mat] = maxi(0, reserved[mat] - milli)
	revision += 1


func lift(mat: int, reserved_amount: int) -> int:
	"""A carrier at the source lifts what it reserved -- as much as the source holds (REQ-SET-124: taken only now) -- and
	it is in transit; only while DELIVERING. Its reservation is spent either way; how much it carries."""
	unreserve(mat, reserved_amount)
	var amount: int = mini(reserved_amount, in_stock(mat))
	if state != STATE_DELIVERING or amount <= 0 or not _take(mat, amount):
		return 0
	in_transit[mat] += amount
	return amount


func deliver(mat: int, milli: int) -> bool:
	"""A load set down at the site -- only while DELIVERING; with everything delivered the building begins (REQ-SET-125).
	False, nothing changed, otherwise (the carrier puts it back: `return_load`)."""
	if state != STATE_DELIVERING or milli <= 0:
		return false
	in_transit[mat] = maxi(0, in_transit[mat] - milli)
	delivered[mat] += milli
	if all_delivered():
		state = STATE_BUILDING
	revision += 1
	return true


func return_load(mat: int, milli: int) -> void:
	"""A load a carrier did not deliver goes back into its source whole, and is no longer in transit."""
	if milli > 0:
		in_transit[mat] = maxi(0, in_transit[mat] - milli)
		_give(mat, milli)
		revision += 1


func all_delivered() -> bool:
	"""Whether every material it costs is at its site."""
	for mat: int in Rules.MAT_COUNT:
		if delivered[mat] < Rules.cost_milli(mat):
			return false
	return true


func add_work(usec: int) -> bool:
	"""A builder's demo time on it (only while it is being built); whether that finished it."""
	if state != STATE_BUILDING or usec <= 0:
		return false
	var before: int = percent()
	work_usec += usec
	if work_usec < Rules.work_usec():
		if percent() != before:
			revision += 1
		return false
	work_usec = Rules.work_usec()
	state = STATE_DONE
	revision += 1
	return true


func cancel() -> String:
	"""Take the planned infirmary away (REQ-SET-126): what was delivered goes back, all of it before the work began, 80%
	floored after. "" when done, else why not. Carriers on their way are the builders' to let go first."""
	if state == STATE_NONE:
		return REFUSE_NOT_PLANNED
	if state == STATE_DONE:
		return REFUSE_BUILT
	var begun: bool = work_usec > 0
	for mat: int in Rules.MAT_COUNT:
		_give(mat, Rules.refund_milli(delivered[mat], begun))
	state = STATE_NONE
	_clear_books()
	work_usec = 0
	revision += 1
	return ""


# --- the beds -------------------------------------------------------------------------------------

func beds_free() -> int:
	"""Patient beds free now (0 until it is built)."""
	if state != STATE_DONE:
		return 0
	var used: int = 0
	for i: int in admitted.size():
		used += admitted[i]
	return maxi(0, Rules.PATIENT_BEDS - used)


func admit(i: int) -> bool:
	"""Give resident `i` a bed; false when not built, full, or already in."""
	if i < 0 or i >= admitted.size() or admitted[i] == 1 or beds_free() <= 0:
		return false
	admitted[i] = 1
	revision += 1
	return true


func discharge(i: int) -> void:
	"""Resident `i` leaves its bed."""
	if i >= 0 and i < admitted.size() and admitted[i] == 1:
		admitted[i] = 0
		revision += 1


func is_admitted(i: int) -> bool:
	"""Whether resident `i` has a bed in it."""
	return i >= 0 and i < admitted.size() and admitted[i] == 1


# --- words and places -----------------------------------------------------------------------------

static func units_text(milli: int) -> String:
	"""Milli-U as tenths, floored ('8.0')."""
	@warning_ignore("integer_division")  # floored tenths by intent
	var tenths: int = milli / 100
	@warning_ignore("integer_division")  # whole units by intent
	var whole: int = tenths / 10
	return "%d.%d" % [whole, tenths % 10]


func cloth_committed() -> int:
	"""Cloth the building has reserved or has in a carrier's arms, milli-U (kept back from treatments)."""
	return reserved[Rules.MAT_CLOTH] + in_transit[Rules.MAT_CLOTH]


func percent() -> int:
	"""How far it has got, 0-100: the delivery is the first half, the work the second."""
	if state == STATE_DONE:
		return 100
	var need: int = 0
	var got: int = 0
	for mat: int in Rules.MAT_COUNT:
		need += Rules.cost_milli(mat)
		got += delivered[mat]
	@warning_ignore("integer_division")  # whole percent by intent
	var part: int = got * 50 / maxi(need, 1) + work_usec * 50 / maxi(Rules.work_usec(), 1)
	return mini(99, part)


func refund_text() -> String:
	"""What a cancel would return now, in words."""
	var begun: bool = work_usec > 0
	var parts := PackedStringArray()
	for mat: int in Rules.MAT_COUNT:
		parts.append("%s %s" % [units_text(Rules.refund_milli(delivered[mat], begun)), Rules.MAT_WORDS[mat]])
	return "returns %s%s" % [", ".join(parts), " (80%: the work has begun)" if begun else ""]


func status_text() -> String:
	"""'Infirmary: materials being fetched — wood 8.0 / 40.0, stone 0.0 / 30.0, cloth 0.0 / 12.0 (5%)', or built."""
	if state == STATE_NONE:
		return "No infirmary yet: the hurt rest in their own beds or by the hall"
	if state == STATE_DONE:
		return "%s: built — %d of %d patient beds free; patients mend at +4 health an hour here" % [Rules.LABEL,
			beds_free(), Rules.PATIENT_BEDS]
	var parts := PackedStringArray()
	for mat: int in Rules.MAT_COUNT:
		parts.append("%s %s / %s" % [Rules.MAT_WORDS[mat], units_text(delivered[mat]), units_text(Rules.cost_milli(mat))])
	return "%s: %s — %s (%d%%)" % [Rules.LABEL, STATE_WORDS[state], ", ".join(parts), percent()]


func door() -> Vector2:
	"""Where patients and healers go in: before its front."""
	return door_point(at, face)


func site() -> Vector2:
	"""Where its materials are set down: beside it."""
	return site_point(at, face)


static func door_point(centre: Vector2, yaw: float) -> Vector2:
	"""Its door, standing at `centre` turned `yaw`: before its front (+Z turned)."""
	return centre + Vector2(sin(yaw), cos(yaw)) * DOOR_M


static func site_point(centre: Vector2, yaw: float) -> Vector2:
	"""Its material site, standing at `centre` turned `yaw`: beside it."""
	return centre + Vector2(cos(yaw), -sin(yaw)) * SITE_SIDE_M
