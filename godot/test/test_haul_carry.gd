extends "res://test/framework/test_case.gd"
## Suite for task 06.4 slice H1 (decision 1022): `haul_carry.gd`'s load, unloads and drop, and
## the satchel door they open in `inventory.gd`.
##
## Brendan's 2026-10-02 rulings are the oracle: a satchel is made per haul at load, sized to the
## hauler's species carry limit, owned by the resident and unplaced, and destroyed when emptied;
## a dying hauler's goods drop as a ground pile under DEC-043 #9; nothing teleports, nothing is
## cloned, and the claim travels with the goods. Every refusal is checked byte-identical.

const HaulWorld := preload("res://test/fixtures/haul_world.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const HaulCarryScript := preload("res://scripts/core/haul_carry.gd")
const GroundPilesScript := preload("res://scripts/core/ground_piles.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const SOURCE: int = ReservationsScript.PURPOSE_HAUL_SOURCE
const CARRIED: int = ReservationsScript.PURPOSE_HAUL_DESTINATION
const JOB: Vector2i = Vector2i(5, 1)
const OTHER_JOB: Vector2i = Vector2i(6, 1)
const STONE: int = HaulWorld.ITEM_STONE

var _w: HaulWorld = null
var _mouse: int = -1
var _otter: int = -1
var _yard: Vector2i = Vector2i(-1, 0)
var _source: Vector2i = Vector2i(-1, 0)
var _target: Vector2i = Vector2i(-1, 0)
var _stones: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""A mouse and an otter; a yard store holding 20 stone and a second building's store."""
	_w = HaulWorld.new()
	_mouse = _w.spawn(&"mouse")
	_otter = _w.spawn(&"otter")
	_yard = _w.place_active("open_stockpile", 40, 40)
	var depot: Vector2i = _w.place_active("open_stockpile", 50, 40)
	_source = _w.store(_yard, 400000, HaulWorld.tile(40, 40))
	_target = _w.store(depot, 400000, HaulWorld.tile(50, 40))
	_stones = _w.lot(_source, STONE, 20000)


func _load(hauler: int, quantity: int, job: Vector2i = JOB) -> InventoryScript.OpResult:
	"""Claim `quantity` stone for `job` as HAUL_SOURCE, then load it."""
	assert_true(_w.claim(job, _stones, SOURCE, quantity), "the source claim is taken")
	return _w.carry.load_payload(job, hauler, _stones)


func _assert_conserved(message: String) -> void:
	"""Twenty stone exist, none sourced or sunk by the haul, and both audits pass."""
	assert_equal(_w.inventory.total_live_milli(STONE), 20000, "%s: the stone is all there" % message)
	assert_equal(_w.inventory.total_sourced_milli(STONE), 20000, "%s: nothing sourced" % message)
	assert_equal(_w.inventory.total_sunk_milli(STONE), 0, "%s: nothing sunk" % message)
	assert_true(_w.audits_pass(), "%s: inventory and pool audits pass" % message)


# --- the satchel door ----------------------------------------------------------------------

func test_a_satchel_is_minted_only_by_its_own_door() -> void:
	"""create_container refuses the satchel policy; create_satchel mints an unplaced, closed row."""
	var refused: InventoryScript.OpResult = _w.inventory.create_container(_w.residents.ref_of(_mouse),
		12000, -1, InventoryScript.POLICY_SATCHEL, false)
	assert_equal(refused.error, InventoryScript.REFUSE_SATCHEL_POLICY_RESERVED, "reserved policy")
	var made: InventoryScript.OpResult = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000)
	assert_true(made.ok, "the satchel door mints one")
	assert_true(_w.inventory.is_satchel(made.ref), "it is a satchel")
	assert_equal(_w.inventory.container_anchor_tile(made.ref), InventoryScript.UNPLACED_TILE, "unplaced")
	assert_false(_w.inventory.container_reachable(made.ref), "not a planning target")
	assert_equal(_w.inventory.container_max_mass_g(made.ref), 12000, "sized as asked")
	assert_equal(_w.inventory.container_filters(made.ref), InventoryScript.FILTERS_ACCEPT_ALL, "takes anything")


func test_the_satchel_door_refuses_a_bad_owner_or_carry() -> void:
	"""A malformed owner and a non-positive carry limit refuse, writing nothing."""
	var before: PackedByteArray = _w.inventory.state_bytes()
	assert_equal(_w.inventory.create_satchel(Vector2i(-1, 0), 12000).error,
		InventoryScript.REFUSE_INVALID_OWNER_REF, "null owner")
	assert_equal(_w.inventory.create_satchel(_w.residents.ref_of(_mouse), 0).error,
		InventoryScript.REFUSE_INVALID_MASS, "zero carry")
	assert_equal(_w.inventory.state_bytes(), before, "nothing written")


func test_a_satchel_cannot_be_placed_and_only_a_satchel_is_destroyed_as_one() -> void:
	"""set_container_anchor refuses a satchel; destroy_satchel refuses a store and a full satchel."""
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	assert_equal(_w.inventory.set_container_anchor(satchel, 10).error,
		InventoryScript.REFUSE_SATCHEL_ANCHOR_FIXED, "never on a tile")
	assert_equal(_w.inventory.destroy_satchel(_source).error, InventoryScript.REFUSE_NOT_A_SATCHEL,
		"a store is not a satchel")
	_w.lot(satchel, STONE, 1000)
	assert_equal(_w.inventory.destroy_satchel(satchel).error, InventoryScript.REFUSE_CONTAINER_NOT_EMPTY,
		"a satchel with goods stays")


func test_a_saved_satchel_on_a_tile_is_refused_on_restore() -> void:
	"""The canonical restore refuses a satchel row anchored on a tile."""
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	_w.lot(satchel, STONE, 1000)
	var cols: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(64, 64)
	assert_true(_w.inventory.copy_canonical_columns_into(cols), "copied")
	assert_true(_fresh_store().restore_canonical_columns(cols), "an unplaced satchel restores")
	cols.c_anchor_tile[satchel.x] = 10
	var fresh: InventoryScript = _fresh_store()
	assert_false(fresh.restore_canonical_columns(cols), "a placed satchel is refused")
	assert_true(fresh.canonical_detail().contains("satchel"), "by the satchel rule")


func test_the_audit_refuses_a_satchel_on_a_tile() -> void:
	"""No door can place a satchel; a row poked onto a tile is what audit() exists to catch."""
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	assert_true(_w.inventory.audit().ok, "an unplaced satchel audits")
	_w.inventory._c_anchor_tile[satchel.x] = 10
	assert_equal(_w.inventory.audit().error, InventoryScript.REFUSE_AUDIT_SATCHEL, "a placed one does not")


func _fresh_store() -> InventoryScript:
	"""An empty store with the fixture's three items registered, ready to restore into."""
	var fresh: InventoryScript = InventoryScript.new(64, 64)
	fresh.register_item(STONE, HaulWorld.STONE_MASS_G, HaulWorld.CATEGORY_MATERIAL)
	fresh.register_item(HaulWorld.ITEM_GRAIN, HaulWorld.GRAIN_MASS_G, HaulWorld.CATEGORY_FOOD)
	fresh.register_item(HaulWorld.ITEM_ODD, HaulWorld.ODD_MASS_G, HaulWorld.CATEGORY_MATERIAL)
	return fresh


func test_the_anchored_cursor_walks_placed_containers_in_slot_order() -> void:
	"""next_container_anchored_in skips unplaced rows and refuses a short mask with the null ref."""
	_w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000)
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(InventoryScript.ANCHOR_TILE_COUNT)
	mask.fill(1)
	var first: Vector2i = _w.inventory.next_container_anchored_in(-1, mask)
	assert_equal(first, _source, "the lowest placed slot first")
	assert_equal(_w.inventory.next_container_anchored_in(first.x, mask), _target, "then the next")
	assert_equal(_w.inventory.next_container_anchored_in(_target.x, mask), InventoryScript.NULL_REF,
		"the satchel is never reported")
	mask[HaulWorld.tile(40, 40)] = 0
	assert_equal(_w.inventory.next_container_anchored_in(-1, mask), _target, "an unmarked tile is skipped")
	assert_equal(_w.inventory.next_container_anchored_in(-1, PackedByteArray()), InventoryScript.NULL_REF,
		"a short mask answers nothing")


