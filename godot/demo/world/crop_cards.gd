extends RefCounted
## Plants on the carded crop beds, as alpha-cutout cards. Decision 0196 (live demo). Presentation only.
##
## The grain and roots L0s shatter (the asset library README's "Known problems"), so
## tools/make_demo_crop_cards.py stages them as a bare bed plus an RGBA atlas of the REAL plants,
## rendered from the high-poly sources. This file plants that atlas: each plant is three quads
## standing round a small triangle, all plants of a bed are one MultiMesh, and which atlas cell a plant shows travels in the
## instance's custom data. Standing cards cannot show a bed from above, which is where an RTS
## camera looks from, so the roots bed also lays each plant's own top-down render flat over it.
## The wheat does not: a dense stand of narrow cards covers its own top, and flat canopy patches
## over it were tried and read as shelves.
##
## Placement is deterministic (a fixed seed per crop) and in the bed's own units -- the source
## model's -- because the cards are a child of the bed and scale with it. The layouts follow the
## sources: wheat is a dense jittered stand; roots are two back rows of five turnips and four
## front rows of eight carrots, as measured from the roots high-poly's top render.

const CARD_SHADER := preload("res://demo/world/crop_card.gdshader")

## Quads per plant, evenly spaced in yaw.
const PLANES: int = 3
## Cards sink this far into the soil (bed units) so no plant floats on a bump.
const SINK: float = 0.012
## Each plane stands this fraction of the card width off the plant's centre, so the three form
## a small open triangle rather than an asterisk: seen from an RTS camera, planes that all cross
## at one point read as stars.
const PLANE_OFFSET: float = 0.18
## Plants lean up to this far (radians) in a random direction, so no two stands line up.
const MAX_LEAN: float = 0.14
## make_demo_crop_cards.py cuts the source's plants out of the bed by colour, which leaves holes
## in the soil where they stood. A dark soil underlay just below the soil surface fills them.
## Near-black umber, matched by eye to the bed's soil under the demo's light.
const SOIL_COLOR: Color = Color(0.13, 0.095, 0.075)
const UNDERLAY_DROP: float = 0.006
## Plants keep this far inside the frame's inner edge (bed units).
const INNER_MARGIN: float = 0.03

## Per-crop layout. `grid`: a jittered n x n stand. `rows`: [kind, v, count] across the bed,
## v from the back (-Z) edge of the inner area to the front, each row spread evenly across it.
const LAYOUTS: Dictionary = {
	&"crop_grain_ripe": {
		"seed": 4101, "grid": 19, "kind": "wheat", "jitter": 0.45, "scale": Vector2(0.84, 1.08),
	},
	&"crop_roots_ripe": {
		"seed": 4102, "jitter": 0.12, "scale": Vector2(0.88, 1.08),
		"rows": [
			["turnip", 0.1, 5], ["turnip", 0.26, 5],
			["carrot", 0.47, 8], ["carrot", 0.6, 8], ["carrot", 0.75, 8], ["carrot", 0.9, 8],
		],
		"tops": {"per_plant": true, "height": Vector2(0.5, 0.58)},
	},
}


static func has_layout(key: StringName) -> bool:
	"""Whether `key` is planted with cards."""
	return LAYOUTS.has(key)


static func inner_rect(inner: Array, reach: float) -> Rect2:
	"""Where plant centres may stand: the manifest's [x0, x1, z0, z1] inner area, shrunk by the
	margin and by `reach`, how far a plant's leaves spread from its centre."""
	var rect := Rect2(float(inner[0]), float(inner[2]), float(inner[1]) - float(inner[0]),
		float(inner[3]) - float(inner[2]))
	return rect.grow(-INNER_MARGIN - reach)


static func plant_reach(layout: Dictionary, cell_m: Array) -> float:
	"""How far a plant's card can reach sideways from its centre at its largest scale, in bed units.

	Half the card width (plus the planes' offset from the centre) at the largest scale. The
	wheat is kept wholly inside the frame; the root rows are measured from the source, whose
	leaves overhang each other but not the frame, so they use a quarter of that.
	"""
	var scale_range: Vector2 = layout["scale"]
	var reach: float = float(cell_m[0]) * (0.5 + PLANE_OFFSET) * scale_range.y
	return reach if layout.has("grid") else reach * 0.25


