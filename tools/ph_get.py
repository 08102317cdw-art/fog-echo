#!/usr/bin/env python3
"""下载 Poly Haven（CC0）模型的 1k glTF 及贴图。用法: ph_get.py id1 id2 ..."""
import json, os, sys, subprocess, urllib.request
D = "/data/assets_raw/ph_models"
def get(url, out):
    subprocess.run(["curl", "-sSL", "--max-time", "120", "-o", out, url], check=True)
info = json.load(open(f"{D}/credits.json")) if os.path.exists(f"{D}/credits.json") else {}
for mid in sys.argv[1:]:
    od = f"{D}/{mid}"
    if os.path.exists(f"{od}/{mid}_1k.gltf"):
        continue
    os.makedirs(od, exist_ok=True)
    fj = f"{od}/files.json"
    get(f"https://api.polyhaven.com/files/{mid}", fj)
    d = json.load(open(fj))
    g = d["gltf"]["1k"]["gltf"]
    for rel, v in g.get("include", {}).items():
        os.makedirs(os.path.dirname(f"{od}/{rel}") or od, exist_ok=True)
        get(v["url"], f"{od}/{rel}")
    get(g["url"], f"{od}/{mid}_1k.gltf")
    aj = f"{od}/info.json"
    get(f"https://api.polyhaven.com/info/{mid}", aj)
    a = json.load(open(aj))
    info[mid] = {"name": a.get("name"), "authors": list(a.get("authors", {}).keys()), "url": f"https://polyhaven.com/a/{mid}", "license": "CC0"}
    print(mid, "ok", sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(od) for f in fs) // 1024, "KB", flush=True)
json.dump(info, open(f"{D}/credits.json", "w"), ensure_ascii=False, indent=1)
