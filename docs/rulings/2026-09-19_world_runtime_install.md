# SAVE-W1-R02 — install decoded clock and RNG together

2026-09-19 · Astra · Version 1 · RESTORE-R01 remains governing.

The clock's writer and GameManager load barrier already exist. Add stateless
`core/save_world_runtime_install.gd`, with exactly one public install operation:

`static install(world:SaveSectionWorldRuntime.Record, streams:SaveSectionRng.Record,
header_completed_tick:int, manager:GameManagerScript, store:RngScript)->SaveHeader.Refusal`.

Inputs are decoded records. The full coordinator owns file validation, same-capture
section provenance, matching the supplied RNG to the manager's actual world, disk
rollback and publication. This helper installs only these clock/RNG fields, never
acquires/releases the barrier or publishes a world. It does not call start_game,
set_speed, set_pause, pump, advance, or modify any queue. No new format or state
field is authorized.

## Preflight before any mutation

Refuse null world/streams/manager/store explicitly. Require a manager-owned load
(`is_loading()` AND `is_load_barrier_held()`), not merely pause bits or an outsider's
clock token. Refuse if already published or unrecoverable. Then validate the world
record, explicit int32 world seed, header/record tick equality, all stream columns,
the seed-dependent HUNTING tombstone, and the clock owner's pure restore_refusal.
Preserve exact codec/clock refusal codes where available; own checks use distinct
SAVE_WORLD_* codes. Do not swallow an empty error code as success.

Incoming `rng_seeded` must be true: full release saves require all fifteen sections,
and the existing section10 codec has no valid unseeded shape. Refuse false without
changing either owner; keep development WorldRuntime codec shapes unchanged.
There is no conditional omission of section10 and no silent zero/default streams.

A different OLD live RNG seed is legal and expected when loading another save.
Seed equality is not world-object identity. Do not reject legitimate replacement
or claim it proves association. Section1/10 incoming agreement is independently
checked through the tombstone; full same-capture evidence belongs to the coordinator.

## Install and bounded recovery

Before writing, capture the old RNG seeded flag and, if seeded, its seed and all
nine state/count pairs through existing readers/SaveSectionRng.capture_into. Check
all capture results. This tiny temporary record is 108 packed bytes plus scalars,
not another world/RNG store; no persistent Snapshot object is returned or retained.
An unseeded prior RNG has canonical clear state and needs no valid section10 image.

Install RNG first: seed_world(incoming seed), then restore all nine pairs through
existing SaveSectionRng.apply. Check each operation. Install the ten clock values
last through manager.restore_clock_runtime, in the existing counter order. The
manager/clock operation is atomic on refusal and emits nothing on success. No fallible
step follows a successful clock install. Return an empty refusal only after both
owners succeeded. No simulated work or random draw is consumed.

If any install step refuses, restore the RNG to its PRE-call state: clear for a
previously unseeded store; otherwise seed its prior seed then restore each saved
stream, checking every result. The clock was not changed on that path. Return a
nonempty install refusal after successful recovery. Do not call manager.rollback_load:
that would restore the earlier begin_load checkpoint and drop the barrier, which
belongs to the full coordinator and may not equal this call's starting state.

If recovery itself refuses, return `SAVE_WORLD_ROLLBACK_FAILED` with the failing
operation named and leave the barrier held. The state is then explicitly uncertain;
never claim byte-identical recovery. The coordinator MUST retain its load barrier,
refuse publication and perform its verified whole-world recovery. This helper does
not add or claim a manager-wide unrecoverable latch; that full recovery gate remains
SAVE-ORCHESTRATOR ownership. No direct write to manager/RNG private fields.

## Required evidence

Use real GameManager, RNG and both codecs. Capture an RNG with multiple live streams
advanced unequal counts, encode/decode it, restore against a different prior seed,
and compare every state/count plus subsequent draws to uninterrupted source. HUNTING
remains canonical/undrawn. Test prior unseeded target too. Encode/decode WorldRuntime
and verify all ten clock values, debt1/999999/1000000/2500001, speeds1/2/4 and valid
composite masks, all six distinct counters, terminal representable tick/debt/counters.
No ticks/day/state/speed signals or queue changes; manager remains loading, unpublished,
barrier held until its caller acts. Preserve ordinary PLAYER pause semantics elsewhere.

For nulls, missing/released/outsider barrier, published manager, false seeded flag,
non-int32 seed, header mismatch, invalid tick/speed/mask/debt/counters, bad stream
shape/zero/negative count/tombstone, verify unchanged clock/RNG/queue and held-barrier
state where relevant. Verify records remain unchanged/no retained input aliases.

Use bounded test subclasses overriding public seed/restore or manager restore to
inject one-shot install failures after preflight, so both seeded and unseeded rollback
paths actually execute. Also force a rollback-write failure and assert the explicit
unrecoverable result and retained barrier, without claiming successful recovery.
No fault switches in production code. Free Node fixtures; no fixture leaks.

Astra owns stale W1 prose, registry category3 entry, decision record and queue/evidence.
Independent Opus review and supervised full Godot suite are mandatory. Full-world
save/load, disk rollback, production startup and release readiness remain open.
