extends CharacterBody3D
## 恶犬：程序雕刻蒙皮网格 + 程序四足步态。成群出没，绕圈后扑咬；扑咬前摇可被“推开”反击

signal killed(id: String)

enum S { IDLE, WANDER, ALERT, CHASE, CIRCLE, LEAP, RECOVER, STAGGER, DOWN, DEAD, EAT }

const PELVIS := 0
const SPINE := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const JAW := 5
const TAIL1 := 6
const TAIL2 := 7
# 腿：[上, 下, 爪]，顺序 FL, HL, FR, HR
const LEG := [[8, 9, 10], [11, 12, 13], [14, 15, 16], [17, 18, 19]]
const NB := 20

static var _mesh: ArrayMesh
static var _bones: Array
static var _skin: Skin
static var _shader: Shader
static var _flesh: Texture2D
static var _grime: Texture2D
static var _blood: Texture2D

var mid := ""
var state := S.IDLE
var hp := 55.0
var t_state := 0.0
var home := Vector3.ZERO
var yaw := 0.0
var path := PackedVector3Array()
var path_i := 0
var repath_t := 0.0
var sense_t := 0.0
var sees := false
var lost_t := 0.0
var leap_cd := 1.5
var circle_dir := 1.0
var leap_dir := Vector3.ZERO
var bit := false
var knock := Vector3.ZERO
var wander_target := Vector3.ZERO
var bark_cd := 0.0
var growl_t := 0.0
var hurt_v := 0.0
var gait := 0.0
var cur_speed := 0.0
var air := 0.0
var jaw_v := 0.0
var head_look := Vector2.ZERO
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var preview := ""
var eating := false
var hunt := false
var pack_delay := 0.0
var rs := RandomNumberGenerator.new()

var visual: Node3D
var skel: Skeleton3D
var mi: MeshInstance3D
var mat: ShaderMaterial
var voice: AudioStreamPlayer3D
var blood_fx: CPUParticles3D
var rest := PackedVector3Array()

static func _load() -> void:
	if _mesh:
		return
	_mesh = load("res://assets/models/dog.res")
	_bones = _mesh.get_meta("bones")
	_skin = Skin.new()
	for i in _bones.size():
		_skin.add_bind(i, Transform3D(Basis(), -(_bones[i][2] as Vector3)))
	_shader = load("res://shaders/flesh2.gdshader")
	_flesh = load("res://assets/tex/flesh.png")
	_grime = load("res://assets/tex/grime.png")
	_blood = load("res://assets/tex/blood.png")

func setup(id: String, pos: Vector3, yaw_deg: float) -> void:
	mid = id
	position = pos
	home = pos
	yaw = deg_to_rad(yaw_deg)

