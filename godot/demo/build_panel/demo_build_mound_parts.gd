extends RefCounted
## THE MOUNDS' OTHER PARTS, DRAWN (decision 2002), each a few primitives gathered by material
## (demo_build_mound_mesh.gd), in the palette of demo_build_mound_front.gd. Presentation only (BUILD-MOUND-023).
##   WINDOWS   outside, flush on the turf slope where it is at the wall's top metre, turned to the slope's surface
##             (BUILD-MOUND-014, -015): its brick ring and timber hood once its cells are framed, its plastered rim,
##             glass and mullions once fitted. The heap is never cut for it: it is laid on the hill as drawn.
##             Inside (the cutaway), a fitted window is a disc of sky at the wall's top metre with a beam of daylight
##             to a pool on the floor (BUILD-MOUND-016; its light is the view's).
##   RIBS      the frame: in each dug room, timber arch ribs across its shorter span every RIB_SPACING_M, each drawn
##             once the cells under it are framed (BUILD-MOUND-007; P-2001-14 (a): the braces drawn as ribs).
##   A HATCH   a way down on a Mound room's floor (BUILD-MOUND-021): a timber frame round a dark hole, its lid open
##             and a ladder's top standing out of it.
##   DRESSING  on a finished (topped) Mound: a chimney over each room with a fitted hearth (BUILD-MOUND-022), a tree on
##             its crown, and shrubs on the berm's lower slope, all kept clear of every window and the slope in
##             front of it, and of every door's path (BUILD-MOUND-017).

const Mound := preload("res://scripts/ui/build_mound.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

const HEARTH: int = Catalog.FURNITURE_DEFINITION["hearth"]
const RIB_SPACING_M: float = 1.2
const RIB_THICK_M: float = 0.16
## The highest a rib's arch rises; a wider room's rib is flattened to it.
const RIB_RISE_M: float = 3.0
## Dressing keeps this far from a window, and out of the strip in front of it (the mockup's figures).
const WINDOW_CLEAR_M: float = 2.6
const WINDOW_STRIP_HALF_M: float = 2.2
const WINDOW_STRIP_OUT_M: float = 6.0
const DOOR_STRIP_HALF_M: float = 4.5
const DOOR_STRIP_OUT_M: float = 6.0
## Shrubs grow where the slope is this low (m), on a jittered grid this far apart.
const SHRUB_LOW_M: float = 0.2
const SHRUB_HIGH_M: float = 1.1
const SHRUB_SPACING_M: float = 1.6
## Inside: the window's sky disc, how far into the room its beam lands.
const BEAM_IN_M: float = 1.6


static func window_spots(field: Field, mounds: Mounds) -> Array[Dictionary]:
	"""Each confirmed window whose slope is heaped: {row, edge, point, normal, out_m} (demo_build_mound_field.gd
	`window_spot`); a window on a hill not heaped yet has none."""
	var out: Array[Dictionary] = []
	for row: int in mounds.edge_count():
		if mounds.edge_kind(row) != Mound.KIND_WINDOW or mounds.stage_of(mounds.edge_cell(row)) < Mounds.HEAPED:
			continue
		var edge: Vector3i = mounds.edges_of(row)[0]
		var spot: Dictionary = field.window_spot(edge)
		if not spot.is_empty():
			spot["row"] = row
			spot["edge"] = edge
			out.append(spot)
	return out


static func window_frame(spot: Dictionary) -> Transform3D:
	"""A window's frame on the slope: its middle on the surface, z out along the slope's normal, x along the wall."""
	var normal: Vector3 = spot["normal"]
	var edge: Vector3i = spot["edge"]
	var along: Vector3 = Vector3(Mound.along(edge.z).x, 0.0, Mound.along(edge.z).y)
	var x_axis: Vector3 = (along - normal * along.dot(normal)).normalized()
	return Transform3D(Basis(x_axis, normal.cross(x_axis), normal), spot["point"])


static func add_window(kit: MeshKit, palette_of: Dictionary, spot: Dictionary, stage: int, fitted: bool) -> void:
	"""One window outside, flush on the slope, as far as it is built."""
	var frame: Transform3D = window_frame(spot)
	if stage < Mounds.FRAMED:
		return
	kit.add_ring(palette_of[&"brick"], 0.41, 0.59, frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.05)))
	var hood: Transform3D = frame * Transform3D(Basis.from_scale(Vector3(1.0, 0.55, 1.0)), Vector3(0.0, 0.0, 0.06))
	kit.add_arch(palette_of[&"rib"], 0.74, 0.12, hood, 10)
	if not fitted:
		kit.add_disc(palette_of[&"hole"], 0.45, frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.03)))
		return
	kit.add_disc(palette_of[&"plaster"], 0.7, frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.02)))
	kit.add_disc(palette_of[&"glass"], 0.44, frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.035)))
	kit.add_box(palette_of[&"rib"], Vector3(0.86, 0.05, 0.03), frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.06)))
	kit.add_box(palette_of[&"rib"], Vector3(0.05, 0.86, 0.03), frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.06)))


