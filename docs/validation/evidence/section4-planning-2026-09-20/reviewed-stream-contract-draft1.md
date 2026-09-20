# Section4 streaming envelope — SAVE-S4-STREAM-R01 draft1

Date2026-09-20. Proposed bounded subtask SAVE-S4-STREAM; parent SAVE-S4-CODEC remains incomplete until18owner semantic contracts and production adapters are complete. This contract must pass independent review before author dispatch. No owner/gameplay normalization is authorized.

## Format and authority

SAVE-LAYOUT-R01 and REG-R01 own column-major framing. Registry6 section4schema2 has18owners/298fields. Use exact keys/types/versions/order from canonical_state_registry.json and its checked-in CanonicalStateHash generated table; runtime never reads JSON. The source-proved count census and proposed-layout.json in section4-planning evidence enumerate every field. Freeze first implemented body at schema2; there is no prior section4codec or emitted fixture to reinterpret. Changes after this freeze require normal compatibility revision.

section = store_count:u32=18 followed by18owner blocks in ASCII order.
owner = key:utf8-u32, owner_schema_version:u32, primary_count:u64, payload_length:u64, payload.
payload = child_extent_count:u32, fixed child extents:u64[], then for each registered field: element_count:u64, values in LE declared signedness.

All primary and child extents are compiled EXACT values, never constructor arguments or inferred from incoming columns. All298columns persist their full physical lengths. No unused-row zeroing, compaction, rebuilding or guessed normalization.

| Owner | Primary | Independent child extents |
|---|---:|---|
| buildings |1024|16384rooms,81920furniture|
| construction |82944|none|
| farming |4096|none|
| field_policy |128|4096plots|
| fishing |32|none; stockstride3|
| forage |128|none; patchstride5|
| injury |512|none|
| jobs |8192|512agents|
| movement |512|none|
| needs |512|none; needstride5|
| orchard_hive |1024|1024hives|
| priorities |512|none; jobkindstride12|
| residents |512|none; skillstride12|
| resource_nodes |4096|none|
| schedule |512|none; hourstride24|
| transforms |87552|none|
| work |512|none; skillstride12|
| world_init |384|none|

FieldPolicy rotation stride3 is independent of its4096plot child table. All eight stride relations in the census are fixed. Equal orchard/hive capacities still declare two independent tables. Primarycounts sum193184 is section4descriptor row_count by explicit SAVE-LAYOUT-R01; it is not an entity count.

Totals:12944480valuebytes;12947565sectionbytes;298field count prefixes; five independent child extent entries;72bytes child-count headers+40extentbytes above ordinary-column census. Owner schemas are SECTION4versions; Fishing's section7schema2 and Buildings/Forage section1primarycounts must not leak here. Buildings reference/chain columns already belong tosection5; no fields are added/moved.

## Exact new interface proposal

Production files: `save_component_columns_schema.gd` (metadata), `save_section_component_columns.gd` (stream), no owner-module writes. Preload SaveCodec, SaveHeader, CanonicalStateHash only; no live stores. New metadata must have deterministic source/registry parity checks and exact logical allocation accounting; native overhead remains separate.

Schema exports static:
`owner_key(owner:int)->String`, `owner_version(owner:int)->int`, `primary_count(owner:int)->int`, `child_extent_count(owner:int)->int`, `child_extent(owner:int,child:int)->int`, `field_count(owner:int)->int`, `field_key(owner:int,field:int)->String`, `field_type(owner:int,field:int)->int`, `element_count(owner:int,field:int)->int`, `field_width(owner:int,field:int)->int`, `payload_bytes(owner:int)->int`, `owner_block_bytes(owner:int)->int`, `owner_offset(owner:int)->int`, `field_count_offset(owner:int,field:int)->int`, `field_value_offset(owner:int,field:int)->int`, `schema_refusal()->SaveHeader.Refusal`.
Offsets are relative to section start. Invalid metadata indices return explicit neutral lookup values (emptyString or0); stream APIs validate owner/field indices before calling them. No neutral lookup value itself proves a valid field. Constants STORE_COUNT18,FIELD_COUNT298,SECTION_SCHEMA_VERSION2,SECTION_BYTES12947565,DESCRIPTOR_ROW_COUNT193184,CHUNK_BYTES65536.

