# ResourceNodes metadata fault plan

Owner13 resource_nodes version1, primary4096, zero children, fieldbegin255/count10. Values172032, payload172116, block172154, offset9550427; owner14offset9722581. All10fields4096: u8,i32,i64,i64,i32,i32,u8,i32,i32,i32.

Eight coherent schema faults and matching guard bypasses, with positive control and unchanged schema forwarding:18cases/162assertions. Every fault must first pass actual Schema.schema_refusal and Section.owner_shape_refusal. Baseline record13 must fill tile field7/refslot field8 with literal-1; other values0. Allzero frame is semantically invalid.

1. key resource_nodes -> resource_nodet, same14ASCII bytes, remains sorted between residents/schedule.
2. version13 1->2, distinct from separate section1's already2.
3. primary13 4096->4097 and owner14 512->511; total unchanged.
4. Move child extent from10 to13: count10=0/count13=1, childbegins11..13=4; payload/block10-8/13+8, offsets11..13-8, owner14 onward unchanged.
5. Append Schedule's first u8[512] descriptor (global265) after all10ResourceNodes fields: fieldcount13=11/14=5, begin14=266; descriptor order unchanged; transfer520bytes (512values+8count) from14 to13, payload/block13+520/14-520, offset14+520. All10pinned fields remain first so countguard bypass is isolated.
6. fieldkey global255 -> _changed.
7. fieldtype global255 u8->i32, delta12288=4096*(4-1); payload/block13+delta, offsets14..17+delta, both SECTION_BYTES/EXPECTED_SECTION_BYTES+delta.
8. extent global2554096->4097, delta1; same later-offset/section changes.

Source constants must pin RESOURCE_NODE_CAPACITY4096, MAP_TILES_X/Z128, TILE_COUNT16384, MIN_CALENDAR_DAY1, NO_NODE-1, NULL_REF(-1,0), EntityDirectory.DIRECTORY_CAPACITY352418 and NULL_SLOT-1/NULL_GENERATION0. Source proofs, schema generator and capacity audit remain independent; no new immutable table claim or source mutation required for this eight-fault metadata matrix.
