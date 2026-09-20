# Transform owner 15 validation evidence

Accepted contract: TRANSFORMS-S4-VALIDATE-R01v1 / ADR 0173. Local image validation is one prerequisite. Section 4, bulk owner binding and full save/load remain incomplete.

Nine exact i32 columns, with the binding column first, feed a static predicate. Its gates check shapes, nonnegative bindings, unique positive bindings, and zero poses at zero-bound rows. Every bound pose and yaw retains the full signed int32 domain, with independent current and previous values. Stale positive bindings survive destruction. The validator performs no live Directory lookup or history normalization. Existing methods, diagnostics and the diagnostic byte order remain unchanged; test fixtures explicitly remap its binding-last order.

The predicate sorts one private 350,208-byte copy of the binding column. The framed image (3,151,872 bytes), scratch copy and three 65,536-byte stream windows total 3,698,688 logical packed bytes. That fits within the existing 6,417,408-byte single-owner maximum when the caller follows the release protocol. This adds no resident allocation row or second world. Native overhead and RSS are unmeasured. TRANSFORMS-SAVED-IDENTITY separately owns saved cursor bounds, Directory associations and file provenance.

The author's 295-line patch passed frozen-input and target/mode checks but failed the initial patch-context check. Astra removed one surplus unchanged blank context line. Every added and deleted line remained byte-identical. The normalized patch passed `git apply --recount --check`. Both patches, the original failure and the disposition are retained. The worker had stopped before intake.

Completed local checks:

- Focused suite: 34 tests, 3,277 assertions, zero failures (9 new tests and 25 existing Transform tests).
- Fourteen required mutants caught by assertion failures: nine zero-argument substitutions, three omitted rules and two changes to gate order. Baseline and restored controls passed; parser and script errors were never credited as kills. Product source hashes remained unchanged.
- Metadata: 18 cases and 162 assertions, including eight bypassed guards caught and unchanged schema-detail forwarding. Each counterfactual preserves a valid schema and physical frame shape so it reaches the intended guard. Production format is unchanged.
- Seventeen static/source checks and import passed. Independent source review found no blocker. Full regression passed 4,916 tests and 236,229 assertions with zero failures. Existing shutdown diagnostics remain 553 objects and 33 resources, unchanged from the predecessor. Exact-head CI remains the merge gate.

Registry prose and its matching canonical JSON note now require canonical pose history to survive both digest checks and publication. Load's `previous=current` behavior is a presentation-only override. The new stateless bridge is category 3. The capacity sidecar was regenerated for source and note hashes. Registry version 6, section 4 schema 2, owner 15 version 1, and all field keys, types and extents remain unchanged.

Predecessor PR 163 merged as `dd68860bb81e1f267ead75f835f359455cb82169` after CI 35496042185 passed 4,907 tests and 233,113 assertions with zero failures. Its Schedule metadata stage took 80 seconds. The Godot CI job took 12m34s, within the existing 30-minute limit. See the predecessor's `ci-merge.json`.
