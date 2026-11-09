import numpy as np, subprocess, os
from scipy import signal
SR=44100; R=np.random.default_rng(1234)
SFX="/data/sh_demo/assets/sfx"; MUS="/data/sh_demo/assets/music"; FS="/data/assets_raw/fs"; KN="/data/assets_raw/kenney"
def load(path, sr=SR, ch=1):
    raw=subprocess.run(["ffmpeg","-v","error","-i",path,"-ac",str(ch),"-ar",str(sr),"-f","f32le","-"],capture_output=True).stdout
    x=np.frombuffer(raw,np.float32).astype(np.float64); return x.reshape(-1,ch).T if ch>1 else x
def save(path, x, q=5):
    x=np.atleast_2d(x); ch=x.shape[0]; data=np.clip(x.T,-1,1).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg","-v","error","-y","-f","f32le","-ar",str(SR),"-ac",str(ch),"-i","-","-c:a","libvorbis","-q:a",str(q),path],input=data,check=True)
def norm(x,peak=0.89):
    m=np.max(np.abs(x)); return x*(peak/m) if m>0 else x
def rmsnorm(x,db=-20):
    r=np.sqrt(np.mean(x**2)); return x*(10**(db/20)/r)
def white(n): return R.normal(0,1,n)
def colored(n,beta):  # circular, seamless
    f=np.fft.rfftfreq(n,1/SR); f[0]=1; s=np.fft.rfft(white(n))/f**(beta/2); s[0]=0; x=np.fft.irfft(s,n); return x/np.std(x)
def fbp(x,lo=None,hi=None,order=2):  # circular frequency-domain butterworth-shaped filter
    n=x.shape[-1]; f=np.fft.rfftfreq(n,1/SR); H=np.ones_like(f)
    if lo: H*=1/np.sqrt(1+(lo/np.maximum(f,1e-3))**(2*order))
    if hi: H*=1/np.sqrt(1+(f/hi)**(2*order))
    return np.fft.irfft(np.fft.rfft(x)*H,n)
def sos(x,kind,fc,order=4): return signal.sosfilt(signal.butter(order,fc,kind,fs=SR,output='sos'),x)
def ir(sec=3.0,pre=0.02,bright=6000,seed=0,er=()):
    r=np.random.default_rng(seed); n=int(sec*SR); t=np.arange(n)/SR
    h=np.zeros((2,n))
    for c in range(2):
        nz=r.normal(0,1,n)*np.exp(-6.9*t/sec); nz=sos(nz,'lowpass',bright,2); h[c]=nz
    p=int(pre*SR); h[:,:p]=0
    for d,g in er: h[:,int(d*SR)]+=g
    return h/np.sqrt(np.sum(h**2)/2)
def reverb(x,h,wet=0.3,circular=False):
    x=np.atleast_2d(x); 
    if x.shape[0]==1: x=np.vstack([x,x])
    n=x.shape[1]
    if circular:
        H=np.fft.rfft(h,n) if h.shape[1]<=n else np.fft.rfft(h[:,:n],n)
        y=np.fft.irfft(np.fft.rfft(x)*H,n)
    else:
        y=np.array([signal.fftconvolve(x[c],h[c])[:n+h.shape[1]] for c in range(2)]); x=np.pad(x,((0,0),(0,y.shape[1]-n)))
    return x*(1-wet)+y*wet*0.35
def env(n,a,d=None,curve=4.0):
    t=np.arange(n)/SR; e=np.minimum(1,t/max(a,1e-4))
    if d: e*=np.exp(-curve*np.maximum(0,t-a)/d)
    return e
def xfade_loop(x,sec):
    x=np.atleast_2d(x); k=int(sec*SR); L=x.shape[1]-k
    out=x[:,:L].copy(); w=np.linspace(0,np.pi/2,k)
    out[:,:k]=out[:,:k]*np.sin(w)+x[:,L:L+k]*np.cos(w); return out
def resample(x,factor):  # factor<1 => lower pitch, longer
    x=np.atleast_2d(x); n=int(x.shape[1]/factor); return np.array([signal.resample(c,n) for c in x])
