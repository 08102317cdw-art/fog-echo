extends Node3D
## 第一人称武器：钢管（近战，由 player 处理）/ 手枪 / 步枪。
## 射击（射线 + 怪物骨骼胶囊）、换弹、瞄准（步枪瞄准镜）、后坐力、枪口火光、弹孔、噪音。

const VM = preload("res://shaders/viewmodel.gdshader")
const ORDER := ["pipe", "pistol", "rifle"]
const NAMES := {"pipe": "钢管", "pistol": "手枪", "rifle": "步枪"}
const MAG := {"pistol": 10, "rifle": 5}
const FOV := 72.0
const RELOAD := {"pistol": 1.6, "rifle": 2.6}
const RS := 0.85  # 步枪模型缩放

var p: CharacterBody3D
var cam: Camera3D
var cur := ""
var want := ""
var owned := {"pipe": false, "pistol": false, "rifle": false}
var mag := {"pistol": 0, "rifle": 0}
var reserve := {"pistol": 0, "rifle": 0}
var holders := {}
var parts := {}
var poses := {}
var muzzles := {}
var aim := 0.0
var aiming := false
var scoped := false
var cool := 0.0
var reload_t := 0.0
var reload_len := 1.0
var bolt_t := 0.0
var swap_t := 0.0
var swap_phase := 0
var kick := 0.0
var flash_t := 0.0
var flash_light: OmniLight3D
var flash_mesh: MeshInstance3D
var holes: Array = []
var hole_mat: StandardMaterial3D
var sparks: CPUParticles3D
var puff: CPUParticles3D
var hit_mark := 0.0
var head_mark := false
var sway := Vector2.ZERO
var last_yaw := 0.0
var last_pitch := 0.0
var recoil_pitch := 0.0
var compat := false
var white: ImageTexture
var part_rest := {}
var mag_dropped := false
var lhand: Node3D
var push_k := 0.0

func setup(pl: CharacterBody3D, c: Camera3D) -> void:
	p = pl
	cam = c
	compat = RenderingServer.get_rendering_device() == null
	var im := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	white = ImageTexture.create_from_image(im)
	_build_pistol()
	_build_rifle()
	_build_fx()
	_build_push_hand()

# ------------------------------------------------------------------ 模型
func _vm_mat(src: Material) -> Material:
	var sm := ShaderMaterial.new()
	sm.shader = VM
	sm.set_shader_parameter("grime_tex", load("res://assets/tex/grime.png"))
	sm.set_shader_parameter("depth_pull", 0.0 if compat else 0.9)
	sm.set_shader_parameter("albedo_tex", white)
	var b := src as BaseMaterial3D
	if b == null:
		return sm
	sm.set_shader_parameter("albedo", b.albedo_color)
	if b.albedo_texture:
		sm.set_shader_parameter("albedo_tex", b.albedo_texture)
	if b.normal_enabled and b.normal_texture:
		sm.set_shader_parameter("normal_tex", b.normal_texture)
	else:
		sm.set_shader_parameter("use_normal", 0.0)
	sm.set_shader_parameter("roughness", b.roughness)
	if b.roughness_texture:
		sm.set_shader_parameter("rough_tex", b.roughness_texture)
		sm.set_shader_parameter("rough_ch", _ch(b.roughness_texture_channel))
	sm.set_shader_parameter("metallic", b.metallic)
	if b.metallic_texture:
		sm.set_shader_parameter("metal_tex", b.metallic_texture)
		sm.set_shader_parameter("metal_ch", _ch(b.metallic_texture_channel))
	else:
		sm.set_shader_parameter("metal_ch", Vector4(1, 0, 0, 0))
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		sm.set_shader_parameter("albedo", Color(0.05, 0.07, 0.08))
		sm.set_shader_parameter("albedo_tex", white)
		sm.set_shader_parameter("roughness", 0.06)
		sm.set_shader_parameter("rough_tex", white)
		sm.set_shader_parameter("metallic", 0.5)
		sm.set_shader_parameter("use_normal", 0.0)
		sm.set_shader_parameter("grime", 0.0)
	return sm

