# Residents component validation — RESIDENTS-S4-VALIDATE-R01 v1

Status: accepted for bounded implementation by Astra after independent contract review and recorded dispositions; ADR0178. Scope is owner12 local validation plus bounded null/arrival producer repairs. Saved cross-owner bindings and complete world restore remain separate. Original public history39/0 and null capture/restore SCRIPT ERROR characterization are recorded in residents-validation-planning-2026-09-20; clean repaired acceptance remains required.

## Existing layout and API

Owner12 `residents`, version2, primary512, no child extents, global field begin236/count19. Values102912, payload103068, block103101, offset9447326; next owner13 starts9550427. Do not change schema, registry ordinals or Columns capture/install API. ADR0132 requires Columns rather than nineteen positional arguments.

| Local | Column | Type | Count |
|---|---|---|---|
|0|_present|u8|512|
|1|_species|i32|512|
|2|_size_class|u8|512|
|3|_named|u8|512|
|4|_life_stage|u8|512|
|5|_arrival_tick|i64|512|
|6|_role|u8|512|
|7|_home_slot|i32|512|
|8|_home_generation|i32|512|
|9|_bed_slot|i32|512|
|10|_bed_generation|i32|512|
|11|_ref_slot|i32|512|
|12|_ref_generation|i32|512|
|13|_equip_tool_item_id|i32|512|
|14|_equip_tool_durability|i32|512|
|15|_equip_satchel_slot|i32|512|
|16|_equip_satchel_generation|i32|512|
|17|_skill_xp|i64|6144|
|18|_skill_level|i32|6144|

## Shared local rules and live refusal compatibility

Add `static func columns_refusal(columns: Columns) -> StringName`. It is argument-only, does not mutate inputs or diagnostics, does not construct Residents, read instance catalogs/Directory/Needs or accept callbacks. Success REFUSE_NONE. Reuse existing COLUMN_* codes.

Extract a static `_columns_local_prefix_refusal` containing the existing restore sequence after catalog-error and before `_column_live_row_refusal`, unchanged:

1. Null or any incorrect extent: COLUMN_SHAPE before indexing. Put null handling in the shared shape helper, making public copy_columns_into(null) refuse safely too.
2. Existing byte-domain order: present0..1 ->COLUMN_PRESENT_BYTE; named0..1 ->COLUMN_NAMED_BYTE; size0..2, stage0..2, role0..2 in that order ->COLUMN_ENUM_BYTE. Each byte scan covers all physical rows.
3. All6144XP nonnegative fulli64 ->COLUMN_SKILL_XP; all levels equal the bounded integer level curve ->COLUMN_SKILL_LEVEL; reserved skill3 XP/level zero at every row ->COLUMN_RESERVED_SKILL. Keep the existing sorted-copy XP helper; no unrelated optimization.
4. Existing ascending row reference/equipment loop, preserving within-row and cross-row priority. For home,bed,self,satchel in that order, exact(-1,0) or anynonnegativei32slot/positivegeneration ->COLUMN_REF_SHAPE. Then item>=-1,durability>=0 and item==-1 impliesdurability0 ->COLUMN_EQUIPMENT. Do not impose arena/catalog/recipe bounds.
5. Existing ascending inactive-row checks ->COLUMN_FREE_ROW: anonymous named0, stageADULT0, roleRESIDENT0, selfrefnull, no tool and nullsatchel. Earlier shape/pair/equipment rules prove remaining halves. Retained species/size/arrival/home/bed/skills survive; inactive species stays fullsignedi32 and arrival fullsignedi64, including oldnegativehistory.
6. present.count(1)<=256 ->COLUMN_LIVING_CAP, preserving current Directory active-resident bound. Storage remains512. No lifecycle/cap redesign.

After that prefix, the saved predicate walks present rows ascending: species0..15 ->COLUMN_SPECIES, then arrival>=0 ->COLUMN_ARRIVAL_TICK. It does not consult species-to-size catalog or Directory. Factor these two scalar rules into static helpers so policies are shared, not duplicated.

The existing live `_restore_column_refusal` keeps `_catalog_error` first, calls the shared prefix, then keeps the original live-row walk: species range, compiled size, arrival, Directory kind and typed-row identity PER ROW. Use shared scalar helpers in their original positions. Do not call the whole saved predicate from live restore: doing so could move a later-row arrival error ahead of an earlier-row size/Directory error. Preserve current live diagnostics with paired-fault tests.

Keep public instance `skill_level_for_xp` as a wrapper around one static curve helper used by validation. Curve max10, threshold5000*L², xp<0 returns0 as before. No floating arithmetic or multiplication by unbounded XP. Convert argument-only validation helpers to static as needed; preserve all old callers and capture/install semantics. Names remain section14 and are cleared by existing successful restore.

## Producer repair

Add OpResult `REFUSE_INVALID_ARRIVAL_TICK = &"INVALID_ARRIVAL_TICK"`. In set_arrival_tick, preserve NOT_PRESENT first, then use the shared arrival scalar rule to refuse negative ticks before writing. Accept0..INT64_MAX unchanged. Refusal preserves all canonical bytes. Do not erase or normalize retained inactive negative history. Existing live/saved column refusal spelling remains COLUMN_ARRIVAL_TICK.

