extends RefCounted
## A MOUND'S FRONT DOOR, DRAWN (decision 2002; BUILD-MOUND-011, -023; P-2001-8 (a), "Our own, oak default"). In its
## yard, on the door's front line, by how far its cells are built (the approved mockup's stages):
##   DUG       the round hole dug through the wall;
##   FRAMED    its frame: timber posts, the brick ring round the hole, and the curved timber eave over the front;
##   FITTED    the front built: a plastered face across the yard's width, the round door in the colour chosen (oak by
##             default) -- vertical planks held by two iron straps and opened by a ring pull at its side: our own
##             design, NO CENTRE KNOB (DEC-010's boundary) -- turf carried over the eave, a lantern, stone steps, and
##             the garden: flower beds and a bush either side, a bench, and a picket fence across the yard's foot.
## Every piece is a primitive gathered by material (demo_build_mound_mesh.gd); the palette is made once here.
## The door's frame: origin on the front line at the door's middle, y up, z out into the yard, x across (right-handed).
## Presentation only: no piece decides anything (BUILD-MOUND-023).

const Mound := preload("res://scripts/ui/build_mound.gd")
const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const MeshKit := preload("res://demo/build_panel/demo_build_mound_mesh.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")

## The mockup's door colours (sRGB), build_mound.gd COLOUR_* order: oak, green, red, blue.
const DOOR_COLOURS: Array[Color] = [Color8(0x7a, 0x52, 0x32), Color8(0x3f, 0x7a, 0x3a), Color8(0x8e, 0x2f, 0x25),
	Color8(0x2f, 0x55, 0x78)]
const PALETTE: Dictionary = {
	&"oak": Color8(0x7a, 0x52, 0x32), &"rib": Color8(0x5e, 0x3d, 0x22), &"stone": Color8(0x8d, 0x87, 0x7d),
	&"plaster": Color8(0xd9, 0xb4, 0x6a), &"brick": Color8(0x9a, 0x4a, 0x32), &"iron": Color8(0x2d, 0x2a, 0x26),
	&"hole": Color8(0x14, 0x0e, 0x09), &"bush": Color8(0x3f, 0x6b, 0x2c), &"leaf": Color8(0x4f, 0x7d, 0x34),
	&"bark": Color8(0x5a, 0x43, 0x30), &"pot": Color8(0xa0, 0x58, 0x3a), &"fence": Color8(0x6a, 0x54, 0x40),
	&"turf": Color8(0x5f, 0x8a, 0x3e), &"pink": Color8(0xe8, 0x6f, 0xa0), &"yellow": Color8(0xf2, 0xd0, 0x4b),
	&"violet": Color8(0x9b, 0x7e, 0xe0), &"white": Color8(0xf4, 0xf1, 0xe6), &"orange": Color8(0xe8, 0x74, 0x3b),
}
const FLOWERS: Array[StringName] = [&"pink", &"yellow", &"violet", &"white", &"orange"]
## The door: its round's middle and radius (m); the hole is a touch wider, the brick ring wider again.
const DOOR_UP_M: float = 1.05
const DOOR_R_M: float = 0.95
## The front's face: as wide as the yard, as high as the wall's lower part; the eave over it (the hill's own figures,
## demo_build_mound_field.gd, so the turf comes down onto it).
const FACE_HIGH_M: float = Field.FACE_HIGH_M
const POSTS_AT: Array[float] = [-2.9, -1.6, 1.6, 2.9]
const EAVE_R_M: float = Field.EAVE_R_M
const EAVE_FLAT: float = Field.EAVE_FLAT
const FENCE_OUT_M: float = 3.4
const LANTERN: Vector3 = Vector3(1.55, 2.3, 0.42)


static func palette() -> Dictionary:
	"""The parts' materials, made once: each PALETTE colour lit and matte, the four door colours, an emissive lantern
	and window glass, the window's sky disc, its light beam and pool (decision 2002 W12: daylight inside)."""
	var out: Dictionary = {}
	for key: StringName in PALETTE:
		out[key] = matte(PALETTE[key])
	for colour: int in DOOR_COLOURS.size():
		out[StringName("door_%d" % colour)] = matte(DOOR_COLOURS[colour])
	out[&"lamp"] = glowing(Color8(0xff, 0xd0, 0x8a), 1.6)
	out[&"glass"] = glowing(Color8(0xff, 0xc4, 0x77), 0.5)
	out[&"sky"] = unshaded(Color8(0xdf, 0xf0, 0xff), 1.0)
	out[&"beam"] = unshaded(Color8(0xcf, 0xe6, 0xff), 0.1)
	out[&"pool"] = unshaded(Color8(0xd8, 0xec, 0xff), 0.22)
	return out


