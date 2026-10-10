extends RefCounted
## The immutable underground binaries the running game opens with FileAccess, each with the digest its reader pins
## (decision 1841). Every entry is one of the readers' own constants, never a copied path, so a renewed pin moves this
## list with it; test_underground_runtime_files.gd refuses a binary the demo's code names that is missing here.
##
## Godot's exporter packs none of these by itself: they are not resources, and four sit under `.gdignore` directories,
## which an export include_filter never enters. The demo export plugin (res://addons/demo_pack_files) adds exactly
## these to the Windows demo pack, and tools/godot/verify_demo_pack.gd checks each one in the pack before the demo boots.

const Session := preload("res://scripts/core/underground_session.gd")
const RouteComposition := preload("res://scripts/core/underground_route_composition.gd")
const EntryComposition := preload("res://scripts/core/underground_entry_composition.gd")
const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")

## res:// path -> the lowercase hex SHA-256 its reader requires, in load order: the level pack (UndergroundSession),
## the six actor images (MolePresentation.load_sources), the profile wire (mole_profile_catalog), the structure
## catalog and stair motion (UndergroundRouteComposition), and the entry bundle (UndergroundEntryComposition).
const FILES: Dictionary[String, String] = {
	Session.LEVEL_PATH: Session.LEVEL_SHA,
	Session.ACTOR_PATH: Catalog.Pins.ACTOR_SHA,
	Session.HANDLING_ACTOR_PATH: Session.HANDLING_ACTOR_SHA,
	Session.HAUL_ACTOR_PATH: Session.HAUL_ACTOR_SHA,
	Session.STONE_ACTOR_PATH: Session.STONE_ACTOR_SHA,
	Session.CLAW_ACTOR_PATH: Session.CLAW_ACTOR_SHA,
	Session.PAW_ACTOR_PATH: Session.PAW_ACTOR_SHA,
	Catalog.WIRE_PATH: Catalog.Pins.WIRE_SHA,
	RouteComposition.CATALOG_PATH: RouteComposition.CATALOG_SHA,
	RouteComposition.MotionPins.WIRE_PATH: RouteComposition.MotionPins.WIRE_SHA,
	EntryComposition.Bundle.RECIPE_PATH: EntryComposition.Bundle.RECIPE_SHA,
	EntryComposition.Bundle.GROUPING_PATH: EntryComposition.Bundle.GROUPING_SHA,
	EntryComposition.Bundle.FRONTIER_PATH: EntryComposition.Bundle.FRONTIER_SHA,
	EntryComposition.Bundle.WORKPIECES_PATH: EntryComposition.Bundle.WORKPIECES_SHA,
}
## Binaries a catalog source the demo loads names but no reader opens: the entry bundle's copies of the ground-pace
## connector and the profile wire. The runtime reads the profile from Catalog.WIRE_PATH, and no reader takes the ground
## file. They are not packed.
const NAMED_UNREAD: PackedStringArray = [
	EntryComposition.Bundle.GROUND_PATH,
	EntryComposition.Bundle.PROFILE_PATH,
]
