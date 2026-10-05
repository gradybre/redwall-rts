# 1186 — Export verifier follows published short-step consumers

Date: 2026-10-05

Status: implemented; focused verification and independent review accepted.

## Finding

The clean CI run for `8f6bad86` (`37275141498`) completed every suite, but shard5
reported three failures in `test_demo_profile_pack.gd`. The actual export
verifier retained the previous nine consumers while decision1173's immutable
publication requires ten, including `work-step-v1/source_program.gd`. Consequently
an exported demo would refuse before boot. The positive test also still expected
the old9,620-byte profile image instead of the current10,502-byte publication.
This is an integration omission, not an allowed diagnostic or a waived test.

## Correction

Retain the exact short-step Script as the tenth entry in the verifier's ordered
preloads. Keep the complete census, resource identity, cached-source text and
digest checks. Bind test expectations to the current immutable catalog's byte
count and source-path census; keep the actual emitted actor digest/size and
nonempty-source checks. The oversized negative case now uses the current exact
byte count plus one, so it remains oversized after publication changes.

Add a regression that modifies only the actual cached short-step Script text,
checks `MOLE_CATALOG_SOURCE_DRIFT`, restores the exact original text, and checks
acceptance again. It also proves that the actual verifier retains this Script.
No source-profile geometry, timing, publication digest or World permission changes.

## Evidence

Retain the failed CI artifacts under
`docs/validation/evidence/underground-integration-checkpoint-2026-10-05/ci-8f6bad86/`.
Focused strict tests and analyzer results for the correction belong under
`docs/validation/evidence/underground-export-consumers-2026-10-05/`.
The frozen8f full local run remains unchanged and cannot certify this correction.

The correction passes12 focused tests/249 assertions/zero failures, with all
strict/raw diagnostic and leak counters zero. The changed test has zero analyzer
warnings (0/1), with a clean raw editor log; the external verifier is executed by
the actual profile-package suite. Independent review verifies the exact ordered
10/10 preload census and unchanged identity/digest refusal gates. This is not
a fresh Windows export or a replacement for the full integration checks.
