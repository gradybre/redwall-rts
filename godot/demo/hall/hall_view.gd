extends Node3D
## THE HALL AS IT GROWS, drawn (decision 0771). Presentation only: composed from the library's existing models -- no new
## art -- over the world's own hall (world_layout.gd BUILDINGS `hall`), which is never moved, scaled or replaced: tier 2
## adds no floor (GDD §5.9), so the hall keeps its footprint and the residents' obstacles do not change.
##
##   while the upgrade is DELIVERED  a site pile by the hall's east end grows with what has been set down there: a stone
##                                   heap (`rock_cluster`), a stack of timber (`log_stack`) and the cloth (`sack_pile`),
##                                   each sized by its share delivered;
##   while it is BUILT               a work rail of fence lengths (`fence`) stands before the front, timber stacked
##                                   (`plank_stack`) by it;
##   at tier 2 (the great hall)      THE STONE HALL (art pass 2, decision 0951): the world's staged `hall_stage2` --
##                                   the same hall rebuilt in sandstone, with its own second chimney and mullioned
##                                   windows -- shown in place of the timber `hall`, with the timber hall's own
##                                   transform and scale (demo_world.gd STAGES, `stage_node`); its windows glow with
##                                   the hall's lamp (night_lights.gd THE WINDOWS). Not staged (CI, a fresh clone): the
##                                   COMPOSED stand-in -- a second chimney on the east roof (the library's clay
##                                   `chimney_pot`, darkened: REQ-SET-136's stone and its fuel x0.75) and two woven
##                                   roundels hung in the outer bays (`rag_rug`: its cloth) on the timber hall;
##   each banner hung                a linen banner (`hall_banner`, hanging upright at its 1.6 m, demo_props.gd) in a
##                                   bay, its cloth (surface 0, never the wood of surface 1) dyed in the woodland
##                                   palette by a multiply on its own material (no new texture). Not staged: the older
##                                   `relic_banner` (or its placeholder) stood upright and scaled to the facade.
## Redrawn only when the projects change (`sync`); nothing per frame. Every placement is in the hall's own frame
## (x along its front, +z out of its front), so it follows the hall wherever the layout stands it.

const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const HALL_ID: StringName = &"hall"
const HALL_KEY: StringName = &"hall"
## The site pile (hall frame, metres): east of the hall, toward its front. Its pieces' biggest sizes.
const SITE_LOCAL: Vector2 = Vector2(7.0, 2.1)
const STONE_LOCAL: Vector2 = Vector2(6.7, 0.9)
const WOOD_LOCAL: Vector2 = Vector2(7.6, -0.6)
const CLOTH_LOCAL: Vector2 = Vector2(7.9, 1.2)
const PILE_MIN: float = 0.15
const STONE_SIZE: float = 0.8
const WOOD_SIZE: float = 0.75
const CLOTH_SIZE: float = 1.6
## The work rail along the front (x of each fence length), this far out of it, at this size; the timber stack by it.
const RAIL_X: PackedFloat32Array = [-4.2, -1.9, 1.9, 4.2]
const RAIL_OUT_M: float = 2.0
const RAIL_SIZE: float = 0.55
const TIMBER_LOCAL: Vector2 = Vector2(-6.9, 2.4)
## The great hall's second chimney (hall frame x, height, z) and scale; its roundels (x) and their height.
const CHIMNEY_LOCAL: Vector3 = Vector3(4.5, 4.6, -1.2)
## The pot is fired clay: darkened toward the hall's weathered stone so it does not glare against the roof.
const CHIMNEY_DYE: Color = Palette.FLINT
const CHIMNEY_SCALE: float = 4.0
const ROUNDEL_X: PackedFloat32Array = [-3.4, 3.4]
const HANGING_Y: float = 2.6
const ROUNDEL_OUT_M: float = 0.11
## The banners' bays (x, in hanging order), how far out of the facade they hang, their scale and their dyes.
const BANNER_X: PackedFloat32Array = [-1.15, 1.15, -5.0, 5.0]
const BANNER_OUT_M: float = 0.15
const BANNER_SCALE: float = 3.0
## The linen banner: its key (drawn at its own 1.6 m by demo_props.gd) and its stand-in's.
const BANNER_KEY: StringName = &"hall_banner"
const STAND_IN_BANNER_KEY: StringName = &"relic_banner"
const BANNER_DYES: Array[Color] = [Palette.CLAY, Palette.LEAF, Palette.BRASS, Palette.SAGE]
## Where each builder works (hall frame x along the front), standing this far out of it.
const UPGRADE_WORK_X: PackedFloat32Array = [-4.2, -1.4, 1.4, 4.2]
const WORK_OUT_M: float = 0.9

