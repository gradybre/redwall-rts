# 0074 — Building service and room domain bindings
Date: 2026-09-11 · Status: Accepted (specification; implementation pending)

## Decision

Adopt [R-BUILD-DOM-001–004](../rulings/2026-09-11_building_room_domains.md):
protected Milestone M0=0 through M4=4, the full compiled Station service domain,
and furniture-presence mask bit i for existing FurnitureDefinition i. Retain five
starter shelf instances but only four pantry shelves contribute 200000g.

## Why

Decision 0056 correctly avoided guessing unpublished bindings. BAL-CAT-002 already
provides unlock ordinals and BAL-CAT-011 the service keys; this completes their
explicit representation and ownership. Mask presence must not be mistaken for
counts, capacity or service readiness. Exact earned bits avoid silently granting
milestones whose conditions have not passed.

## Consequences

Update the catalog artifact deliberately and preserve sibling IDs. Implement
existing packed fields without introducing a second enum registry, station entity
or duplicated container store. Synchronize milestone masks through Progression;
room masks remain saved/hashed with membership validation. Preserve historical
questions while recording resolution. Actual runtime/visual/performance checks
and remaining topology/service engineering are not completed by this decision.

## Source

GDD §4.2–4.3, §5.9, §5.11; BAL-CAT-001/002/006/007/011; decision 0056;
READY_07 §7.1–7.2; Astra's explicit engineering rulings dated 2026-09-11.
