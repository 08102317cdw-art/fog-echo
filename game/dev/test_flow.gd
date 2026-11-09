extends Node
# 开发用：无界面跑通剧情流程
var main: Node
var frames := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()

func w(sec: float) -> void:
	var n := int(sec * 60.0)
	for i in n:
		await get_tree().process_frame

func tp(p: Vector3, yaw := 0.0) -> void:
	main.player.global_position = p
	main.player.velocity = Vector3.ZERO
	main.player.set_yaw_pitch(yaw, 0.0)

func log_(s: String) -> void:
	print("[T %.1f] %s" % [Time.get_ticks_msec() / 1000.0, s])

func _run() -> void:
	await w(1.0)
	log_("mode=%s" % main.mode)
	main.ui_new_game()
	var t0 := 0
	while main.mode != "game" and t0 < 60 * 60:
		await get_tree().process_frame
		t0 += 1
	log_("after intro mode=%s frames=%d obj=%s" % [main.mode, t0, main.objective])
	await w(1.0)
	# 女孩
	tp(Vector3(43, 0.2, 85.5))
	await w(0.5)
	log_("girl_seen=%s girl=%s" % [main.flags.get("girl_seen"), main.girl])
	var g = main.girl
	var k := 0
	while is_instance_valid(g) and k < 60 * 60:
		var gp: Vector3 = g.global_position
		var idx: int = g.idx
		var pts: Array = g.points
		var back: Vector3 = pts[max(idx - 1, 0)]
		var dir := (back - gp)
		dir.y = 0
		if dir.length() < 0.1:
			dir = Vector3(0, 0, 1)
		main.player.global_position = gp + dir.normalized() * 7.0 + Vector3(0, 0.2, 0)
		await get_tree().process_frame
		k += 1
		if k % 300 == 0:
			log_("girl at %s idx=%d state=%d" % [gp, idx, g.state])
	log_("girl gone=%s after %d frames" % [main.flags.get("girl_gone"), k])
	tp(Vector3(59, 0.2, 46.5))
	await w(0.5)
	log_("alley_end=%s obj=%s" % [main.flags.get("alley_end"), main.objective])
	# 咖啡馆
	tp(Vector3(32, 0.2, 56.5))
	await w(1.0)
	log_("cafe_in=%s interior=%.2f" % [main.flags.get("cafe_in"), main.interior])
	main._pickup("map")
	main._pickup("radio")
	await w(0.2)
	var m = main.monsters.get("m_cafe")
	log_("m_cafe=%s" % m)
	var mind := 999.0
	for i in 30:
		await w(1.0)
		main.player.hp = 100.0
		if is_instance_valid(m):
			var d: float = m.global_position.distance_to(main.player.global_position)
			mind = min(mind, d)
			if i % 3 == 0:
				log_("m pos=%s state=%d d=%.1f static=%.2f" % [m.global_position, m.state, d, main.static_level])
			if d < 1.6:
				break
	log_("min dist=%.2f hp=%.1f" % [mind, main.player.hp])
	main._pickup("pipe")
	main._pickup("note_cafe")
	await w(0.3)
	log_("overlay mode=%s paused=%s" % [main.mode, get_tree().paused])
	main.ui_resume()
	await w(0.3)
	# 战斗
	var tries := 0
	while is_instance_valid(m) and m.state != 7 and tries < 40:
		main.player.hp = 100.0
		var d: Vector3 = m.global_position - main.player.global_position
		d.y = 0
		var yaw := atan2(-d.x, -d.z)
		main.player.set_yaw_pitch(yaw, -0.2)
		main.player._try_attack()
		await w(0.85)
		tries += 1
		log_("attack %d m.state=%d hp=%.1f dist=%.2f" % [tries, m.state, m.hp, d.length()])
	await w(1.0)
	log_("killed=%s" % [main.killed])
	# spawn2
	tp(Vector3(32, 0.2, 61.5), PI)
	await w(1.0)
	log_("spawn2=%s monsters=%s" % [main.flags.get("spawn2"), main.monsters.keys()])
	# UI
	main._open_overlay()
	main.ui.open_inventory(main._inv_list())
	await w(0.5)
	main.ui_resume()
	main._open_overlay()
	main.ui.open_map()
	await w(0.5)
	main.ui_resume()
	main.mode = "pause"
	get_tree().paused = true
	main.ui.open_pause()
	await w(0.2)
	main.ui.open_settings("pause")
	await w(0.2)
	main.ui.close_settings()
	main.ui_resume()
	await w(0.2)
	log_("ui ok mode=%s" % main.mode)
	# 公园
	tp(Vector3(56, 0.2, 37.6))
	await w(0.5)
	main._pickup("drawing")
	await w(0.3)
	main.ui_resume()
	log_("drawing obj=%s" % main.objective)
	tp(Vector3(44, 0.2, 17.5), PI)
	await w(0.5)
	main._gate()
	main._pickup("note_gate")
	await w(0.3)
	main.ui_resume()
	log_("note_gate obj=%s" % main.objective)
	tp(Vector3(84.6, 0.2, 39.5), PI)
	await w(0.5)
	main._doghouse()
	await w(3.5)
	log_("trans_t=%.2f ow=%.2f" % [main.trans_t, main.ow])
	await w(12.0)
	log_("after trans ow=%.2f flags.ow=%s monsters=%s torch=%s obj=%s" % [main.ow, main.flags.get("ow"), main.monsters.keys(), main.player.torch_on, main.objective])
	log_("checkpoint tag=%s" % Game.checkpoint.get("tag"))
	# 校门
	tp(Vector3(43, 0.2, 18.0), 0.0)
	main.player.hp = 100.0
	main._gate()
	await w(4.5)
	log_("gate_open=%s" % main.flags.get("gate_open"))
	tp(Vector3(43, 0.2, 14.0), 0.0)
	await w(1.0)
	log_("ending flag=%s ending_t=%.2f" % [main.flags.get("ending"), main.ending_t])
	await w(6.0)
	log_("mode=%s" % main.mode)
	await w(10.0)
	log_("done")
	get_tree().quit()
