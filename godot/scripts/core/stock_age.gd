extends RefCounted
## ARCH-SYS-004 StockAge: GDD §5.8's effective storage age and expiry, once per hour crossing.
##
## REQ-SET-007 fixes five daily legs -- age stocks, update ecology, advance crops/weather,
## process immigration/departures, evaluate progression -- IN THAT ORDER. This module is the
## FIRST leg's owner. Until now it had none: `settlement_system.gd`'s header said "age stocks
## NOT RUN" and `economy_system.gd` said lot ages stay at 0 because nothing advanced them.
##
## ---------------------------------------------------------------------------------------
## THE CADENCE IS AN HOUR CROSSING, NOT A DAY. `systems_architecture.md`'s §5 row reads
## "Hour crossing and expiry crossing; midnight first", so this runs 24 times a simulated day
## and NOT once at midnight. Applying a per-hour rate at midnight would be a 24x error, which is
## the mistake `crop_weather.gd` records having made once for REQ-SET-084 frost.
##
## The calendar is OFFSET, so the crossing predicate is `(tick + 4500) mod 750 == 0` and NEVER
## `tick mod 18000 == 0`. `is_hour_boundary()` here DELEGATES to `crop_weather.gd`'s, rather
## than restating the arithmetic: ARCH-SYS-004 and ARCH-SYS-006 both run on the same crossing
## and two copies of one predicate can drift apart, while one copy cannot. Every midnight is
## also an hour crossing (`(13500 + 4500) mod 750 == 0`), which is what lets ARCH-TICK-002's
## "never perform a second age pass just because the same tick is both hourly and daily" hold
## for free: `_last_hour_tick` consumes the tick once, so the midnight leg either finds the
## hourly pass already done or runs it, never both.
##
## MIDNIGHT USES THE ELAPSED INTERVAL'S SEASON, AND THE CALLER CANNOT GET IT WRONG.
## ARCH-TICK-003: "aging uses the season in the elapsed interval; ecology uses the new calendar
## day's season". The interval being integrated is `(tick-1, tick]`, so the season is decoded
## from `tick - 1` INSIDE `run_hour_into()` rather than accepted as a parameter. At the first
## midnight of a season that is last season; at every other crossing the two are equal.
##
## ---------------------------------------------------------------------------------------
## WHAT GDD §5.8 SETTLES, AND WHAT IS IMPLEMENTED HERE:
##
##   * Base age per game hour is 1000 milli-hours; store factor open pile 1500, covered store
##     1000, pantry 750, cellar 350; seasonal temperature factor spring 1000 / summer 1500 /
##     autumn 1000 / winter 500, with heated interiors using 1000 in winter. Effective age per
##     hour is `floor(store_factor * temperature_factor / 1000)`, retaining tick fractions.
##     IMPLEMENTED. The fraction is retained per lot in `inventory.gd`'s `age_remainder`.
##   * "Changing stores never resets age" (REQ-SET-107). IMPLEMENTED BY OMISSION: nothing in
##     move, transfer, split, merge or the equip pair writes either age column, and the only
##     writer that exists is this stage.
##   * "Unlimited shelf items have shelf_hours=0 and do not spoil". IMPLEMENTED: an item whose
##     catalog shelf life is 0 still AGES -- age is a stored fact -- and never expires.
##   * "When age reaches shelf_hours x 1000, food becomes spoiled_food at identical mass".
##     IMPLEMENTED, as an in-place conversion of the same lot row at the exactly equal gram
##     mass, refusing rather than rounding when the two catalog masses do not divide exactly.
##   * "Spoiled_food lasts 240h then is removed as waste with a notice". THE REMOVAL IS
##     IMPLEMENTED; THE NOTICE IS NOT, and is counted in `notices_owed` instead of being
##     invented: ARCH-SYS-021 ForecastNotice owns the Notice/NoticeCondition rows and no
##     Notice store exists in this repository.
##   * STOCK-SEED-R01's expired seed -> compost conversion. IMPLEMENTED, per lot, as
##     `floor_div(checked_mul(seed_quantity_milli, seed_mass_g), compost_mass_g)` with EXACTLY
##     ONE final floor. The divisor is DERIVED from the two catalog masses and appears nowhere
##     as a literal: with today's five 100 g/U seeds and 1000 g/U compost that is
##     `floor(q/10)`, and a catalog edit moves it without editing this file. The sub-output-unit
##     remainder is DECAY LOSS: the ENTIRE seed quantity is sunk and only the floored compost
##     quantity sourced, so the per-item ledgers carry the loss instead of it vanishing. A lot
##     whose output floors to zero RETIRES -- the seed is sunk and no zero-quantity compost lot
##     is created. No cross-lot remainder carry and no remainder store exist, which is what
##     makes `sum(floor(q_i*sm/cm)) <= floor(sum(q_i)*sm/cm)` hold: splitting cannot gain.
##   * REQ-SET-108's "invalidate its food reservations". IMPLEMENTED to the extent that
##     reservations exist: `inventory.gd` implements GDD §4.2's per-lot `reserved_milli` and
##     this stage releases all of it inside the same transaction as the conversion. The
##     Reservation ROW store (job, lot, quantity, expiry, purpose) is blocked by U4/U5 and is
##     not built, so no job-side claim can be invalidated by job id yet -- REQ-SET-116's stable
##     job-ID order has nothing to order.
##
## WHAT IS NOT IMPLEMENTED, EACH BECAUSE SOMETHING IS GENUINELY UNDECIDED OR ABSENT:
##
##   1. WHICH STORE A CONTAINER IS. §5.8 gives four store factors by STORE KIND -- open pile,
##      covered store, pantry, cellar -- and §5.9 gives those kinds to BUILDINGS and furniture.
##      ARCH-SYS-004's own row lists "storage factors" under READS, so their owner is the
##      Building/Room layer (ARCH-SYS-016 RoomHeat and the building store), which does not
##      exist here. Rather than guess a factor per container, this stage holds an explicit,
##      generation-validated DECLARATION per container that the building layer will make when
##      it lands. AN UNDECLARED CONTAINER IS NOT AGED AND IS NOT SILENTLY SKIPPED: it is
##      absent from the sweep and reported in `HourResult.undeclared_containers`, so the gap is
##      measured every hour instead of looking like freshness.
##   2. WHETHER A ROOM IS HEATED. "Heated interiors use 1000 in winter" needs the RoomHeat
##      result, which has no store. `declare_storage_class()` takes the flag from its caller and
##      defaults it to false; this module never decides it.
##   3. STOCK-SEED-R01'S SEED-CONSUMER ELIGIBILITY GUARD. The ruling requires every
##      seed-consuming path -- new reservation, withdrawal, transfer into production, seed
##      selection and the sowing/work commit, including reservations taken before the lot aged
##      out -- to REJECT a lot whose persisted age has reached its catalog shelf threshold, and
##      it gives ENFORCEMENT to Inventory ("Inventory owns enforcement for quantity admission").
##      `inventory.gd` is not this module's file. What is supplied here is the predicate itself,
##      `refuses_seed_consumption()`, derived from persisted age and the item definition with no
##      new per-lot flag, fail-closed so a lot it cannot evaluate is never admitted. NOTHING
##      CALLS IT YET, and no seed consumer in this repository is guarded: that is a named,
##      unclosed handoff to the Inventory owner, not a solved problem.
##   4. STOCK-SEED-R01'S BLOCKING INTEGRITY PAUSE. "Arithmetic, ledger or schema failure is a
##      blocking integrity fault through the existing critical-pause path", with an
##      exactly-once revalidated retry of the SAME expiry transaction. The critical-pause path
##      belongs to ARCH-SYS-001/SettlementSystem, which calls this stage; a refused lot is
##      counted in `refused_lots` and named in `last_lot_refusal` with the store left byte
##      identical, and this module invents neither a pause nor a retry ledger.
##   5. "TRIGGER RECIPE/MEAL REPLANNING" (REQ-SET-108). There is no recipe store, no order
##      store and no meal plan to replan; ARCH-SYS-014 BatchCompletion and ARCH-SYS-009's
##      production side do not exist. Each conversion increments `replans_owed` so the future
##      owner has the count, and nothing here pretends to notify anybody.
##   6. "INVALID LEASES" in the §5 Writes column. ARCH-JOB-004's travel leases have no store.
##   7. MERGING THE PRODUCED WASTE. Two lots that both become spoiled_food in the same
##      container are NOT merged here. §5.8's merge rule requires identical quality, recipe and
##      provenance, which the conversion CARRIES from each source, so they are frequently not
##      mergeable at all; REQ-SET-120 makes merging a response to reaching the lot cap, and
##      that cap belongs to whoever owns the cap response. Reported, not guessed.
##
## AN EQUIPPED LOT IS NOT AGED, AND THAT IS A NAMED GAP RATHER THAN A DECISION. Decision 0061
## gives a live lot with a null container exactly one meaning: it is an equipped record held by
## a resident. Such a lot is in NO store, and §5.8 defines age as effective STORAGE age through
## a store factor. §5.8 and §5.9 name the two non-container cases they do cover -- prepared food
## on tables takes the open-pile factor, ground piles take 1500 -- and name nothing for
## equipment, so there is no factor to apply and inventing one is exactly what this repository
## forbids. Equipped lots are threaded into no container chain, so this sweep cannot reach one,
## and `inventory.gd` refuses `LOT_EQUIPPED` if anything tries. WHY THE GAP IS CURRENTLY
## UNOBSERVABLE, and where it stops being so: `gear.gd`'s `is_instance_required_item()` admits
## exactly tool, net, trap, ice_kit and outfit_tier2, and all five carry `shelf_hours = 0`,
## which §5.8 says do not spoil. `test_stock_age.gd` asserts that invariant directly, so the
## day a spoiling item becomes equippable the gap becomes real AND a test says so.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. The hourly pass allocates NOTHING of its own on an ordinary hour: the declared
## list is walked as packed integers, the two calendar objects and the IntResult are instance
## scratch, and `inventory.gd`'s `_into` forms write into that scratch. A lot that ACTUALLY
## EXPIRES costs four OpResults inside `inventory.gd` -- begin, the reservation release, the
## conversion or sink, and commit -- which is that module's published per-operation contract and
## happens once in a lot's life, not once an hour.
##
## REFUSAL, NOT SENTINELS. `run_hour_into()` writes into a caller-owned HourResult whose `.ok`
## must be inspected; a refusal clears every count so an unchecked result cannot surface the
## previous hour's numbers. A per-lot refusal does NOT abort the hour -- one unconvertible lot
## is not a reason to leave every other lot unaged -- and is counted and named on the result.
## ALLOCATE BEFORE CONSUME (decision 0059): every per-lot mutation runs inside one
## `inventory.gd` transaction, so a refused conversion rolls back to a byte-identical store.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_NOT_HOUR_BOUNDARY: StringName = &"NOT_AN_HOUR_BOUNDARY"
const REFUSE_HOUR_ALREADY_RUN: StringName = &"STOCK_AGE_HOUR_ALREADY_RUN"
const REFUSE_NO_INVENTORY: StringName = &"INVENTORY_NOT_BOUND"
const REFUSE_NO_ITEM_CATALOG: StringName = &"ITEM_CATALOG_NOT_BOUND"
const REFUSE_INVALID_CONTAINER: StringName = &"INVALID_CONTAINER"
const REFUSE_INVALID_STORAGE_CLASS: StringName = &"INVALID_STORAGE_CLASS"
const REFUSE_NOT_DECLARED: StringName = &"CONTAINER_NOT_DECLARED"
const REFUSE_TRANSACTION_OPEN: StringName = &"INVENTORY_TRANSACTION_OPEN"
## STOCK-SEED-R01's conversion needs positive validated catalog masses and a product that fits
## int64. Neither holding is a reason to write a plausible compost quantity.
const REFUSE_SEED_YIELD_UNREPRESENTABLE: StringName = &"SEED_COMPOST_YIELD_UNREPRESENTABLE"
## REQ-SET-108's "equal mass" is only representable when the two catalog masses divide exactly.
const REFUSE_MASS_NOT_CONVERTIBLE: StringName = &"SPOILAGE_MASS_NOT_CONVERTIBLE"