`FramedOwner.new(owner:int)` owns typed Array[PackedByteArray],Array[PackedInt32Array],Array[PackedInt64Array] in field-type storage order, with every field at its exact count. Invalidowner produces owner=-1 and no arrays. Exposes owner:int; `u8_column(field)`, `i32_column(field)`, `i64_column(field)` return corresponding stored arrays or empty if mismatched. `set_u8/set_i32/set_i64(field,values)->bool` validates ordinal/type/exactextent then duplicates that ONEcolumn; refused setter changes nothing. These records carry arbitrary wire-representable values; constructor zeros are not semantic defaults. i32 signed only, i64 signed only, u8 full0..255; any unexpected type in compiledsection4decl refuses schema. No u64/u32 field exists here.
`owner_shape_refusal(record:FramedOwner)->SaveHeader.Refusal` validates owner/allstoragearraycounts/eachfieldtypeextent, with no gameplay checks.

`Chunk` owns bytes:PackedByteArray, code:StringName,detail:String; `is_ok()->bool`. Any refused output clears bytes; successful output clears diagnostics. Outputbytes at most65536.
`OwnerResult` owns record:FramedOwner=null,code/detail and `is_ok`. Refusal clears record; success clears diagnostics. No caller record is overwritten on decode refusal.

`EncodeCursor.new(section_schema:int, descriptor_rows:int)`:
- Preflight exact schema,descriptorrows and compiled metadata. Store firstrefusal sticky. Starts at section prefix, no ownerbound, offset0.
- `needs_owner()->bool`: true only after store_count emitted or previousowner finished and anotherownerrequired.
- `owner_index()->int`: expected0..17,18afterall.
- `bind_owner(record)->SaveHeader.Refusal`: only when needs_owner; exact expectedowner plus fullshapecheck before storing borrowedrecord. Failure is sticky. Caller freezes record for entire bound emission; no snapshotcopy or livestorecapture here.
- `has_more()->bool`: true until section drained, including awaitingowner; false onfailure.
- `next_chunk_into(out:Chunk)->bool`: emits store_count4; owner wrapper WITH childheader+extents as onefixedsmallchunk; fieldcount8; then valuechunks of wholeelements max65536 in ascendingphysicalindex. No chunk crossesfield. Refuses called awaitingowner or aftercomplete with explicit STATE code; never silently skips owner.
- At owner end clear borrowedrecord and requestnextowner. Each metadata transition is deterministic; no Array of18owners. `emitted_bytes()->int` counts accepted output and ends exactly SECTION_BYTES. `refusal()->SaveHeader.Refusal` reveals the first sticky error.
- Value conversion uses existing bulk packed conversions only after LE host probe. Conversion scratch is bounded by the conservative transient budget below; no field/owner/section concat helper in production.

`DecodeCursor.new(section_schema:int, descriptor_rows:int, section_byte_length:int)`:
- Preflight exactschema,rows,length,compiledmetadata BEFORE creating any FramedOwner. Firstrefusal sticky. Offset0, no record.
- `next_read_size()->int`: exact nextrequiredfragmentlength, always1..65536 whileinputneeded;0on ownerready/completed/failed. Same deterministic boundaries as encoder. Disk caller reads EXACT this many bytes; arbitrary I/O chunking must be assembled in a <=65536callerwindow outside thiscodec. No source/file callbacks here.
- `accept_chunk(bytes:PackedByteArray)->SaveHeader.Refusal`: requires sizeexactlynext_read_size; over/short/zerochunks refuse before changing cursor or privatecolumns. Never retains callerbytes. Fixedframing compared byte-for-byte to compiled expected bytes (including keylength/key/schema/counts/length/extents). Only supported canonical framing accepted; hostile counts cannot control allocation. After accepted ownerheader allocate at mostthatowner's typedcolumns. Fieldcounts checked beforevalues. Value chunks copied/converted into exact privatefieldpositions; preserve int32/int64two's-complement and u8bits verbatim. No meaning inferred from occupancy or negativevalues.
- `owner_ready()->bool`: true only once everyfield ofcurrentownercompleted; no moreinput until `take_owner_into(out:OwnerResult)->bool` transfers completedrecord by reference, clearsprivateowner, advancesexpectedowner. Transfer doesnotcopy or validateworld semantics. On failure/earlytake outputrefuses without exposingpartialrecord; stickyerror. Caller may retain at mostone completedowner during production; persist/release before feedingnextowner. This lifetime is coordinator contract, not enforced through weakref magic.
- `consumed_bytes()->int` countsacceptedinput; `is_complete()->bool` true only after finalowner transferred ANDconsumed==SECTION_BYTES. `finish()->SaveHeader.Refusal` succeeds only in thatstate, otherwise stickyTRUNCATED orpriorfailure. Extra acceptaftercompletion refusesSTATE; sectionlength mismatch already refusedconstructor. Externalfile range/EOF,CRC/headerdigest are coordinator obligations.
- Allfailurepaths dropprivatepartialrecord, preserve consumedoffset atlastacceptedchunk, retainfirsterror, and never mutate callerinput or a previouslytransferredrecord. `refusal()->SaveHeader.Refusal` revealscurrentstickyerror (emptycode ifhealthy). No reset/reuse; newcursorfornewattempt.

