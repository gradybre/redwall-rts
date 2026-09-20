# 2026-09-20 — Equipment authority lifetime

Task: 10_presentation_qualification.md
Date: 2026-09-20

Inventory now borrows Gear through a weak equipment-authority binding. A dropped or freed authority refuses attach/detach before mutation; live Gear continues to retain its collaborators. The anonymous SettlementSystem comparison fixture is freed after obtaining its expected bytes. ADR0187 and EQUIPMENT-LIFETIME-R01v1 define the unchanged gameplay/save boundary.

Independent code/security review found no blocker. The isolated candidate passes 5,060 tests and 526,482 assertions, including 14 new lifetime tests; the focused run passes 422 tests/8,265 assertions. Both actual semantic fault units are caught and 17 static checks pass. The verbose full-suite and simple boot diagnostics show no retained-object/resource warning lines, compared with the baseline's 553 reported objects/33 resources. This does not certify all native memory or first-playable/release qualification. All original diagnostics, failed harness classification, repair lineage, full review and exact source manifests are retained in equipment-authority-lifetime-2026-09-20 and shutdown-leak-diagnostic-2026-09-20.

Local candidate ready for exact-commit CI. No presentation qualification checklist item is closed by this ownership repair.