# --- load ----------------------------------------------------------------------------------

func test_loading_mints_a_satchel_at_the_species_carry_limit() -> void:
	"""A mouse's satchel holds 12000 g and an otter's 16000 g (GDD §5.2), each owned and bound."""
	var loaded: InventoryScript.OpResult = _load(_mouse, 12000)
	assert_true(loaded.ok, "the mouse loads: %s" % loaded.error)
	var satchel: Vector2i = _w.carry.satchel_of(_mouse)
	assert_equal(_w.inventory.container_max_mass_g(satchel), 12000, "a mouse carries 12000 g")
	assert_equal(_w.inventory.container_owner(satchel), _w.residents.ref_of(_mouse), "owned by the mouse")
	assert_equal(_w.residents.satchel_of(_mouse), satchel, "Equipment.satchel names it")
	assert_equal(_w.inventory.lot_container(loaded.ref), satchel, "the goods are in it")
	var limit: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_w.carry.carry_limit_g_into(_otter, limit), "the otter's limit reads")
	assert_equal(limit.value, 16000, "an otter carries 16000 g")


func test_a_partial_load_splits_exactly_and_carries_the_claim() -> void:
	"""12 of 20 stone go; 8 stay; the claim is HAUL_DESTINATION on the carried lot only."""
	var lots_before: int = _w.inventory.live_lot_count()
	var loaded: InventoryScript.OpResult = _load(_mouse, 12000)
	assert_equal(loaded.value, 12000, "the claimed quantity moved")
	assert_equal(_w.inventory.lot_quantity_milli(_stones), 8000, "the remainder stayed")
	assert_equal(_w.inventory.lot_reserved_milli(_stones), 0, "the source is no longer claimed")
	assert_equal(_w.inventory.live_lot_count(), lots_before + 1, "one exact split, nothing cloned")
	assert_false(_w.pool.has_claim(JOB, _stones, SOURCE), "the source claim is gone")
	assert_equal(_w.pool.claim_quantity_milli(JOB, loaded.ref, CARRIED), 12000, "carried, still claimed")
	assert_equal(_w.inventory.lot_reserved_milli(loaded.ref), 12000, "and reserved in the satchel")
	_assert_conserved("after a partial load")


