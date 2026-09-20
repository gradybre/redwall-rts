# FieldPolicy parent source findings

Owner author returned464 actual patch lines; bridge author345 (self-report343 was inaccurate). Both raw patches passed stopped-worker/hash/path/mode/apply checks and were reconstructed without changing production. The owner candidate passed83 tests/3901assertions including82 existing public tests and138 planned local fixtures; clean shutdown, no bridge acceptance yet.

The bridge author lacked Farming source in its bounded packet and therefore declined to invent two crop constant names. Its substitute default-rotation range checks did not pin the five required ordinals and constrained an unrelated gameplay default. Parent verified all five exact published symbols in actual farming.gd and replaced that substitute with CROP_BEANS0/CABBAGE1/FLAX2/GRAIN3/ROOTS4 checks, retaining CROP_NONE-1/CROP_COUNT5. No gameplay source changes. This is a corrected bounded implementation deviation before acceptance, not a waived contract.

Owner comment now says no live Directory/Farming/Forage reads, distinguishing allowed preloaded constants. Author candidates remain immutable; parent-candidate-repairs.patch/json records exact changes. Final candidate/production tests and independent source review must cover these repairs. No native-memory qualification or full save/gameplay completion claim.
