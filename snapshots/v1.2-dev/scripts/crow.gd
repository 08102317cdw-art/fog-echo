extends Node3D
## 乌鸦：程序建模 + 程序飞行。栖息 → 受惊起飞 → 盘旋 → 俯冲啄击 → 拉起。一击即死。

signal killed(id: String)

enum S { PERCH, ALERT, FLY_UP, CIRCLE, DIVE, RECOVER, RETURN, DEAD }

static var _wing_in: ArrayMesh
static var _wing_out: ArrayMesh
static var _feather: Material
static var _beak: Material
static var _eye: StandardMaterial3D
static var _shared := false

var mid := ""
var state := S.PERCH
var t_state := 0.0
var hp := 10.0
var home := Vector3.ZERO
var home_yaw := 0.0
var on_ground := true
var vel := Vector3.ZERO
var yaw := 0.0
var b_pitch := 0.0
var b_roll := 0.0
var flap_ph := 0.0
var flap_amp := 0.0
var fold := 1.0
var circle_a := 0.0
var circle_r := 5.0
var circle_h := 4.5
var circle_dir := 1.0
var circle_len := 3.0
var pecked := false
var caw_cd := 0.0
var peck_k := 0.0
var peck_t := 2.0
var head_yaw := 0.0
var head_tgt := 0.0
var head_t := 1.0
var alert_delay := 0.0
var aggressive := false
var block_r := 0.0
var rs := RandomNumberGenerator.new()

var body: Node3D
var head: Node3D
var wing_l: Node3D
var wing_r: Node3D
var wing_lo: Node3D
var wing_ro: Node3D
var tail: Node3D
var legs: Array = []
var flap_snd: AudioStreamPlayer3D
var feathers: CPUParticles3D
var spin := Vector3.ZERO
var landed_dead := false

static func _init_res() -> void:
	if _shared:
		return
	_shared = true
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.028, 0.028, 0.034)
	fm.roughness = 0.42
	fm.metallic_specular = 0.65
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.rim_enabled = true
	fm.rim = 0.25
	fm.rim_tint = 0.2
	_feather = fm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.05, 0.045, 0.045)
	bm.roughness = 0.3
	_beak = bm
	_eye = StandardMaterial3D.new()
	_eye.albedo_color = Color(0.02, 0.01, 0.01)
	_eye.roughness = 0.05
	_eye.emission_enabled = true
	_eye.emission = Color(0.9, 0.08, 0.04)
	_eye.emission_energy_multiplier = 0.0
	# 内侧翅膀
	_wing_in = _poly_mesh([Vector2(0, -0.05), Vector2(0.09, -0.052), Vector2(0.17, -0.045), Vector2(0.17, 0.065), Vector2(0.1, 0.085), Vector2(0, 0.095)], Vector2(0.08, 0.02))
	# 外侧翅膀（带分叉的初级飞羽）
	var pts: Array = [Vector2(0, -0.045), Vector2(0.09, -0.036)]
	var tips := [Vector2(0.215, -0.012), Vector2(0.222, 0.012), Vector2(0.212, 0.036), Vector2(0.192, 0.056), Vector2(0.165, 0.072)]
	for i in tips.size():
		pts.append(tips[i])
		if i < tips.size() - 1:
			var nx: Vector2 = (tips[i] + tips[i + 1]) * 0.5
			pts.append(Vector2(nx.x - 0.035, nx.y))
	pts.append(Vector2(0.08, 0.08))
	pts.append(Vector2(0, 0.068))
	_wing_out = _poly_mesh(pts, Vector2(0.07, 0.02))

