# Redwall visual references — art, models and movement

Document `SET-ART-PACKAGE-001`, revision 1.1, 2026-09-06. Source folder: `ImageReference/` in `redwall-rts` (capitalization matters on case-sensitive systems). Brendan requested detailed review of every screenshot, direct use as model references, and special attention to tunneling, swimming and climbing.

**Completed:** all 28 PNGs opened and inspected individually; 28 detailed reviews; 62 named viewing windows; direct-reference assignments for bodies, clothes, tools, poses and environments; movement design analysis; current-spec conflict register. IMG-02 and IMG-28 depict the same specialist slide, giving 27 distinct slide compositions. Repeated illustrations within other slides are cross-referenced without multiplying evidence.

Read [whole-game visual alignment](visual_direction_alignment.md) first for Brendan’s latest reference roles and the distinction between UI illustration and world rendering (DEC-037/038).

**Approved visual target:** [mouse keeper and mole worker courtyard](visuals/grounded_expressive_rts_example_v1.png). Brendan approved this look on 2026-09-11; use it alongside the original supplied references.

[Consolidated Claude handoff](claude_visual_handoff.md) brings together the reference-use corrections, UI refinement decisions and approved world-art target.

## Read this package in this order

| Document | Purpose |
|---|---|
| [Every screenshot, one by one](screenshot_review.md) | Original image previews, observations, concrete model transfer, gameplay ideas and limits for each of the 28 files |
| [Direct modeling guide](model_reference_guide.md) | Which exact references to use for each body/wardrobe/pose, how to complete hidden geometry, and inherited Blender/LOD requirements |
| [Tunneling, swimming and climbing](traversal_design_review.md) | Connected spatial design, mode transitions, equipment clearance, route safety, UI, ECS ownership, formulas and synthetic verification fixtures |
| [Reference manifest](reference_manifest.json) | Portable repository source paths, SHA-256 digests, dimensions, inspection status, duplicate relation and 62 selection windows |

## Direct-reference permission — DEC-036

Brendan explicitly authorizes these supplied images as direct image-to-image,
image-to-3D, drawing/tracing/adaptation and model-building references. IMG-25 is
not observe-only. Record input regions and transformations; unknown attribution
does not negate that project instruction. Paid calls still need itemized approval.

## 1. Recommended art direction from these references

Preserve animal identity before costume detail: mouse ears/muzzle, mole working body, squirrel tail/contact poses, otter torso/tail, hare ears/stride and badger mass. Use practical layered clothing and readable equipment to express role. Ground the world in timber, earth, masonry, rope, cloth and occupied workspaces. Keep domestic warmth alongside serious consequences.

The clearest direct model-reference combinations are:

| First reference sheet | Body / silhouette | Clothes / equipment | Action or everyday feel |
|---|---|---|---|
| Mouse and original keeper | IMG-12, IMG-25 | IMG-03/04, IMG-05 | IMG-26 upper for action comparison; kitchen interactions for keeper work |
| Mole worker | IMG-08, IMG-25 | IMG-08 optional mining kit; IMG-03 practical cloth | Digging/working pose plus newly drawn crawl/turn clearance studies |
| Otter | IMG-18, IMG-25 | IMG-20 archer; IMG-17 practical maritime gear | IMG-18 proud fisher; IMG-10 underwater orientation only |
| Squirrel | IMG-09, IMG-25 | IMG-07 cultural variant | IMG-09 supported climbing; IMG-04 ladder use |
| Hare | IMG-01, IMG-25 | IMG-01 officer, IMG-22 light outfit | IMG-27 running/lunging pose |

The pictures become actual reference inputs during modeling, not just a moodboard. The model guide requires the artist/agent to name accepted source features, keep original source images available, and label newly designed backs, joints, attachments and dimensions. Those unseen surfaces are artistic construction work, not facts extracted from a screenshot.

## 2. The movement opportunity

The strongest shared idea is **terrain with several usable routes and distinct ways of inhabiting it**. Underground spaces can be homes and work routes; water can support transport and livelihoods; a canopy can offer access and observation. Tunneling, swimming and climbing therefore affect anatomy, gear, animation, jobs, topology, selection and saving together.

Recommended distinctions:

- Excavating a tunnel, traveling through an existing tunnel and combat sapping are separate activities.
- Wading, swimming on the surface, diving and riding a raft are separate movement states.
- Using a ladder, climbing a trunk and walking along a branch are separate connection types.
- A character's ability to see another character does not automatically grant a route or a legal attack.
- A species silhouette, a group specialist or an animation cannot bypass physical access and clearance.

DEC-035 adopts this connected movement direction; [SET-MOVE-001](../movement_direction_amendment.md) now governs the owner updates. The movement review retains detailed engineering proposals and 14 synthetic fixtures. It also names the exact catalogs, finite capacities and algorithms still needed for a production specification. It does not conceal missing values behind “balance accordingly.”

