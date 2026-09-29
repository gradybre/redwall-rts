extends RefCounted
## Chambers dug off the demo's tunnels: burrow homes and root cellars. Decision 0196 (live demo).
## Presentation only: nothing here writes into the simulation -- the settlement's Beds stay the
## simulation's, and no food is stored or modelled here.
##
## ---------------------------------------------------------------------------------------
## A CHAMBER is a room CHAMBER_SIDE_Q x CHAMBER_SIDE_Q quanta across and one high (moles' height),
## dug beside a finished tunnel at a point along it, its centre OFFSET_M off the route to one side.
## It is a slot in fixed columns (MAX_CHAMBERS, sized once) referred to as (slot, generation). It is
## PLANNED when placed, and DONE when the mole has dug its quanta (tunnel_jobs.gd CHAMBER).
##
## WHERE ONE MAY GO (`refusal`): inside the village by half its size; clear of every building's
## footprint circle by its half-diagonal (no room under a house or the well); CHAMBER_GAP_M from
## every other chamber; MOUTH_GAP_M from every tunnel mouth; and not over another tunnel's route.
##
## BURROW HOME: BEDS_PER_HOME beds for moles. The figure is derived, not invented: the GDD's starter
## dormitory holds 12 beds in 40 tiles (§ interior fixture), so a 9 m^2 floor holds floor(9 x 12 / 40)
## = 2. They are DEMO beds, counted in the tunnel panel -- the HUD's Beds counter is the
## simulation's, which has no bed store yet, and the demo never writes into it.
##
## ROOT CELLAR: a cold store. CELLAR_SPOILAGE_PERMILLE is the GDD's cellar store factor (the spoil-
## age table's "open pile 1500, covered store 1000, pantry 750, cellar 350"), cited. Its capacity in
## U is a DEMO value: the GDD's cellar building holds 1,000,000 g over 6x6 tiles, by mass, and a dug
## root cellar's size in U is not specified.
##
## THE CELLAR API (for the farming demo, after merge): `cellars()` lists every DONE root cellar as
## {"id": Vector2i(slot, generation), "position": Vector3 (centre on the ground), "capacity_u": int,
## "spoilage_permille": int}; `cellar_count()` counts them; `revision` bumps on any change.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")

const KIND_NONE: int = 0
const KIND_HOME: int = 1
const KIND_CELLAR: int = 2
const KIND_NAMES: Array[String] = ["", "Burrow home", "Root cellar"]
const PHASE_FREE: int = 0
const PHASE_PLANNED: int = 1
const PHASE_DONE: int = 2

const MAX_CHAMBERS: int = 8
const CHAMBER_SIDE_Q: int = 3
const CHAMBER_SIDE_U: int = CHAMBER_SIDE_Q * Rules.QUANTUM_U
## The centre stands this far off the route (u): the room opens off the bore's side.
const OFFSET_U: int = 2048
const CHAMBER_GAP_U: int = 3584
const MOUTH_GAP_U: int = 2048
## The GDD starter dormitory: 12 beds in 40 tiles.
const DORMITORY_BEDS: int = 12
const DORMITORY_TILES: int = 40
const BEDS_PER_HOME: int = CHAMBER_SIDE_Q * CHAMBER_SIDE_Q * DORMITORY_BEDS / DORMITORY_TILES
const CELLAR_SPOILAGE_PERMILLE: int = 350
const CELLAR_CAPACITY_U: int = 60

const REFUSE_NONE: int = 0
const REFUSE_FULL: int = 1
const REFUSE_OUT_OF_BOUNDS: int = 2
const REFUSE_UNDER_BUILDING: int = 3
const REFUSE_NEAR_CHAMBER: int = 4
const REFUSE_NEAR_MOUTH: int = 5
const REFUSE_OVER_TUNNEL: int = 6
const REASONS: Array[String] = [
	"",
	"no more chambers can be dug in this demo (8 at most)",
	"that is too near the edge of the village",
	"a chamber cannot be dug under a building or the well",
	"that is too near another chamber",
	"that is too near a tunnel mouth",
	"that would cut into a tunnel",
]

var kind: PackedByteArray = PackedByteArray()
var phase: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var tunnel: PackedInt32Array = PackedInt32Array()
var along_u: PackedInt32Array = PackedInt32Array()
## (x, z) centre in u, per chamber.
var centre_u: PackedInt32Array = PackedInt32Array()
## Bumped on any change.
var revision: int = 0


func _init() -> void:
	"""Size every column once."""
	kind.resize(MAX_CHAMBERS)
	phase.resize(MAX_CHAMBERS)
	generation.resize(MAX_CHAMBERS)
	tunnel.resize(MAX_CHAMBERS)
	along_u.resize(MAX_CHAMBERS)
	centre_u.resize(2 * MAX_CHAMBERS)


static func reason_text(code: int) -> String:
	"""The words for a refusal (REFUSE_*)."""
	return REASONS[code]


static func centre_for(network: NetworkScript, slot: int, along: int, side: int) -> Vector2i:
	"""Where a chamber `along` u into tunnel `slot` stands, on `side` (+1 right, -1 left of the way to
	the exit), in u."""
	var at := network.point_at_u(slot, along)
	var ahead := network.point_at_u(slot, mini(along + Rules.QUANTUM_U, network.length_u[slot]))
	var behind := network.point_at_u(slot, maxi(along - Rules.QUANTUM_U, 0))
	var dx := ahead.x - behind.x
	var dz := ahead.y - behind.y
	var length := maxi(Rules.isqrt(dx * dx + dz * dz), 1)
	return Vector2i(at.x - dz * OFFSET_U * side / length, at.y + dx * OFFSET_U * side / length)


