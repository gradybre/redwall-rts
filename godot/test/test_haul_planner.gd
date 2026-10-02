extends "res://test/framework/test_case.gd"
## Suite for task 06.4 slice H2 (decision 1023): `haul_planner.gd`'s payload sizer, haul demand,
## destination selection, admission with its destination reservation, and the numbered
## ReservationPurpose domain.
##
## Oracles: REQ-SET-111 and BAL-WORK-003 for sizing and trips; BAL-CAT-010 and REQ-SET-134 for
## handling work; decision 0534's R1 store rule and R2 pile fallback, which Brendan's 2026-10-02
## ruling reuses for hauling; REQ-SET-030/031 for all-or-nothing admission with an exact cause.

const HaulWorld := preload("res://test/fixtures/haul_world.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const HaulPlannerScript := preload("res://scripts/core/haul_planner.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const SOURCE: int = ReservationsScript.PURPOSE_HAUL_SOURCE
const CARRIED: int = ReservationsScript.PURPOSE_HAUL_DESTINATION
const JOB: Vector2i = Vector2i(7, 1)
const OTHER_JOB: Vector2i = Vector2i(8, 1)
const STONE: int = HaulWorld.ITEM_STONE
const NOW: int = 1000


class RingTilePassable:
	extends "res://scripts/core/ground_piles.gd"
	## Only tile (41, 44) -- the yard's nearest front ring tile -- is passable.

	func is_tile_passable(tile: int) -> bool:
		"""The one passable tile."""
		return tile == 44 * 128 + 41

var _w: HaulWorld = null
var _mouse: int = -1
var _otter: int = -1
var _yard: Vector2i = Vector2i(-1, 0)
var _depot: Vector2i = Vector2i(-1, 0)
var _source: Vector2i = Vector2i(-1, 0)
var _stones: Vector2i = Vector2i(-1, 0)
var _out: IntMath.IntResult = IntMath.IntResult.new()
var _dest: HaulPlannerScript.Destination = HaulPlannerScript.Destination.new()


func before_each() -> void:
	"""A mouse, an otter, a yard holding 20 stone and a depot building with no store yet."""
	_w = HaulWorld.new()
	_mouse = _w.spawn(&"mouse")
	_otter = _w.spawn(&"otter")
	_yard = _w.place_active("open_stockpile", 40, 40)
	_depot = _w.place_active("open_stockpile", 50, 40)
	_source = _w.store(_yard, 400000, HaulWorld.tile(40, 40))
	_stones = _w.lot(_source, STONE, 20000)


# --- the purpose domain --------------------------------------------------------------------

func test_the_purpose_domain_is_numbered_explicitly() -> void:
	"""Decision 1023: UNSPECIFIED 0, HAUL_SOURCE 1, HAUL_DESTINATION 2, three members."""
	assert_equal(ReservationsScript.PURPOSE_UNSPECIFIED, 0, "unspecified")
	assert_equal(ReservationsScript.PURPOSE_HAUL_SOURCE, 1, "haul source")
	assert_equal(ReservationsScript.PURPOSE_HAUL_DESTINATION, 2, "haul destination")
	assert_equal(ReservationsScript.PURPOSE_NUMBERED_COUNT, 3, "three numbered members")


# --- sizing --------------------------------------------------------------------------------

func test_a_payload_is_the_carry_limit_at_the_per_lot_ceiling() -> void:
	"""REQ-SET-111 boundaries: exact fit, available below it, massless, no room, the odd mass."""
	assert_true(HaulPlannerScript.payload_milli_into(20000, 1000, 12000, 0, _out), "stone")
	assert_equal(_out.value, 12000, "12000 g of 1000 g/U stone is 12 U")
	HaulPlannerScript.payload_milli_into(5000, 1000, 12000, 0, _out)
	assert_equal(_out.value, 5000, "less than a load goes whole")
	HaulPlannerScript.payload_milli_into(999999, 0, 12000, 0, _out)
	assert_equal(_out.value, 999999, "a massless item goes whole")
	HaulPlannerScript.payload_milli_into(20000, 1000, 12000, 12000, _out)
	assert_equal(_out.value, 0, "no room left")
	HaulPlannerScript.payload_milli_into(9999999, 7, 12000, 0, _out)
	assert_equal(_out.value, 1714285, "floor(12000*1000/7)")
	assert_true(1714285 * 7 <= 12000 * 1000 and 1714286 * 7 > 12000 * 1000, "the exact boundary")
	assert_false(HaulPlannerScript.payload_milli_into(-1, 1000, 12000, 0, _out), "negative refuses")
	assert_false(HaulPlannerScript.payload_milli_into(1, 1, 9223372036854775807, 0, _out),
		"overflow refuses")


func test_trips_follow_bal_work_003_and_departures_can_need_one_more() -> void:
	"""ceil(ceil(Q*M/1000)/carry); the per-lot ceiling makes 3 departures of a 2-trip plan."""
	HaulPlannerScript.trips_into(24000, 1000, 12000, 0, _out)
	assert_equal(_out.value, 2, "24 stone in two mouse trips")
	HaulPlannerScript.trips_into(24001, 1000, 12000, 0, _out)
	assert_equal(_out.value, 3, "one milli-unit more needs a third")
	HaulPlannerScript.trips_into(24000, 1000, 16000, 0, _out)
	assert_equal(_out.value, 2, "an otter needs two as well")
	HaulPlannerScript.trips_into(3428571, 7, 12000, 0, _out)
	assert_equal(_out.value, 2, "the plan says two")
	var remaining: int = 3428571
	var departures: int = 0
	while remaining > 0:
		HaulPlannerScript.payload_milli_into(remaining, 7, 12000, 0, _out)
		remaining -= _out.value
		departures += 1
	assert_equal(departures, 3, "the actual per-lot-ceiling departures are three")
	assert_false(HaulPlannerScript.trips_into(1000, 1000, 12000, 12000, _out), "no room refuses")


func test_travel_ticks_are_the_straight_leg_lower_bound() -> void:
	"""BAL-WORK-003: ceil(D*30/v); BAL-WORK-004's 16 m leg at the small cap is 150 ticks."""
	HaulPlannerScript.travel_ticks_into(16384, 3277, _out)
	assert_equal(_out.value, 150, "16 m at 3277 u/s")
	HaulPlannerScript.travel_ticks_into(4096, 4096, _out)
	assert_equal(_out.value, 30, "one second exactly")
	HaulPlannerScript.travel_ticks_into(4097, 4096, _out)
	assert_equal(_out.value, 31, "rounded up")
	assert_false(HaulPlannerScript.travel_ticks_into(1, 0, _out), "no speed refuses")


func test_handling_work_is_2000_each_side_and_a_tenth_less_by_a_pantry() -> void:
	"""BAL-CAT-010's 2000/2000 milli-WU; REQ-SET-134's connection cuts each to 1800."""
	assert_equal(HaulPlannerScript.handling_milli_wu(true, false), 2000, "load")
	assert_equal(HaulPlannerScript.handling_milli_wu(false, false), 2000, "unload")
	assert_equal(HaulPlannerScript.handling_milli_wu(true, true), 1800, "load by a pantry")
	assert_equal(HaulPlannerScript.handling_milli_wu(false, true), 1800, "unload by a pantry")
	assert_equal(HaulPlannerScript.PANTRY_CONNECTION_MAX_U, 8192, "8 m")
	assert_equal(HaulPlannerScript.LEASE_RENEW_TICKS, 30, "REQ-SET-032 renewal")
	assert_equal(HaulPlannerScript.LEASE_EXPIRY_TICKS, 300, "REQ-SET-032 expiry")


# --- demand --------------------------------------------------------------------------------

func test_demand_walks_lots_with_unclaimed_quantity_in_list_order() -> void:
	"""A lot claimed whole is skipped; a part-claimed one is still demand."""
	var grain: Vector2i = _w.lot(_source, HaulWorld.ITEM_GRAIN, 4000)
	assert_true(_w.claim(JOB, _stones, SOURCE, 20000), "the stone is claimed whole")
	assert_equal(_w.planner.next_haul_lot(_source), grain, "the grain is next")
	assert_equal(_w.planner.next_haul_lot(_source, grain), InventoryScript.NULL_REF, "and last")
	assert_true(_w.claim(OTHER_JOB, grain, SOURCE, 1000), "part of the grain")
	assert_equal(_w.planner.next_haul_lot(_source), grain, "still has 3000 unclaimed")
	assert_equal(_w.planner.next_haul_lot(Vector2i(60, 1)), InventoryScript.NULL_REF, "no container")


func test_piles_and_left_satchels_are_standing_sources_but_stores_are_not() -> void:
	"""REQ-SET-110's piles always want hauling; a store only when something names it."""
	assert_false(_w.planner.is_standing_haul_source(_source), "a store waits to be named")
	_w.inventory.begin()
	var pile: Vector2i = _w.inventory.create_ground_pile(HaulWorld.tile(45, 45)).ref
	_w.lot(pile, STONE, 1000)
	assert_true(_w.inventory.commit().ok, "a pile with stone")
	assert_true(_w.planner.is_standing_haul_source(pile), "a pile is a source")
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	assert_false(_w.planner.is_standing_haul_source(satchel), "an empty satchel is not")
	var carried: Vector2i = _w.lot(satchel, STONE, 1000)
	assert_true(_w.planner.is_standing_haul_source(satchel), "a satchel with unclaimed goods is")
	var on_pile: Vector2i = _w.inventory.container_first_lot(pile)
	assert_true(_w.claim(JOB, on_pile, SOURCE, 1000), "the pile's goods are all claimed")
	assert_false(_w.planner.is_standing_haul_source(pile), "so the pile owes no new haul")
	assert_true(_w.claim(JOB, carried, SOURCE, 1000), "and the satchel's")
	assert_false(_w.planner.is_standing_haul_source(satchel), "nor the satchel")


# --- destination ---------------------------------------------------------------------------

func test_the_destination_is_the_lowest_eligible_store_by_slot() -> void:
	"""R1: two eligible stores; the lower slot wins and carries the payload's exact charge."""
	var first: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	_w.store(_depot, 400000, HaulWorld.tile(51, 40))
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "chosen")
	assert_equal(_dest.kind, HaulPlannerScript.DESTINATION_STORE, "a store")
	assert_equal(_dest.container, first, "the lowest slot")
	assert_equal(_dest.tile, HaulWorld.tile(50, 40), "its anchor tile")
	assert_equal(_dest.charge_g, 12000, "ceil(12000*1000/1000)")