func _ready() -> void:
	_load()
	rs.seed = hash(mid) + int(position.x * 7.0)
	add_to_group("monster")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.26
	cs.shape = sp
	cs.position.y = 0.36
	add_child(cs)
	mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("flesh_tex", _flesh)
	mat.set_shader_parameter("grime_tex", _grime)
	mat.set_shader_parameter("seed", rs.randf() * 10.0)
	mat.set_shader_parameter("writhe", 0.25)
	mat.set_shader_parameter("skin_pale", Color(0.26, 0.21, 0.18))
	mat.set_shader_parameter("skin_dark", Color(0.07, 0.05, 0.045))
	mat.set_shader_parameter("worm_a", Vector4(0, -5, 0, 0))
	mat.set_shader_parameter("worm_b", Vector4(0, -5, 0, 0))
	mat.set_shader_parameter("raw_c", Color(0.22, 0.03, 0.025))
	visual = Node3D.new()
	visual.scale = Vector3.ONE * rs.randf_range(0.95, 1.08)
	add_child(visual)
	skel = Skeleton3D.new()
	visual.add_child(skel)
	rest.resize(NB)
	for i in NB:
		skel.add_bone(_bones[i][0])
	for i in NB:
		var p: int = _bones[i][1]
		var h: Vector3 = _bones[i][2]
		var r := h - ((_bones[p][2] as Vector3) if p >= 0 else Vector3.ZERO)
		if p >= 0:
			skel.set_bone_parent(i, p)
		rest[i] = r
		skel.set_bone_rest(i, Transform3D(Basis(), r))
		skel.set_bone_pose_position(i, r)
	mi = MeshInstance3D.new()
	mi.mesh = _mesh
	mi.skin = _skin
	mi.material_override = mat
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	voice = AudioStreamPlayer3D.new()
	voice.bus = "SFX"
	voice.unit_size = 4.0
	voice.max_distance = 40.0
	voice.position.y = 0.6
	add_child(voice)
	blood_fx = CPUParticles3D.new()
	blood_fx.emitting = false
	blood_fx.one_shot = true
	blood_fx.amount = 24
	blood_fx.lifetime = 0.8
	blood_fx.explosiveness = 0.95
	blood_fx.direction = Vector3(0, 0.5, 1)
	blood_fx.spread = 40.0
	blood_fx.initial_velocity_min = 1.5
	blood_fx.initial_velocity_max = 3.5
	blood_fx.gravity = Vector3(0, -9.8, 0)
	blood_fx.scale_amount_min = 0.025
	blood_fx.scale_amount_max = 0.06
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.25, 0.01, 0.01)
	dm.roughness = 0.2
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = dm
	blood_fx.mesh = sm
	blood_fx.position.y = 0.5
	add_child(blood_fx)
	rotation.y = yaw
	last_pos = position
	if eating:
		_set_state(S.EAT)
	if preview != "":
		set_physics_process(false)

# ------------------------------------------------------------------ 接口
func is_alive() -> bool:
	return state != S.DEAD

func blocks() -> bool:
	return false

func is_hittable() -> bool:
	return state != S.DEAD

func is_stompable() -> bool:
	return state == S.DOWN

func is_windup() -> bool:
	return state == S.LEAP and t_state < 0.62

func enemy_kind() -> String:
	return "dog"

func shot_shapes() -> Array:
	if state == S.DEAD:
		return []
	var g := skel.global_transform
	var hp_ := g * skel.get_bone_global_pose(HEAD).origin
	var c := g * skel.get_bone_global_pose(CHEST).origin
	var pe := g * skel.get_bone_global_pose(PELVIS).origin
	return [[pe, c, 0.17, 1.0], [hp_ + (hp_ - c).normalized() * 0.06, hp_ + (hp_ - c).normalized() * 0.06, 0.12, 1.8]]

func _bleed(from: Vector3, n := 20) -> void:
	var away := global_position - from
	away.y = 0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	blood_fx.direction = (global_basis.inverse() * away.normalized() + Vector3(0, 0.5, 0)).normalized()
	blood_fx.amount = n
	blood_fx.restart()
	blood_fx.emitting = true

func _yelp() -> void:
	Game.sfx3d("dog_yelp", global_position + Vector3(0, 0.6, 0), 0.0, rs.randf_range(0.9, 1.15), 4.0, 35.0)

func take_hit(dmg: float, from: Vector3) -> void:
	if state == S.DEAD:
		return
	hurt_v = 1.0
	_bleed(from)
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		knock = away.normalized() * 3.2
	if state == S.DOWN:
		dmg *= 1.4
	hp -= dmg
	if hp <= 0.0:
		_die()
		return
	_yelp()
	if state != S.DOWN:
		_set_state(S.STAGGER)
		air = 0.0

func take_stomp(dmg: float) -> void:
	take_hit(dmg * 1.5, global_position + Vector3(0, 0, 0.3).rotated(Vector3.UP, rs.randf() * TAU))

func take_shot(dmg: float, from: Vector3, _point: Vector3, mult: float) -> void:
	take_hit(dmg * mult, from)

## 推开 / 反击。返回 true 表示成功反击
func push_hit(from: Vector3, counter: bool) -> bool:
	if state == S.DEAD:
		return false
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if counter or is_windup():
		knock = away * 6.0
		hp -= 12.0
		_bleed(from, 14)
		_yelp()
		if hp <= 0.0:
			_die()
		else:
			_set_state(S.DOWN)
			air = 0.0
		return true
	knock = away * 4.5
	if state != S.DOWN:
		_set_state(S.STAGGER)
		air = 0.0
	Game.sfx3d("dog_growl", global_position + Vector3(0, 0.6, 0), -4.0, 1.2)
	return false