static func inside_frame(edge: Vector3i, datum_m: Vector2) -> Transform3D:
	"""A window's disc inside its room: at the wall's top metre on the wall's line, facing into the room and down."""
	var middle: Vector2 = datum_m + Field.edge_middle(edge)
	var outward: Vector3 = Vector3(Mound.step_of(edge.z).x, 0.0, Mound.step_of(edge.z).y)
	var facing: Vector3 = (-outward + Vector3.DOWN * 0.35).normalized()
	var x_axis: Vector3 = Vector3.UP.cross(facing).normalized()
	return Transform3D(Basis(x_axis, facing.cross(x_axis), facing),
		Vector3(middle.x, Field.WINDOW_HEIGHT_M, middle.y) + outward * 0.1)


static func beam_floor(edge: Vector3i, datum_m: Vector2) -> Vector3:
	"""Where a window's daylight lands on its room's floor."""
	var middle: Vector2 = datum_m + Field.edge_middle(edge)
	var outward: Vector2 = Vector2(Mound.step_of(edge.z))
	var at: Vector2 = middle - outward * BEAM_IN_M
	return Vector3(at.x, 0.04, at.y)


static func add_window_inside(kit: MeshKit, palette_of: Dictionary, edge: Vector3i, datum_m: Vector2) -> void:
	"""A fitted window seen from inside: its timber ring round a dark disc (the night's; by day `add_daylight` draws
	the sky in it)."""
	var frame: Transform3D = inside_frame(edge, datum_m)
	kit.add_disc(palette_of[&"hole"], 0.41, frame)
	kit.add_ring(palette_of[&"rib"], 0.4, 0.53, frame)


static func add_daylight(kit: MeshKit, palette_of: Dictionary, edge: Vector3i, datum_m: Vector2) -> void:
	"""A fitted window's daylight inside (BUILD-MOUND-016): the sky in its disc, the beam to the floor and the pool it
	makes there."""
	var frame: Transform3D = inside_frame(edge, datum_m)
	kit.add_disc(palette_of[&"sky"], 0.42, frame * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.01)))
	var floor_at: Vector3 = beam_floor(edge, datum_m)
	var along: Vector3 = frame.origin - floor_at
	var up: Vector3 = along.normalized()
	var x_axis: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var beam: Transform3D = Transform3D(Basis(x_axis, up, x_axis.cross(up)), floor_at + along / 2.0)
	kit.add_cylinder(palette_of[&"beam"], 0.38, 0.95, along.length(), beam, 20)
	kit.add_disc(palette_of[&"pool"], 1.15, Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), floor_at))


# --- ribs ------------------------------------------------------------------------------------------------------------