func test_every_r1_clause_excludes_its_store() -> void:
	"""Same building (on or off its footprint), unreachable, filtered, too full, DEMOLISHING."""
	_w.store(_yard, 400000, HaulWorld.tile(41, 40))
	_w.store(_depot, 400000, HaulWorld.tile(50, 40), InventoryScript.FILTERS_ACCEPT_ALL, false)
	_w.store(_depot, 400000, HaulWorld.tile(51, 40), 1 << HaulWorld.CATEGORY_FOOD)
	_w.store(_depot, 11999, HaulWorld.tile(52, 40))
	var demolishing: Vector2i = _w.place_active("open_stockpile", 60, 40)
	_w.buildings.set_building_state(demolishing, Catalog.BUILDING_STATE["DEMOLISHING"])
	_w.store(demolishing, 400000, HaulWorld.tile(60, 40))
	_w.store(_yard, 400000, HaulWorld.tile(45, 45))
	var eligible: Vector2i = _w.store(_depot, 12000, HaulWorld.tile(53, 40))
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "chosen")
	assert_equal(_dest.container, eligible, "only the last store qualifies, at exactly its room")


func test_a_store_anchored_on_the_source_footprint_is_skipped() -> void:
	"""Off the footprint: another building's store standing on the source's tiles is not used."""
	var on_footprint: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(42, 42))
	var off: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 41))
	assert_true(on_footprint.x < off.x, "the footprint store has the lower slot")
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "chosen")
	assert_equal(_dest.container, off, "the off-footprint store")


