extends Node3D
## 程序化关卡：ASCII 地图 -> 几何体 / 碰撞 / 寻路 / 道具

const L = preload("res://scripts/level_map.gd")
const CS := 2.0
const BUILD := "SIMCQAVBKNOEHRJYZ"
const GROUND := ".,_yglwkPTFG"
const MON_WALK := ".,_yglP"
const SH_S = preload("res://shaders/surface.gdshader")
const SH_C = preload("res://shaders/surface_cut.gdshader")
const SH_CAR = preload("res://shaders/car.gdshader")

const STY := {
	"S": ["pbrick", 10.5, Color(0.95, 0.93, 0.88), false],
	"I": ["brick", 12.0, Color(0.85, 0.8, 0.78), true],
	"M": ["plaster", 9.0, Color(0.82, 0.84, 0.86), false],
	"C": ["siding", 7.0, Color(0.72, 0.76, 0.78), false],
	"Q": ["brick", 8.0, Color(0.92, 0.86, 0.8), true],
	"A": ["concrete", 6.0, Color(0.8, 0.8, 0.8), true],
	"V": ["plaster", 10.0, Color(0.95, 0.9, 0.8), true],
	"B": ["pbrick", 7.0, Color(0.78, 0.84, 0.9), true],
	"K": ["plaster", 4.6, Color(0.96, 0.92, 0.82), true],
	"N": ["brick", 9.0, Color(0.7, 0.64, 0.6), true],
	"O": ["concrete", 8.0, Color(0.86, 0.84, 0.8), true],
	"E": ["siding", 7.0, Color(0.9, 0.87, 0.78), false],
	"H": ["siding", 6.0, Color(0.8, 0.74, 0.68), false],
	"R": ["pbrick", 9.0, Color(0.93, 0.88, 0.84), true],
	"J": ["brick", 11.0, Color(0.8, 0.7, 0.66), true],
	"Y": ["concrete", 8.0, Color(0.9, 0.9, 0.87), true],
	"Z": ["plaster", 7.0, Color(0.86, 0.8, 0.74), true],
}
const OWB := {"brick": "rust1", "pbrick": "dplaster", "plaster": "dplaster", "siding": "corr", "concrete": "rsheet"}

var rows: Array = []
var W := 0
var H := 0
var mats := {}
var mat_list: Array = []
var chunks := {}
var col_faces := PackedVector3Array()
var ow_faces := PackedVector3Array()
var astar := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var ow := 0.0
var override_st: SurfaceTool = null
var ow_body: StaticBody3D
var ow_lights: Array = []
var fog_lights: Array = []
var flicker: Array = []
var glass_mats: Array = []
var model_cache := {}
var prop_mat_cache := {}
var interact_root: Node3D
var sign_font: Font
var tex_cache := {}
var gate_l: Node3D
var gate_r: Node3D
var gate_body: StaticBody3D
var tree_meshes: Array = []

func _ready() -> void:
	rows = L.ROWS
	H = rows.size()
	W = (rows[0] as String).length()
	rng.seed = 1996
	sign_font = load("res://assets/fonts/serif_bold.otf")
	interact_root = Node3D.new()
	interact_root.name = "Interact"
	add_child(interact_root)
	_make_materials()
	_build_cells()
	_build_special()
	_build_trees()
	_build_props()
	_commit()
	_setup_astar()

# ---------------------------------------------------------------- 工具
func ch(c: int, r: int) -> String:
	if r < 0 or r >= H or c < 0 or c >= W:
		return "X"
	return (rows[r] as String)[c]

func is_build(t: String) -> bool:
	return t != "" and BUILD.contains(t)

func is_ground(t: String) -> bool:
	return GROUND.contains(t)

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x + 1.0) / CS)), int(floor((p.z + 1.0) / CS)))

func cpos(c: float, r: float, y := 0.0) -> Vector3:
	return Vector3(c * CS, y, r * CS)

func floor_type(c: int, r: int) -> String:
	var t := ch(c, r)
	if t == "F" or t == "G":
		var ns := [ch(c + 1, r), ch(c - 1, r), ch(c, r + 1), ch(c, r - 1)]
		if ns.has(","): return ","
		if ns.has("g") or ns.has("T"): return "g"
		if ns.has("l"): return "l"
		if ns.has("y"): return "y"
		return ","
	if t == "T": return "g"
	if t == "P": return "."
	return t

func floor_h_t(ft: String) -> float:
	if ft == ",": return 0.1
	if ft == "w" or ft == "k": return 0.12
	return 0.0

func floor_h(p: Vector3) -> float:
	var c := cell_of(p)
	var t := ch(c.x, c.y)
	if not is_ground(t): return 0.0
	return floor_h_t(floor_type(c.x, c.y))

func surface_at(p: Vector3) -> String:
	if p.x >= 400.0:
		var lv := level_at(p)
		if lv.is_empty():
			return "concrete"
		for e in lv.get("surf", []):
			if (e[0] as Rect2).has_point(Vector2(p.x, p.z)):
				var sf: String = e[1]
				if ow > 0.5 and sf == "carpet":
					return "wood"
				return sf
		return String(lv.get("surf_def", "concrete"))
	var c := cell_of(p)
	var ft := floor_type(c.x, c.y)
	if ow > 0.5:
		if ft in [".", ",", "y", "w", "k"]: return "metal"
		if ft == "_": return "concrete"
		return "grass"
	match ft:
		"g", "l": return "grass"
		"w": return "wood"
		"k": return "concrete"
	return "concrete"

func tex(k: String) -> Texture2D:
	if tex_cache.has(k):
		return tex_cache[k]
	var t: Texture2D
	if k == "clear":
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		t = ImageTexture.create_from_image(img)
	else:
		t = load("res://assets/tex/%s.png" % k)
	tex_cache[k] = t
	return t

func mk(key: String, a: String, b: String, sa: float, sb: float, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_C if opts.get("cut", false) else SH_S
	m.set_shader_parameter("tex_a", tex(a + "_a") if a != "clear" else tex("clear"))
	m.set_shader_parameter("nor_a", tex((a if a != "clear" else b) + "_n"))
	m.set_shader_parameter("tex_b", tex(b + "_a"))
	m.set_shader_parameter("nor_b", tex(b + "_n"))
	m.set_shader_parameter("blood_tex", tex("blood"))
	m.set_shader_parameter("peel_tex", tex("peel_noise"))
	m.set_shader_parameter("grime_tex", tex("grime"))
	m.set_shader_parameter("scale_a", 1.0 / sa)
	m.set_shader_parameter("scale_b", 1.0 / sb)
	for k in opts:
		if k != "cut":
			m.set_shader_parameter(k, opts[k])
	mats[key] = m
	mat_list.append(m)
	return m

func _make_materials() -> void:
	mk("road", "road", "walkway", 4.0, 2.0, {"cut": true, "opac_b_on": true, "metal_b": 0.3, "blood": 0.25, "grime": 0.3, "tint_b": Color(0.86, 0.68, 0.58)})
	mk("sidewalk", "sidewalk", "rsheet", 2.0, 2.0, {"metal_b": 0.25, "blood": 0.35, "tint_b": Color(0.8, 0.62, 0.54)})
	mk("alley", "concrete", "rust2", 3.0, 2.0, {"blood": 0.65, "grime": 0.55, "tint_a": Color(0.8, 0.8, 0.78)})
	mk("yard", "concrete", "grate", 3.0, 2.0, {"metal_b": 0.3, "blood": 0.3, "tint_a": Color(0.9, 0.9, 0.88)})
	mk("dirt", "dirt", "rust2", 3.0, 2.5, {"blood": 0.75, "grime": 0.2})
	mk("leaves", "leaves", "rust2", 2.5, 2.5, {"blood": 0.6, "grime": 0.2})
	mk("lino", "lino", "rsheet", 2.0, 2.0, {"blood": 0.6, "grime": 0.25})
	mk("tile", "tile", "rsheet", 1.5, 2.0, {"blood": 0.7, "grime": 0.25})
	mk("curb", "concrete", "rust1", 1.0, 1.0, {"tint_a": Color(0.85, 0.85, 0.83)})
	mk("cliff", "cliff", "rust2", 6.0, 4.0, {"tint_a": Color(0.62, 0.6, 0.58), "grime": 0.2})
	mk("sub", "rust2", "rust2", 4.0, 3.0, {"tint_a": Color(0.25, 0.15, 0.12), "tint_b": Color(0.32, 0.14, 0.1), "blood": 0.5})
	mk("ceiling", "plaster", "dplaster", 3.0, 3.0, {"tint_a": Color(0.85, 0.82, 0.74)})
	mk("wallpaper", "wallpaper", "dplaster", 2.5, 2.5, {"blood": 0.85, "grime": 0.25})
	mk("shutter", "shutter", "corr", 3.0, 3.0, {"metal_b": 0.4, "tint_a": Color(0.8, 0.8, 0.8)})
	mk("door", "door", "rust1", 1.0, 1.0, {"grime": 0.2})
	mk("frame", "planks", "rust1", 1.0, 1.0, {"tint_a": Color(0.42, 0.39, 0.35)})
	mk("boards", "planks", "rust1", 1.2, 1.0, {"tint_a": Color(0.85, 0.78, 0.7)})
	mk("metal", "rust1", "rust2", 1.0, 1.0, {"tint_a": Color(0.4, 0.4, 0.4), "metal_b": 0.3})
	mk("fence", "fence", "fence", 1.6, 1.6, {"cut": true, "opac_a_on": true, "opac_b_on": true, "tint_a": Color(0.75, 0.75, 0.75), "tint_b": Color(0.55, 0.32, 0.22), "blood": 0.0, "grime": 0.1})
	mk("fence_ow", "clear", "fence", 1.6, 1.6, {"cut": true, "opac_a_on": true, "opac_b_on": true, "tint_b": Color(0.5, 0.3, 0.22), "blood": 0.0, "grime": 0.1})
	mk("bark", "planks", "rust2", 1.5, 1.5, {"tint_a": Color(0.3, 0.27, 0.24), "tint_b": Color(0.12, 0.07, 0.06), "grime": 0.5})
	mk("rubble", "concrete", "rust2", 1.0, 1.0, {"box_map": true, "tint_a": Color(0.7, 0.7, 0.68)})
	mk("roadchunk", "road", "rust2", 4.0, 2.0, {"box_map": true})
	mk("plinth", "concrete", "rsheet", 1.5, 1.5, {"tint_a": Color(0.6, 0.6, 0.58)})
	mk("counter", "tile", "rsheet", 0.8, 1.0, {"box_map": true, "blood": 0.7})
	for b in STY:
		var s: Array = STY[b]
		var base: String = s[0]
		mk("b_" + b, base, OWB[base], 3.0 if base != "siding" else 2.5, 3.0, {"tint_a": s[2], "blood": 0.55, "metal_b": 0.3})
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.04, 0.045, 0.05)
	g.roughness = 0.12
	g.metallic = 0.6
	g.metallic_specular = 0.8
	mats["glass"] = g
	glass_mats.append(g)
	var gb := StandardMaterial3D.new()
	gb.albedo_color = Color(0.008, 0.008, 0.008)
	gb.roughness = 1.0
	mats["hole"] = gb
	var gc := StandardMaterial3D.new()
	gc.albedo_color = Color(0.55, 0.6, 0.62, 0.16)
	gc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gc.roughness = 0.05
	gc.metallic = 0.3
	gc.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["glass_clear"] = gc
	glass_mats.append(gc)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.2, 0.2, 0.18)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.85, 0.6)
	lm.emission_energy_multiplier = 0.0
	mats["lampglass"] = lm

