extends "res://test/framework/test_case.gd"
## Exact Room authority composition. Actual storage is real; admission/contact qualification is synthetic.

const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const FurnitureWork := preload("res://scripts/core/underground_furniture_work.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const FixtureScript := preload("res://test/test_underground_furniture_work.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class ForeignPurpose extends Contract.Owner:
	## Only an adversarial purpose-owner binding, never used for paid work or a successful quote.
	var actual: Construction = null
	var world: Vector2i = NULL_REF

	func construction_owner() -> RefCounted:
		"""Expose the exact real owner so the test reaches the already-bound-purpose refusal."""
		return actual

	func world_ref() -> Vector2i:
		"""Return the actual World; numeric mismatch is not needed to test atomic preflight."""
		return world

	func purpose() -> int:
		"""Reserve the real Furniture purpose through the actual router for the adversarial test."""
		return Construction.PURPOSE_SPATIAL_FURNITURE

var _f: FixtureScript.Fixture = null


func before_each() -> void:
	"""Set up actual owners but leave Furniture purpose unbound for atomic composition tests."""
	_f = FixtureScript.Fixture.new(self, false)


func after_each() -> void:
	"""Audit actual material stores and release weak reverse-link composition without leaks."""
	_f.audit()
	_f = null


func test_default_bindings_and_refused_initializers_grant_no_geometry_or_service_permission() -> void:
	"""A typed base interface is no trusted success fallback; failed owners expose no usable binding."""
	var empty: RoomOrders = RoomOrders.new()
	assert_equal(empty.configure(null, null, null, null, null), RoomOrders.REFUSE_BINDING, "null composition refuses")
	assert_null(empty.construction_owner(), "failed initializer has no accounting owner")
	assert_equal(empty.world_ref(), NULL_REF, "failed initializer has no World identity")
	assert_true(empty.binding_refusal() != &"", "failed initializer is explicitly unavailable")
	assert_false(empty.area_of_room(Vector2i(0, 1)).ok, "unknown room area is unavailable")
	assert_true(empty.service_refusal(Vector2i(0, 1)) != &"", "unknown room is not service-ready")
	assert_false(empty.is_publishing(NULL_REF, Contract.COMMIT, NULL_REF, NULL_REF), "null publication never qualifies")
	var base: RoomOrders.Bindings = RoomOrders.Bindings.new()
	assert_equal(empty.configure(_f.router, _f.space, _f.sources, _f.catalog, base), RoomOrders.REFUSE_BINDING, "default contact binding refuses")
	assert_true(_f.buildings.spatial_authority() == _f.orders, "refusal does not replace actual authority")
	assert_null(empty.buildings_owner(), "refused preflight retains no binding")


func test_foreign_same_number_world_and_source_reader_never_match_actual_composition() -> void:
	"""Independent actual worlds intentionally reuse ref numbers; object identity still refuses."""
	var foreign: FixtureScript.Fixture = FixtureScript.Fixture.new(self, false)
	assert_equal(foreign.world, _f.world, "adversarial Worlds have identical numeric refs")
	var candidate: RoomOrders = RoomOrders.new()
	assert_equal(candidate.configure(_f.router, foreign.space, foreign.sources, _f.catalog, foreign.bindings), RoomOrders.REFUSE_BINDING, "foreign source composition refuses")
	var same_numbers: SpaceOwner.CoreSources = SpaceOwner.CoreSources.new(_f.buildings.directory(), _f.buildings, _f.construction)
	assert_equal(candidate.configure(_f.router, _f.space, same_numbers, _f.catalog, _f.bindings), RoomOrders.REFUSE_BINDING, "replacement same-world source reader refuses")
	assert_null(candidate.construction_owner(), "refused authority exposes no valid owner")
	assert_true(_f.buildings.spatial_authority() == _f.orders, "own exact Buildings binding unchanged")
	assert_true(foreign.buildings.spatial_authority() == foreign.orders, "foreign exact Buildings binding untouched")
	foreign.audit()


func test_furniture_binding_preflight_cannot_strand_a_room_authority_after_router_refusal() -> void:
	"""An existing purpose binding is discovered before publishing the second weak Room link."""
	var occupying: ForeignPurpose = ForeignPurpose.new()
	occupying.actual = _f.construction
	occupying.world = _f.world
	assert_true(_f.router.bind_owner(occupying).ok, "actual Router purpose already occupied")
	assert_true(_f.owner.configure(_f.router, _f.orders) != &"", "second purpose owner refuses")
	assert_null(_f.owner.construction_owner(), "failed unpublished Furniture wiring clears")
	assert_equal(_f.orders.furniture_owner_binding_refusal(occupying), &"", "Room link remains free after Router preflight refusal")
	assert_false(_f.orders.is_bound_furniture_owner(occupying), "no half-bound Room purpose")
	assert_true(_f.router.is_bound_owner(occupying), "original actual Router owner retained")


func test_exact_furniture_owner_binds_once_and_expired_weak_target_cannot_be_replaced() -> void:
	"""An expired owner is missing authority, never an invitation to reset retained project ownership."""
	assert_equal(_f.owner.configure(_f.router, _f.orders), &"", "actual composed binding")
	assert_true(_f.orders.is_bound_furniture_owner(_f.owner), "exact live purpose attested")
	assert_true(_f.owner.binding_refusal() == &"", "actual owner ready")
	var other: FurnitureWork = FurnitureWork.new()
	assert_true(other.configure(_f.router, _f.orders) != &"", "replacement purpose refuses")
	assert_null(other.construction_owner(), "failed second owner has no partial composition")
	assert_false(_f.orders.is_bound_furniture_owner(null), "null owner never qualifies")
	_f.owner = null
	assert_true(other.configure(_f.router, _f.orders) != &"", "expired binding still cannot be replaced")
	assert_false(_f.orders.is_bound_furniture_owner(other), "new object cannot adopt old retained authority")


func test_room_area_is_exact_but_presence_never_grants_whole_room_service_validity() -> void:
	"""The actual Room identity owns positive floor area; count and service qualification stay distinct."""
	assert_equal(_f.owner.configure(_f.router, _f.orders), &"", "actual purpose binding")
	var room: Vector2i = _f.make_room(Buildings.ROOM_TYPE_DORMITORY)
	var area: Buildings.OpResult = _f.orders.area_of_room(room)
	assert_true(area.ok, "actual Room receives explicit synthetic physical area")
	assert_equal(area.ref, room, "full Room generation accompanies area")
	assert_equal(area.value, 8192 * 8192, "exact units squared; zero TileLinks is not zero area")
	assert_false(_f.orders.area_of_room(Vector2i(room.x, room.y + 1)).ok, "stale area refuses")
	assert_true(_f.orders.service_refusal(room) != &"", "service physical qualification deliberately absent")
	assert_false(_f.buildings.set_room_valid(room, true).ok, "caller cannot manufacture a whole-room service flag")
	assert_false(_f.buildings.room_is_valid(room), "no usable room service published")


func test_legacy_room_removal_retyping_and_item_mutations_cannot_borrow_furniture_authority() -> void:
	"""A complete or empty Room retains its permanent purpose until real removal/rebuild owns the transition."""
	assert_equal(_f.owner.configure(_f.router, _f.orders), &"", "actual Furniture purpose")
	var room: Vector2i = _f.make_room()
	var item: Vector2i = _f.pending()
	var before: PackedByteArray = _f.image()
	assert_false(_f.buildings.remove_room(room).ok, "room demolition needs its own actual physical workflow")
	assert_false(_f.buildings.reassign_furniture(item, room).ok, "pending item cannot use legacy reassignment")
	assert_false(_f.buildings.install_spatial_furniture(item).ok, "direct installed setter denied")
	assert_equal(_f.buildings.type_of_room(room).value, Buildings.ROOM_TYPE_KITCHEN, "purpose remains Kitchen")
	assert_true(_f.image() == before, "unauthorized operations change no actual owner state")
