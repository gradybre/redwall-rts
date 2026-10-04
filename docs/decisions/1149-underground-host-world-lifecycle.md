# 1149 — Underground host lifetime follows the actual generated World

Date: 2026-10-04. Status: independently reviewed foundation lifecycle; operational
room dispatch and D20 remain open.

## Decision

SettlementSystem retains one Session over its actual existing owners. Mounting
the foundation consumes the already admitted Session reservation and existing
immutable Content; it creates no stock, identity, job, paid entrance or route.
Publish the candidate handle before its observing initialization so a reentrant
host reset refuses while that initialization is busy. A failed initialization
drops the candidate without clearing the settlement.

Session exposes an explicit quiescent foundation retirement. Retirement drops
its own references only after current-owner, empty-arena and unbound-authority
checks. It never privately resets another owner's one-way authority WeakRef.
Settlement reset checks retirement before clearing any store and returns a
success value. The boot caller performs this retirement before resetting
EconomySystem or EntityManager. Callers that generate after reset must inspect
its success; an ignored reset refusal must not become permission to seed or
publish a replacement world.

The UI must use SettlementSystem's existing WorldInit and staged banks, with
exact concrete collaborator checks. The earlier UI path allocated another
generator; independent review measured 175,364 extra packed bytes before native
headers. That allocation cannot fit the current global headroom and is removed
from the composed creation path. The UI retains the same object for map and
attempt reporting. A refused reset retains its prior published map and all
settlement state and discards only its uncommitted replacement plan.

Ordinary Session availability continues to reject a prepared World. Explicit
whole-world retirement alone may accept a staged replacement over the unchanged
original live World/PID/seed/store tuple. It retains all other arena, authority
and source checks; it grants no movement or work permission. World.clear keeps
its staged plan, preserving the existing preflight → reset → seed → publish
contract. The UI holds one borrowed Content reference during this synchronous
replacement, then remounts a new Session on the new full World identity. A
mounted demo cannot silently lose its underground foundation after Create.

## Scope and evidence

The current Session foundation has no externally installed Room/phase
authorities. Its retirement refuses once those authorities are installed;
coordinated operational teardown must be added alongside their host activation,
not bypassed by clearing private fields. This is an explicit partial boundary,
not a permanent restriction on restarting a developed settlement.

Tests must cover actual host composition, duplicate mount, reentrant and held
arena reset refusal with byte preservation, successful retirement, stale
references after regeneration, UI replacement identity, and no extra starter
stock. Independent review, strict diagnostics/leak checks and zero-warning
analysis precede acceptance. No new gameplay rule or reserve limit is adopted.

The corrected candidate passed 287 focused tests / 7,038 assertions with zero
unexpected diagnostics or leaks. The final affected Host rerun passed 8/82,
and the analyzer reported zero warnings across eight files. A real headless
1280×720 demo boot/restart probe passed 14 checks; its 44 known missing-asset/audio
warnings are retained explicitly. The shared memory checker passed 225 tests
and the capacity audit passed 190 checks. Independent Construction review
accepted the correction; the first rejected candidate remains documented.
See `../validation/evidence/underground-host-lifecycle-2026-10-04/` for exact
source pins, raw logs, commands, restoration and scope limits.