func _die() -> void:
	_set_state(S.DEAD)
	remove_from_group("monster")
	collision_layer = 0
	voice.stop()
	_yelp()
	Game.sfx3d("body_fall", global_position, -2.0, 1.3)
	var dc := Decal.new()
	dc.texture_albedo = _blood
	dc.size = Vector3(1.6, 0.8, 1.6)
	dc.modulate = Color(0.45, 0.04, 0.03)
	dc.position.y = 0.2
	dc.rotation.y = rs.randf() * TAU
	dc.scale = Vector3.ONE * 0.2
	add_child(dc)
	create_tween().tween_property(dc, "scale", Vector3.ONE, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	killed.emit(mid)

func _set_state(s: int) -> void:
	state = s
	t_state = 0.0
	bit = false

func _voice(name: String, vol: float, pitch := 1.0) -> void:
	voice.stream = Game.stream(name)
	voice.volume_db = vol
	voice.pitch_scale = pitch * rs.randf_range(0.92, 1.08)
	voice.play()

# ------------------------------------------------------------------ 感知
func _player() -> Node3D:
	var p: Node3D = Game.player
	if p == null or p.dead or not p.enabled:
		return null
	return p

func _sense() -> bool:
	var p := _player()
	if p == null:
		return false
	var d := p.global_position - global_position
	d.y = 0
	var l := d.length()
	if l > 40.0:
		return false
	var ow: float = Game.main.ow if Game.main else 0.0
	var sight: float = lerp(15.0, 11.0, ow)
	if p.torch_on:
		sight += 6.0
	if state in [S.CHASE, S.CIRCLE]:
		sight += 8.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var hear: float = 13.0 * p.noise_level
	if l < hear:
		return true
	if l < 2.5:
		return true
	if l < sight and (d.normalized().dot(fwd) > -0.2 or l < 6.0):
		return _los(p)
	return false

func _los(p: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), p.global_position + Vector3(0, 1.2, 0), 1)
	return space.intersect_ray(q).is_empty()

