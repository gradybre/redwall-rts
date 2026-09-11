# UI asset generation lock — answers for Claude

2026-09-11 · SET-UX-VIS-002 revision3 · ART-LOCK-001.
**Sixteen asset identities and production directions settled by Astra as design lead.
Direct-reference use USER_CONFIRMED under DEC-036. Paid generation NOT APPROVED.**

This answers the seven questions and incorporates Brendan's correction. It
refines ART-UI-03–08/11; functional UI tokens, layout and gameplay stay unchanged.
The structured [asset lock](asset_generation_lock.json) supplies the same sixteen
rows, twelve pigment swatches and numeric rendering conventions for prompts.
These are newly authored art parameters, not inherited GDD constants or user quotes.

## 1. Reference permission: direct use is allowed

Brendan explicitly states that the images he supplied may guide direct builds in
this world. **IMG-25 is not observe-and-describe-only.** Open the original image
and use it directly for image-to-image, reference-guided drawing/tracing/adaptation,
modeling and image-to-3D where useful. The same project permission applies to his
other supplied images/material and supplied reference extracts. A written
description can accompany the image; it is not a mandatory replacement for it.

The former wording that the supplied artwork was not authorized for production
reuse was an assistant-created restriction, now corrected by DEC-036. An unknown
creator/edition field is provenance to retain, not a reason to invent an
observe-only rule or demand that Brendan provide a different reference.
Record the supplied file, region, transformation and generated/edited output.
Do not assert that Brendan owns copyright or that an unknown source is CC-licensed.
Those assertions are unnecessary to carry out his reference-use instruction.

Use IMG-25's upper woodland lineup for mouse, mole, squirrel and otter anatomy.
Its registered region is pixels [413,247,1304,565), from the original1366×1026
image. The whole region may be sent as reference, or isolate the relevant species
visually and record the actual crop. Do not guess individual crop coordinates.
Exclude slide labels/arrows/count tables from the generated asset. Source poses,
clothing and proportions guide adaptation, while DEC-019 and the approved game
scale still control the model. Referencing an image does not adopt its unit counts,
hunting, recipes, faction roles or other mechanics.

**Purpose-made asset sheets may be segmented locally.** ART-UI-11 forbids using the
full HUD concept as a runtime screenshot overlay or cutting out its text-bearing
panels. It does not forbid using that concept as an image reference, extracting
separately generated sheet cells, or adapting supplied object/species references.
Preserve original inputs and sheet outputs, crop coordinates and individual exports.

## 2. Aesthetic and reference roles

Production target: **storybook watercolor with controlled ink contours, grounded
animal anatomy and practical materials**, applying DEC-018/019. Use soft pigment
variation inside clear forms, not airbrushed plastic, glossy3D, chibi proportions
or a generic medieval inventory pack. This is Astra's specific implementation of
the existing blend; Brendan's final acceptance of a probe remains pending.

Use these together, with distinct roles:

- `visuals/05_woodland_art_concept.png`: family finish, restrained depth and warm
  illustrated treatment. The current lock corrects its Fuel/Wood ambiguity and
  supersedes its missing details. Generated lettering/layout is not authoritative.
- IMG-25 upper lineup: direct anatomical/clothing input for the four species.
- IMG-04: direct domestic object, cloth and warm material input when relevant;
  the source's game-effect text stays outside production policy.
- The twelve swatches below: color authority; a reference's scanned paper tint
  or generator's new color preference must not shift the family.

No new owned/licensed-reference request is necessary to start reference preparation.
Do not treat “closer to the books” as permission to claim an unidentified artist's
exact style; use the actual supplied images and the above art language.

## 3. Palette: twelve illustration pigments

