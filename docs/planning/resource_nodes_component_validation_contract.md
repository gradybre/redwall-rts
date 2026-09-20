# ResourceNodes component validation — RESOURCE-NODES-S4-VALIDATE-R01 v1

Date2026-09-20. Accepted by Astra after independent final contract review and recorded corrections; ADR0176 authorizes bounded implementation. Bounded owner13 scalar-domain validation. This does not establish full saved-world resource identity or catalog membership.

## Authority and image

GDD sections4.2/5.1/5.9, REQ-SET-138/139, ADR0052 and existing clear/create/deposit/harvest/regrow/destroy writers. ResourceID is the extracted output's compiled ItemDefinition ID for wood/stone/iron. The generic store only validates range; same-file catalog membership belongs to RESOURCE-NODES-SAVED-BINDINGS. Preserve the already-correct main header. Correct only resource_id_of()'s stale "unstated domain" phrase and the old unit test's corresponding domain comments; arbitrary generic fixture IDs are not published catalog identity.

Owner13 resource_nodes, version1 (separate section1 owner is version2), primary4096, no children, fieldbegin255/count10:

|Ordinal|Field|Type/count|
|---|---|---|
|0|_present|u8/4096|
|1|_resource_id|i32/4096|
|2|_quantity_milli|i64/4096|
|3|_capacity_milli|i64/4096|
|4|_regrow_days|i32/4096|
|5|_planted_day|i32/4096|
|6|_exhausted|u8/4096|
|7|_tile|i32/4096|
|8|_ref_slot|i32/4096|
|9|_ref_generation|i32/4096|

Valuebytes172032, payload172116, block172154, offset9550427. All framing/versions/keys/types/counts unchanged. Every physical row checked, no living256 cap. Present row references use global Directory capacity352418, not typed ResourceNodes4096, Transforms87552 or Work typed refs. Tile bound16384. Positive int64 capacity includes INT64_MAX; never convert to float or compute capacity+quantity. Independently valid day/regrow extrema remain legal even if the later runtime due-date operation refuses OVERFLOW.

## Static predicate and fixed priority

Add static ResourceNodes.columns_refusal(present, resource_id, quantity_milli, capacity_milli, regrow_days, planted_day, exhausted, tile, ref_slot, ref_generation) -> StringName, with explicit PackedByteArray at0/6, PackedInt64Array at2/3, PackedInt32Array at1/4/5/7/8/9. All arguments frozen synchronously. Each gate scans the whole image before any later gate. Codes below gain constants REFUSE_ plus exact code:

1. All10exact4096 shapes before indexing: COLUMN_SHAPE.
2. present0..1: COLUMN_PRESENT_FLAG.
3. exhausted0..1: COLUMN_EXHAUSTED_FLAG.
4. all resource_id>=0: COLUMN_RESOURCE_ID.
5. all quantity_milli>=0: COLUMN_QUANTITY.
6. all capacity_milli>=0: COLUMN_CAPACITY.
7. all regrow_days>=0: COLUMN_REGROW_DAYS.
8. all planted_day>=0: COLUMN_PLANTED_DAY.
9. all quantity<=capacity and present requires capacity>0: COLUMN_STOCK.
10. present requires planted_day>=MIN_CALENDAR_DAY: COLUMN_PRESENT_DAY.
11. present exhausted exactly iff quantity==0: COLUMN_EXHAUSTION.
12. present tile0..TILE_COUNT-1; inactive tile exactly NO_NODE: COLUMN_TILE.
13. present refslot0..EntityDirectory.DIRECTORY_CAPACITY-1 with generation>0; inactive exactly(-1,0): COLUMN_REF.
14. inactive quantity0 and exhausted0: COLUMN_INACTIVE.
15. Existing REFUSE_NONE success.

Inactive resourceID/capacity/regrow/planted_day retain any independently nonnegative values, including zero/positive mixtures; do not impose allzero or reachable-tuple reconstruction. Separate stock gate quantity<=capacity applies allrows. No local unique-tile/ref rejection; duplicate valid scalar rows pass locally but cannot pass required same-file inverse/Directory checks. No constructor, live lookup, callbacks, catalog access, diagnostics write, normalization, default projection, packed duplicate/sort/scratch or range Array. After the flag gates, present means exactly present[row] == 1; inactive means present[row] != 1. The exhaustion relation is (exhausted[row] == 1) == (quantity_milli[row] == 0). These comparisons preserve the intended bool meaning and permit isolated flag-gate witnesses. Private static helpers may divide gates to respect style; keep exact global gate priority. No ordinary method behavior, section1 API/diagnostic, reader, scratch capacity or persistence shape changes. No new live wrapper or bulk API.

## Framed bridge and budget

