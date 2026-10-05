# Final independent scene review — accepted

Reviewer: `ug_construction`, 2026-10-05. Author worktree read only. No engine, cache, project, or foreign source writes were made by the reviewer.

The seven frozen scene files in `acceptance.json` are accepted for actual-world planning presentation. The complete source and all three corrective changes were read independently. No high or medium finding remains in this scope.

The initial review identified held-key/drag camera motion and popup/layer ownership during a critical stall (R1), and a missing explicit Room/Route-owner composition path when reopening after actual UI World Create (R2). Candidate 8 adds the guarded existing camera, clears held/drag/edge/easing state when blocked, dismisses owned popup Windows, places the mouse shield below the original banner, restores its original layer, and uses the existing actual host composition calls on explicit reopen. The old World and its draft are not reused.

Candidate 8 still allowed GUI keyboard focus navigation behind its mouse shield (R3). Candidate 9 now consumes non-mouse input in SceneMode before GUI dispatch while blocked, except the existing banner's Enter, keypad Enter, and Space acknowledgment. Its actual input witness attempts 32 Tab and 32 Shift-Tab presses, arrows, speed 4, and Escape; focus stays absent or inside the banner, the draft and fields remain unchanged, and CRITICAL stays held until actual Enter. The banner remains the acknowledgment owner. These were source-review findings; the reviewer did not independently run a failing engine reproduction.

The author’s exact candidate-9 receipts show 30 tests, 1,132 assertions, zero failures across five official singleton suites; all strict/raw errors, warnings, expected/tolerated counters and leaks are zero. The zero-warning analyzer examined the six changed GDScript files, and its retained editor log is clean. Source, project, assets and old sidecars were restored. The review independently checked every footer, source pin, invocation result, and restoration receipt.

Native-4 ran actual Metal/Forward+ at 1280×720: 74 checks, zero failures, five captures, zero raw import/native errors, warnings or leaks. All 1,285 before/after source entries are equal and still match the author worktree. The seven reviewed sources match both strict and native receipts. All five image hashes match. The reviewer visually inspected opening, drawing, another floor, refused confirmation, and the stalled planner: text and draft remain legible, the actual stall banner sits above the dimmed controls, and no dropdown remains over it.

`verify_receipts.py` is the bounded read-only receipt replay. It copies immutable receipt/source evidence only into this review tree, refuses foreign output, checks the complete current native source closure, and creates `acceptance.json`. Replay:

```sh
python3 -B docs/validation/evidence/underground-planning-scene-review-2026-10-05/verify_receipts.py --root /Users/brendan/Developer/redwall-rts-codex-ug-integration --out docs/validation/evidence/underground-planning-scene-review-2026-10-05/review-3
```

The accepted result is the demo's actual-world planning view, input/modal/reset handover and resource-preserving refusal. It does not qualify a completed playable Kitchen, paid access, worker excavation, performance, native memory, or a full no-argument test milestone. Root’s original evidence remains under `docs/validation/evidence/underground-planning-scene-2026-10-05/{candidate-9,native-4}`.
