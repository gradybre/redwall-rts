# Schedule owner14 validation evidence

Contract SCHEDULE-S4-VALIDATE-R01v1 / ADR0172. This is one owner-local validation primitive, not complete section4, bulk capture/apply, a complete save, or a first-playable milestone.

The accepted shared static predicate checks six exact packed-column extents and all physical values. Full-column first-refusal order preserves deterministic diagnostics; inactive Schedule defaults are explicitly ANYTHING1 for hourly/current, not allzero bytes. The existing inactive reader uses the same rule after its unchanged bounds/presence guards. Present unresolved and sleep-latched rows obey producer-proven local consistency, while current activity remains saved history after hourly edits, template reassignment or a refused subsequent resolve. No timetable, Needs or clock re-resolution is performed.

The owner14 bridge checks schema, exact contract metadata, frame shape and six explicit typed accessors. It constructs no Schedule or private Needs, and adds no packed projection/sort/duplicate buffers. The17920caller-owned packed bytes remain inside the existing streaming allowance; native/wrapper overhead is not measured. Section2 catalog identity and saved cross-owner consistency are separate.

## Completed local evidence

- Author336-line patch passed frozen input SHA checks, output target/mode allowlist and git apply --recount --check after PR162 merge; original patch and stopped worker records retained.
- Focus:62tests /17896assertions /0failures;12new tests plus50existing Schedule tests.
- Real-engine metadata:18cases /162assertions. Eight schema-valid counterfactual faults refused at owner metadata and eight matching guard bypasses killed by actual assertions. Schema-first failure retains original diagnostic. The first field-count test witness did not distinguish a redundant guard; its failure and correction are retained explicitly, not counted as a killed mutant.
- Twelve required mapping/state mutants killed: six correctly-sized allzero argument substitutions, two same-type swaps, three omitted local rules, inverted present-state gates. Baseline/restored controls both pass62/17896/0; no parser/script error counts as a kill; production source byte equality verified.
- Seventeen static/source gates pass. Import passed. Full regression passed4907tests /233113assertions /0failures. Existing shutdown diagnostics remain553objects/33resources, unchanged from the predecessor. Independent source review found no blocker or material gap; see source-review-disposition.md. Exact-head CI remains the merge gate.

Registry wording now accurately describes _resolved as successful resolution history, independent of the current clock hour. Six keys/types/counts, owner version and section schema remain unchanged. Canonical registry note matches the prose; capacity sidecar is regenerated for Schedule source/line changes. New stateless bridge is category3.

PR162 predecessor merged546a90714bbcaa2d2af42dfb3065b10eb159a181, exact-head CI35494963524 passed4895/216053/0; its metadata step took82seconds within the existing30minute job cap. See predecessor ci-merge.json.