func _ch(c: int) -> Vector4:
	match c:
		0: return Vector4(1, 0, 0, 0)
		1: return Vector4(0, 1, 0, 0)
		2: return Vector4(0, 0, 1, 0)
		3: return Vector4(0, 0, 0, 1)
	return Vector4(0.333, 0.333, 0.334, 0)

func _plain(c: Color, rough := 0.85) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = VM
	sm.set_shader_parameter("albedo_tex", white)
	sm.set_shader_parameter("albedo", c)
	sm.set_shader_parameter("roughness", rough)
	sm.set_shader_parameter("metallic", 0.0)
	sm.set_shader_parameter("metal_ch", Vector4(1, 0, 0, 0))
	sm.set_shader_parameter("use_normal", 0.0)
	sm.set_shader_parameter("grime_tex", load("res://assets/tex/grime.png"))
	sm.set_shader_parameter("grime", 0.35)
	sm.set_shader_parameter("depth_pull", 0.0 if compat else 0.9)
	return sm

## 载入 Poly Haven 枪模型。only：保留的子网格名后缀。返回 [holder, inst, parts]
func _load_gun(id: String, file: String, only: Array, scale: float, grip: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = "VM_" + id
	holder.visible = false
	add_child(holder)
	var ps: PackedScene = load("res://assets/ph/%s/%s_1k.gltf" % [file, file])
	var inst: Node3D = ps.instantiate()
	holder.add_child(inst)
	var bs := Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * scale)
	inst.transform = Transform3D(bs, -(bs * grip))
	var pd := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		var keep := false
		for o in only:
			if nm.ends_with(o):
				keep = true
				pd[o] = m
		if not keep:
			m.visible = false
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in m.mesh.get_surface_count():
			m.set_surface_override_material(s, _vm_mat(m.get_active_material(s)))
		part_rest[id + ":" + o_key(nm, only)] = m.position
	parts[id] = pd
	holders[id] = holder
	return holder

func o_key(nm: String, only: Array) -> String:
	for o in only:
		if nm.ends_with(o):
			return o
	return nm

