# SAVE-J2-R02v2 validation

Base d495b9c (PR150). Exact planner35-field capture/restore and section8 adapter.

- Focused:256tests/3369assertions/0failures; actual farm, sow, forage and hive state, stale-job continuation, dirty-order job IDs, independent buffers, malformed-source/output safety and all21diagnostic resets.
- Full local suite:4699tests/183880assertions/0failures in tests-registry-fixed.log. The first attempt stopped before Godot because the new stateless schema was not yet classified; raw tests-first.log retained.
- Fifteen static gates pass in contracts-first.json. Capacity proof regenerated for shared constant aliases; same602canonical records/553packed fields/52owners.
- Shared dependency census:20helper modules including helper itself,22codec closure; no cross-module cycles. Existing int_math/save_codec self-preloads support their inner classes.
- Wire baseline before/after extraction retained in the sibling contract evidence:384203-byte schema2 section; all3hashes unchanged.
- Baseline shutdown findings unchanged:553objects/33resources. Focused run exits cleanly. No native, full-save, first-playable or release acceptance inferred.

The author packet/result/events and parent integration patch preserve code provenance. Independent source review accepted with8findings; astra-review-disposition.md records fixes and parent evidence for packet limits. Final focused260/3625/0, full4703/184136/0 and15static gates pass. Three targeted mutations are killed; source restored. Godot import passes. CI/merge remain pending.
