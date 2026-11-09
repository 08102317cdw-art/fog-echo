extends CharacterBody3D
## 第一人称玩家：移动、体力、手电筒、钢管攻击/踩踏、交互、受伤

signal died

const WALK := 2.3
const RUN := 4.6
const EYE := 1.62

var head: Node3D
var cam: Camera3D
var torch_pivot: Node3D
var torch: SpotLight3D
var torch_glow: OmniLight3D
var pipe_root: Node3D
var yaw := 0.0
var pitch := 0.0
var hp := 100.0
var stamina := 100.0
var enabled := false
var has_pipe := false
var torch_on := false
var dead := false
var exhausted := false
var bob := 0.0
var last_step := 0
var attacking := false
var attack_cd := 0.0
var shake := 0.0
var hurt_flash := 0.0
var cur_interact: Area3D = null
var noise_level := 0.0
var land_dip := 0.0
var stomp_dip := 0.0
var breath: AudioStreamPlayer
var torch_energy := 6.0
var cutscene := false

const PIPE_REST_POS := Vector3(0.3, -0.34, -0.42)
const PIPE_REST_ROT := Vector3(-0.95, 0.18, 0.42)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 72
	cam.near = 0.04
	cam.far = 400.0
	head.add_child(cam)
	# 手电筒（带延迟摆动）
	torch_pivot = Node3D.new()
	torch_pivot.top_level = true
	add_child(torch_pivot)
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.93, 0.8)
	torch.light_energy = 0.0
	torch.spot_range = 27.0
	torch.spot_angle = 32.0
	torch.spot_attenuation = 0.7
	torch.spot_angle_attenuation = 0.85
	torch.shadow_enabled = true
	torch.shadow_bias = 0.04
	torch.shadow_normal_bias = 1.2
	torch.shadow_blur = 1.4
	torch.light_volumetric_fog_energy = 2.2
	torch.light_projector = load("res://assets/tex/flashlight_cookie.png")
	torch.light_specular = 0.6
	torch_pivot.add_child(torch)
	torch_glow = OmniLight3D.new()
	torch_glow.light_color = Color(1.0, 0.9, 0.75)
	torch_glow.omni_range = 2.2
	torch_glow.light_energy = 0.0
	torch_glow.light_volumetric_fog_energy = 0.0
	torch_glow.position = Vector3(0, 0, -0.5)
	torch_pivot.add_child(torch_glow)
	# 钢管视角模型
	pipe_root = Node3D.new()
	pipe_root.position = PIPE_REST_POS
	pipe_root.rotation = PIPE_REST_ROT
	pipe_root.visible = false
	cam.add_child(pipe_root)
	var pm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.019
	cm.bottom_radius = 0.022
	cm.height = 0.95
	cm.radial_segments = 10
	cm.rings = 1
	pm.mesh = cm
	pm.position = Vector3(0, 0.36, 0)
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/tex/rust1_a.png")
	mat.albedo_color = Color(0.75, 0.62, 0.55)
	mat.uv1_scale = Vector3(0.5, 3.0, 1.0)
	mat.metallic = 0.55
	mat.roughness = 0.65
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/tex/rust1_n.png")
	pm.material_override = mat
	pipe_root.add_child(pm)
	# 手（简单的手套形状）
	var hand := MeshInstance3D.new()
	var hm := CapsuleMesh.new()
	hm.radius = 0.045
	hm.height = 0.16
	hand.mesh = hm
	hand.rotation = Vector3(0, 0, PI / 2)
	hand.position = Vector3(0.0, 0.02, 0.0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.09, 0.075, 0.065)
	hmat.roughness = 0.9
	hand.material_override = hmat
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pipe_root.add_child(hand)
	breath = AudioStreamPlayer.new()
	breath.stream = Game.stream("breath")
	breath.bus = "SFX"
	breath.volume_db = -80.0
	add_child(breath)

