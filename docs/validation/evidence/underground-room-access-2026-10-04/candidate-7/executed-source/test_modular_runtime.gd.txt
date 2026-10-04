extends "res://test/framework/test_case.gd"
## Actual World/RoomOrders refusal path through the real editor adapter; no source or work permission is invented.
## Existing Room registration is used only to test receipt interpretation, never to claim playable construction.

const Runtime := preload("res://demo/burrow/modular_runtime.gd")
const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Tool := preload("res://demo/burrow/modular_world_tool.gd")
const Fixture := preload("res://test/test_underground_room_admission.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Bindings := preload("res://scripts/core/underground_room_bindings.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")

class BindingObserver extends Fixture.ObservedWorld:
	var observer: Callable = Callable()

	func binding_refusal() -> StringName:
		"""Run the genuine binding observation, then one externally owned lifetime/view change."""
		var code: StringName = super.binding_refusal()
		if observer.is_valid():
			var callback: Callable = observer
			observer = Callable()
			callback.call()
		return code

class ObservedFixture extends Fixture:
	func _bind_space() -> void:
		"""Use the exact actual fixture owners with an observer at their real binding boundary."""
		super._bind_space()
		_provider = BindingObserver.new()
		_provider.arena = _budget
		assert_equal(_provider.configure(_world, _terrain, _space, _sources, _budget), &"", "observed actual provider")

class NestedRequest extends Fixture.ReleaseProbe:
	var runtime: WeakRef = null
	var request: Dictionary = {}
	var result: Dictionary = {}
	var called: bool = false

	func drop_outer_owners() -> void:
		"""Attempt a direct nested UI command inside actual cold admission, without changing its physical proof."""
		if called:
			return
		called = true
		result = (runtime.get_ref() as Runtime).submit_request(request)

var _f: Fixture = null
var _runtime: Runtime = null
var _editor: Editor = null
var _tool: Tool = null
var _camera: Camera3D = null
var _floor: int = 0
var _view_level: int = 1
var _modal: bool = false
var _late_action: int = 0
var _released_level: WeakRef = null
var _replacement: Runtime = null
var _replacement_result: StringName = &""
var _modal_calls: int = 0
var _discard_on_modal_call: int = -1


func before_each() -> void:
	"""Compose actual finite World owners through the already tested fixture; no permissive room admission."""
	_f = ObservedFixture.new()
	_f.before_each()
	assert_equal(_f.failures, PackedStringArray(), "actual owner fixture initialized")
	var level: Levels.Record = Levels.Record.new()
	assert_equal(_f._levels.level_into(1, 0, level), &"", "actual authored floor")
	_floor = level.floor_y_u
	_view_level = 1
	_modal = false
	_late_action = 0
	_released_level = null
	_replacement = null
	_modal_calls = 0
	_discard_on_modal_call = -1
	var draft: Draft = Draft.new()
	assert_equal(draft.configure(Buildings.ROOM_TYPE_KITCHEN, 1, 256, 512, Rect2i(-16, -16, 32, 32), true), &"", "Kitchen draft")
	_editor = Editor.new()
	_editor.configure(draft, 4)
	_camera = Camera3D.new()
	_tool = Tool.new()
	assert_equal(_tool.configure(_camera, _editor, Vector3i(Fixture.X, _floor, Fixture.Z), 1,
		_input_blocked, _view), &"", "actual editor/world datum")
	_tool.set_active(true)
	_runtime = Runtime.new()
	assert_equal(_runtime.configure(_editor, _tool, _f._orders, _f._rooms, _f._levels, 0), &"", "actual owner command adapter")


func after_each() -> void:
	"""Drop view callbacks before their nodes and release all actual-owner leases without leaks."""
	assert_equal(_runtime.disconnect_view(), &"", "quiescent view disconnect")
	_runtime = null
	_tool.free()
	_editor.free()
	_camera.free()
	_tool = null
	_editor = null
	_camera = null
	_f.after_each()
	assert_equal(_f.failures, PackedStringArray(), "actual owner teardown passed")
	_f = null


func _input_blocked() -> bool:
	"""No mouse event is dispatched by this component fixture; native input is separately required."""
	_modal_calls += 1
	if _modal_calls == _discard_on_modal_call:
		_editor.draft.discard()
	return _modal


func _view() -> Vector3i:
	"""The component view reports the exact bound authored floor."""
	return Vector3i(_view_level, _floor, 1)


func _draw() -> Dictionary:
	"""Create a concave plan through real editor controls; release does not order work."""
	assert_true(_editor.world_press(Vector2i.ZERO), "first stroke")
	_editor.world_motion(Vector2i(3, 1))
	_editor.world_release()
	assert_true(_editor.world_press(Vector2i(0, 2)), "adjoining stroke")
	_editor.world_motion(Vector2i(1, 3))
	_editor.world_release()
	return _editor.draft.snapshot()


func _change_view_late() -> void:
	"""Change real presentation state only after the adapter's initial view predicate."""
	match _late_action:
		0: _view_level = 2
		1: _modal = true
		2: _tool.set_active(false)


func _release_level_late() -> void:
	"""Release the host's last strong catalog handle during the actual binding callback."""
	_released_level = weakref(_f._levels)
	_f._levels = null


func _release_provider_late() -> void:
	"""Release the host's last provider reference while its own genuine binding observer is active."""
	_f._provider = null


func _configure_replacement_late() -> void:
	"""A competing host must truthfully refuse while the inspector is submitting its original plan."""
	_replacement_result = _replacement.configure(_editor, _tool, _f._orders, _f._rooms, _f._levels, 0)


func test_real_editor_confirmation_reaches_actual_physical_refusal_and_retains_draft() -> void:
	"""The missing completed approach remains an explicit real refusal; graph time cannot manufacture a Room."""
	var before: PackedByteArray = _f._state()
	var request: Dictionary = _draw()
	assert_equal(_f._state(), before, "drawing did not mutate any actual owner")
	assert_equal(_runtime.check_request(request), "", "view and owner identities match")
	assert_false(_editor.request_confirmation(), "actual physical companion refuses")
	assert_equal(_f._rooms.preflights, 1, "real RoomOrders reached actual room preflight once")
	assert_equal(_editor.draft.snapshot(), request, "exact concave Kitchen drawing retained")
	assert_equal(_f._state(), before, "no identity, paid Site, work or resource mutation")
	assert_true(_f._budget.is_quiescent(), "actual cold scope released")
	var answer: Dictionary = _runtime.submit_request(request)
	assert_equal(answer.error_code, Bindings.REFUSE_ENTRY, "exact physical refusal preserved separately from UI words")
	assert_equal(_f._state(), before, "retry still cannot spend or invent access")


func test_changed_or_forged_request_cannot_submit_different_paint_purpose_or_level() -> void:
	"""Every submitted input must still equal the actual current drawing; coordinates are never normalized away."""
	var request: Dictionary = _draw()
	var before: PackedByteArray = _f._state()
	for key: String in ["room_type", "level", "pitch_u", "revision", "cells", "allow_holes"]:
		var forged: Dictionary = request.duplicate(true)
		if key == "cells":
			forged[key] = PackedInt32Array([0, 0])
		elif key == "allow_holes":
			forged[key] = false
		else:
			forged[key] = 77
		var answer: Dictionary = _runtime.submit_request(forged)
		assert_equal(answer.error_code, Runtime.REFUSE_DRAFT, "changed %s refused" % key)
	assert_equal(_f._rooms.preflights, 0, "no forged plan entered authority")
	assert_equal(_f._state(), before, "all actual owners unchanged")
	var floated: Dictionary = request.duplicate(true)
	floated.room_type = float(request.room_type)
	assert_equal(_runtime.submit_request(floated).error_code, Runtime.REFUSE_DRAFT, "equal float ordinal refused")


func test_floor_switch_modal_or_inactive_tool_refuses_same_frame_confirmation() -> void:
	"""Hidden plans and modal UI cannot be confirmed using an earlier frame's matching view."""
	var request: Dictionary = _draw()
	_view_level = 2
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_LEVEL, "same-frame floor switch")
	_view_level = 1
	_modal = true
	assert_false(_runtime.submit_request(request).ok, "modal blocks direct confirmation")
	_modal = false
	_tool.set_active(false)
	assert_false(_runtime.submit_request(request).ok, "inactive tool refuses")
	_tool.set_active(true)
	assert_equal(_runtime.check_request(request), "", "return restores view without losing paint")
	assert_equal(_f._rooms.preflights, 0, "hidden/modal plans never reach authority")


