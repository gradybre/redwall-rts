extends RefCounted
## A short line at each busy tunnel mouth. Decision 0196 (live demo). Presentation only.
##
## A MOUTH IS BUSY while someone is in its bore within HOLD_M of it (going down, or waiting below
## to come up), while someone stands on its hole, or while another walker holds its GRANT -- the
## right to step in, taken on the way to the hole and given up once that walker is HOLD_M down.
## A walker reaching JOIN_M from a busy mouth does not crowd it: it joins the mouth's queue and
## stands at its place in a line running out from the hole (QUEUE_FIRST_M, then QUEUE_GAP_M apart),
## facing it, and moves up as the line does. Only the walker at the head may take the grant, and
## only once the mouth is clear. A full queue (QUEUE_MAX) takes nobody more: the planner stops
## offering that way in (its wait is INF), and a walker who meets it plans a walk instead.
##
## THE LINE'S DIRECTION is chosen when a tunnel opens (`lay_out`): straight out of the mouth, away
## from the tunnel, or the first of LINE_TURNS that keeps every place clear of obstacles and inside
## the village.
##
## PLANNING: entering at a mouth costs WAIT_PER_QUEUED_M of walking for each walker in its queue
## (and for a held grant), so a crowded mouth loses to a walk it would otherwise beat.
##
## All demo values. Columns are sized once (2 x MAX_TUNNELS mouths); nothing allocates per frame.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const QUEUE_MAX: int = 4
const JOIN_M: float = 2.2
const HOLD_M: float = 1.2
const QUEUE_FIRST_M: float = 1.4
const QUEUE_GAP_M: float = 0.8
const WAIT_PER_QUEUED_M: float = 3.0
const LINE_TURNS: Array[float] = [0.0, 0.5236, -0.5236, 1.0472, -1.0472, 1.5708, -1.5708]
const MOUTHS: int = 2 * Rules.MAX_TUNNELS

## Per mouth (2 x slot + end): who is queued (QUEUE_MAX places, -1 empty), how many, who holds the
## grant (-1: nobody), and the line's unit direction.
var member: PackedInt32Array = PackedInt32Array()
var count: PackedInt32Array = PackedInt32Array()
var grant: PackedInt32Array = PackedInt32Array()
var line_dir: PackedVector2Array = PackedVector2Array()
var mouth_at: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	"""Size every column once; every mouth empty."""
	member.resize(MOUTHS * QUEUE_MAX)
	member.fill(-1)
	count.resize(MOUTHS)
	grant.resize(MOUTHS)
	grant.fill(-1)
	line_dir.resize(MOUTHS)
	mouth_at.resize(MOUTHS)


func lay_out(mouth: int, at: Vector2, outward: Vector2, clear_at: Callable) -> void:
	"""Place mouth `mouth`'s line: from `at`, along `outward` turned by the first of LINE_TURNS for
	which `clear_at(point) -> bool` holds at every place (straight out when none does)."""
	mouth_at[mouth] = at
	line_dir[mouth] = outward
	for turn in LINE_TURNS:
		var dir := outward.rotated(turn)
		var clear := true
		for k in QUEUE_MAX:
			if not bool(clear_at.call(at + dir * (QUEUE_FIRST_M + QUEUE_GAP_M * float(k)))):
				clear = false
				break
		if clear:
			line_dir[mouth] = dir
			return


func place(mouth: int, k: int) -> Vector2:
	"""Where the `k`-th in mouth `mouth`'s line stands."""
	return mouth_at[mouth] + line_dir[mouth] * (QUEUE_FIRST_M + QUEUE_GAP_M * float(k))


func position_of(mouth: int, index: int) -> int:
	"""Resident `index`'s place in mouth `mouth`'s line (0: the head), or the line's length when it is
	not in it."""
	for k in count[mouth]:
		if member[mouth * QUEUE_MAX + k] == index:
			return k
	return count[mouth]


func is_queued(mouth: int, index: int) -> bool:
	"""Whether resident `index` is in mouth `mouth`'s line."""
	return position_of(mouth, index) < count[mouth]


func join(mouth: int, index: int) -> bool:
	"""Put resident `index` at the back of mouth `mouth`'s line (already in it: kept where it is).
	False when the line is full."""
	if is_queued(mouth, index):
		return true
	if count[mouth] >= QUEUE_MAX:
		return false
	member[mouth * QUEUE_MAX + count[mouth]] = index
	count[mouth] += 1
	return true


func leave(index: int) -> void:
	"""Take resident `index` out of every line (the rest move up) and give up any grant it holds."""
	for mouth in MOUTHS:
		if grant[mouth] == index:
			grant[mouth] = -1
		var k := position_of(mouth, index)
		if k >= count[mouth]:
			continue
		for j in range(k, count[mouth] - 1):
			member[mouth * QUEUE_MAX + j] = member[mouth * QUEUE_MAX + j + 1]
		count[mouth] -= 1
		member[mouth * QUEUE_MAX + count[mouth]] = -1


func may_take(mouth: int, index: int, clear: bool) -> bool:
	"""Whether resident `index` may take mouth `mouth`'s grant now: the mouth `clear` (nobody in its
	bore near it or on its hole), nobody else holding the grant, and nobody ahead in its line."""
	if not clear or (grant[mouth] != -1 and grant[mouth] != index):
		return false
	return count[mouth] == 0 or member[mouth * QUEUE_MAX] == index


func take(mouth: int, index: int) -> void:
	"""Resident `index` takes mouth `mouth`'s grant and leaves its line."""
	leave(index)
	grant[mouth] = index


func release_grant(index: int) -> void:
	"""Resident `index` is far enough down (or gone another way): its grant is free."""
	for mouth in MOUTHS:
		if grant[mouth] == index:
			grant[mouth] = -1


func holds_grant(mouth: int, index: int) -> bool:
	"""Whether resident `index` holds mouth `mouth`'s grant."""
	return grant[mouth] == index


func wait_m(mouth: int) -> float:
	"""What entering at `mouth` costs a planner in waiting (INF when its line is full)."""
	if count[mouth] >= QUEUE_MAX:
		return INF
	var ahead := count[mouth] + (1 if grant[mouth] != -1 else 0)
	return WAIT_PER_QUEUED_M * float(ahead)


func clear_mouths_of(slot: int) -> void:
	"""Empty both of tunnel `slot`'s lines and grants (it closed: nobody waits for it)."""
	for end in 2:
		var mouth := 2 * slot + end
		for k in QUEUE_MAX:
			member[mouth * QUEUE_MAX + k] = -1
		count[mouth] = 0
		grant[mouth] = -1
