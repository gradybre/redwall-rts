# Bounded prepared observations

`prepared_region_observation_into` and `prepared_edge_metadata_reused_into`
copy exact prepared metadata into caller-owned fixed scratch without provider
callbacks or a source census per row. They require the actual sealed token,
full generation, live World and unchanged geometry; Routes also requires its
actual shared cold lease and current profile revision. These are observations,
not source-freshness or publication permission. The consumer must call full
`prepared_refusal` before and after the entire loop and publish certificate
state only after the actual successful graph swap and matching publication token.

The tests perform 1,536 observations with zero counted source reads, including
an actual sealed future Space candidate. An actual Building mutation remains
visible to the mandatory final full source preflight and is refused. Other
regressions cover wrong or unsealed tokens, stale full generations, exact output
shape, abort and released/replaced cold leases. Refused outputs remain unchanged.
The fixtures use real identity/geometry owners and synthetic geometry/profile
proofs; they do not qualify production traversal or the whole simulation budget.

Independent read-only review accepted the four exact source pins. No new packed
or scalar member, image, allocator, wire field or persistent state is introduced.

The clean run moved this worktree's demo assets aside, deleted its `.godot`,
ran the headless editor import, then ran unchanged strict singleton shards via
`tools/run_tests.sh`; assets were restored. Raw logs are retained here.

```
77 test(s), 4845 assertion(s), 0 failure(s)
34 test(s), 8935 assertion(s), 0 failure(s)
```

Both suites report exactly:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`python3 tools/gdscript_warnings.py --port 6153 --max 0` on the four pinned files
reported `0 GDScript warning(s) in 0 of 4 file(s)`.
