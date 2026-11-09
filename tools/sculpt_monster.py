#!/usr/bin/env python3
"""程序化雕刻“皮囊躺尸”型怪物（原创造型，非任何官方素材）。
SDF 组合 -> marching cubes -> Taubin 平滑 -> 二次误差简化 -> 法线 / 顶点遮罩 / AO / 蒙皮权重 -> 二进制。
坐标：Y 向上，怪物面朝 -Z，+X 为怪物右侧；单位米，脚底 y=0。"""
import numpy as np, time, struct, sys, json, os
from skimage import measure
from scipy import sparse
from scipy.interpolate import PchipInterpolator
import pyfqmr

T0 = time.time()
def log(*a): print(f"[{time.time()-T0:6.1f}s]", *a, flush=True)
F = np.float32
H = float(os.environ.get("VOX", "0.004"))
TARGET = int(os.environ.get("TRIS", "34000"))
OUT = os.environ.get("OUT", "/data/work/monster.bin")

def v3(*a): return np.array(a, F)
def length(a): return np.sqrt(np.einsum('ij,ij->i', a, a))
def sat(x): return np.clip(x, 0.0, 1.0)
def sstep(e0, e1, x):
    t = sat((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t)

# ------------------------------------------------------------------ 基本体
def sd_sphere(P, c, r): return length(P - np.asarray(c, F)) - r
def sd_ellipsoid(P, c, r, R=None):
    q = P - np.asarray(c, F)
    if R is not None: q = q @ R
    r = np.asarray(r, F)
    k0 = length(q / r); k1 = length(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
def sd_round_cone(P, a, b, r1, r2):
    a = np.asarray(a, F); b = np.asarray(b, F)
    ba = b - a; l2 = float(ba @ ba); rr = r1 - r2; a2 = l2 - rr * rr; il2 = 1.0 / l2
    pa = P - a; y = pa @ ba; z = y - l2
    x = pa * l2 - y[:, None] * ba; x2 = np.einsum('ij,ij->i', x, x)
    y2 = y * y * l2; z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    return np.where(np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - r2,
           np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - r1,
                    (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1)).astype(F)
def seg_dist(P, a, b):
    a = np.asarray(a, F); b = np.asarray(b, F); ba = b - a
    t = sat(((P - a) @ ba) / float(ba @ ba))
    return length(P - a - t[:, None] * ba), t
def smin(a, b, k):
    h = sat(0.5 + 0.5 * (b - a) / k)
    return b + (a - b) * h - k * h * (1 - h)
def smax(a, b, k): return -smin(-a, -b, k)
def rot(rx=0.0, ry=0.0, rz=0.0):
    cx, sx, cy, sy, cz, sz = np.cos(rx), np.sin(rx), np.cos(ry), np.sin(ry), np.cos(rz), np.sin(rz)
    X = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]); Y = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Z = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return (Z @ Y @ X).astype(F)   # 列 = 局部轴在世界中的方向

class Perlin:
    def __init__(self, seed, n=64):
        r = np.random.default_rng(seed)
        g = r.normal(size=(n, n, n, 3)).astype(F); g /= np.linalg.norm(g, axis=-1, keepdims=True)
        self.g = g; self.n = n
    def __call__(self, p):
        n = self.n; i = np.floor(p).astype(np.int64); f = (p - i).astype(F); i %= n
        u = f * f * f * (f * (f * 6 - 15) + 10)
        def c(dx, dy, dz):
            g = self.g[(i[:, 0] + dx) % n, (i[:, 1] + dy) % n, (i[:, 2] + dz) % n]
            return np.einsum('ij,ij->i', g, f - v3(dx, dy, dz))
        ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
        x00 = c(0, 0, 0) + ux * (c(1, 0, 0) - c(0, 0, 0)); x10 = c(0, 1, 0) + ux * (c(1, 1, 0) - c(0, 1, 0))
        x01 = c(0, 0, 1) + ux * (c(1, 0, 1) - c(0, 0, 1)); x11 = c(0, 1, 1) + ux * (c(1, 1, 1) - c(0, 1, 1))
        y0 = x00 + uy * (x10 - x00); y1 = x01 + uy * (x11 - x01)
        return (y0 + uz * (y1 - y0)) * 1.6
