# Renewed native execution inputs — candidate

Decision1137. This directory prepares the actual runtime inputs for the next
published Mole replay. It does not refresh an old proof or qualify a profile.
The live Catalog and native-capture script are unchanged.

`prepare_runtime_bake.py` verifies the exact prior native specification, then
retains all536 source rows and its manifest. Only three explicit source pairs
change: Actor's reviewed1132 WorldBasis reader, the reviewed1136 construction
contract, and the reviewed1125 Transforms reader. The new digests are also checked
against immutable commit `bdef27f082611b68ce61cdd54d4f2d23bf11472b` by the tests.
Actor palette/driver mathematics are unchanged by this input record. The final
consumer-compatibility review and complete native replay remain mandatory.

Twenty-five absolute paths into the former agent checkout are relocated to
this isolated checkout after their identical bytes are verified. Original raw
asset-library paths remain read-only exact inputs. Every other source must still
match. Imported scenes are checked against the original palette archive; the
unchanged native runner must later restore and verify them in its own cache.
Manifest, cases, source gaps, asset identities, profile count and production
qualification facts remain unchanged. Candidate1 grants zero certificate bits.

The537 records account for3,081,042,450 bytes read, including original and staged
copies. Hashing retains one1MiB chunk, with a256MiB per-file and3GiB total input
limit. This is offline I/O, not a simulation-memory allowance. The rejected first
attempt's2GiB limit, exact producer and refusal are retained in
`rejected-capacity-v1/`; it created no output and changed no input.

All sources are checked before output creation and again after the write.
Existing output and dangling symlinks refuse before input work. Eight tests
cover the immutable source objects, unchanged facts, missing/duplicate rows,
wrong old digests, unlisted drift, archive bytes, symlinks, limits and output
preservation. `tests.log` reports8 passing tests. `generation.log` reports the
actual537-source derivation; it is explicitly not a native renderer run.

Independent source review by `/root/ug_furnishing` accepted this component.
The reviewer reran all8 tests and independently compared536 source rows: exactly
3 changed digests,25 identical-file relocations and every other fact unchanged.
The final current consumer closure and native replay still require acceptance
before changing the live Catalog. `acceptance.json` records the exact reviewed
source and candidate hashes; this paragraph was updated after that review.
