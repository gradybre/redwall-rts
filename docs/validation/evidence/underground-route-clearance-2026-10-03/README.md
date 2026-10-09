# Mixed-height live exclusion prerequisite

Decision1090 records the implementation and its limits. Independent geometry
review accepted the exact `iteration-1/source-sha256.json` source and test pins
with no high or medium finding. The unchanged surrounding source is based on
integration fc4fac4f3b80c0d732d4e7ad82460161b0164344.

`reproduce.py --iteration N` creates a new evidence directory, moves this
worktree's demo assets outside the Godot project if present, deletes its own
`.godot`, runs the exact clean editor import and strict runner on two singleton
CI shards, checks analyzer warnings and restores assets in `finally`. These
focused selections are not a full-suite coverage claim. No diagnostics or leak
allowance is changed.

Terrain:

```text
23 test(s), 966 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Actual WorldBindings regression:

```text
34 test(s), 766 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Analyzer: `0 GDScript warning(s) in 0 of 2 file(s)`.
Invocation records final source unchanged and assets restored. These tests
demonstrate local observations and immutable source-proof reuse. They do not
qualify actual traversable paid space, a room build, connector movement, save
composition or production performance.
