extends RefCounted
## Decision 2052 (slice D2; Brendan, 2026-10-20, "Approve, start phase 1"): THE WAY IN SLICE D2 BINDS to
## `SettlementSystem.bind_underground_way_in`, the seam decision 1991 left. A finished way down gives one level its
## way in: its foot (`Foot`) names the level, the access endpoint at the bottom of the stair (the one access per World,
## P-1936-1 (a)), the room contacts' retreat travel row, the ground row, the headings a room may be dug from (wall,
## forward and backward rows, from the mounted content), and the points of the level's store and spoil pile.
##
## `StairWayIn.approach_into` fills a painted room's admission request and its order (`underground_room_confirm.gd`):
## - only for the foot's level; any other level is refused as the base seam does, "No way in: needs a way down to
##   level N";
## - the front station (P-2052-1 (a), `underground_way_in_front.gd`): found by geometry, published once, reused;
## - the store and the spoil pile (P-2052-2 (a)): one ground staging each on a STORAGE endpoint at the foot's
##   points, joined to the access, made on the first order and found again by their points after a load (no save
##   field); the staging container is the foot's (the surface R; a level below is stair-leg Delivery's, 1941 §2);
## - the order's access is always the foot's, so `ROOM_DIG_OTHER_ACCESS` never fires on one foot.
## A front this call published stays listed until the caller settles it (`settle`): kept when RoomOrders admitted
## the room, withdrawn when it refused; a later call is refused until then, so no front is ever forgotten (review
## H2). The host settles in phase 2's `order_painted_room`. Nothing here pays or digs.
##
## Phase 1 builds and proves this on the claw Kitchen fixture; deriving the Foot from the finished M5 entry, and the
## host binding at completion and on load, are phase 2 (decision 2052 §2.1). No build duration is assumed anywhere
## (Brendan's pacing ruling of 2026-10-20 supersedes P-2052-8).

