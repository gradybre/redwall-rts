# 0172 — Validate saved Schedule history without rederiving it

Date:2026-09-20
Status: accepted

Schedule owner14 stores six canonical columns, including its last resolved activity and sleep-window latch. Public timetable edits and template reassignment intentionally preserve resolved history. A public probe confirms edited hourWORK/currentANYTHING/sleep1 and reassigned flexible hourANYTHING/currentSOCIAL/sleep0 are legal; a validator must not recompute history from the current timetable or Needs.

Adopt SCHEDULE-S4-VALIDATE-R01v1 in docs/planning/schedule_component_validation_contract.md. One pure six-packed-argument predicate checks exact domains and inactiveANYTHING defaults, then two current-producer invariants: unresolved rows have currentANYTHING/sleep0, and latched rows have currentANYTHING (and resolved1 through the preceding gate). Every public writer preserves these implications; independent final review found no reachable counterexample. A future producer altering them must revise the contract.

Share the existing inactive-row rule with its reader, keeping reader guards. A framed bridge validates exactowner14schema/metadata/shape before using six explicit typed accessors. No live owner, projection/default buffer, sort, runtime catalog compiler or CatalogIds preload is permitted; the latter would cycle. Template0..2 is a local numeric check, while section2catalog identity matching remains coordinator-owned and migration remains unwritten.

The17920caller-owned packed bytes are already inside the stream allowance; native overhead is unmeasured. Correct the registry's this-hour interpretation of resolved to last-successful-resolution history. No hourly-reset behavior, schema/version/newfield, bulkcapture/apply, cross-owner agreement or complete-save acceptance is introduced.
