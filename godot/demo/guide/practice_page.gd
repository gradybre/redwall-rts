extends VBoxContainer
## THE PRACTICE STORIES' PAGE (decision 0481; review UX-019) in the village guide: the three stories, then one story at
## a time -- its situation, its choices, what happened when one was chosen, the debrief (every choice compared and the
## lesson), Restart (back to the story's start) and Back to the stories. The stories' model is practice_stories.gd,
## which holds nothing of the village. DEMO UI.

const StoriesScript := preload("res://demo/guide/practice_stories.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const INTRO: String = "Short situations kept apart from your village: nothing they do touches it. Choose one, try a choice, read the debrief, restart."
const START_TEXT: String = "Start"
const RESTART_TEXT: String = "Restart"
const BACK_TEXT: String = "◀ All stories"
const WHAT_HAPPENED: String = "What happened"
const DEBRIEF: String = "Debrief"
const CHOSEN_TIP: String = "Restart to try another choice"

var stories: StoriesScript = StoriesScript.new()
var _list: VBoxContainer = null
var _story: VBoxContainer = null
var _title: Label = null
var _situation: Label = null
var _choices: HFlowContainer = null
var _result: VBoxContainer = null
var _restart: Button = null
var _starts: Array[Button] = []
var _choice_buttons: Array[Button] = []
var _width: float = 520.0


func _init() -> void:
	"""The list of stories and the (hidden) story view."""
	name = "PracticePage"
	add_theme_constant_override(&"separation", 8)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	add_child(_list)
	_list.add_child(FarmUi.label(INTRO, FarmUi.SMALL_PX, Palette.UMBER))
	for s: int in StoriesScript.STORY_COUNT:
		var start: Button = FarmUi.button("%s: %s" % [START_TEXT, StoriesScript.TITLES[s]], FarmUi.BODY_PX)
		start.tooltip_text = StoriesScript.SITUATIONS[s]
		start.pressed.connect(open_story.bind(s))
		_list.add_child(start)
		_starts.append(start)
	_build_story()


func _build_story() -> void:
	"""The story view: title, situation, choices, result, Restart and Back."""
	_story = VBoxContainer.new()
	_story.add_theme_constant_override(&"separation", 6)
	_story.visible = false
	add_child(_story)
	var back: Button = FarmUi.button(BACK_TEXT, FarmUi.SMALL_PX)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_list)
	_story.add_child(back)
	_title = FarmUi.label("", FarmUi.TITLE_PX, Palette.INK, true)
	_situation = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	_story.add_child(_title)
	_story.add_child(_situation)
	_choices = GuideUi.row(6)
	_story.add_child(_choices)
	for k: int in 3:
		var choice: Button = FarmUi.button("", FarmUi.SMALL_PX)
		choice.pressed.connect(choose.bind(k))
		_choices.add_child(choice)
		_choice_buttons.append(choice)
	_result = VBoxContainer.new()
	_result.add_theme_constant_override(&"separation", 3)
	_story.add_child(_result)
	_restart = FarmUi.button(RESTART_TEXT, FarmUi.SMALL_PX)
	_restart.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_restart.pressed.connect(restart)
	_story.add_child(_restart)


func open_story(s: int) -> void:
	"""Story `s` at its start."""
	stories.start(s)
	_title.text = StoriesScript.TITLES[s]
	_situation.text = StoriesScript.SITUATIONS[s]
	var labels: Array = StoriesScript.CHOICES[s]
	for k: int in _choice_buttons.size():
		_choice_buttons[k].visible = k < labels.size()
		_choice_buttons[k].text = String(labels[k]) if k < labels.size() else ""
	_list.visible = false
	_story.visible = true
	_draw_result()
	GuideUi.focus_later(_choice_buttons[0])


func choose(k: int) -> void:
	"""Run the story with choice `k` and show what happened and the debrief; Restart takes the focus."""
	stories.choose(k)
	_draw_result()
	GuideUi.focus_later(_restart)


func restart() -> void:
	"""Back to the story's start."""
	stories.restart()
	_draw_result()


func show_list() -> void:
	"""Back to the three stories."""
	_story.visible = false
	_list.visible = true


func _draw_result() -> void:
	"""What happened and the debrief, or nothing before a choice."""
	GuideUi.clear(_result)
	_restart.visible = stories.choice >= 0
	for k: int in _choice_buttons.size():
		FarmUi.set_enabled(_choice_buttons[k], stories.choice < 0, CHOSEN_TIP)
	if stories.choice < 0:
		return
	_result.add_child(GuideUi.line(WHAT_HAPPENED, FarmUi.BODY_PX, Palette.LEAF, _width, true))
	for text: String in stories.log_lines:
		_result.add_child(GuideUi.line(text, FarmUi.SMALL_PX, Palette.INK, _width))
	_result.add_child(GuideUi.line(DEBRIEF, FarmUi.BODY_PX, Palette.LEAF, _width, true))
	for text: String in stories.debrief:
		_result.add_child(GuideUi.line(text, FarmUi.SMALL_PX, Palette.INK, _width))


func set_text_width(width: float) -> void:
	"""Wrap at `width`."""
	_width = width
	for line: Label in [_title, _situation, _list.get_child(0) as Label]:
		line.custom_minimum_size.x = width


func start_button(s: int) -> Button:
	"""Story `s`'s Start (checks)."""
	return _starts[s]


func choice_button(k: int) -> Button:
	"""Choice `k`'s button (checks)."""
	return _choice_buttons[k]


func restart_button() -> Button:
	"""Restart (checks)."""
	return _restart


func result_text() -> String:
	"""What the story view says after a choice (checks)."""
	var lines := PackedStringArray()
	for child: Node in _result.get_children():
		if child is Label and not child.is_queued_for_deletion():
			lines.append((child as Label).text)
	return "\n".join(lines)
