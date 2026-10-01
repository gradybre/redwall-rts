extends "res://demo/tunnel/tunnel_task.gd"
## A resident's place in a dig crew (tunnel_crew.gd). Decisions 0196 (live demo) and 0211 (the baskets). Presentation
## only.
##
## Every member first walks to its own spot beside the way in -- the dig's entrance, or the mouth the dig
## spoils at when it starts inside the network -- and works there as a hand while the Foremole digs an entry
## shaft. Once the Foremole is below, a member who fits goes down (through the network to where the segment
## it will stand in begins) and works CREW_GAP_M behind it along the piece (further back by its place in
## the crew), finishing what the Foremole cuts; as the dig goes on into the next segment of its piece, the
## member's place follows along the piece (underground_graph.gd `piece_locate_into`), so nobody jumps. A
## member who does not fit stays a surface hand. Either way it counts as at its post only once there
## (tunnel_crew.set_present). The place ends when the Foremole's work on the dig does (`active` answers
## false): a member below walks out to the nearest mouth, and everyone goes back to their routine. Its site
## is read from the crew each frame (tunnel_crew.gd `member_site`), so a crew moved on is followed -- and moved on HERE
## when the Foremole got there first (decision 0361, the review's F03): stepped before its crew, the Foremole opens a
## segment and starts the next of its piece in its own update, and the works move the crew only after every resident
## has stepped. A member whose crew's segment is open with its piece dug on beyond it resolves the piece's active
## segment itself and moves the crew there (`_site_now`), in either cast order, whatever the sub-steps.
##
## THE BASKETS (decision 0211; design §4 "Behind the face"). A member at its post below HAULS for the dig's spoil
## mouth (spoil_haul.gd): once a basketful (MIN_LOAD_MILLI) lies cut behind the face and nobody else of that mouth is
## filling, it FILLS its basket there for FILL_S (the hand clip), takes the whole pile, carries it out stooped (the
## carry clip; the bore's stoop) through the network to its heap, TIPS it there for TIP_S, and walks back down to
## its place. The heap grows by that load when it is tipped; the ledger posted it at the cut. Hauling is the
## finisher's own work, so a member out with its basket still counts as at its post: the crew's rate, and so every
## dig's time, is exactly as before. When the dig is done a member below takes what is left behind the face out in a
## last basket, and its place ends at the heap. Called away, it drops its load on the heap (spoil_haul.gd `leave`).
## ARRIVING IS EXPLICIT (decision 0361, the review's F05): it tips only once its walk out has ARRIVED at the tip spot
## (resident_brain.gd `arrived_near`) -- else it walks there again -- and a haul whose walk was given up returns its
## basket to the pile behind the face (`return_basket`) rather than tipping it from wherever it stopped.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const HaulScript := preload("res://demo/tunnel/spoil_haul.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const CREW_GAP_M: float = 0.9
## A member below never stands nearer the piece's start than this.
const MIN_ALONG_M: float = 0.5
const HAND_CLIP: StringName = &"collect_object"
const TIP_CLIP: StringName = &"pull_radish"
## A member this close to where its segment begins steps into it.
const ENTER_REACH_M: float = 0.35
## A basket goes out once this much lies behind the face (a quantum's spoil, 2 U: the farm's own basketful).
const MIN_LOAD_MILLI: int = 2000
## Filling a basket and tipping it take this long (demo seconds).
const FILL_S: float = 1.4
const TIP_S: float = 0.9
## A tipper stands this far out from the heap's finished rim (m).
const TIP_CLEAR_M: float = 0.45
## It tips only standing within this of its tip spot (m; the brain's crowded-site arrival is 0.35).
const TIP_REACH_M: float = 0.5
const HAUL_POST: int = 0
const HAUL_FILL: int = 1
const HAUL_OUT: int = 2
const HAUL_TIP: int = 3

var slot: int = 0
var haul_stage: int = HAUL_POST

var _crew: CrewScript = null
var _network: GraphScript = null
var _fits: bool = false
var _hand_spot: Vector2 = Vector2.ZERO
var _active: Callable = Callable()
var _along: Callable = Callable()
var _entered: bool = false
var _place: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _mouth: int = -1
var _timer: float = 0.0
## Set at each tip: walking back down from the heap it is still counted at its post (the dig's rate is unchanged by
## hauling). It is read only while the member is not in its place, which after its first way in only a tip causes.
var _returning: bool = false
## Where its basket is carried to and tipped (set as it sets off with it).
var _tip_at: Vector2 = Vector2.ZERO


func _init(crew: CrewScript, network: GraphScript, crew_slot: int, fits: bool, hand_spot: Vector2,
		active: Callable, along: Callable) -> void:
	"""A place on segment `crew_slot`'s crew for a member who `fits` its bore (or works from `hand_spot`).
	`active(slot) -> bool`: whether the Foremole's work goes on; `along(slot) -> float`: where it stands in
	the bore (0 while it works an entry shaft)."""
	_crew = crew
	_network = network
	slot = crew_slot
	_fits = fits
	_hand_spot = hand_spot
	_active = active
	_along = along