static func add_ribs(kit: MeshKit, palette_of: Dictionary, mounds: Mounds, rooms: Array[PackedInt32Array],
		datum_m: Vector2) -> int:
	"""Each room's ribs whose cells are framed (see RIBS); returns how many were drawn."""
	var drawn: int = 0
	for room: PackedInt32Array in rooms:
		drawn += _room_ribs(kit, palette_of, mounds, room, datum_m)
	return drawn


static func _room_ribs(kit: MeshKit, palette_of: Dictionary, mounds: Mounds, room: PackedInt32Array,
		datum_m: Vector2) -> int:
	"""One room's ribs across its shorter span (none where the crossing leaves the room or is not framed)."""
	var cells: Dictionary = Mound.set_of(room)
	var box: Rect2i = _box_of(room)
	var long_x: bool = box.size.x >= box.size.y
	var length: int = box.size.x if long_x else box.size.y
	var drawn: int = 0
	var along: float = 0.6
	while along < length - 0.4:
		var line: int = (box.position.x if long_x else box.position.y) + floori(along)
		if _crossing_framed(mounds, cells, box, line, long_x):
			_add_rib(kit, palette_of, box, along, long_x, datum_m)
			drawn += 1
		along += RIB_SPACING_M
	return drawn


static func _box_of(cells: PackedInt32Array) -> Rect2i:
	"""The box round `cells` (pairs)."""
	var box: Rect2i = Rect2i(Vector2i(cells[0], cells[1]), Vector2i.ONE)
	for at: int in range(2, cells.size(), 2):
		box = box.expand(Vector2i(cells[at], cells[at + 1])).expand(Vector2i(cells[at], cells[at + 1]) + Vector2i.ONE)
	return box


static func _crossing_framed(mounds: Mounds, cells: Dictionary, box: Rect2i, line: int, long_x: bool) -> bool:
	"""Whether every cell across the room on `line` is the room's and framed or further on."""
	var from: int = box.position.y if long_x else box.position.x
	var to: int = box.end.y if long_x else box.end.x
	for at: int in range(from, to):
		var cell: Vector2i = Vector2i(line, at) if long_x else Vector2i(at, line)
		if not cells.has(cell) or mounds.stage_of(cell) < Mounds.FRAMED:
			return false
	return true


static func _add_rib(kit: MeshKit, palette_of: Dictionary, box: Rect2i, along: float, long_x: bool,
		datum_m: Vector2) -> void:
	"""One arch rib across the room `along` m into its length, flattened to RIB_RISE_M, on two posts, its crown a rib's
	thickness under the wall's top (so the cutaway's cut never shows it)."""
	var span: float = float(box.size.y if long_x else box.size.x)
	var radius: float = span / 2.0
	var rise: float = minf(radius, RIB_RISE_M)
	var spring: float = Field.ROOM_TOP_M - rise - RIB_THICK_M
	var middle: Vector2 = datum_m + Vector2(box.position) + (Vector2(along, span / 2.0) if long_x else Vector2(span / 2.0, along))
	var across: Vector3 = Vector3(0.0, 0.0, 1.0) if long_x else Vector3(1.0, 0.0, 0.0)
	var basis: Basis = Basis(across, Vector3.UP, across.cross(Vector3.UP))
	var arch: Transform3D = Transform3D(basis, Vector3(middle.x, spring, middle.y)) \
		* Transform3D(Basis.from_scale(Vector3(1.0, rise / radius, 1.0)), Vector3.ZERO)
	kit.add_arch(palette_of[&"rib"], radius - RIB_THICK_M / 2.0, RIB_THICK_M, arch, 14)
	for side: float in [-1.0, 1.0]:
		var foot: Vector3 = Vector3(middle.x, spring / 2.0, middle.y) + across * side * (radius - RIB_THICK_M / 2.0)
		kit.add_box(palette_of[&"rib"], Vector3(RIB_THICK_M, spring, RIB_THICK_M), Transform3D(Basis.IDENTITY, foot))


