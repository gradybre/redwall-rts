# Requirement-to-task allocation notes

This allocation follows `AGENTS.md`: `settlement_rules_v2`, GDD revision 1.1 as amended by `SET-AMEND-001`, connected movement from `SET-MOVE-001`, then UI/UX revision 1.1. It is allocation rather than completion evidence, so every row is `NOT_ASSESSED`. Earlier Task 01/02 code is only a dependency; string presence never changes the future integration owner.

The primary declaration inventory is 329 distinct IDs: 181 REQ-SET, 103 UI-SET, 15 REQ-UX, 20 MOVE-REQ, and 10 MOVE-TEST. The CSV additionally includes eight REQ-ADM amendment declarations under family SET-AMEND and ten explicit Section 3 retirement/reservation dispositions, for 347 total rows. Headers, prose mentions, identifier ranges, UI-MOVE prose, and MOVE-G engineering gates are excluded.

Sources:

- `docs/game_gdd.md`
- `docs/ui_ux_controls.md`
- `docs/movement_direction_amendment.md`
- `docs/setting_rules_amendment.md`
- `AGENTS.md`
- `docs/tasks/03_ecology_crops_weather.md` (status context only)

No primary-family declaration ID is duplicated or malformed. REQ-ADM-001..008 intentionally overlap their revision-1.1 integrations: REQ-SET-057/058/062, REQ-SET-151..153, REQ-SET-025/061, REQ-SET-065/160, and UI-SET-068/069. Amendment authority wins if wording diverges. The ten synthetic SET-AMEND-001-RET IDs preserve exact retirement rows without creating product IDs: hunting items/recipes/building/fauna are removed; reserved skill, zone, fauna store, RNG, and telemetry slots remain canonical tombstones and may not resurrect hunting.

UI ownership is distributed across Tasks 04–08 by feature. Task 10 owns cross-cutting presentation, accessibility, menus/tutorials, performance evidence, and release qualification. The integration lead owns task 04 and the roadmap/supporting-contract mapping. Task 03 supplies ecology data; calendar/zone interaction is task 04 and detailed fish/crop/relief UI is task 07, so this package does not add an unannounced UI task to the active ecology executor.

Family counts: {'REQ-SET': 181, 'UI-SET': 103, 'REQ-UX': 15, 'MOVE-REQ': 20, 'MOVE-TEST': 10, 'SET-AMEND': 18}
Primary-owner counts: {'task03': 55, 'task04': 66, 'task05': 30, 'task06': 44, 'task07': 46, 'task08': 56, 'task09': 14, 'task10': 36}


This inventory covers declared gameplay/UI/movement rows plus the explicitly
listed amendment dispositions. Narrative requirements, table values, ARCH/BAL
contracts, MOVE-G gates and DEC policy scope still require the owning documents
and the roadmap's supporting-contract matrix. The allocation is not an exhaustive
implementation audit of every normative sentence.

`SET-AMEND-001-RET-01`–`10` are planning-only row keys generated in source order,
not new ruleset IDs. `source_line` identifies the actual retirement table row.
The CSV preserves source wording even when another adopted movement rule limits
its application (for example floor sleep); consult both owners before coding.
