import re

def once(s,a,b):
 assert s.count(a)==1,(a,s.count(a))
 return s.replace(a,b)
def in_func(s,name,change):
 a=s.index('static func '+name+'(');m=re.search(r'^static func ',s[a+1:],re.M);b=a+1+m.start() if m else len(s)
 return s[:a]+change(s[a:b])+s[b:]
def owner_mutants(s):
 out={}
 def expr(label,a,b='false',fn=None):
  start=s.index('const REFUSE_COLUMN_SHAPE')
  out[label]=in_func(s,fn,lambda x:once(x,a,b)) if fn else s[:start]+once(s[start:],a,b)
 for field,row in [('habitat_present','slot'),('stock_present','row'),('habitat_intensive','slot'),('stock_closed','row'),('stock_restocking','row')]:expr('omit-flag-'+field,'image.'+field+'['+row+'] > 1')
 # Keep the upper bound so deliberate malformed type3 cannot index beyond the compiled table.
 expr('omit-habitat-enum-lower-bound','habitat_type_id < 0 or habitat_type_id >= HABITAT_TYPE_COUNT','habitat_type_id >= HABITAT_TYPE_COUNT')
 for field in ['habitat_pollution','habitat_protected_fraction']:expr('omit-domain-'+field,'image.'+field+'[slot] < 0')
 expr('omit-domain-danger','danger < DANGER_MIN or danger > DANGER_MAX')
 expr('omit-present-self-shape','not _columns_is_live_ref(self_slot, self_generation)')
 expr('omit-present-zone-shape','not _columns_is_live_ref(zone_slot, zone_generation)')
 expr('omit-inactive-self-null','_columns_is_null_ref(self_slot, self_generation)','true',fn='_columns_habitat_ref_refusal')
 # The inactive expression and present optional-null expression occur in the same helper.
 expr('omit-inactive-zone-null','and _columns_is_null_ref(zone_slot, zone_generation):','and true:')
 for name in ['habitat_capacity_milli','habitat_effort_used','habitat_intensive']:expr('omit-inactive-'+name,'image.'+name+'[slot] != 0',fn='_columns_habitat_free_refusal')
 expr('omit-inactive-effort-domain','slots != 0 and slots != EFFORT_SLOTS_BY_TYPE[habitat_type_id]')
 expr('omit-present-effort-capacity','slots != EFFORT_SLOTS_BY_TYPE[habitat_type_id]',fn='_columns_habitat_state_refusal')
 expr('omit-present-effort-used','used < 0 or used > slots')
 expr('omit-present-habitat-capacity','image.habitat_capacity_milli[slot] != _capacity_milli_for_type(habitat_type_id)')
 expr('omit-stock-presence-link','image.stock_present[row] != image.habitat_present[parent]')
 def free_stock(x):
  a=x.index('\n');return x[:a+1]+'\treturn REFUSE_NONE\n\n\n'
 out['omit-inactive-stock-blank']=in_func(s,'_columns_stock_free_refusal',free_stock)
 expr('omit-stock-owner-ref','image.stock_habitat_slot[row] != image.habitat_ref_slot[parent] \\\n\t\t\tor image.stock_habitat_generation[row] != image.habitat_ref_generation[parent]')
 expr('omit-stock-species-range','image.stock_species_id[row] < 0')
 expr('omit-stock-capacity','image.stock_capacity_milli[row] != capacity')
 expr('omit-stock-population-lower','population < _percent_of(capacity, HARD_FLOOR_PERCENT) or population > capacity','population > capacity')
 expr('omit-stock-population-upper','population < _percent_of(capacity, HARD_FLOOR_PERCENT) or population > capacity','population < _percent_of(capacity, HARD_FLOOR_PERCENT)')
 expr('omit-stock-harvest-lower','harvested < 0 or harvested > image.habitat_capacity_milli[parent] / DAILY_QUOTA_DIVISOR','harvested > image.habitat_capacity_milli[parent] / DAILY_QUOTA_DIVISOR')
 expr('omit-stock-harvest-upper','harvested < 0 or harvested > image.habitat_capacity_milli[parent] / DAILY_QUOTA_DIVISOR','harvested < 0')
 expr('omit-hysteresis-below30','scaled_population < DEPLETION_WARNING_PERCENT * capacity and restocking != 1')
 expr('omit-hysteresis-above40','scaled_population > RESTOCK_RECOVERY_PERCENT * capacity and restocking != 0')
 expr('omit-species-distinctness','image.stock_species_id[base + other] \\\n\t\t\t\t\t\t== image.stock_species_id[base + position]')
 expr('omit-shared-quota','taken > image.habitat_capacity_milli[slot] / DAILY_QUOTA_DIVISOR')
 expr('omit-self-slot-uniqueness','image.habitat_present[other] == 1 \\\n\t\t\t\t\tand image.habitat_ref_slot[other] == image.habitat_ref_slot[slot]')
 expr('omit-zone-pair-uniqueness','image.habitat_zone_slot[zone_other] == image.habitat_zone_slot[zone_row] \\\n\t\t\t\t\tand image.habitat_zone_generation[zone_other] \\\n\t\t\t\t\t== image.habitat_zone_generation[zone_row]')
 a='\tif image == null or not image.is_sized():'
 expr('flags-before-shape',a,'\tif image != null and image.habitat_present.size() > 0 and image.habitat_present[0] > 1:\n\t\treturn REFUSE_COLUMN_FLAG\n'+a)
 a='\tvar code: StringName = _columns_flag_refusal(image)'
 expr('habitat-enum-before-global-flags',a,'\tif image.habitat_type[0] < 0 or image.habitat_type[0] >= HABITAT_TYPE_COUNT:\n\t\treturn REFUSE_COLUMN_HABITAT_ENUM\n'+a)
 a='\tcode = _columns_habitat_refusal(image)'
 expr('global-enum-before-earlier-habitat-value',a,'\tfor early_slot: int in FISH_HABITAT_CAPACITY:\n\t\tif image.habitat_type[early_slot] < 0 or image.habitat_type[early_slot] >= HABITAT_TYPE_COUNT:\n\t\t\treturn REFUSE_COLUMN_HABITAT_ENUM\n'+a)
 expr('stock-before-habitat',a,'''\tvar types_safe: bool = true
\tfor early_slot: int in FISH_HABITAT_CAPACITY:
\t\tif image.habitat_type[early_slot] < 0 or image.habitat_type[early_slot] >= HABITAT_TYPE_COUNT:
\t\t\ttypes_safe = false
\tif types_safe:
\t\tvar early_stock: StringName = _columns_stock_refusal(image)
\t\tif early_stock != REFUSE_NONE:
\t\t\treturn early_stock
'''+a)
 def quota_first(x):
  a=x.index('\t\tfor position:');b=x.index('\t\tvar taken:');c=x.index('\treturn REFUSE_NONE',b)
  return x[:a]+x[b:c]+x[a:b]+x[c:]
 out['quota-before-species']=in_func(s,'_columns_species_quota_refusal',quota_first)
 def zone_first(x):
  a=x.index('\tfor slot:');b=x.index('\tfor zone_row:');c=x.index('\treturn REFUSE_NONE',b)
  return x[:a]+x[b:c]+x[a:b]+x[c:]
 out['zone-before-self']=in_func(s,'_columns_duplicate_refusal',zone_first)
 assert len(out)==41,len(out)
 return out
if __name__=='__main__':
 from pathlib import Path
 p=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19/docs/validation/evidence/fishing-component-validation-2026-09-20/candidate-fishing.gd')
 print(len(owner_mutants(p.read_text())),'owner mutants prepared; not executed')