func test_with_no_store_the_payload_falls_back_to_piles_on_the_ring() -> void:
	"""R2: ground piles from the source building's front-first ring; nothing reserved."""
	var before: PackedByteArray = _w.state()
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "fallback")
	assert_equal(_dest.kind, HaulPlannerScript.DESTINATION_GROUND, "ground piles")
	assert_equal(_dest.container, InventoryScript.NULL_REF, "no store")
	assert_equal(_dest.tile, HaulWorld.tile(41, 44), "the front (south) ring's nearest tile")
	assert_equal(_w.state(), before, "the proof wrote nothing")


func test_a_pile_or_satchel_source_has_no_pile_fallback() -> void:
	"""A source with no Building owner and no store refuses HAUL_NO_DESTINATION (REQ-SET-031)."""
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	var carried: Vector2i = _w.lot(satchel, STONE, 3000)
	assert_true(_w.planner.select_destination_into(carried, 3000, _dest), "the yard store qualifies")
	assert_equal(_dest.container, _source, "for a satchel's goods")
	_w.inventory.set_container_reachable(_source, false)
	assert_false(_w.planner.select_destination_into(carried, 3000, _dest), "nowhere")
	assert_equal(_w.planner.last_refusal(), HaulPlannerScript.REFUSE_NO_DESTINATION, "by name")
	assert_equal(_dest.kind, HaulPlannerScript.DESTINATION_NONE, "cleared")


