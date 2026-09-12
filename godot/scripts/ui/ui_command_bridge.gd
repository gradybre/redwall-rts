extends RefCounted
## The ONLY path from a UI callback into the simulation: every player action becomes a command.
##
## Task 04.2 states the rule this file exists to keep, in one line: "No UI callback edits
## resident, ecology, jobs or inventory stores directly." A panel that calls
## `forage.set_zone_enabled()` would look identical on screen to one that goes through the
## queue, right up to the first save, the first replay and the first paused edit -- at which
## point the edit has no envelope, no sequence, no execute tick and no refusal code, and the
## world diverges from its own command log.
##
## So this bridge holds a `commands.gd` queue and NOTHING ELSE that can be written. It is
## constructed with no reference to `forage.gd`, `jobs.gd`, `residents.gd` or `inventory.gd`,
## which is not a convention but an absence: there is no store here to write to even by mistake,
## and `test_ui_command_bridge.gd` asserts the stores are byte-identical after a UI action and
## only change when ARCH-SYS-002's commit stage runs on a later tick.
##
## ---------------------------------------------------------------------------------------
## PAUSED EDITS ARE THE NORMAL CASE, NOT AN EDGE CASE. ARCH-CMD-001 stamps an accepted command
## at `completed_tick + 1`. While the world is paused that tick never arrives, so the command
## sits in the queue as VISIBLE PENDING STATE and the stores stay exactly as the player last saw
## them. That is the behaviour 04.4's acceptance asks for -- "make a next-tick zone/policy edit
## while paused, see the ghost and unchanged stocks, resume and observe one real source
## intent/job" -- and it falls out of using the queue rather than being simulated here.
##
## ---------------------------------------------------------------------------------------
## A REFUSAL IS CARRIED, NOT SWALLOWED AND NOT TRANSLATED AWAY. Every method returns the queue's
## own acceptance boolean and leaves the exact refusal code in `last_refusal()`, which UI-SET-085
## renders. `refusal_sentence()` adds a plain-language reading of the codes this milestone can
## produce and, for a code it does not know, RETURNS THE CODE ITSELF rather than a generic
## apology: an unrecognised refusal must stay legible to whoever has to fix it. §7 is explicit
## that "'Insufficient flour:2.0 U missing; mill order disabled' is valid. 'Production issue'
## alone is not."
##
## ---------------------------------------------------------------------------------------
## THIS FILE NEVER WRITES `JOB_STATE_WORK`, AND CANNOT. It has no Job store. A designation that
## commits produces a QUEUED job through ARCH-SYS-009 and stops there, which task 04.4 states is
## the correct visible outcome until task 05 lands routes.

const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## ARCH-CMD-003's kind ids for the actions this shell can actually issue.
const KIND_CANCEL_JOB: int = CommandDispatchScript.KIND_CANCEL_JOB
const KIND_DESIGNATE_ZONE: int = CommandDispatchScript.KIND_DESIGNATE_ZONE
const KIND_NAME_RESIDENT: int = CommandDispatchScript.KIND_NAME_RESIDENT
const KIND_SET_POLICY: int = CommandDispatchScript.KIND_SET_POLICY

## Decision 0043's SET_POLICY selectors and its two-valued toggle encoding.
const POLICY_QUOTA_MODE: int = CommandDispatchScript.POLICY_FORAGE_QUOTA_MODE
const POLICY_ZONE_ENABLED: int = CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED
const TOGGLE_OFF: int = CommandDispatchScript.TOGGLE_OFF
const TOGGLE_ON: int = CommandDispatchScript.TOGGLE_ON

## §8.1's "zone tiles" payload: an i32 count followed by that many ascending i32 tile indices.
const TILE_COUNT_BYTES: int = 4
const TILE_BYTES: int = 4
## ARCH-SAVE-005's alias bounds, which NAME_RESIDENT's payload is checked against before submit.
const ALIAS_MIN_CHARACTERS: int = 2
const ALIAS_MAX_CHARACTERS: int = 32

const REFUSE_NONE: StringName = &""
const REFUSE_NO_QUEUE: StringName = &"UI_NO_COMMAND_QUEUE"
const REFUSE_NO_TILES: StringName = &"UI_ZONE_STROKE_IS_EMPTY"
const REFUSE_TILES_UNSORTED: StringName = &"UI_ZONE_TILES_NOT_ASCENDING"
const REFUSE_ALIAS_LENGTH: StringName = &"UI_ALIAS_LENGTH_OUT_OF_RANGE"
const REFUSE_UNKNOWN_POLICY_VALUE: StringName = &"UI_UNKNOWN_POLICY_VALUE"

