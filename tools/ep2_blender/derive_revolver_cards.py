"""Re-cut founder art without blur; derive cards and the miniature sidearm.
Requires Pillow, NumPy, SciPy. Run from any working directory. All inputs and
outputs are explicit below; no generated imagery or synthesized hidden hand.
"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'src/assets/models/golden_revolver'
PROOF=ROOT/'design/train-revolver-pass'
PROOF.mkdir(parents=True,exist_ok=True)
src=Image.open(DEST/'grip_reference.jpg').convert('RGB')
rgb=np.asarray(src)
# Remove only neutral background connected to the outside; do not erase gold
# highlights or pale leather details in the interior. One-pixel geometric inset
# removes JPEG matte contamination. Edge RGB extends real interior colour.
candidate=(rgb.min(axis=2)>=218)&(np.ptp(rgb.astype(int),axis=2)<30)
seed=np.zeros(candidate.shape,bool);seed[0,:]=True;seed[-1,:]=True;seed[:,0]=True;seed[:,-1]=True
background=nd.binary_propagation(seed&candidate,mask=candidate)
# White backdrop enclosed by the trigger guard is also background. Require a
# sizeable neutral component with a pure-white core, retaining metallic glints.
labels,n=nd.label(candidate)
for label in range(1,n+1):
    region=labels==label
    if region.sum()>10 and ((rgb.min(axis=2)>=245)&region).any(): background|=region
mask=nd.binary_erosion(~background,iterations=1,border_value=1)
interior=nd.binary_erosion(mask,iterations=2,border_value=1)
distance,indices=nd.distance_transform_edt(~interior,return_indices=True)
edge=mask&~interior
clean=rgb.copy();clean[edge]=rgb[indices[0][edge],indices[1][edge]]
rgba=np.dstack((clean,mask.astype(np.uint8)*255))
cut=Image.fromarray(rgba);bounds=cut.getbbox();cut=cut.crop(bounds)
cut.save(DEST/'grip_reference_cut.png',optimize=True)

def edge_white(im):
    a=np.asarray(im.convert('RGBA'));visible=a[:,:,3]>0
    rim=visible&~nd.binary_erosion(visible,border_value=1)
    return int(((a[:,:,:3].min(axis=2)>230)&rim).sum())

cards=[]
for name,size,fit in [
    ('pickup_splash.png',(640,640),(608,608)),
    ('hud_portrait.png',(320,384),(304,368)),
    ('stage2_handoff_closeup.png',(960,540),(920,516)),
    ('fps_grip_card.png',(768,512),(744,496)),
]:
    art=cut.copy();art.thumbnail(fit,Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',size);offset=((size[0]-art.width)//2,size[1]-art.height)
    canvas.alpha_composite(art,offset);canvas.save(DEST/name,optimize=True)
    glyph_height=59*art.height/cut.height
    assert glyph_height>=14,(name,glyph_height)
    cards.append({'file':name,'size':size,'source_glyph_extent':[524,367,565,426],
        'glyph_height_pixels':round(glyph_height,2),'hand_canon':'founder glove, studded bracer and vine arm retained; no mirroring'})

# The intake hand occludes the wood. Use a fresh opposite-side render of the
# existing Blender gun alone, not glove pixels or invented hidden grip artwork.
# The camera renders +X directly, so its Bitcoin emblem is never mirror-flipped.
gun=Image.open(DEST/'sidearm_gun_only.png').convert('RGBA')
gun=gun.crop(gun.getbbox());gun.thumbnail((56,31),Image.Resampling.LANCZOS)
slot=Image.new('RGBA',(56,31));slot.alpha_composite(gun,((56-gun.width)//2,(31-gun.height)//2))
slot.save(ROOT/'src/assets/sprites/sprite_item_golden_revolver.png',optimize=True)
slot.save(DEST/'sidearm_slot.png',optimize=True)

backgrounds={'near_black':Image.new('RGB',cut.size,(8,5,13)),
    'goldrush':Image.open(ROOT/'src/assets/backgrounds/bg_l3_goldrush.jpg').convert('RGB').resize(cut.size)}
for name,bg in backgrounds.items():
    bg.paste(cut,(0,0),cut)
    # Full cutout and three 200% edge details, in the source coordinate system.
    regions=[('barrel',(276,310,446,370)),('cylinder',(500,335,590,450)),('cuff',(790,540,990,740))]
    sheet=Image.new('RGB',(max(cut.width,1000),cut.height+420),(20,15,23));sheet.paste(bg,(0,0))
    d=ImageDraw.Draw(sheet);x=0
    for label,rect in regions:
        r=(rect[0]-bounds[0],rect[1]-bounds[1],rect[2]-bounds[0],rect[3]-bounds[1])
        detail=bg.crop(r).resize(((r[2]-r[0])*2,(r[3]-r[1])*2),Image.Resampling.NEAREST)
        if x+detail.width>sheet.width:x=0
        sheet.paste(detail,(x,cut.height+20));d.text((x,cut.height+3),label+' 200%',fill='white');x+=detail.width+15
    sheet.save(PROOF/('fringe_'+name+'.png'))

old=Image.open(ROOT/'src/assets/models/golden_revolver/grip_reference.jpg')
receipt={'source_sha512':hashlib.sha512((DEST/'grip_reference.jpg').read_bytes()).hexdigest(),
    'cutout_bounds_in_source':bounds,'edge_white_pixels_after':edge_white(cut),
    'method':'outside-connected neutral background removal; 1px inset; 2px interior edge colour extension; no blur',
    'derivations':cards,'sidearm':{'size':[56,31],'facing':'+X','grip':'rear third',
    'exception':'Founder approved 14px glyph minimum only for larger cards and close-ups, 2026-10-15.',
    'source':'sidearm_gun_only.png: fresh opposite-side Blender render of the existing Remington, no hand or mirroring'}}
(PROOF/'revolver-derivation-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
assert receipt['edge_white_pixels_after']==0,receipt
print(json.dumps(receipt,indent=2))
