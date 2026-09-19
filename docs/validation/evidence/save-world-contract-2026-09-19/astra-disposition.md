# Astra disposition

SAVE-W1-R02 governs implementation. The technical review is advisory, not adopted wholesale.

Q1 decoded records; Q2 refuse unseeded incoming release saves rather than invent conditional section10 omission (ARCH-SAVE-004 requires all fifteen sections); Q3 different prior seed is valid replacement, not a world-association check; Q4 separate joint adapter leaves seven ordinary owners and full coordinator separate; Q5 Astra corrects stale comments.

The review overstates that tombstone validation requires first installing the seed: the public pure `tombstone_refusal(record, seed)` already accepts the incoming seed. Use it before mutation. WorldRuntime.record_refusal does not itself check int32 seed, so the adapter must. The proposed 108-byte RNG rollback values remain tiny cold-path scratch; there is no duplicate clock checkpoint and no rollback_load call, because that releases the barrier and restores the begin-load state rather than necessarily the pre-call state.

The manager exposes no public external-store unrecoverable latch. The new helper therefore reports explicit SAVE_WORLD_ROLLBACK_FAILED and holds the barrier; full coordinator recovery/publication gating is a remaining requirement, not a claimed existing API.
