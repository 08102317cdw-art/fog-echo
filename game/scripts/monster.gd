extends CharacterBody3D
## “躺尸”怪物：雕刻蒙皮网格 + 程序骨骼动画 + 状态机
## 站立型：瘸腿蹒跚、脊椎扭动、头部高速乱颤、胸口裂口张合、喷酸；爬行型：俯卧蛇形扭动
## 特殊：DORMANT（装死伏击）、PHANTOM（雾中人影，不可交互）

signal killed(id: String)

enum S { IDLE, WANDER, CHASE, ATTACK, STAGGER, DOWN, RISE, DEAD, SPIT, DORMANT, WAKE, PHANTOM }

const AcidScript = preload("res://scripts/acid.gd")

const PELVIS := 0
const SPINE1 := 1
const SPINE2 := 2
const CHEST := 3
const NECK := 4
const HEAD := 5
const THIGH_L := 6
const SHIN_L := 7
const FOOT_L := 8
const THIGH_R := 9
const SHIN_R := 10
const FOOT_R := 11
const ARM_L := 12
const ARM_R := 13
const HAND_L := 14
const HAND_R := 15
const SLIT_L := 16
const SLIT_R := 17
const JAW := 18
const NB := 19

static var _mesh: ArrayMesh
static var _bones: Array = []
static var _skin: Skin
static var _surf := PackedVector3Array()
static var _flesh: Texture2D
static var _grime: Texture2D
static var _blood: Texture2D
static var _shader: Shader
static var _drop: Mesh

const CAFE_DOOR_OUT := Vector3(32.0, 0, 60.8)
const CAFE_DOOR_IN := Vector3(32.0, 0, 57.6)

var mid := ""
var crawler := false
var dormant := false
var phantom := false
var preview := ""
var state := S.IDLE
var hp := 100.0
var down_hp := 60.0
var t_state := 0.0
var home := Vector3.ZERO
var path := PackedVector3Array()
var path_i := 0
var repath_t := 0.0
var sense_t := 0.0
var sees := false
var lost_t := 0.0
var atk_hit := false
var yaw := 0.0
var walk_ph := 0.0
var step_i := 0
var cur_speed := 0.0
var twitch := Vector3.ZERO
var twitch_h := Vector3.ZERO
var twitch_cur := Vector3.ZERO
var twitch_hcur := Vector3.ZERO
var twitch_t := 0.0
var shake_head := 0.0
var shake_t := 0.0
var spasm_v := 0.0
var spasm_dir := Vector3.ZERO
var spasm_t := 3.0
var hurt_v := 0.0
var scream_cd := 0.0
var growl_cd := 3.0
var spit_cd := 3.0
var burst_t := 4.0
var burst_mode := 0
var burst_left := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var knock := Vector3.ZERO
var wander_target := Vector3.ZERO
var time_alive := 0.0
var aggro := false
var hunt := false
var spat := false
var tilt := 0.3
var slit_open := 0.1
var jaw_open := 0.0
var lit_t := 0.0
var min_d := 999.0
var seen_t := 0.0
var leaving := false
var gush_t := 0.0

var base: Node3D
var visual: Node3D
var skel: Skeleton3D
var mi: MeshInstance3D
var mat: ShaderMaterial
var voice: AudioStreamPlayer3D
var pose_tw: Tween
var blood_fx: CPUParticles3D
var gush: CPUParticles3D
var rest_pos := PackedVector3Array()
var rot := PackedVector3Array()
var off := PackedVector3Array()
var worm_p := [Vector3.ZERO, Vector3.ZERO]
var worm_from := [Vector3.ZERO, Vector3.ZERO]
var worm_to := [Vector3.ZERO, Vector3.ZERO]
var worm_k := [1.0, 1.0]
var worm_spd := [1.0, 1.0]
var worm_w := [0.0, 0.0]
var worm_on := [0.0, 0.0]
var rs := RandomNumberGenerator.new()

# ------------------------------------------------------------------ 资源
static func _load() -> void:
	if _mesh:
		return
	_mesh = load("res://assets/models/monster.res")
	_bones = _mesh.get_meta("bones")
	_skin = Skin.new()
	for i in _bones.size():
		var h: Vector3 = _bones[i][2]
		_skin.add_bind(i, Transform3D(Basis(), -h))
	_flesh = load("res://assets/tex/flesh.png")
	_grime = load("res://assets/tex/grime.png")
	_blood = load("res://assets/tex/blood.png")
	_shader = load("res://shaders/flesh2.gdshader")
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.22, 0.01, 0.01)
	dm.roughness = 0.12
	dm.metallic_specular = 0.8
	sm.material = dm
	_drop = sm
	# 躯干表面采样点：皮下“虫子”的爬行路径
	var arr := _mesh.surface_get_arrays(0)
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var C: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var U2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	for i in range(0, V.size(), 23):
		var v := V[i]
		if U2[i].y < 0.02 and C[i].r < 0.05 and v.y > 0.97 and v.y < 1.52:
			_surf.append(v)

func setup(id: String, pos: Vector3, yaw_deg: float, is_crawler: bool) -> void:
	mid = id
	crawler = is_crawler
	position = pos
	home = pos
	yaw = deg_to_rad(yaw_deg)

func _ready() -> void:
	_load()
	rs.seed = hash(mid) + int(position.x * 13.0)
	if not phantom:
		add_to_group("monster")
		collision_layer = 2
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.3
		cs.shape = sp
		cs.position.y = 0.4
		add_child(cs)
	else:
		collision_layer = 0
		collision_mask = 0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("flesh_tex", _flesh)
	mat.set_shader_parameter("grime_tex", _grime)
	mat.set_shader_parameter("seed", rs.randf() * 10.0)
	var tone := rs.randf()
	mat.set_shader_parameter("skin_pale", Color(0.37, 0.31, 0.27).lerp(Color(0.34, 0.31, 0.28), tone))
	mat.set_shader_parameter("skin_dark", Color(0.12, 0.075, 0.06).lerp(Color(0.10, 0.08, 0.07), tone))
	base = Node3D.new()
	add_child(base)
	visual = Node3D.new()
	visual.scale = Vector3.ONE * rs.randf_range(0.97, 1.06)
	base.add_child(visual)
	skel = Skeleton3D.new()
	visual.add_child(skel)
	rest_pos.resize(NB)
	rot.resize(NB)
	off.resize(NB)
	for i in NB:
		skel.add_bone(_bones[i][0])
	for i in NB:
		var par: int = _bones[i][1]
		var h: Vector3 = _bones[i][2]
		var o := h
		if par >= 0:
			skel.set_bone_parent(i, par)
			o = h - (_bones[par][2] as Vector3)
		rest_pos[i] = o
		skel.set_bone_rest(i, Transform3D(Basis(), o))
	skel.reset_bone_poses()
	mi = MeshInstance3D.new()
	mi.mesh = _mesh
	mi.skin = _skin
	mi.material_override = mat
	mi.custom_aabb = AABB(Vector3(-0.8, -0.3, -0.8), Vector3(1.6, 2.4, 1.6))
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	tilt = rs.randf_range(0.28, 0.5) * (1.0 if rs.randf() < 0.5 else -1.0)
	# 声音
	voice = AudioStreamPlayer3D.new()
	var s: AudioStream = Game.stream("mon_breath")
	if s is AudioStreamOggVorbis:
		s.loop = true
	voice.stream = s
	voice.bus = "SFX"
	voice.unit_size = 3.0
	voice.max_distance = 26.0
	voice.volume_db = 3.0
	voice.pitch_scale = rs.randf_range(0.85, 1.05)
	voice.position.y = 1.2
	add_child(voice)
	# 血液粒子
	blood_fx = _particles(30, 0.9, 0.95)
	blood_fx.position.y = 1.2
	add_child(blood_fx)
	var ba := BoneAttachment3D.new()
	skel.add_child(ba)
	ba.bone_name = "slit_r"
	gush = _particles(70, 1.1, 0.0)
	gush.one_shot = false
	gush.direction = Vector3(0, -0.3, -1)
	gush.spread = 25.0
	gush.initial_velocity_min = 0.4
	gush.initial_velocity_max = 1.6
	ba.add_child(gush)
	rotation.y = yaw
	for k in 2:
		worm_p[k] = _surf[rs.randi() % _surf.size()] if _surf.size() > 0 else Vector3(0, 1.2, -0.1)
		worm_to[k] = worm_p[k]
		worm_from[k] = worm_p[k]
	if phantom:
		state = S.PHANTOM
		voice.volume_db = -6.0
		voice.play(rs.randf() * 3.0)
	elif dormant:
		state = S.DORMANT
		_pose_back(true)
	else:
		voice.play(rs.randf() * 3.0)
		if crawler:
			hp = 70.0
			_pose_prone(true)
	last_pos = global_position
	twitch_t = rs.randf()
	spit_cd = rs.randf_range(2.5, 5.0)
	wander_target = home

