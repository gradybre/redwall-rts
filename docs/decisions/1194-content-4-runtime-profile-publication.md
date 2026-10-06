# 1194 — Runtime loads the content-4 mole profile publication

Date: 2026-10-06 · Status: Accepted

## Decision

The runtime mole profile publication moves from `qualified-step-v4` (content 3,
29 rows, 271 boxes, one source) to `qualified-handling-v5` (content 4, 30 rows,
281 boxes, two sources). `publish_handling_runtime.py` creates the new
publication once. It refuses unless content 4 is a strict superset: rows 0–28,
boxes 0–270 and the actor source must be byte-identical to content 3. Row 29 is
the stationary assembly-handling WORK profile (policy 7, palm contact). Its
boxes are 271–280, and its second source digest is `b94d676e…`.

| Owner | Change |
|---|---|
| `mole_profile_catalog.gd` | Pins point to v5; 30/281/rev 4/10912 B wire/21808 B paired bank. `catalog_refusal` requires exactly two sources (actor + `HANDLING_SOURCE_SHA`). |
| `underground_session.gd` | Source capacity follows `Catalog.SOURCE_COUNT` (2). |
| `underground_route_composition.gd` | Content revision and ground pace come from the ADR 1190 bundle accessor (`877be098…`, revision-4 header). |
| `underground_motion_catalog.gd` / `_clock.gd` | `REVISION = 4`. The motion bank is rebound to the v5 wire. Only the revision words, the embedded wire digest and the input-manifest digest change; tables are byte-identical. |
| `tools/renew_source_pins.py` | Now renews v5 pins. |

`qualified-step-v4` stays in the repository as history and is no longer loaded.

## Why

The real paid-L0 flow needs row 29 at runtime; until now only test fixtures
loaded content 4. Because content 4 is a strict superset, every existing
selection, driver pin (profiles 0, 1 and 13–28) and motion table is unchanged.

## Not covered

- **Presentation of row 29.** `underground_actor_content.gd` matches a
  row's source digest against the actor digest, so row 29 (source 1) has no
  actor presentation yet. A worker drawn during handling needs a handling
  clip or a reviewed presentation fallback. This is open.
- The memory census grows by 820 bytes (the paired profile bank). It is
  counted in `test_underground_motion_catalog.gd`'s admission total, but no
  native measurement was made.
