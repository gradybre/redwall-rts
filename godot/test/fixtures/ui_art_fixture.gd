extends RefCounted
## Art pass 2's UI art for checks (decision 0951), without the staged assets CI never has: tiny PNGs written under
## user:// and a manifest `ui` section naming them, loaded into a real props table (demo_props.gd). `staged()` names a
## portrait for every cast key given, an emblem for every kind but the last, the tapestry ground and the chronicle page,
## each at its manifest size and margins; `empty()` is a props table loaded from an empty manifest -- what CI runs.

const PropsScript := preload("res://demo/props/demo_props.gd")
## The tapestry panel's emblem keys (tapestry.gd's KIND_* order); the fixture leaves the last ("event") unstaged.
const TapestryPanelScript := preload("res://demo/hall/tapestry_panel.gd")

const DIR: String = "user://ui_art_fixture"
const PORTRAIT_SIZES: Array[int] = [48, 64]
const EMBLEM_SIZES: Array[int] = [24, 32]
const TAPESTRY_HALF: Dictionary = {"size": [448, 600], "patch_margins_ltrb": [90, 113, 89, 116]}
const CHRONICLE_PAGE: Dictionary = {"size": [752, 1048], "text_area_ltrb": [130, 150, 622, 898]}


static func empty() -> PropsScript:
	"""A props table from an empty manifest: every UI art asked for is null (CI's case)."""
	var props := PropsScript.new()
	props.load_from({})
	return props


static func staged(cast_keys: Array[StringName]) -> PropsScript:
	"""A props table whose manifest stages a portrait per cast key, seven emblems, the tapestry ground and the page."""
	DirAccess.make_dir_recursive_absolute(DIR)
	var portraits: Dictionary = {}
	for key: StringName in cast_keys:
		var row: Dictionary = {}
		for px: int in PORTRAIT_SIZES:
			row[str(px)] = _png("portrait_%s_%d" % [key, px], Vector2i(px, px), Color(0.6, 0.4, 0.2))
		portraits[String(key)] = row
	var emblems: Dictionary = {}
	for k: int in TapestryPanelScript.EMBLEM_KEYS.size() - 1:
		var row: Dictionary = {}
		for px: int in EMBLEM_SIZES:
			row[str(px)] = _png("emblem_%s_%d" % [TapestryPanelScript.EMBLEM_KEYS[k], px], Vector2i(px, px), Color(0.3, 0.5, 0.2))
		emblems[TapestryPanelScript.EMBLEM_KEYS[k]] = row
	var ui: Dictionary = {"portraits": portraits, "emblems": emblems,
		"tapestry_half": _sized("tapestry_half", TAPESTRY_HALF, Color(0.9, 0.85, 0.7)),
		"chronicle_page": _sized("chronicle_page", CHRONICLE_PAGE, Color(0.95, 0.9, 0.75))}
	var props := PropsScript.new()
	props.load_from({"ui": ui})
	return props


static func _sized(file: String, row: Dictionary, colour: Color) -> Dictionary:
	"""A manifest row like `row`, its picture written at the row's size."""
	var out: Dictionary = row.duplicate(true)
	var size: Array = row["size"]
	out["path"] = _png(file, Vector2i(int(size[0]), int(size[1])), colour)
	return out


static func _png(file: String, size: Vector2i, colour: Color) -> String:
	"""Write a plain `size` picture of `colour` under DIR; its path."""
	var path: String = DIR.path_join(file + ".png")
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	image.save_png(path)
	return path
