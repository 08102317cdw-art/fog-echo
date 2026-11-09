#!/usr/bin/env python3
"""程序化雕刻“剥皮恶犬”（原创造型）。复用 sculpt_monster 的 SDF/网格管线。
坐标：Y 上，狗面朝 -Z，+X 为狗的右侧；脚底 y=0。输出 MON1 二进制，交给 dev/build_monster.gd 转 .res"""
import os, sys, json, struct
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("VOX", "0.0045")
import sculpt_monster as B
from sculpt_monster import v3, length, sat, sstep, sd_sphere, sd_ellipsoid, sd_round_cone, seg_dist, smin, smax, fbm, log, F
import numpy as np
from skimage import measure
import pyfqmr
H = float(os.environ.get("VOX", "0.0045"))
TARGET = int(os.environ.get("TRIS", "15000"))
OUT = os.environ.get("OUT", "/data/work/dog.bin")

LEGS = []
for s in (-1, 1):
    x = 0.082 * s
    LEGS.append(dict(s=s, k="f", a=v3(x, 0.49, -0.30), b=v3(x * 1.1, 0.29, -0.255), c=v3(x * 1.02, 0.10, -0.285), d=v3(x * 1.02, 0.018, -0.34),
                     r=(0.056, 0.034, 0.026, 0.021, 0.018)))
    LEGS.append(dict(s=s, k="h", a=v3(x, 0.52, 0.29), b=v3(x * 1.15, 0.33, 0.195), c=v3(x * 1.06, 0.14, 0.35), d=v3(x * 1.06, 0.018, 0.315),
                     r=(0.076, 0.041, 0.023, 0.019, 0.017)))
CAV_C = v3(-0.112, 0.47, -0.16); CAV_R = v3(0.055, 0.085, 0.11)
RIBS = [(v3(-0.085, 0.585, -0.26 + i * 0.05), v3(-0.103, 0.37, -0.23 + i * 0.05)) for i in range(5)]
SNOUT_A = v3(0, 0.728, -0.62); SNOUT_B = v3(0, 0.695, -0.80)
JAW_A = v3(0, 0.672, -0.585); JAW_B = v3(0, 0.628, -0.775)

def teeth_sdf(P):
    d = np.full(len(P), 1.0, F)
    for s in (-1, 1):
        for i in range(6):
            t = 0.12 + i * 0.15
            p = SNOUT_A + (SNOUT_B - SNOUT_A) * t + v3(s * (0.03 - 0.012 * t), -0.035 + 0.012 * t, 0)
            d = np.minimum(d, sd_round_cone(P, p, p + v3(0, -0.02 + 0.004 * t, -0.003), 0.0055, 0.0012))
            q = JAW_A + (JAW_B - JAW_A) * t + v3(s * (0.022 - 0.008 * t), 0.022 - 0.004 * t, 0)
            d = np.minimum(d, sd_round_cone(P, q, q + v3(0, 0.016, -0.003), 0.005, 0.001))
    return d

