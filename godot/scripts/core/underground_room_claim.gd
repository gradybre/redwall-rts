extends RefCounted
## Decision 1936: what a room builder's cube footprint is swept from (ECON-001, decisions 1933 and 1935): the way back,
## the station's work, the way there and, with a haul, the walk to the storage, each trip's searched edges and the two
## stands. The plan keeps these inputs, not the boxes, so the footprint is swept by this one function both when the
## cube is planned and when a save is loaded (decision 1936: the save writes the inputs, ARCH-SAVE-006 parity).

const Footprint := preload("res://scripts/core/underground_room_footprint.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## Decision 1936: at most this many legs in one planned leg list, and edges in one haul's searched trips (the save's
## bounds; the Kitchen's longest list is 4 legs). A longer plan is refused.
const MAX_LEGS: int = 16
const MAX_TRIP_EDGES: int = 32

var home_legs: PackedInt32Array = PackedInt32Array() # (slot, generation) per leg: the way back to the parking.
var home_profiles: PackedInt32Array = PackedInt32Array()
var approach_legs: PackedInt32Array = PackedInt32Array() # The way to the station.
var approach_profiles: PackedInt32Array = PackedInt32Array()
var store_legs: PackedInt32Array = PackedInt32Array() # With a haul: the way from `start` to the storage.
var store_profiles: PackedInt32Array = PackedInt32Array()
var start: Vector2i = NULL_REF # Where the builder stood when the cube was planned.
var store: Vector2i = NULL_REF # With a haul: the storage's endpoint, where the approach starts.
var trips: PackedInt32Array = PackedInt32Array() # (edge slot, edge generation, row) per searched trip edge.
var stands: PackedInt32Array = PackedInt32Array() # With a haul: R's stand, then M's stand, as (slot, generation).
var carries: PackedInt32Array = PackedInt32Array() # With a haul: each hauled item family's CARRY row.


func clear() -> void:
	"""No cube planned."""
	home_legs.clear(); home_profiles.clear(); approach_legs.clear(); approach_profiles.clear()
	store_legs.clear(); store_profiles.clear(); trips.clear(); stands.clear(); carries.clear()
	start = NULL_REF
	store = NULL_REF


func hauls() -> bool:
	"""The plan runs through the storage."""
	return store != NULL_REF


func bounded() -> bool:
	"""Every list is within the save's bounds."""
	return home_profiles.size() <= MAX_LEGS and approach_profiles.size() <= MAX_LEGS \
		and store_profiles.size() <= MAX_LEGS and trips.size() <= 3 * MAX_TRIP_EDGES and carries.size() <= 2


func sweep_into(foot: Footprint, locations: Locations, routes: Routes, station: Vector2i, work: int) -> void:
	"""The whole footprint, in plan order: way back, station work, way there, trips and the walk to the storage."""
	foot.clear_claim()
	if station == NULL_REF: return
	_legs_into(foot, locations, station, home_legs, home_profiles)
	var point: Vector3i = point_of(locations, station)
	foot.sweep(point, point, work)
	_legs_into(foot, locations, store if hauls() else start, approach_legs, approach_profiles)
	if not hauls(): return
	_trips_into(foot, routes)
	for at: int in carries.size():
		var source: Vector3i = point_of(locations, Vector2i(stands[0], stands[1]))
		var target: Vector3i = point_of(locations, Vector2i(stands[2], stands[3]))
		foot.sweep(source, source, carries[at] + 2) # ADR1206: the item's lift row at R's stand.
		foot.sweep(target, target, carries[at] + 4) # Its set-down row at M's stand.
	_legs_into(foot, locations, start, store_legs, store_profiles)


static func _legs_into(foot: Footprint, locations: Locations, from: Vector2i, legs: PackedInt32Array,
		profiles: PackedInt32Array) -> void:
	"""Each leg's row swept from its start point to its end point."""
	var a: Vector3i = point_of(locations, from)
	for leg: int in profiles.size():
		var b: Vector3i = point_of(locations, Vector2i(legs[2 * leg], legs[2 * leg + 1]))
		foot.sweep(a, b, profiles[leg])
		a = b


func _trips_into(foot: Footprint, routes: Routes) -> void:
	"""Every polyline segment of each searched trip edge, on its row."""
	for at: int in range(0, trips.size(), 3):
		var edge: int = trips[at]
		for vertex: int in range(1, routes._edge_i32(routes._live, Routes.E_PATH_COUNT, edge)):
			foot.sweep(routes._vertex(edge, vertex - 1), routes._vertex(edge, vertex), trips[at + 2])


static func point_of(locations: Locations, location: Vector2i) -> Vector3i:
	"""The integer point of a Location, read from its bank."""
	var cap: int = locations._capacity
	return Vector3i(locations._live.i32[Locations.X * cap + location.x], locations._live.i32[Locations.Y * cap + location.x],
		locations._live.i32[Locations.Z * cap + location.x])