func _limb(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = a.distance_to(b)
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var fw := side.cross(up).normalized()
	mi.transform = Transform3D(Basis(side, up, fw), (a + b) * 0.5)

func _fist(parent: Node3D, c: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.034
	cap.height = 0.115
	cap.radial_segments = 10
	cap.rings = 3
	mi.mesh = cap
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = c
	mi.rotation = rot
	parent.add_child(mi)

func _build_pistol() -> void:
	var h := _load_gun("pistol", "service_pistol", ["pistol_a", "slide_a", "magazine_loaded", "hammer_a", "trigger_a"], 1.0, Vector3(-0.085, -0.015, 0.0))
	var glove := _plain(Color(0.085, 0.072, 0.063), 0.8)
	var sleeve := _plain(Color(0.13, 0.13, 0.14), 0.95)
	_fist(h, Vector3(0.0, -0.035, 0.008), Vector3(0.35, 0, 0), glove)
	_fist(h, Vector3(-0.03, -0.045, -0.012), Vector3(0.5, 0, 0.5), glove)
	_limb(h, Vector3(0.01, -0.08, 0.05), Vector3(0.07, -0.26, 0.36), 0.04, 0.05, sleeve)
	_limb(h, Vector3(-0.045, -0.08, 0.03), Vector3(-0.2, -0.27, 0.32), 0.04, 0.05, sleeve)
	poses["pistol"] = {"hip": Vector3(0.15, -0.175, -0.3), "hip_r": Vector3(0.0, 0.05, 0.0),
		"ads": Vector3(0.0, -0.1, -0.27), "ads_r": Vector3.ZERO}
	var mz := Node3D.new()
	mz.position = Vector3(0, 0.06, -0.27)
	h.add_child(mz)
	muzzles["pistol"] = mz

func _build_rifle() -> void:
	var h := _load_gun("rifle", "bolt_action_rifle_7_62", ["bolt_action_rifle_7_62", "_scope", "_wrap", "_bolt_a", "_trigger"], RS, Vector3(-0.35, -0.045, 0.0))
	var glove := _plain(Color(0.085, 0.072, 0.063), 0.8)
	var sleeve := _plain(Color(0.13, 0.13, 0.14), 0.95)
	_fist(h, Vector3(0.0, -0.03, 0.01), Vector3(0.45, 0, 0), glove)
	_fist(h, Vector3(-0.005, -0.045, -0.3), Vector3(1.2, 0, 0.3), glove)
	_limb(h, Vector3(0.01, -0.07, 0.06), Vector3(0.08, -0.25, 0.33), 0.04, 0.05, sleeve)
	_limb(h, Vector3(-0.02, -0.08, -0.27), Vector3(-0.2, -0.3, 0.02), 0.04, 0.05, sleeve)
	poses["rifle"] = {"hip": Vector3(0.16, -0.19, -0.2), "hip_r": Vector3(0.02, 0.06, 0.0),
		"ads": Vector3(0.0, -0.095, -0.06), "ads_r": Vector3.ZERO}
	var mz := Node3D.new()
	mz.position = Vector3(0, 0.05, -0.8)
	h.add_child(mz)
	muzzles["rifle"] = mz

## 推开用的左手（手掌 + 前臂）
func _build_push_hand() -> void:
	lhand = Node3D.new()
	lhand.name = "VM_push"
	lhand.visible = false
	add_child(lhand)
	var glove := _plain(Color(0.085, 0.072, 0.063), 0.8)
	var sleeve := _plain(Color(0.13, 0.13, 0.14), 0.95)
	var palm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.085, 0.1, 0.03)
	palm.mesh = bm
	palm.material_override = glove
	palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	palm.position = Vector3(0, 0.02, 0)
	lhand.add_child(palm)
	for i in 4:
		var f := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.011
		cm.height = 0.07
		cm.radial_segments = 6
		cm.rings = 2
		f.mesh = cm
		f.material_override = glove
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = Vector3(-0.03 + i * 0.02, 0.095 - abs(i - 1.5) * 0.006, -0.004)
		f.rotation.x = -0.15
		lhand.add_child(f)
	var th := MeshInstance3D.new()
	var tc := CapsuleMesh.new()
	tc.radius = 0.012
	tc.height = 0.06
	th.mesh = tc
	th.material_override = glove
	th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	th.position = Vector3(0.05, 0.03, 0.0)
	th.rotation.z = -0.9
	lhand.add_child(th)
	_limb(lhand, Vector3(0.0, -0.02, 0.02), Vector3(0.02, -0.12, 0.36), 0.035, 0.048, sleeve)

func _build_fx() -> void:
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.72, 0.38)
	flash_light.omni_range = 7.0
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	flash_light.light_volumetric_fog_energy = 0.6
	flash_light.visible = false
	add_child(flash_light)
	flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	flash_mesh.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.no_depth_test = true
	fm.albedo_texture = _star_tex()
	fm.albedo_color = Color(1.0, 0.8, 0.5)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mesh.material_override = fm
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.visible = false
	add_child(flash_mesh)
	hole_mat = StandardMaterial3D.new()
	hole_mat.albedo_texture = _hole_tex()
	hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hole_mat.roughness = 1.0

func _star_tex() -> ImageTexture:
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rs := RandomNumberGenerator.new()
	rs.seed = 7
	var spikes: Array = []
	for i in 6:
		spikes.append([rs.randf() * TAU, rs.randf_range(0.6, 1.0)])
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := v.length()
			var a := atan2(v.y, v.x)
			var s := 0.0
			for sp in spikes:
				var da: float = abs(wrapf(a - float(sp[0]), -PI, PI))
				s = max(s, clamp(1.0 - da * 9.0, 0.0, 1.0) * clamp(float(sp[1]) - r, 0.0, 1.0))
			var core: float = clamp(1.0 - r * 2.2, 0.0, 1.0)
			var val: float = clamp(core * 1.4 + s * 1.2, 0.0, 1.0)
			im.set_pixel(x, y, Color(1.0, 0.85 + 0.15 * core, 0.6 + 0.4 * core, val))
	return ImageTexture.create_from_image(im)

