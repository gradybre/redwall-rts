# Preserve rejected source without executing the archive

The full integration checkpoint at957f03d passed10594 tests and969310 assertions with zero strict/raw unexpected diagnostics or leaks, but its full analyzer failed on one of1178 files. Godot discovered the retained rejected `stair-proof-v2-rejected/capture_stair_motion.gd` as executable source. Its historical relative superclass path does not resolve from the archive directory. The current capture script was not the failing source.

This packaging correction renames that archived file to `capture_stair_motion.gd.txt` and its archived UID to `capture_stair_motion.gd.uid.txt`. **Both files retain their exact original bytes and SHA-256 values.** No historical source is repaired, no failed evidence is relabelled, and no analyzer gate is weakened. The current live capture remains `30ba059c19b75608f3eef01c67780817c1257b4a0b490d63f0f1e1ab5adb339d`.

`history-sha256.before.json` preserves the exact previously accepted146-row history manifest. `relocations.json` is the explicit old-path/current-path mapping. The current146-row history manifest changes only those two locator keys; every expected file hash remains unchanged. Historical native run/spec/source records are untouched. When resolving the preserved before-manifest, use this exact mapping for the two archived paths rather than treating it as current executable source.

The original failed full-checkpoint analyzer log, JSON and invocation are copied byte-for-byte here; their canonical location is `docs/design/underground-planning/evidence/modular-build/checkpoint-957f03d/`. The full suite's success is not a successful full analyzer or whole-checkpoint qualification.

After relocation, the owned content-directory analyzer reports `0 GDScript warning(s) in 0 of 9 file(s)`, exit0. The census contains no rejected executable GDScript archives. This scoped check does not replace the next integrated full analyzer. No engine test suite or native capture was repeated for a byte-preserving archive packaging change.

The source and metadata correction is ready for independent review; only the non-executable locators, current history lookup and this explicit provenance record change.
