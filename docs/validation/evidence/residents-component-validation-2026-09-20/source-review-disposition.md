# Residents source review disposition

Accepted independent review found no production defect. Its pending metadata/mutation finding reflects the frozen input packet. Actual metadata now passes27 cases/243 assertions, including all8 bypass detections. All48 required mutations are detected in52 valid runs:47 assertion oracles and one explicitly characterized null-runtime-error oracle. Baseline/restored runs pass and production sources are unchanged. The known null case is not an assertion kill. See mutation-results.json and metadata-preflights.log.

The focused launcher was omitted from the reviewer packet, not the repository: focused-launcher-proof.json records its exact four-line source/hash and standard-runner discovery of this suite. Actual focused and mutant runs independently prove execution.

Both optional valid-domain endpoints were added after the mutation campaign: present CHILD and item0/durability0. Final focus passes9 tests/47422 assertions with no script errors or shutdown leak diagnostics. The exact47336-assertion pre-addition test source used by mutations is preserved in mutation-test-input.gd/json. endpoint-addition.json records the strictly additive fixtures; production source is unchanged. Do not claim the mutation campaign ran those new endpoints.

Direct Residents.EntityDirectory.NULL_* accesses authoritative preloaded Script constants without constructing Directory and meets the four-preload contract. The conservative254976 logical packed-byte budget is source-derived; native memory is unmeasured. Cross-owner saved bindings, whole-file publication and first-playable acceptance remain separate. Full verification and exact-head CI are separate gates recorded by their own evidence.
