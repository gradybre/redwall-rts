extends "res://test/framework/test_case.gd"
## Suite for DEMO-CONTAIN-R01's container anchor in `scripts/core/inventory.gd` (decision 0531).
##
## Answers 1, 2 and 8: one I32 placement cell per container, `-1` for unplaced, written only by
## `create_container()` and `set_container_anchor()`, read by one bounded cold query that proves
## PLACEMENT the way `containers_by_owner_into()` proves ownership. Each refusal is asserted with
## the store's byte image unchanged, because a destructive gate that half-applied a refused edit
## is the failure the whole ruling exists to prevent.
##
## The save round trip, the refused older schema and the hash coverage of the column live with
## the rest of section 7 in `test_save_section_inventories.gd`.

const InventoryScript := preload("res://scripts/core/inventory.gd")
## Only for the drift guard: the anchor domain must be the exterior grid `buildings.gd` indexes.
const BuildingsScript := preload("res://scripts/core/buildings.gd")

const ITEM_GRAIN: int = 0
const BIG_MASS: int = 100000000
const OWNER_HALL: Vector2i = Vector2i(7, 1)
const OWNER_PROJECT: Vector2i = Vector2i(9, 3)
const OWNER_RESIDENT: Vector2i = Vector2i(2, 1)
const OWNER_WORLD: Vector2i = Vector2i(0, 1)
## A 4 x 3 footprint whose origin is tile (10, 20): x 10..13, z 20..22.
const FOOTPRINT_X: int = 10
const FOOTPRINT_Z: int = 20
const FOOTPRINT_W: int = 4
const FOOTPRINT_D: int = 3
## Values that fit an int32 and are still not placement cells.
const OUT_OF_DOMAIN: Array[int] = [-2, -100, 16384, 16385, 2147483647, -2147483648]

var _inv: InventoryScript = null


func before_each() -> void:
	"""Eight container rows and sixteen lot rows, with one item registered."""
	_inv = InventoryScript.new(8, 16)
	_inv.register_item(ITEM_GRAIN, 250, 0)


func _tile(x: int, z: int) -> int:
	"""GDD §5.1's `z*128+x` placement cell."""
	return z * BuildingsScript.MAP_TILES_X + x


func _container(owner: Vector2i, anchor: int = InventoryScript.UNPLACED_TILE) -> Vector2i:
	"""Create an accept-everything container, optionally anchored, and return its ref."""
	var result: InventoryScript.OpResult = _inv.create_container(owner, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true, anchor)
	assert_true(result.ok, "fixture container is created: %s" % result.error)
	return result.ref


func _footprint_mask() -> PackedByteArray:
	"""A caller-owned tile mask marking exactly the fixture footprint's twelve cells."""
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(_inv.anchor_query_mask_bytes())
	mask.fill(0)
	for z: int in range(FOOTPRINT_Z, FOOTPRINT_Z + FOOTPRINT_D):
		for x: int in range(FOOTPRINT_X, FOOTPRINT_X + FOOTPRINT_W):
			mask[_tile(x, z)] = 1
	return mask


func _pairs(cells: int) -> PackedInt32Array:
	"""A caller-owned pair buffer prefilled with a marker, so a refusal that wrote is visible."""
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(cells)
	buffer.fill(-7)
	return buffer


# --- the domain ---------------------------------------------------------------------------------

func test_anchor_domain_is_the_exterior_grid_buildings_indexes() -> void:
	"""DRIFT GUARD: inventory.gd writes 16384 down itself so it needs no Buildings dependency."""
	assert_equal(InventoryScript.ANCHOR_TILE_COUNT, BuildingsScript.TILE_COUNT,
		"the anchor domain is exactly the 128 x 128 grid")
	assert_equal(InventoryScript.UNPLACED_TILE, -1, "unplaced is -1, per answer 2")
	assert_equal(_inv.anchor_query_mask_bytes(), BuildingsScript.TILE_COUNT,
		"the caller's mask holds one byte per placement cell")


