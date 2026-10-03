extends "res://test/framework/test_case.gd"
## Accounting boundary only. SyntheticRouter grants named store operations, not real payment.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class SyntheticRouter extends Contract:
	var owner: WeakRef = null
	var world: Vector2i = NULL_REF
	var subject: Vector2i = Vector2i(11, 7)
	var operation: int = 1
	var quantity: int = 1001
	var total: int = 251
	var remaining: int = 251
	var workers: int = 4
	var keys: Array[StringName] = [&"excavated_earth"]
	var amounts: PackedInt64Array = PackedInt64Array([1001])
	var prepared: bool = false
	var live: bool = true
	var attached: Vector2i = NULL_REF
	var permit_project: Vector2i = NULL_REF
	var permit_action: int = -1
	var facts_subject: Vector2i = NULL_REF

	func construction_owner() -> RefCounted:
		"""Actual object identity separates fixtures with coincident ref numbers."""
		return owner.get_ref() if owner != null else null

	func world_ref() -> Vector2i:
		"""The synthetic operation still belongs to a real Directory World generation."""
		return world

	func project_open_into(_purpose: int, candidate: Vector2i, kind: int, out: Quote) -> StringName:
		"""Only one explicitly prepared test admission supplies its fixed quote."""
		if not prepared or candidate != subject or kind != operation:
			return REFUSE_AUTHORITY
		_fill(out)
		return &""

	func project_facts_into(project: Vector2i, out: Quote) -> StringName:
		"""The exact attached generation owns this immutable synthetic quantity contract."""
		if not live or project != attached:
			return REFUSE_AUTHORITY
		_fill(out)
		if facts_subject != NULL_REF:
			out.subject = facts_subject
		return &""

	func _fill(out: Quote) -> void:
		"""Write every used field; the caller reset prevents borrowing stale scratch lines."""
		out.subject = subject
		out.operation = operation
		out.quantity_milli = quantity
		out.total_mwu = total
		out.remaining_mwu = remaining
		out.job_kind = int(Catalog.JOB_KIND["BUILD"])
		out.max_workers = workers
		out.input_count = keys.size()
		for index: int in mini(keys.size(), Contract.INPUT_CAPACITY):
			out.input_keys[index] = keys[index]
			out.input_milli[index] = amounts[index]

	func attach_project(_purpose: int, _subject: Vector2i, _operation: int, project: Vector2i) -> void:
		"""Capture the real allocated Construction ref; this fixture publishes no physical state."""
		attached = project
		prepared = false

	func mutation_refusal(project: Vector2i, action: int) -> StringName:
		"""Permission is scoped to a single explicit unit-test mutation."""
		return &"" if project == permit_project and action == permit_action else REFUSE_AUTHORITY

	func allow(project: Vector2i, action: int) -> void:
		"""Begin one synthetic accounting operation without claiming any Inventory proof."""
		permit_project = project
		permit_action = action

class SyntheticSpatial extends Buildings.SpatialAuthority:
	var owner: WeakRef = null
	var action: int = -1
	var subject: Vector2i = NULL_REF
	var related: Vector2i = NULL_REF
	var value: int = 0

	func buildings_owner() -> RefCounted:
		"""Actual Buildings object owns the real Room and Furniture refs in this fixture."""
		return owner.get_ref() if owner != null else null

	func mutation_refusal(candidate_action: int, candidate_subject: Vector2i,
			candidate_related: Vector2i, candidate_value: int, rotation: int) -> StringName:
		"""Only a named exact fixture admission may allocate the real spatial identities."""
		return &"" if candidate_action == action and candidate_subject == subject \
			and candidate_related == related and candidate_value == value and rotation == 0 \
			else Buildings.REFUSE_SPATIAL_COMMAND