func site(_brain: RefCounted) -> Vector2:
	"""Its spot beside the way in."""
	return _hand_spot


func step(brain: RefCounted, delta: float) -> bool:
	"""Keep to its post while the Foremole works, hauling baskets (see the header). False when the work is over."""
	var member := brain as BrainScript
	var at := _site_now(member.index)
	if at >= 0:
		slot = at
	var active := at >= 0 and bool(_active.call(slot))
	if haul_stage != HAUL_POST:
		return _haul(member, delta, active)
	if not active:
		return _last_basket(member)
	var lead_m := float(_along.call(slot))
	if not _fits or (lead_m <= 0.0 and not member.underground and _network.piece_offset_m(slot) <= 0.0):
		_hand(member, delta)
		return true
	_locate(member, lead_m)
	var target := int(_place[0])
	if not _entered:
		_crew.set_present(member.index, _returning)
		_go_in(member, target)
		return true
	member.task_stand_in_bore(target, _place[1], true)
	member.task_play(member.dig_clip())
	_crew.set_present(member.index, true)
	_at_post(member, MIN_LOAD_MILLI)
	return true


func _site_now(who: int) -> int:
	"""The segment resident `who`'s crew works now (-1: none). Its crew's site -- moved on along the piece, with the
	whole crew, when that segment is open and the dig goes on in the next of the piece (see the header): the works'
	move, made before they see it."""
	var at := _crew.member_site[who]
	if at < 0 or bool(_active.call(at)) or not _network.is_open(at):
		return at
	var next := _network.next_in_piece(at)
	for k in Rules.MAX_SEGMENTS:
		if next < 0 or not _network.is_open(next):
			break
		next = _network.next_in_piece(next)
	if next < 0 or not bool(_active.call(next)):
		return at
	_crew.move_site(at, next)
	return next


func _hand(member: BrainScript, delta: float) -> void:
	"""Work as a surface hand at its spot, facing the way in."""
	member.task_face(_network.way_in_m(_network.piece[slot]), delta)
	member.task_play(HAND_CLIP)
	_crew.set_present(member.index, true)


func _locate(member: BrainScript, lead_m: float) -> void:
	"""Its place along the piece: CREW_GAP_M a place behind the Foremole, into _place (segment, along)."""
	var p := _network.piece[slot]
	var behind := CREW_GAP_M * float(_crew.member_rank[member.index] + 1)
	var along := maxf(_network.piece_offset_m(slot) + lead_m - behind, MIN_ALONG_M)
	_network.piece_locate_into(p, along, _place)


func _go_in(member: BrainScript, target: int) -> void:
	"""Down to its place: to where segment `target` begins (through the network, when that is below), then
	in along it."""
	var entry := _network.node_a[target]
	if member.position.distance_to(_network.node_m(entry)) > ENTER_REACH_M:
		member.task_walk_to_node(entry)
		return
	_entered = true
	member.task_enter_bore(target, 0.0, _place[1])


# --- the baskets (see THE BASKETS) ------------------------------------------------------------------

func _at_post(member: BrainScript, least_milli: int) -> bool:
	"""At its post below: haul for the dig's spoil mouth, and start filling a basket when at least `least_milli` lies
	behind the face and nobody else of that mouth is filling. True when it started."""
	var m: int = _network.spoil_mouth[slot]
	if m < 0 or not _network.is_mouth(m):
		return false
	var haul: HaulScript = _network.haul
	haul.join(_network, member.index, m)
	_mouth = m
	if haul.pile_milli(_network, m) < least_milli or _someone_filling(haul, member.index, m):
		return false
	haul_stage = HAUL_FILL
	_timer = 0.0
	haul.set_stage(member.index, HaulScript.STAGE_FILLING, 0)
	return true


static func _someone_filling(haul: HaulScript, me: int, m: int) -> bool:
	"""Whether a hauler of mouth `m` other than `me` is filling its basket."""
	for i in haul.mouth_of.size():
		if i != me and haul.mouth_of[i] == m and haul.stage[i] == HaulScript.STAGE_FILLING:
			return true
	return false


func _last_basket(member: BrainScript) -> bool:
	"""The dig is done: a member at its post below takes whatever is left behind the face out in one last basket; else
	its place ends."""
	if not _entered or not member.underground or _mouth < 0:
		return false
	return _at_post(member, 1)


