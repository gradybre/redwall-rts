# Actual first-room frontier: physical review

Read-only review on 2026-10-04/05. The input root is integration commit
`ebdd5daa2b723a63dd71e2018d2bed9b279cf894`. No runtime source, profile,
World, paid state, cache or engine was changed. The copied 9,620-byte v3 wire
is byte-identical to `a581f90a…`; `input-sha256.json` records full pins.

## Test migrations

The two root-authored test migrations are accepted with no high/medium
finding. Session reload now advances `Catalog.CONTENT_REVISION + 1`, preserving
the stale-bank refusal. The old Room negative explicitly loads immutable v2
at revision1 with its original18/194 capacity; the positive SourceFixture
loads actual reviewed v3 and calls `Catalog.catalog_refusal`. It changes no
certificate flags and adds no successful override. Exact hashes:

- `test_underground_session.gd`: `a737e9ae1e414c96fbc62fff9663015640b7cd34be76bbac5b11e2b9634313f5`
- `test_underground_room_world_phases.gd`: `b12b36cb27be112dd1a6482690651ee73745ca6abef8dc0627df208071a4e1f6`

## Current blocker and source-derived next cuts

All coordinates below are relative to `(X,FLOOR,Z)=(122880,-4608,102400)`.
The existing Corridor is `[-4096,0,-2048 .. 2048,4096,4096]`, with its actual
floor/support and full Room identity. The Kitchen claim is2×2 metre cells,
4m high. The successful fixture has paid only `[2048,0,0 .. 3072,1024,1024]`.

The proposed deeper station `(2304,0,512)` is physically impossible at this
point. WORK24 recovery requires root Z in `[537,430]` to fit this single
cube; travel5/9 requires `[445,114]`. Both intervals are empty. The recovery
width is1,131u, the combined travel width1,355u. Travel's tool reaches1,036u;
WORK24's non-target stroke reaches1,169u. A new floor section cannot supply
the missing completed air. `inspect_frontier.py` retains the exact uncovered
slabs rather than treating the enclosing Room claim as void.

There is a concrete geometric progression. Each added cube below must finish
its own actual BRACE→CUT→FINISH, with original bills, WU, spoil, structural,
worker, source and final-publication checks. These are proposed contacts and
paid dependencies, not executed new cuts or permissions:

| Order | Target cube origin | Source / root | Required completed geometry |
|---|---|---|---|
| 1 | `(2048,0,0)` | existing FRONT24 / `(1280,0,512)` | existing Corridor; already demonstrated by the actual fixture |
| 2 | `(2048,0,1024)` | unchanged FRONT24 / `(1280,0,1536)` | old Corridor; no root in the first paid cube |
| 3 | `(2048,1024,0)` | unchanged HIGH23 / `(1512,0,512)` | both first-layer lower cubes |
| 4 | `(2048,1024,1024)` | unchanged HIGH23 / `(1512,0,1035)` | both first-layer lower cubes |
| 5 | `(3072,0,0)` | unchanged FRONT24 / `(2304,0,768)` | all four preceding cubes, plus actual floor/section publication |

The root at Z1035 is required by the unchanged high tip's `[-11,+128]` Z
span. An earlier arithmetic candidate using Z1024 incorrectly put11u of
stroke into the preceding upper cube; the rejected script/log are retained.
Full source bounds pass at1035. The useful high-work root-Z intervals after
widening are `[409,896]` for upper0 and `[1035,1376]` for upper1; these include
whole tip strokes, not just the contact anchor.

All four first-layer work roots remain in the existing **Corridor Room**.
The target Site belongs to **Kitchen**. Their full Room/Site/section identities
must stay distinct. Neither a fake Kitchen root Site nor invented paid history
is needed. Existing Locations ordinary scope resolves the actual root Site
identity, while actual SUPPORT/SUPPORTED_VOID prove the physical point.

## Mechanical route limitation

The lateral station's straight forward5 and backward9 sweeps from/to a local
gateway `(-1024,0,1536)` fit the existing corridor. That gateway is not an
existing certified edge or a substitute for the actual storage/retreat.
The current provider binds retreat `(-1024,0,512)` and one profile9. Every
segment of profile9 must head -X, so it cannot return laterally from Z1536.
The same issue applies to the new high-work and deeper contact offsets.

The bounded follow-on must prove a sequence of real directed legs, with
explicit profile handoffs at supported clear gateways, back to the original
full storage/retreat. For example, lateral locomotion and heading changes
occur around X=-1024 in the existing4m-high corridor; the all-yaw ground
envelope fits there. Source-clocked READY must survive the supported turn
and select the next exact cardinal programme. Current exact-heading actors
cannot use `turn_actor`, and converting to automatic mode currently cannot
claim READY when returning. That is an explicit canonical handoff/API task,
not a need to shrink the source mesh or grant an instant turn at the wall.