var _at: Vector2 = Vector2.ZERO
var _yaw: float = 0.0
var _rect: Rect2 = Rect2()
var _height: float = 0.0
var _stone: Node3D = null
var _wood: Node3D = null
var _cloth: Node3D = null
var _scaffold: Array[Node3D] = []
var _great: Array[Node3D] = []
var _banners: Array[Node3D] = []
var _seen: int = -1
## The world's timber hall and its stone stage 2 (null: not staged, or no world).
var _timber: Node3D = null
var _stone_hall: Node3D = null
## The model the banners are drawn with (BANNER_KEY, or the stand-in's).
var _banner_model: StringName = &""


func _init() -> void:
	"""The hall's frame, read from the authored layout (the same before or after the world is built)."""
	var hall: Dictionary = Layout.find_placement(Layout.placements(), HALL_ID)
	_at = hall.get("at", Vector2.ZERO)
	_yaw = float(hall.get("yaw", 0.0))
	_rect = Sizes.scaled_rect(HALL_KEY, float(hall.get("size", 1.0)))
	_height = Sizes.target_height_m(HALL_KEY)
	name = "HallView"


# --- the hall's frame -----------------------------------------------------------------------------------------------

func centre() -> Vector2:
	"""Where the hall stands (its middle, metres x z)."""
	return _at


func front_z() -> float:
	"""The hall's front, along its own +z (metres from its middle)."""
	return _rect.end.y


func to_world(local: Vector2) -> Vector2:
	"""A point in the hall's frame (x along its front, +z out of it) in the world's x z."""
	return _at + Layout.rotate_xz(local, _yaw)


func to_world_3d(local: Vector3) -> Vector3:
	"""The same, with a height."""
	var flat: Vector2 = to_world(Vector2(local.x, local.z))
	return Vector3(flat.x, local.y, flat.y)


func bounds() -> AABB:
	"""The hall's box in the world (its footprint turned by its yaw, ground to roof): what a click on it hits."""
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: Vector2 in [_rect.position, Vector2(_rect.end.x, _rect.position.y), _rect.end,
			Vector2(_rect.position.x, _rect.end.y)]:
		var w: Vector2 = to_world(corner)
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	return AABB(Vector3(lo.x, 0.0, lo.y), Vector3(hi.x - lo.x, _height, hi.y - lo.y))


func site_point() -> Vector2:
	"""Where the builders set their loads down (world)."""
	return to_world(SITE_LOCAL)


func work_spots() -> PackedVector2Array:
	"""Each board row's work spot (hall_rules.gd ROWS: the upgrade's places, then each banner's bay), world."""
	var out := PackedVector2Array()
	for x: float in UPGRADE_WORK_X:
		out.append(to_world(Vector2(x, front_z() + WORK_OUT_M)))
	for x: float in BANNER_X:
		out.append(to_world(Vector2(x, front_z() + WORK_OUT_M)))
	return out


func work_faces() -> PackedVector2Array:
	"""The point each row's builder faces as it works: the facade before it (world)."""
	var out := PackedVector2Array()
	for x: float in UPGRADE_WORK_X:
		out.append(to_world(Vector2(x, front_z() - 1.0)))
	for x: float in BANNER_X:
		out.append(to_world(Vector2(x, front_z() - 1.0)))
	return out


# --- building the pieces --------------------------------------------------------------------------------------------

