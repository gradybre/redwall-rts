extends VBoxContainer
## THE HELP PAGE (decision 0481; review P1 "Objectives / Help", F49): one searchable page in place of the game menu's
## wall of controls. A search field ("how do I cross the stream?"), then the topics that match, best first -- each a
## heading, its key or where it is, a line or two, and, where a command answers it, that command as a button
## (`action_requested(action)`: the host runs it). Empty, it lists every topic, the how-tos first, then each key.
## The game menu holds one (its Help page) and the village guide another; both read help_topics.gd.
##
## Built once: a search shows, hides and orders the rows it already has (no row is made or freed per keystroke).

const TopicsScript := preload("res://demo/guide/help_topics.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

signal action_requested(action: StringName)

const PLACEHOLDER: String = "Search help -- e.g. \"how do I cross the stream\""
const COUNT_ALL: String = "%d topics. Type to search."
const COUNT_FOUND: String = "%d found for \"%s\"."
const NONE_FOUND: String = "Nothing matches \"%s\". Try fewer words, or: harvest, supper, bridge, tunnel, frost, save."
## The scroll's height (the host sets it to what it has room for).
const DEFAULT_HEIGHT: float = 300.0

var topics: TopicsScript = TopicsScript.new()
var _field: LineEdit = null
var _count: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _rows: Array[VBoxContainer] = []
var _lines: Array[Label] = []
var _shown: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""The field, the count and every topic's row."""
	name = "HelpPage"
	add_theme_constant_override(&"separation", 6)
	_field = GuideUi.field(PLACEHOLDER, 80)
	_field.text_changed.connect(search)
	add_child(_field)
	_count = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_count)
	var parts: Array = GuideUi.scroll_column(10)
	_scroll = parts[0]
	_list = parts[1]
	_scroll.custom_minimum_size.y = DEFAULT_HEIGHT
	add_child(_scroll)
	for k: int in topics.count():
		var row: VBoxContainer = _row(k)
		_list.add_child(row)
		_rows.append(row)
	search("")


func _row(k: int) -> VBoxContainer:
	"""Topic `k`: heading, its key, its text, its command."""
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	var title: Label = FarmUi.label(topics.title_of(k), FarmUi.BODY_PX, Palette.INK, true)
	var keys: Label = FarmUi.label(topics.keys_of(k), FarmUi.SMALL_PX, Palette.UMBER)
	var body: Label = FarmUi.label(topics.body_of(k), FarmUi.SMALL_PX, Palette.INK)
	for line: Label in [title, keys, body]:
		line.visible = not line.text.is_empty()
		row.add_child(line)
		_lines.append(line)
	var action: StringName = topics.action_of(k)
	if action != TopicsScript.ACTION_NONE:
		var button: Button = FarmUi.button(TopicsScript.action_label(action), FarmUi.SMALL_PX)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.pressed.connect(func() -> void: action_requested.emit(action))
		row.add_child(button)
	return row


func search(query: String) -> void:
	"""Show the topics matching `query`, best first, and say how many."""
	_shown = topics.search(query)
	for row: VBoxContainer in _rows:
		row.visible = false
	for place: int in _shown.size():
		var row: VBoxContainer = _rows[_shown[place]]
		row.visible = true
		_list.move_child(row, place)
	var words: String = query.strip_edges()
	if words.is_empty():
		_count.text = COUNT_ALL % topics.count()
	elif _shown.is_empty():
		_count.text = NONE_FOUND % words
	else:
		_count.text = COUNT_FOUND % [_shown.size(), words]
	_scroll.scroll_vertical = 0


func set_query(query: String) -> void:
	"""Fill the field with `query` and search it (the guide card's Help: this step's topic)."""
	_field.text = query
	search(query)


func set_text_width(width: float) -> void:
	"""Wrap every line at `width` (the frame's inner width less the scrollbar)."""
	for line: Label in _lines:
		line.custom_minimum_size.x = width
	_count.custom_minimum_size.x = width


func set_list_height(height: float) -> void:
	"""The list's scroll height."""
	_scroll.custom_minimum_size.y = height


func field() -> LineEdit:
	"""The search field (the page's first focus)."""
	return _field


func shown() -> PackedInt32Array:
	"""The topics shown now, in order (checks)."""
	return _shown


func count_text() -> String:
	"""The count line (checks)."""
	return _count.text