func _hole_tex() -> ImageTexture:
	var n := 32
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rs := RandomNumberGenerator.new()
	rs.seed = 11
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := v.length() + rs.randf_range(-0.06, 0.06)
			var a := 0.0
			var c := 0.02
			if r < 0.28:
				a = 1.0
			elif r < 0.75:
				a = clamp((0.75 - r) / 0.47, 0.0, 1.0) * 0.75
				c = 0.12 + rs.randf() * 0.08
			im.set_pixel(x, y, Color(c, c * 0.95, c * 0.9, a))
	return ImageTexture.create_from_image(im)

# ------------------------------------------------------------------ 状态
func is_gun() -> bool:
	return cur == "pistol" or cur == "rifle"

func busy() -> bool:
	return swap_phase != 0 or reload_t > 0.0

func give(id: String) -> void:
	owned[id] = true

func equip(id: String, instant := false) -> void:
	if not owned.get(id, false):
		return
	if instant:
		_show(cur, false)
		cur = id
		want = id
		swap_phase = 0
		_show(cur, true)
		return
	if id == want:
		return
	want = id
	reload_t = 0.0
	aim = min(aim, 0.3)
	if cur == "":
		cur = id
		_show(cur, true)
		swap_phase = 2
		swap_t = 0.25
	else:
		swap_phase = 1
		swap_t = 0.18
	Game.sfx("click", -14.0, 0.7)

func cycle(dirn: int) -> void:
	var list: Array = []
	for id in ORDER:
		if owned[id]:
			list.append(id)
	if list.size() < 2:
		return
	var i := list.find(want if want != "" else cur)
	equip(list[(i + dirn + list.size()) % list.size()])

func _show(id: String, on: bool) -> void:
	if id == "pipe":
		p.pipe_root.visible = on and p.has_pipe
	elif holders.has(id):
		(holders[id] as Node3D).visible = on

func sens_mult() -> float:
	if cur == "rifle":
		return lerp(1.0, 0.32, aim * aim)
	if cur == "pistol":
		return lerp(1.0, 0.75, aim)
	return 1.0

func speed_mult() -> float:
	return lerp(1.0, 0.55, aim)

func spread() -> float:
	var mv := Vector2(p.velocity.x, p.velocity.z).length()
	if cur == "rifle":
		return lerp(0.065, 0.0006, aim) + mv * 0.008 * (1.0 - aim * 0.7) + kick * 0.02
	return lerp(0.03, 0.004, aim) + mv * 0.005 + kick * 0.03

func start_reload() -> void:
	if not is_gun() or busy():
		return
	if mag[cur] >= MAG[cur]:
		return
	if reserve[cur] <= 0:
		if Game.main:
			Game.main.ui.message("没有备用的子弹了。")
		return
	reload_len = RELOAD[cur]
	reload_t = reload_len
	bolt_t = 0.0
	mag_dropped = false
	Game.sfx("reload_pistol" if cur == "pistol" else "reload_rifle", -3.0)

func _finish_reload() -> void:
	var n: int = min(MAG[cur] - mag[cur], reserve[cur])
	mag[cur] += n
	reserve[cur] -= n
	if cur == "rifle":
		Game.sfx("rifle_bolt", -5.0, 1.05)

## 每个物理帧由 player 调用（处理输入）
func input_tick(dt: float, can: bool) -> void:
	cool = max(cool - dt, 0.0)
	if can:
		if Input.is_action_just_pressed("weapon_1"):
			equip("pipe")
		elif Input.is_action_just_pressed("weapon_2"):
			equip("pistol")
		elif Input.is_action_just_pressed("weapon_3"):
			equip("rifle")
		elif Input.is_action_just_pressed("weapon_next"):
			cycle(1)
		elif Input.is_action_just_pressed("weapon_prev"):
			cycle(-1)
		if Input.is_action_just_pressed("reload"):
			start_reload()
	aiming = can and is_gun() and Input.is_action_pressed("aim") and not busy()

