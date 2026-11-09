import re, sys, json, urllib.parse, subprocess, html
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
def get(url):
    return subprocess.run(["curl","-sSL","-A",UA,"--max-time","40",url],capture_output=True).stdout.decode("utf-8","ignore")
out={}
for q in sys.argv[1:]:
    url="https://freesound.org/search/?q="+urllib.parse.quote_plus(q)+"&f=license%3A%22Creative+Commons+0%22&s=Downloads+%28most+first%29"
    h=get(url)
    # split by sound blocks
    items=[]
    for m in re.finditer(r'href="/people/([^"/]+)/sounds/(\d+)/" title="([^"]*)"',h):
        user,sid,title=m.group(1),m.group(2),html.unescape(m.group(3))
        if any(i["id"]==sid for i in items): continue
        pm=re.search(r'https://cdn.freesound.org/previews/\d+/'+sid+r'_\d+-lq.mp3',h)
        # duration near
        seg=h[m.start():m.start()+4000]
        dm=re.search(r'(\d+:\d\d)',seg)
        items.append({"id":sid,"user":user,"title":title[:90],"lq":pm.group(0) if pm else None,"dur":dm.group(1) if dm else "?"})
    out[q]=items
    print("##",q)
    for i in items[:14]: print(f'  {i["id"]:>7} {i["dur"]:>6} {i["user"][:16]:16} {i["title"]}')
json.dump(out,open("/data/assets_raw/fs2/search.json","w"),ensure_ascii=False,indent=1)
