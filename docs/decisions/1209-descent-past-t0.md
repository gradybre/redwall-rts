# 1209 — Descent past T0: a flight of T0-family treads to the trench floor

Date: 2026-10-06 · Status: Accepted. Steps 1–3 are done (Brendan decided D1–D3 on 2026-10-06); step 4, the
short-reach install motion, is in progress.

## Brendan's decision being implemented

ADR 1208 option 2: **build the descent first.** Add stair treads after T0 down to the trench floor (y = −1024,
source-local), then later a real 4 m-tall Kitchen dug from inside. All coordinates here are source-local
(surface y = 0, descent along −Z), as in ADR 1208.

## Derivation (no new constants)

Every number below comes from published data: the prefix artifact
(`docs/design/underground-planning/first-entry-prefix-v1.json`, `edd56205…`), the content-6 profiles in
`qualified-stone-v5` and the accepted stair gaits (ADRs 1139, 1142).

### Pitch: 128 u down, 512 u forward

- L0's top is y = 0 and ends at z = −2048. T0's top is y = −128 and spans z ∈ [−2560, −2048].
- The accepted descent gait (`stair-descent-v7` case 0) moves its root exactly (0, −128, −512). Its first and
  last poses both equal compact ready frame 8. The accepted ascent (`stair-motion-v15` case 0) is the reverse
  pitch. So a tread that repeats T0 at that pitch is walked by repeating the same gait, translated.
- The 256 u descent was attempted in that series and refuses (`DESCENT_LEG_REACH_FRAME_28`), so 128 u is the
  only authored rise.
- The 232 u short step (ADR 1164) is a horizontal +X advance on level ground. It is not a stair motion and plays
  no part here.

### Tread count: six, and only five are T0-family

The drop from T0 to the floor is 1024 − 128 = 896 u = 7 × 128. That makes seven descents, onto T1…T6 and then the
floor. T_k is T0 translated by (0, −128k, −512k). T0's posts stand on the cut floor and bear on retained natural
ground below it (`natural_bearings`, y ∈ [−1152, −1024], `requires_never_cut`). So a translated tread keeps its
deck and bearers, and only its posts shorten.

| Tread | Top y | Deck z | Post height (u) | Descent ends at root z |
|---|---:|---|---:|---:|
| T0 (existing) | −128 | [−2560, −2048] | 704 | −2391 |
| T1 | −256 | [−3072, −2560] | 576 | −2903 |
| T2 | −384 | [−3584, −3072] | 448 | −3415 |
| T3 | −512 | [−4096, −3584] | 320 | −3927 |
| T4 | −640 | [−4608, −4096] | 192 | −4439 |
| T5 | −768 | [−5120, −4608] | 64 | −4951 |
| T6 | −896 | [−5632, −5120] | **−64: refused** | −5463 |
| floor | −1024 | from −5632 | — | −5975 |

T6's bearers would reach y = −1088, below the floor, so T6 cannot be a T0-family tread (decision D1).

### Cuts: three more cube rows, and a fourth that the last step needs

The existing cut groups end at z = −3072, so T1 fits in the half metre ADR 1208 called nontraversable. T2…T6 need
cube rows z ∈ [−4096, −3072], [−5120, −4096] and [−6144, −5120], two cubes each (x ∈ [−1024, 0] and [0, 1024]).
The descent onto the floor ends at root z −5975, whose foot reaches exactly −6144. The walking body, though, reaches
well ahead of its feet: the walk profile's boxes extend 474 u (body) and 732 u (held pick) ahead of the root. The
step-2 diagnostic shows the last descent strikes the trench's end wall unless a seventh row,
z ∈ [−7168, −6144], is open (decision D2).

Each new cube is cut from the surface exactly as the existing six are: Frontier stations at (∓1536, 0, row + 512),
profiles 25 (yaw 49152) and 17 (yaw 16384), the existing stations 4–7 translated in z. Their below-surface foot
boxes lie at |x| ≥ 1231, outside every cube, for every row (`compile_entry_frontier.static_geometry`'s rule is
translation-invariant in z). No new work motion is needed for the cuts.

### Installation: the existing motion cannot install T1…T6

