extends "res://test/framework/test_case.gd"
## UI-IDENTITY-R01's identity row, checked as arithmetic against the ruling's own table.
##
## The ruling publishes a table AND the row equation that produces it. This suite checks both
## and checks that they agree, because the failure mode being guarded against is not a wrong
## formula -- it is a right formula and a mistyped table, or the reverse, drawing a name column
## eight pixels into Close on one profile only.
##
## The numbers are restated here as literals rather than read from the module under test. A
## test that asks the module what it thinks 172 is cannot catch the module changing its mind.

const UiResidentHeader := preload("res://scripts/ui/ui_resident_header.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## The ruling's table, transcribed: panel, inner, medallion, name column, Close, per profile.
const PANEL: Array[float] = [320.0, 336.0, 384.0]
const INNER: Array[float] = [280.0, 296.0, 344.0]
const MEDALLION: Array[int] = [48, 64, 64]
const NAME_COLUMN: Array[float] = [172.0, 172.0, 220.0]
const CLOSE: float = 44.0
const INSET: float = 20.0
const GAP: float = 8.0


func test_the_published_table_matches_the_rulings_own_numbers() -> void:
	"""320/336/384 panels, 48/64/64 medallions and 172/172/220 name columns, exactly."""
	for profile: int in UiLayout.PROFILE_COUNT:
		assert_almost_equal(UiResidentHeader.PANEL_WIDTH[profile], PANEL[profile],
			"profile %d's panel width" % profile)
		assert_almost_equal(UiResidentHeader.INNER_WIDTH[profile], INNER[profile],
			"profile %d's inner width" % profile)
		assert_equal(UiResidentHeader.medallion_pixels(profile), MEDALLION[profile],
			"profile %d's medallion" % profile)
		assert_almost_equal(UiResidentHeader.name_column_width(profile), NAME_COLUMN[profile],
			"profile %d's name column" % profile)


func test_the_name_column_is_never_the_old_280_px_minimum() -> void:
	"""The whole point of the ruling: 280 does not fit beside a medallion and Close.

	"With a 280px NAME column the row would require 388px Narrow or 404px Standard/Wide inside
	available 280/296/344px: over by 108/108/60px."
	"""
	for profile: int in UiLayout.PROFILE_COUNT:
		assert_true(UiResidentHeader.name_column_width(profile) < 280.0,
			"profile %d's name column is not the old minimum" % profile)
	assert_almost_equal(20.0 + 48.0 + 8.0 + 280.0 + 8.0 + 44.0 + 20.0, 428.0,
		"a 280 px column would need 428 px of panel at NARROW")
	assert_true(428.0 > PANEL[UiLayout.PROFILE_NARROW],
		"which the 320 px narrow detail column does not have")


func test_the_row_equation_reproduces_the_published_column() -> void:
	"""`panel - 2*inset - medallion - 2*gap - close` must equal the table, on every profile."""
	for profile: int in UiLayout.PROFILE_COUNT:
		var derived: float = PANEL[profile] - 2.0 * INSET - float(MEDALLION[profile]) \
			- 2.0 * GAP - CLOSE
		assert_almost_equal(derived, NAME_COLUMN[profile],
			"profile %d's row equation closes on its column" % profile)
		assert_almost_equal(UiResidentHeader.derived_name_column_width(profile), derived,
			"and the module derives the same number")
	assert_true(UiResidentHeader.is_consistent(),
		"so the table and the derivation agree on all three profiles")


func test_the_panel_widths_are_the_inherited_layout_widths() -> void:
	"""§1.2 owns 320/336/384; this module restates them and must not drift from the source."""
	for profile: int in UiLayout.PROFILE_COUNT:
		assert_almost_equal(UiResidentHeader.PANEL_WIDTH[profile],
			float(UiLayout.DETAIL_W[profile]), "profile %d agrees with ui_layout.gd" % profile)


func test_the_medallion_sits_at_the_top_left_of_the_identity_block() -> void:
	"""Top-aligned with Close, inside the inherited 20 px inset, square at its production size."""
	for profile: int in UiLayout.PROFILE_COUNT:
		var rect: Rect2 = UiResidentHeader.medallion_rect(profile)
		assert_almost_equal(rect.position.x, INSET, "profile %d's medallion x" % profile)
		assert_almost_equal(rect.position.y, INSET, "profile %d's medallion y" % profile)
		assert_almost_equal(rect.size.x, float(MEDALLION[profile]),
			"profile %d's medallion width" % profile)
		assert_almost_equal(rect.size.y, rect.size.x, "and it is square")


func test_the_name_column_starts_beside_the_medallion_and_not_below_it() -> void:
	"""`20 inset | medallion | 8 gap | name column`: the column begins past the roundel."""
	for profile: int in UiLayout.PROFILE_COUNT:
		var left: float = UiResidentHeader.name_column_left(profile)
		assert_almost_equal(left, INSET + float(MEDALLION[profile]) + GAP,
			"profile %d's name column starts after the medallion and one gap" % profile)
		assert_true(left > UiResidentHeader.medallion_rect(profile).end.x - 0.01,
			"so the column never begins inside the medallion")


func test_close_keeps_a_44_px_target_at_the_rows_right_edge() -> void:
	"""§2.2's 44 px target, 20 px inside the panel's own right edge, aligned with the top."""
	for profile: int in UiLayout.PROFILE_COUNT:
		var rect: Rect2 = UiResidentHeader.close_rect(profile, PANEL[profile])
		assert_almost_equal(rect.size.x, CLOSE, "profile %d's Close is 44 wide" % profile)
		assert_almost_equal(rect.size.y, CLOSE, "and 44 high")
		assert_almost_equal(rect.end.x, PANEL[profile] - INSET,
			"and ends one inset inside the panel")
		assert_almost_equal(rect.position.y, INSET, "and shares the block's top")


func test_the_whole_row_closes_on_the_panel_width_with_nothing_overlapping() -> void:
	"""Walk the row left to right: every piece abuts the next and the last ends at the inset."""
	for profile: int in UiLayout.PROFILE_COUNT:
		var medallion: Rect2 = UiResidentHeader.medallion_rect(profile)
		var name_left: float = UiResidentHeader.name_column_left(profile)
		var name_right: float = name_left + UiResidentHeader.name_column_width(profile)
		var close: Rect2 = UiResidentHeader.close_rect(profile, PANEL[profile])
		assert_almost_equal(name_left - medallion.end.x, GAP,
			"profile %d: one 8 px gap after the medallion" % profile)
		assert_almost_equal(close.position.x - name_right, GAP,
			"profile %d: one 8 px gap before Close" % profile)
		assert_true(name_right <= close.position.x + 0.01,
			"profile %d: the name column never reaches Close" % profile)


func test_identity_height_is_the_maximum_of_the_three_pieces() -> void:
	"""The ruling's measurement: medallion, complete text block and Close, whichever is tallest."""
	assert_almost_equal(UiResidentHeader.identity_height(UiLayout.PROFILE_NARROW, 20.0), 48.0,
		"a short name at NARROW leaves the 48 px medallion tallest")
	assert_almost_equal(UiResidentHeader.identity_height(UiLayout.PROFILE_STANDARD, 20.0), 64.0,
		"and the 64 px medallion at STANDARD")
	assert_almost_equal(UiResidentHeader.identity_height(UiLayout.PROFILE_NARROW, 130.0), 130.0,
		"a three-line name is taller than either, and the block takes its height")
	assert_almost_equal(UiResidentHeader.identity_height(UiLayout.PROFILE_NARROW, 0.0), 48.0,
		"and Close's 44 never makes the block shorter than the medallion")


func test_close_alone_floors_the_identity_height() -> void:
	"""Close is 44 high, so no composition can measure the block shorter than its hit target."""
	for profile: int in UiLayout.PROFILE_COUNT:
		assert_true(UiResidentHeader.identity_height(profile, 1.0) >= 44.0,
			"profile %d's identity block holds Close" % profile)


func test_a_text_block_counts_its_own_declared_line_gap() -> void:
	"""Heading plus the declared 8 px line gap plus the secondary line, and no gap without one."""
	assert_almost_equal(UiResidentHeader.text_block_height(26.0, 18.0), 52.0,
		"26 + 8 + 18 is the whole block")
	assert_almost_equal(UiResidentHeader.text_block_height(26.0, 0.0), 26.0,
		"an omitted secondary line leaves no 8 px hole under the name")
	assert_almost_equal(UiResidentHeader.TEXT_LINE_GAP, GAP,
		"and the gap is §1.2's own grid unit, not a new number")


func test_the_footer_is_64_high_and_its_action_is_44() -> void:
	"""§4.1: "a 64 px center-action footer"; "Center view is 44 high"."""
	assert_almost_equal(UiResidentHeader.FOOTER_HEIGHT, 64.0, "the footer is 64")
	assert_almost_equal(UiResidentHeader.FOOTER_ACTION_HEIGHT, 44.0, "the action is 44")
	var action: Rect2 = UiResidentHeader.footer_action_rect(336.0, 400.0)
	assert_almost_equal(action.size.y, 44.0, "the placed action is 44 high")
	assert_almost_equal(action.position.y, 346.0, "centred in the footer band at 336..400")
	assert_almost_equal(action.end.y, 390.0, "and ends 10 px above the panel's bottom")
	assert_almost_equal(action.position.x, INSET, "inside the inherited left inset")
	assert_almost_equal(action.end.x, 336.0 - INSET, "and the right one")


func test_the_body_takes_what_the_header_and_footer_leave() -> void:
	"""Grow the header, recompute the body. The footer never moves and is never overlapped."""
	assert_almost_equal(UiResidentHeader.body_height(400.0, 150.0), 186.0,
		"a 400 px panel with a header ending at 150 leaves 186 for the body")
	assert_almost_equal(UiResidentHeader.footer_top(400.0), 336.0, "because the footer starts at 336")
	assert_almost_equal(UiResidentHeader.body_height(400.0, 300.0), 36.0,
		"a taller header takes the difference out of the body, not out of the footer")


func test_a_body_with_no_room_is_reported_rather_than_drawn_negative() -> void:
	"""The ruling: "fixed header/footer may not consume the whole body" -- so say when they do."""
	assert_almost_equal(UiResidentHeader.body_height(400.0, 340.0), 0.0,
		"a header past the footer top leaves zero, never a negative height")
	assert_true(UiResidentHeader.body_is_starved(400.0, 340.0),
		"and the condition has a name a caller can check")
	assert_false(UiResidentHeader.body_is_starved(400.0, 300.0),
		"while a body with room is not starved")


func test_an_unknown_profile_returns_nothing_rather_than_a_guessed_column() -> void:
	"""There are three profiles. A fourth is not a narrower one; it is not a profile."""
	assert_equal(UiResidentHeader.medallion_pixels(3), 0, "no medallion size is invented")
	assert_almost_equal(UiResidentHeader.name_column_width(-1), 0.0, "no column width either")
	assert_almost_equal(UiResidentHeader.name_column_left(3), 0.0, "and no origin")
	assert_equal(UiResidentHeader.close_rect(3, 336.0), Rect2(), "and no Close rectangle")
	assert_almost_equal(UiResidentHeader.identity_height(3, 100.0), 0.0, "and no height")


func test_close_follows_a_panel_that_is_not_its_nominal_width() -> void:
	"""Close is anchored to the real right edge, so a resized panel keeps its target reachable."""
	var rect: Rect2 = UiResidentHeader.close_rect(UiLayout.PROFILE_STANDARD, 500.0)
	assert_almost_equal(rect.end.x, 480.0, "Close ends 20 px inside a 500 px panel")
	assert_almost_equal(rect.position.x, 436.0, "and starts 44 px before that")
