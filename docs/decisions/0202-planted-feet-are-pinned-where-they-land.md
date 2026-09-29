# 0202 — Planted feet are pinned where they land, in every Meshy clip
Date: 2026-09-29 · Status: Accepted

Builds on [0201](0201-meshy-idles-are-untwisted-to-the-walk-heading-with-the-feet-pinned.md), which
pinned the idles' feet. This extends the pin to every clip, and is stacked on that change.

## Decision

`tools/ground_meshy_clips.py` gains a **pin** step. It runs after the untwist (0201) and before the lift,
seat and root extraction (0193, 0195, 0197), in the same tool and the same `grounded/` output.

- Every foot's **contact phases** are found.
- Within each contact, the foot's drift across the ground is measured.
- Any contact that strays more than **`PIN_SLIDE_M = 2 cm`** is held where it landed. The legs are
  re-solved with 0201's two-bone IK.
- A deliberate step lifts the foot, so it starts a new contact, and a step is never undone.

46 of the 100 clips are pinned.

## The audit

Every creature × clip in `grounded/` was measured. The ten rigged creatures were audited, and the beaver
bridgewright was not: it has not been through the pipeline yet (see *Not done here*).

**Contact point.** A foot's contact point is its lowest skinned vertex on that key, over the vertices whose
strongest influence is that side's `Foot` or `ToeBase`.

**Slip.** The slip is how far that vertex moves to the next key, less the ground's own motion:

| clip kind | ground motion |
|---|---|
| a standing clip | still |
| an in-place gait | back at the gait's speed |
| a travelling carry walk | back by its extracted root (0195) |

A foot that rolls from heel to toe keeps its contact point still, so a roll is not a slide.

### First pass: contacts by height

A foot counted as planted within 2 cm of the clip's ground. The worst slide is the furthest a foot strays
within one contact.