func test_domain_predicate_accepts_unplaced_and_both_grid_ends_only() -> void:
	"""-1, 0 and 16383 are in the domain; everything else is not."""
	assert_true(InventoryScript.is_anchor_tile_in_domain(-1), "unplaced is in the domain")
	assert_true(InventoryScript.is_anchor_tile_in_domain(0), "the first cell is")
	assert_true(InventoryScript.is_anchor_tile_in_domain(16383), "the last cell is")
	for tile: int in OUT_OF_DOMAIN:
		assert_false(InventoryScript.is_anchor_tile_in_domain(tile), "%d is not" % tile)


# --- creation -----------------------------------------------------------------------------------

func test_a_container_created_without_an_anchor_is_unplaced() -> void:
	"""Every pre-0531 caller keeps creating unplaced containers: satchels, packs, residue."""
	var satchel: Vector2i = _inv.create_container(OWNER_RESIDENT, 30000,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true).ref
	assert_true(_inv.is_container_valid(satchel), "the five-argument call still creates")
	assert_equal(_inv.container_anchor_tile(satchel), InventoryScript.UNPLACED_TILE,
		"and the container sits on no tile")


func test_create_container_records_the_anchor_at_both_ends_of_the_grid() -> void:
	"""A building store is anchored explicitly at its origin tile (answer 3a)."""
	var first: Vector2i = _container(OWNER_HALL, 0)
	var last: Vector2i = _container(OWNER_HALL, 16383)
	assert_equal(_inv.container_anchor_tile(first), 0, "cell 0 is recorded")
	assert_equal(_inv.container_anchor_tile(last), 16383, "and so is the last cell")
	assert_true(_inv.audit().ok, "the audited store accepts both")


func test_create_container_refuses_an_out_of_domain_anchor_before_writing() -> void:
	"""INVALID_ANCHOR_TILE, with no row allocated and not one byte of the store changed."""
	var before: PackedByteArray = _inv.state_bytes()
	for tile: int in OUT_OF_DOMAIN:
		var result: InventoryScript.OpResult = _inv.create_container(OWNER_HALL, BIG_MASS,
			InventoryScript.FILTERS_ACCEPT_ALL, 0, true, tile)
		assert_false(result.ok, "anchor %d refuses" % tile)
		assert_equal(result.error, InventoryScript.REFUSE_INVALID_ANCHOR_TILE, "by name")
		assert_equal(result.ref, InventoryScript.NULL_REF, "and returns no ref")
	assert_equal(_inv.live_container_count(), 0, "no row was allocated")
	assert_true(_inv.state_bytes() == before, "the store is byte-identical")


func test_create_container_checks_the_anchor_before_store_capacity() -> void:
	"""A full store still names the bad anchor, so the refusal says what the caller got wrong."""
	for index: int in 8:
		_container(OWNER_HALL)
	var full: InventoryScript.OpResult = _inv.create_container(OWNER_HALL, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true, 16384)
	assert_equal(full.error, InventoryScript.REFUSE_INVALID_ANCHOR_TILE, "the anchor is named")
	var valid: InventoryScript.OpResult = _inv.create_container(OWNER_HALL, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true, 5)
	assert_equal(valid.error, InventoryScript.REFUSE_CAPACITY_INVENTORY_CONTAINER,
		"while a valid anchor reaches the capacity refusal")


func test_a_reused_slot_does_not_inherit_the_retired_rows_anchor() -> void:
	"""A retired placed row leaves residue; an UNPLACED container in that slot must not keep it.

	Without this, a satchel created into a slot a store once used would be reported standing on
	the store's footprint -- a phantom blocker, or worse, a phantom "covered" container.
	"""
	var placed: Vector2i = _container(OWNER_HALL, _tile(FOOTPRINT_X, FOOTPRINT_Z))
	assert_true(_inv.destroy_container(placed).ok, "the placed store retires")
	var satchel: Vector2i = _container(OWNER_RESIDENT)
	assert_equal(satchel.x, placed.x, "the satchel takes the same slot")
	assert_equal(_inv.container_anchor_tile(satchel), InventoryScript.UNPLACED_TILE,
		"and is unplaced, not on the old store's tile")
	var everywhere: PackedByteArray = PackedByteArray()
	everywhere.resize(_inv.anchor_query_mask_bytes())
	everywhere.fill(1)
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	assert_true(_inv.containers_anchored_in_into(everywhere, _pairs(_inv.owner_query_cells()), out),
		"the scan completes")
	assert_equal(out.value, 0, "and nothing is reported anywhere")


