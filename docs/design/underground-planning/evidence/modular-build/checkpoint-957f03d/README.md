# Frozen integrated checkpoint957f03d

This checkpoint is **not accepted**: the full no-argument suite and all35
specification checks passed, but the unchanged zero-warning analyzer refused
an archived rejected script with a broken superclass path.

Frozen source/HEAD: `957f03d72261962cb825057cc8e48b6409bdf2fa`.
The exact CI procedure moved demo assets aside if present (none were present),
deleted this checkout's `godot/.godot`, performed a clean editor import, and ran
`./tools/run_tests.sh` without arguments. The wrapper then ran the whole analyzer
with `--max 0`. Its finally block verified asset state, all source pins and HEAD
were unchanged. Exit1 is retained in `invocation.json`.

```text
10594 test(s), 969310 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
1 GDScript warning(s) in 1 of 1178 file(s)
```

Clean import10.811s; full suite1323.859s; analyzer242.472s. The warning is
`data/underground/mole-worker/evidence/contact-qualification/stair-proof-v2-rejected/capture_stair_motion.gd:1`:
its retained historical superclass path cannot resolve from that archive.
The correct repair preserves its bytes as non-executable evidence, with explicit
path mapping; neither a warning allowance nor a modification of historical
rejected source is authorized. That repair is newer than this frozen run.

All35 specification commands and raw logs are under
`docs/validation/evidence/underground-spec-957f03d/`. The reusable exact wrapper
is `../checkpoint-499bfd73/reproduce.py`; run from the target checkout with a
fresh output directory. All commands, times and original source digests are
retained beside this README. Later FinalFacts, descent, sequence and Contacts
changes require their own integrated checks and are not included here.

This remains component evidence. The full playable room lifecycle, persistence,
1280×720 acceptance and256-resident qualification are still open.
