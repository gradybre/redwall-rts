# Retained snapshot revision validation

The nine-line public reader validates the exact live geometry revision, actual
source facts and retained claim lifetimes without creating another Snapshot or
performing repeated public source lookups. It adds no state or packed buffers.
Underlying CoreSources/Buildings getters may create short-lived result objects;
this is not a claim of transitive allocation-free validation or native timing.

The isolated worktree moved its demo assets aside, deleted `godot/.godot`, ran
`godot --headless --path godot --editor --quit`, then ran the unchanged strict
`./tools/run_tests.sh` with the Owner suite's singleton shard from the full
discovered manifest. Assets were restored afterward. The complete import and
strict logs are retained here; import returned zero with no raw diagnostics.

Final strict summary:

```
59 test(s), 3010 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer command was `python3 tools/gdscript_warnings.py --port 6153 --max 0`
with the two pinned files; its result was
`0 GDScript warning(s) in 0 of 2 file(s)`.

Independent read-only source review accepted the exact nine-line source delta.
The final test revision replaces an incorrect assumed Building interior value
with the actual original getter value; it does not change production source.
The rejected earlier test fixture's log is preserved under
`historical-fixture-refusal/`, including its failure and diagnostics. Final
regressions cover unbound/stale revisions, unpublished staging, unchanged live
bytes, real Building source drift, retired project claims and destroyed World.
These focused checks do not replace the full composed checkpoint.
