extends "res://test/framework/test_case.gd"
## Confirm all's order route in the demo (demo/build_panel/demo_build_orders.gd; decision 1871, Brendan's ruling 2): a
## batch operation's own planner draft goes through the planner's runtime over ACTUAL owners (the room admission
## fixture also used by test_modular_runtime.gd), reaches RoomOrders, and comes back refused in the runtime's words
## with no access endpoint -- spending nothing and changing no owner (BUILD-REQ-019, UX-BUILD-T04). Unbound, every order
## is refused saying so.

const Orders := preload("res://demo/build_panel/demo_build_orders.gd")
const Fixture := preload("res://test/test_underground_room_admission.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Bindings := preload("res://scripts/core/underground_room_bindings.gd")
const Runtime := preload("res://demo/burrow/modular_runtime.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")

const KITCHEN: int = 2

var _f: Fixture = null
var _camera: Camera3D = null


func before_each() -> void:
	"""Actual finite World owners (the admission fixture) and a camera for the planner's world tool."""
	_f = Fixture.new()
	_f.before_each()
	assert_equal(_f.failures, PackedStringArray(), "actual owner fixture initialized")
	_camera = Camera3D.new()


func after_each() -> void:
	"""Release the fixture's owners and the camera without leaks."""
	_camera.free()
	_camera = null
	_f.after_each()
	assert_equal(_f.failures, PackedStringArray(), "actual owner teardown passed")
	_f = null


func _bound() -> Orders:
	"""The route bound to the fixture's RoomOrders, room bindings and level catalog at its datum."""
	var orders: Orders = Orders.new()
	orders.bind_owners(_f._orders, _f._rooms, _f._levels, _camera, Vector3i(Fixture.X, 0, Fixture.Z),
		Rect2i(-16, -16, 32, 32), 512)
	return orders


func _kitchen() -> Draft:
	"""A 6 × 4-cell Kitchen draft on level 1, on the 1 m grid."""
	var draft: Draft = Draft.new()
	assert_equal(draft.configure(KITCHEN, 1, 1024, 512, Rect2i(-16, -16, 32, 32), false), &"", "1 m Kitchen draft")
	draft.begin_stroke(Draft.RECTANGLE, Vector2i(0, 0), 0, false)
	draft.extend_stroke(Vector2i(5, 3))
	assert_equal(draft.finish_stroke(), &"", "painted")
	return draft


func test_an_order_reaches_actual_room_admission_and_is_refused_without_access() -> void:
	"""The planner's runtime is composed over the actual owners; RoomOrders refuses the room for its missing approach,
	in the runtime's own words; the draft is kept and nothing in any owner changed."""
	var orders: Orders = _bound()
	assert_true(orders.bound(), "bound to the actual owners")
	var draft: Draft = _kitchen()
	var request: Dictionary = draft.snapshot()
	var before: PackedByteArray = _f._state()
	var answer: Dictionary = orders.submit(draft, 1, KITCHEN)
	assert_false(bool(answer.ok), "refused")
	assert_equal(answer.get("error_code", &""), Bindings.REFUSE_ENTRY, "the actual missing approach")
	assert_equal(String(answer.error), Validity.no_way_in() + Orders.LATER_WAY_IN, "in the panel's words (review H3)")
	assert_equal(int(answer.kind), Validity.KIND_BLOCKED, "! Blocked: retried by the next Confirm all")
	assert_equal(_f._rooms.preflights, 1, "the real RoomOrders reached room preflight once")
	assert_equal(_f._state(), before, "no identity, site, work or store changed")
	assert_equal(draft.snapshot(), request, "the draft is kept exactly")
	assert_equal([orders.submitted, orders.admitted], [1, 0], "counted")


func test_an_order_on_a_level_without_a_roof_is_refused_in_words() -> void:
	"""Level 0 (the surface in the catalog) has no roof: refused before the runtime, saying to return to the floor."""
	var orders: Orders = _bound()
	var answer: Dictionary = orders.submit(_kitchen(), 0, KITCHEN)
	assert_false(bool(answer.ok), "refused")
	assert_false(String(answer.error).is_empty(), "with words: %s" % answer.error)
	assert_equal(_f._rooms.preflights, 0, "never reached RoomOrders")


func test_unbound_every_order_is_refused_saying_so() -> void:
	"""No underground composed in this run: the default planning area, and each order refused in words."""
	var orders: Orders = Orders.new()
	assert_false(orders.bound(), "unbound")
	assert_equal(orders.cell_bounds(), Rect2i(0, 0, 256, 256), "the level pack's square")
	assert_equal(orders.clear_height(), 4096, "the level pack's clear height")
	assert_equal(orders.bind_session(null, _camera), &"BUILD_ORDERS_NO_SESSION", "no session")
	var answer: Dictionary = orders.submit(_kitchen(), 1, KITCHEN)
	assert_false(bool(answer.ok), "refused")
	assert_equal(String(answer.error), Orders.NOT_COMPOSED, "saying why")


func test_the_route_reads_the_catalogs_clear_height() -> void:
	"""Bound, the ledger's clear height is the actual level 1's."""
	var orders: Orders = _bound()
	var record: Levels.Record = Levels.Record.new()
	assert_equal(_f._levels.level_into(1, 0, record), &"", "level 1")
	assert_equal(orders.clear_height(), record.clear_height_u, "read from the catalog")
	assert_equal(orders.datum_u(), Vector3i(Fixture.X, 0, Fixture.Z), "the datum kept")


func test_grid_bounds_divide_the_domain_into_metre_cells() -> void:
	"""modular_room_mode.gd's rule at 1024 u a cell: offsets from the datum in whole cells."""
	var bounds: PackedInt32Array = PackedInt32Array([0, -32768, 0, 262144, 16384, 262144])
	assert_equal(Orders.grid_bounds(bounds, Vector3i(0, 512, 0)), Rect2i(0, 0, 256, 256), "the pack's square")
	assert_equal(Orders.grid_bounds(bounds, Vector3i(2048, 0, 1024)), Rect2i(-2, -1, 256, 256), "from another datum")


func test_confirm_all_through_the_route_keeps_the_refused_room_with_its_reason() -> void:
	"""A batch's Confirm all through the bound route: the Kitchen stays, "! Blocked" with the runtime's words."""
	var orders: Orders = _bound()
	var batch: Batch = Batch.new()
	assert_equal(batch.configure(BuildCatalog.new(), Rect2i(-16, -16, 32, 32), 512), &"", "batch")
	batch.begin_stroke(KITCHEN, 1, Vector2i(0, 0))
	batch.extend_stroke(Vector2i(5, 3))
	batch.finish_stroke()
	var before: PackedByteArray = _f._state()
	assert_equal(batch.confirm_all(orders.submit), PackedInt32Array([0, 1]), "refused")
	assert_equal(batch.pending_count(), 1, "kept")
	assert_equal(batch.operation_reason(0), Validity.no_way_in() + Orders.LATER_WAY_IN, "with the reason")
	assert_equal(batch.operation_kind(0), Validity.KIND_BLOCKED, "! Blocked")
	assert_equal(batch.first_invalid(), -1, "a route refusal does not hold Confirm all back")
	assert_equal(batch.first_refused(), 0, "it is retried by the next Confirm all")
	assert_equal(_f._state(), before, "nothing changed in any owner")


func _owners() -> PackedByteArray:
	"""Every actual owner's bytes: identities, sites, work and stores (`_state`), and the reservations pool's rows."""
	var out: PackedByteArray = _f._state()
	out.append_array(_f._sites._pool.state_bytes())
	return out


func test_painting_undoing_discarding_and_confirming_touch_no_owner() -> void:
	"""Review M7: the batch's every step -- paint, undo, redo, discard, and a refused Confirm all through the bound
	route -- leaves the actual inventory, reservations, jobs, sites and identities byte-for-byte as they were."""
	var orders: Orders = _bound()
	var batch: Batch = Batch.new()
	assert_equal(batch.configure(BuildCatalog.new(), Rect2i(-16, -16, 32, 32), 512), &"", "batch")
	var before: PackedByteArray = _owners()
	var reserved: int = _f._sites._pool.active_row_count()
	for at: int in 2:
		batch.begin_stroke(KITCHEN, 1, Vector2i(at * 8, 0))
		batch.extend_stroke(Vector2i(at * 8 + 5, 3))
		batch.finish_stroke()
	assert_equal(_owners(), before, "painted: nothing reserved, stored, worked or identified")
	assert_true(batch.undo() and batch.redo(), "undo and redo")
	assert_equal(_owners(), before, "undone and redone: unchanged")
	batch.confirm_all(orders.submit)
	assert_equal(_owners(), before, "refused Confirm all: unchanged")
	assert_equal(_f._sites._pool.active_row_count(), reserved, "no reservation row taken")
	batch.discard_all()
	assert_equal(_owners(), before, "discarded: unchanged")


func test_classify_names_the_way_in_and_the_never_possible_sites() -> void:
	"""Review H3: no approach is "! No way in" with the later-update clause; water, a cut and protected ground are
	"X Cannot dig here: …"; any other refusal keeps the runtime's words as "! Blocked"; an admission is untouched."""
	var refused: Dictionary = {"ok": false, "error": "x", "error_code": Bindings.REFUSE_ENTRY}
	var entry: Dictionary = Orders.classify(refused)
	assert_equal(refused, {"ok": false, "error": "x", "error_code": Bindings.REFUSE_ENTRY}, "the runtime's answer kept")
	assert_equal([entry.error, entry.kind], [Validity.no_way_in() + Orders.LATER_WAY_IN, Validity.KIND_BLOCKED], "entry")
	var water: Dictionary = Orders.classify({"ok": false, "error": "x", "error_code": Terrain.REFUSE_WATER})
	assert_equal([water.error, water.kind], [Validity.cannot_dig("water"), Validity.KIND_NOT_POSSIBLE], "water")
	for code: StringName in [Bindings.REFUSE_CUT, Bindings.REFUSE_ABOVE, Bindings.REFUSE_FOOTING]:
		var never: Dictionary = Orders.classify({"ok": false, "error": "x", "error_code": code})
		assert_equal(never.kind, Validity.KIND_NOT_POSSIBLE, "%s never possible here" % code)
		assert_true(String(never.error).begins_with(Validity.cannot_dig("")), "%s: %s" % [code, never.error])
	var other: Dictionary = Orders.classify({"ok": false, "error": "Busy now", "error_code": &"SOMETHING_ELSE"})
	assert_equal([other.error, other.kind], ["Busy now", Validity.KIND_BLOCKED], "other refusals keep their words")
	var plain: Dictionary = Orders.classify({"ok": false, "error": "Checked"})
	assert_equal([plain.error, plain.kind], ["Checked", Validity.KIND_BLOCKED], "a check's words without a code")
	var admitted: Dictionary = {"ok": true, "room": 7}
	assert_equal(Orders.classify(admitted), admitted, "an admission is returned as it came")
	assert_false(admitted.has("kind"), "and the original is never written")
