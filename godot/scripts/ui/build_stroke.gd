extends RefCounted
## THE STROKE IN PROGRESS in the build panel (UI-BUILD-010; decision 1912, slice C1 of DEC-061): one drag of one tool
## on one level, previewed on a scratch planner draft (`modular_draft.gd`) on the 1 m grid. Presentation only: it
## holds cells, never a store, job or order. The batch (build_batch.gd) judges it and, on release, applies its cells.
##
## THE TOOLS (Brendan's ruling on decision 1911 P-C7 (a), 2026-10-12): "Rectangle · Oval · Paint · Erase".
##   Rectangle  the corners' rectangle                  modular_draft.gd RECTANGLE
##   Oval       the ellipse inside the corners' box     modular_draft.gd ELLIPSE
##   Paint      a 2 × 2-cell brush along the drag       modular_draft.gd BLOCK (the smallest stamp BUILD-REQ-002 keeps)
##   Erase      the same brush, taking pending cells away (only pending ones; confirmed cells are slice F's Earth)
## The stroke's CELLS are always the stamp itself (what the tool covers), painted or erased by the batch on release.

const Draft := preload("res://demo/burrow/modular_draft.gd")

const TOOL_RECTANGLE: int = 0
const TOOL_OVAL: int = 1
const TOOL_PAINT: int = 2
const TOOL_ERASE: int = 3
const TOOL_COUNT: int = 4
## The strip's words, then each tool's accessible name and gesture (the info card's last line).
const TOOL_LABELS: Array[String] = ["Rect", "Oval", "Paint", "Erase"]
const TOOL_NAMES: Array[String] = ["Rectangle", "Oval", "Paint", "Erase"]
const TOOL_GESTURES: Array[String] = [
	"Drag a rectangle to paint; Esc cancels the stroke",
	"Drag the box an oval fills; Esc cancels the stroke",
	"Drag to paint 2 × 2 cells at a time; Esc cancels the stroke",
	"Drag over planned cells to take them out; Esc cancels the stroke",
]
## The planner draft's tool for each of ours.
const DRAFT_TOOLS: Array[int] = [Draft.RECTANGLE, Draft.ELLIPSE, Draft.BLOCK, Draft.BLOCK]

var tool: int = TOOL_RECTANGLE
var room_type: int = -1
var level: int = 0
var start: Vector2i = Vector2i.ZERO
var end: Vector2i = Vector2i.ZERO
var _draft: Draft = null


static func valid_tool(value: int) -> bool:
	"""Whether `value` names one of the four tools."""
	return value >= TOOL_RECTANGLE and value < TOOL_COUNT


func begin(with_tool: int, with_type: int, on_level: int, cell: Vector2i, pitch_u: int, capacity: int,
		bounds: Rect2i) -> bool:
	"""Start a drag at `cell`; false for an unknown tool or a room identity the planner refuses."""
	if not valid_tool(with_tool):
		return false
	var scratch: Draft = Draft.new()
	if scratch.configure(with_type, on_level, pitch_u, capacity, bounds, false) != &"":
		return false
	_draft = scratch
	tool = with_tool
	room_type = with_type
	level = on_level
	start = cell
	end = cell
	_draft.begin_stroke(DRAFT_TOOLS[tool], cell, 0, false)
	return true


func extend(cell: Vector2i) -> bool:
	"""Move the drag to `cell`; false when it is the cell already reached (nothing changes)."""
	if _draft == null or cell == end:
		return false
	end = cell
	_draft.extend_stroke(cell)
	return true


func active() -> bool:
	"""Whether a drag is in progress."""
	return _draft != null


func clear() -> void:
	"""End the drag (released or cancelled)."""
	_draft = null


func erasing() -> bool:
	"""Whether the drag takes cells away (Erase)."""
	return tool == TOOL_ERASE


func error() -> StringName:
	"""The planner's refusal of the stamp as drawn now (&"" when it draws)."""
	return _draft.preview_error() if _draft != null else &""


func cells() -> PackedInt32Array:
	"""The stamp's cells (canonical pairs, a copy), or empty with no drag or a refused stamp."""
	return _draft.visible_cells() if _draft != null and _draft.preview_error() == &"" else PackedInt32Array()


func size() -> Vector2i:
	"""Width × depth in cells: the corners' box for Rectangle and Oval, the stamp's bounding box for the brush."""
	if _draft == null:
		return Vector2i.ZERO
	if tool == TOOL_RECTANGLE or tool == TOOL_OVAL:
		return (end - start).abs() + Vector2i.ONE
	return box_of(cells()).size


static func box_of(stamp: PackedInt32Array) -> Rect2i:
	"""The bounding box of canonical `[x, z]` pairs (empty with none)."""
	if stamp.is_empty():
		return Rect2i()
	var low: Vector2i = Vector2i(stamp[0], stamp[1])
	var high: Vector2i = low
	for at: int in range(2, stamp.size(), 2):
		low = low.min(Vector2i(stamp[at], stamp[at + 1]))
		high = high.max(Vector2i(stamp[at], stamp[at + 1]))
	return Rect2i(low, high - low + Vector2i.ONE)
