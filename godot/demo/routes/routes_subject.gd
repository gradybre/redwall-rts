extends "res://demo/lens_subject.gd"
## Whom the "Getting there: Routes" layer is drawn for, in the Map layer picker's words (decision 0461; the picker's
## subject line and notes, demo/ui/demo_lens_picker.gd): the selected residents, each with its own route and what
## holds it up -- never the first selected standing in for a group (MOVE-REQ-012) -- or, with nobody selected, the
## village's public ways. The words are written by demo_routes.gd a few times a second; this only holds them.

const NOBODY: String = "Routes for: the village's public ways (nobody selected)"
const ONE: String = "Routes for: %s"
const GROUP: String = "Routes for: %d selected, each its own route"
## The legend's promise (ECO-039), always in the notes with nobody selected.
const PUBLIC_NOTE: String = ("Public ways take everyone, carrying, without swimming. Shortcuts — a swim, a narrow "
	+ "tunnel — are optional: nobody is made to swim.")

var _line: String = NOBODY
var _notes: String = PUBLIC_NOTE


func has_subject() -> bool:
	"""The Routes layer is always drawn for someone (the public walker with nobody selected)."""
	return true


func subject_line() -> String:
	"""Whose routes are drawn."""
	return _line


func notes() -> String:
	"""Each member's stretches and hold-up, or the public ways' note."""
	return _notes


func set_words(line: String, words: String) -> void:
	"""New words; the revision moves only when they changed (the picker re-texts on it)."""
	if line == _line and words == _notes:
		return
	_line = line
	_notes = words
	revision += 1
