# Finite route, actor and occupancy component

This is component evidence using actual Directory, Residents, Transforms, Jobs,
Gear, Haul, Inventory and Locations stores with **synthetic geometry/profile
certificates and connector rates**. It does not activate production movement or
qualify the first playable Kitchen. Full graph/motion save/load, actor retirement
handoff, actual WorldRoutes/content binding, native presentation and whole-world
performance remain separate gates.

The final source is pinned in `iteration-3/source-sha256.json`. Clean import moved
this worktree's demo assets aside, removed `godot/.godot`, ran
`godot --headless --path godot --editor --quit`, then the unchanged strict
`tools/run_tests.sh` against the deterministic singleton shard containing
`test_underground_routes.gd`. Assets were restored. The runner's zero-diagnostic
and zero-leak gates were not changed.

Final exact result:

```
31 test(s), 5733 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Static analysis used `python3 tools/gdscript_warnings.py --port 6153 --max 0`
with the two pinned source/test paths. The test covers full edge and resident
identities, staged publication/abort, active-span retention, finite Dijkstra
routing, exact integer headings, current actual ownership/profile checks, shared
complete-body occupancy, stale Transform cache refusal, cold lifetime and
256 real living residents.

Independent review found that the first candidate discarded elapsed time at
each edge boundary. The corrected movement spends an exact rational tick across
freshly qualified spans, preserving geometry subdivision and rate changes.
Added regressions compare one 1024u edge to 32 × 32u edges every tick, cross 64 one-unit
spans in one tick, preserve exact half-unit carry across 300/600/900u/s spans,
and stop at a blocked next edge without banking time. Finite fraction capacity
and checked multiplication refuse rather than round.

The rejected correction run is retained under `historical-rejected/`: its
expected byte ceiling had not been updated, and a nested occupancy query reused
a packet that the new blocked-prefix comparison incorrectly treated as the
moving actor. The final comparison uses the pinned actual worker selection;
all regressions pass. Those earlier logs are not acceptance evidence. The final
iteration also refuses the entire uncommitted tick after attempted callback
reentry on a later segment, even after an earlier clear prefix. A direct
regression confirms unchanged pose and queued links followed by an exact retry.

The final 256-resident synthetic probe printed:

```
ROUTES-COMPONENT-PERF actors=256 ticks=30 elapsed_us=682277 synthetic_clearance=true
```

That is roughly 22.7ms per component tick. It **does not meet** the 2ms movement
budget and is not a native or whole-world performance qualification. Concurrent
agent/tool activity makes this diagnostic timing only. The retained exact
finite limits and real production static/dynamic adapter must still be measured.