# ------------------------------------------------------------------ 行为
func _physics_process(dt: float) -> void:
	t_state += dt
	if state == S.DEAD:
		return
	var p := _player()
	sense_t -= dt
	if sense_t <= 0.0:
		sense_t = 0.2
		sees = _sense()
	bark_cd -= dt
	leap_cd -= dt
	var want := Vector3.ZERO
	var spd := 0.0
	var ow: float = Game.main.ow if Game.main else 0.0
	match state:
		S.IDLE:
			if t_state > rs.randf_range(3.0, 7.0):
				_pick_wander()
			if (sees or hunt) and p:
				_alert()
		S.EAT:
			if (sees and p and p.global_position.distance_to(global_position) < 9.0) or (p and p.noise_level > 0.9 and p.global_position.distance_to(global_position) < 16.0) or hunt:
				_alert()
			elif rs.randf() < dt * 0.4:
				Game.sfx3d("dog_eat", global_position + Vector3(0, 0.3, 0), -8.0, rs.randf_range(0.8, 1.1), 2.0, 14.0)
		S.WANDER:
			spd = 1.1
			want = _follow(dt, wander_target)
			if want == Vector3.ZERO or t_state > 10.0:
				_set_state(S.IDLE)
			if sees and p:
				_alert()
		S.ALERT:
			if p:
				_face(p.global_position - global_position, dt * 6.0)
			if t_state > 0.7 + pack_delay:
				_set_state(S.CHASE)
		S.CHASE:
			if p == null:
				_set_state(S.IDLE)
			else:
				var d := p.global_position - global_position
				d.y = 0
				var l := d.length()
				lost_t = 0.0 if (sees or hunt) else lost_t + dt
				spd = 5.0 + 0.5 * ow
				if bark_cd <= 0.0:
					bark_cd = rs.randf_range(1.6, 3.5)
					_voice("dog_bark", 2.0)
				if lost_t > 8.0 or (l > 45.0 and not hunt):
					wander_target = home
					_set_state(S.WANDER)
				elif l < 3.6 and leap_cd <= 0.0 and sees:
					if rs.randf() < 0.45:
						_set_state(S.CIRCLE)
						circle_dir = -1.0 if rs.randf() < 0.5 else 1.0
					else:
						_start_leap(p)
				elif l < 1.6:
					_set_state(S.CIRCLE)
					circle_dir = -1.0 if rs.randf() < 0.5 else 1.0
				else:
					want = d if (sees and l < 8.0) else _follow(dt, p.global_position)
		S.CIRCLE:
			if p == null:
				_set_state(S.IDLE)
			else:
				var d := p.global_position - global_position
				d.y = 0
				var l := d.length()
				var side := Vector3(-d.z, 0, d.x).normalized() * circle_dir
				var radial: Vector3 = d.normalized() * clamp(l - 2.8, -1.0, 1.0)
				want = side + radial
				spd = 3.2
				_face(d, dt * 8.0)
				if growl_t <= 0.0:
					growl_t = 1.4
					_voice("dog_growl", 0.0)
				growl_t -= dt
				if t_state > rs.randf_range(0.7, 1.6) and leap_cd <= 0.0:
					_start_leap(p)
				elif l > 6.0:
					_set_state(S.CHASE)
		S.LEAP:
			# 0~0.45 蓄力（可被反击）  0.45~0.85 扑出
			if p and t_state < 0.45:
				var d := p.global_position - global_position
				d.y = 0
				_face(d, dt * 10.0)
				var pv: Vector3 = p.velocity
				leap_dir = (d + Vector3(pv.x, 0, pv.z) * 0.25).normalized()
			elif t_state < 0.85:
				want = leap_dir
				spd = 7.5
				air = sin(clamp((t_state - 0.45) / 0.4, 0.0, 1.0) * PI) * 0.45
				if not bit and p:
					var d2 := p.global_position - global_position
					d2.y = 0
					if d2.length() < 1.05:
						bit = true
						p.hurt(rs.randf_range(9.0, 12.0) + 2.0 * ow, global_position)
						Game.sfx3d("dog_bite", p.global_position + Vector3(0, 0.9, 0), 2.0, rs.randf_range(0.9, 1.1))
						jaw_v = 1.0
						knock = -leap_dir * 2.0
			else:
				air = 0.0
				_set_state(S.RECOVER)
				leap_cd = rs.randf_range(1.2, 2.4)
		S.RECOVER:
			spd = 1.0
			if p:
				want = -(p.global_position - global_position) * 0.5
				_face(p.global_position - global_position, dt * 4.0)
			if t_state > 0.6:
				_set_state(S.CHASE if p else S.IDLE)
		S.STAGGER:
			if t_state > 0.55:
				_set_state(S.CHASE if p else S.IDLE)
		S.DOWN:
			if t_state > 2.6:
				_set_state(S.RECOVER)
				Game.sfx3d("dog_growl", global_position + Vector3(0, 0.5, 0), 0.0, 0.9)
	var vel := Vector3.ZERO
	if want != Vector3.ZERO and spd > 0.0:
		want.y = 0
		want = want.normalized()
		if state != S.CIRCLE and state != S.RECOVER:
			_face(want, dt * (7.0 if state != S.LEAP else 2.0))
		vel = want * spd
	knock = knock.lerp(Vector3.ZERO, clamp(dt * 5.0, 0.0, 1.0))
	vel += knock
	for o in get_tree().get_nodes_in_group("monster"):
		if o == self or not (o is CharacterBody3D):
			continue
		var dd: Vector3 = global_position - (o as Node3D).global_position
		dd.y = 0
		var dl := dd.length()
		if dl < 0.8 and dl > 0.001:
			vel += dd / dl * (0.8 - dl) * 4.0
	velocity = vel
	move_and_slide()
	global_position.y = 0.0
	cur_speed = lerp(cur_speed, Vector2(velocity.x, velocity.z).length(), clamp(dt * 8.0, 0.0, 1.0))
	if state in [S.CHASE, S.WANDER] and spd > 0.0:
		if global_position.distance_to(last_pos) < spd * dt * 0.2:
			stuck_t += dt
			if stuck_t > 0.7:
				stuck_t = 0.0
				path = PackedVector3Array()
				repath_t = 0.0
				knock += Vector3(rs.randf_range(-1, 1), 0, rs.randf_range(-1, 1)) * 1.5
		else:
			stuck_t = max(stuck_t - dt, 0.0)
	last_pos = global_position
	rotation.y = yaw