static func matte(colour: Color) -> StandardMaterial3D:
	"""A lit matte material of `colour`, both faces drawn."""
	var out: StandardMaterial3D = StandardMaterial3D.new()
	out.albedo_color = colour
	out.roughness = 0.9
	out.cull_mode = BaseMaterial3D.CULL_DISABLED
	return out


static func glowing(colour: Color, energy: float) -> StandardMaterial3D:
	"""`colour`, lit and glowing at `energy`."""
	var out: StandardMaterial3D = matte(colour)
	out.emission_enabled = true
	out.emission = colour
	out.emission_energy_multiplier = energy
	return out


static func unshaded(colour: Color, alpha: float) -> StandardMaterial3D:
	"""`colour` unlit; see-through and added to what is behind it when `alpha` < 1."""
	var out: StandardMaterial3D = StandardMaterial3D.new()
	out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	out.albedo_color = Color(colour, alpha)
	out.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		out.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		out.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		out.no_depth_test = false
		out.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return out


static func frame_of(door: Vector3i, datum_m: Vector2) -> Transform3D:
	"""A door's frame (see the header) in world metres."""
	var middle: Vector2 = datum_m + Field.front_start(door) + Vector2(Mound.along(door.z)) * (Mound.DOOR_EDGES / 2.0)
	var z_axis: Vector3 = Vector3(Mound.step_of(door.z).x, 0.0, Mound.step_of(door.z).y)
	return Transform3D(Basis(Vector3.UP.cross(z_axis), Vector3.UP, z_axis), Vector3(middle.x, 0.0, middle.y))


static func local(frame: Transform3D, at: Vector3) -> Transform3D:
	"""A piece at `at` in the door's frame, turned with it."""
	return Transform3D(frame.basis, frame * at)


static func add_door(kit: MeshKit, palette_of: Dictionary, frame: Transform3D, stage: int, fitted: bool,
		colour: int) -> void:
	"""One door as far as it is built: its hole once dug, its frame once framed, its front once fitted."""
	if stage >= Mounds.DUG:
		kit.add_disc(palette_of[&"hole"], DOOR_R_M + 0.03, local(frame, Vector3(0.0, DOOR_UP_M, 0.02)))
	if stage >= Mounds.FRAMED:
		_add_frame(kit, palette_of, frame)
	if fitted:
		_add_face(kit, palette_of, frame, colour)
		_add_steps(kit, palette_of, frame)
		add_garden(kit, palette_of, frame)


static func _add_frame(kit: MeshKit, palette_of: Dictionary, frame: Transform3D) -> void:
	"""The posts, the brick ring round the hole and the curved timber eave."""
	for along: float in POSTS_AT:
		kit.add_box(palette_of[&"rib"], Vector3(0.22, FACE_HIGH_M, 0.26), local(frame, Vector3(along, FACE_HIGH_M / 2.0, 0.13)))
	kit.add_ring(palette_of[&"brick"], DOOR_R_M + 0.04, DOOR_R_M + 0.32, local(frame, Vector3(0.0, DOOR_UP_M, 0.08)))
	var eave: Transform3D = local(frame, Vector3(0.0, FACE_HIGH_M - 0.05, 0.3)) \
		* Transform3D(Basis.from_scale(Vector3(1.0, EAVE_FLAT, 1.0)), Vector3.ZERO)
	kit.add_arch(palette_of[&"rib"], EAVE_R_M, 0.26, eave)


static func _add_face(kit: MeshKit, palette_of: Dictionary, frame: Transform3D, colour: int) -> void:
	"""The plastered face, the turf over the eave, the round door (planks, two straps, a ring pull at its side; no
	knob in its middle) and the lantern."""
	var wide: float = Mound.DOOR_EDGES + 2.0 * Mound.YARD_SIDE_CELLS
	kit.add_box(palette_of[&"plaster"], Vector3(wide, FACE_HIGH_M, 0.2), local(frame, Vector3(0.0, FACE_HIGH_M / 2.0, 0.1)))
	var turf: Transform3D = local(frame, Vector3(0.0, FACE_HIGH_M + 0.12, 0.34)) \
		* Transform3D(Basis.from_scale(Vector3(1.0, EAVE_FLAT, 1.0)), Vector3.ZERO)
	kit.add_arch(palette_of[&"turf"], EAVE_R_M + 0.18, 0.42, turf)
	var door: Material = palette_of[StringName("door_%d" % clampi(colour, 0, DOOR_COLOURS.size() - 1))]
	kit.add_disc(door, DOOR_R_M, local(frame, Vector3(0.0, DOOR_UP_M, 0.23)))
	for plank: float in [-0.48, 0.0, 0.48]:
		kit.add_box(palette_of[&"rib"], Vector3(0.03, DOOR_R_M * 1.7, 0.02), local(frame, Vector3(plank, DOOR_UP_M, 0.24)))
	for up: float in [-0.4, 0.4]:
		kit.add_box(palette_of[&"iron"], Vector3(1.7, 0.07, 0.03), local(frame, Vector3(0.0, DOOR_UP_M + up, 0.25)))
	kit.add_ring(palette_of[&"iron"], 0.07, 0.1, local(frame, Vector3(0.62, DOOR_UP_M, 0.27)), 12)
	kit.add_ring(palette_of[&"rib"], DOOR_R_M - 0.02, DOOR_R_M + 0.04, local(frame, Vector3(0.0, DOOR_UP_M, 0.24)))
	kit.add_box(palette_of[&"lamp"], Vector3(0.2, 0.32, 0.2), local(frame, LANTERN))
	kit.add_box(palette_of[&"iron"], Vector3(0.06, 0.06, 0.3), local(frame, LANTERN + Vector3(0.0, 0.2, -0.15)))


