extends RefCounted
## 室内关卡：校工之家（雾世界 → 警报后里世界）/ 米德维奇小学（里世界）/ 锅炉房（Boss）
## 所有坐标为关卡局部坐标 (x, z)，P() 转换为世界坐标。

const SH_GLOW = preload("res://shaders/window_glow.gdshader")
const DW := 0.92
const DH := 2.08
const T := 0.14
const HOUSE_O := Vector3(600, 0, 0)
const SCHOOL_O := Vector3(1200, 0, 0)
const BOILER_O := Vector3(1300, 0, 100)

var w: Node3D
var O := Vector3.ZERO
var H := 2.7
var lv: Dictionary = {}
var cur := ""
var info := {}
var doors := {}
var pickups: Array = []
var spawns := {}
var entries := {}
var searches := {}
var clock := {}
var code_labels: Array = []
var glow_mats: Array = []
var hand_font: Font
var rs := RandomNumberGenerator.new()
var trim_mat := "wood_dk"
var jamb_mat := "h_plaster"
var boiler_fire: OmniLight3D
var merchant_spots := {}

func _init(world: Node3D) -> void:
	w = world
	rs.seed = 1989
	hand_font = load("res://assets/fonts/hand.ttf")

func P(x: float, z: float, y := 0.0) -> Vector3:
	return O + Vector3(x, y, z)

func _w2(p: Vector2) -> Vector2:
	return Vector2(O.x + p.x, O.z + p.y)

func build() -> void:
	_mats()
	build_house()
	build_school()
	build_boiler()

# ---------------------------------------------------------------- 材质
func _mats() -> void:
	_rug_tex()
	w.mk("h_wood", "planks", "rust2", 1.4, 2.0, {"tint_a": Color(0.6, 0.47, 0.36), "blood": 0.55, "grime": 0.35})
	w.mk("h_tile", "tile", "rsheet", 0.9, 2.0, {"tint_a": Color(0.86, 0.85, 0.8), "blood": 0.75, "grime": 0.3})
	w.mk("h_wall", "wallpaper", "dplaster", 2.0, 2.5, {"blood": 0.65, "grime": 0.35})
	w.mk("h_wall2", "wallpaper", "dplaster", 2.0, 2.5, {"tint_a": Color(0.78, 0.86, 0.8), "blood": 0.65, "grime": 0.35})
	w.mk("h_kwall", "tile", "rsheet", 0.75, 2.0, {"tint_a": Color(0.93, 0.9, 0.8), "blood": 0.6, "grime": 0.3})
	w.mk("h_bwall", "tile", "rust1", 0.5, 1.5, {"tint_a": Color(0.72, 0.84, 0.86), "blood": 0.8, "grime": 0.3})
	w.mk("h_plaster", "plaster", "dplaster", 2.5, 2.5, {"tint_a": Color(0.86, 0.83, 0.76), "blood": 0.55, "grime": 0.35})
	w.mk("h_ceil", "plaster", "dplaster", 3.0, 3.0, {"tint_a": Color(0.8, 0.78, 0.72), "blood": 0.3})
	w.mk("h_rug", "rug", "flesh_r", 2.3, 2.0, {"blood": 0.5, "grime": 0.25, "tint_b": Color(0.5, 0.3, 0.26)})
	w.mk("wood_dk", "planks", "rust1", 1.0, 1.0, {"tint_a": Color(0.3, 0.22, 0.16), "box_map": true, "grime": 0.2})
	w.mk("enamel", "tile", "rust1", 2.0, 1.0, {"tint_a": Color(0.95, 0.95, 0.92), "box_map": true, "blood": 0.6, "rough_a": 0.35})
	w.mk("s_floor", "lino", "grate", 2.0, 1.6, {"tint_a": Color(0.78, 0.8, 0.76), "blood": 0.7, "metal_b": 0.45, "tint_b": Color(0.62, 0.46, 0.4)})
	w.mk("s_cfloor", "planks", "rsheet", 1.6, 2.0, {"tint_a": Color(0.66, 0.55, 0.42), "blood": 0.7, "metal_b": 0.3})
	w.mk("s_lo", "tile", "rust1", 1.0, 1.4, {"tint_a": Color(0.6, 0.72, 0.66), "blood": 0.8, "grime": 0.45})
	w.mk("s_hi", "plaster", "dplaster", 2.5, 2.5, {"tint_a": Color(0.84, 0.82, 0.74), "blood": 0.7, "grime": 0.4})
	w.mk("s_ceil", "plaster", "rust2", 3.0, 3.0, {"tint_a": Color(0.7, 0.68, 0.62), "blood": 0.3})
	w.mk("s_wc", "tile", "rust1", 0.6, 1.2, {"tint_a": Color(0.85, 0.88, 0.86), "blood": 0.85, "grime": 0.4})
	w.mk("s_wp", "wallpaper", "dplaster", 2.2, 2.5, {"tint_a": Color(0.7, 0.62, 0.5), "blood": 0.7, "grime": 0.35})
	w.mk("locker", "rsheet", "rust1", 1.2, 1.0, {"tint_a": Color(0.42, 0.5, 0.46), "box_map": true, "metal_b": 0.4, "blood": 0.5})
	w.mk("bo_floor", "concrete", "grate", 3.0, 1.6, {"tint_a": Color(0.55, 0.52, 0.48), "metal_b": 0.45, "blood": 0.6, "tint_b": Color(0.5, 0.36, 0.3)})
	w.mk("bo_wall", "brick", "rust1", 2.5, 2.0, {"tint_a": Color(0.5, 0.42, 0.38), "blood": 0.7, "tint_b": Color(0.5, 0.32, 0.26)})
	w.mk("bo_ceil", "concrete", "rust2", 3.0, 3.0, {"tint_a": Color(0.35, 0.33, 0.3), "tint_b": Color(0.3, 0.16, 0.12)})
	w.mk("bo_rust", "rust1", "rust2", 1.5, 1.5, {"box_map": true, "metal_b": 0.5, "tint_b": Color(0.55, 0.32, 0.24)})
	w.mk("cork", "dirt", "rust2", 0.8, 1.0, {"tint_a": Color(0.85, 0.6, 0.38), "box_map": true, "blood": 0.4})
	var gm := ShaderMaterial.new()
	gm.shader = SH_GLOW
	gm.set_shader_parameter("noise_tex", w.tex("grime"))
	w.mats["win_glow"] = gm
	w.mat_list.append(gm)
	var gm2: ShaderMaterial = gm.duplicate()
	gm2.set_shader_parameter("bars", 0.0)
	gm2.set_shader_parameter("strength", 0.8)
	w.mats["win_glow2"] = gm2
	w.mat_list.append(gm2)
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(0.9, 0.85, 0.7)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.82, 0.55)
	bulb.emission_energy_multiplier = 2.0
	w.mats["bulb"] = bulb
	var bb := StandardMaterial3D.new()
	bb.albedo_color = Color(0.03, 0.05, 0.04)
	bb.roughness = 0.85
	w.mats["board"] = bb
	var mir := StandardMaterial3D.new()
	mir.albedo_color = Color(0.5, 0.52, 0.52)
	mir.metallic = 1.0
	mir.roughness = 0.08
	w.mats["mirror"] = mir
	var wt := StandardMaterial3D.new()
	wt.albedo_color = Color(0.12, 0.02, 0.015)
	wt.roughness = 0.05
	wt.metallic = 0.2
	w.mats["bloodwater"] = wt