# --- a hatch, and dressing ---------------------------------------------------------------------------------------------

static func add_hatch(kit: MeshKit, palette_of: Dictionary, cell: Vector2i, datum_m: Vector2) -> void:
	"""A way down on a room's floor at `cell` (its 2 × 2's north-west): the dark hole, a timber frame, the lid standing
	open to the north, and a ladder's top."""
	var middle: Vector3 = Vector3(datum_m.x + cell.x + 1.0, 0.0, datum_m.y + cell.y + 1.0)
	kit.add_box(palette_of[&"hole"], Vector3(1.7, 0.03, 1.7), Transform3D(Basis.IDENTITY, middle + Vector3(0.0, 0.02, 0.0)))
	for side: Vector3 in [Vector3(0.0, 0.0, -0.9), Vector3(0.0, 0.0, 0.9)]:
		kit.add_box(palette_of[&"oak"], Vector3(1.96, 0.12, 0.16), Transform3D(Basis.IDENTITY, middle + side + Vector3.UP * 0.06))
	for side: Vector3 in [Vector3(-0.9, 0.0, 0.0), Vector3(0.9, 0.0, 0.0)]:
		kit.add_box(palette_of[&"oak"], Vector3(0.16, 0.12, 1.96), Transform3D(Basis.IDENTITY, middle + side + Vector3.UP * 0.06))
	var lid: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(80.0)), middle + Vector3(0.0, 0.9, -0.95))
	kit.add_box(palette_of[&"oak"], Vector3(1.7, 1.7, 0.07), lid)
	for rail: float in [-0.3, 0.3]:
		kit.add_box(palette_of[&"rib"], Vector3(0.07, 1.0, 0.07), Transform3D(Basis.IDENTITY, middle + Vector3(rail, 0.5, 0.3)))
	for rung: float in [0.3, 0.65, 0.95]:
		kit.add_box(palette_of[&"rib"], Vector3(0.6, 0.05, 0.05), Transform3D(Basis.IDENTITY, middle + Vector3(0.0, rung, 0.3)))


static func add_chimney(kit: MeshKit, palette_of: Dictionary, at: Vector3) -> void:
	"""A brick chimney standing on the hill at `at` (its foot on the surface), with two pots."""
	kit.add_box(palette_of[&"brick"], Vector3(0.5, 1.0, 0.5), Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.3))
	for dx: float in [-0.11, 0.11]:
		kit.add_cylinder(palette_of[&"pot"], 0.08, 0.09, 0.3, Transform3D(Basis.IDENTITY, at + Vector3(dx, 0.95, 0.0)), 10)


static func add_tree(kit: MeshKit, palette_of: Dictionary, at: Vector3) -> void:
	"""A tree on the crown at `at` (its foot on the surface): a trunk and four leafy masses (the mockup's)."""
	kit.add_cylinder(palette_of[&"bark"], 0.3, 0.5, 2.8, Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.3), 10)
	for leaf: Vector4 in [Vector4(0.0, 3.6, 0.0, 2.0), Vector4(1.4, 3.1, 0.6, 1.5), Vector4(-1.3, 3.2, -0.5, 1.6),
			Vector4(0.3, 4.4, -0.8, 1.4)]:
		var place: Transform3D = Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0)), at + Vector3(leaf.x, leaf.y, leaf.z))
		kit.add_sphere(palette_of[&"leaf"], leaf.w, place, 14)


static func clear_of_windows(point: Vector2, spots: Array[Dictionary]) -> bool:
	"""Whether dressing at `point` (world x, z) keeps clear of every window and the slope in front of it."""
	for spot: Dictionary in spots:
		var at: Vector3 = spot["point"]
		var edge: Vector3i = spot["edge"]
		var offset: Vector2 = point - Vector2(at.x, at.z)
		var out_m: float = offset.dot(Vector2(Mound.step_of(edge.z)))
		var side_m: float = absf(offset.dot(Vector2(Mound.along(edge.z))))
		if offset.length() < WINDOW_CLEAR_M or (out_m > -1.0 and out_m < WINDOW_STRIP_OUT_M and side_m < WINDOW_STRIP_HALF_M):
			return false
	return true


