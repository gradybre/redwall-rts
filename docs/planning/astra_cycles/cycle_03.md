# Astra Cycle 3 — readable UI, movement policy and save framing

2026-09-14 · Planning cycle and five-merge alignment review complete.
**Four advisory questions answered; movement Q2 materially advanced but still open.**
No new runtime implementation, art approval or complete save/movement acceptance is claimed.

## Claude: start here

Use integrated master **2021444c520a8bf2f0c3aecd84a034149a1fb414**, or its verified descendant. The local root checkout is still the older `3e094e9` with substantial staged/untracked work; do not reset or overwrite it. Read these three rulings, then the updated `docs/planning/work_queue.json`:

1. [UI-C3-R01](../../rulings/2026-09-14_cycle03_ui_geometry.md): readable two-line resource cells, real exact-value disclosure, two reachable full alerts, and correct ordinary/compact/true-modal geometry.
2. [MOVE-C3-R01](../../rulings/2026-09-14_cycle03_movement_policy.md): authored ford semantics; child hazardous-entry versus recovery; ordinary access/elder policy; inherited HAZ bindings; explicit residual interpolation-error coverage and envelope input schema2.
3. [SAVE-C3-R01 / REG-C3-R01](../../rulings/2026-09-14_cycle03_save_counts_and_capacities.md): section8 primary count8192; retain section9 block512/8192 and descriptor8192; permit a source-proved numeric capacity audit, preserving equality versus maximum.

Run independent implementation, testing and review within each task's owned files. PR122 and PR123 are **open** at the snapshot and retain their files. Complete the error-coverage correction before treating the new envelope tool's FIT_OK as even a complete measurement-bound check. The UI correction is ready; repeat screenshots/input evidence afterward. Continue SAVE-S1-OWNERS and inventory normalization in their dependency order. No task may spend credits or clear an art gate.

The current packet file in this local checkout remains a historical output. This cycle's [PR snapshot](cycle_03_prs.json), [evidence record](cycle_03_evidence.json), report and LATEST.json are the current review handoff. Do not copy the old local packet generator over PR117's merged implementation. The executor should regenerate the packet using the merged generator after transferring this package and its queue/inbox updates.

## What changed since Cycle 2

Five new merges trigger the full alignment pass:

| PR | Disposition |
|---|---|
| 117 — packet evidence | Accepted: final PR declarations now distinguish clear, qualified, declared and missing; absent declarations are not approval. Independent67-case test pass here. |
| 118 — visual evidence | Accepted as evidence, not art. The additional workspace-closed control and labeled synthetic counter ladder are useful. The printed negative-count sentinel was replaced by an explicit diagnostic, and the capture/diff harnesses are now retained. The author-email rewrite is administrative, not gameplay scope. Its qualified “no mutations” statement is not a surviving mutation claim. No revert is required; UI failures remain and are addressed below. |
| 119 — Construction registry | Accepted: the17 missing fields are registered. Independently verified553 persisted packed fields,599 canonical records,52 owners and generated declaration equality. This closes the integrated source-membership defect, not adapters or save continuation. |
| 120 — Cycle2 transfer | Accepted: transfers planning and records actual merged/in-flight state without claiming new gameplay. Its updates allowing historical Cycle2 status checks to advance are correct; PR review state is not a format constant. |
| 121 — envelope tooling | Anchored-fit arithmetic and synthetic/measurement separation align with Cycle2;124 checks pass. **One bounded measurement-validation defect requires correction:** interpolation error is recorded but not enforced against margins. Keep the implementation and fix it through MOVE-ENVELOPE-ERROR; it does not qualify real envelopes yet. |

PR118 is the only new merge with nonempty deviations/qualified mutation wording; its exact text is retained. The other four report all three declarations as `none`. These are final-body snapshots read now, not a claim that later edits or prior unrecorded declarations cannot exist. The local first-parent history independently lists these exact five merges after PR116, so the bounded PR query covers this cycle's merge set.