static func _add_steps(kit: MeshKit, palette_of: Dictionary, frame: Transform3D) -> void:
	"""Three stone steps out from the door."""
	for k: int in 3:
		var at: Vector3 = Vector3(0.08 if k % 2 == 1 else -0.06, 0.07, 0.6 + k * 0.8)
		kit.add_box(palette_of[&"stone"], Vector3(1.8 - k * 0.1, 0.14, 0.62), local(frame, at))


static func add_garden(kit: MeshKit, palette_of: Dictionary, frame: Transform3D) -> void:
	"""Flower beds and a bush either side of the steps, a bench, and a picket fence across the yard's foot with a gap
	for the path (all inside the yard and just past it: none on a window's slope)."""
	for side: float in [-2.2, 2.3]:
		_add_bed(kit, palette_of, frame, side)
	kit.add_box(palette_of[&"oak"], Vector3(1.4, 0.12, 0.45), local(frame, Vector3(-2.3, 0.45, 2.3)))
	for leg: float in [-2.85, -1.75]:
		kit.add_box(palette_of[&"oak"], Vector3(0.1, 0.45, 0.4), local(frame, Vector3(leg, 0.22, 2.3)))
	_add_fence(kit, palette_of, frame)


static func _add_bed(kit: MeshKit, palette_of: Dictionary, frame: Transform3D, along: float) -> void:
	"""One flower bed: nine flowers and a bush, placed by a fixed pattern."""
	for k: int in 9:
		var r: float = float((k * 37) % 10) / 10.0
		var q: float = float((k * 53) % 10) / 10.0
		var at: Vector3 = Vector3(along + (r - 0.5) * 1.4, 0.25 + q * 0.2, 0.7 + q * 1.2)
		kit.add_sphere(palette_of[FLOWERS[k % FLOWERS.size()]], 0.12 + r * 0.06, local(frame, at), 8)
	var bush: Transform3D = local(frame, Vector3(along, 0.35, 1.3)) \
		* Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), Vector3.ZERO)
	kit.add_sphere(palette_of[&"bush"], 0.55, bush)


static func _add_fence(kit: MeshKit, palette_of: Dictionary, frame: Transform3D) -> void:
	"""Pickets half a metre apart across the yard's foot, and two rails each side of the path's gap."""
	var reach: float = Mound.YARD_SIDE_CELLS + Mound.DOOR_EDGES / 2.0 + 0.5
	var along: float = -reach
	while along <= reach + 0.01:
		if absf(along) > 0.9:
			kit.add_box(palette_of[&"fence"], Vector3(0.08, 0.8, 0.08), local(frame, Vector3(along, 0.4, FENCE_OUT_M)))
		along += 0.5
	var rail: float = reach - 0.9
	for side: float in [-1.0, 1.0]:
		for up: float in [0.35, 0.65]:
			var at: Vector3 = Vector3(side * (0.9 + rail / 2.0), up, FENCE_OUT_M)
			kit.add_box(palette_of[&"fence"], Vector3(rail, 0.06, 0.05), local(frame, at))


static func lantern_at(frame: Transform3D) -> Vector3:
	"""Where a fitted door's lantern hangs (world m): its light stands there."""
	return frame * (LANTERN + Vector3(0.0, -0.05, 0.25))


static func station_of(door: Vector3i, datum_m: Vector2) -> Vector2:
	"""Where a builder stands in a door's yard (world x, z): on the path two metres out, before the fence."""
	var at: Vector3 = frame_of(door, datum_m) * Vector3(0.0, 0.0, 2.0)
	return Vector2(at.x, at.z)
