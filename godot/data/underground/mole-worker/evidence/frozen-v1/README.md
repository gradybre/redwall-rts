# Compact mole source component

Independent root review accepted the component against `a16b4621` at the exact
compiler, reader, tests and native sequence pins in `source-sha256.json`, with
no high/medium source finding. No production profile is qualified.

The reviewer found one evidence-wrapper guard issue: unexpected output from the
final zero-exit analyzer could leave the exit-code list looking successful.
The corrected wrapper tracks diagnostics separately. Four mocked control-flow
regressions pass; `wrapper-correction-sha256.json` and `wrapper-tests.log` pin
that correction separately. The original native proof retains its original
wrapper hash; its actual saved logs contain no unexpected diagnostics. No GPU
proof was repeated solely for this wrapper control-flow correction.

The compiler consumes the complete reviewed raw image and its footer/hash,
checks its 530 pinned sources, retains the original geometry/skin transcript,
and requires every declared state. It compiles seven actual mole/pick states
into one immutable 354-frame image. Active-tool work stroke is separate from
the non-target body; travel and recovery retain all tool geometry. Work yaw,
stance, actual owner/contact and quality qualification remain absent.

The runtime reader bounds every table/count before allocation, streams the
same file into one Palette, and checks the exact borrowed vertex/skin/format
fingerprint before Actor configuration. This is a geometric identity check;
it does not independently authenticate texture, material or triangle-index
authorship. The original asset owner must keep the borrowed mesh/material
resources immutable. The native witness uses that actual owner and its original
resources. No per-Actor copy of the complete Palette is made.

The source clock is presentation-only. Non-looping clips reach their last pose
at the exact outward Q16 source duration; a short final interval is rescaled.
Loop closure interpolates the last complete source interval to its first
finite pose. All interpolation remains a positive blend of admitted frames.
This finite representation does not claim equivalence to unconstrained live
Skeleton3D interpolation or permission for a gameplay transition.

Validation:

- `../checks-v3`: clean assets-aside import; **29 tests, 334 assertions,
  0 failures**. Diagnostics: **0 unexpected errors, 0 unexpected warnings,
  0 expected, 0 tolerated; 0 leaked objects/resources**. Raw log: **0 unexpected
  errors/warnings, 0 leaked objects/resources**. Analyzer: **0 warnings / 2 files**.
- `python-tests.log`: **11 tests, OK**. Synthetic parser tests explicitly replace
  only backend/file availability attestations; no actual source certificate is
  inferred from those fixtures.
- `../native-v1`: exact Python/native mesh fingerprints, actual imported mole
  and pick, all seven clips and positive two-clip blends: **731 poses,
  1,575 assertions, 0 failures**, no unexpected diagnostics/leaks; analyzer
  **0 warnings / 1 file**. The World identity is a fixture; its finite descriptor
  matches the actual engineering pack.

The 426,216-byte retained Palette plus the larger mesh-array/decode overlap,
648 packed table bytes and explicit 2,097,152-byte unmeasured native/control
allowance total **6,920,048 presentation bytes**. Shared WorldBasis adds 544,768
bytes once. Borrowed asset/texture memory and per-instance RIDs belong to the
separate presentation owner. Native live allocation increased 428,476 bytes;
an earlier larger process peak prevents isolated loading-peak qualification.
This is not the simulation budget or a complete client measurement.

## Rejected iterations and open visual finding

`checks-v1` expected the wrong refusal precedence: a headless backend refuses
before an outside-tree Actor. `checks-v2` passed the suite but the analyzer found
a test local shadowing `pingpong`. Both corrected iterations are retained.
The first `v1` binary was a pre-reader prototype with zero duration fields;
the reader refuses it. `v2` contains complete source durations; `v3` is the
same wire image with the final compiler/source provenance report.

The native evidence faithfully reproduces an unsatisfactory original grip:
the shaft is near the wrist/behind the paw, and claws remain open during idle,
travel and striking. The rig has no finger bones. These images are retained
as **rejected visual quality**, even though they pass component/source checks.
An explicit authored hand/grip correction and regeneration of all dependent
palettes, bounds and hashes is required. Translation alone cannot be claimed
to close claws. The current content never becomes a qualified physical profile
because the reader loads it successfully.
