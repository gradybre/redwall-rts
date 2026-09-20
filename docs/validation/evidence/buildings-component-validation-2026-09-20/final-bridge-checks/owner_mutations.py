import re

def once(s,a,b):
 assert s.count(a)==1,(a,s.count(a))
 return s.replace(a,b)

def within(s,name,a,b):
 match=re.search(r'^(?:static )?func '+re.escape(name)+r'\(.*?(?=\n(?:static )?func |\Z)',s,re.M|re.S)
 assert match,name
 return s[:match.start()]+once(match[0],a,b)+s[match.end():]

def owner_mutants(s):
 m={}
 for field in ['b_present','r_present','f_present','r_valid']:
  m['flag-'+field]=within(s,'_columns_flag_refusal','image.'+field+'[row] > 1','false')
 b='_columns_building_refusal';bs='_columns_building_state_refusal';bf='_columns_building_free_refusal'
 cond='type_id < 0 or type_id >= BuildingDefinitions.BUILDING_DEFINITION_COUNT'
 # An invalid catalog id must be accepted early by this intentional fault, not indexed.
 m['building-type']=within(s,b,'\tvar tier: int = image.b_tier[row]','\tif '+cond+':\n\t\treturn REFUSE_NONE\n\tvar tier: int = image.b_tier[row]')
 for label,cond in [('tier-ordinal','tier < 0 or tier > BuildingDefinitions.TIER_TWO'),('rotation','image.b_rotation[row] < 0 or image.b_rotation[row] >= ROTATION_COUNT'),('state','image.b_state[row] < 0 or image.b_state[row] >= STATE_COUNT'),('origin','image.b_origin_tile[row] < NO_LINK or image.b_origin_tile[row] >= TILE_COUNT'),('condition','image.b_condition[row] < 0'),('interior','image.b_interior_id[row] < NO_INTERIOR'),('construction-reference','not _columns_ref_ok(image.b_construction_slot[row], image.b_construction_generation[row])')]:
  m['building-'+label]=within(s,b,cond,'false')
 m['building-clear-union']=within(s,b,'return _columns_building_free_refusal(image, row)','return REFUSE_NONE')
 m['building-eligible-tier']=within(s,bs,'COLUMN_TIER_TWO_TYPE_IDS.has(type_id)','true')
 m['building-footprint']=within(s,bs,'not _columns_extent_fits(origin, COLUMN_BUILDING_FOOTPRINT_X[type_id],\n\t\t\tCOLUMN_BUILDING_FOOTPRINT_Z[type_id], image.b_rotation[row])','false')
 room='_columns_room_refusal';rf='_columns_room_free_refusal';rs='_columns_room_state_refusal'
 for label,cond in [('type','image.r_type[row] < 0 or image.r_type[row] >= ROOM_TYPE_COUNT'),('offset','image.r_tile_offset[row] < 0 or image.r_tile_offset[row] > ROOM_TILE_LINK_CAPACITY'),('count','image.r_tile_count[row] < 0\n\t\t\tor image.r_tile_count[row] > ROOM_TILE_LINK_CAPACITY'),('mask','image.r_furniture_mask[row] < 0\n\t\t\tor image.r_furniture_mask[row] > (1 << FURNITURE_KIND_COUNT) - 1'),('occupants','image.r_occupants[row] < 0\n\t\t\tor image.r_occupants[row] > EntityDirectory.RESIDENT_LIVING_CAP'),('parent-reference','not _columns_ref_ok(image.r_building_slot[row], image.r_building_generation[row])')]:
  m['room-'+label]=within(s,room,cond,'false')
 m['room-inactive-cleared']=within(s,rf,'image.r_tile_offset[row] != 0 or image.r_tile_count[row] != 0\n\t\t\tor image.r_furniture_mask[row] != 0 or image.r_valid[row] != 0','false')
 m['room-clear-union']=within(s,rf,'image.r_type[row] != 0 or image.r_temperature_tenths[row] != 0\n\t\t\tor image.r_occupants[row] != 0','false')
 m['room-present-nonnull']=within(s,rs,'_columns_ref_is_null(image.r_building_slot[row], image.r_building_generation[row])','false')
 m['room-positive-count']=within(s,rs,'image.r_tile_count[row] < 1','false')
 m['room-span']=within(s,rs,'image.r_tile_offset[row] + image.r_tile_count[row] > ROOM_TILE_LINK_CAPACITY','false')
 f='_columns_furniture_refusal';ff='_columns_furniture_free_refusal';fs='_columns_furniture_state_refusal'
 cond='image.f_type_id[row] < 0 or image.f_type_id[row] >= FURNITURE_KIND_COUNT'
 m['furniture-type']=within(s,f,'\tif ('+cond,'\tif '+cond+':\n\t\treturn REFUSE_NONE\n\tif ('+cond)
 for label,cond in [('rotation','image.f_rotation[row] < 0 or image.f_rotation[row] >= ROTATION_COUNT'),('origin','image.f_origin_tile[row] < NO_LINK or image.f_origin_tile[row] >= TILE_COUNT'),('condition','image.f_condition[row] < 0'),('room-reference','not _columns_ref_ok(image.f_room_slot[row], image.f_room_generation[row])'),('user-reference','not _columns_ref_ok(image.f_user_slot[row], image.f_user_generation[row])')]:
  m['furniture-'+label]=within(s,f,cond,'false')
 m['furniture-inactive-null-user']=within(s,ff,'not _columns_ref_is_null(image.f_user_slot[row], image.f_user_generation[row])','false')
 m['furniture-clear-union']=within(s,ff,'image.f_type_id[row] != 0 or image.f_origin_tile[row] != NO_LINK\n\t\t\tor image.f_rotation[row] != 0 or image.f_condition[row] != 0','false')
 m['furniture-present-nonnull']=within(s,fs,'_columns_ref_is_null(image.f_room_slot[row], image.f_room_generation[row])','false')
 m['furniture-footprint']=within(s,fs,'not _columns_extent_fits(origin, size_x, size_z, image.f_rotation[row])','false')
 shape='\tif image == null or not image.is_sized():\n\t\treturn REFUSE_COLUMN_SHAPE\n'
 m['flag-before-shape']=within(s,'columns_refusal',shape,'\tif image != null and image.b_present.size() > 0 and image.b_present[0] > 1:\n\t\treturn REFUSE_COLUMN_FLAG\n'+shape)
 flags='\tvar flags: StringName = _columns_flag_refusal(image)\n\tif flags != REFUSE_NONE:\n\t\treturn flags\n'
 blocks={}
 for group,cap,letter in [('building','BUILDING_CAPACITY','b'),('room','ROOM_CAPACITY','r'),('furniture','FURNITURE_CAPACITY','f')]:
  blocks[group]='\tfor row: int in '+cap+':\n\t\tvar '+letter+'_code: StringName = _columns_'+group+'_refusal(image, row)\n\t\tif '+letter+'_code != REFUSE_NONE:\n\t\t\treturn '+letter+'_code\n'
 m['building-before-global-flags']=within(s,'columns_refusal',flags+blocks['building'],blocks['building']+flags)
 m['room-before-building']=within(s,'columns_refusal',blocks['building']+blocks['room'],blocks['room']+blocks['building'])
 m['furniture-before-room']=within(s,'columns_refusal',blocks['room']+blocks['furniture'],blocks['furniture']+blocks['room'])
 pre='\tfor row: int in BUILDING_CAPACITY:\n\t\tif image.b_type_id[row] < 0 or image.b_type_id[row] >= BuildingDefinitions.BUILDING_DEFINITION_COUNT:\n\t\t\treturn REFUSE_COLUMN_BUILDING_ENUM\n'
 m['global-building-enum-before-earlier-row']=within(s,'columns_refusal',flags,flags+pre)
 for label,kind in [('first-row-only','1'),('even-rows-only',None)]:
  t=s
  for cap in ['BUILDING_CAPACITY','ROOM_CAPACITY','FURNITURE_CAPACITY']:
   t=within(t,'columns_refusal','for row: int in '+cap+':','for row: int in '+(kind if kind else 'range(0, '+cap+', 2)')+':')
  m[label]=t
 m['skip-furniture-group']=within(s,'columns_refusal',blocks['furniture'],'')
 m['direct-image-write']=within(s,'columns_refusal',shape,shape+'\timage.b_condition[0] += 1\n')
 m['overrestrict-retired-construction']=within(s,b,'\tvar tier: int = image.b_tier[row]','\tvar tier: int = image.b_tier[row]\n\tif image.b_present[row] == 0 and tier > 0 and not _columns_ref_is_null(image.b_construction_slot[row], image.b_construction_generation[row]):\n\t\treturn REFUSE_COLUMN_BUILDING_STATE')
 assert len(m)==46,len(m)
 assert len(set(m.values()))==46
 return m