NZ = [Perlin(s) for s in (11, 23, 37, 41)]
def fbm(P, f, oct=3, k=0):
    s = np.zeros(len(P), F); a = 1.0
    for o in range(oct):
        s += a * NZ[(k + o) % 4](P * f + v3(17.1 * o, 3.7 * o, 9.3 * o)); f *= 2.03; a *= 0.5
    return s

# ------------------------------------------------------------------ 躯干剖面（y, cx, cz, rx, rz）
ST = np.array([
    [0.80,  0.000,  0.012, 0.085, 0.070],
    [0.86,  0.000,  0.015, 0.140, 0.104],
    [0.94,  0.002,  0.013, 0.164, 0.116],
    [1.02,  0.005,  0.007, 0.146, 0.104],
    [1.11,  0.008,  0.000, 0.152, 0.110],
    [1.21,  0.007, -0.006, 0.178, 0.121],
    [1.31,  0.002, -0.010, 0.195, 0.126],
    [1.40, -0.004, -0.012, 0.194, 0.120],
    [1.47, -0.007, -0.016, 0.166, 0.106],
    [1.53, -0.007, -0.024, 0.094, 0.080],
    [1.59, -0.004, -0.032, 0.061, 0.060],
    [1.65,  0.000, -0.040, 0.058, 0.058],
], F)
PCX, PCZ, PRX, PRZ = [PchipInterpolator(ST[:, 0], ST[:, i]) for i in (1, 2, 3, 4)]
def prof(y):
    y = np.clip(y, ST[0, 0], ST[-1, 0])
    return PCX(y).astype(F), PCZ(y).astype(F), PRX(y).astype(F), PRZ(y).astype(F)
def surf(y, a, off=0.0):
    """躯干表面点：a=0 正前方(-Z)，a=+pi/2 右侧(+X)"""
    cx, cz, rx, rz = [float(v[0]) for v in prof(np.array([y]))]
    return v3(cx + (rx + off) * np.sin(a), y, cz - (rz + off) * np.cos(a))

HEAD_C = v3(0.006, 1.700, -0.050)
HEAD_R = v3(0.090, 0.116, 0.098)
HEAD_M = rot(-0.16, 0.05, 0.17)     # 低头 + 歪向一侧
def head_local(P): return (P - HEAD_C) @ HEAD_M
def head_world(q): return HEAD_C + HEAD_M @ np.asarray(q, F)

rng = np.random.default_rng(7)
TUMORS = []
for i in range(10):
    y = rng.uniform(1.14, 1.58); a = rng.uniform(1.4, 4.2) * (1 if rng.random() < 0.7 else -1)
    r = rng.uniform(0.016, 0.04)
    TUMORS.append((surf(y, a, -0.35 * r), r))
TUMORS.append((v3(0.072, 1.585, -0.012), 0.046))      # 颈侧大肉瘤
TUMORS.append((v3(-0.055, 1.78, 0.02), 0.04))         # 头顶后侧
SORES = []
for (y, a, r) in [(1.27, 2.2, 0.018), (1.10, -1.9, 0.015), (1.44, -2.6, 0.02), (0.98, 0.7, 0.013), (1.36, 1.15, 0.012)]:
    SORES.append((surf(y, a, 0.45 * r), r))
SORES.append((v3(-0.135, 0.70, -0.03), 0.014))
SLIT_Y0, SLIT_Y1, SLIT_YC = 1.185, 1.475, 1.33
def slit_front(y):
    cx, cz, rx, rz = prof(np.array([y])); return float(cz[0] - rz[0])

