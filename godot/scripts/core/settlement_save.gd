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
## after the load opened restores the target from its disk checkpoint when the caller asked for
## one (`rollback_path`: the live world is saved there before it is retired), then rolls the clock
## back (`rollback_load()`); without a checkpoint the target is left empty, never half-restored.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveWorld := preload("res://scripts/core/settlement_save_world.gd")
const Capture := preload("res://scripts/core/settlement_save_capture.gd")
const Decode := preload("res://scripts/core/settlement_save_decode.gd")
const Apply := preload("res://scripts/core/settlement_save_apply.gd")
const SaveDigest := preload("res://scripts/core/settlement_save_digest.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BUSY: StringName = &"SAVE_BUSY"
const REFUSE_LOAD_OPEN: StringName = &"SAVE_LOAD_OPEN_REFUSED"
const REFUSE_RESET: StringName = &"SAVE_LOAD_RESET_REFUSED"
const REFUSE_VERIFY: StringName = &"SAVE_LOAD_VERIFY_MISMATCH"
const REFUSE_PUBLISH: StringName = &"SAVE_LOAD_PUBLISH_REFUSED"
## The load failed after the target was retired AND its disk checkpoint would not restore: the
## target is empty, the load barrier stays held and both files are kept (ARCH-SAVE-004).
const REFUSE_ROLLBACK: StringName = &"SAVE_LOAD_ROLLBACK_FAILED"


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

class Incoming:
	"""One validated, decoded and digest-verified file, ready to apply."""
	var body: SaveFile.Body = SaveFile.Body.new()
	var header: SaveHeader.Header = SaveHeader.Header.new()
	var staged: Capture.Staged = Capture.Staged.new()


static func load_bytes(settlement: Node, manager: Node, bytes: PackedByteArray,
		content: RefCounted = null, rollback_path: String = "") -> SaveHeader.Refusal:
	"""Validate, decode and verify `bytes`; then retire, apply, prove and publish. A mounted save is
	re-mounted with `content`, or, when none is given, with the target's own mounted content
	(ADR 1228); either must be the very image the save names. With `rollback_path`, the target's
	world is first saved there as the disk checkpoint a later failure restores (ARCH-SAVE-004)."""
	var mount_content: RefCounted = content if content != null else settlement.underground_content()
	var own_content: RefCounted = settlement.underground_content()
	var incoming: Incoming = Incoming.new()
	var checked: SaveHeader.Refusal = decode_verified(bytes, settlement, manager, incoming)
	if checked.is_ok() and rollback_path != "":
		checked = _write_rollback(settlement, manager, rollback_path)
	if checked.is_ok():
		checked = _retire(settlement, manager)
	if not checked.is_ok():
		return checked
	if not manager.begin_load():
		return _no(REFUSE_LOAD_OPEN, "the GameManager refused to open a load: %s"
			% String(manager.last_refusal()))
	var applied: SaveHeader.Refusal = _apply_prove(settlement, manager, incoming, mount_content)
	if not applied.is_ok():
		return _roll_back(settlement, manager, applied, rollback_path, own_content)
	var published: SaveHeader.Refusal = _publish(manager)
	if published.is_ok():
		SaveFile.remove_file(rollback_path)
	return published


static func decode_verified(bytes: PackedByteArray, settlement: Node, manager: Node,
		out: Incoming) -> SaveHeader.Refusal:
	"""Load steps 3-5: the whole file, every section decoded, section 15 recomputed. Touches no world."""
	var checked: SaveHeader.Refusal = SaveFile.decode_file(bytes, out.body, out.header)
	if checked.is_ok():
		checked = Decode.decode_body(out.body, out.header, out.staged)
	if checked.is_ok():
		checked = Decode.verify_digest(out.staged, out.body, out.header,
			SaveWorld.bind(settlement, manager).movement)
	return checked


static func _write_rollback(settlement: Node, manager: Node, path: String) -> SaveHeader.Refusal:
	"""Step 2: the live world saved and verified at `path`. An empty settlement has nothing to keep."""
	SaveFile.remove_file(path)
	if settlement.world_ref() == EntityDirectoryScript.NULL_REF and settlement.residents().population() == 0:
		return _ok()
	var saved: SaveHeader.Refusal = save_to_path(settlement, manager, path)
	if not saved.is_ok():
		return _no(saved.code, "the rollback checkpoint: " + saved.detail)
	return _ok()


static func _roll_back(settlement: Node, manager: Node, failure: SaveHeader.Refusal, path: String,
		content: RefCounted) -> SaveHeader.Refusal:
	"""A failure after the target was retired: re-apply the disk checkpoint, then roll the clock back
	and release the load. Without a checkpoint the target is left empty. A checkpoint that will not
	restore leaves the target empty, the load barrier held and both files on disk."""
	settlement.reset()
	if path == "" or not FileAccess.file_exists(path):
		manager.rollback_load()
		return failure
	var bytes: PackedByteArray = PackedByteArray()
	var incoming: Incoming = Incoming.new()
	var restored: SaveHeader.Refusal = SaveFile.read_file(path, bytes)
	if restored.is_ok():
		restored = decode_verified(bytes, settlement, manager, incoming)
	if restored.is_ok():
		restored = _apply_prove(settlement, manager, incoming, content)
	if not restored.is_ok():
		settlement.reset()
		return _no(REFUSE_ROLLBACK, "%s (%s); the rollback checkpoint did not restore: %s %s"
			% [failure.code, failure.detail, restored.code, restored.detail])
	manager.rollback_load()
	SaveFile.remove_file(path)
	return failure


static func _retire(settlement: Node, manager: Node) -> SaveHeader.Refusal:
	"""Retire the target world through its own reset, and bind its command queue to the manager's
	clock while no load barrier is held (a queue may only rebind empty and unbarred)."""
	if not settlement.reset():
		return _no(REFUSE_RESET, "the target settlement refused its reset: %s"
			% String(settlement.last_refusal()))
	if not settlement.commands().rebind_clock(manager.clock()):
		return _no(REFUSE_RESET, "the target's command queue would not follow the manager's clock")
	return _ok()


static func _apply_prove(settlement: Node, manager: Node, incoming: Incoming,
		content: RefCounted) -> SaveHeader.Refusal:
	"""Install every section into the retired world, then recapture and compare."""
	var world: SaveWorld.World = SaveWorld.bind(settlement, manager)
	world.content = content
	var applied: SaveHeader.Refusal = Apply.apply_all(world, incoming.staged, incoming.header)
	if not applied.is_ok():
		return applied
	return _prove(world, incoming.body)


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
