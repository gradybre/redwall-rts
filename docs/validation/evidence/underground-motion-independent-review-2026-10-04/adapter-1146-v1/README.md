# 1146 independent adapter review — original candidate

This is a read-only review of the four files identified by
`author-evidence/candidate-sha256.json` in the integration worktree. The source
manifest SHA-256 is
`9fd1efea134f53e9ce38e921aed7aa589c9a8f2edbbde316283692d64bda2b75`.
The subject base observed during review was
`205ec79ed07d6ce5ee4a169ab46b5162e5c9ffc5`.

The reviewer read the complete adapter and tests, the relevant Editor and
WorldTool lifecycle, and the actual RoomOrders, RoomBindings, WorldBindings,
LevelCatalog, Buildings and Draft boundaries. No engine or test runner was
executed by the reviewer. The original four source hashes matched the supplied
manifest before review. The author began the acknowledged corrections after
the findings were reported; corrected source acceptance is recorded separately.

The adapter invokes actual RoomOrders and preserves its physical refusal. This
does not qualify a complete demo host, paid physical composition, a furnished or
operational Kitchen, or playable acceptance. UG09 remains outside this review.

## Findings

1. **MEDIUM — view state could change after its last check.** In the original
   `modular_runtime.gd::_request_refusal` (lines 103–123),
   `confirmation_view_ready()` runs before `_owners_refusal()`. Actual owner
   binding checks invoke observer methods. The final check repeats node, Draft,
   Tool, datum and snapshot identity, but not the active level, modal state or
   active Tool state. A late observer can invalidate the visible confirmation
   context while the subsequent RoomOrders call still receives the plan. Retain
   the original identity checks and repeat current view readiness after these
   observers; exercise a late observer and require no RoomOrders preflight or
   authoritative mutation on refusal.

2. **MEDIUM — strong owner lifetime ended before submission consumed it.** In
   the original `submit_request` (lines 139–147), `_request_refusal` temporarily
   retains Orders, Bindings and Levels, then returns. Submission re-borrows the
   weak references. An observer can release the host's last Levels reference
   while the check's local reference keeps it alive; validation succeeds, the
   check frame returns, and the second weak lookup yields null. The unguarded
   `levels.level_into` then fails with `_busy` still set. Retain one strong exact
   owner tuple for the entire synchronous check and submission, including
   observer callbacks, and test outer owner release without a stale dereference
   or stranded busy state. Apply the same lifetime discipline to configure.

3. **MEDIUM — configure could report a binding that was never installed.**
   `Runtime.configure` pins its owners and returns success after calling the
   existing void `Editor.bind_confirmation`. That Editor method silently
   returns while `_submitting`. Configuring another Runtime from an in-flight
   confirmation callback can therefore report success while the previous
   callbacks remain installed; the new Runtime is already pinned and cannot
   retry configuration. Refuse this condition before pinning or verify exact
   callback installation, and test replacement configuration during submission.

All three findings were sent to the author before source publication and
acknowledged. There was no additional blocking finding in the bounded original
review. In particular, identity-matched unbinding preserves a newer owner, and
an ambiguous receipt deliberately omits `ok`, preventing automatic retry after
a potentially committed room creation.

## Evidence and limits

The copied author evidence is byte-identical to its source at copy time;
`evidence-copy.json` records each file hash. Focused-v2 reports 30 tests and
405 assertions with zero failures and zero strict/raw diagnostics or leaks.
Its one analyzer warning was retained. The test-only correction in focused-v3
reports 11 Runtime tests / 152 assertions / zero failures, zero diagnostics or
leaks, and zero analyzer warnings in four files. These runs predate the three
review corrections and are not evidence that the findings were closed.

The adapter's presentation request copies and caller objects are bounded by
the existing Draft capacity; a later host census must account for their actual
simultaneous lifetime. No whole-client memory or native allocation measurement
is asserted here. The author recovered all four original source snapshots;
the reviewer independently verified their hashes against the original manifest
and preserved the exact bytes in `source-snapshots/`. They are non-executable
text copies and were not edited to resemble the original candidate.
