import glob, subprocess, os
chars=set()
for f in glob.glob('/data/sh_demo/scripts/*.gd'):
    for ch in open(f,encoding='utf-8').read():
        if ord(ch) > 127: chars.add(ch)
extra = "，。、！？：；“”‘’（）《》【】—…·「」『』～％＋－×÷①②③④⑤▶◀▲▼■□●○◆◇★☆→←↑↓ÉéÀàÈèÇçÖöÜüÄä©"
chars |= set(extra)
asc = ''.join(chr(i) for i in range(32,127))
text = asc + ''.join(sorted(chars))
open('/tmp/font_chars.txt','w',encoding='utf-8').write(text)
os.makedirs('/data/sh_demo/assets/fonts', exist_ok=True)
jobs = [
 ('/usr/share/fonts/google-noto-cjk/NotoSerifCJK-Regular.ttc', 2, '/data/sh_demo/assets/fonts/serif.otf'),
 ('/usr/share/fonts/google-noto-cjk/NotoSerifCJK-Bold.ttc', 2, '/data/sh_demo/assets/fonts/serif_bold.otf'),
 ('/data/assets_raw/LXGWWenKai-Regular.ttf', None, '/data/sh_demo/assets/fonts/hand.ttf'),
]
for src, idx, out in jobs:
    cmd = ['pyftsubset', src, '--text-file=/tmp/font_chars.txt', '--output-file='+out, '--layout-features=*', '--no-hinting']
    if idx is not None: cmd.append('--font-number=%d' % idx)
    subprocess.run(cmd, check=True)
    print(out, os.path.getsize(out))
print(len(chars), 'non-ascii chars')
