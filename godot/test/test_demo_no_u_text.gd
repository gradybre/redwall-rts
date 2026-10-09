extends "res://test/framework/test_case.gd"
## No player-facing "U" (decision 1011 §4 Tests, DEC-049; phase 2, decision 1801). A lint over the demo's scripts and
## text tables and the settlement UI's scripts: a string literal -- outside comments and docstrings -- may not print an
## amount in the catalogue unit ("12 U", "%d U", "%.1f U", "%s U", a bare " U" appended to a number), call the
## underground "the U view", or count goods in "units" ("NP a unit", "3 units"). Amounts are worded by
## scripts/ui/goods_measures.gd. Key hints ("U to return", "U: back to the surface", ["U", "Underground"]) are not
## amounts and pass.
##
## ALLOWLIST: the files still being converted, each with the most findings it may hold; it shrinks slice by slice
## (decision 1801's progress section) and is empty from slice 9, when the old U helpers are deleted.

const ROOTS: Array[String] = ["res://demo", "res://scripts/ui"]
const EXTRA_FILES: Array[String] = ["res://scripts/systems/ui_manager.gd"]
const SKIP_DIRS: Array[String] = ["res://demo/assets"]
## A number or a format directive, then a space (or a no-break space) and the unit U as a word.
const AMOUNT_U: String = "(\\d|%[-+ #0-9.]*[dfisx])( |\\\\u00a0|\\x{00a0})U\\b"
## A literal that is only the unit, appended to a number elsewhere: " U".
const BARE_U: String = "^( |\\\\u00a0|\\x{00a0})U$"
const U_VIEW: String = "(?i)\\bU view\\b"
## Goods counted in units: "NP a unit", "a unit for every", "3 units", "%d units".
const UNITS: String = "(?i)\\b(a|per|each|every) unit\\b|(\\d|%[-+ #0-9.]*[dis]) units?\\b"

## path -> the most findings the file may still hold (see ALLOWLIST).
const ALLOWLIST: Dictionary = {
	"res://demo/burrow/modular_demo_mode.gd": 1,
	"res://demo/burrow/room_fixtures.gd": 1,
	"res://demo/burrow/room_text.gd": 1,
	"res://demo/farm/farm_crop_roles.gd": 1,
	"res://demo/farm/farm_plan_rows.gd": 2,
	"res://demo/farm/farm_season.gd": 1,
	"res://demo/farm/farm_tending.gd": 1,
	"res://demo/farm/farm_tending_page.gd": 1,
	"res://demo/farm/farm_text.gd": 3,
	"res://demo/feast/feast_menu.gd": 1,
	"res://demo/forage/demo_forage.gd": 1,
	"res://demo/forestry/forest_crew.gd": 2,
	"res://demo/forestry/forest_rules.gd": 1,
	"res://demo/forestry/forest_text.gd": 1,
	"res://demo/goals/goal_book.gd": 1,
	"res://demo/goals/village_goals.gd": 2,
	"res://demo/guide/field_guide.gd": 11,
	"res://demo/guide/help_topics.gd": 1,
	"res://demo/guide/practice_stories.gd": 8,
	"res://demo/hall/hall_panel.gd": 2,
	"res://demo/hives/hive_text.gd": 2,
	"res://demo/infirmary/care_desk.gd": 2,
	"res://demo/infirmary/care_tasks.gd": 2,
	"res://demo/infirmary/care_text.gd": 4,
	"res://demo/kitchen/kitchen.gd": 4,
	"res://demo/kitchen/kitchen_tab.gd": 1,
	"res://demo/kitchen/kitchen_text.gd": 1,
	"res://demo/orchard/orchard_cards.gd": 3,
	"res://demo/orchard/orchard_text.gd": 3,
	"res://demo/preserve/preserve_text.gd": 3,
	"res://demo/sound/sound_table.json": 1,
	"res://demo/spoil/demo_spoil.gd": 1,
	"res://demo/spoil/spoil_crew.gd": 1,
	"res://demo/stores/cellar_bar.gd": 1,
	"res://demo/stores/cellar_projects.gd": 1,
	"res://demo/tunnel/dig_readout.gd": 2,
	"res://demo/tunnel/tunnel_control.gd": 1,
	"res://demo/tunnel/tunnel_stores.gd": 1,
	"res://demo/ui/action_card.gd": 1,
	"res://demo/water/water_overlay.gd": 1,
	"res://demo/waterplay/demo_waterplay.gd": 1,
	"res://demo/waterplay/water_panel.gd": 2,
	"res://demo/work/spoil_work.gd": 1,
}