Codes (StringName): SAVE_COMPONENT_SCHEMA, SAVE_COMPONENT_DESCRIPTOR, SAVE_COMPONENT_LENGTH, SAVE_COMPONENT_METADATA, SAVE_COMPONENT_OWNER, SAVE_COMPONENT_SHAPE, SAVE_COMPONENT_FRAME, SAVE_COMPONENT_CHUNK, SAVE_COMPONENT_STATE, SAVE_COMPONENT_TRUNCATED, SAVE_COMPONENT_BYTE_ORDER. Deterministicpreflightorder schema,rows,length(decode),metadata,byteorder; then state/size/framing. Detailmust identifyowner/field/offset whereapplicable; successempty. Nulloutputs mustrefuse safely (cursor'sstickySTATE), no dereference. Setter falsehasnoerrorchannel byexplicitcontract.

## Memory and activation

Atmostone privateFramedOwner: maximumconstruction4893696valuebytes. Caller chunk65536 plus two conversion windows65536 each. Conservatively also charge TWO largest field copies (2*663552=1327104bytes) for copy-on-write/reallocation during private column assembly; implementation must explain actual lifetimes and remain below this bound. No second full owner copy. Total private owner plus conservative transient payload=6417408bytes before metadata/native overhead. Framingworstbounded<256bytes; metadatafixed and separatelyaccounted. GDScriptreference/nativeoverhead notcertified. Decoder must not duplicate a full record atpublication or instantiate liveowners. Droppingpartialrecord is safe because itwasneverpublished. Encode borrows onecallerrecord, andcallerholdscompletedboundary/loadbarrieroutsidecodec. No signals, callbacks, canonicalhash, clocks, cleanup, barrierrelease or filesystemwrites.

The cold-phase memory calculations inparent-memory-and-interface-notes.md are candidate lifetime schedules, not a100MBqualification. No whole-sectionrecord/wirebuffer inproduction. FramedOwner is not semanticallyvalid, and users ofthisAPI mustnotpublish itto a liveworld before allsemantic/cross-section/digestvalidation succeeds ininactivecheckpoint. No boolean 'validated' token impliescommonfileorigin.

## Acceptance

Parenttests must independently build bytes usingliteralframing/schema fixtures; no test may derive everyexpectedconstantfrom implementationunder test. Crosscheckall298keys/types/versions/extents withregistryandcapacitycensus. Pinwhole-sectionSHA256fornon-symmetricboundarypatterns with negativei32/i64,INT32MIN/MAX,INT64MIN/MAXandnonbooleanu8. Pinsparse/chosenoffsets including eachownerboundary and mixedtables. No semanticacceptance inferred.

Streamencode→streamdecode at exactrequestedfragments, compareeverycolumn/owner, assertlargestchunk65536, totalbytes12947565 androwcount193184. Reuseoneinputwindow, releaseeachowner; testnodecoding whileownerready. Takeoneowner, then corruptlaterheader: earlierrecordunchanged andno partiallaterrecordexposed. Calleroutput/inputimmutabilityonrefusals. Encoderwrongowner/null/shape/sequence; decoderoldschema/wrongrows/length,wrongstorecount,key/order/owner schema,primary/childcount/childextent/payloadlength/fieldcount,short/long/emptychunk,finishearly/extraafterEOF. Testhighbits/hugehostilelengthbytes andwrongmetadata beforeallocation. Hostbyteorderprobe mustfailclosed usingexistingpattern.

Mutationtargets: omit childextentcomparison; omit exactpayloadlength comparison; swap two equalwidth columns; allow wrongownerorder; publish partialdecodedowner; drop sectionlengthpreflight. Eachmustbe killedbymeaningfulassertions, notparsererrors. Fullsuite/staticchecks/import andindependentsourcereviewrequiredbeforemerge.

## Follow-through required before parent completion

SAVE-S4-CODEC staysincomplete afterthisstreamsubtask. Namedsubsequentscope:18owner semanticvalidators (includingretainedunusedbytes),15missingbulkAPIs, exactcapture/apply adapters, Jobs4+5 andBuildings4+5atomicity, Resident4+14nameagreement, savedDirectorymatching andclaimprojectionbinding, ownercanonical adapters. Section5/otherbodies/coordinator/diskrollback/fullsavecontinuationremainseparateexplicitdependencies. No whole-save flag or first-playablemilestone changes.
