extends Node3D
## 怪物喷出的酸液：抛物线飞行，命中玩家造成伤害，落地留下冒烟的酸液滩（持续灼烧）

const G := 9.0
static var _ball: Mesh
static var _drop: Mesh
static var _pool_mat: Material
static var _smoke_mat: Material
static var _blood: Texture2D

var vel := Vector3.ZERO
var life := 0.0
var dmg := 12.0
var src: Node
var trail: CPUParticles3D
var ball: MeshInstance3D
var done := false

static func _init_res() -> void:
	if _ball:
		return
	_blood = load("res://assets/tex/blood.png")
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.13
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.45, 0.08)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.5, 0.05)
	m.emission_energy_multiplier = 1.6
	m.roughness = 0.08
	sm.material = m
	_ball = sm
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.0
	dm.radial_segments = 6
	dm.rings = 3
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.36, 0.4, 0.06)
	m2.emission_enabled = true
	m2.emission = Color(0.3, 0.38, 0.03)
	m2.emission_energy_multiplier = 1.0
	m2.roughness = 0.1
	dm.material = m2
	_drop = dm
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _blood
	pm.albedo_color = Color(0.4, 0.46, 0.07, 0.95)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.emission_enabled = true
	pm.emission = Color(0.16, 0.22, 0.02)
	pm.emission_texture = _blood
	pm.roughness = 0.05
	pm.metallic_specular = 0.9
	_pool_mat = pm
	var smk := StandardMaterial3D.new()
	smk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smk.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smk.vertex_color_use_as_albedo = true
	smk.albedo_texture = load("res://assets/tex/dot.png")
	_smoke_mat = smk

func launch(from: Vector3, target: Vector3, who: Node) -> void:
	_init_res()
	src = who
	global_position = from
	var d := target - from
	var hd := Vector2(d.x, d.z).length()
	var T: float = clamp(hd / 10.5, 0.25, 1.1)
	vel = Vector3(d.x / T, d.y / T + 0.5 * G * T, d.z / T)
	ball = MeshInstance3D.new()
	ball.mesh = _ball
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.8, 0.2)
	l.light_energy = 0.7
	l.omni_range = 2.2
	add_child(l)
	trail = CPUParticles3D.new()
	trail.amount = 36
	trail.lifetime = 0.45
	trail.local_coords = false
	trail.mesh = _drop
	trail.direction = Vector3(0, -1, 0)
	trail.spread = 60.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, -7.0, 0)
	trail.scale_amount_min = 0.015
	trail.scale_amount_max = 0.04
	add_child(trail)