## Tick 0 is 06:00 of day 1 and is no hour crossing, so -1 names no tick the pass has run at.
## Read from `crop_weather.gd` rather than restated, for the same reason as the predicate.
const NO_HOUR_RUN: int = CropWeatherScript.NO_HOUR_RUN

## GDD §5.8's storage classes. 0 is NOT a class: it is the value a container that nobody has
## declared still holds, and such a container is never aged.
const STORAGE_UNDECLARED: int = 0
const STORAGE_OPEN_PILE: int = 1
const STORAGE_COVERED_STORE: int = 2
const STORAGE_PANTRY: int = 3
const STORAGE_CELLAR: int = 4
const STORAGE_CLASS_COUNT: int = 5

## GDD §5.8's store factors, indexed by the class ids above. Index 0 has no factor because an
## undeclared container has no store kind; `store_factor_of()` refuses it rather than reading 0.
## §5.9 gives a ground pile the open-pile 1500, and §5.8 gives prepared food left on tables the
## same, so both are STORAGE_OPEN_PILE and neither needs a fifth number.
const STORE_FACTOR: Array[int] = [0, 1500, 1000, 750, 350]

## GDD §5.8's seasonal temperature factors, indexed by `sim_clock.gd`'s season order
## (spring, summer, autumn, winter).
const TEMPERATURE_FACTOR: Array[int] = [1000, 1500, 1000, 500]
## "heated interiors use 1000 in winter" -- the one exception, and only in winter.
const HEATED_WINTER_TEMPERATURE_FACTOR: int = 1000
const SEASON_WINTER: int = 3

