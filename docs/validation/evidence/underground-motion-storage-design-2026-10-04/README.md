# Joint source-motion storage proposal

Date: 2026-10-04. Geometry lane, read-only engineering preparation.
No runtime, compiler output, shared budget, registry, Profile, Level, World or
consumer source was changed by this packet. This is a proposed configuration,
not an adopted pace, source certificate or measured memory admission.

The complete 1139 gait and 1142 handoff tables can fit within the existing
262,144-byte `PROFILE_BYTES` reservation alongside the actual current Profiles
and LevelCatalog. A concrete paired proposal below totals **232,436 bytes**,
leaving **29,708 bytes** inside that reservation. It includes an explicit new
identity bank and proposed control ceilings. Implementation must prove those
ceilings before admission. The independent Profile maxima cannot coexist with
these motion banks and must refuse; their global definitions need not change.

## Exact inputs and reproduction

`census.json` contains all 26 file pins, observed checkout HEADs, decoded counts,
coordinate/identity checks, proposed field lists and arithmetic. The initial
census is retained separately; the final pass additionally decodes all three
actual ActorContent clip tables and numerical Domain headers. Every input was
rehashed after the read. No Godot/native process was run. The foreign checkout
HEAD advanced from the completed root checkpoint to its accepted integration
while this document was prepared; the pinned runtime source inputs did not
change.

```sh
MOTION_PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
"$MOTION_PY" -B docs/validation/evidence/underground-motion-storage-design-2026-10-04/census.py \
  --runtime /Users/brendan/Developer/redwall-rts-codex-ug-integration \
  --source /Users/brendan/Developer/redwall-rts-codex-ug-space \
  --out docs/validation/evidence/underground-motion-storage-design-2026-10-04/census.json --check
```

The check is an exact-input replay, including recorded checkout provenance.
For another accepted checkout, use a fresh output file and compare its source
pins explicitly. The Python script reads full source JSON offline; that is
not a proposed runtime allocation strategy.

| Source | Exact source digest or reference |
| --- | --- |
| Current 18-row profile wire | `b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac` |
| 1139 candidate-4 wire, 19,332 bytes | `c966b64608b0308cca2e54973aeb72dd55a2b5b4e59f0b834517933667b50ee8` |
| 1139 candidate-4 report | `1f00fdfd773b129af04d5bd9a6eae0c20cca604959777221bae4b23f7fd91983` |
| 1142 column-proposal-v2 report | `34a62009ebefa9055444353a900abb24b5a225f10ee91dd81899292fe597177f` |
| Canonical first-prefix fixture | `edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81` |

The accepted 1142 offline review is the preceding own commit `6ac128cf`.
The native/default backend and complete paid-world traversal gates remain
separate. This storage proposal neither repeats nor broadens that review.

## Existing reserve that must remain charged

`underground_profiles.gd:191` allocates exactly two banks after checking
`2*(98*P + 28*B + 32*S + 32) + 32768`. The current actual configuration is
P=18, B=194, S=1: **14,520 paired packed bytes +32,768 existing controls =47,288**.
The 7,268-byte profile wire is streamed and is not an extra retained image.
The current production catalog selects publication-v2 and validates cached
consumer sources (`mole_profile_catalog.gd:22`, `:58`). A future source consumer
change requires renewed closure; this proposal supplies no bypass.

`underground_level_catalog.gd:14` reserves **244 retained +2,048 controls =2,292**
inside the same profile arena, as already recorded by ADR1080 near line298.
Thus current occupancy for this calculation is **49,580**, not47,288.
The full profile maxima plus Levels are259,136+2,292=261,428; the old remaining
716-byte figure is correct for those independent maxima.

Global limits stay P256/B3072/S64 and256 living residents. The existing512
resident identity slots are not a population increase. Actual configured
capacities, not all global maxima, determine a joint pack admission.

## Complete immutable tables

| Table class | 1139 gait | 1142 handoff | Combined retained rows |
| --- | ---: | ---: | ---: |
| Programs | 2 | 3 | 5 |
| Source keys | 182 XYZ | 453 XYZ/heading/plant-mask | 635, preserving both formats |
| Intervals | 180 | 450 | 630 |
| Complete body/tool AABBs | 348 | 681 | 1,029 |
| Full-foot support records | 122 | 306 | 428 |
| Support references | 180 | 450 | 630 |
| Source fixture solid rows | 44 | 22 | 66 |
| Packed columns and existing digest allowance | 19,224 B | 48,548 B | 67,772 B |

No cross-program deduplication beyond the emitted source tables is claimed.
All stationary-root intervals remain. All66 source solids remain even though
their exact certified transforms resolve to one22-primitive canonical fixture.
The 1139 digest allowance is only32 bytes; 1142's is128. Their JSON provenance
and source descriptor meanings are not retained runtime identity for free.
See `compile_stair_program.py:338` and
`stair-handoffs-v1/summarize_program.py:23`.

Two complete raw images plus one4,096-byte stream buffer and one176-byte caller
packet are **139,816 bytes**. The earlier160-byte caller applies only to1139;
1142 requires176 including heading/phase (`summarize_program.py:58`). Sharing
means one owner, a busy/reentry guard, and no simultaneous nested use of that
packet. If a real call chain needs another packet, it must be counted before
admission. The caller may borrow bounded rows; it may not copy an entire bank.

