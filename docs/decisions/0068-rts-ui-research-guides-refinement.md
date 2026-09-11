# 0068 — RTS UI research informs refinement without importing game rules
Date: 2026-09-11 · Status: Accepted research basis; future proposals remain unapproved

## Decision

Keep SET-UX-VIS-002 and task04.5 as the implementation owners. Use the
[six-game comparison](../design/ui_refinement/rts_ui_research.md) and eleven mapped
review procedures to evaluate existing requirements. Foreign games are precedents,
not authorities over Redwall input, economy, content, save or pause rules.

## Why

Brendan requested scraping and review of RTS interfaces and best practices after
the initial design package. Public developer accounts and six inspected images
support stronger decision paths, explicit state and contextual explanations.
The comparison also exposes a text-accessibility qualification gap and a misleading
selected check on the synthetic Create button. The latter must not become runtime
toggle semantics; retain the historical image with its explicit correction note.

## Consequences

No runtime code, color token, scale formula, game binding or save format changes.
The eleven checks map to existing acceptance; all runtime outcomes remain NOT_RUN
by the researcher. RUI-P01–04 are proposed/future work and do not defer existing
forecast, save-browser or tutorial requirements. Additional text scaling needs an
owner amendment and native measurements before adoption. User visual approval is
still separate. Third-party screenshots remain linked evidence, not reusable assets.

## Source

Brendan's RTS research request; UI §1–8; SET-UX-VIS-002; linked source register and
comparison. Bounded independent spec review checked counter routing, notification
grouping, tooltips, shortcuts, existing manual commands and scaling authority.
