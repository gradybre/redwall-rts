# Task04.5 — Finish the first-playable visual language

2026-09-11 · **READY for dependency-independent work; not implemented by the planner.**
Owner: integration lead. [Start package](../design/ui_refinement/README.md).
[Owning amendment](../ui_visual_refinement_amendment.md):UXV-001–042.
Existing UI IDs are retained; this is refinement of task04.4, not all103 elements.

## Research-informed review

Read the [RTS interface comparison](../design/ui_refinement/rts_ui_research.md) and
map its RUI-C01–11 checks to the existing acceptance cases. They do not add game
mechanics or replace the42 requirements. RUI-P01–04 remain proposed/future work;
existing forecast, save-browser and tutorial scope is preserved. Record the text
accessibility gap before claiming qualification; independent implementation proceeds.

## Asset preparation lock

Use [ART-LOCK-001](../design/ui_refinement/asset_generation_lock.md) before prompts
or illustration work. DEC-036 permits supplied images as direct generation/build
references. The16 identities, palette, light, silhouette and framing choices are
settled. Prepare references and prompts now; itemized paid generation and final
visual acceptance remain separate.

## Dependencies and file ownership

The first UI implementation is in `feat/ui-shell` at95ee560 in the inspected
worktree. The integration lead must identify its latest reviewed state and
coordinate integration. Do not edit another active agent's worktree or recreate
its fonts/theme/bridges from scratch because they are absent from the main branch.
Existing uncommitted planning documents and unrelated runtime work remain owned
by their authors. This task does not authorize a push/merge or paid asset spending.

| Role/model configuration | Bounded responsibility | Write scope |
| --- | --- | --- |
| Plan-parser / sonnet | Map42 IDs to source defects, dependencies and code owners; no entire-corpus reload | Read only; return mapping to lead |
| Game-coder / inherit | Implement theme/components and prescribed visual states | `godot/ui/`, `scripts/ui/ui_theme.gd`, component scenes/scripts explicitly assigned by lead |
| Game-coder / inherit, separate worker if useful | Fix registry gating, workspace ownership and data formatting | `scripts/ui/ui_availability.gd`, `ui_registry.gd`, designated presenter/formatter module; no shared `ui_shell.gd` writes |
| Integration lead | Sole writer for shared shell, UI manager and project configuration; merge component work and input/scaling | `scripts/ui/ui_shell.gd`, `scripts/systems/ui_manager.gd`, `project.godot`, shared root scenes |
| Test-runner / haiku | Run supplied tests/launches, collect raw logs and captures; escalate diagnosis | Evidence files only, or a separately assigned test file; no aesthetic ruling from exit status |
| User-qa / sonnet | Inspect actual images/input flow against23 cases; Player Impact Report | Review/evidence report; no runtime writes |
| Code-reviewer / sonnet | Review contract adherence, ownership, performance and tests | Read only; actionable corrections |
| Git-manager / haiku | Reviewed owned files and task/evidence bookkeeping under existing session git authorization | Explicitly reviewed paths only; no force/reset or unrelated changes |

Choose models from existing `.claude/agents/` configuration. Keep architecture
judgment and difficult integration with the lead; use inexpensive execution for
repeatable checks. Don't send each worker every research JSON or ask a cheap
runner to resolve a policy contradiction. Review a worker's result before marking
its requirement complete. Each worker receives exact files, IDs and success tests.

## Dependency-ordered work

### 04.5a — Correct the foundation before visual replication

- [ ] Apply the existing gate predicates before availability; implement the four
  availability states (UXV001–005/030). Preserve ALWAYS discoverability.
- [ ] Correct Residents→069 versus F6→087 and workspace child ownership. Implement
  WORKSPACE/MODAL variants and correct input/focus/disclosure behavior.
- [ ] Apply the exact physical/logical scale once and wire real focus neighbors,
  close/return and disabled explanations. Map Mac trackpad gestures via owning
  input rules. Keep these defects in04.4 history; don't retire tests without reasons.

Dependencies: current UI bridge/router and integration ownership. No complete
movement/initializer required for isolated layout/focus tests. Acceptance:A01–03,
A05,A07–08. Completion establishes correct UI structure, not visual quality.

### 04.5b — Build and inspect one complete visual slice

Read [the art-finish requirements](../design/ui_refinement/visual_art_direction.md).
Deliver ART-UI-01–12 alongside the existing cases. The first flat targets are
structural references; the new illustrated concept raises the art bar but has
explicit non-normative geometry/data deviations. Author the asset family before
propagating panels; do not mark art complete based on a theme file or flat fallback.


- [ ] Implement FOREST/JOURNAL/TOOL_COMMAND variants, licensed font and scoped
  icons/emblems/ornament. Check eight states, exact color roles and dimensions.
- [ ] Build HUD/resource/time and resident journal anatomy, correct need/rate/XP
  formatting and contextual actions from real snapshots. No raw stores/class names.
- [ ] Capture native wide and narrow states plus labeled component specimens as
  needed. Compare to reference structure; fix all P0/P1 findings before propagating.
- [ ] Submit the first image set to Brendan and record PENDING/APPROVED/CHANGES_REQUESTED
  with actual feedback. User sign-off is not inferred from an agent's opinion.

Dependencies:04.5a for live scene; pure theme/assets can proceed in parallel.
Actual resident binding needs a real resident composition; if blocked, demonstrate
component design in a specimen and leave live acceptance open. Acceptance:A04,
A06,A09–12,A18,A22. Completion establishes a reviewed component direction; not FP-01.

### 04.5c — Extend the established components

- [ ] Finish roster rows/scroll, full New Settlement form, validation/progress/error
  states, zone previews/cancellation/refusals and actual overflow access.
- [ ] Apply long-label and narrow rules without new one-off themes. Finish remaining
  asset optical checks and per-case functional coverage.
- [ ] Migrate existing UI assertions around fixed canvas/full-height empty boxes,
  raw basis points and blanket disabled visibility; keep their retained semantics
  and replacement IDs in an updated UI test-migration ledger.

Dependencies:reviewed04.5b component direction; full New Settlement success depends
on04.3 legal fixture/services; no substitution. Acceptance:A03,A08,A13–16. Completion
establishes this supported flow subset, not all UI definitions or colony survival.

### 04.5d — Qualify the bounded slice and hand off

- [ ] Execute all23 acceptance cases or name exact blockers. Preserve raw runner
  summary and failed checks. Confirm no increasing node/font/theme allocations.
- [ ] Produce native screenshots and transformed layout/hit metrics at required
  scales; check actual high-DPI dimensions, reduced motion and Mac accessibility.
- [ ] Independent technical and player QA issue reports. Correct P0/P1 findings,
  record remaining P2 and Brendan's visual verdict, and map all42 IDs to evidence.
- [ ] Report exact next task: resume the dependency-ready task05/06 gameplay work
  alongside pending UI integration/accessibility blockers; task10 later completes
  all-release presentation consistency and qualification.

Use `./tools/run_tests.sh` from repo root, the new package validator, and the real
native launch `godot --path godot` after confirming the actual main scene. No
`.claude/launch.json` schema is invented here. No production save/Windows/minimum-
hardware claim follows from a UI specimen or Mac measurement.

## Definition of done

All implemented requirements have linked evidence; functional/structural visual
checks pass with no P0/P1; genuine integration/accessibility blockers stay open.
Report user visual approval separately. Do not mark all of04.4/04.5 complete if
required live bindings or feedback remain unresolved. A theme resource alone,
synthetic screenshot, isolated snapshot test or pretty menu is insufficient.