# ---------------------------------------------------------------- 几何基础
func _st(mat: String, p: Vector3) -> SurfaceTool:
	if override_st:
		return override_st
	var ck := Vector2i(int(floor(p.x / 16.0)), int(floor(p.z / 16.0)))
	if not chunks.has(ck):
		chunks[ck] = {}
	var d: Dictionary = chunks[ck]
	if not d.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		d[mat] = st
	return d[mat]

func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, n: Vector3, collide := false) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b; b = c; c = t
		var tu := ub; ub = uc; uc = tu
	var st := _st(mat, (a + b + c) / 3.0)
	st.set_normal(n); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(n); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(n); st.set_uv(uc); st.add_vertex(c)
	if collide:
		col_faces.append(a); col_faces.append(b); col_faces.append(c)

func tri3(mat: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var t := b; b = c; c = t
		var tn := nb; nb = nc; nc = tn
		var tu := ub; ub = uc; uc = tu
	var st := _st(mat, (a + b + c) / 3.0)
	st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nb); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nc); st.set_uv(uc); st.add_vertex(c)

func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3, collide := false) -> void:
	tri(mat, a, b, c, ua, ub, uc, n, collide)
	tri(mat, a, c, d, ua, uc, ud, n, collide)

func col_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, arr: PackedVector3Array) -> PackedVector3Array:
	arr.append(a); arr.append(b); arr.append(c)
	arr.append(a); arr.append(c); arr.append(d)
	return arr

## 竖直墙面 p=(x,z)
func wall(mat: String, p0: Vector2, p1: Vector2, y0: float, y1: float, n: Vector3, collide := false) -> void:
	var a := Vector3(p0.x, y0, p0.y)
	var b := Vector3(p1.x, y0, p1.y)
	var c := Vector3(p1.x, y1, p1.y)
	var d := Vector3(p0.x, y1, p0.y)
	var u0: float
	var u1: float
	if abs(p1.x - p0.x) > abs(p1.y - p0.y):
		u0 = p0.x; u1 = p1.x
	else:
		u0 = p0.y; u1 = p1.y
	quad(mat, a, b, c, d, Vector2(u0, -y0), Vector2(u1, -y0), Vector2(u1, -y1), Vector2(u0, -y1), n, collide)

func hquad(mat: String, x0: float, z0: float, x1: float, z1: float, y: float, up := true) -> void:
	var n := Vector3.UP if up else Vector3.DOWN
	quad(mat, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
		Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1), n)

const BOX_F := [
	[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
]

func boxb(mat: String, c: Vector3, s: Vector3, bs: Basis, collide := false, bottom := false) -> void:
	var h := s * 0.5
	for f in BOX_F:
		var n: Vector3 = f[0]
		var t1: Vector3 = f[1]
		var t2: Vector3 = f[2]
		if not bottom and n.y < -0.5:
			continue
		var hn: float = abs(n.dot(h))
		var h1: float = abs(t1.dot(h))
		var h2: float = abs(t2.dot(h))
		var cs: Array = []
		var us: Array = []
		for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var lp: Vector3 = n * hn + t1 * h1 * k.x + t2 * h2 * k.y
			cs.append(c + bs * lp)
			us.append(Vector2(h1 * k.x + c.x + c.z, -h2 * k.y - c.y))
		quad(mat, cs[0], cs[1], cs[2], cs[3], us[0], us[1], us[2], us[3], (bs * n).normalized(), collide)

func box(mat: String, c: Vector3, s: Vector3, yaw := 0.0, collide := false) -> void:
	boxb(mat, c, s, Basis(Vector3.UP, yaw), collide)

func cyl(mat: String, p0: Vector3, p1: Vector3, r0: float, r1: float, sides := 6, vscale := 1.0) -> void:
	var axis := p1 - p0
	var ln := axis.length()
	if ln < 0.001:
		return
	var dir := axis / ln
	var rf := Vector3.UP if abs(dir.y) < 0.95 else Vector3.RIGHT
	var x := dir.cross(rf).normalized()
	var z := dir.cross(x).normalized()
	var circ := TAU * (r0 + r1) * 0.5
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var n0 := x * cos(a0) + z * sin(a0)
		var n1 := x * cos(a1) + z * sin(a1)
		var v0 := p0 + n0 * r0
		var v1 := p0 + n1 * r0
		var v2 := p1 + n1 * r1
		var v3 := p1 + n0 * r1
		var u0 := circ * float(i) / sides
		var u1 := circ * float(i + 1) / sides
		tri3(mat, v0, v1, v2, n0, n1, n1, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -ln * vscale))
		tri3(mat, v0, v2, v3, n0, n1, n0, Vector2(u0, 0), Vector2(u1, -ln * vscale), Vector2(u0, -ln * vscale))

# ---------------------------------------------------------------- 网格单元
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

func edge_pts(c: int, r: int, d: Vector2i) -> Array:
	var cx := c * CS
	var cz := r * CS
	if d.x != 0:
		var x := cx + d.x
		return [Vector2(x, cz - 1.0), Vector2(x, cz + 1.0)]
	var z := cz + d.y
	return [Vector2(cx - 1.0, z), Vector2(cx + 1.0, z)]

func _floor_mat(ft: String) -> String:
	match ft:
		".": return "road"
		",": return "sidewalk"
		"_": return "alley"
		"y": return "yard"
		"g": return "dirt"
		"l": return "leaves"
		"w": return "lino"
		"k": return "tile"
	return "sidewalk"

func _build_cells() -> void:
	for r in H:
		for c in W:
			var t := ch(c, r)
			if is_ground(t):
				_ground_cell(c, r, t)
			elif is_build(t):
				_build_cell_extra(c, r, t)

func _ground_cell(c: int, r: int, t: String) -> void:
	var ft := floor_type(c, r)
	var fh := floor_h_t(ft)
	var cx := c * CS
	var cz := r * CS
	hquad(_floor_mat(ft), cx - 1, cz - 1, cx + 1, cz + 1, fh)
	if ft == ".":
		hquad("sub", cx - 1, cz - 1, cx + 1, cz + 1, -6.0)
	if t == "w" or t == "k":
		hquad("ceiling", cx - 1, cz - 1, cx + 1, cz + 1, 3.2, false)
	for d in DIRS:
		var nb := ch(c + d.x, r + d.y)
		var e := edge_pts(c, r, d)
		var into := Vector3(d.x, 0, d.y)
		var face := -into
		if nb == "X":
			_cliff(c, r, d, e, fh, ft)
		elif is_build(nb):
			if t == "w" or t == "k":
				_interior_wall(e, face, fh)
			else:
				_facade(nb, c + d.x, r + d.y, e, face, d)
		elif (t == "w" or t == "k") and not (nb == "w" or nb == "k"):
			_storefront(c, r, d, e, face)
		elif is_ground(nb):
			var nh := floor_h_t(floor_type(c + d.x, r + d.y))
			if fh > nh + 0.01:
				wall("curb", e[0], e[1], nh, fh, into)

func _build_cell_extra(c: int, r: int, t: String) -> void:
	var s: Array = STY[t]
	var h: float = s[1]
	for d in DIRS:
		var nb := ch(c + d.x, r + d.y)
		var e := edge_pts(c, r, d)
		var into := Vector3(d.x, 0, d.y)
		if nb == "X":
			wall("b_" + t, e[0], e[1], -30.0, h, into)
			box("plinth", Vector3((e[0].x + e[1].x) * 0.5, h - 0.15, (e[0].y + e[1].y) * 0.5) + into * 0.12, _edge_box(e, 0.3, 0.24), 0.0)
		elif is_build(nb) and nb != t:
			var h2: float = (STY[nb] as Array)[1]
			if h2 < h:
				wall("b_" + t, e[0], e[1], h2, h, into)

func _edge_box(e: Array, hgt: float, depth: float, extra := 0.0) -> Vector3:
	var p0: Vector2 = e[0]
	var p1: Vector2 = e[1]
	if abs(p1.x - p0.x) > 0.01:
		return Vector3(abs(p1.x - p0.x) + extra, hgt, depth)
	return Vector3(depth, hgt, abs(p1.y - p0.y) + extra)

