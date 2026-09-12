extends RefCounted
## The proportion-comparison scene decision 0002 requires before bulk creature proportions.
##
## Decision 0002, restated by the 2026-09-11 ruling: mouse / hare-or-otter / badger beside
## the SAME door, table and workbench, standing, walking, carrying and crouching, close and
## at the RTS camera, before bulk proportions are approved. Mole and squirrel are included
## because the ruling gives them new comparison candidates that this scene exists to settle.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS SCENE IS.
##
## Hand-authored untextured BLOCKOUT volumes at the ruling's candidate heights. It is the
## brief's step 1.2 -- "blockout the body in simple volumes ... before clothing" -- built
## for all five species at once so their statures can be compared in one frame. No credit
## was spent, no mesh was generated, and nothing here is approved anatomy.
##
## It therefore answers the STATURE half of decision 0002's review: is 922 right for a mole
## beside a 1024 mouse, is 2611 right for a badger beside a 3072 u door, does a 640 u work
## surface serve all five. It does NOT answer the ANATOMY half; that needs the per-species
## construction sheets in the brief's §3, which are separate deliverables.
##
## EVERY CREATURE HEIGHT HERE REMAINS A COMPARISON CANDIDATE UNTIL BRENDAN APPROVES IT.
##
## ---------------------------------------------------------------------------------------
## THE LANDMARK COLUMNS ARE PROPOSED REVIEW INPUTS, NOT CONTRACT VALUES.
##
## The ruling specifies the measurement convention -- neutral standing, soles on Y=0, height
## to the highest anatomical head/ear point, crown/eye/shoulder recorded, raised tail and
## equipment excluded -- and requires those landmarks to be recorded. It does not supply
## their values. The permille columns below are read off the authorized references named
## per row and are offered FOR the review, labelled `PROPOSED_FOR_REVIEW`. A reviewer may
## reject any of them without touching a single ruling number.
##
## Authored in integer millimetres throughout. Floats appear only where a Godot transform
## demands one, which is presentation.

const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")

const LANDMARK_STATUS: StringName = &"PROPOSED_FOR_REVIEW"
const HEIGHT_STATUS: StringName = &"PROPORTION_APPROVED_DEC_039"

# --- poses ---------------------------------------------------------------------------------

const POSE_STANDING: int = 0
const POSE_WALKING: int = 1
const POSE_CARRYING: int = 2
const POSE_CROUCHING: int = 3
const POSE_COUNT: int = 4

const POSE_KEY: Array[StringName] = [&"standing", &"walking", &"carrying", &"crouching"]

## The prop each pose is judged against. Every species meets every prop exactly once, and
## the prop is dimensionally identical in all five bays -- that is what "the same door,
## table and workbench" means on a comparison sheet.
const POSE_STATION: Array[StringName] = [&"doorway", &"open_ground", &"work_surface", &"table"]

# --- species landmark columns, permille of neutral standing height ---------------------------
#
# Reference basis, per the manifest regions already authorized under DEC-036:
#   mouse    IMG-12 mouse_guardian [1019,383,1432,956) + approved image left panel
#   mole     IMG-08 mole_body [12,415,744,1066)       + approved image left panel
#   squirrel IMG-07 squirrel_group [775,4,1408,976)
#   otter    IMG-18 otter_body [771,157,1284,932)
#   badger   IMG-25 woodland_lineup [413,247,1304,565), cell labelled "Badger"
# IMG-25's bands are squad model counts, not heights; it is used for silhouette rank only.

