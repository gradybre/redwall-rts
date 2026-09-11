extends RefCounted
## The `godot/ui/` art registry: stable IDs, sources, optical sizes and stretch margins.
##
## SET-UX-VIS-002 revision 2 §2.4 and ART-UI-11 require that every delivered asset carry a
## stable identity, a single editable source, the optical sizes it is actually drawn for,
## and -- for panel art -- real stretch margins measured from art that exists. This file is
## that declaration, and it is the only place those numbers appear: the exporter, the
## contact-sheet builder and `test/test_ui_art.gd` all read them from here, so a source that
## is renamed, resized or deleted fails the suite instead of silently vanishing from a panel.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS FILE DELIBERATELY DOES NOT DO.
##
## It declares no colour token. §2.1's twelve FOREST tokens and the amendment's nine PAPER
## tokens remain the only semantic colours; the pigments listed in `DECORATIVE_PIGMENTS`
## below are the decorative inks used *inside* illustrations and carry no meaning. Text,
## state marks, borders and focus rings never sample them. It also declares no frame size
## and no hit target: ART-UI-11's "no frame size or click target derives from an asset's
## pixels" is a rule about who owns layout, and layout is `ui_layout.gd`'s.
##
## Nothing here reads game state, and nothing here allocates on a per-frame path. Callers
## resolve a path once and cache the Texture2D.

# --- categories -----------------------------------------------------------------------

const CATEGORY_PAINTED_RESOURCE: int = 0
const CATEGORY_PAINTED_COMMAND: int = 1
const CATEGORY_SYMBOLIC_NARROW: int = 2
const CATEGORY_SYMBOLIC_CONTROL: int = 3
const CATEGORY_EMBLEM: int = 4
const CATEGORY_ORNAMENT: int = 5
const CATEGORY_FRAME_EDGE: int = 6
const CATEGORY_FRAME_CORNER: int = 7
const CATEGORY_COUNT: int = 8

const CATEGORY_KEYS: Array[StringName] = [
	&"painted_resource", &"painted_command", &"symbolic_narrow", &"symbolic_control",
	&"emblem", &"ornament", &"frame_edge", &"frame_corner",
]

# --- the asset table ------------------------------------------------------------------
#
# Columns are parallel: index i of each array describes one asset. Stable ID first,
# because that is what a manifest, a save-independent screenshot record and a future
# renderer refer to; the path is an implementation detail that may move.

