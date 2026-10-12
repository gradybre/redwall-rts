extends "res://test/framework/test_case.gd"
## UI-BUILD-001 "Geometry": the build panel, the level bar and the connector card at the section's worked sizes --
## figures quoted from docs/ui_ux_controls.md, never read back from build_layout.gd -- and UX-BUILD-T01's rule that
## they stay in bounds and overlap no permanent HUD rectangle at the nine UX-T01 sizes, minimap shown and hidden.
## Decision 1871.

const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## UX-T01's nine viewport/scale pairs (the supported range: 1280×720 .. 3840×2160 at 100/125/150 %).
const SIZES: Array = [[1280, 720, 100], [1280, 720, 125], [1600, 900, 100], [1920, 1080, 100], [1920, 1080, 150],
	[2560, 1440, 100], [2560, 1440, 125], [3840, 2160, 100], [3840, 2160, 150]]

var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _at(width: int, height: int, percent: int) -> UiLayout.Geometry:
	"""The HUD's geometry for a viewport, the BR detail closed (the panel closes it)."""
	assert_true(_layout.compute_into(width, height, percent, false, _geometry), "%dx%d@%d lays out" % [width, height, percent])
	return _geometry


func test_the_panel_at_1280x720_and_1920x1080() -> void:
	"""Mw 208 / 256: the panel is 912 wide, centred in the bottom interval, 256 high, 16 above the bottom."""
	var panel: Rect2 = BuildLayout.panel_rect(_at(1280, 720, 100))
	assert_equal(panel, Rect2(296, 448, 912, 256), "1280×720")
	panel = BuildLayout.panel_rect(_at(1920, 1080, 100))
	assert_equal(panel, Rect2(640, 808, 912, 256), "1920×1080: left 288, right 1904")


func test_the_panel_at_the_narrowest_logical_viewport() -> void:
	"""853.33 × 480 (1280×720 at 150 %): 645.33 wide at y 208–464, clear of the alerts and the level bar."""
	var geometry: UiLayout.Geometry = _at(1280, 720, 150)
	var panel: Rect2 = BuildLayout.panel_rect(geometry)
	assert_almost_equal(panel.size.x, 645.333, "645.33 wide")
	assert_almost_equal(panel.position.y, 208.0, "from y 208")
	assert_almost_equal(panel.end.y, 464.0, "to y 464")
	assert_true(panel.position.y > geometry.alerts.end.y, "below the alert zone (y 76–124)")
	assert_true(panel.position.x > BuildLayout.level_bar_rect(geometry, true).end.x, "right of the level bar (x 16–176)")


func test_the_level_bar_at_the_sections_three_sizes() -> void:
	"""y 316–456 at 1280×720; 628–768 at 1920×1080; 160–264 at 853.33 × 480, under the 128-high resource frame."""
	var bar: Rect2 = BuildLayout.level_bar_rect(_at(1280, 720, 100), true)
	assert_equal(bar, Rect2(16, 316, 208, 140), "1280×720")
	bar = BuildLayout.level_bar_rect(_at(1920, 1080, 100), true)
	assert_equal(bar, Rect2(16, 628, 256, 140), "1920×1080")
	var narrow: UiLayout.Geometry = _at(1280, 720, 150)
	bar = BuildLayout.level_bar_rect(narrow, true)
	assert_almost_equal(bar.position.y, 160.0, "narrow top")
	assert_almost_equal(bar.end.y, 264.0, "narrow bottom")
	assert_equal(bar.size.x, 160.0, "narrow width = Mw")
	assert_true(bar.position.y >= narrow.resources.end.y, "below the resource frame")


func test_the_level_bar_with_the_minimap_hidden_sits_above_its_restore_control() -> void:
	"""Lh − 16 − 44 − 8 − Hb."""
	var bar: Rect2 = BuildLayout.level_bar_rect(_at(1280, 720, 100), false)
	assert_equal(bar.position.y, 720.0 - 16.0 - 44.0 - 8.0 - 140.0, "hidden minimap")
	assert_equal(bar.end.y, 720.0 - 16.0 - 44.0 - 8.0, "above the restore control")


func test_level_buttons_are_two_columns_by_three_rows_with_4px_gaps() -> void:
	"""Hb = 3 × 44 + 2 × 4 = 140 (3 × 32 + 8 = 104 in NARROW); buttons in reading order."""
	assert_equal(BuildLayout.level_bar_height(UiLayout.PROFILE_STANDARD), 140.0, "standard")
	assert_equal(BuildLayout.level_bar_height(UiLayout.PROFILE_NARROW), 104.0, "narrow")
	assert_equal(BuildLayout.level_bar_height(99), 140.0, "an unknown profile clamps to the widest's")
	var bar: Rect2 = Rect2(16, 316, 208, 140)
	assert_equal(BuildLayout.level_button_rect(bar, 0, UiLayout.PROFILE_STANDARD), Rect2(0, 0, 102, 44), "Surface")
	assert_equal(BuildLayout.level_button_rect(bar, 1, UiLayout.PROFILE_STANDARD), Rect2(106, 0, 102, 44), "Level 1")
	assert_equal(BuildLayout.level_button_rect(bar, 5, UiLayout.PROFILE_STANDARD), Rect2(106, 96, 102, 44), "Overview")
	var size: Vector2 = BuildLayout.level_button_rect(bar, 2, UiLayout.PROFILE_STANDARD).size
	assert_true(size.x >= 78.0 and size.x <= 126.0 and size.y >= 32.0 and size.y <= 44.0, "UI-BUILD-014's range")