func test_a_whole_lot_load_moves_the_lot_itself() -> void:
	"""A claim on the whole lot moves it whole: the same lot ref arrives in the satchel."""
	var small: Vector2i = _w.lot(_source, HaulWorld.ITEM_GRAIN, 5000)
	assert_true(_w.claim(JOB, small, SOURCE, 5000), "claimed whole")
	var loaded: InventoryScript.OpResult = _w.carry.load_payload(JOB, _mouse, small)
	assert_true(loaded.ok, "loaded: %s" % loaded.error)
	assert_equal(loaded.ref, small, "the lot kept its identity")
	assert_true(_w.inventory.is_satchel(_w.inventory.lot_container(small)), "now in the satchel")
	assert_true(_w.pool.has_claim(JOB, small, CARRIED), "re-keyed on the same lot")


func test_a_load_over_the_carry_limit_refuses_and_changes_nothing() -> void:
	"""13000 g of stone is over a mouse's 12000 g: REQ-SET-111 is re-proved at load."""
	assert_true(_w.claim(JOB, _stones, SOURCE, 13000), "an over-heavy claim exists")
	var before: PackedByteArray = _w.state()
	var loaded: InventoryScript.OpResult = _w.carry.load_payload(JOB, _mouse, _stones)
	assert_equal(loaded.error, HaulCarryScript.REFUSE_OVER_CARRY, "refused by the carry limit")
	assert_equal(_w.state(), before, "byte-identical")
	assert_true(_w.carry.load_payload(JOB, _otter, _stones).ok, "an otter carries it")


