extends RefCounted
## Owner `forage`: section 4 owner 5 validator bridge and the joint section 4 + section 5
## capture/apply pair (ADR 1222 build step 3).
##
##   * `framed_refusal(record)` judges one framed section 4 block: null, owner, the schema guard,
##     the owner's compiled field keys and types against this bridge's pins, the owner shape, then
##     `Forage.columns_refusal()` over a projection that BORROWS the record's buffers.
##   * `capture_into(store, record, block)` copies the live store once through
##     `Forage.copy_columns_into()` and writes both records; the section 4 record is judged last.
##   * `apply(record, block, store)` projects both records and calls `Forage.restore_columns()`,
##     which runs both pure predicates and the Directory resolution before its first write.
## Section 1's tile heads and section 7's claims have their own boundaries in forage.gd. Nothing
## here touches a clock, barrier, signal, filesystem or reflection API, or builds a per-row object.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Forage := preload("res://scripts/core/forage.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")
const ChildSchema := preload("res://scripts/core/save_child_arenas_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

const OWNER_INDEX: int = 5
const OWNER_KEY: String = "forage"
const OWNER_VERSION: int = 1
const OWNER_FIELD_COUNT: int = 20
const CHILD_OWNER_INDEX: int = 2
const COLUMN_DETAIL_PREFIX: String = "Forage owner 5 "

## A capture or apply called without a live store.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"
## The section 5 block is missing, another owner's, or misshaped.
const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_FORAGE_BLOCK_SHAPE"

## Section 4 ordinals, in the registry's order.
const FIELD_ZONE_PRESENT: int = 0
const FIELD_PATCH_PRESENT: int = 1
const FIELD_ZONE_TYPE: int = 2
const FIELD_ZONE_DANGER: int = 3
const FIELD_ZONE_QUOTA_MILLI: int = 4
const FIELD_ZONE_PROTECTED: int = 5
const FIELD_ZONE_ENABLED: int = 6
const FIELD_ZONE_REF_SLOT: int = 7
const FIELD_ZONE_REF_GENERATION: int = 8
const FIELD_ZONE_BASIN_SLOT: int = 9
const FIELD_ZONE_BASIN_GENERATION: int = 10
const FIELD_ZONE_HARVESTED_TODAY_MILLI: int = 11
const FIELD_ZONE_QUOTA_RESERVED_MILLI: int = 12
const FIELD_ZONE_QUOTA_MODE: int = 13
const FIELD_PATCH_ITEM_ID: int = 14
const FIELD_PATCH_ZONE_SLOT: int = 15
const FIELD_PATCH_ZONE_GENERATION: int = 16
const FIELD_PATCH_STOCK_MILLI: int = 17
const FIELD_PATCH_CAPACITY_MILLI: int = 18
const FIELD_PATCH_HARVESTED_YEAR_MILLI: int = 19
const FIELD_KEYS: Array[String] = [
	"_zone_present", "_patch_present", "_zone_type", "_zone_danger", "_zone_quota_milli",
	"_zone_protected", "_zone_enabled", "_zone_ref_slot", "_zone_ref_generation",
	"_zone_basin_slot", "_zone_basin_generation", "_zone_harvested_today_milli",
	"_zone_quota_reserved_milli", "_zone_quota_mode", "_patch_item_id", "_patch_zone_slot",
	"_patch_zone_generation", "_patch_stock_milli", "_patch_capacity_milli",
	"_patch_harvested_year_milli",
]

## Section 5 ordinals, in the registry's order.
const CHILD_LINK_BUMP: int = 0
const CHILD_LINK_FREE_HEAD: int = 1
const CHILD_LINK_USED: int = 2
const CHILD_ZONE_LINK_HEAD: int = 3
const CHILD_ZONE_TILE_COUNT: int = 4
const CHILD_ZONE_PATCH_COUNT: int = 5
const CHILD_LINK_TILE: int = 6
const CHILD_LINK_ZONE: int = 7
const CHILD_LINK_TILE_NEXT: int = 8
const CHILD_LINK_ZONE_NEXT: int = 9


static func _accept() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal carrying an exact code."""
	return SaveHeader.Refusal.new(code, detail)


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 5 block against Forage's own pure column predicate."""
	var preflight: SaveHeader.Refusal = _record_preflight(record)
	if not preflight.is_ok():
		return preflight
	var columns: Forage.Columns = Forage.Columns.new()
	_project_columns(record, columns)
	var code: StringName = Forage.columns_refusal(columns)
	if code != Forage.REFUSE_NONE:
		return _refuse(code, "%srefuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


static func _record_preflight(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Null, owner, schema guard, compiled field keys, then the owner shape."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE, "no framed owner was supplied for owner 5 ('forage')")
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER, "owner %d was supplied where owner 5 is required"
			% record.owner)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY \
			or Schema.owner_version(OWNER_INDEX) != OWNER_VERSION \
			or Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA, "Forage owner5 metadata: owner identity drifted")
	for field: int in OWNER_FIELD_COUNT:
		if Schema.field_key(OWNER_INDEX, field) != FIELD_KEYS[field]:
			return _refuse(Section.REFUSE_METADATA, "Forage owner5 metadata: field %d is '%s'"
				% [field, Schema.field_key(OWNER_INDEX, field)])
	return Section.owner_shape_refusal(record)


static func _block_refusal(block: ChildSection.Block) -> SaveHeader.Refusal:
	"""The section 5 block is forage's and well shaped."""
	if block == null or block.owner != CHILD_OWNER_INDEX \
			or ChildSchema.OWNER_KEYS[CHILD_OWNER_INDEX] != OWNER_KEY or block.shape_detail() != "":
		return _refuse(REFUSE_BLOCK_SHAPE, "a well-shaped section 5 'forage' block is required")
	return _accept()


static func capture_into(store: Forage, record: Section.FramedOwner,
		block: ChildSection.Block) -> SaveHeader.Refusal:
	"""Capture both sections once; judge the written section 4 record last."""
	var target: SaveHeader.Refusal = _record_preflight(record)
	if target.is_ok():
		target = _block_refusal(block)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Forage store was supplied")
	var columns: Forage.Columns = Forage.Columns.new()
	var links: Forage.Links = Forage.Links.new()
	if not store.copy_columns_into(columns, links):
		return _refuse(store.last_column_refusal(), "%scapture refused with %s"
			% [COLUMN_DETAIL_PREFIX, String(store.last_column_refusal())])
	if not (_write_zone_fields(columns, record) and _write_patch_fields(columns, record)):
		return _refuse(Section.REFUSE_SHAPE, "%scapture could not write a column"
			% COLUMN_DETAIL_PREFIX)
	var written: SaveHeader.Refusal = _write_links(links, block)
	if not written.is_ok():
		return written
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, block: ChildSection.Block,
		store: Forage) -> SaveHeader.Refusal:
	"""Install both sections through one `restore_columns()` call. Refusal writes nothing."""
	var target: SaveHeader.Refusal = _record_preflight(record)
	if target.is_ok():
		target = _block_refusal(block)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Forage store was supplied")
	var columns: Forage.Columns = Forage.Columns.new()
	_project_columns(record, columns)
	var links: Forage.Links = Forage.Links.new()
	_read_links(block, links)
	if not store.restore_columns(columns, links):
		return _refuse(store.last_column_refusal(), "%srestore refused with %s"
			% [COLUMN_DETAIL_PREFIX, String(store.last_column_refusal())])
	return _accept()