static func _plant(rng: RandomNumberGenerator, at: Vector2, kind: String, layout: Dictionary,
		kinds: Dictionary) -> Dictionary:
	"""One plant: where, which way, how big, and which atlas cell of its kind."""
	var cells: Array = kinds.get(kind, [0])
	var scale_range: Vector2 = layout["scale"]
	return {
		"at": at, "yaw": rng.randf_range(-PI, PI), "kind": kind,
		"scale": rng.randf_range(scale_range.x, scale_range.y),
		"lean": Vector2(rng.randf_range(-MAX_LEAN, MAX_LEAN), rng.randf_range(-MAX_LEAN, MAX_LEAN)),
		"variant": int(cells[rng.randi_range(0, cells.size() - 1)]),
	}


static func _grid(layout: Dictionary, rect: Rect2, kinds: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""A jittered n x n stand filling the rect."""
	var out: Array[Dictionary] = []
	var n: int = layout["grid"]
	var jitter: float = layout["jitter"]
	for iz: int in n:
		for ix: int in n:
			var u: float = clampf((ix + 0.5 + rng.randf_range(-jitter, jitter)) / n, 0.0, 1.0)
			var v: float = clampf((iz + 0.5 + rng.randf_range(-jitter, jitter)) / n, 0.0, 1.0)
			var at: Vector2 = rect.position + rect.size * Vector2(u, v)
			out.append(_plant(rng, at, layout["kind"], layout, kinds))
	return out


static func _rows(layout: Dictionary, rect: Rect2, kinds: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""Rows across the rect, evenly spaced along each, jittered a little."""
	var out: Array[Dictionary] = []
	var jitter: float = layout["jitter"]
	for row: Array in layout["rows"]:
		var count: int = row[2]
		for i: int in count:
			var u: float = clampf((i + 0.5 + rng.randf_range(-jitter, jitter)) / count, 0.0, 1.0)
			var v: float = clampf(float(row[1]) + rng.randf_range(-jitter, jitter) * 0.1, 0.0, 1.0)
			var at: Vector2 = rect.position + rect.size * Vector2(u, v)
			out.append(_plant(rng, at, row[0], layout, kinds))
	return out


static func placements(key: StringName, cards: Dictionary) -> Array[Dictionary]:
	"""Every plant of a carded bed: {at (bed XZ), yaw, scale, lean, kind, variant}. Deterministic."""
	var layout: Dictionary = LAYOUTS[key]
	var kinds: Dictionary = cards["kinds"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout["seed"])
	var rect: Rect2 = inner_rect(cards["inner"], plant_reach(layout, cards["cell_m"]))
	if layout.has("grid"):
		return _grid(layout, rect, kinds, rng)
	return _rows(layout, rect, kinds, rng)


static func _plant_tops(tops: Dictionary, plants: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	"""One flat top per plant, over it, turned and scaled with it, showing the same plant."""
	var out: Array[Dictionary] = []
	var heights: Vector2 = tops["height"]
	for plant: Dictionary in plants:
		out.append({
			"at": plant["at"], "yaw": plant["yaw"], "scale": plant["scale"],
			"height": rng.randf_range(heights.x, heights.y) * float(plant["scale"]),
			"variant": plant["variant"],
		})
	return out


static func top_placements(key: StringName, plants: Array[Dictionary]) -> Array[Dictionary]:
	"""Every flat top of a bed: {at, yaw, scale, height (fraction of card height), variant}."""
	var layout: Dictionary = LAYOUTS[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout["seed"]) + 1
	return _plant_tops(layout["tops"], plants, rng)


static func top_mesh(size: float) -> ArrayMesh:
	"""A flat square on y = 0. UV v is 0 at its -Z edge, as the top-down renders are framed."""
	var half: float = size * 0.5
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half),
		Vector3(half, 0.0, half), Vector3(-half, 0.0, half)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func card_mesh(cell: Vector2) -> ArrayMesh:
	"""PLANES quads round a small triangle, `cell` wide and tall, on y = 0. UV v is 0 at the top."""
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for plane: int in PLANES:
		var angle: float = PI * plane / PLANES
		var across := Vector3(cos(angle), 0.0, sin(angle)) * cell.x * 0.5
		var off := Vector3(-sin(angle), 0.0, cos(angle)) * cell.x * PLANE_OFFSET * (1.0 if plane % 2 == 0 else -1.0)
		var up := Vector3.UP * cell.y
		var base: int = verts.size()
		verts.append_array([off - across, off + across, off + across + up, off - across + up])
		uvs.append_array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func card_material(texture: Texture2D, variants: int, flat: bool) -> ShaderMaterial:
	"""The alpha-scissor foliage material over an atlas (`flat`: a top, so no base shading)."""
	var material := ShaderMaterial.new()
	material.shader = CARD_SHADER
	material.set_shader_parameter(&"atlas", texture)
	material.set_shader_parameter(&"variants", float(variants))
	if flat:
		material.set_shader_parameter(&"base_shade", 1.0)
	return material


static func _plant_basis(plant: Dictionary) -> Basis:
	"""Yaw, then a small lean, then the plant's uniform scale."""
	var lean: Vector2 = plant["lean"]
	var tilt := Basis.from_euler(Vector3(lean.y, 0.0, lean.x))
	return (tilt * Basis(Vector3.UP, float(plant["yaw"]))).scaled(Vector3.ONE * float(plant["scale"]))


static func _instances(mesh: Mesh, rows: Array[Transform3D], variants: PackedInt32Array, node_name: String) -> MultiMeshInstance3D:
	"""A MultiMesh of `mesh` at these transforms, each showing its atlas cell."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = rows.size()
	for i: int in rows.size():
		multimesh.set_instance_transform(i, rows[i])
		multimesh.set_instance_custom_data(i, Color(float(variants[i]), 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


static func _card_node(cards: Dictionary, texture: Texture2D, plants: Array[Dictionary]) -> MultiMeshInstance3D:
	"""The standing cards of every plant."""
	var cell_m: Array = cards["cell_m"]
	var mesh: ArrayMesh = card_mesh(Vector2(float(cell_m[0]), float(cell_m[1])))
	mesh.surface_set_material(0, card_material(texture, int(cards["variants"]), false))
	var soil: float = float(cards["soil_y"]) - SINK
	var rows: Array[Transform3D] = []
	var variants := PackedInt32Array()
	for plant: Dictionary in plants:
		var at: Vector2 = plant["at"]
		rows.append(Transform3D(_plant_basis(plant), Vector3(at.x, soil, at.y)))
		variants.append(int(plant["variant"]))
	return _instances(mesh, rows, variants, "Cards")


static func _top_node(key: StringName, cards: Dictionary, texture: Texture2D, plants: Array[Dictionary]) -> MultiMeshInstance3D:
	"""The flat tops, laid over the standing cards."""
	var tops: Dictionary = cards["tops"]
	var mesh: ArrayMesh = top_mesh(float((tops["cell_m"] as Array)[0]))
	mesh.surface_set_material(0, card_material(texture, int(tops["variants"]), true))
	var card_height: float = float((cards["cell_m"] as Array)[1])
	var soil: float = float(cards["soil_y"]) - SINK
	var rows: Array[Transform3D] = []
	var variants := PackedInt32Array()
	for top: Dictionary in top_placements(key, plants):
		var at: Vector2 = top["at"]
		var basis := Basis(Vector3.UP, float(top["yaw"])).scaled(Vector3.ONE * float(top["scale"]))
		rows.append(Transform3D(basis, Vector3(at.x, soil + float(top["height"]) * card_height, at.y)))
		variants.append(int(top["variant"]))
	return _instances(mesh, rows, variants, "Tops")


static func soil_underlay(cards: Dictionary) -> MeshInstance3D:
	"""A dark quad just under the soil surface, over the inner area, filling the cut holes."""
	var inner: Array = cards["inner"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(inner[1]) - float(inner[0]), float(inner[3]) - float(inner[2])) + Vector2.ONE * 0.06
	var material := StandardMaterial3D.new()
	material.albedo_color = SOIL_COLOR
	material.roughness = 1.0
	plane.material = material
	var underlay := MeshInstance3D.new()
	underlay.name = "SoilUnderlay"
	underlay.mesh = plane
	underlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underlay.position = Vector3((float(inner[0]) + float(inner[1])) * 0.5, float(cards["soil_y"]) - UNDERLAY_DROP,
		(float(inner[2]) + float(inner[3])) * 0.5)
	return underlay


static func build(key: StringName, cards: Dictionary, texture: Texture2D, top_texture: Texture2D) -> Node3D:
	"""One bed's plants, in bed units, from the manifest's `cards` block: cards, and tops if any."""
	var plants: Array[Dictionary] = placements(key, cards)
	var node := Node3D.new()
	node.name = "Plants"
	node.add_child(soil_underlay(cards))
	node.add_child(_card_node(cards, texture, plants))
	if top_texture != null and cards.has("tops") and (LAYOUTS[key] as Dictionary).has("tops"):
		node.add_child(_top_node(key, cards, top_texture, plants))
	return node