static func clear_of_doors(point: Vector2, doors: Array[Vector3i], datum_m: Vector2) -> bool:
	"""Whether dressing at `point` keeps out of the strip before every door (its path and garden)."""
	for door: Vector3i in doors:
		var frame: Transform3D = Front.frame_of(door, datum_m)
		var local: Vector3 = frame.affine_inverse() * Vector3(point.x, 0.0, point.y)
		if local.z > -0.5 and local.z < DOOR_STRIP_OUT_M and absf(local.x) < DOOR_STRIP_HALF_M:
			return false
	return true


static func shrub_points(field: Field, spots: Array[Dictionary], doors: Array[Vector3i]) -> PackedVector3Array:
	"""Where shrubs grow (world m, on the surface): a jittered grid over the hill, only on its lower slope, a fixed
	hash thinning them, never by a window or on a door's path."""
	var out: PackedVector3Array = PackedVector3Array()
	var box: Rect2i = field.box()
	var low: Vector2 = field.datum_m + Vector2(box.position)
	var x: float = low.x
	while x <= low.x + box.size.x:
		var z: float = low.y
		while z <= low.y + box.size.y:
			var at: Vector2 = Vector2(x + sin(z * 3.1) * 0.6, z + cos(x * 2.7) * 0.6)
			var h: float = field.height_m(at)
			var thin: bool = sin(at.x * 12.9 + at.y * 78.2) > 0.2
			if h > SHRUB_LOW_M and h < SHRUB_HIGH_M and not thin and clear_of_windows(at, spots) \
					and clear_of_doors(at, doors, field.datum_m):
				out.append(Vector3(at.x, h, at.y))
			z += SHRUB_SPACING_M
		x += SHRUB_SPACING_M
	return out


static func add_shrub(kit: MeshKit, palette_of: Dictionary, at: Vector3) -> void:
	"""One shrub on the slope at `at`."""
	var place: Transform3D = Transform3D(Basis.from_scale(Vector3(1.3, 0.8, 1.1)), at + Vector3.UP * 0.1)
	kit.add_sphere(palette_of[&"bush"], 0.4 + fmod(at.y, 0.3), place)


static func hearth_points(fittings: Fittings, cells: Dictionary, datum_m: Vector2) -> Array[Vector2]:
	"""The middles (world x, z) of the fitted hearths on the Surface standing on `cells` (a Mound's)."""
	var out: Array[Vector2] = []
	for row: int in fittings.count():
		if fittings.level_of(row) != Mound.SURFACE or fittings.item_of(row) != HEARTH \
				or fittings.state_of(row) != Fittings.FITTED:
			continue
		var floor_cells: PackedInt32Array = fittings.cells_of(row)
		if floor_cells.is_empty() or not cells.has(Vector2i(floor_cells[0], floor_cells[1])):
			continue
		var box: Rect2i = _box_of(floor_cells)
		out.append(datum_m + Vector2(box.position) + Vector2(box.size) / 2.0)
	return out


static func crown_point(field: Field, cells: PackedInt32Array, spots: Array[Dictionary]) -> Vector2:
	"""Where a Mound's tree stands: the middle of its cell deepest inside its outer walls, clear of every window
	(Vector2.INF when none is)."""
	var best: Vector2 = Vector2.INF
	var depth: float = -1.0
	for at: int in range(0, cells.size(), 2):
		var middle: Vector2 = field.datum_m + Vector2(cells[at] + 0.5, cells[at + 1] + 0.5)
		var inside: float = minf(field.inside_distance(middle), Field.CROWN_REACH_M)
		if inside > depth and clear_of_windows(middle, spots):
			depth = inside
			best = middle
	return best
