# Paid asset generation — the standing process

2026-09-11 · Executor process, adopted at Brendan's instruction. Applies to **every**
future request that would spend money, not just task 04.5.

Paid tools connected to this project: **Meshy** (image and 3D generation, credits are
real money) and **Blender MCP**'s generation bridges (Hyper3D / Hunyuan3D, also paid).
Blender's own modelling, and its PolyHaven / Poly.pizza / Sketchfab asset fetches, are
not charged by us but are covered by step 1 anyway because tool choice is the decision.

## The rule

**No tool that spends credits is called until Brendan has approved a specific,
itemised list.** A subagent can never call one: subagents run unattended and cannot
obtain consent, so their briefs say "forbidden" and the decision stays with the lead.
This is not a judgement call an agent gets to make on cost grounds.

## Step 1 — Establish tool fit before asking for anything

Answer in writing, per asset family:

| Question | Why it decides the tool |
| --- | --- |
| Is the output 2D or 3D? | Meshy's 3D endpoints and Blender are for meshes. A 2D UI icon needs neither. |
| Is it geometric or illustrative? | Nine-slice edges, stretch margins, tiling seams and small state glyphs are **authored**, never generated — generation cannot hit an exact stretch margin. Painted objects and characters are the reverse. |
| Does the family need identical lighting? | A shared 3D render rig gives that by construction; so does one generation call producing a family sheet. Choose one deliberately. |
| Does a usable reference already exist in the repo? | `ImageReference/` and `docs/art-reference/reference_manifest.json` hold 28 catalogued images. Check before paying to create what is already on disk. |
| Is direct reference use authorized? | **For Brendan-supplied images/material: yes, DEC-036.** IMG-25 and the supplied image library may be direct image-to-image/image-to-3D/drawing/modeling inputs. Unknown creator metadata is retained, not converted into an observe-only restriction. Record source and transformations; paid generation still requires the itemized approval below. |

Conclude with an explicit **not needed** list. Naming the tools we are *not* paying for
is as much a part of the answer as the one we are.

## Step 2 — Extract every specification that would raise quality first

Generation quality is set by the brief, not the budget. Before asking for credits,
push Astra and Brendan for the details that are still open. Ask for more than feels
polite; an unanswered question becomes an invented one at generation time.

For current UI art, read `ui_refinement/asset_generation_lock.md`: its seven
design decisions are settled, with final visual review still pending. Reopen only
a concrete conflict or user change; unanswered future assets still use this list.

The recurring list, which has applied to every asset family so far:

1. **Per-asset object identity** — exactly what object, from what angle, in what state.
   Name every ambiguity you can find rather than resolving it yourself.
2. **Palette lock** — explicit hex values for *illustration*. UI tokens govern chrome;
   they do not tell a generator what colour a stew is. Without this the family drifts
   warm or cold between calls and stops cohering.
3. **Light direction and elevation**, stated as an angle, plus the maximum shadow extent.
4. **The small-size contract** — what single shape must survive at the smallest real
   size. This is where generated art fails most often and it is rarely written down.
5. **The legibility fallback ruling** — contour, opaque backing, or neither. A visual
   identity decision, not an implementation detail.
6. **Framing and crop** for anything character-shaped.
7. **The derivation boundary** for each named reference: observe-and-describe, or
   derive-directly. Use the existing written authorization: DEC-036 already settles direct use of Brendan-supplied material. Do not ask again for those references.

## Step 3 — Present the itemised approval list

One table. Per line: what is generated, which tool and model, unit cost, quantity,
line total. Then a floor, a ceiling including an iteration reserve, and what each
tier buys. State plainly what happens if it is declined — usually that a specific
check stays OPEN rather than that the work stops.

Nothing is called before the reply. Approval covers the listed items only; a new
family or a second iteration round is a new request.

## Step 4 — Record provenance in the same commit as the asset

Every generated file lands with its prompt, model, seed where available, credit cost,
date, and the licence position, in `godot/ui/ASSETS.md` and the owning manifest.
An asset whose provenance is not in the repository is not finished.

Purpose-made object/species sheets may be cropped into individual exports, with
cell coordinates and originals retained. This is distinct from cropping a finished
HUD screenshot into production panels. Supplied images may condition generation
and guide direct builds; ART-LOCK-001 fixes the current UI asset identities.

Generated art is **source material**, not a shipped asset: it gets traced, cut,
colour-corrected to the locked palette and exported at real sizes. Never crop a
generated composite into a production panel and never bake its text into a texture.

## Step 5 — Judge the result against the standard, not against the cost

Having paid for an image does not make it good. The visual verdict is Brendan's and is
recorded separately from functional test results. If a generated family misses the bar,
say so and keep the check OPEN; spending credits is not evidence of completion.