func test_a_hauler_already_carrying_cannot_load_a_second_satchel() -> void:
	"""BAL-SAFE-002: one container in transit per hauler."""
	assert_true(_load(_mouse, 5000).ok, "first load")
	assert_true(_w.claim(OTHER_JOB, _stones, SOURCE, 1000), "a second claim")
	var before: PackedByteArray = _w.state()
	assert_equal(_w.carry.load_payload(OTHER_JOB, _mouse, _stones).error,
		HaulCarryScript.REFUSE_ALREADY_CARRYING, "refused")
	assert_equal(_w.state(), before, "byte-identical")


func test_a_load_refuses_without_a_claim_a_hauler_or_with_a_transaction_open() -> void:
	"""No claim, an absent row and a caller's open transaction each refuse by name."""
	assert_equal(_w.carry.load_payload(JOB, _mouse, _stones).error, HaulCarryScript.REFUSE_NO_CLAIM,
		"no claim")
	assert_true(_w.claim(JOB, _stones, SOURCE, 1000), "claimed")
	assert_equal(_w.carry.load_payload(JOB, 300, _stones).error, HaulCarryScript.REFUSE_HAULER_ABSENT,
		"no such resident")
	_w.inventory.begin()
	assert_equal(_w.carry.load_payload(JOB, _mouse, _stones).error,
		HaulCarryScript.REFUSE_TRANSACTION_OPEN, "a caller's transaction is open")
	_w.inventory.abort()
	var unbound: HaulCarryScript = HaulCarryScript.new()
	assert_equal(unbound.load_payload(JOB, _mouse, _stones).error, HaulCarryScript.REFUSE_NOT_BOUND,
		"unbound")
	assert_false(unbound.bind(null, _w.pool, _w.residents, _w.piles), "a null store binds nothing")


func test_a_load_refused_inside_its_transaction_leaves_no_satchel() -> void:
	"""A full lot store refuses the split inside the load's transaction: no satchel, no change."""
	var tight: HaulWorld = HaulWorld.new(64, 1)
	var mouse: int = tight.spawn(&"mouse")
	var yard: Vector2i = tight.place_active("open_stockpile", 40, 40)
	var source: Vector2i = tight.store(yard, 400000, HaulWorld.tile(40, 40))
	var stones: Vector2i = tight.lot(source, STONE, 20000)
	assert_true(tight.claim(JOB, stones, SOURCE, 5000), "claimed part")
	var before: PackedByteArray = tight.state()
	var containers: int = tight.inventory.live_container_count()
	var loaded: InventoryScript.OpResult = tight.carry.load_payload(JOB, mouse, stones)
	assert_equal(loaded.error, InventoryScript.REFUSE_CAPACITY_INVENTORY_LOT, "the split has no row")
	assert_equal(tight.inventory.live_container_count(), containers, "no satchel left behind")
	assert_equal(tight.state(), before, "byte-identical")


# --- unload into a store -------------------------------------------------------------------

func test_unloading_into_a_store_delivers_releases_and_destroys_the_satchel() -> void:
	"""The payload arrives unclaimed, the reserved grams go, the satchel is destroyed and unbound."""
	assert_true(_w.inventory.reserve_container_mass(_target, 12000).ok, "H2's destination grams")
	var loaded: InventoryScript.OpResult = _load(_mouse, 12000)
	var satchel: Vector2i = _w.carry.satchel_of(_mouse)
	var unloaded: InventoryScript.OpResult = _w.carry.unload_into_store(JOB, _mouse, _target, 12000)
	assert_true(unloaded.ok, "unloaded: %s" % unloaded.error)
	assert_equal(_w.inventory.lot_container(unloaded.ref), _target, "in the destination")
	assert_equal(unloaded.ref, loaded.ref, "the carried lot moved whole")
	assert_equal(_w.inventory.lot_reserved_milli(unloaded.ref), 0, "unclaimed on arrival")
	assert_equal(_w.inventory.container_reserved_mass_g(_target), 0, "the grams were released")
	assert_false(_w.inventory.is_container_valid(satchel), "the satchel is destroyed")
	assert_equal(_w.residents.satchel_of(_mouse), InventoryScript.NULL_REF, "and unbound")
	assert_equal(_w.pool.job_claim_count(JOB), 0, "the job holds no claim")
	_assert_conserved("after the unload")