func set_yaw_pitch(y: float, p: float) -> void:
	yaw = y
	pitch = p
	rotation.y = yaw
	cam.rotation.x = pitch
	torch_pivot.global_transform = cam.global_transform

func look(rel: Vector2) -> void:
	if not enabled or dead or cutscene:
		return
	var s: float = Game.settings.mouse_sens * 0.015
	yaw -= rel.x * s
	var inv := -1.0 if Game.settings.invert_y else 1.0
	pitch = clamp(pitch - rel.y * s * inv, -1.45, 1.45)

func give_pipe() -> void:
	has_pipe = true
	pipe_root.visible = true

func set_torch(on: bool) -> void:
	torch_on = on

func _physics_process(dt: float) -> void:
	attack_cd = max(attack_cd - dt, 0.0)
	var inp := Vector2.ZERO
	if enabled and not dead and not cutscene:
		inp = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var lk := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if lk.length() > 0.1:
			look(lk * dt * 900.0)
	var moving := inp.length() > 0.1
	var want_run := Input.is_action_pressed("run") and moving and not exhausted and enabled
	var spd := RUN if want_run else WALK
	if hp < 30.0:
		spd *= 0.75
	if inp.y > 0.2:
		spd *= 0.8
	var wish := Basis(Vector3.UP, yaw) * Vector3(inp.x, 0, inp.y) * spd
	var hv := Vector2(velocity.x, velocity.z).lerp(Vector2(wish.x, wish.z), clamp(dt * 9.0, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.y
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * dt
	_monster_push(dt)
	move_and_slide()
	# 体力
	if want_run and hv.length() > 3.0:
		stamina -= 13.0 * dt
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
	else:
		stamina = min(100.0, stamina + (16.0 if not moving else 9.0) * dt)
		if exhausted and stamina > 35.0:
			exhausted = false
	var sp := hv.length()
	noise_level = 1.0 if (want_run and sp > 3.0) else (0.35 if sp > 0.5 else 0.0)
	# 头部晃动与脚步
	if is_on_floor() and sp > 0.3:
		bob += dt * sp * 2.15
		var idx := int(floor(bob / PI))
		if idx != last_step:
			last_step = idx
			_footstep(sp > 3.0)
	else:
		bob = lerp(bob, round(bob / PI) * PI, clamp(dt * 3.0, 0.0, 1.0))
	if enabled and not dead:
		_interact_scan()
		if not cutscene:
			if Input.is_action_just_pressed("interact") and cur_interact and Game.main:
				Game.main.interact(cur_interact)
			if Input.is_action_just_pressed("flashlight"):
				torch_on = not torch_on
				Game.sfx("click", -6.0)
			if Input.is_action_just_pressed("attack"):
				_try_attack()

func _process(dt: float) -> void:
	rotation.y = yaw
	var amp: float = clamp(Vector2(velocity.x, velocity.z).length() / WALK, 0.0, 1.6)
	var by := sin(bob * 2.0) * 0.035 * amp
	var bx := cos(bob) * 0.028 * amp
	if not dead:
		head.position = Vector3(bx, EYE + by - stomp_dip, 0)
		cam.rotation.x = pitch
		cam.rotation.z = lerp(cam.rotation.z, -Input.get_axis("move_left", "move_right") * 0.012 if enabled else 0.0, clamp(dt * 5.0, 0.0, 1.0))
	shake = max(shake - dt * 1.4, 0.0)
	hurt_flash = max(hurt_flash - dt * 2.0, 0.0)
	cam.h_offset = randf_range(-1, 1) * shake * 0.06
	cam.v_offset = randf_range(-1, 1) * shake * 0.06
	# 手电筒跟随（延迟）
	var target := cam.global_transform
	var tp := target.origin + target.basis * Vector3(0.16, -0.25, -0.1)
	var q0 := torch_pivot.global_transform.basis.get_rotation_quaternion()
	var q1 := (target.basis * Basis(Vector3.RIGHT, -0.1)).get_rotation_quaternion()
	var q := q0.slerp(q1, clamp(dt * 11.0, 0.0, 1.0))
	torch_pivot.global_transform = Transform3D(Basis(q), tp)
	var flick := 1.0
	if Game.main and Game.main.ow > 0.5 and randf() < 0.004:
		flick = randf_range(0.2, 0.7)
	var te := torch_energy * flick if torch_on else 0.0
	torch.light_energy = lerp(torch.light_energy, te, clamp(dt * 20.0, 0.0, 1.0))
	torch_glow.light_energy = torch.light_energy * 0.06
	# 武器摆动
	if has_pipe and not attacking:
		var sway := Vector3(bx * 0.6, by * 0.5, 0)
		pipe_root.position = pipe_root.position.lerp(PIPE_REST_POS + sway, clamp(dt * 10.0, 0.0, 1.0))
	# 呼吸声
	var tired: float = clamp((60.0 - stamina) / 60.0, 0.0, 1.0)
	var hurt_b: float = clamp((45.0 - hp) / 45.0, 0.0, 1.0)
	var bv: float = max(tired, hurt_b * 0.8)
	if bv > 0.02 and not dead:
		if not breath.playing:
			breath.play()
		breath.volume_db = linear_to_db(bv * 0.9)
		breath.pitch_scale = 1.0 + tired * 0.15
	elif breath.playing:
		breath.volume_db = lerp(breath.volume_db, -60.0, dt * 3.0)
		if breath.volume_db < -50.0:
			breath.stop()

func _footstep(run: bool) -> void:
	var surf := "concrete"
	if Game.world:
		surf = Game.world.surface_at(global_position)
	Game.sfx("step_" + surf, (-7.0 if run else -11.0), randf_range(0.92, 1.08))

func _monster_push(dt: float) -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		var mm := m as Node3D
		if not m.call("blocks"):
			continue
		var d := global_position - mm.global_position
		d.y = 0
		var l := d.length()
		if l < 0.75 and l > 0.001:
			var push := d / l * (0.75 - l) * 8.0
			velocity.x += push.x
			velocity.z += push.z

func _interact_scan() -> void:
	cur_interact = null
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 2.3, 1 | 8)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var res := space.intersect_ray(q)
	if res and res.collider is Area3D and (res.collider as Area3D).has_meta("iid"):
		cur_interact = res.collider
		return
	if Game.world == null:
		return
	var best := 0.0
	for a in Game.world.interact_root.get_children():
		var ar := a as Area3D
		if ar == null or not ar.has_meta("iid"):
			continue
		var d := ar.global_position - from
		var l := d.length()
		if l > 1.9:
			continue
		var dot := d.normalized().dot(fwd)
		if dot > 0.86 and dot > best:
			# 确认中间没有墙
			var q2 := PhysicsRayQueryParameters3D.create(from, ar.global_position, 1)
			q2.exclude = [get_rid()]
			var r2 := space.intersect_ray(q2)
			if r2.is_empty() or (r2.position - from).length() > l - 0.35:
				best = dot
				cur_interact = ar

func _try_attack() -> void:
	if not has_pipe or attacking or attack_cd > 0.0:
		return
	# 优先踩踏倒地/匍匐的怪物
	var fwd := -global_transform.basis.z
	var stomp_t: Node3D = null
	var bd := 2.0
	for m in get_tree().get_nodes_in_group("monster"):
		var mm := m as Node3D
		if not m.call("is_stompable"):
			continue
		var d := mm.global_position - global_position
		d.y = 0
		var l := d.length()
		if l < 1.9 and (l < 0.9 or d.normalized().dot(fwd) > 0.2) and l < bd:
			bd = l
			stomp_t = mm
	if stomp_t:
		_stomp(stomp_t)
	else:
		_swing()

func _swing() -> void:
	attacking = true
	attack_cd = 0.7
	stamina = max(stamina - 6.0, 0.0)
	noise_level = 0.8
	var tw := create_tween()
	tw.tween_property(pipe_root, "rotation", PIPE_REST_ROT + Vector3(0.65, -0.5, -0.55), 0.13).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(pipe_root, "position", PIPE_REST_POS + Vector3(0.1, 0.12, 0.08), 0.13)
	tw.tween_callback(func(): Game.sfx("swing" if randf() < 0.5 else "swing2", -6.0, randf_range(0.9, 1.1)))
	tw.tween_property(pipe_root, "rotation", PIPE_REST_ROT + Vector3(-0.35, 1.25, 0.95), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pipe_root, "position", PIPE_REST_POS + Vector3(-0.38, -0.04, -0.1), 0.12)
	tw.tween_callback(_do_hit)
	tw.tween_property(pipe_root, "rotation", PIPE_REST_ROT, 0.36).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(pipe_root, "position", PIPE_REST_POS, 0.36)
	tw.tween_callback(func(): attacking = false)

func _do_hit() -> void:
	var fwd := -cam.global_transform.basis.z
	var fwd_h := Vector3(fwd.x, 0, fwd.z).normalized()
	var best: Node3D = null
	var bs := -1.0
	for m in get_tree().get_nodes_in_group("monster"):
		var mm := m as Node3D
		if not m.call("is_hittable"):
			continue
		var d := mm.global_position - global_position
		d.y = 0
		var l := d.length()
		if l > 2.15:
			continue
		var dot := d.normalized().dot(fwd_h) if l > 0.01 else 1.0
		if dot < 0.45:
			continue
		var score := dot - l * 0.2
		if score > bs:
			bs = score
			best = mm
	if best:
		best.call("take_hit", randf_range(30.0, 38.0), global_position)
		Game.sfx3d("hit_flesh", best.global_position + Vector3(0, 1.3, 0), 2.0, randf_range(0.9, 1.1))
		shake = max(shake, 0.18)
		return
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 1.7, 1)
	q.exclude = [get_rid()]
	var res := space.intersect_ray(q)
	if res:
		Game.sfx3d("hit_metal", res.position, -2.0, randf_range(0.9, 1.1))
		shake = max(shake, 0.12)