func build(world: Node3D, props: PropsScript) -> void:
	"""Make every piece once, hidden (`world`: demo_world.gd, for its own models; `props`: the small ones)."""
	_stone = _pile(world, &"rock_cluster", STONE_LOCAL, STONE_SIZE)
	_wood = _pile(world, &"log_stack", WOOD_LOCAL, WOOD_SIZE)
	_cloth = _prop_at(props, &"sack_pile", Transform3D(Basis(Vector3.UP, _yaw).scaled(Vector3.ONE * CLOTH_SIZE),
		_flat3(CLOTH_LOCAL)))
	for x: float in RAIL_X:
		_scaffold.append(_rail(world, Vector2(x, front_z() + RAIL_OUT_M)))
	_scaffold.append(_prop_at(props, &"plank_stack", Transform3D(Basis(Vector3.UP, _yaw), _flat3(TIMBER_LOCAL))))
	if world != null and world.has_method(&"stage_node"):
		_timber = world.call(&"placed_node", HALL_ID) as Node3D
		_stone_hall = world.call(&"stage_node", HALL_ID) as Node3D
	if _stone_hall == null:
		_build_composed(props)
	_banner_model = BANNER_KEY if props != null and props.is_staged(BANNER_KEY) else STAND_IN_BANNER_KEY
	for k: int in BANNER_X.size():
		var banner: Node3D = _banner(props, BANNER_X[k])
		_dye(banner as MeshInstance3D, BANNER_DYES[k])
		_banners.append(banner)


func _build_composed(props: PropsScript) -> void:
	"""The great hall's composed stand-in (no stone hall staged): the darkened second chimney and the two roundels."""
	var chimney := Transform3D(Basis(Vector3.UP, _yaw).scaled(Vector3.ONE * CHIMNEY_SCALE), to_world_3d(CHIMNEY_LOCAL))
	_great.append(_prop_at(props, &"chimney_pot", chimney))
	_dye(_great[0] as MeshInstance3D, CHIMNEY_DYE)
	for x: float in ROUNDEL_X:
		_great.append(_prop_at(props, &"rag_rug", _hanging(x, ROUNDEL_OUT_M, 1.0)))


func _banner(props: PropsScript, x: float) -> Node3D:
	"""One banner at bay `x`: the linen `hall_banner` hanging upright, centred HANGING_Y up the facade, when staged;
	else the stand-in stood upright and scaled to the facade."""
	if _banner_model != BANNER_KEY:
		return _prop_at(props, STAND_IN_BANNER_KEY, _hanging(x, BANNER_OUT_M, BANNER_SCALE))
	var drop: float = PropsScript.drawn_size_m(BANNER_KEY) * 0.5
	var hung := Transform3D(Basis(Vector3.UP, _yaw), to_world_3d(Vector3(x, HANGING_Y - drop, front_z() + BANNER_OUT_M)))
	return _prop_at(props, BANNER_KEY, hung)


func _flat3(local: Vector2) -> Vector3:
	"""A ground point in the hall's frame, in the world."""
	return to_world_3d(Vector3(local.x, 0.0, local.y))


func _hanging(x: float, out_m: float, scale_by: float) -> Transform3D:
	"""A flat cloth stood upright against the facade at bay `x`, its face out of the hall, scaled `scale_by`."""
	var upright := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -PI / 2.0)
	return Transform3D(upright.scaled(Vector3.ONE * scale_by), to_world_3d(Vector3(x, HANGING_Y, front_z() + out_m)))


func _pile(world: Node3D, key: StringName, local: Vector2, size: float) -> Node3D:
	"""A pile of the world's model `key` (drawn as the world draws it), under a holder at `local` that scales it."""
	var holder := Node3D.new()
	holder.name = "Pile_%s" % key
	holder.position = _flat3(local)
	holder.visible = false
	add_child(holder)
	if world != null and world.has_method(&"make_piece"):
		holder.add_child(world.call(&"make_piece", key, Vector2.ZERO, _yaw, size) as Node3D)
	return holder


func _rail(world: Node3D, local: Vector2) -> Node3D:
	"""One length of the work rail (the world's fence model) at `local`, along the front, hidden."""
	var holder := Node3D.new()
	holder.position = _flat3(local)
	holder.visible = false
	add_child(holder)
	if world != null and world.has_method(&"make_piece"):
		holder.add_child(world.call(&"make_piece", &"fence", Vector2.ZERO, _yaw, RAIL_SIZE) as Node3D)
	return holder


func _prop_at(props: PropsScript, key: StringName, placed: Transform3D) -> Node3D:
	"""The prop `key` drawn at `placed` (with its own fit), hidden."""
	var node: MeshInstance3D = props.instance(key) if props != null else MeshInstance3D.new()
	node.transform = placed * node.transform
	node.visible = false
	add_child(node)
	return node


