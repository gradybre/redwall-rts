# Transform runtime cache freshness

Decision1075, source pins in `source-sha256.json`. Independent source review accepted the exact two files. Clean Godot4.7.2 import moved this checkout's demo assets aside, deleted `.godot`, ran `godot --headless --path godot --editor --quit`, and used the strict unchanged test runner's singleton shard; assets were restored afterward.

The full runner reports **30 tests /203 assertions /0 failures**. Both strict and raw diagnostics/leak footers are zero, with no expected/tolerated diagnostics. Analyzer command: `python3 tools/gdscript_warnings.py --port 6153 --max 0 godot/scripts/core/transforms.gd godot/test/test_transforms.gd`; result **0 GDScript warnings in0 of2 files**. Raw logs are retained.

These tests prove runtime invalidation, same-value writes, refusal preservation, generation reuse, reset and permanent saturation poison. The explicit restore-invalidation method is exercised; there is no current live Transform restore publisher to claim integrated restoration. This counter grants no movement/profile/occupancy permission.
