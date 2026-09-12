extends RefCounted
## The hierarchy-preserving import validator GAP-06 asks for, plus GAP-03/04/08 checks.
##
## `.claude/skills/asset-pipeline/scripts/prep_unit.py` JOINS every imported object into one
## mesh. That is correct for a single-object creature and destroys a managed building, whose
## roof, per-side upper and lower walls and floor must stay separately addressable so
## `docs/ui_ux_controls.md` §6's cutaway can hide them independently. This file is the check
## that a multi-part asset arrived with its hierarchy intact and inside its declared budget.
##
## It reports. It never repairs, and it never returns a sentinel: a refusal is a `Report`
## carrying the failing statements, so a caller that ignores the report cannot receive a
## number that looks like a pass. Every count it compares against a ceiling is MEASURED --
## passed in by whoever read the real file -- and every ceiling is read from
## `lookdev_dimensions.gd`. Nothing here invents a dimension.
##
## ---------------------------------------------------------------------------------------
## NAMED BLOCKER -- cap/opening part naming is not settled.
##
## GAP-06 requires "opening/cap geometry" as an addressable part but does not name it, and
## GAP-08's part clause says only "Parts use the hierarchy names above". This validator
## therefore REQUIRES the ten parts that are named (roof, four upper walls, four lower
## walls, floor), ACCEPTS further parts, and records each unnamed extra as a note rather
## than inventing a `cap_*` convention and enforcing it. Close that contract before a
## reviewer reads the notes as approval.

const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Farming := preload("res://scripts/core/farming.gd")

## GAP-06's named parts for a managed building. Order is authoring order, not a draw order.
const REQUIRED_BUILDING_PARTS: Array[StringName] = [
	&"roof",
	&"wall_n_upper", &"wall_e_upper", &"wall_s_upper", &"wall_w_upper",
	&"wall_n_lower", &"wall_e_lower", &"wall_s_lower", &"wall_w_lower",
	&"floor",
]

## GAP-08 asset-name kinds and whether the kind carries a `_lod<n>` tier suffix.
const NAME_KIND_PREFIX: Array[String] = [
	"building_", "furniture_", "prop_", "flora_", "crop_", "terrain_",
]
const NAME_KIND_HAS_LOD: Array[bool] = [true, true, true, true, true, false]
const MAX_STATIC_LOD_INDEX: int = 2


class Report:
	"""Accumulated outcome of one validation: failing statements and non-failing notes."""

	var failures: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()

	func ok() -> bool:
		"""True only when nothing failed. Notes never make a report fail."""
		return failures.is_empty()

	func fail(statement: String) -> void:
		"""Record a contract violation. The asset is refused until this statement is gone."""
		failures.append(statement)

	func note(statement: String) -> void:
		"""Record something a human must look at that no contract yet decides."""
		notes.append(statement)

	func summary() -> String:
		"""One line naming the outcome and the counts, for a tool's stdout."""
		return "%s: %d failure(s), %d note(s)" % [
			"PASS" if ok() else "REFUSED", failures.size(), notes.size()]


static func validate_asset_name(asset_name: String, report: Report) -> void:
	"""Check one GAP-08 asset name: ASCII, known kind, real catalog key where one is required."""
	if not _is_ascii(asset_name):
		report.fail("name '%s' is not ASCII" % asset_name)
		return
	if not _is_lower_snake(asset_name):
		report.fail("name '%s' is not lowercase a-z, 0-9 and underscore" % asset_name)
		return
	var kind: int = _name_kind_of(asset_name)
	if kind < 0:
		report.fail("name '%s' starts with no GAP-08 kind prefix" % asset_name)
		return
	var remainder: String = asset_name.substr(NAME_KIND_PREFIX[kind].length())
	if NAME_KIND_HAS_LOD[kind]:
		remainder = _strip_lod_suffix(remainder, asset_name, report)
		if remainder.is_empty():
			return
	_check_name_catalog_key(kind, remainder, asset_name, report)


