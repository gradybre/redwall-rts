# Locations, spatial history and connected movement

This is a source-to-design atlas, not a measured canonical world map. The complete location directory is `place_index.md`; exact book records and locators are in `catalog.json`. The diagrams below show selected documented connectivity. Spacing, symbol size and line length do not encode distance, orientation or elevation unless stated.

## 1. Select a place's era before its geometry

| Place family | Source states | Asset and scenario implications |
| --- | --- | --- |
| Redwall Abbey | Planned refuge/building project in Mossflower; developing institutions in Outcast; established communities in later narratives; damage, repair and room reuse recur | Specify construction state, occupied rooms, service access, stored supplies and current memorials; do not import the mature Abbey into a founding era |
| Kotir | Damp occupied fortress, underground cells and levied stores; engineered flooding/collapse in Mossflower; buried tower and cellars in Long Patrol | Distinguish standing, flooded, buried, excavated and collapsed states; changes create route history and spatial hazards |
| Brockhall | Root-built household, domestic chambers, archives and map table in Mossflower; earlier family home references; hidden and dangerous interiors in Triss | Model roots as structural and navigational features, with connected front/rear access and room use chosen by era |
| Salamandastron | Household fortress with kitchens, forge, gardens, command and ancestral rooms; siege/occupation; caves, drains, water shortage and later repairs | Match lord, garrison and repairs to era. A recognizable mountain silhouette does not prove identical interior topology in every book |
| Otter holts and Guosim camps | Riverbanks, cave homes, boats, temporary camps, flotillas, shoreline shelters and hidden stores | Boat landing and storage belong beside ordinary sleeping, food and gathering spaces; relocation is a household decision |
| Noonvale | Council lodge, family cottages, waterfall pool, orchard and vegetable garden | Peaceful politics and productive landscape are usable content alongside the better-known fortresses |
| Marshank | Quarry, compound, pit, longhouse and shore setting | Primarily a coercive source institution; liberation or aftermath adaptations need explicit boundary handling |
| Sampetra / Castle Marl / Riftgard | Distinct island or coastal command centers, harbors, chambers, captives and changing control | Keep each island and institution separate. Ports, supply and civilians matter; source cruelty does not define required gameplay |
| Small independent homes | Treehouses, hollow oaks, bank burrows, root caverns, cliff ledges, rafts, cottages and dens | Strong candidates for varied selectable settlement forms and meaningful neighbors; give each a connected everyday access route |

## 2. Underground movement and inhabited earth

### Lord Brocktree: the escape and return route

Source references: hidden pool cavern 705–739; overhead route 1346–1368; low sea exit 1550–1673; return enlargement 3084–3091. These are `LB-PLACE-hidden-pool-cavern`, `LB-PLACE-coiling-snake-ceiling-route`, `LB-PLACE-low-sea-exit-tunnel`, and `LB-PLACE-northern-mountain-rock-spur` in the book catalog.

```text
[Mountain interior]
        |
   hidden fissure
        |
[Pool-cavern ledge] -- climb / assembled rope --> [Overhead opening]
                                                       |
                                               assisted descent
                                                       |
                                               [Low passage]
                                                       |
                                          [Sea cave / tidal mouth]
                                                       |
                                          [Northern rocky shore]
```

The source includes rope assembled from carried materials, assistance for elders, difficult clearance, sea surge and a later return at favorable tide. Brocktree must crawl and enlarge an opening. A large body does not pass through because it belongs to the player; an older or injured traveler is not denied all agency because unaided traversal is difficult.

The adjacent upper-cell rescue is a different route. Rulango carries line ends; fixed rings and an organized hauling group do the lifting. Do not merge that rescue into a universal flying transport action.

### Mossflower: excavation changes the landscape

Kotir flood tunnels, blocks 2755–2950, connect watercourse and former lake basin through planned excavation. Flooding/collapse at 4806–4811 changes the site. The novel provides shoring, grade, plugs and sluice references; these are design evidence, not engineering-certified construction instructions.

```text
[River bend] --> [Controlled diversion / tunnel] --> [Former basin + Kotir]
                        |
                 excavation and support

Historical state change:
[Occupied fortress] --> [Rising water / collapse] --> [Lake / buried remains]
```

For ordinary colony play, use the same spatial principles for cellars, root passages, drains and inhabited burrows. Military flooding is a separate scenario mechanic and is not automatically adopted by DEC-035.

### The Long Patrol: buried structures and route failure

The buried northwest Kotir tower is placed beneath the Abbey south-wall area through drawings and exploration (2366–2481). A higher opening, bend and old window form the treasure passage (2427–2653). Later cellars contain stairs, mud, a far ledge and an old mole tunnel (2863–2984). Removing a structural stone causes collapse; the source establishes consequence, not a safe building procedure.

```text
[Abbey excavation shaft]
           |
[Broken tower stair / eroded floor]
           |
   elevated passage opening --> [Bent passage / old window]
           |                              X collapse after removal
           |
     [Lower cavern] -- constrained crossing --> [Far ledge / old tunnel]
```

The new game geometry must reconcile grades and walkable connections itself. Source phrases such as “forty paces” remain attributed narrative distance, not meters or grid tiles.

## 3. Swimming, diving, currents and boats