const ASSET_ID: Array[StringName] = [
	&"ART.RES.FOOD_READY", &"ART.RES.FUEL", &"ART.RES.WOOD", &"ART.RES.STONE",
	&"ART.RES.POPULATION", &"ART.RES.BEDS",
	&"ART.CMD.BUILD", &"ART.CMD.ZONE", &"ART.CMD.WORK", &"ART.CMD.FOOD",
	&"ART.CMD.PEOPLE", &"ART.CMD.GOALS",
	&"ART.NARROW.BUILD", &"ART.NARROW.ZONE", &"ART.NARROW.WORK", &"ART.NARROW.FOOD",
	&"ART.NARROW.PEOPLE", &"ART.NARROW.GOALS",
	&"ART.SYM.CLOSE", &"ART.SYM.CHECK", &"ART.SYM.LOCK", &"ART.SYM.WARNING",
	&"ART.SYM.CAMERA", &"ART.SYM.PAUSE", &"ART.SYM.DATE",
	&"ART.EMBLEM.MOUSE_48", &"ART.EMBLEM.MOUSE_64",
	&"ART.EMBLEM.MOLE_48", &"ART.EMBLEM.MOLE_64",
	&"ART.EMBLEM.OTTER_48", &"ART.EMBLEM.OTTER_64",
	&"ART.EMBLEM.SQUIRREL_48", &"ART.EMBLEM.SQUIRREL_64",
	&"ART.ORN.SPRIG", &"ART.ORN.OAK_LEAF", &"ART.ORN.ACORN", &"ART.ORN.BINDING_SEAM",
	&"ART.ORN.PAGE_EDGE",
	&"ART.FRAME.TRAY.EDGE_TOP", &"ART.FRAME.TRAY.EDGE_BOTTOM",
	&"ART.FRAME.TRAY.EDGE_LEFT", &"ART.FRAME.TRAY.EDGE_RIGHT",
	&"ART.FRAME.TRAY.CORNER_TL", &"ART.FRAME.TRAY.CORNER_TR",
	&"ART.FRAME.TRAY.CORNER_BL", &"ART.FRAME.TRAY.CORNER_BR",
	&"ART.FRAME.TIME.EDGE_TOP", &"ART.FRAME.TIME.EDGE_BOTTOM",
	&"ART.FRAME.TIME.EDGE_LEFT", &"ART.FRAME.TIME.EDGE_RIGHT",
	&"ART.FRAME.TIME.CORNER_TL", &"ART.FRAME.TIME.CORNER_TR",
	&"ART.FRAME.TIME.CORNER_BL", &"ART.FRAME.TIME.CORNER_BR",
	&"ART.FRAME.FOLIO.EDGE_TOP", &"ART.FRAME.FOLIO.EDGE_BOTTOM",
	&"ART.FRAME.FOLIO.EDGE_LEFT", &"ART.FRAME.FOLIO.EDGE_RIGHT",
	&"ART.FRAME.FOLIO.CORNER_TL", &"ART.FRAME.FOLIO.CORNER_TR",
	&"ART.FRAME.FOLIO.CORNER_BL", &"ART.FRAME.FOLIO.CORNER_BR",
	&"ART.FRAME.JOURNAL.EDGE_TOP", &"ART.FRAME.JOURNAL.EDGE_BOTTOM",
	&"ART.FRAME.JOURNAL.EDGE_LEFT", &"ART.FRAME.JOURNAL.EDGE_RIGHT",
	&"ART.FRAME.JOURNAL.CORNER_TL", &"ART.FRAME.JOURNAL.CORNER_TR",
	&"ART.FRAME.JOURNAL.CORNER_BL", &"ART.FRAME.JOURNAL.CORNER_BR",
	&"ART.FRAME.JOURNAL.RING", &"ART.FRAME.JOURNAL.STRAP",
	&"ART.FRAME.DOCK.EDGE_TOP", &"ART.FRAME.DOCK.EDGE_BOTTOM",
	&"ART.FRAME.DOCK.EDGE_LEFT", &"ART.FRAME.DOCK.EDGE_RIGHT",
	&"ART.FRAME.DOCK.CORNER_TL", &"ART.FRAME.DOCK.CORNER_TR",
	&"ART.FRAME.DOCK.CORNER_BL", &"ART.FRAME.DOCK.CORNER_BR",
]

