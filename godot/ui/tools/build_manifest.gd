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
const GEOMETRY: GDScript = preload("res://ui/ui_frame_geometry.gd")

const OUTPUT: String = "res://ui/ui_art_manifest.json"

## What the frame numbers mean, written into the manifest because both were misread once and
## a bare pair of integers cannot say which axis it belongs to. `ui_frame_geometry.gd` is the
## executable version of this text; ADR 0077 is the reasoning.
const PLACEMENT: Dictionary = {
	"owner": "res://ui/ui_frame_geometry.gd",
	"builder": "res://ui/ui_frame_builder.gd",
	"decision": "docs/decisions/0077-container-frame-placement-contract.md",
	"stretch_margin_means": "Thickness measured ACROSS the strip: the height of the top and "
		+ "bottom strips, the width of the left and right strips. Not a square extent, and "
		+ "not a distance between the panel edge and the strip -- every strip is flush with "
		+ "the panel edge.",
	"corner_extent_means": "The exact draw size of that corner, equal to its source document. "
		+ "Not an outer bound with bleed and not a nine-patch margin. Corners never scale.",
	"assembly_rule": "Corners own the corners. Each strip then runs between the two corner "
		+ "extents that bracket it, so no strip is drawn underneath a corner motif, and is "
		+ "scaled along its run only.",
	"minimum_panel_size_means": "The smallest panel this silhouette can dress: both corner "
		+ "pairs plus one pixel of edge run. A smaller panel is refused by name, never "
		+ "clamped.",
}


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
		"frame_placement": PLACEMENT,
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
	"""The stretch margins, corner extents and smallest dressable panel of each silhouette."""
	var rows: Array = []
	for frame: int in ART.frame_count():
		var corners: Array = []
		for corner: int in 4:
			var size: Vector2i = ART.frame_corner_size(frame, corner)
			corners.append([size.x, size.y])
		var minimum: Vector2 = GEOMETRY.minimum_size_of(frame)
		rows.append({
			"id": String(ART.FRAME_KEYS[frame]),
			"stretch_margins_trbl": [
				ART.frame_edge_inset(frame, 0), ART.frame_edge_inset(frame, 1),
				ART.frame_edge_inset(frame, 2), ART.frame_edge_inset(frame, 3),
			],
			"corner_extents_tl_tr_bl_br": corners,
			"minimum_panel_size": [int(minimum.x), int(minimum.y)],
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