func test_late_binding_observer_cannot_confirm_a_hidden_or_inactive_drawing() -> void:
	"""Post-owner view validation closes the real callback window before Room preflight or state mutation."""
	var request: Dictionary = _draw()
	var before: PackedByteArray = _f._state()
	for action: int in 3:
		_late_action = action
		(_f._provider as BindingObserver).observer = _change_view_late
		assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_LEVEL, "late view change refuses")
		assert_equal(_f._rooms.preflights, 0, "late change never reaches Room preflight")
		assert_equal(_f._state(), before, "actual stores conserved")
		_view_level = 1
		_modal = false
		_tool.set_active(true)
	assert_equal(_runtime.check_request(request), "", "view returns without a stuck busy flag")


func test_level_owner_release_during_observation_survives_only_the_synchronous_command() -> void:
	"""The complete submission owns its original borrowed tuple until the actual physical refusal returns."""
	var request: Dictionary = _draw()
	var before: PackedByteArray = _f._state()
	(_f._provider as BindingObserver).observer = _release_level_late
	assert_equal(_runtime.submit_request(request).error_code, Bindings.REFUSE_ENTRY, "original catalog survives command")
	assert_equal(_f._rooms.preflights, 1, "one real physical preflight")
	assert_equal(_f._state(), before, "refused command conserved actual state")
	assert_null(_released_level.get_ref(), "temporary strong borrower released on return")
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_BINDING, "next command refuses expired owner")
	assert_false(_runtime._busy, "no null dereference leaves the view stuck")


