extends "res://test/framework/test_case.gd"
## The section 6 column APIs of the declared underground owners (ADR 1228): excavation sites and their
## funding, the modular Router and Inventory's spatial endpoint arena. Each is captured from the live
## entry chain while it holds state, refused on damage without a write, and restored exactly, with
## the derived indexes rebuilt.
##
## The state is the committed `underground_entry` checkpoint at its first funded BRACE after tick 2000
## (decision 1240): loaded through the real save loader instead of replaying the chain from tick 0
## before every test. `test_checkpoint_equivalence.gd` proves it equals that replay.

const AutoloadClockReset := preload("res://test/fixtures/autoload_clock_reset.gd")
const Recipes := preload("res://test/fixtures/checkpoint_recipes.gd")
const Store := preload("res://test/fixtures/checkpoint_store.gd")
const Settlement := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Inventory := preload("res://scripts/core/inventory.gd")

var _host: Node = null


func before_each() -> void:
	"""A mounted settlement whose first entry has hauled and is working a paid BRACE (DEC-059: phases
	are short, so this is the first BRACE in progress after tick 2000; its funding receipts are held)."""
	_host = Settlement.new()
	assert_equal(Store.load_into(_host, GameManager, Recipes.UNDERGROUND, Recipes.BRACE_POINT,
		Recipes.underground_content()), "", "the checkpoint loads")
	assert_true(Recipes.is_bracing(_host), "a paid brace is in progress")


func after_each() -> void:
	"""Free the host; leave the autoload as the other suites expect it."""
	_host.free()
	_host = null
	assert_true(AutoloadClockReset.release(), "the autoload is handed back at tick 0")


func _owners() -> Session.Retirement.Owners:
	"""The mounted Session's owner packet."""
	return _host.underground_session()._retirement_owners


func _assert_round_trip(store: Object, label: String) -> Array:
	"""Capture, restore the same columns, recapture identically; returns the capture."""
	var columns: Array = store.save_columns()
	assert_true(store.columns_valid(columns), "%s: its own capture is valid" % label)
	assert_true(store.restore_columns(columns), "%s: restores" % label)
	assert_equal(store.save_columns(), columns, "%s: writes back the very same columns" % label)
	return columns


func _assert_refused(store: Object, columns: Array, ordinal: int, index: int, value: int, label: String) -> void:
	"""One damaged value refuses and leaves the live columns unchanged."""
	var before: Array = store.save_columns()
	var damaged: Array = columns.duplicate(true)
	var column: Variant = damaged[ordinal]
	column[index] = value
	damaged[ordinal] = column
	assert_false(store.columns_valid(damaged), "%s is invalid" % label)
	assert_false(store.restore_columns(damaged), "%s refuses" % label)
	assert_equal(store.save_columns(), before, "%s wrote nothing" % label)


func test_sites_restore_their_columns_and_rebuild_the_key_order_and_job_index() -> void:
	"""Sites hold claimed history at mid-chain; the derived indexes come back identical."""
	var sites: RefCounted = _owners().sites
	assert_true(sites._count > 0, "the entry has claimed sites")
	var ordered: Array = [sites._ordered_key.duplicate(), sites._ordered_row.duplicate(), sites._job_site.duplicate()]
	sites._ordered_key.fill(-1)
	sites._job_site.fill(-1)
	var columns: Array = _assert_round_trip(sites, "sites")
	assert_equal([sites._ordered_key, sites._ordered_row, sites._job_site], ordered, "derived indexes rebuilt")
	_assert_refused(sites, columns, 0, 0, sites._capacity + 1, "another capacity")
	_assert_refused(sites, columns, 9, 0, 99, "another World slot")
	_assert_refused(sites, columns, 20, 0, -1, "an unclaimed populated row")
	_assert_refused(sites, columns, 22, 0, 9, "a phase outside its domain")
	_assert_refused(sites, columns, 30, 0, 7, "a project slot with no generation")


func test_funding_restores_its_receipts_and_refuses_a_broken_chain() -> void:
	"""The excavation funding receipts round-trip; a free row that is also chained refuses."""
	var funding: RefCounted = _owners().sites._funding
	var columns: Array = _assert_round_trip(funding, "funding")
	assert_true(columns[1][0] < funding._capacity, "receipts are in use at mid-chain")
	_assert_refused(funding, columns, 0, 0, 1, "another capacity")
	_assert_refused(funding, columns, 17, 0, -5, "a negative loss")
	var used: int = 0
	while columns[1][0] > 0 and (columns[2] as PackedInt32Array).has(used):
		used += 1
	_assert_refused(funding, columns, 2, 0, used, "a free receipt that is in a chain")


func test_router_restores_its_bindings() -> void:
	"""The Router's Job/Project bindings round-trip; half a binding refuses."""
	var router: RefCounted = _owners().router
	var columns: Array = _assert_round_trip(router, "router")
	_assert_refused(router, columns, 0, 0, 5, "a Job slot with no generation")


func test_inventory_spatial_endpoints_restore_and_audit() -> void:
	"""The spatial arena round-trips through the endpoint audit; a damaged endpoint refuses."""
	var inventory: Inventory = _owners().inventory
	var columns: Array = inventory.save_spatial_columns()
	assert_equal(columns[0][0], inventory._spatial_container_slot.size(), "the composed capacity")
	assert_true((columns[3] as PackedInt32Array).count(-1) < columns[0][0], "R and M are live endpoints")
	assert_equal(inventory.restore_spatial_columns(columns), &"", "restores")
	assert_equal(inventory.save_spatial_columns(), columns, "writes back the same columns")
	var damaged: Array = columns.duplicate(true)
	var row: int = (columns[3] as PackedInt32Array).find(-1)
	var slots: PackedInt32Array = damaged[3]
	slots[row] = 5
	damaged[3] = slots
	assert_equal(inventory.restore_spatial_columns(damaged), Inventory.REFUSE_SPATIAL_LOCATION, "half an endpoint")
	var world: Array = columns.duplicate(true)
	world[1] = PackedInt32Array([columns[1][0] + 1])
	assert_equal(inventory.restore_spatial_columns(world), Inventory.REFUSE_SPATIAL_BINDING, "another World")
	assert_equal(inventory.save_spatial_columns(), columns, "no refusal wrote anything")