static func _name_kind_of(asset_name: String) -> int:
	"""Index into NAME_KIND_PREFIX for `asset_name`, or -1 when no prefix matches.

	Private and never returned to a caller: `validate_asset_name` turns -1 into a failure
	statement, so no public surface hands back an out-of-band number.
	"""
	for kind: int in NAME_KIND_PREFIX.size():
		if asset_name.begins_with(NAME_KIND_PREFIX[kind]):
			return kind
	return -1


static func _strip_lod_suffix(remainder: String, asset_name: String, report: Report) -> String:
	"""Remove a valid `_lod0..2` tail. Returns "" and records a failure when it is absent."""
	var cut: int = remainder.rfind("_lod")
	if cut < 0:
		report.fail("name '%s' carries no _lod<n> tier suffix" % asset_name)
		return ""
	var tier: String = remainder.substr(cut + 4)
	if not tier.is_valid_int() or tier.to_int() < 0 or tier.to_int() > MAX_STATIC_LOD_INDEX:
		report.fail("name '%s' tier must be lod0, lod1 or lod2" % asset_name)
		return ""
	if cut == 0:
		report.fail("name '%s' has no key before its tier suffix" % asset_name)
		return ""
	return remainder.substr(0, cut)


static func _check_name_catalog_key(kind: int, remainder: String, asset_name: String,
		report: Report) -> void:
	"""Require a real catalog key where GAP-08 demands one, and a non-empty variant or state."""
	var cut: int = remainder.rfind("_")
	if cut <= 0:
		report.fail("name '%s' carries no <variant> or <state> token" % asset_name)
		return
	var key: String = remainder.substr(0, cut)
	var tail: String = remainder.substr(cut + 1)
	if tail.is_empty():
		report.fail("name '%s' carries no <variant> or <state> token" % asset_name)
		return
	match NAME_KIND_PREFIX[kind]:
		"building_":
			if not Catalog.BUILDING_DEFINITION.has(key):
				report.fail("name '%s' names no BuildingDefinition key" % asset_name)
		"furniture_":
			if not Catalog.FURNITURE_DEFINITION.has(key):
				report.fail("name '%s' names no FurnitureDefinition key" % asset_name)
		"crop_":
			_check_crop_name(key, tail, asset_name, report)
		"terrain_":
			if not Catalog.SOIL.has(key.to_upper()):
				report.fail("name '%s' names no Soil key" % asset_name)


static func _check_crop_name(key: String, state: String, asset_name: String,
		report: Report) -> void:
	"""A crop asset names a real CropDefinition key and a real CropState, both bound to data."""
	if not Farming.CROP_KEYS.has(StringName(key)):
		report.fail("name '%s' names no CropDefinition key" % asset_name)
	if not Catalog.CROP_STATE.has(state.to_upper()):
		report.fail("name '%s' names no CropState" % asset_name)


static func _is_ascii(text: String) -> bool:
	"""True when every codepoint is below 128.

	Checked codepoint by codepoint rather than by round-tripping through `to_ascii_buffer()`,
	which pushes an engine error of its own for the exact input this function exists to
	reject -- the refusal belongs in the report, not in the console.
	"""
	for index: int in text.length():
		if text.unicode_at(index) > 127:
			return false
	return true


static func _is_lower_snake(text: String) -> bool:
	"""True when `text` is non-empty and uses only a-z, 0-9 and underscore."""
	if text.is_empty():
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var lower: bool = code >= 97 and code <= 122
		var digit: bool = code >= 48 and code <= 57
		if not (lower or digit or code == 95):
			return false
	return true


static func validate_building_parts(part_names: PackedStringArray, report: Report) -> void:
	"""Check a managed building's part list against GAP-06's named hierarchy."""
	var seen: Dictionary = {}
	for name: String in part_names:
		if seen.has(name):
			report.fail("part '%s' appears more than once" % name)
		seen[name] = true
	for required: StringName in REQUIRED_BUILDING_PARTS:
		if not seen.has(String(required)):
			report.fail("required cutaway part '%s' is missing" % required)
	for name: String in part_names:
		if not REQUIRED_BUILDING_PARTS.has(StringName(name)):
			report.note("part '%s' is outside GAP-06's named set; cap/opening naming is open"
				% name)
	if part_names.size() <= 1:
		report.fail(
			"a managed building arrived as %d part(s); prep_unit.py's join destroys the cutaway"
				% part_names.size())