const ASSET_PATH: Array[String] = [
	"res://ui/painted/res_food_ready.svg", "res://ui/painted/res_fuel.svg",
	"res://ui/painted/res_wood.svg", "res://ui/painted/res_stone.svg",
	"res://ui/painted/res_population.svg", "res://ui/painted/res_beds.svg",
	"res://ui/painted/cmd_build.svg", "res://ui/painted/cmd_zone.svg",
	"res://ui/painted/cmd_work.svg", "res://ui/painted/res_food_ready.svg",
	"res://ui/painted/res_population.svg", "res://ui/painted/cmd_goals.svg",
	"res://ui/symbolic16/build.svg", "res://ui/symbolic16/zone.svg",
	"res://ui/symbolic16/work.svg", "res://ui/symbolic16/food.svg",
	"res://ui/symbolic16/people.svg", "res://ui/symbolic16/goals.svg",
	"res://ui/icons/cancel.svg", "res://ui/icons/check.svg", "res://ui/icons/lock.svg",
	"res://ui/icons/warning.svg", "res://ui/icons/center_view.svg",
	"res://ui/icons/pause.svg", "res://ui/icons/calendar.svg",
	"res://ui/emblems/species_mouse_48.svg", "res://ui/emblems/species_mouse_64.svg",
	"res://ui/emblems/species_mole_48.svg", "res://ui/emblems/species_mole_64.svg",
	"res://ui/emblems/species_otter_48.svg", "res://ui/emblems/species_otter_64.svg",
	"res://ui/emblems/species_squirrel_48.svg", "res://ui/emblems/species_squirrel_64.svg",
	"res://ui/ornaments/sprig.svg", "res://ui/ornaments/oak_leaf.svg",
	"res://ui/ornaments/acorn.svg", "res://ui/ornaments/binding_seam.svg",
	"res://ui/ornaments/page_edge.svg",
	"res://ui/frames/resource_tray/resource_tray_edge_top.svg",
	"res://ui/frames/resource_tray/resource_tray_edge_bottom.svg",
	"res://ui/frames/resource_tray/resource_tray_edge_left.svg",
	"res://ui/frames/resource_tray/resource_tray_edge_right.svg",
	"res://ui/frames/resource_tray/resource_tray_corner_tl.svg",
	"res://ui/frames/resource_tray/resource_tray_corner_tr.svg",
	"res://ui/frames/resource_tray/resource_tray_corner_bl.svg",
	"res://ui/frames/resource_tray/resource_tray_corner_br.svg",
	"res://ui/frames/time_group/time_group_edge_top.svg",
	"res://ui/frames/time_group/time_group_edge_bottom.svg",
	"res://ui/frames/time_group/time_group_edge_left.svg",
	"res://ui/frames/time_group/time_group_edge_right.svg",
	"res://ui/frames/time_group/time_group_corner_tl.svg",
	"res://ui/frames/time_group/time_group_corner_tr.svg",
	"res://ui/frames/time_group/time_group_corner_bl.svg",
	"res://ui/frames/time_group/time_group_corner_br.svg",
	"res://ui/frames/map_folio/map_folio_edge_top.svg",
	"res://ui/frames/map_folio/map_folio_edge_bottom.svg",
	"res://ui/frames/map_folio/map_folio_edge_left.svg",
	"res://ui/frames/map_folio/map_folio_edge_right.svg",
	"res://ui/frames/map_folio/map_folio_corner_tl.svg",
	"res://ui/frames/map_folio/map_folio_corner_tr.svg",
	"res://ui/frames/map_folio/map_folio_corner_bl.svg",
	"res://ui/frames/map_folio/map_folio_corner_br.svg",
	"res://ui/frames/journal/journal_edge_top.svg",
	"res://ui/frames/journal/journal_edge_bottom.svg",
	"res://ui/frames/journal/journal_edge_left.svg",
	"res://ui/frames/journal/journal_edge_right.svg",
	"res://ui/frames/journal/journal_corner_tl.svg",
	"res://ui/frames/journal/journal_corner_tr.svg",
	"res://ui/frames/journal/journal_corner_bl.svg",
	"res://ui/frames/journal/journal_corner_br.svg",
	"res://ui/frames/journal/journal_ring.svg",
	"res://ui/frames/journal/journal_strap.svg",
	"res://ui/frames/command_dock/command_dock_edge_top.svg",
	"res://ui/frames/command_dock/command_dock_edge_bottom.svg",
	"res://ui/frames/command_dock/command_dock_edge_left.svg",
	"res://ui/frames/command_dock/command_dock_edge_right.svg",
	"res://ui/frames/command_dock/command_dock_corner_tl.svg",
	"res://ui/frames/command_dock/command_dock_corner_tr.svg",
	"res://ui/frames/command_dock/command_dock_corner_bl.svg",
	"res://ui/frames/command_dock/command_dock_corner_br.svg",
]

const ASSET_CATEGORY: Array[int] = [
	CATEGORY_PAINTED_RESOURCE, CATEGORY_PAINTED_RESOURCE, CATEGORY_PAINTED_RESOURCE,
	CATEGORY_PAINTED_RESOURCE, CATEGORY_PAINTED_RESOURCE, CATEGORY_PAINTED_RESOURCE,
	CATEGORY_PAINTED_COMMAND, CATEGORY_PAINTED_COMMAND, CATEGORY_PAINTED_COMMAND,
	CATEGORY_PAINTED_COMMAND, CATEGORY_PAINTED_COMMAND, CATEGORY_PAINTED_COMMAND,
	CATEGORY_SYMBOLIC_NARROW, CATEGORY_SYMBOLIC_NARROW, CATEGORY_SYMBOLIC_NARROW,
	CATEGORY_SYMBOLIC_NARROW, CATEGORY_SYMBOLIC_NARROW, CATEGORY_SYMBOLIC_NARROW,
	CATEGORY_SYMBOLIC_CONTROL, CATEGORY_SYMBOLIC_CONTROL, CATEGORY_SYMBOLIC_CONTROL,
	CATEGORY_SYMBOLIC_CONTROL, CATEGORY_SYMBOLIC_CONTROL, CATEGORY_SYMBOLIC_CONTROL,
	CATEGORY_SYMBOLIC_CONTROL,
	CATEGORY_EMBLEM, CATEGORY_EMBLEM, CATEGORY_EMBLEM, CATEGORY_EMBLEM,
	CATEGORY_EMBLEM, CATEGORY_EMBLEM, CATEGORY_EMBLEM, CATEGORY_EMBLEM,
	CATEGORY_ORNAMENT, CATEGORY_ORNAMENT, CATEGORY_ORNAMENT, CATEGORY_ORNAMENT,
	CATEGORY_ORNAMENT,
	CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE,
	CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE,
	CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE,
	CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE,
	CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE, CATEGORY_FRAME_EDGE,
	CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER, CATEGORY_FRAME_CORNER,
	CATEGORY_FRAME_CORNER,
]

