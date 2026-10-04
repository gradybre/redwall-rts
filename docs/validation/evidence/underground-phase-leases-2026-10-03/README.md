# Actual WorldBindings phase lease lifecycle

Decision1088 follow-through, 2026-10-03. This component connects the existing
SpaceAuthority begin/attest/end hooks to the actual shared World-owned Budget.
It preserves exact Site, Room, project and geometry pins and refuses stale,
nested, foreign or replaced leases. Cleanup still releases its own memory after
World or scope invalidation. Qualification revision remains zero until the
actual productive providers are connected; no test here claims a completed dig.

`iteration-2/source-sha256.json` pins the final corrected source. The invocation records
each exact command, duration, exit code, unchanged source and restored asset
state. Only this worktree's cache was removed, then the mandatory clean import
preceded strict CI singleton selections and the changed-file analyzer.

```text
34 test(s), 766 assertion(s), 0 failure(s)
6 test(s), 58 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Both suites have the quoted zero-diagnostic/raw-leak footer. This is 40 focused
tests and 824 assertions, separate from the full9126ba2b checkpoint. Tests
include actual project opening and Room-claim release during a lease, real
geometry publication, World teardown, opening-callback reentry and preservation
of a foreign replacement lease. Actual Sites/World/Space/Construction/Budget
owners are used with explicitly synthetic fixture room/contact permissions.

Independent review found one HIGH defect in iteration1: the call that releases
the Budget was inside `assert`, whose expression a release export omits. The
correction executes release before checking its returned value. Iteration2
reruns the strict suites and analyzer on that corrected source.

`reproduce_release.py` copies the actual transitive sources into a temporary
probe project and exports the installed Godot4.7.2 macOS universal release
template. This isolated cleanup probe uses an actual Budget and the production
cleanup method; it does not claim actual room construction. Source hashes and
commands are in each `evidence.json`. The corrected release output is:

```text
PHASE-LEASE-RELEASE checks=8 failures=0 assert_ran=false
```

The same exported probe with only the rejected assert-side-effect line restored
prints8 checks/4 failures, proving the test detects the missed cleanup and
failed next acquisition with assertions compiled out. Its raw log is retained
under `release-rejected-assert/`. Both exports confirm `assert_ran=false`.
The corrected runtime log contains no error, warning or leak report. The first
`release-corrected/` attempt never ran: incomplete preset filters and a request
for an absent arm64-only template caused export refusal. The corrected fixture
uses the installed universal template and explicit filters in
`release-corrected-v2/`; those temporary export settings change no game settings.

Independent geometry re-review accepted final source8510288b… and unchanged
testaf06d057…, matching the exported-entry hash and release runtime log. The
HIGH finding is closed; no other high/medium finding remains in this bounded
lease-lifecycle increment. The reviewer inspected the evidence without claiming
another independent engine run.
