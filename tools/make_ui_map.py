import re, random, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
src = open('/data/sh_demo/scripts/level_map.gd', encoding='utf-8').read()
rows = re.findall(r'"([A-Za-z.,_]+)"', src.split('ROWS')[1])
H, W = len(rows), len(rows[0])
S = 20; M = 70
IW, IH = W*S + 2*M, H*S + 2*M + 40
random.seed(7)
paper = Image.open('/data/sh_demo/assets/tex/paper.png').convert('RGB').resize((IW, IH))
base = Image.new('RGB', (IW, IH), (226, 214, 188))
img = Image.blend(base, paper, 0.55)
d = ImageDraw.Draw(img, 'RGBA')
FS = '/usr/share/fonts/google-noto-cjk/NotoSerifCJK-Regular.ttc'
FB = '/usr/share/fonts/google-noto-cjk/NotoSerifCJK-Bold.ttc'
def font(sz, bold=False): return ImageFont.truetype(FB if bold else FS, sz, index=2)
ink = (52, 46, 40)
def cell_rect(c, r): return (M + c*S, M + 40 + r*S, M + c*S + S, M + 40 + r*S + S)
BUILD = "SIMCQAVBKNOEHRJYZ"
cols = {
 'X': (120, 112, 100, 120), '.': (240, 234, 216, 255), ',': (214, 205, 184, 255), 'P': (240, 234, 216, 255),
 'g': (176, 182, 150, 200), 'T': (150, 160, 128, 210), 'y': (200, 192, 170, 230), 'l': (182, 182, 150, 210),
 'w': (196, 170, 140, 255), 'k': (196, 170, 140, 255), '_': (192, 186, 170, 255), 'F': (176, 182, 150, 200), 'G': (200, 192, 170, 230),
}
for r in range(H):
    for c in range(W):
        t = rows[r][c]
        x0, y0, x1, y1 = cell_rect(c, r)
        if t in BUILD:
            col = (168, 156, 136, 255) if t != 'S' else (160, 146, 126, 255)
            d.rectangle((x0, y0, x1, y1), fill=col)
        elif t in cols:
            d.rectangle((x0, y0, x1, y1), fill=cols[t])
# hatch void / cliffs
for r in range(H):
    for c in range(W):
        if rows[r][c] == 'X':
            x0, y0, x1, y1 = cell_rect(c, r)
            for k in range(-S, S, 6):
                d.line((x0 + k, y1, x0 + k + S, y0), fill=(70, 62, 54, 90), width=1)
# building outlines
def is_b(c, r):
    return 0 <= r < H and 0 <= c < W and rows[r][c] in BUILD + 'wk'
for r in range(H):
    for c in range(W):
        if not is_b(c, r): continue
        x0, y0, x1, y1 = cell_rect(c, r)
        if not is_b(c, r-1): d.line((x0, y0, x1, y0), fill=ink + (255,), width=2)
        if not is_b(c, r+1): d.line((x0, y1, x1, y1), fill=ink + (255,), width=2)
        if not is_b(c-1, r): d.line((x0, y0, x0, y1), fill=ink + (255,), width=2)
        if not is_b(c+1, r): d.line((x1, y0, x1, y1), fill=ink + (255,), width=2)
# cliff edges (where road/sidewalk meets X)
for r in range(H):
    for c in range(W):
        if rows[r][c] in '.,P':
            x0, y0, x1, y1 = cell_rect(c, r)
            for dc, dr, ln in [(0, -1, (x0, y0, x1, y0)), (0, 1, (x0, y1, x1, y1)), (-1, 0, (x0, y0, x0, y1)), (1, 0, (x1, y0, x1, y1))]:
                cc, rr = c + dc, r + dr
                if 0 <= cc < W and 0 <= rr < H and rows[rr][cc] == 'X':
                    d.line(ln, fill=(40, 30, 25, 255), width=3)
# trees
for r in range(H):
    for c in range(W):
        if rows[r][c] == 'T':
            x0, y0, x1, y1 = cell_rect(c, r)
            cx, cy = (x0 + x1) / 2 + random.uniform(-3, 3), (y0 + y1) / 2 + random.uniform(-3, 3)
            d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), outline=(70, 80, 60, 255), width=2)
# fences
for r in range(H):
    for c in range(W):
        if rows[r][c] == 'F':
            x0, y0, x1, y1 = cell_rect(c, r)
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            d.line((x0, cy, x1, cy), fill=(80, 80, 70, 200), width=1)
            d.line((cx, y0, cx, y1), fill=(80, 80, 70, 200), width=1)
# road center dashes
def wx(x): return M + (x + 1) * S / 2
def wz(z): return M + 40 + (z + 1) * S / 2
for x in range(8, 88, 6):
    d.line((wx(x), wz(22), wx(x + 3), wz(22)), fill=(170, 150, 80, 255), width=2)
for x in range(8, 80, 6):
    d.line((wx(x), wz(64), wx(x + 3), wz(64)), fill=(170, 150, 80, 255), width=2)