func _cliff(c: int, r: int, d: Vector2i, e: Array, fh: float, ft: String) -> void:
	var into := Vector3(d.x, 0, d.y)
	wall("cliff", e[0], e[1], -40.0, fh, into)
	# 隐形墙
	var a := Vector3(e[0].x, 0, e[0].y) - into * 0.15
	var b := Vector3(e[1].x, 0, e[1].y) - into * 0.15
	col_quad(a, b, b + Vector3(0, 4, 0), a + Vector3(0, 4, 0), col_faces)
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector3i(c, r, d.x * 3 + d.y))
	var along := Vector3(e[1].x - e[0].x, 0, e[1].y - e[0].y)
	var mid := Vector3((e[0].x + e[1].x) * 0.5, fh, (e[0].y + e[1].y) * 0.5)
	for i in rs.randi_range(1, 3):
		var p := mid + along * rs.randf_range(-0.45, 0.45) - into * rs.randf_range(0.0, 0.3)
		var sz := Vector3(rs.randf_range(0.25, 0.7), rs.randf_range(0.12, 0.35), rs.randf_range(0.25, 0.6))
		var bs := Basis.from_euler(Vector3(rs.randf_range(-0.4, 0.4), rs.randf_range(0, TAU), rs.randf_range(-0.4, 0.4)))
		boxb("rubble", p, sz, bs)
	if ft == "." and rs.randf() < 0.6:
		# 断裂下垂的路面板
		var bs2 := Basis(along.normalized(), -rs.randf_range(0.35, 0.8) * (1.0 if d.x + d.y > 0 else -1.0))
		var p2 := mid + into * 0.55 + Vector3(0, -0.35, 0) + along * rs.randf_range(-0.2, 0.2)
		boxb("roadchunk", p2, _edge_box([Vector2.ZERO, Vector2(along.x, along.z) * 0.7], 0.22, 1.3), bs2)

func _interior_wall(e: Array, face: Vector3, fh: float) -> void:
	wall("wallpaper", e[0], e[1], fh, 3.2, face, true)
	var mid := Vector3((e[0].x + e[1].x) * 0.5, fh + 0.07, (e[0].y + e[1].y) * 0.5) + face * 0.015
	box("frame", mid, _edge_box(e, 0.14, 0.03))
	var mid2 := Vector3(mid.x, 2.35, mid.z) + face * 0.0
	box("frame", mid2, _edge_box(e, 0.05, 0.03))

# ---------------------------------------------------------------- 立面
func _facade(b: String, bc: int, br: int, e: Array, face: Vector3, d: Vector2i) -> void:
	var s: Array = STY[b]
	var h: float = s[1]
	var shop: bool = s[3]
	var m := "b_" + b
	wall(m, e[0], e[1], -0.3, h, face, false)
	var p0: Vector2 = e[0]
	var p1: Vector2 = e[1]
	var a := Vector3(p0.x, 0, p0.y)
	var bb := Vector3(p1.x, 0, p1.y)
	col_quad(a, bb, bb + Vector3(0, 5, 0), a + Vector3(0, 5, 0), col_faces)
	var mid := Vector3((p0.x + p1.x) * 0.5, 0, (p0.y + p1.y) * 0.5)
	var along := Vector3(p1.x - p0.x, 0, p1.y - p0.y).normalized()
	box("plinth", mid + Vector3(0, 0.22, 0) + face * 0.03, _edge_box(e, 0.5, 0.07, 0.07))
	box("plinth", mid + Vector3(0, h - 0.2, 0) + face * 0.12, _edge_box(e, 0.4, 0.26, 0.26))
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector3i(bc, br, d.x * 7 + d.y * 13))
	var yaw := atan2(face.x, face.z)
	# 学校正门
	if b == "S" and face.z > 0.5 and (bc == 21 or bc == 22):
		_school_entrance(mid, face, along, bc == 21)
		for fl in range(1, int(h / 3.5)):
			_window(mid + Vector3(0, fl * 3.5 + 0.9, 0), face, along, 1.2, 1.5, rs, yaw)
		return
	# 校工霍华德家的后门（Levin 街后院）
	if b == "H" and bc == 44 and br == 19 and face.x < -0.5:
		_door(mid, face, along, yaw, "house_door", "开门")
		box("metal", mid + face * 0.18 + Vector3(0, 2.55, 0), Vector3(0.12, 0.12, 0.2), yaw)
		for fl in range(1, int(h / 3.5)):
			_window(mid + Vector3(0, fl * 3.5 + 0.95, 0), face, along, 1.0, 1.5, rs, yaw)
		return
	var nfl := int(h / 3.5)
	if h < 5.0:
		nfl = 1
	for fl in nfl:
		var y0 := fl * 3.5
		if fl > 0:
			box("plinth", mid + Vector3(0, y0, 0) + face * 0.04, _edge_box(e, 0.12, 0.08, 0.08))
		var roll := rs.randf()
		if fl == 0:
			if shop:
				if roll < 0.38:
					_shopwin(mid, face, along, rs, yaw)
				elif roll < 0.68:
					_shutter(mid, face, along, yaw)
				elif roll < 0.8:
					_door(mid, face, along, yaw)
				elif roll < 0.9:
					_window(mid + Vector3(0, 1.0, 0), face, along, 1.1, 1.4, rs, yaw)
			else:
				if roll < 0.55:
					_window(mid + Vector3(0, 1.0, 0), face, along, 1.0, 1.4, rs, yaw)
				elif roll < 0.67:
					_door(mid, face, along, yaw)
		else:
			if roll < 0.78:
				var ww := 1.0 if b != "S" else 1.3
				_window(mid + Vector3(0, y0 + 0.95, 0), face, along, ww, 1.5, rs, yaw)

func _frame_rect(c: Vector3, face: Vector3, along: Vector3, w: float, hh: float, t: float, depth: float, yaw: float, mat := "frame") -> void:
	# c = 底边中点
	box(mat, c + Vector3(0, hh + t * 0.5, 0) + face * depth * 0.5, Vector3(w + 2 * t, t, depth), yaw)
	box(mat, c + Vector3(0, -t * 0.5, 0) + face * depth * 0.5, Vector3(w + 2 * t, t, depth), yaw)
	box(mat, c + along * (w * 0.5 + t * 0.5) + Vector3(0, hh * 0.5, 0) + face * depth * 0.5, Vector3(t, hh, depth), yaw)
	box(mat, c - along * (w * 0.5 + t * 0.5) + Vector3(0, hh * 0.5, 0) + face * depth * 0.5, Vector3(t, hh, depth), yaw)

func _pane(mat: String, c: Vector3, face: Vector3, along: Vector3, w: float, hh: float, off: float) -> void:
	var p0 := c - along * w * 0.5 + face * off
	var p1 := c + along * w * 0.5 + face * off
	wall(mat, Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), c.y, c.y + hh, face)

func _window(c: Vector3, face: Vector3, along: Vector3, w: float, hh: float, rs: RandomNumberGenerator, yaw: float) -> void:
	var k := rs.randf()
	_pane("glass" if k > 0.1 else "hole", c, face, along, w, hh, 0.012)
	_frame_rect(c, face, along, w, hh, 0.08, 0.1, yaw)
	box("frame", c + Vector3(0, hh * 0.55, 0) + face * 0.04, Vector3(w, 0.05, 0.06), yaw)
	box("frame", c + Vector3(0, hh * 0.5, 0) + face * 0.04, Vector3(0.05, hh, 0.06), yaw)
	box("plinth", c + Vector3(0, -0.11, 0) + face * 0.1, Vector3(w + 0.3, 0.07, 0.2), yaw)
	if k > 0.1 and k < 0.24:
		for i in 3:
			var tilt := rs.randf_range(-0.25, 0.25)
			var bs := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), tilt)
			boxb("boards", c + Vector3(0, hh * (0.2 + 0.3 * i), 0) + face * 0.14, Vector3(w + 0.35, 0.2, 0.035), bs)

func _shopwin(c: Vector3, face: Vector3, along: Vector3, rs: RandomNumberGenerator, yaw: float) -> void:
	box("frame", c + Vector3(0, 0.3, 0) + face * 0.06, Vector3(1.7, 0.6, 0.12), yaw)
	var cc := c + Vector3(0, 0.6, 0)
	_pane("glass", cc, face, along, 1.6, 2.0, 0.015)
	_frame_rect(cc, face, along, 1.6, 2.0, 0.07, 0.12, yaw)
	box("frame", cc + Vector3(0, 1.55, 0) + face * 0.05, Vector3(1.6, 0.05, 0.08), yaw)
	if rs.randf() < 0.3:
		for i in 2:
			var bs := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), rs.randf_range(-0.5, 0.5))
			boxb("boards", cc + Vector3(0, 0.6 + 0.7 * i, 0) + face * 0.16, Vector3(1.9, 0.22, 0.035), bs)
	box("plinth", c + Vector3(0, 3.0, 0) + face * 0.09, Vector3(1.9, 0.5, 0.18), yaw)

func _shutter(c: Vector3, face: Vector3, along: Vector3, yaw: float) -> void:
	_pane("shutter", c, face, along, 1.8, 2.7, 0.03)
	box("metal", c + Vector3(0, 2.85, 0) + face * 0.14, Vector3(1.95, 0.32, 0.26), yaw)
	box("metal", c + along * 0.93 + Vector3(0, 1.35, 0) + face * 0.05, Vector3(0.06, 2.7, 0.1), yaw)
	box("metal", c - along * 0.93 + Vector3(0, 1.35, 0) + face * 0.05, Vector3(0.06, 2.7, 0.1), yaw)

