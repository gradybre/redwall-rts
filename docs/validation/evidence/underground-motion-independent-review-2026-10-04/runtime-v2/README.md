# Independent ADR1143 correction review — accepted candidate 5

The source-only MotionCatalog component is accepted at the nine exact pins in
`source-sha256.json`. All nine matched before and after this review. No remaining
high or medium finding was identified in the stated reader scope.

The only runtime delta from the reviewed candidate 4 moves payload reading and
scalar copying into `_decode_payload`. That helper returns only StringName, so
its complete frame—including packed return temporaries—ends before the next
chunk is allocated. The caller loop retains no packed payload. Fixed column
counts, hashing, decoding and refusal behavior are unchanged. This closes the
medium simultaneous-buffer finding retained in `../runtime-v1/README.md`.

The census now checks this exact lifetime boundary. Its regressions reject the
old loop, an escaped packed result, a retained alias, a duplicate buffer and an
enlarged window. The reproducer also rejects raw import diagnostics when the
engine exits zero, closing the earlier low runner finding. Historical candidate
4 sources and logs remain intact in the author's packet and this review.

I independently ran the seven new tests successfully, reproduced the corrected
census byte-for-byte, and rechecked all nine pins. Results and commands are in
`independent-results.json`. The maximum own declared numeric chain remains 144
bytes and complete logical/helper census 1,090 within 4,096. The single decode
window is now supported by its actual lifetime. Joint admission remains
232,436 / 262,144 bytes, including both 70,860-byte banks, actual configured
Profiles and Levels, caller scratch and the provisional 32,768 native allowance.
Native allocation has not been measured.

I read the final author-run evidence: Motion 15 tests / 13,671 assertions / zero
failures, zero strict/raw diagnostics or leaks, raw import guard zero, analyzer
zero warnings in two files, and source/project/registry/assets restoration true.
No engine suite was repeated by the reviewer. The unchanged packer and source
wire retain the earlier independent 11-test pass and byte-identical wire and
manifest reconstruction from `runtime-v1`.

This acceptance covers bounded source reading, identities, immutability,
malformed/refused loading, source phase and logical storage. It does not activate
a route or grant native memory, renderer, support, paid-world, gait, pace or
whole-game qualification. `activation_refusal()` remains unconditional.
ADR1145's separate 30/45-tick tuning approval does not populate these unbound
runtime fields.