def arms():
    """皮下被束缚的双臂：[(起点, 终点, r1, r2, 类型, 侧)]"""
    out = []
    for s in (-1, 1):
        hi = 0.045 if s > 0 else 0.0
        sh = v3(s * 0.160, 1.452 if s < 0 else 1.432, 0.004)
        el = v3(s * 0.190, 1.172 + hi, -0.028)
        wr = v3(-s * 0.052, 1.072 + hi, -0.130)
        kn = surf(1.072 + hi, -s * 0.92, 0.012)
        out.append((sh, el, 0.048, 0.040, "arm", s))
        out.append((el, wr, 0.040, 0.029, "fore", s))
        out.append((wr, kn, 0.027, 0.025, "hand", s))
        for j in range(4):
            yy = 1.072 + hi + (j - 1.5) * 0.021
            b = surf(yy, -s * 0.98, 0.009)
            t = surf(yy - 0.004 * j, -s * (1.30 + 0.05 * (j == 1) - 0.06 * (j == 3)), 0.005)
            out.append((b, t, 0.0105, 0.0082, "hand", s))
    return out
ARMS = arms()

def legs_def():
    L = []
    for s in (-1, 1):
        L.append(dict(s=s, hip=v3(s * 0.098, 0.925, 0.008), knee=v3(s * 0.090, 0.505, -0.028),
                      ank=v3(s * 0.083, 0.088, 0.034), toe=v3(s * 0.088, 0.02, -0.15)))
    return L
LEGS = legs_def()

