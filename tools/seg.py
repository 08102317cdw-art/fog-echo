import sys, subprocess, numpy as np
SR = 44100
def load(i):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", f"/data/assets_raw/fs2/fs_{i}.mp3", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).copy()
def segs(x, thr_db=-30, gap=0.12, minlen=0.05):
    hop = 441
    n = len(x) // hop
    env = np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, 1) + 1e-12)
    db = 20 * np.log10(env / (env.max() + 1e-9) + 1e-9)
    on = db > thr_db
    out = []; s = None; last = -1
    for k in range(n):
        if on[k]:
            if s is None: s = k
            last = k
        elif s is not None and (k - last) * hop / SR > gap:
            if (last - s) * hop / SR >= minlen: out.append((s * hop / SR, (last + 1) * hop / SR, float(db[s:last + 1].max())))
            s = None
    if s is not None: out.append((s * hop / SR, (last + 1) * hop / SR, float(db[s:last + 1].max())))
    return out
if __name__ == "__main__":
    thr = float(sys.argv[1])
    for i in sys.argv[2:]:
        x = load(i)
        ss = segs(x, thr)
        pk = 20 * np.log10(np.abs(x).max() + 1e-9)
        print(i, f"len={len(x)/SR:.2f} peak={pk:.1f}dB n={len(ss)}", " ".join(f"[{a:.2f}-{b:.2f}]" for a, b, d in ss[:14]))
