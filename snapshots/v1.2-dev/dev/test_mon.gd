extends Node
# 开发用：新怪物行为测试（喷酸、装死伏击、雾中人影、击杀）
var tree: SceneTree

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func w(sec: float) -> void:
	for i in int(sec * 60.0):
		await tree.process_frame

func log_(s: String) -> void:
	print("[M] ", s)

func tp(m, p: Vector3, yaw := 0.0) -> void:
	m.player.global_position = p
	m.player.velocity = Vector3.ZERO
	m.player.set_yaw_pitch(yaw, 0.0)

func _run() -> void:
	tree = get_tree()
	var par := get_parent()
	par.remove_child(self)
	tree.root.add_child(self)
	tree.change_scene_to_file("res://main.tscn")
	await w(1.0)
	var m = Game.main
	m._begin_play()
	await w(0.3)
	m.flags["girl_seen"] = true
	m._pickup("pipe")
	await w(0.3)
	m.ui_resume()
	await w(0.2)
	m.flags["alley_end"] = true
	# 0) 雾中人影
	tp(m, Vector3(56, 0.2, 64.5), PI / 2)
	await w(0.3)
	var ph = null
	for n in m.actors.get_children():
		if n.get("phantom") == true:
			ph = n
	log_("phantom spawned=%s pos=%s" % [ph != null, ph.global_position if ph else Vector3.ZERO])
	if ph:
		await w(1.0)
		log_("phantom leaving=%s (d=%.1f)" % [ph.leaving, ph.global_position.distance_to(m.player.global_position)])
		tp(m, Vector3(47, 0.2, 64.5), PI / 2)
		await w(1.0)
		log_("phantom leaving=%s state=%d in_group=%s" % [ph.leaving, ph.state, ph.is_in_group("monster")])
		await w(10.0)
		log_("phantom freed=%s" % [not is_instance_valid(ph)])
	# 1) 喷酸：站立怪 7m 外
	tp(m, Vector3(50, 0.2, 65), PI / 2)
	var MS = load("res://scripts/monster.gd")
	var a = MS.new()
	a.setup("t_spit", Vector3(43, 0, 65), -90.0, false)
	a.hunt = true
	m.actors.add_child(a)
	var spits := 0
	var last := -1
	var hp0: float = m.player.hp
	for i in 60 * 12:
		await tree.process_frame
		tp(m, Vector3(50, 0.2, 65), PI / 2) if a.global_position.distance_to(m.player.global_position) < 4.0 and false else null
		if a.state == 8 and last != 8:
			spits += 1
		last = a.state
		if a.global_position.distance_to(m.player.global_position) < 4.5:
			a.global_position = Vector3(43, 0, 65)
	var acid := 0
	for n in m.actors.get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with("acid.gd"):
			acid += 1
	log_("spit: spits=%d player hp %.0f -> %.0f state=%d" % [spits, hp0, m.player.hp, a.state])
	a.queue_free()
	m.player.hp = 100.0
	await w(0.5)
	# 2) 装死伏击
	m._spawn_monster("m_corpse")
	var c = m.monsters.get("m_corpse")
	await w(0.5)
	log_("corpse state=%d groups=%s static=%.2f" % [c.state, c.get_groups(), m.static_level])
	tp(m, Vector3(60, 0.2, 64.5), -PI / 2)
	await w(1.0)
	log_("corpse after 8m: state=%d" % c.state)
	tp(m, Vector3(64.5, 0.2, 64.5), -PI / 2)
	await w(0.5)
	log_("corpse after 3.6m: state=%d" % c.state)
	tp(m, Vector3(66.5, 0.2, 64.8), -PI / 2)
	await w(0.3)
	log_("corpse after close: state=%d" % c.state)
	await w(2.6)
	log_("corpse after wake: state=%d hunt=%s pos=%s" % [c.state, c.hunt, c.global_position])
	# 击杀
	var tries := 0
	while is_instance_valid(c) and c.state != 7 and tries < 60:
		m.player.hp = 100.0
		var d: Vector3 = c.global_position - m.player.global_position
		d.y = 0
		m.player.set_yaw_pitch(atan2(-d.x, -d.z), -0.2)
		if d.length() > 1.6:
			tp(m, c.global_position - d.normalized() * 1.2 + Vector3(0, 0.2, 0), atan2(-d.x, -d.z))
		m.player._try_attack()
		await w(0.85)
		tries += 1
		if tries % 6 == 0:
			log_("  try %d state=%d hp=%.0f down_hp=%.0f d=%.1f" % [tries, c.state, c.hp, c.down_hp, d.length()])
	log_("corpse killed=%s tries=%d killed_list=%s" % [is_instance_valid(c) and c.state == 7, tries, m.killed])
	await w(2.0)
	# 3) 第二只伏击：从身边走过后背后起身
	m.killed.erase("m_corpse")
	m.monsters.erase("m_corpse")
	m._spawn_monster("m_corpse")
	var c2 = m.monsters.get("m_corpse")
	await w(0.3)
	tp(m, Vector3(62, 0.2, 61.0), -PI / 2)
	await w(0.3)
	tp(m, Vector3(68, 0.2, 61.0), -PI / 2)
	await w(0.3)
	tp(m, Vector3(73, 0.2, 61.0), -PI / 2)
	await w(0.4)
	log_("corpse2 pass-by state=%d" % c2.state)
	c2.queue_free()
	m.monsters.erase("m_corpse")
	await w(0.3)
	tree.quit()