# ------------------------------------------------------------------ SDF
def sdf(P, comp=False):
    ylo, yhi = float(P[:, 1].min()), float(P[:, 1].max())
    def on(y0, y1, m=0.07): return not (y1 + m < ylo or y0 - m > yhi)
    N = len(P); x, y, z = P[:, 0], P[:, 1], P[:, 2]
    BIG = np.full(N, 1.0, F)
    C = {}
    d = BIG.copy()
    C["torso"] = BIG.copy()
    if on(0.78, 1.68):
        cx, cz, rx, rz = prof(y)
        qx = (x - cx) / rx; qz = (z - cz) / rz
        k0 = np.sqrt(qx * qx + qz * qz); k1 = np.sqrt((qx / rx) ** 2 + (qz / rz) ** 2)
        dt = k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
        dt = smax(dt, 0.80 - y, 0.035); dt = smax(dt, y - 1.665, 0.02)
        dt = smin(dt, sd_ellipsoid(P, (-0.12, 1.47, -0.008), (0.075, 0.05, 0.085)), 0.04)   # 左肩隆起
        for s in (-1, 1):
            dt = smin(dt, sd_ellipsoid(P, (s * 0.085, 1.37, 0.098), (0.058, 0.08, 0.022), rot(0.15, 0, s * 0.35)), 0.03)
            dt = smin(dt, sd_ellipsoid(P, (s * 0.142, 1.005, -0.012), (0.022, 0.02, 0.06), rot(0, s * 0.6, 0)), 0.03)
        for yy in np.arange(0.97, 1.53, 0.031):
            pcx, pcz, prx, prz = [float(v[0]) for v in prof(np.array([yy]))]
            rr = 0.0145 + (0.006 if yy > 1.45 else 0.0)
            dt = smin(dt, sd_sphere(P, (pcx, yy, pcz + prz - 0.0125), rr), 0.013)
        for s in (-1, 1):
            dt = smin(dt, sd_round_cone(P, (s * 0.034, 1.645, -0.032), (s * 0.085, 1.50, -0.05), 0.013, 0.018), 0.02)
        C["torso"] = dt.copy()
        d = dt
    da = BIG.copy()
    for (a, b, r1, r2, kind, s) in ARMS:
        if on(min(a[1], b[1]) - r1, max(a[1], b[1]) + r1):
            da = np.minimum(da, sd_round_cone(P, a, b, r1, r2))
    for s in (-1, 1):
        hi = 0.045 if s > 0 else 0.0
        if on(1.1, 1.3): da = np.minimum(da, sd_sphere(P, (s * 0.198, 1.168 + hi, -0.018), 0.034))
    C["arms"] = da
    d = smin(d, da, 0.032)
    C["mouth"] = BIG.copy(); C["eyes"] = BIG.copy(); C["head"] = BIG.copy()
    if on(1.55, 1.86):
        q = head_local(P)
        dh = sd_ellipsoid(q, (0, 0, 0), HEAD_R)
        dh = smin(dh, sd_round_cone(q, (-0.05, 0.026, -0.078), (0.05, 0.032, -0.076), 0.016, 0.015), 0.03)
        dh = smin(dh, sd_round_cone(q, (0, 0.012, -0.094), (0.002, -0.028, -0.114), 0.010, 0.015), 0.02)
        for s in (-1, 1):
            dh = smin(dh, sd_sphere(q, (s * 0.052, -0.014, -0.074), 0.023), 0.025)
        dh = smin(dh, sd_ellipsoid(q, (0, -0.062, -0.090), (0.036, 0.046, 0.024)), 0.016)
        dh = smin(dh, sd_sphere(q, (0, -0.112, -0.066), 0.026), 0.026)
        eyes = np.minimum(sd_sphere(q, (-0.033, -0.002, -0.101), 0.021), sd_sphere(q, (0.033, 0.002, -0.101), 0.019))
        dh = smax(dh, -eyes, 0.016)
        mouth = sd_ellipsoid(q, (0.002, -0.064, -0.098), (0.022, 0.033, 0.036))
        dh = smax(dh, -mouth, 0.01)
        C["mouth"] = mouth; C["eyes"] = eyes; C["head"] = dh.copy()
        d = smin(d, dh, 0.045)
    for (c, r) in TUMORS:
        if on(c[1] - r, c[1] + r): d = smin(d, sd_sphere(P, c, r), 0.022)
    dl = BIG.copy(); cav = BIG.copy(); teeth = BIG.copy()
    if on(SLIT_Y0, SLIT_Y1):
        zf = slit_front(SLIT_YC)
        for s in (-1, 1):
            dl = np.minimum(dl, sd_ellipsoid(P, (s * 0.021, SLIT_YC, zf + 0.002), (0.0175, 0.158, 0.021)))
        d = smin(d, dl, 0.02)
        cav = sd_ellipsoid(P, (0, SLIT_YC, zf + 0.012), (0.0135, 0.150, 0.052))
        d = smax(d, -cav, 0.008)
        for s in (-1, 1):
            for j in range(7):
                yy = 1.218 + j * 0.037 + s * 0.008
                teeth = np.minimum(teeth, sd_round_cone(P, (s * 0.0135, yy, zf + 0.016), (s * 0.002, yy - 0.009, zf - 0.004), 0.0056, 0.0018))
        d = smin(d, teeth, 0.004)
        d = smin(d, sd_ellipsoid(P, (0, SLIT_YC, zf + 0.062), (0.03, 0.13, 0.02)), 0.02)
    C["lips"] = dl; C["cavity"] = cav; C["teeth"] = teeth
    dg = BIG.copy()
    for L in LEGS:
        s = L["s"]; hip, knee, ank = L["hip"], L["knee"], L["ank"]
        if not on(-0.02, 0.98): continue
        g = sd_round_cone(P, hip, knee, 0.072, 0.043)
        g = smin(g, sd_ellipsoid(P, (s * 0.104, 0.72, -0.018), (0.044, 0.15, 0.046)), 0.03)
        g = smin(g, sd_ellipsoid(P, (s * 0.094, 0.70, 0.026), (0.042, 0.14, 0.042)), 0.03)
        g = smin(g, sd_sphere(P, (s * 0.090, 0.505, -0.064), 0.029), 0.012)
        for o in (-1, 1):
            g = smin(g, sd_sphere(P, (s * 0.090 + o * 0.03, 0.50, -0.03), 0.027), 0.015)
        g = smin(g, sd_round_cone(P, knee, ank, 0.041, 0.025), 0.02)
        g = smin(g, sd_ellipsoid(P, (s * 0.091, 0.37, 0.007), (0.039, 0.10, 0.043)), 0.025)
        g = smin(g, sd_round_cone(P, (s * 0.088, 0.47, -0.047), (s * 0.084, 0.15, -0.012), 0.011, 0.008), 0.012)
        for o in (-1, 1):
            g = smin(g, sd_sphere(P, (s * 0.083 + o * 0.025, 0.088, 0.032), 0.016), 0.01)
        ft = sd_sphere(P, (s * 0.083, 0.036, 0.058), 0.034)
        ft = smin(ft, sd_round_cone(P, (s * 0.083, 0.046, 0.04), (s * 0.088, 0.024, -0.098), 0.035, 0.024), 0.02)
        for j in range(4):
            xx = s * (0.068 + j * 0.0145)
            rr = 0.0125 if j == 0 else 0.0095 - 0.0008 * j
            ft = smin(ft, sd_round_cone(P, (xx, 0.022, -0.095), (xx + s * 0.003 * j, 0.012, -0.160 + 0.011 * j), rr, rr * 0.82), 0.006)
        g = smin(g, ft, 0.022)
        dg = np.minimum(dg, g)
    C["legs"] = dg
    d = smin(d, dg, 0.045)
    dsore = BIG.copy()
    for (c, r) in SORES:
        if on(c[1] - r, c[1] + r): dsore = np.minimum(dsore, sd_sphere(P, c, r))
    d = smax(d, -dsore, 0.006)
    C["sores"] = dsore
    near = np.abs(d) < 0.03
    if near.any():
        Q = P[near]; qy = Q[:, 1]
        cx, cz, rx, rz = prof(qy)
        ang = np.arctan2(Q[:, 0] - cx, -(Q[:, 2] - cz))
        tf = np.clip(-(Q[:, 2] - cz) / rz, -1, 1)
        disp = np.zeros(len(Q), F)
        amp = 0.0042 + 0.004 * sstep(1.55, 1.7, qy) - 0.0022 * sstep(0.9, 0.8, qy)
        disp += amp * fbm(Q, 7.0, 3, 0)
        disp += 0.0011 * fbm(Q, 38.0, 2, 2)
        sr = qy + 0.03 * tf
        rib = (0.5 + 0.5 * np.cos(2 * np.pi * (sr - 1.12) / 0.034)) ** 3
        side = sstep(0.35, 0.75, np.abs(Q[:, 0] - cx) / rx) * (1 - sstep(0.75, 0.95, -tf))
        ribm = sstep(1.12, 1.18, qy) * (1 - sstep(1.40, 1.45, qy)) * side
        disp -= 0.0042 * rib * ribm
        nm = sstep(1.46, 1.52, qy) * (1 - sstep(1.62, 1.68, qy))
        disp += 0.0042 * np.sin(3 * ang + (qy - 1.46) * 46 + 0.7) * nm
        wm = sstep(0.95, 0.99, qy) * (1 - sstep(1.06, 1.1, qy)) * (1 - sstep(0.4, 0.9, -tf))
        disp += 0.0022 * np.sin(2 * np.pi * (qy + 0.004 * fbm(Q, 12, 1, 1)) / 0.019) * wm
        km = np.exp(-((qy - 0.50) / 0.03) ** 2) + 0.7 * np.exp(-((qy - 0.10) / 0.02) ** 2)
        km = km * (qy < 0.9)
        disp += 0.0016 * np.sin(2 * np.pi * qy / 0.012) * km
        d[near] = d[near] - disp
    d = smax(d, 0.002 - y, 0.004)
    if comp: return d, C
    return d