T0 is installed from L0 with INSTALL profile 16 and handling row 29, from station (0, 0, −1536), against L0's
forward top edge `[-256,-64,-2048, 256,0,-1920]`. Profile 16's contact anchor is 448 u ahead of the root and
128 u above the stance plane. Its foot is z ∈ [−169, 174] about the root, and its body extends 234 u behind.

For T_k the target is T_{k−1}'s forward top edge, z ∈ [far, far + 128), where far is T_{k−1}'s far edge. With
the anchor 448 u ahead, the root must be at z ∈ [far + 448, far + 576), so the foot reaches far + 622 or more.
T_{k−1}'s deck ends at far + 512, so the foot overhangs the step behind it by at least 110 u. L0 is 2048 u deep,
which is why profile 16 works there. A tread is 512 u deep, so it does not work on any tread.

**A new install motion is required:** the same vertical relation (anchor 128 u above the stance, on the target's
top face), but reaching only 41–169 u ahead. Stationed at the descent's end root (far + 169), it reaches the
target with no reposition. Its body already fits: 234 u behind is less than the 343 u to the riser. The pending
piece of T_k is lower than the stance, so its prism and start volume must be re-derived for the new profile.

### Motion that already exists

| Need | Existing content | State |
|---|---|---|
| Repeated descent / ascent, 128 u | `stair-descent-v7`, `stair-motion-v15`; tables `stair-program-v1` (ADR 1139) | Source-accepted; repeated over the real flight in step 2 |
| L0 approach, half-turn/reposition on the lower tread, retreat to L0 | `stair-handoffs-v1` candidate 6 (ADR 1142) | Source-proved only for L0/T0 (its 22-prism fixture) |
| Runtime tables | `underground_motion_catalog.gd` (ADR 1143) holds all five programs | `activation_refusal` is `MOTION_SOURCE_ONLY` |
| Pace | DEC-050 / ADR 1145: 30 ticks per tread, 45 per half-turn | Adopted, with no pace row published |
| Cut work from the surface | profiles 25 and 17, stations 4–7 | Live (content 6) |
| Install a tread from the tread above | none | **Must be authored** (step 4) |
| Half-turn on T1…T6 and the step-off at the floor | none proved | Re-prove the ADR 1142 turn on T_k; the floor exit waits on D1 and D2 |
| Stair travel in WorldRoutes | none | Routes refuses fixed connector edges: `WORLD_ROUTE_FIXED_CONNECTOR_SOURCE_REQUIRED` |

All of these hold the pick (source 0), which matches the workers that cut and install.

### Bills

L0 carries 4,000 milli wood and 32,000 mWU; T0 carries 1,000 milli and 12,000 mWU. These are not proportional to
timber volume. L0's volume is exactly 3.0 × T0's, while its bill is 4 × T0's wood and 2.67 × its work. So no
per-volume rule exists to derive a shorter tread's bill from (decision D3).

### What the bundle successor must contain

`INSTALL` count must equal the Grouping's assembly count (`entry_source_constants._frontier`), and every new part
changes `structure.ugconn`, whose digest every other file links. So this is a **full bundle successor**, not a
Frontier-only one like `qualified-landing-v4`:

- **Catalog:** six new assemblies (T1…T6) with their parts, natural bearings and one LANDING datum per tread. The
  envelope grows to the new cuts. The variant's start and end points stay as the L0 → T0 segment.
- **Grouping, recipes and workpieces:** one row each per new assembly, with bills from D3.
- **Frontier:** CUT rows for the new cube rows. STATION and ENDPOINT rows for 8 (or 6) surface cut stations.
  EPISODE rows (BRACE/CUT/FINISH) for each new cube. INSTALL rows 2…7, each with its station on T_{k−1}'s
  installed contact (the new profile), its bearing on T_{k−1}'s edge, M as material and a retreat.

The structure catalog's single OPENING region (the stair top) is unchanged. A far opening belongs to the Kitchen
(ADR 1208).

### A constraint on the Kitchen

Every new post and T6's support bear on natural ground below y = −1024 under the flight, z ∈ [−5632, −2048].
That ground is `requires_never_cut`. A Kitchen dug from inside cannot be dug beneath the stair.

## Brendan's decisions (2026-10-06)