func test_the_connector_card_sits_above_the_panel_or_inside_it_when_narrow() -> void:
	"""y 304–440 at 1280×720; y 664–800 at 1920×1080; NARROW: 280 × 128 in the content row."""
	var card: Rect2 = BuildLayout.connector_rect(_at(1280, 720, 100))
	assert_equal(Vector2(card.position.y, card.end.y), Vector2(304, 440), "1280×720")
	assert_equal(card.end.x, 1208.0, "right edges aligned")
	card = BuildLayout.connector_rect(_at(1920, 1080, 100))
	assert_equal(Vector2(card.position.y, card.end.y), Vector2(664, 800), "1920×1080")
	var geometry: UiLayout.Geometry = _at(1280, 720, 150)
	card = BuildLayout.connector_rect(geometry)
	var panel: Rect2 = BuildLayout.panel_rect(geometry)
	assert_equal(card.size, Vector2(280, 128), "narrow size")
	assert_true(panel.encloses(card), "inside the panel")


func test_the_panels_inner_rows() -> void:
	"""Tabs at y 12, content at 64 (info card 208, 160 NARROW), footer at 200, 12 px padding."""
	assert_equal(BuildLayout.tabs_rect(912), Rect2(12, 12, 888, 44), "tabs")
	assert_equal(BuildLayout.info_rect(UiLayout.PROFILE_STANDARD), Rect2(12, 64, 208, 128), "info")
	assert_equal(BuildLayout.info_rect(UiLayout.PROFILE_NARROW).size.x, 160.0, "narrow info")
	assert_equal(BuildLayout.cards_rect(912, UiLayout.PROFILE_STANDARD), Rect2(228, 64, 672, 128), "cards")
	assert_equal(BuildLayout.footer_rect(912), Rect2(12, 200, 888, 44), "footer")
	assert_equal(BuildLayout.cards_rect(100, UiLayout.PROFILE_STANDARD).size.x, 0.0, "never negative")


func test_the_footer_fits_its_five_controls_at_every_width() -> void:
	"""Max widths with a ≥120 ledger at 888; minimum widths at the narrow 621.33; always within the footer."""
	var widths: PackedFloat32Array = PackedFloat32Array()
	BuildLayout.footer_widths_into(888.0, widths)
	assert_equal(widths, PackedFloat32Array([264, 96, 96, 160, 240]), "standard")
	BuildLayout.footer_widths_into(621.333, widths)
	assert_almost_equal(widths[0], 285.333, "narrow ledger")
	assert_equal(widths[1], 44.0, "narrow undo")
	assert_equal(widths[4], 120.0, "narrow confirm")
	BuildLayout.footer_widths_into(700.0, widths)
	assert_equal(widths[1], 44.0, "at 700 the wide buttons would leave the ledger under 120: minimum widths")
	assert_almost_equal(widths[0], 364.0, "and the ledger the rest")
	for footer: float in [888.0, 621.333, 700.0, 1200.0]:
		BuildLayout.footer_widths_into(footer, widths)
		var total: float = widths[0] + widths[1] + widths[2] + widths[3] + widths[4] + 4.0 * BuildLayout.GAP
		assert_true(total <= footer + 0.01, "fits %f" % footer)
		assert_true(widths[0] <= BuildLayout.LEDGER_MAX_WIDTH, "ledger at most 520")


func test_the_expanded_ledger_stays_in_its_range() -> void:
	"""320×160 → 640×320."""
	assert_equal(BuildLayout.ledger_open_size(2, 20.0, UiLayout.PROFILE_STANDARD), Vector2(320, 160), "few lines")
	assert_equal(BuildLayout.ledger_open_size(40, 20.0, UiLayout.PROFILE_WIDE), Vector2(640, 320), "many lines")


func test_ux_build_t01_rectangles_stay_in_bounds_and_apart_at_the_nine_sizes() -> void:
	"""Panel, level bar and connector card: inside the viewport, and none over resources, time, alerts or the minimap
	(the command strip and BR detail are hidden while the panel is open), with the minimap shown and hidden."""
	for row: Array in SIZES:
		var geometry: UiLayout.Geometry = _at(int(row[0]), int(row[1]), int(row[2]))
		var view: Rect2 = Rect2(0, 0, geometry.logical_width, geometry.logical_height)
		for shown: bool in [true, false]:
			var own: Array[Rect2] = [BuildLayout.panel_rect(geometry), BuildLayout.level_bar_rect(geometry, shown),
				BuildLayout.connector_rect(geometry)]
			var hud: Array[Rect2] = [geometry.resources, geometry.time, geometry.alerts]
			if shown:
				hud.append(geometry.minimap)
			_assert_apart(row, shown, view, own, hud)


func _assert_apart(row: Array, shown: bool, view: Rect2, own: Array[Rect2], hud: Array[Rect2]) -> void:
	"""Each own rectangle in the view and clear of every HUD rectangle; the panel and bar clear of each other."""
	var label: String = "%dx%d@%d map %s" % [row[0], row[1], row[2], "shown" if shown else "hidden"]
	for k: int in own.size():
		assert_true(view.encloses(own[k]), "%s: rect %d in bounds %s" % [label, k, own[k]])
		for other: Rect2 in hud:
			assert_false(own[k].intersects(other), "%s: rect %d %s clear of %s" % [label, k, own[k], other])
	assert_false(own[0].intersects(own[1]), "%s: panel and level bar apart" % label)
	assert_false(own[2].intersects(own[1]), "%s: connector card and level bar apart" % label)