# ------------------------------------------------------------------ 体素化 + 提取
def build():
    lo = v3(-0.30, -0.012, -0.235); hi = v3(0.30, 1.865, 0.225)
    nx, ny, nz = [int(np.ceil((hi[i] - lo[i]) / H)) + 1 for i in range(3)]
    log(f"grid {nx}x{ny}x{nz} = {nx*ny*nz/1e6:.1f}M  h={H}")
    vol = np.empty((nx, ny, nz), F)
    xs = lo[0] + np.arange(nx, dtype=F) * H; zs = lo[2] + np.arange(nz, dtype=F) * H
    XX, ZZ = np.meshgrid(xs, zs, indexing='ij')
    step = max(1, int(500000 / (nx * nz)))
    for j0 in range(0, ny, step):
        j1 = min(ny, j0 + step); ys = lo[1] + np.arange(j0, j1, dtype=F) * H
        P = np.stack(np.broadcast_arrays(XX[:, None, :], ys[None, :, None], ZZ[:, None, :]), -1).reshape(-1, 3).astype(F)
        vol[:, j0:j1, :] = sdf(P).reshape(nx, j1 - j0, nz)
    log("sdf done")
    verts, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(H, H, H))
    verts = (verts + lo).astype(F); faces = faces.astype(np.int32)
    log(f"mc: {len(verts)} v {len(faces)} f")
    return verts, faces

