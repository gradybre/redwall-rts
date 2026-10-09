# 1077 — Smooth the visible underground reversal without changing its route

2026-10-03. Implements the narrow presentation correction identified by 1074.
This does not qualify a movement profile or a connector's body clearance.

The actual demo `ResidentBrain.turn_back` and nearest-exit retreat immediately
reverse their committed direction. `stand_in_bore` then supplies the new yaw,
and the old Actor copied it directly. All ten native underground transitions
in 1074 consequently rotated the visible body by pi in one frame. Rewriting the
brain to turn gradually would change its route, progress and queue behavior.

The Actor now retains whether its visible heading has been initialized and
whether a visible underground turn is unfinished. During that turn it follows
the shortest angular arc, bounded by the existing `Brain.SPOT_TURN_RATE` and the
existing `DemoClock.delta_s()`. It writes only its rendered rotation. The actual
position, brain yaw and pitch, committed progress, route and mouth grants are
unchanged. An unfinished turn continues after the actor reaches a mouth so the
surface transition cannot reintroduce the snap. Ordinary surface movement
keeps its existing direct brain-to-Actor behavior.

The first pose and explicit placement initialize from the real supplied pose;
they do not turn from an invented default heading. A paused clock freezes an
unfinished turn. Retargeting starts from the visible orientation. The root's
slope uses the same remaining-turn fraction, the spine counterlean follows
that rendered slope during the turn, and water tail pull uses the rendered
heading. Lying retains its existing pose handling. No new turn rate, movement
speed, gear permission, carrying rule or work delay is introduced.

The two booleans are transient Actor presentation history. They are not
authoritative resident columns or saved route state. This change adds no
per-frame container or object allocation. Existing bounds that pin the old
Actor source remain historical evidence; future current-source physical
certificates must include the changed turn and counterlean poses.

The new sibling `tools/capture_underground_heading.gd` extends the unchanged
1074 evaluator. It records actual rendered yaw, pitch and spine counterlean in
addition to the inherited actual Brain, source, animation, identity and skin
observations. Its wrapper selects exactly the five cast types' reversal and
retreat cases, preserves create-only output bundles, and rejects missing poses,
visible snaps, mismatched pitch/counterlean, altered reported authority,
incomplete recovery and false profile qualification. Its native run uses the
actual imported rigs and attachments machinery. Route geometry and separate
core identity fixtures retain 1074's explicitly synthetic scope; these ten
cases carry no cargo and do not change cargo presentation.

Validation is preserved under
`docs/design/underground-planning/evidence/modular-build/profiles/runtime/heading/`.
The asset-aside clean import and strict focused suites report:

```text
198 test(s), 4591 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 6 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The ten new Actor tests include real twin brains stepped over separate equal
synthetic routes; drawing one twin changes none of their route observations.
The focused regression set also covers existing demo bore, sleep, cast and
asset behavior. The first run exposed a direct stoop caller that had not drawn
its Actor; applying rendered pitch only during an unfinished turn preserves
that caller's existing behavior. That rejected run remains in `history/`.

The native run covers 10 cases, 1,894 poses and 54,816 engine skin-matrix checks,
with zero unexpected diagnostics and leaks. Each case's maximum visible yaw
step is 0.10666561126709 radians at 30 Hz, within the existing turn rate. Each
actual Brain still reports a pi change. Every preexisting motion field, event,
identity and animation timeline equals its original 1074 `native-v2` case.
Thirteen Python tests replay the saved native evidence and reject targeted
corruptions. Actor/test analyzer output is zero warnings in two files; the
capture analyzer reports zero warnings in one file. Exact invocations and source
hashes are retained. Independent source review accepted the frozen Actor, tests,
capture and wrapper; all thirteen replay tests also passed independently.

These are source-bound sampled presentation results, with **zero qualified
profiles**. They do not prove continuous body/held/load clearance, support,
equipment permissions, production HaulCarry rendering, multilevel world
activation, or the complete underground feature's performance and persistence.