## Milli-hours of age one game hour costs at store factor 1000 in an unmodified season.
const MILLI_HOURS_PER_HOUR: int = 1000

## Catalog keys this stage must resolve to run §5.8's conversions. They are KEYS, never compiled
## ids: BAL-CAT-001 compiles ids from sorted ASCII keys, so no number may be written here.
const SPOILED_FOOD_KEY: StringName = &"spoiled_food"
## STOCK-SEED-R01's expiry output. The 10:1 ratio today's catalog produces is DERIVED from this
## item's mass and the seed's, never written down: a catalog edit must move the yield, not be
## silently overridden by a constant here.
const COMPOST_KEY: StringName = &"compost"

## One declaration row per `inventory.gd` container slot, so a lookup is an index and never a
## search. Sized from the inventory's own capacity constant, so the two cannot drift.
const CONTAINER_CAPACITY: int = InventoryScript.CONTAINER_CAPACITY

## `inventory.gd`'s null slot, read from it rather than restated.
const NULL_SLOT: int = InventoryScript.NULL_SLOT
const NULL_REF: Vector2i = InventoryScript.NULL_REF


class HourResult:
	"""One completed hourly aging pass: which hour it was, and exactly what it changed.

	`.ok` MUST be inspected before any count is read. A refusal clears every field, so an
	unchecked result cannot surface a previous hour's numbers as if they were this hour's.
	"""
	var ok: bool
	var error: StringName
	var tick: int
	var absolute_day: int
	var hour: int
	## ARCH-TICK-003's season of the ELAPSED interval, which at a midnight tick is not the
	## season the day now beginning carries.
	var season: int
	var containers_aged: int
	var undeclared_containers: int
	var lots_aged: int
	var lots_expired: int
	var reservations_invalidated_milli: int
	var waste_removed_lots: int
	var waste_removed_milli: int
	## STOCK-SEED-R01. `seed_lots_converted` is also counted in `lots_expired`, because a
	## converted seed row IS an expired lot that became another item; a retired zero-yield seed
	## is not, because no row survived the hour to have become anything.
	var seed_lots_converted: int
	var seed_lots_retired: int
	var seed_sunk_milli: int
	var compost_sourced_milli: int
	## The floored-away remainder, in MILLI-GRAMS of nominal seed mass, reported so the decay
	## loss is a measured number rather than a silent one. It is a per-hour report, never a
	## store: STOCK-SEED-R01 forbids an authoritative mass-remainder field.
	var seed_decay_loss_milli_g: int
	var refused_lots: int
	## REQ-SET-108's replanning and §5.8's removal notice, both owed to owners that do not exist.
	var replans_owed: int
	var notices_owed: int
	var last_lot_refusal: StringName

	func _init() -> void:
		"""Start cleared; every field is written by the hour step before it returns."""
		clear()

	func clear() -> void:
		"""Return every field to its empty value, so nothing survives from a previous hour."""
		ok = false
		error = REFUSE_NONE
		tick = 0
		absolute_day = 0
		hour = 0
		season = 0
		containers_aged = 0
		undeclared_containers = 0
		lots_aged = 0
		lots_expired = 0
		reservations_invalidated_milli = 0
		waste_removed_lots = 0
		waste_removed_milli = 0
		seed_lots_converted = 0
		seed_lots_retired = 0
		seed_sunk_milli = 0
		compost_sourced_milli = 0
		seed_decay_loss_milli_g = 0
		refused_lots = 0
		replans_owed = 0
		notices_owed = 0
		last_lot_refusal = REFUSE_NONE

	func refuse(code: StringName) -> bool:
		"""Record a refusal that carries no counts. Always returns false."""
		clear()
		error = code
		return false