func test_destination_selection_refuses_bad_inputs() -> void:
	"""A dead lot, a zero payload and one larger than the lot each refuse by name."""
	assert_false(_w.planner.select_destination_into(Vector2i(60, 1), 1000, _dest), "dead lot")
	assert_equal(_w.planner.last_refusal(), HaulPlannerScript.REFUSE_SOURCE_LOT, "named")
	assert_false(_w.planner.select_destination_into(_stones, 0, _dest), "zero")
	assert_false(_w.planner.select_destination_into(_stones, 20001, _dest), "more than the lot")
	assert_equal(_w.planner.last_refusal(), HaulPlannerScript.REFUSE_INVALID_ARGUMENT, "named")


# --- admission -----------------------------------------------------------------------------

func test_admission_sizes_claims_and_reserves_all_at_once() -> void:
	"""REQ-SET-030: a mouse's 12 of 20 stone is claimed and the depot holds 12000 g for it."""
	var depot_store: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	var admitted: InventoryScript.OpResult = _w.planner.admit(JOB, _mouse, _stones, 20000, NOW + 300)
	assert_true(admitted.ok, "admitted: %s" % admitted.error)
	assert_equal(admitted.value, 12000, "sized to a mouse")
	assert_equal(_w.pool.claim_quantity_milli(JOB, _stones, SOURCE), 12000, "HAUL_SOURCE claim")
	assert_equal(_w.inventory.container_reserved_mass_g(depot_store), 12000, "destination grams")
	assert_true(_w.planner.is_admitted(JOB), "recorded")
	assert_false(_w.planner.is_admitted(Vector2i(JOB.x, JOB.y + 1)), "not another generation")
	assert_equal(_w.planner.destination_of(JOB), depot_store, "the store")
	assert_equal(_w.planner.destination_kind_of(JOB), HaulPlannerScript.DESTINATION_STORE, "kind")
	assert_equal(_w.planner.destination_tile_of(JOB), HaulWorld.tile(50, 40), "the tile")
	assert_equal(_w.planner.reserved_g_of(JOB), 12000, "the grams")
	var expiry: IntMath.IntResult = IntMath.IntResult.new()
	_w.pool.claim_expiry_into(JOB, _stones, SOURCE, expiry)
	assert_equal(expiry.value, NOW + 300, "the lease the caller set")
	assert_true(_w.planner.admit(OTHER_JOB, _otter, _stones, 20000, NOW + 300).ok, "the rest")
	assert_equal(_w.pool.claim_quantity_milli(OTHER_JOB, _stones, SOURCE), 8000, "only 8 were left")


