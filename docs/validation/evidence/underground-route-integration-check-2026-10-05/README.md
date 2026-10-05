# Exact ca1edc3f integration check: editor gate failed

The unchanged full test run passes **406 suites, 11,226 tests, 1,028,141 assertions, zero failures**. Its strict and raw test error/warning/leak counters are zero (272 expected and 353 tolerated diagnostics are classified by the existing runner). The analyzer reports zero warnings in all 1,252 GDScript files, but the editor process emits **eight raw parse/load errors**. The wrapper therefore exits 1. This is not a green integration milestone.

All work ran in the new own `codex/underground-route-integration-check` worktree at `ca1edc3f62b09300f0e36ff0dfbcb1172a5f90ac`, after a fresh fetch of origin/master and a permitted fast-forward. `worktree.json` records creation. No source, registry, queue, expectation or gate was changed. Each invocation records its separate user directory, exact source manifest and restoration. All 10,551 original tracked pins still match; original project, sidecars and assets state are restored. No engine remains running; port 6465 is released.

## Executed checks

| Receipt | Actual result |
| --- | --- |
| `full-ca1edc3f/` | Clean import passes; unchanged `./tools/run_tests.sh` passes 11,226 / 1,028,141 / 0; analyzer 0 / 1,252; raw editor eight errors, wrapper 1 |
| `analyzer-retry-1/` | Fresh cache/import and isolated userdata; analyzer 0 / 1,252; raw editor log byte-identical to original, wrapper 1 |
| `lsp-order-1/` | Bounded seven-file diagnostic; five raw errors first occur while opening `demo_stall_banner.gd`; other three not reproduced, wrapper 1 |
| `input-map-1/` | Unchanged `test_demo_build.gd` singleton: 6 / 224 / 0, all strict/raw/leak counters zero; read-only actual InputMap census |
| `input-platform-1/` | Read-only actual InputMap versus base settings and macOS override counts, exit 0; no map mutation |

Every command, timing, executed wrapper, original and isolated project digest, source manifest, and restoration result is retained in each directory. The full suite ran once. The only follow-ups were the authorized analyzer retry, bounded seven-file diagnosis, unchanged singleton replay and two read-only InputMap probes. `audit_results.py` audits preserved receipts and source bytes without starting an engine; `audit.json` is its current result.

To reproduce the original full procedure, use a clean own checkout at the exact checkpoint, then:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B docs/validation/evidence/underground-route-integration-check-2026-10-05/reproduce.py --expected-commit ca1edc3f62b09300f0e36ff0dfbcb1172a5f90ac --out /absolute/new/evidence/output
```

The wrapper runs clean asset isolation/cache removal/import, the no-argument CI test procedure and max-zero full analyzer, then restores project/assets/sidecars in `finally`. A nonzero raw diagnostic gate stays a failure even if the LSP analyzer JSON is empty.

## Exact local/CI ten-assertion difference

Same-head GitHub run **37262123814**, attempt 2, passes 406 suites / 11,226 tests / **1,028,131 assertions** / 0. Its raw compressed shard logs and aggregate/run metadata are copied byte-exact under `ci-reference/`; original locators are root's `underground-short-step-itinerary-2026-10-05/ci-ca1edc3f/`. The copied raw/gzip hashes are independently verified. All 406 suite names and all 11,226 passing method names match the local full log exactly.

The unchanged `test_demo_build.gd::test_f11_is_bound_to_nothing_else` makes one assertion for each actual `InputEventKey`. There are 17 other fixed assertions in the suite. The same-source singleton replay yields 207 key events on macOS, so **17 + 207 = 224 assertions**. CI reports **214** for that suite. The separate actual ProjectSettings/InputMap census proves 197 base key events plus ten macOS additions, so **17 + 197 = 214**. The eight built-in overrides are:

| Action | Base | macOS | Difference |
| --- | ---: | ---: | ---: |
| ui_close_dialog | 1 | 2 | 1 |
| ui_text_backspace_all_to_left | 0 | 1 | 1 |
| ui_text_delete_all_to_right | 0 | 1 | 1 |
| ui_text_caret_line_start | 1 | 3 | 2 |
| ui_text_caret_line_end | 1 | 3 | 2 |
| ui_text_caret_document_start | 1 | 2 | 1 |
| ui_text_caret_document_end | 1 | 2 | 1 |
| ui_filedialog_focus_path | 1 | 2 | 1 |

This accounts for the complete net ten-assertion difference. The original no-argument log does not emit per-suite assertion totals, so this conclusion uses the bounded unchanged singleton replay and actual platform settings; it does not claim a missing original per-suite receipt. No assertion count is normalized and no test or diagnostic expectation is relaxed.

## Raw editor failure and bounded diagnosis

Both full-editor attempts produce the same eight raw lines: the stall banner cannot resolve `ui_manager.gd` / infer its constant and the village dependency fails (five lines); `ui_specimen.gd` cannot resolve `ui_shell.gd` / infer its constant and fails loading (three lines). All named files exist and match the frozen manifest. A fresh `.godot` cache/import reproduces the exact bytes. No alternate `--editor-project` is used, and no competing port-6465 process or source change was observed. Thus a foreign source/cache race is not established.

The seven-file LSP trace first has no errors after opening/closing the village. Opening the stall banner adds the five village/UIManager errors. Opening UIManager, resident card/snapshot, UiShell and specimen afterward adds none. This narrows one trigger; it does not prove the underlying engine dependency cause or reproduce the second family. Diagnosis stops at this authorized bound.

Read-only source findings and the smallest proposed follow-up, **not implemented or proven fixes**:

- Root's UI presentation owner can remove the unused `UiShell` preload in `scripts/ui/ui_specimen.gd:15`. It has no other use in that file.
- `demo/ui/demo_stall_banner.gd:38,42` loads the entire UIManager class solely to alias its `CLOCK_OVERLOAD_CODE`. The smallest root-owned UI seam is an independent shared notice-code constant used by both banner and UIManager, preserving the same code and public behavior. This avoids that unnecessary autoload-class dependency; a corrected-source analyzer run must establish whether it closes the observed trigger.
- `scripts/ui/ui_resident_card.gd:60` preloads/instantiates `ui_resident_snapshot.gd`, while the snapshot preloads the card at line 49 solely for labels, fields and formatting. This is a real source cycle reachable from the UI graph, but this probe does not prove it caused either failure. If still required after the first small fixes, root's UI owner can extract the shared immutable labels/formatting into one independent helper while retaining public wrappers and tests.

No runtime-owner/source lease was taken for these proposals. The editor gate remains open. Native memory, performance, visual presentation and complete playable-room acceptance are not claimed by this evidence.
