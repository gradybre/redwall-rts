# Integrated hauling memory and support regression — 2026-10-04

The independently accepted ADR1141 component is integrated at `ee63d7b9`.
This packet charges its separate3,072-byte per-world allowance once, outside
the fully assigned binding reserve:512 controls,512 helpers and2,048
provisional native bytes. The two fixed216-byte packets plus one scope byte
use433 control bytes; the accepted complete lower-owner helper census uses466.
Delivery borrows the view packet. No canonical or per-Job bank is added.

The resulting source-counted pack is99,994,686 bytes with5,314 bytes of
headroom under the unchanged100,000,000-byte ceiling. Delivery and the proposed
stair programs remain excluded. Runtime memory and composed saving are still
unqualified. The architecture history preserves every previous subtotal.

`normal-v2` passes170 memory tests,190 capacity checks and all six ledger,
registry and decision checks. READY07 reports145 field rows/51 allocation
rows; registry coverage reports142 modules/708 rows/1,044 packed columns.
`registry-format-final` repeats the six checks after removing a blank line
that incorrectly split a Markdown table. Its seven pins define the final
reviewed delta. Independent review reproduced two inherited-storage census
holes, then verified the added exact-base guards and regressions. It also ran
11 focused Python checks and independently reconciled the pack, READY07 and
capacity artifact delta. Exact evidence is in `independent-review`.

The full6ee1f789 checkpoint had one stale source-catalog expectation. Its
reviewed correction accepts the actual renewed v2 consumers and applies the
unchanged production source guard to the actual cached Contacts Script with
its historical v1 digest. That negative case still refuses source drift.
Geometry bytes, source guards and qualification flags remain unchanged.

`focused-v2` runs the real strict suite wrapper for both affected suites:

```text
9 test(s), 137 assertion(s), 0 failure(s)
16 test(s), 603 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 5 file(s)
```

Both suites separately emit the diagnostic/raw lines above. Import has no raw
error/warning/leak markers. The original project and absent-assets state were
restored, and all pinned source files were unchanged during testing. Exact
commands, source pins and timings are in each invocation. This is focused
component evidence; the next full integrated run remains required.

Rejected attempts are retained: `normal-v1` passed168 tests but called a
nonexistent capacity-test filename; `focused-v1` failed to parse the direct
Script-class property/method access (1 test,0 assertions,2 failures,1
unexpected error,zero leaks). Assigning the cached constant to a typed Script
local corrected that access without changing its identity or guard. No
failed attempt is counted as accepted evidence.