def place(buf,snd,pos,circ=True):
    snd=np.atleast_2d(snd); n=buf.shape[1]
    if snd.shape[0]==1 and buf.shape[0]==2: snd=np.vstack([snd,snd])
    for i in range(snd.shape[1]):
        pass
    L=snd.shape[1]; idx=(np.arange(L)+pos)%n if circ else np.arange(L)+pos
    if not circ: idx=idx[idx<n]; snd=snd[:,:len(idx)]
    np.add.at(buf,(slice(None),idx),snd) if False else None
    for c in range(buf.shape[0]): np.add.at(buf[c],idx,snd[c])
def pan(x,p):  # p -1..1
    a=(p+1)*np.pi/4; return np.vstack([x*np.cos(a),x*np.sin(a)])
def clang(f0,dur=2.5,bright=1.0,seed=0):
    r=np.random.default_rng(seed); n=int(dur*SR); t=np.arange(n)/SR; y=np.zeros(n)
    for k,(ratio,amp,dec) in enumerate([(1,1,1.0),(2.76,0.6,0.6),(5.40,0.4,0.35),(8.93,0.25,0.2),(13.3,0.15,0.12),(1.5,0.3,0.8)]):
        f=f0*ratio*(1+r.normal(0,0.004)); y+=amp*np.sin(2*np.pi*f*t+r.uniform(0,6))*np.exp(-t/(dec*dur*0.4))
    y+=sos(white(n),'highpass',2000)*np.exp(-t/0.01)*0.5*bright
    return y*env(n,0.001)
def creak(dur=1.2,f0=380,rate=(25,70),seed=0):
    r=np.random.default_rng(seed); n=int(dur*SR); t=np.arange(n)/SR; imp=np.zeros(n)
    rr=np.interp(t,[0,dur*0.5,dur],[rate[0],rate[1],rate[0]*0.8]); ph=np.cumsum(rr/SR); idx=np.where(np.diff(np.floor(ph))>0)[0]
    imp[idx]=r.uniform(0.5,1,len(idx))
    y=np.zeros(n)
    for f,q,g in [(f0,18,1),(f0*2.3,14,0.5),(f0*3.9,12,0.3)]:
        b,a=signal.iirpeak(f,q,fs=SR); y+=g*signal.lfilter(b,a,imp)
    return y*np.sin(np.pi*np.clip(t/dur,0,1))**0.5
# ================= AMBIENCES =================
def amb_fog():
    L=64*SR; out=np.zeros((2,L)); t=np.arange(L)/SR
    for c in range(2):
        pk=colored(L,1.0)
        g1=0.55+0.45*np.sin(2*np.pi*t/16+c)*np.sin(2*np.pi*t/64*3+0.5); g2=0.5+0.5*np.sin(2*np.pi*t/21.333+1.7+c)
        w=fbp(pk,180,700)*g1**2+0.6*fbp(pk,500,1400)*g2**2+0.25*fbp(colored(L,0.0),2500,6000)*(g1*g2)**2
        out[c]+=w*0.5
    drone=np.zeros(L)
    for f,a in [(41.2,1),(41.7,0.8),(61.73,0.5),(82.4,0.25),(123.47,0.12)]:
        f=f*np.round(64*f)/(64*f)
        drone+=a*np.sin(2*np.pi*f*t+0.3*np.sin(2*np.pi*t/32))
    drone*=0.5+0.5*np.sin(2*np.pi*t/32)**2
    rumble=fbp(colored(L,2.0),20,110)
    for c in range(2): out[c]+=0.35*drone+0.6*rumble
    res=fbp(colored(L,0.0),500,560,order=6)*0.8+fbp(colored(L,0.0),770,800,order=6)*0.6
    res*=np.clip(np.sin(2*np.pi*t/64*2),0,1)**3
    out+=pan(res,0.3)*0.6
    ev=np.zeros((2,L))
    for i,(tt,kind) in enumerate([(5,'creak'),(18,'thud'),(29,'clang'),(41,'creak'),(52,'thud'),(58,'clang')]):
        if kind=='creak': s=creak(1.6,R.uniform(250,420),seed=i)*0.5
        elif kind=='thud': n=int(1.5*SR); tt2=np.arange(n)/SR; s=np.sin(2*np.pi*(55-15*tt2)*tt2)*np.exp(-tt2/0.35)*0.9+sos(white(n),'lowpass',300)*np.exp(-tt2/0.08)*0.3
        else: s=clang(R.uniform(140,260),2.5,0.3,seed=i)*0.35
        s=sos(s,'lowpass',2500,2); place(ev,pan(s,R.uniform(-0.8,0.8)),int(tt*SR))
    out+=reverb(ev,ir(4.0,0.08,3000,seed=3,er=[(0.31,0.6),(0.77,0.4)]),wet=0.85,circular=True)
    try:
        deep=load(f"{FS}/fs_467026.mp3",ch=2); deep=resample(deep,0.9)[:, :L]
        if deep.shape[1]<L: deep=np.pad(deep,((0,0),(0,L-deep.shape[1])))
        deep=xfade_loop(np.hstack([deep,deep[:,:4*SR]]),4)[:,:L] if deep.shape[1]>=L else deep
        out+=0.18*deep/np.std(deep)*np.std(out)
    except Exception as e: print("deep fail",e)
    out=reverb(out,ir(2.5,0.03,5000,seed=4),wet=0.3,circular=True)
    save(f"{SFX}/amb_fog.ogg",norm(rmsnorm(out,-22),0.8))
