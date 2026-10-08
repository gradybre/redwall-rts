extends RefCounted
## The settlement save and load entry points (ADR 1222 build steps 8-9).
##
## SAVE: `save_bytes(settlement, manager, out)` binds the live world, captures sections 1-14,
## derives the header identities from section 1's provenance, computes section 15 over the
## captured records and lays the whole file out. `save_to_path()` adds the atomic disk write.
##
## LOAD: `load_bytes(settlement, manager, bytes)` validates the whole file and decodes every
## section, recomputing section 15 against the decoded records BEFORE any world is touched (load
## steps 3-5). Only then does it retire the target world through its own `reset()` (ADR 1222's
## one-way bindings) and bind its command queue to the manager's clock, open the GameManager load,
## apply every section in dependency order, and prove the
## result by RECAPTURING the restored world: sections 1-14 must come back byte-identical and the
## digest must equal section 15 (load steps 7-9). Then it publishes and ends the load. A refusal
## after the load opened rolls the clock back (`rollback_load()`) and resets the settlement, so
## the target is left empty rather than half-restored; the disk-checkpoint rollback of a populated
## target is `settlement_save_slots.gd`'s.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const Capture := preload("res://scripts/core/settlement_save_capture.gd")
const Decode := preload("res://scripts/core/settlement_save_decode.gd")
const Apply := preload("res://scripts/core/settlement_save_apply.gd")
const SaveDigest := preload("res://scripts/core/settlement_save_digest.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BUSY: StringName = &"SAVE_BUSY"
const REFUSE_LOAD_OPEN: StringName = &"SAVE_LOAD_OPEN_REFUSED"
const REFUSE_RESET: StringName = &"SAVE_LOAD_RESET_REFUSED"
const REFUSE_VERIFY: StringName = &"SAVE_LOAD_VERIFY_MISMATCH"
const REFUSE_PUBLISH: StringName = &"SAVE_LOAD_PUBLISH_REFUSED"


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


# --- save ----------------------------------------------------------------------------------------

static func save_bytes(settlement: Node, manager: Node, out: PackedByteArray) -> SaveHeader.Refusal:
	"""Capture the live settlement into one complete save file in `out`."""
	var busy: SaveHeader.Refusal = quiescence_refusal(settlement, manager)
	if not busy.is_ok():
		return busy
	var world: SaveWorld.World = SaveWorld.bind(settlement, manager)
	var staged: Capture.Staged = Capture.Staged.new()
	var body: SaveFile.Body = SaveFile.Body.new()
	var captured: SaveHeader.Refusal = Capture.capture_body(world, staged, body)
	if not captured.is_ok():
		return captured
	var digested: SaveHeader.Refusal = _seal(world, staged, body)
	if not digested.is_ok():
		return digested
	return SaveFile.encode_file(body, out)


static func _seal(world: SaveWorld.World, staged: Capture.Staged,
		body: SaveFile.Body) -> SaveHeader.Refusal:
	"""Section 15: the digest under the identities the header will carry."""
	var identity: SaveHeader.Header = SaveHeader.Header.new()
	var stamped: SaveHeader.Refusal = SaveFile.header_identity_into(body.section(1), identity)
	if not stamped.is_ok():
		return stamped
	var inputs: Variant = SaveDigest.inputs_for(identity.rules_hash, identity.catalog_hash,
		identity.map_hash, identity.lookup_hash, body.completed_tick)
	var outcome: SaveDigest.DigestOutcome = SaveDigest.digest_of(staged, world.movement, inputs)
	if not outcome.ok:
		return _no(outcome.code, "section 15: " + outcome.detail)
	body.set_section(15, outcome.digest, Capture.SECTION_15_SCHEMA_VERSION, 1)
	return _ok()


static func quiescence_refusal(settlement: Node, manager: Node) -> SaveHeader.Refusal:
	"""SAVE_BUSY inside a tick, during a load, or while the stock layer holds a fault."""
	if manager.is_loading() or manager.scheduler_events().is_executing_tick():
		return _no(REFUSE_BUSY, "a tick or a load is in progress")
	if settlement._stock_retry_pending or settlement._stock_fault_halted \
			or settlement._stock_pause_held:
		return _no(REFUSE_BUSY, "the stock layer holds an unresolved fault")
	return _ok()


static func save_to_path(settlement: Node, manager: Node, path: String) -> SaveHeader.Refusal:
	"""Save, then write atomically: temp file, re-read and re-decode, rename."""
	var bytes: PackedByteArray = PackedByteArray()
	var saved: SaveHeader.Refusal = save_bytes(settlement, manager, bytes)
	if not saved.is_ok():
		return saved
	return SaveFile.write_atomic(path, bytes)


# --- load ----------------------------------------------------------------------------------------

static func load_bytes(settlement: Node, manager: Node,
		bytes: PackedByteArray) -> SaveHeader.Refusal:
	"""Validate, decode and verify `bytes`; then retire, apply, prove and publish."""
	var body: SaveFile.Body = SaveFile.Body.new()
	var header: SaveHeader.Header = SaveHeader.Header.new()
	var staged: Capture.Staged = Capture.Staged.new()
	var checked: SaveHeader.Refusal = SaveFile.decode_file(bytes, body, header)
	if checked.is_ok():
		checked = Decode.decode_body(body, header, staged)
	if checked.is_ok():
		checked = Decode.verify_digest(staged, body, header,
			SaveWorld.bind(settlement, manager).movement)
	if checked.is_ok():
		checked = _retire(settlement, manager)
	if not checked.is_ok():
		return checked
	if not manager.begin_load():
		return _no(REFUSE_LOAD_OPEN, "the GameManager refused to open a load: %s"
			% String(manager.last_refusal()))
	var applied: SaveHeader.Refusal = _apply_prove(settlement, manager, staged, body, header)
	if not applied.is_ok():
		manager.rollback_load()
		settlement.reset()
		return applied
	return _publish(manager)


static func _retire(settlement: Node, manager: Node) -> SaveHeader.Refusal:
	"""Retire the target world through its own reset, and bind its command queue to the manager's
	clock while no load barrier is held (a queue may only rebind empty and unbarred)."""
	if not settlement.reset():
		return _no(REFUSE_RESET, "the target settlement refused its reset: %s"
			% String(settlement.last_refusal()))
	if not settlement.commands().rebind_clock(manager.clock()):
		return _no(REFUSE_RESET, "the target's command queue would not follow the manager's clock")
	return _ok()


static func _apply_prove(settlement: Node, manager: Node, staged: Capture.Staged,
		body: SaveFile.Body, header: SaveHeader.Header) -> SaveHeader.Refusal:
	"""Install every section into the retired world, then recapture and compare."""
	var world: SaveWorld.World = SaveWorld.bind(settlement, manager)
	var applied: SaveHeader.Refusal = Apply.apply_all(world, staged, header)
	if not applied.is_ok():
		return applied
	return _prove(world, body)


static func _prove(world: SaveWorld.World, body: SaveFile.Body) -> SaveHeader.Refusal:
	"""Recapture the restored world: sections 1-14 byte-identical and the same section 15."""
	var staged: Capture.Staged = Capture.Staged.new()
	var again: SaveFile.Body = SaveFile.Body.new()
	var captured: SaveHeader.Refusal = Capture.capture_body(world, staged, again)
	if captured.is_ok():
		captured = _seal(world, staged, again)
	if not captured.is_ok():
		return _no(captured.code, "recapture: " + captured.detail)
	for id: int in range(1, SaveFile.SECTION_COUNT + 1):
		if again.section(id) != body.section(id):
			return _no(REFUSE_VERIFY, "section %d of the restored world differs from the file" % id)
	return _ok()


static func _publish(manager: Node) -> SaveHeader.Refusal:
	"""Publish the restored world and release the load barrier."""
	if not manager.publish_restored_world() or not manager.end_load():
		manager.rollback_load()
		return _no(REFUSE_PUBLISH, "the GameManager refused to publish: %s"
			% String(manager.last_refusal()))
	return _ok()
