# Woodland UI art finish — the visual quality bar

2026-09-11 · SET-UX-VIS-002 revision3 §2.4–2.5 · Task04.5 art direction.
**Aesthetic ambition adopted; generated concept remains a candidate, not user-approved art.**

Brendan clarified that the comparison must address visual appeal, not merely
function. The first shell and the first programmatic target both underdeliver:
uniform flat rectangles, repetitive thin outlines, generic line symbols, weak
material identity and insufficient illustration. The later target improves layout
but still reads as a software theme. Claude must not treat that as finished art.

## What the comparison means visually

The [RTS research](rts_ui_research.md) contains sources and direct image observations.
Our aesthetic interpretation is that Anno's material contrast, Against the Storm's
illustrated objects and characters, and Frostpunk's distinctive framing give those
interfaces an authored identity. Their UI carries art direction independently of
the world behind it. Northgard and AoE show why that identity also needs restraint.
We want the warmth of a woodland community expressed through a keeper's journal.
This is not an instruction to reproduce any source game's assets or period styling.

## A concrete candidate

[The new art concept](visuals/05_woodland_art_concept.png) demonstrates painted object
icons, a bound paper journal, illustrated mouse identity, layered edges and an
individual command-dock silhouette. It deliberately uses a quiet background so
terrain beauty cannot disguise weak UI art. The original generated image and
[prompt](woodland_art_prompt.txt) are preserved with [provenance](woodland_art_manifest.json).

The image is AI-generated concept art, not a Godot screenshot, valid starter state,
asset atlas, exact layout template or accessibility pass. Requested1920×1080 was
not the delivered pixel size; use the manifest's measured dimensions. A source
slide supplied material/anatomy inspiration for this concept. DEC-036 now
explicitly confirms direct supplied-image use for image-to-image and builds; the
earlier restriction was incorrect. Source mechanics still require their owners. The pictured mouse is an invented generic
species illustration, not a verified portrait of Warden Rowan.

### Concept deviations Claude must not implement

- The concept makes resources, time and map surfaces paper. **Keep the current
  FOREST/JOURNAL role mapping** pending a recorded design change. Bring craft into
  the forest surfaces through borders, relief and painted icons instead.
- Panels and icons in the image exceed some current logical dimensions. Preserve
  the owning layout; use the explicit icon change below, never measurements from
  this image. No occupied-area or narrow-profile qualification is claimed.
- Some labels are serif, unlike the prescribed Sans roles. Use the exact Noto
  roles from the amendment; generated lettering is not a production font.
- The resident panel omits hourly rates, XP and required unavailable states.
  Implement all required content. Illustration must yield before information.
- The map depicts invented terrain and buildings. The real minimap reads real
  world state. The concept cannot be loaded as its background or passed as a save.
- Texture crosses text in the concept. Production text surfaces stay flat and
  opaque; paper grain is confined to non-text margins. Generated shadows and
  highlights have not been contrast-tested.

## Required art deliverables

These twelve art checks refine UXV-006–012/019/032/040. They supplement the existing
42 requirements and A-cases; they do not replace them with a new functional scope.

