# Actual work approach — 1156

Worktree `/Users/brendan/Developer/redwall-rts-codex-ug-work-approach`, branch
`codex/underground-work-approach`, base
`84acf74036484bd8ec4930895b7d0a96f8567937`. Created from freshly fetched
`origin/master` 82d60ba8, then fast-forwarded after an ancestry check. The
previous read-only diagnosis is preserved in the Geometry room-phase worktree.
No foreign source or project/cache was changed.

## Actual obstruction and whole-source diagnosis

Construction's immutable `fixture-5/` evidence in the room-phases worktree
retains the original published-WALK refusal. Its current fixture has actual
WORK root `(X+1280,-4608,Z+512)`, access/retreat `(X-1024,-4608,Z+512)`,
`X=60*2048`, `Z=50*2048`, and a solid face at `X+2048`. The original fixture-5
used Z+1024; that historical invocation is not rewritten. The actual FRONT16
WorkFace succeeds at the current station. WALK1's all-yaw 1256u tool envelope
penetrates the face by 488u, producing `WORLD_ROUTE_NO_FITTING_PROFILE`.

`inspect_source.py` is a read-only diagnostic using the exact accepted raw
geometry and current Actor image through their bounded binary readers. It
reproduces the accepted full idle/walk source hull before narrowing the phase
programme. It does not rerun the historical complete input reconstruction,
emit certificate bits, publish profiles, or establish native replay.

`source-bounds.json` is the initial diagnostic. `cardinal-bounds.json` adds the
actual finite WorldBasis coefficients, complete projected foot triangles and
all four cardinal orientations. The latter is the current reproducible result.

| Complete source set | Body bound u | Tool bound u |
| --- | --- | --- |
| Idle | [-413,-1,-496;521,857,259] | [-108,355,-865;891,847,130] |
| Walk | [-445,-1,-474;546,930,346] | [182,439,-621;910,1036,64] |
| Shared ready | [-409,-1,-395;364,840,234] | [184,379,-733;548,810,-249] |
| Walk + ready + every convex fade | [-445,-1,-474;546,930,346] | [182,379,-733;910,1036,64] |

Idle frame38/tool vertex148 has even its upper numerical bound forward of
768u. Thus the idle failure is a source-point witness, not only a loose AABB.
The new programme excludes idle explicitly; the ordinary ground programme
still includes it.

The tighter cardinal calculation retains BODY above-plane
`[-445,0,-474;546,930,346]`, full below-plane primitive
`[-239,-1,-274;284,0,249]`, tool `[182,379,-732;910,1036,64]`, and complete
stance `[-274,-1,-274;299,0,249]`. The three BODY rows are repeated as complete
TURN_RECOVERY rows. At yaw49152 this puts the tool no farther than +732u X
and the foot support at `[-249,-1,-274;274,0,299]`, inside the real existing
station footing. No air box is footing; every body/tool and below-plane
support obligation remains independent.

## Source and retreat semantics

The Actor image remains `adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9`:
14 clips, ground WALK at clip1 and shared ready at clip0@8*65536. The actual
loop duration and shortened terminal interval come from Content. Source
programme version5 is proposed; no new palette or second Content allocation.

Forward and backward are distinct selected policies. Both have READY,
ready→walk0 fade, full WALK cycle and any walk interval→ready fade. Backward
reads clip1 at `(D - (q % D)) % D`. Calling the same Content reader preserves
the exact loop seam and shortened last interval. Reversal reorders the same
complete source support/body/tool geometry; root displacement must reverse
with source time. It must not render a forward gait over a backward root.
The proof/native packet must exhibit this coupling, not merely equal AABBs.

Actual approach follows +X while body yaw is49152. After complete WORK
recovery to shared ready, actual retreat follows−X while body yaw stays49152
and the source walk cycle runs backward. It ends at the full real retreat
Location, facing the same way. It needs no about-face at the face. A separate
ordinary turning action can occur only after reaching an actually proved
turning area; 1156 grants no turn.

Furnishing checked the accepted1142 half-turn alternative: relative tool
bound `[-900,379,-865;548,810,906]`, 270 intervals,174u root shift. It does not
fit this wall and has a distinct T0 support proof. It is not reused as flat
ground permission.