def taubin(V, Fc, it=6, lam=0.5, mu=-0.53):
    n = len(V); e = np.concatenate([Fc[:, [0, 1]], Fc[:, [1, 2]], Fc[:, [2, 0]]])
    A = sparse.coo_matrix((np.ones(len(e) * 2, F), (np.r_[e[:, 0], e[:, 1]], np.r_[e[:, 1], e[:, 0]])), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel(); deg[deg == 0] = 1
    for _ in range(it):
        for f in (lam, mu):
            V = V + f * ((A @ V) / deg[:, None] - V)
    return V.astype(F)

def vnormals(V, Fc):
    fn = np.cross(V[Fc[:, 1]] - V[Fc[:, 0]], V[Fc[:, 2]] - V[Fc[:, 0]])
    N = np.zeros_like(V)
    for k in range(3): np.add.at(N, Fc[:, k], fn)
    return (N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)).astype(F)

def grad(P, e=0.0015):
    g = np.zeros_like(P)
    for k in range(3):
        o = np.zeros(3, F); o[k] = e
        g[:, k] = sdf(P + o) - sdf(P - o)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)

# ------------------------------------------------------------------ 骨骼
BONES = [
    ("pelvis", -1, (0.0, 0.93, 0.008)),
    ("spine1", 0, (0.004, 1.05, 0.004)),
    ("spine2", 1, (0.007, 1.18, -0.004)),
    ("chest", 2, (0.002, 1.31, -0.010)),
    ("neck", 3, (-0.006, 1.50, -0.020)),
    ("head", 4, (-0.002, 1.605, -0.036)),
    ("thigh_l", 0, tuple(LEGS[0]["hip"])), ("shin_l", 6, tuple(LEGS[0]["knee"])), ("foot_l", 7, tuple(LEGS[0]["ank"])),
    ("thigh_r", 0, tuple(LEGS[1]["hip"])), ("shin_r", 9, tuple(LEGS[1]["knee"])), ("foot_r", 10, tuple(LEGS[1]["ank"])),
    ("arm_l", 3, (-0.165, 1.40, -0.004)), ("arm_r", 3, (0.165, 1.40, -0.004)),
    ("hand_l", 1, None), ("hand_r", 1, None),
    ("slit_l", 3, (-0.012, SLIT_YC, -0.14)), ("slit_r", 3, (0.012, SLIT_YC, -0.14)),
    ("jaw", 5, None),
]
BI = {b[0]: i for i, b in enumerate(BONES)}
def finalize_bones():
    out = []
    for (n, p, h) in BONES:
        if n == "hand_l": h = tuple(ARMS[2][1])
        if n == "hand_r": h = tuple(ARMS[9][1])
        if n == "jaw": h = tuple(head_world((0, -0.07, -0.07)))
        out.append((n, p, np.asarray(h, F)))
    return out