| Source family | Relevant evidence | Game-direction use |
| --- | --- | --- |
| Lord Brocktree | Gurth paddles successfully at 1034–1036; Trobee swims at 1668; Bucko swims later; Ruff learns sea work; low-tide sea-cave access differs from surge | Training, water familiarity, shore access and load matter beyond species identity |
| Salamandastron | Great South Stream, branching waterfall route, hidden creek, Great Lake and island household; mountain rescue/drain routes | Separate river, lake, shore and underground-water connections. An island destination needs a landing or climb, not just water proximity |
| Marlfox | Blocked sidestream, confluence relaunch, gorge and waterfall rescue, cave mouth, underground river, raft and lake approach | A blocked water route can require landing, carrying, scouting and relaunch. Route knowledge changes options without changing world geometry magically |
| Pearls of Lutra | Harbor/inlet/cove distinctions, sea travel, holt caves, iceberg and island refuge | Craft state, landing access, weather exposure and known sheltered stops support expedition planning |
| Triss | Reef approach, hidden sea cave, low-tide repair site, boat cache, ford and creek landing | Sea craft require navigable approach and repair access; tide changes the usable workspace |
| Outcast | Household raft, current split and hazardous wet descent described in its route dossiers | Keep branch direction, arrival shore and assistance explicit; a tether can transmit another person's fall rather than guarantee safety |

Do not assign a universal “otters swim / everybody else cannot” permission table. The accepted movement direction calls for body, equipment, load and connected access compatibility. Actual trait values, learned-skill mechanics and breath rules belong to the movement specification, not this library.

Diving is not interchangeable with surface swimming. A proposed underwater route must identify an entry, submerged segment, destination or exit, and access to air under the completed engineering contract. The source corpus does not supply a universal oxygen meter, dive depth or speed formula.

## 4. Climbing and canopy access

Tree homes, nest ledges, wall access, roots, belltowers, ropes and steep caves make climbing useful for daily work as well as dramatic escapes. Polleekin's treehouse in Martin the Warrior, squirrel and bird homes in Mossflower, the Abbey spire in Salamandastron, Marlfox's nesting shelf and gorge, and Triss's woodland and wall routes are distinct references.

```text
[Ground path] --> [Climbable trunk / built stair] --> [Home platform]
                                                         |
                                                [Connected branch]
                                                         |
                                                  [Work location]

[Ground stores] --> [Approved hauling point] --> [Platform stores]
```

This is an authored generic topology based on the reference family, not a canonical floor plan. Hauling goods is a separate access problem from moving an unladen creature. A unit reaching a platform does not imply that a barrel, stretcher or building beam can use the same connection.

The model brief must include contact surfaces, route opening, usable landing and silhouette at the gameplay camera. Decorative branches must not look like traversable bridges unless the mechanical map supports them. A source climber can have a harness, rope or learned technique without making that equipment magically appear on every unit model.

## 5. Source-to-map authoring fields

Before a selected literary place becomes a buildable scenario map, its plan must contain every field below. This table defines the research handoff, not a replacement for the existing spatial save schema.

| Field | Required content |
| --- | --- |
| `source_refs` | One or more book-qualified place/system records and precise passage locators |
| `era_state` | Named narrative state: standing, occupied, damaged, under construction, flooded, abandoned, excavated or restored as applicable |
| `authored_geometry` | Explicit statement that model dimensions and grid coordinates are game-authored unless independently measured evidence exists |
| `region_nodes` | Complete named set of surface, underground, water, canopy and interior areas in the selected map |
| `route_edges` | Directed connections with both endpoints; reverse traversal specified separately where conditions differ |
| `access_conditions` | Mechanical-owner references for body/load clearance, slope, support, water/tide, air, equipment and assistance |
| `construction_method` | Excavated, built-and-covered or natural-cavity adaptation under DEC-029/031; combinations explicitly connected |
| `ordinary_jobs` | Selected daily jobs that actually use each non-surface route |
| `state_changes` | Which events open, block, repair, flood or relocate routes, with owner-spec references |
| `recovery` | Behavior when a route becomes invalid while occupied; engineering contract required before implementation |
| `art_refs` | Reviewed image IDs plus literary material/room/prop records |
| `uncertainties` | Specific unresolved claims; empty array only if none apply |

## 6. EARS rules

| ID | Requirement |
| --- | --- |
| MAP-001 | When a map combines historical structures, the author shall select one coherent era state or explicitly author a composite adaptation. |
| MAP-002 | When a building contains a usable room, its map shall provide a connected route from a valid access region. |
| MAP-003 | When an underground, water or canopy route is used for daily work, its job plan shall account for carried goods and return access. |
| MAP-004 | When tide, collapse, construction or damage invalidates an edge, the implementation shall use the completed movement-owner recovery contract before enabling that state change. |
| MAP-005 | When a novel supplies a directional or travel-time claim, the atlas shall retain that wording as attributed evidence and shall not convert it into exact geometry without an authored conversion. |
| MAP-006 | When spatial claims conflict between books, the source atlas shall preserve both and the selected scenario shall document its resolution. |

This pass supplies substantially more location and movement evidence. It does not close the existing five movement engineering gates or provide an unverified full-world floor plan.