## Additional immutable identity proposal

These are proposed field widths, fully enumerated in `census.py` and the JSON.
They are additional to both existing table digest allowances, not replacements
for them. They are not fields that already exist in either emitted artifact.

| Proposed column group per motion bank | Bytes |
| --- | ---: |
| 20 I64 header revision/count/backend/contract fields | 160 |
| 12 SHA256 pins | 384 |
| Three actor source rows: SHA256 +four I64 fields each | 192 |
| Five program descriptors:20 I32 +seven I64 each | 680 |
| 66 immutable primitive-map rows: six I32 each | 1,584 |
| Four exact join rows: four I32 each | 64 |
| Six I32 numerical Domain bounds | 24 |
| **Additional identity per bank** | **3,088** |

The digest set pins actual Profile wire, Level wire, connector Catalog,
Assemblies, Frontier, WorldBasis and its producer, numerical proof manifest,
presentation proof manifest, consumer closure manifest, shared ready pose, and
canonical fixture. An expected aggregate bundle digest belongs to the bounded
owner control/read state; do not insert a self-referential digest into its own
hashed payload. Proof manifests must resolve and verify their exact inputs at
cold admission; a matching opaque string alone is not proof.

Program rows name their component/table row, image and clip, coordinate equation,
fixed orientation/origin, actual Profile/variant identities and revisions,
complete included assembly and primitive-map ranges, endpoint phases/yaws,
source duration, and **separate unadopted** rational tick-rate fields. Null
runtime source/profile/rate bindings must keep activation refused. No source
file currently supplies the future qualifying stair Profile rows or live part
mapping, so those missing bindings cannot be filled with synthetic flags.

Source IDs are three actual immutable images, not five independent image copies:
ascent `3a9e2459…` (two clips, only clip0 selectable), descent `16b83eea…`
(clip0), and handoffs `c0d74030…` (clips0/1/2). ActorContent already supplies
exact first/count/nonloop/duration metadata; no preview-seconds scalar is
needed in the runtime descriptor. The unselectable rejected256u ascent clip
still occupies its original presentation image and is counted there.

Canonical fixture IDs0..13 are the exact timber part IDs. IDs14..21 are the
eight retained natural bearings under parts3,4,5,6,10,11,12,13, in that order.
Each gait's22 local solids transforms exactly to those bounds; handoff solids
are already in the fixed fixture frame. Support rows refer to deck IDs0 or7.
The map is immutable source identity, **not** a live Region map: runtime must
resolve exact actual Catalog/Grouping/Placement/prefix/source/full-generation
Region and current natural Terrain/history facts. Box equality cannot confer
ownership. A bounded current-owner scan can avoid a new retained live map,
but its finite work and performance still require implementation proof.

## Proposed finite joint admission

| Simultaneously charged component | Paired replacement proposal |
| --- | ---: |
| Current Profiles paired banks and existing controls | 47,288 |
| Existing LevelCatalog and controls | 2,292 |
| Two complete motion/identity banks,2×70,860 | 141,720 |
| Single stream/decode buffer | 4,096 |
| Single reusable caller packet | 176 |
| New logical owner/reader/helper ceiling, proposed | 4,096 |
| New native/control ceiling, provisional and unmeasured | 32,768 |
| **Total in existing262,144 reserve** | **232,436** |
| **Remaining inside that reserve** | **29,708** |

The last two rows are explicit implementation ceilings, not source-counted
members or measured RAM. The logical ceiling must include the expected bundle
digest, all fixed source/descriptor/scope packets, current-owner pins, poison
and load controls, nested reader/helper stack, and any frame buffers beyond
the176-byte caller. The native allowance includes bank/packed-array headers,
references, handles and parser/hash controls. Each actual member/constructor/
simultaneous call path needs a census; native measurement remains a separate
gate. An implementation that exceeds either ceiling must refuse or be redesigned.
The existing32,768 Profile controls are counted independently; they are not
silently shared with the new32,768 allowance.

For arbitrary permitted configured P/B/S, proposed joint admission is:

`2*(98P+28B+32S+32)+32768+2292+2*70860+4096+176+4096+32768 <=262144`.

Future actual Profile row/box/source growth costs
`2*(98ΔP+28ΔB+32ΔS)` against the29,708 remainder. It is not admitted merely by
being under the old global MAX values. Independent maxima produce444,284 and
must refuse before any bank allocation. Program/control capacity growth also
consumes that remainder and requires a new complete census; no silent reserve
increase follows. Current source geometry/intervals are never trimmed to fit.

The captured shared ledger is99,994,686 with5,314 remaining before the pending
4,096 Delivery charge. This proposal adds **zero** to the global reserved total:
it assigns capacity already held by PROFILE_BYTES. That does not certify the
whole application or free this arena for unrelated allocations.

## Source-once versus replacement lifetime