static func _write_zone_fields(c: Forage.Columns, r: Section.FramedOwner) -> bool:
	"""Ordinals 0..13: both presence bytes and the HarvestZone columns."""
	return (r.set_u8(FIELD_ZONE_PRESENT, c.zone_present)
		and r.set_u8(FIELD_PATCH_PRESENT, c.patch_present)
		and r.set_i32(FIELD_ZONE_TYPE, c.zone_type) and r.set_i32(FIELD_ZONE_DANGER, c.zone_danger)
		and r.set_i64(FIELD_ZONE_QUOTA_MILLI, c.zone_quota_milli)
		and r.set_u8(FIELD_ZONE_PROTECTED, c.zone_protected)
		and r.set_u8(FIELD_ZONE_ENABLED, c.zone_enabled)
		and r.set_i32(FIELD_ZONE_REF_SLOT, c.zone_ref_slot)
		and r.set_i32(FIELD_ZONE_REF_GENERATION, c.zone_ref_generation)
		and r.set_i32(FIELD_ZONE_BASIN_SLOT, c.zone_basin_slot)
		and r.set_i32(FIELD_ZONE_BASIN_GENERATION, c.zone_basin_generation)
		and r.set_i64(FIELD_ZONE_HARVESTED_TODAY_MILLI, c.zone_harvested_today_milli)
		and r.set_i64(FIELD_ZONE_QUOTA_RESERVED_MILLI, c.zone_quota_reserved_milli)
		and r.set_u8(FIELD_ZONE_QUOTA_MODE, c.zone_quota_mode))


