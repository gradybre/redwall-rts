extends RefCounted
## Where the kitchen's work is done, in the village (world/world_layout.gd) or a test's hand-made one. Decision 0381.
## Presentation only.
##
##   the cauldron   the kitchen's outdoor hearth before the kitchen building (13.5, -6): where the cook puts the food
##                  down, cooks and the steam rises (the `cauldron` prop, 8.9, -3.9)
##   the table      the hall's east table (`table_e`, 5, -7): where the cook puts the portions out
##   the seats      SEATS_PER_TABLE spots round each of the hall's two tables, where the diners gather (a diner
##                  with no seat left stands by the table)
##   the well       where water is drawn (the village well, the square)
##   the butt       the village's water butt, beside the well (the `bucket` prop, 2.35, 0.9): water is drawn "into the
##                  stores" (ruling 2) and taken from them by a batch, as its wood is (decision 0381)
## Each is a point and the spot a resident stands at to work it (`stand_*`), found once on rings round the point,
## clear of obstacles and reachable (cast_orders.gd `spot_ok`); a test may give the spots directly.

const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

const SEATS_PER_TABLE: int = 5
## The seats' ring round a table's centre, and the rings a spot is looked for on round a point (m).
const SEAT_RING_M: float = 1.6
const RING_GAP_M: float = 0.45
const RINGS: int = 5
const RING_SPOTS: int = 12
const BODY_M: float = 0.3
## The arc of a table's ring kept clear of seats, toward the cauldron (radians: 70 degrees).
const SERVING_GAP: float = 1.22

var cauldron: Vector2 = Vector2.ZERO
var stand_cauldron: Vector2 = Vector2.ZERO
var table: Vector2 = Vector2.ZERO
var stand_table: Vector2 = Vector2.ZERO
var well: Vector2 = Vector2.ZERO
var stand_well: Vector2 = Vector2.ZERO
var butt: Vector2 = Vector2.ZERO
var stand_butt: Vector2 = Vector2.ZERO
var seats: PackedVector2Array = PackedVector2Array()
## The table each seat faces.
var seat_face: PackedVector2Array = PackedVector2Array()


func set_points(p_cauldron: Vector2, p_table: Vector2, p_well: Vector2, p_butt: Vector2) -> void:
	"""The four places; their standing spots start beside them (a test's open ground: the table's on its side toward
	the cauldron, where no seat is), `find_spots` moves them clear."""
	cauldron = p_cauldron
	table = p_table
	well = p_well
	butt = p_butt
	stand_cauldron = p_cauldron
	stand_table = p_table + (p_cauldron - p_table).normalized() * SEAT_RING_M
	stand_well = p_well
	stand_butt = p_butt


func add_table_seats(centre: Vector2, count: int, ring_m: float = SEAT_RING_M) -> void:
	"""`count` seats round a table at `centre`, `ring_m` out, each facing it -- spread over the circle but for the side
	toward the cauldron, where the cook stands to put the pot down (SERVING_GAP)."""
	var toward: float = (cauldron - centre).angle()
	for k: int in count:
		var angle: float = toward + SERVING_GAP / 2.0 + (TAU - SERVING_GAP) * (float(k) + 0.5) / float(count)
		seats.append(centre + Vector2.from_angle(angle) * ring_m)
		seat_face.append(centre)


func find_spots(space: CastSpaceScript, bounds: Rect2, cauldron_poi: StringName, well_poi: StringName) -> void:
	"""Move every standing spot and seat to the nearest clear spot round its point reachable from the cauldron's work
	spot (left where it is when none is found): the cauldron's and the well's are the world's own work spots
	(`cauldron_poi`, `well_poi`) where it has them."""
	stand_cauldron = _poi_or(space, cauldron_poi, cauldron)
	stand_well = _poi_or(space, well_poi, well)
	var from: Vector2 = stand_cauldron
	if stand_cauldron == cauldron:
		stand_cauldron = spot_near(space, bounds, cauldron, cauldron, from)
	if stand_well == well:
		stand_well = spot_near(space, bounds, well, well, from)
	stand_table = spot_near(space, bounds, stand_table, stand_table, from)
	stand_butt = spot_near(space, bounds, butt, butt, from)
	for k: int in seats.size():
		seats[k] = spot_near(space, bounds, seats[k], seats[k], from)


static func _poi_or(space: CastSpaceScript, poi: StringName, fallback: Vector2) -> Vector2:
	"""A work spot's position in this world, or `fallback` when it has none of that name."""
	var k: int = space.poi_names.find(poi)
	return space.poi_position[k] if k >= 0 else fallback


static func spot_near(space: CastSpaceScript, bounds: Rect2, target: Vector2, fallback: Vector2,
		from: Vector2 = Vector2.INF, clear_of: Array[RefCounted] = []) -> Vector2:
	"""The clear, reachable spot nearest `target` on rings round it (`fallback` when no ring has one). Reachable from
	`from` (the square's middle when not given); with `clear_of` (brains), clear of every resident standing still
	but them too (a walk that failed among them tries a free spot)."""
	var reach: Vector2 = from if from.is_finite() else Vector2.ZERO
	var no_taken := PackedVector2Array()
	var members: Array[BrainScript] = []
	for brain: RefCounted in clear_of:
		members.append(brain as BrainScript)
	var avoid: PackedVector3Array = space.mouth_circles() if clear_of.is_empty() \
			else CastOrdersScript.standing_except(space, members)
	for ring: int in RINGS:
		var radius: float = RING_GAP_M * float(ring)
		for k: int in (1 if ring == 0 else RING_SPOTS):
			var spot: Vector2 = target + Vector2.from_angle(TAU * float(k) / float(RING_SPOTS)) * radius
			if CastOrdersScript.spot_ok(space, spot, BODY_M, bounds, avoid, no_taken, reach):
				return spot
	return fallback
