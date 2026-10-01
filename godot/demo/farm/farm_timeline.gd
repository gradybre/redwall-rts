extends Control
## The season calendar's COMPACT TIMELINE (decision 0451; P1's "Seasonal forecast": "Offer an accessible table alongside
## timeline"): a lane per crop row, the weather, frost, blight, the beds and the meals, across the season's twelve days,
## with today marked. Drawn from farm_season.gd's entries only when they change (`show_season`); the planner's Table view
## lists the very same entries in words, and this control's accessible description says so. DEMO UI.
##
## HOW EACH KIND OF KNOWING IS DRAWN (never by colour alone -- each has its own shape, and the legend names them):
##   SCHEDULED  a solid bar in the lane's upper half;   RECORDED  a small filled square;
##   NOW        a ringed diamond;                       ESTIMATE  an outlined bar in the lane's lower half (it may move).
## So a crop row's planting window and its ripening, or the meals planned and the food's estimate, never cover each
## other. A season-long SCHEDULED entry on the weather lane (§5.10's baseline) is a thin band under the lane, so a day's
## weather drawn over it still reads. An entry's short word (the bed, the event) is written in its bar when it fits.

const SeasonScript := preload("res://demo/farm/farm_season.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const LABEL_W: float = 78.0
const HEADER_H: float = 20.0
const LANE_H: float = 24.0
const BAR_INSET: float = 2.0
const TAG_PX: int = 12
const TEXT_PX: int = 14
const OUTLINE_W: float = 2.0
const MARK: float = 6.0
## Per knowing (SCHEDULED, RECORDED, NOW, ESTIMATE): the fill or line colour.
const KNOWING_COLOURS: Array[Color] = [Palette.LEAF, Palette.SAGE, Palette.EMBER, Palette.UMBER]
const TODAY_WASH: Color = Color(0.72, 0.4, 0.27, 0.16)
const DAY_WASH: Color = Color(0.35, 0.26, 0.2, 0.06)

var _season: SeasonScript = null


func _init() -> void:
	"""Sized by its lanes; never takes focus (the table is the keyboard's view of the same entries)."""
	custom_minimum_size = Vector2(0.0, HEADER_H + LANE_H * SeasonScript.LANE_COUNT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func show_season(season: SeasonScript) -> void:
	"""Draw this season's entries (call again after it is rebuilt)."""
	_season = season
	accessibility_description = "Timeline of %s: %d entries. The Table view lists every one in words." % [
		season.title(), season.count()] if season != null else ""
	queue_redraw()


func day_width() -> float:
	"""One day's width (logical px)."""
	return maxf(size.x - LABEL_W, 0.0) / float(SeasonScript.DAYS)


func day_x(day: int) -> float:
	"""Where season day `day` (1..12) starts."""
	return LABEL_W + float(day - 1) * day_width()


func _draw() -> void:
	"""The day grid and lane names, today, then every entry."""
	if _season == null:
		return
	var font: Font = get_theme_default_font()
	_draw_grid(font)
	if _season.today > 0:
		var at: float = day_x(_season.today) + day_width() * float(_season.today_hour) / 24.0
		draw_rect(Rect2(day_x(_season.today), 0.0, day_width(), size.y), TODAY_WASH)
		draw_line(Vector2(at, 0.0), Vector2(at, size.y), Palette.CLAY, OUTLINE_W)
	for k: int in _season.count():
		_draw_entry(k)


func _draw_grid(font: Font) -> void:
	"""Alternate day washes, the day numbers and the lane names."""
	for day: int in range(1, SeasonScript.DAYS + 1):
		if day % 2 == 0:
			draw_rect(Rect2(day_x(day), 0.0, day_width(), size.y), DAY_WASH)
		draw_string(font, Vector2(day_x(day) + 2.0, HEADER_H - 5.0), "%d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_PX,
			Palette.UMBER)
	for lane: int in SeasonScript.LANE_COUNT:
		draw_string(font, Vector2(2.0, _lane_y(lane) + LANE_H - 6.0), SeasonScript.LANE_NAMES[lane],
			HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 4.0, TEXT_PX, Palette.INK)


func _lane_y(lane: int) -> float:
	"""The top of a lane."""
	return HEADER_H + float(lane) * LANE_H


func _draw_entry(k: int) -> void:
	"""One entry in its knowing's shape (see HOW EACH KIND OF KNOWING IS DRAWN)."""
	var how: int = _season.knowing[k]
	var colour: Color = KNOWING_COLOURS[how]
	var y: float = _lane_y(_season.lane[k])
	var half: float = (LANE_H - 2.0 * BAR_INSET) * 0.5
	var rect := Rect2(day_x(_season.first_day[k]) + 1.0, y + BAR_INSET,
		day_width() * float(_season.last_day[k] - _season.first_day[k] + 1) - 2.0, LANE_H - 2.0 * BAR_INSET)
	if how == SeasonScript.SCHEDULED and _season.first_day[k] == 1 and _season.last_day[k] == SeasonScript.DAYS \
			and _season.lane[k] == SeasonScript.LANE_WEATHER:
		draw_rect(Rect2(rect.position.x, y + LANE_H - BAR_INSET - 3.0, rect.size.x, 3.0), colour)
		return
	match how:
		SeasonScript.SCHEDULED:
			_draw_bar(Rect2(rect.position, Vector2(rect.size.x, half - 1.0)), colour, true, _season.tag[k])
		SeasonScript.ESTIMATE:
			_draw_bar(Rect2(rect.position + Vector2(0.0, half + 1.0), Vector2(rect.size.x, half - 1.0)), colour, false,
				_season.tag[k])
		SeasonScript.RECORDED:
			draw_rect(Rect2(rect.get_center() - Vector2(MARK, MARK) * 0.5, Vector2(MARK, MARK)), colour)
		SeasonScript.NOW:
			_draw_diamond(rect.get_center(), colour)


func _draw_bar(rect: Rect2, colour: Color, solid: bool, word: String) -> void:
	"""A solid or outlined bar, its short word written in it when it fits."""
	if solid:
		draw_rect(rect, colour)
	else:
		draw_rect(rect, colour, false, OUTLINE_W)
	if word.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_PX).x + 6.0 > rect.size.x:
		return
	draw_string(font, Vector2(rect.position.x + 3.0, rect.end.y - 1.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_PX,
		Palette.CREAM if solid else Palette.INK)


func _draw_diamond(at: Vector2, colour: Color) -> void:
	"""A ringed diamond (today's conditions)."""
	var r: float = MARK
	var points := PackedVector2Array([at + Vector2(0.0, -r), at + Vector2(r, 0.0), at + Vector2(0.0, r), at + Vector2(-r, 0.0)])
	draw_colored_polygon(points, colour)
	points.append(points[0])
	draw_polyline(points, Palette.INK, 1.5)
