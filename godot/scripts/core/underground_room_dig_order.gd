extends RefCounted
## Decision 1933 (C2.1), BUILD-REQ-012: the order a confirmed underground room is dug in. Cells are taken
## breadth-first from the cells touching finished space (the access face), ties by cell index (z-major, then x, as
## SET-BUILD-001 §3's `z × 256 + x`), and the quanta inside a cell in the excavation contract's own key order
## (lowest layer first). Stateless and cold: it runs once when a room's dig starts, never per tick. It reads Sites'
## immutable keys and the Space owner's published open regions only; it pays, claims and publishes nothing.

const Sites := preload("res://scripts/core/excavation_sites.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_SCOPE: StringName = &"ROOM_DIG_ORDER_SCOPE"
const REFUSE_EMPTY: StringName = &"ROOM_DIG_ORDER_NO_SITES"
const REFUSE_NO_WAY_IN: StringName = &"ROOM_DIG_ORDER_NO_WAY_IN"
## A cell no breadth-first step reaches sorts after every reached cell (it is still tried; its refusal is honest).
const UNREACHED: int = 1 << 20
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


class Order extends RefCounted:
	## Caller-owned result: parallel Site rows and keys in dig order, and the breadth-first distance of each.
	var rows: PackedInt32Array = PackedInt32Array()
	var keys: PackedInt32Array = PackedInt32Array()
	var distance: PackedInt32Array = PackedInt32Array()


class Cells extends RefCounted:
	## Per-call scratch over one room's horizontal cells; dies with the call.
	var keys: PackedInt32Array = PackedInt32Array() # every Site key of the room, ascending
	var rows: PackedInt32Array = PackedInt32Array()
	var cells: PackedInt32Array = PackedInt32Array() # unique horizontal index z * size_x + x, ascending
	var distance: PackedInt32Array = PackedInt32Array()
	var floor_y: int = 0


static func order_into(sites: Sites, owner: Owner, room: Vector2i, out: Order) -> StringName:
	"""The whole room's dig order from the live open regions around it; a refusal leaves `out` unchanged."""
	if sites == null or owner == null or out == null or room == NULL_REF: return REFUSE_SCOPE
	var scratch: Cells = Cells.new()
	var code: StringName = _collect(sites, room, scratch)
	if code != &"": return code
	var voids: PackedInt32Array = PackedInt32Array()
	open_regions_into(owner, sites, scratch, voids)
	return order_from_into(sites, scratch, voids, out)


static func order_from_into(sites: Sites, scratch: Cells, voids: PackedInt32Array, out: Order) -> StringName:
	"""Seed from the cells beside any open box in `voids` (six ints per box), then order breadth-first. The sort key
	holds a cell index below 2^22 and a Site index below 2^20; a larger room or grid refuses rather than mis-sorts."""
	if scratch.keys.size() >= 1 << 20 or sites._domain.size_quanta.x * sites._domain.size_quanta.z >= 1 << 22:
		return REFUSE_SCOPE
	var seeds: PackedInt32Array = _seeds(sites, scratch, voids)
	if seeds.is_empty(): return REFUSE_NO_WAY_IN
	_spread(sites, scratch, seeds)
	_write(sites, scratch, out)
	return &""


static func collect_into(sites: Sites, room: Vector2i, out: Cells) -> StringName:
	"""Public seam for tests and callers that bring their own open boxes: the room's Sites and cells."""
	if sites == null or out == null or room == NULL_REF: return REFUSE_SCOPE
	return _collect(sites, room, out)


static func _collect(sites: Sites, room: Vector2i, out: Cells) -> StringName:
	"""Every live Site of the room in ascending key order, its floor layer and its unique horizontal cells."""
	var size_x: int = sites._domain.size_quanta.x
	var plane: int = size_x * sites._domain.size_quanta.z
	var floor_y: int = 1 << 30
	for index: int in sites._count:
		var row: int = sites._ordered_row[index]
		if sites._present[row] != 1 or sites._room_slot[row] != room.x or sites._room_generation[row] != room.y: continue
		out.keys.append(sites._ordered_key[index]); out.rows.append(row)
		@warning_ignore("integer_division") var layer: int = sites._ordered_key[index] / plane
		floor_y = mini(floor_y, layer)
		_insert_unique(out.cells, sites._ordered_key[index] % plane)
	if out.keys.is_empty(): return REFUSE_EMPTY
	out.floor_y = floor_y
	return &""


static func _insert_unique(sorted: PackedInt32Array, value: int) -> void:
	"""Keep an ascending set without duplicates (cold; one insert per Site)."""
	var at: int = sorted.bsearch(value)
	if at < sorted.size() and sorted[at] == value: return
	sorted.insert(at, value)


static func open_regions_into(owner: Owner, sites: Sites, scratch: Cells, out: PackedInt32Array) -> void:
	"""Live SUPPORTED_VOID regions that meet the room's floor layer within one cube of its cells."""
	var hull: PackedInt32Array = _hull(sites, scratch)
	var box: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	for row: int in owner._region_capacity:
		if owner._r_present[row] != 1 or owner._r_role[row] != Space.SUPPORTED_VOID: continue
		box[0] = owner._r_lo_x[row]; box[1] = owner._r_lo_y[row]; box[2] = owner._r_lo_z[row]
		box[3] = owner._r_hi_x[row]; box[4] = owner._r_hi_y[row]; box[5] = owner._r_hi_z[row]
		if Space.overlaps(box, hull): out.append_array(box)


static func _hull(sites: Sites, scratch: Cells) -> PackedInt32Array:
	"""The floor layer's world box around every cell, widened by one cube on each horizontal side."""
	var hull: PackedInt32Array = PackedInt32Array([1 << 30, 0, 1 << 30, -(1 << 30), 0, -(1 << 30)])
	var size_x: int = sites._domain.size_quanta.x
	for cell: int in scratch.cells:
		@warning_ignore("integer_division") var origin: Vector3i = cube_origin(sites, cell % size_x, scratch.floor_y, cell / size_x)
		hull[0] = mini(hull[0], origin.x - Contract.QUANTUM_SIDE_U); hull[3] = maxi(hull[3], origin.x + 2 * Contract.QUANTUM_SIDE_U)
		hull[2] = mini(hull[2], origin.z - Contract.QUANTUM_SIDE_U); hull[5] = maxi(hull[5], origin.z + 2 * Contract.QUANTUM_SIDE_U)
		hull[1] = origin.y; hull[4] = origin.y + Contract.QUANTUM_SIDE_U
	return hull


static func cube_origin(sites: Sites, x: int, y: int, z: int) -> Vector3i:
	"""World origin of one quantum cell of the Sites lattice, the same decode as Sites.origin_of."""
	var local: Vector3i = Vector3i(x, y, z)
	var origin: Vector3i = Vector3i.ZERO
	for axis: int in 3:
		origin[axis] = int(sites._domain.datum_u[axis]) \
			+ (int(local[axis]) + int(sites._domain.minimum_quantum[axis])) * Contract.QUANTUM_SIDE_U
	return origin


static func _seeds(sites: Sites, scratch: Cells, voids: PackedInt32Array) -> PackedInt32Array:
	"""Cells (ascending index) with a horizontal neighbour whose floor-layer cube is open: finished space outside the
	room, or a cell of the room already dug (an unpaid room cell is a reservation marker, never open)."""
	var seeds: PackedInt32Array = PackedInt32Array()
	var size_x: int = sites._domain.size_quanta.x
	var size_z: int = sites._domain.size_quanta.z
	for at: int in scratch.cells.size():
		var cell: int = scratch.cells[at]
		@warning_ignore("integer_division") var z: int = cell / size_x
		var x: int = cell % size_x
		for step: Vector2i in NEIGHBOURS:
			var nx: int = x + step.x
			var nz: int = z + step.y
			if nx < 0 or nz < 0 or nx >= size_x or nz >= size_z: continue
			if _open(cube_origin(sites, nx, scratch.floor_y, nz), voids):
				seeds.append(at)
				break
	return seeds


static func _open(origin: Vector3i, voids: PackedInt32Array) -> bool:
	"""The whole floor-layer cube lies inside one open box (finished space, not a sliver of air)."""
	@warning_ignore("integer_division") var boxes: int = voids.size() / 6
	for index: int in boxes:
		var at: int = index * 6
		if voids[at] <= origin.x and voids[at + 1] <= origin.y and voids[at + 2] <= origin.z \
				and voids[at + 3] >= origin.x + Contract.QUANTUM_SIDE_U \
				and voids[at + 4] >= origin.y + Contract.QUANTUM_SIDE_U \
				and voids[at + 5] >= origin.z + Contract.QUANTUM_SIDE_U: return true
	return false


static func _spread(sites: Sites, scratch: Cells, seeds: PackedInt32Array) -> void:
	"""Plain breadth-first distances over the room's 4-connected cells from every seed at distance 0."""
	var size_x: int = sites._domain.size_quanta.x
	scratch.distance.resize(scratch.cells.size())
	scratch.distance.fill(UNREACHED)
	var queue: PackedInt32Array = seeds.duplicate()
	for at: int in seeds: scratch.distance[at] = 0
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		var cell: int = scratch.cells[at]
		for step: Vector2i in NEIGHBOURS:
			var next: int = scratch.cells.bsearch(cell + step.y * size_x + step.x)
			if next >= scratch.cells.size() or scratch.cells[next] != cell + step.y * size_x + step.x: continue
			if step.x != 0 and (cell % size_x) + step.x != (scratch.cells[next] % size_x): continue
			if scratch.distance[next] != UNREACHED: continue
			scratch.distance[next] = scratch.distance[at] + 1
			queue.append(next)


static func _write(sites: Sites, scratch: Cells, out: Order) -> void:
	"""Sort every Site by (cell distance, cell index, key): breadth-first, ties by cell index, layers upward."""
	var plane: int = sites._domain.size_quanta.x * sites._domain.size_quanta.z
	var sort: PackedInt64Array = PackedInt64Array()
	sort.resize(scratch.keys.size())
	for index: int in scratch.keys.size():
		var cell: int = scratch.keys[index] % plane
		var distance: int = scratch.distance[scratch.cells.bsearch(cell)]
		sort[index] = (distance << 42) | (cell << 20) | index
	sort.sort()
	out.rows.resize(sort.size()); out.keys.resize(sort.size()); out.distance.resize(sort.size())
	for at: int in sort.size():
		var index: int = sort[at] & 0xFFFFF
		out.rows[at] = scratch.rows[index]
		out.keys[at] = scratch.keys[index]
		out.distance[at] = sort[at] >> 42