func _particles(n: int, life: float, expl: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = expl
	p.local_coords = false
	p.mesh = _drop
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 40.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.04
	return p

# ------------------------------------------------------------------ 姿态（整体翻转）
func _pose_prone(instant := false) -> void:
	_pose(Vector3(-PI / 2, 0, 0), Vector3(0, 0.17, 0.95), 0.6, instant)

func _pose_back(instant := false) -> void:
	_pose(Vector3(PI / 2, 0, 0), Vector3(0, 0.15, -0.95), 0.55, instant)

func _pose_stand(dur := 1.3) -> void:
	_pose(Vector3.ZERO, Vector3.ZERO, dur, false)

func _pose(r: Vector3, pos: Vector3, dur: float, instant: bool) -> void:
	if pose_tw and pose_tw.is_valid():
		pose_tw.kill()
	if instant:
		visual.rotation = r
		visual.position = pos
		return
	pose_tw = create_tween()
	pose_tw.tween_property(visual, "rotation", r, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if r.x > 0.1 else Tween.EASE_IN_OUT)
	pose_tw.parallel().tween_property(visual, "position", pos, dur).set_trans(Tween.TRANS_QUAD)

# ------------------------------------------------------------------ 接口
func is_alive() -> bool:
	return state != S.DEAD

func blocks() -> bool:
	return not crawler and state in [S.IDLE, S.WANDER, S.CHASE, S.ATTACK, S.STAGGER, S.SPIT]

func is_hittable() -> bool:
	return state != S.DEAD and state != S.RISE and state != S.PHANTOM

func is_stompable() -> bool:
	return state == S.DOWN or state == S.DORMANT or (crawler and state != S.DEAD)

func _bleed(from: Vector3, n := 30) -> void:
	var away := global_position - from
	away.y = 0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	blood_fx.position.y = 0.35 if (crawler or state == S.DOWN or state == S.DORMANT) else 1.15
	blood_fx.direction = (global_basis.inverse() * away.normalized() + Vector3(0, 0.4, 0)).normalized()
	blood_fx.amount = n
	blood_fx.restart()
	blood_fx.emitting = true

func take_hit(dmg: float, from: Vector3) -> void:
	if state == S.DEAD or state == S.PHANTOM:
		return
	hurt_v = 1.0
	aggro = true
	_bleed(from)
	if state == S.DORMANT:
		hp -= dmg * 0.5
		_wake()
		return
	_scream("mon_hurt", 0.0, 0.9)
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		knock = away.normalized() * (1.6 if not crawler else 0.6)
	if state == S.DOWN:
		down_hp -= dmg * 0.6
		_spasm(0.8)
		if down_hp <= 0.0:
			_die()
		return
	hp -= dmg
	if hp <= 0.0:
		if crawler:
			_die()
		else:
			_go_down()
		return
	_set_state(S.STAGGER)
	shake_head = 0.8
	if not crawler:
		twitch = Vector3(0.45, randf_range(-0.4, 0.4), randf_range(-0.3, 0.3))
		_spasm(0.5)

func take_stomp(dmg: float) -> void:
	if state == S.DEAD or state == S.PHANTOM:
		return
	hurt_v = 1.0
	aggro = true
	_bleed(global_position + Vector3(0, 0, 0.5).rotated(Vector3.UP, randf() * TAU), 24)
	if state == S.DORMANT:
		hp -= dmg * 0.5
		_wake()
		return
	_spasm(1.0)
	if crawler:
		hp -= dmg
		if hp <= 0.0:
			_die()
		else:
			_set_state(S.STAGGER)
			_scream("mon_hurt", -2.0, 0.8)
		return
	if state == S.DOWN:
		down_hp -= dmg
		t_state = min(t_state, 2.0)
		_scream("mon_hurt", -2.0, 0.75)
		if down_hp <= 0.0:
			_die()

func _spasm(v := 1.0, sound := true) -> void:
	spasm_v = max(spasm_v, v)
	spasm_dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	twitch = Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.6), randf_range(-0.5, 0.5))
	shake_head = max(shake_head, 0.8)
	if sound and v > 0.4:
		Game.sfx3d("mon_crack", global_position + Vector3(0, 1.0 if not crawler else 0.3, 0), -3.0 + v * 3.0, randf_range(0.85, 1.15), 3.0, 22.0)

func _go_down() -> void:
	_set_state(S.DOWN)
	down_hp = 60.0
	Game.sfx3d("mon_screech", global_position + Vector3(0, 1, 0), 0.0, 0.72)
	Game.sfx3d("stomp", global_position, -6.0, 0.6)
	_spasm(1.0)
	_pose_back()

