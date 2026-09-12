extends SceneTree
## Rasterise every `godot/ui/` SVG source to PNG at its declared optical sizes.
##
## ART-UI-11 asks for editable sources plus individual exports. The SVG files under
## `res://ui/` are the editable sources; this script is the only producer of the review
## PNGs under `res://ui/review/exports/`, so no export can drift from its source without
## being regenerated. Godot's own ThorVG rasteriser is used, which is the same code path
## the runtime importer uses -- an export therefore shows exactly what the game will draw.
##
## Run: `godot --headless --path godot --script ui/tools/export_art_pngs.gd`
## This is a developer tool. Nothing in the game loads it.

const ART: GDScript = preload("res://ui/ui_art.gd")

const EXPORT_DIRECTORY: String = "res://ui/review/exports"


func _init() -> void:
	"""Export every declared asset at every declared optical size, then report the count."""
	var written: int = _export_all()
	print("art-export: wrote %d PNG(s) to %s" % [written, EXPORT_DIRECTORY])
	quit(0 if written > 0 else 1)


func _export_all() -> int:
	"""Walk the art registry and rasterise each entry. Returns how many files were written."""
	DirAccess.make_dir_recursive_absolute(EXPORT_DIRECTORY)
	var written: int = 0
	for index: int in ART.asset_count():
		var source: String = ART.source_path_of(index)
		var stem: String = ART.asset_id_of(index).to_lower().replace(".", "_")
		for size: int in ART.optical_sizes_of(index):
			if _export_one(source, stem, size):
				written += 1
	return written


func _export_one(source: String, stem: String, size: int) -> bool:
	"""Rasterise one SVG to one PNG. Returns false and complains if either step fails."""
	var image: Image = ART.rasterise(source, size)
	if image == null:
		push_error("art-export: could not rasterise %s at %d" % [source, size])
		return false
	var target: String = "%s/%s_%d.png" % [EXPORT_DIRECTORY, stem, size]
	var status: int = image.save_png(target)
	if status != OK:
		push_error("art-export: could not write %s (error %d)" % [target, status])
		return false
	return true
