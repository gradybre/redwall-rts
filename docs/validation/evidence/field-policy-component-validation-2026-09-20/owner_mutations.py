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
 def tail(label,fn,marker,replacement):out[label]=in_func(s,fn,lambda x:x[:x.index(marker)]+replacement+'\n\n')
 for field,high in [('field_present','1'),('auto_rotation','1'),('seed_reserve','1'),('cycle_state','CYCLE_STATE_COUNT - 1'),('close_reason','CLOSE_REASON_COUNT - 1'),('request_state','REQUEST_STATE_COUNT - 1'),('plot_outcome','OUTCOME_COUNT - 1')]:expr('omit-byte-'+field,'not _bytes_within(columns.'+field+', '+high+')')
 for field,low,high in [('rotation_ids','NO_CROP','FarmingScript.CROP_COUNT - 1'),('rotation_cursor','0','ROTATION_LENGTH - 1'),('requested_crop','NO_CROP','FarmingScript.CROP_COUNT - 1')]:expr('omit-domain-'+field,'not _ints_within(columns.'+field+', '+low+', '+high+')')
 expr('omit-present-zone','slot < 0 or slot >= EntityDirectory.DIRECTORY_CAPACITY or generation <= 0')
 expr('omit-inactive-zone','slot != EntityDirectory.NULL_SLOT or generation != EntityDirectory.NULL_GENERATION')
 expr('omit-history-nonnegative','ordinal < NO_CYCLE or completed < 0 or cancelled < 0')
 expr('omit-participant-nonnegative','participants < 0 or resolved < 0 or withdrawn < 0')
 expr('omit-resolved-bound','resolved > participants','false',fn='_counters_refusal')
 expr('omit-participant-withdrawn-bound','participants + withdrawn > PLOT_CAPACITY')
 expr('omit-history-sum-bound','completed + cancelled > ordinal')
 expr('omit-inactive-state','state != CYCLE_IDLE or columns.participants[field] != 0 \\\n\t\t\t\tor columns.resolved[field] != 0')
 tail('omit-idle-reset-state','_idle_state_refusal','\tif columns.participants','\treturn REFUSE_NONE')
 expr('omit-open-ordinal-close','columns.cycle_ordinal[field] <= NO_CYCLE or columns.close_reason[field] != CLOSE_NONE')
 tail('omit-open-unresolved-state','_open_state_refusal','\tvar participants:','\treturn REFUSE_NONE')
 expr('omit-closed-ordinal-reason','columns.cycle_ordinal[field] <= NO_CYCLE or reason == CLOSE_NONE')
 expr('omit-completed-shape','participants <= 0 or resolved != participants \\\n\t\t\t\tor columns.completed_cycles[field] <= 0')
 tail('omit-cancelled-unresolved-state','_cancelled_state_refusal','\tif participants == 0:','\treturn REFUSE_NONE')
 expr('omit-abandoned-shape','participants != 0 or resolved != 0 or columns.withdrawn[field] <= 0')
 expr('omit-retained-completed','reason == CLOSE_COMPLETED and columns.completed_cycles[field] <= 0')
 expr('omit-retained-cancelled','reason == CLOSE_CANCELLED and columns.cancelled_cycles[field] <= 0')
 expr('omit-retained-abandoned','reason == CLOSE_ABANDONED and withdrawn <= 0')
 expr('omit-withdrawn-positive-ordinal','withdrawn > 0 and ordinal <= NO_CYCLE')
 expr('omit-request-none-crop','crop != NO_CROP',fn='_request_refusal')
 expr('omit-request-lifecycle','not present or columns.cycle_state[field] != CYCLE_CLOSED \\\n\t\t\tor columns.close_reason[field] != CLOSE_COMPLETED')
 expr('omit-request-cursor','crop != columns.rotation_ids[field * ROTATION_LENGTH + cursor]')
 expr('omit-request-empty-state','(request == REQUEST_ENTRY_NOT_CONFIGURED) != (crop == NO_CROP)')
 # Safe bypass skips malformed links rather than triggering an unrelated index exception.
 expr('omit-plot-link-range','\t\tif field < 0 or field >= FIELD_CAPACITY:\n\t\t\treturn REFUSE_COLUMN_PLOT_LEDGER','\t\tif field < 0 or field >= FIELD_CAPACITY:\n\t\t\tcontinue')
 expr('omit-null-ledger','columns.plot_cycle[plot] != NO_CYCLE \\\n\t\t\t\t\tor columns.plot_outcome[plot] != OUTCOME_UNRESOLVED')
 expr('omit-positive-stamp','cycle < FIRST_CYCLE')
 expr('omit-stamp-bound','cycle > columns.cycle_ordinal[field]')
 for field in ['participants','resolved','withdrawn']:expr('omit-open-'+field+'-equality',field+'[field] != columns.'+field+'[field]')
 expr('omit-unresolved-contribution','\t\tparticipants[field] += 1','\t\tif outcome != OUTCOME_UNRESOLVED:\n\t\t\tparticipants[field] += 1')
 expr('omit-harvested-contribution','outcome == OUTCOME_HARVESTED','false',fn='_open_counts_refusal')
 expr('omit-cleared-contribution','outcome == OUTCOME_CLEARED','false',fn='_open_counts_refusal')
 expr('omit-withdrawn-contribution','\t\tif outcome == OUTCOME_WITHDRAWN:\n\t\t\twithdrawn[field] += 1\n\t\t\tcontinue','\t\t# Withdrawal tally/exclusion deliberately omitted.')
 expr('omit-current-stamp-filter','return columns.plot_cycle[plot] == columns.cycle_ordinal[field]','return true')
 expr('omit-open-scope-filter','return columns.field_present[field] == 1 and columns.cycle_state[field] == CYCLE_OPEN','return true')
 a='\tvar code: StringName = _columns_shape_refusal(columns)\n\tif code != REFUSE_NONE:\n\t\treturn code\n\tcode = _columns_flag_refusal(columns)'
 b='\tvar code: StringName = _columns_flag_refusal(columns) if columns != null else REFUSE_COLUMN_SHAPE\n\tif code != REFUSE_NONE:\n\t\treturn code\n\tcode = _columns_shape_refusal(columns)'
 expr('flags-before-shape',a,b)
 def flags_after_rows(x):
  block='\tcode = _columns_flag_refusal(columns)\n\tif code != REFUSE_NONE:\n\t\treturn code\n';x=once(x,block,'');return once(x,'\tcode = _plot_ledger_refusal(columns)',block+'\tcode = _plot_ledger_refusal(columns)')
 out['rows-before-global-flags']=in_func(s,'columns_refusal',flags_after_rows)
 def hoist_counters(x):
  return once(x,'\tfor field: int in FIELD_CAPACITY:','\tfor early_field: int in FIELD_CAPACITY:\n\t\tcode = _counters_refusal(columns, early_field)\n\t\tif code != REFUSE_NONE:\n\t\t\treturn code\n\tfor field: int in FIELD_CAPACITY:')
 out['global-counters-before-earlier-zone']=in_func(s,'columns_refusal',hoist_counters)
 assert len(out)==49,len(out)
 return out

