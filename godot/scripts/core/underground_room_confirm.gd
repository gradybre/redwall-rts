extends RefCounted
## Decision 1991 (slice C3; Brendan, P-1990-1 (b) "Keep the mole, build real"): CONFIRM ALL'S REAL ROUTE for one
## painted underground room. Its cells, type, level, origin and dug height (as the build panel judged and priced them)
## become a real reserved Room through RoomOrders' own admission (`confirm_room`: the room, one Site per cube, its
## geometry and its approach witness), and the room is ordered through the composer with the crew the player chose
## (P-1990-4 (a)); the room foreman then digs it, each phase paying when its work starts (BUILD-REQ-019: nothing is
## deducted here).
##
## THE WAY IN IS ONE SEAM (`WayIn`), which slice D2 fills: a confirmed connector's access endpoint, the retreat travel
## row, the approach's work location, rows and face, and the room's three containers. Until a level has one, the seam
## is the base class and every painted room is refused ROOM_DIG_NO_WAY_IN ("No way in: needs a way down to level N")
## before anything is admitted. The demo keeps decision 1912's proof-of-concept mole until D2 switches it over.
##
## Order of checks, so a refusal changes nothing: the crew (the composer's own check), then the way in and its access
## (one access until a per-access binding exists, P-1936-1 (a)), then RoomOrders' admission. Once the room is admitted the order cannot be refused by the crew or the way in; a parking
## or plan refused after admission leaves the room confirmed and undug, named, and `order_underground_room` may order
## it again (RoomOrders has no room removal before slice F).

const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const PITCH_U: int = 1024
const REFUSE_NO_WAY_IN: StringName = &"ROOM_DIG_NO_WAY_IN"
const REFUSE_SCOPE: StringName = &"ROOM_DIG_SCOPE"
const NO_WAY_IN_WORDS: String = "No way in: needs a way down to level %d"


class Painted extends RefCounted:
	## One painted room as the build panel confirmed it: its level, room type, the level's origin (datum x and z, the
	## level's floor y, in u), its 1 m cells as (x, z) pairs from that origin, the height it is dug to (DEC-054, read
	## where the panel prices it), and the crew the player named as resident (slot, generation) pairs (empty: the
	## first idle mole).
	var level: int = -1
	var room_type: int = -1
	var origin_u: Vector3i = Vector3i.ZERO
	var cells: PackedInt32Array = PackedInt32Array()
	var height_u: int = 0
	var crew: PackedInt32Array = PackedInt32Array()


class WayIn extends RefCounted:
	## THE SEAM SLICE D2 FILLS. Given a painted room's admission request (shape, level and height already set), set
	## its approach (access, work location, travel and work rows and revisions, content, target origin, face, yaw) and
	## the order's access, retreat row and containers, or refuse. This base class is the game before D2: no level has
	## a way in.
	func approach_into(_request: Approach.Request, _order: Composer.Order) -> StringName:
		"""No connector reaches any level yet (slice D): every painted room is refused, naming its level."""
		return REFUSE_NO_WAY_IN


class Result extends RefCounted:
	## The confirmed and ordered room, or the refusal; `admitted` says whether RoomOrders admitted the room (a refusal
	## after admission leaves it confirmed and undug).
	var code: StringName = &""
	var room: Vector2i = NULL_REF
	var admitted: bool = false


static func confirm(orders: Orders, runtime: Runtime, placements: RefCounted, way_in: WayIn, world: Vector2i,
		space_revision: int, painted: Painted) -> Result:
	"""Admit one painted room and order its dig (see the header)."""
	var result: Result = Result.new()
	var owners: Builder.Owners = runtime.bound_owners() if runtime != null else null
	if orders == null or owners == null or placements == null or painted == null:
		result.code = REFUSE_SCOPE
		return result
	result.code = Composer.crew_refusal(owners, painted.crew)
	var request: Approach.Request = _request(world, space_revision, painted)
	var order: Composer.Order = Composer.Order.new()
	if result.code == &"": result.code = way_in.approach_into(request, order) if way_in != null else REFUSE_NO_WAY_IN
	if result.code == &"": result.code = Composer.access_refusal(runtime, order)
	if result.code != &"": return result
	var made: Buildings.OpResult = orders.confirm_room(request)
	if not made.ok:
		result.code = made.error
		return result
	result.admitted = true
	result.room = made.ref
	order.room = made.ref
	order.crew = painted.crew
	result.code = Composer.order(runtime, placements, order)
	return result


static func _request(world: Vector2i, space_revision: int, painted: Painted) -> Approach.Request:
	"""RoomOrders' plan for the painted shape: exact cells on the 1 m grid, the panel's dug height, no approach yet."""
	var request: Approach.Request = Approach.Request.new()
	request.world = world
	request.space_revision = space_revision
	request.room_type = painted.room_type
	request.level = painted.level
	request.origin_u = painted.origin_u
	request.cell_size_u = PITCH_U
	request.height_u = painted.height_u
	request.cells = painted.cells
	return request


static func refusal_words(code: StringName, level: int) -> String:
	"""The player's words for the route's own refusal; any other code is returned as it is (its owner's words)."""
	return NO_WAY_IN_WORDS % level if code == REFUSE_NO_WAY_IN else String(code)