func _door(c: Vector3, face: Vector3, along: Vector3, yaw: float, iid := "locked_door", prompt := "调查") -> void:
	var p0 := c - along * 0.55 + face * 0.025
	var p1 := c + along * 0.55 + face * 0.025
	var n := face
	var a := Vector3(p0.x, 0.0, p0.z)
	var b := Vector3(p1.x, 0.0, p1.z)
	quad("door", a, b, b + Vector3(0, 2.3, 0), a + Vector3(0, 2.3, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), n)
	_frame_rect(c, face, along, 1.1, 2.3, 0.1, 0.12, yaw)
	box("plinth", c + face * 0.3 + Vector3(0, 0.07, 0), Vector3(1.5, 0.14, 0.6), yaw)
	box("metal", c + along * 0.4 + Vector3(0, 1.05, 0) + face * 0.07, Vector3(0.05, 0.05, 0.08), yaw)
	add_interact(iid, c + face * 0.3 + Vector3(0, 1.2, 0), Vector3(1.2, 2.2, 0.5), prompt, yaw)

func _school_entrance(mid: Vector3, face: Vector3, along: Vector3, left: bool) -> void:
	var yaw := atan2(face.x, face.z)
	# 每格 2m，两格组成正门
	var c := mid
	var p0 := c - along * 0.85 + face * 0.03
	var p1 := c + along * 0.85 + face * 0.03
	var a := Vector3(p0.x, 0.3, p0.z)
	var b := Vector3(p1.x, 0.3, p1.z)
	quad("door", a, b, b + Vector3(0, 2.6, 0), a + Vector3(0, 2.6, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), face)
	_frame_rect(c + Vector3(0, 0.3, 0), face, along, 1.7, 2.6, 0.12, 0.14, yaw)
	box("plinth", c + face * 0.6 + Vector3(0, 0.1, 0), Vector3(2.1, 0.2, 1.2), yaw)
	box("plinth", c + face * 0.35 + Vector3(0, 0.25, 0), Vector3(2.1, 0.12, 0.7), yaw)
	box("plinth", c + Vector3(0, 3.35, 0) + face * 0.45, Vector3(2.1, 0.18, 0.9), yaw)
	if left:
		cyl("plinth", c - along * 1.0 + face * 0.8, c - along * 1.0 + face * 0.8 + Vector3(0, 3.3, 0), 0.16, 0.14, 8)
	else:
		cyl("plinth", c + along * 1.0 + face * 0.8, c + along * 1.0 + face * 0.8 + Vector3(0, 3.3, 0), 0.16, 0.14, 8)
	add_interact("school_door", c + face * 0.4 + Vector3(0, 1.3, 0), Vector3(1.8, 2.4, 0.6), "调查", yaw)

func _storefront(c: int, r: int, d: Vector2i, e: Array, face: Vector3) -> void:
	# 咖啡馆临街玻璃立面 (face 指向室内)
	var outn := -face
	var p0: Vector2 = e[0]
	var p1: Vector2 = e[1]
	var mid := Vector3((p0.x + p1.x) * 0.5, 0, (p0.y + p1.y) * 0.5)
	var along := Vector3(p1.x - p0.x, 0, p1.y - p0.y).normalized()
	var yaw := atan2(outn.x, outn.z)
	var is_door := (c == 16 and d == Vector2i(0, 1))
	# 外檐墙
	wall("b_K", p0, p1, 3.2, 4.6, outn)
	box("plinth", mid + Vector3(0, 4.45, 0) + outn * 0.12, _edge_box(e, 0.3, 0.26, 0.26))
	box("frame", mid + Vector3(0, 3.0, 0), _edge_box(e, 0.4, 0.16))
	box("frame", mid + along * 0.97 + Vector3(0, 1.5, 0), Vector3(0.1, 3.0, 0.16), yaw)
	if is_door:
		box("frame", mid + along * 0.97 + Vector3(0, 1.5, 0), Vector3(0.12, 3.0, 0.16), yaw)
		box("frame", mid - along * 0.97 + Vector3(0, 1.5, 0), Vector3(0.12, 3.0, 0.16), yaw)
		box("frame", mid + Vector3(0, 2.6, 0), Vector3(1.9, 0.1, 0.16), yaw)
		_pane("glass_clear", mid + Vector3(0, 2.65, 0), outn, along, 1.8, 0.3, 0.0)
		# 敞开的门扇
		var hinge := mid - along * 0.9
		var openb := Basis(Vector3.UP, yaw - 1.9)
		var leafc := hinge + openb * Vector3(0.45, 1.25, 0)
		boxb("frame", leafc, Vector3(0.9, 2.5, 0.05), openb)
		var gpos := leafc
		boxb("frame", gpos + Vector3(0, 0.0, 0), Vector3(0.05, 2.4, 0.06), openb)
		var dl := StaticBody3D.new()
		add_child(dl)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.9, 2.5, 0.06)
		cs.shape = bx
		dl.add_child(cs)
		dl.transform = Transform3D(openb, leafc)
		return
	box("frame", mid + Vector3(0, 0.3, 0), _edge_box(e, 0.6, 0.14))
	_pane("glass_clear", mid + Vector3(0, 0.6, 0), outn, along, 1.9, 2.2, 0.0)
	box("frame", mid + Vector3(0, 0.62, 0), _edge_box(e, 0.05, 0.18))
	var a := Vector3(p0.x, 0, p0.y)
	var b := Vector3(p1.x, 0, p1.y)
	col_quad(a, b, b + Vector3(0, 3.2, 0), a + Vector3(0, 3.2, 0), col_faces)

# ---------------------------------------------------------------- 特殊结构：铁丝网、大门、狗屋、小巷
func fence_line(mat: String, p0: Vector2, p1: Vector2, h := 2.4, collide := true, faces_target := 0) -> void:
	var n := Vector3(-(p1.y - p0.y), 0, p1.x - p0.x).normalized()
	wall(mat, p0, p1, 0.0, h, n, false)
	var a := Vector3(p0.x, 0, p0.y)
	var b := Vector3(p1.x, 0, p1.y)
	cyl("metal", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.025, 0.025, 5)
	cyl("metal", a + Vector3(0, 0.15, 0), b + Vector3(0, 0.15, 0), 0.018, 0.018, 4)
	if collide:
		if faces_target == 0:
			col_quad(a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0), col_faces)
		else:
			col_quad(a, b, b + Vector3(0, h, 0), a + Vector3(0, h, 0), ow_faces)

func post(p: Vector2, h := 2.5) -> void:
	cyl("metal", Vector3(p.x, 0, p.y), Vector3(p.x, h, p.y), 0.045, 0.04, 6)

func _is_fl(t: String) -> bool:
	return t == "F" or t == "G"

func _build_special() -> void:
	# 铁丝网格
	for r in H:
		for c in W:
			if ch(c, r) != "F":
				continue
			var cx := c * CS
			var cz := r * CS
			var lf := _is_fl(ch(c - 1, r)) or (is_build(ch(c - 1, r)) and _is_fl(ch(c + 1, r)))
			var rt := _is_fl(ch(c + 1, r)) or (is_build(ch(c + 1, r)) and _is_fl(ch(c - 1, r)))
			var up := _is_fl(ch(c, r - 1)) or (is_build(ch(c, r - 1)) and _is_fl(ch(c, r + 1)))
			var dn := _is_fl(ch(c, r + 1)) or (is_build(ch(c, r + 1)) and _is_fl(ch(c, r - 1)))
			var horiz := lf or rt
			var vert := up or dn
			if not horiz and not vert:
				horiz = true
			var corner := horiz and vert
			if horiz:
				var x0 := cx - 1.0 if (lf or not corner) else cx
				var x1 := cx + 1.0 if (rt or not corner) else cx
				fence_line("fence", Vector2(x0, cz), Vector2(x1, cz))
			if vert:
				var z0 := cz - 1.0 if (up or not corner) else cz
				var z1 := cz + 1.0 if (dn or not corner) else cz
				fence_line("fence", Vector2(cx, z0), Vector2(cx, z1))
			post(Vector2(cx, cz))
	# 小巷北端的铁丝网（雾世界即存在）
	fence_line("fence", Vector2(57, 43), Vector2(61, 43))
	post(Vector2(57, 43)); post(Vector2(59, 43)); post(Vector2(61, 43))
	box("metal", Vector3(59.0, 1.05, 43.0), Vector3(0.06, 0.18, 0.08))
	add_interact("alley_fence", Vector3(59, 1.2, 43.4), Vector3(4.0, 2.4, 0.6), "调查")
	# 里世界才出现的铁丝网：公园北口、小巷南口
	fence_line("fence_ow", Vector2(57, 28), Vector2(63, 28), 3.0, true, 1)
	fence_line("fence_ow", Vector2(57, 59.2), Vector2(61, 59.2), 3.0, true, 1)
	_gate()
	_doghouse()
	_cafe_interior_static()