| Question | Decision |
|---|---|
| D1 — T6's form | **Sill tread** (option a): T0's deck and bearers six pitches down, the bearers cut to 64 u so they rest on the floor, no posts. |
| D2 — the stair foot | **The seventh row is part of the descent** (option a): z ∈ [−7168, −6144] is cut with the stair. The Kitchen starts beyond it. |
| D3 — the bill of T1…T6 | **T0's bill per tread** (option a): 1,000 milli wood and 12,000 mWU each. |

## Decisions as they were put (options retained)

**D1 — T6's form.**
- (a) **Recommended: a sill tread.** T0's deck and bearers six pitches down, with the bearers cut to 64 u so they
  rest on the floor, and no posts. Its walking surface is identical to the family's, and the step-2 diagnostic
  proves the last two descents over it.
- (b) A 128 u thick deck block resting on the floor. This is not proved: the swing foot passes its front face,
  which (a) leaves open between the bearers.
- (c) No T6, with a 256 u last drop. This is impossible: the 256 u descent refuses.

**D2 — the stair foot.**
- (a) **Recommended: cut a seventh row, z ∈ [−7168, −6144], as part of the descent.** The step onto the floor needs it: with six rows it refuses, with seven it is clear.
  It also gives the all-yaw turning stance (±406) room at the foot (root −5975, stance to −6381).
- (b) Make that row the Kitchen's first cubes, cut before the last step is walked.

**D3 — the bill of T1…T6.**
- (a) **Recommended: T0's bill per tread**: 1,000 milli wood and 12,000 mWU each, 6,000 and 72,000 in total.
  It is the only approved per-tread bill.
- (b) Brendan sets per-tread bills, for example lighter ones for the short-post treads.

## Order of work

1. This plan. **Done.**
2. Prove both accepted gaits over the derived T0-family flight. **Done** (below).
3. Brendan: D1, D2, D3. **Done** (sill, seventh row, T0's bill).
4. **New motion, install from the tread above** (candidates ready, awaiting review). Follow the install-source path: static pose candidates and exact
   provers, then a review packet. **Stop for Brendan's review.** After approval: the program, native capture,
   integer rows, and content 7 with one yaw-0 INSTALL row and one handling row. The rows are root-relative, so one
   pair serves every tread.
5. Re-prove the ADR 1142 half-turn/reposition on T_k (riser behind, next tread ahead and below). After D1/D2, also
   prove the step-off at the foot.
6. The bundle successor: `publish_qualified_descent.py`, create-only and fully pinned, proven on the hand fixture.
7. Runtime stair travel:
   - stair profile rows and the DEC-050 pace;
   - a connector variant per tread segment;
   - WorldRoutes fixed-connector edges;
   - Locations on tread datums;
   - motion catalog activation.

   Budgets are measured as each lands (ADRs 1205, 1207).
8. The foreman cuts rows 4–7, then for each k descends, installs T_k and ascends. First on the hand fixture, then
   live, with exact ledgers.
9. The Kitchen, under its own ADR.

## Step 2 — the flight proof (done)

`prove_descent_flight.py` (contact-qualification) derives the flight from the prefix artifact only and runs the
accepted `prove_stair_sequence.prove`, unchanged, over it.

**Fixture: 82 solids.**
- L0 and T0, as in the prefix artifact;
- T1…T5 with their natural bearings;
- the trench's floor slab, side walls and end walls, six rows long.

The derivation refuses T6: `DESCENT_FLIGHT_TREAD_6_POST_BELOW_FLOOR`. Only the prover's capacities change (4 → 8
segments, 32 → 96 solids). Pinned scripts that changed since the actor images were captured are restored from the
git commit whose bytes match their pin (ADR 1205), and each restoration is recorded.

**Result** (`descent-flight-v1/`):

| Gait | Segments | Triangle pairs | Separating checks | Sole contacts | Unresolved | Support rows inside |
|---|---|---:|---:|---:|---:|---:|
| Descent L0 → T5 | 6 | 4,044 | 162 | 3,978 | 0 | 540 / 540 |
| Ascent T5 → L0 | 6 | 4,686 | 336 | 4,350 | 0 | 540 / 540 |

The descent's 4,044 pairs are exactly six times the single-step prefix proof's 674. The risers behind, the treads
ahead and the trench add no candidate pairs.

**Bottom diagnostic** (`descent-bottom-v1/`), with the D1-a sill and two descents, T5 → T6 → floor:

