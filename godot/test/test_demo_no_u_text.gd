extends "res://test/framework/test_case.gd"
## No player-facing "U" (decision 1011 §4 Tests, DEC-049; phase 2, decision 1801). A lint over the demo's scripts and
## text tables and the settlement UI's scripts: a string literal -- outside comments and docstrings -- may not print an
## amount in the catalogue unit ("12 U", "%d U", "%.1f U", "%s U", a bare " U" appended to a number), call the
## underground "the U view", or count goods in "units" ("NP a unit", "3 units"). Amounts are worded by
## scripts/ui/goods_measures.gd. Key hints ("U to return", "U: back to the surface", ["U", "Underground"]) are not
## amounts and pass.
##
## ALLOWLIST: the files still being converted, each with the exact findings it may hold. It shrank slice by slice
## (decision 1801) and has been EMPTY since slice 9, when the old U helpers were deleted; it stays empty.

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
		if over_allowance(found.size(), allowed):
			fail("%s: %d player-facing U string(s), %d allowed:\n    %s" % [path, found.size(), allowed,
				"\n    ".join(found)])
		else:
			assert_true(true, "%s is clean" % path)


func test_the_allowlist_names_only_files_that_still_need_it() -> void:
	"""An allowlist entry is exact: a file converted below its count must have its entry lowered or removed, so the
	list only ever shrinks."""
	assert_equal(ALLOWLIST.size(), 0, "slice 9: the allowlist is empty and every old U helper deleted")
	for path: String in ALLOWLIST:
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		assert_true(allowance_exact(findings(path).size(), int(ALLOWLIST[path])), "%s's allowlist count is exact (%d)"
			% [path, findings(path).size()])


func test_the_walk_covers_the_demo_the_ui_and_the_text_tables() -> void:
	"""The lint reads the demo's scripts and JSON tables, the UI's scripts and the UI manager, and never the staged art."""
	var files: PackedStringArray = _files()
	for path: String in ["res://demo/ui/demo_hud_model.gd", "res://demo/sound/sound_table.json", "res://scripts/ui/hud.gd",
			"res://scripts/ui/goods_measures.gd", "res://scripts/systems/ui_manager.gd"]:
		assert_true(files.has(path), "%s is linted" % path)
	for path: String in files:
		if path.begins_with("res://demo/assets/"):
			fail("the staged art is not linted: %s" % path)
	assert_true(not files.has("res://demo/demo_village.tscn"), "only .gd and .json")


func test_a_file_over_its_allowance_fails() -> void:
	"""The allowance is a ceiling: at it passes, one over fails; a file not on the list is allowed none."""
	assert_false(over_allowance(2, 2), "at the allowance")
	assert_true(over_allowance(3, 2), "one over")
	assert_true(over_allowance(1, int(ALLOWLIST.get("res://no/such/file.gd", 0))), "not listed: none allowed")
	assert_false(over_allowance(0, 0), "clean")
	assert_true(allowance_exact(2, 2), "an exact entry")
	assert_false(allowance_exact(1, 2), "a file converted below its entry must lower it")


func allowance_exact(found: int, allowed: int) -> bool:
	"""Whether an allowlist entry is exactly what its file still holds (see ALLOWLIST: it only ever shrinks)."""
	return found == allowed


func over_allowance(found: int, allowed: int) -> bool:
	"""Whether a file holds more findings than its allowlist entry lets it."""
	return found > allowed


# --- the scanner, on synthetic text -------------------------------------------------------------------------------

func test_flags_amounts_in_the_unit() -> void:
	"""Each forbidden form is found."""
	for line: String in ['var a := "12 U of wood"', 'var a := "%d U" % n', 'var a := "%.1f U left" % f',
			'var a := "herbs %s U" % s', 'var a := str(n) + " U"', 'var a := "4\\u00a0U"', 'const K := "the U view"',
			'var a := "(%d NP a unit)" % n', 'var a := "a unit for every four guests"', 'var a := "3 units"',
			'var a := &"5 U"', "var a := '7 U'", 'f(x, "U View")', 'var a := "4\u00a0U"'.replace("\\u00a0", "\u00a0")]:
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
	assert_equal(scan_source('var a := "open\nvar b := 9 # 9 U"').size(), 0, "an unclosed string ends at its line")


func test_a_triple_quoted_string_that_is_a_value_is_linted() -> void:
	"""A triple-quoted string assigned or passed is text, not a docstring."""
	assert_equal(scan_source('const T := """long\n12 U text"""').size(), 1, "assigned")
	assert_equal(scan_source('func f() -> void:\n\t"""docstring\n12 U"""\n\tvar a := 1').size(), 0, "after a header: a docstring")
	assert_equal(scan_source('func f() -> void: """3 units"""').size(), 0, "an inline docstring")
	assert_equal(scan_source('var t := (\n\t"""12 U""")').size(), 1, "a value on a line of its own is text")
	assert_equal(scan_source('var t := [\n\t"""12 U""",\n]').size(), 1, "an array element is text")


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
	var head: int = 0
	var prev: String = ""
	while i < text.length():
		var c: String = text[i]
		if c == "\n":
			line += 1
			head = i + 1
			i += 1
		elif c == " " or c == "\t":
			i += 1
		elif c == "#":
			i = _line_end(text, i)
		elif c == "\"" or c == "'":
			var start: int = i
			i = _literal(text, i, line, _docstring_here(text, head, start, prev), out)
			line += text.substr(start, i - start).count("\n")
			prev = c
		else:
			prev = c
			i += 1
	return out


func _docstring_here(text: String, head: int, at: int, prev: String) -> bool:
	"""Whether a triple-quoted string at `at` is a docstring: right after a block header's ':' -- on a line of its own,
	or inline after a `func` header. A triple-quoted VALUE (assigned, passed, in an array) is player text."""
	if prev != ":":
		return false
	var before: String = text.substr(head, at - head).strip_edges()
	return before.is_empty() or before.begins_with("func ") or before.begins_with("static func ")


func _line_end(text: String, i: int) -> int:
	"""The index of the newline ending the line at `i` (or the end)."""
	var j: int = text.find("\n", i)
	return text.length() if j < 0 else j


func _literal(text: String, i: int, line: int, docstring: bool, out: PackedStringArray) -> int:
	"""Read the literal starting at `i`, check it unless it is a docstring, and return the index after it."""
	var quote: String = text[i]
	if text.substr(i, 3) == quote.repeat(3):
		var close: int = text.find(quote.repeat(3), i + 3)
		var end: int = text.length() if close < 0 else close + 3
		if not docstring:
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
