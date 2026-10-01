extends RefCounted
## The wood yard by the workbench: where logs are stacked, sawn and stacked again as planks, and where
## sapling baskets wait. Decision 0196 (live demo). Presentation only; pure and static.
##
## The village already has a log stack (world_layout.gd PROPS `log_stack`, beside the workbench); the
## yard sets the staged sawhorse, the plank stack, the chopping block (with its axe) and two sapling
## baskets round it, off the south road and the workbench's and log stack's work spots. Each piece is
## an obstacle circle the cast walks round (merged with the world's at build, demo_village.gd).
## Positions and the stock-log pile are demo values.

const Layout := preload("res://demo/world/world_layout.gd")

const LOG_STACK_ID: StringName = &"log_stack"
## [key, at, yaw (deg), obstacle radius (m)].
const PIECES: Array[Array] = [
	[&"sawhorse", Vector2(7.7, 16.3), 20.0, 0.75],
	[&"plank_stack", Vector2(10.3, 16.8), -8.0, 0.95],
	[&"chopping_block", Vector2(10.8, 19.3), 35.0, 0.6],
	[&"sapling_basket", Vector2(11.9, 14.3), 0.0, 0.35],
	[&"sapling_basket", Vector2(12.5, 14.9), 70.0, 0.35],
]
const SAWHORSE: int = 0
const PLANK_STACK: int = 1
const BASKETS: int = 3
## Beside the world's log stack (which stays as it is) a second woodpile -- the same log_stack model --
## stands as tall as the demo stores' wood: a sliver at a little, full at LOG_PILE_FULL_MILLI.
const LOG_PILE_AT: Vector2 = Vector2(6.1, 15.3)
const LOG_PILE_YAW_DEG: float = 80.0
const LOG_PILE_SIZE: float = 0.8
const LOG_PILE_RADIUS_M: float = 1.0
const LOG_PILE_FULL_MILLI: int = 80000
const LOG_PILE_MIN_SHARE: float = 0.12
## The plank stack is drawn this full at PLANK_STACK_FULL_MILLI and more (its height follows the stock).
const PLANK_STACK_FULL_MILLI: int = 20000
## How far from a piece's centre a worker first tries to stand (m).
const STAND_M: Array[float] = [1.25, 1.45, 1.0, 0.85, 0.85]


static func log_stack_at() -> Vector2:
	"""The world's log stack (world_layout.gd PROPS)."""
	for entry: Dictionary in Layout.PROPS:
		if entry["id"] == LOG_STACK_ID:
			return entry["at"]
	assert(false, "the woods need the log stack")
	return Vector2.ZERO


static func at(piece: int) -> Vector2:
	"""Where yard piece `piece` stands."""
	return (PIECES[piece] as Array)[1]


static func key(piece: int) -> StringName:
	"""Yard piece `piece`'s model key."""
	return (PIECES[piece] as Array)[0]


static func yaw(piece: int) -> float:
	"""Yard piece `piece`'s yaw (radians)."""
	return deg_to_rad(float((PIECES[piece] as Array)[2]))


static func obstacles() -> Array[Vector3]:
	"""Every yard piece and the log pile as circles in the world's published form (x, radius, z)."""
	var out: Array[Vector3] = []
	for piece: Array in PIECES:
		var centre: Vector2 = piece[1]
		out.append(Vector3(centre.x, float(piece[3]) + Layout.OBSTACLE_MARGIN_M, centre.y))
	out.append(Vector3(LOG_PILE_AT.x, LOG_PILE_RADIUS_M, LOG_PILE_AT.y))
	return out


static func log_pile_share(wood_milli: int) -> float:
	"""How tall the woodpile stands for this much wood (0 at none; presentation)."""
	if wood_milli <= 0:
		return 0.0
	return clampf(float(wood_milli) / float(LOG_PILE_FULL_MILLI), LOG_PILE_MIN_SHARE, 1.0)