# --- the declaration store (ARCH-MEM-001: packed columns, allocated once) ----------------------
#
# Indexed by `inventory.gd` CONTAINER SLOT. `_c_declared_generation` holds the container
# generation the declaration was made against, which is what stops a recycled slot inheriting
# the storage class of the container that used to live there -- `inventory.gd` runs its own
# generation space for containers, separate from the entity directory's.

var _c_storage_class: PackedByteArray = PackedByteArray()
var _c_heated_interior: PackedByteArray = PackedByteArray()
var _c_declared_generation: PackedInt32Array = PackedInt32Array()
## Dense list of the container slots that carry a live declaration, so the hourly sweep visits
## declared containers only and never scans 101376 rows.
var _declared_slots: PackedInt32Array = PackedInt32Array()
var _declared_count: int = 0

# --- bound collaborators (not owned, never cleared from here) ----------------------------------

var _inventory: InventoryScript = null
var _definitions: ItemDefinitionsScript = null

# --- the idempotence latch ---------------------------------------------------------------------

var _last_hour_tick: int = NO_HOUR_RUN

# --- scratch (not simulation state) ------------------------------------------------------------

var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _last_refusal: StringName = REFUSE_NONE
var _spoiled_food_id: int = -1
var _compost_id: int = -1
## The two §5.8 factors in force for the container currently being swept. Fixed once per
## container by `_resolve_hour_factors()` and read by every lot in its chain.
var _store_factor: int = 0
var _temperature_factor: int = 0


func _init(p_inventory: InventoryScript = null,
		p_definitions: ItemDefinitionsScript = null) -> void:
	"""Allocate the declaration columns once and bind the two stores this stage reads."""
	_c_storage_class.resize(CONTAINER_CAPACITY)
	_c_heated_interior.resize(CONTAINER_CAPACITY)
	_c_declared_generation.resize(CONTAINER_CAPACITY)
	_declared_slots.resize(CONTAINER_CAPACITY)
	_inventory = p_inventory
	_definitions = p_definitions
	_assert_shared_contracts()
	clear()


func _assert_shared_contracts() -> void:
	"""Prove the cadence and table facts this file reads out of other modules."""
	assert(STORE_FACTOR.size() == STORAGE_CLASS_COUNT,
		"every storage class must carry exactly one GDD §5.8 store factor")
	assert(TEMPERATURE_FACTOR.size() == SimClock.SEASONS_PER_YEAR,
		"every season must carry exactly one GDD §5.8 temperature factor")
	assert(SimClock.SEASON_NAMES[SEASON_WINTER] == "winter",
		"the heated-interior exception must index the season the GDD calls winter")
	assert(is_hour_boundary(SimClock.FIRST_MIDNIGHT_TICK),
		"every midnight is also an hour crossing, which is what makes 'midnight first' one pass")


func clear() -> void:
	"""Drop every declaration and the hourly latch, without reallocating a column."""
	_c_storage_class.fill(STORAGE_UNDECLARED)
	_c_heated_interior.fill(0)
	_c_declared_generation.fill(0)
	_declared_slots.fill(NULL_SLOT)
	_declared_count = 0
	_last_hour_tick = NO_HOUR_RUN
	_last_refusal = REFUSE_NONE
	_spoiled_food_id = -1
	_compost_id = -1


func bind_stores(p_inventory: InventoryScript, p_definitions: ItemDefinitionsScript) -> bool:
	"""Bind -- or with nulls, unbind -- the inventory and item catalog this stage reads.

	Refused while an inventory transaction is open, because rebinding mid-transaction would
	leave a half-applied sequence with nobody able to roll it back.

	BINDING A DIFFERENT INVENTORY DROPS EVERY DECLARATION. The declarations are keyed on the
	OLD store's container slots and generations; carried across, slot 4 of a new inventory would
	inherit the storage class of a container it has never held.
	"""
	if p_inventory != null and p_inventory.is_transaction_open():
		return _refuse(REFUSE_TRANSACTION_OPEN)
	if p_inventory != _inventory:
		clear()
	_inventory = p_inventory
	_definitions = p_definitions
	_spoiled_food_id = -1
	_compost_id = -1
	_last_refusal = REFUSE_NONE
	return true


# --- GDD §5.8's two factor tables ---------------------------------------------------------------

static func is_storage_class(storage_class: int) -> bool:
	"""True for one of §5.8's four declared store kinds. STORAGE_UNDECLARED is not one."""
	return storage_class > STORAGE_UNDECLARED and storage_class < STORAGE_CLASS_COUNT


static func store_factor_into(storage_class: int, out: IntMath.IntResult) -> bool:
	"""§5.8's store factor for a declared storage class, into a caller-owned result.

	Refuses an undeclared or unknown class rather than answering 0: a zero factor is a
	perfectly plausible-looking "this never ages", and that is exactly the silent wrong answer
	an undeclared container must not produce.
	"""
	if not is_storage_class(storage_class):
		return out.refuse(String(REFUSE_INVALID_STORAGE_CLASS))
	return out.succeed(STORE_FACTOR[storage_class])


static func temperature_factor_of(season: int, heated_interior: bool) -> int:
	"""§5.8's seasonal temperature factor, with the heated-interior exception applied in winter.

	"Seasonal temperature factor spring 1000/summer 1500/autumn 1000/winter 500; heated
	interiors use 1000 in winter." The exception is winter-only: a heated interior in summer
	still takes the summer factor, because §5.8 grants the substitution for winter alone.
	"""
	if season < 0 or season >= TEMPERATURE_FACTOR.size():
		return 0
	if heated_interior and season == SEASON_WINTER:
		return HEATED_WINTER_TEMPERATURE_FACTOR
	return TEMPERATURE_FACTOR[season]


