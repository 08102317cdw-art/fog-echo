import glob, os
TEX3D = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{src}"

[params]

compress/mode={mode}
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={nm}
compress/channel_pack=0
mipmaps/generate={mip}
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""
root='/data/sh_demo'
ui = {'drawing.png','paper.png','map.png','title_bg.png'}
n=0
for f in glob.glob(root+'/assets/tex/*.png') + glob.glob(root+'/assets/ui/*.png'):
    b=os.path.basename(f)
    rel='res://'+os.path.relpath(f, root)
    if b in ui or '/assets/ui/' in f:
        txt=TEX3D.format(src=rel, mode=0, nm=2, mip='true')
    else:
        txt=TEX3D.format(src=rel, mode=2, nm=1 if b.endswith('_n.png') else 2, mip='true')
    imp=f+'.import'
    if os.path.exists(imp):
        # keep if params identical
        old=open(imp).read()
        if 'compress/mode=' in old and old.split('[params]')[1].strip()==txt.split('[params]')[1].strip():
            continue
    open(imp,'w').write(txt); n+=1
print('wrote', n)