func _start_leap(p: Node3D) -> void:
	_set_state(S.LEAP)
	leap_dir = (p.global_position - global_position).normalized()
	_voice("dog_snarl", 3.0, 1.05)

func _alert() -> void:
	if state in [S.CHASE, S.ALERT, S.CIRCLE, S.LEAP]:
		return
	_set_state(S.ALERT)
	_voice("dog_bark", 3.0, 0.95)
	bark_cd = 1.5
	# 叫醒同伴
	for o in get_tree().get_nodes_in_group("monster"):
		if o != self and o.has_method("pack_alert") and (o as Node3D).global_position.distance_to(global_position) < 18.0:
			o.pack_alert()

func hear_noise(_pos: Vector3) -> void:
	if state in [S.IDLE, S.WANDER, S.EAT]:
		_alert()

func pack_alert() -> void:
	if state in [S.IDLE, S.WANDER, S.EAT]:
		pack_delay = rs.randf_range(0.2, 0.7)
		_set_state(S.ALERT)

func _face(dir: Vector3, k: float) -> void:
	if dir.length() < 0.001:
		return
	yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), clamp(k, 0.0, 1.0))

func _pick_wander() -> void:
	var w = Game.world
	for i in 6:
		var a := rs.randf() * TAU
		var t := home + Vector3(cos(a), 0, sin(a)) * rs.randf_range(2.0, 6.0)
		if w == null or w.walkable(t):
			wander_target = t
			path = PackedVector3Array()
			_set_state(S.WANDER)
			return
	_set_state(S.IDLE)

func _follow(dt: float, target: Vector3) -> Vector3:
	repath_t -= dt
	if path.is_empty() or repath_t <= 0.0:
		repath_t = 0.5
		if Game.world:
			path = Game.world.find_path(global_position, target)
		path_i = 0
	var me := global_position
	while path_i < path.size():
		var d := path[path_i] - me
		d.y = 0
		if d.length() < 0.6:
			path_i += 1
			continue
		return d
	var df := target - me
	df.y = 0
	return df if df.length() > 0.5 else Vector3.ZERO

