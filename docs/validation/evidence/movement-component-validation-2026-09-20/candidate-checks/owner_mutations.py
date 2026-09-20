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
 m['phase-domain']=within(s,'_column_row_refusal','phase < MOTION_IDLE or phase >= MOTION_PHASE_COUNT','false')
 for f in ['correction_x','correction_z','radius_u','desired_yaw','next_yaw','blocked_ticks']:
  m['reserved-'+f]=within(s,'_columns_reserved_clear','image.'+f+'[row] == 0','true')
 for f in ['remainder_x','remainder_z']:
  m['remainder-'+f]=within(s,'_column_row_refusal','_is_remainder(image.'+f+'[row])','true')
 m['speed-membership']=within(s,'_column_row_refusal','speed != 0 and ResidentsScript.SIZE_MOVEMENT_U_PER_S.find(speed) < 0','false')
 for f in ['vx','vz']:
  m['velocity-'+f]=within(s,'_column_row_refusal','_is_within(image.'+f+'[row], limit)','true')
 for f in ['grid_cell','grid_next']:
  m['cell-'+f]=within(s,'_column_row_refusal','_is_cell(image.'+f+'[row])','true')
 m['target-pair']=within(s,'_column_row_refusal','_is_target_pair(image.next_x[row], image.next_z[row])','true')
 for label,cond in [('velocity','image.vx[row] != 0 or image.vz[row] != 0'),('remainder','image.remainder_x[row] != 0 or image.remainder_z[row] != 0'),('target','image.next_x[row] != 0 or image.next_z[row] != 0'),('next-cell','image.grid_next[row] != NO_REQUEST')]:
  m['idle-'+label]=within(s,'_columns_idle_refusal',cond,'false')
 for label,cond in [('speed','image.speed_u_per_s[row] <= 0'),('cell','image.grid_cell[row] < 0')]:
  m['travel-'+label]=within(s,'_columns_travelling_refusal',cond,'false')
 t=within(s,'_columns_travelling_refusal','image.grid_next[row] < 0','false')
 m['travel-target-binding']=within(t,'_columns_travelling_refusal','return _columns_target_is_centre(image, row, image.grid_next[row])','return REFUSE_NONE')
 for phase,label in [('MOTION_ARRIVED','arrived'),('not-arrived','terminal')]:
  for suffix,cond in [('speed','image.speed_u_per_s[row] <= 0'),('cell','image.grid_cell[row] < 0'),('next-cell','image.grid_next[row] != NO_REQUEST')]:
   check='phase != MOTION_ARRIVED' if phase=='MOTION_ARRIVED' else 'phase == MOTION_ARRIVED'
   m[label+'-'+suffix]=within(s,'_columns_state_refusal',cond,'('+check+' and '+cond+')')
 m['arrived-target']=within(s,'_columns_arrived_refusal','return _columns_target_is_centre(image, row, image.grid_cell[row])','return REFUSE_NONE')
 m['terminal-velocity']=within(s,'_columns_state_refusal','image.vx[row] != 0 or image.vz[row] != 0','false')
 shape='\tif image == null or not image.is_sized():\n\t\treturn REFUSE_COLUMN_SHAPE\n'
 before='\tif image != null and image.movement_phase.size() > 0 and (image.movement_phase[0] < MOTION_IDLE or image.movement_phase[0] >= MOTION_PHASE_COUNT):\n\t\treturn REFUSE_COLUMN_PHASE\n'
 m['phase-before-shape']=within(s,'columns_refusal',shape,before+shape)
 after='\tfor phase_row: int in MOTION_CAPACITY:\n\t\tif image.movement_phase[phase_row] < MOTION_IDLE or image.movement_phase[phase_row] >= MOTION_PHASE_COUNT:\n\t\t\treturn REFUSE_COLUMN_PHASE\n'
 m['global-phase-before-earlier-row']=within(s,'columns_refusal',shape,shape+after)
 repair='\tif _movement_phase[row] == MOTION_TRAVELLING:\n\t\t_travelling_count -= 1\n'
 m['readmission-omitted-adjustment']=within(s,'_attach_route',repair,'')
 m['readmission-unconditional-adjustment']=within(s,'_attach_route',repair,'\t_travelling_count -= 1\n')
 assert len(m)==34,len(m)
 assert len(set(m.values()))==34
 return m