## Optical sizes are the exact rendered WIDTH in logical pixels, one row per asset,
## stored flat with `OPTICAL_OFFSET` marking where each asset's run starts. Painted
## resource art is drawn for 24 and also exported at 32 for the wider counter slot;
## §2.4 fixes the wide toolbar at 24 and narrow at 16; emblems are 48 and 64. Frame
## pieces have exactly one size -- their authored size -- because scaling relief art
## changes its apparent depth.
const OPTICAL_SIZE: Array[int] = [
	24, 32, 24, 32, 24, 32, 24, 32, 24, 32, 24, 32,
	24, 24, 24, 24, 24, 24,
	16, 16, 16, 16, 16, 16,
	16, 18, 24, 16, 18, 24, 16, 18, 24, 16, 18, 24, 16, 18, 24, 16, 18, 24, 16, 18, 24,
	48, 64, 48, 64, 48, 64, 48, 64,
	48, 28, 12, 16, 48,
	48, 48, 8, 8, 18, 18, 18, 18,
	48, 48, 5, 5, 16, 16, 16, 16,
	48, 48, 6, 6, 18, 18, 18, 18,
	48, 48, 12, 5, 12, 14, 12, 14, 10, 14,
	48, 48, 7, 7, 22, 22, 22, 22,
]


static func _optical_run_lengths() -> PackedInt32Array:
	"""How many optical sizes each asset declares, in asset order."""
	var runs: PackedInt32Array = PackedInt32Array()
	for index: int in ASSET_ID.size():
		var category: int = ASSET_CATEGORY[index]
		if category == CATEGORY_PAINTED_RESOURCE:
			runs.append(2)
		elif category == CATEGORY_SYMBOLIC_CONTROL:
			runs.append(3)
		else:
			runs.append(1)
	return runs


# --- decorative pigments ---------------------------------------------------------------
#
# The inks used inside illustrations. §2.4: "Decorative pigments in original illustrations
# are not new semantic UI tokens." They are recorded so a reviewer can see that one palette
# runs through the whole family, and so a future asset can be checked against it.

const DECORATIVE_PIGMENTS: Array[StringName] = [
	&"I01 #25372D Ink", &"I02 #14211B Deep shade", &"I03 #EAE1C8 Oat",
	&"I04 #F5F0DF Cream", &"I05 #708171 Sage", &"I06 #466647 Leaf",
	&"I07 #B49A58 Brass", &"I08 #91613E Timber", &"I09 #594332 Umber",
	&"I10 #B76545 Clay", &"I11 #D99743 Ember", &"I12 #8A8D84 Flint",
]

# --- stretch margins -------------------------------------------------------------------
#
# Measured from the art that now exists, as ART-UI-11 requires. `FRAME_*` rows are
# top, right, bottom, left insets in logical pixels: the clearance a renderer must leave
# between the panel rectangle and its text, so that no relief band or corner motif ever
# crosses a glyph, a focus ring or a hit target. Corner sizes are separate because a
# corner never stretches.

## Registry index of each silhouette's first piece. A run is four edges then four
## corners, and the journal adds two non-stretching extras after its corners, so the runs
## are not evenly spaced and must be written down rather than computed.
const FRAME_FIRST_ASSET: Array[int] = [38, 46, 54, 62, 72]