func _dye(node: MeshInstance3D, dye: Color) -> void:
	"""Draw `node`'s surface 0 in a duplicate of its model's own material multiplied by `dye` (the shared model
	untouched): the whole of a single-material prop, the cloth of the linen banner (its surface 1, the wood, is never
	dyed)."""
	if node == null or node.mesh == null or node.mesh.get_surface_count() == 0:
		return
	var source := node.mesh.surface_get_material(0) as BaseMaterial3D
	if source == null:
		return
	var dyed := source.duplicate() as BaseMaterial3D
	dyed.albedo_color = source.albedo_color * dye
	if node.mesh.get_surface_count() == 1:
		node.material_override = dyed
	else:
		node.set_surface_override_material(0, dyed)


# --- showing the state ----------------------------------------------------------------------------------------------

func sync(projects: ProjectsScript) -> bool:
	"""Show the projects as they stand, when they changed since the last call. Whether anything was redrawn."""
	if projects == null or projects.revision == _seen or _stone == null:
		return false
	_seen = projects.revision
	var upgrade: int = Rules.PROJECT_UPGRADE
	var active: bool = projects.is_active(upgrade)
	_show_pile(_stone, projects, Rules.MAT_STONE, active)
	_show_pile(_wood, projects, Rules.MAT_WOOD, active)
	_show_pile(_cloth, projects, Rules.MAT_CLOTH, active)
	var building: bool = projects.phase[upgrade] == ProjectsScript.PHASE_BUILDING
	for post: Node3D in _scaffold:
		post.visible = building
	_show_great(projects.tier >= Rules.TIER_GREAT)
	for k: int in _banners.size():
		_banners[k].visible = projects.phase[Rules.PROJECT_BANNER_FIRST + k] == ProjectsScript.PHASE_DONE
	return true


func _show_great(great: bool) -> void:
	"""The great hall: the stone hall in the timber one's place when staged, else the composed additions."""
	if _stone_hall != null and is_instance_valid(_stone_hall):
		_stone_hall.visible = great
		if _timber != null and is_instance_valid(_timber):
			_timber.visible = not great
	for piece: Node3D in _great:
		piece.visible = great


func _show_pile(pile: Node3D, projects: ProjectsScript, mat: int, active: bool) -> void:
	"""A site pile sized by its material's share delivered (hidden when none is, or no upgrade is under way)."""
	var need: int = Rules.need_milli(Rules.PROJECT_UPGRADE, mat)
	var have: int = projects.delivered[projects.cell(Rules.PROJECT_UPGRADE, mat)] if active else 0
	pile.visible = have > 0 and need > 0
	if pile.visible and mat != Rules.MAT_CLOTH:
		pile.scale = Vector3.ONE * lerpf(PILE_MIN, 1.0, float(have) / float(need))


# --- reading (checks) -----------------------------------------------------------------------------------------------

func shown_banners() -> int:
	"""How many banners are drawn."""
	var n: int = 0
	for banner: Node3D in _banners:
		n += 1 if banner.visible else 0
	return n


func great_shown() -> bool:
	"""Whether the great hall is drawn: the stone hall, or the composed additions."""
	return stone_shown() or (not _great.is_empty() and _great[0].visible)


func stone_shown() -> bool:
	"""Whether the staged stone hall stands in the timber one's place."""
	return _stone_hall != null and _stone_hall.visible


func composed_pieces() -> int:
	"""How many composed great-hall pieces were made (the chimney and the roundels; none with the stone hall)."""
	return _great.size()


func banner_model() -> StringName:
	"""The model the banners are drawn with: the linen `hall_banner`, or the stand-in `relic_banner`."""
	return _banner_model


func banner_node(k: int) -> MeshInstance3D:
	"""Banner `k`'s node (checks)."""
	return _banners[k] as MeshInstance3D


func scaffold_shown() -> bool:
	"""Whether the scaffold stands."""
	return not _scaffold.is_empty() and _scaffold[0].visible


func pile_shown(mat: int) -> bool:
	"""Whether material `mat`'s site pile is drawn."""
	var pile: Node3D = [_wood, _stone, _cloth][mat] as Node3D
	return pile != null and pile.visible