## 程序生成地毯贴图（暗红底 + 菱形花纹 + 边框）
func _rug_tex() -> void:
	var img := Image.create(128, 128, true, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var fx := float(x) / 128.0
			var fy := float(y) / 128.0
			var c := Color(0.32, 0.07, 0.06)
			var d: float = abs(fposmod(fx * 4.0, 1.0) - 0.5) + abs(fposmod(fy * 4.0, 1.0) - 0.5)
			if d < 0.18:
				c = Color(0.62, 0.45, 0.22)
			elif d < 0.26:
				c = Color(0.1, 0.06, 0.08)
			var n := sin(x * 1.7) * cos(y * 2.3) * 0.03
			c = c.lightened(n) if n > 0 else c.darkened(-n)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	w.tex_cache["rug_a"] = ImageTexture.create_from_image(img)
	w.tex_cache["rug_n"] = w.tex("planks_n")
	w.tex_cache["flesh_r_a"] = w.tex("rust2_a")
	w.tex_cache["flesh_r_n"] = w.tex("rust2_n")

# ---------------------------------------------------------------- 关卡框架
func _begin(id: String, origin: Vector3, size: Vector2, h: float, surf_def: String) -> void:
	O = origin
	H = h
	cur = id
	lv = w.begin_level(id, origin, size)
	lv["surf"] = []
	lv["surf_def"] = surf_def
	lv["h"] = h
	info[id] = {"root": lv.root, "lights": [], "fx": [], "size": size}

func _end() -> void:
	w.end_level()
	lv = {}

func root() -> Node3D:
	return lv.root

## 地板（同时登记脚步声材质）
func fl(mat: String, x0: float, z0: float, x1: float, z1: float, surf := "") -> void:
	w.hquad(mat, O.x + x0, O.z + z0, O.x + x1, O.z + z1, O.y, true)
	if surf != "":
		(lv.surf as Array).push_front([Rect2(O.x + x0, O.z + z0, x1 - x0, z1 - z0), surf])

func ceil_q(mat: String, x0: float, z0: float, x1: float, z1: float, y := -1.0) -> void:
	var yy := H if y < 0.0 else y
	w.hquad(mat, O.x + x0, O.z + z0, O.x + x1, O.z + z1, O.y + yy, false)

## 门洞 / 拱口 / 窗洞（中心坐标为沿墙轴的绝对局部坐标）
func D(c: float, wd := DW) -> Array:
	return [c, wd + 0.06, 0.0, DH + 0.03]

func AR(c: float, wd: float, hh: float) -> Array:
	return [c, wd, 0.0, hh]

func WN(c: float, ww: float, y0: float, hh: float) -> Array:
	return [c, ww, y0, y0 + hh]

## 墙段 (x0,z0)→(x1,z1)，必须轴对齐且坐标递增。
## 沿 x 的墙：A 面朝 +z，B 面朝 −z；沿 z 的墙：A 面朝 −x，B 面朝 +x。
## 材质 "" 表示该面不生成，"lo|hi" 表示 1.15m 处上下分段 + 腰线。
func ws(x0: float, z0: float, x1: float, z1: float, ma: String, mb: String, ops := []) -> void:
	var a := Vector2(x0, z0)
	var b := Vector2(x1, z1)
	var ln := a.distance_to(b)
	var u := (b - a) / ln
	var n := Vector2(-u.y, u.x)
	var along_x: bool = abs(u.x) > 0.5
	var cuts: Array = []
	for o in ops:
		var oc: float = o[0]
		var s := (oc - x0) if along_x else (oc - z0)
		cuts.append([s, o[1], o[2], o[3]])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var segs: Array = []
	var cs := -T * 0.5
	for o in cuts:
		var c: float = o[0]
		var hw: float = float(o[1]) * 0.5
		var oy0: float = o[2]
		var oy1: float = o[3]
		if c - hw > cs:
			segs.append([cs, c - hw, 0.0, H])
		if oy0 > 0.0:
			segs.append([c - hw, c + hw, 0.0, oy0])
		if oy1 < H:
			segs.append([c - hw, c + hw, oy1, H])
		_reveal(a, u, n, c - hw, c + hw, oy0, oy1)
		cs = c + hw
	var e := ln + T * 0.5
	if e > cs:
		segs.append([cs, e, 0.0, H])
	for sg in segs:
		_wface(a, u, n, sg, ma, 1.0)
		_wface(a, u, n, sg, mb, -1.0)
		if float(sg[2]) < 0.01 and float(sg[3]) > 1.0:
			var cc: Vector2 = a + u * (float(sg[0]) + float(sg[1])) * 0.5
			var L: float = float(sg[1]) - float(sg[0])
			w.nav_block(P(cc.x, cc.y), Vector2(L, T) if along_x else Vector2(T, L))

func _wface(a: Vector2, u: Vector2, n: Vector2, sg: Array, mat: String, side: float) -> void:
	if mat == "":
		return
	var off := n * (T * 0.5) * side
	var p0 := a + u * float(sg[0]) + off
	var p1 := a + u * float(sg[1]) + off
	var nn := Vector3(n.x, 0, n.y) * side
	var y0: float = sg[2]
	var y1: float = sg[3]
	if mat.contains("|"):
		var parts := mat.split("|")
		var ym := 1.15
		if y0 < ym:
			w.wall(parts[0], _w2(p0), _w2(p1), O.y + y0, O.y + min(y1, ym), nn, true)
		if y1 > ym:
			w.wall(parts[1], _w2(p0), _w2(p1), O.y + max(y0, ym), O.y + y1, nn, true)
		if y0 < ym and y1 > ym:
			_trim(p0, p1, nn, ym, 0.07, 0.025)
	else:
		w.wall(mat, _w2(p0), _w2(p1), O.y + y0, O.y + y1, nn, true)
	if y0 < 0.01 and trim_mat != "":
		_trim(p0, p1, nn, 0.055, 0.11, 0.018)

func _trim(p0: Vector2, p1: Vector2, nn: Vector3, yc: float, hh: float, depth: float) -> void:
	var c := (p0 + p1) * 0.5
	var ln := p0.distance_to(p1)
	var yaw := 0.0 if abs(p1.x - p0.x) > abs(p1.y - p0.y) else PI / 2
	w.box(trim_mat if trim_mat != "" else "wood_dk", P(c.x, c.y, yc) + nn * depth * 0.5, Vector3(ln, hh, depth), yaw)

func _reveal(a: Vector2, u: Vector2, n: Vector2, s0: float, s1: float, y0: float, y1: float) -> void:
	var hn := n * T * 0.5
	for k in [[s0, 1.0], [s1, -1.0]]:
		var pp: Vector2 = a + u * float(k[0])
		w.wall(jamb_mat, _w2(pp - hn), _w2(pp + hn), O.y + y0, O.y + y1, Vector3(u.x, 0, u.y) * float(k[1]), true)
	var c0 := a + u * s0
	var c1 := a + u * s1
	var q0 := _w2(c0 - hn)
	var q1 := _w2(c1 + hn)
	var mn := Vector2(min(q0.x, q1.x), min(q0.y, q1.y))
	var mx := Vector2(max(q0.x, q1.x), max(q0.y, q1.y))
	if y1 < H - 0.01:
		w.hquad(jamb_mat, mn.x, mn.y, mx.x, mx.y, O.y + y1, false)
	if y0 > 0.01:
		w.hquad(jamb_mat, mn.x, mn.y, mx.x, mx.y, O.y + y0, true)

## 门框贴脸（两侧）
func casing(x: float, z: float, ax: String, wd: float, hh: float, mat := "wood_dk") -> void:
	var yaw := 0.0 if ax == "x" else PI / 2
	var along := Vector3(1, 0, 0) if ax == "x" else Vector3(0, 0, -1)
	var nrm := Vector3(0, 0, 1) if ax == "x" else Vector3(1, 0, 0)
	for sd in [1.0, -1.0]:
		var c: Vector3 = P(x, z) + nrm * (T * 0.5 + 0.012) * float(sd)
		w.box(mat, c + along * (wd * 0.5 + 0.04) + Vector3(0, hh * 0.5, 0), Vector3(0.08, hh + 0.04, 0.025), yaw)
		w.box(mat, c - along * (wd * 0.5 + 0.04) + Vector3(0, hh * 0.5, 0), Vector3(0.08, hh + 0.04, 0.025), yaw)
		w.box(mat, c + Vector3(0, hh + 0.04, 0), Vector3(wd + 0.16, 0.08, 0.025), yaw)

# ---------------------------------------------------------------- 门
func door_mesh(wd: float, hh: float, mat := "door") -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	w.override_st = st
	var t := 0.045
	for sgn in [1.0, -1.0]:
		var z: float = t * 0.5 * sgn
		var u0 := 0.0 if sgn > 0 else 1.0
		var u1 := 1.0 - u0
		w.quad(mat, Vector3(0, 0, z), Vector3(wd, 0, z), Vector3(wd, hh, z), Vector3(0, hh, z),
			Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0), Vector3(0, 0, sgn))
	for sx in [0.0, wd]:
		var nx := -1.0 if sx == 0.0 else 1.0
		w.quad(mat, Vector3(sx, 0, -t * 0.5), Vector3(sx, 0, t * 0.5), Vector3(sx, hh, t * 0.5), Vector3(sx, hh, -t * 0.5),
			Vector2(0, 1), Vector2(0.03, 1), Vector2(0.03, 0), Vector2(0, 0), Vector3(nx, 0, 0))
	w.quad(mat, Vector3(0, hh, -t * 0.5), Vector3(wd, hh, -t * 0.5), Vector3(wd, hh, t * 0.5), Vector3(0, hh, t * 0.5),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.02), Vector2(0, 0.02), Vector3(0, 1, 0))
	w.override_st = null
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, w.mats[mat])
	return m

var _handle_mat: StandardMaterial3D

func _knob(pv: Node3D, x: float) -> void:
	if _handle_mat == null:
		_handle_mat = StandardMaterial3D.new()
		_handle_mat.albedo_color = Color(0.45, 0.38, 0.25)
		_handle_mat.metallic = 0.85
		_handle_mat.roughness = 0.35
	for sd in [1.0, -1.0]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.032
		sm.height = 0.064
		sm.radial_segments = 10
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = _handle_mat
		mi.position = Vector3(x, 1.0, 0.06 * sd)
		pv.add_child(mi)

## 门。x,z：门洞中心；ax：所在墙的走向（"x" 或 "z"）
## kind：open（敞开）/ closed（可推开）/ locked（需钥匙）/ code（密码锁）/ exit（出口）/ fake（打不开）
## opts：key, len, to, msg, prompt, dir（开向：沿墙法线 ±1）, ang, w, double, mat
func door(id: String, x: float, z: float, ax: String, kind: String, opts := {}) -> Dictionary:
	var wd: float = opts.get("w", DW)
	var yaw0 := 0.0 if ax == "x" else PI / 2
	var along := Vector3(1, 0, 0) if ax == "x" else Vector3(0, 0, -1)
	var dir: float = opts.get("dir", 1.0)
	var ang: float = deg_to_rad(float(opts.get("ang", 98.0)))
	var mat: String = opts.get("mat", "door")
	var dbl: bool = opts.get("double", false)
	casing(x, z, ax, wd + 0.06, DH + 0.03)
	var c := P(x, z)
	var n_leaf := 2 if dbl else 1
	var lw := wd / n_leaf - 0.012
	var d := {"id": id, "kind": kind, "lvl": cur, "pivots": [], "rots": [], "body": null, "area": null,
		"key": opts.get("key", ""), "len": opts.get("len", 0), "to": opts.get("to", ""), "msg": opts.get("msg", ""),
		"open": kind == "open", "pos": c + Vector3(0, 1.1, 0)}
	for i in n_leaf:
		var pv := Node3D.new()
		root().add_child(pv)
		var hs := -1.0 if i == 0 else 1.0
		pv.position = c + along * (wd * 0.5 - 0.006) * hs
		var mi := MeshInstance3D.new()
		mi.mesh = door_mesh(lw, DH - 0.01, mat)
		pv.add_child(mi)
		_knob(pv, lw - 0.075)
		var base := yaw0 if i == 0 else yaw0 + PI
		var ro := base - dir * ang if i == 0 else base + dir * ang
		pv.rotation.y = base
		if kind == "open":
			pv.rotation.y = ro
		(d.pivots as Array).append(pv)
		(d.rots as Array).append(ro)
	if kind != "open":
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(wd, DH, 0.1)
		cs.shape = bx
		body.add_child(cs)
		root().add_child(body)
		body.position = c + Vector3(0, DH * 0.5, 0)
		body.rotation.y = yaw0
		d.body = body
		var tag := "door_" + id if kind in ["closed", "locked", "code"] else ""
		w.nav_block(c, Vector2(wd + 0.1, 0.3), yaw0, tag)
		var pr: String = opts.get("prompt", "进入" if kind == "exit" else ("输入密码" if kind == "code" else "开门"))
		d.area = w.add_interact("door:" + id, c + Vector3(0, 1.1, 0), Vector3(wd, 2.0, 0.7), pr, yaw0)
	doors[id] = d
	return d

func open_door(id: String, instant := false) -> void:
	if not doors.has(id):
		return
	var d: Dictionary = doors[id]
	if d.open:
		return
	d.open = true
	if is_instance_valid(d.body):
		(d.body as Node).queue_free()
	d.body = null
	if is_instance_valid(d.area):
		(d.area as Node).queue_free()
	d.area = null
	w.nav_open(d.lvl, "door_" + id)
	for i in (d.pivots as Array).size():
		var pv: Node3D = d.pivots[i]
		var r: float = d.rots[i]
		if instant:
			pv.rotation.y = r
		else:
			var tw := pv.create_tween()
			tw.tween_property(pv, "rotation:y", r, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 出口门开一条缝（转场前的动画）
func ajar(id: String) -> void:
	if not doors.has(id):
		return
	var d: Dictionary = doors[id]
	for i in (d.pivots as Array).size():
		var pv: Node3D = d.pivots[i]
		var r: float = d.rots[i]
		var base := pv.rotation.y
		var tw := pv.create_tween()
		tw.tween_property(pv, "rotation:y", lerp(base, r, 0.35), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(1.2)
		tw.tween_property(pv, "rotation:y", base, 0.3)

# ---------------------------------------------------------------- 窗
## 假窗：墙上需有对应 WN 开口。ax：墙走向；out：室外方向（沿法线 ±1）
func window(x: float, z: float, ax: String, out: float, y0: float, ww: float, hh: float, boards := 0, mat := "win_glow") -> void:
	var yaw := 0.0 if ax == "x" else PI / 2
	var along := Vector3(1, 0, 0) if ax == "x" else Vector3(0, 0, -1)
	var nrm := (Vector3(0, 0, 1) if ax == "x" else Vector3(1, 0, 0)) * out
	var c := P(x, z, y0)
	var g0 := c + nrm * (T * 0.5 + 0.02) - along * ww * 0.5
	var g1 := c + nrm * (T * 0.5 + 0.02) + along * ww * 0.5
	w.quad(mat, g0, g1, g1 + Vector3(0, hh, 0), g0 + Vector3(0, hh, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), -nrm)
	# 内侧窗框与窗台
	var ci := c - nrm * (T * 0.5 + 0.015)
	w.box("wood_dk", ci + Vector3(0, -0.03, 0) - nrm * 0.05, Vector3(ww + 0.22, 0.05, 0.16), yaw)
	w.box("wood_dk", ci + Vector3(0, hh + 0.035, 0), Vector3(ww + 0.16, 0.07, 0.03), yaw)
	for sd in [-1.0, 1.0]:
		w.box("wood_dk", ci + along * (ww * 0.5 + 0.04) * sd + Vector3(0, hh * 0.5, 0), Vector3(0.07, hh, 0.03), yaw)
	# 钉死的木板
	for i in boards:
		var tilt := rs.randf_range(-0.3, 0.3)
		var bs := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), tilt)
		w.boxb("boards", ci - nrm * 0.03 + Vector3(0, hh * (0.18 + 0.64 * float(i) / max(boards - 1, 1)), 0), Vector3(ww + 0.3, 0.17, 0.03), bs)