| ID | Hex | Assigned role |
| --- | --- | --- |
| I01 Ink | #25372D | Permanent object contour, facial ink and dark linework |
| I02 Deep shade | #14211B | Occlusion, ember base and restrained cast shadow |
| I03 Oat | #EAE1C8 | Pale cloth, bowl interior and medallion field |
| I04 Cream | #F5F0DF | Small highlights and FOREST separation keyline |
| I05 Sage | #708171 | Cool leaf variation, muted cloth |
| I06 Leaf | #466647 | Stew greens and shared garment green |
| I07 Brass | #B49A58 | Muted medallion ring and restrained fittings |
| I08 Timber | #91613E | Wood and warm mouse/squirrel fur base |
| I09 Umber | #594332 | Bark, dark fur, straps and wooden recesses |
| I10 Clay | #B76545 | Ceramic, roots in stew, subtle ear interior and flame edge |
| I11 Ember | #D99743 | Flame core/edge light and small warm highlights |
| I12 Flint | #8A8D84 | Stone, metal and mole/otter cool fur variation |

Use these base swatches and blends between them for watercolor shading and
antialiasing. This is not indexed12-color quantization; do not destroy soft edges
to force every pixel to equal a swatch. No additional blue/purple/cyan, white
glare, orange wash over every object or global warming filter. The material-role
mapping prevents a gray bed or a gold mouse on one call and a brown one on another.
These pigments are illustration-only; they do not replace semantic UI tokens.

## 4. Camera, light, shadow and outlines

Angles below are **screen-space**, x right/y down,0° right,90° down, increasing
clockwise. Light-source azimuth225° is upper-left; elevation45° above the picture
plane. Cast-shadow direction45° is lower-right. Camera instructions per row are
separate from light direction. Render diffuse watercolor light; no second rim
light and no baked ambient glow. Fuel's flame is a symbol, not an emissive light
that changes the family rig.

At24px: cast shadow has offset(+1,+1)px, opacity≤18%, and no nonzero shadow pixel
more than2px from the subject silhouette. At32px the maximum is2px,48px3px,64px4px.
The stated maximum includes blur support, not just offset. Scale offset with
output size and clip the shadow mask to the maximum; avoid a broad gray puddle.
At24px all visible pixels, keylines and shadows fit within a22×22 box centered
in the24×24 canvas. Export transparent RGBA; no baked square or fake transparency.

**Contour ruling: always.** Use I01 ink around the primary silhouette,1 final
pixel at24/32px and1.5 at48/64px (antialiased coverage is allowed). Interior detail
lines are subordinate, not a second web of outlines. On FOREST surfaces add an
outer I04 separation keyline of1 final pixel at24/32px,1.5 at48/64px. On JOURNAL
surfaces omit this light keyline; the dark contour remains. These are two declared
surface variants, not per-generation judgment or a contrast-failure improvisation.
No opaque disc/plaque behind resource or toolbar icons. Medallions have the
intentional opaque roundel specified below. If a variant still fails the owning
contrast requirement, fix/reject it; do not invent another backing style.

## 5. Sixteen rows: exact object, view, state and small-size invariant

The table below is generated from the paired JSON by the planning package.