def sdf(P, comp=False):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    chest = sd_ellipsoid(P, (0, 0.465, -0.215), (0.112, 0.152, 0.19))
    waist = sd_ellipsoid(P, (0, 0.535, 0.035), (0.07, 0.07, 0.17))
    rump = sd_ellipsoid(P, (0, 0.53, 0.275), (0.09, 0.1, 0.12))
    torso = smin(smin(chest, waist, 0.09), rump, 0.08)
    # 脊椎凸起
    spine = np.full(len(P), 1.0, F)
    for i in range(16):
        zz = -0.36 + i * 0.045
        yy = 0.6 + 0.03 * np.sin(np.clip((zz + 0.36) / 0.72, 0, 1) * np.pi) - (0.01 if zz > 0.2 else 0.0)
        spine = np.minimum(spine, sd_sphere(P, (0, yy - 0.002, zz), 0.0145))
    torso = smin(torso, spine, 0.03)
    # 肋骨起伏（瘦骨嶙峋）
    rib = 0.5 + 0.5 * np.cos((z + (0.5 - y) * 0.35) * (2 * np.pi / 0.046))
    rm = sstep(-0.39, -0.33, z) * (1 - sstep(-0.06, 0.0, z)) * sstep(0.33, 0.4, y) * (1 - sstep(0.56, 0.62, y)) * sstep(0.03, 0.07, np.abs(x))
    torso = torso - 0.0065 * rib * rm + 0.004 * (1 - rib) * rm * 0.3
    # 左侧撕裂的伤口 + 裸露肋骨
    cav = sd_ellipsoid(P, CAV_C, CAV_R)
    torso = smax(torso, -cav, 0.015)
    ribs = np.full(len(P), 1.0, F)
    for a, b in RIBS:
        ribs = np.minimum(ribs, sd_round_cone(P, a, b, 0.0085, 0.007))
    ribs = smax(ribs, cav - 0.01, 0.01)
    torso = smin(torso, ribs, 0.006)
    # 颈 + 头
    neck = sd_round_cone(P, v3(0, 0.55, -0.35), v3(0, 0.70, -0.53), 0.078, 0.05)
    skull = sd_ellipsoid(P, (0, 0.738, -0.575), (0.06, 0.062, 0.085))
    snout = sd_round_cone(P, SNOUT_A, SNOUT_B, 0.044, 0.024)
    head = smin(skull, snout, 0.035)
    eyes = np.minimum(sd_sphere(P, (-0.04, 0.752, -0.625), 0.016), sd_sphere(P, (0.04, 0.752, -0.625), 0.016))
    head = smax(head, -eyes, 0.006)
    ears = np.minimum(sd_round_cone(P, v3(-0.035, 0.775, -0.545), v3(-0.065, 0.835, -0.51), 0.018, 0.005),
                      sd_round_cone(P, v3(0.035, 0.775, -0.545), v3(0.06, 0.82, -0.505), 0.017, 0.004))
    head = smin(head, ears, 0.01)
    # 嘴：上颚底部切开
    mouth = sd_round_cone(P, v3(0, 0.67, -0.6), v3(0, 0.655, -0.83), 0.022, 0.015)
    head = smax(head, -mouth, 0.008)
    jaw = sd_round_cone(P, JAW_A, JAW_B, 0.029, 0.016)
    jaw = smax(jaw, -sd_round_cone(P, JAW_A + v3(0, 0.03, -0.03), JAW_B + v3(0, 0.022, 0), 0.02, 0.011), 0.006)
    teeth = teeth_sdf(P)
    # 腿
    legd = np.full(len(P), 1.0, F)
    for L in LEGS:
        r = L["r"]
        u = sd_round_cone(P, L["a"], L["b"], r[0], r[1])
        lo = sd_round_cone(P, L["b"], L["c"], r[1] * 0.85, r[2])
        pw = sd_round_cone(P, L["c"], L["d"], r[2], r[3])
        paw = sd_ellipsoid(P, L["d"] + v3(0, 0.004, -0.012), (0.024, 0.017, 0.032))
        leg = smin(smin(smin(u, lo, 0.02), pw, 0.012), paw, 0.012)
        legd = np.minimum(legd, leg)
    tail = smin(sd_round_cone(P, v3(0, 0.565, 0.38), v3(0, 0.475, 0.55), 0.022, 0.012),
                sd_round_cone(P, v3(0, 0.475, 0.55), v3(0, 0.36, 0.625), 0.012, 0.006), 0.01)
    body = smin(torso, neck, 0.05)
    body = smin(body, legd, 0.045)
    body = smin(body, tail, 0.015)
    body = smin(body, head, 0.03)
    # 肌肉纹理
    n = fbm(P, 26.0, 3, 1)
    fib = np.sin(z * 260.0 + y * 40.0 + n * 3.0)
    d = body - 0.0028 * n - 0.0009 * fib * sstep(0.2, 0.6, y)
    d = np.minimum(d, smin(jaw, teeth, 0.003))
    d = np.minimum(d, teeth)
    if comp:
        return d, dict(cavity=cav, ribs=ribs, mouth=mouth, teeth=teeth, eyes=eyes, legs=legd, torso=torso, head=np.minimum(head, jaw), jaw=jaw, skull=head, tail=tail)
    return d

def grad(P, e=0.0015):
    g = np.zeros_like(P)
    for k in range(3):
        o = np.zeros(3, F); o[k] = e
        g[:, k] = sdf(P + o) - sdf(P - o)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)

