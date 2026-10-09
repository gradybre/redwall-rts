# 1150/1151 preparatory Room lifetime review

Date: 2026-10-04. Read-only source/census review by Geometry. No engine run,
foreign worktree write, capacity change or runtime qualification.

Root requested this bounded follow-up while Furnishing's 1150 implementation
was still moving. It is **not acceptance of the 1150 source**. The root tail is
the exact eleven-file `focused-2/source-sha256.json` packet in the integration
worktree; all eleven pins matched. The three 1151 sources retain their accepted
pins. `census.json` records every read input and verifies that those inputs did
not change during the read.

## Concrete draft omission

The first 1150 census listed the original survey, prospective WorkFace proof and
post-Sites claim stage, but omitted the larger actual Locations preparation
stage. The existing ADR1095 maximum for Locations is 919,936 bytes, before the
new retained path and witness. The draft maximum of 854,016 therefore was not
the complete ordinary Room lifetime.

Furnishing acknowledged this omission and is adding the explicit Locations and
WorldRoutes phases to its final census. Clearing `Face.Check.proof` releases the
327,680-byte source image and 49,152-byte fragment banks; it does **not** release
the Check's descriptors, endpoint records, Domain, requests or fixed boxes.
Those retained controls must be counted after that assignment.

## Exact retained numeric packet

The development snapshot contains 907 logical bytes in the retained Face.Check
after its proof is dropped:

- own scalar/vector fields: 31;
- original and private Face.Request: 2 × 68;
- one profile Descriptor: 184;
- two profile Boxes: 2 × 32;
- two Locations.Record packets with envelope/support arrays: 2 × 116;
- one Owner.Region with its box: 72;
- one separate Domain including bounds: 92;
- target, bounds, support and scratch six-I32 arrays: 96.

The additional Approach witness/request fields use 1,744 bytes: own scalars32,
derived Request fields84, three Descriptors552, access Record116, extra pins112,
profile boxes672, digest buffers96 and the existing RoomContext80. Neither the
variable path nor the old RoomPlan images are included in that subtotal. The
maximum path is 12,288 bytes, from 1,536 full edge references. No new RoomPlan
cell copy is added by the witness.

Furnishing chose to preserve Face's full existing 2,048-byte control allowance
after proof release. Its new 4,096-byte witness/helper allowance is separate.
The current Approach file's entire declared numeric function-frame sum is556,
even though most functions are sequential. Its final source census must also
close the exact borrowed foreign/helper chains before source acceptance. The
907-byte Face payload is not silently treated as freed or as native overhead.

## Complete conservative cold phases

The capacities remain N16,384 cells, R6,144 Space regions, O2,048 Space sources,
K8,192 Location fragments and 1,536 route edges. All phases use the same original
1,048,960-byte World lease. Sealed Space/Location/Route banks remain in their
existing separate live/stage reservations and are not copied into another cold
arena.

| Phase | Logical bytes |
|---|---:|
| Original terrain/history survey and interval map | 854,016 |
| Prospective WorkFace proof plus path and witness | 790,528 |
| Locations snapshot/fragments plus retained path/witness/Face | 938,368 |
| Sequential WorldRoutes proof plus retained path/witness/Face | 791,552 |
| Sites four cell images/cursor plus retained path/witness/Face and publication | 675,840 |

The corrected maximum is **938,368**, leaving **110,592** cold bytes. This is a
source-counted reservation, not measured native memory.

The post-Sites value uses the original Room/Sites 2,048-byte allowance exactly
once. `Sites.room_claim_cold_bytes` already includes that allowance; ADR1095's
812-byte fixed packet covers the Room plans, request/batch/cursor and other
original controls. Adding a second Room2,048 would be a conservative extra
cushion, not a second required allocation. RoomContext80 is charged once in the
new witness and is not added again to the old Room packet.

## Existing Room publication scratch

Construction's independently accepted root-tail census is 812 original packet
bytes +642 declared numeric frame bytes +128 expression/return allowance =
1,582/2,048. This review reproduces those exact source pins and adds154 declared
bytes for the retained Location/Routes/WorldRoutes static kernels and immutable
source checks. Adding the accepted FinalFacts own-chain160 and final concrete
CoreSources reader88 yields a conservative scoped **1,984/2,048** allowance.
This sums sequential publication kernels and alternative final-reader paths;
it is not a native call-stack measurement. The new Approach functions and
packets remain charged separately to its 4,096-byte allowance and retained
Face allowance. No global reservation is increased.

The packet does not duplicate the already completed transitive static-tail
correctness review. It does not qualify source profiles, actual approach
success, paid excavation or a playable Room confirmation. Those require the
frozen 1150 source and its exact composed evidence.

## Reproduction

Run from the ordinary-room-publication worktree, with no engine:

```sh
python3 -B docs/validation/evidence/underground-room-publication-2026-10-04/cold-lifetime-review-v1/census_review.py \
  --integration /Users/brendan/Developer/redwall-rts-codex-ug-integration \
  --approach /Users/brendan/Developer/redwall-rts-codex-ug-room-approach \
  --tail-review /Users/brendan/Developer/redwall-rts-codex-ug-haul-handling/docs/validation/evidence/underground-ordinary-room-publication-review-2026-10-04/review-v2
```

Because 1150 was not frozen, a later run may report new source pins or fail an
exact development-packet expectation; it must not overwrite the retained
`census.json` or relabel it as final-source evidence.