func test_a_refused_claim_releases_the_reserved_grams_exactly() -> void:
	"""A full reservation pool refuses the claim; the grams go back and nothing changed."""
	var tight: HaulWorld = HaulWorld.new(64, 64, 1)
	var mouse: int = tight.spawn(&"mouse")
	var yard: Vector2i = tight.place_active("open_stockpile", 40, 40)
	var depot: Vector2i = tight.place_active("open_stockpile", 50, 40)
	var stones: Vector2i = tight.lot(tight.store(yard, 400000, HaulWorld.tile(40, 40)), STONE, 20000)
	tight.store(depot, 400000, HaulWorld.tile(50, 40))
	assert_true(tight.claim(OTHER_JOB, stones, SOURCE, 1000), "the pool's only row is taken")
	var before: PackedByteArray = tight.state()
	var admitted: InventoryScript.OpResult = tight.planner.admit(JOB, mouse, stones, 5000, NOW)
	assert_equal(admitted.error, ReservationsScript.REFUSE_CAPACITY_RESERVATION, "the exact cause")
	assert_equal(tight.state(), before, "byte-identical")
	assert_false(tight.planner.is_admitted(JOB), "no record")


func test_admission_refuses_by_name_and_writes_nothing() -> void:
	"""Each precondition's refusal leaves every store byte-identical."""
	_w.store(_depot, 400000, HaulWorld.tile(50, 40))
	var before: PackedByteArray = _w.state()
	assert_equal(_w.planner.admit(Vector2i(9000, 1), _mouse, _stones, 1000, NOW).error,
		HaulPlannerScript.REFUSE_JOB_RANGE, "job out of range")
	assert_equal(_w.planner.admit(Vector2i(3, 0), _mouse, _stones, 1000, NOW).error,
		HaulPlannerScript.REFUSE_JOB_RANGE, "no generation")
	assert_equal(_w.planner.admit(JOB, 300, _stones, 1000, NOW).error,
		HaulPlannerScript.REFUSE_HAULER_ABSENT, "no hauler")
	assert_equal(_w.planner.admit(JOB, _mouse, Vector2i(60, 1), 1000, NOW).error,
		HaulPlannerScript.REFUSE_SOURCE_LOT, "no lot")
	assert_equal(_w.planner.admit(JOB, _mouse, _stones, 0, NOW).error,
		HaulPlannerScript.REFUSE_INVALID_ARGUMENT, "nothing asked")
	_w.inventory.begin()
	assert_equal(_w.planner.admit(JOB, _mouse, _stones, 1000, NOW).error,
		HaulPlannerScript.REFUSE_TRANSACTION_OPEN, "a caller's transaction")
	_w.inventory.abort()
	assert_equal(_w.state(), before, "byte-identical")
	assert_true(_w.planner.admit(JOB, _mouse, _stones, 1000, NOW).ok, "a good one")
	assert_equal(_w.planner.admit(JOB, _mouse, _stones, 1000, NOW).error,
		HaulPlannerScript.REFUSE_JOB_ADMITTED, "not twice")


func test_nothing_left_to_haul_refuses() -> void:
	"""A lot claimed whole elsewhere has nothing to size: HAUL_NOTHING_TO_HAUL."""
	assert_true(_w.claim(OTHER_JOB, _stones, SOURCE, 20000), "claimed whole")
	assert_equal(_w.planner.admit(JOB, _mouse, _stones, 1000, NOW).error,
		HaulPlannerScript.REFUSE_NOTHING_TO_HAUL, "nothing left")


func test_only_the_owner_is_admitted_to_haul_a_satchel_on() -> void:
	"""A satchel source admits its owner and refuses anyone else."""
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	var carried: Vector2i = _w.lot(satchel, STONE, 3000)
	_w.store(_depot, 400000, HaulWorld.tile(50, 40))
	assert_equal(_w.planner.admit(JOB, _otter, carried, 3000, NOW).error,
		HaulPlannerScript.REFUSE_NOT_HAULERS_SATCHEL, "not the otter")
	assert_true(_w.planner.admit(JOB, _mouse, carried, 3000, NOW).ok, "the mouse")