# --- the storage-class declarations --------------------------------------------------------------

func declare_storage_class(container_ref: Vector2i, storage_class: int,
		heated_interior: bool = false) -> bool:
	"""Record which of §5.8's store kinds a container is, so its contents can be aged.

	THE BUILDING LAYER IS THE REAL OWNER OF THIS FACT (module header, gap 1). This is the seam
	it will write through; until it exists, a container nobody declares is not aged and is
	counted as undeclared every hour rather than quietly treated as fresh.
	"""
	if _inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if not _inventory.is_container_valid(container_ref):
		return _refuse(REFUSE_INVALID_CONTAINER)
	if not is_storage_class(storage_class):
		return _refuse(REFUSE_INVALID_STORAGE_CLASS)
	var slot: int = container_ref.x
	if _c_storage_class[slot] == STORAGE_UNDECLARED:
		_declared_slots[_declared_count] = slot
		_declared_count += 1
	_c_storage_class[slot] = storage_class
	_c_heated_interior[slot] = 1 if heated_interior else 0
	_c_declared_generation[slot] = container_ref.y
	_last_refusal = REFUSE_NONE
	return true


func withdraw_storage_class(container_ref: Vector2i) -> bool:
	"""Remove a container's declaration, so its contents stop being aged from the next hour."""
	if _inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	var slot: int = container_ref.x
	if slot < 0 or slot >= CONTAINER_CAPACITY:
		return _refuse(REFUSE_INVALID_CONTAINER)
	if _c_storage_class[slot] == STORAGE_UNDECLARED:
		return _refuse(REFUSE_NOT_DECLARED)
	if _c_declared_generation[slot] != container_ref.y:
		return _refuse(REFUSE_INVALID_CONTAINER)
	_drop_declaration(_index_of_declared(slot))
	_last_refusal = REFUSE_NONE
	return true


func _index_of_declared(slot: int) -> int:
	"""Position of `slot` in the dense declared list, or -1. Linear, and never on the hot path.

	The hourly sweep walks the dense list by index and drops a stale entry with the index it
	already holds, so this search only runs for an explicit withdrawal.
	"""
	for index: int in _declared_count:
		if _declared_slots[index] == slot:
			return index
	return -1


func _drop_declaration(index: int) -> void:
	"""Clear the declaration at dense position `index` and swap the last entry into its place."""
	if index < 0 or index >= _declared_count:
		return
	var slot: int = _declared_slots[index]
	_c_storage_class[slot] = STORAGE_UNDECLARED
	_c_heated_interior[slot] = 0
	_c_declared_generation[slot] = 0
	_declared_count -= 1
	_declared_slots[index] = _declared_slots[_declared_count]
	_declared_slots[_declared_count] = NULL_SLOT


func storage_class_of(container_ref: Vector2i) -> int:
	"""Declared storage class of a container, or STORAGE_UNDECLARED for anything else.

	A slot whose declaration was made against an older generation reads as undeclared: the
	container that owned that declaration is gone, and the row belongs to a different one.
	"""
	var slot: int = container_ref.x
	if slot < 0 or slot >= CONTAINER_CAPACITY:
		return STORAGE_UNDECLARED
	if _c_declared_generation[slot] != container_ref.y:
		return STORAGE_UNDECLARED
	return _c_storage_class[slot]


func is_heated_interior(container_ref: Vector2i) -> bool:
	"""True when a declared container was declared as sitting in a heated interior."""
	if storage_class_of(container_ref) == STORAGE_UNDECLARED:
		return false
	return _c_heated_interior[container_ref.x] == 1


func declared_container_count() -> int:
	"""Number of containers carrying a declaration, stale ones included until swept."""
	return _declared_count


# --- the hourly cadence ---------------------------------------------------------------------------

static func is_hour_boundary(tick: int) -> bool:
	"""True when `tick` is the first tick of a new game hour under the offset calendar.

	DELEGATED to `crop_weather.gd`'s predicate on purpose. ARCH-TICK-002's `(k+4500) mod 750=0`
	is one crossing shared by ARCH-SYS-004 and ARCH-SYS-006, and a second copy of it here could
	drift by a tick without either file looking wrong.
	"""
	return CropWeatherScript.is_hour_boundary(tick)


func run_hour(tick: int) -> HourResult:
	"""Run one hourly aging pass. See run_hour_into(); this form allocates one result."""
	var out: HourResult = HourResult.new()
	run_hour_into(tick, out)
	return out


func run_hour_into(tick: int, out: HourResult) -> bool:
	"""ARCH-SYS-004 at one hour crossing, into caller-owned `out`.

	`tick` is the tick being committed. The season read is the ELAPSED interval's (ARCH-TICK-003)
	and is decoded from `tick - 1` here rather than taken from the caller, so a midnight pass
	cannot be handed the new day's season by mistake. The hour is consumed before any lot is
	touched, so a replay refuses rather than aging the same sixty minutes twice.
	"""
	out.clear()
	if tick < 0:
		return out.refuse(REFUSE_INVALID_TICK)
	if not is_hour_boundary(tick):
		return out.refuse(REFUSE_NOT_HOUR_BOUNDARY)
	if tick <= _last_hour_tick:
		return out.refuse(REFUSE_HOUR_ALREADY_RUN)
	var ready: StringName = _preflight()
	if ready != REFUSE_NONE:
		return out.refuse(ready)
	_last_hour_tick = tick
	SimClock.calendar_at_into(tick, _calendar)
	out.tick = tick
	out.absolute_day = _calendar.absolute_day
	out.hour = _calendar.hour
	SimClock.calendar_at_into(tick - 1, _calendar)
	out.season = _calendar.season
	_sweep_declared_containers(out)
	out.ok = true
	return true


