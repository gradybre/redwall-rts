extends "res://test/framework/test_case.gd"
## Suite for `inventory.gd`'s ground-pile door (DEMO-CONTAIN-R01 #9, decision 0532).
##
## `create_ground_pile()` is driven here through a STUB site authority, so every rule Inventory
## enforces itself -- the transaction requirement, the domain, one pile per tile through the
## derived tile map, the World owner, the fixed 400000 g -- is pinned apart from the world rules
## `ground_piles.gd` supplies (those are `test_ground_piles.gd`). Every refusal is asserted with
## the store's byte image unchanged; reclaim at commit, the map under rollback, the audit and the
## restore rebuild are pinned last.

const InventoryScript := preload("res://scripts/core/inventory.gd")

const ITEM_STONE: int = 3
const STONE_MASS_G: int = 1000
const WORLD: Vector2i = Vector2i(0, 1)
const TILE_A: int = 30 * 128 + 40
const TILE_B: int = 30 * 128 + 41


class StubSite:
	extends RefCounted
	## A site authority whose answer and owner the test sets. Counts its calls.
	var refusal: StringName = &""
	var owner: Vector2i = Vector2i(0, 1)
	var calls: int = 0
	var reenter: InventoryScript = null
	var reentry_error: StringName = &""

	func ground_pile_tile_refusal(_tile: int) -> StringName:
		"""The configured answer, after optionally trying to re-enter the store."""
		calls += 1
		if reenter != null:
			reentry_error = reenter.create_container(Vector2i(1, 1), 1, -1, 0, true).error
		return refusal

	func ground_pile_owner_ref() -> Vector2i:
		"""The configured World ref."""
		return owner


class NotASite:
	extends RefCounted
	## Publishes only one of the two methods.
	func ground_pile_tile_refusal(_tile: int) -> StringName:
		"""Half an authority."""
		return &""


var _inv: InventoryScript = null
var _site: StubSite = null


func before_each() -> void:
	"""Sixteen container rows, sixteen lot rows, one 1000 g item, and a permissive stub site."""
	_inv = InventoryScript.new(16, 16)
	_inv.register_item(ITEM_STONE, STONE_MASS_G, 0)
	_site = StubSite.new()
	assert_true(_inv.set_ground_pile_authority(_site).ok, "the stub site binds")


func _pile_in_transaction(tile: int) -> Vector2i:
	"""Create a pile on `tile` and one lot in it, in one committed transaction."""
	assert_true(_inv.begin().ok, "begin")
	var made: InventoryScript.OpResult = _inv.create_ground_pile(tile)
	assert_true(made.ok, "the pile is created: %s" % made.error)
	assert_true(_inv.create_lot(made.ref, ITEM_STONE, 5000, 0, 0, 0, 0, 0).ok, "a lot goes in")
	assert_true(_inv.commit().ok, "commit")
	return made.ref


# --- the door's own rules -----------------------------------------------------------------------