const SKULL_TOP_PERMILLE: Array[int] = [870, 1000, 880, 1000, 1000]
const EYE_PERMILLE: Array[int] = [830, 880, 840, 930, 920]
const NECK_PERMILLE: Array[int] = [760, 860, 770, 850, 830]
const SHOULDER_PERMILLE: Array[int] = [720, 830, 730, 820, 800]
const HIP_PERMILLE: Array[int] = [460, 450, 460, 470, 470]
const TORSO_WIDTH_PERMILLE: Array[int] = [290, 400, 290, 300, 360]
const TORSO_DEPTH_PERMILLE: Array[int] = [230, 340, 240, 260, 300]
const MUZZLE_PERMILLE: Array[int] = [130, 220, 110, 120, 150]
## Tail length along the ground plane. The convention EXCLUDES a raised tail from height,
## so a squirrel's plume never shortens its torso when this scene is measured.
const TAIL_PERMILLE: Array[int] = [820, 120, 950, 620, 250]
## 1 where the highest anatomical point is the ear or ear tuft rather than the skull.
## `Array[int]` and not `PackedByteArray`: a packed-array constructor is not a constant
## expression in GDScript and will not parse as a `const`.
const EAR_DEFINES_CROWN: Array[int] = [1, 0, 1, 0, 0]

const PERMILLE: int = 1000
## Walking stride and crouch depth, as permille of standing height. Pose construction, not
## a movement contract: MOVE-G01 owns real stride, step height and clearance.
const WALK_STRIDE_PERMILLE: int = 180
const CROUCH_HIP_PERMILLE: int = 550

# --- shared props, authored in integer millimetres ------------------------------------------
#
# Doorway: GAP-03's "ordinary common-access door opening 1536 wide x 3072 high", in a panel
# whose head height is the workbench building's own 3584 u envelope. 1536/3072/3584 u are
# 1500/3000/3500 mm exactly, so nothing is rounded into this scene.

const DOOR_OPENING_WIDTH_MM: int = 1500
const DOOR_OPENING_HEIGHT_MM: int = 3000
const DOOR_PANEL_WIDTH_MM: int = 2500
const DOOR_PANEL_HEIGHT_MM: int = 3500
const DOOR_PANEL_DEPTH_MM: int = 400

## GAP-03's 640 u work-surface top height, exactly 625 mm. An EXPLICIT CANDIDATE.
const WORK_SURFACE_TOP_MM: int = 625
const SURFACE_SLAB_MM: int = 60
const SURFACE_LEG_MM: int = 100
## D4 seat place: GDD §5.9 furniture is 1x1 tile, and a tile is 2 m.
const TABLE_SIZE_MM: int = 2000
const WORK_SURFACE_LENGTH_MM: int = 2000
const WORK_SURFACE_DEPTH_MM: int = 800

## The `workbench` BuildingDefinition itself, present once as the GAP-03 envelope reference:
## 3x3 tiles = 6 m, 3584 u = 3500 mm maximum local Y.
const SHELTER_FOOTPRINT_MM: int = 6000
const SHELTER_HEIGHT_MM: int = 3500
const SHELTER_POST_MM: int = 200
const SHELTER_ROOF_SLAB_MM: int = 250
const SHELTER_ROOF_OVERHANG_MM: int = 400

# --- layout -----------------------------------------------------------------------------

## One bay per species along +X, one station per pose along +Z.
const BAY_PITCH_MM: int = 4500
const STATION_PITCH_MM: int = 3000
## The shelter sits BEHIND the last station. The front elevation is taken from -Z and clips
## everything past the standing row, so anything placed at -Z would stand in front of the
## measured sheet instead of behind it.
const SHELTER_Z_MM: int = 14000
const GROUND_WIDTH_MM: int = 30000
const GROUND_DEPTH_MM: int = 30000
const GROUND_CENTRE_Z_MM: int = 6000

## A graduated post beside the standing row, banded every 500 mm, so the elevation sheet can
## be read off rather than believed. This is what makes the scene "measured" to a human eye;
## the manifest carries the same fact for a machine.
const SCALE_RULE_BAND_MM: int = 500
const SCALE_RULE_TOP_MM: int = 3500
const SCALE_RULE_THICKNESS_MM: int = 120
const SCALE_RULE_X_MM: int = -11000

