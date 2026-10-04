# Actual endpoint retention boundary

A weak typed graph observer extends the existing real Inventory retention gate.
The committed component tests use an explicitly synthetic retention observer;
the actual packed Routes owner is still being implemented separately.

Independent review found and the final source fixes a cross-owner callback
ordering hole. All observer callbacks finish before a callback-free final actual
Inventory pass and exact shared Budget check. Current geometry is revalidated
before that final pass. An observer for a later changed row cannot create a
container retaining an earlier row and then publish its removal. Expired/foreign
observers refuse, and direct self-reentry cannot consume the active token.
There is no new packed or canonical wire data: two transient booleans plus the
weak native observer handle remain inside the existing bindings/control reserve.

Clean CI invocation moved this worktree's demo assets aside, deleted
`godot/.godot`, ran `godot --headless --path godot --editor --quit`, and used the
unchanged strict `./tools/run_tests.sh` singleton shard for this suite from the
complete discovered manifest. Assets were restored afterward. Import returned
zero with no raw diagnostics. Final raw logs are retained here.

```
25 test(s), 591 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Analyzer: `python3 tools/gdscript_warnings.py --port 6153 --max 0` on the two
pinned files returned `0 GDScript warning(s) in 0 of 2 file(s)`.

Independent read-only review accepted the final pinned correction; no engine
suite was duplicated by the reviewer. Historical rejected fixture output is
preserved separately: it called a nonexistent Inventory helper, corrected to
the actual `is_container_valid` reader before the final clean rerun. That earlier
failure and script errors are not part of the accepted result.
