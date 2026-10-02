# 1049 — Follow-ups this lane left open: the scale subprocess's warnings, the grass speckle, the gait scrape

Date: 2026-10-02 · Status: Proposed (written up, not built)

## The scale subprocess's other `WARNING:` lines (decision 0998's P2)

**Why it is not built here.** P2 is a follow-up to decision 0998. Decision 0998
and the code P2 changes (`test_scale_stress.gd`'s `_errors_in` and
`_run_harness`, and `scale_test.gd`'s close) exist only on `fix/codex-review`
(PR #221). That PR was still open when this lane finished. The brief said to
merge `origin/master` before starting this item, so that the item lands on
#221's code. Building it on master's older `test_scale_stress.gd` would conflict
with #221 throughout the same functions. So the exact change is recorded here,
to apply once #221 has merged.

**The change, on #221's `godot/test/test_scale_stress.gd`:**

- **A named tolerance list.** `const TOLERATED_WARNINGS: PackedStringArray`
  holds the machine-dependent fragments: today only
  `"it plays silent until they are staged"`, the sound cues' warning where the
  demo's assets are not staged, as in CI. Each entry gets a comment saying why
  it depends on the machine and not the code, as `tolerate_diagnostic` requires
  (`test/framework/test_case.gd`).
- **`_errors_in` becomes `_findings_in(lines)`.** As now, it adds `SCRIPT
  ERROR`, `ERROR:` and `SCALE-ERROR` lines, the exit report apart. It also adds
  every line that `begins_with("WARNING:")`, is not an exit-report line, and
  contains none of `TOLERATED_WARNINGS`. Both live tests use it. The fault run
  must stay free of findings, so a warning in it fails too.
- **A pure test of the filter**, `test_the_subprocess_fails_an_unnamed_warning`,
  in the style of `test_the_exit_check_allows_no_count`. It checks that:
  - a "plays silent" warning is no finding;
  - any other `WARNING:` line is;
  - the exit report's object warning is still counted only by `exit_report`,
    not twice.
- **Before the tolerance list is fixed**, run the live test once with the
  assets moved aside and once staged, and list every `WARNING:` it prints. The
  list must name only what those runs show. The outer suite log does not carry
  the subprocess's other lines, so this needs the run itself.
- **The scale tool** (`godot/tools/scale_test/scale_test.gd`) needs no change.
  It prints the engine's lines as they come; only the test reads them.

**Mutation targets once built:** the `WARNING:` branch removed; a tolerance
widened to match everything; the exit-report exclusion dropped.


## The grass speckle (visual polish)

**What is known.** "Grass speckle" survives only as a tracker reminder, carried as
one of the "OLD PLAN leftovers" and later listed among art pass 2's "free fixes".
No decision, README section or review describes the symptom: where it shows, at
what zoom, by day or night, or with which assets.

The only speckle in the records was fixed by decision 0301: the selected
resident's x-ray silhouette speckled where a grass card crossed the body, and
it now compares view distances. Batch 8 (`integrate/review-batch-8`) does not
touch the grass either.

**Looked for here.** Frames were captured windowed at 1920x1080 with staged
assets, paused by day:

- the spotlight frame, a near view, cropped and enlarged 2× over the square's
  grass;
- the Routes layer's wide frame, at camera distance 52;
- the Woods layer's frame.

None showed speckle on the ground or the grass cards. These frames are in the
session scratchpad, `followups_check/`.

**Not built: it needs a repro.** A guess at a fix would change the grass without
evidence. **Question for Brendan:** where was the speckle seen? Possible places:

- the ground's grass texture shimmering when the camera moves, which would be
  texture aliasing or mipmaps;
- grass cards flickering at the fade distance;
- dots on the ground at night;
- something on the Windows build only.

A screenshot or the camera position is enough to start.

## The gait's swing-foot scrape (visual polish)

**What is known** (decision 0202, and 0196's open items). In all 40 walk, run
and carry clips the swinging foot drags 0.1–1.2 m along the ground
(`ground_scrape_m`, per clip), and the planted foot hovers. Meshy's retarget
puts the swing foot below the planted one, and the grounding pass stands each
clip on its lowest foot, the swing foot.

Decision 0202 already ruled out a fix in code: "A pin cannot do it. Retarget or
author the gait cycles."

**Not built: it is animation work, beyond a small fix.** The options:

1. Re-author or re-retarget the gait cycles: walk, run and carry for each
   creature. This is the real fix.
   - Meshy re-rigging and re-animation spends paid credits, which needs
     Brendan's approval (decision 0961).
   - In Blender, it is a hand pass per clip.
2. A procedural two-bone foot IK at runtime that lifts the swing foot clear. Its
   costs:
   - work per resident per frame;
   - against CLAUDE.md's "no AnimationTree per resident" for crowds;
   - only the up-to-24 conventional skeletal actors could have it.
3. Accept it for the demo.

**Recommended: (1)** in the next paid art pass, with the gait clips listed in the
asset ledger.
