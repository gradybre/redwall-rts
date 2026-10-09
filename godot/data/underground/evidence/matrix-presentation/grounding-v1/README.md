# Common post-skin grounding component

This bundle validates the additive Actor grounding implementation in decision
1080. Independent review by the construction lane accepted the three pinned
source files after reading the actual evidence. No production clearance or tight
culling qualification is claimed.

The original `invocation.json` records the clean test sequence: own assets moved
outside the Godot project, own `.godot` removed, headless editor import, then the
unchanged strict runner through its existing CI suite selector. Assets were
restored on exit. `strict.log` reports 14 tests, 113 assertions, 0 failures and
zero strict/raw diagnostics and leaks.

The first analyzer command incorrectly named repository-level tools that the
Godot LSP requires inside its project. `analyzer.log` preserves that CLI error.
The corrected command used byte-identical ignored mirrors in
`godot/demo/assets/underground-analysis/` for the three tools and checked the
four actual project files:

```sh
python3 tools/gdscript_warnings.py --port 6149 --max 0 \
  godot/demo/cast/underground_actor.gd \
  godot/test/test_underground_actor.gd \
  godot/data/underground/evidence/matrix-presentation/native_compare.gd \
  godot/data/underground/evidence/matrix-presentation/native_grounding_check.gd \
  godot/demo/assets/underground-analysis/capture_underground_profiles.gd \
  godot/demo/assets/underground-analysis/bake_underground_matrices.gd \
  godot/demo/assets/underground-analysis/export_underground_native_source.gd
```

`analyzer-corrected.log`: 0 GDScript warnings in 0 of 7 files. The associated
offline exporter remains a separately reviewed implementation; this component
verdict is limited to the Actor delta, its test and the native grounding probe.

The actual desktop backend was Godot 4.7.2 official ed1daf0bf, macOS OpenGL4.1
Compatibility. Both native commands used `--path godot --rendering-method
gl_compatibility --audio-driver Dummy --script` followed by the respective
`res://data/underground/evidence/matrix-presentation/native_adapter_check.gd` or
`native_grounding_check.gd`. Copied raw logs report 140 total lifecycle assertions
and 8 grounding assertions, respectively, with 0 failures and no diagnostics or
leaks. The grounding probe independently observes rendered pixels: a body whose
skin weight sum is0.5 and an unskinned held item both move32 pixels for the same
common0.5m instance translation.

`python-envelopes.log` preserves an incorrect module invocation, which failed
before collecting the tool's tests. The corrected direct-script invocation in
`python-envelopes-corrected.log` reports52 passed adversarial checks;
`python-reproduce.log` reports10 passed create-only/source-preservation checks.
Those pure-Python results are additional development evidence, not the separate
continuous source proof or a production profile certificate.

The native fixtures intentionally use generous culling bounds. Production
skinned culling uses the palette's pre-common-translation space, while static
parts use original mesh space. Actor-space physical bounds are a distinct output.