func _stomp(target: Node3D) -> void:
	attacking = true
	attack_cd = 0.8
	stamina = max(stamina - 5.0, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "stomp_dip", 0.32, 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(pipe_root, "position", PIPE_REST_POS + Vector3(0.05, -0.25, 0.1), 0.16)
	tw.tween_callback(func():
		if is_instance_valid(target):
			target.call("take_stomp", randf_range(34.0, 40.0))
			Game.sfx3d("stomp", target.global_position, 2.0, randf_range(0.9, 1.05))
			Game.sfx3d("hit_flesh", target.global_position, -2.0, 0.8)
		shake = max(shake, 0.25))
	tw.tween_property(self, "stomp_dip", 0.0, 0.34).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(pipe_root, "position", PIPE_REST_POS, 0.34)
	tw.tween_callback(func(): attacking = false)

func hurt(dmg: float, from: Vector3) -> void:
	if dead or not enabled:
		return
	hp -= dmg
	shake = 0.45
	hurt_flash = 1.0
	Game.sfx("hit_flesh", -3.0, randf_range(0.8, 0.95))
	var push := global_position - from
	push.y = 0
	if push.length() > 0.01:
		velocity += push.normalized() * 3.5
	if hp <= 0.0:
		hp = 0.0
		die()

func burn(dmg: float) -> void:
	if dead or not enabled:
		return
	hp -= dmg
	hurt_flash = max(hurt_flash, 0.4)
	shake = max(shake, 0.12)
	if hp <= 0.0:
		hp = 0.0
		die()

func heal(v: float) -> void:
	hp = min(100.0, hp + v)

func die() -> void:
	dead = true
	enabled = false
	torch_on = false
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.35, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "rotation:z", 1.3, 1.0).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(cam, "rotation:x", 0.2, 1.0)
	tw.tween_interval(1.2)
	tw.tween_callback(func(): died.emit())
