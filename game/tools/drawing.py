import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
r=np.random.default_rng(9)
W,H=900,640
paper=Image.open("/data/sh_demo/assets/tex/paper.png").convert("RGB").resize((W,H)).point(lambda v: min(255,int(v*1.12)))
layer=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(layer)
def crayon_line(pts,col,w=5,passes=3,jit=2.2,alpha=170):
    for _ in range(passes):
        q=[(x+r.normal(0,jit),y+r.normal(0,jit)) for x,y in pts]
        d.line(q,fill=col+(alpha,),width=int(w+r.integers(-1,2)),joint="curve")
def crayon_fill(box,col,dens=0.9,ang=0.6,alpha=120):
    x0,y0,x1,y1=box; n=int((x1-x0+y1-y0)*dens/3)
    for i in range(n):
        t=i/n; x=x0+t*(x1-x0)
        d.line([(x+r.normal(0,2),y0+r.normal(0,3)),(x+(y1-y0)*ang*0.2+r.normal(0,2),y1+r.normal(0,3))],fill=col+(alpha,),width=3)
# gray scribbled sky (fog)
for i in range(260):
    y=r.uniform(20,250); x=r.uniform(0,W); L=r.uniform(40,160)
    d.line([(x,y),(x+L,y+r.normal(0,6))],fill=(120,120,125,int(r.uniform(25,60))),width=4)
# ground
crayon_line([(20,520),(300,512),(600,525),(880,515)],(90,70,50),w=6)
crayon_fill((20,522,880,600),(110,95,70),dens=0.6,alpha=70)
# school building
crayon_fill((380,250,760,515),(150,120,95),alpha=90)
crayon_line([(380,515),(380,250),(760,250),(760,515)],(60,40,30),w=6)
crayon_line([(360,252),(570,170),(780,252)],(60,40,30),w=6)
crayon_line([(570,170),(570,110)],(40,40,40),w=4); crayon_line([(570,112),(625,124),(570,138)],(170,20,20),w=5)  # flag
for cx in (430,520,620,700):
    for cy in (300,390):
        crayon_line([(cx,cy),(cx+42,cy),(cx+42,cy+46),(cx,cy+46),(cx,cy)],(30,30,40),w=4,passes=2)
        crayon_fill((cx+4,cy+4,cx+38,cy+42),(25,25,35),alpha=150)
crayon_line([(545,515),(545,440),(595,440),(595,515)],(30,20,20),w=6)
crayon_fill((549,444,591,513),(15,10,10),alpha=200)
# one window with a red face
crayon_fill((624,394,658,432),(160,15,15),alpha=180)
# girl stick figure (small) & big dad figure
def person(x,y,s,col,dress=False):
    d.ellipse([x-12*s,y-80*s,x+12*s,y-56*s],outline=col+(200,),width=4)
    if dress: crayon_line([(x,y-56*s),(x-18*s,y-12*s),(x+18*s,y-12*s),(x,y-56*s)],col,w=4)
    else: crayon_line([(x,y-56*s),(x,y-20*s)],col,w=4)
    crayon_line([(x-6*s,y-12*s if dress else y-20*s),(x-12*s,y)],col,w=4); crayon_line([(x+6*s,y-12*s if dress else y-20*s),(x+12*s,y)],col,w=4)
    crayon_line([(x-20*s,y-40*s),(x,y-48*s),(x+20*s,y-40*s)],col,w=4)
person(250,515,2.0,(40,40,90))
person(330,515,1.2,(180,40,60),dress=True)
# scratched-out third figure
person(150,515,1.7,(20,20,20))
for i in range(40):
    d.line([(110+r.uniform(0,80),370+r.uniform(0,150)),(110+r.uniform(0,80),370+r.uniform(0,150))],fill=(10,10,10,150),width=3)
# dead trees
for tx in (60,830):
    crayon_line([(tx,515),(tx+5,330)],(50,35,25),w=8)
    for k in range(5):
        y=360+k*30; crayon_line([(tx+3,y),(tx+3+r.uniform(-60,60),y-r.uniform(30,70))],(50,35,25),w=4,passes=2)
img=Image.alpha_composite(paper.convert("RGBA"),layer.filter(ImageFilter.GaussianBlur(0.6)))
f=ImageFont.truetype("/data/assets_raw/LXGWWenKai-Regular.ttf",46); dd=ImageDraw.Draw(img)
dd.text((60,40),"爸爸，我在学校等你。",font=f,fill=(150,25,25,230))
dd.text((560,580),"——小雪",font=ImageFont.truetype("/data/assets_raw/LXGWWenKai-Regular.ttf",34),fill=(60,40,40,220))
img.convert("RGB").save("/data/sh_demo/assets/tex/drawing.png")
print("ok")