func _die() -> void:
	_set_state(S.DEAD)
	remove_from_group("monster")
	collision_layer = 0
	voice.stop()
	Game.sfx3d("mon_death", global_position + Vector3(0, 0.5, 0), 3.0, randf_range(0.92, 1.05))
	_spasm(1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("writhe", v), 2.5, 0.0, 4.5)
	if not crawler and visual.rotation.x < 1.0:
		_pose_back()
	if not crawler:
		gush.emitting = true
		gush_t = 3.2
	# 血泊
	var dc := Decal.new()
	dc.texture_albedo = _blood
	dc.size = Vector3(2.6, 1.2, 2.6)
	dc.modulate = Color(0.45, 0.04, 0.03)
	dc.albedo_mix = 0.95
	dc.position = Vector3(0, 0.3, 0 if crawler else 0.0)
	dc.rotation.y = randf() * TAU
	dc.scale = Vector3.ONE * 0.2
	add_child(dc)
	var tw2 := create_tween()
	tw2.tween_property(dc, "scale", Vector3.ONE, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	killed.emit(mid)

func _set_state(s: int) -> void:
	state = s
	t_state = 0.0
	atk_hit = false
	spat = false

func _scream(name: String, vol: float, pitch: float) -> void:
	Game.sfx3d(name, global_position + Vector3(0, 1.0 if not crawler else 0.35, 0), vol, pitch * randf_range(0.9, 1.1))

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
	var ow: float = Game.main.ow if Game.main else 0.0
	var sight: float = lerp(11.0, 7.5, ow)
	if crawler:
		sight -= 2.0
	if p.torch_on:
		sight += 6.0
	if state == S.CHASE:
		sight += 6.0
	var hear: float = 11.5 * p.noise_level
	if l < 1.8 or l < hear:
		return true
	if l < sight:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		if state == S.CHASE or aggro or l < 4.5 or d.normalized().dot(fwd) > -0.3:
			return _los(p)
	return false

func _los(p: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.5 if (crawler or state == S.DORMANT) else 1.3, 0)
	var to := p.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()

func _lit_by(p: Node3D, maxd: float, cosang: float) -> bool:
	if not p.torch_on:
		return false
	var cam: Node3D = p.get("cam")
	if cam == null:
		return false
	var to := global_position + Vector3(0, 0.35, 0) - cam.global_position
	var l := to.length()
	if l > maxd:
		return false
	var fwd := -cam.global_basis.z
	return fwd.dot(to / l) > cosang

func _looked_at(p: Node3D, cosang: float) -> bool:
	var cam: Node3D = p.get("cam")
	if cam == null:
		return false
	var to := global_position + Vector3(0, 1.2, 0) - cam.global_position
	return (-cam.global_basis.z).dot(to.normalized()) > cosang

# ------------------------------------------------------------------ 主循环
func _physics_process(dt: float) -> void:
	time_alive += dt
	t_state += dt
	scream_cd = max(scream_cd - dt, 0.0)
	if state == S.DEAD:
		return
	var p := _player()
	if state == S.PHANTOM:
		_phantom(dt, p)
		return
	if state == S.DORMANT:
		_dormant(dt, p)
		return
	sense_t -= dt
	if sense_t <= 0.0:
		sense_t = 0.22
		sees = _sense()
	var want := Vector3.ZERO
	var spd := 0.0
	var ow: float = Game.main.ow if Game.main else 0.0
	spit_cd -= dt * (1.0 + 0.6 * ow)
	match state:
		S.IDLE:
			if t_state > randf_range(2.5, 6.0) and not crawler:
				_pick_wander()
			elif crawler and t_state > 7.0:
				_pick_wander()
			if (sees or hunt) and p:
				_alert()
		S.WANDER:
			spd = 0.7 if not crawler else 0.6
			want = _follow(dt, wander_target)
			if want == Vector3.ZERO or t_state > 14.0:
				_set_state(S.IDLE)
			if sees and p:
				_alert()
		S.CHASE:
			if p == null:
				_set_state(S.IDLE)
			else:
				spd = (1.95 + 0.35 * ow) if not crawler else (1.45 + 0.25 * ow)
				var d := p.global_position - global_position
				d.y = 0
				var l := d.length()
				if sees or hunt:
					lost_t = 0.0
				else:
					lost_t += dt
				# 突然冲刺 / 停下抽搐
				burst_t -= dt
				if burst_t <= 0.0 and l > 3.0:
					burst_t = randf_range(3.5, 7.5)
					burst_mode = 1 if randf() < 0.55 else 2
					burst_left = 0.8 if burst_mode == 1 else 0.55
					if burst_mode == 2:
						_spasm(0.9)
					else:
						_scream("mon_growl", 1.0, 1.05)
						growl_cd = 3.0
				if burst_left > 0.0:
					burst_left -= dt
					spd *= 1.85 if burst_mode == 1 else 0.0
				growl_cd -= dt
				if growl_cd <= 0.0:
					growl_cd = randf_range(3.5, 7.0)
					_scream("mon_growl", -2.0, 1.0 if not crawler else 0.8)
				if lost_t > 9.0 or (l > 30.0 and not hunt):
					aggro = false
					wander_target = home
					_set_state(S.WANDER)
				elif l < (1.3 if not crawler else 1.15):
					_set_state(S.ATTACK)
					_scream("mon_growl", 2.0, 1.15)
				elif not crawler and spit_cd <= 0.0 and l > 3.5 and l < 10.0 and sees and _los(p):
					_set_state(S.SPIT)
					spit_cd = randf_range(5.0, 9.0)
					Game.sfx3d("mon_gurgle", global_position + Vector3(0, 1.3, 0), 2.0, randf_range(0.9, 1.05))
					Game.sfx3d("mon_slit", global_position + Vector3(0, 1.3, 0), -2.0, 0.9)
				else:
					want = _chase_dir(dt, p)
		S.ATTACK:
			if p:
				var d := p.global_position - global_position
				d.y = 0
				_face(d, dt * 6.0)
				var hit_t := 0.5 if not crawler else 0.35
				if t_state > hit_t and t_state < hit_t + 0.15:
					want = d.normalized()
					spd = 2.6 if not crawler else 2.0
				if not atk_hit and t_state > hit_t + 0.08:
					atk_hit = true
					var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
					if d.length() < (1.65 if not crawler else 1.45) and d.normalized().dot(fwd) > 0.3:
						p.hurt(16.0 + 4.0 * ow if not crawler else 9.0, global_position)
						Game.sfx3d("hit_flesh", p.global_position + Vector3(0, 1.0, 0), 0.0, 0.7)
						Game.sfx3d("mon_slit", global_position + Vector3(0, 1.3, 0), 0.0, 1.1)
			if t_state > (1.25 if not crawler else 1.0):
				_set_state(S.CHASE if p else S.IDLE)
		S.SPIT:
			if p:
				var d := p.global_position - global_position
				d.y = 0
				_face(d, dt * 5.0)
				if not spat and t_state > 0.78:
					spat = true
					_spit(p)
			if t_state > 1.5:
				_set_state(S.CHASE if p else S.IDLE)
		S.STAGGER:
			if t_state > (0.55 if not crawler else 0.45):
				_set_state(S.CHASE if p else S.IDLE)
		S.DOWN:
			if t_state > 7.5:
				_set_state(S.RISE)
				hp = 45.0
				_scream("mon_screech", 0.0, 0.8)
				_pose_stand(1.4)
		S.RISE:
			if t_state > 1.2 and t_state - dt <= 1.2:
				_spasm(0.9)
			if t_state > 1.5:
				aggro = true
				_set_state(S.CHASE)
		S.WAKE:
			if p:
				var d := p.global_position - global_position
				d.y = 0
				if t_state > 0.8:
					_face(d, dt * 2.2)
			if t_state > 0.25 and t_state - dt <= 0.25:
				_spasm(1.0, false)
			if t_state > 0.5 and t_state - dt <= 0.5:
				_spasm(1.0, false)
			if t_state > 0.8 and t_state - dt <= 0.8:
				_pose_stand(1.1)
			if t_state > 1.95 and t_state - dt <= 1.95:
				_spasm(1.0)
				_scream("mon_screech", 3.0, 0.9)
				shake_head = 1.4
			if t_state > 2.3:
				aggro = true
				hunt = true
				voice.play()
				_set_state(S.CHASE)
	# 移动
	var vel := Vector3.ZERO
	if want != Vector3.ZERO and spd > 0.0:
		want.y = 0
		want = want.normalized()
		_face(want, dt * (5.0 if state != S.ATTACK else 7.0))
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var align: float = clamp(fwd.dot(want) * 0.5 + 0.6, 0.15, 1.0)
		vel = want * spd * align
		# 瘸腿：右腿拖地时速度骤降
		if not crawler:
			vel *= 0.72 + 0.4 * max(0.0, sin(walk_ph))
	knock = knock.lerp(Vector3.ZERO, clamp(dt * 5.0, 0.0, 1.0))
	vel += knock
	for o in get_tree().get_nodes_in_group("monster"):
		if o == self:
			continue
		var dd: Vector3 = global_position - (o as Node3D).global_position
		dd.y = 0
		var dl := dd.length()
		if dl < 0.9 and dl > 0.001:
			vel += dd / dl * (0.9 - dl) * 3.0
	velocity = vel
	move_and_slide()
	global_position.y = 0.0
	cur_speed = lerp(cur_speed, Vector2(velocity.x, velocity.z).length(), clamp(dt * 8.0, 0.0, 1.0))
	if state in [S.CHASE, S.WANDER] and spd > 0.0:
		if global_position.distance_to(last_pos) < spd * dt * 0.2:
			stuck_t += dt
			if stuck_t > 0.8:
				stuck_t = 0.0
				repath_t = 0.0
				path = PackedVector3Array()
				knock += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 1.2
		else:
			stuck_t = max(stuck_t - dt, 0.0)
	last_pos = global_position
	rotation.y = yaw

func _spit(p: Node3D) -> void:
	var o := _slit_world() + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.12
	var a: Node3D = AcidScript.new()
	get_parent().add_child(a)
	var pv: Vector3 = p.get("velocity") if p.get("velocity") != null else Vector3.ZERO
	var tgt := p.global_position + Vector3(0, 1.0, 0) + Vector3(pv.x, 0, pv.z) * 0.35
	tgt += Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))
	a.launch(o, tgt, self)
	Game.sfx3d("mon_spit", o, 3.0, randf_range(0.9, 1.1))
	_spasm(0.6, false)