| ID | Required finish | Review evidence |
| --- | --- | --- |
| ART-UI-01 | FOREST has a crafted cover edge; JOURNAL has a paper edge and binding treatment. The center of each text region retains the exact solid token color | Native close-ups with art on/off; A04/A06 |
| ART-UI-02 | Produce separate silhouettes for resource tray, time group, map folio, journal and command dock. Do not give every container the same rounded outline | All five components together on a neutral background; A06/A22 |
| ART-UI-03 | Author a coherent watercolor/ink family for ready food, fuel, wood, stone, population and beds. Show actual object form and controlled light/shadow, not enlarged monochrome line icons | Source files plus actual24px and32px contact sheets; A06 |
| ART-UI-04 | Author matching build, zone, work, food, people and goals object icons, reusing identical concepts where appropriate. Wide/standard TOOL_COMMAND icons become24 logical px instead of18; all other toolbar geometry stays unchanged. Narrow retains16px symbolic variants | Actual52-high wide and44-high narrow buttons, labels and all states; A04/A06/A08 |
| ART-UI-05 | Retain simple optical SVGs for close, check, lock, warning, camera, pause, date and other small functional controls. Painted artwork never obscures a required state marker |16/18/24px control sheet and focused/selected/disabled examples; A04/A06 |
| ART-UI-06 | Produce four illustrated generic species medallions: mouse, mole, otter and squirrel. Use original anatomy informed directly by IMG-25. Deliver48px and64px optical variants; fit within existing header/wrapping rules | Four consistent head/body silhouettes with species labels; no unique biography or portrait claim; A06/A12 |
| ART-UI-07 | Decorative vocabulary is oak leaf/acorn, a binding seam and a restrained page edge. Ornament belongs at component anchors, not around every row. No repetitive vines, thick armor frame or gold around every value | Full-scale HUD and thumbnail review; A06/A22 |
| ART-UI-08 | Keep a single consistent shallow relief direction. Foreground edges separate components without large bevels, glass highlights or an inner box around every datum | Component states and neutral-backdrop capture; A04/A06 |
| ART-UI-09 | Visual attention goes to name/identity and current decisions, then values, then supporting detail. The frame must not overpower the resident or data | Resident card with rates/XP, long name and narrow scroll; A08/A12/A22 |
| ART-UI-10 | Make the UI convincing on a plain background and over real terrain. A painted village cannot supply the missing visual quality. Different terrain states must not change functional contrast | Matching neutral specimen and native gameplay captures; A04/A19/A22 |
| ART-UI-11 | Deliver editable asset sources and individual exports, stable IDs, provenance, actual bounds and stretch margins. Never crop the generated composite into production panels or bake its text into a texture | Source/export manifest and scene review; A06/A23 |
| ART-UI-12 | Visual QA must report composition, material craft, illustration coherence, typography and setting identity separately from functionality. Correct concrete art defects and record Brendan's verdict without inventing approval | Before/after image review and PENDING/APPROVED/CHANGES_REQUESTED; A22/A23 |

### Asset construction rules

Painted object icons have transparent surrounds, recognizable silhouettes, a
restrained shared palette and consistent lighting. Labels remain present. Their
functional silhouette must meet the contrast contract. ART-LOCK-001 now fixes
the treatment: always I01 dark contour; add I04 separation keyline on FOREST only;
no opaque backing for object icons. Medallions use the declared roundel. Do not assume every watercolor highlight is readable.
Use24px for actual resource icons unless the existing slot permits32px without
changing geometry. No frame size or click target derives from an asset's pixels.

New24px wide toolbar art plus existing14px caption,4px gap and two4px insets uses
50px inside the52px button. Center that stack; keep the existing target, caption
minimum, selected check and focus ring. At narrow sizes use the simpler16px
variant rather than shrinking intricate painted detail until it becomes noise.

Each panel needs separate stretchable edge and nonstretching corner/binding art;
the renderer owns the flat fill. Declare nine-slice margins after actual art exists.
Keep all ornament inside the existing measured panel rectangle and out of text,
focus-ring and hit-target clearances. Remove ornament first on small layouts.
No animation, memory or draw-call budget is invented by this brief. Measure the
result under the existing UI performance contract; cache/reuse shared resources.

Decorative pigments in original illustrations are not new semantic UI tokens.
Text, functional state marks and focus colors still use the prescribed tokens.
The image's warm brass and distressed surfaces are visual inspiration, not sampled
runtime constants. Do not add noise to the approved solid text backgrounds.

## Exact generation decisions

[ART-LOCK-001](asset_generation_lock.md) controls per-asset identity, all twelve
pigment swatches, light225°/elevation45°, bounded shadows, contour variants and
shared medallion framing. It supersedes open choices in the earlier prose or
concept. Direct supplied-reference use is allowed; quoted spend remains unapproved.

## Execution and acceptance

Task04.5b starts with an art asset pass and **one** complete HUD/resident slice.
The lead assigns art/components to game-coder and visual critique to user-qa;
the test runner cannot approve aesthetics. Preserve the existing six-agent model
and shared-file ownership rules. If the executor cannot author the needed art,
report the specific missing asset and keep that art check open. Default icons or
a generic flat panel are not a finished substitute. No paid external asset credits
are authorized by this document.

Read the new concept for art quality, the earlier four references for structural
intent, and the owning text for exact geometry/data/input rules. User sign-off is
still pending. The next deliverable is a native, fully populated resident UI slice
(or an explicitly labeled specimen when its data dependency is blocked) with the
new asset family, plus a narrow version proving the design survives reflow.