static func _write_patch_fields(c: Forage.Columns, r: Section.FramedOwner) -> bool:
	"""Ordinals 14..19: the ForagePatch columns."""
	return (r.set_i32(FIELD_PATCH_ITEM_ID, c.patch_item_id)
		and r.set_i32(FIELD_PATCH_ZONE_SLOT, c.patch_zone_slot)
		and r.set_i32(FIELD_PATCH_ZONE_GENERATION, c.patch_zone_generation)
		and r.set_i64(FIELD_PATCH_STOCK_MILLI, c.patch_stock_milli)
		and r.set_i64(FIELD_PATCH_CAPACITY_MILLI, c.patch_capacity_milli)
		and r.set_i64(FIELD_PATCH_HARVESTED_YEAR_MILLI, c.patch_harvested_year_milli))


static func _write_links(l: Forage.Links, b: ChildSection.Block) -> SaveHeader.Refusal:
	"""The three allocator scalars, then the seven section 5 columns."""
	for refusal: SaveHeader.Refusal in [
			b.set_scalar(CHILD_LINK_BUMP, l.link_bump),
			b.set_scalar(CHILD_LINK_FREE_HEAD, l.link_free_head),
			b.set_scalar(CHILD_LINK_USED, l.link_used),
			b.set_i32_column(CHILD_ZONE_LINK_HEAD, l.zone_link_head),
			b.set_i32_column(CHILD_ZONE_TILE_COUNT, l.zone_tile_count),
			b.set_i32_column(CHILD_ZONE_PATCH_COUNT, l.zone_patch_count),
			b.set_i32_column(CHILD_LINK_TILE, l.link_tile),
			b.set_i32_column(CHILD_LINK_ZONE, l.link_zone),
			b.set_i32_column(CHILD_LINK_TILE_NEXT, l.link_tile_next),
			b.set_i32_column(CHILD_LINK_ZONE_NEXT, l.link_zone_next)]:
		if not refusal.is_ok():
			return refusal
	return _accept()


static func _project_columns(r: Section.FramedOwner, c: Forage.Columns) -> void:
	"""Bind the record's twenty columns over a `Columns` image by assignment (no copy here)."""
	c.zone_present = r.u8_column(FIELD_ZONE_PRESENT)
	c.patch_present = r.u8_column(FIELD_PATCH_PRESENT)
	c.zone_type = r.i32_column(FIELD_ZONE_TYPE)
	c.zone_danger = r.i32_column(FIELD_ZONE_DANGER)
	c.zone_quota_milli = r.i64_column(FIELD_ZONE_QUOTA_MILLI)
	c.zone_protected = r.u8_column(FIELD_ZONE_PROTECTED)
	c.zone_enabled = r.u8_column(FIELD_ZONE_ENABLED)
	c.zone_ref_slot = r.i32_column(FIELD_ZONE_REF_SLOT)
	c.zone_ref_generation = r.i32_column(FIELD_ZONE_REF_GENERATION)
	c.zone_basin_slot = r.i32_column(FIELD_ZONE_BASIN_SLOT)
	c.zone_basin_generation = r.i32_column(FIELD_ZONE_BASIN_GENERATION)
	c.zone_harvested_today_milli = r.i64_column(FIELD_ZONE_HARVESTED_TODAY_MILLI)
	c.zone_quota_reserved_milli = r.i64_column(FIELD_ZONE_QUOTA_RESERVED_MILLI)
	c.zone_quota_mode = r.u8_column(FIELD_ZONE_QUOTA_MODE)
	c.patch_item_id = r.i32_column(FIELD_PATCH_ITEM_ID)
	c.patch_zone_slot = r.i32_column(FIELD_PATCH_ZONE_SLOT)
	c.patch_zone_generation = r.i32_column(FIELD_PATCH_ZONE_GENERATION)
	c.patch_stock_milli = r.i64_column(FIELD_PATCH_STOCK_MILLI)
	c.patch_capacity_milli = r.i64_column(FIELD_PATCH_CAPACITY_MILLI)
	c.patch_harvested_year_milli = r.i64_column(FIELD_PATCH_HARVESTED_YEAR_MILLI)


static func _read_links(b: ChildSection.Block, l: Forage.Links) -> void:
	"""Decode the section 5 block into `l` (fresh arrays per getter)."""
	l.link_bump = b.scalar(CHILD_LINK_BUMP)
	l.link_free_head = b.scalar(CHILD_LINK_FREE_HEAD)
	l.link_used = b.scalar(CHILD_LINK_USED)
	l.zone_link_head = b.i32_column(CHILD_ZONE_LINK_HEAD)
	l.zone_tile_count = b.i32_column(CHILD_ZONE_TILE_COUNT)
	l.zone_patch_count = b.i32_column(CHILD_ZONE_PATCH_COUNT)
	l.link_tile = b.i32_column(CHILD_LINK_TILE)
	l.link_zone = b.i32_column(CHILD_LINK_ZONE)
	l.link_tile_next = b.i32_column(CHILD_LINK_TILE_NEXT)
	l.link_zone_next = b.i32_column(CHILD_LINK_ZONE_NEXT)