func _slit_world() -> Vector3:
	var a := skel.get_bone_global_pose(SLIT_L).origin
	var b := skel.get_bone_global_pose(SLIT_R).origin
	return skel.global_transform * ((a + b) * 0.5)

func _wake() -> void:
	if state != S.DORMANT:
		return
	_set_state(S.WAKE)
	aggro = true
	Game.sfx3d("mon_wake", global_position + Vector3(0, 0.4, 0), 4.0, 1.0, 4.0, 30.0)
	_spasm(1.0, false)
	if Game.main and Game.main.has_method("on_monster_wake"):
		Game.main.on_monster_wake(mid)

func _dormant(dt: float, p: Node3D) -> void:
	if p == null:
		return
	var d := p.global_position - global_position
	d.y = 0
	var l := d.length()
	min_d = min(min_d, l)
	if _lit_by(p, 9.0, 0.94) and _los(p):
		lit_t += dt
	else:
		lit_t = max(lit_t - dt * 0.5, 0.0)
	# 靠太近 / 被手电盯着 / 从身边走过之后在背后起身
	if l < 3.2 or lit_t > 0.9 or (min_d < 7.0 and l > min_d + 2.0):
		_wake()

func _phantom(dt: float, p: Node3D) -> void:
	if p == null:
		return
	var d := p.global_position - global_position
	d.y = 0
	var l := d.length()
	if not leaving:
		_face(d, dt * 3.0)
		if _looked_at(p, 0.9) and l < 26.0:
			seen_t += dt
		if l < 12.5 or seen_t > 3.5 or t_state > 40.0:
			leaving = true
			t_state = 0.0
			shake_head = 1.5
			Game.sfx("sting", -10.0, 0.55)
			if Game.main and Game.main.has_method("on_phantom_leave"):
				Game.main.on_phantom_leave()
	else:
		var away := -d.normalized() if l > 0.01 else Vector3.FORWARD
		var dir := Vector3(-sin(yaw), 0, -cos(yaw))
		if t_state > 0.6:
			_face(away, dt * 2.5)
			global_position += dir * 0.95 * dt
			cur_speed = lerp(cur_speed, 0.95, dt * 4.0)
		if t_state > 9.0 or l > 30.0:
			queue_free()
	rotation.y = yaw

func _face(dir: Vector3, k: float) -> void:
	if dir.length() < 0.001:
		return
	var ty := atan2(-dir.x, -dir.z)
	yaw = lerp_angle(yaw, ty, clamp(k, 0.0, 1.0))

func _alert() -> void:
	if state == S.CHASE:
		return
	_set_state(S.CHASE)
	path = PackedVector3Array()
	repath_t = 0.0
	lost_t = 0.0
	shake_head = 1.2
	burst_t = randf_range(2.0, 5.0)
	if scream_cd <= 0.0:
		scream_cd = 8.0
		_scream("mon_screech", 2.0, 0.95)
		_spasm(0.7, false)

func _pick_wander() -> void:
	var w = Game.world
	for i in 6:
		var a := randf() * TAU
		var r := randf_range(2.0, 7.0)
		var t := home + Vector3(cos(a) * r, 0, sin(a) * r)
		if w and w.astar.is_in_boundsv(w.cell_of(t)) and not w.astar.is_point_solid(w.cell_of(t)):
			wander_target = t
			path = PackedVector3Array()
			_set_state(S.WANDER)
			return
	_set_state(S.IDLE)

func _in_cafe(p: Vector3) -> bool:
	return p.x > 27.0 and p.x < 37.0 and p.z > 47.0 and p.z < 59.0

func _chase_dir(dt: float, p: Node3D) -> Vector3:
	var pp := p.global_position
	var me := global_position
	if _in_cafe(pp) and not _in_cafe(me):
		if me.distance_to(CAFE_DOOR_OUT) > 1.2 and not (me.z > 58.0 and abs(me.x - 32.0) < 1.6):
			return _follow(dt, CAFE_DOOR_OUT)
		return (CAFE_DOOR_IN - me) if me.z > 58.3 else (pp - me)
	if _in_cafe(me) and not _in_cafe(pp):
		if me.z < 58.6:
			return (CAFE_DOOR_IN + Vector3(0, 0, 1.5) - me) if abs(me.x - 32.0) < 1.2 or me.z > 57.0 else (CAFE_DOOR_IN - me)
	if _in_cafe(pp) and _in_cafe(me):
		return pp - me
	var d := pp - me
	d.y = 0
	if sees and d.length() < 7.0:
		return d
	return _follow(dt, pp)

func _follow(dt: float, target: Vector3) -> Vector3:
	repath_t -= dt
	if path.is_empty() or repath_t <= 0.0:
		repath_t = 0.6 if state == S.CHASE else 3.0
		if Game.world:
			path = Game.world.find_path(global_position, target)
		path_i = 0
	var me := global_position
	if path.is_empty():
		var d := target - me
		d.y = 0
		return d if d.length() > 0.6 else Vector3.ZERO
	while path_i < path.size():
		var wp := path[path_i]
		var d := wp - me
		d.y = 0
		var last := path_i == path.size() - 1
		if d.length() < (0.7 if not last else 0.5):
			path_i += 1
			continue
		if last:
			var dt2 := target - me
			dt2.y = 0
			if dt2.length() < 2.0:
				return dt2 if dt2.length() > 0.5 else Vector3.ZERO
		return d
	var df := target - me
	df.y = 0
	return df if df.length() > 0.5 else Vector3.ZERO