func _gate() -> void:
	# 校门 G = (21..22, 8)，铁栅门，铰链在 x=41 与 x=45
	gate_l = Node3D.new()
	gate_r = Node3D.new()
	add_child(gate_l)
	add_child(gate_r)
	gate_l.position = Vector3(41, 0, 16)
	gate_r.position = Vector3(45, 0, 16)
	for g in [gate_l, gate_r]:
		var sgn := 1.0 if g == gate_l else -1.0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		override_st = st
		cyl("metal", Vector3(0, 0.1, 0), Vector3(0, 2.6, 0), 0.05, 0.05, 6)
		cyl("metal", Vector3(sgn * 2.0, 0.1, 0), Vector3(sgn * 2.0, 2.4, 0), 0.04, 0.04, 6)
		cyl("metal", Vector3(0, 2.4, 0), Vector3(sgn * 2.0, 2.4, 0), 0.035, 0.035, 5)
		cyl("metal", Vector3(0, 0.2, 0), Vector3(sgn * 2.0, 0.2, 0), 0.035, 0.035, 5)
		cyl("metal", Vector3(0, 1.3, 0), Vector3(sgn * 2.0, 1.3, 0), 0.03, 0.03, 5)
		for i in 9:
			var x := sgn * (0.2 + i * 0.2)
			cyl("metal", Vector3(x, 0.2, 0), Vector3(x, 2.55 - abs(x - sgn * 1.0) * 0.12, 0), 0.014, 0.014, 4)
		override_st = null
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats["metal"]
		g.add_child(mi)
	# 锁链
	var chain := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.07
	tm.outer_radius = 0.11
	chain.mesh = tm
	chain.material_override = mats["metal"]
	chain.position = Vector3(43, 1.3, 16.05)
	chain.rotation = Vector3(PI / 2, 0, 0.3)
	chain.name = "GateChain"
	add_child(chain)
	var lock := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.11, 0.04)
	lock.mesh = bm
	lock.material_override = mats["metal"]
	lock.position = Vector3(43, 1.17, 16.1)
	lock.name = "GateLock"
	add_child(lock)
	gate_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4.0, 3.0, 0.2)
	cs.shape = bx
	gate_body.add_child(cs)
	gate_body.position = Vector3(43, 1.5, 16)
	add_child(gate_body)
	# 门柱与拱形招牌
	for x in [40.8, 45.2]:
		box("plinth", Vector3(x, 1.6, 16), Vector3(0.5, 3.2, 0.5))
		box("plinth", Vector3(x, 3.3, 16), Vector3(0.6, 0.2, 0.6))
	box("metal", Vector3(43, 4.1, 16), Vector3(4.9, 0.08, 0.08))
	box("metal", Vector3(43, 3.4, 16), Vector3(4.9, 0.08, 0.08))
	for x in [41.0, 45.0]:
		box("metal", Vector3(x, 3.75, 16), Vector3(0.08, 0.8, 0.08))
	sign3d("MIDWICH ELEMENTARY SCHOOL", Vector3(43, 3.75, 16.06), 0.0, 60, Color(0.12, 0.12, 0.11), Color(0.75, 0.73, 0.68), Vector2(4.4, 0.55))
	sign3d("MIDWICH ELEMENTARY SCHOOL", Vector3(43, 3.75, 15.94), PI, 60, Color(0.12, 0.12, 0.11), Color(0.75, 0.73, 0.68), Vector2(4.4, 0.55))
	add_interact("school_gate", Vector3(43, 1.3, 16.3), Vector3(3.8, 2.4, 0.5), "调查")

func open_gate(t: float) -> void:
	var a := t * deg_to_rad(105)
	gate_l.rotation.y = a
	gate_r.rotation.y = -a
	if t > 0.05 and gate_body and is_instance_valid(gate_body):
		gate_body.queue_free()
		gate_body = null
		astar.set_point_solid(Vector2i(21, 8), false)
		astar.set_point_solid(Vector2i(22, 8), false)
	var chn := get_node_or_null("GateChain")
	if chn and not chn.is_queued_for_deletion():
		chn.queue_free()
		get_node("GateLock").position = Vector3(43.4, 0.03, 16.5)