def weights(V, bones):
    n = len(V); W = np.zeros((n, len(bones)), F)
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    legw = np.zeros(n, F)
    for L in LEGS:
        s = L["s"]; sfx = "_l" if s < 0 else "_r"
        side = sstep(-0.01, 0.03, s * x)
        dth, tth = seg_dist(V, L["hip"], L["knee"]); dsh, tsh = seg_dist(V, L["knee"], L["ank"]); dft, _ = seg_dist(V, L["ank"], L["toe"])
        raw = np.stack([1 / (dth + 0.02) ** 4, 1 / (dsh + 0.02) ** 4, 1 / (dft + 0.02) ** 4], 1)
        raw /= raw.sum(1, keepdims=True)
        lw = side * (1 - sstep(0.84, 0.97, y))
        for k, nm in enumerate(("thigh", "shin", "foot")):
            W[:, BI[nm + sfx]] += raw[:, k] * lw
        legw += lw
    chain = [("pelvis", 0.88, 1.05), ("spine1", 1.05, 1.18), ("spine2", 1.18, 1.31), ("chest", 1.31, 1.50), ("neck", 1.50, 1.61), ("head", 1.61, 1.95)]
    cw = []
    for nm, a, b in chain:
        dd = np.maximum(np.maximum(a - y, y - b), 0.0)
        if nm == "pelvis": dd = np.maximum(y - b, 0.0)
        cw.append(np.maximum(0, 1 - dd / 0.07) ** 2)
    cw = np.stack(cw, 1); cw /= np.maximum(cw.sum(1, keepdims=True), 1e-6)
    rest = 1 - legw
    special = np.zeros(n, F)
    for s, sfx in ((-1, "_l"), (1, "_r")):
        segs = [a for a in ARMS if a[5] == s]
        darm = np.full(n, 1.0, F); dfore = np.full(n, 1.0, F); dhand = np.full(n, 1.0, F); tfore = np.zeros(n, F)
        for (a, b, r1, r2, kind, _) in segs:
            dd, tt = seg_dist(V, a, b); dd = dd - (r1 + r2) * 0.5
            if kind == "arm": darm = np.minimum(darm, dd)
            elif kind == "fore":
                m = dd < dfore; tfore = np.where(m, tt, tfore); dfore = np.minimum(dfore, dd)
            else: dhand = np.minimum(dhand, dd)
        wa = (1 - sstep(0.0, 0.04, darm)) * 0.85; wf = 1 - sstep(0.0, 0.035, dfore); wh = (1 - sstep(0.0, 0.03, dhand)) * 0.9
        wfa = wf * (1 - tfore) * 0.8; wfh = wf * tfore * 0.85
        a_tot = np.maximum(wa, wfa); h_tot = np.maximum(wh, wfh)
        tot = np.minimum(a_tot + h_tot, 0.92)
        sc = np.where(a_tot + h_tot > 0, tot / np.maximum(a_tot + h_tot, 1e-6), 0)
        W[:, BI["arm" + sfx]] += a_tot * sc * rest
        W[:, BI["hand" + sfx]] += h_tot * sc * rest
        special += tot
    zf = slit_front(SLIT_YC)
    yy = sstep(SLIT_Y0 - 0.03, SLIT_Y0 + 0.02, y) * (1 - sstep(SLIT_Y1 - 0.02, SLIT_Y1 + 0.03, y))
    front = sstep(zf + 0.075, zf + 0.03, z)
    lat = 1 - sstep(0.008, 0.055, np.abs(x))
    ws = yy * front * lat * 0.95
    sideL = sstep(0.004, -0.004, x); sideR = 1 - sideL
    W[:, BI["slit_l"]] += ws * sideL * rest
    W[:, BI["slit_r"]] += ws * sideR * rest
    special += ws
    q = head_local(V)
    wj = (1 - sstep(-0.05, -0.025, q[:, 1])) * sstep(-0.02, -0.07, q[:, 2]) * (1 - sstep(0.04, 0.07, np.abs(q[:, 0]))) * (y > 1.5)
    wj = wj * 0.9
    W[:, BI["jaw"]] += wj * rest
    special += wj
    special = np.minimum(special, 0.95)
    for k, (nm, a, b) in enumerate(chain):
        W[:, BI[nm]] += cw[:, k] * rest * (1 - special)
    idx = np.argsort(-W, axis=1)[:, :4].astype(np.int32)
    w4 = np.take_along_axis(W, idx, 1)
    w4 /= np.maximum(w4.sum(1, keepdims=True), 1e-6)
    return idx, w4.astype(F)

