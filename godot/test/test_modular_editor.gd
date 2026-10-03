extends "res://test/framework/test_case.gd"
## UI-owner boundary tests. Synthetic callbacks never stand in for paid room construction.

const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")

class Owner extends RefCounted:
	var calls: int = 0
	var blocker: String = ""
	var reject: bool = false
	var malformed: bool = false
	var editor: Editor = null
	var nested_accepted: bool = false
	var replace_on_check: bool = false
	var change_on_submit: bool = false

	func check(_snapshot: Dictionary) -> String:
		"""Represent a freshly changed world obstruction."""
		if replace_on_check:
			var replacement: Draft = Draft.new()
			replacement.configure(0, 1, 256, 512, Rect2i(-16, -16, 32, 32), false)
			replacement.revision = editor.draft.revision
			editor.draft = replacement
		return blocker

	func submit(_snapshot: Dictionary) -> Variant:
		"""Count explicit submissions and challenge the UI's duplicate-confirm guard."""
		calls += 1
		if editor != null:
			nested_accepted = editor.request_confirmation()
			if change_on_submit:
				editor.draft.begin_stroke(Draft.RECTANGLE, Vector2i(5, 1), 0, false)
				editor.draft.extend_stroke(Vector2i(6, 3))
				editor.draft.finish_stroke()
		if malformed:
			return {"ok": "yes"}
		return {"ok": not reject, "error": "Landing occupied." if reject else ""}

var _editor: Editor = null
var _owner: Owner = null


func before_each() -> void:
	"""Use actual controls outside the tree; all owned nodes are freed after each case."""
	var draft: Draft = Draft.new()
	draft.configure(0, 1, 256, 512, Rect2i(-16, -16, 32, 32), false)
	_editor = Editor.new()
	_editor.configure(draft, 8)
	_owner = Owner.new()


func after_each() -> void:
	"""Free the complete widget subtree and borrowed synthetic owner."""
	_editor.free()
	_editor = null
	_owner = null


func _room() -> void:
	"""Draw through the host-facing integer pointer API."""
	assert_true(_editor.world_press(Vector2i.ZERO), "press handled")
	_editor.world_motion(Vector2i(4, 4))
	_editor.world_release()


func test_world_release_only_retains_blueprint() -> void:
	"""Dragging and release never calls the coordinator."""
	_editor.bind_confirmation(_owner.check, _owner.submit)
	_room()
	assert_equal(_owner.calls, 0, "no order while drawing")
	assert_false(_editor.draft.visible_cells().is_empty(), "blueprint retained")
	assert_true(_editor.request_confirmation(), "explicit confirmation submits")
	assert_equal(_owner.calls, 1, "one order")
	assert_true(_editor.draft.visible_cells().is_empty(), "successful draft consumed")
	assert_false(_editor.request_confirmation(), "duplicate Enter cannot resubmit empty draft")


func test_unbound_editor_cannot_authorize_a_room() -> void:
	"""Geometry alone is not construction authority."""
	_room()
	assert_false(_editor.request_confirmation(), "unbound confirmation refused")
	assert_false(_editor.draft.visible_cells().is_empty(), "preview kept")


func test_changed_world_and_owner_rejection_preserve_draft() -> void:
	"""Both preflight and atomic commit refusal leave the drawing intact."""
	_editor.bind_confirmation(_owner.check, _owner.submit)
	_room()
	var before: Dictionary = _editor.draft.snapshot()
	_owner.blocker = "Stair landing occupied."
	assert_false(_editor.request_confirmation(), "fresh site refuses")
	assert_equal(_owner.calls, 0, "blocked site submits nothing")
	_owner.blocker = ""
	_owner.reject = true
	assert_false(_editor.request_confirmation(), "atomic owner refuses changed site")
	assert_equal(_editor.draft.snapshot(), before, "failed confirmation preserves draft")


func test_callback_cannot_duplicate_confirmation() -> void:
	"""Synchronous owner callbacks cannot recursively submit a second paid order."""
	_editor.bind_confirmation(_owner.check, _owner.submit)
	_owner.editor = _editor
	_room()
	assert_true(_editor.request_confirmation(), "outer order accepted")
	assert_false(_owner.nested_accepted, "reentrant request refused")
	assert_equal(_owner.calls, 1, "one coordinator call")


