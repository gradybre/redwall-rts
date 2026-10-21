extends RefCounted
## Decision 2052 (slice D2; Brendan, 2026-10-20, "Approve, start phase 1"): THE WAY IN SLICE D2 BINDS to
## `SettlementSystem.bind_underground_way_in`, the seam decision 1991 left. A finished way down gives one level its
## way in: its foot (`Foot`) names the level, the access endpoint rooms are dug from (the one access per World,
## P-1936-1 (a)), the room contacts' retreat travel row, the ground row, the headings a room may be dug from (wall,
## forward and backward rows, from the mounted content), and the points of the level's store and spoil pile.
##
## `StairWayIn.approach_into` fills a painted room's admission request and its order (`underground_room_confirm.gd`):
## - only for the foot's level; any other level is refused as the base seam does, "No way in: needs a way down to
##   level N";
## - the foot made ready once (`prepare`, decision 2054, `underground_way_in_foot_prep.gd`): at M5's foot a floor hub
##   with the run-out's air joined to the stair's own stop F', the parking, the store and its grip stand with the
##   loaded span from F' (P-2091-7 (a)), and the pile; on the claw Kitchen fixture the access is given and only the
##   store and pile are made;
## - the front station (P-2052-1 (a), `underground_way_in_front.gd`): found by geometry, published once, reused;
## - the store and the spoil pile (P-2052-2 (a)), found again by their points after a load (no save field); the
##   staging container is the foot's (the surface R; a level below is stair-leg Delivery's, 1941 §2);
## - the order's access is always the foot's, so `ROOM_DIG_OTHER_ACCESS` never fires on one foot.
## A front this call published stays listed until the caller settles it (`settle`): kept when RoomOrders admitted
## the room, withdrawn when it refused; a later call is refused until then, so no front is ever forgotten (review
## H2). Decision 2054: a kept front is retired once its room's record is released (`retire_fronts`), and the fronts
## are found again from the rooms' Sites after a load (`recall_fronts`). Nothing here pays or digs. No build duration
## is assumed anywhere (Brendan's pacing ruling of 2026-10-20 supersedes P-2052-8).