## Existing interfaces and bounded extension

* Profiles currently stores18 I32 +3 I64 +2 bytes per row. Byte97 must be0;
  a version2 wire gives it exactly `AUTOMATIC=0`, `READY_FORWARD=1`,
  `READY_BACKWARD=2`, `SOURCE_WORK=3`. Version1 keeps byte97=0. Unknown values refuse.
  Exact mode/yaw/state/source restrictions are checked during load. No new
  Descriptor or Selection field is added.
* `selection_policy_of(profile_id, profile_revision, content_revision) -> int`
  reads that immutable byte, returning−1 on stale identity. New
  `query_travel_profile_into(worker,job,id,profile_revision,content_revision,
  posture,family,tool_hint,out Selection)` repeats the actual dynamic guards
  for the exact requested WALK row. Default `query_into` selects only policy0.
  Same-policy overlapping physical keys still refuse; different selected
  policies are not automatic fallbacks.
* Routes gains exact `admit_travel_actor` / `refresh_travel_actor` counterparts
  to the current exact WORK APIs. Existing R_PROFILE and two revision columns
  retain the selected policy through search, motion, occupancy and reload.
  Every selected edge's mode/posture/source remains exact. A selected policy
  cannot silently switch to the ordinary all-yaw profile.
* Path heading is distinct from body heading only for policy2. All segments
  must equal body yaw for policy1 or `(body_yaw+32768)%65536` for policy2.
  WorldRoutes still sweeps all seven source rows at the actual body heading.
  Routes does not turn the Transform to the reverse path heading. Arbitrary
  bends, policy changes in flight and stationary-turn calls refuse.
* Driver programme5 reads the actual Route actor's exact profile/source tuple.
  It holds ready and refuses idle, yaw drift, in-flight row changes and early
  WORK/recovery handoffs. Existing18 role pins can retain0/1 and16WORK rows;
  eight selected rows must prove the same source/profile/content revision and
  exact immutable mapping, avoiding another retained pin bank. Final census
  must establish that reuse rather than assuming it.
* A presentation `Frame.ready` cannot be a caller-supplied permission flag.
  The existing Routes `R_PHASE` and `R_REQUEST_TICK` columns have a tagged
  source-policy interpretation documented in ADR1156. Policy0 remains
  unchanged. `actor_phase` and static `actor_phase_in` return decoded physical
  phases only. `source_work_observation_refusal` and concrete static
  `source_work_leaf_refusal` bind the original actor/Job/profile/revisions and
  require canonical WORK after ENTRY, supplementing the caller's physical
  proof. Static `source_ready_leaf_refusal` proves the exact ready handoff.
  `request_source_ready` performs seam/recovery or partial-entry retrace on
  actual30Hz ticks. `source_state_leaf_into` supplies four scalars to the
  driver's existing scratch. Rendering does not advance or grant this state.

The current Room Approach Request already carries an explicit travel profile,
revision, content revision and yaw. WorkFace needs no geometric exception.
The1152 provider presently pins one retreat travel profile; its successful
source fixture must select the backward row for WORK→retreat and the forward
row for access→WORK, with full current handles. Construction owns that caller
change. Runtime extension never substitutes copied WORK geometry for WALK.

## Additive publisher API

New owned module `godot/data/underground/mole-worker/work-approach-v1/compile_work_approach.py`
exports `compile_approach() -> dict`. It rederives the exact accepted537-input
source reconstruction using the unchanged accepted adapter plus four explicit
original immutable source locators. It accepts no caller success flags.
Its report names all source hashes, loop timing,
ready frame, complete interval/fade set, all eight selected rows and seven
whole boxes per row, forward/back root-phase equation and proof limits.
Rows contain `selection_policy`, physical identity, exact yaw and complete
roles. They emit no certificate bits themselves. The root-owned publication
pipeline consumes this report only after numerical, native and consumer
closure, then produces the coherent new immutable catalog. Oldv2 remains
unchanged. A sorted26-row map is required: two ordinary ground rows, eight
selected travel rows, sixteen work rows; old WORK numeric IDs cannot silently
retain their old meaning under a new content revision. New WORK rows are
SOURCE_WORK, not duplicate legacy rows. The real +X pair is forward5/WORK24/
backward9, preserving strict worker-free unique contact resolution.

