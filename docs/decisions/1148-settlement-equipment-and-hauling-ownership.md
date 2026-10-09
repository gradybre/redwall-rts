# 1148 — Settlement ownership of equipment and hauling

Date: 2026-10-04 · Status: implementation under review

UG24 composes one Gear and one HaulCarry at SettlementSystem construction,
over its existing Inventory, Directory, Residents, Work, Reservations and
GroundPiles. Their getters return those same instances. Wiring creates no
lot, equipment record, worker assignment, carried quantity or travel permission.
The existing budget already includes these stores; this fills their host
composition gap rather than adding another population-sized owner.

Eager composition gives every generation the same equipment and carry identity
and avoids a half-bound first underground command. Reset clears Gear alongside
Work and the other stores, retaining the existing equipment/carry bindings.
Carry's canonical payload lives in Residents and Inventory, which the existing
reset clears. Its fixed reclaim scratch remains the same allocation.

Do not call `Gear.seed_starter_tools` from this composer: main's existing
Economy initialization already deposits 24 tools into the shared Inventory.
Calling both producers would mint 48. The conversion to 12 equipped and 12
stored individual tool instances needs one coordinated stock initialization
path; this increment does not claim that conversion or working excavation.

Session creation remains separate and requires the actual source image and
published World. This decision does not authorize clearing expired spatial
authority WeakRefs or bypassing the coordinated underground reset gate.

Validation covers exact owner identities, unchanged startup stock, clearing a
real equipped record on reset, stale full references, and repeated generation
with the same services. Existing settlement, starter-colony and demolition
tests remain regression gates, followed by the integrated full suite.
