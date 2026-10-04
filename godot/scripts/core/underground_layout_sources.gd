extends "res://scripts/core/room_layout.gd".Sources
## Actual typed RoomLayout adapter. It never supplies prices, geometry or a boolean permission fixture.
## A strong coordinator reference lasts only through the same synchronous input lease.

const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const Layout := preload("res://scripts/core/room_layout.gd")

var _rooms: WeakRef = null
var _active: RoomOrders = null


func _init(rooms: RoomOrders) -> void:
	"""Pin the actual coordinator weakly; no callback, world image or cold allocation occurs here."""
	_rooms = weakref(rooms) if rooms != null else null


func _owner() -> RoomOrders:
	"""Numeric Room references cannot replace an expired actual coordinator object."""
	return _rooms.get_ref() as RoomOrders if _rooms != null else null


func binding_refusal() -> StringName:
	"""This read invokes only the coordinator's local exact identity proof, not a provider callback."""
	var rooms: RoomOrders = _owner()
	return rooms.layout_binding_refusal() if rooms != null else RoomOrders.REFUSE_BINDING


func begin_operation(room: Vector2i, packed_bytes: int, geometry_limit: int,
		placement_limit: int) -> int:
	"""Retain the actual owner before acquisition so callbacks and synchronous cleanup cannot outlive it."""
	if _active != null:
		return 0
	_active = _owner()
	if _active == null:
		return 0
	var token: int = _active.begin_layout_operation(room, packed_bytes, geometry_limit, placement_limit)
	if token <= 0:
		_active = null
	return token


func cold_refusal() -> StringName:
	"""Forward the explicit actual acquisition error; never manufacture a nonzero lease."""
	var rooms: RoomOrders = _owner()
	return rooms.layout_cold_refusal() if rooms != null else RoomOrders.REFUSE_BINDING


func scope_refusal(token: int, room: Vector2i, packed_bytes: int) -> StringName:
	"""The operation keeps its exact original coordinator and physical provider for its whole lifetime."""
	return _active.layout_scope_refusal(token, room, packed_bytes) \
		if _active != null and _active == _owner() else Layout.REFUSE_SCOPE


func end_operation(token: int, room: Vector2i) -> StringName:
	"""RoomLayout has already dropped its views; actual provider/receipt scratch drops before shared release."""
	if _active == null or _active != _owner():
		return Layout.REFUSE_SCOPE
	var code: StringName = _active.end_layout_operation(token, room)
	if not _active.has_layout_scope():
		_active = null
	return code


func read(room: Vector2i, token: int) -> Layout.Snapshot:
	"""Only the actual Room coordinator can provide completed physical floor/profile/contact evidence."""
	return _active.layout_snapshot(room, token) if _active != null and _active == _owner() else null


func is_live(domain: int, ref: Vector2i, token: int) -> bool:
	"""Query the real Directory-backed typed stores, including each generation, inside the current scope."""
	return _active != null and _active == _owner() and _active.layout_identity_live(domain, ref, token)


func can_submit(token: int) -> bool:
	"""Submission is the actual paired transaction, never a caller-supplied callable or permission bit."""
	return _active != null and _active == _owner() and _active.can_submit_layout(token)


func submit(batch: Layout.Batch, token: int) -> Layout.Submission:
	"""Return the actual accepted project receipt, or an explicit refusal with no world mutation."""
	return _active.accept_layout(batch, token) if _active != null and _active == _owner() else null
