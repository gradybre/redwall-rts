extends "../../../../../tools/bake_underground_matrices.gd"
## Actual cast comparison: original Skeleton3D, exact finite matrix pose, and adjacent-frame interpolation.
## Root placement/camera/lighting are visual witnesses, not authoritative physical inputs.

var _matrix_values: PackedFloat32Array = PackedFloat32Array()
var _grounding_values: PackedFloat32Array = PackedFloat32Array()
var _frame_first_scalar: bool = false
var _saving_frame: bool = false
var _witness_skins: Array = []
var _witness_item_transform: Transform3D = Transform3D.IDENTITY
var _preview: Node3D = null
var _preview_age: int = -1


func _begin_case(request: Dictionary) -> void:
	"""Retain only the current finite clip palette and one exact native source pose for the comparison."""
	_matrix_values.clear()
	_grounding_values.clear()
	_witness_skins.clear()
	super._begin_case(request)


func _write_float(value: float) -> void:
	"""The same binary32 values go to the streamed file and the preview's immutable shared palette."""
	super._write_float(value)
	if _saving_frame:
		if _frame_first_scalar:
			_grounding_values.append(value)
			_frame_first_scalar = false
		else:
			_matrix_values.append(value)


func _capture_pose() -> void:
	"""Snapshot the actual native source mid-clip without seeking or reconstructing its procedural tail."""
	_saving_frame = true
	_frame_first_scalar = true
	super._capture_pose()
	_saving_frame = false
	@warning_ignore("integer_division") var middle: int = _steps / 2
	if _error == "" and _step == middle:
		for part: Dictionary in _body:
			var transforms: Array[Transform3D] = []
			for bind: int in part.binds.indices.size():
				transforms.append(_skeleton.get_bone_global_pose(part.binds.indices[bind]) * part.binds.poses[bind])
			_witness_skins.append(transforms)
		if not _items.is_empty():
			_witness_item_transform = _item_instance(_items[0]).transform


func _end_case() -> void:
	"""Pause before source disposal so both render paths share the real original meshes and material resources."""
	_error = _build_preview()
	if _error != "":
		_finish()
		return
	_preview_age = 0


func _process(delta: float) -> bool:
	"""Wait for actual rendered frames, save the visible comparison, then resume the unchanged capture lifecycle."""
	if _preview_age >= 0:
		_restore_native_palette()
		_preview_age += 1
		if _preview_age == 6:
			call_deferred("_save_preview")
		return false
	return super._process(delta)


func _build_preview() -> String:
	"""Three columns compare actual source, exact matrix frame, and a half-step affine interpolation."""
	_preview = Node3D.new()
	root.add_child(_preview)
	root.size = Vector2i(1280, 720)
	var height: float = _actor.height_m
	_build_world(height)
	_restore_source_pose(height)
	var content: Dictionary = _preview_content()
	var palette: MatrixActor.Palette = MatrixActor.Palette.new()
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(_matrix_values.to_byte_array())
	hashing.update(_grounding_values.to_byte_array())
	var code: StringName = palette.configure(hashing.finish().hex_encode(), _steps, content.counts, _matrix_values, _grounding_values)
	if code != &"":
		return String(code)
	code = _make_preview_actor(palette, content.meshes, content.materials, 0.0, 0, height)
	if code == &"":
		code = _make_preview_actor(palette, content.meshes, content.materials, -1.2 * height, 32768, height)
	_restore_source_item()
	_add_labels()
	return String(code)


func _preview_content() -> Dictionary:
	"""Copy only resource references and small descriptors; meshes and materials remain their actual originals."""
	var meshes: Array[Mesh] = []
	var materials: Array[Material] = []
	var counts: PackedInt32Array = PackedInt32Array()
	for part: Dictionary in _body:
		meshes.append(part.node.mesh)
		materials.append(part.node.material_override)
		counts.append(part.binds.indices.size())
	for item: Dictionary in _items:
		meshes.append(item.mesh)
		materials.append(_item_instance(item).material_override)
		counts.append(0)
	return {"meshes": meshes, "materials": materials, "counts": counts}