`source-4/` retains the successful reconstruction. `runtime-1` retains the
test fixture's same-revision malformed-reload setup refusal; `runtime-2`
retains three legacy stale-profile read regressions, corrected without
relaxing selected source tags. `runtime-3` retains the old future-program5
test after5 became explicit; `runtime-4` retains the actual image refusing a
test's undersized3MiB load allowance. The corrected test uses the existing
7,141,920-byte presentation reservation. These are retained attempts, not
qualified runtime evidence. Exact component and native results follow below;
root owns the current publication and composed paid gate.

## Simultaneous storage proposal

The paired Profiles formula stays `2*(98*P +28*B +32*S +32)`.
Current `(P,B,S)=(18,194,1)` uses14520 packed bytes. Proposed `(26,250,1)`
uses19224, a4704-byte increase inside the existing joint PROFILE_BYTES reserve.
Profiles control32768, Levels2292, paired Motion141720, decode4096,
caller176, Motion helper4096, Motion native32768 and Session1536 remain counted:
`19224+32768+2292+141720+4096+176+4096+32768+1536=238676`, below262144.
That is the immutable source report's historical subtotal. The final
`census.json` additionally charges the reviewed retirement owner 8,192:
**246,868 /262,144**, with 15,276 bytes left inside that existing joint arena.
The final prospective Catalog has 26 profiles/250 boxes/1 source and 9 cached
consumer scripts. Root's current Profile/Motion rebind must close the exact
profile digest/header semantics; arithmetic does not supply that identity.
Both banks coexist; no independent-max composition is admitted.

Eight used pace rows consume576 bytes of existing paired preallocated Catalog
capacity; they add no new allocation or speed. Both directions retain the
actual `RATE_GROUND_CAP`/Movement rate and existing integer fractional travel.
No actor row, Content image, clip, global capacity or arena ceiling grows.
`census.py` verifies every module/nested member and resize call against the
original base. No existing owner gains retained state or another bank. New
SourceProgram is stateless, with 128 bytes of integer constants and 512 bytes
for the two complete UTF32 digest strings, counted once. The complete actual
public admission/cargo stack is 632 bytes with 48 expression/return bytes;
the baseline WORK stack already used 624. Static source-work readiness is 320,
decoded phase232, and the visual source read 360. A foreign caller must add its
own frame; a source-readiness leaf does not replace its physical proof.

The complete control calculation includes 326 existing fixed Profile packet
bytes, all 552 Profile integer-constant bytes, 8 for the null ref,8 for the new
Driver constant, 640 shared programme bytes, and the larger cold/hot peak 1,649.
The cold peak conservatively sums every sequential Profile loader/validation
frame 625 including expressions, plus a 1,024-byte payload ceiling for 988
explicit decode-buffer/String/literal bytes. Two generations of each loop
buffer account initializer-before-assignment overlap. Thus 3,183 fits a 4,096
logical slice of the existing 32,768 Profile control reserve. The remaining
28,672 native bytes remain provisional, not measured. No reserve grows.

Driver fields and 54 pin scalars, 14 durations, 24 live/stage scalars and caller
scratch are unchanged. Its existing cold Content.profile_matches descriptor/
digest lifetime is identified separately in the census; no second Content is
allocated. The unchanged presentation admission remains 7,141,920 bytes.

## Exact component and native results

`runtime-9` is the final clean-import/official strict singleton invocation:

| Suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Profiles |27|643|0|
| Routes |73|11,633|0|
| WorldRoutes |39|2,437|0|
| Driver |16|1,472|0|
| Total |155|16,185|0|

Every strict/raw unexpected, expected, tolerated diagnostic and leak count is
zero; analyzer 0/10. Source/project/registry/assets were unchanged/restored.
The two final Routes tests cover interrupted ENTRY, pending work-loop seam,
RECOVERY and partial-entry retrace, as well as exact read-only source timing.
No Driver is instantiated for those canonical phase tests. Actual Profile
reload and wrong revisions cannot reopen readiness; reserved tag/clock bits
and stale full handles refuse without output writes.

