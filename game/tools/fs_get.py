import re, sys, json, subprocess, html, os
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
D="/data/assets_raw/fs2"
def get(url, out=None):
    a=["curl","-sSL","-A",UA,"--max-time","90",url]
    if out: a+=["-o",out]
    return subprocess.run(a,capture_output=True).stdout.decode("utf-8","ignore")
info={}
if os.path.exists(f"{D}/credits.json"): info=json.load(open(f"{D}/credits.json"))
for sid in sys.argv[1:]:
    if sid in info and os.path.exists(f"{D}/fs_{sid}.mp3"): continue
    h=get(f"https://freesound.org/s/{sid}/")
    lic="CC0" if "publicdomain/zero" in h else ("CC-BY" if "licenses/by/" in h else "?")
    t=re.search(r'<title>Freesound - ([^<]*)</title>',h); title=html.unescape(t.group(1)) if t else "?"
    pm=re.search(r'https://cdn.freesound.org/previews/\d+/'+sid+r'_\d+-hq.mp3',h) or re.search(r'https://cdn.freesound.org/previews/\d+/'+sid+r'_\d+-lq.mp3',h)
    if not pm or lic!="CC0":
        print("skip",sid,lic,title); continue
    get(pm.group(0),f"{D}/fs_{sid}.mp3")
    dur=subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",f"{D}/fs_{sid}.mp3"],capture_output=True,text=True).stdout.strip()
    info[sid]={"title":title,"license":lic,"url":f"https://freesound.org/s/{sid}/","dur":dur}
    print(sid,lic,dur,title)
json.dump(info,open(f"{D}/credits.json","w"),ensure_ascii=False,indent=1)
