# Farming component validation — FARMING-S4-VALIDATE-R01 v1

Status: accepted by Astra for bounded implementation after independent contract review and frozen metadata/witness plans. ADR0180 records this decision. Scope owner2 local FarmPlot columns only, no gameplay producer changes. Existing SavedTileHistory/section1 APIs and live simulation behavior remain unchanged.

## Layout and typed image

Owner2 farming version1, primary4096, no child extents, global fieldbegin45/count15. Values266240, payload266364, block266395, offset8192457. Preserve schema, registry version and every existing public API. Add one cold Columns type with15typed properties (canonical key without leading underscore) and static columns_refusal. No new capture/restore/getter or alternate live constructor.

|Local|Property / canonical key|Type|Count|
|---|---|---|---|
|0|present / _present|u8|4096|
|1|crop_id / _crop_id|i32|4096|
|2|state / _state|i32|4096|
|3|soil / _soil|i32|4096|
|4|fertility / _fertility|i32|4096|
|5|moisture / _moisture|i32|4096|
|6|growth_milli_hours / _growth_milli_hours|i64|4096|
|7|health / _health|i32|4096|
|8|last_family / _last_family|i32|4096|
|9|family_streak / _family_streak|i32|4096|
|10|compost_milli / _compost_milli|i64|4096|
|11|sow_day / _sow_day|i32|4096|
|12|tile / _tile|i32|4096|
|13|ref_slot / _ref_slot|i32|4096|
|14|ref_generation / _ref_generation|i32|4096|

Columns defaults exactly mirror _clear_plot_columns: present0,cropNONE-1,stateEMPTY0,soilLOAM0,fertility/moisture/growth/health0,familyNONE-1/streak0,compost0,sowday0,tileNO_ROW-1,self(-1,0). Existing live creation's health10000/moisture6000/fertility-from-tile are not clear defaults.

## Pure predicate, exact refusal order

Static argument-only; no live Farming/Directory/catalog, callbacks, diagnostics, input mutation, normalization, calendar or float. Success existing REFUSE_NONE. New constants REFUSE_COLUMN_SHAPE/PRESENT/ENUM/VALUE/HISTORY/IDENTITY/FREE_ROW/STATE/DUPLICATE_TILE/DUPLICATE_REF return exact corresponding COLUMN_* string codes. Existing S1_* refusals stay unchanged.

1. Null or any15wrong extents ->COLUMN_SHAPE before indexing.
2. Global4096present byte0..1 scan ->COLUMN_PRESENT.
3. Ascending rows; within each row ENUM, VALUE, HISTORY, IDENTITY, then FREE_ROW or STATE:
   - crop -1..4, state0..4, soil0..2 ->COLUMN_ENUM. Protected Soil/CropState ordinals come from existing Catalog constants, not inferred ASCII order.
   - fertility/moisture/health0..10000; growth>=0 fullnonnegativei64; compost exactly0 or2000; sowday>=0 (packedi32 gives upperMAX) ->COLUMN_VALUE.
   - last_family -1..4; streak>=0 fullnonnegativei32; reuse existing static is_history_pair_consistent after ranges ->COLUMN_HISTORY. NONE iff streak0, named family iff positive streak. This applies to inactive history too; source clear/creation/harvest/deletion preserve the pair.
   - Present tile0..16383 and selfslot0..EntityDirectory.DIRECTORY_CAPACITY-1 (352418rows), generation>0; inactive tileNO_ROW-1 and exact selfNULL(-1,0) ->COLUMN_IDENTITY. Kind, generation liveness and typed-row join stay saved bindings.
   - Inactive requires cropNONE/stateEMPTY only ->COLUMN_FREE_ROW. Preserve all other valid scalar/history fields, including nonzero growth/MAXi64, health0..10000, compost2000 and sowdayMAXi32. These inactive endpoints are synthetic/source-backed, not publicly read through refusing getters.
   - Present EMPTY requires cropNONE, growth0,health10000,sowday0. Other states require crop0..4, sowday>=1 and CROP_ALLOWED_SOILS[crop] matching1<<soil. Only after crop/soil ranges may source tables be indexed. For nonEMPTY, target=CROP_GROWTH_HOURS[crop]*MILLI_HOURS_PER_HOUR; growth<=target+MILLI_HOURS_PER_HOUR-1. SOWN requiresgrowth0/health10000; GROWING requireshealth>0/growth<target; RIPE requireshealth>0/growth>=target; WITHERED requires either health0/growth<target or health>0/growth>=target. All these local producer-state relations ->COLUMN_STATE.
4. Unique present tile values, then unique present selfslot values ->COLUMN_DUPLICATE_TILE then COLUMN_DUPLICATE_REF. Since identity already proves inactive -1, duplicate-and-sort each full i32 column, skip -1 and reject adjacent equal nonnegative values. Two present refs sharing a slot are impossible even if generations differ: saved Directory has only one current generation at a slot. Do not modify originals, infer liveness, or construct Directory.

The state bound follows writers: one hourly release<=1000, GROWING stops below target and changes toRIPE as soon as it crosses. WITHERED preserves growth from healthdeath before target or ripeexpiry after target; healthy WITHERED is valid. No state relationship is imposed on inactive retained growth because destroy clearscrop/state and loses its crop-specific context. Loaded clock comparisons do not belong here: public plant accepts independently supplied day/season arguments, including MAXsowday.

No producer repair: the hypothetical checked-growth-overflow refusal after tile-remainder change requires illegal injected GROWING growth already excluded by the proposed domain. It is not a demonstrated normal public-path defect. No private mutation API is introduced to make it one.

## Framed bridge and source pins