# ---------------------------------------------------------------- 灯光
func light(x: float, z: float, y: float, col: Color, e: float, rng: float, col_ow: Color, e_ow: float, flick := 0.0, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = P(x, z, y)
	l.light_color = col
	l.light_energy = e
	l.omni_range = rng
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadow
	l.shadow_bias = 0.06
	l.light_specular = 0.35
	root().add_child(l)
	(info[cur].lights as Array).append({"l": l, "c": col, "e": e, "co": col_ow, "eo": e_ow, "f": flick, "k": rs.randf() * 100.0})
	return l

func spot(x: float, z: float, y: float, dirv: Vector3, col: Color, e: float, rng: float, angle: float, col_ow: Color, e_ow: float, flick := 0.0, shadow := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = P(x, z, y)
	l.light_color = col
	l.light_energy = e
	l.spot_range = rng
	l.spot_angle = angle
	l.spot_attenuation = 1.2
	l.shadow_enabled = shadow
	l.light_specular = 0.3
	root().add_child(l)
	l.look_at(l.position + dirv, Vector3.UP if abs(dirv.normalized().y) < 0.95 else Vector3.FORWARD)
	(info[cur].lights as Array).append({"l": l, "c": col, "e": e, "co": col_ow, "eo": e_ow, "f": flick, "k": rs.randf() * 100.0})
	return l

## 吸顶灯泡（灯罩 + 发光泡）
func bulb(x: float, z: float, cord := 0.25) -> void:
	var yb := H - cord
	w.cyl("metal", P(x, z, H), P(x, z, yb), 0.008, 0.008, 4)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.12
	mi.mesh = sm
	mi.material_override = w.mats["bulb"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = P(x, z, yb - 0.05)
	root().add_child(mi)
	w.cyl("metal", P(x, z, yb + 0.02), P(x, z, yb - 0.06), 0.03, 0.16, 10)

func hang_lamp(x: float, z: float) -> void:
	w.ph("hanging_industrial_lamp", P(x, z, H - 1.36), 0.0, {"collide": false, "shadow": false, "grime": 0.5})

# ---------------------------------------------------------------- 交互 / 搜刮 / 拾取 / 刷怪
## 搜刮点：node 为可动画的模型，part 为子网格名后缀，mode：slide（抽屉拉出）/ lift（盖子掀开）
func search(id: String, pos: Vector3, size: Vector3, yaw_deg: float, node: Node3D = null, part := "", mode := "slide", prompt := "搜索") -> void:
	var a: Area3D = w.add_interact("search:" + id, pos, size, prompt, deg_to_rad(yaw_deg))
	searches[id] = {"node": node, "part": part, "mode": mode, "lvl": cur, "pos": pos, "area": a}

func act(iid: String, pos: Vector3, size: Vector3, prompt: String, yaw_deg := 0.0) -> Area3D:
	return w.add_interact(iid, pos, size, prompt, deg_to_rad(yaw_deg))

func pick(id: String, item: String, x: float, z: float, y: float, prompt := "拾取") -> void:
	pickups.append([id, item, P(x, z, y), prompt])

func spawn(id: String, kind: String, x: float, z: float, yaw_deg: float, cond := "", extra := {}) -> void:
	var s := {"kind": kind, "pos": P(x, z), "yaw": yaw_deg, "lvl": cur, "cond": cond}
	s.merge(extra)
	spawns[id] = s

func entry(nm: String, x: float, z: float, yaw_deg: float) -> void:
	entries[nm] = [P(x, z), deg_to_rad(yaw_deg)]

func sub(n: Node, nm: String) -> Node3D:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).ends_with(nm):
			return mi as Node3D
	return null

func anim_search(id: String) -> void:
	if not searches.has(id):
		return
	var s: Dictionary = searches[id]
	var n: Node3D = s.node
	if n == null or not is_instance_valid(n):
		return
	var part: String = s.part
	var tg: Node3D = sub(n, part) if part != "" else null
	if tg == null:
		return
	var par := tg.get_parent() as Node3D
	var inv := par.global_transform.basis.inverse()
	var tw := tg.create_tween()
	if s.mode == "lift":
		var dl: Vector3 = inv * (Vector3(0, 0.1, 0) + n.global_transform.basis.x.normalized() * 0.12)
		tw.tween_property(tg, "position", tg.position + dl, 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(tg, "rotation:z", tg.rotation.z + 0.35, 0.5)
	else:
		var dl2: Vector3 = inv * (n.global_transform.basis.z.normalized() * 0.24)
		tw.tween_property(tg, "position", tg.position + dl2, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 抽屉直接设为已拉开（读档恢复）
func set_searched(id: String) -> void:
	if not searches.has(id):
		return
	var s: Dictionary = searches[id]
	var n: Node3D = s.node
	if n == null or not is_instance_valid(n) or s.part == "":
		return
	var tg: Node3D = sub(n, s.part)
	if tg == null or tg.has_meta("opened"):
		return
	tg.set_meta("opened", true)
	var inv := (tg.get_parent() as Node3D).global_transform.basis.inverse()
	if s.mode == "lift":
		tg.position += inv * (Vector3(0, 0.1, 0) + n.global_transform.basis.x.normalized() * 0.12)
		tg.rotation.z += 0.35
	else:
		tg.position += inv * (n.global_transform.basis.z.normalized() * 0.24)

# ---------------------------------------------------------------- 文字 / 黑板 / 血迹 / 门牌
func scrawl(text: String, pos: Vector3, yaw: float, size: int, col: Color, px := 0.004, tilt := 0.0, shaded := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = hand_font
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.shaded = shaded
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.position = pos
	l.rotation = Vector3(0, yaw, tilt)
	root().add_child(l)
	return l

func _mesh_box(mat: Material, c: Vector3, s: Vector3, yaw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = c
	mi.rotation.y = yaw
	root().add_child(mi)
	return mi

## 黑板：c 为中心（局部 x,z,y），yaw 为朝向（正面朝 (sin yaw, 0, cos yaw)）
func blackboard(x: float, z: float, y: float, yaw: float, wd: float, hh: float) -> Vector3:
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var c := P(x, z, y) + f * (T * 0.5 + 0.02)
	_mesh_box(w.mats["board"], c, Vector3(wd, hh, 0.03), yaw)
	var bs := Basis(Vector3.UP, yaw)
	w.box("wood_dk", c + Vector3(0, hh * 0.5 + 0.03, 0), Vector3(wd + 0.12, 0.06, 0.05), yaw)
	w.box("wood_dk", c - Vector3(0, hh * 0.5 + 0.03, 0) + f * 0.04, Vector3(wd + 0.12, 0.05, 0.12), yaw)
	for sd in [-1.0, 1.0]:
		w.box("wood_dk", c + bs * Vector3(sd * (wd * 0.5 + 0.03), 0, 0), Vector3(0.06, hh + 0.12, 0.05), yaw)
	return c + f * 0.02

var _splat_tex: ImageTexture
var _splat_mats := {}

func _splat() -> ImageTexture:
	if _splat_tex:
		return _splat_tex
	var img := Image.create(128, 128, true, Image.FORMAT_RGBA8)
	var r2 := RandomNumberGenerator.new()
	r2.seed = 77
	var blobs: Array = []
	for i in 9:
		blobs.append([Vector2(r2.randf_range(0.3, 0.7), r2.randf_range(0.3, 0.7)), r2.randf_range(0.08, 0.2)])
	for i in 14:
		var a := r2.randf() * TAU
		var dd := r2.randf_range(0.25, 0.42)
		blobs.append([Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * dd, r2.randf_range(0.015, 0.04)])
	for y in 128:
		for x in 128:
			var p := Vector2(x, y) / 128.0
			var v := 0.0
			for b in blobs:
				var bc: Vector2 = b[0]
				var br: float = b[1]
				v = max(v, 1.0 - p.distance_to(bc) / br)
			var al: float = clamp(v * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.22 + v * 0.1, 0.012, 0.01, al * 0.92))
	img.generate_mipmaps()
	_splat_tex = ImageTexture.create_from_image(img)
	return _splat_tex

## 血迹贴片（平面）：pos 世界坐标，nrm 朝向
func decal(pos: Vector3, size: float, nrm := Vector3.UP, rot := 0.0, alpha := 1.0) -> void:
	var k := "%.2f" % alpha
	if not _splat_mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _splat()
		m.albedo_color = Color(1, 1, 1, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.25
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_splat_mats[k] = m
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = _splat_mats[k]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	var up := nrm.normalized()
	var ref := Vector3.FORWARD if abs(up.y) > 0.9 else Vector3.UP
	var xa := ref.cross(up).normalized()
	var za := xa.cross(up).normalized()
	mi.transform = Transform3D(Basis(xa, up, za) * Basis(Vector3.UP, rot), pos + up * 0.006)

func plate(text: String, pos: Vector3, yaw: float, wd := 0.5) -> void:
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.82, 0.8, 0.72)
	sm.roughness = 0.7
	_mesh_box(sm, pos, Vector3(wd, 0.16, 0.02), yaw)
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/serif_bold.otf")
	l.font_size = 30
	l.pixel_size = 0.0035
	l.modulate = Color(0.12, 0.1, 0.09)
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos + f * 0.012
	l.rotation.y = yaw
	root().add_child(l)

func paper_note(pos: Vector3, yaw: float, tilt := 0.0, sz := Vector2(0.21, 0.28)) -> void:
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = w.tex("paper")
	sm.roughness = 0.9
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = sz
	mi.mesh = qm
	mi.material_override = sm
	mi.position = pos
	mi.rotation = Vector3(0, yaw, tilt)
	root().add_child(mi)

## 散落在地上的纸张
func papers(x: float, z: float, n: int, rad := 0.6) -> void:
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = w.tex("paper")
	sm.roughness = 0.95
	for i in n:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.21, 0.29)
		mi.mesh = pm
		mi.material_override = sm
		mi.position = P(x + rs.randf_range(-rad, rad), z + rs.randf_range(-rad, rad), 0.004 + i * 0.001)
		mi.rotation.y = rs.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root().add_child(mi)

# ---------------------------------------------------------------- 模型辅助
func km(nm: String, x: float, z: float, yaw: float, scale := 2.0, y := 0.0, collide := true) -> Node3D:
	if not w.model_cache.has(nm):
		w.model_cache[nm] = load("res://assets/models/%s.glb" % nm)
	var n: Node3D = w.model(nm, P(x, z, y), yaw, 0.0, "h", collide, root())
	n.scale = Vector3.ONE * scale
	var bb: Vector3 = n.get_meta("size")
	var c: Vector3 = w._aabb_of(n).get_center()
	# 重新按缩放后的尺寸定位（model() 以 scale=1 计算）
	var bs := Basis(Vector3.UP, deg_to_rad(yaw))
	var ab: AABB = w._aabb_of(n)
	n.transform = Transform3D(bs.scaled(Vector3.ONE * scale), P(x, z, y) - bs * (Vector3(ab.get_center().x, ab.position.y, ab.get_center().z) * scale))
	var sz := bb * scale
	if collide:
		# model() 生成的碰撞体按 scale=1，替换之
		var par := root()
		var last := par.get_child(par.get_child_count() - 1)
		if last is StaticBody3D:
			last.queue_free()
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = sz
		cs.shape = bx
		body.add_child(cs)
		par.add_child(body)
		body.transform = Transform3D(bs, P(x, z, y) + Vector3(0, sz.y * 0.5, 0))
		w.nav_block(P(x, z), Vector2(sz.x, sz.z), deg_to_rad(yaw))
	n.set_meta("size", sz)
	return n

func ph(nm: String, x: float, z: float, yaw: float, opts := {}, y := 0.0) -> Node3D:
	return w.ph(nm, P(x, z, y), yaw, opts)

## 程序生成的落地灯
func floor_lamp(x: float, z: float) -> void:
	w.cyl("metal", P(x, z, 0.0), P(x, z, 0.04), 0.16, 0.16, 12)
	w.cyl("metal", P(x, z, 0.04), P(x, z, 1.45), 0.015, 0.015, 6)
	w.cyl("h_plaster", P(x, z, 1.32), P(x, z, 1.62), 0.24, 0.14, 14)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	mi.mesh = sm
	mi.material_override = w.mats["bulb"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = P(x, z, 1.42)
	root().add_child(mi)
	w.nav_block(P(x, z), Vector2(0.35, 0.35))

func desk_lamp(x: float, z: float, y: float, yaw := 0.0) -> void:
	w.cyl("metal", P(x, z, y), P(x, z, y + 0.025), 0.08, 0.08, 10)
	var top := P(x, z, y + 0.38) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.12)
	w.cyl("metal", P(x, z, y + 0.02), top, 0.01, 0.01, 5)
	w.cyl("metal", top, top + Vector3(0, -0.12, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.06), 0.03, 0.09, 10)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	mi.mesh = sm
	mi.material_override = w.mats["bulb"]
	mi.position = top + Vector3(0, -0.08, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)

## 相框（墙上或桌上）：贴图 tex（paper/drawing）
func frame_pic(pos: Vector3, yaw: float, sz: Vector2, texname: String, stand := false) -> void:
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var bs := Basis(Vector3.UP, yaw)
	if stand:
		bs = bs * Basis(Vector3.RIGHT, -0.22)
	w.boxb("wood_dk", pos, Vector3(sz.x + 0.05, sz.y + 0.05, 0.02), bs)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = w.tex(texname)
	sm.roughness = 0.6
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = sz
	mi.mesh = qm
	mi.material_override = sm
	mi.transform = Transform3D(bs, pos + bs * Vector3(0, 0, 0.012))
	root().add_child(mi)

# ---------------------------------------------------------------- 校工之家
func build_house() -> void:
	_begin("house", HOUSE_O, Vector2(14, 10), 2.7, "wood")
	trim_mat = "wood_dk"
	jamb_mat = "h_plaster"
	fl("h_wood", 0, 0, 5, 4, "wood")
	fl("h_tile", 5, 0, 8, 4, "concrete")
	fl("h_wood", 8, 0, 14, 4, "wood")
	fl("h_wood", 0, 4, 14, 5.5, "wood")
	fl("h_tile", 0, 5.5, 5, 10, "concrete")
	fl("h_wood", 5, 5.5, 14, 10, "wood")
	ceil_q("h_ceil", 0, 0, 14, 10)
	# 地毯
	w.hquad("h_rug", O.x + 10.6, O.z + 6.9, O.x + 13.1, O.z + 9.5, O.y + 0.008)
	(lv.surf as Array).push_front([Rect2(O.x + 10.6, O.z + 6.9, 2.5, 2.6), "carpet"])
	w.hquad("h_rug", O.x + 0.9, O.z + 4.38, O.x + 12.8, O.z + 5.12, O.y + 0.008)
	(lv.surf as Array).push_front([Rect2(O.x + 0.9, O.z + 4.38, 11.9, 0.74), "carpet"])
	# 外墙
	ws(0, 0, 5, 0, "h_wall", "")
	ws(5, 0, 8, 0, "h_bwall", "", [WN(6.6, 0.6, 1.55, 0.55)])
	ws(8, 0, 14, 0, "h_wall2", "", [WN(11.0, 1.1, 1.25, 1.05)])
	ws(0, 10, 5, 10, "", "h_kwall", [WN(2.23, 0.95, 1.2, 0.85)])
	ws(5, 10, 14, 10, "", "h_wall", [WN(8.2, 1.1, 0.9, 1.3), D(12.8)])
	ws(0, 0, 0, 4, "", "h_wall", [WN(2.8, 1.0, 0.9, 1.25)])
	ws(0, 4, 0, 5.5, "", "h_plaster")
	ws(0, 5.5, 0, 10, "", "h_kwall", [D(7.8)])
	ws(14, 0, 14, 4, "h_wall2", "")
	ws(14, 4, 14, 5.5, "h_plaster", "")
	ws(14, 5.5, 14, 10, "h_wall", "", [WN(6.4, 1.0, 0.9, 1.3)])
	# 走廊北墙（A 面朝走廊）
	ws(0, 4, 5, 4, "h_plaster", "h_wall", [D(2.6)])
	ws(5, 4, 8, 4, "h_plaster", "h_bwall", [D(6.5)])
	ws(8, 4, 14, 4, "h_plaster", "h_wall2", [D(11.0)])
	# 走廊南墙（A 面朝厨房/客厅）
	ws(0, 5.5, 5, 5.5, "h_kwall", "h_plaster", [AR(2.6, 1.0, 2.12)])
	ws(5, 5.5, 14, 5.5, "h_wall", "h_plaster", [AR(9.6, 1.6, 2.25)])
	# 隔墙
	ws(5, 0, 5, 4, "h_wall", "h_bwall")
	ws(8, 0, 8, 4, "h_bwall", "h_wall2")
	ws(5, 5.5, 5, 10, "h_kwall", "h_wall", [AR(7.75, 1.4, 2.2)])
	casing(2.6, 5.5, "x", 1.0, 2.12)
	casing(9.6, 5.5, "x", 1.6, 2.25)
	casing(5.0, 7.75, "z", 1.4, 2.2)
	# 门
	door("h_bed", 2.6, 4.0, "x", "open", {"dir": -1.0, "ang": 80.0})
	door("h_bath", 6.5, 4.0, "x", "closed", {"dir": -1.0})
	door("h_study", 11.0, 4.0, "x", "locked", {"dir": -1.0, "key": "study_key", "msg": "书房的门锁着。"})
	door("h_back", 0.0, 7.8, "z", "exit", {"to": "town_house", "prompt": "离开"})
	door("h_front", 12.8, 10.0, "x", "fake", {"msg": "前门被人从外面用木板钉死了。"})
	# 窗
	window(6.6, 0.0, "x", -1.0, 1.55, 0.6, 0.55, 0, "win_glow2")
	window(11.0, 0.0, "x", -1.0, 1.25, 1.1, 1.05, 2)
	window(2.23, 10.0, "x", 1.0, 1.2, 0.95, 0.85)
	window(8.2, 10.0, "x", 1.0, 0.9, 1.1, 1.3, 3)
	window(0.0, 2.8, "z", -1.0, 0.9, 1.0, 1.25)
	window(14.0, 6.4, "z", 1.0, 0.9, 1.0, 1.3, 2)
	_house_bedroom()
	_house_bath()
	_house_study()
	_house_kitchen()
	_house_living()
	_house_hall()
	entry("house_back", 0.8, 7.8, -90.0)
	spawn("h_crawl", "crawler", 6.2, 2.4, 160.0, "alarm")
	spawn("h_mon", "mon", 11.5, 8.2, -120.0, "alarm")
	_end()

func _house_bedroom() -> void:
	ph("GothicBed_01", 1.2, 1.1, 0.0, {"grime": 0.5})
	var ns := ph("ClassicNightstand_01", 2.42, 0.3, 0.0, {"grime": 0.4})
	search("h_night", P(2.42, 0.3, 0.45), Vector3(0.7, 0.8, 0.7), 0.0, ns, "", "slide", "搜索床头柜")
	pick("diary", "diary", 2.36, 0.3, 0.705, "阅读")
	desk_lamp(2.6, 0.22, 0.7, 0.0)
	var wd := ph("painted_wooden_cabinet", 4.6, 2.0, -90.0, {"grime": 0.5})
	search("h_ward", P(4.4, 2.0, 0.6), Vector3(0.6, 1.2, 1.2), -90.0, wd, "drawer_01")
	ph("SchoolChair_01", 3.8, 3.3, 200.0, {"grime": 0.3})
	frame_pic(P(4.92, 3.3, 1.6), -PI / 2, Vector2(0.4, 0.3), "drawing")
	papers(3.2, 2.6, 3, 0.5)
	light(1.2, 2.8, 1.9, Color(0.72, 0.78, 0.86), 0.55, 5.0, Color(0.55, 0.06, 0.03), 0.35, 0.0)
	light(2.6, 0.45, 1.05, Color(1.0, 0.75, 0.45), 0.5, 2.8, Color(0.8, 0.1, 0.04), 0.4, 0.15)

func _house_bath() -> void:
	# 浴缸（内有暗红色的水）
	w.box("enamel", P(6.0, 0.815, 0.28), Vector3(1.75, 0.56, 0.07), 0.0, true)
	w.box("enamel", P(6.0, 0.105, 0.28), Vector3(1.75, 0.56, 0.07), 0.0, true)
	w.box("enamel", P(5.16, 0.46, 0.28), Vector3(0.07, 0.56, 0.68), 0.0, true)
	w.box("enamel", P(6.84, 0.46, 0.28), Vector3(0.07, 0.56, 0.68), 0.0, true)
	w.box("enamel", P(6.0, 0.46, 0.06), Vector3(1.62, 0.12, 0.68))
	w.hquad("bloodwater", O.x + 5.19, O.z + 0.14, O.x + 6.81, O.z + 0.78, O.y + 0.43)
	w.nav_block(P(6.0, 0.46), Vector2(1.75, 0.8))
	# 洗手池 + 镜子
	w.cyl("enamel", P(7.7, 2.0, 0.0), P(7.7, 2.0, 0.75), 0.1, 0.07, 10)
	w.box("enamel", P(7.68, 2.0, 0.8), Vector3(0.48, 0.12, 0.56))
	w.box("metal", P(7.86, 2.0, 0.92), Vector3(0.05, 0.14, 0.04))
	w.nav_block(P(7.68, 2.0), Vector2(0.5, 0.56))
	_mesh_box(w.mats["mirror"], P(7.925, 2.0, 1.55), Vector3(0.015, 0.62, 0.5), 0.0)
	w.box("wood_dk", P(7.92, 2.0, 1.55), Vector3(0.02, 0.68, 0.56))
	scrawl("别看", P(7.91, 2.08, 1.62), -PI / 2, 64, Color(0.35, 0.02, 0.01), 0.003, 0.15)
	# 马桶
	w.cyl("enamel", P(5.42, 3.05, 0.0), P(5.42, 3.05, 0.4), 0.15, 0.2, 10)
	w.box("enamel", P(5.42, 3.05, 0.42), Vector3(0.38, 0.05, 0.44))
	w.box("enamel", P(5.18, 3.05, 0.65), Vector3(0.18, 0.42, 0.44))
	w.nav_block(P(5.35, 3.05), Vector2(0.55, 0.45))
	# 药箱
	var st := km("sideTable", 7.6, 3.35, -90.0, 2.0)
	var mb := ph("medical_box", 7.6, 3.35, -90.0, {"collide": false, "grime": 0.4}, 0.77)
	search("h_med", P(7.6, 3.35, 0.9), Vector3(0.6, 0.4, 0.6), -90.0, mb, "lid", "lift")
	decal(P(6.2, 1.6), 1.2, Vector3.UP, 0.4, 0.8)
	light(6.5, 2.0, 2.45, Color(0.85, 0.9, 0.95), 0.6, 4.2, Color(0.6, 0.05, 0.03), 0.5, 0.2)
	bulb(6.5, 2.0, 0.12)

func _house_study() -> void:
	var dr := ph("vintage_wooden_drawer_01", 11.0, 0.58, 0.0, {"grime": 0.4})
	searches["h_lock"] = {"node": dr, "part": "drawer02", "mode": "slide", "lvl": cur, "pos": P(11, 0.9, 1.1)}
	act("h_lock", P(11.0, 1.15, 0.8), Vector3(1.2, 0.5, 0.5), "调查抽屉")
	desk_lamp(10.35, 0.35, 1.09, 0.4)
	frame_pic(P(11.6, 0.35, 1.2), 0.0, Vector2(0.18, 0.14), "paper", true)
	ph("painted_wooden_chair_01", 11.0, 1.75, 165.0, {"grime": 0.4})
	ph("wooden_bookshelf_worn", 8.37, 2.0, 90.0, {"grime": 0.5})
	var cab := ph("drawer_cabinet", 13.68, 1.2, -90.0, {"grime": 0.45})
	search("h_cab", P(13.4, 1.2, 0.9), Vector3(0.6, 1.0, 1.1), -90.0, cab, "drawer_02")
	ph("cardboard_box_01", 13.5, 3.4, 20.0, {"grime": 0.5})
	papers(10.5, 2.6, 5, 0.9)
	light(10.4, 0.9, 1.45, Color(1.0, 0.76, 0.46), 0.9, 4.6, Color(0.85, 0.12, 0.04), 0.7, 0.25, true)

func _house_kitchen() -> void:
	km("kitchenFridge", 0.5, 9.64, 180.0)
	km("kitchenStove", 1.37, 9.48, 180.0)
	km("kitchenSink", 2.23, 9.48, 180.0)
	var kc := km("kitchenCabinet", 3.09, 9.48, 180.0)
	km("kitchenCabinet", 3.95, 9.48, 180.0)
	km("kitchenCabinetUpper", 1.37, 9.71, 180.0, 2.0, 1.5, false)
	km("kitchenCabinetUpper", 3.09, 9.71, 180.0, 2.0, 1.5, false)
	km("kitchenCabinetUpper", 3.95, 9.71, 180.0, 2.0, 1.5, false)
	km("kitchenMicrowave", 3.95, 9.55, 180.0, 1.8, 0.9, false)
	search("h_kit", P(3.09, 9.1, 0.5), Vector3(0.8, 0.9, 0.5), 0.0, kc, "", "slide", "搜索橱柜")
	search("h_fridge", P(0.5, 9.2, 1.0), Vector3(0.8, 1.6, 0.5), 0.0, null, "", "slide", "打开冰箱")
	km("table", 2.4, 7.25, 0.0, 2.3)
	km("chair", 1.8, 6.45, 0.0, 2.0, 0.0, false)
	km("chair", 3.1, 8.05, 200.0, 2.0, 0.0, false)
	km("trashcan", 4.6, 6.0, 30.0, 2.0)
	# 狗碗
	w.cyl("metal", P(0.5, 6.4, 0.0), P(0.5, 6.4, 0.07), 0.13, 0.15, 12)
	pick("note_howard", "note_howard", 2.1, 7.1, 0.765, "阅读")
	light(2.4, 7.4, 2.45, Color(0.95, 0.92, 0.82), 0.85, 6.0, Color(0.65, 0.08, 0.04), 0.5, 0.35)
	bulb(2.4, 7.4, 0.15)

func _house_living() -> void:
	ph("Sofa_01", 10.3, 8.2, 90.0, {"grime": 0.45})
	var tvt := ph("WoodenTable_01", 13.6, 8.2, -90.0, {"grime": 0.4})
	ph("Television_01", 13.6, 8.2, -90.0, {"collide": false, "grime": 0.4}, 0.55)
	ph("ArmChair_01", 12.4, 6.35, 200.0, {"grime": 0.45})
	ph("Rockingchair_01", 6.0, 9.2, 135.0, {"grime": 0.45})
	var cab := ph("painted_wooden_cabinet", 7.0, 5.86, 0.0, {"grime": 0.45})
	search("h_lcab", P(7.0, 6.2, 0.6), Vector3(1.2, 1.0, 0.5), 0.0, cab, "drawer_02")
	frame_pic(P(6.85, 5.75, 1.33), 0.0, Vector2(0.2, 0.26), "paper", true)
	act("h_photo", P(6.85, 5.9, 1.3), Vector3(0.5, 0.4, 0.4), "查看照片")
	var wc := ph("wall_clock", 12.0, 5.57, 0.0, {"collide": false, "grime": 0.3}, 1.85)
	_set_wall_clock(wc, 3, 30)
	floor_lamp(10.3, 6.95)
	frame_pic(P(5.08, 9.0, 1.6), PI / 2, Vector2(0.5, 0.4), "drawing")
	papers(11.8, 8.4, 2, 0.6)
	light(10.3, 6.95, 1.5, Color(1.0, 0.7, 0.42), 1.25, 7.5, Color(0.85, 0.16, 0.07), 0.95, 0.3, true)
	light(7.0, 8.0, 2.4, Color(0.85, 0.82, 0.78), 0.25, 5.0, Color(0.4, 0.04, 0.02), 0.25, 0.0)

func _house_hall() -> void:
	km("coatRackStanding", 0.45, 4.75, 0.0, 2.3, 0.0, true)
	km("sideTable", 13.6, 4.75, -90.0, 2.0)
	frame_pic(P(4.0, 4.07, 1.55), 0.0, Vector2(0.42, 0.32), "drawing")
	frame_pic(P(8.6, 5.43, 1.55), PI, Vector2(0.42, 0.32), "drawing")
	scrawl("爸爸\n快点来", P(13.0, 5.42, 1.2), PI, 48, Color(0.5, 0.06, 0.03), 0.003, -0.1)
	light(5.0, 4.75, 2.45, Color(1.0, 0.86, 0.62), 0.5, 5.0, Color(0.75, 0.1, 0.04), 0.45, 0.5)
	light(11.5, 4.75, 2.45, Color(1.0, 0.86, 0.62), 0.35, 4.5, Color(0.75, 0.1, 0.04), 0.35, 0.6)
	bulb(5.0, 4.75, 0.15)
	bulb(11.5, 4.75, 0.15)

## 挂钟指针（停在 h:m）
func _set_wall_clock(n: Node3D, h: int, m: int) -> void:
	_set_hands(n, "hours_hand", "minute_hand", Vector3(0, 0, 0.028), h, m)
	var sec := sub(n, "second_hand")
	if sec:
		sec.visible = false

## 绕表盘中心旋转指针：center 为模型局部表盘中心
func _set_hands(n: Node3D, hn: String, mn: String, center: Vector3, h: int, m: int) -> void:
	for pair in [[hn, (float(h % 12) + m / 60.0) / 12.0], [mn, m / 60.0]]:
		var hand := sub(n, pair[0])
		if hand == null:
			continue
		var pv: Node3D
		if hand.get_parent().has_meta("pivot"):
			pv = hand.get_parent()
		else:
			var par := hand.get_parent() as Node3D
			pv = Node3D.new()
			pv.set_meta("pivot", true)
			pv.position = center
			par.add_child(pv)
			var xf := hand.transform
			par.remove_child(hand)
			pv.add_child(hand)
			hand.transform = Transform3D(Basis(), -center) * xf
			# 原始朝向（自 12 点顺时针）
			var bb: AABB = xf * (hand as MeshInstance3D).get_aabb()
			var d := bb.get_center() - center
			pv.set_meta("a0", atan2(d.x, d.y))
		var a0: float = pv.get_meta("a0")
		var target: float = float(pair[1]) * TAU
		pv.rotation.z = -(target - a0)

# ---------------------------------------------------------------- 米德维奇小学（里世界）
const LOW := "s_lo|s_hi"

func build_school() -> void:
	_begin("school", SCHOOL_O, Vector2(42, 17), 3.2, "metal")
	trim_mat = "wood_dk"
	jamb_mat = "s_hi"
	# 地板
	fl("s_floor", 0, 7, 42, 10, "metal")
	fl("s_cfloor", 0, 0, 8, 7, "wood")
	fl("s_cfloor", 8, 0, 16, 7, "wood")
	fl("s_cfloor", 16, 0, 24, 7, "wood")
	fl("s_floor", 24, 0, 30, 7, "metal")
	fl("s_cfloor", 30, 0, 36, 7, "wood")
	fl("s_floor", 36, 0, 42, 7, "metal")
	fl("s_cfloor", 0, 10, 8, 17, "wood")
	fl("s_cfloor", 8, 10, 16, 17, "wood")
	fl("s_floor", 16, 10, 24, 17, "metal")
	fl("s_wc", 24, 10, 30, 17, "concrete")
	fl("s_cfloor", 30, 10, 36, 17, "wood")
	fl("s_floor", 36, 10, 42, 17, "metal")
	ceil_q("s_ceil", 0, 0, 42, 17)
	# 外墙
	ws(0, 0, 8, 0, LOW, "", [WN(2.5, 1.4, 1.0, 1.5), WN(5.5, 1.4, 1.0, 1.5)])
	ws(16, 0, 24, 0, LOW, "", [WN(18.5, 1.4, 1.0, 1.5), WN(21.5, 1.4, 1.0, 1.5)])
	ws(24, 0, 30, 0, LOW, "", [WN(27.0, 1.4, 1.0, 1.5)])
	ws(30, 0, 36, 0, "s_wp", "", [WN(33.0, 1.4, 1.0, 1.5)])
	ws(0, 17, 8, 17, "", LOW, [WN(2.5, 1.4, 1.0, 1.5), WN(5.5, 1.4, 1.0, 1.5)])
	ws(8, 17, 16, 17, "", LOW, [WN(10.5, 1.4, 1.0, 1.5), WN(13.5, 1.4, 1.0, 1.5)])
	ws(16, 17, 24, 17, "", LOW, [D(20.0, 1.9)])
	ws(24, 17, 30, 17, "", "s_wc", [WN(27.0, 0.8, 1.75, 0.5)])
	ws(36, 17, 42, 17, "", LOW)
	ws(0, 0, 0, 7, "", LOW)
	ws(0, 7, 0, 10, "", LOW, [WN(8.5, 1.0, 1.2, 1.4)])
	ws(0, 10, 0, 17, "", LOW)
	ws(42, 7, 42, 10, LOW, "", [D(8.5)])
	ws(42, 10, 42, 17, LOW, "")
	# 走廊北墙（A 面朝走廊）
	ws(0, 7, 8, 7, LOW, LOW, [D(4.0)])
	ws(8, 7, 16, 7, LOW, "", [D(12.0)])
	ws(16, 7, 24, 7, LOW, LOW, [D(20.0)])
	ws(24, 7, 30, 7, LOW, LOW, [D(27.0)])
	ws(30, 7, 36, 7, LOW, "s_wp", [D(33.0)])
	ws(36, 7, 42, 7, LOW, "", [D(39.0)])
	# 走廊南墙（B 面朝走廊）
	ws(0, 10, 8, 10, LOW, LOW, [D(4.0)])
	ws(8, 10, 16, 10, LOW, LOW, [D(12.0)])
	ws(16, 10, 24, 10, LOW, LOW, [AR(20.0, 5.0, 2.9)])
	ws(24, 10, 30, 10, "s_wc", LOW, [D(27.0)])
	ws(30, 10, 36, 10, "", LOW, [D(33.0)])
	ws(36, 10, 42, 10, LOW, LOW, [D(39.0)])
	# 隔墙
	ws(8, 0, 8, 7, LOW, "")
	ws(16, 0, 16, 7, "", LOW)
	ws(24, 0, 24, 7, LOW, LOW)
	ws(30, 0, 30, 7, LOW, "s_wp")
	ws(36, 0, 36, 7, "s_wp", "")
	ws(8, 10, 8, 17, LOW, LOW)
	ws(16, 10, 16, 17, LOW, LOW)
	ws(24, 10, 24, 17, LOW, "s_wc")
	ws(30, 10, 30, 17, "s_wc", "")
	ws(36, 10, 36, 17, "", LOW)
	casing(20.0, 10.0, "x", 5.0, 2.9)
	# 门
	door("d_1a", 4.0, 7.0, "x", "open", {"dir": -1.0, "ang": 72.0})
	door("d_1b", 12.0, 7.0, "x", "fake")
	door("d_music", 20.0, 7.0, "x", "locked", {"dir": -1.0, "key": "music_key", "msg": "音乐教室的门锁着。"})
	door("d_inf", 27.0, 7.0, "x", "open", {"dir": -1.0, "ang": 88.0})
	door("d_prin", 33.0, 7.0, "x", "code", {"dir": -1.0, "len": 4, "msg": "校长室的门上装着四位数字的密码锁。"})
	door("d_equip", 39.0, 7.0, "x", "fake", {"msg": "门被里面堆着的东西死死顶住了。"})
	door("d_lounge", 4.0, 10.0, "x", "closed", {"dir": 1.0})
	door("d_2a", 12.0, 10.0, "x", "open", {"dir": 1.0, "ang": 64.0})
	door("d_wc", 27.0, 10.0, "x", "open", {"dir": 1.0, "ang": 85.0})
	door("d_2b", 33.0, 10.0, "x", "fake")
	door("d_store", 39.0, 10.0, "x", "closed", {"dir": 1.0})
	door("d_main", 20.0, 17.0, "x", "exit", {"double": true, "w": 1.9, "to": "town_school", "prompt": "离开学校"})
	door("d_boiler", 42.0, 8.5, "z", "exit", {"to": "boiler_in", "key": "basement_key", "prompt": "进入锅炉房", "msg": "通往地下锅炉房的铁门上挂着一把大锁。", "mat": "shutter"})
	# 窗（里世界：暗红色的光，大多被钉死）
	for wx in [2.5, 5.5, 18.5, 21.5, 27.0, 33.0]:
		window(wx, 0.0, "x", -1.0, 1.0, 1.4, 1.5, rs.randi_range(0, 3))
	for wx in [2.5, 5.5, 10.5, 13.5]:
		window(wx, 17.0, "x", 1.0, 1.0, 1.4, 1.5, rs.randi_range(0, 3))
	window(27.0, 17.0, "x", 1.0, 1.75, 0.8, 0.5, 0, "win_glow2")
	window(0.0, 8.5, "z", -1.0, 1.2, 1.0, 1.4, 2)
	_school_corridor()
	_school_1a()
	_school_music()
	_school_infirmary()
	_school_principal()
	_school_lounge()
	_school_2a()
	_school_foyer()
	_school_toilet()
	_school_storage()
	entry("school_foyer", 20.0, 15.9, 0.0)
	entry("school_base", 41.0, 8.5, 90.0)
	_end()

func _lockers(x0: float, x1: float, z: float, face: float) -> void:
	var x := x0
	var i := 0
	while x + 0.42 <= x1 + 0.001:
		var c := P(x + 0.21, z + face * (T * 0.5 + 0.23), 0.92)
		w.box("locker", c, Vector3(0.4, 1.84, 0.44), 0.0, true)
		# 通风缝
		for k in 3:
			w.box("wood_dk", c + Vector3(0, 0.62 + k * 0.05, face * 0.222), Vector3(0.26, 0.015, 0.006))
		if rs.randf() < 0.18:
			var bs := Basis(Vector3.UP, face * rs.randf_range(0.6, 1.5))
			w.boxb("locker", c + Vector3(-0.2, 0, face * 0.22) + bs * Vector3(0.19, 0, 0), Vector3(0.38, 1.78, 0.02), bs)
		x += 0.42
		i += 1
	w.nav_block(P((x0 + x) * 0.5, z + face * (T * 0.5 + 0.23)), Vector2(x - x0, 0.46))

func _school_corridor() -> void:
	_lockers(4.7, 11.3, 7.0, 1.0)
	_lockers(12.7, 19.3, 7.0, 1.0)
	_lockers(4.7, 11.3, 10.0, -1.0)
	_lockers(27.7, 32.3, 10.0, -1.0)
	_lockers(33.7, 38.3, 10.0, -1.0)
	for lx in [3.5, 10.5, 17.5, 24.5, 31.5, 38.5]:
		hang_lamp(lx, 8.5)
		light(lx, 8.5, 1.75, Color(0.8, 0.14, 0.06), 0.9, 7.5, Color(0.8, 0.14, 0.06), 0.9, 0.55)
	ph("wheelchair_01", 14.2, 9.25, 200.0, {"grime": 0.7, "blood": 0.5})
	plate("1-A", P(4.0, 7.08, 2.42), 0.0)
	plate("1-B", P(12.0, 7.08, 2.42), 0.0)
	plate("音乐教室", P(20.0, 7.08, 2.42), 0.0, 0.7)
	plate("医务室", P(27.0, 7.08, 2.42), 0.0, 0.6)
	plate("校长室", P(33.0, 7.08, 2.42), 0.0, 0.6)
	plate("器材室", P(39.0, 7.08, 2.42), 0.0, 0.6)
	plate("教师休息室", P(4.0, 9.92, 2.42), PI, 0.8)
	plate("2-A", P(12.0, 9.92, 2.42), PI)
	plate("厕所", P(27.0, 9.92, 2.42), PI)
	plate("2-B", P(33.0, 9.92, 2.42), PI)
	plate("储藏室", P(39.0, 9.92, 2.42), PI, 0.6)
	plate("锅炉房", P(41.92, 8.5, 2.42), -PI / 2, 0.6)
	scrawl("她在下面", P(41.92, 9.6, 1.5), -PI / 2, 90, Color(0.42, 0.03, 0.02), 0.004, 0.12)
	scrawl("数字藏在教室里\n① ② ③ ④", P(34.2, 7.08, 1.45), 0.0, 52, Color(0.85, 0.85, 0.8), 0.003, -0.05)
	paper_note(P(33.62, 7.09, 1.35), 0.0, 0.08)
	for i in 9:
		decal(P(6.0 + i * 3.9 + rs.randf_range(-1, 1), 8.5 + rs.randf_range(-0.9, 0.9)), rs.randf_range(0.5, 1.3), Vector3.UP, rs.randf() * TAU, 0.85)
	decal(P(41.0, 7.07, 1.4), 1.0, Vector3(0, 0, 1), 0.0, 0.7)
	spawn("s_cor_a", "mon", 10.0, 8.5, 90.0)
	spawn("s_cor_b", "mon", 36.5, 8.5, -90.0, "basement_key", {"hunt": true})

## 一排课桌椅：朝向 yaw（学生面对的方向）
func _desks(cx: Array, cz: Array, yaw: float) -> void:
	var f := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	for x in cx:
		for z in cz:
			if rs.randf() < 0.12:
				continue
			var jy := yaw + rs.randf_range(-8, 8)
			if rs.randf() < 0.15:
				var d := ph("SchoolDesk_01", x, z, jy + rs.randf_range(-40, 40), {"collide": false, "grime": 0.6, "blood": 0.3})
				d.rotation.z = PI / 2
				d.position += Vector3(0, 0.3, 0)
				w.nav_block(P(x, z), Vector2(0.9, 0.9))
			else:
				ph("SchoolDesk_01", x, z, jy, {"grime": 0.6, "blood": 0.3})
			var cp: Vector3 = Vector3(x, 0, z) - f * 0.55
			if rs.randf() < 0.2:
				var ch := ph("SchoolChair_01", cp.x + rs.randf_range(-0.3, 0.3), cp.z - f.z * 0.3, rs.randf() * 360.0, {"collide": false, "grime": 0.6})
				ch.rotation.x = PI / 2 * (1.0 if rs.randf() < 0.5 else -1.0)
				ch.position.y += 0.25
			else:
				ph("SchoolChair_01", cp.x, cp.z, jy + 180.0 + rs.randf_range(-15, 15), {"grime": 0.6, "collide": false})

func _code_label(idx: int, lb: Label3D, prefix: String) -> void:
	code_labels.append([lb, idx, prefix])

func set_code(c: String) -> void:
	for e in code_labels:
		var lb: Label3D = e[0]
		var i: int = e[1]
		lb.text = String(e[2]) + c.substr(i, 1)

func _school_1a() -> void:
	var bc := blackboard(0.0, 3.6, 1.65, PI / 2, 3.4, 1.2)
	scrawl("值日生：艾米丽", bc + Vector3(0, 0.35, 1.05), PI / 2, 40, Color(0.85, 0.85, 0.8), 0.003)
	_code_label(0, scrawl("① 0", bc + Vector3(0.005, -0.05, -0.6), PI / 2, 150, Color(0.92, 0.9, 0.85), 0.004, 0.06), "① ")
	scrawl("○ △ □", bc + Vector3(0.005, 0.3, -0.9), PI / 2, 60, Color(0.85, 0.85, 0.8), 0.003)
	var dk := ph("metal_office_desk", 1.55, 3.5, 90.0, {"grime": 0.6, "blood": 0.2})
	search("s_1a_desk", P(2.1, 3.5, 0.6), Vector3(0.5, 0.6, 1.8), 90.0, dk, "drawer_01")
	_desks([3.8, 5.3, 6.8], [1.4, 2.8, 4.2, 5.6], -90.0)
	papers(5.0, 3.0, 6, 2.0)
	light(4.0, 3.5, 2.8, Color(0.7, 0.13, 0.06), 0.55, 7.0, Color(0.7, 0.13, 0.06), 0.55, 0.4)
	spawn("s_1a_c", "crawler", 5.6, 3.4, 60.0)

func _school_music() -> void:
	# 钢琴（程序几何）
	var pc := Vector3(16.5, 0, 3.4)
	w.box("wood_dk", P(pc.x, pc.z, 0.65), Vector3(0.6, 1.3, 1.5), 0.0, true)
	w.box("wood_dk", P(pc.x + 0.42, pc.z, 0.72), Vector3(0.3, 0.06, 1.42))
	w.box("enamel", P(pc.x + 0.45, pc.z, 0.77), Vector3(0.18, 0.025, 1.36))
	for k in 20:
		if k % 7 in [2, 6]:
			continue
		w.box("wood_dk", P(pc.x + 0.4, pc.z - 0.64 + k * 0.066, 0.795), Vector3(0.1, 0.02, 0.03))
	w.nav_block(P(pc.x + 0.1, pc.z), Vector2(0.9, 1.5))
	var bench := Vector3(17.35, 0, 3.4)
	w.box("wood_dk", P(bench.x, bench.z, 0.45), Vector3(0.38, 0.06, 0.9), 0.0, true)
	for sx in [-0.15, 0.15]:
		for sz in [-0.4, 0.4]:
			w.box("wood_dk", P(bench.x + sx, bench.z + sz, 0.21), Vector3(0.04, 0.42, 0.04))
	w.nav_block(P(bench.x, bench.z), Vector2(0.4, 0.9))
	search("s_music_bench", P(bench.x, bench.z, 0.55), Vector3(0.5, 0.4, 1.0), 0.0, null, "", "slide", "搜索琴凳")
	var bc := blackboard(24.0, 3.5, 1.65, -PI / 2, 3.2, 1.2)
	for i in 5:
		w.box("enamel", bc + Vector3(0.004, 0.3 - i * 0.09, 0), Vector3(0.004, 0.012, 2.8), 0.0)
	scrawl("♪　♫　♪", bc + Vector3(0.006, 0.12, 0.5), -PI / 2, 70, Color(0.88, 0.88, 0.82), 0.003)
	_code_label(1, scrawl("② 0", bc + Vector3(0.006, -0.35, -0.7), -PI / 2, 150, Color(0.92, 0.9, 0.85), 0.004, -0.05), "② ")
	for row in 3:
		for i in 4:
			var x := 19.0 + row * 1.3
			var z := 1.4 + i * 1.3 + row * 0.2
			ph("SchoolChair_01", x, z, -90.0 + rs.randf_range(-20, 20), {"grime": 0.6, "collide": false})
	light(20.0, 3.5, 2.8, Color(0.6, 0.1, 0.05), 0.45, 7.0, Color(0.6, 0.1, 0.05), 0.45, 0.3)
	spawn("s_music_d", "mon", 21.5, 4.5, -60.0, "", {"dormant": true})

func _school_infirmary() -> void:
	ph("vintage_day_bed", 29.45, 1.6, -90.0, {"grime": 0.7, "blood": 0.6})
	ph("vintage_day_bed", 29.45, 4.5, -90.0, {"grime": 0.7, "blood": 0.4})
	ph("wheelchair_01", 25.6, 5.6, 35.0, {"grime": 0.6, "blood": 0.3})
	var dk := ph("SchoolDesk_01", 25.0, 1.0, 180.0, {"grime": 0.5})
	var mb := ph("medical_box", 25.0, 1.0, 10.0, {"collide": false, "grime": 0.5, "blood": 0.3}, 0.88)
	search("s_inf_med", P(25.0, 1.0, 1.0), Vector3(0.7, 0.4, 0.6), 0.0, mb, "lid", "lift")
	ph("steel_frame_shelves_01", 27.4, 0.33, 0.0, {"target": 2.0, "grime": 0.6})
	# 镜子与血字
	_mesh_box(w.mats["mirror"], P(24.09, 3.6, 1.55), Vector3(0.012, 0.7, 0.55), 0.0)
	w.box("wood_dk", P(24.08, 3.6, 1.55), Vector3(0.02, 0.76, 0.61))
	w.cyl("enamel", P(24.35, 3.6, 0.0), P(24.35, 3.6, 0.75), 0.09, 0.07, 10)
	w.box("enamel", P(24.32, 3.6, 0.8), Vector3(0.5, 0.12, 0.5))
	w.nav_block(P(24.32, 3.6), Vector2(0.5, 0.5))
	_code_label(2, scrawl("③ 0", P(24.1, 3.6, 1.6), PI / 2, 140, Color(0.45, 0.02, 0.01), 0.004, 0.1), "③ ")
	decal(P(24.08, 3.3, 1.2), 0.6, Vector3(1, 0, 0), 0.3, 0.9)
	decal(P(28.0, 3.0), 1.4, Vector3.UP, 1.0, 0.9)
	light(27.0, 3.5, 2.8, Color(0.5, 0.62, 0.55), 0.5, 6.5, Color(0.5, 0.62, 0.55), 0.5, 0.65)
	spawn("s_inf_c", "crawler", 27.6, 3.0, 200.0)

func _school_principal() -> void:
	ph("metal_office_desk", 33.0, 2.2, 0.0, {"grime": 0.5})
	ph("ArmChair_01", 33.0, 0.95, 0.0, {"grime": 0.5})
	pick("rifle", "rifle", 33.25, 2.25, 0.8)
	pick("basement_key", "basement_key", 32.3, 2.45, 0.8)
	pick("fire_report", "fire_report", 33.9, 2.1, 0.8, "阅读")
	desk_lamp(32.35, 1.95, 0.79, 0.3)
	var cab := ph("drawer_cabinet", 35.68, 4.6, -90.0, {"grime": 0.5})
	search("s_prin_cab", P(35.4, 4.6, 0.9), Vector3(0.6, 1.0, 1.1), -90.0, cab, "drawer_02")
	ph("wooden_bookshelf_worn", 30.37, 3.6, 90.0, {"grime": 0.5})
	frame_pic(P(33.0, 0.08, 2.0), 0.0, Vector2(0.6, 0.45), "paper")
	light(32.4, 2.0, 1.3, Color(0.95, 0.45, 0.2), 0.8, 5.0, Color(0.95, 0.45, 0.2), 0.8, 0.2, true)

func _school_lounge() -> void:
	ph("Sofa_01", 0.45, 13.4, 90.0, {"grime": 0.4})
	ph("WoodenTable_01", 1.75, 13.4, 90.0, {"grime": 0.4})
	km("kitchenBar", 3.3, 16.6, 180.0)
	km("kitchenBar", 4.16, 16.6, 180.0)
	km("kitchenCoffeeMachine", 3.3, 16.7, 180.0, 2.0, 0.84, false)
	ph("Television_01", 7.6, 11.0, -60.0, {"grime": 0.4})
	merchant_spots["school"] = [P(6.3, 15.2), deg_to_rad(205.0)]
	w.nav_block(P(6.3, 15.2), Vector2(1.2, 1.2))
	light(5.6, 14.6, 1.6, Color(1.0, 0.7, 0.4), 1.2, 7.5, Color(1.0, 0.66, 0.38), 1.15, 0.12, true)
	light(2.0, 12.0, 2.6, Color(0.9, 0.7, 0.5), 0.35, 6.0, Color(0.9, 0.62, 0.45), 0.35, 0.0)

func _school_2a() -> void:
	var bc := blackboard(16.0, 13.5, 1.65, -PI / 2, 3.4, 1.2)
	scrawl("我的爸爸", bc + Vector3(0.006, 0.38, 0.9), -PI / 2, 46, Color(0.88, 0.88, 0.82), 0.003)
	_code_label(3, scrawl("④ 0", bc + Vector3(0.006, -0.1, -0.6), -PI / 2, 150, Color(0.92, 0.9, 0.85), 0.004, 0.04), "④ ")
	var dk := ph("metal_office_desk", 14.5, 13.5, -90.0, {"grime": 0.6})
	search("s_2a_desk", P(13.95, 13.5, 0.6), Vector3(0.5, 0.6, 1.8), -90.0, dk, "drawer_01")
	_desks([9.4, 10.9, 12.4], [11.4, 12.8, 14.2, 15.6], 90.0)
	light(12.0, 13.5, 2.8, Color(0.7, 0.13, 0.06), 0.5, 7.0, Color(0.7, 0.13, 0.06), 0.5, 0.35)

func _school_foyer() -> void:
	var gc := ph("vintage_grandfather_clock_01", 23.7, 14.0, -90.0, {"grime": 0.5})
	clock = {"node": gc, "h": 10, "m": 50}
	_set_hands(gc, "HourHand", "MinuteHand", Vector3(0, 1.735, 0.119), 10, 50)
	act("s_clock", P(23.4, 14.0, 1.4), Vector3(0.6, 1.6, 0.8), "调查座钟", -90.0)
	# 公告栏
	w.box("cork", P(16.1, 13.4, 1.6), Vector3(0.04, 1.0, 1.8), 0.0)
	w.box("wood_dk", P(16.11, 13.4, 1.6), Vector3(0.05, 1.08, 1.88))
	paper_note(P(16.14, 13.0, 1.62), PI / 2, 0.04, Vector2(0.42, 0.58))
	for i in 4:
		paper_note(P(16.135, 13.75 + (i % 2) * 0.35, 1.35 + (i / 2) * 0.45), PI / 2, rs.randf_range(-0.2, 0.2))
	var lb := scrawl("作息时间表", P(16.15, 13.0, 1.82), PI / 2, 26, Color(0.1, 0.08, 0.07), 0.0025, 0.0, true)
	lb.font = load("res://assets/fonts/serif_bold.otf")
	act("s_board", P(16.3, 13.4, 1.6), Vector3(0.4, 1.0, 1.8), "查看公告栏", 90.0)
	ph("wooden_display_shelves_01", 16.3, 11.3, 90.0, {"grime": 0.5})
	km("bench", 18.4, 15.9, 0.0, 2.2)
	km("bench", 21.6, 15.9, 0.0, 2.2)
	hang_lamp(20.0, 13.5)
	light(20.0, 13.5, 1.75, Color(0.85, 0.2, 0.08), 1.0, 8.0, Color(0.85, 0.2, 0.08), 1.0, 0.45, true)
	scrawl("三点半", P(23.92, 12.6, 2.2), -PI / 2, 80, Color(0.42, 0.03, 0.02), 0.004, -0.08)

## 座钟指针
func set_clock(h: int, m: int) -> void:
	if clock.is_empty():
		return
	clock.h = h
	clock.m = m
	_set_hands(clock.node, "HourHand", "MinuteHand", Vector3(0, 1.735, 0.119), h, m)

func _school_toilet() -> void:
	# 隔间（沿东墙）
	for i in 5:
		var z := 11.2 + i * 1.2
		w.box("locker", P(29.3, z, 0.98), Vector3(1.3, 1.8, 0.04), 0.0, true)
	for i in 4:
		var z := 11.8 + i * 1.2
		w.cyl("enamel", P(29.6, z, 0.0), P(29.6, z, 0.4), 0.14, 0.18, 10)
		w.box("enamel", P(29.82, z, 0.6), Vector3(0.18, 0.4, 0.4))
		var bs := Basis(Vector3.UP, rs.randf_range(-1.4, 0.0) if i != 2 else 0.0)
		w.boxb("locker", P(28.65, z - 0.6, 0.98) + bs * Vector3(0, 0, 0.6), Vector3(0.035, 1.6, 1.15), bs)
	w.nav_block(P(29.3, 13.6), Vector2(1.4, 5.0))
	for i in 3:
		var z := 12.0 + i * 1.3
		w.cyl("enamel", P(24.35, z, 0.0), P(24.35, z, 0.75), 0.09, 0.07, 10)
		w.box("enamel", P(24.32, z, 0.8), Vector3(0.5, 0.12, 0.5))
		_mesh_box(w.mats["mirror"], P(24.09, z, 1.55), Vector3(0.012, 0.6, 0.48), 0.0)
	w.nav_block(P(24.32, 13.3), Vector2(0.5, 3.2))
	ph("metal_trash_can", 25.0, 16.4, 30.0, {"only": ["metal_trash_can_rust", "rust_handle"], "grime": 0.6})
	decal(P(26.8, 14.8), 1.8, Vector3.UP, 0.7, 0.95)
	decal(P(27.4, 15.6), 1.1, Vector3.UP, 2.0, 0.9)
	decal(P(26.0, 13.2), 0.7, Vector3.UP, 1.3, 0.8)
	light(27.0, 13.5, 2.8, Color(0.5, 0.6, 0.5), 0.45, 6.0, Color(0.5, 0.6, 0.5), 0.45, 0.7)
	spawn("s_wc_d1", "dog", 26.6, 14.6, 30.0, "", {"eating": true})
	spawn("s_wc_d2", "dog", 27.5, 15.4, 200.0, "", {"eating": true})

func _school_storage() -> void:
	ph("steel_frame_shelves_01", 41.7, 12.3, -90.0, {"target": 2.0, "grime": 0.6})
	ph("steel_frame_shelves_01", 41.7, 14.5, -90.0, {"target": 2.0, "grime": 0.6})
	var cr := ph("wooden_crate_01", 37.0, 16.4, 0.0, {"grime": 0.5})
	search("s_store_crate", P(37.0, 16.2, 0.4), Vector3(0.9, 0.5, 0.6), 0.0, cr, "lid", "lift")
	ph("wooden_crate_01", 38.0, 16.45, 10.0, {"grime": 0.5})
	var tb := ph("metal_toolbox", 38.0, 16.45, -15.0, {"collide": false, "grime": 0.5}, 0.35)
	search("s_store_tool", P(38.0, 16.3, 0.55), Vector3(0.5, 0.4, 0.5), 0.0, tb, "lid", "lift")
	ph("Barrel_01", 36.6, 11.0, 0.0, {"grime": 0.6})
	ph("cardboard_box_01", 40.4, 16.5, 20.0, {"grime": 0.5})
	ph("cardboard_box_01", 40.9, 16.4, -10.0, {"grime": 0.5}, 0.34)
	ph("WetFloorSign_01", 37.5, 12.4, 40.0, {"grime": 0.5})
	light(39.0, 13.5, 2.8, Color(0.6, 0.12, 0.06), 0.4, 6.0, Color(0.6, 0.12, 0.06), 0.4, 0.3)

# ---------------------------------------------------------------- 锅炉房（Boss 战）
var fire_mat: StandardMaterial3D

func _disc(mat: String, c: Vector3, r: float, nrm: Vector3, sides := 20) -> void:
	var ref := Vector3.UP if abs(nrm.y) < 0.9 else Vector3.RIGHT
	var xa := nrm.cross(ref).normalized()
	var ya := nrm.cross(xa).normalized()
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := c + (xa * cos(a0) + ya * sin(a0)) * r
		var p1 := c + (xa * cos(a1) + ya * sin(a1)) * r
		w.tri(mat, c, p0, p1, Vector2(0, 0), Vector2(cos(a0), sin(a0)) * r, Vector2(cos(a1), sin(a1)) * r, nrm)

func build_boiler() -> void:
	_begin("boiler", BOILER_O, Vector2(20, 16), 4.5, "metal")
	trim_mat = ""
	jamb_mat = "bo_wall"
	fl("bo_floor", 0, 0, 20, 16, "metal")
	ceil_q("bo_ceil", 0, 0, 20, 16)
	ws(0, 0, 20, 0, "bo_wall", "")
	ws(0, 16, 20, 16, "", "bo_wall")
	ws(0, 0, 0, 16, "", "bo_wall", [D(8.0)])
	ws(20, 0, 20, 16, "bo_wall", "")
	door("d_bo_exit", 0.0, 8.0, "z", "exit", {"to": "school_base", "prompt": "返回学校", "mat": "shutter"})
	# 锅炉本体
	var y := 2.0
	w.cyl("bo_rust", P(11.0, 8.0, y), P(17.0, 8.0, y), 1.5, 1.5, 22)
	w.cyl("bo_rust", P(11.0, 8.0, y), P(10.75, 8.0, y), 1.5, 1.15, 22)
	_disc("bo_rust", P(10.75, 8.0, y), 1.15, Vector3(-1, 0, 0), 22)
	_disc("bo_rust", P(17.0, 8.0, y), 1.5, Vector3(1, 0, 0), 22)
	for bx in [12.0, 14.0, 16.0]:
		w.cyl("bo_rust", P(bx - 0.05, 8.0, y), P(bx + 0.05, 8.0, y), 1.54, 1.54, 22)
	for lx in [11.8, 16.2]:
		w.box("bo_rust", P(lx, 8.0, 0.35), Vector3(0.35, 0.7, 2.6))
	w.cyl("bo_rust", P(15.5, 8.0, 3.3), P(15.5, 8.0, 4.5), 0.42, 0.42, 14)
	w.cyl("bo_rust", P(12.6, 8.0, 3.35), P(12.6, 8.0, 4.0), 0.16, 0.16, 8)
	w.cyl("bo_rust", P(12.6, 8.0, 4.0), P(12.6, 0.4, 4.0), 0.16, 0.16, 8)
	# 炉门（橙色火光）
	fire_mat = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(0.2, 0.05, 0.0)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.42, 0.1)
	fire_mat.emission_energy_multiplier = 3.0
	_mesh_box(fire_mat, P(10.73, 8.0, 1.55), Vector3(0.03, 0.62, 0.84), 0.0)
	w.box("bo_rust", P(10.7, 8.0, 1.9), Vector3(0.08, 0.08, 1.0))
	w.box("bo_rust", P(10.7, 8.0, 1.2), Vector3(0.08, 0.08, 1.0))
	for k in 5:
		w.box("metal", P(10.69, 7.68 + k * 0.16, 1.55), Vector3(0.05, 0.62, 0.03))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bxs := BoxShape3D.new()
	bxs.size = Vector3(6.5, 3.6, 3.1)
	cs.shape = bxs
	body.add_child(cs)
	root().add_child(body)
	body.position = P(13.9, 8.0, 1.8)
	w.nav_block(P(13.9, 8.0), Vector2(6.6, 3.2))
	boiler_fire = light(9.9, 8.0, 1.5, Color(1.0, 0.45, 0.15), 2.4, 11.0, Color(1.0, 0.45, 0.15), 2.4, 0.45, true)
	# 管道
	for pz in [0.35, 15.65]:
		w.cyl("bo_rust", P(0.3, pz, 3.8), P(19.7, pz, 3.8), 0.14, 0.14, 8)
		w.cyl("bo_rust", P(0.3, pz, 3.35), P(19.7, pz, 3.35), 0.09, 0.09, 8)
	for px in [3.0, 8.0, 19.6]:
		w.cyl("bo_rust", P(px, 0.35, 0.0), P(px, 0.35, 3.8), 0.1, 0.1, 8)
		w.cyl("bo_rust", P(px, 15.65, 0.0), P(px, 15.65, 3.8), 0.1, 0.1, 8)
	for vx in [3.0, 8.0]:
		w.cyl("bo_rust", P(vx, 0.47, 1.4), P(vx, 0.52, 1.4), 0.22, 0.22, 12)
	# 柱子
	for pp in [[5.0, 4.0], [5.0, 12.0], [10.0, 3.0], [10.0, 13.0], [17.0, 3.2], [17.0, 12.8]]:
		var px: float = pp[0]
		var pz: float = pp[1]
		w.box("bo_wall", P(px, pz, H * 0.5), Vector3(0.55, H, 0.55), 0.0, true)
		w.nav_block(P(px, pz), Vector2(0.55, 0.55))
	# 杂物与搜刮
	ph("Barrel_01", 0.8, 0.9, 0.0, {"grime": 0.7})
	ph("Barrel_01", 1.5, 1.1, 40.0, {"grime": 0.7})
	var br := ph("Barrel_01", 19.1, 15.0, 10.0, {"grime": 0.7})
	search("s_bo_barrel", P(19.1, 15.0, 0.95), Vector3(0.7, 0.5, 0.7), 0.0, br, "", "slide", "搜索铁桶")
	var c1 := ph("wooden_crate_01", 1.0, 15.3, 0.0, {"grime": 0.6})
	search("s_bo_crate", P(1.0, 15.2, 0.4), Vector3(0.9, 0.5, 0.6), 0.0, c1, "lid", "lift")
	var c2 := ph("wooden_crate_01", 18.9, 1.0, 90.0, {"grime": 0.6})
	search("s_bo_crate2", P(18.9, 1.0, 0.4), Vector3(0.6, 0.5, 0.9), 90.0, c2, "lid", "lift")
	ph("metal_trash_can", 6.5, 15.4, 0.0, {"only": ["metal_trash_can_rust", "rust_handle"], "grime": 0.7})
	light(2.0, 2.0, 3.9, Color(0.75, 0.1, 0.05), 0.8, 9.0, Color(0.75, 0.1, 0.05), 0.8, 0.3)
	light(18.0, 14.0, 3.9, Color(0.75, 0.1, 0.05), 0.8, 9.0, Color(0.75, 0.1, 0.05), 0.8, 0.35)
	light(4.0, 13.5, 3.9, Color(0.6, 0.08, 0.04), 0.5, 7.0, Color(0.6, 0.08, 0.04), 0.5, 0.5)
	scrawl("1989.11.2", P(9.0, 0.08, 2.3), 0.0, 120, Color(0.4, 0.03, 0.02), 0.005, -0.06)
	scrawl("爸爸，好热", P(14.0, 15.92, 1.6), PI, 80, Color(0.42, 0.03, 0.02), 0.004, 0.08)
	for i in 7:
		decal(P(rs.randf_range(3, 18), rs.randf_range(2, 14)), rs.randf_range(0.8, 2.0), Vector3.UP, rs.randf() * TAU, 0.9)
	_steam(P(8.0, 0.5, 3.8), Vector3(0, -0.3, 1))
	_steam(P(19.5, 11.0, 3.6), Vector3(-1, -0.2, 0))
	_embers(P(10.4, 8.0, 1.5))
	entry("boiler_in", 1.5, 8.0, -90.0)
	merchant_spots["girl"] = [P(9.4, 8.0), deg_to_rad(-90.0)]
	spawn("boss", "boss", 15.5, 12.4, 200.0, "!boss_dead")
	_end()

func _steam(pos: Vector3, dirv: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 2.6
	p.preprocess = 3.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = w.tex("fog_wisp")
	sm.albedo_color = Color(0.75, 0.7, 0.68, 0.22)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = sm
	p.mesh = qm
	p.direction = dirv.normalized()
	p.spread = 18.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.25, 0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var cv := Curve.new()
	cv.add_point(Vector2(0, 0.3))
	cv.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = cv
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.0))
	gr.add_point(0.2, Color(1, 1, 1, 0.8))
	gr.set_color(gr.get_point_count() - 1, Color(1, 1, 1, 0.0))
	p.color_ramp = gr
	p.position = pos
	root().add_child(p)

func _embers(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 2.2
	p.preprocess = 2.0
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.radial_segments = 4
	sm.rings = 2
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(1.0, 0.55, 0.15)
	sm.material = mt
	p.mesh = sm
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.2, 0.3, 0.4)
	p.direction = Vector3(-1, 1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.35, 0)
	p.position = pos
	root().add_child(p)

# ---------------------------------------------------------------- 商人（程序生成的斗篷人 + 提灯）
func make_merchant(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Merchant"
	parent.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	var bodyn := Node3D.new()
	bodyn.name = "Body"
	n.add_child(bodyn)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.2, 0.15, 0.11)
	cloth.albedo_texture = w.tex("grime")
	cloth.roughness = 1.0
	cloth.uv1_scale = Vector3(2, 2, 2)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.008, 0.006)
	dark.roughness = 1.0
	# 斗篷（旋转体，上身前倾）
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof := [[0.46, 0.0], [0.44, 0.25], [0.38, 0.6], [0.31, 0.95], [0.27, 1.15], [0.22, 1.3], [0.12, 1.4]]
	var seg := 18
	var r2 := RandomNumberGenerator.new()
	r2.seed = 5
	var wob: Array = []
	for i in seg:
		wob.append(r2.randf_range(-0.035, 0.035))
	for j in prof.size() - 1:
		for i in seg:
			var quads: Array = []
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var a := TAU * float(k[0] % seg) / seg
				var pr: Array = prof[k[1]]
				var r: float = float(pr[0]) + float(wob[k[0] % seg]) * (1.0 - float(pr[1]) / 1.4)
				var hy: float = pr[1]
				var lean := pow(hy / 1.4, 2.0) * 0.16
				quads.append(Vector3(sin(a) * r, hy, cos(a) * r + lean))
			var q0: Vector3 = quads[0]
			var q1: Vector3 = quads[1]
			var q3: Vector3 = quads[3]
			var nrm: Vector3 = (q1 - q0).cross(q3 - q0).normalized()
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = quads[idx]
				st.set_normal(-nrm)
				st.set_uv(Vector2(atan2(v.x, v.z) / TAU, v.y))
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	var cm := MeshInstance3D.new()
	cm.mesh = st.commit()
	cm.material_override = cloth
	bodyn.add_child(cm)
	# 兜帽与黑洞般的脸
	var hood := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.2
	hs.height = 0.44
	hood.mesh = hs
	hood.material_override = cloth
	hood.position = Vector3(0, 1.47, 0.2)
	hood.rotation.x = 0.35
	bodyn.add_child(hood)
	var face := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.13
	fs.height = 0.3
	face.mesh = fs
	face.material_override = dark
	face.position = Vector3(0, 1.43, 0.33)
	face.scale = Vector3(1, 1, 0.45)
	bodyn.add_child(face)
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color(1.0, 0.75, 0.35)
	eye_m.emission_enabled = true
	eye_m.emission = Color(1.0, 0.7, 0.3)
	eye_m.emission_energy_multiplier = 2.5
	for sx in [-0.04, 0.04]:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.011
		es.height = 0.022
		e.mesh = es
		e.material_override = eye_m
		e.position = Vector3(sx, 1.45, 0.385)
		bodyn.add_child(e)
	# 袖子（伸手提灯）
	for sd in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.07
		am.bottom_radius = 0.1
		am.height = 0.55
		arm.mesh = am
		arm.material_override = cloth
		var sh := Vector3(0.24 * sd, 1.18, 0.12)
		var hd := Vector3(0.17 * sd, 0.92, 0.48) if sd > 0 else Vector3(-0.12, 0.82, 0.36)
		arm.position = (sh + hd) * 0.5
		arm.look_at_from_position((sh + hd) * 0.5, hd, Vector3.UP)
		arm.rotate_object_local(Vector3.RIGHT, PI / 2)
		bodyn.add_child(arm)
	var lan: Node3D = w.ph("wooden_lantern_01", Vector3(0.17, 0.42, 0.52), 0.0, {"collide": false, "parent": bodyn, "grime": 0.2, "shadow": false})
	lan.name = "Lantern"
	var ll := OmniLight3D.new()
	ll.name = "LanternLight"
	ll.light_color = Color(1.0, 0.66, 0.34)
	ll.light_energy = 1.3
	ll.omni_range = 5.5
	ll.omni_attenuation = 1.4
	ll.position = Vector3(0.17, 0.62, 0.52)
	bodyn.add_child(ll)
	var gl := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.035
	gs.height = 0.07
	gl.mesh = gs
	gl.material_override = w.mats["bulb"]
	gl.position = Vector3(0.17, 0.6, 0.52)
	bodyn.add_child(gl)
	# 货箱
	var crate: Node3D = w.ph("wooden_crate_01", Vector3(-0.62, 0, 0.25), 70.0, {"collide": false, "parent": n, "grime": 0.4})
	w.ph("ammo_box", Vector3(-0.66, 0.35, 0.18), 80.0, {"collide": false, "parent": n, "grime": 0.2})
	w.ph("ammo_box", Vector3(-0.55, 0.35, 0.42), 60.0, {"collide": false, "parent": n, "grime": 0.2})
	w.ph("can_rusted", Vector3(-0.7, 0.35, 0.45), 0.0, {"collide": false, "parent": n, "grime": 0.2})
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.4, 1.6, 0.9)
	cs.shape = bx
	body.add_child(cs)
	body.position = Vector3(-0.2, 0.8, 0.1)
	n.add_child(body)
	n.set_meta("light", ll)
	return n