func test_a_pile_is_world_owned_400000_g_reachable_and_anchored_on_its_tile() -> void:
	"""Every #9 fact Inventory owns is on the row, and the tile map indexes it."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	assert_equal(_inv.container_owner(pile), WORLD, "owned by the World ref")
	assert_equal(_inv.container_policy(pile), InventoryScript.POLICY_GROUND_PILE, "GROUND_PILE")
	assert_equal(InventoryScript.POLICY_GROUND_PILE, 1, "the authored, explicit policy number")
	assert_equal(_inv.container_max_mass_g(pile), 400000, "400000 g")
	assert_equal(_inv.container_filters(pile), InventoryScript.FILTERS_ACCEPT_ALL, "takes anything")
	assert_true(_inv.container_reachable(pile), "reachable")
	assert_equal(_inv.container_anchor_tile(pile), TILE_A, "anchored on its tile")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), pile, "and the map finds it there")
	assert_true(_inv.is_ground_pile(pile), "it is a ground pile")
	assert_true(_inv.audit().ok, "the store audits")


func test_creation_outside_an_explicit_transaction_refuses_and_writes_nothing() -> void:
	"""Alone it would be reclaimed by its own commit, so it is not admitted at all."""
	var before: PackedByteArray = _inv.state_bytes()
	var made: InventoryScript.OpResult = _inv.create_ground_pile(TILE_A)
	assert_equal(made.error, InventoryScript.REFUSE_GROUND_PILE_NEEDS_TRANSACTION, "by name")
	assert_equal(_site.calls, 0, "before asking the site")
	assert_true(_inv.state_bytes() == before, "byte-identical")


func test_one_pile_per_tile_within_and_across_transactions() -> void:
	"""A second pile on the same tile refuses TILE_TAKEN; a neighbouring tile is fine."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var before: PackedByteArray = _inv.state_bytes()
	_inv.begin()
	assert_equal(_inv.create_ground_pile(TILE_A).error,
		InventoryScript.REFUSE_GROUND_PILE_TILE_TAKEN, "a later transaction cannot double it")
	assert_equal(_inv.commit().error, InventoryScript.REFUSE_GROUND_PILE_TILE_TAKEN, "rolled back")
	assert_true(_inv.state_bytes() == before, "byte-identical")
	_inv.begin()
	var other: InventoryScript.OpResult = _inv.create_ground_pile(TILE_B)
	assert_true(other.ok, "the next tile admits one")
	assert_equal(_inv.create_ground_pile(TILE_B).error,
		InventoryScript.REFUSE_GROUND_PILE_TILE_TAKEN, "and the same transaction cannot double it")
	_inv.abort()
	assert_equal(_inv.ground_pile_at_tile(TILE_A), pile, "the first pile is untouched")


func test_an_out_of_domain_tile_refuses_before_the_site_is_asked() -> void:
	"""-1 (unplaced) and 16384 are not tiles a pile can stand on."""
	for tile: int in [-1, -2, 16384, 2147483647]:
		_inv.begin()
		var made: InventoryScript.OpResult = _inv.create_ground_pile(tile)
		assert_equal(made.error, InventoryScript.REFUSE_INVALID_ANCHOR_TILE, "tile %d" % tile)
		_inv.abort()
	assert_equal(_site.calls, 0, "the site was never asked")
	assert_equal(_inv.ground_pile_at_tile(-1), InventoryScript.NULL_REF, "nothing reads at -1")
	assert_equal(_inv.ground_pile_at_tile(16384), InventoryScript.NULL_REF, "or past the grid")


func test_the_sites_refusal_is_returned_by_name() -> void:
	"""Inventory does not soften the world rules: the authority's code is the refusal."""
	_site.refusal = &"GROUND_PILE_TILE_IMPASSABLE"
	var before: PackedByteArray = _inv.state_bytes()
	_inv.begin()
	assert_equal(_inv.create_ground_pile(TILE_A).error, &"GROUND_PILE_TILE_IMPASSABLE", "named")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "byte-identical")


func test_a_malformed_world_ref_refuses_invalid_owner() -> void:
	"""The null ref and a zero generation are not a World."""
	for owner: Vector2i in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1)]:
		_site.owner = owner
		_inv.begin()
		assert_equal(_inv.create_ground_pile(TILE_A).error, InventoryScript.REFUSE_INVALID_OWNER_REF,
			"owner %s" % owner)
		_inv.abort()
	assert_equal(_inv.live_container_count(), 0, "no row survives")


func test_an_unbound_or_released_authority_fails_closed() -> void:
	"""Unbound refuses NO_GROUND_PILE_AUTHORITY; a released one refuses INVALID, never admits."""
	assert_true(_inv.set_ground_pile_authority(null).ok, "unbind")
	assert_false(_inv.has_ground_pile_authority(), "nothing is bound")
	_inv.begin()
	assert_equal(_inv.create_ground_pile(TILE_A).error,
		InventoryScript.REFUSE_NO_GROUND_PILE_AUTHORITY, "unbound refuses")
	_inv.abort()
	var temporary: StubSite = StubSite.new()
	assert_true(_inv.set_ground_pile_authority(temporary).ok, "bind a short-lived site")
	assert_true(_inv.has_ground_pile_authority(), "it is live")
	temporary = null
	assert_false(_inv.has_ground_pile_authority(), "released")
	_inv.begin()
	assert_equal(_inv.create_ground_pile(TILE_A).error,
		InventoryScript.REFUSE_INVALID_GROUND_PILE_AUTHORITY, "released fails closed")
	_inv.abort()


