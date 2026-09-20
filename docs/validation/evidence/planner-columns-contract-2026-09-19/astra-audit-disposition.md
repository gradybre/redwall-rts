# Astra disposition before SAVE-J2-R02 review

D1: choose shared schema extraction with the owner re-exporting the21existing
referenced constants plus STATUS_UNMET. Preserve their existing leaf-store
expressions, rather than inventing a second literal extent catalog. The shared
helper cannot import planner/codec. New init assertions tie domain counts to
existing final ordinals; schema/registry tests enforce unchanged wire values.
D2: preserve structurally legal stale references. Actual runtime probe confirms
pending1/jobunresolved/currentcodecvalid, followed by normal reconcile creating
newgeneration exactly once. The audit's specific claim about retire_service
leaving a stale index is not used as evidence; the actual destroy_job API is.
Resolving refs must have the right kind and owners the correct typed row.
D3: reset existing21outcome diagnostics using _reset_counters; rebuild8derived
counters, retain3saved dirty counts. Audit mislabeled those3asderived despite
schema2 explicitly persisting them. Registry currently groups counters under
category3; correcting8scalar classifications needs no canonical wire change.
D4: actual Godot4.7.2 inheritance probe passes const/nestedtype/static calls;
choose inherited sharedRecord rather than hundreds of duplicated wrappers.
No need to test deliberately cyclic preload: implementation must have none.
D5: fullworldcoordinator retains crossownerclaim/Jobtarget consistency. This
packet validates exact ownerstate and resolvingrefkind/index; stale refs preclude
a false claim that an empty bound collaborator proves restoration is ordered.
Shared world/restore order remain coordinator prerequisites, with apply guarded
by actual supplied SimClock loadbarrier. Neither API acquires/releases it.