func test_the_query_reports_the_current_generation_of_a_reused_slot() -> void:
	"""The pairs are complete refs: a slot retired and re-placed answers at its NEW generation."""
	var first: Vector2i = _container(OWNER_HALL, _tile(FOOTPRINT_X, FOOTPRINT_Z))
	assert_true(_inv.destroy_container(first).ok, "the first store retires")
	var second: Vector2i = _container(OWNER_HALL, _tile(FOOTPRINT_X + 1, FOOTPRINT_Z))
	assert_equal(second.x, first.x, "the slot is reused")
	assert_equal(second.y, first.y + 1, "at the next container generation")
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	assert_true(_inv.containers_anchored_in_into(_footprint_mask(), pairs, out), "it completes")
	assert_equal(out.value, 1, "one live container on the footprint")
	assert_equal(Vector2i(pairs[0], pairs[1]), second, "named by its current, valid ref")
	assert_true(_inv.is_container_valid(Vector2i(pairs[0], pairs[1])), "which validates")


func test_clear_resets_every_anchor_to_unplaced() -> void:
	"""clear() refills the column, so no residue survives into a cleared store's rollback image."""
	var box: Vector2i = _container(OWNER_HALL, 5)
	assert_true(_inv.destroy_container(_container(OWNER_PROJECT, 6)).ok, "one placed row retires")
	assert_equal(_inv.container_anchor_tile(box), 5, "the precondition: a live anchor")
	_inv.clear()
	var expected: PackedInt32Array = PackedInt32Array()
	expected.resize(8)
	expected.fill(InventoryScript.UNPLACED_TILE)
	assert_equal(_inv._c_anchor_tile, expected, "every row, live or dead, is unplaced again")


func test_an_anchor_beyond_int32_is_refused_not_truncated() -> void:
	"""GDScript ints are 64-bit: 4294967301 would wrap to cell 5 in an I32 if it got through."""
	var box: Vector2i = _container(OWNER_HALL, 5)
	assert_equal(_inv.set_container_anchor(box, 4294967301).error,
		InventoryScript.REFUSE_INVALID_ANCHOR_TILE, "a 64-bit value refuses")
	assert_equal(_inv.create_container(OWNER_HALL, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL,
		0, true, 4294967301).error, InventoryScript.REFUSE_INVALID_ANCHOR_TILE, "on create as well")
	assert_equal(_inv.container_anchor_tile(box), 5, "and nothing was written")


# --- set_container_anchor -----------------------------------------------------------------------

func test_set_container_anchor_places_moves_and_unplaces() -> void:
	"""The only mover of an anchor; -1 unplaces explicitly."""
	var box: Vector2i = _container(OWNER_PROJECT)
	assert_true(_inv.set_container_anchor(box, _tile(11, 21)).ok, "the project container is placed")
	assert_equal(_inv.container_anchor_tile(box), _tile(11, 21), "on the subject's tile")
	assert_true(_inv.set_container_anchor(box, 16383).ok, "it moves to the last cell")
	assert_equal(_inv.container_anchor_tile(box), 16383, "which is recorded")
	assert_true(_inv.set_container_anchor(box, InventoryScript.UNPLACED_TILE).ok, "and unplaces")
	assert_equal(_inv.container_anchor_tile(box), InventoryScript.UNPLACED_TILE, "explicitly")


