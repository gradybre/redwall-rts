# 0153 — Install decoded clock and RNG as one bounded save step

Date: 2026-09-19 · Status: Accepted implementation contract

WorldRuntime captures RNG seed metadata while section10 captures stream positions.
Reseeding alone discards those positions. The clock and GameManager restore APIs
already exist; the missing save-layer join must validate both records before writes
and recover the previous RNG if installation fails before clock commit.

[SAVE-W1-R02](../rulings/2026-09-19_world_runtime_install.md) defines that adapter,
explicit header-tick/seed/tombstone checks, manager-owned barrier and bounded recovery.
Different prior seeds are valid replacements. Unseeded incoming release saves refuse
because section10 has no valid unseeded payload; no section is silently omitted.
The existing development codec stays unchanged. The coordinator owns world-object
association, all other sections, disk rollback and publication. Recovery failure is
explicit and leaves the barrier held; it does not manufacture a successful rollback.
