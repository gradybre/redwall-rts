# Building mockups (design references)

Two small 3D mockups that Brendan reviewed in chat on 2026-10-14 and 2026-10-15. Each file is self-contained: one
HTML page with its own CSS and script. **They contain no game code.** The game shares no code with them, and nothing
in `godot/` loads them.

| File | What it shows | Approved as | Record | Live copy |
|---|---|---|---|---|
| `mound-home-3d.html` | A Mound home. The hill is heaped to fit the painted rooms, which are dug, framed and topped (heap → dig → frame → top). Doors and windows are placed on the rooms' outer edges. Includes "Add a pantry" (the hill grows), a door-colour choice and a section view down to level 1 | "This looks good, let's build this into the plan" (2026-10-15) | [decision 2001](../../../decisions/2001-mound-homes.md) | https://claude.ai/artifact/EQ31p3ZtSQ42KU8EvA7GVt |
| `burrow-walls-3d.html` | A level-1 burrow drawn as square cells or with rounded, hand-dug walls | "Let's build this" (2026-10-15) | [decision 1914](../../../decisions/1914-rounded-hand-dug-walls.md) | https://claude.ai/artifact/Gf55LFe2j2wfMTPeGV7hoC |

## Opening them

Open a file in a web browser. They need the network for three libraries:

- three.js r128 from cdnjs (`cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js`);
- its OrbitControls from jsDelivr (`cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js`);
- the Alegreya fonts from Google Fonts.

Without the network the page shows "The 3D view could not load". The files are the published pages' bodies, exactly
as approved. They have no `<!doctype>` or `<html>` wrapper, because the artifact host adds one. A browser opens them
as they are.

## Using them

- **Their scripts are the reference geometry.** For example `heapH`, `scoopH`, `slopeSpot` and `buildEdges` in the
  mound mockup, and `sdf` and `heightAt` in the walls mockup.
- **Their numbers are illustrative.** The mound's 3 m room depth, 1 m cover, 3.6 m berm, door yard and 2.2 m window
  height are candidates, not rules. Decision 2001 §5 lists each value and where it differs from an adopted rule, and
  its questions P-2001-4 to P-2001-6 fix them. Decision 1914 E2 records where the rounded walls in the game depart
  from the walls mockup.
- **No reference image is inside them.** Brendan's four Bag End reference images inspired the mound's door front,
  garden and dressing. They are not in the repository and their provenance is unknown (decision 2001 §4, DEC-036).
  Everything in the mockup is drawn by its own script.
- **Do not edit these copies** to try new ideas. Make a new file, so the approved state stays as it was approved.
