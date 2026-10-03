# Exact future Room identity / source publication

The actual Directory and Buildings own identity. A synthetic test authority supplies
only the explicit component publication window and planned marker geometry; this is
not production terrain, profile, access or complete room-confirmation proof.

The new regressions preserve fine256u marker edges, reject arbitrary future source
registration and physical void/support roles, pin every mutable candidate scalar,
require the actual owner/type/window/after-facts, and preserve prior bytes and the
unspent persistent identity through abort/retry. No new wire columns are created.

```text
49 test(s), 812 assertion(s), 0 failure(s)
24 test(s), 3010 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Both suites emitted those diagnostic footers after the final reentrancy fix.
Independent review found and then accepted the correction for authority callbacks
attempting to abort/rebegin the source transaction. Four additional adversarial
regressions cover preparation/binding, seal/preflight, post-allocation publication
and candidate mutation inside callbacks. Owner mutations poison only the current
attestation; the exact original stage remains available for caller abort or retry.
The accepted final hashes are pinned below; no production qualification is implied.

Historical rejected logs preserve two earlier fixture access/type errors and a
test-only incompatible ternary. No diagnostic allowance or warning suppression
was added. Clean import removed the own worktree's cache while demo assets were
temporarily outside the project, then restored those assets.
