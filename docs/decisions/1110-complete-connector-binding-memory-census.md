# 1110 — Count actual connector placement and work in the shared reserve

Date:2026-10-03 · Status: source-accounting correction; runtime qualification open.

The previous generated binding subtotal378136 omitted actual Placement and its
ConnectorWork adapter. Its146152-byte remainder was therefore overstated. Their
existing finite reservations are now included before EntryFrontier, Contacts or
EntryBindings may allocate. No memory allowance or gameplay capacity increases.

The checker derives both actual Placement banks from every declared nested packed
column and resize, resolves256 placements/512 openings, and adds the actual mark
buffer, stream reservation,2048 controls and8192 provisional native reserve. The
complete maximum is108800 bytes. A separate exact-member census rejects hidden
or late-allocated packets, new collections and changed packet inheritance. Current
fixed control coexistence is1670/2048, including the future-Room context and
Directory candidate added by1108. The existing shared OrderRecord/AssemblyRecord
pair is128 bytes already counted there.

ConnectorWork contributes51 additional retained numeric bytes plus512 helper
allowance. Its128-byte caller pair aliases the pair above; charging it again
would double-count the same simultaneous lifetime. The complete additional charge
is563 bytes. Concrete base Owner/Publisher fields are checked as well as nested
Publication and top-level fields, so inherited state cannot silently disappear.
No extra per-placement or per-project bank is introduced.

Known consumers now total487499 of524288, leaving36789 bytes for immutable
EntryFrontier, actual contact/binding consumers and remaining native growth.
Frontier's proposed28597 ceiling leaves4096 each for Contacts and EntryBindings;
real smaller source counts must leave native headroom. Filling all ceilings is
not a runtime qualification. Logical pack total remains99959250 and overall
40750-byte headroom, since this corrects accounting within an existing reserve.

New regression cases reject nested bank widening/additions, late packet members,
changed parents, inherited adapter/publication state, uncharged adapter controls,
a constructor undercount and a reserve below the corrected subtotal. The emitted
pack pins the actual Placement/Work/Directory source in addition to the existing
source closure. Physical contact, complete save composition and256-resident native
measurement remain independent acceptance gates.


Independent review found the initial checker inspected expected inherited fields
without pinning the two modules' actual top-level superclass. The corrected
checker explicitly requires RefCounted for Placement and the actual
ModularProjectContract.Owner for ConnectorWork; two additional adversarial
source edits exercise that refusal. This closes the omission without changing
production source or admission constants.
## Concrete Contacts consumer

The accepted concrete `underground_connector_contacts.gd` now consumes the
existing4096-byte Contacts earmark. The checker derives148 logical numeric
control bytes,376 packed scratch bytes,1633 bytes for both finite fragment
banks and their controls, and753 for owned Order/Location/Profile/checked-int
packets:2910 total. Its existing1024-byte helper allowance brings the logical
packet to3934, within4096. Borrowed owner references, native object/array
headers and the actual combined call stack still require measured qualification.

The census checks the exact base class and absence of inherited Contacts state,
all14 packed scratch members and their resize expressions, all five fragment
buffers and their width/capacity, every nested packet and the exact checked-int
result shape. Untyped or duplicate retained fields and undeclared owned objects
refuse accounting. The full shared binding reserve is now assigned:524288 of
524288 bytes. This consumes an existing reservation; it does not add another
4096 to the whole-world memory total or promise that future composition fits.

The90-test source-census suite passed against exact Contacts source
`680114461ecaf8d96bea6ed45b1edba60f057d89f76fc59aa3e0e2fd03233c39`.
Geometry independently read both tool files and the actual source, verified
their hashes and reran all90 tests with no failures. The externally read source
was unchanged. Exact invocation, raw results and the explicit source-index
projection are retained under
`docs/validation/evidence/underground-connector-memory-2026-10-03/candidate-1/`.
This verifies a logical source census, not an engine/native performance result;
the normal integrated CLI/artifact check follows the accepted Contacts commit.
