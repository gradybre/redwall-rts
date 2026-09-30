extends RefCounted
## The demo's render layers, and the one ground plane each view picks on. Decision 0206 (the underground
## revamp's P0; design docs/design/underground_revamp.md §5). Presentation only; pure and static.
##
## THE UNDERGROUND VIEW IS A LAYER CUTAWAY. Everything the demo draws sits on exactly one of four render
## layers, and the U view is nothing but the camera's `cull_mask` (tunnel_view.gd):
##
##   | Layer | Bit            | What                                                              |
##   |-------|----------------|-------------------------------------------------------------------|
##   | 1     | SURFACE        | the village: ground, buildings, trees, crops, water, residents up |
##   | 2     | SURFACE_MARKS  | labels and marks over the surface (Label3D, rings, plan ribbons)  |
##   | 3     | UNDERGROUND    | the cap, the bores, rooms, frames, lanterns, residents below      |
##   | 4     | UNDERGROUND_MARKS | marks and labels drawn in the U view (resident markers, rings) |
##
## A node never changes material, transparency or visibility when the view switches: nothing is faded,
## nothing is built. A resident moves between SURFACE and UNDERGROUND when it goes down or comes up (a
## layers write, no material), and every mark that shows in both views is a PAIR of nodes, one per view.
## A light's `layers` cull it with the camera too, so the sun (layer 1) is off in the U view -- no sun
## shadow pass there -- and the underground's fill light (layer 3) is off on the surface.
##
## PICKING. The surface view picks on the ground (y = 0); the U view on the level's FLOOR (the bores sit
## FLOOR_Y_M down). The cap is drawn at CAP_Y_M but samples everything it shows -- strata, voids, marks
## -- where the view ray meets the floor (underground_cap.gdshader), so what the player sees under the
## pointer IS the floor point the click lands on.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")

const SURFACE: int = 1
const SURFACE_MARKS: int = 2
const UNDERGROUND: int = 4
const UNDERGROUND_MARKS: int = 8
## What each view's camera draws.
const SURFACE_VIEW: int = SURFACE | SURFACE_MARKS
const UNDERGROUND_VIEW: int = UNDERGROUND | UNDERGROUND_MARKS
## Level 1's floor: the bore floor depth (tunnel_rules.gd BORE_FLOOR_DEPTH_M).
const FLOOR_Y_M: float = -Rules.BORE_FLOOR_DEPTH_M
## The cap: the section plane, at the crown (decision 0207; the design's -0.15 m for level 1) -- the
## widened bore's drawn crown (tunnel_rules.gd BORE_CROWNS_U), 0.1 m over the standard one's -- so the
## bores' walls rise to it under the cut and a stooped resident shows whole below it.
const CAP_Y_M: float = FLOOR_Y_M + float(Rules.BORE_CROWNS_U[Rules.BORE_WIDE]) / float(Rules.UNITS_PER_M)
## Marks in the U view float this far above the floor.
const MARK_LIFT_M: float = 0.035


static func view_mask(underground: bool) -> int:
	"""The camera's cull mask for the surface view or the U view."""
	return UNDERGROUND_VIEW if underground else SURFACE_VIEW


static func pick_y(underground: bool) -> float:
	"""The plane a view picks on: the ground, or the level's floor."""
	return FLOOR_Y_M if underground else 0.0


static func is_one_view(layers: int) -> bool:
	"""Whether a layer mask belongs to exactly one view (the rule every drawn node keeps)."""
	return (layers & SURFACE_VIEW != 0) != (layers & UNDERGROUND_VIEW != 0)


static func pick_ground(origin: Vector3, direction: Vector3, plane_y: float) -> Vector2:
	"""Where a unit camera ray meets the plane y = `plane_y`, as (x, z) metres; INF when it points level,
	up, or away from the plane."""
	var t: float = PickScript.ray_ground(origin, direction, plane_y)
	if t < 0.0:
		return Vector2.INF
	return Vector2(origin.x + direction.x * t, origin.z + direction.z * t)


static func floor_through(eye: Vector3, seen: Vector3, floor_y: float) -> Vector2:
	"""Where the line from `eye` through `seen` meets the floor, (x, z) -- what the cap shows at `seen`
	(underground_cap.gdshader does the same sum). `seen` must lie below the eye."""
	var drop: float = maxf(eye.y - seen.y, 1e-4)
	var reach: float = (eye.y - floor_y) / drop
	return Vector2(eye.x + (seen.x - eye.x) * reach, eye.z + (seen.z - eye.z) * reach)


static func set_layers(root: Node, mask: int, skip: Node = null) -> int:
	"""Put every VisualInstance3D at and under `root` (except `skip` and what it holds) on `mask`.
	Returns how many were set. Walks the tree: call it on a change (a resident going down, a room dug),
	never per frame."""
	if root == skip:
		return 0
	var count: int = 0
	var visual := root as VisualInstance3D
	if visual != null:
		visual.layers = mask
		count += 1
	for child: Node in root.get_children():
		count += set_layers(child, mask, skip)
	return count
