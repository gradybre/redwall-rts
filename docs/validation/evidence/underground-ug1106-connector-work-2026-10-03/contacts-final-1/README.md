# Actual ConnectorContacts focused evidence

This is the concrete contact component of decision1106. Actual Directory,
Buildings, Construction, Router, Work, Gear, Inventory, Reservations, Sites,
Terrain, Space, Placement, Locations and Routes participate in the tests.
The fixture's source motion certificates and installation geometry are
explicitly synthetic. These checks do not activate an entrance source,
installation motion, stair traversal, native memory or worker timing.

The exact source/test hashes are in `source-sha256.json`. Independent source
review subsequently found two medium gaps. This original passing run is
superseded by the corrected and independently accepted `contacts-final-2`;
it is retained to distinguish the original evidence from the final candidate.

| Strict singleton | Tests | Assertions | Failures |
|---|---:|---:|---:|
| ConnectorContacts | 18 | 7228 | 0 |
| ConnectorWork | 22 | 258 | 0 |
| ConnectorPlacements | 29 | 4004 | 0 |
| EntryPlacements | 13 | 466 | 0 |
| EntryFrontier | 17 | 402 | 0 |
| Total | 99 | 12358 | 0 |

Every strict unexpected error/warning and object/resource leak count is zero.
Every corresponding raw-log diagnostic/leak count is zero. The clean editor
import has no unexpected diagnostic. The zero-warning analyzer passed both
new files. `invocation.json` records successful source pin checks, exact
commands, and restoration of project settings and assets.

The harness temporarily uses `Redwall-ug-connector-contacts` as the Godot user
directory so this run does not share writable fixtures with another agent.
It restores the original project bytes after validation. From repository root:

```sh
python3 docs/validation/evidence/underground-ug1106-connector-work-2026-10-03/reproduce_contacts.py \
  --out docs/validation/evidence/underground-ug1106-connector-work-2026-10-03/contacts-final-1 \
  --port 6156 \
  --suite test_underground_connector_contacts.gd \
  --suite test_underground_connector_work.gd \
  --suite test_underground_connector_placements.gd \
  --suite test_underground_entry_placements.gd \
  --suite test_underground_entry_frontier.gd
```

The earlier iteration directories retain rejected runs. Iterations1–5 exposed
registry/fixture wiring problems and the actual Gear lazy-ID assumption;
iteration7 exposed an incorrectly armed productive-observer test, corrected to
the real source observation; iterations9–10 exposed the retained-history
negative fixture's Room namespace mistake. Iteration11 is the final own-suite
pass at the same two source pins as this five-suite run. No rejected result is
used as passing evidence. History-only fixtures seed permanent rows explicitly
and do not claim to have performed paid construction.

Runtime reflection counts2910 logical reused bytes, including both fixed
fragment banks and every nested caller record. `reproduce_frame_census.py`
derives the pinned source's longest own numeric helper chain,289 bytes. Adding
the existing512-byte nested reader allowance gives801, below the admitted1024
helper allowance. The whole3934 logical bytes fit the4096 Contacts subreserve.
`frame-census.json` preserves that calculation; it is not native allocation
measurement. No new persistent entity, paid progress, receipt or permission
bank exists in this component. The actual route-query timing gate remains open.

The earlier26-group/44-wood entrance was an engineering candidate. Current
passing ascent motion uses128u rise/512u tread run. The approved per-tread and
landing wood-only prices stand; an active source must derive its own group
count, physical dependencies and complete bill.
