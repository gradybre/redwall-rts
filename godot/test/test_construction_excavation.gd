extends "res://test/framework/test_case.gd"
## ECON phase-accounting tests; SyntheticSite is explicitly not production spatial proof.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class SyntheticSite extends Contract:
	var site: Vector2i = Vector2i(17, 3)
	var live: bool = true
	var remaining: int = -1
	var refusal: StringName = &""
	var attached: Vector2i = NULL_REF

	func is_live_site(candidate: Vector2i) -> bool:
		"""Synthetic identity proof for the accounting fixture, not a live-world site."""
		return live and candidate == site

	func project_open_refusal(_candidate: Vector2i, _operation: int) -> StringName:
		"""Expose an explicit synthetic geometry refusal for fail-closed owner wiring tests."""
		return refusal

	func remaining_work_into(_candidate: Vector2i, operation: int, out: IntMath.IntResult) -> bool:
		"""Return fixture-authoritative retained progress, never a caller-provided open argument."""
		return out.succeed(remaining if remaining >= 0 else Contract.work_mwu(operation))

	func attach_project(_candidate: Vector2i, _operation: int, project: Vector2i) -> void:
		"""Record that Construction publishes its actual generational project identity."""
		attached = project

	func mutation_refusal(_project: Vector2i, _action: int) -> StringName:
		"""This labeled accounting fixture has no production physical transaction to attest."""
		return &""