const FRAME_KEYS: Array[StringName] = [
	&"resource_tray", &"time_group", &"map_folio", &"journal", &"command_dock",
]
## Edge thickness per frame: top, right, bottom, left.
const FRAME_EDGE_INSET: Array[int] = [
	8, 8, 8, 8,
	5, 5, 5, 5,
	6, 6, 6, 6,
	5, 5, 5, 12,
	7, 7, 7, 7,
]
## Non-stretching corner extent, four corners per frame as width,height pairs in the
## order top-left, top-right, bottom-left, bottom-right. The journal is the reason this is
## per corner rather than per frame: its bound side is a 12x16 spine cap and its fore-edge
## side is a 14x14 page corner, and averaging the two would misplace both.
const FRAME_CORNER_SIZE: Array[int] = [
	18, 18, 18, 18, 18, 18, 18, 18,
	16, 16, 16, 16, 16, 16, 16, 16,
	18, 18, 18, 18, 18, 18, 18, 18,
	12, 16, 14, 14, 12, 16, 14, 14,
	22, 22, 22, 22, 22, 22, 22, 22,
]

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_ASSET: StringName = &"UI_ART_UNKNOWN_ASSET"
const REFUSE_UNREADABLE_SOURCE: StringName = &"UI_ART_UNREADABLE_SOURCE"


static func asset_count() -> int:
	"""How many assets the registry declares."""
	return ASSET_ID.size()


static func is_asset(index: int) -> bool:
	"""True for a declared asset index."""
	return index >= 0 and index < ASSET_ID.size()


static func asset_id_of(index: int) -> StringName:
	"""The stable ID of one asset. Callers validate the index first."""
	return ASSET_ID[index]


static func source_path_of(index: int) -> String:
	"""The single editable SVG source of one asset."""
	return ASSET_PATH[index]


static func category_of(index: int) -> int:
	"""Which delivery family one asset belongs to."""
	return ASSET_CATEGORY[index]


static func has_asset_id(id: StringName) -> bool:
	"""True when a stable ID is declared. There is deliberately no index-or-minus-one
	lookup: a caller that cannot name a real asset gets a refusal, never a usable-looking
	index."""
	return ASSET_ID.has(id)


static func optical_sizes_of(index: int) -> PackedInt32Array:
	"""Every rendered width, in logical pixels, that one asset is delivered at.

	Builds a small array, so it belongs to tooling and start-up, never a per-frame path.
	"""
	var runs: PackedInt32Array = _optical_run_lengths()
	var start: int = 0
	for i: int in index:
		start += runs[i]
	var sizes: PackedInt32Array = PackedInt32Array()
	for offset: int in runs[index]:
		sizes.append(OPTICAL_SIZE[start + offset])
	return sizes


static func frame_count() -> int:
	"""How many distinct panel silhouettes are delivered."""
	return FRAME_KEYS.size()


static func frame_first_asset(frame: int) -> int:
	"""The registry index of one silhouette's top edge, the first piece of its run."""
	return FRAME_FIRST_ASSET[frame]


static func frame_edge_inset(frame: int, side: int) -> int:
	"""The stretch margin one panel silhouette needs on one side; 0=top,1=right,2=bottom,3=left."""
	return FRAME_EDGE_INSET[frame * 4 + side]


static func frame_corner_size(frame: int, corner: int) -> Vector2i:
	"""The non-stretching extent of one corner; 0=top-left,1=top-right,2=bottom-left,3=bottom-right."""
	var at: int = frame * 8 + corner * 2
	return Vector2i(FRAME_CORNER_SIZE[at], FRAME_CORNER_SIZE[at + 1])


static func rasterise(source_path: String, width: float) -> Image:
	"""Render one SVG source to an Image of the requested logical width.

	Returns null rather than a blank Image when the source cannot be read or parsed, so a
	caller cannot mistake a missing asset for an empty one. Not for a per-frame path.
	"""
	if not FileAccess.file_exists(source_path):
		return null
	var text: String = FileAccess.get_file_as_string(source_path)
	var declared: float = declared_width(text)
	if declared <= 0.0 or width <= 0.0:
		return null
	var image: Image = Image.new()
	if image.load_svg_from_string(text, width / declared) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


static func declared_width(svg_text: String) -> float:
	"""The `width` attribute of an SVG document, or 0.0 when it has none."""
	var marker: String = "width=\""
	var at: int = svg_text.find(marker)
	if at < 0:
		return 0.0
	var tail: String = svg_text.substr(at + marker.length())
	var value: String = tail.substr(0, tail.find("\""))
	return value.to_float()