# ------------------------------------------------------------------ 动画
func _process(dt: float) -> void:
	if skel == null:
		return
	var tt := Time.get_ticks_msec() / 1000.0 + float(hash(mid) % 100)
	hurt_v = max(hurt_v - dt * 2.5, 0.0)
	jaw_v = max(jaw_v - dt * 3.0, 0.0)
	mat.set_shader_parameter("hurt", hurt_v * 0.6)
	var st := state
	if preview != "":
		t_state += dt
		st = {"idle": S.IDLE, "run": S.CHASE, "walk": S.WANDER, "growl": S.CIRCLE, "leap": S.LEAP, "down": S.DOWN, "dead": S.DEAD, "eat": S.EAT}.get(preview, S.IDLE)
	var spd := cur_speed
	if preview == "run":
		spd = 5.0
	elif preview == "walk":
		spd = 1.1
	var R := []
	R.resize(NB)
	for i in NB:
		R[i] = Vector3.ZERO
	var off := Vector3.ZERO
	var roll := 0.0
	var jaw := 0.08 + jaw_v * 0.5
	var gallop: float = clamp((spd - 2.6) / 2.0, 0.0, 1.0)
	var freq: float = lerp(1.7, 2.9, clamp(spd / 3.0, 0.0, 1.0)) + gallop * 0.4
	if spd > 0.15:
		gait += dt * freq
	var amp: float = clamp(spd / 1.2, 0.0, 1.0) * lerp(0.42, 0.75, gallop)
	# 相位：小跑=对角线，奔跑=旋转式
	var offs := [0.0, 0.5, 0.5, 0.0]
	var goffs := [0.0, 0.6, 0.12, 0.72]
	var stance: float = lerp(0.62, 0.42, gallop)
	for k in 4:
		var u := fposmod(gait + lerp(offs[k], goffs[k], gallop), 1.0)
		var sw: float
		var lift := 0.0
		if u < stance:
			sw = lerp(1.0, -1.0, u / stance)
		else:
			var kk := (u - stance) / (1.0 - stance)
			sw = lerp(-1.0, 1.0, smoothstep(0.0, 1.0, kk))
			lift = sin(kk * PI)
		var L: Array = LEG[k]
		var front := k == 0 or k == 2
		sw *= amp
		lift *= clamp(amp * 1.6, 0.0, 1.0)
		if front:
			R[L[0]] = Vector3(sw * 0.8, 0, 0)
			R[L[1]] = Vector3(-lift * 1.3, 0, 0)
			R[L[2]] = Vector3(lift * 0.9 - sw * 0.2, 0, 0)
		else:
			R[L[0]] = Vector3(sw * 0.75, 0, 0)
			R[L[1]] = Vector3(lift * 0.9 + sw * 0.1, 0, 0)
			R[L[2]] = Vector3(-lift * 1.2, 0, 0)
	var bob := 0.0
	if spd > 0.15:
		bob = -abs(sin(gait * TAU)) * 0.02 * amp - gallop * 0.02
		R[CHEST] += Vector3(sin(gait * TAU) * 0.12 * gallop, 0, 0)
		R[PELVIS] += Vector3(-sin(gait * TAU) * 0.08 * gallop, 0, 0)
		R[HEAD] += Vector3(sin(gait * TAU * 2.0) * 0.05, 0, 0)
		R[NECK] += Vector3(-0.15 * gallop, 0, 0)
	off.y = bob
	# 尾巴
	R[TAIL1] = Vector3(-0.2 + 0.1 * sin(tt * 2.0), sin(tt * 5.0) * (0.15 + 0.2 * amp), 0)
	R[TAIL2] = Vector3(0.2, sin(tt * 5.0 - 1.0) * 0.3, 0)
	match st:
		S.IDLE, S.WANDER:
			if spd < 0.2:
				R[NECK] += Vector3(-0.35 - 0.08 * sin(tt * 0.9), sin(tt * 0.5) * 0.3, 0)
				R[HEAD] += Vector3(-0.25 - 0.05 * sin(tt * 7.0) * float(sin(tt * 1.3) > 0.4), 0, 0)
				R[CHEST] += Vector3(0.02 * sin(tt * 3.0), 0, 0)
		S.EAT:
			R[NECK] += Vector3(-0.75, 0.0, 0)
			R[HEAD] += Vector3(-0.45 - 0.15 * sin(tt * 9.0), 0.15 * sin(tt * 4.0), 0)
			R[LEG[0][0]] += Vector3(0.3, 0, 0)
			R[LEG[2][0]] += Vector3(0.35, 0, 0)
			R[LEG[0][1]] += Vector3(-0.4, 0, 0)
			R[LEG[2][1]] += Vector3(-0.45, 0, 0)
			jaw = 0.15 + 0.2 * max(0.0, sin(tt * 9.0))
			off.y -= 0.04
		S.ALERT, S.CIRCLE:
			R[NECK] += Vector3(-0.3, 0, 0)
			R[HEAD] += Vector3(0.12, 0, 0)
			jaw = 0.25 + 0.12 * sin(tt * 23.0)
			off.y -= 0.05
			for k in 4:
				R[LEG[k][0]] += Vector3(0.15 if k % 2 == 1 else -0.1, 0, 0)
				R[LEG[k][1]] += Vector3(0.25 if k % 2 == 1 else -0.25, 0, 0)
			R[TAIL1] = Vector3(0.4, sin(tt * 2.0) * 0.05, 0)
			R[CHEST] += Vector3(0.03 * sin(tt * 9.0), 0, 0)
		S.LEAP:
			var a: float = clamp(t_state / 0.45, 0.0, 1.0)
			if t_state < 0.45:
				# 蓄力伏低
				off.y -= 0.12 * a
				R[NECK] += Vector3(-0.35 * a, 0, 0)
				R[HEAD] += Vector3(0.2 * a, 0, 0)
				jaw = 0.35 + 0.1 * sin(tt * 30.0)
				for k in 4:
					R[LEG[k][0]] += Vector3((-0.35 if k % 2 == 1 else -0.25) * a, 0, 0)
					R[LEG[k][1]] += Vector3((0.7 if k % 2 == 1 else -0.6) * a, 0, 0)
					R[LEG[k][2]] += Vector3((-0.5 if k % 2 == 1 else 0.4) * a, 0, 0)
				R[CHEST] += Vector3(0.0, 0, 0)
				roll = 0.0
			else:
				var b: float = clamp((t_state - 0.45) / 0.4, 0.0, 1.0)
				off.y += air
				R[PELVIS] += Vector3(-0.3 * sin(b * PI), 0, 0)
				R[NECK] += Vector3(0.15, 0, 0)
				jaw = 0.75 * (1.0 - b) + 0.1
				for k in 4:
					if k % 2 == 0:
						R[LEG[k][0]] += Vector3(0.9, 0, 0)
						R[LEG[k][1]] += Vector3(-0.3, 0, 0)
					else:
						R[LEG[k][0]] += Vector3(-0.9, 0, 0)
						R[LEG[k][2]] += Vector3(0.3, 0, 0)
		S.RECOVER:
			jaw = 0.2
			R[NECK] += Vector3(-0.1, 0, 0)
		S.STAGGER:
			var s := sin(clamp(t_state / 0.55, 0.0, 1.0) * PI)
			R[NECK] += Vector3(0.4 * s, 0.3 * s, 0)
			roll = 0.25 * s
			jaw = 0.5 * s
		S.DOWN, S.DEAD:
			var k2: float = clamp(t_state / 0.35, 0.0, 1.0)
			roll = PI * 0.5 * k2
			off.y = 0.02 - 0.13 * k2
			var tw: float = 0.0 if st == S.DEAD and t_state > 3.0 else sin(tt * 17.0) * 0.25 * (1.0 if st == S.DOWN else max(0.0, 1.0 - t_state / 3.0))
			for k in 4:
				R[LEG[k][0]] = Vector3((0.5 if k % 2 == 0 else -0.5) + tw * (1.0 if k < 2 else -1.0), 0, 0)
				R[LEG[k][1]] = Vector3((-0.3 if k % 2 == 0 else 0.4) + tw * 0.5, 0, 0)
			R[NECK] = Vector3(0.2, 0, 0.1)
			jaw = 0.5 if st == S.DEAD else 0.35 + 0.2 * sin(tt * 11.0)
	R[JAW] = Vector3(jaw, 0, 0)
	# 头部朝向玩家
	var p: Node3D = Game.player
	if p and st in [S.ALERT, S.CIRCLE, S.CHASE, S.LEAP] and preview == "":
		var d := global_transform.affine_inverse() * p.global_position
		var want := Vector2(clamp(atan2(-d.x, -d.z), -0.8, 0.8), 0.0)
		head_look = head_look.lerp(want, clamp(dt * 6.0, 0.0, 1.0))
	else:
		head_look = head_look.lerp(Vector2.ZERO, clamp(dt * 3.0, 0.0, 1.0))
	R[NECK] += Vector3(0, head_look.x * 0.5, 0)
	R[HEAD] += Vector3(0, head_look.x * 0.5, 0)
	for i in NB:
		var r: Vector3 = R[i]
		skel.set_bone_pose_rotation(i, Basis.from_euler(r).get_rotation_quaternion())
	skel.set_bone_pose_position(PELVIS, rest[PELVIS] + off)
	visual.rotation = Vector3(0, 0, roll)
	visual.position = Vector3(0, 0.0, 0)
