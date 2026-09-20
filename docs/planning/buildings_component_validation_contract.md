# Buildings component validation and borrowed-buffer contract

BUILDINGS-S4-VALIDATE-R01 · version1 · accepted for bounded implementation, 2026-09-20; ADR0183.

This milestone validates the29 existing section4 building/room/furniture columns. It does not implement live construction, change furniture occupancy policy, infer complete room validity, complete section1/5 consistency, or add bulk capture/apply. No schema or canonical registry version changes.

## Layout and cold image

Owner0 buildings/version1, primary1024, two child extents16384 rooms and81920 furniture, fieldbegin0/count29. Values3298304, payload3298556, block3298589, offset4. Self references, parent/child chains, room tile arena, kind counts and tile maps are elsewhere in sections1/5 and are not silently added to this image. Ordinals come from the schema, never source declaration order.

Columns has29 typed packed properties. Argument allocate_defaults:bool=true preserves a normal fully sized clear image. With false, return before any resize/fill, leaving all29 member initializers as empty typed packed arrays. This path exists only for borrowed framed validation; it does not construct live Buildings, Definitions or Directory. is_sized checks all29 exact extents. Any unbound empty view refuses COLUMN_SHAPE.

| Ordinal | Property | Type/count | Clear value |
|---|---|---|---|
|0|b_present|u8[1024]|0|
|1|r_present|u8[16384]|0|
|2|f_present|u8[81920]|0|
|3|b_type_id|i32[1024]|0|
|4|b_tier|i32[1024]|0|
|5|b_origin_tile|i32[1024]|-1|
|6|b_rotation|i32[1024]|0|
|7|b_state|i32[1024]|0|
|8|b_condition|i32[1024]|0|
|9|b_construction_slot|i32[1024]|-1|
|10|b_construction_generation|i32[1024]|0|
|11|b_interior_id|i32[1024]|-1|
|12|r_type|i32[16384]|0|
|13|r_building_slot|i32[16384]|-1|
|14|r_building_generation|i32[16384]|0|
|15|r_tile_offset|i32[16384]|0|
|16|r_tile_count|i32[16384]|0|
|17|r_temperature_tenths|i32[16384]|0|
|18|r_furniture_mask|i32[16384]|0|
|19|r_occupants|i32[16384]|0|
|20|r_valid|u8[16384]|0|
|21|f_type_id|i32[81920]|0|
|22|f_room_slot|i32[81920]|-1|
|23|f_room_generation|i32[81920]|0|
|24|f_origin_tile|i32[81920]|-1|
|25|f_rotation|i32[81920]|0|
|26|f_user_slot|i32[81920]|-1|
|27|f_user_generation|i32[81920]|0|
|28|f_condition|i32[81920]|0|

## Pure ordered domains

static columns_refusal(image:Columns)->StringName returns existing REFUSE_NONE on success. Exact new codes are COLUMN_SHAPE/FLAG, COLUMN_BUILDING_ENUM/VALUE/REF/FREE/STATE, COLUMN_ROOM_ENUM/VALUE/REF/FREE/STATE, COLUMN_FURNITURE_ENUM/VALUE/REF/FREE/STATE, with matching REFUSE_COLUMN_* constants. It reads only supplied buffers and pinned immutable constants; no writes, live constructors, diagnostic, clock, callback, float, per-row object or packed scratch.

First null or any incorrect extent gives SHAPE. Then scan entire b_present, r_present, f_present, r_valid buffers in that fixed contract order (not an order inferred from storage type or future ordinals) for canonical0/1, giving FLAG before any scalar row. Then ascending building rows, ascending room rows, ascending furniture rows. Within each row use exactly the gates below, returning the first code.

Building:
1. ENUM: type0..29, tier0..2, rotation0..3, state0..5.
2. VALUE: origin-1..16383, condition0..MAX_i32, interior-1..MAX_i32.
3. REF: construction exactlyNULL(-1,0) or slot0..352417/generation1..MAX_i32.
4. FREE: if inactive and tier0, require the exact clear building row (type0,origin-1,rotation/state/condition0,constructionNULL,interior-1); then this row succeeds. This discriminates never-used storage, not destroyed history.
5. STATE: all other rows, including inactive retained history, require tier1 for any valid type, or tier2 only for typeIDs5/12/23/29, origin>=0 and the source rotated footprint inside128x128. Present tier0 refuses here. No construction-versus-state or interior-versus-managed-building implication: public setters do not impose one.

