# 1200 — Runtime loads the content-5 mole profile publication with the tool-free haul rows

Date: 2026-10-06 · Status: Accepted

ADR 1198 step 4b. Follows the ADR 1194 model (content 3 → 4).

## Decision

The runtime mole profile publication moves from `qualified-handling-v5` (content 4, 30 rows,
281 boxes, two sources) to `qualified-haul-v6` (content 5, 37 rows, 334 boxes, three sources).
`publish_haul_runtime.py` creates it once. It refuses unless rows 0–29, boxes 0–280 and sources
0–1 are byte-identical to content 4. Source 2 is the native haul image v8 (`cc854271…`). Wire
`dc4969e4…`, 13,114 bytes, paired bank 26,212 bytes (+4,404).

The new rows sit in source 2's own block, already in key order, so no earlier row is renumbered:

| Row | Content | Mode / yaw | Cargo | Boxes from |
|---|---|---|---|---|
| 30 | A STAND | 0, YAW_ALL | none | `empty-walk-v1/empty-walk.json` |
| 31 | A′ WALK | 1, YAW_ALL | none | same |
| 32 | B CARRY | 2, YAW_ALL | wood 1000..1000 | `haul-rows-v1/rows.json` |
| 33 / 34 | C HAUL load | 3, YAW_EXACT 0 / 16384 | none | rows.json; 34 is 33 rotated |
| 35 / 36 | D HAUL unload | 3, YAW_EXACT 0 / 16384 | wood 1000..1000 | rows.json; 36 is 35 rotated |

All seven rows are tool-free (−1/−1), revision 1, certificate 15, and `POLICY_AUTOMATIC` (ADR 1198:
automatic first). C and D use `JOB_KIND_HAUL` (0) and `CONTACT_HAUL_GRIP`, with roles 0–4 and no
point or patch box. Wood is the compiled item id 60. The publisher derives it in ascending-ASCII
order from `item_definitions.json`, and the GDScript test checks it against `Items.compiled_id`.
Every box is copied as the derivations wrote it. Nothing is widened.

**Rotation.** Row 34 is row 33 turned an exact quarter, and row 36 is row 35 turned the same way.
Each box maps `(x0,y0,z0,x1,y1,z1) → (z0, y0, −x1, z1, y1, −x0)`. The publisher first confirms
that this map turns every box of published row 13 into row 17. Yaw 0 faces −Z, so S at
(0,0,−576) maps to (−576,0,0) and the 16384 rows face −X, matching the work-area stand points.

**Ground pace.** Rows 31 and 32 get `RATE_GROUND_CAP` pace rows (profile, family −1, variant 0,
the existing Movement profile 1 and revision 1, rate 0). Brendan's decision stands: no new pace
constant. Route composition loads the first-entry bundle's `structure.ugconn` as its single pace
catalog, and every bundle file binds the profile content revision. So `publish_qualified_haul.py`
creates a successor bundle, `first-entry-prefix-v1/qualified-haul-v2/`:

- the v6 profile and ground;
- the v1 structure with content 5 and the 14-row pace table;
- grouping, recipes, Frontier and Workpieces, which change only their content-revision word and
  linked digests. Every other byte is checked equal to v1.

**Connector catalog change.** A pace catalog binds one profile source (`header[10]` = 0), and
`_pace_row_refusal` required each pace row's profile to come from that source. Rows 31 and 32 come
from source 2, so the rule is narrowed. A ground-cap row (family −1) takes its rate from Movement,
not from any source, so it may name a row from another source in the same pinned content.
Authored connector timing (family ≥ 0) stays bound to the catalog's source.

**Assembly source program.** `qualified-assembly-v1/source_program.gd` required exactly 30 rows,
281 boxes and 2 sources. It now accepts successor counts (≥). The check of row 29's words, boxes
271–280 and both source digests is still exact. This is ADR 1198's "earlier rows byte-identical"
generalisation, and with it `ShortStep.uses` holds through `Assembly.uses`.

| Owner | Change |
|---|---|
| `mole_profile_catalog.gd` | v6 pins; 37/334/rev 5/13114 B wire/26212 B paired bank; `SOURCE_COUNT` 3; `catalog_refusal` checks `HAUL_SOURCE_SHA` and hashes the third digest. |
| `underground_route_composition.gd` | Bundle v2; `GROUND_PACE_COUNT` 14 replaces the literal 12. |
| `underground_entry_composition.gd`, `underground_entry_site.gd` | Bundle v2. |
| `underground_motion_catalog.gd` / `_clock.gd` | `REVISION` 5. The bank is rebound, and only the revision words and the wire and input digests change (`b9eb5b95…`). |
| `tools/renew_source_pins.py` | Active publication is v6. |

`qualified-handling-v5` and `qualified-handling-v1` stay as history and are no longer loaded.

## Why

ADR 1198 steps 5–8 need the tool-free WALK and CARRY rows, plus the grip rows at the stand
headings, inside the runtime content. Content 5 is a strict superset, so every existing selection,
driver pin and motion table is unchanged.

## Not covered

- **The curved grip certificate module** (ADR 1198). Rows 33–36 carry certificate 15, as the loader
  requires, but no module yet proves both hand contacts on the wood mesh at runtime. Until that
  lands, the stations must not treat the row as a contact proof.
- **Presentation of source 1 and source 2 rows** (ADR 1198 step 7). `underground_actor_content.gd`
  still matches only the actor digest.
- **Floor support at S** (step 6), **joint memory census** for the extra image, and native
  measurement of the +4,404-byte bank.
- **Pre-existing:** the Python suites `test_compile_entry_frontier.py`, `test_entry_work_area.py`
  and `test_rebind_handling_diagnostic.py` fail with `STRUCTURE_DRIFT:manifest.json`. The
  structural-v1 manifest pins owner digests for `underground_connector_assemblies.gd` and
  `underground_connector_recipes.gd`, and those had already drifted before this change. The
  catalog edit here adds one more drifted owner digest.