# ------------------------------------------------------------------ 动画
func _process(dt: float) -> void:
	if Game.world:
		base.position.y = lerp(base.position.y, Game.world.floor_h(global_position), clamp(dt * 8.0, 0.0, 1.0))
	hurt_v = max(hurt_v - dt * 3.0, 0.0)
	mat.set_shader_parameter("hurt", hurt_v * 0.6)
	if gush_t > 0.0:
		gush_t -= dt
		if gush_t <= 0.0:
			gush.emitting = false
	if state == S.DEAD and t_state > 7.0:
		return
	if preview != "":
		_preview_setup()
	var t := time_alive
	if not is_physics_processing():
		t_state += dt
		time_alive += dt
	# 随机抽动
	twitch_t -= dt
	if twitch_t <= 0.0:
		twitch_t = randf_range(0.08, 1.3) if state != S.DOWN else randf_range(0.05, 0.4)
		var amp := 0.12 if state != S.CHASE else 0.2
		if state == S.DOWN or state == S.WAKE:
			amp = 0.4
		if state == S.DORMANT:
			amp = 0.0
		if state == S.DEAD:
			amp = 0.4 * exp(-t_state * 0.7)
		twitch = Vector3(randf_range(-amp, amp), randf_range(-amp, amp) * 1.5, randf_range(-amp, amp))
		twitch_h = Vector3(randf_range(-0.5, 0.5), randf_range(-0.7, 0.7), randf_range(-0.6, 0.6)) * (0.5 if randf() < 0.7 else 1.2)
		if state == S.DORMANT:
			twitch_h = Vector3.ZERO
	twitch_cur = twitch_cur.lerp(twitch, clamp(dt * 28.0, 0.0, 1.0))
	twitch_hcur = twitch_hcur.lerp(twitch_h, clamp(dt * 22.0, 0.0, 1.0))
	# 头部高速乱颤（阵发）
	shake_t -= dt
	if shake_t <= 0.0 and state != S.DORMANT and state != S.DEAD:
		shake_t = randf_range(1.2, 3.5) if state == S.CHASE else randf_range(2.5, 7.0)
		if state == S.PHANTOM:
			shake_t = randf_range(0.8, 2.5)
		shake_head = max(shake_head, randf_range(0.5, 1.1))
	shake_head = max(shake_head - dt * 1.3, 0.0)
	# 全身痉挛（阵发，伴随骨裂声）
	spasm_t -= dt
	if spasm_t <= 0.0 and state in [S.IDLE, S.WANDER, S.CHASE, S.PHANTOM, S.DOWN]:
		spasm_t = randf_range(5.0, 12.0) if state != S.DOWN else randf_range(0.8, 2.0)
		_spasm(randf_range(0.5, 1.0), state != S.PHANTOM)
	if state == S.DEAD and t_state < 4.0 and randf() < dt * 2.0 * exp(-t_state * 0.6):
		_spasm(0.8 * exp(-t_state * 0.5), false)
	spasm_v = max(spasm_v - dt * 2.2, 0.0)
	for i in NB:
		rot[i] = Vector3.ZERO
		off[i] = Vector3.ZERO
	var amp_w: float = clamp(cur_speed / 1.5, 0.0, 1.4)
	if not crawler:
		walk_ph += dt * cur_speed * 4.3 * (1.0 + 0.45 * sin(walk_ph))
	else:
		walk_ph += dt * cur_speed * 3.6
	_steps()
	var writhe := 1.0
	var breathe := 0.5 + 0.5 * sin(t * 1.6 + sin(t * 0.37) * 2.0)
	var slit_t: float = 0.12 + 0.1 * max(0.0, sin(t * 0.9 + 1.3))
	var jaw_t: float = 0.08 + 0.12 * max(0.0, sin(t * 1.3))
	match state:
		S.DORMANT:
			_anim_dormant(t)
			writhe = 0.0
			breathe = 0.0
			slit_t = 0.05
			jaw_t = 0.35
		S.DOWN, S.WAKE:
			if state == S.WAKE and t_state > 0.8:
				_anim_rise(t, t_state - 0.8, 1.15)
			else:
				_anim_down(t)
			writhe = 2.4
			slit_t = 0.5 + 0.4 * sin(t * 5.0)
			jaw_t = 0.6 + 0.4 * sin(t * 7.0)
		S.RISE:
			_anim_rise(t, t_state, 1.2)
			writhe = 1.8
			slit_t = 0.5
			jaw_t = 0.7
		S.DEAD:
			_anim_dead(t)
			writhe = 2.5 * exp(-t_state * 0.6)
			breathe = 0.0
			slit_t = 1.0 if not crawler else 0.3
			jaw_t = 0.9
		_:
			if crawler:
				_anim_crawl(t, amp_w)
				jaw_t = 0.5 + 0.3 * sin(t * 3.0) if state == S.CHASE else jaw_t
			else:
				_anim_stand(t, amp_w)
			if state == S.CHASE:
				writhe = 1.6
				slit_t += 0.15
			elif state == S.ATTACK:
				writhe = 2.0
				var hit_t := 0.5 if not crawler else 0.35
				slit_t = clamp(t_state / hit_t, 0.0, 1.0) * 1.15 if t_state < hit_t + 0.35 else 0.4
				jaw_t = 1.0
			elif state == S.SPIT:
				writhe = 2.2
				slit_t = clamp(t_state / 0.75, 0.0, 1.0) * 1.3 if t_state < 1.0 else 0.5
				jaw_t = 0.6
				breathe = 1.0
			elif state == S.STAGGER:
				writhe = 2.2
				slit_t = 0.6
				jaw_t = 0.8
			elif state == S.PHANTOM:
				writhe = 0.8
	if scream_cd > 6.5:
		jaw_t = 1.0
		slit_t = max(slit_t, 0.8)
	slit_open = lerp(slit_open, slit_t, clamp(dt * 9.0, 0.0, 1.0))
	jaw_open = lerp(jaw_open, jaw_t, clamp(dt * 12.0, 0.0, 1.0))
	_anim_face_slit(t)
	_anim_worms(dt, t)
	if state != S.DORMANT:
		_anim_arms(t)
	mat.set_shader_parameter("writhe", writhe)
	mat.set_shader_parameter("breathe", breathe)
	_apply()

func _apply() -> void:
	for i in NB:
		skel.set_bone_pose_rotation(i, Quaternion.from_euler(rot[i]))
		skel.set_bone_pose_position(i, rest_pos[i] + off[i])

func _steps() -> void:
	var k := int(floor(walk_ph / PI))
	if k != step_i:
		step_i = k
		if cur_speed < 0.25 or state == S.DORMANT:
			return
		if crawler:
			Game.sfx3d("mon_step", global_position, -15.0, randf_range(0.65, 0.8), 2.0, 18.0)
		elif k % 2 == 0:
			Game.sfx3d("mon_step", global_position, -9.0, randf_range(0.85, 1.0), 2.0, 22.0)
		else:
			Game.sfx3d("mon_step", global_position, -13.0, randf_range(0.6, 0.7), 2.0, 20.0)

