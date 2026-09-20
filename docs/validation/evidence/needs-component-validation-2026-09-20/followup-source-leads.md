# Source leads for the two remaining Needs domain contracts

Research only; not an accepted contract or additional implementation scope. Recorded while the v2 primitive author was running.

GDD REQ-SET-021..024: two low-mood midnights warn; third marks departure unless incapacitated; mood3500 clears warning/counter; incapacitated blocks departure and requests rescue/care; exit completion releases population/home/tool but keeps relationships/history.

GDD ResidentStatus enum includes LEAVING4 and TRANSFERRED6. GDD feast eligibility explicitly excludes both, so they cannot simply be removed as unused bytes. Current _refresh_status has DEAD, INCAPACITATED, INJURED, RESTING/ACTIVE precedence and explicitly does not place LEAVING. Public set_activity and set_injury_state both refresh status immediately.

Current Needs header still mentions U6 for MoodMemory, but architecture U6 now names ManualTask after earlier child-index rulings. No mood/lifecycle/departure module was found among core filenames. A later plan must reconcile this stale blocker against actual child-store rules before inventing a new storage shape or claiming a required decision is missing.

The generic validator intentionally admits nonnegative departure counters and in-range nonfatal status values. The upcoming source-backed contracts must decide production, interruption and retained-row behavior with family caregiver and lifecycle ordering rules; they must not silently tighten the already accepted primitive.

Source SHA256 (Needs is pre-implementation source, not an accepted final hash):
- docs/game_gdd.md: bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e
- docs/systems_architecture.md: 551736de66b7ecc81faa757b2d300c9fa907975419991b0b49848ebdf073d67e
- docs/planning/family_lifecycle_contract.md: f8c7131a76e0cc4a1c2e31e92b871e1ff3e692e4ae627f43c682ab64cd6a0607
- godot/scripts/core/needs.gd: 31fc6a56d294154024f39ff4f04924d9c2148fc4f08acee388fd6ea94595d553