const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Front := preload("res://scripts/core/underground_way_in_front.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## Named apart from the confirm route's own REFUSE_SCOPE, which the way in inherits through the WayIn base.
const REFUSE_FOOT: StringName = &"WAY_IN_SCOPE"
## The store or the spoil pile could not be made or reached at its point.
const REFUSE_CONTAINER: StringName = &"WAY_IN_CONTAINER"
## Review H2: the last call published a front and nobody said whether RoomOrders admitted its room (`settle`).
const REFUSE_UNSETTLED: StringName = &"WAY_IN_UNSETTLED"


class Foot extends RefCounted:
	## The foot of one finished way down, as its level's way in sees it.
	var level: int = -1
	var access: Vector2i = NULL_REF
	var travel: int = -1 # The room contacts' retreat travel row: Order.travel.
	var ground: int = -1 # The all-yaw ground WALK row joining a corner, the store and the pile to the access.
	var content: int = 0
	## The headings a room may be dug from, in preference order: parallel wall (WORK) and forward travel rows.
	var wall_rows: PackedInt32Array = PackedInt32Array()
	var forward_rows: PackedInt32Array = PackedInt32Array()
	var store_point: Vector3i = Vector3i.ZERO
	var pile_point: Vector3i = Vector3i.ZERO
	var staging: Vector2i = NULL_REF # The staging container a short store hauls from (the surface R), or none.

	func refusal() -> StringName:
		"""REFUSE_FOOT unless every field a room order reads is set and the heading rows pair up."""
		if level < 1 or access == NULL_REF or travel < 0 or ground < 0 or content <= 0 or wall_rows.is_empty() \
				or wall_rows.size() != forward_rows.size() or store_point == pile_point: return REFUSE_FOOT
		return &""


class StairWayIn extends Confirm.WayIn:
	## The seam filled from a finished way down's foot.
	var foot: Foot = null
	var owners: Builder.Owners = null
	var _pending: PackedInt32Array = PackedInt32Array() # Endpoints the last call published for its front.

	func configure(p_owners: Builder.Owners, p_foot: Foot) -> StringName:
		"""Take the Session's owners (as a dig borrows them) and the foot; refused when either is incomplete."""
		if p_owners == null or p_owners.locations == null or p_owners.binding == null or p_owners.inventory == null \
				or p_foot == null: return REFUSE_FOOT
		var code: StringName = p_foot.refusal()
		if code != &"": return code
		owners = p_owners
		foot = p_foot
		return &""

	func approach_into(request: Approach.Request, order: Composer.Order) -> StringName:
		"""The foot's level only: the room's front station, then the store and pile, then the order's way in. Refused
		REFUSE_UNSETTLED while the last call's published front is still unsettled (review H2): nothing is forgotten."""
		if foot == null or owners == null or request == null or order == null or request.level != foot.level:
			return Confirm.REFUSE_NO_WAY_IN
		if not _pending.is_empty(): return REFUSE_UNSETTLED
		var access: Locations.Record = Front.record()
		var code: StringName = owners.locations.read_location_into(foot.access, access)
		var front: Front.Candidate = Front.Candidate.new()
		if code == &"": code = Front.find_into(owners, foot, request, access, front)
		var corner: Vector2i = Front.publish_into(owners, foot, access, front, _pending) if code == &"" else NULL_REF
		if code == &"" and corner == NULL_REF: code = Front.REFUSE_UNJOINED
		if code == &"": code = _containers_into(access, order)
		if code != &"":
			withdraw_pending()
			return code
		_fill(request, order, front, corner)
		return &""

	func pending() -> PackedInt32Array:
		"""The endpoints (slot, generation pairs) the last call published for its front station, until withdrawn."""
		return _pending.duplicate()

	func settle(admitted: bool) -> StringName:
		"""The caller's answer once RoomOrders has ruled on the room the last call approached (Confirm's `admitted`):
		an admitted room keeps its front, which its approach stands on; a refused one's is withdrawn. Every caller
		settles after every successful `approach_into` (the host's `order_painted_room` in phase 2)."""
		if not admitted: return withdraw_pending()
		_pending.clear()
		return &""

	func withdraw_pending() -> StringName:
		"""Retire what the last call published for its front (a room RoomOrders then refused): the endpoints and every
		span touching them. Endpoints reused from before, the store and the pile stay."""
		if owners == null: return REFUSE_FOOT
		var code: StringName = Front.withdraw(owners, _pending)
		if code == &"": _pending.clear()
		return code

	func _fill(request: Approach.Request, order: Composer.Order, front: Front.Candidate, corner: Vector2i) -> void:
		"""The admission's approach from the corner to the station, and the order's way in from the foot."""
		request.access = corner
		request.work_location = front.station
		request.travel_profile = front.forward; request.travel_revision = front.forward_revision
		request.work_profile = front.wall; request.work_revision = front.wall_revision
		request.content_revision = foot.content
		request.target_origin = front.cube; request.face = front.face; request.yaw = front.yaw
		request.space_revision = owners.owner.revision() # Publication may have moved it; admission reads it fresh.
		order.access = foot.access
		order.travel = foot.travel
		order.staging = foot.staging

	func _containers_into(access: Locations.Record, order: Composer.Order) -> StringName:
		"""The store and the spoil pile at the foot's points (P-2052-2 (a)), made on first use."""
		order.storage = _container_at(access, foot.store_point)
		order.output = _container_at(access, foot.pile_point)
		return REFUSE_CONTAINER if order.storage == NULL_REF or order.output == NULL_REF else &""

	func _container_at(access: Locations.Record, point: Vector3i) -> Vector2i:
		"""The ground staging on the STORAGE endpoint at the point (its footing the ground row's), joined to the access
		by a straight span each way; the endpoint, its spans and the container are each made only when missing."""
		var made: PackedInt32Array = PackedInt32Array()
		var rows: PackedInt32Array = PackedInt32Array([foot.ground])
		var spot: Vector2i = Front.endpoint_at(owners, foot, access, point, Locations.ROLE_STORAGE, rows, made)
		if spot == NULL_REF or not Front.span_pair(owners, foot, access, foot.access, spot): return NULL_REF
		var found: Vector2i = owners.inventory.spatial_ground_container_at(spot)
		if found != NULL_REF: return found
		var created: Inventory.OpResult = owners.inventory.create_spatial_ground_staging(spot)
		return created.ref if created.ok else NULL_REF
