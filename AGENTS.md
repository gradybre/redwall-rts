# Redwall RTS — rules for any agent working here

Read this first, whatever model you are. It is deliberately short and points at
detail rather than repeating it. **Where this file and any other disagree, this
file's authority order settles it.**

A Redwall-inspired three-layer strategy game in Godot 4.x / GDScript: a
settlement colony sim, Total War-scale tactical battles, and a campaign map.
**Only the settlement layer is being built.**

## Authority order

The active ruleset is **`settlement_rules_v2`**.

1. `docs/setting_decisions.md` — Brendan's policy decisions (`DEC-nnn`).
2. `docs/game_gdd.md` (rev 1.1) — Settlement GDD. **Authoritative**, as amended by
   `docs/setting_rules_amendment.md` (`SET-AMEND-001`), which supersedes the
   earlier admission and food rules. [SET-MOVE-001](docs/movement_direction_amendment.md) additionally owns DEC-035 connected movement; its direction is adopted and MOVE-G01–05 remain engineering closure gates. Hunting is **not** active in rules v2.
3. `docs/ui_ux_controls.md` (rev 1.1) — UI, UX, controls.
4. `docs/gameplay_balance.md` and `docs/systems_architecture.md` — derived from
   the above.
5. `docs/crowd_rendering_architecture.md` — battle-layer crowd rendering; also
   the source for asset conventions (§9) and determinism rules.
6. `docs/setting_bible.md` — setting and lore.
7. `docs/validation_resolution.md` + `docs/validation/` — evidence and tooling
   for what has actually been verified versus asserted.
8. `docs/decisions/` — engineering decisions with reasoning.
9. `AGENTS.md` (this file) and `CLAUDE.md` — working rules.

*Items 1, 6 and 7 were authored outside this assistant's sessions; their
placement in this order is a reading of their stated scope, not a confirmed
ruling. Check the documents themselves if precedence matters to your task.*

If a lower item contradicts a higher one, the higher wins **and the lower one
gets fixed**. Do not silently work around a contradiction; record it.

## Non-negotiables

From the GDD. These break the build if ignored, and they are not obvious from
reading the existing code — which predates the GDD and violates several.

- **Integer arithmetic for all authoritative state.** `float` is presentation
  and import only; it never decides a gameplay outcome.
- **30 fixed ticks/second** at 1x; 18000 ticks/day; 750 ticks/game hour.
- Speeds are `PAUSED=0, NORMAL=1, DOUBLE=2, QUADRUPLE=4`. **There is no 3x.**
- **Structure-of-arrays** storage — packed integer columns, not one object per
  entity.
- `EntityRef = (slot:int32, generation:int32)`, null `(-1,0)`; slots are reused
  with generation validation.
- **Living population caps at 256.** Never model or tabulate beyond it.
- Quantities are `quantity_milli:int64` (1000 = one unit). Needs and mood are
  integers 0–10000. Positions are int32 in 1/1024 m units, **−Z forward**.
- Model scale is anchored on a **1.0 m mouse** — deliberately not biological.

## Before you build

- `godot/` **is a prototype and knowingly violates the GDD.** Read
  `docs/decisions/0006-prototype-diverges-from-gdd.md` before extending it, or
  you will build on sand.
- `docs/systems_architecture.md` now exists and settles the storage layout.
  Read it before rewriting the ECS — decision 0006's divergence list was
  compiled against **GDD rev 1.0** and needs re-checking against rev 1.1.
- `docs/validation_resolution.md` records what has been genuinely verified and
  what is still `BLOCKED_RUNTIME`. Do not treat an asserted budget as a
  measured one; that document is explicit about the difference.

- Before movement/space work, read `docs/movement_direction_amendment.md`; ground-only and one-floor baseline contracts do not satisfy the adopted scope.
- Before theme, culture, food, location or cast work, read `docs/redwall-content-library/README.md` and `authoring_handoff.md` there. The shared catalog and recipe library use book-qualified IDs; the pantry resolves explicitly authored game components. Earlier `docs/redwall-design/` and `docs/redwall-series/` retain their narrower historical coverage. Source facts, AI recipe completions and active numerical catalogs remain separate; full Eulalia text and the known Salamandastron source gap remain unresolved.

## Working rules

**Record decisions as you make them.** Anything a later reader could undo by
accident goes in `docs/decisions/` — see its README. A decision is not made
until it is written there; this is part of the work, not follow-up.

**Everything lives in the repository.** Assistant-private memory may hold a
pointer, never the only copy. Externally generated documents are written into
`docs/`, not a scratch directory (decision 0007).

**Never commit secrets.** `docs/ENVIRONMENT.md` records where credentials live,
never their values.

**Verify, do not assume.** `godot` run from the repository root silently opens
the project manager and exits 0 — success and total no-op look identical. Working
commands are in `docs/ENVIRONMENT.md`.

**Meshy credits cost real money.** Present the cost and get explicit
confirmation before spending.

## Layout

```
docs/                 Specifications and decisions — the source of truth
  decisions/          Numbered decision records
  ENVIRONMENT.md      Toolchain, working commands, secret locations
  tasks/              Sequential implementation checklists
godot/                Godot 4 project (prototype; see decision 0006)
  scripts/            systems, components, entities, ui, utils
  test/               Test suites and the headless runner
assets/source/        Raw generated assets, unprocessed
chatgpt-prompts/      Prompts for external model runs
.claude/skills/       Packaged workflows (Claude Code)
```

`CLAUDE.md` holds the Claude Code development pipeline and the GDScript style
rules. Those style rules apply to anyone writing GDScript here.

## Supplied-reference authorization

Brendan authorizes direct use of supplied images/material, including IMG-25,
for image-to-image and reference-guided builds (DEC-036 in `docs/setting_decisions.md`).
Do not reduce supplied references to observe-and-describe-only because creator
metadata is unknown. Record provenance; source mechanics and paid generation
authorization remain separate. UI art follows `docs/design/ui_refinement/asset_generation_lock.md`.

For all visual work, also read `docs/art-reference/visual_direction_alignment.md`
(DEC-037): combine literary context, complementary supplied images and modern RTS
visual principles. UI illustration locks do not define the whole 3D world style.

Brendan approved the grounded, expressive world-art example under DEC-038.
Open `docs/art-reference/visuals/grounded_expressive_rts_example_v1.png` with
relevant supplied references when authoring visual assets; the broad world look
is settled, while production geometry and performance still require verification.
