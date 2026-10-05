# Independent review — 1160 UI reset candidate1

Accepted for the author's scoped commit. No high or medium correctness finding.
This review changes no UI, host, retirement, or shared accounting source.

The candidate is in `redwall-rts-codex-ug-world-create-reset` at base
`721038a4198df17d9bfab6c9994cc9916f875447`. Its seven source/executable pins
match before and after review; all thirty output hashes match. The retained
`source.diff` equals the actual diff of the four leased GDScript/test files.
`reviewed-source-sha256.json` records the exact reviewed bytes.

The review covers:

- `ui_world_session.gd:153` and `:385`: the typed packet defaults to STOPPED;
  unknown states, absent output, contradictory causes and a legacy boolean
  return cannot grant clearing. The old Report result is cleared before every
  observation.
- `ui_world_session.gd:341`: the actual original World/store tuple is checked;
  only CLEARED continues through seed/cohort/publication. RETAINED alone drops
  the replacement request. STOPPED does not discard the request captured by a
  partially completed retirement Scope.
- `ui_manager.gd:198` and `:219`: form validation precedes abandonment; actual
  original-live abandonment precedes Content borrowing and replacement
  preflight. The guard covers the entire synchronous Create path, including
  materialization, remount, economy reconciliation, reporting and roster work.
  A nested Create leaves the outer Report intact.
- `ui_manager.gd:248` and `:282`: the reset cause is copied before abandonment
  can overwrite the host's refusal. Late cleanup uses the same actual host
  boundary and retains its error separately from the original stage error.
  Only confirmed cleanup clearing withdraws the UI map. CLEARED text describes
  the observed earlier clearing without claiming that later partial creation
  left an empty World.

The actual test paths include successful creation/remount, a busy retained
World, a prior prepared Scope, invalid form before abandonment, altered source
that prevents abandonment, a real placement callback attempting nested Create,
late cleanup refusal/retry, actual remount refusal and a deliberately partial
actual clear. The adverse host subclass interrupts clearing but does not fake
an owner proof or successful publication.

Independently ran all twelve Python census mutants and reproduced the complete
census payload, with no engine rerun. The sole ResetOutcome is live across
three mutually exclusive constructor sites; caller prefixes include the
accepted static retirement chain. Counts remain 5,995/6,144 control bytes and
1,882/2,048 helper bytes (186 numeric/name bytes, 45 provisional reference
values), with no new packed bank or reservation. Session1,536 and retirement
8,192 are each charged once.

Reviewed author evidence: 77 tests, 548 assertions, zero failures, one existing
expected null-HUD diagnostic, zero unexpected/tolerated diagnostics or leaks,
analyzer0/4, and all recorded source/project/registry/prerequisite/assets/HEAD
restoration checks true. `invocation.json` and `python-*.log` are the independent
Python commands/results. `review.json` records the verdict and limitations.

This is component source/census acceptance. Existing UI catalog/economy/native
presentation allocations remain in their prior scopes; native object and
reference sizes remain provisional. It is not full-demo, operational-room,
whole-client performance, or native allocation qualification.
