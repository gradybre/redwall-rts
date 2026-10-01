extends RefCounted
## BASKET HAULING: where each mouth's spoil is on its way to its heap. Decision 0211 (the underground revamp's P5;
## design docs/design/underground_revamp.md §4 "Staged construction visuals": "A helper hauls it and the heap grows on
## dump; the ledger still posts at the cut, as in `spoil_into`"). Presentation only.
##
## THE LEDGER IS UNTOUCHED. A mouth's heap has received what its digs have cut (underground_graph.gd `heaped_milli`,
## posted at the cut, milli-U). Here that spoil is only LOCATED, three ways, in integers:
##   PILE      behind the face, cut and waiting for a basket     = heaped - carried - dumped
##   CARRIED   in the baskets of haulers bound for the mouth     (the sum of their baskets)
##   DUMPED    tipped on the heap -- what the heap is DRAWN at    (and all the farm may take from it)
## so PILE + CARRIED + DUMPED == HEAPED for every mouth, at every moment, and each is never below 0 (the conservation
## the tests check). A mouth nobody is hauling for has nothing in a pile or a basket: its heap is drawn at all it has
## received, as before P5 -- a dig without a crew below heaps its spoil at once, and hauling never changes a dig's time.
##
## A HAULER (a dig crew's member at its post below, tunnel_crew_task.gd) JOINS its dig's spoil mouth, FILLS its basket
## from the pile (the whole pile: one basketful of however much is waiting), carries it out and DUMPS it on the heap,
## and LEAVES when its place on the crew ends -- whatever its basket holds is tipped on the heap then (a hauler called
## away drops its load there), and the last hauler to leave a mouth takes its pile with it. A hauler whose walk out was
## given up RETURNS its basket to the pile instead (`return_basket`; decision 0361): nothing is tipped from afar. A
## mouth row freed or reused starts clean.
##
## Per resident it also keeps what the drawing needs (haul_view.gd): its STAGE and how far through the fill it is.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const STAGE_NONE: int = 0
const STAGE_FILLING: int = 1
const STAGE_CARRYING: int = 2
const STAGE_TIPPING: int = 3

## Per mouth row: what is tipped on its heap and what is in baskets bound for it (milli-U); how many haulers work for
## it; the mouth generation these were counted for.
var dumped_milli: PackedInt64Array = PackedInt64Array()
var carried_milli: PackedInt64Array = PackedInt64Array()
var haulers: PackedInt32Array = PackedInt32Array()
var _gen: PackedInt32Array = PackedInt32Array()
## Per resident: the mouth it hauls for (-1: none), its basket (milli-U), its stage and its fill (per mille).
var mouth_of: PackedInt32Array = PackedInt32Array()
var basket_milli: PackedInt64Array = PackedInt64Array()
var stage: PackedByteArray = PackedByteArray()
var fill_permille: PackedInt32Array = PackedInt32Array()
## Bumped whenever something is tipped (the heap's drawing redraws).
var revision: int = 0


func _init() -> void:
	"""Every mouth row clean."""
	dumped_milli.resize(Rules.MAX_MOUTHS)
	carried_milli.resize(Rules.MAX_MOUTHS)
	haulers.resize(Rules.MAX_MOUTHS)
	_gen.resize(Rules.MAX_MOUTHS)
	_gen.fill(-1)


func _ensure(i: int) -> void:
	"""Resident `i`'s row (the columns grow to it)."""
	if mouth_of.size() > i:
		return
	var from := mouth_of.size()
	mouth_of.resize(i + 1)
	basket_milli.resize(i + 1)
	stage.resize(i + 1)
	fill_permille.resize(i + 1)
	for k in range(from, i + 1):
		mouth_of[k] = -1


func _sync(network: RefCounted, m: int) -> void:
	"""Mouth row `m` follows its generation: freed or reused, it starts clean (nobody's basket is bound for it)."""
	var gen: int = network.mouth_gen[m]
	if _gen[m] == gen:
		return
	_gen[m] = gen
	dumped_milli[m] = 0
	carried_milli[m] = 0
	haulers[m] = 0
	for i in mouth_of.size():
		if mouth_of[i] == m:
			_forget(i)