## Plain-language readings of the refusal codes this milestone can produce. A code absent from
## this table is displayed verbatim; nothing is ever replaced by a generic message.
const REFUSAL_SENTENCES: Dictionary = {
	&"COMMAND_QUEUE_FULL": "The command queue is full; resume the world to let it drain.",
	&"COMMAND_TARGET_INVALID": "That target no longer exists.",
	&"COMMAND_TARGET_MALFORMED": "That target reference is malformed.",
	&"COMMAND_DUPLICATE_KEY": "That exact command is already queued for the next tick.",
	&"COMMAND_TICK_IN_PAST": "That command was stamped for a tick that has already run.",
	&"COMMAND_PAYLOAD_ARENA_FULL": "The command payload arena is full.",
	&"COMMAND_UNSUPPORTED_FEATURE": "That command has no owning store yet.",
	&"COMMAND_DUPLICATE_INTENT": "This designation was already made by the same intent.",
	&"COMMAND_TARGET_STALE": "That target was destroyed before the command ran.",
	&"COMMAND_TARGET_KIND": "That reference now points at a different kind of thing.",
	&"COMMAND_ZONE_TILE_RANGE": "A tile in that stroke is outside the map.",
	&"COMMAND_ZONE_TILE_UNSORTED": "The tiles in that stroke are not in ascending order.",
	&"COMMAND_ZONE_CAPACITY": "No harvest zone rows are free.",
	&"COMMAND_ZONE_LINK_CAPACITY": "That stroke needs more tile links than remain.",
	&"COMMAND_BASIN_TYPE": "That basin is not a forage basin.",
	&"COMMAND_BASIN_CHAIN": "That target is a designation, not a basin.",
	&"COMMAND_JOB_NOT_CANCELLABLE": "That job has already finished or been cancelled.",
	&"COMMAND_POLICY_NOT_VALID_HERE": "That policy does not apply to this kind of zone.",
	&"COMMAND_ALIAS_LENGTH": "A name must be 2 to 32 characters.",
	&"COMMAND_ALIAS_CONTROL_CHARACTER": "A name may not contain control characters.",
	&"COMMAND_ALIAS_MALFORMED_UTF8": "That name is not valid UTF-8.",
	&"COMMAND_STORE_NOT_BOUND": "The store that command writes to is not bound.",
	&"UI_NO_COMMAND_QUEUE": "No command queue is bound to the interface.",
	&"UI_ZONE_STROKE_IS_EMPTY": "Paint at least one tile before designating.",
	&"UI_ZONE_TILES_NOT_ASCENDING": "The painted tiles must be in ascending order.",
	&"UI_ALIAS_LENGTH_OUT_OF_RANGE": "A name must be 2 to 32 characters.",
	&"UI_UNKNOWN_POLICY_VALUE": "That policy value is not one this zone accepts.",
	&"UI_SHELL_NOTHING_SELECTED": "Nothing is selected. Pick a tile on the map first.",
	&"UI_SHELL_NO_COMMAND_BRIDGE": "The interface is not connected to the command queue.",
	&"UI_SHELL_TILE_OUT_OF_RANGE": "That tile is outside the map.",
	&"UI_SHELL_TILE_NOT_ASCENDING": "Paint tiles in order; that one is already behind the stroke.",
	&"UI_SHELL_STROKE_FULL": "This stroke already holds as many tiles as a zone can link.",
	&"UI_SHELL_NO_PRESENTATION_SNAPSHOT": "No presentation snapshot is bound, so no layer can be hidden.",
	&"UI_SHELL_ELEMENT_NOT_WIRED": "That control has no owning store yet.",
	&"UI_SHELL_UNKNOWN_ELEMENT": "That control is not part of this interface.",
}

var _queue: CommandsScript = null
## Reused submission scratch. One command is built and submitted at a time, so a single
## instance is enough and no player action allocates a record.
var _command: CommandsScript.Command = CommandsScript.Command.new()
var _result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
var _payload: PackedByteArray = PackedByteArray()
var _submitted: int = 0
var _refused: int = 0
var _last_refusal: StringName = REFUSE_NONE


func _init(p_queue: CommandsScript = null) -> void:
	"""Adopt the settlement's command queue. No store is taken, because none may be written."""
	_queue = p_queue


func bind_queue(p_queue: CommandsScript) -> bool:
	"""Point the bridge at a live command queue. Refuses null rather than going quiet."""
	if p_queue == null:
		return _refuse(REFUSE_NO_QUEUE)
	_queue = p_queue
	_last_refusal = REFUSE_NONE
	return true


