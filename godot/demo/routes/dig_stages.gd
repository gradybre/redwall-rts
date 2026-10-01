extends RefCounted
## A larger dig read as USEFUL STAGES (review ECO-045): spur -> junction -> connection. Decision 0461. A piece of the
## network (underground_graph.gd PIECES) is dug segment by segment from its start; this reads, from the graph alone,
## which points along it are worth reaching and how far the digging has got. Presentation only.
##
## MILESTONES are the nodes along the piece, in dig order, where its dug part becomes useful:
##   JUNCTION     a node where the piece meets another piece's dug segment -- a bore it crosses or joins on the way:
##                from there the dug part is part of the network, a second way in;
##   CONNECTION   the piece's last node, when it opens a mouth on the surface or joins the network there: a through
##                way at last;
##   SPUR         the piece's last node, when it ends anywhere else -- a room's door or socket, a blind end below
##                (decision 0212) -- a useful dead end: somewhere to go, not a way through.
## A milestone is REACHED when every segment from the piece's start to it is open (MOVE-REQ-002: unfinished space is
## no through route). Open segments past the last milestone reached are a DEAD-END HEADING: dug, walkable to the face,
## useful only for digging on -- told apart from a finished stage. The NEXT PAYOFF is the first milestone not reached:
## what it opens, and how much of the dig is left to it.

const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const JUNCTION: int = 0
const CONNECTION: int = 1
const SPUR: int = 2
const KIND_WORDS: Array[String] = ["junction", "connection", "spur"]
const GIVES: Array[String] = ["joins the network: a second way in", "a through way: open at both ends",
	"reaches its end: a place to go, not a way through"]

## The piece read, and its segments in dig order.
var piece: int = -1
var chain: PackedInt32Array = PackedInt32Array()
## Per milestone: its kind, its node, and how many chain segments lead to it (its segment index + 1).
var kinds: PackedInt32Array = PackedInt32Array()
var nodes: PackedInt32Array = PackedInt32Array()
var upto: PackedInt32Array = PackedInt32Array()
## How many leading chain segments are open; how many milestones that reaches; the open segments past the last
## reached milestone (a dead-end heading), and their length (m).
var open_prefix: int = 0
var reached: int = 0
var heading_segments: int = 0
var heading_m: float = 0.0


func read(graph: GraphScript, p: int) -> void:
	"""Read piece `p` (see the header)."""
	piece = p
	graph.piece_segments_into(p, chain)
	kinds.clear()
	nodes.clear()
	upto.clear()
	for k: int in chain.size():
		var end: int = graph.node_b[chain[k]]
		var last: bool = k == chain.size() - 1
		if last:
			_add(CONNECTION if graph.node_mouth[end] >= 0 or joins_network(graph, end, p) else SPUR, end, k + 1)
		elif joins_network(graph, end, p):
			_add(JUNCTION, end, k + 1)
	_read_progress(graph)


func _add(kind: int, node: int, segments: int) -> void:
	"""One milestone."""
	kinds.append(kind)
	nodes.append(node)
	upto.append(segments)


func _read_progress(graph: GraphScript) -> void:
	"""How far the digging has got: the open prefix, the milestones it reaches and the heading past them."""
	open_prefix = 0
	while open_prefix < chain.size() and graph.is_open(chain[open_prefix]):
		open_prefix += 1
	reached = 0
	while reached < upto.size() and upto[reached] <= open_prefix:
		reached += 1
	var stage_end: int = upto[reached - 1] if reached > 0 else 0
	heading_segments = open_prefix - stage_end
	heading_m = 0.0
	for k: int in range(stage_end, open_prefix):
		heading_m += graph.length_m(chain[k])


static func joins_network(graph: GraphScript, node: int, p: int) -> bool:
	"""Whether `node` meets a dug segment of another piece (see MILESTONES)."""
	for k: int in GraphScript.DEGREE:
		var slot: int = graph.node_segment(node, k)
		if slot >= 0 and graph.piece[slot] != p and graph.is_open(slot):
			return true
	return false


func count() -> int:
	"""How many milestones the piece has."""
	return kinds.size()


func is_finished() -> bool:
	"""Whether every milestone is reached (the whole piece is open)."""
	return reached >= kinds.size()


func next_milestone() -> int:
	"""The first milestone not reached (-1: none left)."""
	return reached if reached < kinds.size() else -1


func percent_to_next(graph: GraphScript) -> int:
	"""How much of the dig from the last milestone reached to the next is done, whole per cent (100 with none left):
	ticks dug over ticks in those segments."""
	var next: int = next_milestone()
	if next < 0:
		return 100
	var from: int = upto[reached - 1] if reached > 0 else 0
	var dug: int = 0
	var total: int = 0
	for k: int in range(from, upto[next]):
		dug += graph.done(chain[k])
		total += graph.total_ticks(chain[k])
	return dug * 100 / maxi(total, 1)


func stage_line(k: int) -> String:
	"""Milestone `k` in words: "Stage 1 of 3: junction — done"."""
	var state: String = "done" if k < reached else ("next" if k == reached else "later")
	return "Stage %d of %d: %s — %s" % [k + 1, kinds.size(), KIND_WORDS[kinds[k]], state]


func heading_line() -> String:
	"""The dead-end heading in words ("" with none): dug past the last stage, not yet useful."""
	if heading_segments <= 0:
		return ""
	return "Dead-end heading: %.1f m dug past the last stage — useful only to dig on" % heading_m
