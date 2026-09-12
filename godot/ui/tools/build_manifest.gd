extends SceneTree
## Write `res://ui/ui_art_manifest.json` from the declared registry and the actual rasters.
##
## ART-UI-11 wants stable IDs, provenance and *actual* bounds -- not the bounds someone
## intended. Every number below is measured by rendering the real source: the declared
## document size, the opaque bounding box inside it, and the source's SHA-256. A silently
## re-cropped or re-coloured icon therefore changes the manifest, which is reviewable.
##
## Run: `godot --headless --path godot --script ui/tools/build_manifest.gd`

const ART: GDScript = preload("res://ui/ui_art.gd")

const OUTPUT: String = "res://ui/ui_art_manifest.json"


func _init() -> void:
	"""Measure every declared asset, add the frame margins, and write the manifest."""
	var assets: Array = []
	for index: int in ART.asset_count():
		var entry: Dictionary = _measure(index)
		if entry.is_empty():
			push_error("manifest: could not measure %s" % ART.asset_id_of(index))
			quit(1)
			return
		assets.append(entry)
	var document: Dictionary = {
		"schema": "redwall.ui.art.manifest/1",
		"owner": "SET-UX-VIS-002 revision 2 section 2.4, ART-UI-03 to 08 and ART-UI-11",
		"origin": "Original hand-authored SVG for this repository. No paid generation.",
		"licence": "Same as the repository.",
		"decorative_pigments": ART.DECORATIVE_PIGMENTS,
		"frames": _frames(),
		"assets": assets,
	}
	var status: int = _write(document)
	print("manifest: %s assets=%d (%d)" % [OUTPUT, assets.size(), status])
	quit(0 if status == OK else 1)


func _measure(index: int) -> Dictionary:
	"""One manifest row: identity, source, sizes and the measured opaque bounds."""
	var path: String = ART.source_path_of(index)
	var sizes: PackedInt32Array = ART.optical_sizes_of(index)
	var image: Image = ART.rasterise(path, sizes[0])
	if image == null:
		return {}
	var used: Rect2i = image.get_used_rect()
	return {
		"id": String(ART.asset_id_of(index)),
		"source": path,
		"category": String(ART.CATEGORY_KEYS[ART.category_of(index)]),
		"optical_widths": Array(sizes),
		"document": [image.get_width(), image.get_height()],
		"opaque_bounds": [used.position.x, used.position.y, used.size.x, used.size.y],
		"sha256": FileAccess.get_sha256(path),
	}


func _frames() -> Array:
	"""The stretch margins and non-stretching corner extents of the five silhouettes."""
	var rows: Array = []
	for frame: int in ART.frame_count():
		var corners: Array = []
		for corner: int in 4:
			var size: Vector2i = ART.frame_corner_size(frame, corner)
			corners.append([size.x, size.y])
		rows.append({
			"id": String(ART.FRAME_KEYS[frame]),
			"stretch_margins_trbl": [
				ART.frame_edge_inset(frame, 0), ART.frame_edge_inset(frame, 1),
				ART.frame_edge_inset(frame, 2), ART.frame_edge_inset(frame, 3),
			],
			"corner_extents_tl_tr_bl_br": corners,
		})
	return rows


func _write(document: Dictionary) -> int:
	"""Serialise the manifest with a trailing newline so diffs stay clean."""
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t") + "\n")
	file.close()
	return OK