| ID / label | Exact object | Angle / state | Shape that survives24px | Pigments |
| --- | --- | --- | --- | --- |
| RES-FOOD — Ready food | One shallow olive ceramic bowl, filled with vegetable stew; two cream root pieces and one green leaf; no spoon, lid, basket or loaf. | Front,30° elevation; bowl rim horizontal. Full, served; no steam or motion. | Wide elliptical rim over a single rounded bowl body. | I06 bowl; I10 broth/roots; I03 pale chunks; I09 underside. |
| RES-FUEL — Fuel | One upright three-tongue flame over two small dark ember stones; no timber, candle, brazier or stove. | Frontal graphic, no perspective tilt. Burning symbol; no smoke, rays or external glow. | Single pointed flame/teardrop mass; ember base subordinate. | I10 outer flame; I11 middle; I04 small core; I02 embers. |
| RES-WOOD — Wood | Three cut logs stacked two below and one above; visible circular cut ends and bark. | Front-right three-quarter,30° elevation; length axes recede upper-right at35° above screen horizontal. Dry unburnt stack; no leaf, ember or flame. | Three circular ends in a triangle joined to one compact stack. | I08 cut ends; I09 bark; I03 narrow ring highlights. |
| RES-STONE — Stone | Three rough angular gray stones: one large rear peak, two smaller front pieces. | Front,25° elevation. Dry raw stones, no ore crystal, gem or metal glint. | One jagged peaked mound; no circles or log rings. | I12 faces; I02/I09 shadow; I03 small edge planes. |
| RES-POP — Population | Exactly three upper-chest busts: mouse center/front, mole screen-left/rear, otter screen-right/rear; no hats or props. | Frontal group, eye-level. Neutral attentive group; same plain green tunics; no age/sex/faction coding. | Three staggered head masses, center mouse ears above the other two. | I08 mouse; I12 mole; I09 otter; I06 clothing; I03 small muzzle highlights. |
| RES-BEDS — Beds | One single low wooden bed with four posts, cream pillow at rear-left and a folded moss-green blanket; no canopy, bunk or row. | Three-quarter from foot/right side,30° elevation; head recedes upper-left. Made and empty; no sleeper, occupancy marker or warmth glow. | Horizontal mattress rectangle with two prominent end posts. | I08 frame; I09 legs; I03 pillow/sheet; I06 blanket. |
| CMD-BUILD — Build | One wooden carpenter mallet: rectangular head and straight handle; no nail, anvil or crossed tool. | Side-on; handle runs lower-left to upper-right,45° above horizontal; head perpendicular. Clean serviceable mallet at rest. | Unbroken T silhouette. | I08 head/handle; I09 end grain; I03 small lit edge. |
| CMD-ZONE — Zone | Four short wooden survey stakes joined by one slack rope boundary into an empty square; no crops, building or fill. | Oblique top view,45° elevation; projected square is a diamond. One closed marked boundary, no active selection check. | Hollow four-corner diamond loop. | I08 stakes; I03 rope with I01 contour; empty transparent center. |
| CMD-WORK — Work | One hand spade and one wooden mallet crossed, spade blade upper-left, mallet head upper-right. | Front, tool plane parallel to picture plane; handles at opposing45° diagonals. Tools at rest; no sparks, person or progress state. | X silhouette with one broad spade lobe and one T head. | I12 blade; I08 handles/head; I09 grip shadows. |
| CMD-FOOD — Food | Exactly the RES-FOOD bowl artwork. | Identical to RES-FOOD. Identical; button state drawn separately. | Identical bowl silhouette. | Identical to RES-FOOD. |
| CMD-PEOPLE — People | Exactly the RES-POP group artwork. | Identical to RES-POP. Identical; no selected check baked into art. | Identical three-head group. | Identical to RES-POP. |
| CMD-GOALS — Goals | One partly unfurled vertical oat parchment scroll with rolled top/bottom edges; blank surface, no lettering, seal, quill or check. | Frontal, top/bottom edges horizontal. Open for reading; no completion indication. | Tall scroll rectangle with curled top and bottom. | I03 paper; I09 roll recess; I04 lit edge. |
| MED-MOUSE — Mouse medallion | Natural mouse with two large round ears, pointed muzzle and fine whiskers; plain shared tunic. | Eye-level,30° three-quarter toward screen-left; head-and-shoulders. Neutral attentive; clothed; common roundel/overlay. | At24px diagnostic: two large round ears plus protruding fine muzzle. | I08 fur; I03 muzzle; I10 inner ear; I06 tunic. |
| MED-MOLE — Mole medallion | Natural mole with low rounded head, broad projecting nose, tiny eyes and no prominent external ears; plain shared tunic. | Eye-level,30° three-quarter toward screen-left; head-and-shoulders. Neutral attentive; clothed; no shovel, hat or spectacles; common roundel. | At24px diagnostic: low earless dome and broad blunt nose. | I12/I09 fur; I03 muzzle highlight; I10 small nose; I06 tunic. |
| MED-OTTER — Otter medallion | River otter with broad whisker pads, small round ears, strong tapered neck and cream throat; plain shared tunic. | Eye-level,30° three-quarter toward screen-left; head-and-shoulders. Neutral attentive; clothed; no sailor scarf or profession prop; common roundel. | At24px diagnostic: broad double-lobed muzzle and small low ears. | I09 fur; I08 lit face; I03 throat/pads; I06 tunic. |
| MED-SQUIRREL — Squirrel medallion | Natural squirrel with upright tufted ears, pointed muzzle and one bushy tail arc behind screen-right shoulder; plain shared tunic. | Eye-level,30° three-quarter toward screen-left; head-and-shoulders. Neutral attentive; clothed; tail rests, no nut or weapon; common roundel. | At24px diagnostic: pointed/tufted ears and a broad tail crescent. | I08 fur; I10 warm fur accents; I03 muzzle; I09 tail shade; I06 tunic. |