func test_cancel_before_the_load_returns_claim_and_grams() -> void:
	"""Cancel releases the HAUL_SOURCE claim, the destination grams and the record."""
	var depot_store: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	var before: PackedByteArray = _w.inventory.state_bytes()
	_w.planner.admit(JOB, _mouse, _stones, 20000, NOW)
	var cancelled: InventoryScript.OpResult = _w.planner.cancel(JOB)
	assert_true(cancelled.ok, "cancelled: %s" % cancelled.error)
	assert_equal(_w.inventory.container_reserved_mass_g(depot_store), 0, "grams back")
	assert_equal(_w.pool.active_row_count(), 0, "claim back")
	assert_false(_w.planner.is_admitted(JOB), "record cleared")
	assert_equal(_w.inventory.state_bytes(), before, "inventory as before the admission")
	assert_equal(_w.planner.cancel(JOB).error, HaulPlannerScript.REFUSE_JOB_NOT_ADMITTED, "once")


func test_cancel_after_the_load_leaves_the_goods_in_the_satchel_unclaimed() -> void:
	"""The ruling: a haul cancelled mid-carry keeps its goods in the satchel for a fresh haul."""
	_w.store(_depot, 400000, HaulWorld.tile(50, 40))
	_w.planner.admit(JOB, _mouse, _stones, 20000, NOW)
	var loaded: InventoryScript.OpResult = _w.carry.load_payload(JOB, _mouse, _stones)
	assert_true(_w.planner.cancel(JOB).ok, "cancelled mid-carry")
	assert_equal(_w.inventory.lot_container(loaded.ref), _w.carry.satchel_of(_mouse), "still carried")
	assert_equal(_w.inventory.lot_reserved_milli(loaded.ref), 0, "unclaimed")
	assert_true(_w.planner.is_standing_haul_source(_w.carry.satchel_of(_mouse)), "awaiting a haul")


func test_a_cancel_whose_grams_are_gone_refuses() -> void:
	"""A destination store no longer holding the recorded grams refuses, writing nothing."""
	var depot_store: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	_w.planner.admit(JOB, _mouse, _stones, 20000, NOW)
	_w.inventory.release_container_mass(depot_store, 12000)
	assert_equal(_w.planner.cancel(JOB).error, InventoryScript.REFUSE_INSUFFICIENT_RESERVED_MASS,
		"named")
	assert_true(_w.planner.is_admitted(JOB), "the record stays")


# --- end to end ----------------------------------------------------------------------------

func test_admit_load_unload_conserves_every_gram() -> void:
	"""The whole haul: no teleport, nothing cloned, no claim or gram left behind."""
	var depot_store: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	assert_true(_w.planner.admit(JOB, _mouse, _stones, 20000, NOW).ok, "admitted")
	assert_true(_w.carry.load_payload(JOB, _mouse, _stones).ok, "loaded")
	assert_true(_w.audits_pass(), "audits pass mid-carry")
	assert_equal(_w.planner.audit(), &"", "the record agrees with the store mid-carry")
	var unloaded: InventoryScript.OpResult = _w.planner.complete_unload(JOB, _mouse, _w.carry)
	assert_true(unloaded.ok, "unloaded: %s" % unloaded.error)
	assert_false(_w.planner.is_admitted(JOB), "the record is retired with the delivery")
	assert_equal(_w.inventory.container_used_mass_g(depot_store), 12000, "12 stone delivered")
	assert_equal(_w.inventory.container_used_mass_g(_source), 8000, "8 left")
	assert_equal(_w.inventory.container_reserved_mass_g(depot_store), 0, "no grams held")
	assert_equal(_w.pool.active_row_count(), 0, "no claim held")
	assert_equal(_w.inventory.total_live_milli(STONE), 20000, "every stone")
	assert_equal(_w.inventory.total_sourced_milli(STONE), 20000, "none sourced by the haul")
	assert_equal(_w.inventory.total_sunk_milli(STONE), 0, "none sunk")
	assert_true(_w.audits_pass(), "audits pass")