func test_replacement_host_during_editor_submission_refuses_without_pinning() -> void:
	"""An in-flight confirmation cannot silently accept a host whose callbacks were never connected."""
	_draw()
	_replacement = Runtime.new()
	(_f._provider as BindingObserver).observer = _configure_replacement_late
	assert_false(_editor.request_confirmation(), "original physical refusal")
	assert_equal(_replacement_result, Runtime.REFUSE_BINDING, "busy editor refuses replacement")
	assert_equal(_f._rooms.preflights, 1, "original owner remains connected")
	assert_equal(_replacement.configure(_editor, _tool, _f._orders, _f._rooms, _f._levels, 0), &"", "refused host can retry later")
	assert_equal(_replacement.disconnect_view(), &"", "replacement releases its real callback lease")
	_replacement = null


func test_provider_expiry_between_check_and_confirm_is_a_safe_refusal() -> void:
	"""A weak provider may expire after validation; a missing reborrow never becomes a null dereference."""
	var request: Dictionary = _draw()
	var before: PackedByteArray = _f._state()
	var provider: WeakRef = weakref(_f._provider)
	(_f._provider as BindingObserver).observer = _release_provider_late
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_BINDING, "expired provider refuses")
	assert_null(provider.get_ref(), "the view does not retain an orphan provider")
	assert_equal(_f._rooms.preflights, 0, "no Room preflight after provider expiry")
	assert_equal(_f._state(), before, "actual state conserved")
	assert_false(_runtime._busy, "safe refusal releases busy gate")


func test_final_modal_observer_cannot_change_the_drawing_after_snapshot_validation() -> void:
	"""Late read-view/modal callbacks cannot smuggle an earlier valid snapshot into the actual owner."""
	var request: Dictionary = _draw()
	var before: PackedByteArray = _f._state()
	_discard_on_modal_call = _modal_calls + 2
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_DRAFT, "late drawing mutation refused")
	assert_equal(_modal_calls, _discard_on_modal_call, "mutant ran in final callback window")
	assert_equal(_f._rooms.preflights, 0, "changed drawing never enters Room preflight")
	assert_equal(_f._state(), before, "actual state conserved")


func test_replaced_same_revision_draft_cannot_use_old_world_tool() -> void:
	"""A matching integer revision is not the same editing session."""
	_draw()
	var replacement: Draft = Draft.new()
	replacement.configure(Buildings.ROOM_TYPE_KITCHEN, 1, 256, 512, Rect2i(-16, -16, 32, 32), true)
	replacement.revision = _editor.draft.revision
	_editor.draft = replacement
	assert_equal(_runtime.submit_request(replacement.snapshot()).error_code, Runtime.REFUSE_BINDING, "replaced draft refused")
	assert_equal(_f._rooms.preflights, 0, "no different editor identity sent to actual owner")


func test_reconfigured_empty_session_cannot_move_its_existing_world_binding() -> void:
	"""An emptied editor cannot silently reuse its old floor/pitch/datum after reconfiguration."""
	_editor.draft.configure(Buildings.ROOM_TYPE_KITCHEN, 2, 128, 512, Rect2i(-16, -16, 32, 32), true)
	var request: Dictionary = _draw()
	assert_false(_runtime.submit_request(request).ok, "changed view domain refuses")
	assert_equal(_f._rooms.preflights, 0, "no plan submitted on a mismatched floor")


func test_foreign_unbound_level_catalog_cannot_replace_current_binding() -> void:
	"""Authored floor identity is checked against the actual World, not a matching UI level label."""
	var other: Runtime = Runtime.new()
	assert_equal(other.configure(_editor, _tool, _f._orders, _f._rooms, Levels.new(), 0), Runtime.REFUSE_BINDING,
		"foreign unbound catalog refuses")
	assert_equal(_runtime.configure(_editor, _tool, _f._orders, _f._rooms, _f._levels, 0), Runtime.REFUSE_BINDING,
		"configured view cannot rebind")
	assert_equal(_runtime.check_request(_draw()), "", "original owner still usable")