func fire() -> bool:
	if not is_gun() or busy() or cool > 0.0 or bolt_t > 0.0:
		return false
	var pistol := cur == "pistol"
	if mag[cur] <= 0:
		Game.sfx("gun_empty", -4.0)
		cool = 0.3
		if reserve[cur] > 0:
			start_reload()
		elif Game.main:
			Game.main.ui.message("没有子弹了。")
		return false
	mag[cur] -= 1
	cool = 0.28 if pistol else 0.25
	if not pistol and mag[cur] > 0:
		bolt_t = 1.15
	elif not pistol:
		bolt_t = 0.5
	if pistol:
		Game.sfx("gun_pistol%d" % (randi() % 3), 0.0, randf_range(0.95, 1.05))
	else:
		Game.sfx("gun_rifle%d" % (randi() % 2), 2.0, randf_range(0.96, 1.03))
	var shell_pos := p.global_position + Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4))
	get_tree().create_timer(randf_range(0.35, 0.55)).timeout.connect(func():
		Game.sfx3d("shell%d" % (randi() % 3), shell_pos, -9.0, randf_range(0.9, 1.15), 2.0, 12.0))
	_noise(26.0 if pistol else 36.0)
	# 枪口火光
	flash_t = 0.055
	var mz: Node3D = muzzles[cur]
	flash_light.global_position = mz.global_position
	flash_light.light_energy = 3.5 if pistol else 5.0
	flash_light.visible = true
	flash_mesh.global_position = mz.global_position
	flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.2) * (1.0 if pistol else 1.5)
	flash_mesh.rotation.z = randf() * TAU
	flash_mesh.visible = not scoped
	# 后坐
	kick = 1.0
	var kp := 0.022 if pistol else 0.055
	p.pitch = clamp(p.pitch + kp, -1.45, 1.45)
	recoil_pitch += kp * 0.55
	p.yaw += randf_range(-1.0, 1.0) * (0.006 if pistol else 0.012)
	p.shake = max(p.shake, 0.08 if pistol else 0.2)
	# 射线
	var spr := spread()
	var b := cam.global_transform.basis
	var a := randf() * TAU
	var rr := sqrt(randf()) * spr
	var dir := (-b.z + b.x * cos(a) * rr + b.y * sin(a) * rr).normalized()
	var dmg := randf_range(24.0, 30.0) if pistol else randf_range(100.0, 120.0)
	_shoot(cam.global_position, dir, dmg, 1 if pistol else 2)
	return true

func _noise(r: float) -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		var mm := m as Node3D
		if mm.global_position.distance_to(p.global_position) < r and m.has_method("hear_noise"):
			m.call("hear_noise", p.global_position)

static func ray_capsule(o: Vector3, d: Vector3, maxd: float, a: Vector3, b: Vector3, r: float) -> float:
	var u := d * maxd
	var v := b - a
	var w0 := o - a
	var A := u.dot(u)
	var B := u.dot(v)
	var C := v.dot(v)
	var D := u.dot(w0)
	var E := v.dot(w0)
	var sc := 0.0
	var tc := 0.0
	var den := A * C - B * B
	if den > 1e-9:
		sc = clamp((B * E - C * D) / den, 0.0, 1.0)
	else:
		sc = clamp(-D / A, 0.0, 1.0) if A > 1e-9 else 0.0
	tc = clamp((B * sc + E) / C, 0.0, 1.0) if C > 1e-9 else 0.0
	sc = clamp((tc * B - D) / A, 0.0, 1.0) if A > 1e-9 else 0.0
	var p1 := o + u * sc
	var p2 := a + v * tc
	var dist := p1.distance_to(p2)
	if dist > r:
		return -1.0
	return max(sc * maxd - sqrt(max(r * r - dist * dist, 0.0)), 0.0)

