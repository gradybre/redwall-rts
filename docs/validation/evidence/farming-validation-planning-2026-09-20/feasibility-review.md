# Farming owner-2 feasibility review (read-only)

Independent re-derivation from `save_component_columns_schema.gd`, `farming.gd` and `catalog.gd`. No contract, no code, nothing executed. The `astra-source-note.md` hypotheses were re-derived here, not adopted.

## Confirmed owner shape

- Owner index 2, key `farming`, version **1**, primary count **4096**, **0** independent child extents, **15** fields at global begin 45.
- Ordinal types: `_present` u8; `_crop_id _state _soil _fertility _moisture` i32; `_growth_milli_hours` i64; `_health _last_family _family_streak` i32; `_compost_milli` i64; `_sow_day _tile _ref_slot _ref_generation` i32 — twelve i32, two i64, one u8.
- `4096*(1+12*4+2*8)` = **266240** value bytes; `+4` child-count `+15*8` element counts = **266364** payload; `+24+7` key = **266395** block at offset **8192457**. All agree with the compiled tables.
- Catalog IDs must be read, never inferred: `SOIL` and `CROP_STATE` are PROTECTED explicit tables (LOAM=0/CLAY=1/SAND=2; EMPTY..WITHERED=0..4) and are **not** their own ASCII order; `CROP_FAMILY` is compiled ASCII (CEREAL=0..ROOT=4).
- `SavedTileHistory` is section 1 TileHistory, not a FarmPlot capture. One new cold 15-property Columns type per ADR 0132 is feasible, populated from an existing source, with no live Farming/EntityDirectory construction and no callback.

## Pure column domains (15)

present 0/1; crop −1..4; state 0..4; soil 0..2; fertility, moisture, health 0..10000; compost exactly 0 or 2000; last_family −1..4; family_streak 0..INT32_MAX; sow_day 0..INT32_MAX; tile −1 or 0..16383; ref_slot/ref_generation either the null pair or in range; growth nonnegative i64.

## Relations, present rows only

`destroy()` clears only present, crop, state, tile and the ref pair, so an inactive row legitimately retains growth, health, sow_day, moisture, fertility, soil, compost and the history pair. Every invariant below is conditional on `present==1`.

- crop == −1 iff state EMPTY; non-EMPTY ⇒ crop 0..4, `CROP_ALLOWED_SOILS[crop] & (1<<soil)` ≠ 0 (plant enforces it and soil is never rewritten while the row lives) and sow_day ≥ 1.
- EMPTY ⇒ health 10000, growth 0, sow_day 0.
- SOWN ⇒ growth 0 and health 10000; no loss, tend, frost or blight entry accepts SOWN.
- GROWING ⇒ health ≥ 1 and growth below the crop's target.
- RIPE ⇒ health ≥ 1 and growth ≥ target; no writer changes health while RIPE.
- WITHERED has two causes: health 0 with growth below target, or ripe expiry with health up to 10000 and growth at or above target. Requiring health 0 would be false — the probe shows 10000 after expiry.
- History pair: reuse the static `is_history_pair_consistent` after the range checks; do not restate the rule.
- tile/self: present ⇒ tile in range and a non-null ref pair; at most one present row per tile is locally checkable.

## Bounds to state carefully

The strongest defensible present-row growth bound is target+999, since one released hour is at most 1000 milli-hours, but it rests on every writer holding. The retained-inactive column justifies only nonnegative. Prefer state-conditional tightness for present rows over one narrow global i64 bound.

`sow_day` = MAX_I32 is publicly reachable, because `plant()` takes caller-supplied day, season and season_day. No agreement with a loaded world clock may be required of this column.

The 434/0 probe covers public observables only; inactive-row history is publicly unobservable and needs source writer proof, not probe proof.

## Producer-defect finding

`advance_growth_hour_into` updates the tile growth remainder before `checked_add_into` can refuse. Each release is ≤1000 and GROWING growth stays under 193000, so no public sequence reaches that refusal; it is reachable only from an injected or illegally loaded growth value that the domain above already excludes. That is characterisation, not a defect, and no repair is proposed. No other concrete producer defect was proven, and no redesign is suggested.

## Explicitly cross-section, kept separate

The TileHistory `active_plot_row` inverse, Directory identity/kind/typed-row for each ref, the compost mirror against the loaded season, ripe tick, growth remainder, tended flags, the unpopulated orchard reverse map, and clock and provenance agreement are same-file saved bindings. The live `section_1_cross_check_refusal()` is not evidence for any of them.