| clip | worst | typical (median creature) |
|---|---:|---:|
| pull_radish | 12.6 cm | 4.2 cm |
| collect_object | 9.0 cm | 4.9 cm |
| chair_sit_idle (moles' feet on the floor) | 3.2 cm | 0 |
| wave_one_hand | 2.6 cm | 0.3 cm |
| idle (after 0201) | 1.5 cm | 0.4 cm |
| stand_and_drink | 0.8 cm | 0.2 cm |
| walk | 103 cm | 38 cm |
| run | 126 cm | 48 cm |
| carry_heavy_object_walk | 121 cm | 56 cm |
| carry_water_bucket_walk | 114 cm | 43 cm |

The results barely move with the height. A 1, 2 or 3 cm threshold gives:
- the same worst slide, to within 2 mm, on most standing clips;
- the same verdict on every standing clip over 2 cm but the two moles' chair clips. Their feet rest 1–2 cm
  up, so they are contacts at 2 or 3 cm and not at 1.

A few kneels move by up to 1.9 cm, as a foot hovering near the threshold joins or leaves a contact.

**The gaits' numbers were not stance slide.** Looked at key by key, Meshy's retargeted gaits drive the
**swinging** foot 2–6 cm deeper than the planted one. Grounding (0193) lifts by the lowest support, so:
- the swinging foot scrapes along the ground at 1–8 m/s;
- the planted foot hovers, typically 2–6 cm up and 18–22 cm on the squirrel forester's walk.

For the gaits, "within 2 cm of the ground" picks out the scraping swing foot, not the stance.

### Second pass: gaits' contacts by speed

In a gait, a foot is planted while it moves with the ground at less than half the gait's speed, for at
least 3 keys. An in-place gait's speed is found from its own planted feet: the speed `v` at which the feet
planted at `v` move back, on average, at `v`.

This is the same definition the pin uses. The worst slide is measured from where the contact would be held.
For a contact spanning the whole clip, the loop-closing ramp is set aside (see *What is kept*).

| clip | worst before | mean | clips > 2 cm | worst after | mean after |
|---|---:|---:|---:|---:|---:|
| pull_radish | 12.7 (squirrel gatherer) | 4.2 | 8 | 1.1 | 0.1 |
| collect_object | 9.0 (squirrel gatherer) | 4.7 | 8 | 5.1 † | 1.6 |
| run | 8.6 (badger quarryman) | 4.8 | 7 | 2.0 | 0.5 |
| carry_heavy_object_walk | 7.8 (badger quarryman) | 3.7 | 9 | 2.0 | 1.8 |
| walk | 4.8 (squirrel gatherer) | 3.3 | 8 | 2.0 | 1.1 |
| carry_water_bucket_walk | 3.6 (badger quarryman) | 1.9 | 4 | 1.8 | 1.4 |
| chair_sit_idle | 3.2 (mole mason) | 0.7 | 2 | 0.9 | 0.1 |
| wave_one_hand | 1.9 | 0.5 | 0 | 1.9 | 0.5 |
| idle | 1.5 | 0.4 | 0 | 1.5 | 0.4 |
| stand_and_drink | 0.8 | 0.3 | 0 | 0.8 | 0.3 |

All values are in cm. † marks a contact the pin reports and leaves, which is covered below.

"After" is every contact's slide read back from the written file. It includes the contacts under 2 cm that
were never pinned, so 2.0 is the threshold, not a residual. Every **pinned** contact reads back at
**0.0 mm** (to 0.1 mm).

### Threshold: 2 cm

- **Above the measure's own noise.** 0201's idles have the ankle pinned exactly, yet read 0.1–1.5 cm here.
  That is the toe flexing under a fixed ankle. A threshold below 1.5 cm would "fix" 0201's already pinned
  feet.
- **About 2% of stature for a 1 m mouse.** The rule is one absolute number, not a share of stride. A 2 cm
  skate reads the same on a slow creature and a fast one.
- **Stride shares.** For the walks, 2 cm is 1–4% of stride (0.53–2.2 m). Before the pin, the stance drift was
  1.3–4.8 cm, or 2–8% of stride.

## What was a defect, and what was intended

**Defects, pinned:**
- **Kneels and crouches.** The feet drift while the creature collects or pulls: pull_radish on 8 creatures,
  collect_object on 8.
- **Sitting moles.** Their feet shuffle on the floor, in the chair clip on 2 creatures.
- **Gait stances.** The stance drifts against the ground in 28 of 40 gait clips.

**Intended, untouched:**
- **Steps.** collect_object's steps, and every landing, are kept where Meshy puts them.
- **Clean contacts.** idle, stand_and_drink and wave_one_hand stay within 2 cm (on the squirrels' wave, once
  the loop ramp is set aside). They are byte-identical to 0201's output.

**Defects this does not fix.** These are the largest foot problems left, and they are reported, not hidden.
- **The gaits' swinging foot scrapes along the ground.** The longest drag outside a contact is 0.1–1.2 m
  (`ground_scrape_m`, per clip). It happens because Meshy's retarget puts the swing foot below the planted
  one, and grounding stands the clip on the swing foot.
- **The planted foot hovers** while that happens.
- **Fixing it needs a new gait:** the planted foot grounded, the swing foot lifted to clear. A pin cannot
  do it. Retarget or author the gait cycles.

## How the pin works

For each drifting contact, the move that cancels its accumulated slip is computed on every key. It is
anchored where the contact **lands**. A contact that touches the loop's seam is anchored at the seam, so the
first and last keys keep one pose. A contact that spans the whole clip is held at both ends, less a straight
ramp that closes the loop.

The foot is moved across the ground by that amount, keeping its height and world rotation. The thigh and shin
are re-solved by 0201's `_solve_leg`/`_solve_leg_keys`, reused and not duplicated. The knee bends in that
key's own plane, which is the least knee motion.

**Between contacts,** in the air, the move eases (smoothstep) back to nothing:
- across the whole gap, if it is 0.5 s or shorter;
- otherwise out over 0.25 s and back in over 0.25 s (`PIN_EASE_S`), so a long kneel keeps its own pose.

**Where a leg cannot reach:**
- The contact is held at whichever of its keys asks least of the leg.
- If the leg still cannot reach, the hips come down by what `_hip_drop` (0201) says, eased over 4 keys either
  side, at most `PIN_DROP_MAX_M = 3 cm`.
- Measured, the most any clip needs is 2.5 cm (squirrel gatherer run), then 1.1, 0.9 and 0.8 cm (the otter
  fisher's, badger quarryman's and squirrel gatherer's walks). The other seven need 2 mm or less.
- The walks' planted legs are 98–99.8% straight, which is why any move needed a drop.

**Extra passes.** A sole vertex weighted partly to the shin does not move exactly with the ankle, so up to
three more passes take out what one leaves (`PIN_PASSES = 4`).

**An in-place gait's ground speed** is recorded on the Hips' extras as
`gait = {speed_m_s, period_s, stride_m}`. That is the speed its planted feet now move back at. **The game
must move the creature at that speed, or play the clip at `ground_speed / gait.speed_m_s`,** or the pinned
stance slides again.

The demo's own estimator (`stage_demo_assets.walk_speed`, the median planted-toe speed) agrees within 5% on
seven of the eight staged walks. On the squirrel forester's walk it reads **0.828** m/s against its 0.682,
**21% fast**, because it counts the scraping swing toe.

## What the tool refuses, reports and checks

**It refuses:**
- a drifting contact on a skeleton without `UpLeg/Leg/Foot` chains;
- a pinned leg whose bone changes length;
- an in-place gait whose feet never move back, or whose speed does not settle;
- a pin that does not hold, in memory: every pinned contact posed from the rewritten keys must stay within
  `PIN_TOLERANCE_M = 2 mm`;
- a pin that does not hold when read back from the written file: every contact, on the ground it plays on,
  must stay within 2 cm + 2 mm, unless the contact was reported unpinned.

**It leaves the contact as it is, and reports it in `unpinned` with a reason:**
- `"reach"`: the leg cannot reach even with the hips 3 cm down;
- `"support"`: holding the foot would move what the clip stands on by more than
  `PIN_SUPPORT_TOLERANCE_M = 1 cm`, which is half the contact height. That is a kneeling knee. The lift that
  follows would raise or lower the whole creature, and the pinned foot off the ground with it. The culprit is
  the pinned contact, on the side of the leg that moved the support, nearest the key.

Two contacts are left today, both `"support"`:
- the squirrel gatherer's left foot as it kneels to `collect_object` (5.1 cm);
- the otter fisher's right foot through `collect_object` (3.1 cm).

## What is kept

- **Landings.** A step still lands where Meshy put it.
- **Idles.** Every idle is byte-identical to 0201's.
- **Stamp and seat.** The stamp keeps `version: 3`. A pinned clip carries
  `pinned: {contacts, max_move_m, decision: "0202"}`. The lift and seat logic is unchanged. Only two clips'
  largest lift moved by more than 1 mm, both collect_object, where the knee sits 6–7 mm higher.
- **Loop ramps.** A contact that spans the whole clip keeps a straight ramp, so the loop closes. Four clips
  have a ramp over 1 cm:

  | clip | ramp over the clip |
  |---|---:|
  | squirrel forester `collect_object` | 6.5 cm over 6 s |
  | squirrel gatherer `pull_radish` | 4.1 cm |
  | the squirrels' `wave_one_hand` | 1.7 and 2.4 cm |

  Meshy's own clip does not return that foot to where it started. That is a slow creep of 0.3–1.1 cm/s, not a
  slide.

## Evidence

- **Library, regenerated in order** (repair → tail → ground → bake) in a staging copy of the ten rigged
  creatures. The beaver was left out: see below.
  - `repaired.json` and `tailed.json` are **byte-identical** to 0201's.
  - `grounded.json`: **51 output hashes changed**. 46 are pinned. The other 5 are in-place gaits that only
    gained their `gait` record (the moles' walks and runs, and the mouse fieldworker's run, whose stances drift
    less than 2 cm). The other 49 are identical.
  - `baked.json`: **29 hashes changed. Every verdict is unchanged** from 0201:
    - 0 tails below the ground;
    - 1 flick (otter fisher `collect_object`, 124.37° → 124.40°);
    - 2 clips burying the feet or tail base (mouse keeper `chair_sit_idle`, squirrel forester
      `collect_object`);
    - worst clearance shortfall 0.03 mm, as before;
    - largest seam 20.15° → 20.22°;
    - no clip's largest tail step grew more than 5°.
  - The outputs were then copied into `assets/library/creature/*/grounded|baked/`. All 336 files match the
    manifests.
- **Godot 4.7.2.** All 51 changed clips, before and after, went through Godot's own glTF import and
  `AnimationPlayer`. Every bone was sampled at the clip's own keys (`viewer/dump_bones.gd`), and the foot
  vertices were skinned with those transforms.

  | clip | before | after |
  |---|---:|---:|
  | squirrel gatherer pull_radish | 12.6 | 0.2 |
  | badger cellarer collect_object | 9.0 | 1.0 |
  | badger quarryman run | 8.6 | 2.6 * |
  | badger cellarer run | 8.3 | 0.0 |
  | squirrel gatherer run | 7.9 | 0.0 |
  | badger quarryman carry_heavy | 7.8 | 3.2 * |
  | squirrel forester collect_object | 6.5 | 0.2 |
  | otter boatwright run | 5.6 | 0.5 |
  | squirrel gatherer walk | 4.8 | 0.5 |

  Worst planted slide in cm.

  Godot's playback and the Python measure of the same files agree within 2 mm on 40 of the 51 clips. The other
  11 differ by up to 1.5 cm, marked * where it is the worst. Each difference comes from a key Godot's import
  dropped, below.

  **\* Godot's import thins some keys.** Godot 4.7.2's scene import drops an occasional key: the badger
  quarryman run's `RightUpLeg` loses the one at 0.5 s. That leaves up to 21–30 mm of foot error at that single
  key, in Meshy's original clips as much as in the pinned ones. Measured on the feet across all 102 imported
  files, the worst key is off:
  - 25.9 mm before;
  - 29.5 mm after.

  Setting `optimizer/enabled = false` in the import did not keep the key. This is a pre-existing import
  behaviour, not the pin, and is left open below.
- **Contact sheets.** For the three worst clips, the sheets are:
  - `contact_sheets/foot_pin_squirrel_gatherer_pull_radish.png`;
  - `foot_pin_badger_cellarer_collect_object.png`;
  - `foot_pin_badger_quarryman_run.png`.

  Each shows the 0201 file (before) and the pinned one at six key times, from above and close up from behind.
  A red disc marks where each planted foot's contact began, and the run is carried forward at its gait speed.
  Beside it, a plot of the worst contact's contact point on the ground, from Godot's playback, before (red)
  against pinned (blue). They were looked at:
  - The pinned toes stay on their discs.
  - The before feet creep off them. On pull_radish the squirrel's left foot works forward through the pull.
  - In the plots, the red path wanders 8.6–12.6 cm and the blue stays within 1.4 mm.

  Scripts: `viewer/dump_bones.gd`, `viewer/shots_feet.gd`.
- **`tools/test_ground_meshy_clips.py`: 197 checks (95 before).** The new fixtures are literal:
  - **The stander:** 0201's biped, still, 30 Hz. Pitching a thigh by θ puts that foot at z = −0.5 sin θ.
  - **A 3 cm sway** of the hips: both feet pinned at (±0.1, 0.02, 0), the hips keeping their sway.
  - **1.99 cm** left alone, and **2.01 cm** pinned.
  - **A step** that lifts the foot: contacts [0,2], [5,8], [11,11], nothing rewritten.
  - **The same step landing and then drifting 3 cm:** held at z 0.10 where it landed, the stand before and
    after untouched.
  - **An in-place gait** whose stances creep ±2.5 cm:
    - speed found to be exactly 0.6 m/s;
    - each planted foot then moves back 0.02 m a key;
    - `gait = {0.6, 0.4, 0.24}` recorded;
    - each swing covers one stride, 0.24 m.
  - **A travelling gait:** the creeping foot, root added back, stays at z 0.06.
  - **A 9 cm sway:** the hips drop exactly 0.48 − √(0.485303² − 0.09²) on every key, and every ankle, the seams
    too, holds.
  - **Everything else:**
    - the foot's own rotation kept;
    - quaternion sides kept;
    - a toe partly on the shin pinned to 0.05 mm by the extra passes;
    - a seated clip's contacts;
    - a shin spur that is the support: left, reported `"support"`, the culprit found by side;
    - unreachable contacts reported `"reach"`;
    - the unit literals for contacts, slips, holds, eases, drops, reach and the gait speed's two fixed points;
    - N08, and two sabotages that each reach the one check that can see them.

  Matching the old refusals on their reason exposed one pre-existing vacuous test. "A lift that moves keys
  needing none refuses" had been refused for floating, not for the check it names. It now reaches that check.
- **Mutants: 68 of 68 killed** (`python3 -B`, a fresh copy of `tools/` per mutant, full list in the PR).
  21 survived the first round. One was the support culprit's first form, which picked by distance alone. The
  code was changed to pick by the side that moved the support, and got four mutants of its own. Each of the
  others was killed by a test that should have existed:
  - the inclusive edges (0.02 m up, 0.02 m of slide);
  - the nearest swing culprit;
  - the clip's own reach;
  - seams sharing the drop;
  - the foot's rotation;
  - quaternion continuity;
  - every hip-drop mutant, killed by the 9 cm sway;
  - one pass, and the residual threshold, killed by the shin-weighted toe;
  - the support culprit's side, killed by unit tests of `_support_culprit`;
  - the travelling read-back and reference, killed by the travelling gait;
  - the first or median-only seeded gait speed, killed by a fixture with two fixed points;
  - the floor from the lift, killed by the seated sway;
  - a shin counted as foot.

## Not done here

- **The gaits need re-authoring.** The swing foot scrapes 0.1–1.2 m along the ground while the planted one
  hovers (above). This is the largest foot defect left in the library.
- **The demo still plays the old files**, and still measures its own walk speed. Restaging, and moving at
  `gait.speed_m_s`, is left to the lead.
- **Godot's import drops occasional keys**, giving up to 3 cm at a single key. That is on original and pinned
  clips alike, and still happens with the animation optimizer off. It needs its own look.
- **Two kneeling contacts are unpinned**, because the knee is the support. A kneel that moves the hips with
  the feet is the real fix.
- **The beaver bridgewright** is in the raw library but not in `lookdev_dimensions.gd`. `repair_meshy_rig.py`
  over the whole library **crashes** on it with `KeyError: 'beaver'` rather than refusing. That is why the
  library was regenerated in a staging copy of the other ten. Adding the species height, or making the repair
  skip or refuse an unknown species, comes before its first run.
