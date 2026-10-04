# Explicit reusable region observation

Final validation used the unchanged strict runner on the complete-manifest singleton shard after moving demo assets aside, deleting `.godot` and a clean headless editor import. Assets were restored afterward.

- Owner: **61 tests / 3,041 assertions / 0 failures**.
- Both strict and raw diagnostics: **0 unexpected errors, 0 unexpected warnings, 0 expected, 0 tolerated, 0 object/resource leaks**.
- Analyzer: **0 warnings in 0 of 2 files**, actual source/test paths, port 6153.
- Independent source review accepted the exact pinned delta; no duplicate full suite.

The rejected historical test is important: GDScript packed-array aliases observe in-place mutation. The existing allocating reader remains unchanged. The separately named reusable reader requires a six-int scratch array, overwrites any aliases deliberately, and supplies no borrowed authoritative columns. Callers must duplicate a result they want to retain. No source/canonical fields or buffers were added.