func test_set_container_anchor_refuses_an_out_of_domain_tile_without_writing() -> void:
	"""INVALID_ANCHOR_TILE leaves the old anchor and every other byte in place."""
	var box: Vector2i = _container(OWNER_HALL, 300)
	var before: PackedByteArray = _inv.state_bytes()
	for tile: int in OUT_OF_DOMAIN:
		var result: InventoryScript.OpResult = _inv.set_container_anchor(box, tile)
		assert_false(result.ok, "tile %d refuses" % tile)
		assert_equal(result.error, InventoryScript.REFUSE_INVALID_ANCHOR_TILE, "by name")
	assert_equal(_inv.container_anchor_tile(box), 300, "the anchor did not move")
	assert_true(_inv.state_bytes() == before, "the store is byte-identical")


func test_set_container_anchor_refuses_a_dead_or_stale_container() -> void:
	"""Liveness and generation are checked: a retired row and a reused slot both refuse."""
	var retired: Vector2i = _container(OWNER_HALL, 40)
	assert_true(_inv.destroy_container(retired).ok, "the container is retired")
	var before: PackedByteArray = _inv.state_bytes()
	var dead: InventoryScript.OpResult = _inv.set_container_anchor(retired, 41)
	assert_equal(dead.error, InventoryScript.REFUSE_INVALID_CONTAINER, "a dead row refuses")
	assert_true(_inv.state_bytes() == before, "and writes nothing, not even dead residue")
	var reused: Vector2i = _container(OWNER_WORLD, 50)
	assert_equal(reused.x, retired.x, "the slot is handed out again")
	var stale: InventoryScript.OpResult = _inv.set_container_anchor(retired, 41)
	assert_equal(stale.error, InventoryScript.REFUSE_INVALID_CONTAINER,
		"the old ref does not reach the new row")
	assert_equal(_inv.container_anchor_tile(reused), 50, "whose anchor is untouched")
	for bad: Vector2i in [InventoryScript.NULL_REF, Vector2i(99, 1), Vector2i(reused.x, 0)]:
		assert_equal(_inv.set_container_anchor(bad, 41).error,
			InventoryScript.REFUSE_INVALID_CONTAINER, "(%d, %d) refuses" % [bad.x, bad.y])


func test_a_poisoned_transaction_restores_the_anchor_byte_for_byte() -> void:
	"""The write is journaled: rollback puts back the pre-image, not the clear value."""
	var box: Vector2i = _container(OWNER_HALL, 77)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "a transaction opens")
	assert_true(_inv.set_container_anchor(box, 78).ok, "the anchor moves inside it")
	assert_true(_inv.create_container(OWNER_PROJECT, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL,
		0, true, 79).ok, "and a placed container is created inside it")
	assert_false(_inv.set_container_anchor(box, -5).ok, "then a refusal poisons it")
	assert_false(_inv.commit().ok, "so the commit rolls everything back")
	assert_equal(_inv.container_anchor_tile(box), 77, "the old anchor is back")
	assert_true(_inv.state_bytes() == before, "and the store is byte-identical to the start")


func test_a_committed_transaction_keeps_the_anchor() -> void:
	"""The journal only undoes on refusal: a clean commit keeps the move."""
	var box: Vector2i = _container(OWNER_HALL, 77)
	assert_true(_inv.begin().ok, "a transaction opens")
	assert_true(_inv.set_container_anchor(box, 78).ok, "the anchor moves")
	assert_true(_inv.commit().ok, "and commits")
	assert_equal(_inv.container_anchor_tile(box), 78, "the new anchor stands")


# --- readers ------------------------------------------------------------------------------------

