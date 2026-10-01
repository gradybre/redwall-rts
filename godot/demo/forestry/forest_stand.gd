extends RefCounted
## The demo's trees as REAL ResourceNode rows. Decision 0196 (live demo). Presentation around a real
## store: every tree the village shows is a row in `scripts/core/resource_nodes.gd`, created on the
## GDD §5.1 exterior tile it stands on, and every change to its wood goes through that store's own
## verbs -- nothing here does the store's arithmetic.
##
##   mature tree   `create_at_tile(tile, wood, 12000, 48, day)`: §5.1's "Each mature node contains
##                 12 wood U"; `resource_id` is the compiled `wood` item (READY_07 §2, bound by the
##                 caller through resource_catalog_binding.gd).
##   felling       `harvest_all(slot, day)` -- REQ-SET-138's single debit, which dates the stump. The
##                 debited wood becomes the felled trunk lying there (`trunk_milli`) until it is hauled
##                 away a load at a time (`take_trunk_into`), so node -> trunk -> stores is conserved.
##   regrowth      each day `is_regrow_ready_into` then `regrow(slot, day)`, only while the stump
##                 remains and nothing occupies its spot (§5.9; the store cannot see occupancy, its
##                 header says so, so the caller's `occupied` answers it).
##   blow-down     a storm uproots a tree: `harvest_all` (its wood lies as a trunk), then `destroy` --
##                 no stump remains, so the spot is CLEARED and nothing regrows until it is replanted.
##   grubbing      a stump dug out: `destroy`; the spot is cleared.
##   planting      §5.9's cleared forestry tile, maturing after 48 days. GAP, NAMED: the store has no
##                 verb that creates a growing (empty) row -- `create_at_tile` makes a FULL node, as §5.1
##                 generates them. A planting is therefore `create_at_tile` then a same-day `harvest_all`
##                 whose 12 U are NOT credited anywhere: the row ends exactly as §5.9 describes it
##                 (empty, `planted_day` today, ready on day + 48), and the returned wood is discarded
##                 because a sapling holds none. The demo's standing saplings are bound the same way on
##                 day 1. Recorded for decision 0196; a planting verb belongs to the real store.
##
## STATES (per tree, read from the store): MATURE (a live full row), STUMP (an emptied row with its
## stump standing), YOUNG (an emptied row that was planted -- a sapling), CLEARED (no row: uprooted or
## grubbed out). A felled trunk may lie beside any of them.
##
## Columns are packed and sized once (MAX_TREES); positions, yaw and size are presentation floats.

