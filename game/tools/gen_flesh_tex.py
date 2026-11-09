# 生成可平铺的血肉细节贴图 RGBA：R 斑驳 / G 血管 / B 皱纹高度 / A 淤青斑块
import numpy as np
from PIL import Image
N = 1024; R = np.random.default_rng(99)
fy = np.fft.fftfreq(N)[:, None] * N; fx = np.fft.fftfreq(N)[None, :] * N
fr = np.sqrt(fx * fx + fy * fy); fr[0, 0] = 1
def band(f0, f1, beta=1.0, aniso=(1.0, 1.0)):
    ff = np.sqrt((fx * aniso[0]) ** 2 + (fy * aniso[1]) ** 2); ff[0, 0] = 1
    S = (R.normal(size=(N, N)) + 1j * R.normal(size=(N, N))) * (ff ** -beta)
    S *= np.exp(-(ff / f1) ** 2) * (1 - np.exp(-(ff / f0) ** 2)); S[0, 0] = 0
    x = np.real(np.fft.ifft2(S)); return (x - x.mean()) / x.std()
def warp(img, dx, dy, amt):
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    xs = (xx + dx * amt) % N; ys = (yy + dy * amt) % N
    x0 = np.floor(xs).astype(int); y0 = np.floor(ys).astype(int); tx = xs - x0; ty = ys - y0
    x1 = (x0 + 1) % N; y1 = (y0 + 1) % N
    return (img[y0, x0] * (1 - tx) * (1 - ty) + img[y0, x1] * tx * (1 - ty) + img[y1, x0] * (1 - tx) * ty + img[y1, x1] * tx * ty)
def n01(x, lo=1, hi=99):
    a, b = np.percentile(x, [lo, hi]); return np.clip((x - a) / (b - a), 0, 1)
# R 斑驳
mott = band(1, 24, 1.1) * 0.7 + band(8, 90, 0.9) * 0.3
mott = n01(mott)
# G 血管：多层 ridged + 域扭曲
dwx = band(2, 10, 1.0); dwy = band(2, 10, 1.0)
v = np.zeros((N, N))
for f0, f1, w, p in [(5, 14, 1.0, 10), (12, 30, 0.7, 14), (26, 60, 0.45, 18)]:
    b = band(f0, f1, 0.6)
    r = 1 - np.abs(np.tanh(b * 1.3))
    v = np.maximum(v, (r ** p) * w)
v = warp(v, dwx, dwy, 14.0)
veins = n01(v, 2, 99.7)
# B 皱纹 + 毛孔
wr = band(30, 140, 0.6) * 0.6 + band(60, 260, 0.3) * 0.35
cre = 1 - np.abs(np.tanh(band(10, 40, 0.8, (1.0, 0.25)) * 1.6))
wr = n01(wr) * 0.6 + (cre ** 6) * 0.5
pores = band(150, 320, 0.0)
wr -= (pores > 2.3) * 0.25
wr = n01(wr)
# A 淤青/尸斑斑块
bl = band(1, 10, 1.4) + band(5, 30, 1.0) * 0.35
bl = n01(bl)
img = np.stack([mott, veins, wr, bl], -1)
Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save("/data/sh_demo/assets/tex/flesh.png")
Image.fromarray((np.concatenate([np.concatenate([mott, veins], 1), np.concatenate([wr, bl], 1)], 0)[::4, ::4] * 255).astype(np.uint8)).save("/data/work/flesh_preview.png")
print("ok", [round(float(c.mean()), 3) for c in (mott, veins, wr, bl)])
