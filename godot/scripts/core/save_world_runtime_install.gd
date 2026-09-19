extends RefCounted
## SAVE-W1-R02 joins decoded WorldRuntime and RNG records under the caller's manager load.
## All preflight checks precede writes. RNG installs first; the atomic clock install is last.
## A tiny temporary prior RNG image supports recovery if either installation step refuses.
## Recovery failure is explicit and leaves the barrier held for the coordinator to resolve.
## The coordinator owns file/capture validation, matching-world objects, other sections,
## disk rollback and publication. This helper never raises/lowers the barrier or pumps work.
## Incoming release state must be seeded; the section10 codec has no valid unseeded image.
## A different prior seed is legal replacement, not evidence of the wrong world object.

const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveSectionWorldRuntime := preload("res://scripts/core/save_section_world_runtime.gd")
const SaveSectionRng := preload("res://scripts/core/save_section_rng.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE

## This module's own refusals. Codec and clock codes are preserved verbatim where they exist;
## these cover only the conditions no other owner checks.
const REFUSE_NULL_INPUT: StringName = &"SAVE_WORLD_NULL_INPUT"
const REFUSE_NOT_LOADING: StringName = &"SAVE_WORLD_NOT_LOADING"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_WORLD_BARRIER_NOT_HELD"
const REFUSE_ALREADY_PUBLISHED: StringName = &"SAVE_WORLD_ALREADY_PUBLISHED"
const REFUSE_LOAD_UNRECOVERABLE: StringName = &"SAVE_WORLD_LOAD_UNRECOVERABLE"
const REFUSE_SEED_NOT_INT32: StringName = &"SAVE_WORLD_SEED_NOT_INT32"
const REFUSE_RNG_NOT_SEEDED: StringName = &"SAVE_WORLD_RNG_NOT_SEEDED"
const REFUSE_PRIOR_CAPTURE_FAILED: StringName = &"SAVE_WORLD_PRIOR_CAPTURE_FAILED"
const REFUSE_RNG_SEED_FAILED: StringName = &"SAVE_WORLD_RNG_SEED_FAILED"
const REFUSE_CLOCK_INSTALL_FAILED: StringName = &"SAVE_WORLD_CLOCK_INSTALL_FAILED"
const REFUSE_PRIOR_STREAM_FAILED: StringName = &"SAVE_WORLD_PRIOR_STREAM_FAILED"
const REFUSE_ROLLBACK_FAILED: StringName = &"SAVE_WORLD_ROLLBACK_FAILED"
## Substituted when another owner reports failure with an empty code, so a refusal can never be
## mistaken for success by a caller that tests the code rather than `is_ok()`.
const REFUSE_UNNAMED: StringName = &"SAVE_WORLD_UNNAMED_REFUSAL"


class PriorStreams:
	"""The pre-call RNG image: a seeded flag, the prior seed and the nine state/count pairs.

	Scalars plus one section 10 record. Never returned to a caller and never retained past the
	install that captured it.
	"""
	var seeded: bool = false
	var seed_value: int = 0
	var record: SaveSectionRng.Record = null

	func _init() -> void:
		"""Allocate the nine-stream column this image restores from."""
		record = SaveSectionRng.Record.new()


static func install(world: SaveSectionWorldRuntime.Record, streams: SaveSectionRng.Record,
		header_completed_tick: int, manager: GameManagerScript,
		store: RngScript) -> SaveHeader.Refusal:
	"""Install both decoded records into one world. Empty refusal only if BOTH owners succeeded.

	Everything is validated before the first mutation. On any install failure the RNG is returned
	to its pre-call state and the ORIGINAL refusal is returned; the clock is never left written on
	that path, because the clock is written last and is atomic on refusal. If the recovery itself
	refuses, `REFUSE_ROLLBACK_FAILED` is returned naming the operation that failed -- the state is
	then explicitly uncertain and no byte-identical recovery is claimed.
	"""
	var refused: SaveHeader.Refusal = _preflight_refusal(world, streams, header_completed_tick,
		manager, store)
	if not refused.is_ok():
		return refused
	var prior: PriorStreams = PriorStreams.new()
	var captured: SaveHeader.Refusal = _capture_prior(store, prior)
	if not captured.is_ok():
		return captured
	var installed: SaveHeader.Refusal = _install_streams(streams, world.world_seed, store)
	if not installed.is_ok():
		return _recover(prior, store, installed)
	if not _install_clock(world, manager):
		return _recover(prior, store, _refuse(REFUSE_CLOCK_INSTALL_FAILED,
			"the manager refused the clock runtime with %s" % manager.last_refusal()))
	return _ok()


# --- preflight -------------------------------------------------------------------------------------

static func _preflight_refusal(world: SaveSectionWorldRuntime.Record,
		streams: SaveSectionRng.Record, header_completed_tick: int, manager: GameManagerScript,
		store: RngScript) -> SaveHeader.Refusal:
	"""Every rule checked before any mutation. Internal to the one public install operation.

	Pure: it reads the two records and the manager's load phase and writes nothing at all.
	"""
	if world == null or streams == null or manager == null or store == null:
		return _refuse(REFUSE_NULL_INPUT, "world, streams, manager and store are all required")
	var barrier: SaveHeader.Refusal = _barrier_refusal(manager)
	if not barrier.is_ok():
		return barrier
	var record: SaveHeader.Refusal = SaveSectionWorldRuntime.record_refusal(world)
	if not record.is_ok():
		return _carry(record)
	if not IntMathScript.fits_int32(world.world_seed):
		return _refuse(REFUSE_SEED_NOT_INT32,
			"world seed %d is not an i32, which rng.gd::seed_world() requires" % world.world_seed)
	var header: SaveHeader.Refusal = SaveSectionWorldRuntime.header_tick_refusal(world,
		header_completed_tick)
	if not header.is_ok():
		return _carry(header)
	if not world.rng_seeded:
		return _refuse(REFUSE_RNG_NOT_SEEDED,
			"section 1 says the world is unseeded; section 10 has no valid unseeded image")
	return _stream_refusal(streams, world)


static func _stream_refusal(streams: SaveSectionRng.Record,
		world: SaveSectionWorldRuntime.Record) -> SaveHeader.Refusal:
	"""Section 10's shape, its seed-dependent tombstone, then the clock owner's pure validator."""
	var shape: SaveHeader.Refusal = SaveSectionRng.record_refusal(streams)
	if not shape.is_ok():
		return _carry(shape)
	var tombstone: SaveHeader.Refusal = SaveSectionRng.tombstone_refusal(streams,
		world.world_seed)
	if not tombstone.is_ok():
		return _carry(tombstone)
	var clock: SimClockScript.RestoreRefusal = SimClockScript.restore_refusal(
		world.completed_tick, world.debt, world.requested_speed, world.pause_mask,
		world.counters[SaveSectionWorldRuntime.COUNTER_FALLBACK],
		world.counters[SaveSectionWorldRuntime.COUNTER_DIAGNOSTIC_PAUSE],
		world.counters[SaveSectionWorldRuntime.COUNTER_ACKNOWLEDGED_CATCHUP_RESETS],
		world.counters[SaveSectionWorldRuntime.COUNTER_ACKNOWLEDGED_TICKS_DISCARDED],
		world.counters[SaveSectionWorldRuntime.COUNTER_SUBTICK_DEBT_DISCARDS],
		world.counters[SaveSectionWorldRuntime.COUNTER_DAY_BOUNDARIES_CROSSED])
	if clock.is_ok():
		return _ok()
	return _carry(SaveHeader.Refusal.new(clock.code, clock.detail))


static func _barrier_refusal(manager: GameManagerScript) -> SaveHeader.Refusal:
	"""The load must be the MANAGER's own, still open and not yet published.

	Both halves are required: `is_loading()` alone is the coordinator guard, and
	`is_load_barrier_held()` alone could be an outsider's grant on the raw clock.
	"""
	if not manager.is_loading():
		return _refuse(REFUSE_NOT_LOADING, "the manager holds no open load")
	if not manager.is_load_barrier_held():
		return _refuse(REFUSE_BARRIER_NOT_HELD, "the manager's clock barrier is not held")
	if manager.is_load_published():
		return _refuse(REFUSE_ALREADY_PUBLISHED, "this load has already published its world")
	if manager.is_load_unrecoverable():
		return _refuse(REFUSE_LOAD_UNRECOVERABLE, "this load is already marked unrecoverable")
	return _ok()


# --- install and bounded recovery -------------------------------------------------------------------

static func _capture_prior(store: RngScript, prior: PriorStreams) -> SaveHeader.Refusal:
	"""Read the pre-call RNG image. An unseeded store has a canonical clear state and needs none."""
	prior.seeded = store.is_seeded()
	if not prior.seeded:
		return _ok()
	var seed_value: IntMathScript.IntResult = store.world_seed_value()
	if not seed_value.ok:
		return _refuse(REFUSE_PRIOR_CAPTURE_FAILED,
			"the live store refused its own seed with %s" % seed_value.error)
	prior.seed_value = seed_value.value
	var captured: SaveHeader.Refusal = SaveSectionRng.capture_into(store, prior.record)
	if captured.is_ok():
		return _ok()
	return _carry(captured)


static func _install_streams(streams: SaveSectionRng.Record, world_seed: int,
		store: RngScript) -> SaveHeader.Refusal:
	"""Seed the store from section 1, then restore all nine pairs through section 10's own apply."""
	var seeded: RngScript.OpResult = store.seed_world(world_seed)
	if not seeded.ok:
		return _refuse(REFUSE_RNG_SEED_FAILED,
			"seed_world(%d) refused with %s" % [world_seed, seeded.error])
	var applied: SaveHeader.Refusal = SaveSectionRng.apply(streams, store)
	if applied.is_ok():
		return _ok()
	return _carry(applied)


static func _install_clock(world: SaveSectionWorldRuntime.Record,
		manager: GameManagerScript) -> bool:
	"""Hand the ten scalars to the manager's restore call site, in `restore_runtime()` order."""
	return manager.restore_clock_runtime(world.completed_tick, world.debt,
		world.requested_speed, world.pause_mask,
		world.counters[SaveSectionWorldRuntime.COUNTER_FALLBACK],
		world.counters[SaveSectionWorldRuntime.COUNTER_DIAGNOSTIC_PAUSE],
		world.counters[SaveSectionWorldRuntime.COUNTER_ACKNOWLEDGED_CATCHUP_RESETS],
		world.counters[SaveSectionWorldRuntime.COUNTER_ACKNOWLEDGED_TICKS_DISCARDED],
		world.counters[SaveSectionWorldRuntime.COUNTER_SUBTICK_DEBT_DISCARDS],
		world.counters[SaveSectionWorldRuntime.COUNTER_DAY_BOUNDARIES_CROSSED])


static func _recover(prior: PriorStreams, store: RngScript,
		cause: SaveHeader.Refusal) -> SaveHeader.Refusal:
	"""Return the RNG to its pre-call state and report `cause`, or report an uncertain state.

	A failed recovery is never dressed up as a clean refusal: the coordinator must keep its
	barrier, refuse publication and run its own whole-world recovery.
	"""
	var rolled: SaveHeader.Refusal = _restore_prior(prior, store)
	if rolled.is_ok():
		return cause
	return _refuse(REFUSE_ROLLBACK_FAILED,
		"install refused with %s (%s); recovery then refused at %s: %s"
			% [cause.code, cause.detail, rolled.code, rolled.detail])


static func _restore_prior(prior: PriorStreams, store: RngScript) -> SaveHeader.Refusal:
	"""Reinstall the captured image, checking every seed/stream write; clear if previously unseeded."""
	if not prior.seeded:
		store.clear()
		return _ok()
	var seeded: RngScript.OpResult = store.seed_world(prior.seed_value)
	if not seeded.ok:
		return _refuse(REFUSE_RNG_SEED_FAILED,
			"seed_world(%d) refused with %s" % [prior.seed_value, seeded.error])
	for stream_id: int in RngScript.STREAM_COUNT:
		var restored: RngScript.OpResult = store.restore_stream(stream_id,
			prior.record.unsigned_state_at(stream_id), prior.record.draw_counts[stream_id])
		if not restored.ok:
			return _refuse(REFUSE_PRIOR_STREAM_FAILED,
				"restore_stream(%d) refused with %s" % [stream_id, restored.error])
	return _ok()


# --- refusal plumbing ---------------------------------------------------------------------------------

static func _ok() -> SaveHeader.Refusal:
	"""The accepted outcome."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""One of this module's own refusals."""
	return SaveHeader.Refusal.new(code, detail)


static func _carry(refusal: SaveHeader.Refusal) -> SaveHeader.Refusal:
	"""Preserve another owner's refusal code, substituting a named one if it carried none."""
	if refusal.code != REFUSE_NONE:
		return refusal
	return _refuse(REFUSE_UNNAMED, "an owner reported failure with an empty code: %s"
		% refusal.detail)