# 头颈：歪斜断颈 + 高速乱颤
func _head_layer(t: float, k: float) -> void:
	var sh := shake_head
	var hs := Vector3(sin(t * 61.0 + 2.0) * 0.32 + sin(t * 37.0) * 0.15, sin(t * 53.0) * 0.55 + sin(t * 79.0 + 1.0) * 0.3, sin(t * 47.0) * 0.4 + sin(t * 89.0 + 3.0) * 0.18) * sh
	rot[NECK] += Vector3(twitch_hcur.x * 0.25, twitch_hcur.y * 0.3, tilt * 0.45 + twitch_hcur.z * 0.2) * k + hs * 0.25
	rot[HEAD] += Vector3(twitch_hcur.x * 0.45, twitch_hcur.y * 0.55, tilt * 0.75 + twitch_hcur.z * 0.4) * k + hs * 0.75

func _spine_layer(t: float, amp: float) -> void:
	var o := float(rs.seed % 100) * 0.1
	var a := 1.0 + amp * 0.6
	rot[SPINE1] += Vector3(0.0, sin(t * 0.9 + o) * 0.06, sin(t * 1.3 + o) * 0.07) * a
	rot[SPINE2] += Vector3(0.0, sin(t * 0.9 + o + 1.0) * 0.09, -sin(t * 1.3 + o + 0.8) * 0.1) * a
	rot[CHEST] += Vector3(0.0, -sin(t * 0.9 + o + 2.0) * 0.1, sin(t * 1.3 + o + 1.6) * 0.08) * a
	rot[SPINE1] += twitch_cur * 0.3
	rot[SPINE2] += twitch_cur * 0.55
	rot[CHEST] += Vector3(twitch_cur.x * 0.6, -twitch_cur.y * 0.5, -twitch_cur.z * 0.5)
	var sv := spasm_v * spasm_v
	if sv > 0.001:
		var j := Vector3(sin(t * 43.0), sin(t * 37.0 + 1.0), sin(t * 51.0 + 2.0)) * 0.12 * sv
		rot[SPINE1] += Vector3(spasm_dir.x * 0.25, spasm_dir.y * 0.3, spasm_dir.z * 0.25) * sv + j
		rot[SPINE2] += Vector3(-spasm_dir.x * 0.3, spasm_dir.y * 0.4, -spasm_dir.z * 0.35) * sv - j
		rot[CHEST] += Vector3(spasm_dir.x * 0.35, -spasm_dir.y * 0.3, spasm_dir.z * 0.3) * sv + j * 1.3
		rot[NECK] += Vector3(-spasm_dir.x * 0.5, spasm_dir.y * 0.5, -spasm_dir.z * 0.5) * sv
		rot[HEAD] += Vector3(spasm_dir.x * 0.4, -spasm_dir.y * 0.4, spasm_dir.z * 0.6) * sv

func _anim_stand(t: float, amp: float) -> void:
	var ph := walk_ph
	var s := sin(ph)
	# 左腿正常，右腿拖行内翻
	rot[THIGH_L] = Vector3(s * 0.5 * amp + 0.04, -0.05, 0.03)
	rot[SHIN_L] = Vector3(-max(0.0, sin(ph + 1.3)) * 0.95 * amp - 0.1, 0, 0)
	rot[FOOT_L] = Vector3(0.12 * amp * sin(ph - 0.6) + 0.04, -0.1, 0)
	rot[THIGH_R] = Vector3(-s * 0.26 * amp - 0.06, 0.32, -0.06)
	rot[SHIN_R] = Vector3(-0.2 - max(0.0, sin(ph + PI + 1.0)) * 0.3 * amp, 0.05, 0)
	rot[FOOT_R] = Vector3(-0.55, 0.3, 0.28)
	rot[PELVIS] = Vector3(0.05, s * 0.13 * amp, -0.06 + s * 0.09 * amp)
	off[PELVIS] = Vector3(0.0, -0.035 + abs(cos(ph)) * 0.022 * amp - max(0.0, -s) * 0.03 * amp, 0.0)
	var lean := -0.1 - 0.12 * amp
	var lean2 := -0.12
	var headx := 0.12
	match state:
		S.ATTACK:
			var hit_t := 0.5
			if t_state < hit_t:
				var k := t_state / hit_t
				lean = lerp(-0.1, 0.3, k)
				lean2 = lerp(-0.12, 0.3, k)
				headx = lerp(0.1, 0.7, k)
			elif t_state < hit_t + 0.2:
				var k := (t_state - hit_t) / 0.2
				lean = lerp(0.3, -0.55, k)
				lean2 = lerp(0.3, -0.45, k)
				headx = lerp(0.7, -0.3, k)
			else:
				var k: float = clamp((t_state - hit_t - 0.2) / 0.5, 0.0, 1.0)
				lean = lerp(-0.55, -0.15, k)
				lean2 = lerp(-0.45, -0.12, k)
				headx = lerp(-0.3, 0.1, k)
		S.SPIT:
			if t_state < 0.78:
				var k := t_state / 0.78
				lean = lerp(-0.1, 0.28, k)
				lean2 = lerp(-0.12, 0.35, k)
				headx = lerp(0.1, 0.9, k)
			else:
				var k: float = clamp((t_state - 0.78) / 0.15, 0.0, 1.0)
				var r: float = clamp((t_state - 0.95) / 0.5, 0.0, 1.0)
				lean = lerp(lerp(0.28, -0.5, k), -0.12, r)
				lean2 = lerp(lerp(0.35, -0.45, k), -0.12, r)
				headx = lerp(lerp(0.9, -0.2, k), 0.1, r)
		S.STAGGER:
			var k: float = clamp(t_state / 0.55, 0.0, 1.0)
			lean = lerp(0.35, -0.1, k)
			lean2 = lerp(0.25, -0.12, k)
			headx = lerp(0.8, 0.1, k)
		S.PHANTOM:
			lean = -0.05
			lean2 = -0.05
	if state == S.CHASE and burst_left > 0.0 and burst_mode == 1:
		lean -= 0.18
	rot[SPINE1] += Vector3(lean * 0.4, 0, 0)
	rot[SPINE2] += Vector3(lean * 0.6 + lean2 * 0.3, 0, 0)
	rot[CHEST] += Vector3(lean2 * 0.7, 0, 0)
	rot[NECK] += Vector3(-0.05 + headx * 0.4, 0, 0)
	rot[HEAD] += Vector3(headx * 0.6, 0, 0)
	_spine_layer(t, amp)
	_head_layer(t, 1.0)

