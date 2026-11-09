import json, urllib.request, os, concurrent.futures as cf
OUT="/data/assets_raw/ph"; os.makedirs(OUT, exist_ok=True)
ASSETS=["asphalt_02","concrete_pavement","dirty_concrete","red_brick_03","painted_worn_brick","worn_plaster_wall","weathered_plank_siding","painted_metal_shutter","rough_pine_door","decrepit_wallpaper","old_linoleum_flooring_01","worn_tile_floor","park_dirt","dry_decay_leaves","cliff_side","wood_planks_grey","rusty_metal_04","rust_coarse_01","rusty_corrugated_iron","rebar_reinforced_concrete","metal_grate_rusty","damaged_plaster","rusty_metal_sheet"]
def get(u):
    req=urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0"}); return urllib.request.urlopen(req,timeout=60).read()
def one(a):
    files=json.loads(get(f"https://api.polyhaven.com/files/{a}"))
    got=[]
    for key,short in [("Diffuse","diff"),("nor_gl","nor"),("Rough","rough")]:
        if key not in files: continue
        res="1k" if "1k" in files[key] else sorted(files[key].keys())[0]
        u=files[key][res]["jpg"]["url"]; open(f"{OUT}/{a}_{short}.jpg","wb").write(get(u)); got.append(short)
    return a, got, [k for k in files.keys() if k not in ("blend","gltf","mtlx")]
with cf.ThreadPoolExecutor(8) as ex:
    for a,got,keys in ex.map(one, ASSETS): print(a, got, "| maps:", ",".join(keys))