## Residents face -Z (AGENTS.md). A doorway a resident stands IN sits behind them at +Z; a
## surface a resident works AT sits in front of them at -Z. Both offsets are stated here so
## the elevation camera can clip everything behind the standing row without guessing.
const PROP_BEHIND_Z_MM: int = 1200
const PROP_AHEAD_Z_MM: int = -1200

const MM_PER_METRE: float = 1000.0


static func species_count() -> int:
	"""How many species the comparison scene places. Five, per the ruling's named set."""
	return Dimensions.SPECIES_KEY.size()


static func landmark_mm(permille_column: Array[int], row: int, height_mm: int) -> int:
	"""One landmark in integer millimetres: permille of the species' standing height."""
	return permille_column[row] * height_mm / PERMILLE


static func crown_mm(row: int, pose: int) -> int:
	"""Highest anatomical head or ear point of one species in one pose, in millimetres.

	Standing crown is the species' candidate height by construction, which is what makes the
	rendered sheet measurable rather than merely plausible.
	"""
	var height: int = Dimensions.SPECIES_HEIGHT_MM[row]
	if pose != POSE_CROUCHING:
		return height
	return height - _crouch_drop_mm(row)


static func _crouch_drop_mm(row: int) -> int:
	"""How far the whole upper body lowers when a species crouches, in millimetres."""
	var height: int = Dimensions.SPECIES_HEIGHT_MM[row]
	var hip: int = landmark_mm(HIP_PERMILLE, row, height)
	return hip - CROUCH_HIP_PERMILLE * hip / PERMILLE


static func measured_bounds_mm(node: Node3D) -> AABB:
	"""Union of every direct child mesh's AABB, in millimetres, in `node`'s own space.

	Measured off the assembled meshes, so a manifest built from this cannot report a height
	the geometry does not have. Returns an empty box when `node` holds no mesh -- callers
	check `size`, and an empty box is an honest "nothing here", not a height of zero.
	"""
	var bounds: AABB = AABB()
	var started: bool = false
	for child: Node in node.get_children():
		var mesh_child := child as MeshInstance3D
		if mesh_child == null or mesh_child.mesh == null:
			continue
		var box: AABB = mesh_child.mesh.get_aabb()
		box.position = (box.position + mesh_child.position) * MM_PER_METRE
		box.size *= MM_PER_METRE
		bounds = box if not started else bounds.merge(box)
		started = true
	return bounds


static func blockout_of(root: Node3D, row: int, pose: int) -> Node3D:
	"""The blockout node for one species in one pose, or null when the scene does not hold it."""
	var path: String = "%s_%s/blockout_%s" % [Dimensions.SPECIES_KEY[row], POSE_KEY[pose],
		Dimensions.SPECIES_KEY[row]]
	return root.get_node_or_null(NodePath(path)) as Node3D


static func bay_x_mm(row: int) -> int:
	"""Centre of one species' bay along X, with the five bays centred on the origin.

	The first species sits at +X. The front elevation is taken from -Z, where +X falls on
	the left of frame, so the sheet reads mouse to badger left to right as a reader expects.
	"""
	return ((species_count() - 1) / 2 - row) * BAY_PITCH_MM


static func station_z_mm(pose: int) -> int:
	"""Centre of one pose's station along Z."""
	return pose * STATION_PITCH_MM


# --- scene construction ---------------------------------------------------------------------


static func build_scene() -> Node3D:
	"""Assemble the whole comparison scene: ground, the shelter reference, bays and blockouts."""
	var root := Node3D.new()
	root.name = "ProportionComparison"
	root.add_child(_build_ground())
	root.add_child(_build_shelter())
	root.add_child(_build_scale_rule())
	for row: int in species_count():
		for pose: int in POSE_COUNT:
			root.add_child(_build_bay_cell(row, pose))
	_own_recursively(root, root)
	return root


static func _own_recursively(node: Node, owner: Node) -> void:
	"""Set `owner` on every descendant so `PackedScene.pack()` keeps the whole hierarchy."""
	for child: Node in node.get_children():
		if child != owner:
			child.owner = owner
		_own_recursively(child, owner)


