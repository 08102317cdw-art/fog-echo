extends Node3D
## 雾中的小女孩剪影：沿路点奔跑，玩家太远时停下回头等待，最后消失在铁丝网后

signal vanished

var points: Array = []
var idx := 0
var state := 0 # 0 等待 1 奔跑 2 消失
var spd := 0.0
var ph := 0.0
var step_acc := 0.0
var t := 0.0
var fade_t := 0.0
var mats: Array = []
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var body: Node3D
var head: Node3D
var yaw := 0.0
var started := false
var hold := false

func _ready() -> void:
	var dress := _mat(Color(0.05, 0.055, 0.07))
	var skin := _mat(Color(0.09, 0.075, 0.07))
	var hair := _mat(Color(0.03, 0.025, 0.02))
	body = Node3D.new()
	add_child(body)
	leg_l = _limb(Vector3(-0.065, 0.56, 0), 0.042, 0.52, skin)
	leg_r = _limb(Vector3(0.065, 0.56, 0), 0.042, 0.52, skin)
	var skirt := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.21
	cm.height = 0.27
	cm.radial_segments = 12
	skirt.mesh = cm
	skirt.material_override = dress
	skirt.position.y = 0.66
	body.add_child(skirt)
	var tor := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.105
	tm.height = 0.42
	tor.mesh = tm
	tor.material_override = dress
	tor.position.y = 0.93
	tor.scale = Vector3(1.0, 1.0, 0.8)
	body.add_child(tor)
	arm_l = _limb(Vector3(-0.14, 1.06, 0), 0.032, 0.42, dress)
	arm_r = _limb(Vector3(0.14, 1.06, 0), 0.032, 0.42, dress)
	head = Node3D.new()
	head.position.y = 1.17
	body.add_child(head)
	var hm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.095
	sm.height = 0.2
	hm.mesh = sm
	hm.material_override = skin
	hm.position.y = 0.06
	head.add_child(hm)
	var hr := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.108
	hs.height = 0.22
	hr.mesh = hs
	hr.material_override = hair
	hr.position = Vector3(0, 0.075, 0.018)
	hr.scale = Vector3(1.05, 1.0, 1.0)
	head.add_child(hr)
	var bob := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.105
	bc.bottom_radius = 0.12
	bc.height = 0.13
	bob.mesh = bc
	bob.material_override = hair
	bob.position = Vector3(0, 0.0, 0.025)
	head.add_child(bob)
	scale = Vector3.ONE * 1.02

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mats.append(m)
	return m

func _limb(p: Vector3, r: float, h: float, m: Material) -> Node3D:
	var piv := Node3D.new()
	piv.position = p
	body.add_child(piv)
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = h
	mi.mesh = cap
	mi.material_override = m
	mi.position.y = -h * 0.5 + r
	piv.add_child(mi)
	return piv

func start(pts: Array) -> void:
	points = pts
	idx = 0
	started = true
	position = points[0]

func _process(dt: float) -> void:
	if not started:
		return
	t += dt
	var p: Node3D = Game.player
	var pd := 999.0
	if p:
		pd = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if hold:
		spd = move_toward(spd, 0.0, dt * 6.0)
		if p:
			_face(p.global_position - global_position, dt * 2.0)
		state = 0
		rotation.y = yaw
		leg_l.rotation.x = lerp(leg_l.rotation.x, 0.0, dt * 4.0)
		leg_r.rotation.x = lerp(leg_r.rotation.x, 0.0, dt * 4.0)
		arm_l.rotation.x = lerp(arm_l.rotation.x, 0.0, dt * 4.0)
		arm_r.rotation.x = lerp(arm_r.rotation.x, 0.0, dt * 4.0)
		body.rotation.x = lerp(body.rotation.x, 0.0, dt * 4.0)
		body.position.y = sin(t * 1.7) * 0.004
		return
	match state:
		0:
			spd = move_toward(spd, 0.0, dt * 6.0)
			if p:
				var to := p.global_position - global_position
				_face(to, dt * 2.5)
			if pd < 12.5 and t > 1.2:
				state = 1
		1:
			spd = move_toward(spd, 3.1, dt * 5.0)
			if pd > 21.0 and idx < points.size() - 2:
				state = 0
		2:
			spd = move_toward(spd, 1.2, dt * 3.0)
			fade_t += dt
			var a: float = clamp(1.0 - fade_t / 1.6, 0.0, 1.0)
			for m in mats:
				(m as StandardMaterial3D).albedo_color.a = a
			if fade_t > 1.7:
				vanished.emit()
				queue_free()
				return
	if spd > 0.05 and idx < points.size():
		var tgt: Vector3 = points[idx]
		var d := tgt - global_position
		d.y = 0
		if d.length() < 0.4:
			idx += 1
			if idx >= points.size():
				idx = points.size() - 1
				spd = 0.0
			elif idx == points.size() - 1 and state != 2:
				state = 2
				for m in mats:
					(m as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		else:
			_face(d, dt * 8.0)
			global_position += d.normalized() * min(spd * dt, d.length())
	rotation.y = yaw
	# 动画
	var amp: float = clamp(spd / 3.0, 0.0, 1.0)
	ph += dt * spd * 4.6
	var s := sin(ph)
	leg_l.rotation.x = s * 0.75 * amp
	leg_r.rotation.x = -s * 0.75 * amp
	arm_l.rotation.x = -s * 0.6 * amp
	arm_r.rotation.x = s * 0.6 * amp
	arm_l.rotation.z = -0.08
	arm_r.rotation.z = 0.08
	body.position.y = abs(cos(ph)) * 0.05 * amp
	body.rotation.x = -0.12 * amp
	if spd < 0.1:
		body.position.y = sin(t * 1.7) * 0.004
	# 脚步
	if spd > 0.5:
		step_acc += dt * spd
		if step_acc > 0.68:
			step_acc = 0.0
			Game.sfx3d("step_concrete", global_position, -13.0, randf_range(1.45, 1.6), 3.0, 30.0)

func _face(d: Vector3, k: float) -> void:
	d.y = 0
	if d.length() < 0.01:
		return
	yaw = lerp_angle(yaw, atan2(-d.x, -d.z), clamp(k, 0.0, 1.0))