func test_binding_refuses_half_an_authority_and_an_open_transaction() -> void:
	"""Both methods are required, and wiring never changes mid-transaction."""
	assert_equal(_inv.set_ground_pile_authority(NotASite.new()).error,
		InventoryScript.REFUSE_INVALID_GROUND_PILE_AUTHORITY, "half an authority refuses")
	assert_true(_inv.has_ground_pile_authority(), "and the old binding stays")
	_inv.begin()
	assert_equal(_inv.set_ground_pile_authority(null).error,
		InventoryScript.REFUSE_TRANSACTION_OPEN, "no rebinding inside a transaction")
	_inv.abort()


func test_an_authority_that_reenters_the_store_is_refused() -> void:
	"""`_attesting` covers the site call exactly as it covers the other two authorities."""
	_site.reenter = _inv
	_inv.begin()
	assert_true(_inv.create_ground_pile(TILE_A).ok, "the pile itself is created")
	_inv.abort()
	assert_equal(_site.reentry_error, InventoryScript.REFUSE_ATTESTATION_REENTRY,
		"the re-entrant mutator was refused")


func test_a_full_container_store_refuses_capacity() -> void:
	"""Pile rows come out of the same 101376-row bound (ARCH-MEM-002)."""
	for index: int in 16:
		_inv.create_container(Vector2i(5, 1), 1000, -1, 0, true)
	_inv.begin()
	assert_equal(_inv.create_ground_pile(TILE_A).error,
		InventoryScript.REFUSE_CAPACITY_INVENTORY_CONTAINER, "the store is full")
	_inv.abort()
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF, "no map cell")


# --- the other doors cannot make or move a pile -------------------------------------------------

func test_create_container_refuses_the_reserved_pile_policy() -> void:
	"""Only `create_ground_pile()` mints POLICY_GROUND_PILE; every other policy is untouched."""
	var made: InventoryScript.OpResult = _inv.create_container(WORLD, 400000, -1,
		InventoryScript.POLICY_GROUND_PILE, true, TILE_A)
	assert_equal(made.error, InventoryScript.REFUSE_GROUND_PILE_POLICY_RESERVED, "refused")
	var ordinary: Vector2i = _inv.create_container(WORLD, 400000, -1, 2, true, TILE_A).ref
	assert_true(_inv.is_container_valid(ordinary), "policy 2 is opaque")
	assert_false(_inv.is_ground_pile(ordinary), "and is no pile")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF,
		"and an ordinary container on a tile is not a pile")


func test_a_piles_anchor_cannot_be_moved() -> void:
	"""A pile IS its tile; moving it would orphan the map cell."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var before: PackedByteArray = _inv.state_bytes()
	assert_equal(_inv.set_container_anchor(pile, TILE_B).error,
		InventoryScript.REFUSE_GROUND_PILE_ANCHOR_FIXED, "refused")
	assert_equal(_inv.set_container_anchor(pile, -1).error,
		InventoryScript.REFUSE_GROUND_PILE_ANCHOR_FIXED, "unplacing it too")
	assert_true(_inv.state_bytes() == before, "byte-identical")


func test_destroying_a_pile_clears_its_cell_and_rollback_restores_it() -> void:
	"""`destroy_container()` keeps the map honest, inside and outside a transaction."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var lot: Vector2i = _inv.container_first_lot(pile)
	_inv.begin()
	_inv.sink_lot_quantity(lot, 5000)
	assert_true(_inv.destroy_container(pile).ok, "the emptied pile is destroyed")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF, "the cell clears")
	var before_abort: PackedByteArray = _inv.state_bytes()
	_inv.abort()
	assert_false(_inv.state_bytes() == before_abort, "abort changed the image back")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), pile, "and restored the cell")
	assert_true(_inv.audit().ok, "the restored store audits")


