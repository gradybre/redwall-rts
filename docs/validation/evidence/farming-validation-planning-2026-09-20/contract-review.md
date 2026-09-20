# Contract review — FARMING-S4-VALIDATE-R01 v1

Independent, read-only review of `docs/planning/farming_component_validation_contract.md`
against the supplied `farming.gd`, `catalog.gd`, `entity_directory.gd` and
`save_component_columns_schema.gd`. Nothing was executed and no other file is proposed
for change. Verdict: **no counterexample found; accept with three notes.**

## Layout, domains and budget re-derived

- Owner 2 `farming`: `OWNER_FIELD_BEGIN[2]=45`, `OWNER_FIELD_COUNTS[2]=15`, version 1,
  primary 4096, zero child extents. Global keys 45..59 are exactly the 15 listed, in the
  listed order; types are u8 at 45, i64 at 51 and 55, i32 elsewhere — matching local 0
  (`present`), 6 (`growth_milli_hours`), 10 (`compost_milli`). All 15 counts are 4096.
- Values 4096 + 12·16384 + 2·32768 = 266240; payload 4 + 15·8 + 266240 = 266364; block
  24 + 7 + 266364 = 266395; offset 8192457. All four agree with the compiled table.
- Defaults mirror `_clear_plot_columns` exactly, including `NO_ROW = NULL_SLOT = -1` and
  self `(-1, 0)`. Live creation's 10000/6000/tile-fertility are correctly excluded.
- Protected ordinals match `Catalog.SOIL` and `Catalog.CROP_STATE`; crop ids are ASCII
  (beans 0 … roots 4); `CROP_ALLOWED_SOILS=[3,3,5,3,5]` equals `BALANCE_ALLOWED_SOILS`;
  `CROP_GROWTH_HOURS=[144,120,168,192,120]` transcribes §5.6.
- Budget 266240 + 266240 + 2·16384 = 565248, under the 6417408 allowance. Arithmetic
  holds; it is a logical packed figure, not RSS, and the document says so.

## Rules checked against every writer

- **Inactive rows.** `destroy()` clears only present/crop/state/tile/ref; fertility,
  moisture, growth, health, family, streak, compost and sow_day survive. The FREE_ROW
  rule (crop NONE, state EMPTY, tile −1, self NULL, everything else retained) is the
  weakest rule consistent with that writer. Full nonnegative i64 growth is wider than
  any producible value but safe: nothing indexes it, and `_write_created_row` and
  `plant()` both zero it before a crop exists.
- **Present states.** EMPTY is written only by `_write_created_row` and `_reset_to_empty`,
  both leaving growth 0, health 10000, sow_day 0; no EMPTY-legal mutator moves health.
  SOWN is written only by `plant()` (growth 0, health 10000, sow_day ≥ 1 via `_check_day`);
  growth, tend, frost and blight all refuse non-GROWING. GROWING implies health > 0
  because `_apply_health_loss` withers at 0, and growth < target because `_ripen_if_complete`
  promotes on reaching it. RIPE keeps health > 0 (no loss path accepts RIPE). WITHERED has
  exactly two producers, so the stated disjunction — (health 0, growth < target) or
  (health > 0, growth ≥ target) — is both exhaustive and tight; a healthy WITHERED row is
  legal and a health-0 ripe-expired row is not producible.
- **target+999.** One hourly release is `(remainder<10^6 + 1000·tf·mf ≤ 10^9)/10^6 ≤ 1000`,
  applied only from growth < target, so growth ≤ target+999 = target+`MILLI_HOURS_PER_HOUR`−1.
- **Pair consistency on all rows.** `clear()`, `create_plot_at_tile()`, `_record_rotation()`
  and `restore_tile_family_history()` are the only pair writers and each preserves
  `is_history_pair_consistent`; `destroy()` does not touch it. No counterexample.
- **Uniqueness.** `create_plot_at_tile()` refuses an occupied tile, so present tiles are
  unique; a directory slot holds one live generation at a time and `destroy()` clears
  `present`, so two present rows cannot share `ref_slot` even with differing generations.
- **No unguarded source index.** Crop 0..4 and soil 0..2 are proven by ENUM before STATE
  evaluates `1<<soil`, `CROP_ALLOWED_SOILS[crop]` or `CROP_GROWTH_HOURS[crop]`; EMPTY and
  inactive rows index no table at all. The proof is complete for the stated order.
- **Cost.** 4096 rows × 15 fields plus two 4096-element sorts is ~61k element reads and no
  per-row allocation, provided the predicate returns codes rather than result objects.

## Notes for the author

1. Pin the CropFamily ids by equality with `Catalog.CROP_FAMILY[...]`, not bare literals;
   Soil and CropState already do this and a second hand-written ordinal set is the drift
   decision 0018 forbids.
2. The global present-byte scan precedes per-row faults, so a late present byte outranks an
   early enum fault. That is a defensible choice but must appear as an explicit priority
   witness, alongside VALUE-before-STATE for negative growth on a present GROWING row.
3. The one true blocker to codec dispatch is that no bulk FarmPlot capture/apply exists;
   the predicate is unreachable from a real save until it does. TileHistory inverse,
   directory kind/generation joins and compost-versus-loaded-season remain correctly
   deferred to FARMING-SAVED-BINDINGS and are not local blockers.