## Framed bridge

Add save_owner_residents.gd following the seven-gate Needs bridge: null; wrongowner12; Schema.schema_refusal forwarded unchanged; metadata/sourcepins; Section.owner_shape_refusal forwarded unchanged; construct one Residents.Columns and explicitly assign all19typedcanonicalaccessors; call static predicate and wrap its exact raw code with owner-qualified detail. Success empty code/detail. Metadata detail prefix `Residents owner12 metadata:`; column detail contains `Residents owner 12 ` and code. Only Residents/Schema/Section/SaveHeader preloads, no live owner construction or restore/copy calls.

Pin key residents, version2,primary512,child0,count19; Residents.COLUMN_COUNT and all three declaration-array lengths19, every canonical key/type/count parity. Pin RESIDENT_CAPACITY512,RESIDENT_LIVING_CAP256,SPECIES_COUNT16,SIZE_COUNT3/SMALL0/MEDIUM1/LARGE2,stageADULT0/CHILD1/ELDER2/COUNT3,roleRESIDENT0/WARDEN1/SPECIALIST2/COUNT3,SKILL_COUNT12/reserved3/maxlevel10/XPfactor5000,NO_TOOL_ITEM-1,DirectoryNULL_SLOT-1/NULL_GENERATION0 and NULL_REF. No unnecessary live Directory capacity pin for shape-only refs. No schema format changes.

One caller image102912 + default Columns buffers102912 + largest XP sorted copy49152 =254976logicalpackedbytes conservatively, below existing6417408stream allowance. Projection assigns buffers, does not duplicate them, and is discarded on return. Cold Refusal/Columns/native overhead remains unmeasured. No new resident packedallocation, alternateconstructor, native/RSS claim or speculative optimization.

## Verification to finalize before author dispatch

Public history probe, null capture/restore characterization, nineteen mapping witnesses, actual legacy restore priority fixtures, negative arrival atomicity, all physical row/tail/skill positions, retained inactive history/full endpoints, shape/null/bucket validation, exact-code/nonmutation, metadatafault plan and required mutants. Mutants other than the explicitly characterized null-guard runtime-error case must fail by assertions, not parse errors; distinguish refusal-identity witnesses from acceptance-domain witnesses and identify redundant omissions honestly. Capture once, mutate independent buffers; outer Array copy alone does not snapshot packed arrays.

Metadata counterfactual plan: key residentt same9bytes; version2->3; primary12+1/13-1; child10->12 with childbegin11/12-1, owner10payload/block-8,owner12+8, offsets11/12-8; fieldcount append ResourceNodes firstu8[4096] after all19Residents fields, counts12=20/13=9,begin13=256,payload/block12+4104/13-4104,offset13+4104; fieldkey236 changed; fieldtype236u8->i32delta1536; extent236+1delta1. Type/extent update owner12payload/block, offsets13..17 and both section totals. Schema remains internally coherent, all19knownfields preserved in countcase. Eightfaults/eightgatebypasses/control/schemaforward=18cases162assertions, then source hashes unchanged. Source parity and sourcepin fault witnesses may add required cases after review.

## Explicit remaining saved bindings

Verified compiled species-size catalog agreement, saved Directory self-kind/typed-row identity and uniqueness, home/bed target kinds/liveness policy, saved Needs presence/health/status and death commit barrier, section14name pairs, equipment/item/container/Gear ownership and common-file provenance. Generic local acceptance cannot authorize world publication. Existing capture/restore APIs remain live-owner interfaces; installing a complete validated file and coordinating names/Needs/Directory remain later integration.

## Required acceptance matrix (author and reviewer must consume)