def amb_other():
    L=60*SR; t=np.arange(L)/SR
    a=load(f"{FS}/fs_240895.mp3",ch=2)[:,30*SR:30*SR+72*SR]; b=load(f"{FS}/fs_393398.mp3",ch=1)[10*SR:10*SR+72*SR]; b=np.vstack([b,b])
    a=resample(a,0.82); b=resample(b,0.78)
    m=a[:,:L+5*SR]/np.std(a)+0.8*b[:,:L+5*SR]/np.std(b); m=xfade_loop(m,5)[:,:L]
    m=np.array([fbp(c,25,5500) for c in m])
    hum=np.zeros(L)
    for k in range(1,9): hum+=np.sin(2*np.pi*50*k*t+k)/k**1.2*(0.6+0.4*np.sin(2*np.pi*t/(60/(k%3+1))))
    hum*=0.25
    grind=np.zeros((2,L))
    for c in range(2):
        g=colored(L,0.5); grind[c]=(fbp(g,700,1000,4)*np.clip(np.sin(2*np.pi*t/15+c*2),0,1)**4+fbp(g,1800,2300,4)*np.clip(np.sin(2*np.pi*t/20+1+c),0,1)**6)
    ev=np.zeros((2,L))
    beat=0
    for i in range(34):
        tt=(i*1.76+R.normal(0,0.05))%60 if i<24 else R.uniform(0,60)
        f0=[92,92,138,92][i%4] if i<24 else R.uniform(150,400)
        s=clang(f0,3.0 if i<24 else 1.5,0.8,seed=100+i)*(0.9 if i<24 else 0.4)*(0.5+0.5*np.sin(np.pi*tt/60)**2)
        place(ev,pan(s,R.uniform(-0.9,0.9)),int(tt*SR))
    for i in range(5):
        s=creak(2.5,R.uniform(180,300),rate=(12,40),seed=200+i)*0.8; place(ev,pan(s,R.uniform(-1,1)),int(R.uniform(0,60)*SR))
    ev=reverb(ev,ir(5.0,0.12,2500,seed=9,er=[(0.45,0.6),(1.1,0.4),(1.7,0.25)]),wet=0.9,circular=True)
    out=m*0.9+np.vstack([hum,hum])*1.2+grind*0.5+ev*1.4
    out+=np.vstack([fbp(colored(L,2.0),15,80)]*2)*1.5
    save(f"{SFX}/amb_other.ogg",norm(rmsnorm(out,-19),0.85))
