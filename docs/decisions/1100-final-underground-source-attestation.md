# 1100 — Final actual underground source attestation

2026-10-03. Bounded correctness implementation; does not qualify first entry,
worker contact, navigation, profiles or a physical construction action.

## Problem and decision

The completed-passage work-face observation in 1099 first takes a complete
Space snapshot, then invokes actual endpoint/source observations. A final
Location observation can change a real Building's placement facts without a
Space geometry publication. Repeating the ordinary snapshot freshness call
invokes the same Source/ResidentLocations observation boundaries again, so it
cannot be the last callback-free attestation.

`underground_final_facts.gd` is a stateless typed bridge. After every external
observation, `snapshot_refusal(owner, routes, locations, expected_revision,
max_checks)` compares all present stored source facts and all long-lived
claims to actual current owners. The exact actual Directory, World, immutable
Domain, CoreSources, Buildings, Construction, Residents, Transforms, Routes,
Locations and shared Budget wiring are mandatory. Pending geometry/topology or
endpoint preparation and reentrant validation refuse.

CoreSources retains its ordinary Resident observer for normal source reads.
Its static `read_leaf_into` dispatches the same existing World, Building, Room,
Furniture and Construction schemas directly. Resident final facts instead
compare the actual full Resident identity, bound Transform, committed actor,
containing Room/section and complete endpoint or occupied span generation and
integer progress. This does not call public Sources/ResidentLocations/actor/
endpoint/span observation methods. It adds neither a location fallback nor a
new profile/traversal permission. Full Room and Construction claim identities
retain their existing rules; no claim markers are omitted here.

`record_matches(actual_locations, full_location, expected_record, actual_owner)`
compares every field of the current immutable endpoint, including both
six-integer boxes, full Room/section identity, World, level, role and both
revisions. It observes packed storage directly and writes no output. Matching
an endpoint alone does not validate all source facts or grant clearance.
Consumers must perform both final checks after their public observations, then
finish with their own callback-free Terrain/request/profile/lease pins. A
later arbitrary callback invalidates the ordering guarantee.

## Bounded work and memory

There are no new retained fields, arrays, snapshots, counters, saved fields or
canonical ordinals. The existing Facts, Room identity and Transform Pose
scratch are reused. Actual getter results remain short-lived native objects;
this is not a claim that every leaf transitively allocates nothing.

Before reading any leaf, the helper admits 128 fixed binding checks, two full
capacity scans `2*(R+O)`,64 checks per present nonresident source or claim, and
256 per Resident source. The first scan counts these exact live costs; the
second verifies them. Invalid and unaffordable work refuses before reading
source leaves. These are conservative source-counted logical operation units,
not CPU-time measurements. Resident allowance includes bounded integer
segment-length/interpolation work. The immutable Domain maximum remains
unchanged. At the actual R 6144/O 2048 pack, one World costs 16576 units; no
quadratic capacity product is introduced.

The maximum simultaneous logical helper frames fit 256 bytes. The largest
chain is the moving Resident's integer square-root branch:

| Simultaneously active frame | Numeric bytes |
|---|---:|
| Final query revision/work parameters | 16 |
| Source loop row and full ref | 16 |
| Resident full ref and typed row | 16 |
| Resident-location row, full endpoint and Room | 24 |
| Transit row, edge, segment, progress, two points and length | 64 |
| Existing segment-length parameters and scalar loop locals | 64 |
| Existing integer square-root parameter and locals | 48 |
| Total | 248 |

The alternate interpolation chain is 212 bytes. Building/Furniture leaves may
retain at most three existing OpResult numeric payloads (51 bytes), on a
separate shallower branch; these are not added to the Resident peak. Existing
Facts/Pose/Room scratch is already charged in its actual owner. The 256-byte
ceiling remains inside 1099's
existing 2048 fixed-control allowance (982 private packet plus 68 caller leave
998 for this and remaining leaf frames). Borrowed native references, existing
OpResult allocation headers and engine stack representation remain separately
obligated in the unchanged bindings/growth reserve. No native or whole-tick
performance qualification is asserted.

## Validation

The final clean assets-aside editor import followed by the strict focused
runner passed 149 tests /15296 assertions /0 failures: new FinalFacts 16/944,
existing Owner 88/5024 and Routes 45/9328. Both diagnostic and raw-log footers
report zero unexpected errors/warnings and zero object/resource leaks.
Analyzer reports `0 GDScript warning(s) in 0 of 3 file(s)` at the same source
hashes. Parent independently reviewed all three frozen files and accepted the
bounded source delta. Raw logs, exact source pins and a reproducer are in
`docs/validation/evidence/underground-final-facts-2026-10-03/`.

The actual 6144-region/2048-source pack is tested, including 256 real Resident
identities, with 82112 precharged checks at that occupancy. Generation reuse,
late actual Building mutation without a Space revision, every Location payload
field, idle and moving actor facts, incompatible preparation and exact work
budget refusal are covered. Component geometry and profile certificates remain
explicitly synthetic; no production permission or native performance is claimed.

An initial fixture parse refusal and incomplete fixture scratch/level run are
retained as rejected evidence. The latter exposed a real GDScript script-resource
cycle: qualifying calls inside CoreSources as `CoreSources.read_leaf_into` /
`CoreSources._building` retained 81 script/native-class objects and 23 resources
at shutdown, also reproduced by the unchanged Routes suite. Reverting the
refactor gave zero leaks. Keeping static dispatch but using unqualified internal
calls removed the cycle; external bridge calls stay explicitly static. The
final strict run retains the unchanged zero-leak gate. Do not reintroduce those
qualified self-class calls during stylistic cleanup.