## 3. Conflicts and corrections to preserve

| ID | Evidence | Required treatment |
|---|---|---|
| ART-C01 | IMG-15 says five pearls; supplied *Pearls of Lutra* PDF p.12 b14 and p.49 b54 describe six | Use six for that verified lore claim; keep the slide error recorded |
| ART-C02 | IMG-07's hero spelling differs from the supplied *Rakkety Tam* title | Verify names in primary sources before naming production assets |
| ART-C03 | IMG-04 includes waterfowl food and military ingredient buffs | DEC-006 and SET-AMEND-001 govern food; no bird-hunting import or automatic health/combat buffs |
| ART-C04 | IMG-08/09/10 propose movement missing from current ground-only GDD/architecture | SET-MOVE-001 now adopts the direction; production contracts remain incomplete; anatomy alone does not enable it |
| ART-C05 | DEC-029/031 already require interoperable multi-level construction; current GDD single-floor mechanics and ARCH-MEM-002 derive limits from one floor | The current implementation specification remains incomplete for that approved requirement; recompute topology, room, furniture and container bounds |
| ART-C06 | IMG-21/22 mix leaders from multiple eras and label launch/FLC/DLC | Build era-specific scenario records; do not adopt the source deck's release/commercial plan |
| ART-C07 | IMG-25 gives squad counts and a separate illustrative lineup | Do not convert counts to resident caps or silhouette pixels to canonical meters |
| ART-C08 | Several slides attach species to moral/faction roles, coercion or captive economies | Preserve individual admission and content policies; a depiction is not permission for a gameplay economy |
| ART-C09 | Existing biped palette has 16 clips/609 frames; new movement requires additional poses/transitions | Version animation metadata and memory totals; do not relabel a walk clip as climbing |
| ART-C10 | Specialist traits and terrain claims are qualitative; other slides use turn-based durations | Source-only quantities remain source-only; no turn-to-tick conversion without campaign/calendar rules |
| ART-C11 | Bright concept portraits, domestic book art, battle illustration and lineups differ stylistically | Produce one coherent species sheet from named features rather than copy incompatible whole styles |
| ART-C12 | IMG-02 and IMG-28 are duplicate content; owl art repeats in IMG-11/24 | Retain all requested reviews but count each repeated design once in production planning |

The source's presentation provenance remains unknown. References to Total War, Warhammer, Pharaoh, Barbarian Invasion and commercial release categories are visible on the supplied slides; this package does not claim the deck is an official product, a released mod or Brian Jacques's own game design.

## 4. Claude / Blender-agent handoff

1. Read the setting decisions and authority order. Keep the active implementation ruleset unchanged during this reference task.
2. Open the original PNGs for the selected asset; use manifest `source_repo_path`, not a guessed lowercase directory or the Mac absolute path.
3. Read the relevant individual review and the modeling guide. Record exactly which source feature controls which part of the model.
4. Author missing neutral/side/rear construction views and contact poses as original design work. Do not claim a cropped screenshot supplied them.
5. Follow the existing mouse-first asset sequence and geometry/rig/atlas constraints. Prepare other species' reference sheets without claiming qualified crowd assets before the established Windows gates.
6. For any movement mechanic, use the traversal review as the specification work queue. Update its owning GDD/UI/architecture/balance contracts completely before enabling it.
7. Preserve approved underground scope. Do not treat swimming/canopy research as a reason to reduce multi-level construction to a cosmetic burrow.
8. Validate source IDs, direct-reference features, content policies, modeled clearance and measured asset budgets. Report production gaps honestly.

## 5. Numbers, verification and remaining work

**Measured this task:** 28 files, 27 distinct slide compositions, 62 authored viewing windows, original dimensions and SHA-256 values. **Inherited:** approved mouse scale, LOD/rig/atlas limits, tick convention, resident limits and current architecture. **New:** review IDs, reference selections, proposed spatial interfaces, formulas and synthetic fixture values. **Source-only:** slide model counts, three/four/five/twenty-turn examples and other advertised benefits. No new speed, hazard rate, species size or economy bonus is adopted.

The review covers every supplied screenshot. It does not cover unseen carousel pages, complete original paintings, source artist identification, full anatomical turnarounds or any actual Blender/Godot execution. Complete novel reading limits from the previous research remain unchanged. The six-pearl correction is a separately recorded supplementary excerpt check.

The next concrete engineering deliverables close MOVE-G01–05: species construction sheets and shared underground/topology rules, then exact surface swimming, climbing and diving contracts. Directional acceptance is complete under DEC-035. The current documents preserve every supported application and the decisions required to make those deliverables executable.