def static_loop():
    L=6*SR; t=np.arange(L)/SR
    n=white(L); s=fbp(n,350,5200,2)
    puls=0.75+0.25*np.sign(np.sin(2*np.pi*t*7.5))*np.clip(np.sin(2*np.pi*t/3),0,1)
    am=0.8+0.2*fbp(white(L),0.5,12,1)/np.std(fbp(white(L),0.5,12,1))*0.3
    cr=np.zeros(L); idx=R.integers(0,L,900); cr[idx]=R.normal(0,6,900); cr=fbp(cr,1500,9000)
    tone=np.sin(2*np.pi*(1200+300*np.sin(2*np.pi*t/3))*t)*0.04*np.clip(np.sin(2*np.pi*t/2),0,1)**8
    x=s*puls*am+cr*0.5+tone*np.std(s)
    try:
        r=load(f"{FS}/fs_38693.mp3")[12*SR:12*SR+L+SR]; r=xfade_loop(r[None,:],1)[0][:L]; x=x/np.std(x)+0.7*r/np.std(r)
    except Exception as e: print("static rec fail",e)
    save(f"{SFX}/static.ogg",norm(x,0.9))
def siren():
    x=load(f"{FS}/fs_336640.mp3",ch=2); a=x[:,int(0.4*SR):int(26*SR)]; b=x[:,int(56*SR):int(76.5*SR)]
    k=int(2.5*SR); w=np.linspace(0,np.pi/2,k)
    y=np.hstack([a[:,:-k],a[:,-k:]*np.cos(w)+b[:,:k]*np.sin(w),b[:,k:]])
    y=np.array([sos(c,'lowpass',7000,2) for c in y]); y[:,:int(0.3*SR)]*=np.linspace(0,1,int(0.3*SR))
    y=reverb(y,ir(3.5,0.05,4000,seed=11,er=[(0.42,0.5),(0.95,0.35),(1.6,0.25)]),wet=0.45)
    y[:,-3*SR:]*=np.linspace(1,0,3*SR)
    save(f"{SFX}/siren.ogg",norm(y,0.9))
# ================= ONE-SHOTS =================
def heartbeat():
    n=int(0.86*SR); y=np.zeros(n)
    for t0,a in [(0.0,1.0),(0.24,0.7)]:
        m=int(0.25*SR); tt=np.arange(m)/SR; s=np.sin(2*np.pi*(62-25*tt)*tt)*np.exp(-tt/0.06)*a; s+=sos(white(m),'lowpass',150)*np.exp(-tt/0.02)*0.3*a
        i=int(t0*SR); y[i:i+m]+=s[:n-i]
    save(f"{SFX}/heartbeat.ogg",norm(sos(y,'lowpass',400,2),0.95))
def whoosh(name,dur=0.32,f0=300,f1=1800,amp=1.0):
    n=int(dur*SR); t=np.arange(n)/SR; x=white(n); y=np.zeros(n); seg=256
    fc=f0+(f1-f0)*np.sin(np.pi*t/dur)
    for i in range(0,n,seg):
        b,a=signal.iirpeak(fc[i],1.2,fs=SR); y[i:i+seg]=signal.lfilter(b,a,x[i:i+seg+512])[:len(y[i:i+seg])]
    y*=np.sin(np.pi*t/dur)**2*amp; save(f"{SFX}/{name}.ogg",norm(y,0.8))
def squelch(dur=0.35,f0=900,f1=180,seed=0):
    r=np.random.default_rng(seed); n=int(dur*SR); t=np.arange(n)/SR; x=r.normal(0,1,n)
    am=np.abs(fbp(r.normal(0,1,n),20,60))*3; y=np.zeros(n); seg=256; fc=f0*(f1/f0)**(t/dur)
    for i in range(0,n,seg):
        b,a=signal.iirpeak(fc[i],3,fs=SR); y[i:i+seg]=signal.lfilter(b,a,x[i:i+seg+256])[:len(y[i:i+seg])]
    return y*am*np.exp(-t/(dur*0.4))
def kn(path): return load(f"{KN}/{path}")
def mix(*xs):
    n=max(len(x) for x in xs); o=np.zeros(n)
    for x in xs: o[:len(x)]+=x
    return o
