# 0058 — The first-playable UI receives an authored visual shell

Date: 2026-09-11 · Status: Implementation direction; visual acceptance pending

**Renumbered by the executor on 2026-09-11.** Astra authored this as 0053, but
0053 was already taken by the committed movement ground slice record and the
file had not been committed. Only the number changed; the content below is the
planner's. The UI shell implementation's own record is 0057.

## Context

Brendan requested a high-quality UI fitting the game's feel and style after the
executor offered an unstyled implementation or an art-directed shell. UI §2
already specifies tokens, Noto Sans, geometry and inherited interaction profiles;
missing asset files do not mean appearance is unspecified.

## Decision

Build the task-04.4 subset with the existing UI profiles and an intentional
woodland visual treatment. Functional wiring and visible quality are both part
of the work. The authored direction, proposed asset locations, execution sequence
and evidence expectations are in
[the UI visual brief](../planning/ui_visual_direction.md).

Use opaque forest-green surfaces, cream text and restrained gold, with consistent
icons and modest original botanical ornament. This treatment elaborates the
existing art/UI directions; it does not amend token values, font sizes, control
geometry, gameplay scope or authority order. The proposed icon art grid and
ornament are presentation choices to evaluate in the first visual pass.

Recommend launching the actual Mac scene and collecting screenshots alongside
headless checks. No app launch, screenshot review or runtime test was performed
by this planning change. Missing initializer/service work remains an explicit
blocker for affected integrated acceptance; isolated UI specimens must be labeled.

## Consequences

The executor can build a complete shared theme now without waiting for painted
nine-slices or portraits. Native launch setup is documented using supported
local tooling; absence of `.claude/launch.json` is not proof Godot cannot launch.
No paid assets, new gameplay constants or blanket visual/performance claims are
authorized by this decision. Brendan's visual feedback and implementation evidence
remain to be captured in project files.
