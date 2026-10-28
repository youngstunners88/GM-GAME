from PIL import Image,ImageDraw,ImageFont,ImageFilter
import random,math
random.seed(1886)
w,h=1600,1000
im=Image.new('RGB',(w,h)); px=im.load()
for y in range(h):
 for x in range(w):
  edge=min(x,y,w-1-x,h-1-y); shade=min(1,edge/95); fold=5*math.exp(-((x-800)/7)**2)+4*math.exp(-((y-500)/6)**2); n=random.gauss(0,2)
  px[x,y]=(int(203+34*shade+n-fold),int(170+40*shade+n-fold),int(115+38*shade+n-fold))
d=ImageDraw.Draw(im)
ink='#49331f';red='#8a3425'
font='/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'
f=lambda s:ImageFont.truetype(font,s)
def text(p,t,s=24,fill=ink,anchor='mm'):d.text(p,t,font=f(s),fill=fill,anchor=anchor)
def road(pts):
 for a,b in zip(pts,pts[1:]):
  length=math.dist(a,b)
  for k in range(int(length/17)):
   t=k*17/length;u=min(1,(k*17+9)/length);d.line((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u),fill=ink,width=3)
def place(p,t):
 x,y=p;d.rectangle((x-13,y-12,x+13,y+9),outline=ink,width=3);d.line((x-17,y-12,x,y-25,x+17,y-12),fill=ink,width=3);text((x,y+32),t,22)
d.rectangle((27,27,w-28,h-28),outline=ink,width=3);d.rectangle((36,36,w-37,h-37),outline=ink,width=1)
text((800,91),'GOLD COUNTRY',54);text((800,143),'A traveller’s chart • claims, trails & watering places',21)
# Lake and river, inked water contours.
d.ellipse((1005,290,1390,480),fill='#b1b9a0',outline=ink,width=3)
for i in range(7):d.arc((1020+i*8,300+i*6,1375-i*8,465-i*6),5,168,fill='#65796c',width=2)
text((1190,382),"LOGAN’S LAKE",30);place((1400,395),'Logan’s cabin')
d.line((1180,476,1170,535,1220,590,1200,660,1270,724,1280,842),fill='#778a77',width=14)
text((1375,660),'RIVER',22)
road([(370,660),(360,540),(370,400),(590,345),(810,290),(1030,355)])
road([(590,345),(780,480),(830,720),(1040,795)])
# Town inset geography, with stables south of Main Street, armory off its north-west side.
d.rounded_rectangle((115,495,655,875),radius=20,outline=ink,width=2)
text((385,843),'GOLD TOWN • MAIN STREET',26)
d.line((370,555,370,775),fill='#a47c4b',width=17)
for p,t in [((240,620),'Claims office'),((500,620),'Saloon'),((185,735),'Rich & Utah'),((240,535),'Jail'),((370,420),'Dude’s stables'),((1060,795),'Auction grounds')]:place(p,t)
text((785,398),'LAKE TRAIL',22);text((800,435),'from Dude’s ranch',17)
# Mountains and crosshatched terrain.
for x,y in [(710,610),(760,650),(900,580),(640,230),(720,220),(1470,260),(980,210)]:
 d.line((x-30,y+30,x,y-25,x+38,y+30),fill=ink,width=2)
 d.line((x,y-25,x+7,y+3,x-2,y-3,x-13,y+15),fill=ink,width=1)
for i in range(160):
 x=random.randint(75,1515);y=random.randint(195,920)
 if 660<x<1000 and y>480:d.line((x,y,x+7,y-3),fill='#b3915c',width=1)
# Compass and cartographer legend.
cx,cy=1450,805
for a in range(8):
 t=a*math.pi/4;r=65 if a%2==0 else 35
 d.polygon([(cx+math.sin(t)*r,cy-math.cos(t)*r),(cx+math.sin(t+.5)*14,cy-math.cos(t+.5)*14),(cx,cy)],fill=ink)
text((cx,cy-85),'N',25);text((cx,cy+85),'S',20);text((cx-85,cy),'W',20);text((cx+85,cy),'E',20)
text((800,925),'— Roads drawn by hand • distances approximate —',22)
im.quantize(colors=48,dither=Image.Dither.NONE).save('src/episode2/ui/region_map.png',optimize=True)
