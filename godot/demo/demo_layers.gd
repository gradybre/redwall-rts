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
##
## THE SECOND LEVEL (decision 0212, the revamp's P6). Level 2 has its own two layers, and the U view shows ONE
## level at a time (PgUp/PgDn, tunnel_view.gd):
##
##   | Layer | Bit                 | What                                                        |
##   |-------|---------------------|-------------------------------------------------------------|
##   | 5     | UNDERGROUND_2       | level 2's cap, bores, rooms, fixtures, marks' meshes, residents on it |
##   | 6     | UNDERGROUND_2_MARKS | what level 2's view draws over its cap                      |
##
## `below(level)` and `marks(level)` name a level's pair; `level_mask(level)` is what the U view draws on it --
## so switching the level is again one cull-mask write, and the other level's geometry is not drawn at all (no
## bleed-through; its outline is the cap's own, underground_cap.gd). A LINK between the levels is on both
## `below` layers, each copy drawn in its own level's material (bore_view.gd). What a whole-view mark follows
## (a selection ring, an order marker, a resident's marker) lies on both marks layers, at the floor of the level
## shown (`view_floor_y`); a resident's own marker shows in the views of the levels it is NOT on
## (`marker_mask`). `active_level` is the level the U view shows (tunnel_view.gd sets it).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")

const SURFACE: int = 1
const SURFACE_MARKS: int = 2
const UNDERGROUND: int = 4
const UNDERGROUND_MARKS: int = 8
const UNDERGROUND_2: int = 16
const UNDERGROUND_2_MARKS: int = 32
## Every level's underground layer, and every level's marks (a pooled light, a shared particle; a whole-view mark).
const BELOW_ALL: int = UNDERGROUND | UNDERGROUND_2
const MARKS_ALL: int = UNDERGROUND_MARKS | UNDERGROUND_2_MARKS
## What each view's camera draws (the U view: every level's layers, for the rule `is_one_view`; one level's at a
## time is `level_mask`).
const SURFACE_VIEW: int = SURFACE | SURFACE_MARKS
const UNDERGROUND_VIEW: int = BELOW_ALL | MARKS_ALL
## Level 1's floor: the bore floor depth (tunnel_rules.gd BORE_FLOOR_DEPTH_M).
const FLOOR_Y_M: float = -Rules.BORE_FLOOR_DEPTH_M
## The cap: the section plane, at the crown (decision 0207; the design's -0.15 m for level 1) -- the
## widened bore's drawn crown (tunnel_rules.gd BORE_CROWNS_U), 0.1 m over the standard one's -- so the
## bores' walls rise to it under the cut and a stooped resident shows whole below it.
const CAP_Y_M: float = FLOOR_Y_M + float(Rules.BORE_CROWNS_U[Rules.BORE_WIDE]) / float(Rules.UNITS_PER_M)
## Marks in the U view float this far above the floor.
const MARK_LIFT_M: float = 0.035

## The level the U view shows (see THE SECOND LEVEL): 1 or 2.
static var active_level: int = Rules.TOP_LEVEL


static func below(level: int) -> int:
	"""A level's underground layer (level 1's for anything but level 2)."""
	return UNDERGROUND_2 if level == Rules.LEVEL_2 else UNDERGROUND


static func marks(level: int) -> int:
	"""A level's marks layer (level 1's for anything but level 2)."""
	return UNDERGROUND_2_MARKS if level == Rules.LEVEL_2 else UNDERGROUND_MARKS


static func level_mask(level: int) -> int:
	"""What the U view draws while it shows `level`: that level's underground and marks layers."""
	return below(level) | marks(level)


static func floor_y(level: int) -> float:
	"""A level's floor height (m): level 1's -1.25, level 2's the candidate 4 m lower."""
	return Rules.level_floor_m(clampi(level, Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL))


static func cap_y(level: int) -> float:
	"""A level's section plane (m): its floor and the widened bore's crown, as CAP_Y_M is level 1's."""
	return floor_y(level) + (CAP_Y_M - FLOOR_Y_M)


static func view_floor_y() -> float:
	"""The floor of the level the U view shows (where whole-view marks lie)."""
	return floor_y(active_level)


static func level_at(y: float) -> int:
	"""The level a height below the ground belongs to: level 2 at or under the middle of the spacing between the two
	floors, else level 1 (a puff, a clod: which view draws it)."""
	return Rules.LEVEL_2 if y <= (floor_y(Rules.TOP_LEVEL) + floor_y(Rules.LEVEL_2)) * 0.5 else Rules.TOP_LEVEL


## A resident on a link's hidden middle -- under level 1's section, over level 2's -- is seen from neither level:
## its body is drawn on no layer, and its marker shows in both views (resident_brain.gd `view_level`).
const BETWEEN_LEVELS: int = 3


static func body_mask(level: int) -> int:
	"""The layer a resident's body is on where it stands: the surface's, or its level's underground (none between the
	levels)."""
	if level == BETWEEN_LEVELS:
		return 0
	return SURFACE if level <= Rules.LEVEL_SURFACE else below(level)


static func marker_mask(level: int) -> int:
	"""The marks layers a resident's U-view marker shows on: every level's while it is on the surface or between the
	levels, else the other levels' (see THE SECOND LEVEL)."""
	return MARKS_ALL & ~marks(level) if level > Rules.LEVEL_SURFACE and level != BETWEEN_LEVELS else MARKS_ALL


static func view_mask(underground: bool, level: int = Rules.TOP_LEVEL) -> int:
	"""The camera's cull mask for the surface view or the U view showing `level`."""
	return level_mask(level) if underground else SURFACE_VIEW


static func pick_y(underground: bool, level: int = Rules.TOP_LEVEL) -> float:
	"""The plane a view picks on: the ground, or the floor of the level the U view shows."""
	return floor_y(level) if underground else 0.0


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