func _restore_source_pose(height: float) -> void:
	"""Use the actual captured engine matrices in the original SkinReference, without re-evaluating animation."""
	_actor.transform = Transform3D(FORWARD_CONVERSION.basis, Vector3(1.2 * height, 0, 0)) * _actor.transform
	_restore_native_palette()
	var marker: Node3D = _actor.get("_marker") as Node3D
	if marker != null:
		marker.visible = false
	_restore_source_item()


func _restore_native_palette() -> void:
	"""Parent transform invalidation must not replace the actual retained native source skin during the still witness."""
	for part: int in _body.size():
		var instance: MeshInstance3D = _body[part].node
		var rid: RID = instance.get_skin_reference().get_skeleton()
		for bind: int in _witness_skins[part].size():
			RenderingServer.skeleton_bone_set_transform(rid, bind, _witness_skins[part][bind])


func _restore_source_item() -> void:
	"""Only the selected original attachment is visible; the whole measurement catalog is not a carried load."""
	for path: String in ["_load", "_held", "_tool"]:
		var node: MeshInstance3D = _actor.get(path) as MeshInstance3D
		if node != null:
			node.visible = false
	if not _items.is_empty():
		var item: MeshInstance3D = _item_instance(_items[0])
		item.transform = _witness_item_transform
		item.visible = true


func _make_preview_actor(palette: MatrixActor.Palette, meshes: Array[Mesh], materials: Array[Material],
		x: float, weight: int, height: float) -> StringName:
	"""Only explicit visual placement differs; all native geometry, material and finite content stay shared."""
	var node: MatrixActor = MatrixActor.new()
	_preview.add_child(node)
	node.position.x = x
	var bounds: Array[AABB] = []
	for part: int in meshes.size():
		bounds.append(AABB(Vector3.ONE * -4.0 * height, Vector3.ONE * 8.0 * height))
	var code: StringName = node.configure(palette, meshes, palette.source_digest(), bounds, materials)
	if code != &"":
		return code
	var visible: int = (1 << _body.size()) - 1
	if not _items.is_empty():
		visible |= 1 << _body.size()
	code = node.set_parts_visible(visible)
	if code != &"":
		return code
	@warning_ignore("integer_division") var middle: int = _steps / 2
	return node.apply_pose(PackedInt32Array([middle, mini(middle + 1, _steps - 1), weight, middle, middle, 0, 65536]))


func _build_world(height: float) -> void:
	"""A neutral lit contact plane keeps silhouette, fur/material response and grounded feet visible."""
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.095, 0.105, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.78, 0.82, 0.9)
	environment.environment.ambient_light_energy = 0.6
	_preview.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.7
	_preview.add_child(light)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8, 8) * height
	ground.mesh = plane
	_preview.add_child(ground)
	var camera: Camera3D = Camera3D.new()
	_preview.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2 * height
	camera.position = Vector3(0.0, 1.0, -3.4) * height
	camera.look_at(Vector3(0, 0.58, 0) * height, Vector3.UP)
	camera.current = true


func _add_labels() -> void:
	"""Label the exact scope in the image itself; a still frame does not establish continuous clearance."""
	var layer: CanvasLayer = CanvasLayer.new()
	_preview.add_child(layer)
	for index: int in 3:
		var label: Label = Label.new()
		label.position = Vector2(45 + index * 425, 35)
		label.add_theme_font_size_override("font_size", 20)
		label.text = ["Original native actor", "Grounded matrix pose", "Grounded half-step"][index]
		layer.add_child(label)
	var caption: Label = Label.new()
	caption.position = Vector2(35, 665)
	caption.add_theme_font_size_override("font_size", 16)
	caption.text = _row.id + " | Real source assets; native comparison; no gameplay clearance qualification"
	layer.add_child(caption)


func _save_preview() -> void:
	"""Capture the actual viewport after rendering, then destroy every preview-owned native object."""
	var path: String = _out.get_base_dir().path_join(_row.id + ".png")
	if FileAccess.file_exists(path) or root.get_texture().get_image().save_png(path) != OK:
		_error = "PALETTE_PREVIEW_OUTPUT"
	_preview.free()
	_preview = null
	_preview_age = -1
	_matrix_values.clear()
	_grounding_values.clear()
	_witness_skins.clear()
	if _error != "":
		_finish()
	else:
		super._end_case()