static func _build_bay_cell(row: int, pose: int) -> Node3D:
	"""One species in one pose at its station, with that station's prop beside it."""
	var cell := Node3D.new()
	cell.name = "%s_%s" % [Dimensions.SPECIES_KEY[row], POSE_KEY[pose]]
	cell.position = Vector3(bay_x_mm(row) / MM_PER_METRE, 0.0, station_z_mm(pose) / MM_PER_METRE)
	var prop: Node3D = _build_station_prop(pose)
	if prop != null:
		cell.add_child(prop)
	cell.add_child(_build_blockout(row, pose))
	return cell


static func _build_station_prop(pose: int) -> Node3D:
	"""The prop for one station: doorway panel, table, work surface, or nothing on open ground."""
	match pose:
		POSE_STANDING:
			return _build_doorway()
		POSE_CROUCHING:
			return _build_surface("table", TABLE_SIZE_MM, TABLE_SIZE_MM)
		POSE_CARRYING:
			return _build_surface("work_surface", WORK_SURFACE_LENGTH_MM, WORK_SURFACE_DEPTH_MM)
		_:
			return null


static func _build_doorway() -> Node3D:
	"""A wall panel carrying GAP-03's 1536 x 3072 u common-access opening, built from three boxes."""
	var node := Node3D.new()
	node.name = "doorway"
	node.position = Vector3(0.0, 0.0, PROP_BEHIND_Z_MM / MM_PER_METRE)
	var jamb: int = (DOOR_PANEL_WIDTH_MM - DOOR_OPENING_WIDTH_MM) / 2
	var offset: int = (DOOR_OPENING_WIDTH_MM + jamb) / 2
	var header: int = DOOR_PANEL_HEIGHT_MM - DOOR_OPENING_HEIGHT_MM
	_add_box(node, "jamb_w", Vector3i(jamb, DOOR_PANEL_HEIGHT_MM, DOOR_PANEL_DEPTH_MM),
		Vector3i(-offset, DOOR_PANEL_HEIGHT_MM / 2, 0))
	_add_box(node, "jamb_e", Vector3i(jamb, DOOR_PANEL_HEIGHT_MM, DOOR_PANEL_DEPTH_MM),
		Vector3i(offset, DOOR_PANEL_HEIGHT_MM / 2, 0))
	_add_box(node, "header", Vector3i(DOOR_OPENING_WIDTH_MM, header, DOOR_PANEL_DEPTH_MM),
		Vector3i(0, DOOR_OPENING_HEIGHT_MM + header / 2, 0))
	return node


static func _build_surface(surface_name: String, length_mm: int, depth_mm: int) -> Node3D:
	"""A table or work surface with its top at GAP-03's 640 u candidate height."""
	var node := Node3D.new()
	node.name = surface_name
	node.position = Vector3(0.0, 0.0, PROP_AHEAD_Z_MM / MM_PER_METRE)
	var slab_centre: int = WORK_SURFACE_TOP_MM - SURFACE_SLAB_MM / 2
	_add_box(node, "top", Vector3i(length_mm, SURFACE_SLAB_MM, depth_mm),
		Vector3i(0, slab_centre, 0))
	var leg_height: int = WORK_SURFACE_TOP_MM - SURFACE_SLAB_MM
	var dx: int = (length_mm - SURFACE_LEG_MM) / 2 - SURFACE_LEG_MM
	var dz: int = (depth_mm - SURFACE_LEG_MM) / 2 - SURFACE_LEG_MM
	for corner: int in 4:
		var sx: int = 1 if corner % 2 == 0 else -1
		var sz: int = 1 if corner < 2 else -1
		_add_box(node, "leg_%d" % corner,
			Vector3i(SURFACE_LEG_MM, leg_height, SURFACE_LEG_MM),
			Vector3i(sx * dx, leg_height / 2, sz * dz))
	return node