for z in range(26, 96, 6):
    if 42 <= z <= 50: continue
    d.line((wx(42), wz(z), wx(42), wz(z + 3)), fill=(170, 150, 80, 255), width=2)
for z in range(26, 62, 6):
    d.line((wx(78), wz(z), wx(78), wz(z + 3)), fill=(170, 150, 80, 255), width=2)
# labels
def text(x, y, s, sz, rot=0, bold=False, fill=ink):
    f = font(sz, bold)
    bb = d.textbbox((0, 0), s, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    tmp = Image.new('RGBA', (w + 8, h + 12), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((4 - bb[0], 4 - bb[1]), s, font=f, fill=fill + (255,))
    if rot: tmp = tmp.rotate(rot, expand=True, resample=Image.BICUBIC)
    img.paste(tmp, (int(x - tmp.width / 2), int(y - tmp.height / 2)), tmp)
text(wx(20), wz(22), 'MIDWICH ST.', 17, bold=True)
text(wx(64), wz(22), 'MIDWICH ST.', 17, bold=True)
text(wx(24), wz(64), 'LINDSEY ST.', 17, bold=True)
text(wx(60), wz(64), 'LINDSEY ST.', 17, bold=True)
text(wx(42), wz(36), 'BACHMAN RD.', 17, rot=90, bold=True)
text(wx(42), wz(78), 'BACHMAN RD.', 17, rot=90, bold=True)
text(wx(78), wz(44), 'LEVIN ST.', 17, rot=90, bold=True)
text(wx(45), wz(4), 'MIDWICH ELEMENTARY SCHOOL', 20, bold=True)
text(wx(45), wz(8.5), '米德维奇小学', 18)
text(wx(60), wz(33), '公园', 22, bold=True)
text(wx(60), wz(37), 'PARK', 14)
text(wx(32), wz(54), 'CAFÉ', 15, bold=True)
text(wx(32), wz(56.4), '5TO2', 15, bold=True)
text(wx(16), wz(56), 'POST', 13)
text(wx(16), wz(58), 'OFFICE', 13)
text(wx(52), wz(55), 'BAR', 13)
text(wx(68), wz(55), 'HARDWARE', 12)
text(wx(86), wz(30), '公寓', 14)
text(wx(85), wz(40.5), 'LEVIN ST.', 11)
text(wx(85), wz(42.5), '后院', 13)
text(wx(80), wz(12), 'TOWN HALL', 12)
text(wx(14), wz(14), 'DINER', 12)
text(wx(12), wz(29.5), 'MOTEL', 12)
text(wx(86), wz(62), 'HOTEL', 11)
text(wx(48), wz(97), '← 往 镇 外', 13)
text(wx(42), wz(46), '道路崩塌', 13, fill=(110, 30, 25))
text(wx(89), wz(22), '断崖', 12, fill=(110, 30, 25))
# title & compass
text(IW / 2, 34, 'SILENT HILL  ·  中心区街道图', 26, bold=True)
cx, cy = IW - M - 10, M + 70
d.polygon([(cx, cy - 34), (cx - 10, cy), (cx + 10, cy)], fill=ink + (255,))
d.polygon([(cx, cy + 34), (cx - 10, cy), (cx + 10, cy)], outline=ink + (255,))
text(cx, cy - 50, 'N', 18, bold=True)
# border
d.rectangle((M - 8, M + 32, IW - M + 8, IH - M + 8), outline=ink + (255,), width=3)
d.rectangle((M - 14, M + 26, IW - M + 14, IH - M + 14), outline=ink + (160,), width=1)
# folds and stains
fold = Image.new('L', (IW, IH), 0)
fd = ImageDraw.Draw(fold)
for i in (1, 2):
    fd.line((IW * i / 3, 0, IW * i / 3, IH), fill=60, width=3)
fd.line((0, IH / 2, IW, IH / 2), fill=60, width=3)
fold = fold.filter(ImageFilter.GaussianBlur(4))
img = ImageChops.subtract(img, Image.merge('RGB', (fold, fold, fold)))
stain = Image.new('L', (IW, IH), 0)
sd = ImageDraw.Draw(stain)
for _ in range(7):
    x, y, r = random.uniform(0, IW), random.uniform(0, IH), random.uniform(30, 110)
    sd.ellipse((x - r, y - r, x + r, y + r), outline=40, width=random.randint(2, 6))
stain = stain.filter(ImageFilter.GaussianBlur(3))
img = ImageChops.subtract(img, Image.merge('RGB', (stain, stain.point(lambda v: v * 1.3), stain.point(lambda v: v * 1.8))))
# vignette edge darkening
vig = Image.new('L', (IW, IH), 0)
vd = ImageDraw.Draw(vig)
vd.rectangle((20, 20, IW - 20, IH - 20), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(40))
dark = Image.new('RGB', (IW, IH), (120, 96, 70))
img = Image.composite(img, ImageChops.multiply(img, dark.point(lambda v: v * 2)), vig)
img.save('/data/sh_demo/assets/ui/map.png')
print(img.size, 'scale px/m =', S / 2, 'origin', M + S / 2, M + 40 + S / 2)
