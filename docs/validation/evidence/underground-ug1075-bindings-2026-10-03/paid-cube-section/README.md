# Exact paid-cube section observation

`section_for_paid_cube_into(room, origin_u, expected_revision, out)` observes
actual full-Room CLAIM_ROOM rows intersecting the complete paid 1024u cube.
All intersecting claims must name one full live FLOOR_DATUM owned by that Room,
with matching level/source revisions and its self-qualified section handle.
No upper-cut Y becomes an inferred floor Y. Empty, ambiguous, missing, stale or
foreign links refuse without modifying the caller's fixed six-I32 scratch.

Alignment and the far corner are checked in int64 against the immutable datum
and complete Domain. No per-row box, handle array, snapshot or new retained state
is allocated. Existing actual-source readers retain their already declared cold
OpResult/native costs. Full source/claim validation brackets the scalar scan;
the query admits the conservative 4R+3O row-work bound before reading. It is a
cold metadata observation, not a worker/tick query or permission to excavate,
finish, walk, grant room area or turn the metadata envelope into usable space.

Six new tests cover multiple fine concave strips sharing a section, upper cubes
above a lower floor, half-open touching, physical-only rows, ambiguous older
sections, missing/foreign floor links, actual source drift, Room generation and
retirement, overflow, domain alignment, exact output shape, bounded work and the
unchanged actual 6,144-region/2,048-source pack. Geometry is explicitly synthetic;
Directory/Buildings/source identities are real. No production terrain/profile
qualification is claimed.

The clean run moved assets aside, deleted only this worktree's `.godot`, imported
with the headless editor, and invoked the unchanged strict test runner on its
singleton shard. Assets were restored. Independent read-only source review
accepted both exact pinned files with no high/medium finding.

```
83 test(s), 4961 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer command uses `--port 6153 --max 0`; its exact output is `0 GDScript warning(s) in 0 of 2 file(s)`.
