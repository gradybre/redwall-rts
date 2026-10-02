# 1049 — Follow-ups this lane left open: the scale subprocess's warnings, the grass speckle, the gait scrape

Date: 2026-10-02 · Status: Accepted for the scale warnings (built); Proposed for the grass speckle and the gait scrape (written up, not built)

## The scale subprocess's other `WARNING:` lines (decision 0998's P2): built

PR #221 merged, which put decision 0998 and its code on master. This item was
then built on that code, after merging `origin/master` into this branch.

**`godot/test/test_scale_stress.gd`:**

- `TOLERATED_WARNINGS` names two machine-dependent fragments:
  - `"demo assets are not staged (tools/stage_demo_assets.py); running on
    placeholders"` (`demo_village.gd`);
  - `"it plays silent until they are staged"` (each sound cue).

  Both are printed only where the demo's assets are not staged, as in CI. They
  depend on the machine, not the code, which is the rule
  `tolerate_diagnostic` uses.
- **Measured before the list was fixed.** The real 25-resident run and the
  fault run were each run with the assets staged and with them moved aside.
  - Staged, neither printed any `WARNING:` line apart from the fault run's
    injected exit report.
  - Bare, both printed exactly these two kinds of line, and nothing else apart
    from the exit report.
- `_errors_in` (now static) also returns every line that begins `WARNING:`,
  is not an exit-report line, and contains no named fragment. Both live tests
  already use it, so the real run and the fault run fail on any other warning.
  The exit report's object warning is still counted only by `exit_report`.
- New test `test_the_subprocess_fails_an_unnamed_warning`. It checks that:
  - the named fragments pass;
  - an unnamed warning is a finding;
  - the exit report's warning is not counted twice;
  - only the engine's own `WARNING:` prefix counts.
- `godot/tools/scale_test/scale_test.gd` is unchanged. It prints the engine's
  lines, and only the test reads them.

**Mutation testing:** 3 mutants, all killed. They removed the `WARNING:` branch,
tolerated every fragment, and dropped the exit-report exclusion.

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