The Frontier's canonical X-fastest scan will encounter the blocked deeper
cube before the lateral one. Its existing `after_key` can support a bounded
search of further incomplete candidates; a failed contact never grants work
or marks the skipped Site complete. The selected new contact still needs
the complete real paid-phase checks.

## Source geometry limitation and the smaller source protocol

HIGH23's unchanged contact is536u forward, versus FRONT24's768u, so its root
must advance232u. At `(1512,0,512)`, the full current WALK5 tool crosses the
wall in `[2048,1024,694 .. 2244,1036,1422]`. Paying the two lower cubes does
not clear these12u of upper solid. The whole HIGH work programme itself
fits after lower widening; only arrival/retreat still fail.

A smaller protocol can use **unchanged supplied keys**. Independent complete
primitive/native-residual bounds for READY plus the first three emitted walk
ticks, including every admitted convex ready fade, are:

| Programme at +X | Body full primitive | Tool full primitive |
|---|---|---|
| forward prefix | `[-237,-1,-438 .. 394,926,476]` | `[127,379,185 .. 732,972,797]` |
| backward prefix | `[-234,-1,-438 .. 394,926,527]` | `[27,379,185 .. 732,966,881]` |

The retained full-walk negative body primitive
`[-249,-1,-239 .. 274,0,284]` and full stance
`[-249,-1,-274 .. 274,0,299]` remain separate complete obligations. The broad
full-body AABB's -1y minimum is not silently clipped into air or extruded
into an invented footprint. These larger existing floor/support primitives
already cover the proposed source subset and its fades.

The complete232u forward/back sweeps fit at both high roots after the two
lower cubes. At Z512, forward tool sweep is
`[1407,379,697 .. 2244,972,1309]`; backward is
`[1307,379,697 .. 2244,966,1393]`. At Z1035 their maxima are1832/1916,
still within the paid2048u width. Full translated body, foot and support
boxes are in `frontier-bounds.json`.

The actual small-Mole ground rate is3277u/s at30Hz. For every original
remainder0…29,232u takes exactly three accepted movement ticks. The new
protocol must constrain this exact phase/root/remainder coupling, both
directions, every pause/held/resume, all ready fades, and stop before a fourth
movement tick. Forward keys0…3 and backward0,32,31,30,29 (including the
one-Q16 loop seam) are a conservative complete enclosure; reverse3…0 is
wrong. Current full-cycle profiles cannot be relabelled with these bounds.

The smallest build packet is an additive finite READY→232u step→READY source
programme and its reverse, with two exact +X profile rows proposed for the
first case. The actor image, full body/tool meshes, Work HIGH/FRONT programmes,
integer ground rate and existing foot source stay unchanged. A later runtime
lease must add exact policy/clock admission and driver consumption; no
rendered-frame flag may decide phase readiness. Native replay and current
consumer publication are still required. No image allocation is added: two
7-box rows would cost `2*(2*98+14*28)=1176` paired Profile bytes; one original
Actor source digest can be reused. Protocol/helper/native controls are not
yet counted or admitted. Four-heading publication would instead cost4704
paired bytes and remains a separately counted choice.

This sequence reaches the next deeper ground cut. It does **not** prove the
entire4m-high Kitchen can be finished: later upper reach, lateral clearance,
service routing and any elevated access still require their own exact proof.

## Source evidence and reproduction

Relevant current source anchors:

- `test_underground_room_world_phases.gd:180` defines the real Corridor;
  `:376` defines the fine Kitchen claim; `:526` drives actual paid phases.
- `underground_work_face.gd:250` keeps body/stance/stroke separate;
  `:337` grants only the exact target a stroke exception; `:386` requires the
  complete contact patch.
- `underground_world_routes.gd:784` checks profile heading on every segment;
  `:823` checks complete swept roles; `:1736` keeps stationary turns all-yaw.
- `underground_room_world_bindings.gd:53` pins one retreat/profile;
  `:443` uses that exact profile for the whole return path.
- `underground_routes.gd:2204` refuses automatic→source-ready fabrication;
  `:3059` advances source time once per committed root tick.
- `underground_room_frontier.gd:77` selects canonical incomplete identity;
  `:336` derives contacts from the actual source point; the first-paid-cube
  missing-contact regression is `test_underground_room_frontier.gd:166`.

Run `python3 -B inspect_frontier.py` in this directory and compare its JSON
with `frontier-bounds.json`. The separate `inspect_short_gait.py` invocation
in `invocation.json` re-reads the exact accepted raw actor geometry, image
and numerical basis using bundled NumPy. It does not reconstruct or replace
the accepted source programmes, modify a certificate or run Godot. Its
proof scope is whole-primitive bounds; full source/foot/interruption/native
validation belongs to the proposed1164 packet.