var _patterns: Array[RegEx] = []


func before_each() -> void:
	"""Compile the lint's patterns once per test."""
	_patterns.clear()
	for source: String in [AMOUNT_U, BARE_U, U_VIEW, UNITS]:
		var re := RegEx.new()
		re.compile(source)
		_patterns.append(re)


# --- the lint over the tree ---------------------------------------------------------------------------------------

func test_no_player_facing_u_amounts_outside_the_allowlist() -> void:
	"""Every linted file holds no more findings than its allowlist entry (none for a file not on it)."""
	var files: PackedStringArray = _files()
	assert_true(files.size() > 300, "the lint walked the demo and the UI (%d files)" % files.size())
	for path: String in files:
		var found: PackedStringArray = findings(path)
		var allowed: int = int(ALLOWLIST.get(path, 0))
		if found.size() > allowed:
			fail("%s: %d player-facing U string(s), %d allowed:\n    %s" % [path, found.size(), allowed,
				"\n    ".join(found)])
		else:
			assert_true(true, "%s is clean" % path)


func test_the_allowlist_names_only_files_that_still_need_it() -> void:
	"""An allowlist entry is exact: a file converted below its count must have its entry lowered or removed, so the
	list only ever shrinks."""
	assert_true(ALLOWLIST.size() <= 44, "the allowlist only shrinks from slice 1's 44 files (%d)" % ALLOWLIST.size())
	for path: String in ALLOWLIST:
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		assert_equal(findings(path).size(), int(ALLOWLIST[path]), "%s's allowlist count is exact" % path)


# --- the scanner, on synthetic text -------------------------------------------------------------------------------

func test_flags_amounts_in_the_unit() -> void:
	"""Each forbidden form is found."""
	for line: String in ['var a := "12 U of wood"', 'var a := "%d U" % n', 'var a := "%.1f U left" % f',
			'var a := "herbs %s U" % s', 'var a := str(n) + " U"', 'var a := "4\\u00a0U"', 'const K := "the U view"',
			'var a := "(%d NP a unit)" % n', 'var a := "a unit for every four guests"', 'var a := "3 units"',
			'var a := &"5 U"', "var a := '7 U'", 'f(x, "U View")']:
		assert_equal(scan_source(line).size(), 1, "flagged: %s" % line)


func test_passes_key_hints_comments_and_docstrings() -> void:
	"""Key hints, the U key itself, comments, doc comments and docstrings are not player-facing amounts."""
	var source: String = "\n".join([
		'## 12 U in a doc comment', '# "12 U" in a comment', 'func f() -> void:',
		'\t"""A docstring: 12 U, the U view, 3 units."""', '\tvar a := "U to return"  # 5 U',
		'\tvar b := ["U", "Underground"]', '\tvar c := "U: back to the surface"', '\tvar d := "Shift+U: your view"',
		'\tvar e := "12 logs"', '\tvar g := "Underground (U to return to the surface)"', '\tvar h := "a unity of"',
		'\tvar i := "NP"', '\tvar j := "%d days" % n', '\tvar k := Callable(Text, &"units")'])
	assert_equal(scan_source(source), PackedStringArray(), "nothing flagged")


