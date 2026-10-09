# Independent 1150 correction review

Accepted the source-only correction at the ten exact pins in
`source-sha256.json` (manifest SHA256
`f4b559f7046b0e8bc6807fbd5453bb29f7690e34ecdfdbe9f6d3f65c61410f2c`).
The author worktree was `redwall-rts-codex-ug-room-approach`, base
`7e199b7669a5bad5613aaf2881c9a801cc1dda51`. All ten pins matched at the
start and end of the review. No author files were written and no engine was
run by this reviewer.

The original review remains in `../approach-review-v1/`. Its sole blocking
finding was a final observer chain: World, endpoint, Room and transitive
Terrain store readers could run after the last physical proof. The correction
uses the original private owner bindings, full Directory generations and
typed reverse ownership, mirrored Room/Building/Resource rows and the exact
sealed Space/original cold tuple. The nine additive static Terrain functions
perform the same finite tile, water, footing, resource and rotated-building
checks without invoking those public readers. Earlier observing APIs are
unchanged. The reviewer checked the complete transitive static chain, its
ordinary-reader parity, and the exact-script Profiles/configuration boundary.
No remaining high or medium correctness finding was identified in this delta.

The author retained candidate14's five real mutation regressions on rejected
source: 23 tests, 271 assertions, five failures and no diagnostics/leaks. The
World and Room callbacks returned success after adding a real well; the other
three callbacks caused a forbidden side effect before later stale refusal.
The corrected tests require all five callbacks to remain uncalled, then
explicitly add the same well and require the real foundation refusal. Four
additional cases cover purposes/water/local limits, current resource lifecycle,
rotated footprint and full identity, and original candidate/lease tokens.

Independent checks executed with Python `-B` from this reviewer's worktree:

1. Author `test_census.py`: ten tests passed (`census-tests.log`).
2. Author `census.py`: `census.json` matches the author's candidate15 output
   structurally and byte for byte.
3. Rehashed all ten executable/UID pins and inspected the exact candidate15
   invocation/restoration fields (`verification.json`).

The source census preserves zero retained delta. Witness/request 1,744 bytes,
own declared frames 604, complete static/transitive Terrain frames 384,
path-call 512 and expression allowance 512 total 3,756 of 4,096. The inherited
Face allowance remains separate. The complete sequential cold peak is
938,368 of 1,048,960; the foreign final tail remains 1,984 of its existing
2,048 allowance. Native/reference/allocator costs remain unmeasured.

Author engine evidence was inspected, not duplicated: candidate15 has
96 tests, 3,251 assertions, zero failures and every strict/raw diagnostic and
leak count zero; analyzer zero warnings across five files. Source, HEAD,
project, registry, imported assets and sidecar restoration all passed.

Acceptance is limited to this ordinary Room approach/source-correction
component. It grants no new profile, physical source, paid-phase, movement,
native-memory, performance or whole playable qualification.