func test_malformed_owner_answer_disables_retry_without_erasing_draft() -> void:
	"""An ambiguous receipt is not treated as safely rolled back and blindly resubmitted."""
	_editor.bind_confirmation(_owner.check, _owner.submit)
	_owner.malformed = true
	_room()
	var before: Dictionary = _editor.draft.snapshot()
	assert_false(_editor.request_confirmation(), "malformed answer rejected")
	assert_false(_editor.request_confirmation(), "retry disabled until owner rebind")
	assert_equal(_owner.calls, 1, "ambiguous result never automatically retried")
	assert_equal(_editor.draft.snapshot(), before, "reviewable drawing retained")


func test_checker_cannot_replace_session_with_same_revision() -> void:
	"""Revision equality does not authorize submission from a different editing session."""
	_editor.bind_confirmation(_owner.check, _owner.submit)
	_owner.editor = _editor
	_owner.replace_on_check = true
	_room()
	assert_false(_editor.request_confirmation(), "changed session requires a fresh review")
	assert_equal(_owner.calls, 0, "old geometry was never sent for construction")


func test_committed_receipt_preserves_a_newer_draft_created_during_submit() -> void:
	"""After world commit, report success truthfully but consume only the submitted revision."""
	_editor.bind_confirmation(_owner.check, _owner.submit)
	_owner.editor = _editor
	_owner.change_on_submit = true
	_room()
	var revision: int = _editor.draft.revision
	assert_true(_editor.request_confirmation(), "accepted world transaction is not reported as rollback")
	assert_equal(_owner.calls, 1, "one order")
	assert_true(_editor.draft.revision > revision, "new revision survives")
	assert_false(_editor.draft.visible_cells().is_empty(), "new unsubmitted drawing is never discarded")


func test_tool_selection_and_escape_preserve_previous_blueprint() -> void:
	"""Tool changes retain the previous paint; escape cancels only the active drag."""
	_room()
	var before: Dictionary = _editor.draft.snapshot()
	assert_true(_editor.select_tool(Draft.TUNNEL, false, 1), "route tool available")
	_editor.world_press(Vector2i(5, 2))
	_editor.world_motion(Vector2i(9, 2))
	assert_true(_editor.cancel_stroke(), "one escape cancels gesture")
	assert_false(_editor.cancel_stroke(), "next escape belongs to host")
	assert_equal(_editor.draft.snapshot(), before, "previous paint retained")
	assert_false(_editor.select_tool(99, false, 1), "bad tool refused")


func test_all_buttons_have_keyboard_focus_and_minimum_hit_height() -> void:
	"""The inspector's actions remain reachable without world clicks at the small HUD size."""
	var pending: Array[Node] = [_editor]
	var buttons: int = 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Button:
			var button: Button = node as Button
			assert_true(button.custom_minimum_size.y >= 32.0, "minimum32pixelhitheight")
			assert_true(button.focus_mode != Control.FOCUS_NONE, "keyboardfocusavailable")
			buttons += 1
		for child: Node in node.get_children():
			pending.append(child)
	assert_true(buttons >= 5, "actual inspector actions visited")


func test_live_drawing_and_inspector_input_at_1280x720() -> void:
	"""A child viewport exercises actual drag capture, GUI history, refusal and narrow panel bounds."""
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://test/live/modular_editor_live.gd"]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var lines: PackedStringArray = "".join(PackedStringArray(output)).split("\n")
	var checks: int = 0
	var summary: bool = false
	for line: String in lines:
		if line.begins_with("MODULAR-EDITOR "):
			checks += 1
			assert_true(line.ends_with(": PASS"), line)
		elif line.begins_with("MODULAR-EDITOR-SUMMARY "):
			summary = line.ends_with(" 0 failures")
		elif line.contains("ERROR:") or line.contains("WARNING:") or line.contains("leaked at exit") \
				or line.contains("ObjectDB instance") or line.contains("resources still in use"):
			fail("child diagnostics: " + line)
	assert_true(checks >= 35, "live checks actually executed")
	assert_true(summary, "live summary confirms zero failures")
	assert_equal(code, 0, "live fixture terminated normally")