static func validate_part_cut(part_name: String, min_y_u: int, max_y_u: int,
		report: Report) -> void:
	"""Check one wall part sits on its side of the inherited 1 m cutaway cut line."""
	if min_y_u > max_y_u:
		report.fail("part '%s' has inverted bounds %d..%d" % [part_name, min_y_u, max_y_u])
		return
	var cut: int = Dimensions.CUTAWAY_CUT_HEIGHT_U
	if part_name.ends_with("_upper") and min_y_u < cut:
		report.fail("upper part '%s' starts at %d u, below the %d u cut"
			% [part_name, min_y_u, cut])
	if part_name.ends_with("_lower") and max_y_u > cut:
		report.fail("lower part '%s' reaches %d u, above the %d u cut"
			% [part_name, max_y_u, cut])


static func validate_building_envelope(building_key: StringName, measured_min_y_u: int,
		measured_max_y_u: int, report: Report) -> void:
	"""Check a measured exterior against GAP-03's maximum local Y for that building."""
	var ceiling := IntMath.IntResult.new()
	if not Dimensions.building_max_y_units_into(building_key, ceiling):
		report.fail(ceiling.error)
		return
	if measured_min_y_u != 0:
		report.fail("'%s' base is at %d u; local Y = 0 is the placed base"
			% [building_key, measured_min_y_u])
	if measured_max_y_u > ceiling.value:
		report.fail("'%s' reaches %d u, above its %d u envelope"
			% [building_key, measured_max_y_u, ceiling.value])


static func validate_static_budget(family: int, lod: int, triangles: int, surfaces: int,
		texture_edge: int, report: Report) -> void:
	"""Check one measured static asset tier against GAP-04's triangle, surface and texture caps."""
	var ceiling := IntMath.IntResult.new()
	if not Dimensions.family_triangle_ceiling_into(family, lod, ceiling):
		report.fail(ceiling.error)
		return
	if triangles > ceiling.value:
		report.fail("%d triangles at %s lod%d exceeds %d"
			% [triangles, Dimensions.FAMILY_KEY[family], lod, ceiling.value])
	var surface_ceiling := IntMath.IntResult.new()
	if not Dimensions.family_surface_ceiling_into(family, lod, surface_ceiling):
		report.fail(surface_ceiling.error)
		return
	if surfaces > surface_ceiling.value:
		report.fail("%d draw surfaces at %s lod%d exceeds %d"
			% [surfaces, Dimensions.FAMILY_KEY[family], lod, surface_ceiling.value])
	if texture_edge > Dimensions.FAMILY_TEXTURE_EDGE_CEILING[family]:
		report.fail("texture edge %d at %s exceeds %d"
			% [texture_edge, Dimensions.FAMILY_KEY[family],
				Dimensions.FAMILY_TEXTURE_EDGE_CEILING[family]])


static func validate_building_materials(distinct_materials: int, report: Report) -> void:
	"""Check a building assembly uses at most GAP-04's four distinct shared materials."""
	if distinct_materials > Dimensions.BUILDING_MATERIAL_CEILING:
		report.fail("%d distinct materials exceeds the %d shared-material ceiling"
			% [distinct_materials, Dimensions.BUILDING_MATERIAL_CEILING])


static func collect_part_names(root: Node) -> PackedStringArray:
	"""Every direct child mesh name of an imported asset root, in scene order.

	Direct children only: a joined single-mesh import therefore reports one name, which is
	what `validate_building_parts` refuses for a managed building.
	"""
	var names: PackedStringArray = PackedStringArray()
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			names.append(child.name)
	return names
