# Component owner follow-through — draft, 2026-09-20

The streaming envelope is one prerequisite. The complete section4 task still requires semantic validation for all18owners and production capture/restore bindings. Wire-shape success alone cannot release SAVE-CAPTURE.

A bulk API must preserve every canonical field owned by the module, including associated sections. Existing split APIs may support capture, but installation must compose coupled state under the unpublished load barrier. Do not treat a successful section4-only assignment as a complete owner restoration.

| Owner | Registered sections | Current section4 bulk API | Work remaining |
|---|---|---|---|
| buildings | 1, 4, 5 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| construction | 4, 5 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| farming | 1, 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| field_policy | 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| fishing | 4, 7 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| forage | 1, 4, 5, 7 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| injury | 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| jobs | 4, 5 | copy/restore exists | Expose/reuse pure validation against saved inputs; bind existing API |
| movement | 2, 4, 9 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| needs | 4 | copy/restore exists | Expose/reuse pure validation against saved inputs; bind existing API |
| orchard_hive | 4, 5 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| priorities | 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| residents | 4, 14 | copy/restore exists | Expose/reuse pure validation against saved inputs; bind existing API |
| resource_nodes | 1, 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| schedule | 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| transforms | 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| work | 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |
| world_init | 1, 4 | missing | Freeze exact domains and retained unused values; implement atomic bulk API and adapter |

Cross-section identity and atomicity apply to Buildings1/4/5, Construction4/5, Farming1/4, Fishing4/7, Forage1/4/5/7, Jobs4/5, Movement2/4/9, OrchardHive4/5, Residents4/14, ResourceNodes1/4 and WorldInit1/4. Existing readers or per-row mutators do not automatically satisfy those transactions.

The next task split must make the streaming envelope, semantic validation and bulk owner bindings prerequisites of SAVE-S4-CODEC. Only add exact owner implementation packets after source-backed domain audits; preserve existing source/registry authority and the separately gated coordinator.