static func _poly_mesh(pts: Array, c: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		st.add_vertex(Vector3(c.x, 0, c.y))
		st.add_vertex(Vector3(b.x, 0, b.y))
		st.add_vertex(Vector3(a.x, 0, a.y))
	return st.commit()

func setup(id: String, pos: Vector3, yaw_deg: float) -> void:
	mid = id
	position = pos
	home = pos
	yaw = deg_to_rad(yaw_deg)
	home_yaw = yaw

func _ready() -> void:
	_init_res()
	rs.seed = hash(mid)
	add_to_group("monster")
	add_to_group("crow")
	body = Node3D.new()
	add_child(body)
	var torso := _mesh_i(body, _ellipsoid(), _feather, Vector3(0, 0.0, 0.0))
	torso.scale = Vector3(0.085, 0.08, 0.19)
	var chest := _mesh_i(body, _ellipsoid(), _feather, Vector3(0, -0.012, -0.07))
	chest.scale = Vector3(0.075, 0.075, 0.1)
	head = Node3D.new()
	head.position = Vector3(0, 0.055, -0.15)
	body.add_child(head)
	var hm := _mesh_i(head, _ellipsoid(), _feather, Vector3(0, 0, -0.02))
	hm.scale = Vector3(0.05, 0.05, 0.062)
	var bk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.002
	cm.bottom_radius = 0.016
	cm.height = 0.07
	cm.radial_segments = 6
	cm.rings = 1
	bk.mesh = cm
	bk.material_override = _beak
	bk.rotation.x = -PI / 2
	bk.position = Vector3(0, -0.006, -0.105)
	bk.scale = Vector3(1.0, 1.0, 0.8)
	head.add_child(bk)
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.008
		em.height = 0.016
		em.radial_segments = 6
		em.rings = 3
		e.mesh = em
		e.material_override = _eye
		e.position = Vector3(0.036 * sx, 0.012, -0.045)
		head.add_child(e)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.015, 0.16)
	body.add_child(tail)
	var tm := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.075, 0.008, 0.14)
	tm.mesh = tb
	tm.material_override = _feather
	tm.position = Vector3(0, 0, 0.06)
	tail.add_child(tm)
	# 翅膀
	wing_r = _wing(Vector3(0.05, 0.035, -0.035), 1.0)
	wing_l = _wing(Vector3(-0.05, 0.035, -0.035), -1.0)
	wing_ro = wing_r.get_child(1)
	wing_lo = wing_l.get_child(1)
	for sx in [-1.0, 1.0]:
		var lg := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.006
		lc.bottom_radius = 0.005
		lc.height = 0.075
		lc.radial_segments = 5
		lc.rings = 1
		lg.mesh = lc
		lg.material_override = _beak
		lg.position = Vector3(0.022 * sx, -0.105, 0.015)
		body.add_child(lg)
		legs.append(lg)
	body.position.y = 0.14
	for c in body.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# 声音
	flap_snd = AudioStreamPlayer3D.new()
	var s: AudioStream = Game.stream("wings_flap")
	if s is AudioStreamOggVorbis:
		s.loop = true
	flap_snd.stream = s
	flap_snd.bus = "SFX"
	flap_snd.unit_size = 2.5
	flap_snd.max_distance = 22.0
	flap_snd.volume_db = -80.0
	add_child(flap_snd)
	# 羽毛
	feathers = CPUParticles3D.new()
	feathers.emitting = false
	feathers.one_shot = true
	feathers.amount = 16
	feathers.lifetime = 2.4
	feathers.explosiveness = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.014)
	var fq := StandardMaterial3D.new()
	fq.albedo_color = Color(0.03, 0.03, 0.035)
	fq.cull_mode = BaseMaterial3D.CULL_DISABLED
	fq.roughness = 0.5
	qm.material = fq
	feathers.mesh = qm
	feathers.direction = Vector3(0, 1, 0)
	feathers.spread = 180.0
	feathers.initial_velocity_min = 0.6
	feathers.initial_velocity_max = 2.2
	feathers.gravity = Vector3(0, -1.2, 0)
	feathers.damping_min = 1.5
	feathers.damping_max = 3.0
	feathers.angular_velocity_min = -360.0
	feathers.angular_velocity_max = 360.0
	feathers.particle_flag_rotate_y = true
	feathers.position.y = 0.14
	add_child(feathers)
	feathers.top_level = false
	on_ground = true
	caw_cd = rs.randf_range(3.0, 16.0)
	peck_t = rs.randf_range(0.5, 3.0)
	rotation.y = yaw

func _ellipsoid() -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 6
	return sm