func test_aborting_a_pile_creation_is_byte_identical() -> void:
	"""The map cell is journaled with the row, so a rollback leaves no trace."""
	var before: PackedByteArray = _inv.state_bytes()
	_inv.begin()
	var made: InventoryScript.OpResult = _inv.create_ground_pile(TILE_A)
	_inv.create_lot(made.ref, ITEM_STONE, 1000, 0, 0, 0, 0, 0)
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "byte-identical, map included")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF, "no pile")


# --- reclaim at commit (ARCH-MEM-002) -----------------------------------------------------------

func test_an_empty_pile_is_reclaimed_by_the_commit_that_created_it() -> void:
	"""Created and never filled: gone at commit, slot back on the stack, cell cleared."""
	_inv.begin()
	var made: InventoryScript.OpResult = _inv.create_ground_pile(TILE_A)
	assert_true(made.ok, "created")
	assert_true(_inv.is_container_valid(made.ref), "live inside the transaction")
	assert_true(_inv.commit().ok, "commit")
	assert_false(_inv.is_container_valid(made.ref), "reclaimed at commit")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF, "the cell is clear")
	assert_equal(_inv.live_container_count(), 0, "no row is retained")
	assert_true(_inv.audit().ok, "the store audits")


func test_a_pile_emptied_by_an_implicit_operation_is_reclaimed_at_once() -> void:
	"""The last lot sunk outside a transaction: the implicit commit reclaims the pile."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	assert_true(_inv.is_container_valid(pile), "a filled pile survives its commit")
	assert_true(_inv.sink_lot_quantity(_inv.container_first_lot(pile), 5000).ok, "sink the lot")
	assert_false(_inv.is_container_valid(pile), "reclaimed")
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF, "cell cleared")
	assert_true(_inv.audit().ok, "audits")


func test_a_pile_emptied_by_a_transfer_inside_a_transaction_is_reclaimed_at_commit() -> void:
	"""A haul out of the pile empties it; the explicit commit reclaims it, not before."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var store: Vector2i = _inv.create_container(Vector2i(5, 1), 100000, -1, 0, true).ref
	_inv.begin()
	assert_true(_inv.move_lot(_inv.container_first_lot(pile), store).ok, "move the lot out")
	assert_true(_inv.is_container_valid(pile), "still live while the transaction is open")
	assert_true(_inv.commit().ok, "commit")
	assert_false(_inv.is_container_valid(pile), "reclaimed at commit")
	assert_true(_inv.is_container_valid(store), "an ordinary empty container is never reclaimed")


func test_a_partial_withdrawal_keeps_the_pile() -> void:
	"""A pile still holding goods is not reclaimed, claimed or not."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	assert_true(_inv.sink_lot_quantity(_inv.container_first_lot(pile), 1000).ok, "take some")
	assert_true(_inv.is_container_valid(pile), "a pile still holding goods is kept")
	assert_true(_inv.reserve_container_mass(pile, 2000).ok, "claim headroom on it")
	assert_true(_inv.release_container_mass(pile, 2000).ok, "and release it again")
	assert_true(_inv.is_container_valid(pile), "still kept: it holds a lot")
	assert_true(_inv.audit().ok, "audits")


func test_emptying_a_claimed_pile_is_refused_not_unclaimed() -> void:
	"""ARCH-MEM-002 forbids the lotless row, and the claim forbids destroying it: refused."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	assert_true(_inv.reserve_container_mass(pile, 2000).ok, "a claim on the pile")
	var before: PackedByteArray = _inv.state_bytes()
	var sunk: InventoryScript.OpResult = _inv.sink_lot_quantity(_inv.container_first_lot(pile), 5000)
	assert_equal(sunk.error, InventoryScript.REFUSE_GROUND_PILE_EMPTY_WITH_CLAIM,
		"the implicit commit refuses")
	assert_true(_inv.state_bytes() == before, "byte-identical")
	_inv.begin()
	_inv.sink_lot_quantity(_inv.container_first_lot(pile), 5000)
	assert_equal(_inv.commit().error, InventoryScript.REFUSE_GROUND_PILE_EMPTY_WITH_CLAIM,
		"so does an explicit one")
	assert_true(_inv.state_bytes() == before, "byte-identical")
	_inv.begin()
	_inv.sink_lot_quantity(_inv.container_first_lot(pile), 5000)
	_inv.release_container_mass(pile, 2000)
	assert_true(_inv.commit().ok, "releasing the claim in the same transaction lets it go")
	assert_false(_inv.is_container_valid(pile), "and the empty pile is reclaimed")