func test_the_refusal_carrying_reader_tells_unplaced_from_missing() -> void:
	"""The plain reader answers -1 for both; the `_into` form refuses a missing container."""
	var satchel: Vector2i = _container(OWNER_RESIDENT)
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	assert_true(_inv.container_anchor_tile_into(satchel, out), "an unplaced container answers")
	assert_equal(out.value, InventoryScript.UNPLACED_TILE, "with -1")
	var placed: Vector2i = _container(OWNER_HALL, 900)
	assert_true(_inv.container_anchor_tile_into(placed, out), "a placed container answers")
	assert_equal(out.value, 900, "with its cell")
	assert_false(_inv.container_anchor_tile_into(Vector2i(6, 1), out), "a missing one refuses")
	assert_equal(out.error, String(InventoryScript.REFUSE_INVALID_CONTAINER), "by name")
	assert_equal(out.value, 0, "with the value channel zeroed")
	assert_equal(_inv.container_anchor_tile(Vector2i(6, 1)), InventoryScript.UNPLACED_TILE,
		"while the plain reader cannot tell the two apart, as documented")
	assert_true(_inv.destroy_container(placed).ok, "the placed container retires")
	var reused: Vector2i = _container(OWNER_PROJECT, 901)
	assert_equal(reused.x, placed.x, "and its slot is placed again")
	assert_equal(_inv.container_anchor_tile(placed), InventoryScript.UNPLACED_TILE,
		"the stale ref does not read the new row's 901")
	assert_false(_inv.container_anchor_tile_into(placed, out), "and the _into form refuses it")


# --- the anchor query ---------------------------------------------------------------------------

func test_the_query_finds_every_container_on_a_footprint_in_slot_order() -> void:
	"""Store, project container and a doorway pile on the footprint; satchel and outside excluded.

	Answers 1, 2, 3a, 3c, 3d and 5 in one fixture: three containers anchored on the footprint
	(two of them on the SAME tile, which a tile -> container map could not hold), one pile just
	outside it, one unplaced satchel, and one retired row whose anchor is dead residue on the
	footprint. Only the three live footprint rows come back, ascending by slot.
	"""
	var store: Vector2i = _container(OWNER_HALL, _tile(FOOTPRINT_X, FOOTPRINT_Z))
	var satchel: Vector2i = _container(OWNER_RESIDENT)
	var outside: Vector2i = _container(OWNER_WORLD, _tile(FOOTPRINT_X + FOOTPRINT_W, FOOTPRINT_Z))
	var project: Vector2i = _container(OWNER_PROJECT, _tile(FOOTPRINT_X, FOOTPRINT_Z))
	var retired: Vector2i = _container(OWNER_HALL, _tile(FOOTPRINT_X + 1, FOOTPRINT_Z + 1))
	var doorway: Vector2i = _container(OWNER_WORLD,
		_tile(FOOTPRINT_X + FOOTPRINT_W - 1, FOOTPRINT_Z + FOOTPRINT_D - 1))
	assert_true(_inv.destroy_container(retired).ok, "one footprint container is retired")
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	assert_true(_inv.containers_anchored_in_into(_footprint_mask(), pairs, out),
		"the scan completes")
	assert_equal(out.value, 3, "store, project and the doorway pile")
	assert_equal(Vector2i(pairs[0], pairs[1]), store, "the store comes first")
	assert_equal(Vector2i(pairs[2], pairs[3]), project, "then the project on the same tile")
	assert_equal(Vector2i(pairs[4], pairs[5]), doorway, "then the pile in the doorway corner")
	assert_equal(pairs[6], -7, "and nothing is written past the result")
	assert_equal(_inv.container_anchor_tile(satchel), -1, "the satchel was unplaced throughout")
	assert_equal(_inv.container_anchor_tile(outside), _tile(FOOTPRINT_X + FOOTPRINT_W, FOOTPRINT_Z),
		"and the outside pile really sits one tile east of the footprint")


func test_an_unplaced_container_is_never_reported_whatever_the_mask_marks() -> void:
	"""Answer 3d: a satchel sits on no tile, so even an all-marked mask cannot select it."""
	_container(OWNER_RESIDENT)
	_container(OWNER_RESIDENT)
	var everywhere: PackedByteArray = PackedByteArray()
	everywhere.resize(_inv.anchor_query_mask_bytes())
	everywhere.fill(1)
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	assert_true(_inv.containers_anchored_in_into(everywhere, pairs, out), "the scan completes")
	assert_equal(out.value, 0, "and reports no unplaced container")
	var corner: Vector2i = _container(OWNER_WORLD, 16383)
	assert_true(_inv.containers_anchored_in_into(everywhere, pairs, out), "asked again")
	assert_equal(out.value, 1, "the one placed container, on the very last cell, is found")
	assert_equal(Vector2i(pairs[0], pairs[1]), corner, "by its complete ref")