func _anim_crawl(t: float, amp: float) -> void:
	var ph := walk_ph
	var a: float = max(amp, 0.25)
	var lunge := 0.0
	if state == S.ATTACK:
		lunge = sin(clamp((t_state - 0.2) / 0.5, 0.0, 1.0) * PI) * 0.45
	if not (pose_tw and pose_tw.is_running()):
		visual.position.z = lerp(visual.position.z, 0.95 - lunge, clamp(get_process_delta_time() * 12.0, 0.0, 1.0))
	# 俯卧时本地 Z 轴 = 世界竖直：绕 Z 转即左右蛇形扭动
	rot[PELVIS] = Vector3(0.0, sin(ph) * 0.12 * a, -sin(ph) * 0.18 * a)
	rot[SPINE1] = Vector3(0.0, sin(ph - 0.6) * 0.1 * a, sin(ph - 0.8) * 0.28 * a + sin(t * 1.3) * 0.05)
	rot[SPINE2] = Vector3(0.05, sin(ph - 1.4) * 0.1 * a, sin(ph - 1.6) * 0.3 * a)
	rot[CHEST] = Vector3(0.1, sin(ph - 2.2) * 0.1 * a, sin(ph - 2.4) * 0.26 * a)
	rot[SPINE1] += twitch_cur * 0.4
	rot[CHEST] += twitch_cur * 0.5
	# 蛙腿：交替外展 + 屈膝蹬地
	var kl := sin(ph)
	var kr := sin(ph + PI)
	rot[THIGH_L] = Vector3(-0.05 + max(0.0, kl) * 0.3 * a, 0.0, -0.3 - max(0.0, kl) * 0.3 * a)
	rot[SHIN_L] = Vector3(-0.15 - max(0.0, kl) * 0.45 * a, 0.0, 0.25 * max(0.0, kl) * a)
	rot[FOOT_L] = Vector3(-0.6, 0.0, 0.0)
	rot[THIGH_R] = Vector3(-0.05 + max(0.0, kr) * 0.3 * a, 0.0, 0.3 + max(0.0, kr) * 0.3 * a)
	rot[SHIN_R] = Vector3(-0.15 - max(0.0, kr) * 0.45 * a, 0.0, -0.25 * max(0.0, kr) * a)
	rot[FOOT_R] = Vector3(-0.6, 0.0, 0.0)
	var lift := 0.55 + lunge * 1.2
	if state == S.STAGGER:
		lift = 0.0
	rot[NECK] += Vector3(lift * 0.6, sin(ph - 3.0) * 0.2 * a, 0)
	rot[HEAD] += Vector3(lift * 0.5, 0, 0)
	var sv := spasm_v * spasm_v
	rot[SPINE2] += Vector3(0, 0, spasm_dir.z * 0.5) * sv
	rot[CHEST] += Vector3(spasm_dir.x * 0.3, 0, -spasm_dir.z * 0.4) * sv
	_head_layer(t, 0.6)

func _anim_down(t: float) -> void:
	# 仰躺：踢腿、扭动、甩头
	var w := 1.0 if state != S.WAKE else 1.6
	rot[THIGH_L] = Vector3(0.35 + sin(t * 3.1 * w) * 0.35, 0, -0.15)
	rot[THIGH_R] = Vector3(0.35 + sin(t * 2.6 * w + 1.7) * 0.35, 0, 0.15)
	rot[SHIN_L] = Vector3(-0.6 - sin(t * 3.1 * w + 0.6) * 0.4, 0, 0)
	rot[SHIN_R] = Vector3(-0.6 - sin(t * 2.6 * w + 2.2) * 0.4, 0, 0)
	rot[FOOT_L] = Vector3(-0.4 + sin(t * 5.0) * 0.2, 0, 0)
	rot[FOOT_R] = Vector3(-0.4 + sin(t * 4.3) * 0.2, 0, 0)
	rot[PELVIS] = Vector3(0, sin(t * 4.0) * 0.15, 0)
	rot[SPINE1] = Vector3(0.08, sin(t * 5.0) * 0.12, sin(t * 3.3) * 0.1)
	rot[SPINE2] = Vector3(0.12 + sin(t * 2.2) * 0.1, -sin(t * 5.0 + 1.0) * 0.12, -sin(t * 3.3 + 1.0) * 0.12)
	rot[CHEST] = Vector3(0.1, sin(t * 4.1) * 0.1, sin(t * 3.0 + 2.0) * 0.1)
	rot[NECK] = Vector3(0.3, sin(t * 4.0) * 0.5, 0)
	rot[HEAD] = Vector3(0.2, sin(t * 4.0 + 0.4) * 0.5, 0)
	rot[SPINE2] += twitch_cur * 0.8
	rot[CHEST] += twitch_cur
	var sv := spasm_v * spasm_v
	rot[SPINE1] += Vector3(-0.5, spasm_dir.y * 0.3, spasm_dir.z * 0.3) * sv
	rot[SPINE2] += Vector3(-0.5, -spasm_dir.y * 0.3, -spasm_dir.z * 0.3) * sv
	rot[THIGH_L] += Vector3(0.6 * sv, 0, 0)
	rot[THIGH_R] += Vector3(0.5 * sv, 0, 0)
	_head_layer(t, 0.8)

func _anim_rise(t: float, tt: float, dur: float) -> void:
	# 僵直起身：身体像木板一样立起，头向后折，最后猛地甩回
	var k: float = clamp(tt / dur, 0.0, 1.0)
	var snap: float = clamp((tt - dur) / 0.15, 0.0, 1.0)
	var back := (1.0 - snap) * 0.95
	rot[NECK] = Vector3(back * 0.8, 0, tilt * 0.4)
	rot[HEAD] = Vector3(back * 0.7, sin(t * 30.0) * 0.08, tilt * 0.6)
	rot[SPINE2] = Vector3(0.1 * (1.0 - k), 0, 0)
	rot[CHEST] = Vector3(0.15 * (1.0 - k), 0, 0)
	rot[THIGH_R] = Vector3(0, 0.32 * k, 0)
	rot[FOOT_R] = Vector3(-0.55 * k, 0.3 * k, 0.28 * k)
	rot[FOOT_L] = Vector3(-0.3 * (1.0 - k), 0, 0)
	_spine_layer(t, 0.0)

func _anim_dead(t: float) -> void:
	var e := exp(-t_state * 0.6)
	if crawler:
		rot[NECK] = Vector3(0.1 * (1.0 - e), 0, 0.3)
		rot[HEAD] = Vector3(-0.1, 0.5, 0.2)
		rot[THIGH_L] = Vector3(0.15, 0, -0.3)
		rot[THIGH_R] = Vector3(0.1, 0, 0.35)
		rot[SHIN_L] = Vector3(-0.4 - sin(t * 6.0) * 0.4 * e, 0, 0)
		rot[SHIN_R] = Vector3(-0.3 - sin(t * 5.0) * 0.4 * e, 0, 0)
	else:
		rot[THIGH_L] = Vector3(0.25 + sin(t * 5.0) * 0.4 * e, 0, -0.18)
		rot[THIGH_R] = Vector3(0.1 + sin(t * 4.1 + 1.0) * 0.3 * e, 0.3, 0.12)
		rot[SHIN_L] = Vector3(-0.5 - sin(t * 5.0 + 0.6) * 0.4 * e, 0, 0)
		rot[SHIN_R] = Vector3(-0.3, 0, 0)
		rot[FOOT_R] = Vector3(-0.5, 0.3, 0.3)
		rot[SPINE2] = Vector3(0.1 - 0.4 * e * max(0.0, sin(t * 2.0)), 0, 0.1)
		rot[NECK] = Vector3(0.35, 0.6 * (1.0 - e) + sin(t * 9.0) * 0.3 * e, tilt * 0.5)
		rot[HEAD] = Vector3(0.3, 0.4 * (1.0 - e), tilt * 0.6)
	rot[SPINE1] += twitch_cur
	rot[CHEST] += twitch_cur * 0.8
	var sv := spasm_v * spasm_v
	rot[SPINE1] += Vector3(-0.4, spasm_dir.y * 0.3, spasm_dir.z * 0.3) * sv
	rot[CHEST] += Vector3(-0.3, -spasm_dir.y * 0.3, 0) * sv
	rot[HEAD] += Vector3(spasm_dir.x, spasm_dir.y, spasm_dir.z) * 0.5 * sv