def build():
    lo = v3(-0.17, -0.01, -0.88); hi = v3(0.17, 0.87, 0.67)
    nx, ny, nz = [int(np.ceil((hi[i] - lo[i]) / H)) + 1 for i in range(3)]
    log(f"grid {nx}x{ny}x{nz} = {nx*ny*nz/1e6:.1f}M")
    vol = np.empty((nx, ny, nz), F)
    xs = lo[0] + np.arange(nx, dtype=F) * H; zs = lo[2] + np.arange(nz, dtype=F) * H
    XX, ZZ = np.meshgrid(xs, zs, indexing='ij')
    step = max(1, int(400000 / (nx * nz)))
    for j0 in range(0, ny, step):
        j1 = min(ny, j0 + step); ys = lo[1] + np.arange(j0, j1, dtype=F) * H
        P = np.stack(np.broadcast_arrays(XX[:, None, :], ys[None, :, None], ZZ[:, None, :]), -1).reshape(-1, 3).astype(F)
        vol[:, j0:j1, :] = sdf(P).reshape(nx, j1 - j0, nz)
    verts, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(H, H, H))
    return (verts + lo).astype(F), faces.astype(np.int32)

BONES = [
    ("pelvis", -1, (0, 0.53, 0.27), (0, 0.54, 0.15), 0.09),
    ("spine", 0, (0, 0.55, 0.15), (0, 0.55, -0.07), 0.08),
    ("chest", 1, (0, 0.53, -0.07), (0, 0.5, -0.34), 0.13),
    ("neck", 2, (0, 0.57, -0.36), (0, 0.70, -0.52), 0.055),
    ("head", 3, (0, 0.725, -0.545), (0, 0.70, -0.80), 0.045),
    ("jaw", 4, (0, 0.672, -0.585), (0, 0.63, -0.775), 0.02),
    ("tail1", 0, (0, 0.565, 0.38), (0, 0.475, 0.55), 0.015),
    ("tail2", 6, (0, 0.475, 0.55), (0, 0.36, 0.625), 0.01),
]
for L in LEGS:
    sfx = ("_l" if L["s"] < 0 else "_r")
    pi = 2 if L["k"] == "f" else 0
    base = L["k"] + sfx
    n0 = len(BONES)
    BONES.append((base + "_up", pi, tuple(L["a"]), tuple(L["b"]), L["r"][0] * 0.8))
    BONES.append((base + "_lo", n0, tuple(L["b"]), tuple(L["c"]), L["r"][1] * 0.8))
    BONES.append((base + "_paw", n0 + 1, tuple(L["c"]), tuple(L["d"]), L["r"][2] * 0.8))
BI = {b[0]: i for i, b in enumerate(BONES)}

def weights(V, C):
    n = len(V); W = np.zeros((n, len(BONES)), F)
    x = V[:, 0]
    headzone = (V[:, 2] < -0.52) & (V[:, 1] > 0.55)
    isjaw = (((C["jaw"] < C["skull"] - 0.001) & (C["jaw"] < 0.02)) | ((C["teeth"] < 0.004) & (V[:, 1] < 0.668))) & headzone
    for i, (nm, p, a, b, r) in enumerate(BONES):
        d, t = seg_dist(V, a, b)
        de = np.maximum(d - r, 0.0)
        w = 1.0 / (de + 0.012) ** 4
        if nm[0] in "fh" and nm[1] == "_":
            s = -1 if nm[2] == "l" else 1
            w *= sstep(-0.012, 0.02, s * x)
            w *= (C["legs"] < 0.012) | (V[:, 1] < 0.42)
        if nm == "jaw":
            w = np.where(isjaw, 1e6, 0.0)
        elif nm in ("head",):
            w = np.where(isjaw, 0.0, w)
        if nm.startswith("tail"):
            w *= (C["tail"] < 0.01)
        W[:, i] = w
    idx = np.argsort(-W, axis=1)[:, :4].astype(np.int32)
    w4 = np.take_along_axis(W, idx, 1)
    w4 /= np.maximum(w4.sum(1, keepdims=True), 1e-9)
    return idx, w4.astype(F)