func _haul(member: BrainScript, delta: float, active: bool) -> bool:
	"""One frame of a basket's round (see THE BASKETS); false when the last basket is tipped."""
	var haul: HaulScript = _network.haul
	_crew.set_present(member.index, true)
	if not _network.is_mouth(_mouth):
		haul.set_stage(member.index, HaulScript.STAGE_NONE, 0)
		haul_stage = HAUL_POST
		_entered = false
		return true
	if haul_stage == HAUL_FILL:
		_fill(member, haul, delta)
	elif haul_stage == HAUL_OUT:
		_reach_tip(member, haul)
	elif haul_stage == HAUL_TIP:
		return _tip(member, haul, delta, active)
	return true


func _fill(member: BrainScript, haul: HaulScript, delta: float) -> void:
	"""Fill the basket at its post for FILL_S, then take the pile and set off with it for the heap (back to its post
	when there is no way out, or nothing to take)."""
	member.task_play(HAND_CLIP)
	_timer += delta
	haul.set_stage(member.index, HaulScript.STAGE_FILLING, int(_timer / FILL_S * float(Rules.PERMILLE)))
	if _timer < FILL_S:
		return
	_tip_at = tip_spot(member)
	if haul.pile_milli(_network, _mouth) <= 0 or not member.task_haul_out(_mouth, _tip_at):
		haul.set_stage(member.index, HaulScript.STAGE_NONE, 0)
		haul_stage = HAUL_POST
		return
	haul.fill(_network, member.index)
	haul.set_stage(member.index, HaulScript.STAGE_CARRYING, Rules.PERMILLE)
	haul_stage = HAUL_OUT


func _reach_tip(member: BrainScript, haul: HaulScript) -> void:
	"""Carried out: start tipping only standing at the tip spot (see ARRIVING IS EXPLICIT), else walk there again."""
	if not member.arrived_near(_tip_at, TIP_REACH_M):
		member.task_walk_to(_tip_at)
		return
	haul_stage = HAUL_TIP
	_timer = 0.0
	haul.set_stage(member.index, HaulScript.STAGE_TIPPING, 0)


func _tip(member: BrainScript, haul: HaulScript, delta: float, active: bool) -> bool:
	"""At the heap: tip the basket for TIP_S, then back down to its place -- or, the dig done, its place ends here."""
	var m := _mouth
	member.task_face(heap_centre(m), delta)
	member.task_play(TIP_CLIP if member.has_clip(TIP_CLIP) else HAND_CLIP)
	_timer += delta
	haul.set_stage(member.index, HaulScript.STAGE_TIPPING, int(_timer / TIP_S * float(Rules.PERMILLE)))
	if _timer < TIP_S:
		return true
	haul.tip(_network, member.index)
	haul.set_stage(member.index, HaulScript.STAGE_NONE, 0)
	haul_stage = HAUL_POST
	_entered = false
	_returning = active
	return active


func tip_spot(member: BrainScript) -> Vector2:
	"""Where the hauler stands to tip at its mouth's heap: TIP_CLEAR_M off the heap's finished rim, on the side away
	from the mouth's ramp, else beside it, else straight out -- the first clear of obstacles."""
	var m := _mouth
	var heap := heap_centre(m)
	var reach: float = _network.heap_radius_m[m] + TIP_CLEAR_M
	var from_mouth := (heap - _network.mouth_at(m)).normalized()
	var side := Vector2(-from_mouth.y, from_mouth.x)
	if side.dot(-_network.mouth_inward(m)) < 0.0:
		side = -side
	for way: Vector2 in [side, -side, from_mouth]:
		var at := heap + way * reach
		if member.space().obstacle_clearance(at) > member.radius:
			return at
	return heap + side * reach


func heap_centre(m: int) -> Vector2:
	"""Where mouth `m`'s heap stands (tunnel_heaps.gd placed it when the dig was accepted); a mouth with none placed,
	a metre and a half out of it."""
	if _network.heap_radius_m[m] > 0.0:
		return _network.heap_at[m]
	return _network.mouth_at(m) - _network.mouth_inward(m) * 1.5


func finish(brain: RefCounted) -> void:
	"""The work is over: off the crew, its basket tipped."""
	_off((brain as BrainScript).index)


func cancel(brain: RefCounted) -> void:
	"""Called away: off the crew, its load dropped on the heap -- or, its walk out given up, returned to the pile (see
	ARRIVING IS EXPLICIT)."""
	var member := brain as BrainScript
	if member.trip_failed() and haul_stage == HAUL_OUT:
		_network.haul.return_basket(_network, member.index)
	_off(member.index)


func _off(who: int) -> void:
	"""Leave the crew and the hauling."""
	_crew.leave(who)
	_network.haul.leave(_network, who)


func label() -> String:
	"""What the panel says."""
	if haul_stage == HAUL_FILL:
		return "Dig crew — filling a basket"
	if haul_stage != HAUL_POST:
		return "Dig crew — carrying spoil to the heap"
	return "Dig crew" if _fits else "Dig crew — surface hand"
