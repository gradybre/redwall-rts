#!/usr/bin/env python3
"""Independent Cycle3 design arithmetic and durable-handoff checks, not runtime acceptance."""
from pathlib import Path
from fractions import Fraction as F
import argparse,json,re
ROOT=Path(__file__).resolve().parents[2]
COUNT=0
def check(v,label):
 global COUNT
 COUNT+=1
 if not v:raise AssertionError(label)
def geometry(w,h,user):
 s=min(max(min(F(w,1920),F(h,1080)),1),2)*user;lw,lh=F(w)/s,F(h)/s
 p='wide' if lw>=1600 else 'standard' if lw>=1120 else 'narrow'
 rw={'wide':480,'standard':360,'narrow':176}[p];tw={'wide':320,'standard':304,'narrow':256}[p]
 aw=min(360,lw-32) if p=='narrow' else 420 if p=='wide' else 360
 alerts=((lw-aw)/2,76 if p=='narrow' else 16,aw,48 if p=='narrow' else 104)
 return lw,lh,p,(16,16,rw,128),(lw-16-tw,16,tw,48 if p=='narrow' else 88),alerts
def overlap(a,b):return a[0]<b[0]+b[2] and b[0]<a[0]+a[2] and a[1]<b[1]+b[3] and b[1]<a[1]+a[3]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--source-root',type=Path,required=True);ap.add_argument('--package-root',type=Path,default=ROOT);args=ap.parse_args();root=args.package_root
 for w,h in [(1280,720),(1920,1080),(3840,2160)]:
  for scale in [F(1),F(5,4),F(3,2)]:
   lw,lh,p,r,t,a=geometry(w,h,scale)
   check(not overlap(r,t) and not overlap(r,a) and not overlap(a,t),'HUD zones overlap')
   top=max(128,r[1]+r[3],t[1]+t[3],a[1]+a[3])+8
   check(top==152,'management band')
   height=min(560,lh-16-top);width=min(640,lw-32)
   body=((lw-width)/2,top+(lh-16-top-height)/2,width,height)
   check(not any(overlap(body,z) for z in [r,t,a]),'compact management covers top HUD')
   check(height-64-60>=188,'minimum compact body')
 for w,p in [(1119,'narrow'),(1120,'standard'),(1599,'standard'),(1600,'wide')]:
  _,_,actual,r,t,a=geometry(w,720,F(1));check(actual==p,'breakpoint');check(not overlap(r,a) and not overlap(t,a),'breakpoint overlap')
 check(2+48+4+48+2==104,'reachable two full alerts')
 check(max(23,24)+24==48,'full notice padding');check(max(23,24)+16<=44,'narrow summary padding')
 check(100-70-4<48,'tall first notice leaves no second')
 check(20+26+8<=56,'resource typography')
 check(1+2<=4,'inset focus ring stays in resource padding')
 check(8+56==64 and 64+56+8==128,'resource rows/frame')
 check(136+32+8==176,'narrow expand bounds')
 # §8/§9 primary extents: independent designated counts, never sum of child tables.
 check(sum([8192,4096,128,640,1024])==14080,'five extent sum')
 check(8192!=14080 and 8192!=512+8192,'primary not sum')
 check(23+8+4+363112+4==363151,'section8 byte length')
 schema=json.loads((args.source_root/'docs/planning/canonical_state_registry.json').read_text())
 # Traverse metadata shape independently of the registry's outer owner layout.
 fields=[]
 def walk(x):
  if isinstance(x,dict):
   if 'shape' in x and 'hash' in x:fields.append(x)
   for v in x.values():walk(v)
  elif isinstance(x,list):
   for v in x:walk(v)
 walk(schema)
 canonical=[f for f in fields if f['hash']]
 strings=[f['shape']['declared_capacity'] for f in canonical if isinstance(f['shape'].get('declared_capacity'),str)]
 pattern=re.compile(r'^`([^`]+)`\s*(<=|=)\s*(\d+)$')
 parsed=[pattern.fullmatch(x) for x in strings]
 check(all(parsed),'bounded capacity grammar')
 eq=sum(m[2]=='=' for m in parsed);lte=sum(m[2]=='<=' for m in parsed)
 check(eq+lte==len(strings),'operator accounting');check(lte>0,'bounded stores retain distinct operator')
 for bad in ['`x` = -1','`x` = 1; run()','x=1','`x` <= infinity']:
  check(pattern.fullmatch(bad) is None,'unsafe grammar refused')
 check(1<=16384 and 1!=16384,'below-max capacity is valid bound')
 q=json.loads((root/'docs/planning/work_queue.json').read_text());ts={t['id']:t for t in q['tasks']}
 check(ts['MOVE-ENVELOPES']['astra_answered'] is False,'movement remains gated')
 check('UI-C3-EVIDENCE' in ts['ART-UI-12']['depends_on'],'fresh visual evidence dependency')
 check('SAVE-S8-COUNT' in ts['SAVE-CAPTURE']['depends_on'],'save primary prerequisite')
 inbox=json.loads((root/'docs/rulings/requests/open_items.json').read_text());answered={i['anchor']:i for i in inbox['answered']}
 for key in ['multi-table-primary-count','declared-capacity-as-prose','alert-card-44px-is-not-reachable-typography','alert-zone-inside-workspace-frame']:
  check(key in answered,'answered anchor');p,a=answered[key]['ruling'].split('#');check('id="'+a+'"' in (root/p).read_text(),'ruling anchor exists')
 check(any(i['anchor']=='move-g01-clearance-and-modes' for i in inbox['items']),'partial question remains open')
 print(f'PASS Cycle3: {COUNT} checks; design geometry/format/grammar/handoff only.')
 print(f'Observed registry: {len(canonical)} canonical fields; {len(strings)} capacity strings = {eq} exact + {lte} upper bounds. Source proofs still owned by REGISTRY-CAPACITY-AUDIT.')
if __name__=='__main__':main()
