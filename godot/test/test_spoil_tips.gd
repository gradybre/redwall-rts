extends "res://test/framework/test_case.gd"
## Isolated tip-ledger tests. Actual Construction progress, SYNTHETIC publication/geometry/funding.
## This is not paid Inventory/Jobs/Work integration or a production SPOIL_TIP project fixture.

const Tips := preload("res://scripts/core/spoil_tips.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Accounting := preload("res://test/test_construction_excavation.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class SyntheticPublisher extends Tips.Publisher:
	var owner: Tips = null
	var construction: Construction = null
	var world: Vector2i = NULL_REF
	var tip: Vector2i = NULL_REF
	var project: Vector2i = NULL_REF
	var operation: int = -1
	var quantity: int = 0
	var action: int = -1
	var live: bool = true

	func exact_binding(candidate: RefCounted, actual_world: Vector2i,
			actual_construction: Construction) -> bool:
		"""Labeled synthetic composition; no callback here claims actual terrain or paid output."""
		return live and candidate == owner and actual_world == world and actual_construction == construction

	func project_refusal(actual_tip: Vector2i, actual_project: Vector2i,
			actual_operation: int, actual_quantity: int) -> StringName:
		"""A single fixture bill pins full project/subject generation, operation and exact quantity."""
		return &"" if actual_tip == tip and actual_project == project \
			and actual_operation == operation and actual_quantity == quantity else &"SYNTHETIC_BILL_MISMATCH"

	func publication_refusal(actual_tip: Vector2i, actual_project: Vector2i,
			actual_operation: int, actual_quantity: int, actual_action: int) -> StringName:
		"""Explicit synthetic permit only, proving ledger boundaries rather than real Work or Funding."""
		var code: StringName = project_refusal(actual_tip, actual_project, actual_operation, actual_quantity)
		return code if code != &"" else (&"" if actual_action == action else &"SYNTHETIC_NO_PUBLICATION")

var _construction: Construction = null
var _site: Accounting.SyntheticSite = null
var _publisher: SyntheticPublisher = null
var _tips: Tips = null
var _world: Vector2i = NULL_REF
var _next_site: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Create actual generational Construction and World; the isolated spatial/economic adapter is synthetic."""
	_construction = Construction.new()
	_site = Accounting.SyntheticSite.new()
	assert_true(_construction.bind_excavation_authority(_site).ok, "synthetic accounting binding")
	_world = _construction.directory().create(Directory.KIND_WORLD)
	_tips = Tips.new(_construction, _world, 4)
	_publisher = SyntheticPublisher.new()
	_publisher.owner = _tips
	_publisher.construction = _construction
	_publisher.world = _world
	assert_equal(_tips.bind_publisher(_publisher), &"", "explicit synthetic publisher")
	_next_site = 0


func after_each() -> void:
	"""Drop all owned fixture references; the production-facing binding itself is weak."""
	_publisher = null
	_tips = null
	_site = null
	_construction = null


func _project(tip: Vector2i, operation: int, quantity: int, remaining: int = -1) -> Vector2i:
	"""Borrow only a bounded <=4250mWU accounting fixture; never reinterpret this as a production tip bill."""
	var total: int = Tips.total_work_mwu(operation, quantity)
	var retained: int = _tips.retained_work_mwu(tip, operation, quantity) if _tips.is_live_tip(tip) else 0
	_site.remaining = total - retained if remaining < 0 else remaining
	assert_true(_site.remaining >= 0 and _site.remaining <= 4250, "synthetic fixture work bound")
	_site.site = Vector2i(100 + _next_site, 1)
	_next_site += 1
	var opened: Construction.OpResult = _construction.open_excavation_phase(_site.site, Contract.OP_BACKFILL_CLOSE)
	assert_true(opened.ok, "actual generational project: %s" % opened.error)
	_publisher.tip = tip
	_publisher.project = opened.ref
	_publisher.operation = operation
	_publisher.quantity = quantity
	return opened.ref


func _designate(tile: int = 30) -> Vector2i:
	"""Publish one exact synthetic prepare admission, with actual Construction remaining work."""
	var tip: Vector2i = _tips.candidate_tip_ref()
	var project: Vector2i = _project(tip, Tips.PREPARE, 0)
	assert_equal(_tips.prepare_order_refusal(tile, project), &"", "prepare preflight")
	_publisher.action = Tips.ADMIT
	assert_equal(_tips.publish_prepare_order(tile, project), &"", "prepare publication")
	_publisher.action = -1
	return tip


func _order(tip: Vector2i, operation: int, quantity: int = 0) -> Vector2i:
	"""Create an exact retained-work accounting project and publish its synthetic admission."""
	var project: Vector2i = _project(tip, operation, quantity)
	assert_equal(_tips.order_refusal(tip, project, operation, quantity), &"", "operation preflight")
	_publisher.action = Tips.ADMIT
	assert_equal(_tips.publish_order(tip, project, operation, quantity), &"", "operation publication")
	_publisher.action = -1
	return project


func _begin(tip: Vector2i) -> void:
	"""Fund the labeled accounting fixture; real tip input/output integration is tested by its coordinator."""
	var project: Vector2i = _tips.project_of(tip)
	assert_true(_construction.deliver_material(project, 0, 2000).ok, "synthetic accounting funding")
	assert_true(_construction.begin_work(project).ok, "actual Construction work begins")


func _work(tip: Vector2i, amount: int) -> void:
	"""Progress comes from actual Construction; the ledger has no caller-supplied labor setter."""
	var project: Vector2i = _tips.project_of(tip)
	assert_true(_construction.add_work_mwu(project, amount).ok, "actual Construction work")
	_publisher.action = Tips.PRODUCTIVE
	assert_equal(_tips.publish_work(tip, project), &"", "retain actual earned work")
	_publisher.action = -1


func _finish(tip: Vector2i) -> void:
	"""Complete actual fixture work and synthetically attest source commit once; no Inventory permission claim."""
	var project: Vector2i = _tips.project_of(tip)
	_begin(tip)
	assert_true(_construction.remaining_mwu_into(project, _math), "actual remaining")
	if _math.value > 0:
		_work(tip, _math.value)
	assert_equal(_tips.completion_refusal(tip, project), &"", "physical completion preflight")
	_publisher.action = Tips.COMMIT
	assert_equal(_tips.publish_completion(tip, project), &"", "synthetic successful source publication")
	_publisher.action = -1
	assert_true(_construction.retire_excavation_phase(project, _site).ok, "actual fixture project retires")
	assert_equal(_tips.audit_refusal(), &"", "post-completion owner audit")


func _cancel(tip: Vector2i) -> void:
	"""Simulate a successful refund only after actual retained progress matches; stock itself never moves."""
	var project: Vector2i = _tips.project_of(tip)
	assert_equal(_tips.cancellation_refusal(tip, project), &"", "cancellation preflight")
	assert_true(_construction.begin_refund(project).ok, "actual refund phase")
	_publisher.action = Tips.CANCEL
	assert_equal(_tips.publish_cancellation(tip, project), &"", "synthetic successful refund publication")
	_publisher.action = -1
	assert_true(_construction.retire_excavation_phase(project, _site).ok, "actual fixture retires after refund")
	assert_equal(_tips.audit_refusal(), &"", "post-cancellation audit")


func _prepared() -> Vector2i:
	"""One completed preparation for tests that need actual embedded-source operations."""
	var tip: Vector2i = _designate()
	_finish(tip)
	return tip


func test_exact_adopted_prices_keep_fractional_quantities_and_refuse_invalid_operations() -> void:
	"""Milli-U never becomes whole units before rational work prices round up."""
	assert_equal(Tips.total_work_mwu(Tips.PREPARE, 0), 4000, "prepare")
	assert_equal(Tips.total_work_mwu(Tips.CLOSE, 0), 4000, "close")
	assert_equal(Tips.total_work_mwu(Tips.COMPACT, 1), 1, "fractional compact")
	assert_equal(Tips.total_work_mwu(Tips.COMPACT, 5), 2, "compact ceil")
	assert_equal(Tips.total_work_mwu(Tips.RECLAIM, 3), 2, "reclaim ceil")
	assert_equal(Tips.total_work_mwu(Tips.COMPACT, 400000), 100000, "full tip compact")
	assert_equal(Tips.total_work_mwu(Tips.RECLAIM, 400000), 200000, "full tip reclaim")
	for operation: int in [-1, Tips.OP_COUNT]:
		assert_equal(Tips.total_work_mwu(operation, 1000), -1, "invalid operation")
	for quantity: int in [-1, 0, 400001]:
		assert_equal(Tips.total_work_mwu(Tips.COMPACT, quantity), -1, "invalid quantity")
	assert_equal(Tips.total_work_mwu(Tips.PREPARE, 1), -1, "fixed operation forbids q")


func test_explicit_capacity_and_live_world_are_required_before_any_allocation() -> void:
	"""No default production arena, clamped invalid capacity or borrowed namespace creates a usable owner."""
	assert_equal(_tips.initialization_refusal(), &"", "valid owner")
	assert_equal(_tips.world_ref(), _world, "actual World")
	assert_equal(_tips.construction_owner(), _construction, "actual Construction")
	assert_equal(_tips.packed_memory_bytes(), 107 * 4 + 65536, "all packed live bytes")
	assert_equal(_tips.state_bytes().size(), 48 + 103 * 4, "persistent diagnostic payload")
	for capacity: int in [0, -1, Tips.MAX_CAPACITY + 1]:
		var invalid: Tips = Tips.new(_construction, _world, capacity)
		assert_equal(invalid.initialization_refusal(), Tips.REFUSE_BINDING, "invalid capacity")
		assert_equal(invalid.packed_memory_bytes(), 0, "no allocation on invalid input")
	var wrong: Tips = Tips.new(_construction, Vector2i(_world.x, _world.y + 1), 4)
	assert_equal(wrong.initialization_refusal(), Tips.REFUSE_BINDING, "wrong World generation")
	assert_equal(wrong.legacy_save_refusal(), Tips.REFUSE_BINDING, "invalid owner cannot save")


func test_candidate_preparation_is_read_only_and_does_not_mint_a_project() -> void:
	"""The paid router can reject physical allocation before spending any Directory identity."""
	var before: PackedByteArray = _tips.state_bytes()
	var directory: PackedByteArray = _construction.directory().state_bytes()
	assert_equal(_tips.candidate_prepare_refusal(30), &"", "vacant tile is a physical candidate")
	assert_equal(_tips.candidate_prepare_refusal(-1), Tips.REFUSE_TIP, "negative tile refuses")
	assert_equal(_tips.candidate_prepare_refusal(Tips.MAX_CAPACITY), Tips.REFUSE_TIP, "outside world refuses")
	assert_equal(_tips.state_bytes(), before, "physical preview changes no history")
	assert_equal(_construction.directory().state_bytes(), directory, "preview allocates no project")
	_designate(30)
	assert_equal(_tips.candidate_prepare_refusal(30), Tips.REFUSE_TIP, "existing designation occupies tile")
	_publisher.live = false
	assert_equal(_tips.candidate_prepare_refusal(31), Tips.REFUSE_BINDING, "expired composition refuses")


func test_publisher_binding_preflight_is_read_only_and_preserves_the_accepted_owner() -> void:
	"""A composed adapter can test both bindings before either owner publishes its link."""
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.publisher_binding_refusal(_publisher), &"", "same exact live publisher qualifies")
	assert_equal(_tips.publisher_binding_refusal(null), Tips.REFUSE_BINDING, "null grants no publication")
	var foreign: SyntheticPublisher = SyntheticPublisher.new()
	foreign.owner = _tips
	foreign.construction = _construction
	foreign.world = _world
	assert_equal(_tips.publisher_binding_refusal(foreign), Tips.REFUSE_BINDING, "different object cannot replace accepted history")
	assert_equal(_tips.state_bytes(), before, "preflight consumes no source or identity")
	assert_equal(_tips.candidate_prepare_refusal(30), &"", "original accepted publisher remains bound")
	_publisher.live = false
	assert_equal(_tips.publisher_binding_refusal(_publisher), Tips.REFUSE_BINDING, "late invalidation refuses")
	_publisher.live = true


func test_candidate_orders_prove_phase_source_capacity_and_exact_retained_contract() -> void:
	"""An impossible or changed-q order refuses before Construction allocation or source claims."""
	var tip: Vector2i = _prepared()
	assert_equal(_tips.candidate_order_refusal(tip, Tips.PREPARE, 0), Tips.REFUSE_PHASE, "already prepared")
	assert_equal(_tips.candidate_order_refusal(tip, Tips.RECLAIM, 1), Tips.REFUSE_QUANTITY, "empty source")
	assert_equal(_tips.candidate_order_refusal(tip, Tips.COMPACT, 400001), Tips.REFUSE_QUANTITY, "over capacity")
	assert_equal(_tips.candidate_order_refusal(Vector2i(tip.x, tip.y + 1), Tips.CLOSE, 0), Tips.REFUSE_TIP, "full identity")
	_order(tip, Tips.COMPACT, 5)
	assert_equal(_tips.candidate_order_refusal(tip, Tips.CLOSE, 0), Tips.REFUSE_BUSY, "current project holds source")
	_begin(tip)
	_work(tip, 1)
	_cancel(tip)
	var before: PackedByteArray = _tips.state_bytes()
	var directory: PackedByteArray = _construction.directory().state_bytes()
	assert_equal(_tips.candidate_order_refusal(tip, Tips.COMPACT, 6), Tips.REFUSE_CONTRACT, "changed q cannot inherit work")
	assert_equal(_tips.candidate_order_refusal(tip, Tips.COMPACT, 5), &"", "exact retained q may resume")
	assert_equal(_tips.state_bytes(), before, "no source or incoming capacity is claimed by a preview")
	assert_equal(_construction.directory().state_bytes(), directory, "no project is allocated by a preview")
	_publisher.live = false
	assert_equal(_tips.candidate_order_refusal(tip, Tips.CLOSE, 0), Tips.REFUSE_BINDING, "expired owner refuses")


func test_direct_admission_or_foreign_composition_cannot_designate_a_tip() -> void:
	"""Valid-looking refs alone cannot write physical state without the exact typed publication."""
	var tip: Vector2i = _tips.candidate_tip_ref()
	var project: Vector2i = _project(tip, Tips.PREPARE, 0)
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.publish_prepare_order(30, project), &"SYNTHETIC_NO_PUBLICATION", "direct call refuses")
	assert_equal(_tips.state_bytes(), before, "no partial tip")
	assert_equal(_tips.bind_publisher(Tips.Publisher.new()), Tips.REFUSE_BINDING, "abstract publisher refuses")
	_publisher.live = false
	assert_equal(_tips.candidate_tip_ref(), NULL_REF, "changed composition loses admission")
	assert_equal(_tips.prepare_order_refusal(30, project), Tips.REFUSE_BINDING, "lost real owner")
	assert_equal(_tips.audit_refusal(), Tips.REFUSE_BINDING, "binding audit")


func test_designation_and_mid_prepare_cancel_keep_tile_generation_and_earned_work() -> void:
	"""Cancellation never resets work or releases the designated footprint for a free redraw."""
	var tip: Vector2i = _designate()
	assert_equal(_tips.tip_at(30), tip, "indexed identity")
	assert_equal(_tips.tile_of(tip), 30, "real tile")
	assert_false(_tips.is_prepared(tip), "designation not completion")
	assert_equal(_tips.operation_of(tip), Tips.PREPARE, "active operation")
	assert_equal(_tips.quantity_milli(tip), 0, "fixed work has no q")
	_begin(tip)
	_work(tip, 1250)
	_cancel(tip)
	assert_equal(_tips.retained_work_mwu(tip, Tips.PREPARE), 1250, "work retained")
	assert_equal(_tips.tip_at(30), tip, "footprint and generation retained")
	assert_equal(_tips.project_of(tip), NULL_REF, "old project released")
	_order(tip, Tips.PREPARE)
	_finish(tip)
	assert_true(_tips.is_prepared(tip), "remaining work completed")
	assert_equal(_tips.retained_work_mwu(tip, Tips.PREPARE), 0, "completed work contract consumed")


func test_admission_refuses_a_fresh_counter_that_would_erase_retained_work() -> void:
	"""New projects inherit the exact retained amount; a plausible same-purpose fresh quote is insufficient."""
	var tip: Vector2i = _designate()
	_begin(tip)
	_work(tip, 900)
	_cancel(tip)
	var project: Vector2i = _project(tip, Tips.PREPARE, 0, 4000)
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.order_refusal(tip, project, Tips.PREPARE, 0), Tips.REFUSE_PROGRESS, "fresh counter rejected")
	assert_equal(_tips.state_bytes(), before, "retained state unchanged")


func test_unattested_or_unrecorded_work_cannot_cancel_or_complete() -> void:
	"""Missed Work publication must fail before refund, so actual earned labor cannot disappear."""
	var tip: Vector2i = _designate()
	var project: Vector2i = _tips.project_of(tip)
	_begin(tip)
	assert_true(_construction.add_work_mwu(project, 4000).ok, "actual earned work awaiting publication")
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.publish_work(tip, project), &"SYNTHETIC_NO_PUBLICATION", "direct work refuses")
	assert_equal(_tips.cancellation_refusal(tip, project), Tips.REFUSE_PROGRESS, "unrecorded work cannot cancel")
	assert_equal(_tips.completion_refusal(tip, project), Tips.REFUSE_PROGRESS, "unrecorded work cannot complete")
	assert_equal(_tips.state_bytes(), before, "all refusals atomic")
	_publisher.action = Tips.PRODUCTIVE
	assert_equal(_tips.publish_work(tip, project), &"", "genuine fixture window records work")
	_publisher.action = -1
	assert_equal(_tips.completion_refusal(tip, project), &"", "recorded completion can preflight")
	assert_equal(_tips.publish_completion(tip, project), &"SYNTHETIC_NO_PUBLICATION", "completion requires output publication too")


func test_compaction_retains_exact_quantity_and_reserves_whole_incoming_amount() -> void:
	"""Partial paid compaction yields no embedded stock; cancellation pins its exact full repayment contract."""
	var tip: Vector2i = _prepared()
	_order(tip, Tips.COMPACT, 16000)
	assert_equal(_tips.incoming_milli(tip), 16000, "whole capacity held")
	assert_equal(_tips.embedded_milli(tip), 0, "no premature stock")
	_begin(tip)
	_work(tip, 750)
	_cancel(tip)
	assert_equal(_tips.incoming_milli(tip), 0, "cancel releases incoming claim")
	assert_equal(_tips.retained_work_mwu(tip, Tips.COMPACT, 16000), 750, "exact-q work retained")
	assert_equal(_tips.retained_work_mwu(tip, Tips.COMPACT, 15999), -1, "other q cannot inherit")
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.COMPACT, 15999), Tips.REFUSE_CONTRACT, "mismatch refuses")
	_order(tip, Tips.COMPACT, 16000)
	_finish(tip)
	assert_equal(_tips.embedded_milli(tip), 16000, "only committed compaction embeds")
	assert_equal(_tips.total_embedded_milli(), 16000, "world conservation total")
	assert_equal(_tips.retained_work_mwu(tip, Tips.COMPACT, 15999), 0, "completed contract no longer pins q")


func test_cancelled_reclamation_keeps_source_until_actual_output_commit() -> void:
	"""A reclaim source lock is not delivered loose material and never suffers a synthetic eighty-percent refund."""
	var tip: Vector2i = _prepared()
	_order(tip, Tips.COMPACT, 16000)
	_finish(tip)
	_order(tip, Tips.RECLAIM, 8000)
	assert_equal(_tips.locked_milli(tip), 8000, "actual full source locked")
	assert_equal(_tips.embedded_milli(tip), 16000, "pending withdrawal creates no capacity")
	_begin(tip)
	_work(tip, 1700)
	_cancel(tip)
	assert_equal(_tips.embedded_milli(tip), 16000, "cancelled source unchanged")
	assert_equal(_tips.locked_milli(tip), 0, "cancel source unlock")
	assert_equal(_tips.retained_work_mwu(tip, Tips.RECLAIM, 8000), 1700, "same-q earned work survives")
	_order(tip, Tips.RECLAIM, 8000)
	_finish(tip)
	assert_equal(_tips.embedded_milli(tip), 8000, "only committed output debits source")
	assert_equal(_tips.total_embedded_milli(), 8000, "world total after reclaim")


func test_full_tip_and_busy_operation_never_admit_predicted_free_capacity() -> void:
	"""A pending reclaim cannot finance incoming earth or exceed the fixed actual embedded limit."""
	var tip: Vector2i = _prepared()
	for batch: int in 25:
		_order(tip, Tips.COMPACT, 16000)
		_finish(tip)
	assert_equal(_tips.embedded_milli(tip), 400000, "actual full tip")
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.COMPACT, 1), Tips.REFUSE_CAPACITY, "no space")
	_order(tip, Tips.RECLAIM, 8000)
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.COMPACT, 8000), Tips.REFUSE_BUSY, "pending withdrawal not capacity")
	assert_equal(_tips.embedded_milli(tip), 400000, "still full while withdrawing")


func test_paid_empty_closure_reuses_slot_with_new_generation_and_no_legacy_save_downgrade() -> void:
	"""Closing an empty tip is paid and preserves generation history even if it never held earth."""
	assert_equal(_tips.legacy_save_refusal(), &"", "pristine owner")
	var tip: Vector2i = _prepared()
	_order(tip, Tips.CLOSE)
	assert_equal(_tips.completion_refusal(tip, _tips.project_of(tip)), Tips.REFUSE_PROGRESS, "closure not free")
	_finish(tip)
	assert_false(_tips.is_live_tip(tip), "closed identity stale")
	assert_equal(_tips.tip_at(30), NULL_REF, "tile released")
	assert_equal(_tips.candidate_tip_ref(), Vector2i(tip.x, tip.y + 1), "lowest row new generation")
	assert_equal(_tips.legacy_save_refusal(), Tips.REFUSE_CODEC, "old save cannot erase generation history")
	var replacement: Vector2i = _designate()
	assert_equal(replacement, Vector2i(tip.x, tip.y + 1), "new identity")
	assert_equal(_tips.embedded_milli(tip), -1, "stale source read refuses")
	assert_equal(_tips.project_of(tip), NULL_REF, "old handle cannot claim new project")


func test_stock_must_be_reclaimed_before_paid_closure() -> void:
	"""Removing a designation never discards physical source stock."""
	var tip: Vector2i = _prepared()
	_order(tip, Tips.COMPACT, 16000)
	_finish(tip)
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.CLOSE, 0), Tips.REFUSE_PHASE, "nonempty close refuses")
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.RECLAIM, 16001), Tips.REFUSE_QUANTITY, "cannot overdraw source")
	assert_equal(_tips.state_bytes(), before, "source conserved through refusal")


func test_retries_wrong_generations_and_lost_world_cannot_republish_source() -> void:
	"""Completion is single-use and every ref includes its actual generation and World."""
	var tip: Vector2i = _designate()
	var project: Vector2i = _tips.project_of(tip)
	assert_equal(_tips.work_refusal(tip, Vector2i(project.x, project.y + 1)), Tips.REFUSE_TIP, "wrong project generation")
	_finish(tip)
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.publish_completion(tip, project), Tips.REFUSE_TIP, "completion retry cannot publish twice")
	assert_equal(_tips.state_bytes(), before, "idempotent refusal")
	assert_true(_construction.directory().destroy(_world), "actual World retires")
	assert_false(_tips.is_live_tip(tip), "lost World invalidates local tip")
	assert_equal(_tips.tip_at(30), NULL_REF, "indexed read also requires live World")
	assert_equal(_tips.audit_refusal(), Tips.REFUSE_BINDING, "no authority after World loss")


func test_tile_index_heap_claim_and_conservation_corruption_are_detected_without_repairing() -> void:
	"""Fault injection tests both directions of derived maps, source accounting and retained canonical claims."""
	var tip: Vector2i = _prepared()
	_tips._tile_row[31] = tip.x
	assert_equal(_tips.audit_refusal(), &"SPOIL_TILE_INDEX", "phantom reverse index")
	_tips._tile_row[31] = -1
	var saved_free_row: int = _tips._free_heap[1]
	_tips._free_heap[1] = _tips._free_heap[0]
	assert_equal(_tips.audit_refusal(), &"SPOIL_FREE_INDEX", "duplicate free slot")
	_tips._free_heap[1] = saved_free_row
	assert_equal(_tips.audit_refusal(), &"", "restored fixture")
	_tips._embedded_milli[tip.x] = 1
	assert_equal(_tips.audit_refusal(), &"SPOIL_CONSERVATION", "unfunded embedded source")
	_tips._embedded_milli[tip.x] = 0
	_order(tip, Tips.COMPACT, 16000)
	_tips._incoming_milli[tip.x] -= 1
	assert_equal(_tips.audit_refusal(), &"SPOIL_ACTIVE_CLAIM", "partial reservation cannot pass audit")


func test_expired_publisher_binding_cannot_be_replaced_with_fresh_history() -> void:
	"""Weak binding avoids leaks without allowing another owner to reinterpret live local handles."""
	var before: PackedByteArray = _tips.state_bytes()
	_publisher = null
	var replacement: SyntheticPublisher = SyntheticPublisher.new()
	replacement.owner = _tips
	replacement.construction = _construction
	replacement.world = _world
	assert_equal(_tips.bind_publisher(replacement), Tips.REFUSE_BINDING, "binding is final after expiry")
	assert_equal(_tips.state_bytes(), before, "expired owner did not reset anything")


func test_exhausted_closed_generation_retires_without_wrapping_or_reusing_its_slot() -> void:
	"""A maximum generation can complete its operation but never become a fresh aliased source."""
	_tips._generation[0] = Tips.I32_MAX - 1 # Explicit fault/history fixture, not ordinary gameplay publication.
	var tip: Vector2i = _prepared()
	assert_equal(tip, Vector2i(0, Tips.I32_MAX), "last valid generation")
	_order(tip, Tips.CLOSE)
	_finish(tip)
	assert_equal(_tips.candidate_tip_ref(), Vector2i(1, 1), "exhausted row skipped")
	assert_equal(_tips.audit_refusal(), &"", "retired row absent from reusable heap")


func test_unprepared_tip_and_stale_reads_refuse_without_partial_claims() -> void:
	"""Cancelling a designation grants neither embedded capacity service nor a prepared source."""
	var tip: Vector2i = _designate()
	_cancel(tip)
	var before: PackedByteArray = _tips.state_bytes()
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.COMPACT, 16000), Tips.REFUSE_PHASE, "unprepared compaction")
	assert_equal(_tips.order_refusal(tip, NULL_REF, Tips.RECLAIM, 8000), Tips.REFUSE_PHASE, "unprepared reclaim")
	var stale: Vector2i = Vector2i(tip.x, tip.y + 1)
	assert_equal(_tips.tile_of(stale), -1, "stale tile")
	assert_false(_tips.is_prepared(stale), "stale preparation")
	assert_equal(_tips.operation_of(stale), -1, "stale operation")
	assert_equal(_tips.quantity_milli(stale), -1, "stale q")
	assert_equal(_tips.incoming_milli(stale), -1, "stale incoming claim")
	assert_equal(_tips.locked_milli(stale), -1, "stale source lock")
	assert_equal(_tips.tip_at(-1), NULL_REF, "negative tile")
	assert_equal(_tips.tip_at(Tips.MAX_CAPACITY), NULL_REF, "outside map")
	assert_equal(_tips.state_bytes(), before, "all refusals preserve exact physical state")