func _shoot(o: Vector3, d: Vector3, dmg: float, pierce: int) -> void:
	var maxd := 70.0
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(o, o + d * maxd, 1)
	q.exclude = [p.get_rid()]
	var res := space.intersect_ray(q)
	var wall_d := maxd
	if res:
		wall_d = o.distance_to(res.position)
	var hits: Array = []
	for grp in ["monster"]:
		for m in get_tree().get_nodes_in_group(grp):
			if not m.has_method("shot_shapes") or not m.call("is_hittable"):
				continue
			var best := -1.0
			var bm := 1.0
			for s in m.call("shot_shapes"):
				var tt := ray_capsule(o, d, wall_d, s[0], s[1], s[2])
				if tt < 0.0:
					continue
				var sm: float = s[3]
				if best < 0.0 or tt < best - 0.04 or (abs(tt - best) <= 0.04 and sm > bm):
					best = tt
					bm = sm
			if best >= 0.0:
				hits.append([best, m, bm])
	hits.sort_custom(func(x, y): return x[0] < y[0])
	var n := 0
	for h in hits:
		if n >= pierce:
			break
		var pt: Vector3 = o + d * float(h[0])
		var mult: float = h[2]
		h[1].call("take_shot", dmg * (1.0 if n == 0 else 0.75), p.global_position, pt, mult)
		Game.sfx3d("bullet_flesh%d" % (randi() % 3), pt, 0.0, randf_range(0.9, 1.1), 3.0, 30.0)
		_puff(pt, d)
		hit_mark = 1.0
		head_mark = mult > 1.5
		n += 1
	if res and n < pierce:
		_impact(res.position, res.normal)

func _puff(pt: Vector3, d: Vector3) -> void:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.amount = 14
	ps.lifetime = 0.5
	ps.explosiveness = 1.0
	ps.direction = -d
	ps.spread = 50.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 2.6
	ps.gravity = Vector3(0, -6.0, 0)
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.radial_segments = 4
	sm.rings = 2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.015, 0.01)
	m.roughness = 0.3
	sm.material = m
	ps.mesh = sm
	Game.world.add_child(ps)
	ps.global_position = pt
	ps.emitting = true
	get_tree().create_timer(1.2).timeout.connect(ps.queue_free)

