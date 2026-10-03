# Connector settlement logical reservation

Decision1106 adds two transient full references to Funding. The source census
now charges their16 logical bytes once inside the existing524288-byte bindings
reserve. Known named consumers use378136 bytes, leaving146152 before Placement,
remaining adapters/frontier data, other controls and native growth. The complete
logical pack stays99959250 bytes with40750 headroom; native memory and complete
runtime admission remain unqualified. Reused refund scratch is not counted twice.

Independent Construction-agent review reproduced one MEDIUM in the first
checker: a compact declaration without a space after the colon escaped its
regex. The correction enumerates every top-level settlement declaration, allows
whitespace-independent type parsing and requires exact unique coverage. Compact,
untyped and duplicate declarations now fail, alongside missing/changed-width
controls. All44 Python tests passed on the actual integrated source; the separate
reviewer reran them successfully and accepted the unchanged four pins recorded
here. No runtime source is changed by this follow-up.

The capacity sidecar refresh changes exactly three source hashes and55 source
line/proof locations after the accepted Funding/Router/Reservations edits.
Independent structural comparison found no capacity, arithmetic or schema change.
Both generated artifacts match their source checkers.

Reproduce from this exact checkout:

```sh
python3 tools/test_underground_memory_budget.py
python3 tools/underground_memory_budget.py --check
python3 tools/audit_registry_capacities.py --check
```