PR122's authoritative spawn/render change and PR123's movement proposal register remain under review. PR122 reports4355 tests/155623 assertions; those are executor figures, not independently rerun here. Its single bind-pose mouse mesh still does not meet species/material/animation visual acceptance. PR123 is useful evidence:288 rows and35 unresolved slots, not completed authored profiles. Cycle3 corrects several of its source interpretations; retain its original snapshot as [review input](cycle_03_inputs/README.md), then apply policy changes in a successor task after its ownership releases.

## UI verdict and exact new values

I inspected PR118's Standard settlement,150% Narrow settlement and roster-open images directly, alongside the illustrated woodland concept. The defect is visible: the food quantity and Residents caption clip, NARROW shows Fuel in Population's slot, and the roster covers alerts. The flat repetitive roster and raw `Paused: PLAYER` readout also fall below the already specified crafted journal/woodland finish. This is a planner assessment; Brendan's ART-UI-12 decision remains pending.

The strongest source correction is that SET-UX-VIS-002 §4.2 **already distinguishes ordinary workspaces from centered modals**. `ui_shell.gd` still places ID_WORKSPACE using `_geometry.modal`. The executor's claim that only base §1.2 governs the overlap missed that adopted amendment. Repair its implementation; don't solve it by putting all HUD controls above all dialogs.

New design values: resource cells56px/frame128px with caption14/value18,16px caption-row icons, inset resource focus rings; retained resource widths360/480/176; Standard/Wide alert height104/minimum card48; NARROW44px summary keeps its48px zone with8px vertical padding; management top band152px at supported profiles. Exact values too long for a resource card get an explicit **See ledger** action with full-value accessibility, never K/M abbreviation or clipped digits. The ruling narrowly records this disclosure exception; critical warnings and transaction costs still wrap fully. At minimum logical853⅓×480, compact management is640×312 below the band, with188px of scrollable body between header/footer.

These values were checked against vendored Godot font metrics: caption14=20px, numeric18=26px, notice16=23px. They do not establish the revised shell's actual runtime rendering before Claude implements it.

## Movement progress and the new defect

The natural ford already has authored walkability; its mode must be enforced per segment, not merely stored as an unused route-wide label. It remains ordinary supported travel, not generic shallow-water permission. Neither the128u water depth nor640u land/floor difference is a new per-species depth/step capability.

DEC-032 already forbids child hazardous expeditions. The new engineering binding prohibits deliberate child surface-swim, dive and unprotected-climb entry while preserving recovery/rescue of a child already in danger. Protected nonproductive access remains possible with actual child/support profiles; no escort grants a forbidden mode. Elders gain no blanket age veto. Completed ordinary access is not exclusive to a digging specialist. The full ruling distinguishes inherited policy, the newly explicit action interpretation, and the bounded choice to use declared profile/access eligibility rather than an unowned movement-XP acquisition system.

**Reproduced PR121 defect:** a synthetic box with1u residual interpolation error and zero margins passes schema/semantic checks and returns FIT_OK/class1. Accounting for that1u margin makes its translated minimum−1 and maximum513 and correctly refuses placement. This shows missing error coverage, not a measured production collision. [The retained probe and raw result](cycle_03_movement_probe.log) reproduce the current defect. Schema2 must define residual error and require covering margins on every axis, with conservative outward rounding at the earlier micrometre export boundary too. No actual body dimension, margin, speed or cost is invented.

MOVE-G01/Q2 stays open for complete mode/species costs, adult/elder water and unprotected-climb permissions, real source-bound envelopes, support/contacts and the associated G02 contracts. Tool tests, a policy matrix and rig identities cannot close those gates.

## Full alignment pass: narrower, dropped and absent work

