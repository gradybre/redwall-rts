import re

def once(s,a,b):
 assert s.count(a)==1,(a,s.count(a))
 return s.replace(a,b)
def in_func(s,name,change):
 a=s.index('static func '+name+'(');m=re.search(r'^static func ',s[a+1:],re.M);b=a+1+m.start() if m else len(s)
 return s[:a]+change(s[a:b])+s[b:]
def owner_mutants(s):
 out={}
 def expr(label,a,b='false',fn=None):out[label]=in_func(s,fn,lambda x:once(x,a,b)) if fn else once(s,a,b)
 expr('omit-present-byte','image.present[row] > 1')
 for name,lo,hi in [('crop_id','CROP_NONE','CROP_COUNT'),('state','STATE_EMPTY','STATE_COUNT'),('soil','SOIL_LOAM','SOIL_COUNT')]:expr('omit-enum-'+name,'image.'+name+'[row] < '+lo+' or image.'+name+'[row] >= '+hi)
 for name,lo,hi in [('fertility','FERTILITY_MIN','FERTILITY_MAX'),('moisture','MOISTURE_MIN','MOISTURE_MAX'),('health','HEALTH_MIN','HEALTH_MAX')]:expr('omit-value-'+name,'image.'+name+'[row] < '+lo+' or image.'+name+'[row] > '+hi)
 expr('omit-value-growth','image.growth_milli_hours[row] < 0')
 expr('omit-value-compost','image.compost_milli[row] != COMPOST_MIRROR_NONE \\\n\t\t\tand image.compost_milli[row] != COMPOST_MILLI_PER_TILE')
 expr('omit-value-sow-day','image.sow_day[row] < 0')
 expr('omit-family-range','image.last_family[row] < FAMILY_NONE or image.last_family[row] >= FAMILY_COUNT')
 expr('omit-history-pair','not is_history_pair_consistent(image.last_family[row], image.family_streak[row])')
 def no_present_identity(x):return x[:x.index('\tif image.tile[row] < 0')]+'\treturn REFUSE_NONE\n\n\n'
 out['omit-present-identity']=in_func(s,'_columns_identity_refusal',no_present_identity)
 expr('omit-inactive-identity','image.tile[row] != NO_ROW or image.ref_slot[row] != EntityDirectory.NULL_SLOT \\\n\t\t\t\tor image.ref_generation[row] != EntityDirectory.NULL_GENERATION')
 expr('omit-free-crop','image.crop_id[row] != CROP_NONE')
 expr('omit-free-state','image.state[row] != STATE_EMPTY')
 expr('omit-empty-state','crop != CROP_NONE or image.growth_milli_hours[row] != 0 \\\n\t\t\t\tor image.health[row] != INITIAL_HEALTH or image.sow_day[row] != 0')
 expr('omit-nonempty-crop','crop < 0 or crop >= CROP_COUNT')
 expr('omit-positive-sow-day','image.sow_day[row] < MIN_CALENDAR_DAY')
 expr('omit-crop-soil','(CROP_ALLOWED_SOILS[crop] & (1 << image.soil[row])) == 0')
 expr('omit-growth-ceiling','image.growth_milli_hours[row] > target + MILLI_HOURS_PER_HOUR - 1')
 expr('omit-sown-growth','growth != 0 or health != INITIAL_HEALTH','health != INITIAL_HEALTH')
 expr('omit-sown-health','growth != 0 or health != INITIAL_HEALTH','growth != 0')
 expr('omit-growing-health','health <= HEALTH_MIN or growth >= target','growth >= target')
 expr('omit-growing-threshold','health <= HEALTH_MIN or growth >= target','health <= HEALTH_MIN')
 expr('omit-ripe-health','health <= HEALTH_MIN or growth < target','growth < target')
 expr('omit-ripe-threshold','health <= HEALTH_MIN or growth < target','health <= HEALTH_MIN')
 expr('omit-health-wither-threshold','\t\tif growth >= target:','\t\tif false:')
 expr('omit-age-wither-threshold','\tif growth < target:','\tif false:')
 expr('omit-tile-uniqueness','_columns_has_duplicate(image.tile)')
 expr('omit-ref-slot-uniqueness','_columns_has_duplicate(image.ref_slot)')
 a='\tif image == null or not image.is_sized():'
 b='\tif image != null and image.present.size() > 0 and image.present[0] > 1:\n\t\treturn REFUSE_COLUMN_PRESENT\n'+a
 expr('present-before-shape',a,b)
 def enum_before_present(x):
  a='\tfor row: int in FARM_PLOT_CAPACITY:\n\t\tif image.present[row] > 1:'
  b='\tvar early_enum: StringName = _columns_enum_refusal(image, 0)\n\tif early_enum != REFUSE_NONE:\n\t\treturn early_enum\n'+a
  return once(x,a,b)
 out['early-enum-before-global-present']=in_func(s,'columns_refusal',enum_before_present)
 def enum_before_value(x):
  a='\tfor row: int in FARM_PLOT_CAPACITY:\n\t\tvar code: StringName = _columns_row_refusal(image, row)'
  b='\tfor early_row: int in FARM_PLOT_CAPACITY:\n\t\tvar early_code: StringName = _columns_enum_refusal(image, early_row)\n\t\tif early_code != REFUSE_NONE:\n\t\t\treturn early_code\n'+a
  return once(x,a,b)
 out['global-enum-before-earlier-row-value']=in_func(s,'columns_refusal',enum_before_value)
 a='\tif _columns_has_duplicate(image.tile):\n\t\treturn REFUSE_COLUMN_DUPLICATE_TILE\n\tif _columns_has_duplicate(image.ref_slot):\n\t\treturn REFUSE_COLUMN_DUPLICATE_REF'
 b='\tif _columns_has_duplicate(image.ref_slot):\n\t\treturn REFUSE_COLUMN_DUPLICATE_REF\n\tif _columns_has_duplicate(image.tile):\n\t\treturn REFUSE_COLUMN_DUPLICATE_TILE'
 expr('ref-duplicate-before-tile',a,b)
 assert len(out)==35,len(out)
 return out

if __name__=='__main__':
 from pathlib import Path
 p=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19/docs/validation/evidence/farming-component-validation-2026-09-20/candidate-farming.gd')
 print(len(owner_mutants(p.read_text())),'prepared unique owner variants; not executed')
