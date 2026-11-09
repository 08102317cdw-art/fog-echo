#!/usr/bin/env python3
"""v1.2 新音效：从 Freesound CC0 素材裁剪、处理并编码为 ogg"""
import subprocess, numpy as np, json, os, sys
from scipy import signal
sys.path.insert(0, os.path.dirname(__file__))
from seg import load, segs, SR
OUT = "/data/sh_demo/assets/sfx"
CACHE = {}
def src(i):
    if i not in CACHE: CACHE[i] = load(str(i))
    return CACHE[i]
def cut(i, a, d):
    x = src(i); s = int(a * SR); e = min(len(x), int((a + d) * SR))
    return x[s:e].copy()
def segcut(i, k, thr=-26, pre=0.02, post=0.12, maxd=3.0):
    ss = segs(src(i), thr)
    a, b, _ = ss[k]
    return cut(i, max(0, a - pre), min(b - a + pre + post, maxd))
def fade(x, fi=0.004, fo=0.08):
    n = len(x); a = int(fi * SR); b = int(fo * SR)
    if a > 0: x[:a] *= np.linspace(0, 1, a)
    if b > 0 and b < n: x[-b:] *= np.linspace(1, 0, b) ** 2
    return x
def norm(x, db=-1.0):
    pk = np.abs(x).max() + 1e-9
    return x * (10 ** (db / 20) / pk)
def lp(x, f, o=2):
    b, a = signal.butter(o, f / (SR / 2), 'low'); return signal.lfilter(b, a, x).astype(np.float32)
def hp(x, f, o=2):
    b, a = signal.butter(o, f / (SR / 2), 'high'); return signal.lfilter(b, a, x).astype(np.float32)
def pitch(x, r):
    n = int(len(x) / r); return signal.resample(x, n).astype(np.float32)
def trim_tail(x, thr_db=-50):
    env = np.abs(x); th = 10 ** (thr_db / 20) * env.max()
    idx = np.where(env > th)[0]
    return x[:idx[-1] + int(0.03 * SR)] if len(idx) else x
def cat(*xs, gap=0.0):
    out = []
    for x in xs:
        out.append(x); 
        if gap: out.append(np.zeros(int(gap * SR), np.float32))
    return np.concatenate(out)
def write(name, x, db=-1.0, fo=0.08, q=5):
    x = fade(trim_tail(np.asarray(x, np.float32)), 0.003, fo)
    x = norm(x, db)
    p = subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", str(q), f"{OUT}/{name}.ogg"], input=x.astype(np.float32).tobytes())
    print(name, f"{len(x)/SR:.2f}s")
def loopify(x, xf=0.25):
    n = int(xf * SR)
    a = x[:n] * np.linspace(0, 1, n); b = x[-n:] * np.linspace(1, 0, n)
    y = x[:-n].copy(); y[:n] = a + b
    return y