Room:
1. ENUM: type0..7.
2. VALUE: offset0..16384, tile_count0..16384, mask0..511, occupants0..256. Temperature permits the full signed i32 domain, already enforced by its packed type.
3. REF: building exactlyNULL or structural slot0..352417/generation>0.
4. FREE: inactive offset/count/mask/valid must all be0. If its parent is NULL, also require type/temperature/occupants0 (exact never-used row). Inactive rows with retained nonnull parents keep valid type/temperature/occupants history, but still require valid==0 and offset/count/mask==0. This row then succeeds.
5. STATE: present parent must be nonnull, tile_count>=1, offset+count<=16384. Do not derive valid from furniture counts, heat, enclosure or access; it is externally supplied. Do not compare mask against furniture references without saved self identity.

Furniture:
1. ENUM: type0..8, rotation0..3.
2. VALUE: origin-1..16383, condition0..MAX_i32.
3. REF: room and user independently NULL or structural references.
4. FREE: inactive user must beNULL. If inactive parent isNULL, require type0,origin-1,rotation/condition0 (exact never-used row), then this row succeeds. Retired rows may retain nonnull parent/type/origin/rotation/condition.
5. STATE: every other row requires nonnull room and origin>=0, with the source rotated floor footprint inside128x128. Edge furniture has0x0 floor footprint and is valid at any valid origin; it claims no floor tile. Present rows may have nonnull users even when catalog user_slots=0: current public APIs demonstrably permit this, and live policy repair belongs to a separate contract.

Rotated dimensions exchange X/Z for odd rotations. Bounds are checked before lookup. All coordinate arithmetic and offset+count fit i64. Parent and user references are structural only; saved Directory kind/current generation/typed row and parent liveness are not local assumptions. Footprint overlap, room tile coverage and map reciprocity stay in the section1/5 binding pass.

## Immutable source facts and bridge

Owner-side static arrays: COLUMN_BUILDING_KEYS, COLUMN_BUILDING_FOOTPRINT_X/Z (30 each), COLUMN_FURNITURE_KEYS, COLUMN_FURNITURE_FLOOR_X/Z (9 each), COLUMN_TIER_TWO_TYPE_IDS=[5,12,23,29]. Their exact contents are frozen-source-facts.json, derived by canonical catalog ID. They do not allocate per row. No live BuildingDefinitions construction is allowed to obtain facts.

save_owner_buildings.gd directly preloads only Buildings/Schema/Section/SaveHeader; Catalog, BuildingDefinitions and Directory are reached via existing Buildings preloads. Seven gates: null, wrongowner0, unchanged schema refusal, metadata/source pins, unchanged owner shape refusal, Columns.new(false) plus29 explicit canonical typed assignments, then raw pure code wrapped with detail containing `Buildings owner 0 ` and the code. Success code/detail empty; metadata prefix `Buildings owner0 metadata:`. These two distinct literal prefixes are deliberate and independently asserted; do not normalize their spacing. No full-copy constructor, duplicate, serialization or new buffer during projection.

Pin ownerkey/version/primary1024/childcount2/each childextent16384,81920/29field key,type,count declarations. Source pins: capacities1024/16384/81920, map128x128/tile_count16384, room tile links16384, rotation_count4/state_count6/room_type_count8/furniture_kind_count9, NO_ROW/NO_LINK/NO_INTERIOR=-1, DirectoryNULL_SLOT=-1/NULL_GENERATION0/DIRECTORY_CAPACITY352418/RESIDENT_LIVING_CAP256, Definitionsbuilding_count30/furniture_count9/MIN_TIER1/TIER_TWO2, CatalogEMPTY_CATALOG_ID=-1 and exact protected room/state ordinals.