static func _build_shelter() -> Node3D:
	"""The `workbench` BuildingDefinition at its 6 m footprint and 3584 u envelope, once."""
	var node := Node3D.new()
	node.name = "building_workbench_reference"
	node.position = Vector3(0.0, 0.0, SHELTER_Z_MM / MM_PER_METRE)
	var post_height: int = SHELTER_HEIGHT_MM - SHELTER_ROOF_SLAB_MM
	var half: int = (SHELTER_FOOTPRINT_MM - SHELTER_POST_MM) / 2
	for corner: int in 4:
		var sx: int = 1 if corner % 2 == 0 else -1
		var sz: int = 1 if corner < 2 else -1
		_add_box(node, "post_%d" % corner,
			Vector3i(SHELTER_POST_MM, post_height, SHELTER_POST_MM),
			Vector3i(sx * half, post_height / 2, sz * half))
	var span: int = SHELTER_FOOTPRINT_MM + 2 * SHELTER_ROOF_OVERHANG_MM
	_add_box(node, "roof", Vector3i(span, SHELTER_ROOF_SLAB_MM, span),
		Vector3i(0, SHELTER_HEIGHT_MM - SHELTER_ROOF_SLAB_MM / 2, 0))
	_add_box(node, "work_surface_top",
		Vector3i(WORK_SURFACE_LENGTH_MM, SURFACE_SLAB_MM, WORK_SURFACE_DEPTH_MM),
		Vector3i(0, WORK_SURFACE_TOP_MM - SURFACE_SLAB_MM / 2, -2000))
	return node


static func _build_scale_rule() -> Node3D:
	"""A banded post beside the standing row: alternate 500 mm bands from the ground to 3500 mm."""
	var node := Node3D.new()
	node.name = "scale_rule"
	node.position = Vector3(SCALE_RULE_X_MM / MM_PER_METRE, 0.0,
		station_z_mm(POSE_STANDING) / MM_PER_METRE)
	var bands: int = SCALE_RULE_TOP_MM / SCALE_RULE_BAND_MM
	for band: int in bands:
		if band % 2 == 1:
			continue
		_add_box_with_material(node, "band_%04d" % (band * SCALE_RULE_BAND_MM),
			Vector3i(SCALE_RULE_THICKNESS_MM, SCALE_RULE_BAND_MM, SCALE_RULE_THICKNESS_MM),
			Vector3i(0, band * SCALE_RULE_BAND_MM + SCALE_RULE_BAND_MM / 2, 0),
			_rule_material())
	_add_box(node, "spine", Vector3i(SCALE_RULE_THICKNESS_MM / 3, SCALE_RULE_TOP_MM,
		SCALE_RULE_THICKNESS_MM / 3), Vector3i(0, SCALE_RULE_TOP_MM / 2, 0))
	return node


static func _build_ground() -> MeshInstance3D:
	"""A flat ground plane at the placed-base datum, local Y = 0, with a 2 m tile check."""
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_WIDTH_MM / MM_PER_METRE, GROUND_DEPTH_MM / MM_PER_METRE)
	var node := MeshInstance3D.new()
	node.name = "ground"
	node.mesh = plane
	node.position = Vector3(0.0, 0.0, GROUND_CENTRE_Z_MM / MM_PER_METRE)
	node.material_override = _ground_material()
	return node


static func _build_blockout(row: int, pose: int) -> Node3D:
	"""One species' untextured blockout: legs, torso, arms, neck, head, muzzle, ears, tail."""
	var node := Node3D.new()
	node.name = "blockout_%s" % Dimensions.SPECIES_KEY[row]
	var height: int = Dimensions.SPECIES_HEIGHT_MM[row]
	var drop: int = _crouch_drop_mm(row) if pose == POSE_CROUCHING else 0
	var width: int = landmark_mm(TORSO_WIDTH_PERMILLE, row, height)
	var depth: int = landmark_mm(TORSO_DEPTH_PERMILLE, row, height)
	var hip: int = landmark_mm(HIP_PERMILLE, row, height) - drop
	var shoulder: int = landmark_mm(SHOULDER_PERMILLE, row, height) - drop
	_add_legs(node, row, pose, width, hip)
	_add_box(node, "torso", Vector3i(width, shoulder - hip, depth),
		Vector3i(0, (shoulder + hip) / 2, 0))
	_add_arms(node, row, pose, width, depth, drop)
	_add_head(node, row, drop, width, depth)
	_add_tail(node, row, hip, width)
	if pose == POSE_CARRYING:
		_add_carried_basket(node, row, hip, depth)
	return node