def monster_set():
    # idle gurgle loop 4s
    L=4*SR; t=np.arange(L)/SR
    growl_f=68+6*np.sin(2*np.pi*t/4)+3*fbp(white(L),0.3,4,1)/np.std(fbp(white(L),0.3,4,1))
    saw=signal.sawtooth(2*np.pi*np.cumsum(growl_f)/SR)
    g=fbp(saw,40,600)
    breath=np.clip(np.sin(2*np.pi*t/2.0),0,1)**1.5
    bub=np.zeros(L); idx=R.integers(0,L,180); bub[idx]=R.uniform(0.3,1,180)
    bb=np.zeros(L)
    for f in (320,520,880): b,a=signal.iirpeak(f,9,fs=SR); bb+=signal.lfilter(b,a,bub)
    nz=fbp(white(L),300,1600)*breath
    y=g*(0.3+0.7*breath)*0.6+bb*0.25+nz*0.4
    y=xfade_loop(np.concatenate([y,y[:SR//2]])[None,:],0.5)[0]
    save(f"{SFX}/mon_idle.ogg",norm(y,0.85))
    for k in range(3):  # screech
        n=int(1.6*SR); t=np.arange(n)/SR; fc=(1100+k*180)*(0.55+0.45*np.exp(-t/0.5)); mod=150+k*20
        idx=6*np.exp(-t/0.7)+1.5; ph=np.cumsum(fc/SR)*2*np.pi; y=np.sin(ph+idx*np.sin(2*np.pi*mod*t))
        y+=0.6*np.sin(1.5*ph+idx*0.7*np.sin(2*np.pi*mod*1.5*t)); y=np.tanh(2.5*y)
        y+=fbp(white(n),1500,7000)*0.4; y*=env(n,0.03,1.0,3.0)*(1+0.3*np.sin(2*np.pi*14*t))
        y=reverb(y[None,:],ir(1.2,0.01,6000,seed=30+k),wet=0.25)[0]
        save(f"{SFX}/mon_screech{k}.ogg",norm(y,0.9))
    for k in range(3):
        y=mix(squelch(0.5,1200,200,seed=k)*1.0, kn(f"impact-sounds/Audio/impactPunch_heavy_00{k}.ogg")*0.9, squelch(0.3,400,150,seed=9+k)*0.6)
        save(f"{SFX}/hit_flesh{k}.ogg",norm(y,0.95))
    n=int(0.7*SR); t=np.arange(n)/SR
    for k in range(2):
        f=(700+k*140)*np.exp(-t*1.2); y=mix(np.tanh(3*np.sin(np.cumsum(f/SR)*2*np.pi+3*np.sin(2*np.pi*90*t)))*env(n,0.01,0.4),squelch(0.6,800,200,seed=20+k))
        save(f"{SFX}/mon_hurt{k}.ogg",norm(y,0.9))
    n=int(2.6*SR); t=np.arange(n)/SR; f=600*np.exp(-t*0.9)+60
    y=np.tanh(3*np.sin(np.cumsum(f/SR)*2*np.pi+4*np.sin(2*np.pi*70*t)))*env(n,0.02,1.4,2.5)+mix(squelch(1.5,900,120,seed=40),np.zeros(n))*0.8
    y=reverb(y[None,:],ir(1.5,0.01,5000,seed=41),wet=0.3)[0]; save(f"{SFX}/mon_death.ogg",norm(y,0.9))
    for k in range(4):
        c=kn(f"rpg-audio/Audio/cloth{k+1}.ogg"); c=resample(c[None,:],0.7)[0]
        st=kn(f"impact-sounds/Audio/footstep_carpet_00{k}.ogg"); st=resample(st[None,:],0.75)[0]
        save(f"{SFX}/mon_step{k}.ogg",norm(mix(c*0.8,st*0.9,squelch(0.25,500,200,seed=60+k)*0.4),0.8))
    y=mix(kn("impact-sounds/Audio/impactSoft_heavy_001.ogg"),kn("impact-sounds/Audio/impactWood_heavy_002.ogg")*0.6,squelch(0.5,1000,150,seed=70)*1.2)
    save(f"{SFX}/stomp.ogg",norm(y,0.95))
def misc():
    for i in range(5):
        for surf,src in [("concrete","footstep_concrete"),("wood","footstep_wood"),("grass","footstep_grass"),("carpet","footstep_carpet")]:
            save(f"{SFX}/step_{surf}{i}.ogg",norm(kn(f"impact-sounds/Audio/{src}_00{i}.ogg"),0.8))
        m=mix(kn(f"impact-sounds/Audio/impactPlate_light_00{i}.ogg")*0.8,kn(f"impact-sounds/Audio/footstep_concrete_00{i}.ogg")*0.6)
        save(f"{SFX}/step_metal{i}.ogg",norm(m,0.8))
    for i in range(3): save(f"{SFX}/hit_metal{i}.ogg",norm(kn(f"impact-sounds/Audio/impactMetal_heavy_00{i}.ogg"),0.9))
    a=kn("rpg-audio/Audio/metalLatch.ogg"); c=kn("rpg-audio/Audio/metalClick.ogg"); y=np.zeros(int(1.0*SR))
    for t0,s,g in [(0,a,1),(0.18,c,0.8),(0.36,a,0.9),(0.55,c,0.6)]: i=int(t0*SR); y[i:i+len(s)]+=s[:len(y)-i]*g
    save(f"{SFX}/door_locked.ogg",norm(y,0.9))
    save(f"{SFX}/door_open.ogg",norm(mix(kn("rpg-audio/Audio/doorOpen_1.ogg"),kn("rpg-audio/Audio/creak1.ogg")*0.7),0.9))
    save(f"{SFX}/gate_open.ogg",norm(mix(creak(2.2,240,rate=(10,30),seed=5)*0.8,kn("rpg-audio/Audio/metalLatch.ogg"),np.pad(kn("impact-sounds/Audio/impactMetal_medium_001.ogg"),(int(1.8*SR),0))*0.7),0.9))
    save(f"{SFX}/pickup.ogg",norm(mix(kn("rpg-audio/Audio/handleSmallLeather.ogg"),kn("rpg-audio/Audio/cloth2.ogg")*0.5),0.8))
    save(f"{SFX}/paper.ogg",norm(kn("rpg-audio/Audio/bookFlip2.ogg"),0.8))
    save(f"{SFX}/click.ogg",norm(kn("rpg-audio/Audio/metalClick.ogg"),0.7))
    for nm,src in [("ui_move","interface-sounds/Audio/tick_002.ogg"),("ui_select","interface-sounds/Audio/select_006.ogg"),("ui_back","interface-sounds/Audio/back_002.ogg"),("ui_open","interface-sounds/Audio/open_002.ogg")]:
        save(f"{SFX}/{nm}.ogg",norm(kn(src),0.6))
    g=mix(*[np.pad(kn(f"impact-sounds/Audio/impactGlass_heavy_00{i}.ogg"),(int(i*0.05*SR),0)) for i in range(4)])
    save(f"{SFX}/glass_break.ogg",norm(g,0.95))
    whoosh("swing",0.34,250,1600); whoosh("swing2",0.30,300,2000)
    # breathing (exhausted) loop 2.6s
    L=int(2.6*SR); t=np.arange(L)/SR; y=np.zeros(L)
    for t0,d,lo,hi,g in [(0.0,0.75,400,2200,1.0),(1.2,0.9,250,1500,0.7)]:
        n=int(d*SR); tt=np.arange(n)/SR; s=fbp(white(n),lo,hi)*np.sin(np.pi*tt/d)**2*g; i=int(t0*SR); y[i:i+n]+=s
    save(f"{SFX}/breath.ogg",norm(y,0.7))
    L=int(3.2*SR); y=np.zeros(L); c1=creak(0.9,520,rate=(40,90),seed=7); c2=creak(0.8,470,rate=(35,80),seed=8)
    y[int(0.2*SR):int(0.2*SR)+len(c1)]+=c1; y[int(1.8*SR):int(1.8*SR)+len(c2)]+=c2*0.8
    save(f"{SFX}/swing_creak.ogg",norm(y,0.8))
    # stinger
    n=int(3.0*SR); t=np.arange(n)/SR; y=np.zeros(n)
    for f in (73.4,77.8,103.8,110,146.8,155.6,207.6): y+=signal.sawtooth(2*np.pi*f*(1+R.normal(0,0.003))*t)
    y=sos(y,'lowpass',2200,2)*env(n,0.005,1.2,3)+sos(white(n),'highpass',3000)*env(n,0.001,0.15)*0.6
    y=reverb(y[None,:],ir(3.5,0.01,4000,seed=50),wet=0.5); save(f"{SFX}/sting.ogg",norm(y,0.95))
    # transition rumble 9s
    n=9*SR; t=np.arange(n)/SR; y=np.zeros((2,n))
    rum=sos(white(n),'lowpass',90,2)*np.clip(t/4,0,1)**2*np.exp(-np.maximum(0,t-6)/1.5)*6
    swell=sos(white(n),'bandpass',[800,6000],2)*np.clip(t/7,0,1)**3*np.exp(-np.maximum(0,t-7)/0.3)
    sc=np.zeros(n)
    for k in range(6): s=creak(1.5,R.uniform(600,1500),rate=(60,140),seed=80+k); i=int(R.uniform(1,7)*SR); sc[i:i+len(s)]+=s[:n-i]*0.6
    for c in range(2): y[c]=rum+swell*0.8+sc*(0.7 if c else 0.4)
    y=reverb(y,ir(4,0.05,3000,seed=81),wet=0.5)[:, :n+2*SR]; save(f"{SFX}/transition.ogg",norm(y,0.95))
    save(f"{SFX}/radio_on.ogg",norm(mix(kn("rpg-audio/Audio/metalClick.ogg"),fbp(white(int(0.5*SR)),400,5000)*env(int(0.5*SR),0.01,0.2)*0.5),0.8))
# ================= MUSIC =================
def ks(f,dur,bright=0.5,decay=0.996,seed=0):
    r=np.random.default_rng(seed); n=int(dur*SR); N=int(round(SR/f))
    exc=np.zeros(n); burst=r.uniform(-1,1,N); burst=signal.lfilter([bright],[1,-(1-bright)],burst); exc[:N]=burst
    a=np.zeros(N+2); a[0]=1; a[N]=-decay/2; a[N+1]=-decay/2
    y=signal.lfilter([1],a,exc); y=sos(y,'highpass',60,2); return y*np.exp(-np.arange(n)/SR/ (dur*0.9))
NOTE={'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
def hz(name):
    p=name[:-1]; o=int(name[-1]); return 440*2**((NOTE[p]+12*(o-4)-9)/12)
def music_title():
    bpm=66; beat=60/bpm; bar=4*beat
    chords=[("D3",["D3","A3","D4","F4"]),("Bb2",["Bb2","F3","Bb3","D4"]),("G2",["G2","D3","G3","Bb3"]),("A2",["A2","E3","A3","C#4"]),
            ("D3",["D3","A3","D4","F4"]),("F2",["F2","C3","F3","A3"]),("G2",["G2","D3","G3","Bb3"]),("A2",["A2","E3","A3","C#4"])]
    mel=[[("A4",2),("F4",1),("E4",1)],[("D4",3),("F4",1)],[("G4",1),("A4",1),("Bb4",1),("A4",1)],[("E4",4)],
         [("A4",1),("D5",2),("C5",1)],[("A4",2),("G4",1),("F4",1)],[("E4",1),("F4",1),("G4",1),("E4",1)],[("C#4",3),("E4",1)]]
    passes=3; total=passes*8*bar+6; n=int(total*SR); L=np.zeros((2,n))
    pat=[0,1,2,3,2,1,2,3]
    for p in range(passes):
        for b,(root,notes) in enumerate(chords):
            t0=(p*8+b)*bar
            for i in range(8):
                f=hz(notes[pat[i]]); s=ks(f,2.8,0.35,0.9965,seed=p*100+b*10+i)*0.5*(0.8 if i%2 else 1.0)
                place(L,pan(s,-0.25+0.1*(i%3)),int((t0+i*beat/2+R.normal(0,0.008))*SR),circ=False)
            bs=ks(hz(root)/2*2,bar+1,0.2,0.998,seed=999+b)*0.7; place(L,pan(bs,0),int(t0*SR),circ=False)
            if p>=1:
                tt=t0
                for (nm,d) in mel[b]:
                    f=hz(nm)*(2 if p==2 and b>=4 else 1); s=ks(f,d*beat+1.5,0.55,0.9975,seed=7000+p*50+b*5)
                    m=len(s); vib=1+0.004*np.sin(2*np.pi*5*np.arange(m)/SR)*np.clip(np.arange(m)/SR-0.3,0,1)
                    s=s*0.75; place(L,pan(s,0.25),int((tt+R.normal(0,0.01))*SR),circ=False); tt+=d*beat
    t=np.arange(n)/SR; pad=np.zeros(n)
    for p in range(passes):
        for b,(root,notes) in enumerate(chords):
            t0=(p*8+b)*bar; i0=int(t0*SR); i1=min(n,int((t0+bar+0.5)*SR)); tt=np.arange(i1-i0)/SR
            for nm in notes[1:]:
                f=hz(nm)
                for det in (-0.004,0.004): pad[i0:i1]+=signal.sawtooth(2*np.pi*f*(1+det)*tt)*0.05*np.sin(np.pi*np.clip(tt/(bar+0.5),0,1))
    pad=sos(pad,'lowpass',900,2)
    L+=pan(pad,0)*(0.4+0.6*np.clip(t/(8*bar),0,1))
    L=reverb(L,ir(4.2,0.03,5000,seed=77),wet=0.45)[:, :n]
    hiss=fbp(white(n),2000,9000)*0.004; crk=np.zeros(n); idx=R.integers(0,n,int(total*6)); crk[idx]=R.normal(0,0.25,len(idx)); crk=fbp(crk,800,6000)
    L+=np.vstack([hiss+crk*0.25,hiss+crk*0.25])
    L[:,-int(5*SR):]*=np.linspace(1,0,int(5*SR)); save(f"{MUS}/title.ogg",norm(L,0.85),q=6)
def tine(f,dur,seed=0):
    r=np.random.default_rng(seed); n=int(dur*SR); t=np.arange(n)/SR; f*=1+r.normal(0,0.002)
    y=np.sin(2*np.pi*f*t)*np.exp(-t/1.1)+0.35*np.sin(2*np.pi*f*3.01*t)*np.exp(-t/0.35)+0.12*np.sin(2*np.pi*f*5.43*t)*np.exp(-t/0.12)
    y+=fbp(r.normal(0,1,n),3000,9000)*np.exp(-t/0.004)*0.2; return y
def music_box():
    bpm=84; beat=60/bpm
    melody=[("E5",1),("A5",1),("C6",1),("B5",2),("A5",1),("G#5",2),("E5",1),("F5",2),("E5",1),("D5",3),
            ("C5",1),("E5",1),("A5",1),("G5",2),("F5",1),("E5",2),("D5",1),("C5",1),("B4",1),("D5",1),("A4",3)]
    total=sum(d for _,d in melody)*beat*2+4; n=int(total*SR); y=np.zeros((2,n)); tt=0
    for rep in range(2):
        for i,(nm,d) in enumerate(melody):
            slow=1+0.05*rep+0.02*i/len(melody)
            s=tine(hz(nm)*(0.97 if rep else 1.0),2.5,seed=rep*100+i); place(y,pan(s*0.6,0.1),int(tt*SR),circ=False)
            if i%3==0: s2=tine(hz(nm)/2,2.5,seed=500+i)*0.3; place(y,pan(s2,-0.2),int(tt*SR),circ=False)
            tt+=d*beat*slow
    y=reverb(y,ir(3.0,0.02,6000,seed=88),wet=0.4)[:, :n]; y[:,-2*SR:]*=np.linspace(1,0,2*SR)
    save(f"{MUS}/music_box.ogg",norm(y,0.8))
def ending_drone():
    n=40*SR; t=np.arange(n)/SR; y=np.zeros(n)
    for f,a in [(73.42,1),(110,0.6),(146.83,0.4),(174.6,0.25),(220,0.2),(261.6,0.12)]:
        for d in (-0.003,0.003): y+=a*np.sin(2*np.pi*f*(1+d)*t+R.uniform(0,6))
    y*=np.clip(t/6,0,1)*np.clip((40-t)/8,0,1); y+=fbp(colored(n,1.0),200,2000)*0.05
    out=reverb(np.vstack([y,y*0.98]),ir(5,0.05,3000,seed=99),wet=0.5)[:, :n]; save(f"{MUS}/ending.ogg",norm(out,0.7))
import sys
jobs=sys.argv[1:] or ["amb_fog","amb_other","static_loop","siren","heartbeat","monster_set","misc","music_title","music_box","ending_drone"]
for j in jobs:
    globals()[j](); print("done",j, flush=True)
