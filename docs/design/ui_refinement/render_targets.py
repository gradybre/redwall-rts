"""Original UI composition references. Synthetic values; not Godot screenshots.
Run with Pillow. All geometry is in logical UI pixels, transformed once by S.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math, json
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'visuals'; FONTS=OUT/'fonts'; OUT.mkdir(exist_ok=True)
C=dict(ink='#14211B', panel='#1E3028', hover='#2B4638', pressed='#111C17', text='#F5F0DF', muted='#BECABF', gold='#E6C77A', success='#9DD8AF', warning='#FFD28A', danger='#FFB3AD', paper='#EAE1C8', paper_hover='#E0D4B8', paper_pressed='#D3C29E', paper_text='#25372D', paper_muted='#43523F', paper_line='#596953', edge='#708171', track='#C9C1A9', fill='#466647')
class Canvas:
 def __init__(self,w,h,scale=1):
  self.w=w;self.h=h;self.s=scale;self.q=2;self.im=Image.new('RGB',(w*2,h*2),'#66765B');self.d=ImageDraw.Draw(self.im);self.fonts={};self.text_boxes=[]
 def b(self,x):return round(x*self.s*self.q)
 def box(self,x,y,w,h):return tuple(self.b(a) for a in (x,y,x+w,y+h))
 def rect(self,x,y,w,h,fill,r=0,stroke=None,sw=1):
  self.d.rounded_rectangle(self.box(x,y,w,h),radius=self.b(r),fill=C.get(fill,fill),outline=C.get(stroke,stroke) if stroke else None,width=max(1,self.b(sw)))
 def line(self,points,fill,sw=1):self.d.line([(self.b(x),self.b(y)) for x,y in points],fill=C.get(fill,fill),width=max(1,self.b(sw)),joint='curve')
 def oval(self,x,y,w,h,fill,stroke=None,sw=1):self.d.ellipse(self.box(x,y,w,h),fill=C.get(fill,fill) if fill else None,outline=C.get(stroke,stroke) if stroke else None,width=max(1,self.b(sw)))
 def text(self,x,y,text,size=16,color='text',weight='regular',anchor='left',maxw=None):
  key=(size,weight,self.s)
  if key not in self.fonts:
   fn='NotoSerif-SemiBold.ttf' if weight=='serif' else 'NotoSans-SemiBold.ttf' if weight=='bold' else 'NotoSans-Regular.ttf'
   self.fonts[key]=ImageFont.truetype(str(FONTS/fn),self.b(size))
  f=self.fonts[key];width=self.d.textlength(text,font=f)/(self.s*self.q)
  if maxw is not None:assert width<=maxw+0.1,(text,width,maxw)
  if anchor=='right':x-=width
  if anchor=='center':x-=width/2
  self.d.text((self.b(x),self.b(y)),text,font=f,fill=C.get(color,color),anchor='lt')
  self.text_boxes.append((text,x,y,width,size))
 def icon(self,name,x,y,size=24,color='text'):
  # Original small diagram glyphs; actual icon export/optical QA remains executor work.
  sc=size/24
  def l(pts,w=1.8):self.line([(x+a*sc,y+b*sc) for a,b in pts],color,w*sc)
  if name=='bowl':l([(2,9),(5,17),(10,20),(15,20),(20,17),(22,9),(2,9)]);l([(8,5),(10,2)]);l([(14,5),(16,2)])
  elif name=='pause':self.rect(x+5*sc,y+4*sc,4*sc,16*sc,color,1);self.rect(x+15*sc,y+4*sc,4*sc,16*sc,color,1)
  elif name=='close':l([(6,6),(18,18)]);l([(18,6),(6,18)])
  elif name=='wood':l([(3,6),(17,6),(22,11),(8,11),(3,6),(3,17),(8,21),(22,21),(22,11)]);l([(8,11),(8,21)])
  elif name=='stone':l([(2,19),(6,8),(13,4),(20,9),(22,19),(2,19)]);l([(6,8),(13,12),(20,9)])
  elif name=='people':
   self.oval(x+7*sc,y+2*sc,9*sc,9*sc,None,color,1.6*sc);l([(3,22),(3,18),(7,14),(16,14),(21,18),(21,22)])
  elif name=='bed':l([(2,3),(2,22)]);l([(2,17),(22,17),(22,22)]);l([(2,9),(9,9),(9,14),(2,14)]);l([(9,9),(20,9),(22,14),(9,14)])
  elif name=='flame':l([(12,1),(17,8),(16,11),(20,9),(21,16),(17,22),(8,22),(3,16),(5,9),(7,13),(12,1)])
  elif name=='leaf':l([(3,22),(18,2)]);l([(7,17),(3,13),(3,9),(8,11),(10,13)]);l([(11,11),(14,6),(21,4),(19,11),(14,14)])
  elif name=='zone':l([(2,8),(2,2),(8,2)]);l([(16,2),(22,2),(22,8)]);l([(22,16),(22,22),(16,22)]);l([(8,22),(2,22),(2,16)]);l([(8,15),(15,8)])
  elif name=='build':l([(3,13),(12,3),(22,13)]);l([(6,11),(6,22),(18,22),(18,11)]);l([(10,22),(10,16),(14,16),(14,22)])
  elif name=='work':l([(3,21),(16,8),(13,5),(16,2),(23,9),(20,12),(17,9)]);l([(3,3),(7,3),(9,7),(5,11),(1,7),(1,3)])
  elif name=='menu':
   for a in (5,12,19):l([(3,a),(21,a)])
  elif name=='history':l([(4,2),(18,2),(21,5),(21,22),(4,22),(4,2)]);l([(8,8),(17,8)]);l([(8,12),(17,12)]);l([(8,16),(14,16)])
  elif name=='lock':l([(5,11),(19,11),(19,22),(5,22),(5,11)]);l([(8,11),(8,5),(10,2),(14,2),(16,5),(16,11)])
  elif name=='check':l([(4,12),(9,17),(20,5)],2.2)
  elif name=='warning':l([(12,2),(23,22),(1,22),(12,2)]);l([(12,8),(12,14)]);l([(12,17),(12,19)],2)
  else:l([(4,4),(20,4),(20,20),(4,20),(4,4)])
 def sprig(self,x,y,w=100,color='paper_line'):
  self.line([(x,y+8),(x+w,y+8)],color,0.7)
  for i in range(4):
   a=x+w/2+i*7-12
   self.line([(a,y+8),(a+4,y),(a+9,y+4),(a+4,y+8)],color,0.9)
 def button(self,x,y,w,h,label,paper=False,selected=False,focus=False,disabled=False,icon=None,state='default'):
  fill='panel' if not paper else 'paper';fg='text' if not paper else 'paper_text';border='muted' if not paper else 'paper_line'
  if state=='hover':fill='hover' if not paper else 'paper_hover'
  if state=='pressed':fill='pressed' if not paper else 'paper_pressed'
  if selected:fill='gold' if not paper else 'panel';fg='ink' if not paper else 'text'
  if disabled:fg='muted' if not paper else 'paper_muted'
  self.rect(x,y,w,h,fill,6,border)
  if selected and w>=120:self.icon('check',x+8,y+(h-12)/2,12,fg)
  if focus:self.rect(x-4,y-4,w+8,h+8,None,8,'gold' if not paper else 'ink',2)
  if icon:self.icon(icon,x+10,y+(h-18)/2,18,fg);self.text(x+36,y+(h-16)/2-1,label,16,fg,'bold',maxw=w-44)
  else:self.text(x+w/2,y+(h-16)/2-1,label,16,fg,'bold','center',maxw=w-12)
 def world(self):
  lw=self.w/self.s;lh=self.h/self.s
  self.rect(0,0,lw,lh,'#66765B')
  # Neutral original contour board, deliberately not a simulated settlement/map.
  for i in range(9):
   pts=[]
   for x in range(-40,int(lw)+80,14):pts.append((x,lh*.25+i*42+35*math.sin(x/160+i*.4)))
   self.line(pts,'#748167',1)
  if lw<1120:
   self.rect(192,160,300,66,'panel',8)
   self.text(342,173,'DESIGN REFERENCE',14,'text','bold','center')
   self.text(342,197,'Synthetic state · no engine capture',14,'muted','regular','center',maxw=280)
  else:
   self.rect(lw/2-230,160,460,66,'panel',8)
   self.text(lw/2,173,'DESIGN REFERENCE · SYNTHETIC STATE',14,'text','bold','center')
   self.text(lw/2,197,'Contour backdrop is not a game-world render.',14,'muted','regular','center')
 def save(self,name):
  for t,x,y,w,h in self.text_boxes:
   assert x>=0 and y>=0 and x+w<=self.w/self.s+.1 and y+h<=self.h/self.s+.1,(name,t,x,y,w,h)
  self.im.resize((self.w,self.h),Image.Resampling.LANCZOS).save(OUT/name)
  return dict(file=name,pixels=[self.w,self.h],logical_scale=self.s,text_runs=len(self.text_boxes),status='DESIGN_REFERENCE_NOT_RUNTIME')

def detail(c,x,y,w,h,narrow=False):
 c.rect(x+3,y+5,w,h,'#344330',9)
 c.rect(x,y,w,h,'paper',8,'paper_line',1)
 c.line([(x+7,y+14),(x+7,y+h-14)],'paper_line',1)
 c.oval(x+20,y+22,42,42,'paper_hover')
 # Original generic mouse emblem: species mark, not a portrait of Rowan.
 c.oval(x+24,y+29,12,12,'paper_muted');c.oval(x+41,y+26,13,13,'paper_muted');c.oval(x+29,y+36,25,18,'paper_muted');c.oval(x+50,y+42,6,5,'paper_muted')
 c.text(x+76,y+24,'Warden Rowan',20,'paper_text','serif',maxw=w-126)
 c.text(x+76,y+54,'Mouse · Adult',14,'paper_muted')
 c.button(x+w-44,y+12,32,32,'',paper=True);c.icon('close',x+w-39,y+17,22,'paper_text')
 c.sprig(x+20,y+82,w-40)
 if not narrow:
  c.text(x+20,y+112,'Health',16,'paper_text','bold');c.text(x+w-20,y+112,'100 / 100',16,'paper_text','bold','right')
  c.text(x+20,y+154,'Daily needs',20,'paper_text','serif')
  for i,label in enumerate(['Fullness','Rest','Comfort','Social','Purpose']):
   yy=y+194+i*52;c.text(x+20,yy,label,16,'paper_text');c.text(x+w-20,yy,'75%',16,'paper_text','bold','right')
   c.rect(x+20,yy+26,w-40,8,'track',4);c.rect(x+20,yy+26,(w-40)*.75,8,'fill',4)
   c.text(x+w-88,yy+2,['−2.50 pp/h','−3.75 pp/h','0.00 pp/h','−1.00 pp/h','0.00 pp/h'][i],14,'paper_muted','regular','right')
  c.line([(x+20,y+474),(x+w-20,y+474)],'paper_line',.7)
  c.text(x+20,y+495,'Current activity',14,'paper_muted');c.text(x+20,y+520,'No assigned job',16,'paper_text','bold')
  c.text(x+20,y+550,'Keeping 3 · 45,000 / 80,000 XP',14,'paper_muted')
 else:
  c.text(x+20,y+108,'Health 100 / 100',16,'paper_text','bold')
  for i,label in enumerate(['Fullness','Rest']):
   yy=y+148+i*52;c.text(x+20,yy,label,16,'paper_text');c.text(x+w-32,yy,'75%',16,'paper_text','bold','right')
   c.rect(x+20,yy+26,w-52,8,'track',4);c.rect(x+20,yy+26,(w-52)*.75,8,'fill',4)
   c.text(x+w-88,yy+2,['−2.50 pp/h','−3.75 pp/h'][i],14,'paper_muted','regular','right')
  c.rect(x+w-24,y+142,16,100,'paper_hover',4);c.rect(x+w-21,y+145,10,38,'paper_line',4)
 c.line([(x+20,y+h-64),(x+w-20,y+h-64)],'paper_line',.7)
 c.button(x+20,y+h-56,w-40,44,'Center view',paper=True)

def hud(w=1920,h=1080,user=1):
 s=max(1,min(2,min(w/1920,h/1080)))*user;c=Canvas(w,h,s);c.world();lw=w/s;lh=h/s;n=lw<1120;wide=lw>=1600
 rw=176 if n else 480 if wide else 360;tw=256 if n else 320 if wide else 304;mw,mh=(160,192) if n else (256,288) if wide else (208,240);dw=320 if n else 384 if wide else 336
 c.rect(16,16,rw,88,'panel',8,'edge')
 if not n:
  names=[('bowl','Provisions','5.48 days'),('flame','Fuel','4.20 days'),('wood','Wood','180 U'),('stone','Stone','100 U'),('people','Residents','12 / 256'),('bed','Beds','12 / 12')]
  cw=(rw-32)/3
  for i,(icon,label,val) in enumerate(names):
   xx=24+(i%3)*(cw+8);yy=24+(i//3)*36;c.icon(icon,xx,yy+7,20);c.text(xx+28,yy,label,14,'muted');c.text(xx+28,yy+17,val,18,'text','bold',maxw=cw-28)
 else:
  c.icon('bowl',26,30,20);c.text(54,29,'5.48 days',16,'text','bold');c.icon('people',26,68,20);c.text(54,65,'12 residents',16,'text','bold');c.button(152,38,32,44,'+');
 tx=lw-16-tw;c.rect(tx,16,tw,48 if n else 88,'panel',8,'edge')
 if n:
  xx=tx+4
  for wid,label in [(44,'Ⅱ'),(36,'1×'),(36,'2×'),(36,'4×'),(36,'▦'),(36,'≡')]:
   c.button(xx,22,wid,36,label if label in ('1×','2×','3×','4×') else '',selected=label in ('Ⅱ','1×'))
   if label not in ('1×','2×','3×','4×'):c.icon('pause' if label=='Ⅱ' else 'history' if label=='▦' else 'menu',xx+(wid-20)/2,30,20,'ink' if label=='Ⅱ' else 'text')
   xx+=wid+4
 else:
  c.button(tx+8,24,56,36,'',selected=True);c.icon('pause',tx+26,31,20,'ink')
  for i,label in enumerate(['1×','2×','4×']):c.button(tx+72+i*44,24,36,36,label,selected=i==0)
  c.text(tx+8,72,'Spring 1 · 06:00',16,'text','bold');c.button(tx+tw-44,64,36,32,'');c.icon('menu',tx+tw-36,70,20)
 # Empty alert card is absent. Only history entry remains visible.
 hx=lw/2+min(360 if n else 420,lw-32)/2-36
 c.button(hx,84 if n else 24,32,32,'');c.icon('history',hx+6,90 if n else 30,20)
 if not n:c.rect(lw/2-102,116,204,36,'panel',6);c.text(lw/2,125,'Paused by you',16,'text','bold','center')
 else:c.rect(lw/2-82,84,164,36,'panel',6);c.text(lw/2,94,'Paused by you',16,'text','bold','center')
 c.rect(16,lh-16-mh,mw,mh,'panel',8,'edge');c.text(28,lh-mh,'Settlement map',16,'text','bold',maxw=mw-24)
 c.rect(24,lh-mh+28,mw-16,mh-48,'#5C7352',4)
 c.line([(32,lh-mh+80),(mw-4,lh-48)],'#A2B697',2);c.line([(44,lh-38),(mw-24,lh-mh+54)],'#8DA285',2)
 c.text(mw/2+16,lh-16-48,'Illustrative map',14,'text','regular','center')
 dh=min(640,lh-144);dx=lw-16-dw;dy=lh-16-dh;detail(c,dx,dy,dw,dh,n)
 left=mw+32;right=lw-dw-32;avail=right-left;cw=min(640,avail);xx=left+(avail-cw)/2;cols=3 if n else 6;bh=44 if n else 52;rows=2 if n else 1;ch=24+rows*bh+(rows-1)*8;yy=lh-16-ch
 c.rect(xx,yy,cw,ch,'panel',8,'edge');bw=(cw-24-(cols-1)*8)/cols
 labels=['Build','Zone','Work','Food','People','Goals'] if n else ['Build','Zones','Jobs','Food','Residents','Objectives'];icons=['build','zone','work','bowl','people','history']
 for i,(label,icon) in enumerate(zip(labels,icons)):
  x=xx+12+(i%cols)*(bw+8);y=yy+12+(i//cols)*(bh+8)
  if i==4:c.rect(x,y,bw,bh,'gold',6);fg='ink'
  else:fg='muted' if i in [0,3,5] else 'text'
  if i in [0,3,5]:c.icon('lock',x+bw-13,y+3,10,fg)
  if i==4:c.icon('check',x+bw-13,y+3,10,fg)
  if n:c.icon(icon,x+7,y+13,16,fg);c.text(x+28,y+13,label,16,fg,'bold',maxw=bw-34)
  else:c.icon(icon,x+(bw-18)/2,y+4,18,fg);c.text(x+bw/2,y+28,label,14,fg,'bold','center',maxw=bw-4)
 c.save('01_hud_resident_wide.png' if not n else '02_hud_resident_narrow.png')
 return c

def setup():
 c=Canvas(1920,1080);c.world();c.rect(0,0,1920,1080,'#26352B');x,y,w,h=528,220,864,640;c.rect(x+5,y+7,w,h,'ink',12);c.rect(x,y,w,h,'paper',12,'paper_line',2)
 c.text(x+32,y+28,'Create a settlement',28,'paper_text','serif');c.text(x+32,y+74,'Choose the beginnings of your community.',16,'paper_muted')
 c.button(x+w-52,y+20,32,32,'',paper=True);c.icon('close',x+w-47,y+25,22,'paper_text')
 c.line([(x+32,y+112),(x+w-32,y+112)],'paper_line')
 fx=x+32;fw=460
 for yy,label,value in [(y+136,'Settlement name',"Rowan’s Refuge"),(y+236,'World seed','20260905')]:
  c.text(fx,yy,label,16,'paper_text','bold');c.rect(fx,yy+30,fw,44,'paper_hover',4,'paper_line');c.text(fx+12,yy+43,value,16,'paper_text')
 c.text(fx,y+336,'Architecture',16,'paper_text','bold')
 for i,label in enumerate(['Abbey','Holt','Fortress']):c.button(fx+i*156,y+366,148,44,label,paper=True,selected=i==0)
 c.text(fx,y+436,'Mode',16,'paper_text','bold');c.button(fx+88,y+424,174,44,'Standard',paper=True,selected=True);c.button(fx+270,y+424,190,44,'Sandbox',paper=True)
 c.button(fx,y+492,32,32,'',paper=True,selected=True);c.icon('check',fx+6,y+498,20,'text');c.text(fx+44,y+500,'Show tutorial guidance',16,'paper_text')
 sx=x+544;c.line([(sx-24,y+136),(sx-24,y+532)],'paper_line',.7);c.sprig(sx+18,y+156,210)
 c.text(sx+124,y+198,'A place to',28,'paper_text','serif','center');c.text(sx+124,y+239,'call home',28,'paper_text','serif','center')
 # Original decorative hall/hearth line study, not a runtime building model.
 c.line([(sx+30,y+374),(sx+123,y+314),(sx+218,y+374)],'paper_line',2);c.line([(sx+48,y+365),(sx+48,y+439),(sx+200,y+439),(sx+200,y+365)],'paper_line',2)
 c.line([(sx+95,y+439),(sx+95,y+389),(sx+150,y+389),(sx+150,y+439)],'paper_line',2);c.icon('flame',sx+108,y+402,30,'paper_line')
 c.text(sx+124,y+484,'Begin paused. Take your time.',14,'paper_muted','regular','center',maxw=252)
 c.line([(x+24,y+h-60),(x+w-24,y+h-60)],'paper_line');c.button(x+32,y+h-52,144,44,'Cancel',paper=True);c.button(x+w-244,y+h-52,212,44,'Create settlement',paper=True,selected=True)
 c.rect(656,936,608,54,'panel',8);c.text(960,952,'DESIGN REFERENCE · SYNTHETIC FORM STATE',14,'text','bold','center')
 c.save('03_new_settlement.png')

def states():
 c=Canvas(1600,1000);c.rect(0,0,1600,1000,'ink');c.text(48,36,'The woodland interface',28,'text','serif');c.text(48,83,'Component direction · synthetic states · not engine captures',16,'muted')
 c.rect(48,136,736,404,'panel',8,'edge');c.rect(816,136,736,404,'paper',8,'paper_line')
 for x,p in [(48,False),(816,True)]:
  fg='paper_text' if p else 'text';c.text(x+24,162,'Journal controls' if p else 'Forest controls',20,fg,'serif')
  entries=[('Default','default',False,False,False),('Hover','hover',False,False,False),('Pressed','pressed',False,False,False),('Selected','default',True,False,False),('Focused','default',False,True,False),('Selected + focus','default',True,True,False)]
  for i,(label,st,sel,foc,dis) in enumerate(entries):
   xx=x+24+(i%3)*232;yy=218+(i//3)*116;c.text(xx,yy,label,14,fg);c.button(xx,yy+30,208,44,'Residents',paper=p,selected=sel,focus=foc,disabled=dis,state=st)
  c.button(x+24,462,208,44,'Unavailable',paper=p,disabled=True,icon='lock');c.text(x+252,475,'Reason remains readable on focus.',14,fg)
 c.rect(48,574,736,180,'panel',8,'danger',2);c.icon('warning',72,604,24,'danger');c.text(112,602,'Zone could not be placed',20,'text','serif');c.text(72,648,'Choose a valid area inside the settlement.',16);c.button(72,689,180,44,'Return to brush');c.text(272,703,'Keep the draft so it can be corrected.',14,'muted')
 c.rect(816,574,736,180,'paper',8,'paper_line');c.text(840,602,'Needs are values, not debug output',20,'paper_text','serif');c.text(840,652,'Fullness',16,'paper_text');c.text(1528,652,'75%',16,'paper_text','bold','right');c.rect(840,684,688,8,'track',4);c.rect(840,684,516,8,'fill',4);c.text(840,716,'7500 maps to 75%; exact basis points remain in data.',14,'paper_muted')
 c.text(48,794,'Material and icon language',20,'text','serif');c.sprig(1190,808,334,'gold')
 for i,name in enumerate(['bowl','wood','bed','build','zone','people','history','leaf']):
  x=60+i*184;c.icon(name,x,854,32,'gold');c.text(x+46,861,name.capitalize(),16,'text')
 c.text(48,938,'Quiet borders · opaque reading surfaces · no fabricated data · distinct focus · no oversized empty panels',16,'muted')
 c.save('04_component_states.png')

if __name__=='__main__':
 hud();hud(1280,720,1.5);setup();states();print('Rendered four design targets; text fit assertions passed.')
