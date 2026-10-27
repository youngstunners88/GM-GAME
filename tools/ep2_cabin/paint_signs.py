"""Exact local lettering; canonical logo/poster pixels are reused unchanged."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import random,json
OUT=Path('src/episode2/extras/lake/cabin');OUT.mkdir(parents=True,exist_ok=True)
FONTS=Path('tools/ep2_forge/fonts')
def font(n,s):return ImageFont.truetype(str(FONTS/n),s)
def board(name,size,lines):
 r=random.Random(827);im=Image.new('RGB',size,(34,47,36));d=ImageDraw.Draw(im);w,h=size
 for y in range(h):
  t=r.randint(-5,5);d.line((0,y,w,y),fill=(34+t,47+t,36+t))
 for _ in range(160):
  x=r.randrange(w);y=r.randrange(h);d.line((x,y,min(w,x+r.randrange(12,130)),y+r.randrange(-1,2)),fill=(46,56,40),width=1)
 d.rounded_rectangle((8,8,w-9,h-9),radius=8,outline=(143,113,63),width=3)
 for text,y,sz,face,color in lines:
  f=font(face,sz);d.text((w/2,y),text,font=f,fill=color,anchor='mt',stroke_width=0)
 im.save(OUT/(name+'.png'))
board('liquidity_sign',(1024,320),[("LOGAN'S CABIN",24,39,'Rye-Regular.ttf',(207,173,103)),('Be a liquidity provider.',112,84,'OldStandard-Bold.ttf',(235,220,173))])
board('goldmine_wordmark',(512,128),[('GOLDMINE',22,59,'OldStandard-Bold.ttf',(222,185,94))])
board('btc_reserves',(512,256),[('BTC',18,85,'Rye-Regular.ttf',(224,187,99)),('RESERVES',138,55,'OldStandard-Bold.ttf',(221,211,175))])
(OUT/'sign_manifest.json').write_text(json.dumps({'liquidity_sign.png':{'owner':"LOGAN'S CABIN",'sentence':'Be a liquidity provider.'},'goldmine_wordmark.png':{'text':'GOLDMINE'},'btc_reserves.png':{'text':'BTC RESERVES'},'GM':'res://src/episode2/assets/textures/logos/logo_gold_mine.png','BTC':'res://src/episode2/assets/textures/tex_btc_coin.png','posters':['res://src/episode2/extras/town/posters/poster_rh.png','res://src/episode2/extras/town/posters/poster_jack_hammer.jpg']},indent=2)+'\n')
