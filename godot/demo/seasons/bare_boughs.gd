extends RefCounted
## A staged tree's BARE BOUGHS: its own mesh with the leaf triangles taken out. Decision 0551. Presentation only.
##
## A tree with every leaf down could be drawn by the tree shader discarding each leaf texel -- but a shader that
## discards runs its fragment in the depth prepass and in every shadow cascade, over the whole of every crown in
## the woods, all winter. Measured, that was the season's whole cost. So a bare tree is drawn as this mesh instead:
## the same vertices, only the triangles that are not leaf (by the model's own texture: the same test the shader
## makes, season_leaves.gdshaderinc `leafness`). Made once per model, from its own glTF material's albedo, at boot
## (the prewarm) -- never per tree and never per frame.
##
## A triangle is LEAF when its centre's texel is, or more than one of its corners' are (`is_bark`) -- unless it lies
## wholly in the model's bottom ROOTS_SHARE (roots and the trunk's foot, whose moss is as green as a leaf: the
## shader keeps it too, season_leaves.gdshaderinc ROOTS_TOP_M). The leaf texels
## left on the kept triangles are still dropped by the tree shader, so a bare tree drawn this way looks the same as
## the whole mesh with every leaf discarded -- it only has far fewer leaf triangles to discard.

## A texel is leaf at or above this linear green-over-red ratio (about the middle of the shader's 1.08-1.35 ramp).
const LEAF_RATIO: float = 1.2
## The albedo is read at this size (a 2048 texture's leaf clumps are tens of texels across).
const SAMPLE_PX: int = 512
## The bottom share of the model's height that is roots and trunk foot (~1.6 m of a 13 m oak): never leaf. The
## shader's mask eases to leaf over the next ROOTS_BLEND_SHARE (season_leaves.gdshaderinc `roots_y`).
const ROOTS_SHARE: float = 0.12
const ROOTS_BLEND_SHARE: float = 0.08


static func bark_only(mesh: Mesh) -> ArrayMesh:
	"""`mesh` (one surface, its own textured material) without its leaf triangles, carrying the same material;
	null when it has no albedo to read or nothing would be left."""
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	var image: Image = albedo_image(material)
	if image == null:
		return null
	var arrays: Array = mesh.surface_get_arrays(0)
	var kept: PackedInt32Array = bark_triangles(arrays, image)
	if kept.is_empty():
		return null
	arrays[Mesh.ARRAY_INDEX] = kept
	var bare := ArrayMesh.new()
	bare.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	bare.surface_set_material(0, material)
	return bare


static func albedo_image(material: BaseMaterial3D) -> Image:
	"""The material's albedo as a readable SAMPLE_PX image (decompressed), or null."""
	if material == null or material.albedo_texture == null:
		return null
	var image: Image = material.albedo_texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	image.resize(SAMPLE_PX, SAMPLE_PX, Image.INTERPOLATE_BILINEAR)
	return image


static func bark_triangles(arrays: Array, image: Image) -> PackedInt32Array:
	"""The index list of the surface's triangles that are not leaf (see the header)."""
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var roots_top: float = roots_top_y(verts)
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty():
		index.resize(uvs.size())
		for k: int in uvs.size():
			index[k] = k
	var kept := PackedInt32Array()
	for k: int in range(0, index.size() - 2, 3):
		var a: Vector2 = uvs[index[k]]
		var b: Vector2 = uvs[index[k + 1]]
		var c: Vector2 = uvs[index[k + 2]]
		var top: float = maxf(verts[index[k]].y, maxf(verts[index[k + 1]].y, verts[index[k + 2]].y))
		if top <= roots_top or is_bark(image, a, b, c):
			kept.append(index[k])
			kept.append(index[k + 1])
			kept.append(index[k + 2])
	return kept


static func roots_top_y(verts: PackedVector3Array) -> float:
	"""The model height (its own units) below which a triangle is roots or trunk foot: ROOTS_SHARE up its bound."""
	if verts.is_empty():
		return 0.0
	var low: float = verts[0].y
	var high: float = verts[0].y
	for v: Vector3 in verts:
		low = minf(low, v.y)
		high = maxf(high, v.y)
	return low + (high - low) * ROOTS_SHARE


static func roots_mask(mesh: Mesh) -> Vector2:
	"""The shader's `roots_y` for a model: the top of its roots (ROOTS_SHARE up its bound, its own units) and the
	height over which its leaves begin (ROOTS_BLEND_SHARE of it)."""
	var bound: AABB = mesh.get_aabb()
	return Vector2(bound.position.y + bound.size.y * ROOTS_SHARE, maxf(bound.size.y * ROOTS_BLEND_SHARE, 0.0001))


static func is_bark(image: Image, a: Vector2, b: Vector2, c: Vector2) -> bool:
	"""Whether a triangle (its UVs) is kept as bark: its centre is not leaf and at most one corner is. (Stricter tests
	-- no leaf at any corner or edge -- shred the trunks, whose bark the texture paints with moss.)"""
	var corners: int = int(is_leaf(image, a)) + int(is_leaf(image, b)) + int(is_leaf(image, c))
	return corners <= 1 and not is_leaf(image, (a + b + c) / 3.0)


static func is_leaf(image: Image, uv: Vector2) -> bool:
	"""Whether the texel at `uv` (wrapped) is leaf: green over red in linear light, and green over blue."""
	var size: Vector2i = image.get_size()
	var x: int = posmod(floori(uv.x * float(size.x)), size.x)
	var y: int = posmod(floori(uv.y * float(size.y)), size.y)
	var texel: Color = image.get_pixel(x, y).srgb_to_linear()
	return texel.g >= texel.b and texel.g >= texel.r * LEAF_RATIO
