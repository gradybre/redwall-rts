## What changed

Players can now open **Plan an underground room** from the demo's Tunnels panel and draw directly on dirt in the running settlement's actual World. The inspector supports shape tools, room purposes, the authored floor catalog, retained drafts, camera handover and explicit confirmation. Without completed access, confirmation explains the refusal and conserves resources. The original camera returns on close; actual World replacement retires the old view and draft. Stall recovery contains mouse, held camera keys, popup windows and keyboard focus.

The integrated checkpoint is `8f6bad86`, including independent scene review. It also contains the reviewed original Room/Route/SurfaceAnchor owner composition, integer footprints, physical excavation/accounting, short-step source/runtime work, current memory accounting and the analyzer correction. No endpoint, worker permission, delivered material or completed room is fabricated by this integration.

This remains a draft implementation. **The first worker-built empty Kitchen is still open.** Paid timber handling/fastening, actual entry dispatch, completed room excavation, furniture/services, the full connector catalog, replacement/renovation, composed saves and 256-resident qualification remain in `docs/tasks/underground-build-queue.json`. Component and preview tests do not close those player workflows.

## Evidence

- Scene acceptance: five official focused suites, **30 tests / 1,132 assertions / 0 failures** after clean assets/cache/import; analyzer **0 GDScript warning(s) in 0 of 6 file(s)** with zero raw editor findings. Each suite reports `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)` and `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- Native Metal/Forward+ acceptance: **74 checks / 0 failures**, five inspected **1280×720** captures. Real Viewport input exercises dirt drawing, floor changes, conserving refusal, close/reopen, an actual clock overload, Tab/Shift-Tab containment and actual UI World Create. Raw import/runtime findings and leaks are zero; sources/project restored. Independent review verified all seven changed source pins and 1,285 native closure paths. [Drawing capture](https://github.com/gradybre/redwall-rts/blob/c713aa5f/docs/validation/evidence/underground-planning-scene-2026-10-05/native-4/planning-drawing.png), [stall recovery](https://github.com/gradybre/redwall-rts/blob/c713aa5f/docs/validation/evidence/underground-planning-scene-2026-10-05/native-4/planning-stalled.png).
- A new exact-`8f6bad86` clean-assets/cache/import/**no-argument** `./tools/run_tests.sh`, all-file `tools/gdscript_warnings.py --max 0` and source/registry/memory checks are running in a frozen owned checkout. This is pending, not a current-head full-pass claim.
- The preceding `ca1edc3f` [CI run](https://github.com/gradybre/redwall-rts/actions/runs/37262123814) passed all 14 jobs on attempt 2; 406 files ran exactly once across eight shards, **11,226 tests / 1,028,131 assertions / 0 failures**, zero unexpected diagnostics/leaks, 272 expected and 353 tolerated diagnostics. Its local no-argument run passed **11,226 tests / 1,028,141 assertions**, but the raw analyzer editor log had eight errors despite a zero-warning summary. Those findings led to the reviewed preload and analyzer-lifetime fixes; the failures are retained. No diagnostic or warning gate was weakened.
- Current logical memory publication is reproduced and independently reviewed. Global allocation remains **99,999,806 bytes**; constructor maximum **8,185/8,192 bytes**. These are logical/source accounting, not measured native RAM or 256-resident qualification. Decision-number and build-queue validation pass.

Exact commands, source hashes, rejected iterations and independent review are retained under `docs/validation/evidence/`. No paid asset generation was used.

## Declarations

DEVIATIONS: none
SURVIVED_MUTANTS: none
BLOCKED: none
