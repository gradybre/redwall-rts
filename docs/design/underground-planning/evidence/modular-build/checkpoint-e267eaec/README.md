# Rejected full integration checkpoint e267eaec

Source remained exactly `e267eaec69813696a6931edebe980d3a8a5162f5` for the clean import, no-argument strict suite and whole-project zero-warning analyzer. Assets were restored. This is a rejected checkpoint, not a green full-suite claim.

```text
9670 test(s), 675202 assertion(s), 1 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1085 file(s)
```

The strict script stops at the failed-test gate, so there is no final raw-log footer. The failure is `test_all_nine_section_one_owners_supply_a_canonical_adapter`: decision1072 declares the mandatory tenth World owner, while the frozen legacy section1 codec supplies nine. Decision1084 records the independently reviewed test correction and explicit refusal to hash a subset. It does not implement or waive the required UG16 versioned owner/save integration.

`invocation.json` records actual commands, exit statuses, timings and frozen-source verification. Full log and analyzer JSON are retained here. A subsequent full integration run remains required.