save_owner_farming.gd seven gates: null; wrongowner2; unchanged Schema.schema_refusal; metadata/source pins; unchanged Section.owner_shape_refusal; one coldFarming.Columns with15explicit canonical typed assignments; exact raw columncode wrapped with owner-qualified detail. Only Farming/Schema/Section/SaveHeader preloads. Prefix METADATA_DETAIL_PREFIX=`Farming owner2 metadata:`; column detail contains `Farming owner 2 ` and code; success empty/empty.

Pin farming/version1/primary4096/childcount0/fieldcount15 and every15key/type/count. Pin source FARM_PLOT_CAPACITY4096,TILE_COUNT16384, cropNONE-1/count5 andIDsbeans0,cabbage1,flax2,grain3,roots4; SOIL_LOAM0/CLAY1/SAND2/count3; STATE_EMPTY0/SOWN1/GROWING2/RIPE3/WITHERED4/count5; FAMILY_NONE-1/CEREAL0/FIBER1/LEAF2/LEGUME3/ROOT4/count5; STREAK_NONE0/FIRST1/MAX2147483647; fertility/moisture/healthMIN0/MAX10000, INITIAL_HEALTH10000, compostNONE0/PER_TILE2000, MIN_CALENDAR_DAY1, NO_ROW-1, NULL_REF(-1,0), DirectoryNULL_SLOT-1/NULL_GENERATION0/DIRECTORY_CAPACITY352418; MILLI_HOURS_PER_HOUR1000.

Also pin lengths5 and each entry of CROP_ALLOWED_SOILS=[3,3,5,3,5] and CROP_GROWTH_HOURS=[144,120,168,192,120] because the pure state rule indexes them and depends on their numeric meaning. No live catalog compilation is called. No unrelated yield/window/recipe policy changes or pins.

Caller266240 +defaultColumns266240 +two4096i32sort copies32768 =565248 conservative logical packedbytes, below6417408stream allowance. Two copies may be held together for clear budget accounting; transient wrappers/native allocations/RSS unmeasured. No duplicateworld or new live authoritative allocation. Columns/projection/scratch are cold validation only.

## Evidence, verification and remaining work

Original public history434/0 with clean shutdown proves MAXstreak public restore/mirroring/saturating harvest, MAXsowday, cancellation preservinghistory/compost, healthy ripe expiry, healthloss withering before growth, tile history surviving deletion/recreation and seasonalmirror refresh. It does not prove private inactive bytes or loaded-clock agreement. Feasibility reviewer confirmedlayout and source relations; strongestpresentbounds, uniqueness and exactcode priority remain contract decisions for this review.

Before author dispatch freeze coherent metadata faults and mutation witnesses. Minimum fault matrix: key/version/primary/childcount/fieldcount/fieldkey/type/extent, independent bypasses, control/schema-forward, plus source-table shape/value drift that cannot reach unsafe indexing. All15projection omissions must have independent malformed and acceptednondefault witnesses. Pin every physical4096row and all15types/extents; null/short/long and malformedbucket cases; exact refusal/nonmutation/priority; everyenum/cropsoilpair, allstateedges, growthtarget-1/target/target+999/target+1000, positive/zerohealth WITHERED distinction, MAXi64inactivegrowth/MAXi32day/streak, pair consistency, duplicatesathead/tail andsame selfslot/differentgeneration. All4096present accepted with unique tile/self and correctpresentEMPTY defaults. No equivalently redundant omission may be claimed killed. Parser/runtimeerrors are not mutationkills.

Final required gates:17static/capacityhash/generator checks, actual import/preload closure, focus/fullGodot, metadata/source faults, requiredmutants, independent actualsource review and exact-headCI. Existing full-suite shutdownbaseline is separate.

Saved section1 TileHistory inverse, Directorykind/currentgeneration/typedrow, fertility/family/streak mirrors, compostagainstloadedseason, ripe tick/remainder/tended/orchardbindings, clock/provenance and gameplaylifecycle remain FARMING-SAVED-BINDINGS. Current section1 live cross-check is not same-file proof. Bulk FarmPlot capture/apply and complete restore remain missing. This component milestone does not complete farming gameplay or settlement acceptance.

### Frozen verification plan

metadata-arithmetic-check.json records control plus eight coherent schema faults. Keyfarminh/version2; primaryowner2+1/3-1; childowner2=1/3=0,begin3+1,payload/block2+8/3-8,offset3+8; fieldcount2=16/3=19,begin3+1,payload/block2+136/3-136,offset3+136; fieldkey45changed; fieldtype45u8->i32delta12288; extent45+1delta1. Type/extent update owner2payload/block, all later offsets and both section totals. All preserve298fields/5children/193184primaries. Eight faults/eight individual bypasses/control/schema forwarding=18enginecases. Add short/long/value faults for each of CROP_ALLOWED_SOILS and CROP_GROWTH_HOURS source tables, for24cases/216assertions. Original source remainsunchanged after disposableclonefaults.

frozen-witnesses.json specifies163 exact images and their codes. Physical coverage is every4096row with fault field=row%15, plus each15field at both head and tail; this is deliberately not a15x4096Cartesian fault campaign. Source-aware boundary/state/shape cases, full4096present acceptance and all15projection omissions add separate coverage. Measure actual candidate focus runtime before freezing per-mutant timeout; do not infer runtime from static complexity. No tests mirror a new production predicate as their oracle: Python fixture-consistency results only detect contradictory planning data, and actual Godot runs remain required.

mutation-witness-plan.md freezes50 logical code units plus8metadata bypasses, with equivalent streak-bound exclusions and exactpriority cases. Source-table sixfaultcases prove pre-index metadata guards. Parent owns test integration/actualfaults; authors must not substitute invented passes or the planning model for engine evidence.