def masks(V, Nrm):
    d, C = sdf(V, comp=True)
    n = len(V)
    ao = np.zeros(n, F)
    for i, h in enumerate((0.005, 0.01, 0.018, 0.03, 0.045)):
        ao += (h - sdf(V + Nrm * h)) / h * (0.5 ** i)
    ao = sat(1.0 - ao * 0.55)
    patch = fbm(V, 7.0, 3, 2)
    wound = sstep(0.02, 0.2, patch)                      # 斑驳的剥皮
    wound = np.maximum(wound, 1 - sstep(-0.004, 0.012, C["cavity"]))
    wound = np.maximum(wound, 1 - sstep(-0.002, 0.008, C["mouth"]))
    wound = np.maximum(wound, (1 - sstep(-0.003, 0.006, C["eyes"])) * 0.8)
    wound = np.maximum(wound, sstep(0.0, 0.03, -V[:, 1] + 0.12) * 0.0)
    teeth = 1 - sstep(-0.001, 0.003, C["teeth"])
    ribs = 1 - sstep(-0.001, 0.004, C["ribs"])
    teeth = np.maximum(teeth, ribs * 0.5)
    irrit = sat(1 - np.abs(patch - 0.03) / 0.08) * 0.8
    irrit = np.maximum(irrit, 1 - sstep(0.0, 0.03, C["cavity"]))
    stretch = np.zeros(n, F)
    region = np.where(C["legs"] < np.minimum(C["torso"], 0.0) + 0.003, 1.0, 0.0).astype(F)
    region = np.where(C["head"] < C["torso"] - 0.01, 2.0, region)
    return ao, wound, irrit, stretch, teeth, region, C

def main():
    V, Fc = build(); log(f"mc {len(V)} v")
    V = B.taubin(V, Fc, 4)
    s = pyfqmr.Simplify(); s.setMesh(V.astype(np.float64), Fc)
    s.simplify_mesh(target_count=TARGET, aggressiveness=6, preserve_border=False, verbose=False)
    V, Fc, _ = s.getMesh(); V = V.astype(F); Fc = Fc.astype(np.int32)
    V = B.taubin(V, Fc, 1, 0.3, -0.31)
    log(f"simplified {len(V)} v {len(Fc)} f")
    g = grad(V)
    fn = np.cross(V[Fc[:, 1]] - V[Fc[:, 0]], V[Fc[:, 2]] - V[Fc[:, 0]])
    flip = np.einsum('ij,ij->i', fn, g[Fc[:, 0]] + g[Fc[:, 1]] + g[Fc[:, 2]]) > 0
    Fc[flip] = Fc[flip][:, [0, 2, 1]]
    Nrm = -B.vnormals(V, Fc)
    Nrm = Nrm * 0.8 + g * 0.2; Nrm /= np.linalg.norm(Nrm, axis=1, keepdims=True)
    ao, wound, irrit, stretch, teeth, region, C = masks(V, Nrm)
    bidx, bw = weights(V, C)
    col = np.stack([wound, ao, irrit, stretch], 1).astype(F)
    uv = V[:, :2].copy(); uv2 = np.stack([V[:, 2], region + teeth * 0.5], 1).astype(F)
    with open(OUT, "wb") as f:
        f.write(b"MON1"); f.write(struct.pack("<iii", len(V), len(Fc), len(BONES)))
        for (nm, p, a, b, r) in BONES:
            f.write(nm.encode().ljust(16, b"\0")); f.write(struct.pack("<i3f", p, *[float(v) for v in a]))
        for arr in (V, Nrm, col, uv, uv2): f.write(np.ascontiguousarray(arr, F).tobytes())
        f.write(np.ascontiguousarray(bidx, np.int32).tobytes()); f.write(np.ascontiguousarray(bw, F).tobytes())
        f.write(np.ascontiguousarray(Fc, np.int32).tobytes())
    log("wrote", OUT, json.dumps(dict(v=len(V), f=len(Fc), bmin=V.min(0).round(3).tolist(), bmax=V.max(0).round(3).tolist(), wound=round(float((wound > 0.5).mean()), 3))))

if __name__ == "__main__":
    main()