func test_any_nonzero_mask_byte_marks_a_tile() -> void:
	"""The mask is a set: 255 marks a tile as surely as 1, and 0 is the only unmarked value."""
	var box: Vector2i = _container(OWNER_HALL, 12)
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(_inv.anchor_query_mask_bytes())
	mask.fill(0)
	mask[12] = 255
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	assert_true(_inv.containers_anchored_in_into(mask, pairs, out), "the scan completes")
	assert_equal(out.value, 1, "the marked tile's container is found")
	assert_equal(Vector2i(pairs[0], pairs[1]), box, "by its ref")
	mask[12] = 0
	mask[13] = 1
	assert_true(_inv.containers_anchored_in_into(mask, pairs, out), "the neighbour is asked")
	assert_equal(out.value, 0, "and a container one tile away is not on it")


func test_a_clear_footprint_is_a_complete_scan_reporting_zero() -> void:
	"""The only shape allowed to mean "nothing stands here": success with a count of 0."""
	_container(OWNER_HALL, _tile(0, 0))
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	assert_true(_inv.containers_anchored_in_into(_footprint_mask(), pairs, out), "it completes")
	assert_equal(out.value, 0, "nothing is anchored on the footprint")
	assert_true(out.error.is_empty(), "and it is an answer, not a refusal")
	assert_equal(pairs[0], -7, "with nothing written")


func test_the_query_refuses_a_mask_of_the_wrong_size() -> void:
	"""A short mask would read every tile past its end as unaffected: refused, not truncated."""
	_container(OWNER_HALL, 16383)
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	for size: int in [0, 16383, 16385]:
		var mask: PackedByteArray = PackedByteArray()
		mask.resize(size)
		mask.fill(1)
		assert_false(_inv.containers_anchored_in_into(mask, pairs, out), "%d bytes refuses" % size)
		assert_equal(out.error, String(InventoryScript.REFUSE_ANCHOR_MASK_SHAPE), "by name")
		assert_equal(out.value, 0, "with the count cleared")
	assert_equal(pairs, _pairs(_inv.owner_query_cells()), "and the buffer untouched")


func test_the_query_refuses_an_undersized_buffer_without_truncating() -> void:
	"""Two placed containers need four cells: three refuse and write nothing, four succeed."""
	_container(OWNER_HALL, _tile(FOOTPRINT_X, FOOTPRINT_Z))
	_container(OWNER_PROJECT, _tile(FOOTPRINT_X + 1, FOOTPRINT_Z))
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var small: PackedInt32Array = _pairs(3)
	assert_false(_inv.containers_anchored_in_into(_footprint_mask(), small, out),
		"three cells cannot hold two pairs")
	assert_equal(out.error, String(InventoryScript.REFUSE_OWNER_OUTPUT_TOO_SMALL), "by name")
	assert_equal(out.value, 0, "with the count cleared")
	assert_equal(small, _pairs(3), "and not one cell written")
	var exact: PackedInt32Array = _pairs(4)
	assert_true(_inv.containers_anchored_in_into(_footprint_mask(), exact, out), "four cells do")
	assert_equal(out.value, 2, "exactly two pairs")


func test_the_query_is_read_only_on_success_and_refusal() -> void:
	"""Neither a full answer nor a refusal changes one byte of the store."""
	for index: int in 8:
		_container(OWNER_HALL, _tile(FOOTPRINT_X + index % FOOTPRINT_W, FOOTPRINT_Z))
	var before: PackedByteArray = _inv.state_bytes()
	var out: InventoryScript.IntMath.IntResult = InventoryScript.IntMath.IntResult.new()
	var pairs: PackedInt32Array = _pairs(_inv.owner_query_cells())
	assert_true(_inv.containers_anchored_in_into(_footprint_mask(), pairs, out), "full store")
	assert_equal(out.value, 8, "every row is on the footprint")
	assert_equal(pairs[14], 7, "the last pair is the last slot")
	assert_false(_inv.containers_anchored_in_into(_footprint_mask(), _pairs(2), out),
		"an undersized ask refuses")
	assert_true(_inv.state_bytes() == before, "and the store is byte-identical")


