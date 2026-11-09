# 新怪物音效：基于 Freesound CC0 素材（/data/assets_raw/fs2，见 credits.json）切片、变调、叠层、混响
import sys
_src=open('/data/tools/gen_audio.py').read().split('import sys')[0]
exec(_src)
F2="/data/assets_raw/fs2"
_cache={}
def fs(i):
    if i not in _cache: _cache[i]=load(f"{F2}/fs_{i}.mp3")
    return _cache[i]
def seg(i,a,b,fade=0.02):
    x=fs(i)[int(a*SR):int(b*SR)].copy(); k=min(int(fade*SR),len(x)//4)
    if k>0:
        w=np.linspace(0,1,k); x[:k]*=w; x[-k:]*=w[::-1]
    return x
def rs(x,f): return resample(x[None,:],f)[0]
def at(x,sec,n=None):
    o=np.zeros(int(sec*SR)+len(x)) if n is None else np.zeros(n); p=int(sec*SR); L=min(len(x),len(o)-p); o[p:p+L]+=x[:L]; return o
def sat(x,d=2.0): return np.tanh(x*d)/np.tanh(d)
def room(x,wet=0.18,sec=1.2,seed=0):
    y=reverb(x[None,:],ir(sec,0.01,4500,seed=seed),wet=wet); return y.mean(0)
def fin(x,peak=0.9,tail=0.05):
    x=fbp(x,45,None); k=int(tail*SR); x[-k:]*=np.linspace(1,0,k); return norm(x,peak)
def S(name,x,peak=0.9): save(f"{SFX}/{name}.ogg",fin(x,peak)); print(name, round(len(x)/SR,2))

def breath():
    a=rs(seg(567723,0.5,9.75,0.3),0.86)            # 低沉怪物呼吸
    fl=seg(435896,10.6,10.6+len(a)/SR,0.3)            # 湿黏血肉蠕动
    sl=rs(seg(125405,4.75,9.2,0.2),0.7)               # 口水/咕噜
    y=mix(norm(a)*0.9, norm(fl)*0.22, at(norm(sl)*0.18, 3.0, len(a)))
    y=room(y,0.2,1.0,1)[:len(a)]
    y=xfade_loop(y[None,:],1.2)[0]
    y=fbp(y,50,None); save(f"{SFX}/mon_breath.ogg",norm(y,0.8)); print("mon_breath",round(len(y)/SR,2))

def screams():
    v=[ mix(norm(seg(179345,0.1,2.55))*0.9, at(norm(rs(seg(830859,3.0,4.15),0.72))*0.6,0.05)),
        mix(norm(seg(391552,30.5,33.8))*0.85, at(norm(rs(seg(435651,0.05,2.0),0.8))*0.45,0.1)),
        mix(norm(rs(seg(830859,9.9,11.3),0.9))*0.9, at(norm(rs(seg(396797,0.25,1.3),0.75))*0.6,0.15)) ]
    for k,x in enumerate(v): S(f"mon_screech{k}", room(sat(x,1.6),0.22,1.6,10+k))
def growls():
    v=[seg(133974,0.25,2.3), rs(seg(323819,0.05,2.6),0.85), seg(830859,4.85,6.8), rs(seg(545484,22.6,25.3),0.8)]
    for k,x in enumerate(v): S(f"mon_growl{k}", room(sat(norm(x),1.3),0.15,1.0,20+k),0.85)
def hurts():
    v=[mix(norm(seg(830859,0.1,0.9))*0.9, norm(squelch(0.45,1100,200,seed=3))*0.5),
       mix(norm(rs(seg(125405,11.0,11.55),0.85))*0.9, norm(squelch(0.4,900,150,seed=4))*0.5),
       mix(norm(seg(830859,8.8,9.35))*0.9, norm(seg(411671,0.0,0.4))*0.6)]
    for k,x in enumerate(v): S(f"mon_hurt{k}", room(sat(x,1.5),0.15,1.0,30+k))
def death():
    sc=rs(seg(391552,10.4,14.9,0.1),0.82)
    gu=rs(seg(826999,3.6,5.5),0.85)
    sp=seg(414296,0.0,2.0)
    n=int((len(sc)/SR+2.2)*SR)
    e=np.ones(len(sc)); e[-int(1.2*SR):]=np.linspace(1,0.15,int(1.2*SR))
    y=mix(at(norm(sc*e)*0.85,0,n), at(norm(gu)*0.7,len(sc)/SR-0.9,n), at(norm(sp)*0.55,0.3,n))
    S("mon_death", room(sat(y,1.4),0.3,2.0,40))
def cracks():
    v=[mix(norm(seg(215140,0.6,0.9)),at(norm(seg(574752,3.6,4.15))*0.7,0.08)),
       mix(norm(seg(215140,2.95,3.35)),at(norm(seg(134025,0.55,1.1))*0.6,0.02)),
       mix(norm(seg(574752,1.2,1.4)),at(norm(seg(215140,0.2,0.5))*0.8,0.12),at(norm(seg(574752,4.6,4.75))*0.7,0.25))]
    for k,x in enumerate(v): S(f"mon_crack{k}", room(x,0.12,0.8,50+k),0.95)
def spit():
    g=mix(norm(rs(seg(826999,3.6,4.2),0.8))*0.8, norm(rs(seg(171336,0.2,1.1),0.75))*0.6)
    S("mon_gurgle", room(sat(g,1.4),0.15,1.0,60))
    s=mix(norm(seg(171336,5.6,5.9))*0.9, at(norm(seg(232211,0.15,0.45))*0.6,0.02), at(norm(seg(370710,2.55,3.3))*0.5,0.03), at(norm(rs(seg(414296,0.0,0.5),0.8))*0.4,0.0))
    S("mon_spit", room(s,0.15,1.0,61))
def acid():
    h=mix(norm(seg(414296,0.8,1.6))*0.8, at(norm(seg(382313,28.0,29.6,0.01))*0.9,0.02), at(norm(seg(338116,10.3,10.8))*0.5,0.0))
    S("acid_hit", room(h,0.12,0.8,70))
    a=mix(norm(seg(382313,28.2,32.2,0.3))*0.8, norm(np.tile(seg(202094,0.15,1.7,0.2),3)[:int(4.0*SR)])*0.45)
    a=xfade_loop(a[None,:],0.6)[0]; save(f"{SFX}/acid_loop.ogg",norm(fbp(a,80,None),0.7)); print("acid_loop")
def wake():
    n=int(2.2*SR)
    y=mix(at(norm(seg(215140,0.6,0.9)),0.0,n), at(norm(seg(574752,3.6,4.15))*0.8,0.22,n), at(norm(seg(134025,0.55,1.1))*0.7,0.5,n),
          at(norm(rs(seg(826999,4.4,5.5),0.8))*0.8,0.7,n), at(norm(seg(435896,1.5,3.0,0.2))*0.35,0.0,n))
    S("mon_wake", room(y,0.2,1.2,80))
def slit():
    y=mix(norm(rs(seg(234236,6.95,8.2),0.8))*0.7, norm(seg(435896,1.6,2.85,0.15))*0.6, at(norm(seg(411671,0,0.4))*0.5,0.1))
    S("mon_slit", room(y,0.12,0.8,90),0.8)
jobs=sys.argv[1:] or ["breath","screams","growls","hurts","death","cracks","spit","acid","wake","slit"]
for j in jobs: globals()[j]()
