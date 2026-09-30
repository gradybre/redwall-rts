extends "res://demo/tunnel/tunnel_task.gd"
## A resident's place in a dig crew (tunnel_crew.gd). Decision 0196 (live demo). Presentation only.
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
## is read from the crew each frame (tunnel_crew.gd `member_site`), so a crew moved on is followed.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

const CREW_GAP_M: float = 0.9
## A member below never stands nearer the piece's start than this.
const MIN_ALONG_M: float = 0.5
const HAND_CLIP: StringName = &"collect_object"
## A member this close to where its segment begins steps into it.
const ENTER_REACH_M: float = 0.35

var slot: int = 0

var _crew: CrewScript = null
var _network: GraphScript = null
var _fits: bool = false
var _hand_spot: Vector2 = Vector2.ZERO
var _active: Callable = Callable()
var _along: Callable = Callable()
var _entered: bool = false
var _place: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])


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
	"""Keep to its post while the Foremole works (see the header). False when the work is over."""
	var member := brain as BrainScript
	var at := _crew.member_site[member.index]
	if at >= 0:
		slot = at
	if at < 0 or not bool(_active.call(slot)):
		return false
	var lead_m := float(_along.call(slot))
	if not _fits or (lead_m <= 0.0 and not member.underground and _network.piece_offset_m(slot) <= 0.0):
		_hand(member, delta)
		return true
	_locate(member, lead_m)
	var target := int(_place[0])
	if not _entered:
		_crew.set_present(member.index, false)
		_go_in(member, target)
		return true
	member.task_stand_in_bore(target, _place[1], true)
	member.task_play(member.dig_clip())
	_crew.set_present(member.index, true)
	return true


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


func finish(brain: RefCounted) -> void:
	"""The work is over: off the crew."""
	_crew.leave((brain as BrainScript).index)


func cancel(brain: RefCounted) -> void:
	"""Called away: off the crew."""
	_crew.leave((brain as BrainScript).index)


func label() -> String:
	"""What the panel says."""
	return "Dig crew" if _fits else "Dig crew — surface hand"
