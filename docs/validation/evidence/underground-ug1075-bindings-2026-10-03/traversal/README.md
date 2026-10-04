# Exact traversal observation and adjacent-room endpoints

The change adds live and sealed-prepared traversal snapshots. Only a typed
CLAIM_ROOM marker whose stored role is OBSTACLE and whose full owner equals its
claim owner is omitted. Actual matter, walls, unfinished excavation, furniture,
protected access and Construction claims remain. Ordinary and site-scoped
placement snapshots retain their prior behavior.

ROLE_TRANSIT keeps its root inside the exact full Room/FLOOR_DATUM and still
requires the real root Sites key, Room and immutable domain. Its entire body and
footing must fit the union of actual supported physical space across a doorway.
Storage/work retain their full-envelope single-section rule. Metadata and a
planned neighbouring Room provide no physical permission.

The fixtures use actual Buildings Room identities, Sites identities, sparse
source/region stores and shared Budget. Shell geometry and the fixture Sites
physical authority are explicitly synthetic; no production digging, profile or
navigation qualification is claimed.

Independent read-only review accepted all four pinned files. The final validation
moves assets aside, deletes this worktree's `.godot`, runs the headless editor
import, then unchanged strict singleton shards through `tools/run_tests.sh`.
Assets were restored. Final raw logs and source hashes are under `iteration-3/`.

```
75 test(s), 3280 assertion(s), 0 failure(s)
29 test(s), 780 assertion(s), 0 failure(s)
```

Each suite's exact footer reports:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`python3 tools/gdscript_warnings.py --port 6153 --max 0` on the four pinned files
reported `0 GDScript warning(s) in 0 of 4 file(s)`.

Tests cover live/prepared equivalence, sealed and stale tokens, unchanged refused
outputs, copied results, Room retirement, both doorway directions, wrong root or
Room, absent/wrong-root Site, changed paid domain, actual same-Room walls,
unfinished and access blockers, missing neighbouring footing, and a planned
neighbour without clear physical volume. The rejected fixture initially placed
an unrelated Construction claim across the Room reservation; the real overlap
gate correctly refused it. That test-only claim was moved to a separate extent.
A subsequent analyzer run rejected a test variable shadow; it was renamed.
Those historical logs are retained separately and are not acceptance evidence.

No packed columns, canonical schema or simultaneous snapshot count changed.
