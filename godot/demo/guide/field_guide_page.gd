extends VBoxContainer
## THE FIELD GUIDE'S PAGE (decision 0481; review UX-018) in the village guide: a search field over the entries, the
## entries listed by kind (crops, dishes, materials, buildings and stations, residents' skills, water safety), and one
## entry open at a time -- what it is for, what it requires, the alternatives, where it is available here, and a
## button for every entry it links to. Built once: a search shows, hides and orders the list's buttons; an entry's
## page is redrawn when another is opened (a click, never per frame). DEMO UI.

const GuideScript := preload("res://demo/guide/field_guide.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const PLACEHOLDER: String = "Search the field guide -- e.g. \"what makes soup\""
const BACK_TEXT: String = "◀ All entries"
const SECTION_NAMES: Array[String] = ["Uses", "Requires", "Alternatives", "Available here"]
const SEE_ALSO: String = "See also"
const NONE_FOUND: String = "Nothing in the field guide matches \"%s\"."

var guide: GuideScript = GuideScript.new()
var _field: LineEdit = null
var _count: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _entry_view: VBoxContainer = null
var _buttons: Array[Button] = []
var _headers: Array[Label] = []
var _open: int = -1
var _width: float = 520.0


func _init() -> void:
	"""The field, the count, the list (one button an entry, under its kind's heading) and the entry view."""
	name = "FieldGuidePage"
	add_theme_constant_override(&"separation", 6)
	_field = GuideUi.field(PLACEHOLDER, 80)
	_field.text_changed.connect(search)
	add_child(_field)
	_count = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_count)
	var parts: Array = GuideUi.scroll_column(4)
	_scroll = parts[0]
	_list = parts[1]
	add_child(_scroll)
	_entry_view = VBoxContainer.new()
	_entry_view.add_theme_constant_override(&"separation", 4)
	_build_list()
	search("")


func _build_list() -> void:
	"""A heading per kind and a button per entry, in the guide's order."""
	for kind: int in GuideScript.KIND_NAMES.size():
		var header: Label = FarmUi.label(GuideScript.KIND_NAMES[kind], FarmUi.BODY_PX, Palette.INK, true)
		_list.add_child(header)
		_headers.append(header)
		for k: int in guide.of_kind(kind):
			var entry: GuideScript.Entry = guide.entry(k)
			var button: Button = FarmUi.button("%s -- %s" % [entry.title, entry.summary], FarmUi.SMALL_PX)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.clip_text = true
			button.pressed.connect(open_entry.bind(k))
			_list.add_child(button)
			_buttons.append(button)


func search(query: String) -> void:
	"""Show the entries matching `query`: by kind for an empty one, else best first under no headings."""
	_close_entry()
	var found: PackedInt32Array = guide.search(query)
	var words: String = query.strip_edges()
	for header: Label in _headers:
		header.visible = words.is_empty()
	for button: Button in _buttons:
		button.visible = false
	for place: int in found.size():
		var button: Button = _button_of(found[place])
		button.visible = true
		if not words.is_empty():
			_list.move_child(button, place)
	if words.is_empty():
		_restore_order()
	_count.text = "%d entries." % guide.count() if words.is_empty() else (NONE_FOUND % words if found.is_empty()
		else "%d found for \"%s\"." % [found.size(), words])


func _button_of(k: int) -> Button:
	"""Entry `k`'s list button (the list holds them in the guide's kind order)."""
	var at: int = 0
	for kind: int in GuideScript.KIND_NAMES.size():
		for entry_k: int in guide.of_kind(kind):
			if entry_k == k:
				return _buttons[at]
			at += 1
	return _buttons[0]


func _restore_order() -> void:
	"""Back to the kind order, each heading over its entries."""
	var place: int = 0
	var at: int = 0
	for kind: int in GuideScript.KIND_NAMES.size():
		_list.move_child(_headers[kind], place)
		place += 1
		for _k: int in guide.of_kind(kind).size():
			_list.move_child(_buttons[at], place)
			place += 1
			at += 1


func open_entry(k: int) -> void:
	"""Show entry `k` in place of the list: its sections, its live line and its links."""
	_open = k
	GuideUi.clear(_entry_view)
	var entry: GuideScript.Entry = guide.entry(k)
	var back: Button = FarmUi.button(BACK_TEXT, FarmUi.SMALL_PX)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(search.bind(_field.text))
	_entry_view.add_child(back)
	_entry_view.add_child(GuideUi.line(entry.title, FarmUi.TITLE_PX, Palette.INK, _width, true))
	_entry_view.add_child(GuideUi.line("%s · %s" % [GuideScript.KIND_NAMES[entry.kind], entry.summary], FarmUi.SMALL_PX,
		Palette.UMBER, _width))
	var texts: Array[String] = [entry.uses, entry.requires, entry.alternatives, entry.here]
	for s: int in SECTION_NAMES.size():
		_entry_view.add_child(GuideUi.line(SECTION_NAMES[s], FarmUi.BODY_PX, Palette.LEAF, _width, true))
		_entry_view.add_child(GuideUi.line(texts[s], FarmUi.SMALL_PX, Palette.INK, _width))
	var live: String = guide.live_line(k)
	if not live.is_empty():
		_entry_view.add_child(GuideUi.line(live, FarmUi.SMALL_PX, Palette.CLAY, _width))
	_add_links(entry)
	_show_entry_view()
	GuideUi.focus_later(back)


func _add_links(entry: GuideScript.Entry) -> void:
	"""A button for each linked entry."""
	_entry_view.add_child(GuideUi.line(SEE_ALSO, FarmUi.BODY_PX, Palette.LEAF, _width, true))
	var row: HFlowContainer = GuideUi.row(6)
	_entry_view.add_child(row)
	for id: StringName in entry.links:
		var target: int = guide.index_of(id)
		if target < 0:
			continue
		var link: Button = FarmUi.button(guide.entry(target).title, FarmUi.SMALL_PX)
		link.pressed.connect(open_entry.bind(target))
		row.add_child(link)


func _show_entry_view() -> void:
	"""The entry in the scroll in place of the list."""
	if _entry_view.get_parent() != _scroll:
		_scroll.remove_child(_list)
		_scroll.add_child(_entry_view)
	_scroll.scroll_vertical = 0


func _close_entry() -> void:
	"""The list back in the scroll."""
	_open = -1
	if _list.get_parent() != _scroll:
		_scroll.remove_child(_entry_view)
		_scroll.add_child(_list)


func _notification(what: int) -> void:
	"""Free whichever of the list and the entry view is out of the tree with the page (no orphan left)."""
	if what != NOTIFICATION_PREDELETE:
		return
	for held: Node in [_list, _entry_view]:
		if is_instance_valid(held) and held.get_parent() == null:
			held.free()


func set_text_width(width: float) -> void:
	"""Wrap at `width` (the frame's inner width less the scrollbar)."""
	_width = width
	_count.custom_minimum_size.x = width


func set_list_height(height: float) -> void:
	"""The scroll's height."""
	_scroll.custom_minimum_size.y = height


func field() -> LineEdit:
	"""The search field (the page's first focus)."""
	return _field


func open_index() -> int:
	"""The entry open now (-1: the list)."""
	return _open


func entry_text() -> String:
	"""The open entry's lines (checks)."""
	var lines := PackedStringArray()
	for child: Node in _entry_view.get_children():
		if child is Label:
			lines.append((child as Label).text)
	return "\n".join(lines)
