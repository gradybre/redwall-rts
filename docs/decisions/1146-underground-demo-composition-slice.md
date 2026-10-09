# 1146 — Compose the underground owners into the running demo

Date: 2026-10-04 · Status: Active engineering work; D20 remains open

## Decision

Extract UG24 from UG09 so the demo host, confirmation adapter, fixed-tick
dispatch and committed shell reader can be implemented alongside the remaining
motion and handling work. UG09 retains every playable acceptance gate and its
UG07/08/21 dependencies. Completing this composition component alone cannot
close the first empty Kitchen or any native construction walkthrough.

The independent audit at `42bff090` found that the demo already boots the real
SettlementSystem and its GameManager fixed-tick callback. Its visible room
confirmation still uses the separate legacy graph and demo worker loop.
ModularEditor and ModularWorldTool have tested input, but no production host
connects their confirmation to RoomOrders.

## Ownership and sequence

The integration owner implements the existing queued `modular_runtime.gd`
adapter, its tests and shared demo/SettlementSystem entry points. The Geometry
worker may implement a new `underground_session.gd` owner composer after its
1143 candidate is reviewed and frozen, on a separate own branch with explicitly
leased new files. Existing phase/room owners stay under their recorded leases;
changes to them require their current writer to stop first.

1. Borrow the running settlement's actual World, Directory, Buildings,
   Construction, Inventory, Jobs, Work and Transforms. Compose the underground
   owners around those same instances and the published finite Terrain datum.
   Never create a second settlement or borrow synthetic fixture catalogs.
2. Connect the world tool's exact typed draft to RoomOrders and its real receipt.
   The drawing datum, authored level, room purpose and cells must survive this
   boundary unchanged. A refusal retains the drawing and spends no identity,
   resource or work. Repeated confirmation, teardown, stale generations and
   world reset are explicit tests.
3. Dispatch only genuinely linked underground work and Routes through the
   existing clock. Preserve demolition and require real assignment, arrival,
   tool, input, source and work-face observations. A new callback cannot grant
   productive work or infer arrival from a visible animation.
4. Supply the missing ordinary-room approach/phase companion and read committed
   physical masks into the shell view. Room completion leaves an empty Kitchen;
   room purpose, installed furnishings and active services remain distinct.

Actual source/paid entry work still consumes 1143 and 1144 after their separate
qualification. The approved 1145 timing is no substitute for those bindings.
An unavailable catalog/contact returns its real refusal; no legacy passage,
elapsed demo time, free resource or manually completed Site is a fallback.

## Storage and evidence

New editor-side state is bounded presentation/command input. The existing room
admission budget includes its caller plan; the adapter must not add a second
authoritative footprint or physical ledger. The eventual host must separately
count finite editor snapshots and their presentation peak; that caller plan
allowance alone does not cover every UI copy. Any retained simulation
composer, callback, column or packet must be reconciled with the unchanged
100 MB census before integration. Source fingerprints and lifetime/reset checks
remain required; source-only models are not runtime qualification.

UG24 requires independent review, focused strict tests and zero analyzer
warnings. Integrated playable milestones retain the exact clean-assets,
cache-removal, import and no-argument suite procedure, native 1280×720 input
and before/during/empty-shell captures. The 107 requirements and the complete
UG09 acceptance list are unchanged.

## Source

Brendan's standing instruction to build all approved requirements concurrently
and automatically release independent work; decision1051; the independent
`integration-audit-42bff090.md` in the motion-review evidence directory. This
is a scheduling and composition decision, not a new gameplay rule.