An initial source-once store with one motion bank would total161,576, including
the same conservative controls, caller and decoder. It must remain entirely
unready after incomplete source load and cannot be replaced while actors hold
it. A second owner created for replacement is not free: it duplicates controls
and scratch, as well as the bank. The one-bank number cannot authorize that.

The preferred implementation envelope charges both banks from the start, even
if the first public loader is source-once. It avoids depending on future memory
reclamation and fits the unchanged reserve. Runtime reads use the live bank;
decode streams only into the preallocated candidate, with all source/capacity/
shape checks before publication, no full wire/JSON copy and no third bank.

Actual joint Profile+motion replacement is not already implemented:
`Profiles.load_file:254` validates then immediately swaps its own bank. A future
coordinator must either restrict motion loading to a source-once unactivated
composition or obtain a separately reviewed prepare/seal/pure-swap seam for
all participants. It must preserve the old complete binding on refusal,
prevent reentrant scratch borrowing, validate actual retained source references
and revisions after the last observer, and preserve any occupied old source
obligation. This proposal changes none of those existing APIs.

## Exact phase, joins and physical obligations

All three images are nonlooping. Each ordinary interval uses share0..65535;
terminal is `(last,last,0)`. Ascent/descent each have91 keys/90 intervals;
approach91/90, turn271/270, retreat91/90. Actual source duration is exactly
`(count-1)*65536`, independently decoded from the image. The nominal3/9-second
previews do not adopt a gameplay pace. Future30Hz integer rate and overflow/
remainder/blocked-time behavior require their own adopted contract.

Gait roots use signed component-wise ceil in local space, then the certified
fixed fixture orientation and translation. Handoffs keep root in the fixed
program frame and use signed-ceil **unwrapped** heading to rotate body before
root addition. The equation tag must pin these differences, Q16 limits and
terminal rules. Existing complete interval boxes already contain source root
motion; never add the phase root again or rotate the fixed handoff root with
body heading. Loop/short-final-interval sources need a newly admitted protocol.

The independently checked joins are approach→descent at(0,0,-1879)/yaw0;
descent→turn at(0,-128,-2391)/yaw0; turn→ascent at(0,-128,-2217)/yaw32768;
ascent→retreat at(0,0,-1705)/yaw32768. Each has the same exact source ready-pose
digest. Initial(0,0,-1536)/yaw0 returns to that position at yaw32768. No hidden
heading reset or reverse-playback permission is implied.

The full numerical root Domain is[0,-32256,0,262144,16896,262144]u, lower
inclusive/upper exclusive. Admitting that root range does not admit translated
body/tool boxes outside it. Runtime physical proof must preserve actual
completed air, foreign/dynamic obstacle exclusions, source full-foot support,
explicit installed-solid identities and last exit. A body AABB spanning both
decks is not an ordinary void box or a blanket stair-solid exception; only
the exact live primitives corresponding to the offline complete-triangle
proof may receive its narrow treatment. All other solids still refuse.

ADR1112's proposed existing-column reuse remains viable: actor `R_SEGMENT`
holds source interval; `R_PROGRESS` holds share; `R_REMAINDER` holds reduced
sub-phase remainder. The immutable edge/variant selects the program and tag;
full profile, edge, generation, Job/tool/cargo facts remain current. No new
per-resident program copy or state column is proposed. Saved distance state
cannot be reinterpreted without explicit versioned tag/restore/parity checks.
Native source recovery/entry joins, exact backend qualification, new Profile
bindings and real supported endpoint publication remain mandatory.

## Coupled presentation is separate

The source tables do not replace the original three actor images. Together
with the currently published ground/WORK image, the four existing readers
retain1,524,064 palette/table bytes. The conservative sum of their existing
admitted peaks plus one shared Basis is28,041,568. This includes per-reader
native allowances and deliberately makes no shared-loader optimization claim.

A **not implemented** sequential single reader with all retained palettes,
one maximum decode, one borrowed-mesh allowance, one reader native reserve and
one Basis would be9,209,768; keeping all old palettes during replacement would
make that10,733,832. These are conditional arithmetic alternatives, not a
measured source lifetime or existing API. ActorContent currently copies into
an immutable Palette while raw decode arrays coexist (`:76`, `:91`). Borrowed
original meshes/textures and per-Actor renderer RIDs remain separately owned;
they are excluded from these figures and must not be declared free. None of
this presentation memory is covered by the262,144 Profile arena.

## Implementation gate and ownership handoff

Root approved additive ADR1143 work after this design: a new motion catalog,
its tests and new compiler/packer files, with existing consumers and shared
Profile/Level/Budget/World/accounting files frozen. The first bounded component
can prove exact packed bank sizes, source-once streaming, current Profile/Level
references, refusal preservation and source geometry reads while leaving
travel permission closed. It must retain this complete census and reject
stale/current-source substitutions before allocation or output.

Before any executable traversal, the missing work is actual member/helper/native
census; current immutable Profile/source/proof publication and backend closure;
real Catalog/variant/paid-prefix/live-part binding; qualified phase support,
occupancy and retreat integration; adopted fixed-tick rate; current-source
presentation; and save/restore/256-resident timing evidence. The29,708 remainder
is a bound for that next census, not evidence those tasks are complete.