func _physics_process(dt: float) -> void:
	if done:
		return
	life += dt
	var p0 := global_position
	vel.y -= G * dt
	var p1 := p0 + vel * dt
	# 玩家
	var pl: Node3D = Game.player
	if pl and not pl.dead and pl.enabled:
		var c := pl.global_position + Vector3(0, 1.0, 0)
		var seg := p1 - p0
		var tt: float = clamp((c - p0).dot(seg) / max(seg.length_squared(), 1e-6), 0.0, 1.0)
		var q := p0 + seg * tt
		var dd := q - c
		if Vector2(dd.x, dd.z).length() < 0.42 and abs(dd.y) < 0.85:
			pl.hurt(dmg, p0 - vel.normalized() * 2.0)
			Game.sfx("acid_hit", -2.0, randf_range(0.95, 1.1))
			if Game.main and Game.main.has_method("acid_flash"):
				Game.main.acid_flash()
			var fp := pl.global_position
			if Game.world:
				fp.y = Game.world.floor_h(fp)
			_splash(fp, false)
			return
	# 场景
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(p0, p1, 1)
	if src and is_instance_valid(src):
		rq.exclude = [(src as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(rq)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		if (hit.normal as Vector3).y > 0.6:
			_splash(hp, true)
		else:
			# 撞墙：顺墙流到地面
			var fp := hp + (hit.normal as Vector3) * 0.25
			fp.y = Game.world.floor_h(fp) if Game.world else 0.0
			_splash(fp, true, 0.7)
		return
	var fh: float = Game.world.floor_h(p1) if Game.world else 0.0
	if p1.y <= fh + 0.02:
		_splash(Vector3(p1.x, fh, p1.z), true)
		return
	global_position = p1
	if life > 3.5:
		queue_free()

func _splash(at: Vector3, sound: bool, sz := 1.0) -> void:
	done = true
	if ball:
		ball.queue_free()
	for ch in get_children():
		if ch is OmniLight3D:
			ch.queue_free()
	if trail:
		trail.emitting = false
	var pool := AcidPool.new()
	get_parent().add_child(pool)
	pool.start(at, sz, _pool_mat, _smoke_mat, _drop, sound)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)

class AcidPool extends Node3D:
	var t := 0.0
	var tick := 0.0
	var dur := 6.5
	var plane: MeshInstance3D
	var smoke: CPUParticles3D
	var snd: AudioStreamPlayer3D
	var rad := 0.85

	func start(at: Vector3, sz: float, pm: Material, smm: Material, drop: Mesh, sound: bool) -> void:
		global_position = at + Vector3(0, 0.025, 0)
		rad = 0.85 * sz
		var q := PlaneMesh.new()
		q.size = Vector2(1.9, 1.9) * sz
		plane = MeshInstance3D.new()
		plane.mesh = q
		plane.material_override = pm
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plane.rotation.y = randf() * TAU
		plane.scale = Vector3.ONE * 0.3
		add_child(plane)
		var tw := create_tween()
		tw.tween_property(plane, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var spl := CPUParticles3D.new()
		spl.one_shot = true
		spl.explosiveness = 1.0
		spl.amount = 26
		spl.lifetime = 0.7
		spl.local_coords = false
		spl.mesh = drop
		spl.direction = Vector3(0, 1, 0)
		spl.spread = 70.0
		spl.initial_velocity_min = 1.0
		spl.initial_velocity_max = 2.8
		spl.gravity = Vector3(0, -9.8, 0)
		spl.scale_amount_min = 0.015
		spl.scale_amount_max = 0.035
		add_child(spl)
		spl.emitting = true
		smoke = CPUParticles3D.new()
		smoke.amount = 18
		smoke.lifetime = 1.8
		smoke.local_coords = false
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.5)
		qm.material = smm
		smoke.mesh = qm
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.5 * sz
		smoke.direction = Vector3(0, 1, 0)
		smoke.spread = 15.0
		smoke.initial_velocity_min = 0.2
		smoke.initial_velocity_max = 0.5
		smoke.gravity = Vector3(0, 0.15, 0)
		smoke.scale_amount_min = 0.6
		smoke.scale_amount_max = 1.4
		var g := Gradient.new()
		g.set_color(0, Color(0.55, 0.6, 0.35, 0.0))
		g.set_color(1, Color(0.5, 0.52, 0.4, 0.0))
		g.add_point(0.25, Color(0.5, 0.56, 0.32, 0.22))
		smoke.color_ramp = g
		add_child(smoke)
		smoke.emitting = true
		if sound:
			Game.sfx3d("acid_hit", global_position, -1.0, randf_range(0.9, 1.1), 3.0, 25.0)
		snd = AudioStreamPlayer3D.new()
		var st: AudioStream = Game.stream("acid_loop")
		if st is AudioStreamOggVorbis:
			st.loop = true
		snd.stream = st
		snd.bus = "SFX"
		snd.unit_size = 2.0
		snd.max_distance = 16.0
		snd.volume_db = -2.0
		add_child(snd)
		snd.play(randf() * 2.0)

	func _physics_process(dt: float) -> void:
		t += dt
		var k: float = clamp((dur - t) / 1.5, 0.0, 1.0)
		if snd:
			snd.volume_db = -2.0 + linear_to_db(max(k, 0.001))
		if t > dur - 1.8 and smoke.emitting:
			smoke.emitting = false
		if plane and t > dur - 1.5:
			plane.transparency = 1.0 - k
		tick -= dt
		var pl: Node3D = Game.player
		if tick <= 0.0 and pl and not pl.dead and pl.enabled and t < dur - 0.8:
			var d := pl.global_position - global_position
			if Vector2(d.x, d.z).length() < rad and abs(d.y) < 0.6:
				tick = 0.5
				if pl.has_method("burn"):
					pl.burn(3.0)
				Game.sfx("acid_hit", -14.0, randf_range(1.2, 1.4))
		if t > dur:
			queue_free()
