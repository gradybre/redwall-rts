# 0166 — Restore resource claims without rebuilding other sections

Date:2026-09-19 · Status:Implemented and independently reviewed; exact-head CI pending

SAVE-CLAIMS-R01v2 installs only the7Fishing and11Forage section7 claim arrays and
derived livecounts. Preserve exact typed-row identities, stale generation pairs
and canonical Forage orderkeys. All othersection state, scratch and borrowed
bindings remain untouched. Old rowrestore and aggregate rebuild methods are
ineligible: they change section4 effort/quota and Forage ordering fields.

Owner admission narrows codec-only quantities to existing healthy runtime bounds:
Fishing1..maxexistinghabitatcapacity6; Forage1..1180000remaining. Zero Forage
claim rows have already completed and must be inactive. Refuse incompatible
payloads explicitly; no clamping/remapping and no schema-layout change.

A single stateless adapter handles either ownerblock separately, requires held
clock onapply and has no invented Inventory dependency. Full-world activation
requires a new read-only checked claim reconciler, owned by SAVE-CLAIM-RECONCILIATION
and gated by PLAN-CLAIM-RECONCILIATION, before SAVE-ORCHESTRATOR may resume.
Independent contract review and disposition are recorded; no public overflowbug
is inferred from forged inputs. Claim-only acceptance is not complete save/load.