# ---------------- 枪械
write("gun_pistol0", lp(cut(427592, 0.10, 1.25), 9000), -0.5, 0.35)
write("gun_pistol1", lp(cut(385811, 0.0, 1.3), 9000), -0.5, 0.35)
write("gun_pistol2", cut(402789, 1.23, 1.2), -0.5, 0.35)
write("gun_rifle0", cut(410442, 0.0, 2.2), -0.3, 0.6)
write("gun_rifle1", cut(351777, 0.43, 2.0), -0.3, 0.6)
write("rifle_bolt", cut(802673, 0.07, 1.5), -3.0, 0.1)
write("reload_pistol", cut(432139, 0.0, 1.5), -3.0, 0.1)
write("reload_rifle", cat(cut(431830, 1.72, 1.55), cut(263459, 2.5, 1.0)), -3.0, 0.1)
write("gun_empty", cut(674568, 0.0, 0.29), -4.0, 0.03)
write("shell0", cut(210102, 0.05, 0.42), -9.0, 0.1)
write("shell1", cut(210102, 0.53, 0.6), -9.0, 0.1)
write("shell2", cut(210102, 2.52, 0.45), -9.0, 0.1)
write("bullet_flesh0", cut(423301, 0.03, 0.8), -2.0, 0.2)
write("bullet_flesh1", segcut(423301, 1, post=0.2), -2.0, 0.15)
write("bullet_flesh2", cut(511194, 0.04, 0.6), -2.0, 0.15)
write("ricochet0", segcut(30932, 0, post=0.5), -5.0, 0.2)
write("ricochet1", segcut(148840, 1, post=0.25), -5.0, 0.15)
write("ricochet2", segcut(148840, 3, post=0.15), -5.0, 0.15)
# ---------------- 恶犬
write("dog_bark0", segcut(332176, 0, post=0.15), -1.0, 0.12)
write("dog_bark1", segcut(619045, 3, post=0.15), -1.0, 0.12)
write("dog_bark2", segcut(332176, 1, post=0.2), -1.0, 0.12)
write("dog_growl0", cut(122183, 4.4, 0.85), -2.0, 0.15)
write("dog_growl1", cut(122183, 5.38, 1.05), -2.0, 0.15)
write("dog_growl2", pitch(cut(404920, 0.56, 1.85), 0.9), -2.0, 0.25)
write("dog_snarl0", cut(122183, 12.8, 1.4), -1.0, 0.2)
write("dog_snarl1", cut(439535, 0.0, 1.6), -1.0, 0.2)
write("dog_yelp0", cut(160478, 2.94, 0.7), -1.5, 0.12)
write("dog_yelp1", cut(160478, 7.72, 0.66), -1.5, 0.12)
write("dog_yelp2", cut(160478, 3.74, 0.58), -1.5, 0.12)
write("dog_bite0", cat(cut(122183, 11.27, 0.42)), -1.0, 0.08)
write("dog_bite1", cut(122183, 11.86, 0.44), -1.0, 0.08)
write("dog_eat", lp(cut(122183, 9.14, 1.05), 3500), -8.0, 0.2)
# ---------------- 乌鸦
write("crow_caw0", cut(361470, 0.06, 0.36), -2.0, 0.06)
write("crow_caw1", segcut(536732, 0, post=0.1), -2.0, 0.1)
write("crow_caw2", segcut(536732, 1, post=0.1), -2.0, 0.1)
write("crow_caw3", cut(274439, 1.95, 0.36), -2.0, 0.08)
write("crow_caw4", segcut(75162, 0, post=0.1), -2.0, 0.1)
write("wings_flap", cut(528250, 0.04, 1.6), -4.0, 0.3)
write("wings_takeoff", cut(241032, 0.14, 1.1), -3.0, 0.3)
# ---------------- 金币 / 商店 / 搜刮
write("coin0", cut(343462, 0.0, 0.16), -6.0, 0.03)
write("coin1", cut(163451, 0.0, 0.22), -6.0, 0.05)
write("coin_pile", cut(363090, 4.76, 0.6), -5.0, 0.15)
write("shop_buy", cut(209578, 0.07, 1.4), -4.0, 0.3)
write("drawer_open", cut(185842, 0.5, 0.8), -5.0, 0.12)
write("drawer_wood", cut(414819, 0.27, 1.5), -5.0, 0.2)
write("rummage0", cut(870037, 5.75, 1.4), -6.0, 0.25)
write("rummage1", cut(870037, 8.1, 0.9), -6.0, 0.2)
write("rummage2", cut(870037, 3.44, 0.7), -6.0, 0.15)
# ---------------- 谜题 / 门 / 杂项
write("keypad_beep", segcut(840450, 0, post=0.03), -8.0, 0.03)
write("keypad_deny", cut(419023, 0.0, 0.31), -6.0, 0.05)
write("keypad_ok", cut(759975, 3.78, 1.95), -4.0, 0.3)
write("clock_tick", loopify(cut(125968, 0.0, 6.0)), -10.0, 0.0)
write("clock_chime", cut(234268, 7.5, 8.0), -2.0, 1.5)
write("door_creak", cut(125957, 0.25, 1.8), -3.0, 0.2)
write("door_creak2", cut(219499, 0.08, 0.8), -3.0, 0.12)
write("body_fall", cut(346695, 0.55, 0.8), -2.0, 0.2)
write("push_hit0", segcut(586841, 0, post=0.15), -1.5, 0.1)
write("push_hit1", segcut(586841, 2, post=0.15), -1.5, 0.1)
write("push_hit2", segcut(540752, 3, post=0.12), -1.5, 0.1)
write("punch", cut(517744, 0.44, 0.35), -2.0, 0.1)
