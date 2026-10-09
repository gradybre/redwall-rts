extends RefCounted
## ADR 1229: the derived geometry of the descent's treads in the Placement's source frame (ADR 1209). Nothing here is
## chosen; every value follows from the prefix artifact and the approved motions:
## - T_k is T0 translated by (0, -128k, -512k) (D1: T6 is the sill, its bearers cut to 64 u); T_k's top is
##   y = -128(k + 1) and its far edge z = -2560 - 512k; L0's top is y = 0 and its far edge z = -2048.
## - The stops on a deck sit 169 u (the descent's arrival and the half-turn's start), 310 u (the tread station,
##   ADR 1209 step 4) and 343 u (the half-turn's end and the ascent's start) behind its far edge.
## - T_k (k >= 1) is installed from the station on T_{k-1}. Its left bearer (part 7(k + 1) + 1: seven parts per
##   assembly from L0's 0, so the sill's deck is 49 and its left bearer 50) is
##   staged quarter-turned across T_{k-1}'s forward top edge: station-local [-256, 0, -310, 256, h, -182], h being the
##   bearer's height (128, the sill's 64). Turned as T0's part 8 is (turn 3), its translation is T0's
##   (2304, 320, -2816) moved by d - R(d) for the tread offset d = (0, -128k, -512k), R(x, z) = (z, -x): that is
##   (2304 + 512k, 320, -2816 - 512k); the sill's bearer, 64 u lower, rises by 64 less.
## Assembly a is L0 (0), T0 (1) or T_{a-1}.

const TREADS: int = 6
const L0_FAR_Z: int = -2048
const T0_FAR_Z: int = -2560
const RISE: int = 128
const RUN: int = 512
const ARRIVAL: int = 169
const STATION: int = 310
const ASCENT_START: int = 343
const PARTS_PER_TREAD: int = 7
const SILL_PARTS: int = 3
const SILL: int = 6
const BEARER_HALF_WIDTH: int = 256
const BEARER_DEPTH: int = 128
const BEARER_HEIGHT: int = 128
const SILL_BEARER_HEIGHT: int = 64
const T0_BEARER_PART: int = 8
const T0_TURN: int = 3
const T0_TRANSLATION: Vector3i = Vector3i(2304, 320, -2816)


static func is_tread(assembly: int) -> bool:
	"""T1-T6: assemblies 2-7."""
	return assembly >= 2 and assembly <= TREADS + 1


static func top_y(level: int) -> int:
	"""The walking surface of L0 (level -1) or T_level."""
	return 0 if level < 0 else -RISE * (level + 1)


static func far_z(level: int) -> int:
	"""The far (downhill) edge of L0 (level -1) or T_level."""
	return L0_FAR_Z if level < 0 else T0_FAR_Z - RUN * level


static func stop(level: int, behind: int) -> Vector3i:
	"""A stop on L0 (level -1) or T_level, `behind` u behind its far edge on the stair's centre line."""
	return Vector3i(0, top_y(level), far_z(level) + behind)


static func station_of(assembly: int) -> Vector3i:
	"""The handling and fitting station of a tread assembly: 310 u behind the far edge of the tread above it."""
	return stop(assembly - 2, STATION)


static func bearer_height(assembly: int) -> int:
	"""A tread bearer's height; the sill's is cut to 64 u (D1)."""
	return SILL_BEARER_HEIGHT if assembly == SILL + 1 else BEARER_HEIGHT


static func bearer_part(assembly: int) -> int:
	"""The staged left bearer of T_{assembly-1}: the assembly's first part (7 per assembly) plus one."""
	return PARTS_PER_TREAD * assembly + 1


static func bearer_translation(assembly: int) -> Vector3i:
	"""The staged bearer's translation after turn 3 (see the header)."""
	var k: int = assembly - 1
	var rise: int = 0 if k < SILL else BEARER_HEIGHT - SILL_BEARER_HEIGHT
	return T0_TRANSLATION + Vector3i(RUN * k, -rise, -RUN * k)


static func bearer_prism_into(assembly: int, root: Vector3i, out: PackedInt32Array) -> bool:
	"""The staged bearer's prism around the station root; false for a non-tread assembly or a mis-sized packet."""
	if not is_tread(assembly) or out.size() != 6: return false
	var low: Vector3i = root + Vector3i(-BEARER_HALF_WIDTH, 0, -STATION)
	var high: Vector3i = root + Vector3i(BEARER_HALF_WIDTH, bearer_height(assembly), BEARER_DEPTH - STATION)
	for axis: int in 3:
		out[axis] = low[axis]
		out[axis + 3] = high[axis]
	return true