Pin all owner fact-array lengths before any entries. For the immutable source dictionaries, check exact sizes30/9; for each expected key check existence, canonical ID type=int/value=ordinal, facts type=Array, exact row lengths10/4 before reading dimensions, dimensions type=int and exact frozen values. Pin Definitions.B_FOOTPRINT_X=0/B_FOOTPRINT_Z=1, Definitions.F_FLOOR_X=0/F_FLOOR_Z=1, TIER_TWO_KEYS length4 and exact ordered keys. All owner fact arrays must equal the frozen constants as well. Source/preflight drift refuses METADATA before any column projection/indexing.

## Memory and verification

This is a logical ceiling comparison, not a measured Buildings peak: full caller plus full defaults would be6596608 bytes, exceeding the6417408 stream allowance by179200 and violating the no-second-owner rule. Borrowed Columns.new(false) avoids this. Buildings values3298304 plus two largest-field allowances2*327680 plus3*65536 windows=4150272, within the existing6417408. No allowance increase is approved. Release-before-next-owner still applies; metadata/object/empty-array/native overhead remains separately unmeasured.

The synthetic borrowed-view experiment measured3724 bytes incremental static peak versus3302692 for the forbidden default-image path. It is not evidence for the future adapter. On the actual adapter, use the same owned cold-clone ballast method and require incremental static peak<1048576 across a valid full-capacity framed call. The allocation test must fail closed when either OS static-memory method is unavailable, readings are zero/invalid, or ballast fails to raise current static usage above the previous peak. Such a run is unavailable/failed evidence, never a zero-increment pass. A mutation replacing new(false) with new() must fail that bound through its allocation assertion, with the same valid measurement prerequisites. This narrowly detects an extra full image; it is not process RSS or100MB release qualification. Preserve the experiment's initial native-class-name parse failure and corrected results.

Before author dispatch freeze value/shape/priority cases, coherent metadata counterfactuals and named semantic mutants. Each field gets first/interior/last witnesses; full-capacity mixed and retained valid images cover all groups. Avoid quadratic full-store revalidation at every row; do not claim exhaustive physical-row fault injection. Include skip-only-first/even-row/skip-furniture-group mutants with odd final-row failures, all29 projection omissions, a direct pure-image write caught by complete nonmutation, and the default-constructor allocation mutant. Benchmark the full-capacity path before any time claim. No parser/runtime-error catches count.

Existing public probes3/40 and1/16 pass; private inactive bytes remain source-backed. Required final gates are static/capacity checks, actual import, focused/full suite, frozen faults, independent exact-source review, exact-head CI and merge. BUILDINGS-SAVED-BINDINGS must still reconcile Directory self IDs, section5 parent/child chains/arena/kind counts, section1 tile maps/overlap, mask equality, construction links/users, loaded tick and common provenance. Full capture/apply, gameplay occupancy policy and live construction remain unfinished.

## Reviewed witness additions

171 explicit value/history/priority cases include a retired tier1 building retaining a nonnull structural construction reference. The additional overrestrictive-retired-reference mutant must be caught, making76 required semantic code units (75 functional including29 projections, plus1 allocation unit). The89 shape cases,87 sampled field/row faults and69 metadata cases/621assertions remain unchanged. Review arithmetic for170/75 is preserved as historical pre-disposition evidence. These are planned counts, not executed results.


## Independent source-review refinement — September 20

The frozen69-case metadata plan is retained as historical evidence. Review M2 requires exact state/room dictionary size, key membership, integer type and ordinal gates; the bridge now checks all six BUILDING_STATE and eight ROOM_TYPE keys before projection. Revision2 adds missing/extra/last-id-type faults for both dictionaries (75cases/675assertions); follow-up F1 adds one size-preserving last-key rename per dictionary (revision3:77cases/693assertions). The10existing schema-bypass catches remain unchanged. CORRIDOR missing/type/rename cases preserve only the existing integer7 alias in owned cold clones to reach runtime metadata; production aliases and dictionaries remain unchanged. This extends evidence for the same frozen source-domain contract, not a new saved schema.

Final bridge verification runs focus, all77metadata cases, allocation and all29projection units against its final hash. The46unchanged-owner functional units may retain their original valid runs only with byte-identical owner/test inputs and a recorded pure-owner assertion witness independent of bridge metadata for every unit. There remain75unique functional units plus1allocation unit;77initial and31final functional executions are distinct runs, not108unique mutants. Executable171-case content equality is archived beside its output. Actual full-suite/import/static/CI acceptance remains required.