Population and People share the identical group artwork. Ready food and Food
share the identical bowl artwork. There are16 logical rows but14 distinct art
designs, including four medallions. Shared IDs still need all required surface/
size exports. This may change a quote's work allocation; it does not establish a
different vendor price or approve spending.

### Medallion frame, common to all four species

Head-and-shoulders, eye-level,30° three-quarter turn toward screen-left, eyes
level, neutral attentive expression. Natural animal muzzle/ears/eyes; no human
face. Wear the same plain I06 work tunic with an I03 neck edge, no hat, hood,
rank, jewelry, weapon or occupation prop. Clothing is not a job assignment.

Circular opaque I03 field and thin I07 brass ring, not a free bust. At48px the
outer roundel is44px diameter centered in the canvas; ring1px. At64px it is60px,
ring1.5px. One separate oak sprig at lower-left, bounded6×8px at48 and8×11px at64;
no wreath, acorn clusters or decoration over the face. Frame/sprig are a shared
authored overlay, not independently regenerated for each species. Subject crop
ends at upper chest; ears remain inside the ring with clear separation. Squirrel's
tail arc may rise behind one shoulder within the roundel without hiding the head.
Generate subject artwork separately from that frame when the tool permits.
Medallion frames have no external cast shadow; use internal face/cloth shading
under the same light. Keep the entire frame and sprig inside the export canvas.

Actual production sizes are48/64px. A24px reduction is a **diagnostic species test**,
not a newly authorized24px resident portrait. Remove the sprig in that diagnostic
and retain ear/muzzle/tail distinctions. Never shrink the whole journal header
or lose its existing name, rates or XP merely to enlarge portrait art.

## 6. Sheet preparation, evidence and budget boundary

Two images from one call do not by themselves establish a locked family. Every
call receives the identical palette, light, framing, relevant reference images
and exact requested asset IDs. If the provider supports conditioning on a chosen
probe, retain that probe as an additional style input in subsequent calls.

For a three-cell purpose-made sheet: three equal cells in one row, objects fully
separated with at least12.5% empty margin per cell; no cell-border art, captions,
lettering, decorative sheet background or touching shadows. Do not place two
states of one icon where three distinct IDs were requested. Save the original
sheet and crop manifest. Validate actual output dimensions/alpha; generator
instructions are not proof. A failed cell stays OPEN; do not spend reserve without
the authorization required by the paid-asset process.

For each of the12 icon rows, show native24px on PANEL and PAPER plus its silhouette
mask, beside the locked label and reference. For species show48/64 plus24px
diagnostic. Check all declared surfaces/states after local palette cleanup.
Record exact missing silhouette, anatomy, alpha, crop or contrast failures.
Visual review is separate from a mechanical pass. No asset has been generated
or visually accepted by this lock itself.

Claude's quote is recorded as a **proposal**: floor90, reserve30, ceiling120 in
the quoted units; the proposed two-call probe is18. Vendor model availability,
units, actual price and balance are not verified here. This message approves
reference use and supplies design decisions, **not** that quote or any paid call.
Keep the lead-only itemized-spending process in `docs/design/paid_asset_process.md`.
Prepare references/prompts/sheets and other independent work now; paid generation
requires Brendan's explicit approval of the relevant itemized tier.

## Exact next handoff

Read this lock and DEC-036; use supplied images directly, including IMG-25.
Prepare the two style-probe briefs with the same objects, palette and lighting so
their finish can be compared. Suggested fixed comparison group: ready-food bowl,
flame/embers, timber stack. Do not change object identity between probes. Reuse
the prior art concept as the finish reference and the supplied sources as direct
material/anatomy inputs. Show the itemized probe request if still awaiting approval;
do not reopen these seven settled design questions or demand replacement references.
