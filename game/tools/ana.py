import subprocess, numpy as np, sys
def load(f, sr=22050):
    raw = subprocess.run(["ffmpeg","-v","error","-i",f,"-ac","1","-ar",str(sr),"-f","f32le","-"],capture_output=True).stdout
    return np.frombuffer(raw, np.float32), sr
for f in sys.argv[1:]:
    x, sr = load(f); hop = sr//1  # 1s
    out=[]
    for i in range(0, len(x)-hop, hop):
        seg = x[i:i+hop]; rms = 20*np.log10(np.sqrt(np.mean(seg**2))+1e-9)
        sp = np.abs(np.fft.rfft(seg*np.hanning(len(seg)))); fr = np.fft.rfftfreq(len(seg),1/sr)
        m = (fr>150)&(fr<2000); pk = fr[m][np.argmax(sp[m])]
        out.append(f"{int(rms)}/{int(pk)}")
    print(f, "len", round(len(x)/sr,1), "s  [dB/peakHz per sec]:"); print(" ".join(out))
