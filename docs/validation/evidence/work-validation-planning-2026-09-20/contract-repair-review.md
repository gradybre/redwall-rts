# Work owner16 contract repair confirmation — draft2

2026-09-20. Bounded independent recheck of the three review-B1/C items only. No production
edit, no run, no acceptance of the wider slice.

## B1 — closed

The compiled `OWNER_VERSIONS[16]` is 2, and owner index 16 is `work`. Draft2 pins version 2
and `metadata-fault-plan.md` now mutates 2 to 3, so the metadata fault is a real change rather
than a no-op. The earlier version-1 claim is superseded. Nothing else in the block moved:
key `work`, primary 512, no children, field begin 280 / count 9.

## C1 — closed

`save_section_component_columns.gd` already publishes `u8_column()` and `set_u8()`, and
`_column_shape_refusal()` tallies and extent-checks the u8 bucket alongside i32 and i64. The
`priorities` bridge consumes four u8 ordinals today, so field8 is not a first-of-kind path.
The supplied probe sets and reads field8, accepts a valid shape and refuses a 511-byte extent.
No Section change is implied, so the author's two-file scope holds.

## C2 — closed

The memory-extent omission is killed by calling `Work.columns_refusal` directly with a
wrong-length memory column and otherwise valid columns; the bridge cannot witness it because
Section shape runs first. Stated that way in the contract. The correctly sized memory-zero
substitution stays excluded as semantically equivalent, with source review in its place.

## C3 — closed as far as it can be

The chained-constant probe reports 20 assertions and 0 failures across owner key/version/
primary/field count and every requested Work, Gear, Inventory, Jobs and Directory constant.
That is evidence for the pins, not for the registry: the independent schema-generator and
source-capacity audits remain required after any edit.

## Re-derived, unchanged

Value bytes 9728*4 + 512 = 39424; payload 39500; block 39528; 12892567 + 39528 = 12932095.
Mutant census still 21. Corrected multiline preload scan: 22 nodes, three pre-existing
self-loops (IntMath, SaveCodec, SaveSectionComponentColumns), none touching the new root.

## Outstanding, not contract blockers

Engine import of the not-yet-written bridge; the generator/capacity audit above; the probe's
28 objects and 5 resources at shutdown, which is not a clean-teardown claim. No new blocker.