var _construction: Construction = null
var _router: SyntheticRouter = null
var _spatial: SyntheticSpatial = null
var _out: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Bind one actual world and a labeled synthetic accounting router."""
	_construction = Construction.new()
	_router = SyntheticRouter.new()
	_router.owner = weakref(_construction)
	_router.world = _construction.directory().create(Directory.KIND_WORLD)
	assert_true(_construction.bind_modular_authority(_router).ok, "exact router binds")


func after_each() -> void:
	"""Weak reverse wiring leaves no cycles or retained worlds."""
	_spatial = null
	_router = null
	_construction = null


func _open(purpose: int = Construction.PURPOSE_SPOIL_TIP) -> Vector2i:
	"""Prepare one synthetic immutable order then use real Construction admission."""
	_router.prepared = true
	var result: Construction.OpResult = _construction.open_modular_phase(purpose, _router.subject, _router.operation)
	assert_true(result.ok, "actual project opens: %s" % result.error)
	assert_equal(_router.attached, result.ref, "router receives actual full project ref")
	return result.ref


func _deliver(project: Vector2i, index: int, quantity: int) -> Construction.OpResult:
	"""Scope a single unit-test delivery; real receipt tests supply actual Inventory later."""
	_router.allow(project, Contract.ACTION_DELIVER)
	var result: Construction.OpResult = _construction.deliver_material(project, index, quantity)
	_router.allow(NULL_REF, -1)
	return result


func _begin(project: Vector2i) -> Construction.OpResult:
	"""Scope the stored funding transition without pretending this unit fixture consumes goods."""
	_router.allow(project, Contract.ACTION_BEGIN_WORK)
	var result: Construction.OpResult = _construction.begin_work(project)
	_router.allow(NULL_REF, -1)
	return result


func _work(project: Vector2i, amount: int) -> Construction.OpResult:
	"""Exercise only the owner-protected accounting sink; actual Work is a separate composition."""
	_router.allow(project, Contract.ACTION_WORK)
	var result: Construction.OpResult = _construction.add_work_mwu(project, amount)
	_router.allow(NULL_REF, -1)
	return result


func _image() -> PackedByteArray:
	"""Include Directory allocation and every accounting column in refusal comparisons."""
	var image: PackedByteArray = _construction.directory().state_bytes()
	image.append_array(_construction.state_bytes())
	return image


func _pending_bench() -> Vector2i:
	"""Actual pending Kitchen furniture identity; only geometric qualification is synthetic."""
	var buildings: Buildings = _construction.buildings()
	_spatial = SyntheticSpatial.new()
	_spatial.owner = weakref(buildings)
	assert_true(buildings.bind_spatial_authority(_spatial).ok, "spatial owner binds")
	_spatial.action = Buildings.SPATIAL_ROOM_CREATE
	_spatial.value = Buildings.ROOM_TYPE_KITCHEN
	var room: Buildings.OpResult = buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN)
	assert_true(room.ok, "real kitchen identity")
	_spatial.action = Buildings.SPATIAL_FURNITURE_CREATE
	_spatial.related = room.ref
	_spatial.value = int(Catalog.FURNITURE_DEFINITION["kitchen_bench"])
	var piece: Buildings.OpResult = buildings.stage_spatial_furniture(room.ref, _spatial.value, 0)
	assert_true(piece.ok, "real pending bench")
	_spatial.action = -1
	return piece.ref


func _quote_bench(piece: Vector2i) -> void:
	"""Read the actual unchanged GDD catalog rather than inventing a fixture recipe."""
	_router.subject = piece
	_router.operation = int(Catalog.FURNITURE_DEFINITION["kitchen_bench"])
	_router.quantity = 0
	_router.total = _construction.definitions().furniture_work_mwu_of(_router.operation)
	_router.remaining = _router.total
	_router.keys = [&"wood", &"stone", &"iron"]
	_router.amounts = PackedInt64Array([4000, 4000, 1000])


func test_new_domains_append_without_widening_frozen_save_or_excavation_ids() -> void:
	"""No old codec may interpret a new quantity-dependent subject as a surface building."""
	assert_equal(Construction.PURPOSE_EXCAVATION, 5, "excavation purpose unchanged")
	assert_equal(Construction.PURPOSE_SPATIAL_FURNITURE, 6, "spatial furniture appended")
	assert_equal(Construction.PURPOSE_SPOIL_TIP, 7, "tip appended separately")
	assert_equal(Construction.PURPOSE_CONNECTOR_INSTALL, 8, "connector installation appended separately")
	assert_equal(Construction.LIVE_PURPOSE_COUNT, 9, "live purpose domain")
	assert_equal(Construction.PURPOSE_COUNT, 4, "frozen save domain remains unchanged")
	for purpose: int in [Construction.PURPOSE_SPATIAL_FURNITURE, Construction.PURPOSE_SPOIL_TIP,
			Construction.PURPOSE_CONNECTOR_INSTALL]:
		var columns: Construction.Columns = Construction.Columns.new()
		columns.purpose[0] = purpose
		assert_equal(Construction.columns_refusal(columns), Construction.REFUSE_COLUMN_ENUM, "old codec explicitly refuses")
	assert_equal(Construction.column_source_metadata_refusal(), &"", "legacy metadata intact")


func test_context_free_tip_bill_refuses_and_actual_project_bill_is_exact() -> void:
	"""An operation ID without the actual immutable q cannot price a tip order."""
	assert_false(_construction.bill_size_into(7, 1, _out), "no context-free bill")
	assert_equal(StringName(_out.error), Contract.REFUSE_PROJECT_CONTEXT, "explicit quantity context refusal")
	assert_false(_construction.declared_work_mwu_into(7, 1, _out), "no guessed work price")
	assert_equal(_construction.material_key_at(7, 1, 0), &"", "no invented key")
	var project: Vector2i = _open()
	assert_true(_construction.project_bill_size_into(project, _out), "exact bill reads")
	assert_equal(_out.value, 1, "one actual line")
	assert_equal(_construction.project_material_key_at(project, 0), &"excavated_earth", "earth retains its own key")
	assert_true(_construction.project_required_milli_into(project, 0, _out), "quantity reads")
	assert_equal(_out.value, 1001, "milli-unit quantity retained exactly")
	assert_true(_construction.project_material_index_of_key_into(project, &"excavated_earth", _out), "actual key resolves")
	assert_false(_construction.project_material_index_of_key_into(project, &"wood", _out), "foreign item cannot credit earth")
	assert_false(_construction.project_required_milli_into(Vector2i(project.x, project.y + 1), 0, _out), "stale generation refuses")


func test_unprepared_direct_calls_and_malformed_quotes_are_atomic() -> void:
	"""No direct caller can open from arbitrary q/work data or leave a partially allocated row."""
	var before: PackedByteArray = _image()
	assert_equal(_construction.open_modular_phase(7, _router.subject, 1).error, Contract.REFUSE_AUTHORITY, "no prepared order")
	_router.prepared = true
	_router.remaining = _router.total + 1
	assert_equal(_construction.open_modular_phase(7, _router.subject, 1).error, Contract.REFUSE_QUOTE, "excess retained work refuses")
	_router.remaining = _router.total
	_router.keys = [&"wood", &"wood"]
	_router.amounts = PackedInt64Array([1, 1])
	assert_equal(_construction.open_modular_phase(7, _router.subject, 1).error, Contract.REFUSE_QUOTE, "duplicate line refuses")
	_router.keys = [&"earth"]
	_router.amounts = PackedInt64Array([0])
	assert_equal(_construction.open_modular_phase(7, _router.subject, 1).error, Contract.REFUSE_QUOTE, "zero material bill refuses")
	assert_equal(_image(), before, "all refusals leave both owners unchanged")


func test_delivery_is_full_exact_and_all_mutations_require_the_actual_window() -> void:
	"""Direct accounting calls cannot bypass the future shared real material transaction."""
	var project: Vector2i = _open()
	var before: PackedByteArray = _image()
	assert_equal(_construction.deliver_material(project, 0, 1001).error, Contract.REFUSE_AUTHORITY, "direct free delivery refuses")
	assert_equal(_construction.begin_work(project).error, Contract.REFUSE_AUTHORITY, "direct unfunded start refuses")
	assert_equal(_construction.set_material_container(project, Vector2i(1, 1)).error, Contract.REFUSE_AUTHORITY, "direct container swap refuses")
	assert_equal(_construction.begin_refund(project).error, Contract.REFUSE_AUTHORITY, "direct cancel refuses")
	assert_equal(_image(), before, "refusals are atomic")
	assert_true(_deliver(project, 0, 1000).ok, "partial legitimate accounting delivery")
	assert_false(_begin(project).ok, "short delivery still blocks")
	before = _image()
	assert_equal(_deliver(project, 0, 2).error, Construction.REFUSE_OVER_DELIVERY, "over delivery refuses")
	assert_equal(_image(), before, "over delivery leaves ledger exact")
	assert_true(_deliver(project, 0, 1).ok, "last milli completes bill")
	assert_true(_begin(project).ok, "owned fully funded phase begins")
	assert_equal(_construction.add_work_mwu(project, 1).error, Contract.REFUSE_AUTHORITY, "direct free work refuses")
	assert_true(_work(project, 250).ok, "owned labor retires actual amount")
	assert_true(_construction.remaining_mwu_into(project, _out), "remaining reads")
	assert_equal(_out.value, 1, "integer retained work")


func test_complete_and_cancel_cannot_retire_before_real_owner_publication() -> void:
	"""Having the authority object alone grants no right to drop WIP/source ownership."""
	var project: Vector2i = _open()
	assert_true(_deliver(project, 0, 1001).ok, "fund accounting")
	assert_true(_begin(project).ok, "begin accounting")
	assert_true(_work(project, 251).ok, "all labor accepted")
	var before: PackedByteArray = _image()
	assert_equal(_construction.commit_completion(project).error, Construction.REFUSE_COORDINATOR_ONLY, "legacy completion cannot publish tip")
	assert_equal(_construction.retire_modular_phase(project, _router).error, Contract.REFUSE_AUTHORITY, "actual object without active transaction refuses")
	assert_equal(_image(), before, "paid completion stays pending")
	_router.allow(project, Contract.ACTION_CANCEL)
	assert_true(_construction.begin_refund(project).ok, "owner freezes refund")
	_router.allow(NULL_REF, -1)
	assert_true(_construction.cancellation_refund_milli_into(project, 0, _out), "refund exact line")
	assert_equal(_out.value, 800, "80 percent floors once per item")
	assert_equal(_construction.close_refund(project).error, Construction.REFUSE_COORDINATOR_ONLY, "legacy close cannot drop WIP")
	_router.allow(project, Contract.ACTION_RETIRE)
	assert_true(_construction.retire_modular_phase(project, _router).ok, "scoped synthetic post-refund retirement")
	assert_false(_construction.is_live_project(project), "real project identity retires")
	_router.allow(NULL_REF, -1)
	var replacement: Vector2i = _open()
	assert_true(replacement != project, "reuse has a fresh full identity")
	assert_false(_construction.delivered_milli_into(project, 0, _out), "stale ledger cannot address replacement")


func test_retained_completed_work_still_requires_full_repayment_and_pause_is_respected() -> void:
	"""Zero remaining labor after a cancelled order never grants free input materials."""
	_router.remaining = 0
	var project: Vector2i = _open()
	assert_false(_begin(project).ok, "retained work is not material payment")
	assert_true(_construction.set_paused(project, true).ok, "player hold")
	assert_equal(_deliver(project, 0, 1001).error, Construction.REFUSE_PAUSED, "no paused delivery")
	assert_true(_construction.set_paused(project, false).ok, "hold released")
	assert_true(_deliver(project, 0, 1001).ok, "full new price paid")
	assert_true(_begin(project).ok, "funded retained work completes accounting phase")
	assert_true(_construction.phase_into(project, _out), "phase reads")
	assert_equal(_out.value, Construction.PHASE_WORK_DONE, "no fake timed progress")
	assert_true(_construction.has_work_begun(project), "started refund policy applies to re-funding")


func test_local_tip_numbers_do_not_alias_any_directory_subject() -> void:
	"""A tip with the same numeric pair cannot overwrite an unrelated Building back-reference."""
	var buildings: Buildings = _construction.buildings()
	var building: Vector2i = buildings.place_building(int(Catalog.BUILDING_DEFINITION["dirt_path"]), 0, 0, 1).ref
	var existing: Vector2i = _construction.open_build(building).ref
	_router.subject = building
	var tip_project: Vector2i = _open()
	assert_equal(_construction.project_of_subject(building), existing, "legacy lookup ignores local tip namespace")
	assert_equal(_construction.project_of_modular_subject(7, building), tip_project, "explicit purpose lookup finds tip")
	assert_equal(buildings.construction_ref_of_building(building), existing, "back-reference remains actual building project")
	_router.prepared = true
	assert_equal(_construction.open_modular_phase(7, building, 1).error, Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION, "duplicate exact tip refuses")
	assert_true(_construction.is_live_project(existing), "unrelated project preserved")


func test_connector_subject_is_local_and_requires_its_actual_project_bill() -> void:
	"""A local placement cannot alias a Building or use its default recipe/work by numeric coincidence."""
	var buildings: Buildings = _construction.buildings()
	var building: Vector2i = buildings.place_building(int(Catalog.BUILDING_DEFINITION["dirt_path"]), 0, 0, 1).ref
	var existing: Vector2i = _construction.open_build(building).ref
	_router.subject = building
	_router.keys = [&"wood", &"rope"]
	_router.amounts = PackedInt64Array([1001, 501])
	var project: Vector2i = _open(Construction.PURPOSE_CONNECTOR_INSTALL)
	assert_equal(_construction.project_of_subject(building), existing, "legacy lookup ignores local connector")
	assert_equal(buildings.construction_ref_of_building(building), existing, "real Building backlink preserved")
	assert_equal(_construction.project_of_modular_subject(8, building), project, "exact namespace finds connector")
	assert_false(_construction.bill_size_into(8, 0, _out), "no context-free bill")
	assert_equal(StringName(_out.error), Contract.REFUSE_PROJECT_CONTEXT, "explicit context required")
	assert_false(_construction.declared_work_mwu_into(8, 0, _out), "no borrowed Building work")
	assert_equal(_construction.material_key_at(8, 0, 0), &"", "no borrowed Building key")
	assert_true(_construction.project_required_milli_into(project, 1, _out), "actual owner bill")
	assert_equal(_out.value, 501, "exact positive recipe quantity")
	_router.prepared = true
	assert_equal(_construction.open_modular_phase(8, building, 1).error,
		Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION, "one active connector operation")


func test_three_line_furniture_prices_are_catalog_exact_and_legacy_doors_stay_closed() -> void:
	"""An underground Kitchen bench cannot use the pre-installed legacy furniture route."""
	var piece: Vector2i = _pending_bench()
	_quote_bench(piece)
	assert_equal(_construction.open_furniture(piece).error, Construction.REFUSE_COORDINATOR_ONLY, "legacy construction blocked")
	assert_equal(_construction.open_furniture_removal(piece).error, Construction.REFUSE_COORDINATOR_ONLY, "legacy removal blocked")
	_router.prepared = true
	_router.amounts[2] = 999
	var before: PackedByteArray = _image()
	assert_equal(_construction.open_modular_phase(6, piece, _router.operation).error, Contract.REFUSE_QUOTE, "invented discount refuses")
	assert_equal(_image(), before, "discount leaves no allocated project")
	_router.amounts[2] = 1000
	var project: Vector2i = _open(6)
	assert_true(_construction.project_bill_size_into(project, _out), "bench bill reads")
	assert_equal(_out.value, 3, "all three actual inputs retained")
	for index: int in 3:
		assert_true(_deliver(project, index, _router.amounts[index]).ok, "actual bill line")
	assert_true(_begin(project).ok, "full catalog funding permits work")
	assert_false(_construction.buildings().is_furniture_installed(piece), "accounting does not install service presence")
	assert_equal(_construction.project_of_subject(piece), project, "real furniture remains Directory namespace")


func test_changed_subject_foreign_world_expiration_and_rebinding_refuse() -> void:
	"""Numerically equal refs and a retained old quote cannot substitute for actual owner identity."""
	var project: Vector2i = _open()
	_router.facts_subject = Vector2i(_router.subject.x, _router.subject.y + 1)
	assert_false(_construction.project_bill_size_into(project, _out), "changed full subject refuses")
	_router.facts_subject = NULL_REF
	var foreign: Construction = Construction.new()
	assert_false(foreign.has_modular_binding(), "never-bound world remains distinguishable")
	assert_true(_construction.has_modular_binding(), "actual owner binding is retained")
	var foreign_world: Vector2i = foreign.directory().create(Directory.KIND_WORLD)
	assert_equal(foreign_world, _router.world, "fixture creates coincident World numbers")
	_router.owner = weakref(foreign)
	assert_equal(_construction.modular_authority(), null, "actual foreign object refuses")
	assert_false(_construction.project_bill_size_into(project, _out), "foreign wiring cannot price own project")
	_router.owner = weakref(_construction)
	assert_true(_construction.directory().destroy(_router.world), "actual World retires")
	assert_equal(_construction.modular_authority(), null, "stale World refuses")
	_router = null
	assert_true(_construction.has_modular_binding(), "expiry cannot erase old owner state")
	var replacement: SyntheticRouter = SyntheticRouter.new()
	replacement.owner = weakref(_construction)
	replacement.world = _construction.directory().create(Directory.KIND_WORLD)
	assert_equal(_construction.bind_modular_authority(replacement).error, Contract.REFUSE_AUTHORITY, "expired binding cannot reset ownership")


func test_quote_shape_and_unused_metadata_are_validated_before_use() -> void:
	"""Finite quote scratch rejects oversized/trailing data and does not invent default permission."""
	var quote: Contract.Quote = Contract.Quote.new()
	_router._fill(quote)
	assert_equal(quote.refusal(), &"", "explicit synthetic quote valid")
	quote.output_item[1] = 0
	assert_equal(quote.refusal(), Contract.REFUSE_QUOTE, "unused output cannot hide metadata")
	quote.reset()
	_router._fill(quote)
	quote.input_milli.resize(5)
	assert_equal(quote.refusal(), Contract.REFUSE_QUOTE, "widened scratch shape refuses")
	var base: Contract.Owner = Contract.Owner.new()
	assert_equal(base.prepared_order_into(Vector2i(0, 1), 0, quote), Contract.REFUSE_AUTHORITY, "base owner never prices operation")


func test_base_binding_and_publication_queries_refuse_without_actual_router() -> void:
	"""The typed adapter seam grants no publication or world permission by itself."""
	var base: Contract = Contract.new()
	var owner: Contract.Owner = Contract.Owner.new()
	assert_equal(Contract.ADMIT, 0, "tip admission ID preserved")
	assert_equal(Contract.CANCEL, 1, "tip cancellation ID preserved")
	assert_equal(Contract.COMMIT, 2, "tip completion ID preserved")
	assert_equal(Contract.PRODUCTIVE, 3, "tip labor publication ID preserved")
	assert_equal(Contract.START, 4, "new contact preparation has its own action")
	assert_equal(base.owner_binding_refusal(owner), Contract.REFUSE_AUTHORITY, "base cannot bind")
	assert_false(base.is_bound_owner(owner), "typed owner alone grants nothing")
	assert_false(base.is_bound_owner(null), "null does not match")
	assert_false(base.is_publishing(Vector2i(1, 1), Contract.COMMIT, owner), "no direct publication")
	assert_equal(base.item_definitions_owner(), null, "base has no actual catalog")
	assert_equal(owner.transition_refusal(Vector2i(1, 1), Contract.START), Contract.REFUSE_AUTHORITY, "start requires actual contact proof")