| Trench | Result |
|---|---|
| 6 rows | Refuses. The body meets the far end wall from interval 44 of the step onto the floor (the prover stops at its 32-witness limit). |
| 7 rows | Clear: 1,348 pairs, 0 unresolved. |

**Scope.** These are source-local yaw-0 triangle and support proofs. They are not a native capture, a pace,
Locations, routes or installed support. They read the accepted source closure through the inputs that the
stair evidence's recorded invocation names (the frozen `redwall-rts-codex-ug-space` worktree, ADR 1192 §6),
each hash-checked. They also read 76 gitignored `godot/demo/assets/` files cloned from that worktree for the
run and verified against the image's source pins. Those files are not committed, so this is offline evidence,
not a test (ADR 1192 §2). `test_descent_flight.py` checks the derivation and the stored results without them.

## Step 4 — the short-reach install tap (candidates ready; stopped for Brendan's review)

`author_tread_install.py` (contact-qualification) authors the tap that installs T_k from T_{k−1}. It reuses the
accepted fitting source (`install-source-v4`) as far as the tread allows.

**Derived, not chosen.**
- **Workpiece.** T_k's left bearer, quarter-turned as T0's part 8 is, lies across T_{k−1}'s forward top edge:
  station-local `[-256,0,-310, 256,128,-182]`. The contact plane stays y = 128.
- **Station.** On T_{k−1}, at x = 0, yaw 0, 310 u behind its far edge. The ready body's own vertices
  (front −168.3 below the plane, back +188.4 in the riser band) admit 297–323 u. 310 is the midpoint.
- **Fixture.** One station-local fixture covers every tread: the support deck, the deck behind (a superset of
  L0's and any tread's), superset side boxes for the bearers and posts, and the workpiece.

**Unchanged.**
- The arm solver (`poll_pose`) with the real grip and unchanged arm links.
- The planted lower body.
- The 17-key poll lowering (208 → 126), mirrored to 33 keys, with the 31-key planted entry and its exact reverse.
- Every v4 proof: the crossing patch, the tool below the plane inside the workpiece, continuous self-clearance
  and the complete world proof.

**New.**
- **The upper body pitches back** 20–35° about Spine02 (`pitched_ready`). Bones 0–8 stay bit-identical.
- **The handle lean may reach 60°**, where v4 stopped at 50°.

`probe_tread_install.py` records why. Upright, 0 of 80 recipes clear:

| Result | Count |
|---|---:|
| The shaft meets the right arm | 70 |
| The head escapes the bearer | 2 |
| No arm solution | 8 |

Pitched back, 20 of 36 recipes clear. Pitching forward puts the snout on the handle.

**Candidates** (`tread-install-v1/`). All pass every proof.

| Candidate | Torso | Lean, azimuth | Contact (x, z) | Tool to body |
|---|---:|---|---|---:|
| v1 | −30° | 50°, 30° | 128, −278 | 4.8 u |
| v2 | −35° | 50°, 30° | 128, −262 | 4.5 u |
| v3 | −25° | 60°, 30° | 128, −246 | 7.8 u |

Accepted v4's tool-to-body minimum is also 7.8 u. **Recommended: v3.** It contacts the bearer's centre line,
pitches the torso least and keeps v4's clearance.

**Review packet:** `tread-install-review-v1/`. It holds `README.md`, `invocation.json`, `tests.log`, and for
each candidate `overview.png`, `hands.png`, `motion.png` and `review.json`. `test_tread_install.py` holds 7 tests.

**Open after approval:**
- **Arrival.** A 141 u backward reposition from the descent's end (169 u from the edge) to the station.
- **T6.** The sill's bearer is 64 u tall, so T6 needs a variant of the tap at y = 64.
- **Then:** the handling program, native capture, integer rows, content 7 and the Frontier.

### Review of step 4 (2026-10-07): Brendan chose **Revise**

Brendan's reason: **the pick looks awkward.** The handle angle reads badly: it is too steep and crosses the body.
He did not object to the backward lean, the station or the strike point.

The revision must:
- hold the pick naturally, with the handle angle and grip close to the accepted install motion's (≤ 50° if
  possible);
- keep the shaft from crossing the body.

The lean, stance, grip position or strike point may adjust as the proofs need. Every accepted proof stays. The
candidates v1–v3 stay as the record of what was reviewed.