static func _add_legs(node: Node3D, row: int, pose: int, width: int, hip: int) -> void:
	"""Two leg volumes from the ground to the hip, split fore and aft when walking."""
	var stride: int = 0
	if pose == POSE_WALKING:
		stride = WALK_STRIDE_PERMILLE * Dimensions.SPECIES_HEIGHT_MM[row] / PERMILLE / 2
	var leg: int = width / 3
	for side: int in 2:
		var sx: int = 1 if side == 0 else -1
		_add_box(node, "leg_%d" % side, Vector3i(leg, hip, leg),
			Vector3i(sx * width / 4, hip / 2, -sx * stride))


static func _add_arms(node: Node3D, row: int, pose: int, width: int, depth: int,
		drop: int) -> void:
	"""Two arm volumes hanging from the shoulder, swung when walking, forward when carrying."""
	var height: int = Dimensions.SPECIES_HEIGHT_MM[row]
	var shoulder: int = landmark_mm(SHOULDER_PERMILLE, row, height) - drop
	var hip: int = landmark_mm(HIP_PERMILLE, row, height) - drop
	var arm: int = width / 4
	var swing: int = WALK_STRIDE_PERMILLE * height / PERMILLE / 3 if pose == POSE_WALKING else 0
	var forward: int = depth if pose == POSE_CARRYING else 0
	for side: int in 2:
		var sx: int = 1 if side == 0 else -1
		_add_box(node, "arm_%d" % side, Vector3i(arm, shoulder - hip, arm),
			Vector3i(sx * (width / 2 + arm / 2), (shoulder + hip) / 2, sx * swing - forward))


static func _add_head(node: Node3D, row: int, drop: int, width: int, depth: int) -> void:
	"""Neck, skull, forward muzzle and -- where the ear is the crown -- the ear volumes."""
	var height: int = Dimensions.SPECIES_HEIGHT_MM[row]
	var neck: int = landmark_mm(NECK_PERMILLE, row, height) - drop
	var skull: int = landmark_mm(SKULL_TOP_PERMILLE, row, height) - drop
	var shoulder: int = landmark_mm(SHOULDER_PERMILLE, row, height) - drop
	var head_w: int = width * 4 / 5
	_add_box(node, "neck", Vector3i(head_w / 2, neck - shoulder, head_w / 2),
		Vector3i(0, (neck + shoulder) / 2, 0))
	_add_box(node, "skull", Vector3i(head_w, skull - neck, depth * 4 / 5),
		Vector3i(0, (skull + neck) / 2, 0))
	var muzzle: int = landmark_mm(MUZZLE_PERMILLE, row, height)
	_add_box(node, "muzzle", Vector3i(head_w / 2, head_w / 2, muzzle),
		Vector3i(0, landmark_mm(EYE_PERMILLE, row, height) - drop - head_w / 4,
			-(depth * 2 / 5 + muzzle / 2)))
	_add_ears(node, row, skull, head_w, drop)


static func _add_ears(node: Node3D, row: int, skull: int, head_w: int, drop: int) -> void:
	"""Ear volumes reaching the crown for the species whose ear IS the highest point."""
	var crown: int = crown_mm(row, POSE_STANDING) - drop
	var rise: int = crown - skull
	if EAR_DEFINES_CROWN[row] == 0:
		return
	for side: int in 2:
		var sx: int = 1 if side == 0 else -1
		_add_box(node, "ear_%d" % side, Vector3i(head_w * 9 / 20, rise, head_w / 6),
			Vector3i(sx * head_w / 2, skull + rise / 2, 0))