`native-2` uses the original actual Actor image, Content, Driver, body mesh,
rigid pick and actual Routes/Resident/Job/Gear owners. Its geometry provider
and profile certificate flags are explicitly diagnostic. Four headings, two
views and 188 canonical ticks produce 1,504 poses: ready→walk fade, 30 actual
ground travel ticks, ready fade, 30 entry ticks,36 FRONT work ticks, 30 recovery
ticks, fade, 30 backward travel ticks and final ready fade. Body heading stays
fixed while root and walk source both reverse. One actual Content is shared;
actors/owners are released between sequences.

Independent verification compares all 24 actual body bone matrices, the rigid
pick matrix and the body instance matrix at every recorded pose against the
original source/Q16/basis/root equations: 469,248 bit-exact float32 scalar
comparisons. All 9,336 capture assertions and raw diagnostics are clean.
There are 64 real 1280×720 side/RTS captures. The visible blank diagnostic scene
is deliberately not Room composition/render acceptance or a GPU/all-phase
error proof. Existing continuous source/native-residual certificates remain
separate exact inputs. Eleven independent verifier tests include source phase,
reverse heading, root teleport, native-byte corruption and omitted-pose
mutants; seven compiler tests retain every short-seam interval/fade/join.

The independently assembled 9,620-byte diagnostic profile image matches root's
`a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204`
byte for byte (schema2/content2/26 rows/250 boxes). No production certificate
or current Catalog closure is emitted here.

`native-1` is a retained interrupted attempt: the inherited asynchronous
screenshot wait stalled, so the owned process was stopped. `native-2` uses
the existing synchronous draw/readback pattern. Exact executed owned helper
versions live under each attempt's `executed-owned-sources/`, with original
hash locators. Final capture differs from native-2 only by removal of the
analyzer's redundant `await` on that synchronous helper. The wrapper's added
import restoration is independently unit-tested; it does not alter replay.

`runtime-8` passed all 155 strict cases but correctly failed analyzer on that
redundant await. Its wrapper then attempted restoring import metadata before
returning parked assets. The cleanup exception and manual exact 303-input
restoration are retained. The final wrapper restores the original project and
assets first, and refuses to delete parked originals if restoration fails.
The final sixteen census/runner tests include this negative and raw-import
diagnostic refusal. `runtime-9` verifies the corrected complete restoration.

## Timing limits

`source-clock-timing.json` records the exact current source and call chains.
At 4,096 calls on this machine, the full 32-byte/64-character digest helper took
19,460 microseconds; decoded actor phase 29,499; source-work leaf 35,343. A 512-tick
single-actor actual-owner run took 84,233 microseconds with explicitly synthetic
spatial proof. A successful stationary tick makes four direct digest checks,
including pre-observer selection and the final source check. Moving ticks make
two direct checks before foreign caller work. Foreign physical/contact/occupant
queries can add calls. Immutable checks remain unchanged; no cache was added.
These focused values are not a 256-actor or target-hardware qualification.

## Owned implementation and acceptance

Root's explicit lease covers Profiles/Routes/WorldRoutes with their existing
tests, `mole_profile_driver.gd` / `test_mole_profile_driver.gd`, additive
`work-approach-v1/**`, ADR1156 and this evidence subtree. Root retains the
shared publisher/Catalog output, source renewal, registry and budget tooling.
Construction retains WorkFace/provider/phase tests. No other source writes.

Acceptance needs source/key/seam/foot reversal and mutation tests; default
selection/unknown-policy/ambiguity regressions; actual full-owner movement
and refusals in both directions; unchanged pose/route state on source,
Job/tool/cargo/geometry/callback changes; exact ready/WORK joins; all-cardinal
native root/pose replay; complete cold/control/presentation census; and the
actual ordinary phase positive using coherent qualified content. Existing
all-yaw failure remains a regression. Historical/geometry-only fixtures do
not replace current consumer closure or the paid positive.
