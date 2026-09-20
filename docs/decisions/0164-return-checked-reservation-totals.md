# 0164 — Return checked reservation totals

Date:2026-09-19 · Status:Implemented after PR154; independent review repaired; full4760tests/186771assertions/0failures; exact-head CI pending

RES-TOTAL-R01v2 fixes a public-API witness where two valid6e18milli claims on
different item lots produce a negative wrapped job total. Preserve legal claims
and exact save rows. Change the two cold total queries to explicit IntResult
returns and add nonallocating caller-output variants. Migrate every live caller;
remove the unchecked helper and make the existing lot audit refuse overflow
before comparing totals. No product feature, quantity or wire format is removed.

Independent contract review conditions are resolved in the version2 packet.
Serialize implementation after the exact reservation owner PR; gate external
file loading on this repair. The archived old-API probe remains historical
source evidence and is not the new acceptance test.