func _preflight() -> StringName:
	"""Every input this pass needs, checked before the hour latch is consumed.

	The spoiled_food and compost ids are resolved BY KEY from the compiled catalog and cached for
	the run: a catalog with no such item cannot honour §5.8's or STOCK-SEED-R01's conversion at
	all, and refusing here is better than discovering it per lot after half the store has aged.
	"""
	if _inventory == null:
		return REFUSE_NO_INVENTORY
	if _inventory.is_transaction_open():
		return REFUSE_TRANSACTION_OPEN
	if _definitions == null or not _definitions.is_loaded():
		return REFUSE_NO_ITEM_CATALOG
	if _spoiled_food_id < 0:
		_spoiled_food_id = _definitions.compiled_id(SPOILED_FOOD_KEY)
	if _compost_id < 0:
		_compost_id = _definitions.compiled_id(COMPOST_KEY)
	if _spoiled_food_id < 0 or _compost_id < 0:
		return REFUSE_NO_ITEM_CATALOG
	return REFUSE_NONE


func _sweep_declared_containers(out: HourResult) -> void:
	"""Age every lot in every live declared container, dropping declarations that went stale.

	The walk is over the DENSE declared list, not over the 101376 container rows: an hour
	crossing costs one pass over the containers somebody actually declared. A slot whose
	container has been destroyed or recycled is dropped in place, and the entry swapped into
	its position is visited on the same iteration because the index does not advance.
	"""
	out.undeclared_containers = _inventory.live_container_count()
	var index: int = 0
	while index < _declared_count:
		var slot: int = _declared_slots[index]
		var ref: Vector2i = Vector2i(slot, _c_declared_generation[slot])
		if not _inventory.is_container_valid(ref):
			_drop_declaration(index)
			continue
		out.containers_aged += 1
		out.undeclared_containers -= 1
		_age_one_container(ref, out)
		index += 1


func _age_one_container(container_ref: Vector2i, out: HourResult) -> void:
	"""One hour of §5.8 age for every lot in one declared container.

	The two factors are decided ONCE per container rather than per lot: both depend on the store
	and the season, neither depends on the lot. The next lot is read BEFORE the current one is
	touched, because an expiring lot can be removed from the chain.
	"""
	if not _resolve_hour_factors(container_ref, out.season):
		return
	var lot: Vector2i = _inventory.container_first_lot(container_ref)
	while lot.x != NULL_SLOT:
		var next: Vector2i = _inventory.container_next_lot(lot)
		_age_one_lot(lot, out)
		lot = next


func _resolve_hour_factors(container_ref: Vector2i, season: int) -> bool:
	"""Fix `_store_factor` and `_temperature_factor` for this container this hour.

	False means §5.8 supplies no factor for this container -- an undeclared class, or a season
	outside the calendar -- and the caller then ages nothing. No substitute number is written:
	the two scratch fields keep their previous values and are not read after a false answer.
	"""
	if not store_factor_into(_c_storage_class[container_ref.x], _math):
		return false
	var temperature: int = temperature_factor_of(season,
		_c_heated_interior[container_ref.x] == 1)
	if temperature <= 0:
		return false
	_store_factor = _math.value
	_temperature_factor = temperature
	return true


func _age_one_lot(lot_ref: Vector2i, out: HourResult) -> void:
	"""Fold one hour into one lot's age, then expire it if §5.8 says its shelf life is over."""
	if not _inventory.advance_lot_age_hour_into(lot_ref, _store_factor,
			_temperature_factor, _math):
		out.refused_lots += 1
		out.last_lot_refusal = StringName(_math.error)
		return
	var aged: int = _math.value
	out.lots_aged += 1
	var threshold: int = _shelf_threshold_milli_hours(_inventory.lot_item_id(lot_ref))
	if threshold <= 0:
		return
	if aged < threshold:
		return
	_expire_one_lot(lot_ref, out)


func _shelf_threshold_milli_hours(item_id: int) -> int:
	"""Milli-hours of age at which §5.8 says this item is over: `shelf_hours * 1000`, or 0.

	Zero means "unlimited shelf" (§5.8's `shelf_hours = 0`) and is the ONE value that must never
	be compared against as a threshold; both callers test it before comparing. Shared so the
	hourly expiry boundary and STOCK-SEED-R01's consumer guard cannot come to disagree about
	which tick a lot crossed.
	"""
	var shelf_hours: int = _definitions.shelf_hours(item_id)
	if shelf_hours <= 0:
		return 0
	return shelf_hours * MILLI_HOURS_PER_HOUR


func _expire_one_lot(lot_ref: Vector2i, out: HourResult) -> void:
	"""Route an expired lot to the outcome GDD §5.8 gives its item class.

	Three outcomes and no fourth: spoiled_food is REMOVED as waste; a seed becomes compost under
	STOCK-SEED-R01's floored nominal-mass yield; everything else becomes spoiled_food at
	identical mass. The seed test precedes the general one because a seed is not food waste.
	"""
	var item_id: int = _inventory.lot_item_id(lot_ref)
	if item_id == _spoiled_food_id:
		_remove_expired_waste(lot_ref, out)
		return
	if _definitions.is_seed(item_id):
		_convert_expired_seed(lot_ref, item_id, out)
		return
	_convert_to_spoiled_food(lot_ref, item_id, out)


func _remove_expired_waste(lot_ref: Vector2i, out: HourResult) -> void:
	"""§5.8: "Spoiled_food lasts 240h then is removed as waste with a notice".

	The notice is OWED, not issued: ARCH-SYS-021 owns Notice rows and there is no Notice store.
	"""
	var quantity: int = _inventory.lot_quantity_milli(lot_ref)
	if not _begin_lot_transaction():
		out.refused_lots += 1
		out.last_lot_refusal = _last_refusal
		return
	_inventory.release_all_reservations(lot_ref)
	_inventory.sink_lot_quantity(lot_ref, quantity)
	var committed: InventoryScript.OpResult = _inventory.commit()
	if not committed.ok:
		out.refused_lots += 1
		out.last_lot_refusal = committed.error
		return
	out.waste_removed_lots += 1
	out.waste_removed_milli += quantity
	out.notices_owed += 1