func test_an_unload_refuses_without_a_satchel_or_a_claim() -> void:
	"""Carrying nothing, a stale satchel pair, and another job's goods each refuse by name."""
	assert_equal(_w.carry.unload_into_store(JOB, _mouse, _target, 0).error,
		HaulCarryScript.REFUSE_NOT_CARRYING, "nothing carried")
	assert_true(_load(_mouse, 3000).ok, "loaded")
	assert_equal(_w.carry.unload_into_store(OTHER_JOB, _mouse, _target, 0).error,
		HaulCarryScript.REFUSE_NO_CLAIM, "not this job's goods")
	_w.residents.set_satchel(_mouse, Vector2i(40, 9))
	assert_equal(_w.carry.unload_into_store(JOB, _mouse, _target, 0).error,
		HaulCarryScript.REFUSE_SATCHEL_STALE, "a stale pair")


func test_a_pair_naming_someone_elses_satchel_is_stale() -> void:
	"""A live satchel the otter owns does not become the mouse's by being named in its pair."""
	assert_true(_load(_otter, 3000).ok, "the otter carries")
	_w.residents.set_satchel(_mouse, _w.carry.satchel_of(_otter))
	assert_equal(_w.carry.satchel_of(_mouse), InventoryScript.NULL_REF, "not the mouse's")
	assert_equal(_w.carry.unload_into_store(JOB, _mouse, _target, 0).error,
		HaulCarryScript.REFUSE_SATCHEL_STALE, "unload refuses")
	assert_true(_w.claim(OTHER_JOB, _stones, SOURCE, 1000), "another claim")
	assert_equal(_w.carry.load_payload(OTHER_JOB, _mouse, _stones).error,
		HaulCarryScript.REFUSE_SATCHEL_STALE, "load refuses")


func test_an_unload_the_store_cannot_take_refuses_and_keeps_the_goods_carried() -> void:
	"""A full destination refuses the delivery; the goods, claim and satchel are untouched."""
	var full: Vector2i = _w.store(_yard, 1000, HaulWorld.tile(41, 40))
	assert_true(_load(_mouse, 3000).ok, "loaded")
	var before: PackedByteArray = _w.state()
	assert_equal(_w.carry.unload_into_store(JOB, _mouse, full, 0).error,
		InventoryScript.REFUSE_CAPACITY_EXCEEDED, "no room")
	assert_equal(_w.state(), before, "byte-identical")


# --- unload into ground piles --------------------------------------------------------------

func test_unloading_into_piles_moves_the_goods_and_frees_the_satchel() -> void:
	"""R2's fallback: the goods move onto a pile at the seed, unclaimed; nothing is created."""
	_load(_mouse, 12000)
	var seeds: PackedInt32Array = PackedInt32Array([HaulWorld.tile(45, 45)])
	var unloaded: InventoryScript.OpResult = _w.carry.unload_into_piles(JOB, _mouse, seeds, 1,
		PackedByteArray())
	assert_true(unloaded.ok, "unloaded: %s" % unloaded.error)
	assert_equal(unloaded.value, 12000, "the whole payload")
	var pile: Vector2i = _w.inventory.ground_pile_at_tile(HaulWorld.tile(45, 45))
	assert_equal(_w.inventory.container_used_mass_g(pile), 12000, "on the pile")
	assert_equal(_w.stock_age.storage_class_of(pile), StockAgeScript.STORAGE_OPEN_PILE, "open pile")
	assert_equal(_w.residents.satchel_of(_mouse), InventoryScript.NULL_REF, "the satchel is gone")
	assert_equal(_w.pool.job_claim_count(JOB), 0, "and the claim")
	_assert_conserved("after the pile unload")


