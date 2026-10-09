# 1146 independent correction review — focused-v5

All four corrected source hashes in `source-pins.json` matched at the start and
end of this read-only review. All four recovered original source files also
matched the original manifest exactly. The originals are preserved in
`../adapter-1146-v1/source-snapshots/`; this directory contains the corrected
snapshots and exact unified delta. No source, project, cache, or engine was
changed or run by the reviewer.

The truthful callback-binding correction closes the third original finding:
Editor now reports whether the callbacks were actually installed, and Runtime
clears its temporary handles if binding is refused. Its new regression attempts
replacement during a real Editor submission, verifies the original callback
remains, and successfully retries the previously refused Runtime later.

The original owner and view corrections are partly effective, but the following
two concrete continuations remain before acceptance. These are the same
lifetime and freshness requirements identified in the original review.

## MEDIUM — required provider still expires between check and use

`modular_runtime.gd::_owners_refusal` retains WorldBindings only in its local
`provider` variable (lines 87–95). Actual RoomBindings retains that provider
weakly. The complete command now retains Orders, RoomBindings and LevelCatalog,
but those three do not strongly retain WorldBindings. A genuine provider
`binding_refusal` observer can release the host's last provider reference while
the checking frame keeps it alive. When that frame returns, the provider can
expire. `_confirm` then re-borrows the weak provider and dereferences
`provider.space_owner()` without checking it (lines 170–173).

Retain this exact required provider for the complete command, with identity
verification, or safely refuse expiration before the dereference. Extend the
existing late owner-release regression to this actual weak owner. A Levels-only
regression cannot detect this remaining case.

## MEDIUM — the final view callback runs after the final Draft comparison

The new `_request_refusal` ends by calling `_view_refusal`. That helper checks
the Draft identity and exact request snapshot first (lines 113–118), then calls
`confirmation_view_ready` (line 121). WorldTool invokes both `_read_view` and
`_blocked` during that call. A late `_blocked` observer can discard or replace
the drawing and return false, causing the helper to return success with no
callback-free final identity or snapshot check. `_can_draw` has already
evaluated its active/view flags before invoking `_blocked`.

For a concrete regression, arm the modal observer during the real binding
observer. The initial view read remains unchanged; the final modal read then
changes the Draft and returns unblocked. Submission must refuse before any
RoomOrders preflight. Retain a callback-free identity/request check after the
final presentation observers; do not simply move the same callback to another
last-check position.

## Evidence

`independent-evidence-check.json` verifies the copied final author logs: Runtime
14 tests / 200 assertions, WorldTool 9 / 149, and Editor 10 / 104, totaling 33
tests / 453 assertions with zero failures and zero strict/raw diagnostics or
leaks. Analyzer reports zero warnings in four files. Source, project, registry
and assets were unchanged or restored according to the retained invocation.

Focused-v4 is preserved as a registry preflight refusal before Runtime tests,
not as a failed Runtime test. No additional blocker was found in the bounded
receipt or identity-matched teardown paths. The review remains limited to the
confirmation adapter; complete host/session, physical activation, and playable
acceptance remain outside its scope.
