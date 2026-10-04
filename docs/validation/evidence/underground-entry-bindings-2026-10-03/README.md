# Concrete entrance admission evidence

Decision1111 implements actual surface-entry admission through World, Terrain,
RoomOrders, Sites and Placement. It reserves an exact virgin cut set and retains
existing routes. It does not construct timber, excavate matter, move a worker or
qualify production source content. Motion and connector geometry in these tests
remain explicit synthetic fixtures.

The current frozen source/test hashes are in `checks6/source-sha256.json`.
`reproduce.py` moves this worktree's demo assets aside if present, removes its
Godot cache, performs a clean editor import, runs each selected suite through
the official exact-once shard interface and runs the warning analyzer with
`--max 0`. It uses an isolated user directory and restores `project.godot`
byte-for-byte and the original asset state. `checks6/commands.json` confirms
source and project hashes are unchanged and assets restored.

The two strict runner summaries are:

```text
15 test(s), 377 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

13 test(s), 466 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).

0 GDScript warning(s) in 0 of 2 file(s)
```

This is 28 tests / 843 assertions. These focused checks are not the full
no-argument integrated suite. The integration branch records that checkpoint
separately; a later integrated milestone must run the complete procedure.

## Independent review and corrections

Construction's independent review found four medium issues in the earlier
`checks-5` candidate: original-lease validation preceded an observing source
callback; another observer could follow final Terrain facts; surface contact
resolution accepted a different full section; natural footing ignored paid
backfill history. The corrected candidate adds pure scope/source guards, removes
observers after final physical facts, pins the anchor's exact section and checks
the existing canonical Site history for all natural supports. Seven regressions
cover those boundaries in the actual owner composition. The paid-history
fixtures are explicitly seeded negative state, not paid-construction evidence.
Construction independently accepted the corrected source/test at
`0bf345d577dc1c0cdbb5ee338216782d66ad9b5b44bd81c8074a50b16b346294` /
`9f6840d1d51910c26311c4e13a311d36279ac9cf50cf2ea42e05c8c03d9576ac`.
No remaining high/medium finding was reported within the admission scope.
The reviewer confirmed the history cursor borrows the configured concrete
Domain copy and does not reintroduce caller descriptor callbacks.

The memory-tool review independently found two drift-check gaps: an inherited
Frontier could add storage, and its initial fixed charge could disappear.
Both guards and negative tests were added. Geometry independently accepted the
corrected tools at SHA256 `fc9d1e048928eeef53c1969d1416381d04c86382565f8c137b683ba4e8c20a20`
and test `92a6a588e3dfd2cf30f44eec4c8fabecaebb6047b218a88cb5c4130b942100fb`.
`memory-review-corrected.log` records 73 tests, OK. The additional EntryBindings
census is454 numeric/packed bytes plus2048 helper bytes inside4096; Frontier
reserves28597. The logical whole pack remains99,959,250 bytes, leaving40,750
below100MB; native and runtime memory qualification remains open. The remaining
4096 binding bytes are reserved for the concrete Contacts owner.

All earlier rejected and superseded iterations are retained. Their presence
does not turn a prior failure into a successful run. Complete demo workflows,
productive construction, persistence, native1280×720 interaction and measured
256-resident qualification remain separate unfinished gates.