func _doghouse() -> void:
	# 狗屋在 (43, 20.5) 格 -> 世界 (86, 41)
	var c := Vector3(85.9, 0, 41.0)
	var yaw := -PI / 2
	var bs := Basis(Vector3.UP, yaw)
	boxb("boards", c + bs * Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 1.0), bs, true)
	# 屋顶
	for sgn in [-1.0, 1.0]:
		var rb := bs * Basis(Vector3(0, 0, 1), sgn * 0.62)
		boxb("frame", c + bs * Vector3(sgn * 0.3, 1.12, 0), Vector3(0.78, 0.05, 1.2), rb)
	# 门洞（黑色）
	var hole_c := c + bs * Vector3(0, 0.0, 0.505)
	var face := bs * Vector3(0, 0, 1)
	var along := bs * Vector3(1, 0, 0)
	var p0 := hole_c - along * 0.25
	var p1 := hole_c + along * 0.25
	wall("hole", Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), 0.05, 0.6, face)
	# 断掉的狗链
	for i in 7:
		var p := c + bs * Vector3(0.1 + i * 0.12, 0.03, 0.75 + sin(i * 1.3) * 0.08)
		box("metal", p, Vector3(0.07, 0.025, 0.04), i * 0.7)
	sign3d("BEWARE OF DOG", c + bs * Vector3(0, 0.75, 0.52), yaw, 32, Color(0.15, 0.03, 0.02), Color(0.8, 0.76, 0.66), Vector2(0.75, 0.2))
	# 低矮木栅栏：x=83，z 35..39.4 与 42.6..45
	for seg in [[35.0, 39.4], [42.6, 45.0]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		var z := z0
		while z <= z1 + 0.01:
			box("boards", Vector3(83.0, 0.5, z), Vector3(0.08, 1.0, 0.12), 0.0)
			z += 0.3
		box("boards", Vector3(83.0, 0.75, (z0 + z1) * 0.5), Vector3(0.05, 0.1, z1 - z0), 0.0)
		box("boards", Vector3(83.0, 0.3, (z0 + z1) * 0.5), Vector3(0.05, 0.1, z1 - z0), 0.0)
		col_quad(Vector3(83, 0, z0), Vector3(83, 0, z1), Vector3(83, 1.2, z1), Vector3(83, 1.2, z0), col_faces)

func _cafe_interior_static() -> void:
	# 吧台：z=51，x 27..31
	box("frame", Vector3(29.0, 0.55, 51.0), Vector3(4.0, 1.0, 0.6), 0.0, true)
	box("counter", Vector3(29.0, 1.08, 51.05), Vector3(4.1, 0.06, 0.78), 0.0)
	box("frame", Vector3(33.0 - 0.06, 1.6, 51.0), Vector3(0.12, 3.2, 0.3), 0.0)

# ---------------------------------------------------------------- 招牌
func sign3d(text: String, pos: Vector3, yaw: float, size: int, col: Color, plate: Color, plate_size: Vector2, cn := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = sign_font if not cn else load("res://assets/fonts/serif.otf")
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.position = pos
	l.rotation.y = yaw
	add_child(l)
	if plate_size.x > 0:
		var pm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(plate_size.x, plate_size.y, 0.04)
		pm.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = plate
		sm.roughness = 0.8
		pm.material_override = sm
		pm.position = pos - Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.025)
		pm.rotation.y = yaw
		add_child(pm)
	return l

# ---------------------------------------------------------------- 枯树
func _tree_mesh(seed_v: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	override_st = st
	var rs := RandomNumberGenerator.new()
	rs.seed = seed_v
	_branch(rs, Vector3.ZERO + Vector3(0, -0.2, 0), Vector3(rs.randf_range(-0.1, 0.1), 1, rs.randf_range(-0.1, 0.1)).normalized(), rs.randf_range(4.5, 7.0), rs.randf_range(0.17, 0.26), 3)
	override_st = null
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, mats["bark"])
	return m

func _branch(rs: RandomNumberGenerator, p: Vector3, dir: Vector3, length: float, r: float, depth: int) -> void:
	var segs := 3
	var cur := p
	var d := dir
	var rc := r
	var sides := 7 if depth >= 3 else (5 if depth >= 2 else 4)
	for s in segs:
		var nd := (d + Vector3(rs.randf_range(-0.3, 0.3), rs.randf_range(-0.05, 0.12), rs.randf_range(-0.3, 0.3))).normalized()
		var nxt := cur + nd * length / segs
		var r1 := r * (1.0 - 0.62 * float(s + 1) / segs)
		cyl("bark", cur, nxt, rc, r1, sides, 0.6)
		cur = nxt
		d = nd
		rc = r1
		if depth > 0 and s >= (1 if depth >= 2 else 0):
			var nb := rs.randi_range(1, 2) if depth < 3 else rs.randi_range(2, 3)
			for k in nb:
				var side := Vector3(rs.randf_range(-1, 1), rs.randf_range(-0.1, 0.5), rs.randf_range(-1, 1)).normalized()
				var cd := (d * 0.55 + side * 0.8).normalized()
				_branch(rs, cur, cd, length * rs.randf_range(0.45, 0.65), rc * 0.75, depth - 1)

func _build_trees() -> void:
	for i in 4:
		tree_meshes.append(_tree_mesh(77 + i * 31))
	var xf := [[], [], [], []]
	var body := StaticBody3D.new()
	add_child(body)
	var rs := RandomNumberGenerator.new()
	rs.seed = 4242
	for r in H:
		for c in W:
			if ch(c, r) != "T":
				continue
			var p := cpos(c, r) + Vector3(rs.randf_range(-0.5, 0.5), 0, rs.randf_range(-0.5, 0.5))
			var s := rs.randf_range(0.8, 1.25)
			var t := Transform3D(Basis(Vector3.UP, rs.randf_range(0, TAU)).scaled(Vector3.ONE * s), p)
			xf[rs.randi_range(0, 3)].append(t)
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.28 * s
			cy.height = 4.0
			cs.shape = cy
			cs.position = p + Vector3(0, 2, 0)
			body.add_child(cs)
	for i in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tree_meshes[i]
		var arr: Array = xf[i]
		mm.instance_count = arr.size()
		for k in arr.size():
			mm.set_instance_transform(k, arr[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

# ---------------------------------------------------------------- 模型
func _aabb_of(n: Node3D) -> AABB:
	var res := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = (inv * m.global_transform) * m.get_aabb()
		if first:
			res = bb
			first = false
		else:
			res = res.merge(bb)
	return res

func model(name: String, pos: Vector3, yaw_deg: float, target := 0.0, axis := "h", collide := true, parent: Node = null) -> Node3D:
	if not model_cache.has(name):
		model_cache[name] = load("res://assets/models/%s.glb" % name)
	var ps: PackedScene = model_cache[name]
	var n: Node3D = ps.instantiate()
	var par: Node = self
	if parent:
		par = parent
	par.add_child(n)
	var bb := _aabb_of(n)
	var s := 1.0
	if target > 0.0:
		var ref := bb.size.y
		if axis == "l":
			ref = max(bb.size.x, bb.size.z)
		s = target / max(ref, 0.001)
	var bs := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var c := bb.get_center()
	n.transform = Transform3D(bs.scaled(Vector3.ONE * s), pos - bs * (Vector3(c.x, bb.position.y, c.z) * s))
	_retex(n)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = bb.size * s
		cs.shape = bx
		body.add_child(cs)
		par.add_child(body)
		body.transform = Transform3D(bs, pos + Vector3(0, bb.size.y * s * 0.5, 0))
	n.set_meta("size", bb.size * s)
	return n

const SH_GRIME = preload("res://shaders/grime_overlay.gdshader")
var ph_cache := {}
var grime_mats := {}

func grime_mat(amount: float, blood_v := 0.0) -> ShaderMaterial:
	var k := "%.2f_%.2f" % [amount, blood_v]
	if grime_mats.has(k):
		return grime_mats[k]
	var m := ShaderMaterial.new()
	m.shader = SH_GRIME
	m.set_shader_parameter("grime_tex", tex("grime"))
	m.set_shader_parameter("blood_tex", tex("blood"))
	m.set_shader_parameter("amount", amount)
	m.set_shader_parameter("blood", blood_v)
	m.set_shader_parameter("ow_mix", ow)
	grime_mats[k] = m
	mat_list.append(m)
	return m

func ph_scene(name: String) -> PackedScene:
	if not ph_cache.has(name):
		ph_cache[name] = load("res://assets/ph/%s/%s_1k.gltf" % [name, name])
	return ph_cache[name]

## Poly Haven 模型：保留原 PBR 材质，叠加污渍。opts: target(高度) / scale / hide / only / collide / grime / blood / parent / shadow / block(导航)
func ph(name: String, pos: Vector3, yaw_deg: float, opts := {}) -> Node3D:
	var n: Node3D = ph_scene(name).instantiate()
	var par: Node = opts.get("parent", cur_build.get("root", self) if not cur_build.is_empty() else self)
	par.add_child(n)
	var hide: Array = opts.get("hide", [])
	var only: Array = opts.get("only", [])
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		var vis := true
		for h in hide:
			if nm.contains(h):
				vis = false
		if only.size() > 0:
			vis = false
			for o in only:
				if nm == o or nm.ends_with(o):
					vis = true
		if not vis:
			m.queue_free()
			m.name = "_dead"
			continue
		var gv: float = opts.get("grime", 0.45)
		if gv > 0.0:
			m.material_overlay = grime_mat(gv, opts.get("blood", 0.0))
		if not opts.get("shadow", true):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bb := _aabb_vis(n)
	var s: float = opts.get("scale", 1.0)
	if opts.has("target"):
		s = float(opts.target) / max(bb.size.y, 0.001)
	var bs := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var c := bb.get_center()
	n.transform = Transform3D(bs.scaled(Vector3.ONE * s), pos - bs * (Vector3(c.x, bb.position.y, c.z) * s))
	var size := bb.size * s
	n.set_meta("size", size)
	if opts.get("collide", true):
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = size
		cs.shape = bx
		body.add_child(cs)
		par.add_child(body)
		body.transform = Transform3D(bs, pos + Vector3(0, size.y * 0.5, 0))
		n.set_meta("body", body)
		if opts.get("block", true):
			nav_block(pos, Vector2(size.x, size.z), deg_to_rad(yaw_deg), opts.get("tag", ""))
	return n

func _aabb_vis(n: Node3D) -> AABB:
	var res := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name) == "_dead":
			continue
		var bb: AABB = (inv * m.global_transform) * m.get_aabb()
		if first:
			res = bb
			first = false
		else:
			res = res.merge(bb)
	return res

func _prop_mat(src: Material) -> Material:
	var nm := src.resource_name if src else ""
	var col := Color(0.6, 0.6, 0.6)
	if src is BaseMaterial3D:
		col = (src as BaseMaterial3D).albedo_color
	var key := nm + col.to_html()
	if prop_mat_cache.has(key):
		return prop_mat_cache[key]
	var m: Material
	if nm == "colormap" and src is BaseMaterial3D:
		var sm := ShaderMaterial.new()
		sm.shader = SH_CAR
		sm.set_shader_parameter("colormap", (src as BaseMaterial3D).albedo_texture)
		sm.set_shader_parameter("grime_tex", tex("grime"))
		sm.set_shader_parameter("rust_tex", tex("rust1_a"))
		mat_list.append(sm)
		m = sm
	elif nm.begins_with("glass"):
		m = mats["glass"]
	else:
		var base := "plaster"
		var b2 := "rust2"
		if nm.begins_with("wood"):
			base = "planks"
		elif nm.begins_with("metal"):
			base = "rust1"
			b2 = "rust1"
		elif nm.begins_with("carpet"):
			base = "concrete"
		var l := col.get_luminance()
		var tint := col.lerp(Color(l, l, l), 0.35) * (1.7 if base != "rust1" else 1.25)
		if base == "rust1":
			tint = Color(l, l, l) * 1.3
		var sm2 := ShaderMaterial.new()
		sm2.shader = SH_S
		sm2.set_shader_parameter("tex_a", tex(base + "_a"))
		sm2.set_shader_parameter("nor_a", tex(base + "_n"))
		sm2.set_shader_parameter("tex_b", tex(b2 + "_a"))
		sm2.set_shader_parameter("nor_b", tex(b2 + "_n"))
		sm2.set_shader_parameter("blood_tex", tex("blood"))
		sm2.set_shader_parameter("peel_tex", tex("peel_noise"))
		sm2.set_shader_parameter("grime_tex", tex("grime"))
		sm2.set_shader_parameter("scale_a", 1.6)
		sm2.set_shader_parameter("scale_b", 1.0)
		sm2.set_shader_parameter("box_map", true)
		sm2.set_shader_parameter("tint_a", tint)
		sm2.set_shader_parameter("grime", 0.45)
		sm2.set_shader_parameter("blood", 0.5)
		mat_list.append(sm2)
		m = sm2
	prop_mat_cache[key] = m
	return m

func _retex(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, _prop_mat(m.mesh.surface_get_material(i)))

# ---------------------------------------------------------------- 路灯 / 街牌 / 车辆 / 杂物
func lamp(p: Vector3, toward: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	cyl("metal", p, p + Vector3(0, 4.6, 0), 0.08, 0.055, 7)
	box("metal", p + Vector3(0, 0.25, 0), Vector3(0.26, 0.5, 0.26))
	var tip := p + Vector3(0, 4.6, 0) + toward * 1.1
	cyl("metal", p + Vector3(0, 4.45, 0), tip + Vector3(0, 0.05, 0), 0.04, 0.035, 5)
	box("metal", tip + Vector3(0, -0.02, 0), Vector3(0.55, 0.14, 0.32), atan2(toward.x, toward.z) + PI / 2)
	var gl := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.04, 0.22)
	gl.mesh = bm
	gl.material_override = mats["lampglass"]
	gl.position = tip + Vector3(0, -0.1, 0)
	gl.rotation.y = atan2(toward.x, toward.z) + PI / 2
	add_child(gl)
	n.position = tip + Vector3(0, -0.4, 0)
	return n

func street_sign(p: Vector3, a: String, a_yaw: float, b: String, b_yaw: float) -> void:
	cyl("metal", p, p + Vector3(0, 3.0, 0), 0.04, 0.04, 6)
	var green := Color(0.16, 0.3, 0.2)
	var ba := Basis(Vector3.UP, a_yaw)
	var bb := Basis(Vector3.UP, b_yaw)
	sign3d(a, p + Vector3(0, 2.85, 0) + ba * Vector3(0.45, 0, 0.03), a_yaw, 40, Color(0.92, 0.92, 0.88), green, Vector2(1.0, 0.2))
	sign3d(a, p + Vector3(0, 2.85, 0) + ba * Vector3(-0.45, 0, -0.03), a_yaw + PI, 40, Color(0.92, 0.92, 0.88), Color(0, 0, 0, 0), Vector2.ZERO)
	sign3d(b, p + Vector3(0, 2.6, 0) + bb * Vector3(0.45, 0, 0.03), b_yaw, 40, Color(0.92, 0.92, 0.88), green, Vector2(1.0, 0.2))
	sign3d(b, p + Vector3(0, 2.6, 0) + bb * Vector3(-0.45, 0, -0.03), b_yaw + PI, 40, Color(0.92, 0.92, 0.88), Color(0, 0, 0, 0), Vector2.ZERO)

func _build_props() -> void:
	# 路灯：沿人行道
	for r in H:
		for c in W:
			if ch(c, r) != ",":
				continue
			if (c * 3 + r * 5) % 13 != 0:
				continue
			var roads := []
			for d in DIRS:
				if ch(c + d.x, r + d.y) == ".":
					roads.append(d)
			if roads.size() != 1:
				continue
			var d: Vector2i = roads[0]
			var tw := Vector3(d.x, 0, d.y)
			var lp := cpos(c, r, 0.1) + tw * 0.7
			var ln := lamp(lp, tw)
			fog_lights.append(ln)
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.12
			cy.height = 3.0
			cs.shape = cy
			body.add_child(cs)
			body.position = lp + Vector3(0, 1.5, 0)
			add_child(body)
	# 街牌
	street_sign(cpos(19, 13, 0.1) + Vector3(-0.4, 0, 0.4), "MIDWICH ST.", 0.0, "BACHMAN RD.", PI / 2)
	street_sign(cpos(19, 30, 0.1) + Vector3(-0.4, 0, -0.4), "LINDSEY ST.", 0.0, "BACHMAN RD.", PI / 2)
	street_sign(cpos(37, 30, 0.1) + Vector3(-0.4, 0, -0.4), "LINDSEY ST.", 0.0, "LEVIN ST.", PI / 2)
	street_sign(cpos(37, 13, 0.1) + Vector3(-0.4, 0, 0.4), "MIDWICH ST.", 0.0, "LEVIN ST.", PI / 2)
	# 店招
	var y := Color(0.86, 0.82, 0.7)
	var dk := Color(0.1, 0.1, 0.1)
	sign3d("CAFÉ  5TO2", Vector3(37.15, 3.9, 55.0), PI / 2, 110, Color(0.55, 0.12, 0.08), Color(0.9, 0.86, 0.76), Vector2(3.6, 0.7))
	sign3d("CAFÉ  5TO2", Vector3(32.0, 3.9, 59.15), 0.0, 110, Color(0.55, 0.12, 0.08), Color(0.9, 0.86, 0.76), Vector2(3.6, 0.7))
	sign3d("GENERAL STORE", Vector3(37.15, 3.4, 33.0), PI / 2, 90, dk, y, Vector2(3.6, 0.6))
	sign3d("POST OFFICE", Vector3(16.0, 3.6, 59.15), 0.0, 90, Color(0.9, 0.9, 0.85), Color(0.15, 0.2, 0.35), Vector2(3.4, 0.6))
	sign3d("THE OLD LANTERN · BAR", Vector3(52.0, 3.5, 59.15), 0.0, 80, Color(0.85, 0.75, 0.5), Color(0.18, 0.1, 0.08), Vector2(4.4, 0.55))
	sign3d("HARDWARE", Vector3(68.0, 3.5, 59.15), 0.0, 90, dk, Color(0.8, 0.78, 0.7), Vector2(3.0, 0.6))
	sign3d("FIRST BANK", Vector3(20.0, 3.6, 68.85), PI, 90, Color(0.85, 0.85, 0.8), Color(0.2, 0.22, 0.25), Vector2(3.0, 0.6))
	sign3d("VIDEO & BOOKS", Vector3(58.0, 3.5, 68.85), PI, 90, Color(0.75, 0.15, 0.12), Color(0.85, 0.84, 0.8), Vector2(3.6, 0.6))
	sign3d("LAUNDROMAT", Vector3(82.85, 3.5, 54.0), -PI / 2, 90, dk, Color(0.7, 0.8, 0.85), Vector2(3.2, 0.6))
	sign3d("HOTEL NORMAN", Vector3(82.85, 5.0, 64.0), -PI / 2, 100, Color(0.85, 0.8, 0.6), Color(0.15, 0.12, 0.1), Vector2(3.8, 0.7))
	sign3d("APARTMENTS", Vector3(82.85, 3.5, 30.0), -PI / 2, 80, dk, y, Vector2(2.8, 0.5))
	sign3d("DINER", Vector3(14.0, 3.6, 17.15), 0.0, 110, Color(0.7, 0.12, 0.1), Color(0.88, 0.86, 0.8), Vector2(2.2, 0.7))
	sign3d("TOWN HALL", Vector3(80.0, 3.8, 17.15), 0.0, 90, Color(0.85, 0.85, 0.8), Color(0.22, 0.22, 0.22), Vector2(3.0, 0.6))
	sign3d("MOTEL", Vector3(12.0, 3.6, 26.85), PI, 110, Color(0.75, 0.18, 0.12), Color(0.86, 0.84, 0.78), Vector2(2.2, 0.7))
	sign3d("MIDWICH ELEMENTARY SCHOOL", Vector3(43.0, 4.6, 9.18), 0.0, 120, Color(0.2, 0.18, 0.15), Color(0.82, 0.8, 0.74), Vector2(7.6, 0.8))
	# 车辆
	var cars := [
		["sedan", 24.0, 46.1, 52.0, 4.4],
		["hatchback-sports", 12.5, 10.5, 93.0, 4.0],
		["suv", 33.0, 12.1, -86.0, 4.7],
		["police", 21.6, 17.5, 8.0, 4.6],
		["taxi", 27.5, 31.1, 97.0, 4.5],
		["sedan-sports", 9.5, 33.0, -80.0, 4.4],
		["delivery", 39.4, 21.0, 176.0, 5.4],
		["sedan", 38.6, 32.9, 138.0, 4.4],
		["suv", 20.3, 38.0, -14.0, 4.7],
		["ambulance", 15.0, 12.1, 88.0, 5.6],
	]
	for cdat in cars:
		var cp := cpos(cdat[1], cdat[2])
		var cn := model(cdat[0], cp, cdat[3], cdat[4], "l", true)
		cn.set_meta("car", true)
		var cc := cell_of(cp)
		_solid.append(cc)
	# 坠毁汽车的碎片
	model("debris-tire", cpos(22.6, 45.2), 30, 0.7, "l", false)
	model("debris-door", cpos(22.9, 47.2), 120, 1.2, "l", false)
	# 公园长椅
	model("bench", cpos(28.0, 19.5), 180, 0.9, "h", true)
	model("bench", cpos(33.0, 16.0), 90, 0.9, "h", true)
	model("bench", cpos(26.0, 15.7), 0, 0.9, "h", true)
	# 街上杂物
	var junk := [
		["trashcan", 19.2, 15.0, 0.0, 0.85], ["trashcan", 23.3, 27.0, 20.0, 0.85], ["trashcan", 29.0, 23.6, 0.0, 0.85],
		["trashcan", 30.2, 26.5, 40.0, 0.85], ["cardboardBoxClosed", 29.2, 25.2, 15.0, 0.5], ["cardboardBoxOpen", 30.3, 27.6, 70.0, 0.45],
		["cardboardBoxClosed", 29.1, 28.4, 40.0, 0.45], ["trashcan", 37.2, 26.0, 0.0, 0.85], ["cardboardBoxOpen", 41.2, 29.3, 10.0, 0.45],
		["trashcan", 13.0, 9.3, 0.0, 0.85], ["cone", 21.0, 21.3, 0.0, 0.6], ["cone", 20.2, 21.4, 30.0, 0.6], ["cone", 22.1, 26.4, 0.0, 0.6],
		["box", 42.8, 18.6, 30.0, 0.5], ["trashcan", 41.2, 34.2, 0.0, 0.85], ["cardboardBoxClosed", 4.6, 30.4, 25.0, 0.45],
	]
	for j in junk:
		var jp := cpos(j[1], j[2])
		jp.y = floor_h(jp)
		model(j[0], jp, j[3], j[4], "h", j[4] > 0.55)
	# 咖啡馆家具
	var cafe := Node3D.new()
	cafe.name = "Cafe"
	add_child(cafe)
	model("table", Vector3(35.0, 0.12, 53.6), 0, 0.78, "h", true, cafe)
	model("table", Vector3(35.0, 0.12, 57.0), 0, 0.78, "h", true, cafe)
	model("table", Vector3(29.4, 0.12, 57.0), 0, 0.78, "h", true, cafe)
	for cp2 in [[34.0, 53.6, 90.0], [36.0, 53.6, -90.0], [34.0, 57.0, 90.0], [36.1, 57.2, -100.0], [28.4, 57.0, 90.0], [30.4, 56.6, -70.0]]:
		model("chair", Vector3(cp2[0], 0.12, cp2[1]), cp2[2], 0.95, "h", true, cafe)
	for sx in [27.8, 29.0, 30.2]:
		model("stoolBar", Vector3(sx, 0.12, 52.0), 0, 0.78, "h", false, cafe)
	model("kitchenStove", Vector3(28.2, 0.12, 47.7), 0, 0.95, "h", true, cafe)
	model("kitchenCabinet", Vector3(29.9, 0.12, 47.7), 0, 0.95, "h", true, cafe)
	model("kitchenFridge", Vector3(32.2, 0.12, 47.8), 0, 1.85, "h", true, cafe)
	model("kitchenCoffeeMachine", Vector3(27.6, 1.11, 51.0), 0, 0.38, "h", false, cafe)
	model("televisionVintage", Vector3(30.4, 1.11, 51.0), 0, 0.5, "h", false, cafe)
	model("lampSquareCeiling", Vector3(32.0, 2.95, 55.0), 0, 0.25, "h", false, cafe)
	model("lampSquareCeiling", Vector3(29.5, 2.95, 49.0), 0, 0.25, "h", false, cafe)
	model("trashcan", Vector3(36.4, 0.12, 51.6), 0, 0.7, "h", false, cafe)
	model("coatRackStanding", Vector3(27.6, 0.12, 58.3), 0, 1.75, "h", false, cafe)
	model("rugDoormat", Vector3(32.0, 0.13, 58.2), 0, 0.02, "h", false, cafe)
	var tv := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.3, 0.22)
	tv.mesh = qm
	var tvm := ShaderMaterial.new()
	var tsh := Shader.new()
	tsh.code = "shader_type spatial;\nrender_mode unshaded;\nuniform float on = 1.0;\nvoid fragment(){ vec2 g = floor(UV*vec2(96.0,72.0)); float n = fract(sin(dot(g + floor(TIME*24.0)*vec2(1.37,7.13), vec2(12.9898,78.233)))*43758.5453); float sc = 0.85 + 0.15*sin(UV.y*300.0 + TIME*20.0); ALBEDO = vec3(n*sc*0.75*on); }"
	tvm.shader = tsh
	tv.material_override = tvm
	tv.name = "TVScreen"
	cafe.add_child(tv)
	tv.position = Vector3(30.4, 1.36, 51.27)
	add_interact("tv", Vector3(30.4, 1.35, 51.4), Vector3(0.6, 0.5, 0.4), "调查")

var _solid: Array = []

func _commit() -> void:
	var body := commit_geo(self)
	body.name = "WorldBody"
	# 地面
	var fl := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(W * CS + 20, 1.0, H * CS + 20)
	fl.shape = bx
	fl.position = Vector3(W * CS * 0.5, -0.5, H * CS * 0.5)
	body.add_child(fl)
	# 里世界铁丝网碰撞
	ow_body = StaticBody3D.new()
	ow_body.collision_layer = 0
	add_child(ow_body)
	var cs2 := CollisionShape3D.new()
	var sh2 := ConcavePolygonShape3D.new()
	sh2.backface_collision = true
	sh2.set_faces(ow_faces)
	cs2.shape = sh2
	ow_body.add_child(cs2)

## 把当前累积的几何（chunks / col_faces）生成网格与碰撞体，挂到 parent 下；最后一个子节点为 StaticBody3D
func commit_geo(parent: Node3D) -> StaticBody3D:
	for ck in chunks:
		var d: Dictionary = chunks[ck]
		var mesh := ArrayMesh.new()
		var i := 0
		for mk_ in d:
			var st: SurfaceTool = d[mk_]
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(i, mats[mk_])
			i += 1
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		parent.add_child(mi)
	chunks.clear()
	var body := StaticBody3D.new()
	body.name = "GeoBody"
	parent.add_child(body)
	if col_faces.size() > 0:
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(col_faces)
		cs.shape = sh
		body.add_child(cs)
	col_faces = PackedVector3Array()
	return body

func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(CS, CS)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for r in H:
		for c in W:
			if not MON_WALK.contains(ch(c, r)):
				astar.set_point_solid(Vector2i(c, r), true)
	for s in _solid:
		var v: Vector2i = s
		if astar.is_in_boundsv(v):
			astar.set_point_solid(v, true)

func set_ow_fences(on: bool) -> void:
	ow_body.collision_layer = 1 if on else 0
	astar.set_point_solid(Vector2i(29, 14), on)
	astar.set_point_solid(Vector2i(30, 14), on)
	astar.set_point_solid(Vector2i(31, 14), on)
	astar.set_point_solid(Vector2i(29, 29), on)
	astar.set_point_solid(Vector2i(30, 29), on)

## 怪物寻路：返回世界坐标路径点（室内关卡使用各自的细网格）
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var lv := level_at(from)
	if not lv.is_empty():
		return _level_path(lv, from, to)
	var a := cell_of(from)
	var b := cell_of(to)
	var out := PackedVector3Array()
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return out
	if astar.is_point_solid(a):
		a = _nearest_free(a)
	if astar.is_point_solid(b):
		b = _nearest_free(b)
	if a.x < 0 or b.x < 0:
		return out
	var pts := astar.get_point_path(a, b)
	for p in pts:
		out.append(Vector3(p.x, 0, p.y))
	return out

## 该点是否可供怪物行走
func walkable(p: Vector3) -> bool:
	var lv := level_at(p)
	if not lv.is_empty():
		var g: AStarGrid2D = lv.astar
		var c := _lcell(lv, p)
		return g.is_in_boundsv(c) and not g.is_point_solid(c)
	var c2 := cell_of(p)
	return astar.is_in_boundsv(c2) and not astar.is_point_solid(c2)

# ---------------------------------------------------------------- 室内关卡
var levels := {}
var cur_build: Dictionary = {}

func level_at(p: Vector3) -> Dictionary:
	if p.x < 400.0:
		return {}
	for id in levels:
		var lv: Dictionary = levels[id]
		if (lv.rect as Rect2).has_point(Vector2(p.x, p.z)):
			return lv
	return {}

func begin_level(id: String, origin: Vector3, size: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.name = "Level_" + id
	add_child(root)
	var lv := {"id": id, "origin": origin, "rect": Rect2(origin.x - 1.0, origin.z - 1.0, size.x + 2.0, size.y + 2.0), "root": root, "blocks": [], "cs": 0.5, "astar": null}
	levels[id] = lv
	cur_build = lv
	chunks.clear()
	col_faces = PackedVector3Array()
	return lv

## 记录导航障碍：中心、尺寸（xz）、yaw
func nav_block(c: Vector3, sz: Vector2, yaw := 0.0, tag := "") -> void:
	if cur_build.is_empty():
		return
	(cur_build.blocks as Array).append([Vector2(c.x, c.z), sz * 0.5, yaw, tag])

func end_level() -> void:
	var lv := cur_build
	var body := commit_geo(lv.root)
	# 地板碰撞
	var r: Rect2 = lv.rect
	var fl := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(r.size.x, 1.0, r.size.y)
	fl.shape = bx
	fl.position = Vector3(r.get_center().x, -0.5, r.get_center().y)
	body.add_child(fl)
	build_nav(lv)
	cur_build = {}

func _lcell(lv: Dictionary, p: Vector3) -> Vector2i:
	var r: Rect2 = lv.rect
	var cs: float = lv.cs
	return Vector2i(int(floor((p.x - r.position.x) / cs)), int(floor((p.z - r.position.y) / cs)))

func build_nav(lv: Dictionary) -> void:
	var r: Rect2 = lv.rect
	var cs: float = lv.cs
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, int(ceil(r.size.x / cs)), int(ceil(r.size.y / cs)))
	g.cell_size = Vector2(cs, cs)
	g.offset = r.position + Vector2(cs, cs) * 0.5
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	lv.astar = g
	_raster_nav(lv)

func _raster_nav(lv: Dictionary) -> void:
	var g: AStarGrid2D = lv.astar
	var r: Rect2 = lv.rect
	var cs: float = lv.cs
	var reg := g.region
	g.fill_solid_region(reg, false)
	# 边界
	for x in reg.size.x:
		g.set_point_solid(Vector2i(x, 0), true)
		g.set_point_solid(Vector2i(x, reg.size.y - 1), true)
	for y in reg.size.y:
		g.set_point_solid(Vector2i(0, y), true)
		g.set_point_solid(Vector2i(reg.size.x - 1, y), true)
	var pad := 0.22
	for b in lv.blocks:
		if b[3] == "open":
			continue
		var c: Vector2 = b[0]
		var h: Vector2 = b[1] + Vector2(pad, pad)
		var yaw: float = b[2]
		var ca := cos(yaw)
		var sa := sin(yaw)
		var ext := Vector2(abs(h.x * ca) + abs(h.y * sa), abs(h.x * sa) + abs(h.y * ca))
		var x0 := int(floor((c.x - ext.x - r.position.x) / cs))
		var x1 := int(ceil((c.x + ext.x - r.position.x) / cs))
		var y0 := int(floor((c.y - ext.y - r.position.y) / cs))
		var y1 := int(ceil((c.y + ext.y - r.position.y) / cs))
		for yy in range(max(y0, 0), min(y1 + 1, reg.size.y)):
			for xx in range(max(x0, 0), min(x1 + 1, reg.size.x)):
				var pc := r.position + Vector2((xx + 0.5) * cs, (yy + 0.5) * cs) - c
				# 旋转到局部（yaw 绕 Y：x' = x cos + z sin ...）
				var lx := pc.x * ca - pc.y * sa
				var lz := pc.x * sa + pc.y * ca
				if abs(lx) <= h.x and abs(lz) <= h.y:
					g.set_point_solid(Vector2i(xx, yy), true)

## 打开门后更新导航（tag 对应的障碍失效）
func nav_open(level_id: String, tag: String) -> void:
	if not levels.has(level_id):
		return
	var lv: Dictionary = levels[level_id]
	for b in lv.blocks:
		if b[3] == tag:
			b[3] = "open"
	_raster_nav(lv)

func _level_path(lv: Dictionary, from: Vector3, to: Vector3) -> PackedVector3Array:
	var g: AStarGrid2D = lv.astar
	var out := PackedVector3Array()
	if g == null:
		return out
	var a := _lcell(lv, from)
	var b := _lcell(lv, to)
	if not g.is_in_boundsv(a) or not g.is_in_boundsv(b):
		return out
	if g.is_point_solid(a):
		a = _lnearest(g, a)
	if g.is_point_solid(b):
		b = _lnearest(g, b)
	if a.x < 0 or b.x < 0:
		return out
	var pts := g.get_point_path(a, b)
	# 稀疏化：每 2 个点取 1 个（保留终点）
	for i in pts.size():
		if i % 2 == 1 or i == pts.size() - 1:
			out.append(Vector3(pts[i].x, 0, pts[i].y))
	return out

func _lnearest(g: AStarGrid2D, v: Vector2i) -> Vector2i:
	for rad in range(1, 5):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := v + Vector2i(dx, dy)
				if g.is_in_boundsv(q) and not g.is_point_solid(q):
					return q
	return Vector2i(-1, -1)

func _nearest_free(v: Vector2i) -> Vector2i:
	for rad in range(1, 4):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := v + Vector2i(dx, dy)
				if astar.is_in_boundsv(q) and not astar.is_point_solid(q):
					return q
	return Vector2i(-1, -1)

# ---------------------------------------------------------------- 交互区域
func add_interact(id: String, pos: Vector3, size: Vector3, prompt: String, yaw := 0.0) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	a.add_child(cs)
	a.position = pos
	a.rotation.y = yaw
	a.set_meta("iid", id)
	a.set_meta("prompt", prompt)
	interact_root.add_child(a)
	return a

# ---------------------------------------------------------------- 表里世界
func set_ow(v: float) -> void:
	ow = v
	for m in mat_list:
		(m as ShaderMaterial).set_shader_parameter("ow_mix", v)
	var g: StandardMaterial3D = mats["glass"]
	g.albedo_color = Color(0.04, 0.045, 0.05).lerp(Color(0.05, 0.015, 0.01), v)
	var gc: StandardMaterial3D = mats["glass_clear"]
	gc.albedo_color = Color(0.55, 0.6, 0.62, 0.16).lerp(Color(0.25, 0.08, 0.05, 0.45), v)