static func _add_tail(node: Node3D, row: int, hip: int, width: int) -> void:
	"""A tail volume running back along +Z from the hip, excluded from the height convention."""
	var length: int = landmark_mm(TAIL_PERMILLE, row, Dimensions.SPECIES_HEIGHT_MM[row])
	if length <= 0:
		return
	var thickness: int = width / 4
	_add_box(node, "tail", Vector3i(thickness, thickness, length),
		Vector3i(0, hip - thickness, length / 2 + width / 2))


static func _add_carried_basket(node: Node3D, row: int, hip: int, depth: int) -> void:
	"""The carried-load proxy for the carrying pose: a basket-sized box held in front."""
	var height: int = Dimensions.SPECIES_HEIGHT_MM[row]
	var size: int = 280 * height / PERMILLE
	_add_box(node, "carried_load", Vector3i(size, size * 3 / 4, size),
		Vector3i(0, hip + size / 3, -(depth + size / 2)))


static func _add_box(parent: Node3D, box_name: String, size_mm: Vector3i,
		centre_mm: Vector3i) -> void:
	"""Attach one blockout box in the shared neutral material."""
	_add_box_with_material(parent, box_name, size_mm, centre_mm, _blockout_material())


static func _add_box_with_material(parent: Node3D, box_name: String, size_mm: Vector3i,
		centre_mm: Vector3i, material: StandardMaterial3D) -> void:
	"""Attach one axis-aligned blockout box, authored in millimetres, converted once for Godot."""
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_mm.x / MM_PER_METRE, size_mm.y / MM_PER_METRE,
		size_mm.z / MM_PER_METRE)
	var node := MeshInstance3D.new()
	node.name = box_name
	node.mesh = mesh
	node.position = Vector3(centre_mm.x / MM_PER_METRE, centre_mm.y / MM_PER_METRE,
		centre_mm.z / MM_PER_METRE)
	node.material_override = material
	parent.add_child(node)


static var _shared_blockout_material: StandardMaterial3D = null
static var _shared_ground_material: StandardMaterial3D = null
static var _shared_rule_material: StandardMaterial3D = null


static func _rule_material() -> StandardMaterial3D:
	"""A darker material for the scale rule's alternating bands, so the graduation reads."""
	if _shared_rule_material == null:
		_shared_rule_material = StandardMaterial3D.new()
		_shared_rule_material.albedo_color = Color(0.16, 0.16, 0.15)
		_shared_rule_material.roughness = Dimensions.MATERIAL_ROUGHNESS_PERMILLE[2] / 1000.0
		_shared_rule_material.metallic = 0.0
	return _shared_rule_material


static func _blockout_material() -> StandardMaterial3D:
	"""One shared neutral matte blockout material. Deliberately carries no approved palette.

	ART-LOCK-001's twelve illustration pigments govern UI art and are not a world palette,
	so none of them appears here; and an untextured blockout is what the brief's step 1.2
	asks to judge, because a painted surface can hide wrong volume. It is shared rather than
	built per box so a 240-volume scene does not carry 240 materials.
	"""
	if _shared_blockout_material == null:
		_shared_blockout_material = StandardMaterial3D.new()
		_shared_blockout_material.albedo_color = Color(0.62, 0.60, 0.56)
		_shared_blockout_material.roughness = Dimensions.MATERIAL_ROUGHNESS_PERMILLE[1] / 1000.0
		_shared_blockout_material.metallic = 0.0
	return _shared_blockout_material


static func _ground_material() -> StandardMaterial3D:
	"""One shared darker matte ground so the blockout silhouettes separate from the plane."""
	if _shared_ground_material == null:
		_shared_ground_material = StandardMaterial3D.new()
		_shared_ground_material.albedo_color = Color(0.38, 0.37, 0.34)
		_shared_ground_material.roughness = Dimensions.MATERIAL_ROUGHNESS_PERMILLE[2] / 1000.0
		_shared_ground_material.metallic = 0.0
	return _shared_ground_material