func _convert_to_spoiled_food(lot_ref: Vector2i, item_id: int, out: HourResult) -> void:
	"""REQ-SET-108: invalidate the lot's reservations and convert it to spoiled_food, equal mass.

	The whole sequence is ONE inventory transaction, so a conversion that cannot be completed
	leaves the store byte identical rather than releasing a claim on food that is still food.
	"""
	if not equal_mass_quantity_into(_inventory.lot_quantity_milli(lot_ref),
			_inventory.item_mass_g(item_id), _inventory.item_mass_g(_spoiled_food_id), _math):
		out.refused_lots += 1
		out.last_lot_refusal = REFUSE_MASS_NOT_CONVERTIBLE
		return
	var converted: int = _math.value
	var reserved: int = _inventory.lot_reserved_milli(lot_ref)
	if not _begin_lot_transaction():
		out.refused_lots += 1
		out.last_lot_refusal = _last_refusal
		return
	_inventory.release_all_reservations(lot_ref)
	_inventory.transform_lot_item(lot_ref, _spoiled_food_id, converted)
	var committed: InventoryScript.OpResult = _inventory.commit()
	if not committed.ok:
		out.refused_lots += 1
		out.last_lot_refusal = committed.error
		return
	out.lots_expired += 1
	out.reservations_invalidated_milli += reserved
	out.replans_owed += 1


func _convert_expired_seed(lot_ref: Vector2i, item_id: int, out: HourResult) -> void:
	"""STOCK-SEED-R01: one expired seed lot becomes compost by exact floored nominal mass.

	PER LOT, and nothing about the containing stack: the yield is computed from THIS row's
	quantity, so `sum(floor(q_i*sm/cm)) <= floor(sum(q_i)*sm/cm)` and splitting a lot can never
	manufacture compost. The two masses are read from the inventory's registered catalog, so no
	ratio is written here for a future catalog edit to invalidate.
	"""
	var quantity: int = _inventory.lot_quantity_milli(lot_ref)
	var seed_mass_g: int = _inventory.item_mass_g(item_id)
	var compost_mass_g: int = _inventory.item_mass_g(_compost_id)
	if not expiry_compost_quantity_into(quantity, seed_mass_g, compost_mass_g, _math):
		out.refused_lots += 1
		out.last_lot_refusal = REFUSE_SEED_YIELD_UNREPRESENTABLE
		return
	var compost_milli: int = _math.value
	if not expiry_decay_loss_milli_g_into(quantity, seed_mass_g, compost_mass_g, _math):
		out.refused_lots += 1
		out.last_lot_refusal = REFUSE_SEED_YIELD_UNREPRESENTABLE
		return
	var decay_loss_milli_g: int = _math.value
	if compost_milli == 0:
		_retire_zero_yield_seed(lot_ref, quantity, decay_loss_milli_g, out)
		return
	_transform_seed_to_compost(lot_ref, quantity, compost_milli, decay_loss_milli_g, out)


func _transform_seed_to_compost(lot_ref: Vector2i, quantity_milli: int, compost_milli: int,
		decay_loss_milli_g: int, out: HourResult) -> void:
	"""Commit a positive seed -> compost conversion as ONE atomic inventory transaction.

	The whole seed quantity is SUNK and only `compost_milli` SOURCED by `transform_lot_item()`,
	which is exactly how the floored remainder is booked as decay loss instead of disappearing:
	`audit()`'s per-item `live + sunk == sourced` still closes on both items. Age is reset by
	that call, because fresh compost has not been sitting anywhere for 1440 hours.
	"""
	var reserved: int = _inventory.lot_reserved_milli(lot_ref)
	if not _begin_lot_transaction():
		out.refused_lots += 1
		out.last_lot_refusal = _last_refusal
		return
	_inventory.release_all_reservations(lot_ref)
	_inventory.transform_lot_item(lot_ref, _compost_id, compost_milli)
	var committed: InventoryScript.OpResult = _inventory.commit()
	if not committed.ok:
		out.refused_lots += 1
		out.last_lot_refusal = committed.error
		return
	out.lots_expired += 1
	out.seed_lots_converted += 1
	out.seed_sunk_milli += quantity_milli
	out.compost_sourced_milli += compost_milli
	out.seed_decay_loss_milli_g += decay_loss_milli_g
	out.reservations_invalidated_milli += reserved
	out.replans_owed += 1


func _retire_zero_yield_seed(lot_ref: Vector2i, quantity_milli: int, decay_loss_milli_g: int,
		out: HourResult) -> void:
	"""STOCK-SEED-R01: "When output is zero, ... sink retire the seed lot".

	No zero-quantity compost lot is created, and the row does NOT linger at zero holding a slot
	against REQ-SET-120's 16384-lot cap: `sink_lot_quantity()` for the whole quantity retires it.
	The entire seed quantity is still booked as a sink, so the decay loss is ledgered rather
	than deleted.
	"""
	var reserved: int = _inventory.lot_reserved_milli(lot_ref)
	if not _begin_lot_transaction():
		out.refused_lots += 1
		out.last_lot_refusal = _last_refusal
		return
	_inventory.release_all_reservations(lot_ref)
	_inventory.sink_lot_quantity(lot_ref, quantity_milli)
	var committed: InventoryScript.OpResult = _inventory.commit()
	if not committed.ok:
		out.refused_lots += 1
		out.last_lot_refusal = committed.error
		return
	out.seed_lots_retired += 1
	out.seed_sunk_milli += quantity_milli
	out.seed_decay_loss_milli_g += decay_loss_milli_g
	out.reservations_invalidated_milli += reserved
	out.replans_owed += 1