var _construction: Construction = null
var _site: SyntheticSite = null
var _out: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Each test owns one actual Construction store and a labeled synthetic site authority."""
	_construction = Construction.new()
	_site = SyntheticSite.new()
	assert_true(_construction.bind_excavation_authority(_site).ok, "typed authority binds")


func after_each() -> void:
	"""The weak owner binding must not retain a reference cycle."""
	_site = null
	_construction = null


func _open(operation: int) -> Vector2i:
	"""Open a project through the real owner and assert the published binding."""
	var opened: Construction.OpResult = _construction.open_excavation_phase(_site.site, operation)
	assert_true(opened.ok, "phase opens: %s" % opened.error)
	assert_equal(_site.attached, opened.ref, "site receives actual project identity")
	return opened.ref


func _fund(project: Vector2i, operation: int) -> void:
	"""Store-level fixture delivery; real Inventory coordinator integration has its own suite."""
	for index: int in Contract.input_count(operation):
		assert_true(_construction.deliver_material(project, index, Contract.input_milli(operation, index)).ok, "phase line delivers")


func test_adopted_economic_rows_and_legacy_material_domain_are_exact() -> void:
	"""The new phase table is pinned independently to ECON, including coupled closure."""
	var work: Array[int] = [4250, 940, 1880, 1410, 1250] # DEC-059: brace, cut, finish x 0.47
	var count: Array[int] = [1, 2, 0, 0, 0]
	assert_equal(Construction.MATERIAL_KEYS.size(), 6, "legacy material-key numbering remains unchanged")
	for operation: int in 5:
		assert_true(_construction.declared_work_mwu_into(5, operation, _out), "economic work reads")
		assert_equal(_out.value, work[operation], "authored milli-WU")
		assert_true(_construction.bill_size_into(5, operation, _out), "phase bill reads")
		assert_equal(_out.value, count[operation], "phase bill line count")
	assert_equal(_construction.material_key_at(5, 1, 0), &"wood", "brace wood")
	assert_equal(_construction.material_key_at(5, 1, 1), &"stone", "brace stone")
	assert_equal(_construction.material_key_at(5, 0, 0), &"excavated_earth", "closure earth is its actual key")
	assert_true(_construction.required_milli_into(5, 1, 0, _out), "brace quantity reads")
	assert_equal(_out.value, 250, "quarter unit of wood")
	assert_true(_construction.required_milli_into(5, 0, 0, _out), "backfill quantity reads")
	assert_equal(_out.value, 2000, "two units of actual earth")
	assert_equal(_construction.material_key_at(5, 99, 0), &"", "invalid operation has no free recipe")
	assert_false(_construction.required_milli_into(5, 2, 0, _out), "material-free cut has no input line")


func test_brace_needs_full_delivery_and_preserves_partial_accounting() -> void:
	"""One partially delivered quantum cannot begin free work or accept over-delivery."""
	var project: Vector2i = _open(Contract.OP_BRACE)
	assert_true(_construction.deliver_material(project, 0, 249).ok, "partial delivery")
	assert_equal(_construction.begin_work(project).error, Construction.REFUSE_WRONG_PHASE, "unfunded work refuses")
	var before: PackedByteArray = _construction.state_bytes()
	assert_equal(_construction.deliver_material(project, 0, 2).error, Construction.REFUSE_OVER_DELIVERY, "over-delivery refuses")
	assert_equal(_construction.state_bytes(), before, "refusal leaves accounting untouched")
	assert_true(_construction.deliver_material(project, 0, 1).ok, "wood reaches authored total")
	assert_true(_construction.deliver_material(project, 1, 250).ok, "stone delivered")
	assert_true(_construction.begin_work(project).ok, "fully funded work begins")
	assert_true(_construction.add_work_mwu(project, 640).ok, "partial brace work")
	assert_true(_construction.remaining_mwu_into(project, _out), "remaining work reads")
	assert_equal(_out.value, 300, "actual partial progress remains")
	assert_true(_construction.max_workers_into(project, _out), "worker capacity reads")
	assert_equal(_out.value, 1, "one worker per quantum")
	assert_false(_construction.set_assigned_count(project, 2).ok, "two workers cannot share one cut face")


func test_site_completion_requires_physical_coordinator_and_retry_spends_no_work() -> void:
	"""A completed labor project is not automatically a navigable or soil-producing cut."""
	var project: Vector2i = _open(Contract.OP_CUT)
	assert_true(_construction.begin_work(project).ok, "material-free paid cut work begins")
	assert_true(_construction.add_work_mwu(project, 4000).ok, "cut earns exact authored work")
	var before: PackedByteArray = _construction.state_bytes()
	assert_equal(_construction.commit_completion(project).error, Construction.REFUSE_COORDINATOR_ONLY, "ordinary building completion cannot publish a void")
	assert_equal(_construction.add_work_mwu(project, 1).error, Construction.REFUSE_WRONG_PHASE, "retry cannot earn additional WU")
	assert_equal(_construction.state_bytes(), before, "commit-pending work remains exactly retained")
	var foreign: Contract = Contract.new()
	assert_equal(_construction.retire_excavation_phase(project, foreign).error, Construction.REFUSE_COORDINATOR_ONLY, "wrong owner cannot retire physical work")
	var row: int = _construction._directory.get_typed_row(project)
	assert_true(_construction.retire_excavation_phase(project, _site).ok, "bound coordinator retires after its physical transaction")
	assert_false(_construction.is_live_project(project), "project identity retires")
	assert_equal([_construction._purpose[row], _construction._type_id[row], _construction._max_workers[row]],
		[Construction.PURPOSE_BUILD, -1, 0], "ADR 1228: the retired row is the exact never-used clear row")


func test_cancelled_started_brace_prices_refund_per_phase() -> void:
	"""Only uncommitted delivered brace inputs receive the authored 80 percent refund."""
	var project: Vector2i = _open(Contract.OP_BRACE)
	_fund(project, Contract.OP_BRACE)
	assert_true(_construction.begin_work(project).ok, "WIP begins")
	assert_true(_construction.add_work_mwu(project, 700).ok, "work earned")
	assert_true(_construction.begin_refund(project).ok, "cancellation freezes phase")
	for index: int in 2:
		assert_true(_construction.cancellation_refund_milli_into(project, index, _out), "refund line reads")
		assert_equal(_out.value, 200, "200 returned, 50 loss per input")
	assert_true(_construction.remaining_mwu_into(project, _out), "work retained while refund waits")
	assert_equal(_out.value, 240, "earned 700 WU-milli not reset (DEC-059: 940 brace)")
	assert_equal(_construction.close_refund(project).error, Construction.REFUSE_COORDINATOR_ONLY, "ordinary cancel cannot erase site history")
	assert_true(_construction.retire_excavation_phase(project, _site).ok, "physical owner retires only after refunds")


func test_retained_work_needs_full_new_funding_even_when_work_is_ready() -> void:
	"""Cancellation never lets retained completed labor bypass its next full material payment."""
	_site.remaining = 0
	var project: Vector2i = _open(Contract.OP_BRACE)
	assert_false(_construction.begin_work(project).ok, "zero remaining work still needs new inputs")
	_fund(project, Contract.OP_BRACE)
	assert_true(_construction.begin_work(project).ok, "full re-funding commits WIP")
	assert_true(_construction.phase_into(project, _out), "phase reads")
	assert_equal(_out.value, Construction.PHASE_WORK_DONE, "ready retained labor requires no extra productive tick")
	assert_true(_construction.has_work_begun(project), "new funding uses started-phase refund rule")


func test_site_and_building_reference_namespaces_never_alias() -> void:
	"""Coincident numbers cannot overwrite or clear an unrelated building's project back-reference."""
	var buildings: Buildings = _construction.buildings()
	var building: Vector2i = buildings.place_building(int(Catalog.BUILDING_DEFINITION["dirt_path"]), 0, 0, 1).ref
	var building_project: Vector2i = _construction.open_build(building).ref
	_site.site = building
	var site_project: Vector2i = _open(Contract.OP_FINISH)
	assert_equal(_construction.project_of_subject(building), building_project, "legacy subject lookup ignores site namespace")
	assert_equal(_construction.project_of_excavation_site(_site.site), site_project, "explicit site lookup finds site")
	assert_equal(buildings.construction_ref_of_building(building), building_project, "site open cannot replace building back-reference")
	assert_true(_construction.begin_work(site_project).ok, "site phase begins")
	assert_true(_construction.add_work_mwu(site_project, 3000).ok, "site phase works")
	assert_true(_construction.retire_excavation_phase(site_project, _site).ok, "site phase retires")
	assert_equal(buildings.construction_ref_of_building(building), building_project, "site retirement cannot clear unrelated back-reference")
	assert_true(_construction.is_live_project(building_project), "unrelated project remains live")


