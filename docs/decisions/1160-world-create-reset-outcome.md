# 1160 — Preserve the actual outcome of New settlement reset

Date: 2026-10-04 · Status: independently accepted component; integration pending

ADR1158 makes a started whole-World clear irreversible. New settlement must
not translate every false reset return into “the old World was retained”,
discard a request still captured by a retirement Scope, or report an empty
settlement after cleanup itself refused.

## Typed boundary and order

`UiWorldSession.ResetOutcome` is a caller-owned synchronous packet with three
integer states: CLEARED, RETAINED and STOPPED. Its default is STOPPED with an
unwritten-outcome refusal. The reset callback receives this packet; an ordinary
return value, including `true`, is never success. Only a well-formed CLEARED
result permits stream seeding, cohort creation and publication. RETAINED alone
discards the prepared replacement. STOPPED preserves the exact request and
Scope for the host's original stopped state; the UI cannot repair private host
state or claim rollback.

The actual UI adapter validates the form before any abandonment, then calls
`SettlementSystem.abandon_world_reset()` before borrowing Content or staging a
new request. This is harmless when idle, proves the original live tuple when a
Scope is prepared, and refuses after clearing has started. A create-in-progress
guard spans generation, colony materialization, foundation remount, economy
reconciliation and reporting. Reentry never replaces the outer report.

The reset adapter captures the original host error before its abandonment
attempt. Successful reset yields CLEARED; false reset plus successful original-
live abandonment yields RETAINED; any failed abandonment yields STOPPED. Later
colony/remount cleanup uses the same typed boundary. Only confirmed clearing
withdraws the published UI map. Reports retain the stage error separately from
the reset error and describe what was observed, never an assumed empty World.

Standalone `create_into` keeps its existing generation and store semantics.
No Session, host, main, source/catalog, authority, registry or shared memory
implementation changes belong to this packet. Its callbacks describe actual
host outcomes; they confer no gameplay admission or source qualification.

## Scope, storage and evidence

The furnishing lane owns UIManager, UiWorldSession, their existing tests, this
ADR and `docs/validation/evidence/underground-world-create-reset-2026-10-04/`.
All other owners remain read-only. The new retained state is a UI create guard
and bounded report fields. One cold ResetOutcome exists per synchronous reset;
there is no per-entity state or packed arena. The final source census must count
constructor and callback/helper coexistence, with native reference/header terms
explicitly provisional and no increase to existing simulation ceilings.

Required tests cover real host/Create success and repeated remount, busy
original-live refusal, abandonment before request replacement, a partial clear
that stays stopped with its exact Scope/request, unwritten/malformed callback
outcomes, UI reentry, and colony/remount cleanup refusal. Existing standalone
form/generation and cohort identity/pose tests remain active. Strict diagnostics,
zero-warning changed-file analysis, exact source/restoration evidence and
independent review are required before commit. Full demo activation and native
allocation qualification remain separate.

## Frozen component evidence

Candidate1 passes UiWorldSession21/119 and UIManager56/429: 77 tests, 548
assertions and zero failures. One preexisting expected null-HUD diagnostic is
retained; unexpected/raw diagnostics, tolerated diagnostics and leaks are zero.
Changed-file analyzer is 0/4. The exact four independently accepted publication-
v3 prerequisites were temporarily composed and fully restored; no source guard
or current consumer was replaced. This is selected component evidence, not a
full no-argument run or an operational Room/demo activation result.

The source census and twelve mutation checks count 18 new retained numeric/name
bytes, a 16-byte ResetOutcome, 32 bytes of new integer/name constants, and one
provisional 256-byte packet header. One packet is live at a time across the
three exclusive constructor sites. Together with accepted1158 this gives
5,995/6,144 controls and 1,882/2,048 helper bytes, including complete accepted
static retirement frames and conservative maxima of 186 scalar/name bytes and
45 reference values. No reserve grows; original Session1,536 and retirement
8,192 are each charged once. Original UI catalog/generation/HUD allocations
keep their previous lifetimes; native headers, reference width and formatted
text remain unmeasured presentation costs. Independent source review accepted
the exact seven executable and 30 output pins; Geometry independently replayed
all twelve census tests and found no high or medium issue. Its durable evidence
is commit `b9f90b39be8986349ee512890fe834c69c906984`, copied with provenance in
the owned evidence packet. This does not expand the component scope.