func designate_zone(basin: Vector2i, zone_type: int, danger_band: int,
		tiles: PackedInt32Array) -> bool:
	"""Queue one DESIGNATE_ZONE over a generated ecology basin. Writes no store.

	The tiles are §8.1's zone-tile payload and must be ascending, which is the owning schema's
	rule; an empty or unsorted stroke is refused HERE so the player is told about their own
	stroke rather than reading a queue-level schema code.
	"""
	if tiles.is_empty():
		return _refuse(REFUSE_NO_TILES)
	if not _is_ascending(tiles):
		return _refuse(REFUSE_TILES_UNSORTED)
	_build_tile_payload(tiles)
	return _submit(KIND_DESIGNATE_ZONE, basin, zone_type, danger_band, _payload)


func set_zone_enabled(zone: Vector2i, enabled: bool) -> bool:
	"""Queue one SET_POLICY turning a designation's harvesting on or off."""
	return _submit(KIND_SET_POLICY, zone, POLICY_ZONE_ENABLED,
		TOGGLE_ON if enabled else TOGGLE_OFF, PackedByteArray())


func set_quota_mode(zone: Vector2i, mode: int) -> bool:
	"""Queue one SET_POLICY choosing decision 0030's quota mode for a zone."""
	if mode < 0 or mode >= ForageScript.QUOTA_MODE_COUNT:
		return _refuse(REFUSE_UNKNOWN_POLICY_VALUE)
	return _submit(KIND_SET_POLICY, zone, POLICY_QUOTA_MODE, mode, PackedByteArray())


func cancel_job(job: Vector2i) -> bool:
	"""Queue one CANCEL_JOB. The identity is the whole command, so it carries no payload."""
	return _submit(KIND_CANCEL_JOB, job, 0, 0, PackedByteArray())


func name_resident(resident: Vector2i, alias: String) -> bool:
	"""Queue one NAME_RESIDENT carrying ARCH-SAVE-005's sanitized alias as UTF-8 bytes."""
	if alias.length() < ALIAS_MIN_CHARACTERS or alias.length() > ALIAS_MAX_CHARACTERS:
		return _refuse(REFUSE_ALIAS_LENGTH)
	return _submit(KIND_NAME_RESIDENT, resident, 0, 0, alias.to_utf8_buffer())


func _submit(kind: int, target: Vector2i, arg0: int, arg1: int,
		payload: PackedByteArray) -> bool:
	"""Fill the reused envelope and hand it to the queue. The queue decides, not this file."""
	if _queue == null:
		return _refuse(REFUSE_NO_QUEUE)
	_command.reset()
	_command.kind = kind
	_command.target_slot = target.x
	_command.target_generation = target.y
	_command.arg0 = arg0
	_command.arg1 = arg1
	_command.payload = payload
	if not _queue.submit_into(_command, _result):
		return _refuse(_result.error)
	_submitted += 1
	_last_refusal = REFUSE_NONE
	return true


static func _is_ascending(tiles: PackedInt32Array) -> bool:
	"""True when every tile index is strictly greater than the one before it."""
	for index: int in range(1, tiles.size()):
		if tiles[index] <= tiles[index - 1]:
			return false
	return true


func _build_tile_payload(tiles: PackedInt32Array) -> void:
	"""Encode §8.1's zone-tile payload into the reused buffer: count, then ascending indices."""
	_payload.resize(TILE_COUNT_BYTES + TILE_BYTES * tiles.size())
	_payload.encode_s32(0, tiles.size())
	for index: int in tiles.size():
		_payload.encode_s32(TILE_COUNT_BYTES + index * TILE_BYTES, tiles[index])


func refusal_sentence(code: StringName) -> String:
	"""A plain reading of a refusal code for UI-SET-085, or the code itself when unknown.

	An unknown code is returned verbatim on purpose. §7 forbids a message that names no cause,
	and a code a player can quote is more useful than a sentence this file invented.
	"""
	if code == REFUSE_NONE:
		return ""
	if REFUSAL_SENTENCES.has(code):
		return "%s (%s)" % [REFUSAL_SENTENCES[code], code]
	return String(code)


func last_refusal_sentence() -> String:
	"""The displayable reading of the most recent refusal, or "" after a successful action."""
	return refusal_sentence(_last_refusal)


func pending_count() -> int:
	"""How many commands are queued and not yet committed. Zero when nothing is bound."""
	if _queue == null:
		return 0
	return _queue.pending_count()


func submitted_count() -> int:
	"""How many player actions this bridge has turned into accepted commands."""
	return _submitted


func refused_count() -> int:
	"""How many player actions were refused, here or by the queue."""
	return _refused


func queue() -> CommandsScript:
	"""The bound command queue, or null. Exposed so a test can prove it is the settlement's."""
	return _queue


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful action."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code, count the refused action, and return false.

	Every refusal is counted here rather than at each call site, so a refusal path added later
	cannot quietly escape the tally the UI reports.
	"""
	_last_refusal = code
	_refused += 1
	return false
