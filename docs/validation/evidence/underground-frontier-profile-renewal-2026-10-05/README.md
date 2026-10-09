# Frontier worker profile source renewal

`source-compatibility-review.json` records the independent review of all nine
current consumers at 8003bfe1, with exactly three changes from the original
v3 publication. `consumer-delta.diff` retains those changes. The old geometry
wire is unchanged; its SHA-256 remains
`a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204`.

`native-1/` is the fresh actual canonical program-5 replay. It contains the
original commands, source maps, binary matrices, reports and 64 captures.
The original harness reports 9,336 assertions, zero failures, 1,504 poses and
469,248 exact matrix scalar comparisons. Import/native commands both exited
zero with no raw diagnostics. `native-reverify-1.log` is an additional offline
replay of the original independent oracle.

```sh
python3 -B tools/test_renew_work_approach_profiles.py
# Requires the existing local NumPy runtime, not new asset generation:
python3 -B godot/data/underground/mole-worker/work-approach-v1/run_canonical.py \
  docs/validation/evidence/underground-frontier-profile-renewal-2026-10-05/native-1 --verify
```

The eight publisher tests cover every live consumer, the historical source
replacements, all native proof files, old publication and review mutation,
reviewed commit mismatch, output overwrite, path escape and symlink refusal.
The publisher creates a new immutable output directory and rechecks the
entire source closure immediately before writing.

`run_current_native.executed-1.py.txt` is the exact wrapper used. Its outer
cleanup failed after the native harness succeeded because Godot extracted
15 additional texture PNGs. `staging-recovery.json` preserves that failure
and the subsequent bounded cleanup. `run_current_native.py` contains the
corrected helper, separately checked in `staging-cleanup-tests.json`.
Existing asset files and the borrowed source checkout were preserved.

The native scene exercises a synthetic physical provider and has no real
room or HUD. `visual-inspection.json` therefore accepts no whole-room visual
or input requirement. Production support, work, persistence and performance
gates remain open. See decision 1170.