func _mesh_i(parent: Node3D, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _wing(pos: Vector3, sx: float) -> Node3D:
	var pv := Node3D.new()
	pv.position = pos
	pv.scale = Vector3(sx, 1, 1)
	body.add_child(pv)
	var inner := MeshInstance3D.new()
	inner.mesh = _wing_in
	inner.material_override = _feather
	pv.add_child(inner)
	var op := Node3D.new()
	op.position = Vector3(0.165, 0, 0.0)
	pv.add_child(op)
	var outer := MeshInstance3D.new()
	outer.mesh = _wing_out
	outer.material_override = _feather
	op.add_child(outer)
	return pv

# ------------------------------------------------------------------ 接口
func is_alive() -> bool:
	return state != S.DEAD

func blocks() -> bool:
	return false

func _ground_y(p: Vector3) -> float:
	if Game.world and p.x < 400.0:
		return Game.world.floor_h(p)
	return 0.0

func is_hittable() -> bool:
	return state != S.DEAD and global_position.y - _ground_y(global_position) < 2.3

func is_stompable() -> bool:
	return false

func is_windup() -> bool:
	if state != S.DIVE or pecked:
		return false
	var p := _player()
	return p != null and global_position.distance_to(_head_pos(p)) < 3.2

func enemy_kind() -> String:
	return "crow"

func radio_mult() -> float:
	return 2.2 if state == S.PERCH else 1.0

func shot_shapes() -> Array:
	if state == S.DEAD:
		return []
	var c := body.global_position
	return [[c + body.global_basis.z * 0.12, c - body.global_basis.z * 0.12, 0.17, 1.0]]

func take_hit(_dmg: float, from: Vector3) -> void:
	if state == S.DEAD:
		return
	var away := global_position - from
	away.y = 0
	vel = away.normalized() * 3.5 + Vector3(0, 1.5, 0) if away.length() > 0.01 else Vector3(0, 1.5, 0)
	_die()

func take_stomp(dmg: float) -> void:
	take_hit(dmg, global_position + Vector3(0, 0, 0.3))

func take_shot(_dmg: float, from: Vector3, _point: Vector3, _mult: float) -> void:
	if state == S.DEAD:
		return
	var away := global_position - from
	vel = away.normalized() * 4.0
	_die()

func push_hit(from: Vector3, counter: bool) -> bool:
	if state == S.DEAD:
		return false
	var c := counter or is_windup()
	take_hit(10.0, from)
	return c

func hear_noise(_pos: Vector3) -> void:
	if state == S.PERCH or state == S.ALERT:
		aggressive = true
		alert_delay = rs.randf_range(0.0, 0.35)
		_set_state(S.ALERT)

func flock_alert() -> void:
	if state == S.PERCH:
		alert_delay = rs.randf_range(0.15, 0.8)
		_set_state(S.ALERT)

func _die() -> void:
	_set_state(S.DEAD)
	remove_from_group("monster")
	flap_snd.stop()
	feathers.restart()
	feathers.emitting = true
	Game.sfx3d("crow_caw%d" % rs.randi_range(0, 4), global_position, -2.0, 1.35, 3.0, 30.0)
	Game.sfx3d("hit_flesh", global_position, -6.0, 1.5)
	spin = Vector3(rs.randf_range(-8, 8), rs.randf_range(-6, 6), rs.randf_range(-10, 10))
	killed.emit(mid)

func _set_state(s: int) -> void:
	state = s
	t_state = 0.0

func _player() -> Node3D:
	var p: Node3D = Game.player
	if p == null or p.dead or not p.enabled:
		return null
	if p.get("cutscene") == true:
		return null
	return p

func _head_pos(p: Node3D) -> Vector3:
	return p.global_position + Vector3(0, 1.45, 0)

func _caw(vol := -3.0) -> void:
	if caw_cd > 0.0:
		return
	caw_cd = rs.randf_range(2.5, 6.0)
	Game.sfx3d("crow_caw%d" % rs.randi_range(0, 4), global_position + Vector3(0, 0.2, 0), vol, rs.randf_range(0.88, 1.08), 4.0, 45.0)

# ------------------------------------------------------------------ 行为
func _physics_process(dt: float) -> void:
	t_state += dt
	caw_cd -= dt
	if state == S.DEAD:
		_dead_fall(dt)
		return
	var p := _player()
	var pos := global_position
	match state:
		S.PERCH:
			on_ground = true
			vel = Vector3.ZERO
			if caw_cd <= 0.0 and rs.randf() < dt * 0.25:
				_caw(-8.0)
			if p:
				var d := p.global_position.distance_to(pos)
				var r := 8.0
				if p.get("noise_level") != null and float(p.get("noise_level")) >= 0.9:
					r += 5.0
				if p.get("torch_on") == true:
					r += 2.0
				if d < r:
					alert_delay = rs.randf_range(0.2, 0.7)
					_set_state(S.ALERT)
					for o in get_tree().get_nodes_in_group("crow"):
						if o != self and (o as Node3D).global_position.distance_to(pos) < 12.0:
							o.flock_alert()
		S.ALERT:
			if p:
				var d := p.global_position - pos
				_face(d, dt * 6.0)
				head_tgt = 0.0
			if t_state > alert_delay and t_state - dt <= alert_delay:
				_caw(-1.0)
			if t_state > alert_delay + 0.35:
				_take_off(p)
		S.FLY_UP:
			on_ground = false
			var up := Vector3(0, 3.6, 0)
			var away := Vector3(-sin(yaw), 0, -cos(yaw)) * 2.2
			vel = vel.lerp(up + away, clamp(dt * 4.0, 0.0, 1.0))
			if t_state > 0.9:
				if p and (aggressive or p.global_position.distance_to(pos) < 14.0):
					_begin_circle(p)
				else:
					_set_state(S.RETURN)
		S.CIRCLE:
			if p == null or p.global_position.distance_to(pos) > 30.0:
				_set_state(S.RETURN)
			else:
				circle_a += dt * circle_dir * (5.5 / max(circle_r, 1.0))
				var c := p.global_position
				var tgt := c + Vector3(cos(circle_a) * circle_r, circle_h, sin(circle_a) * circle_r)
				tgt.y = max(tgt.y, _ground_y(tgt) + 2.6)
				var want := (tgt - pos) * 1.8
				if want.length() > 6.5:
					want = want.normalized() * 6.5
				vel = vel.lerp(want, clamp(dt * 2.6, 0.0, 1.0))
				if t_state > circle_len:
					var divers := 0
					for o in get_tree().get_nodes_in_group("crow"):
						if o.get("state") == S.DIVE:
							divers += 1
					if divers < 2:
						_set_state(S.DIVE)
						pecked = false
						_caw(1.0)
					else:
						t_state = circle_len - rs.randf_range(0.5, 1.2)
		S.DIVE:
			if p == null:
				_set_state(S.RETURN)
			else:
				var hpos := _head_pos(p)
				var pv: Vector3 = p.get("velocity") if p.get("velocity") != null else Vector3.ZERO
				var lead := hpos + Vector3(pv.x, 0, pv.z) * 0.25
				var to := lead - pos
				var l := to.length()
				var want := to.normalized() * 8.0
				vel = vel.lerp(want, clamp(dt * (3.2 if l > 2.0 else 1.2), 0.0, 1.0))
				if not pecked and pos.distance_to(hpos) < 0.6:
					pecked = true
					p.call("hurt", rs.randf_range(3.0, 4.5), pos)
					Game.sfx3d("crow_caw%d" % rs.randi_range(0, 4), pos, 2.0, 1.2, 3.0, 30.0)
					_set_state(S.RECOVER)
				elif t_state > 2.2 or (t_state > 0.6 and to.dot(vel) < 0.0 and l > 0.8):
					_set_state(S.RECOVER)
		S.RECOVER:
			var away := Vector3.ZERO
			if p:
				away = pos - p.global_position
				away.y = 0
			if away.length() < 0.1:
				away = Vector3(-sin(yaw), 0, -cos(yaw))
			var want := away.normalized() * 4.0 + Vector3(0, 3.2, 0)
			vel = vel.lerp(want, clamp(dt * 3.0, 0.0, 1.0))
			if t_state > rs.randf_range(1.0, 1.4):
				if p:
					_begin_circle(p)
				else:
					_set_state(S.RETURN)
		S.RETURN:
			var tgt := home + Vector3(0, 0.0 if pos.distance_to(home) < 4.0 else 2.5, 0)
			var to := tgt - pos
			var want := to * 1.5
			if want.length() > 5.0:
				want = want.normalized() * 5.0
			vel = vel.lerp(want, clamp(dt * 2.5, 0.0, 1.0))
			if pos.distance_to(home) < 0.25:
				global_position = home
				vel = Vector3.ZERO
				yaw = home_yaw + rs.randf_range(-0.8, 0.8)
				aggressive = false
				_set_state(S.PERCH)
			elif p and p.global_position.distance_to(pos) < 10.0 and t_state > 2.0:
				_begin_circle(p)
	if state != S.PERCH and state != S.ALERT:
		var np := global_position + vel * dt
		var gy := _ground_y(np) + 0.25
		if state != S.RETURN and np.y < gy:
			np.y = gy
			vel.y = max(vel.y, 0.0)
		global_position = np
		_orient(dt)

func _take_off(p: Node3D) -> void:
	_set_state(S.FLY_UP)
	on_ground = false
	if p:
		var away := global_position - p.global_position
		away.y = 0
		if away.length() > 0.1:
			yaw = atan2(-away.x, -away.z) + rs.randf_range(-0.6, 0.6)
	vel = Vector3(0, 2.5, 0)
	Game.sfx3d("wings_takeoff", global_position, -2.0, rs.randf_range(0.9, 1.15), 3.0, 30.0)

func _begin_circle(p: Node3D) -> void:
	_set_state(S.CIRCLE)
	var rel := global_position - p.global_position
	circle_a = atan2(rel.z, rel.x)
	circle_r = rs.randf_range(3.5, 6.0)
	circle_h = rs.randf_range(3.2, 5.0)
	circle_dir = 1.0 if rs.randf() < 0.5 else -1.0
	circle_len = rs.randf_range(1.8, 4.2)
	# 墙体遮挡时缩小半径
	var space := get_world_3d().direct_space_state
	var from := p.global_position + Vector3(0, 1.6, 0)
	for i in 3:
		var tgt := p.global_position + Vector3(cos(circle_a) * circle_r, circle_h, sin(circle_a) * circle_r)
		var q := PhysicsRayQueryParameters3D.create(from, tgt, 1)
		if space.intersect_ray(q).is_empty():
			break
		circle_r *= 0.65
		circle_h *= 0.8

func _face(d: Vector3, k: float) -> void:
	d.y = 0
	if d.length() < 0.001:
		return
	yaw = lerp_angle(yaw, atan2(-d.x, -d.z), clamp(k, 0.0, 1.0))

func _orient(dt: float) -> void:
	var hv := Vector2(vel.x, vel.z)
	var prev := yaw
	if hv.length() > 0.3:
		yaw = lerp_angle(yaw, atan2(-vel.x, -vel.z), clamp(dt * 6.0, 0.0, 1.0))
	var turn: float = wrapf(yaw - prev, -PI, PI) / max(dt, 0.001)
	var tp: float = clamp(atan2(vel.y, max(hv.length(), 0.5)) * 0.75, -1.1, 0.9)
	b_pitch = lerp(b_pitch, tp, clamp(dt * 5.0, 0.0, 1.0))
	b_roll = lerp(b_roll, clamp(-turn * 0.35, -0.9, 0.9), clamp(dt * 4.0, 0.0, 1.0))

func _dead_fall(dt: float) -> void:
	if landed_dead:
		return
	vel.y -= 9.8 * dt
	vel.x *= 1.0 - dt * 0.8
	vel.z *= 1.0 - dt * 0.8
	var np := global_position + vel * dt
	var gy := _ground_y(np)
	body.rotation += spin * dt
	if np.y <= gy + 0.02:
		np.y = gy + 0.02
		landed_dead = true
		body.rotation = Vector3(0.0, rs.randf() * TAU, 1.5 * (1.0 if rs.randf() < 0.5 else -1.0))
		body.position.y = 0.07
		Game.sfx3d("body_fall", np, -14.0, 2.2)
		wing_r.rotation = Vector3(0, -0.3, -0.2)
		wing_l.rotation = Vector3(0, 0.3, 0.2)
		wing_ro.rotation = Vector3(0, -0.2, 0)
		wing_lo.rotation = Vector3(0, -0.2, 0)
	global_position = np

# ------------------------------------------------------------------ 动画
func _process(dt: float) -> void:
	var ow: float = Game.main.ow if Game.main else 0.0
	_eye.emission_energy_multiplier = 1.4 * ow
	if state == S.DEAD:
		return
	rotation.y = yaw
	var flying := state in [S.FLY_UP, S.CIRCLE, S.DIVE, S.RECOVER, S.RETURN]
	var tgt_fold := 0.0 if flying else 1.0
	fold = move_toward(fold, tgt_fold, dt * (5.0 if flying else 2.5))
	var amp := 0.0
	var freq := 11.0
	match state:
		S.FLY_UP:
			amp = 1.0
			freq = 15.0
		S.CIRCLE, S.RETURN:
			# 扇几下、滑翔一会儿
			amp = 0.75 if (vel.y > 0.2 or fmod(t_state, 2.2) < 1.0) else 0.08
			freq = 11.0
		S.RECOVER:
			amp = 1.0
			freq = 14.0
		S.DIVE:
			amp = 0.05
	flap_amp = lerp(flap_amp, amp, clamp(dt * 6.0, 0.0, 1.0))
	flap_ph += dt * freq
	var f := sin(flap_ph) * 0.95 * flap_amp
	var fo := sin(flap_ph - 0.7) * 0.55 * flap_amp
	var dive_tuck := 0.55 if state == S.DIVE else 0.0
	# 收拢：沿身体向后折叠
	var rz := f + 0.12 * (1.0 - fold) - 0.15 * fold
	var ry := -1.45 * fold - dive_tuck
	wing_r.rotation = Vector3(0, ry, rz)
	wing_l.rotation = Vector3(0, -ry, -rz)
	wing_ro.rotation = Vector3(0, -1.9 * fold - dive_tuck * 0.6, fo)
	wing_lo.rotation = Vector3(0, -1.9 * fold - dive_tuck * 0.6, fo)
	for lg in legs:
		(lg as Node3D).visible = fold > 0.5
	# 身体
	if flying:
		body.rotation = Vector3(b_pitch, 0, b_roll)
		body.position.y = 0.14 - sin(flap_ph) * 0.018 * flap_amp
		head.rotation = Vector3(-b_pitch * 0.4, 0, 0)
		tail.rotation.x = -b_pitch * 0.3 + 0.1
	else:
		# 栖息：转头、啄地
		head_t -= dt
		if head_t <= 0.0:
			head_t = rs.randf_range(0.4, 1.8)
			head_tgt = rs.randf_range(-1.1, 1.1) if state == S.PERCH else 0.0
		head_yaw = lerp(head_yaw, head_tgt, clamp(dt * 14.0, 0.0, 1.0))
		peck_t -= dt
		if peck_t <= 0.0 and state == S.PERCH:
			peck_t = rs.randf_range(1.0, 4.0)
			peck_k = 1.0
		peck_k = max(peck_k - dt * 3.2, 0.0)
		var pk := sin(peck_k * PI) if peck_k > 0.0 else 0.0
		body.rotation = Vector3(-0.15 - pk * 0.55, 0, 0)
		body.position.y = 0.14 - pk * 0.03
		head.rotation = Vector3(-pk * 0.6, head_yaw, 0)
		tail.rotation.x = 0.25 + pk * 0.3
	# 扇翅声
	var fv := flap_amp if flying else 0.0
	if fv > 0.15:
		if not flap_snd.playing:
			flap_snd.play(rs.randf() * 1.0)
		flap_snd.volume_db = linear_to_db(fv) - 4.0
		flap_snd.pitch_scale = 0.9 + freq * 0.012
	elif flap_snd.playing:
		flap_snd.volume_db -= dt * 60.0
		if flap_snd.volume_db < -40.0:
			flap_snd.stop()