# --- audit, rollback image and canonical projection ----------------------------------------------

func test_audit_refuses_an_out_of_domain_anchor_on_a_live_row_only() -> void:
	"""No public door writes one, so audit() is what catches a corrupted column."""
	var box: Vector2i = _container(OWNER_HALL, 5)
	assert_true(_inv.audit().ok, "a valid anchor audits")
	_inv._c_anchor_tile[box.x] = 16384
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_ANCHOR, "16384 is caught")
	_inv._c_anchor_tile[box.x] = -2
	assert_equal(_inv.audit().error, InventoryScript.REFUSE_AUDIT_ANCHOR, "-2 is caught")
	assert_true(_inv.destroy_container(_container(OWNER_PROJECT, 6)).ok, "a second row retires")
	_inv._c_anchor_tile[box.x] = 5
	_inv._c_anchor_tile[1] = 99999
	assert_true(_inv.audit().ok, "dead residue is not audited as a live anchor")


func test_the_rollback_image_includes_the_anchor() -> void:
	"""state_bytes() must see the column, or a rollback test could not catch a lost anchor."""
	var box: Vector2i = _container(OWNER_HALL, 5)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.set_container_anchor(box, 6).ok, "the anchor moves")
	assert_false(_inv.state_bytes() == before, "and the image changes with it")


func test_the_canonical_projection_copies_live_anchors_and_masks_dead_ones() -> void:
	"""Live rows keep their anchor exactly; an inactive row is emitted as UNPLACED_TILE."""
	var placed: Vector2i = _container(OWNER_HALL, 1234)
	var satchel: Vector2i = _container(OWNER_RESIDENT)
	var retired: Vector2i = _container(OWNER_PROJECT, 4321)
	assert_true(_inv.destroy_container(retired).ok, "one row retires with residue 4321")
	assert_equal(_inv._c_anchor_tile[retired.x], 4321, "the live column keeps the residue")
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(8, 16)
	assert_true(_inv.copy_canonical_columns_into(columns), "copy: %s" % _inv.canonical_detail())
	assert_equal(columns.c_anchor_tile[placed.x], 1234, "the placed store keeps its cell")
	assert_equal(columns.c_anchor_tile[satchel.x], -1, "the satchel stays unplaced")
	assert_equal(columns.c_anchor_tile[retired.x], -1, "the dead row is masked to -1")
	assert_equal(columns.c_anchor_tile[7], -1, "and so is a never-used row")


func test_restore_refuses_an_out_of_domain_live_anchor_and_a_dead_anchor_residue() -> void:
	"""The restore side is stricter than capture: neither shape is repaired on the way in."""
	_container(OWNER_HALL, 1234)
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(8, 16)
	assert_true(_inv.copy_canonical_columns_into(columns), "copy")
	var target: InventoryScript = InventoryScript.new(8, 16)
	var before: PackedByteArray = target.state_bytes()
	columns.c_anchor_tile[0] = 16384
	assert_false(target.restore_canonical_columns(columns), "a live anchor of 16384 refuses")
	assert_true(target.canonical_detail().contains("anchored"), "and names the anchor")
	columns.c_anchor_tile[0] = 1234
	columns.c_anchor_tile[5] = 3
	assert_false(target.restore_canonical_columns(columns), "an inactive anchor of 3 refuses")
	assert_true(target.state_bytes() == before, "and neither refusal wrote into the target")
	columns.c_anchor_tile[5] = -1
	assert_true(target.restore_canonical_columns(columns), "the canonical projection restores")
	assert_equal(target.container_anchor_tile(Vector2i(0, 1)), 1234, "with the anchor intact")