func test_a_pile_unload_with_nowhere_to_go_refuses_and_keeps_the_claim() -> void:
	"""An impassable seed refuses before the claim is released: byte-identical."""
	_load(_mouse, 12000)
	var before: PackedByteArray = _w.state()
	var seeds: PackedInt32Array = PackedInt32Array([HaulWorld.tile(40, 40)])
	var unloaded: InventoryScript.OpResult = _w.carry.unload_into_piles(JOB, _mouse, seeds, 1,
		PackedByteArray())
	assert_equal(unloaded.error, GroundPilesScript.REFUSE_INACCESSIBLE_FOOTPRINT,
		"a standing footprint is no pile site")
	assert_equal(_w.state(), before, "byte-identical")


# --- the drop ------------------------------------------------------------------------------

func test_a_dying_haulers_satchel_drops_onto_a_pile_at_its_tile() -> void:
	"""Death mid-carry: goods to a pile at the tile, claims released, satchel destroyed."""
	_load(_mouse, 12000)
	var seeds: PackedInt32Array = _seeds_for(HaulWorld.tile(46, 46))
	var dropped: InventoryScript.OpResult = _w.carry.drop_satchel(_mouse, seeds, 1)
	assert_true(dropped.ok, "dropped: %s" % dropped.error)
	var pile: Vector2i = _w.inventory.ground_pile_at_tile(HaulWorld.tile(46, 46))
	assert_equal(_w.inventory.container_used_mass_g(pile), 12000, "the goods lie there")
	assert_equal(_w.residents.satchel_of(_mouse), InventoryScript.NULL_REF, "the satchel is gone")
	assert_equal(_w.pool.active_row_count(), 0, "every claim released")
	assert_true(_w.residents.despawn(_w.residents.ref_of(_mouse)).ok, "the row can now go")
	_assert_conserved("after the drop")


func test_a_drop_inside_a_footprint_starts_at_that_buildings_ring() -> void:
	"""A hauler standing on a footprint drops from the building's front-first ring."""
	_load(_mouse, 12000)
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(GroundPilesScript.TILE_COUNT)
	var seeds: PackedInt32Array = PackedInt32Array()
	seeds.resize(GroundPilesScript.REFUND_SEED_CAPACITY)
	var count: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_w.piles.drop_seeds_into(HaulWorld.tile(41, 41), mask, seeds, count), "seeds")
	assert_true(count.value > 1, "the ring, not the tile")
	assert_true(_w.carry.drop_satchel(_mouse, seeds, count.value).ok, "dropped")
	assert_equal(_w.inventory.ground_pile_at_tile(HaulWorld.tile(41, 41)), InventoryScript.NULL_REF,
		"never on the footprint")
	assert_equal(_w.inventory.ground_pile_at_tile(seeds[0]) != InventoryScript.NULL_REF, true,
		"on the first ring tile")


func test_a_hauler_carrying_nothing_drops_nothing() -> void:
	"""No satchel: ok with value 0 and nothing changed."""
	var before: PackedByteArray = _w.state()
	var dropped: InventoryScript.OpResult = _w.carry.drop_satchel(_mouse, _seeds_for(0), 1)
	assert_true(dropped.ok and dropped.value == 0, "nothing to drop")
	assert_equal(_w.state(), before, "byte-identical")


func _seeds_for(tile: int) -> PackedInt32Array:
	"""A full-size seed buffer whose first cell is `tile`."""
	var seeds: PackedInt32Array = PackedInt32Array()
	seeds.resize(GroundPilesScript.REFUND_SEED_CAPACITY)
	seeds[0] = tile
	return seeds


# --- a cancelled haul re-posted --------------------------------------------------------------