1. Existing test_residents_columns suite stays unchanged unless adding priority/null/arrival regression coverage. Shared prefix/live row behavior retains all old tests. Public real-catalog fixtures use Directory/Needs only in tests, never bridge.
2. All19shape omissions: zero,short,long; staticnull and bridge null/wrongowner; all5byte/12i32/2i64 bucket cardinalities. Malformedshape plus earlierrow badvalue must refuse shape before index. Every field mapping has both legitimate nondefault and malformed witnesses, with explicit packed-buffer snapshots for accepted/refused calls. NoArray-onlysnapshot.
3. Exercise each512row physical address in the static prefix. For XP/level6144addresses, use a bounded test implementation whose cases genuinely visit each address, with no assumption that only active rows matter; time it before freezing mutation harness limits. Named/life/role/size tests pin every enum edge. Include all16species valid on presentrows, -1/16invalid and fullsignedinactive extremes.
4. Preserve all genericpair endpoints, includingmaxi32slot/maxgen forhome/bed/satchel, exactnull, halfnull and negativegeneration. Equipment item-1/dur0, item0/dur0 andmaxi32 endpoints legal; item-2,negativedur and emptyitem/nonzerodur refuse. Selfpair shape is local; its identity is saved binding.
5. XP0..MAX and curveboundary values4999/5000/19999/20000/499999/500000/MAX; reserved3 cannotcarrypositiveXP evenwhenlevelmatches. Skill retainedoninactive. Free-row named/stage/role/self/tool/satchel violations; positivepresent fixtures may have healthy, anonymous and unassigned references.256present accepted,257refused; a valid presentrow511 is accepted withoutprefixrestriction.
6. Public negativearrival -1/MIN refuses INVALID_ARRIVAL_TICK with fullstate equality; absentnegative givesNOT_PRESENT.0/MAX accepted. Public copy/restore(null) falseCOLUMN_SHAPE with no script errors. OldinactiveMINarrival remainsaccepted by Columns predicate and actualexistingrestore, preserving all19fields. Normalnames clear/restore behavior unchanged.
7. Legacy priority: an earlier presentrow size mismatch wins over laterrow negativearrival; earlierrow Directory mismatch wins over laterrow badspecies/arrival; same-row speciesbefore sizebeforearrivalbeforeDirectory. Purepredicate remains speciesbeforearrival perpresentrow, deliberately deferring size/Directory. Existing catalog-error-first path remains source-reviewed; do not add a production corruption setter to construct that fixture.
8. Required actual mutants:19individual projection assignment omissions (leaving Columns defaults, not a different schema), all5byte clauses, XPnonnegative/levelcurve/reserved rule, each of4referencepair clauses, equipmentitemfloor/durfloor/emptydur, each of6free-row clauses, presentcap, present speciesrange/arrival, shapepriority and purepresentrow scalarpriority, arrivalproducer guard, nullshape guard, and legacypriorityreordering. Redundant free-row halves need no separate equivalent mutant; every required mutation must have a real witness or be explicitly revised before authoring. Preserve source after runs. Exactcode assertions may kill an omission that still refuseslater: label this honestly.
9. Nullguard omission causesSCRIPT ERROR, which is itself the characterized defect. Its dedicated mutation oracle must require the original operation stillruns/returnsfalse/COLUMN_SHAPE and exactknownNilshapeerror; report as runtime-error detection, not assertion-killed. Normalfocusedruns must fail on anySCRIPT ERROR. Do not classify unrelated parser failures as killed.
10. Run17static gates, capacity-source regeneration, generator parity, actual import/preload graph, focus/fullGodot, metadatafaults, requiredmutants, independent source review and exact-headCI beforemerge. Fullshutdownbaseline553objects/33resources remainsseparate; newfocusedtests shouldshutdowncleanly.

### Frozen omission oracles and measured bounds

Use a cleared Columns image with present[511]=1. For each omitted projection assignment, change only its designated field at511 (6143for skill arrays), preserving all other defaults. The omission leaves its existing constructor default and therefore removes the intended fault: present2 ->COLUMN_PRESENT_BYTE; species-1 ->COLUMN_SPECIES; size3/stage3/role3 ->COLUMN_ENUM_BYTE; named2 ->COLUMN_NAMED_BYTE; arrival-1 ->COLUMN_ARRIVAL_TICK; each slotfield(home7,bed9,self11,satchel15)-2 with generation0 ->COLUMN_REF_SHAPE; each generationfield8/10/12/16=-1 with slot-1 ->COLUMN_REF_SHAPE; toolitem-2/durability0 or toolitem-1/durability-1 ->COLUMN_EQUIPMENT; skillXP[6143]=-1/level0 ->COLUMN_SKILL_XP; skilllevel[6143]=1/XP0 ->COLUMN_SKILL_LEVEL. For present omission all other fields stay cleared, so inactive defaults are valid. These19witnesses are designed as acceptance-domain kills; report any actual later refusal honestly. Validnondefault fixtures additionally catch omissions that corrupt a pair; they are not substitutes for the malformed matrix.

Original publicrestore benchmark covered every6144XP and6144level position:24578assertions/0failures in3.838seconds, noSCRIPTERROR, on this Mac with only oneheavyjob. This is bounded feasibility evidence, not future static implementation timing or a release performance claim. Put all-address coverage in one focused test; allow180seconds per mutation run, verify each run's expectedtestcount and absenceofparseerrors. Expected48required mutation sites:47assertion oracles plus1nullruntimeerrororacle. Nullruntimeerrorcase must run dedicated publiccapture/restore probe, require both false/COLUMN_SHAPE results plus knownNil.skill_xp error at the shapehelper, and reject anyunrelatedparseerror; baseline/restoredprobe must have noerrors. Metadata8bypasses are additional, total56required detections when executed.

Sixfree clauses have independent earlier-gate-valid fixtures: inactive named1,stageCHILD1,roleWARDEN1,selfpair(0,1),toolitem0/dur0,satchelpair(0,1), with allotherdefaults. No redundant generation/durability-half omission is included. The metadata countfault borrows ResourceNodes OWNER13 firstfield, not owner10; all19Residents descriptors remain before the appendedfield. Legacycatalog-error-first remains source-reviewed without adding a productioncorruption API.
