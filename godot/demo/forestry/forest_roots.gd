extends RefCounted
## The mature trees' root mounds. Decision 0196 (live demo). Presentation only; pure and static.
##
## The staged oak and beech (world/world_sizes.gd: 13 m and 15 m) stand on wide mossy root mounds --
## the oak's rises to ~1.4 m at 2 m from its trunk and runs out at 4.5 m, the beech's to ~0.6 m and
## 3 m -- far wider than the trunk circle the cast walks round (world_layout.gd TRUNK_RADIUS_M). A
## resident stepping in to fell one would stand inside the mound. So:
##   * a walker on the surface over a mound is lifted onto it (`height_at`, forest_lift.gd), from the
##     profile below -- every resident, not only the woods' crew;
##   * a feller stands on the mound where it can reach the trunk's flare (`stand_m`);
##   * a felled tree's cut is made above its mound (`cut_m`), where forest_split.gd splits the model.
## The profiles were MEASURED from the staged L0s with a one-off script (the median vertex height in
## half-metre rings, at the models' demo heights, 2026-09-29), at size 1.0; a placement's size scales
## them. Demo values, like the heights they were measured at.

const StandScript := preload("res://demo/forestry/forest_stand.gd")

## Mound height (m) at each RING_M step out from the trunk's centre, per StandScript.LOOK_*.
const RING_M: float = 0.5
const PROFILE_M: Array[Array] = [
	[2.0, 2.0, 2.0, 2.0, 1.4, 1.19, 1.07, 0.59, 0.08, 0.0],
	[0.9, 0.9, 0.61, 0.54, 0.4, 0.36, 0.02, 0.0],
]
## Where a feller stands (m from the centre) and the cut (m above the ground), per look.
const STAND_M: PackedFloat32Array = [3.0, 1.45]
const CUT_M: PackedFloat32Array = [2.3, 0.95]
## The trunk's radius at the cut (m), which the fresh stump is scaled to cover.
const CUT_RADIUS_M: PackedFloat32Array = [1.25, 0.6]
## A felled trunk lies beyond the mound, this long (the felled_trunk prop's drawn length, demo_props.gd).
const TRUNK_LENGTH_M: float = 5.5


static func height_at(look: int, size: float, distance_m: float) -> float:
	"""The mound's surface this far from a tree's centre (0 beyond it), linearly between rings."""
	var profile: Array = PROFILE_M[look]
	var r: float = distance_m / maxf(size, 0.01) / RING_M
	if r >= float(profile.size() - 1):
		return 0.0
	var k: int = int(r)
	return lerpf(float(profile[k]), float(profile[k + 1]), r - float(k)) * size


static func reach_m(look: int, size: float) -> float:
	"""How far out the mound runs."""
	return float((PROFILE_M[look] as Array).size() - 1) * RING_M * size


static func stand_m(look: int, size: float) -> float:
	"""Where a feller stands, from the tree's centre."""
	return STAND_M[look] * size


static func cut_m(look: int, size: float) -> float:
	"""How high the felling cut is made."""
	return CUT_M[look] * size


static func cut_radius_m(look: int, size: float) -> float:
	"""The trunk's radius at the cut."""
	return CUT_RADIUS_M[look] * size


static func trunk_start_m(look: int, size: float) -> float:
	"""How far out from the stump a felled trunk's near end lies: where the mound runs out."""
	return reach_m(look, size)


static func trunk_middle(stand: StandScript, t: int) -> Vector2:
	"""The middle of tree `t`'s felled trunk, on the ground along its fall."""
	var out: float = trunk_start_m(stand.look[t], stand.size[t]) + TRUNK_LENGTH_M * 0.5
	return stand.at[t] + stand.fall_dir[t] * out