func test_a_ground_destination_unloads_onto_its_tile() -> void:
	"""R2 end to end: no store, the payload is put down on the recorded ring tile."""
	assert_true(_w.planner.admit(JOB, _mouse, _stones, 20000, NOW).ok, "admitted to piles")
	assert_equal(_w.planner.reserved_g_of(JOB), 0, "nothing reserved")
	assert_equal(_w.planner.destination_kind_of(JOB), HaulPlannerScript.DESTINATION_GROUND, "kind")
	_w.carry.load_payload(JOB, _mouse, _stones)
	assert_true(_w.planner.complete_unload(JOB, _mouse, _w.carry).ok, "put down")
	var pile: Vector2i = _w.inventory.ground_pile_at_tile(HaulWorld.tile(41, 44))
	assert_equal(_w.inventory.container_used_mass_g(pile), 12000, "on the ring tile")
	assert_false(_w.planner.is_admitted(JOB), "retired")
	assert_true(_w.audits_pass(), "audits pass")


func test_the_record_and_scratch_are_the_ledgered_sizes() -> void:
	"""Decision 1023's §3 record (196608 B) and §2.3 scratch (34916 B in the planner)."""
	assert_equal(_w.planner.record_bytes(), 196608, "five columns over 8192 job keys")
	assert_equal(_w.planner.scratch_bytes(), 34916, "two masks, seeds, a spec, a claim, one seed")


func test_the_pile_tile_is_the_first_eligible_ring_seed() -> void:
	"""With the front ring covered by another footprint, the unload tile moves along the ring."""
	assert_true(_w.place_active("open_stockpile", 40, 44) != InventoryScript.NULL_REF, "blocker")
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "fallback")
	assert_equal(_dest.kind, HaulPlannerScript.DESTINATION_GROUND, "ground")
	assert_true(_w.piles.ground_pile_tile_refusal(_dest.tile) == &"", "an eligible tile")
	assert_true(_dest.tile != HaulWorld.tile(41, 44), "not the covered front tile")


func test_a_cancel_after_the_unload_cannot_take_another_jobs_grams() -> void:
	"""Two hauls hold 12000 g each in one depot; A delivers; a late cancel of A changes nothing."""
	var depot_store: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	var more: Vector2i = _w.lot(_source, STONE, 20000)
	assert_true(_w.planner.admit(JOB, _mouse, _stones, 12000, NOW).ok, "A")
	assert_true(_w.planner.admit(OTHER_JOB, _otter, more, 12000, NOW).ok, "B")
	assert_equal(_w.inventory.container_reserved_mass_g(depot_store), 24000, "both held")
	_w.carry.load_payload(JOB, _mouse, _stones)
	assert_true(_w.planner.complete_unload(JOB, _mouse, _w.carry).ok, "A delivered")
	var before: PackedByteArray = _w.state()
	assert_equal(_w.planner.cancel(JOB).error, HaulPlannerScript.REFUSE_JOB_NOT_ADMITTED, "refused")
	assert_equal(_w.state(), before, "nothing changed")
	assert_equal(_w.inventory.container_reserved_mass_g(depot_store), 12000, "B's grams intact")
	assert_equal(_w.planner.audit(), &"", "the records agree with the store")


func test_the_audit_sees_grams_the_record_holds_but_the_store_does_not() -> void:
	"""Grams released behind the record's back, or a dead store, fail the planner's audit."""
	var depot_store: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	_w.planner.admit(JOB, _mouse, _stones, 12000, NOW)
	assert_equal(_w.planner.audit(), &"", "consistent")
	_w.inventory.release_container_mass(depot_store, 1)
	assert_equal(_w.planner.audit(), HaulPlannerScript.REFUSE_AUDIT_GRAMS, "one gram short")
	_w.inventory.release_container_mass(depot_store, 11999)
	_w.inventory.destroy_container(depot_store)
	assert_equal(_w.planner.audit(), HaulPlannerScript.REFUSE_AUDIT_STORE, "store gone")