New save_owner_resource_nodes.gd, only public static framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal. Preload ResourceNodes, Schema, Section, SaveHeader only. Gates: null->SAVE_COMPONENT_SHAPE; wrongowner13->SAVE_COMPONENT_OWNER; Schema.schema_refusal unchanged; exact owner/field/source metadata->SAVE_COMPONENT_METADATA; Section.owner_shape_refusal unchanged;10explicit canonical typed accessors; raw columns_refusal code. Success emptycode/detail. Metadata prefix exactly `ResourceNodes owner13 metadata:`. Column detail includes `ResourceNodes owner 13 ` plus exact code and no row identity.

Pin key/version1/primary4096/children0/10fields and allkeys/types/counts. Source pins: ResourceNodes.RESOURCE_NODE_CAPACITY4096, MAP_TILES_X/Z128, TILE_COUNT16384, MIN_CALENDAR_DAY1, NO_NODE-1, NULL_REF(-1,0), ResourceNodes.EntityDirectory.DIRECTORY_CAPACITY352418 and NULL_SLOT-1/NULL_GENERATION0. Constant chains construct nothing. Source mismatch refuses before reading columns. No new const Array/publication table; independent generator/source-capacity checks remain required.

Caller172032packed bytes already covered by stream6417408; no extra packed scratch. Native/wrapper overhead unmeasured. Proposed preload closure20nodes has only the3existing self-preloads; actual engine import required. An actual existing i64_column/set_i64 probe passed12assertions/0, retaining separate exact values above2^53 and INT64_MAX; existing supported self-preloads must not be misreported as new cycles.

## Parent evidence and fault detection

Every10field empty/short/long shape, canonical defaults, raw-zero refusal, null/wrongowner/malformed typed buckets. Domain endpoints and signed extrema in every applicable column; physicaltail4095, tile16383/16384, ref352417/352418, generation0/1/INT32_MAX and malformed null halves. All4096positions across all10columns must have an executable value witness; representative endpoints use present/free/retained-history fixtures. Presentstock full/partial/exhausted; regrow0; inactive retained numeric extremes/mixedzero; no calendar sum-fit; localduplicateacceptance explicitly scoped. Full input equality before/after every primitive/bridge refusal/success. Paired faults on different rows prove global priority.

Actual public history probe passed24assertions/0 with clean shutdown. Parent regression repeats create/partial harvest/exhaust/regrow/destroy and public reader observations, including >2^53 and INT64_MAX, OVERFLOW, unchanged plantingdate and section1 diagnostics/count/readers. No public all-column capture exists: construct present fixtures from public readers and source-owned inactive expected tuples; do not claim inactive private-column capture or add a getter. Existing ordinary ResourceNodes suite remains full-run coverage. Correct its stale comments only.

Required executable mutants30:10zero-accessor substitutions;17clause omissions (presentflag, exhaustedflag, resourceID, quantitynonnegative, capacitynonnegative, regrownonnegative, plantednonnegative, quantity<=capacity, presentcapacitypositive, presentdaypositive, exhaustionrelation, presenttilebound, inactivetilesentinel, presentrefdomain, inactiverefnull, inactivequantityzero, inactiveexhaustedzero);3order reversals (shape behind presentflag with safe indexing, quantity behind capacity, tile behind ref). Clause witnesses must isolate each omission so later gates do not mask it: e.g. negativequantity on inactive row also hits inactive gate, so use presentrow; capacitynegative needs other gates considered. The capacity-nonnegative clause is redundant for acceptance because quantity>=0 plus quantity<=capacity already excludes a negative capacity. Its required mutant is an exact-code-identity witness: capacity-1 must return COLUMN_CAPACITY, whereas omission reaches COLUMN_STOCK. This is a real assertion kill, never described as malformed data becoming accepted. Other witnesses may also fail exact-code priority; no assertion-count total is proof of distinct acceptance cases. All expected suites must run, fail real assertions with nonzeroexit, and contain no parser/script errors. Baseline/restored controls pass.

Metadata plan in evidence defines8faults+8bypasses+positive+schemaforward=18cases/162assertions, each schema/shape-valid. Exact arithmetic must be re-derived before author acceptance.17staticchecks, capacity regeneration, import, focused/full tests, independent final source review and exact-head CI required before merge.

Author owns only resource_nodes.gd plus new save_owner_resource_nodes.gd via SHA-pinned bounded patch. Astra owns tests, tooling, registry category3, queue/docs/CI. No production intake before predecessor PR166 merged. RESOURCE-NODES-SAVED-BINDINGS must be explicit under section4 semantics: saved section1 inverse, Directory kind/typed-row/ref and unique placement in both directions, verified same-file catalog/output-ID membership. Bulk restoration/derived counts and common-file provenance remain other prerequisites. No first-playable/release claim changes.
