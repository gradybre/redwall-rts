# Transform component validation — TRANSFORMS-S4-VALIDATE-R01 v1

Date:2026-09-20. Accepted by Astra after two independent planning reviews and public history probe; ordinary settlement-scope implementation authorized under ADR0173. Local owner15 image validity, not full save acceptance or publication.

## Canonical fields and producer domain

Owner15 `transforms`, version1, primary87552, no child extents, nine i32[87552] fields in exact order: `_bound_persistent_id`, `_x`, `_y`, `_z`, `_yaw`, `_prev_x`, `_prev_y`, `_prev_z`, `_prev_yaw`. Values3151872bytes, payload3151948, block3151982. Schema and registry versions remain unchanged.

All eight pose fields admit every signed int32 value at any positively bound row. Preserve arbitrary signed yaw, differing current/previous, all elevations and coordinates; no current map, normalized yaw, speed or movement-domain checks. Stale positive bindings are reachable after Directory destruction and stay canonical until normal replacement/unbind/reset. Never require every positive stamp to name a currently live Directory entity. Zero binding requires eight exact zero poses. Positive binding IDs are unique among all87552rows; repeated zero is legal. Directory persistent IDs are never reused in a valid world, and each positioned entity has exactly one derived row. No current Directory object is consulted.

`state_bytes()` is an existing diagnostic with stamp LAST; canonical schema is stamp FIRST. Do not change diagnostic order. Test fixture conversion must explicitly map that order, never assume it matches the save.

## Pure predicate

Add `static func columns_refusal(bound_persistent_id: PackedInt32Array, x: PackedInt32Array, y: PackedInt32Array, z: PackedInt32Array, yaw: PackedInt32Array, prev_x: PackedInt32Array, prev_y: PackedInt32Array, prev_z: PackedInt32Array, prev_yaw: PackedInt32Array) -> StringName` to transforms.gd.

Every gate completes globally before the next:
1. All nine exact extents87552 -> REFUSE_COLUMN_SHAPE / COLUMN_SHAPE.
2. Every binding ID nonnegative -> REFUSE_COLUMN_BINDING_ID / COLUMN_BINDING_ID.
3. Duplicate-and-sort one copy of binding IDs; reject any repeated positive value -> REFUSE_COLUMN_BINDING_DUPLICATE / COLUMN_BINDING_DUPLICATE. Repeated zeros ignored. Negative values already refused. Temporary copy local to a helper; no retaining it or sorting caller data.
4. Every zero-binding row's eight pose values are0 -> REFUSE_COLUMN_FREE_ROW / COLUMN_FREE_ROW. A simple bounded scan or find(0,from) increasing scan is permitted.
5. Existing REFUSE_NONE on success.

No owner/Directory instance, live store access, callback, I/O, reflection, new resident column, diagnostic mutation or repair. No range Array or other scratch than the one binding copy. All ordinary gameplay methods, state_bytes, reset/unbind semantics and existing public refusal state are unchanged. No shared inactive helper is required because no prior inactive reader exists.

One framed image3151872 plus one binding scratch350208 =3502080logical packed bytes; even with three65536stream windows3698688 is below current stream maximum6417408. Caller freezes its record; typed accessors share COW buffers, and only binding duplicate is mutated. Native/wrapper overhead remains unmeasured. No new resident allocation row, no second world. Parent records arithmetic, not measured peak.

## Bridge

New save_owner_transforms.gd with only public static framed_refusal(record:Section.FramedOwner)->SaveHeader.Refusal. Preloads Transforms,Schema,Section,SaveHeader only. Null -> SAVE_COMPONENT_SHAPE; wrongowner!=15 -> SAVE_COMPONENT_OWNER; Schema.schema_refusal unchanged; exactmetadata -> SAVE_COMPONENT_METADATA; Section.owner_shape_refusal unchanged; nine explicit i32 accessors in canonical order; predicate rawCOLUMNcode. Success empty code/detail. No live owner construction or canonical projection.

Pin metadata ownerkey/version/primary87552/zerochildren/fieldcount9 and all9 exactfieldkeys/typeI32/count87552 with scalar constants. Cross-check Transforms.TRANSFORM_CAPACITY87552. No publication-table parity claim or new constArray. Gate4 detail begins exactly `Transforms owner15 metadata:`; rawcolumn detail names `Transforms owner 15 ` and exactcode, no rowidentity. Schema gate detail is not rewritten.

## Documentation and downstream constraints

Correct only the persistence registry Previous pose note and its canonical JSON copy: all eight canonical current/previous fields remain exact across load/digests/publication; first-frame previous=current is a presentation override only. ARCH-HASH-001 includes canonical history and excludes overrides; ARCH-SAVE-004 verifies incoming and installed digests. No canonical mutation after either verification.

Local success does not establish the named TRANSFORMS-SAVED-IDENTITY obligation: all positive saved stamps must be below the saved section1 Directory cursor, and same-file saved Directory identity/typed-row associations must be reconciled without rejecting legitimate stale stamps or consulting live state. That coupled contract, fullfile provenance and coordinator invocation remain incomplete. bound_count is category2 count of nonzero stored stamps, not count of currently live matches; bulk capture/apply/rebuild remains a separate owner-binding task.

## Acceptance

Parent tests every9 empty/short/long extent, null/wrongowner/bucket mismatches, negativebinding−1/INT32_MIN, positive1/INT32_MAX, duplicates at distant/boundary rows, repeated0legal, all87552uniquepositivebindingsvalid, globalfirstrefusal precedence, each8pose field's nonzero residue at first/last/positioned-kind boundary rows, signedpose/yaw extrema, distinctcurrent/previous, fullinputnonmutation and exactrawdiagnostics. Replay actual public history from source probe, explicitly remapping diagnostic stamp-last order into canonical inputs, and prove predicate calls leave existing liveownerrefusal/count/digest unchanged. A zero frame is a valid empty Transform image.

Required actual assertion-killed mutants:9 correctly sized allzero accessor substitutions; omitbindingdomain; omitduplicatecheck; omitfreecheck; checkfreebeforeduplicate; checkduplicatebeforebindingdomain. Binding substitution has two explicit witnesses: negativebinding−1/allposes0 changes COLUMN_BINDING_ID tosuccess; positivebinding1/nonzeropose changes success toCOLUMN_FREE_ROW. Both order mutants use paired faults: negativebinding plus repeatedpositive17, and repeatedpositive17 plus a different zero-boundrow with nonzeropose. Pose-field swaps are equivalent for these symmetric validation rules and must not be falsely reported as killed; exact mapping is source reviewed. Test failures must be assertions with expected suite count, never parse errors.

Real-engine schema-valid ownerkey/version/primary/childextent/fieldcount/fieldkey/type/count faults, gate4distinctprefix, exactschemaforwarding and8comparison bypasses. Balance schema metadata in disposable clones; do not change production format. Import/static gates, focused/full suite, independent source review and exact-head CI precede merge.

Author owns only transforms.gd and new bridge via bounded SHA-pinned patch. Parent owns tests/mutation tooling/classification/registrynote/capacitysidecar/queue/docs/CI. Full section4 remains incomplete.