1. **Narrower than required, with passing tests:** REQ-SET-009 requires the complete starter settlement. The current initializer tests explicitly expect zero buildings/beds and the active settlement inventory has no starter lots. Cohort+terrain tests therefore do not establish hall, furniture, legal stockpiles, tools or a working colony. This limitation is recorded in task04.3 and source; it is not a newly discovered stealth deletion. PLAN-RELEASE-COVERAGE now explicitly requires one active inventory/economy authority and the complete starter12 equipped +12 stored tool sets without duplication.
2. **Narrower UI:** base-rectangle workspace placement passes its geometry assumptions but omits the adopted workspace variants, and fixed counter cells fail the real text. UI-C3-R01 supplies the missing implementation/evidence tasks.
3. **No unrecorded scope removal found** in the inspected tasks04–10/source. Known incomplete slices have records. That is a bounded finding, not a proof that the whole release is fully represented.
4. **Missing named follow-through:** add planning/implementation sequencing for later-arrival placement at the authored exit(64,126), stock-integrity retry/hold save continuation, and annual relief seeds through command→next dawn→real inventory/history. Their queue entries must materialize concrete runtime prerequisites before completion. The stock-fault contract must reconcile completed-tick saving with partial-fault states; it cannot serialize an unsafe world or grant another retry after load. Fixed release life stages remain; this adds no births/aging.
5. **Art against vision:** corrected geometry will not itself produce the approved rounded, expressive 3D community or the illustrated journal. Keep species/anatomy/material/animation/world presentation as explicit release work, and retain actual screenshot review. No generated world content or polished concept is represented as implemented evidence.

## Validation and source limits

Astra independently executed:

- **26 Godot font/layout-bound checks,0 failures.** Source at `docs/validation/cycle03_ui_font_probe.gd`; [log](cycle_03_font_probe.log). These test actual vendored fonts against proposed cell/card budgets, not a rewritten UI scene. Engine emits its known14ObjectDB/3resource shutdown warnings and a macOS certificate lookup error; no font-load failure occurred.
- **75 Cycle3 arithmetic/format/grammar/handoff checks, pass.** [Validator](../../validation/validate_cycle03_handoff.py). Checks include profile boundaries, minimum layout, alert packing, numeric-capacity operator distinction and gated task dependencies.
- **124 existing movement-tool checks, pass;67 merged packet checks, pass.** The separately retained error-coverage probe still demonstrates the defect those124 checks miss.
- **Merged-source registry validation and generated table check, pass:**553 persisted fields,599 canonical records,52 owners;54 modules/352 source rows/681 packed columns. The31 independent save/name fixtures also pass. Capacity census is519 prose records=473 equality+46 upper bounds, with80 other canonical shapes. These are source snapshot counts, not future immutable totals.

Final [package checks](cycle_03_checks.log) also pass:37-task graph, inbox rendering,37 historical Cycle2 fixtures, document links and unchanged runtime/index/art fingerprints.

No full Godot suite, Windows run, release benchmark, loader continuation or movement-runtime qualification was run in this planning cycle. The old local root still has the pre-PR119 registry/source snapshot and duplicate historical ADR copies; a root-only failure there must not be reported as a current-master failure. All runtime/index/art-ledger fingerprints were preserved. No commit, push, merge or paid generation was performed.

## Exact next executor sequence

From the verified integration base, use the updated37-task graph rather than an informal parallel file list. Independent ready work includes **UI-RESPONSIVE-C3**, **MOVE-ENVELOPE-ERROR**, **SAVE-S8-COUNT**, **REGISTRY-CAPACITY-AUDIT**, and existing save/release planning subject to ownership. PR122/123 retain their files; policy-register corrections wait for PR123's merge. Follow existing save-owner dependencies before inventory normalization. Record one dated lane report per task with source/ref, actual checks, failures and remaining contracts. Cycle4 should finish the two remaining advisory economics questions and continue adult/elder mode-profile authoring from the now-separated policy/evidence gaps.