func test_a_store_that_fills_before_the_unload_refuses_and_keeps_the_record() -> void:
	"""complete_unload into a store that no longer has room refuses; the record stays to cancel."""
	var depot_store: Vector2i = _w.store(_depot, 12000, HaulWorld.tile(50, 40))
	_w.planner.admit(JOB, _mouse, _stones, 12000, NOW)
	_w.carry.load_payload(JOB, _mouse, _stones)
	assert_true(_w.inventory.release_container_mass(depot_store, 12000).ok, "grams stolen")
	_w.lot(depot_store, STONE, 12000)
	assert_false(_w.planner.complete_unload(JOB, _mouse, _w.carry).ok, "refused")
	assert_true(_w.planner.is_admitted(JOB), "the record stays")


func test_a_ring_with_no_eligible_tile_has_no_pile_fallback() -> void:
	"""R2's proof: with every ring tile under another footprint, HAUL_NO_DESTINATION."""
	for origin: Vector2i in [Vector2i(40, 36), Vector2i(40, 44), Vector2i(36, 40), Vector2i(44, 40)]:
		assert_true(_w.place_active("open_stockpile", origin.x, origin.y) != InventoryScript.NULL_REF,
			"a neighbour at %s" % origin)
	assert_false(_w.planner.select_destination_into(_stones, 12000, _dest), "no ring tile")
	assert_equal(_w.planner.last_refusal(), HaulPlannerScript.REFUSE_NO_DESTINATION, "named")


func test_the_footprint_exclusion_does_not_outlive_its_choice() -> void:
	"""After choosing for the yard, a store on the yard's footprint is eligible for another source."""
	var on_yard: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(42, 42))
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "the yard's choice")
	assert_true(_dest.container != on_yard, "the footprint store is skipped for the yard")
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	var carried: Vector2i = _w.lot(satchel, STONE, 3000)
	_w.inventory.set_container_reachable(_source, false)
	assert_true(_w.planner.select_destination_into(carried, 3000, _dest), "a satchel's choice")
	assert_equal(_dest.container, on_yard, "the yard's footprint is no longer excluded")


func test_a_ring_whose_piles_are_full_has_no_pile_fallback() -> void:
	"""R2 is PROVED: an eligible ring tile whose pile cannot take the payload refuses."""
	var piles: RingTilePassable = RingTilePassable.new()
	assert_true(piles.bind_stores(_w.inventory, _w.buildings, _w.stock_age), "bound")
	assert_true(piles.bind_world(_w.world), "world")
	var planner: HaulPlannerScript = HaulPlannerScript.new()
	planner.bind(_w.inventory, _w.pool, _w.residents, _w.buildings, piles, _w.store_policy)
	_w.inventory.begin()
	var pile: Vector2i = _w.inventory.create_ground_pile(HaulWorld.tile(41, 44)).ref
	_w.lot(pile, STONE, 399000)
	assert_true(_w.inventory.commit().ok, "the only ring pile is nearly full")
	assert_false(planner.select_destination_into(_stones, 12000, _dest), "12 stone do not fit")
	assert_equal(planner.last_refusal(), HaulPlannerScript.REFUSE_NO_DESTINATION, "named")
	assert_true(planner.select_destination_into(_stones, 1000, _dest), "1 stone does")
	assert_equal(_dest.tile, HaulWorld.tile(41, 44), "on that tile")


func test_a_main_stores_per_item_allow_byte_excludes_it() -> void:
	"""Decision 1031 P3: a depot whose building disallows stone is skipped for the next store."""
	var depot_main: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(50, 40))
	var depot_side: Vector2i = _w.store(_depot, 400000, HaulWorld.tile(51, 40))
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "chosen")
	assert_equal(_dest.container, depot_main, "the main store, while stone is allowed")
	assert_equal(_w.store_policy.set_allowed(_depot, STONE, 0), &"", "stone disallowed")
	assert_true(_w.planner.select_destination_into(_stones, 12000, _dest), "chosen again")
	assert_equal(_dest.container, depot_side, "the off-origin store answers by its mask alone")


func test_binding_needs_every_store() -> void:
	"""A null store policy binds nothing."""
	var planner: HaulPlannerScript = HaulPlannerScript.new()
	assert_false(planner.bind(_w.inventory, _w.pool, _w.residents, _w.buildings, _w.piles, null),
		"no store policy")