func test_a_reposted_haul_loads_by_re_keying_the_goods_already_carried() -> void:
	"""Cancel mid-carry keeps the goods; the fresh haul's load moves nothing and claims them."""
	var loaded: InventoryScript.OpResult = _load(_mouse, 12000)
	assert_true(_w.pool.release_job_claims(JOB, _w.inventory).ok, "the first haul is cancelled")
	assert_true(_w.claim(OTHER_JOB, loaded.ref, SOURCE, 12000), "the fresh haul claims the satchel")
	var satchel: Vector2i = _w.carry.satchel_of(_mouse)
	var containers: int = _w.inventory.live_container_count()
	var reloaded: InventoryScript.OpResult = _w.carry.load_payload(OTHER_JOB, _mouse, loaded.ref)
	assert_true(reloaded.ok, "re-keyed: %s" % reloaded.error)
	assert_equal(_w.carry.satchel_of(_mouse), satchel, "the same satchel")
	assert_equal(_w.inventory.live_container_count(), containers, "no second satchel minted")
	assert_equal(_w.inventory.lot_container(loaded.ref), _w.carry.satchel_of(_mouse), "not moved")
	assert_true(_w.pool.has_claim(OTHER_JOB, loaded.ref, CARRIED), "now carried for the new job")
	assert_true(_w.carry.unload_into_store(OTHER_JOB, _mouse, _target, 0).ok, "and delivered")
	_assert_conserved("after the re-posted haul")


func test_only_the_satchels_owner_hauls_its_goods() -> void:
	"""The otter cannot load goods out of the mouse's satchel."""
	var loaded: InventoryScript.OpResult = _load(_mouse, 3000)
	_w.pool.release_job_claims(JOB, _w.inventory)
	assert_true(_w.claim(OTHER_JOB, loaded.ref, SOURCE, 3000), "claimed")
	assert_equal(_w.carry.load_payload(OTHER_JOB, _otter, loaded.ref).error,
		HaulCarryScript.REFUSE_NOT_HAULERS_SATCHEL, "refused")


func test_a_drop_with_nowhere_to_go_refuses_and_keeps_every_claim() -> void:
	"""The drop proves the walk before releasing anything: a footprint seed changes nothing."""
	_load(_mouse, 12000)
	var before: PackedByteArray = _w.state()
	var dropped: InventoryScript.OpResult = _w.carry.drop_satchel(_mouse,
		_seeds_for(HaulWorld.tile(41, 41)), 1)
	assert_equal(dropped.error, GroundPilesScript.REFUSE_INACCESSIBLE_FOOTPRINT, "refused")
	assert_equal(_w.state(), before, "byte-identical, claims kept")


func test_dropping_an_empty_satchel_just_destroys_it() -> void:
	"""A satchel bound with nothing in it is retired without a pile walk."""
	var satchel: Vector2i = _w.inventory.create_satchel(_w.residents.ref_of(_mouse), 12000).ref
	_w.residents.set_satchel(_mouse, satchel)
	var dropped: InventoryScript.OpResult = _w.carry.drop_satchel(_mouse, _seeds_for(0), 1)
	assert_true(dropped.ok and dropped.value == 0, "nothing moved: %s" % dropped.error)
	assert_false(_w.inventory.is_container_valid(satchel), "destroyed")
	assert_equal(_w.residents.satchel_of(_mouse), InventoryScript.NULL_REF, "unbound")


func test_a_second_claim_on_the_satchel_lot_rolls_the_unload_back() -> void:
	"""Two hauls claim the same carried lot: the pile unload's move refuses, the claim returns."""
	var loaded: InventoryScript.OpResult = _load(_mouse, 12000)
	_w.pool.release_job_claims(JOB, _w.inventory)
	assert_true(_w.claim(OTHER_JOB, loaded.ref, SOURCE, 1000), "J1")
	assert_true(_w.claim(JOB, loaded.ref, SOURCE, 1000), "J2")
	assert_true(_w.carry.load_payload(OTHER_JOB, _mouse, loaded.ref).ok, "J1 re-keyed")
	var before: PackedByteArray = _w.state()
	var unloaded: InventoryScript.OpResult = _w.carry.unload_into_piles(OTHER_JOB, _mouse,
		_seeds_for(HaulWorld.tile(45, 45)), 1, PackedByteArray())
	assert_equal(unloaded.error, GroundPilesScript.REFUSE_MOVE_SOURCE_RESERVED, "J2's claim stands")
	assert_equal(_w.state(), before, "J1's claim restored, nothing moved")