def masks(V, Nrm):
    d, C = sdf(V, comp=True)
    n = len(V)
    ao = np.zeros(n, F)
    for i, h in enumerate((0.006, 0.012, 0.022, 0.036, 0.055)):
        ao += (h - sdf(V + Nrm * h)) / h * (0.5 ** i)
    ao = sat(1.0 - ao * 0.55)
    wound = np.zeros(n, F)
    wound = np.maximum(wound, 1 - sstep(-0.004, 0.006, C["cavity"]))
    wound = np.maximum(wound, (1 - sstep(-0.004, 0.006, C["teeth"])) * 0.4)
    wound = np.maximum(wound, 1 - sstep(-0.002, 0.008, C["mouth"]))
    wound = np.maximum(wound, (1 - sstep(-0.003, 0.006, C["eyes"])) * 0.5)
    wound = np.maximum(wound, 1 - sstep(-0.002, 0.006, C["sores"]))
    teeth = 1 - sstep(-0.002, 0.003, C["teeth"])
    irrit = np.zeros(n, F)
    irrit = np.maximum(irrit, 1 - sstep(0.0, 0.03, C["lips"]))
    irrit = np.maximum(irrit, 1 - sstep(0.0, 0.025, C["mouth"]))
    irrit = np.maximum(irrit, 1 - sstep(0.0, 0.03, C["sores"]))
    stretch = 1 - sstep(-0.004, 0.02, C["arms"])
    region = np.where(C["legs"] < np.minimum(C["torso"], 0.0) + 0.002, 1.0, 0.0).astype(F)
    region = np.where(V[:, 1] > 1.56, 2.0, region)
    return ao, wound, irrit, stretch, teeth, region

def main():
    V, Fc = build()
    V = taubin(V, Fc, 5)
    log("smoothed")
    s = pyfqmr.Simplify(); s.setMesh(V.astype(np.float64), Fc)
    s.simplify_mesh(target_count=TARGET, aggressiveness=6, preserve_border=False, verbose=False)
    V, Fc, _ = s.getMesh(); V = V.astype(F); Fc = Fc.astype(np.int32)
    log(f"simplified: {len(V)} v {len(Fc)} f")
    V = taubin(V, Fc, 1, 0.3, -0.31)
    g = grad(V)
    fn = np.cross(V[Fc[:, 1]] - V[Fc[:, 0]], V[Fc[:, 2]] - V[Fc[:, 0]])
    gc = (g[Fc[:, 0]] + g[Fc[:, 1]] + g[Fc[:, 2]])
    flip = np.einsum('ij,ij->i', fn, gc) > 0
    log(f"flip {flip.mean()*100:.1f}% faces")
    Fc[flip] = Fc[flip][:, [0, 2, 1]]
    Nrm = -vnormals(V, Fc)
    Nrm = Nrm * 0.8 + g * 0.2; Nrm /= np.linalg.norm(Nrm, axis=1, keepdims=True)
    ao, wound, irrit, stretch, teeth, region = masks(V, Nrm)
    log("masks")
    bones = finalize_bones()
    bidx, bw = weights(V, bones)
    log("weights")
    col = np.stack([wound, ao, irrit, stretch], 1).astype(F)
    uv = V[:, :2].copy(); uv2 = np.stack([V[:, 2], region + teeth * 0.5], 1).astype(F)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(b"MON1"); f.write(struct.pack("<iii", len(V), len(Fc), len(bones)))
        for (n, p, h) in bones:
            f.write(n.encode().ljust(16, b"\0")); f.write(struct.pack("<i3f", p, *[float(v) for v in h]))
        for arr in (V, Nrm, col, uv, uv2): f.write(np.ascontiguousarray(arr, F).tobytes())
        f.write(np.ascontiguousarray(bidx, np.int32).tobytes()); f.write(np.ascontiguousarray(bw, F).tobytes())
        f.write(np.ascontiguousarray(Fc, np.int32).tobytes())
    st = dict(verts=len(V), tris=len(Fc), bmin=V.min(0).round(3).tolist(), bmax=V.max(0).round(3).tolist(),
              wound=round(float((wound > 0.5).mean()), 4), ao_mean=round(float(ao.mean()), 3))
    log("wrote", OUT, json.dumps(st))

if __name__ == "__main__":
    main()
