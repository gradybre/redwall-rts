extends RefCounted
## The mature trees' root mounds. Decision 0196 (live demo). Presentation only; pure and static.
##
## The staged oak and beech (world/world_sizes.gd: 13 m and 15 m) are modelled standing on wide mossy
## root mounds -- the oak's rises to ~1.4 m at 2 m from its trunk and runs out at 4.5 m, the beech's to
## ~0.6 m and 3 m. The world lets each staged tree down into the ground by its mound's shoulder
## (world_sizes.gd SINK_M: oak 1.2 m, beech 0.5 m), so its roots run into the ground rather than the
## tree sitting on a plinth; what stays above the ground is the trunk's flare and the roots. Every
## height here is above the ground AFTER that sink, and is 0 where the mound is buried:
##   * where a walker stands on a root is NOT read from here any more: the radial profile below is a
##     median of rings, and the staged roots are lobes (review F40). forest_root_field.gd bakes each
##     model's own support heightfield, read with the tree's yaw (decision 0301). The profile's length
##     still gives the root skirt's reach (`reach_m`), which bounds that field;
##   * a feller stands where it can reach the trunk's flare (`stand_m`);
##   * a felled tree's cut is made above its flare (`cut_m`, above the ground); forest_split.gd splits
##     the MODEL there, which it measures from the model's own base (`model_cut_m`);
##   * the felled trunk lies beyond the model's whole root skirt (`reach_m`, `trunk_start_m`).
## The profiles were MEASURED from the staged L0s with a one-off script (the median vertex height in
## half-metre rings, at the models' demo heights, 2026-09-29), at size 1.0 and above the model's own
## base; a placement's size scales them. Demo values, like the heights they were measured at.

const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")

## Mound height (m) above the MODEL's base at each RING_M step out from the trunk's centre, per
## StandScript.LOOK_* (measured before the sink; only its length is read now, as the reach).
const RING_M: float = 0.5
const PROFILE_M: Array[Array] = [
	[2.0, 2.0, 2.0, 2.0, 1.4, 1.19, 1.07, 0.59, 0.08, 0.0],
	[0.9, 0.9, 0.61, 0.54, 0.4, 0.36, 0.02, 0.0],
]
## Where a feller stands (m from the centre) and the cut (m above the MODEL's base), per look.
const STAND_M: PackedFloat32Array = [3.0, 1.45]
const CUT_M: PackedFloat32Array = [2.3, 0.95]
## The trunk's radius at the cut (m), which the fresh stump is scaled to cover.
const CUT_RADIUS_M: PackedFloat32Array = [1.25, 0.6]
## A felled trunk lies beyond the mound, this long (the felled_trunk prop's drawn length, demo_props.gd).
const TRUNK_LENGTH_M: float = 5.5


static func sink_m(look: int, size: float) -> float:
	"""How far the world lets a staged tree of this look down into the ground (world_sizes.gd SINK_M)."""
	return Sizes.sink_m(StandScript.LOOK_KEYS[look], size)


static func reach_m(look: int, size: float) -> float:
	"""How far out the model's root skirt runs (buried or not): nothing of the tree lies beyond it."""
	return float((PROFILE_M[look] as Array).size() - 1) * RING_M * size


static func stand_m(look: int, size: float) -> float:
	"""Where a feller stands, from the tree's centre."""
	return STAND_M[look] * size


static func cut_m(look: int, size: float) -> float:
	"""How high above the ground the felling cut is made (the sunk tree's cut)."""
	return (CUT_M[look] - sink_m(look, 1.0)) * size


static func model_cut_m(look: int, size: float) -> float:
	"""How high above the model's own base the cut is, at drawn scale: where forest_split.gd splits the
	model (divide by the model's scale for its own units). The sink moves the model, not the cut in it."""
	return CUT_M[look] * size


static func cut_radius_m(look: int, size: float) -> float:
	"""The trunk's radius at the cut."""
	return CUT_RADIUS_M[look] * size


static func trunk_start_m(look: int, size: float) -> float:
	"""How far out from the stump a felled trunk's near end lies: where the root skirt runs out, clear
	of every root that still stands above the ground."""
	return reach_m(look, size)


static func trunk_middle(stand: StandScript, t: int) -> Vector2:
	"""The middle of tree `t`'s felled trunk, on the ground along its fall."""
	var out: float = trunk_start_m(stand.look[t], stand.size[t]) + TRUNK_LENGTH_M * 0.5
	return stand.at[t] + stand.fall_dir[t] * out