func _forget(i: int) -> void:
	"""Resident `i` hauls for nobody, its basket empty."""
	mouth_of[i] = -1
	basket_milli[i] = 0
	stage[i] = STAGE_NONE
	fill_permille[i] = 0


# --- the three places -------------------------------------------------------------------------

func pile_milli(network: RefCounted, m: int) -> int:
	"""Mouth `m`'s spoil cut and waiting behind the face for a basket (0 when nobody hauls for it)."""
	return network.heaped_milli(m) - carried(network, m) - on_heap_milli(network, m)


func carried(network: RefCounted, m: int) -> int:
	"""Mouth `m`'s spoil in baskets on the way."""
	_sync(network, m)
	return carried_milli[m]


func on_heap_milli(network: RefCounted, m: int) -> int:
	"""Mouth `m`'s spoil tipped on its heap: what the heap is drawn at. With nobody hauling for it, everything it has
	received (see THE LEDGER IS UNTOUCHED) -- none is carried then: the last hauler to leave tips its basket."""
	_sync(network, m)
	if haulers[m] == 0:
		dumped_milli[m] = network.heaped_milli(m)
	return dumped_milli[m]


# --- a hauler's round ---------------------------------------------------------------------------

func join(network: RefCounted, i: int, m: int) -> void:
	"""Resident `i` hauls for mouth `m` from now on (leaving any mouth it hauled for before)."""
	_ensure(i)
	if mouth_of[i] == m:
		return
	leave(network, i)
	on_heap_milli(network, m)
	mouth_of[i] = m
	haulers[m] += 1


func leave(network: RefCounted, i: int) -> void:
	"""Resident `i` hauls no more: its basket is tipped on the heap; the last hauler of a mouth takes its pile too."""
	if mouth_of.size() <= i or mouth_of[i] < 0:
		return
	var m := mouth_of[i]
	_sync(network, m)
	if mouth_of[i] != m:
		return
	tip(network, i)
	haulers[m] -= 1
	_forget(i)
	revision += 1


func fill(network: RefCounted, i: int) -> int:
	"""Resident `i` fills its basket with its mouth's whole pile; returns how much it took (milli-U; 0: nothing)."""
	if mouth_of.size() <= i or mouth_of[i] < 0:
		return 0
	var m := mouth_of[i]
	var took := pile_milli(network, m)
	if took <= 0:
		return 0
	basket_milli[i] += took
	carried_milli[m] += took
	return took


func tip(network: RefCounted, i: int) -> int:
	"""Resident `i` tips its basket on its mouth's heap; returns how much (milli-U)."""
	if mouth_of.size() <= i or mouth_of[i] < 0:
		return 0
	var m := mouth_of[i]
	_sync(network, m)
	var held := basket_milli[i]
	basket_milli[i] = 0
	carried_milli[m] -= held
	dumped_milli[m] += held
	if held > 0:
		revision += 1
	return held


func return_basket(network: RefCounted, i: int) -> int:
	"""Resident `i`'s basket goes back to its mouth's pile behind the face, never tipped: a haul whose walk out was given
	up delivers nothing from where it stands (decision 0361). Returns how much (milli-U)."""
	if mouth_of.size() <= i or mouth_of[i] < 0:
		return 0
	var m := mouth_of[i]
	_sync(network, m)
	if mouth_of[i] != m:
		return 0
	var held := basket_milli[i]
	basket_milli[i] = 0
	carried_milli[m] -= held
	return held


func set_stage(i: int, value: int, permille: int) -> void:
	"""What resident `i` is doing with its basket (STAGE_*), `permille` through a fill (for the drawing)."""
	_ensure(i)
	stage[i] = value
	fill_permille[i] = clampi(permille, 0, Rules.PERMILLE)


func basket_of(i: int) -> int:
	"""What resident `i`'s basket holds (milli-U)."""
	return basket_milli[i] if basket_milli.size() > i else 0


func stage_of(i: int) -> int:
	"""Resident `i`'s stage (STAGE_*)."""
	return stage[i] if stage.size() > i else STAGE_NONE