func test_wrong_floor_height_refuses_before_replacing_editor_callbacks() -> void:
	"""A numerically nearby floor is not the catalog's approved placement datum."""
	var tool: Tool = Tool.new()
	assert_equal(tool.configure(_camera, _editor, Vector3i(Fixture.X, _floor + 1, Fixture.Z), 1,
		_input_blocked, _view), &"", "presentation tool has an explicit different datum")
	var other: Runtime = Runtime.new()
	assert_equal(other.configure(_editor, tool, _f._orders, _f._rooms, _f._levels, 0), Runtime.REFUSE_LEVEL, "actual catalog rejects wrong height")
	tool.free()
	assert_equal(_runtime.check_request(_draw()), "", "prior valid binding survives")


func test_expired_owner_cannot_authorize_or_recreate_a_room_coordinator() -> void:
	"""The view does not keep the authoritative World graph alive after its host releases it."""
	var request: Dictionary = _draw()
	var old: WeakRef = weakref(_f._orders)
	_f._orders = null
	assert_null(old.get_ref(), "view borrowed the actual coordinator weakly")
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_BINDING, "expired owner refuses")
	# The existing fixture teardown expects its coordinator; abandon only that now-empty assertion path.
	_f._orders = Fixture.RoomFixture.SyntheticRegistration.new()


func test_nested_provider_command_cannot_reenter_or_disconnect_view_during_admission() -> void:
	"""Actual physical callbacks do not permit a second room transaction through a direct adapter call."""
	var request: Dictionary = _draw()
	var probe: NestedRequest = NestedRequest.new()
	probe.runtime = weakref(_runtime)
	probe.request = request
	_f._provider.release_probe = probe
	var before: PackedByteArray = _f._state()
	assert_equal(_runtime.submit_request(request).error_code, Bindings.REFUSE_ENTRY, "outer actual refusal retained")
	assert_true(probe.called, "real cold admission invoked observer")
	assert_equal(probe.result.error_code, Runtime.REFUSE_BUSY, "nested command refused")
	assert_equal(_f._rooms.preflights, 1, "one actual admission only")
	assert_equal(_f._state(), before, "actual state conserved")


func test_receipt_keeps_full_actual_identity_and_never_implies_furniture_or_service() -> void:
	"""Explicit fixture registration exercises receipt decoding only; the room remains genuinely bare."""
	var room: Vector2i = _f._room()
	var receipt: Dictionary = _runtime._receipt(_f._orders, room, Buildings.ROOM_TYPE_KITCHEN, _f._space.revision())
	assert_true(receipt.ok, "actual live underground Room receipt")
	assert_equal(receipt.room, room, "full slot/generation retained")
	assert_equal(receipt.world, _f._world_ref, "actual World retained")
	assert_equal(receipt.origin_u, Vector3i(Fixture.X, _floor, Fixture.Z), "exact dirt datum retained")
	assert_equal(receipt.room_type, Buildings.ROOM_TYPE_KITCHEN, "permanent Kitchen purpose")
	assert_false(_f._orders.service_refusal(room) == &"", "receipt does not grant room service")
	assert_false(_runtime._receipt(_f._orders, Vector2i(room.x, room.y + 1), Buildings.ROOM_TYPE_KITCHEN, 1).has("ok"),
		"ambiguous generation disables editor retry")
	assert_false(_runtime._receipt(_f._orders, room, Buildings.ROOM_TYPE_PRIVATE_ROOM, 1).has("ok"),
		"wrong purpose cannot be a successful receipt")


func test_old_host_disconnect_does_not_disconnect_new_editor_owner() -> void:
	"""Teardown is identity-checked and never resets paid state or replacement UI callbacks."""
	var other: Runtime = Runtime.new()
	assert_equal(other.configure(_editor, _tool, _f._orders, _f._rooms, _f._levels, 0), &"", "replacement view borrows actual owners")
	assert_equal(_runtime.disconnect_view(), &"", "old view disconnects")
	_draw()
	assert_false(_editor.request_confirmation(), "new host reaches actual refusal")
	assert_equal(_f._rooms.preflights, 1, "new host callback still connected")
	assert_equal(other.disconnect_view(), &"", "new host releases its own callbacks")
	assert_false(_editor.request_confirmation(), "disconnected editor cannot order")
	assert_equal(_f._rooms.preflights, 1, "no call after disconnect")