const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Front := preload("res://scripts/core/underground_way_in_front.gd")
const Prep := preload("res://scripts/core/underground_way_in_foot_prep.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## Named apart from the confirm route's own REFUSE_SCOPE, which the way in inherits through the WayIn base.
const REFUSE_FOOT: StringName = &"WAY_IN_SCOPE"
## The store or the spoil pile could not be made or reached at its point.
const REFUSE_CONTAINER: StringName = Prep.REFUSE_CONTAINER
## Review H2: the last call published a front and nobody said whether RoomOrders admitted its room (`settle`).
const REFUSE_UNSETTLED: StringName = &"WAY_IN_UNSETTLED"
## Decision 2054: a room to re-order has no cells on the foot's level.
const REFUSE_NO_ROOM: StringName = &"WAY_IN_NO_ROOM"
## Decision 2054 (review H3): an admitted room settled without naming the room.
const REFUSE_SETTLE_ROOM: StringName = &"WAY_IN_SETTLE_ROOM"


class Foot extends Prep.Foot:
	## The foot of one finished way down, as its level's way in sees it (the fields: `Prep.Foot`).
	pass


class StairWayIn extends Confirm.WayIn:
	## The seam filled from a finished way down's foot.
	var foot: Foot = null
	var owners: Builder.Owners = null
	var _pending: PackedInt32Array = PackedInt32Array() # Endpoints the last call published for its front.
	var _last: Front.Candidate = null # The last call's front, until settled.
	## Decision 2054: the kept fronts, three pairs each: room, station, corner (the corner is the access when none).
	var _fronts: PackedInt32Array = PackedInt32Array()
	var _refused_kept: int = -1 # Review H5: the kept-record count when a retirement was last refused.
	var _retiring: PackedInt32Array = PackedInt32Array() # Review H5: one scratch list, reused.

	func configure(p_owners: Builder.Owners, p_foot: Foot) -> StringName:
		"""Take the Session's owners (as a dig borrows them) and the foot; refused when either is incomplete."""
		if p_owners == null or p_owners.locations == null or p_owners.binding == null or p_owners.inventory == null \
				or p_foot == null: return REFUSE_FOOT
		var code: StringName = p_foot.refusal()
		if code != &"": return code
		owners = p_owners
		foot = p_foot
		return &""

	func prepare() -> StringName:
		"""Decision 2054: make the foot ready (idempotent: what exists is found by its point): the access, the parking,
		the store and the pile (all a room order needs, which `approach_into` makes itself), then the store's grip stand
		and its loaded span from the hub (P-2091-7 (a), for stair-leg Delivery, which calls this when it binds)."""
		if foot == null or owners == null: return REFUSE_FOOT
		var code: StringName = Prep.access_ready(owners, foot)
		if code == &"": code = Prep.containers_into(owners, foot, Composer.Order.new())
		return code if code != &"" else Prep.stand_ready(owners, foot)

	func approach_into(request: Approach.Request, order: Composer.Order) -> StringName:
		"""The foot's level only: the room's front station, the foot made ready, then the order's way in. Refused
		REFUSE_UNSETTLED while the last call's published front is still unsettled (review H2): nothing is forgotten."""
		if foot == null or owners == null or request == null or order == null or request.level != foot.level:
			return Confirm.REFUSE_NO_WAY_IN
		if not _pending.is_empty(): return REFUSE_UNSETTLED
		var front: Front.Candidate = Front.Candidate.new()
		var code: StringName = _front_into(request, order, front)
		if code == &"": _fill(request, order, front, front.corner_ref)
		return code

	func order_into(room: Vector2i, order: Composer.Order) -> StringName:
		"""Decision 2054 (M-4, P-2052-5 (a)): the way in of a room already confirmed, to re-order it whole (Resume after
		a Stop): its front found again from its Sites (published again if it was retired) and kept, then the order's
		access, retreat row and containers."""
		if foot == null or owners == null or order == null: return REFUSE_FOOT
		if not _pending.is_empty(): return REFUSE_UNSETTLED
		var request: Approach.Request = Prep.request_of_room(owners.sites, room, foot.level)
		if request == null: return REFUSE_NO_ROOM
		var front: Front.Candidate = Front.Candidate.new()
		var code: StringName = _front_into(request, order, front)
		if code != &"": return code
		_fill_order(order)
		order.room = room
		return &""

	func _front_into(request: Approach.Request, order: Composer.Order, front: Front.Candidate) -> StringName:
		"""Decision 2054: the front found from the access as it is (or will be) published, publishing nothing until it
		is; then the foot made ready, the front published and the containers; a refusal withdraws what it published."""
		var access: Locations.Record = Front.record()
		var code: StringName = Prep.access_record(owners, foot, access)
		if code == &"": code = Front.find_into(owners, foot, request, access, front)
		if code == &"": code = Prep.access_ready(owners, foot)
		var corner: Vector2i = Front.publish_into(owners, foot, access, foot.access, front, _pending) \
			if code == &"" else NULL_REF
		if code == &"" and corner == NULL_REF: code = Front.REFUSE_UNJOINED
		if code == &"": code = Prep.containers_into(owners, foot, order)
		if code != &"":
			withdraw_pending()
			return code
		front.corner_ref = corner
		_last = front
		return &""

	func pending() -> PackedInt32Array:
		"""The endpoints (slot, generation pairs) the last call published for its front station, until withdrawn."""
		return _pending.duplicate()

	func settle(admitted: bool, room: Vector2i = NULL_REF) -> StringName:
		"""The caller's answer once RoomOrders has ruled on the room the last call approached (Confirm's `admitted`
		and `room`): an admitted room keeps its front, which its approach stands on, until its record is released
		(`retire_fronts`); a refused one's is withdrawn. Every caller settles after every successful `approach_into`
		(the host's `order_painted_room`) and `order_into`. Decision 2054 (review H3): an admitted answer must name
		its room, or the front could never be retired; REFUSE_SETTLE_ROOM keeps it unsettled."""
		if not admitted:
			_last = null
			return withdraw_pending()
		if room == NULL_REF: return REFUSE_SETTLE_ROOM
		if _last != null: _keep(room, _last.station, _last.corner_ref)
		_last = null
		_pending.clear()
		return &""

	func withdraw_pending() -> StringName:
		"""Retire what the last call published for its front (a room RoomOrders then refused): the endpoints and every
		span touching them. Endpoints reused from before, the store and the pile stay."""
		if owners == null: return REFUSE_FOOT
		_last = null
		var code: StringName = Front.withdraw(owners, _pending)
		if code == &"": _pending.clear()
		return code

	func fronts() -> PackedInt32Array:
		"""The kept fronts: (room, station, corner) as six integers each."""
		return _fronts.duplicate()

	func retire_fronts(runtime: Runtime) -> int:
		"""Decision 2054 (2053 §3): retire each kept front whose room's record is released (dug, or stopped and its crew
		out): its station, and its corner unless it is the access or another kept front's. A refused retirement (an
		actor still on it) is offered again only once the rooms' records change (review H5: no retry, and nothing
		allocated, on every tick while it stays refused). Returns the fronts retired."""
		if runtime == null or owners == null or _fronts.is_empty() or runtime.kept() == _refused_kept: return 0
		_refused_kept = -1
		var retired: int = 0
		var at: int = 0
		while at < _fronts.size():
			var room: Vector2i = Vector2i(_fronts[at], _fronts[at + 1])
			if runtime.state_of(room) != Runtime.RECORD_NONE:
				at += 6
				continue
			if not _retire(at):
				_refused_kept = runtime.kept()
				at += 6
				continue
			_fronts = _fronts.slice(0, at) + _fronts.slice(at + 6)
			retired += 1
		return retired

	func recall_fronts(runtime: Runtime) -> int:
		"""Decision 2054: after a load, find the kept fronts again, unsaved and publishing nothing: for every room with
		Sites on the foot's level, the front the way in places for it, where both its endpoints are live. Returns how
		many."""
		if runtime == null or owners == null or not _fronts.is_empty() or not Prep.access_found(owners, foot): return 0
		var access: Locations.Record = Front.record()
		if owners.locations.read_location_into(foot.access, access) != &"": return 0
		for room: Vector2i in Prep.rooms_on_level(owners.sites, access.point.y):
			var request: Approach.Request = Prep.request_of_room(owners.sites, room, foot.level)
			var front: Front.Candidate = Front.Candidate.new()
			if request == null or Front.find_into(owners, foot, request, access, front) != &"": continue
			var station: Vector2i = Front.existing(owners.locations, access, front.point, Locations.ROLE_WORK)
			var corner: Vector2i = foot.access if front.corner == access.point \
				else Front.existing(owners.locations, access, front.corner, Locations.ROLE_TRANSIT)
			if station != NULL_REF and corner != NULL_REF: _keep(room, station, corner)
		@warning_ignore("integer_division") var count: int = _fronts.size() / 6
		return count

	func _keep(room: Vector2i, station: Vector2i, corner: Vector2i) -> void:
		"""Keep one front, once per room."""
		for at: int in range(0, _fronts.size(), 6):
			if _fronts[at] == room.x and _fronts[at + 1] == room.y: return
		_fronts.append_array(PackedInt32Array([room.x, room.y, station.x, station.y, corner.x, corner.y]))

	func _retire(at: int) -> bool:
		"""Retire the front kept at `at`: its station, and its corner unless shared or the access."""
		var station: Vector2i = Vector2i(_fronts[at + 2], _fronts[at + 3])
		var corner: Vector2i = Vector2i(_fronts[at + 4], _fronts[at + 5])
		_retiring.clear()
		if not _shared(at, station) and owners.locations._live_ref(owners.locations._live, station):
			_retiring.append(station.x); _retiring.append(station.y)
		if corner != foot.access and not _shared(at, corner) \
				and owners.locations._live_ref(owners.locations._live, corner):
			_retiring.append(corner.x); _retiring.append(corner.y)
		return Front.withdraw(owners, _retiring) == &""

	func _shared(at: int, ref: Vector2i) -> bool:
		"""Another kept front uses the endpoint (as its station or its corner)."""
		for other: int in range(0, _fronts.size(), 6):
			if other == at: continue
			if (_fronts[other + 2] == ref.x and _fronts[other + 3] == ref.y) \
					or (_fronts[other + 4] == ref.x and _fronts[other + 5] == ref.y): return true
		return false

	func _fill(request: Approach.Request, order: Composer.Order, front: Front.Candidate, corner: Vector2i) -> void:
		"""The admission's approach from the corner to the station, and the order's way in from the foot."""
		request.access = corner
		request.work_location = front.station
		request.travel_profile = front.forward; request.travel_revision = front.forward_revision
		request.work_profile = front.wall; request.work_revision = front.wall_revision
		request.content_revision = foot.content
		request.target_origin = front.cube; request.face = front.face; request.yaw = front.yaw
		request.space_revision = owners.owner.revision() # Publication may have moved it; admission reads it fresh.
		_fill_order(order)

	func _fill_order(order: Composer.Order) -> void:
		"""The order's way in: the foot's access, retreat row and staging (its containers are already set)."""
		order.access = foot.access
		order.travel = foot.travel
		order.staging = foot.staging