const IntMath := preload("res://scripts/core/int_math.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const Layout := preload("res://demo/world/world_layout.gd")

const MAX_TREES: int = 256
const STATE_CLEARED: int = 0
const STATE_MATURE: int = 1
const STATE_STUMP: int = 2
const STATE_YOUNG: int = 3
const STATE_NAMES: Array[String] = ["cleared", "mature", "stump", "young"]
const LOOK_OAK: int = 0
const LOOK_BEECH: int = 1
const LOOK_KEYS: Array[StringName] = [&"oak_mature", &"beech_mature"]
const LOOK_NAMES: Array[String] = ["Oak", "Beech"]
const SAPLING_KEY: StringName = &"oak_sapling"
const NO_SLOT: int = -1

const REFUSE_NOT_A_TREE: String = "NOT_A_TREE"
const REFUSE_NOT_MATURE: String = "NOT_MATURE"
const REFUSE_NO_STUMP: String = "NO_STUMP"
const REFUSE_NOT_CLEARED: String = "NOT_CLEARED"
const REFUSE_NO_TRUNK: String = "NO_TRUNK"
const REFUSE_UNBOUND: String = "NO_WOOD_ITEM_BOUND"
const REFUSE_FULL: String = "STAND_FULL"

## The real store (its own directory: the demo's trees are not the settlement's world).
var nodes: ResourceNodes = ResourceNodes.new()
## Bumped on every change, so drawings and panels redraw only when something changed.
var revision: int = 0

var at: PackedVector2Array = PackedVector2Array()
var yaw: PackedFloat32Array = PackedFloat32Array()
var size: PackedFloat32Array = PackedFloat32Array()
## The trunk's obstacle radius as the world placed it (world_layout.gd TRUNK_RADIUS_M x size), m.
var radius_m: PackedFloat32Array = PackedFloat32Array()
var look: PackedByteArray = PackedByteArray()
var tile: PackedInt32Array = PackedInt32Array()
## Which world placement each tree is drawn by (demo_world.gd `trees()` index).
var placement: PackedInt32Array = PackedInt32Array()
## The row standing on the tree's tile (NO_SLOT when cleared); the store is private, so only this
## module changes it and the cache cannot go stale.
var node_slot: PackedInt32Array = PackedInt32Array()
var stump: PackedByteArray = PackedByteArray()
var trunk_milli: PackedInt64Array = PackedInt64Array()
## Which way the tree fell (presentation), and whether it was gnawed down (the beaver's look).
var fall_dir: PackedVector2Array = PackedVector2Array()
var gnawed: PackedByteArray = PackedByteArray()
## Placements left unbound because their tile already held a tree (two trunks within one 2 m tile).
var skipped: int = 0

var _count: int = 0
var _wood_id: int = -1
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Size every column once."""
	for column: PackedInt32Array in [tile, placement, node_slot]:
		column.resize(MAX_TREES)
	for column: PackedByteArray in [look, stump, gnawed]:
		column.resize(MAX_TREES)
	at.resize(MAX_TREES)
	yaw.resize(MAX_TREES)
	size.resize(MAX_TREES)
	radius_m.resize(MAX_TREES)
	trunk_milli.resize(MAX_TREES)
	fall_dir.resize(MAX_TREES)
	node_slot.fill(NO_SLOT)


func count() -> int:
	"""How many trees are bound."""
	return _count


func bind_into(placements: Array[Dictionary], wood_id: int, day: int, out: IntMath.IntResult) -> bool:
	"""Bind every tree placement (`key`, `at`, `yaw`, `size`) to a real row on `day`: mature keys full,
	saplings growing (see the header). `out.value` is how many were bound. Refuses a negative wood id."""
	if wood_id < 0:
		return out.refuse(REFUSE_UNBOUND)
	_wood_id = wood_id
	for k: int in placements.size():
		var p: Dictionary = placements[k]
		if _count >= MAX_TREES or not Rules.tile_of_into(p["at"], _read) or nodes.has_node_at_tile(_read.value):
			skipped += 1
			continue
		_add(k, p, _read.value)
		if not _grow_new(_count - 1, day, p["key"] == SAPLING_KEY):
			_count -= 1
			skipped += 1
	revision += 1
	return out.succeed(_count)


func _add(k: int, p: Dictionary, on_tile: int) -> void:
	"""Fill one tree's presentation columns."""
	var t: int = _count
	at[t] = p["at"]
	yaw[t] = float(p["yaw"])
	size[t] = float(p["size"])
	radius_m[t] = float(Layout.TRUNK_RADIUS_M.get(p["key"], 0.3)) * size[t]
	look[t] = LOOK_BEECH if p["key"] == LOOK_KEYS[LOOK_BEECH] else LOOK_OAK
	tile[t] = on_tile
	placement[t] = k
	stump[t] = 0
	trunk_milli[t] = 0
	gnawed[t] = 0
	fall_dir[t] = Vector2.ZERO
	_count += 1


func _grow_new(t: int, day: int, sapling: bool) -> bool:
	"""Create tree `t`'s row: full, or -- a sapling -- emptied the same day (the planting gap)."""
	var made: ResourceNodes.OpResult = nodes.create_at_tile(tile[t], _wood_id, Rules.TREE_WOOD_MILLI,
		Rules.REGROW_DAYS, day)
	if not made.ok:
		return false
	node_slot[t] = nodes.directory().get_typed_row(made.ref)
	if not sapling or nodes.harvest_all(node_slot[t], day).ok:
		return true
	nodes.destroy(made.ref)
	node_slot[t] = NO_SLOT
	return false


func is_tree(t: int) -> bool:
	"""Whether `t` names a bound tree."""
	return t >= 0 and t < _count


func state_of(t: int) -> int:
	"""STATE_*: what stands at tree `t`."""
	if not is_tree(t) or node_slot[t] == NO_SLOT:
		return STATE_CLEARED
	if not nodes.is_exhausted(node_slot[t]):
		return STATE_MATURE
	return STATE_STUMP if stump[t] == 1 else STATE_YOUNG


func wood_milli_of(t: int) -> int:
	"""The wood standing in tree `t`'s row (0 when growing or cleared)."""
	if state_of(t) == STATE_CLEARED or not nodes.quantity_milli_into(node_slot[t], _read):
		return 0
	return _read.value


func fell_into(t: int, day: int, direction: Vector2, by_gnawing: bool, out: IntMath.IntResult) -> bool:
	"""REQ-SET-138: fell a mature tree on `day` -- the store debits its wood once and dates the stump.
	The wood lies as the felled trunk. `out.value` is the wood debited. Refuses anything not mature."""
	if state_of(t) != STATE_MATURE:
		return out.refuse(REFUSE_NOT_MATURE if is_tree(t) else REFUSE_NOT_A_TREE)
	var cut: ResourceNodes.OpResult = nodes.harvest_all(node_slot[t], day)
	if not cut.ok:
		return out.refuse(String(cut.error))
	stump[t] = 1
	trunk_milli[t] += cut.value
	fall_dir[t] = direction
	gnawed[t] = 1 if by_gnawing else 0
	revision += 1
	return out.succeed(cut.value)


func blow_down_into(t: int, day: int, direction: Vector2, out: IntMath.IntResult) -> bool:
	"""A storm uproots a mature tree: its wood is debited once (it lies as a trunk) and the row goes --
	no stump, so the spot is cleared. `out.value` is the wood debited."""
	if not fell_into(t, day, direction, false, out):
		return false
	var felled: int = out.value
	if not _clear(t):
		return out.refuse(REFUSE_NO_STUMP)
	return out.succeed(felled)


func grub_into(t: int, out: IntMath.IntResult) -> bool:
	"""Dig a stump out: the row goes and the spot is cleared (ready to replant)."""
	if state_of(t) != STATE_STUMP:
		return out.refuse(REFUSE_NO_STUMP)
	if not _clear(t):
		return out.refuse(REFUSE_NO_STUMP)
	return out.succeed(tile[t])


func _clear(t: int) -> bool:
	"""Destroy tree `t`'s row (the store frees its tile and directory slot)."""
	var gone: ResourceNodes.OpResult = nodes.destroy(nodes.ref_of(node_slot[t]))
	if not gone.ok:
		return false
	node_slot[t] = NO_SLOT
	stump[t] = 0
	revision += 1
	return true


func plant_into(t: int, day: int, out: IntMath.IntResult) -> bool:
	"""§5.9: plant a sapling on a cleared spot on `day`; it matures after 48 days (the planting gap in
	the header). `out.value` is the maturing day. Refuses a spot that is not cleared."""
	if not is_tree(t) or state_of(t) != STATE_CLEARED:
		return out.refuse(REFUSE_NOT_CLEARED)
	if _wood_id < 0:
		return out.refuse(REFUSE_UNBOUND)
	if not _grow_new(t, day, true):
		node_slot[t] = NO_SLOT
		return out.refuse(REFUSE_NOT_CLEARED)
	look[t] = LOOK_OAK
	revision += 1
	return nodes.regrow_ready_day_into(node_slot[t], out)


func take_trunk_into(t: int, want_milli: int, out: IntMath.IntResult) -> bool:
	"""Take up to `want_milli` of the felled trunk's wood (a hauler's load). `out.value` is what was
	taken; refuses when nothing lies there."""
	if not is_tree(t) or trunk_milli[t] <= 0 or want_milli <= 0:
		return out.refuse(REFUSE_NO_TRUNK)
	var taken: int = mini(want_milli, trunk_milli[t])
	trunk_milli[t] -= taken
	revision += 1
	return out.succeed(taken)


func regrow_due(day: int, occupied: Callable, out_matured: PackedInt32Array) -> int:
	"""The day's sweep: every emptied row whose 48 days are up and whose spot nobody occupies is
	restored by the store (`regrow`). Appends each matured tree to `out_matured`; returns how many
	were held back by an occupied spot."""
	var held: int = 0
	for t: int in _count:
		var slot: int = node_slot[t]
		if slot == NO_SLOT or not nodes.is_exhausted(slot):
			continue
		if not nodes.is_regrow_ready_into(slot, day, _read) or _read.value != 1:
			continue
		if bool(occupied.call(at[t])):
			held += 1
			continue
		if nodes.regrow(slot, day).ok:
			stump[t] = 0
			out_matured.append(t)
			revision += 1
	return held


func growth_permille(t: int, day: int, hour: int) -> int:
	"""How far a young tree or a stump's regrowth has come, 0..1000 (presentation): days since its
	cycle began, with the hour, over the store's regrowth period. 1000 when mature, 0 when cleared."""
	var state: int = state_of(t)
	if state == STATE_MATURE:
		return 1000
	if state == STATE_CLEARED:
		return 0
	var planted: IntMath.IntResult = nodes.planted_day_of(node_slot[t])
	var since: int = (day - planted.value) * 24 + hour if planted.ok else 0
	return clampi(since * 1000 / (Rules.REGROW_DAYS * 24), 0, 999)


func days_left(t: int, day: int) -> int:
	"""Days until an emptied row regrows (0 when mature or cleared)."""
	var slot: int = node_slot[t] if is_tree(t) else NO_SLOT
	if slot == NO_SLOT or not nodes.regrow_ready_day_into(slot, _read):
		return 0
	return maxi(_read.value - day, 0)


func stump_age_days(t: int, day: int) -> int:
	"""Days since tree `t`'s stump was dated (0 without one)."""
	if state_of(t) != STATE_STUMP:
		return 0
	var dated: IntMath.IntResult = nodes.planted_day_of(node_slot[t])
	return maxi(day - dated.value, 0) if dated.ok else 0


func counts_into(out: PackedInt32Array) -> void:
	"""Trees by STATE_* into `out` (4 entries), and lying trunks' wood in out[4] (milli)."""
	out.resize(5)
	out.fill(0)
	for t: int in _count:
		out[state_of(t)] += 1
		out[4] += trunk_milli[t]


func nearest_into(point: Vector2, reach_m: float, want_state: int, out: IntMath.IntResult) -> bool:
	"""The tree in `want_state` (-1: any) nearest `point` within `reach_m`, into `out`."""
	var best: float = reach_m * reach_m
	var found: bool = false
	for t: int in _count:
		if want_state >= 0 and state_of(t) != want_state:
			continue
		var d: float = at[t].distance_squared_to(point)
		if d <= best:
			best = d
			found = out.succeed(t)
	return found or out.refuse(REFUSE_NOT_A_TREE)


func label_of(t: int) -> String:
	"""What stands there, in words: "Oak", "Beech stump", "Young oak", "Cleared spot"."""
	match state_of(t):
		STATE_MATURE:
			return LOOK_NAMES[look[t]]
		STATE_STUMP:
			return "%s stump" % LOOK_NAMES[look[t]]
		STATE_YOUNG:
			return "Young %s" % LOOK_NAMES[look[t]].to_lower()
	return "Cleared spot"