func test_site_authority_liveness_and_pause_are_revalidated() -> void:
	"""No base authority, lost site or paused project may progress through a permissive default."""
	_site.refusal = &"SYNTHETIC_SITE_NOT_DRY"
	var before: PackedByteArray = _construction.state_bytes()
	assert_equal(_construction.open_excavation_phase(_site.site, Contract.OP_BRACE).error, _site.refusal, "actual authority refusal propagates")
	assert_equal(_construction.state_bytes(), before, "site admission refusal is atomic")
	_site.refusal = &""
	var project: Vector2i = _open(Contract.OP_FINISH)
	assert_equal(_construction.open_excavation_phase(_site.site, Contract.OP_FINISH).error, Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION, "same physical identity has one phase project")
	_site.live = false
	assert_equal(_construction.begin_work(project).error, Construction.REFUSE_SUBJECT_LOST, "lost physical identity refuses")
	_site.live = true
	assert_true(_construction.set_paused(project, true).ok, "phase pauses")
	assert_equal(_construction.begin_work(project).error, Construction.REFUSE_PAUSED, "paused phase cannot begin")
	assert_true(_construction.set_paused(project, false).ok, "phase resumes")
	assert_true(_construction.begin_work(project).ok, "valid owner allows funded work")


func test_base_authority_and_expired_binding_cannot_reset_physical_history() -> void:
	"""Rebinding a dead owner could alias old site numbers, so even an expired weak binding is final."""
	var authority: Contract = Contract.new()
	var store: Construction = Construction.new()
	assert_true(store.bind_excavation_authority(authority).ok, "base binds for negative test")
	assert_equal(store.open_excavation_phase(Vector2i(0, 1), Contract.OP_BRACE).error, Contract.REFUSE_AUTHORITY, "base contract never authorizes")
	assert_equal(store.live_project_count(), 0, "unbound proof creates no paid project")
	_site = null
	assert_equal(_construction.bind_excavation_authority(SyntheticSite.new()).error, Contract.REFUSE_AUTHORITY, "expired binding cannot swap in a fresh physical ledger")


func test_new_purpose_is_rejected_by_frozen_legacy_save_columns() -> void:
	"""An old save decoder cannot reinterpret excavation type numbers as building catalog IDs."""
	var columns: Construction.Columns = Construction.Columns.new()
	columns.purpose[0] = Construction.PURPOSE_EXCAVATION
	assert_equal(Construction.columns_refusal(columns), Construction.REFUSE_COLUMN_ENUM, "new purpose explicitly refuses old save domain")
	assert_equal(Construction.column_source_metadata_refusal(), &"", "legacy metadata and recipes remain compatible")