func _impact(pos: Vector3, nrm: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var sz := randf_range(0.045, 0.06)
	qm.size = Vector2(sz, sz)
	mi.mesh = qm
	mi.material_override = hole_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(mi)
	var z := nrm.normalized()
	var x := z.cross(Vector3.UP)
	if x.length() < 0.1:
		x = z.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := z.cross(x).normalized()
	mi.global_transform = Transform3D(Basis(x, y, z).rotated(z, randf() * TAU), pos + z * 0.004)
	holes.append(mi)
	if holes.size() > 40:
		var old: Node = holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.amount = 10
	ps.lifetime = 0.35
	ps.explosiveness = 1.0
	ps.direction = nrm
	ps.spread = 35.0
	ps.initial_velocity_min = 1.5
	ps.initial_velocity_max = 4.0
	ps.gravity = Vector3(0, -9.8, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.008, 0.008, 0.03)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.7, 0.35)
	bm.material = m
	ps.mesh = bm
	ps.particle_flag_align_y = true
	Game.world.add_child(ps)
	ps.global_position = pos + nrm * 0.02
	ps.emitting = true
	get_tree().create_timer(0.8).timeout.connect(ps.queue_free)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 6
	dust.lifetime = 0.9
	dust.explosiveness = 1.0
	dust.direction = nrm
	dust.spread = 25.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.9
	dust.gravity = Vector3(0, -0.4, 0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	var dm := QuadMesh.new()
	dm.size = Vector2(0.06, 0.06)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_texture = load("res://assets/tex/dot.png")
	dmat.albedo_color = Color(0.5, 0.48, 0.45, 0.35)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.material = dmat
	dust.mesh = dm
	Game.world.add_child(dust)
	dust.global_position = pos + nrm * 0.03
	dust.emitting = true
	get_tree().create_timer(1.3).timeout.connect(dust.queue_free)
	if randf() < 0.35:
		Game.sfx3d("ricochet%d" % (randi() % 3), pos, -6.0, randf_range(0.9, 1.1), 3.0, 30.0)
	else:
		Game.sfx3d("hit_metal", pos, -12.0, randf_range(1.5, 1.9), 2.0, 20.0)

# ------------------------------------------------------------------ 每帧动画
func _process(dt: float) -> void:
	if p == null:
		return
	# 切换
	if swap_phase == 1:
		swap_t -= dt
		if swap_t <= 0.0:
			_show(cur, false)
			cur = want
			_show(cur, true)
			swap_phase = 2
			swap_t = 0.25
	elif swap_phase == 2:
		swap_t -= dt
		if swap_t <= 0.0:
			swap_phase = 0
	var lower := 0.0
	if swap_phase == 1:
		lower = 1.0 - swap_t / 0.18
	elif swap_phase == 2:
		lower = swap_t / 0.25
	p.pipe_lower = (lower * 0.35 if cur == "pipe" else 0.0) + push_k * 0.12
	# 推开的左手
	lhand.visible = push_k > 0.01 and not p.dead
	if lhand.visible:
		var e := ease(push_k, -1.6)
		lhand.position = Vector3(-0.32, -0.42, -0.12).lerp(Vector3(-0.06, -0.12, -0.42), e)
		lhand.rotation = Vector3(0.9, 0.5, 0.4).lerp(Vector3(0.12, 0.05, 0.1), e)
	# 换弹
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			reload_t = 0.0
			_finish_reload()
	if bolt_t > 0.0:
		var prev := bolt_t
		bolt_t = max(bolt_t - dt, 0.0)
		if prev > 0.82 and bolt_t <= 0.82 and cur == "rifle" and reload_t <= 0.0:
			Game.sfx("rifle_bolt", -4.0, randf_range(0.97, 1.05))
	# 瞄准
	var aspd := 1.0 / (0.16 if cur == "pistol" else 0.24)
	aim = move_toward(aim, 1.0 if aiming else 0.0, dt * aspd)
	scoped = cur == "rifle" and aim > 0.92 and p.enabled and not p.dead
	var tfov := FOV
	if cur == "pistol":
		tfov = lerp(FOV, 56.0, ease(aim, -1.6))
	elif cur == "rifle":
		tfov = lerp(FOV, 52.0, ease(aim, -1.6)) if not scoped else 24.0
	cam.fov = lerp(cam.fov, tfov, clamp(dt * 20.0, 0.0, 1.0)) if not scoped else 24.0
	kick = move_toward(kick, 0.0, dt * (7.0 if cur == "pistol" else 3.5))
	if recoil_pitch > 0.0:
		var rec: float = min(recoil_pitch, dt * 0.25)
		recoil_pitch -= rec
		p.pitch -= rec
	hit_mark = max(hit_mark - dt * 5.0, 0.0)
	# 枪口火光
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			flash_light.visible = false
			flash_mesh.visible = false
	# 晃动
	if dt > 0.0:
		var dy := wrapf(p.yaw - last_yaw, -PI, PI) / dt
		var dp: float = (p.pitch - last_pitch) / dt
		sway = sway.lerp(Vector2(clamp(dy * 0.012, -0.06, 0.06), clamp(dp * 0.012, -0.06, 0.06)), clamp(dt * 8.0, 0.0, 1.0))
	last_yaw = p.yaw
	last_pitch = p.pitch
	if not is_gun():
		return
	var h: Node3D = holders[cur]
	h.visible = not scoped and not p.dead
	var ps: Dictionary = poses[cur]
	var ea := ease(aim, -1.8)
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	var amp: float = clamp(spd / 2.3, 0.0, 1.6) * (1.0 - ea * 0.85)
	var bob := Vector3(cos(p.bob) * 0.011 * amp, sin(p.bob * 2.0) * 0.009 * amp, 0.0)
	var pos: Vector3 = (ps.hip as Vector3).lerp(ps.ads, ea) + bob
	var rot: Vector3 = (ps.hip_r as Vector3).lerp(ps.ads_r, ea)
	pos += Vector3(-sway.x, sway.y, 0.0) * 0.35 * (1.0 - ea * 0.8)
	rot += Vector3(-sway.y * 0.6, sway.x * 0.8, 0.0) * (1.0 - ea * 0.7)
	# 后坐
	var kk := kick * kick
	if cur == "pistol":
		rot.x += kk * 0.32
		pos.z += kk * 0.045
		pos.y += kk * 0.012
	else:
		rot.x += kk * 0.22
		pos.z += kk * 0.09
	# 跑步时枪口下压
	if Input.is_action_pressed("run") and spd > 3.2 and aim < 0.1:
		rot += Vector3(-0.35, 0.5, 0.25)
		pos += Vector3(-0.03, -0.04, 0.03)
	# 换弹动作
	if reload_t > 0.0:
		var r := 1.0 - reload_t / reload_len
		var env: float = sin(clamp(r * 1.15, 0.0, 1.0) * PI)
		if cur == "pistol":
			rot += Vector3(0.35, 0.0, 0.6) * env
			pos += Vector3(-0.04, -0.05, 0.02) * env
			_pistol_reload_parts(r)
		else:
			rot += Vector3(0.25, -0.2, -0.5) * env
			pos += Vector3(-0.06, -0.03, 0.04) * env
			rot.x += sin(r * 28.0) * 0.015 * env
			_bolt_part(clamp(r * 6.0, 0.0, 1.0) * clamp((1.0 - r) * 8.0, 0.0, 1.0))
	elif cur == "rifle":
		# 拉栓
		var b := 0.0
		if bolt_t > 0.0:
			var bt := 1.15 - bolt_t
			b = clamp((bt - 0.3) / 0.22, 0.0, 1.0) * clamp((0.85 - bt) / 0.22, 0.0, 1.0)
			var e2: float = clamp((bt - 0.2) / 0.2, 0.0, 1.0) * clamp((1.0 - bt) / 0.2, 0.0, 1.0)
			rot += Vector3(0.05, -0.1, -0.22) * e2 * (1.0 - ea * 0.6)
		_bolt_part(b)
	h.position = h.position.lerp(pos, clamp(dt * 18.0, 0.0, 1.0))
	h.rotation = h.rotation.lerp(rot, clamp(dt * 18.0, 0.0, 1.0))
	h.position.y -= lower * 0.32 + push_k * 0.06
	# 手枪套筒
	if cur == "pistol" and reload_t <= 0.0:
		var sl: MeshInstance3D = parts.pistol.get("slide_a")
		if sl:
			sl.position = (part_rest.get("pistol:slide_a", Vector3.ZERO) as Vector3) + Vector3(-0.028 * clamp(kick * 1.6, 0.0, 1.0), 0, 0)

func _pistol_reload_parts(r: float) -> void:
	var mg: MeshInstance3D = parts.pistol.get("magazine_loaded")
	var sl: MeshInstance3D = parts.pistol.get("slide_a")
	var mr: Vector3 = part_rest.get("pistol:magazine_loaded", Vector3.ZERO)
	var sr: Vector3 = part_rest.get("pistol:slide_a", Vector3.ZERO)
	if mg:
		var drop := 0.0
		if r < 0.45:
			drop = clamp((r - 0.18) / 0.12, 0.0, 1.0)
		else:
			drop = 1.0 - clamp((r - 0.5) / 0.15, 0.0, 1.0)
		mg.position = mr + Vector3(0, -0.16 * drop, 0)
		mg.visible = drop < 0.95
	if sl:
		var rack: float = clamp((r - 0.72) / 0.08, 0.0, 1.0) * clamp((0.9 - r) / 0.08, 0.0, 1.0)
		sl.position = sr + Vector3(-0.03 * rack, 0, 0)

func _bolt_part(b: float) -> void:
	var bo: MeshInstance3D = parts.rifle.get("_bolt_a")
	if bo:
		var br: Vector3 = part_rest.get("rifle:_bolt_a", Vector3.ZERO)
		bo.position = br + Vector3(-0.07 * b, 0.0, 0.0)
		bo.rotation.x = -0.9 * clamp(b * 2.0, 0.0, 1.0)

# ------------------------------------------------------------------ 存档
func save_state() -> Dictionary:
	return {"owned": owned.duplicate(), "mag": mag.duplicate(), "reserve": reserve.duplicate(), "cur": want if want != "" else cur}

func load_state(d: Dictionary) -> void:
	var o: Dictionary = d.get("owned", {})
	for k in o:
		owned[k] = o[k]
	var m: Dictionary = d.get("mag", {})
	for k in m:
		mag[k] = int(m[k])
	var r: Dictionary = d.get("reserve", {})
	for k in r:
		reserve[k] = int(r[k])
	var c: String = d.get("cur", "")
	if c != "" and owned.get(c, false):
		equip(c, true)
