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
board('mine4gold_board',(1024,224),[('mine4gold.app',40,118,'OldStandard-Bold.ttf',(226,190,98))])
def tin(name,logo,size=(512,640)):
 # Uniswap's own vertical logo (github.com/Uniswap/brand-assets, pixels unchanged) on a painted tin plate
 r=random.Random(1115);w,h=size;im=Image.new('RGB',size,(226,216,192));d=ImageDraw.Draw(im)
 for _ in range(900):
  x=r.randrange(w);y=r.randrange(h);c=r.randint(150,205);d.point((x,y),fill=(c,c-12,c-38))
 for _ in range(60):
  x=r.choice([r.randrange(0,26),r.randrange(w-26,w)]);y=r.randrange(h);d.ellipse((x,y,x+r.randrange(4,14),y+r.randrange(4,14)),fill=(122,72,38))
 d.rectangle((10,10,w-11,h-11),outline=(58,44,34),width=6)
 for x,y in ((26,26),(w-27,26),(26,h-27),(w-27,h-27)):d.ellipse((x-7,y-7,x+7,y+7),fill=(70,66,60))
 lg=Image.open(logo).convert('RGBA');sc=min((w-110)/lg.width,(h-110)/lg.height);lg=lg.resize((int(lg.width*sc),int(lg.height*sc)),Image.LANCZOS)
 im.paste(lg,((w-lg.width)//2,(h-lg.height)//2),lg);im.save(OUT/(name+'.png'))
tin('uniswap_tin','tools/ep2_cabin/brand/Uniswap_verticallogo_pink.png')
(OUT/'sign_manifest.json').write_text(json.dumps({'liquidity_sign.png':{'owner':"LOGAN'S CABIN",'sentence':'Be a liquidity provider.'},'goldmine_wordmark.png':{'text':'GOLDMINE'},'mine4gold_board.png':{'text':'mine4gold.app'},'uniswap_tin.png':{'logo':'Uniswap vertical logo, pink (github.com/Uniswap/brand-assets)'},'btc_reserves.png':{'text':'BTC RESERVES'},'GM':'res://src/episode2/assets/textures/logos/logo_gold_mine.png','BTC':'res://src/episode2/assets/textures/tex_btc_coin.png','posters':['res://src/episode2/extras/town/posters/poster_rh.png','res://src/episode2/extras/town/posters/poster_jack_hammer.png']},indent=2)+'\n')