func refusal(network: NetworkScript, centre: Vector2i, bounds_u: Rect2i, under_u: PackedInt32Array) -> int:
	"""REFUSE_NONE, or why no chamber may be centred at `centre` (see WHERE ONE MAY GO)."""
	if not phase.has(PHASE_FREE):
		return REFUSE_FULL
	var half := CHAMBER_SIDE_U / 2
	if not bounds_u.grow(-half).has_point(centre):
		return REFUSE_OUT_OF_BOUNDS
	var diagonal := Rules.isqrt_ceil(2 * half * half)
	for i in under_u.size() / 3:
		if _closer(centre, Vector2i(under_u[3 * i], under_u[3 * i + 2]), under_u[3 * i + 1] + diagonal):
			return REFUSE_UNDER_BUILDING
	for c in MAX_CHAMBERS:
		if phase[c] != PHASE_FREE and _closer(centre, chamber_point_u(c), CHAMBER_GAP_U):
			return REFUSE_NEAR_CHAMBER
	return _tunnel_refusal(network, centre, half)


func _tunnel_refusal(network: NetworkScript, centre: Vector2i, half: int) -> int:
	"""REFUSE_NEAR_MOUTH, REFUSE_OVER_TUNNEL or REFUSE_NONE, from every planned tunnel."""
	var at := Vector2(Rules.to_m(centre.x), Rules.to_m(centre.y))
	for slot in Rules.MAX_TUNNELS:
		if network.phase[slot] == NetworkScript.PHASE_FREE:
			continue
		for end in 2:
			var mouth := network.mouth(slot, end == 1)
			if _closer(centre, Vector2i(Rules.to_u(mouth.x), Rules.to_u(mouth.y)), MOUTH_GAP_U):
				return REFUSE_NEAR_MOUTH
		if network.distance_to_route(slot, at) < Rules.to_m(half + Rules.BORE_WIDTH_U / 2) - 0.01:
			return REFUSE_OVER_TUNNEL
	return REFUSE_NONE


static func _closer(a: Vector2i, b: Vector2i, reach: int) -> bool:
	"""Whether a and b (u) are closer than `reach` (exact integers)."""
	var dx := a.x - b.x
	var dz := a.y - b.y
	return dx * dx + dz * dz < reach * reach


func add_into(chamber_kind: int, network: NetworkScript, slot: int, along: int, centre: Vector2i,
		out_ref: PackedInt32Array) -> bool:
	"""Plan a chamber of `chamber_kind` off tunnel `slot`, `along` u in, centred at `centre` (already
	checked by `refusal`); write its (slot, generation) into out_ref. False with no free slot."""
	var c := phase.find(PHASE_FREE)
	if c < 0 or chamber_kind == KIND_NONE:
		return false
	kind[c] = chamber_kind
	phase[c] = PHASE_PLANNED
	tunnel[c] = slot
	along_u[c] = along
	centre_u[2 * c] = centre.x
	centre_u[2 * c + 1] = centre.y
	revision += 1
	out_ref[0] = c
	out_ref[1] = generation[c]
	return true


func set_done(c: int) -> void:
	"""Chamber `c` is dug out."""
	phase[c] = PHASE_DONE
	revision += 1


func forget(c: int) -> void:
	"""Chamber `c` was never dug (its job was voided): free its slot and retire its generation."""
	kind[c] = KIND_NONE
	phase[c] = PHASE_FREE
	generation[c] += 1
	revision += 1


func chamber_point_u(c: int) -> Vector2i:
	"""Chamber `c`'s centre in u."""
	return Vector2i(centre_u[2 * c], centre_u[2 * c + 1])


func centre_m(c: int) -> Vector2:
	"""Chamber `c`'s centre in metres (x, z), for drawing."""
	return Vector2(Rules.to_m(centre_u[2 * c]), Rules.to_m(centre_u[2 * c + 1]))


func count_done(chamber_kind: int) -> int:
	"""How many chambers of this kind are dug out."""
	var n := 0
	for c in MAX_CHAMBERS:
		if phase[c] == PHASE_DONE and kind[c] == chamber_kind:
			n += 1
	return n


func beds() -> int:
	"""Demo beds for moles in every finished burrow home."""
	return count_done(KIND_HOME) * BEDS_PER_HOME


func cellar_count() -> int:
	"""How many root cellars are dug out."""
	return count_done(KIND_CELLAR)


func cellars() -> Array[Dictionary]:
	"""Every finished root cellar (see THE CELLAR API). Allocates; call on change, not per frame."""
	var out: Array[Dictionary] = []
	for c in MAX_CHAMBERS:
		if phase[c] != PHASE_DONE or kind[c] != KIND_CELLAR:
			continue
		var at := centre_m(c)
		out.append({"id": Vector2i(c, generation[c]), "position": Vector3(at.x, 0.0, at.y),
			"capacity_u": CELLAR_CAPACITY_U, "spoilage_permille": CELLAR_SPOILAGE_PERMILLE})
	return out


func housing_line() -> String:
	"""The panel's housing readout."""
	return "Burrow homes: %d (%d demo beds for moles) · Root cellars: %d" % [count_done(KIND_HOME), beds(),
		cellar_count()]