func test_a_new_pile_holding_only_a_claim_is_refused_at_commit() -> void:
	"""Creating a pile and only reserving on it cannot leave a lotless row behind."""
	var before: PackedByteArray = _inv.state_bytes()
	_inv.begin()
	var pile: Vector2i = _inv.create_ground_pile(TILE_A).ref
	assert_true(_inv.reserve_container_mass(pile, 1000).ok, "reserve on the new pile")
	assert_equal(_inv.commit().error, InventoryScript.REFUSE_GROUND_PILE_EMPTY_WITH_CLAIM, "refused")
	assert_true(_inv.state_bytes() == before, "byte-identical")


func test_the_audit_refuses_a_lotless_pile_at_rest() -> void:
	"""A pile with no lot outside a transaction is an illegal resting row."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var lot: Vector2i = _inv.container_first_lot(pile)
	_inv._unlink_lot(lot.x)
	_inv._l_container_slot[lot.x] = -1
	_inv._c_used_mass_g[pile.x] = 0
	_inv._l_live[lot.x] = 0
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_GROUND_PILE, "refused")


func test_a_rolled_back_transaction_reclaims_nothing() -> void:
	"""A poisoned sequence that emptied a pile restores it, and the pile stays."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var before: PackedByteArray = _inv.state_bytes()
	_inv.begin()
	_inv.sink_lot_quantity(_inv.container_first_lot(pile), 5000)
	_inv.sink_lot_quantity(Vector2i(9, 9), 1)
	assert_false(_inv.commit().ok, "the poisoned transaction refuses")
	assert_true(_inv.state_bytes() == before, "byte-identical")
	assert_true(_inv.is_container_valid(pile), "and the pile was not reclaimed")


# --- the derived map: audit, clear, restore -----------------------------------------------------