func _anim_dormant(t: float) -> void:
	# 装死：仰躺，头歪向一侧，一条腿别扭地弯着；几乎一动不动
	rot[NECK] = Vector3(0.2, 0.75 * sign(tilt), 0.2)
	rot[HEAD] = Vector3(0.15, 0.4 * sign(tilt), tilt * 0.4)
	rot[THIGH_L] = Vector3(0.15, -0.2, -0.12)
	rot[SHIN_L] = Vector3(-0.25, 0, 0)
	rot[THIGH_R] = Vector3(0.55, 0.4, 0.22)
	rot[SHIN_R] = Vector3(-1.1, 0, 0)
	rot[FOOT_R] = Vector3(-0.5, 0.3, 0.3)
	rot[SPINE2] = Vector3(0.06, 0.1, 0.05)
	# 偶尔：皮下的手指动了一下
	var f: float = max(0.0, sin(t * 0.35) - 0.97) * 30.0
	off[HAND_L] = Vector3(0.006, 0.0, -0.01) * f * (0.5 + 0.5 * sin(t * 23.0))

func _anim_face_slit(t: float) -> void:
	var o := slit_open
	var flutter := sin(t * 17.0) * 0.04 * o + sin(t * 29.0) * 0.02
	off[SLIT_L] += Vector3(-0.022 * (o + flutter), 0.0, -0.004 * o)
	off[SLIT_R] += Vector3(0.022 * (o + flutter), 0.0, -0.004 * o)
	rot[SLIT_L] += Vector3(0.0, 0.5 * o, 0.05 * o)
	rot[SLIT_R] += Vector3(0.0, -0.5 * o, -0.05 * o)
	var j := jaw_open + sin(t * 31.0) * 0.06 * jaw_open
	off[JAW] += Vector3(0.0, -0.022 * j, 0.006 * j)
	rot[JAW] += Vector3(-0.25 * j, 0.0, sin(t * 7.0) * 0.08 * j)

func _anim_arms(t: float) -> void:
	# 皮下的双臂和手指在往外顶
	var e := 1.0
	if state == S.CHASE or state == S.ATTACK or state == S.SPIT:
		e = 1.8
	if state == S.DOWN or state == S.WAKE or state == S.DEAD:
		e = 2.2 * (exp(-t_state * 0.5) if state == S.DEAD else 1.0)
	var pa: float = max(0.0, sin(t * 1.7 + 0.5)) * e
	var pb: float = max(0.0, sin(t * 1.3 + 2.1)) * e
	var gl: float = max(0.0, sin(t * 2.3)) * e
	var gr: float = max(0.0, sin(t * 2.9 + 1.0)) * e
	off[ARM_L] += Vector3(-0.008 * pa, 0.004 * sin(t * 3.0), -0.012 * pa)
	off[ARM_R] += Vector3(0.008 * pb, 0.004 * sin(t * 2.7), -0.012 * pb)
	rot[ARM_L] += Vector3(0.05 * pa, 0.0, -0.06 * pa) + Vector3(sin(t * 13.0), 0, sin(t * 11.0)) * 0.015 * e
	rot[ARM_R] += Vector3(0.05 * pb, 0.0, 0.06 * pb) + Vector3(sin(t * 12.0), 0, sin(t * 14.0)) * 0.015 * e
	off[HAND_L] += Vector3(0.006 * gl, 0.004 * sin(t * 5.0) * e, -0.016 * gl)
	off[HAND_R] += Vector3(-0.006 * gr, 0.004 * sin(t * 4.4) * e, -0.016 * gr)
	var sv := spasm_v * spasm_v
	off[HAND_L] += Vector3(0.01, 0.0, -0.02) * sv
	off[HAND_R] += Vector3(-0.01, 0.0, -0.02) * sv
	off[ARM_L] += Vector3(-0.012, 0.0, -0.01) * sv
	off[ARM_R] += Vector3(0.012, 0.0, -0.01) * sv

func _anim_worms(dt: float, t: float) -> void:
	if _surf.size() == 0:
		return
	for k in 2:
		var spd: float = worm_spd[k] * (1.8 if state in [S.CHASE, S.SPIT, S.DOWN, S.WAKE] else 1.0)
		worm_k[k] = float(worm_k[k]) + dt * spd / max((worm_to[k] as Vector3).distance_to(worm_from[k]), 0.02) * 0.05
		if worm_k[k] >= 1.0:
			worm_k[k] = 0.0
			worm_from[k] = worm_to[k]
			var cur: Vector3 = worm_to[k]
			var best := cur
			var bd := 9.0
			var target: Vector3 = _slit_target() if state == S.SPIT else cur + Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
			for i in 24:
				var c: Vector3 = _surf[randi() % _surf.size()]
				var dc := c.distance_to(cur)
				if dc < 0.03 or dc > 0.11:
					continue
				var sc := c.distance_to(target)
				if sc < bd:
					bd = sc
					best = c
			worm_to[k] = best
			worm_spd[k] = randf_range(0.6, 1.4)
		worm_p[k] = (worm_from[k] as Vector3).lerp(worm_to[k], worm_k[k])
		var want_on := 0.0
		if state != S.DORMANT and state != S.DEAD:
			want_on = clamp(sin(t * (0.21 + k * 0.13) + k * 2.0) * 1.6 + 0.5, 0.0, 1.0)
			if state in [S.CHASE, S.SPIT, S.DOWN, S.WAKE, S.ATTACK]:
				want_on = 1.0
		elif state == S.DEAD:
			want_on = exp(-t_state * 0.4)
		worm_on[k] = lerp(float(worm_on[k]), want_on, clamp(dt * 2.0, 0.0, 1.0))
		worm_w[k] = float(worm_on[k]) * (0.7 + 0.3 * sin(t * 9.0 + k * 3.0))
	mat.set_shader_parameter("worm_a", Vector4(worm_p[0].x, worm_p[0].y, worm_p[0].z, worm_w[0]))
	mat.set_shader_parameter("worm_b", Vector4(worm_p[1].x, worm_p[1].y, worm_p[1].z, worm_w[1]))

func _slit_target() -> Vector3:
	return Vector3(0.0, 1.33, -0.14)

# ------------------------------------------------------------------ 截图预览
func _preview_setup() -> void:
	match preview:
		"scream":
			scream_cd = 7.5
			shake_head = max(shake_head, 0.3)
		"spit":
			state = S.SPIT
			t_state = 0.7
		"attack":
			state = S.ATTACK
			t_state = 0.45
		"down":
			if state != S.DOWN:
				state = S.DOWN
				_pose_back(true)
		"dormant":
			if state != S.DORMANT:
				state = S.DORMANT
				_pose_back(true)
		"walk":
			cur_speed = 1.4
			state = S.CHASE
		"dead":
			if state != S.DEAD:
				_die()
				t_state = 1.2
		"spitfx":
			if state != S.SPIT:
				state = S.SPIT
				t_state = 0.62
			if t_state > 0.78 and not spat:
				spat = true
				var a: Node3D = AcidScript.new()
				get_parent().add_child(a)
				a.launch(_slit_world(), global_position + global_basis * Vector3(0.6, 0.6, -6.0), self)
			if t_state > 2.5:
				t_state = 1.6