static func expiry_compost_quantity_into(seed_quantity_milli: int, seed_mass_g: int,
		compost_mass_g: int, out: IntMath.IntResult) -> bool:
	"""STOCK-SEED-R01's yield: `floor_div(checked_mul(q_milli, seed_mass_g), compost_mass_g)`.

	EXACTLY ONE FINAL FLOOR, over the full milli-gram product, which is what makes the split
	inequality hold; dividing the masses first and multiplying after would round twice. The
	product is in MILLI-GRAMS (milli-units times grams per unit) and the quotient back in
	milli-units of compost. Non-positive masses or quantity, and an int64 overflow, REFUSE:
	there is no compost quantity to answer and a saturated one would silently create matter.
	"""
	if seed_quantity_milli <= 0 or seed_mass_g <= 0 or compost_mass_g <= 0:
		return out.refuse(String(REFUSE_SEED_YIELD_UNREPRESENTABLE))
	if not IntMath.checked_mul_into(seed_quantity_milli, seed_mass_g, out):
		return false
	var total_milli_g: int = out.value
	return IntMath.floor_div_into(total_milli_g, compost_mass_g, out)


static func expiry_decay_loss_milli_g_into(seed_quantity_milli: int, seed_mass_g: int,
		compost_mass_g: int, out: IntMath.IntResult) -> bool:
	"""Milli-grams of nominal seed mass STOCK-SEED-R01's single floor discards as decay loss.

	`(q_milli * seed_mass_g) mod compost_mass_g`, so 19 milli-U of a 100 g/U seed yields 1
	milli-U of 1000 g/U compost and reports 900 milli-grams -- the ruling's "0.9g decay loss".
	Reported, never stored: no remainder is carried to another lot or another hour.
	"""
	if seed_quantity_milli <= 0 or seed_mass_g <= 0 or compost_mass_g <= 0:
		return out.refuse(String(REFUSE_SEED_YIELD_UNREPRESENTABLE))
	if not IntMath.checked_mul_into(seed_quantity_milli, seed_mass_g, out):
		return false
	return out.succeed(out.value % compost_mass_g)


static func equal_mass_quantity_into(quantity_milli: int, source_mass_g: int,
		target_mass_g: int, out: IntMath.IntResult) -> bool:
	"""Milli-units of the target item carrying EXACTLY `quantity_milli` of the source's mass.

	"food becomes spoiled_food at identical mass" (§5.8) is `q_old * mass_old == q_new *
	mass_new`. Where the two catalog masses do not divide exactly there IS NO equal-mass
	quantity, so this REFUSES rather than rounding mass into or out of existence and rather than
	answering a plausible-looking number. Refusal travels on `out.ok`, never inside the value:
	a rounded conversion would quietly break BAL-RUN-007's spoilage ledger in whichever
	direction the remainder fell.
	"""
	if quantity_milli <= 0 or source_mass_g <= 0 or target_mass_g <= 0:
		return out.refuse(String(REFUSE_MASS_NOT_CONVERTIBLE))
	if not IntMath.checked_mul_into(quantity_milli, source_mass_g, out):
		return false
	var total_milli_g: int = out.value
	if total_milli_g % target_mass_g != 0:
		return out.refuse(String(REFUSE_MASS_NOT_CONVERTIBLE))
	return out.succeed(total_milli_g / target_mass_g)


func _begin_lot_transaction() -> bool:
	"""Open the inventory transaction one expiring lot's steps run inside."""
	var opened: InventoryScript.OpResult = _inventory.begin()
	if opened.ok:
		return true
	_last_refusal = opened.error
	return false


# --- readers ---------------------------------------------------------------------------------------

func refuses_seed_consumption(lot_ref: Vector2i) -> bool:
	"""STOCK-SEED-R01's seed-consumer eligibility predicate. True means: do NOT use this lot.

	Every seed-consuming path -- new reservation, withdrawal, transfer into production, seed
	selection, the sowing/work commit and any reservation taken before the lot aged out -- must
	reject a seed whose persisted age has reached its catalog shelf threshold. Derived from age
	and the item definition, so it adds no per-lot flag and cannot disagree with a save.

	FAIL-CLOSED: an unbound store, an unloaded catalog or an invalid lot all answer TRUE,
	because a guard that cannot evaluate a lot must never be the reason one is admitted. A valid
	NON-seed lot answers false; this predicate has no opinion about food.

	ENFORCEMENT IS NOT HERE (module header, gap 3): STOCK-SEED-R01 gives quantity admission to
	`inventory.gd`, and nothing calls this yet. Release, cancellation and this stage's own
	transform/sink stay permitted precisely because the guard lives at the consumer.
	"""
	if _inventory == null or _definitions == null or not _definitions.is_loaded():
		return true
	if not _inventory.is_lot_valid(lot_ref):
		return true
	var item_id: int = _inventory.lot_item_id(lot_ref)
	if not _definitions.is_seed(item_id):
		return false
	var threshold: int = _shelf_threshold_milli_hours(item_id)
	if threshold <= 0:
		return false
	return _inventory.lot_age_milli_hours(lot_ref) >= threshold


func last_hour_tick() -> int:
	"""Tick of the most recent hourly pass, or NO_HOUR_RUN before the first one."""
	return _last_hour_tick


func last_refusal() -> StringName:
	"""Reason the most recent declaration call refused, or REFUSE_NONE."""
	return _last_refusal


func inventory() -> InventoryScript:
	"""The inventory this stage ages, or null while unbound."""
	return _inventory


func item_definitions() -> ItemDefinitionsScript:
	"""The item catalog this stage reads shelf lives from, or null while unbound."""
	return _definitions


func _refuse(code: StringName) -> bool:
	"""Record a refusal reason and answer false, having changed nothing."""
	_last_refusal = code
	return false