func test_the_audit_refuses_a_map_that_disagrees_with_the_rows() -> void:
	"""A stale cell, a missing cell and a mis-sized pile are each AUDIT_GROUND_PILE_MAP."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	_inv._pile_at_tile[TILE_B] = pile.x
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_GROUND_PILE, "a stale extra cell")
	_inv._pile_at_tile[TILE_B] = InventoryScript.NO_PILE
	_inv._pile_at_tile[TILE_A] = InventoryScript.NO_PILE
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_GROUND_PILE, "a missing cell")
	_inv._pile_at_tile[TILE_A] = pile.x
	assert_true(_inv.audit().ok, "repaired, it audits")
	_inv._c_max_mass_g[pile.x] = 400001
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_GROUND_PILE, "a resized pile")


func test_clear_empties_the_map() -> void:
	"""`clear()` refills the map like every other column."""
	_pile_in_transaction(TILE_A)
	_inv.clear()
	assert_equal(_inv.ground_pile_at_tile(TILE_A), InventoryScript.NULL_REF, "the cell is clear")
	assert_equal(_inv.ground_pile_map_bytes(), 65536, "and the map keeps its 65536 bytes")


func test_restore_rebuilds_the_map_identically_to_the_live_one() -> void:
	"""Copy -> restore into a fresh store: the derived map equals the one maintained live."""
	_pile_in_transaction(TILE_A)
	_pile_in_transaction(16383)
	_pile_in_transaction(0)
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(16, 16)
	assert_true(_inv.copy_canonical_columns_into(columns), "copy: %s" % _inv.canonical_detail())
	var restored: InventoryScript = InventoryScript.new(16, 16)
	restored.register_item(ITEM_STONE, STONE_MASS_G, 0)
	assert_true(restored.restore_canonical_columns(columns), "restore: %s" % restored.canonical_detail())
	assert_true(restored._pile_at_tile == _inv._pile_at_tile, "the rebuilt map equals the live one")
	for tile: int in [TILE_A, 16383, 0]:
		assert_equal(restored.ground_pile_at_tile(tile), _inv.ground_pile_at_tile(tile),
			"tile %d resolves to the same pile" % tile)
	assert_true(restored.audit().ok, "the restored store audits")


func test_restore_refuses_two_piles_on_one_tile_and_an_unplaced_pile() -> void:
	"""The map cannot represent either, so the projection is refused before anything is adopted."""
	_pile_in_transaction(TILE_A)
	_pile_in_transaction(TILE_B)
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(16, 16)
	assert_true(_inv.copy_canonical_columns_into(columns), "copy")
	var target: InventoryScript = InventoryScript.new(16, 16)
	var before: PackedByteArray = target.state_bytes()
	columns.c_anchor_tile[1] = TILE_A
	assert_false(target.restore_canonical_columns(columns), "two piles on one tile refuse")
	assert_true(target.state_bytes() == before, "nothing was adopted")
	columns.c_anchor_tile[1] = InventoryScript.UNPLACED_TILE
	assert_false(target.restore_canonical_columns(columns), "an unplaced pile refuses")
	columns.c_anchor_tile[1] = TILE_B
	columns.c_max_mass_g[1] = 1000
	assert_false(target.restore_canonical_columns(columns), "a resized pile refuses")
	columns.c_max_mass_g[1] = 400000
	columns.c_owner_generation[1] = 0
	assert_false(target.restore_canonical_columns(columns), "a malformed owner refuses")
	columns.c_owner_generation[1] = 1
	columns.c_owner_slot[1] = -1
	assert_false(target.restore_canonical_columns(columns), "a null owner slot refuses")
	columns.c_owner_slot[1] = 0
	columns.c_lot_count[1] = 0
	assert_false(target.restore_canonical_columns(columns), "a lotless pile refuses")
	columns.c_lot_count[1] = 1
	target.register_item(ITEM_STONE, STONE_MASS_G, 0)
	assert_true(target.restore_canonical_columns(columns), "the repaired projection restores")


func test_a_reused_slot_that_is_no_longer_a_pile_is_never_reclaimed() -> void:
	"""Empty a pile, destroy it and reuse its slot for an ordinary store, all in one transaction."""
	var pile: Vector2i = _pile_in_transaction(TILE_A)
	var store: Vector2i = _inv.create_container(Vector2i(5, 1), 100000, -1, 0, true).ref
	_inv.begin()
	assert_true(_inv.move_lot(_inv.container_first_lot(pile), store).ok, "haul the lot out")
	assert_true(_inv.destroy_container(pile).ok, "destroy the emptied pile")
	var reused: Vector2i = _inv.create_container(Vector2i(6, 1), 1000, -1, 0, true).ref
	assert_equal(reused.x, pile.x, "the ordinary container takes the pile's old slot")
	assert_true(_inv.commit().ok, "commit")
	assert_true(_inv.is_container_valid(reused), "an empty ordinary container is never reclaimed")
	assert_false(_inv.is_ground_pile(reused), "and it is not a pile")
	assert_true(_inv.audit().ok, "audits")


func test_state_bytes_covers_the_tile_map() -> void:
	"""The derived map is part of the rollback image, so a stray cell is visible."""
	var before: PackedByteArray = _inv.state_bytes()
	_inv._pile_at_tile[TILE_B] = 0
	assert_false(_inv.state_bytes() == before, "a changed map cell changes the image")
	_inv._pile_at_tile[TILE_B] = InventoryScript.NO_PILE
	assert_true(_inv.state_bytes() == before, "and restoring it restores the image")


func test_a_reclaimed_piles_slot_returns_to_the_allocator_under_a_new_generation() -> void:
	"""Reclaim frees the row like `destroy_container()`: same slot next, stale ref stays stale."""
	_inv.begin()
	var pile: Vector2i = _inv.create_ground_pile(TILE_A).ref
	assert_true(_inv.commit().ok, "the empty pile is reclaimed at commit")
	var next: Vector2i = _inv.create_container(Vector2i(5, 1), 1000, -1, 0, true).ref
	assert_equal(next.x, pile.x, "the reclaimed slot is the next one handed out")
	assert_equal(next.y, pile.y + 1, "under the next generation")
	assert_false(_inv.is_container_valid(pile), "so the pile's ref stays stale")
