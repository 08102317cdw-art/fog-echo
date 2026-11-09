import numpy as np, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont
PH="/data/assets_raw/ph"; ACG="/data/assets_raw/acgdl"; OUT="/data/sh_demo/assets/tex"; os.makedirs(OUT, exist_ok=True)
rng=np.random.default_rng(7)
M={"road":("asphalt_02",1024),"sidewalk":("concrete_pavement",1024),"concrete":("dirty_concrete",512),"brick":("red_brick_03",1024),
"pbrick":("painted_worn_brick",512),"plaster":("worn_plaster_wall",512),"siding":("weathered_plank_siding",512),"shutter":("painted_metal_shutter",512),
"door":("rough_pine_door",512),"wallpaper":("decrepit_wallpaper",512),"lino":("old_linoleum_flooring_01",512),"tile":("worn_tile_floor",512),
"dirt":("park_dirt",512),"leaves":("dry_decay_leaves",512),"cliff":("cliff_side",512),"planks":("wood_planks_grey",512),"rust1":("rusty_metal_04",512),
"rust2":("rust_coarse_01",512),"corr":("rusty_corrugated_iron",512),"rebar":("rebar_reinforced_concrete",512),"grate":("metal_grate_rusty",512),
"dplaster":("damaged_plaster",512),"rsheet":("rusty_metal_sheet",512)}
def ld(p,s,mode="RGB"): return Image.open(p).convert(mode).resize((s,s),Image.LANCZOS)
for k,(a,s) in M.items():
    d=ld(f"{PH}/{a}_diff.jpg",s); r=ld(f"{PH}/{a}_rough.jpg",s,"L"); d.putalpha(r); d.save(f"{OUT}/{k}_a.png")
    ld(f"{PH}/{a}_nor.jpg",min(s,512)).save(f"{OUT}/{k}_n.png")
for k,a,rough in [("fence","Fence003",0.5),("walkway","MetalWalkway014",0.55)]:
    d=ld(f"{ACG}/{a}/{a}_1K-JPG_Color.jpg",512); o=ld(f"{ACG}/{a}/{a}_1K-JPG_Opacity.jpg",512,"L"); d.putalpha(o); d.save(f"{OUT}/{k}_a.png")
    ld(f"{ACG}/{a}/{a}_1K-JPG_NormalGL.jpg",512).save(f"{OUT}/{k}_n.png")
# --- tileable noise via FFT
def pnoise(n, beta, seed):
    r=np.random.default_rng(seed); f=np.fft.fftfreq(n); fx,fy=np.meshgrid(f,f); k=np.sqrt(fx**2+fy**2); k[0,0]=1
    spec=(r.normal(size=(n,n))+1j*r.normal(size=(n,n)))/k**beta; spec[0,0]=0; x=np.real(np.fft.ifft2(spec)); x-=x.min(); return x/x.max()
# blood overlay (tileable RGBA): splatters + drips
N=512; a=np.zeros((N,N)); r=np.random.default_rng(3)
base=pnoise(N,1.6,11); a+=np.clip((base-0.62)*4.0,0,1)
yy,xx=np.mgrid[0:N,0:N]
for _ in range(38):
    cx,cy=r.uniform(0,N,2); rad=r.uniform(4,26)
    dx=np.minimum(abs(xx-cx),N-abs(xx-cx)); dy=np.minimum(abs(yy-cy),N-abs(yy-cy)); d=np.sqrt(dx**2+dy**2)
    a=np.maximum(a,np.clip(1.6-d/rad,0,1))
    for _ in range(int(r.integers(0,3))):  # drips downward
        w=r.uniform(1.5,4); L=r.uniform(30,160); x0=cx+r.uniform(-rad*0.6,rad*0.6)
        dxx=np.minimum(abs(xx-x0),N-abs(xx-x0)); down=(yy-cy)%N
        m=(dxx<w*(1-down/L*0.6))&(down<L); a=np.maximum(a,m*np.clip(1-down/L,0.3,1))
a=np.clip(a,0,1); a=np.array(Image.fromarray((a*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)))/255.0
det=pnoise(N,1.0,5); col=np.zeros((N,N,4)); col[...,0]=0.22+0.18*det; col[...,1]=0.015+0.02*det; col[...,2]=0.01+0.015*det; col[...,3]=np.clip(a*1.2,0,1)
Image.fromarray((col*255).astype(np.uint8),"RGBA").save(f"{OUT}/blood.png")
# dissolve/peel noise (tileable, grayscale)
dn=0.65*pnoise(256,1.3,21)+0.35*pnoise(256,0.7,22); dn=(dn-dn.min())/(dn.max()-dn.min()); Image.fromarray((dn*255).astype(np.uint8)).save(f"{OUT}/peel_noise.png")
# grime mask (tileable)
g=pnoise(256,1.2,31); Image.fromarray((g*255).astype(np.uint8)).save(f"{OUT}/grime.png")
# flashlight cookie
S=256; yy,xx=np.mgrid[0:S,0:S]; rr=np.sqrt((xx-S/2)**2+(yy-S/2)**2)/(S/2)
ck=np.clip(1-rr,0,1)**0.6*(0.85+0.15*np.cos(rr*22))*(1+0.35*np.exp(-((rr-0.55)/0.05)**2)); ck+=0.6*np.exp(-(rr/0.25)**2); ck=np.clip(ck/ck.max(),0,1)
ck*= (0.92+0.08*pnoise(S,1.0,41)); ck[rr>0.98]=0
Image.fromarray((ck*255).astype(np.uint8)).save(f"{OUT}/flashlight_cookie.png")
# fog wisp puff (RGBA, soft) & ash dot
S=256; yy,xx=np.mgrid[0:S,0:S]; rr=np.sqrt((xx-S/2)**2+(yy-S/2)**2)/(S/2)
w=np.clip(1-rr,0,1)**1.5*(0.45+0.55*pnoise(S,1.4,51)); w=np.clip(w*1.6,0,1); fw=np.zeros((S,S,4)); fw[...,:3]=1; fw[...,3]=w
Image.fromarray((fw*255).astype(np.uint8),"RGBA").save(f"{OUT}/fog_wisp.png")
S=32; yy,xx=np.mgrid[0:S,0:S]; rr=np.sqrt((xx-S/2+0.5)**2+(yy-S/2+0.5)**2)/(S/2); dt=np.zeros((S,S,4)); dt[...,:3]=1; dt[...,3]=np.clip(1-rr,0,1)**1.8
Image.fromarray((dt*255).astype(np.uint8),"RGBA").save(f"{OUT}/dot.png")
# paper
S=1024; p=pnoise(S,1.1,61); p2=pnoise(S,0.5,62); pap=np.zeros((S,S,3))
base=np.array([0.80,0.75,0.64]); stain=np.clip((pnoise(S,1.8,63)-0.6)*2.5,0,1)[...,None]
pap=base*(0.9+0.1*p[...,None])*(0.96+0.04*p2[...,None]) - stain*np.array([0.10,0.13,0.16])
yy,xx=np.mgrid[0:S,0:S]; v=np.sqrt(((xx-S/2)/(S/2))**2+((yy-S/2)/(S/2))**2); pap*=np.clip(1.08-0.22*v**2,0,1)[...,None]
Image.fromarray((np.clip(pap,0,1)*255).astype(np.uint8)).save(f"{OUT}/paper.png")
print("textures ok", len(os.listdir(OUT)))
