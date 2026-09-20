# Parent-owned Transform validation witness matrix

Draft aligned with TRANSFORMS-S4-VALIDATE-R01draft1; no implementation or run claims.

Independent counts: nine i32 arrays each87552; canonical index0binding,1x,2y,3z,4yaw,5prev_x,6prev_y,7prev_z,8prev_yaw. Frame owner15. Existing public state_bytes order indexes0..7poses,8binding; explicit remap diagnostic8→canonical0 and diagnostic0..7→canonical1..8. state_bytes is test-only evidence, not a proposed save codec.

| Fault/mutant | Parent fixture | Expected intact result | Broken result that must fail an assertion |
|---|---|---|---|
| binding allzero substitution | binding[0]=-1, every pose0 | COLUMN_BINDING_ID | success |
| each of8pose allzero substitutions | binding[0]=0, exactly target pose[0]=1 | COLUMN_FREE_ROW | success |
| omit binding domain | binding[last]=INT32_MIN, poses0 | COLUMN_BINDING_ID | success (duplicate scan ignoresnegative) |
| omit uniqueness | binding[0]=binding[last]=17, poses0 | COLUMN_BINDING_DUPLICATE | success |
| omit free row | binding0 with pose x1 | COLUMN_FREE_ROW | success |
| free before duplicate | free residue atrow0, duplicatepositive17 atrows1,last | COLUMN_BINDING_DUPLICATE | COLUMN_FREE_ROW |
| duplicate before domain | negative atrow0, duplicatepositive17 atrows1,last | COLUMN_BINDING_ID | COLUMN_BINDING_DUPLICATE |

All9short/empty/long shapes must return COLUMN_SHAPE in staticpredicate, SAVE_COMPONENT_SHAPE in framed bridge, even when another column carries an earlier-range fault. Each8freepose atrows0,1023,1024,82943,82944,83455,83456,87551 detects droppedphysicaltail and kind-boundary shortcuts. Samepositive binding distinct across boundaryrows for validfixture. Full87552uniquepositivebinding column accepts; large number isphysicalstorage, notlivingpopulation count.

All signed extrema in everypose atboundrow accepted; arbitrary INT32_MIN/MAX yaw and differentcurrent/previous retained. BindingINT32_MAX accepts locally; savedcursor gate separately must establish range of spentIDs. Allzero frame isvalidempty; repeatedzeros neverduplicate. Negativebindinggate isglobal beforeduplicate; duplicatebeforefree. Each path preserves allinputpackedvalues and existingownerdiagnostics/count/digest.

Actual publicprobe establishes signedextrema, presentationnonmutation, stale retainedpose, successorunplaceduntilplace, replacementdoesnotdoublecount, andunbindzeroesall9. Replay in assertions andframe the diagnostic remap. No callerprivatecolumn reads or inventeddefaults. Validation must never invoke liveowner construction despite tests constructingowners asfixtures.

Do not claim pose-field swap mutants killed: all8pose columns have symmetric domains andfree-row rule. Canonical mapping still requires explicitnineaccessor source review and testfixture identity pins; latercodec/bulkrestore must verify valuesatindividualfieldpositions.