func test_strings_with_escapes_and_hashes_are_read_whole() -> void:
	"""An escaped quote or a '#' inside a string neither ends it nor starts a comment."""
	assert_equal(scan_source('var a := "say \\"hi\\" # then 9 U"').size(), 1, "a # inside a string")
	assert_equal(scan_source("var a := \"it's\" + '\\'s 9 U'").size(), 1, "an escaped single quote")
	assert_equal(scan_source('var a := "#" # 9 U').size(), 0, "a real comment after a string")


func test_a_triple_quoted_string_that_is_a_value_is_linted() -> void:
	"""A triple-quoted string assigned or passed is text, not a docstring."""
	assert_equal(scan_source('const T := """long\n12 U text"""').size(), 1, "assigned")
	assert_equal(scan_source('\t"""docstring\n12 U"""\n\tvar a := 1').size(), 0, "a statement: a docstring")


func test_json_values_are_linted() -> void:
	"""Every string in a JSON table is player text."""
	assert_equal(scan_json('{"a": "walk (U view)", "b": "3 U", "c": "ok"}').size(), 2, "two findings")


# --- the scanner --------------------------------------------------------------------------------------------------

func findings(path: String) -> PackedStringArray:
	"""The forbidden strings in one file, each as "line: text"."""
	var text: String = FileAccess.get_file_as_string(path)
	return scan_json(text) if path.ends_with(".json") else scan_source(text)


func scan_json(text: String) -> PackedStringArray:
	"""Every quoted string in a JSON text that matches a pattern."""
	var out := PackedStringArray()
	var lines: PackedStringArray = text.split("\n")
	var quoted := RegEx.new()
	quoted.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for n: int in lines.size():
		for m: RegExMatch in quoted.search_all(lines[n]):
			_check(m.get_string(1), n + 1, out)
	return out


func scan_source(text: String) -> PackedStringArray:
	"""Every GDScript string literal outside comments and docstrings that matches a pattern."""
	var out := PackedStringArray()
	var i: int = 0
	var line: int = 1
	var line_start: bool = true
	while i < text.length():
		var c: String = text[i]
		if c == "\n":
			line += 1
			line_start = true
			i += 1
		elif c == " " or c == "\t":
			i += 1
		elif c == "#":
			i = _line_end(text, i)
		elif c == "\"" or c == "'":
			var start: int = i
			i = _literal(text, i, line, line_start, out)
			line += text.substr(start, i - start).count("\n")
			line_start = false
		else:
			line_start = false
			i += 1
	return out


func _line_end(text: String, i: int) -> int:
	"""The index of the newline ending the line at `i` (or the end)."""
	var j: int = text.find("\n", i)
	return text.length() if j < 0 else j


func _literal(text: String, i: int, line: int, line_start: bool, out: PackedStringArray) -> int:
	"""Read the literal starting at `i`, check it unless it is a docstring, and return the index after it."""
	var quote: String = text[i]
	if text.substr(i, 3) == quote.repeat(3):
		var close: int = text.find(quote.repeat(3), i + 3)
		var end: int = text.length() if close < 0 else close + 3
		if not line_start:
			_check(text.substr(i + 3, end - i - 6), line, out)
		return end
	var j: int = i + 1
	while j < text.length() and text[j] != quote and text[j] != "\n":
		j += 2 if text[j] == "\\" else 1
	_check(text.substr(i + 1, j - i - 1), line, out)
	return j + 1


func _check(literal: String, line: int, out: PackedStringArray) -> void:
	"""Record `literal` if any pattern matches it."""
	for re: RegEx in _patterns:
		if re.search(literal) != null:
			out.append("%d: %s" % [line, literal.left(120)])
			return


func _files() -> PackedStringArray:
	"""Every linted file: the demo's .gd and .json (its staged assets aside), the UI's .gd, and the UI manager."""
	var out := PackedStringArray()
	for root: String in ROOTS:
		_walk(root, out)
	out.append_array(EXTRA_FILES)
	return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
	"""Collect the linted files under `dir_path`, recursively."""
	if SKIP_DIRS.has(dir_path):
		return
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd") or file.ends_with(".json"):
			out.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		_walk(dir_path.path_join(sub), out)
