# Root-owned reset callers at the exact 81950fe5 base

Read-only audit of the three source snapshots under `predecessor/`. No UI/main
source changed in this component. This packet implements only the host/Session
lifecycle; these caller repairs belong to the root integration lane.

## Main boot

`godot/scripts/main.gd::_ready`, lines 23–30, first calls
`prepare_world_reset()`, then clears `EntityManager` and resets `EconomySystem`,
then calls `SettlementSystem.reset()`. The existing `if not
prepare_world_reset()` branch at lines 23–25 already reports refusal and returns;
no new failed-prepare guard is needed. After **successful** preparation there is
no conditional early return before the two external clears. Repeated host
preparation retains the original Scope and is supported.

The current failed-prepare return has created no Scope, unless an earlier caller
already holds one. Such a caller must finish or abandon its own pre-clear
operation. After either external owner has been cleared, main must **remain
stopped on failure**; an `abandon_world_reset()` call there cannot undo those
external writes and must not be treated as rollback. If root inserts an early
return before either external clear, it should abandon the original live Scope
before returning. The host's phase 3 starts at its own first clear; it does not
claim to observe the two preceding external clears.

## World form / Create

`godot/scripts/systems/ui_manager.gd::create_world`, lines 198–215, borrows the
old Content before invoking `UiWorldSession.create_with_cohort_into`, passing
`SettlementSystem.reset.bind(true)`. That is one synchronous reset call; the
ordinary path needs no separate prepare. A previously held Scope must be
finished or safely abandoned **before a new form preflight replaces the staged
World request**; a pending Scope deliberately closes fresh Content borrowing.

`godot/scripts/ui/ui_world_session.gd::create_with_cohort_into`, lines
372–375, invokes the reset callback, then unconditionally discards the prepared
request on false and reports that the current World was retained. With the new
host lifecycle this requires root integration:

- If reset refused before clearing, preserve the exact request until any
  original-live pending Scope has been successfully abandoned, then discard the
  staged request. Abandonment cannot succeed after the request is discarded or
  replaced because the private Scope pins its exact object and values.
- If reset reached clearing and release then refused, keep the host stopped,
  preserve its original Scope/request for diagnosis, and report the partial
  reset truthfully. Do not invoke abandonment, discard the request beneath the
  Scope, or describe the old settlement as retained.

The current generic boolean callback cannot communicate this latter distinction
on its own. Root should explicitly compose the host's synchronous reset outcome
with this caller (a bounded typed result or owned status/cleanup adapter),
keeping the legacy standalone generator behavior unchanged. A new success
permission, arbitrary adoption API, or gameplay state rollback is not required.

## Later failures after a successful new World

`UIManager::_materialize_after_create` line 240 and
`_restore_underground_after_create` line 253 call `SettlementSystem.reset()`
after failure in the newly created World. These are not original-live
abandonment sites: the prior World was already discarded. Root should check the
cleanup result before reporting an empty settlement and keep a refused clear
stopped. Existing fresh Content remount behavior is retained on success.

## Component checks that support the handoff

The actual host tests exercise repeated prepare with one Scope, an actual staged
World request, refusal of a distinct equal-value request, successful original
abandon **before** request discard, and refusal of abandonment after clearing
starts. They also prove a deliberately partial clear stays stopped. Those
checks do not assert that the above UI/main repairs have been implemented.
