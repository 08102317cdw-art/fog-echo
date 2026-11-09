extends Node
# 开发用：模拟玩家沿街道行走，检查碰撞/可达性与剧情触发
var main: Node
var stuck_log: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()

func w(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().process_frame

func log_(s: String) -> void:
	print("[W] ", s)

func goto(pts: Array, label: String) -> void:
	var pl = main.player
	for tgt in pts:
		var t: Vector3 = tgt
		var best := 1e9
		var since := 0.0
		var total := 0.0
		while true:
			var d := Vector2(t.x - pl.global_position.x, t.z - pl.global_position.z)
			var l := d.length()
			if l < 0.7:
				break
			pl.set_yaw_pitch(atan2(-d.x, -d.y), 0.0)
			Input.action_press("move_forward")
			pl.hp = 100.0
			for m in get_tree().get_nodes_in_group("monster"):
				m.queue_free()
			await get_tree().process_frame
			var dt := 1.0 / 60.0
			total += dt
			since += dt
			if l < best - 0.3:
				best = l
				since = 0.0
			if since > 3.0:
				stuck_log.append([label, pl.global_position, t])
				log_("STUCK %s at %s -> %s" % [label, pl.global_position, t])
				pl.global_position = Vector3(t.x, t.y + 0.3, t.z)
				break
			if get_tree().paused:
				main.ui_resume()
		Input.action_release("move_forward")
	log_("reached %s pos=%s" % [label, pl.global_position])

func _run() -> void:
	await w(0.5)
	main._begin_play()
	await w(0.5)
	var t0 := Time.get_ticks_msec()
	await goto([Vector3(43, 0, 70), Vector3(43, 0, 64.5), Vector3(59, 0, 64.5), Vector3(59, 0, 58), Vector3(59, 0, 46.2)], "alley_end")
	var k := 0
	while not main.flags.get("alley_end", false) and k < 600:
		await get_tree().process_frame
		k += 1
	log_("alley_end=%s girl_gone=%s" % [main.flags.get("alley_end"), main.flags.get("girl_gone")])
	await goto([Vector3(59, 0, 58), Vector3(59, 0, 64.5), Vector3(32, 0, 64.5), Vector3(32, 0, 60.5), Vector3(32, 0, 56), Vector3(34.6, 0, 54.2)], "radio")
	log_("cafe_in=%s" % main.flags.get("cafe_in"))
	main._pickup("radio")
	await goto([Vector3(31, 0, 52.5), Vector3(31, 0, 50.0)], "pipe")
	main._pickup("pipe")
	await goto([Vector3(29.4, 0, 56.2)], "map")
	main._pickup("map")
	await goto([Vector3(32, 0, 56), Vector3(32, 0, 60.5), Vector3(32, 0, 64.5)], "out_cafe")
	log_("spawn2=%s" % main.flags.get("spawn2"))
	await goto([Vector3(76, 0, 63.5), Vector3(76, 0, 46), Vector3(76, 0, 30), Vector3(76, 0, 22), Vector3(60, 0, 22), Vector3(60, 0, 26), Vector3(60, 0, 30), Vector3(56, 0, 37.6)], "drawing")
	main._pickup("drawing")
	await w(0.2)
	main.ui_resume()
	await goto([Vector3(60, 0, 30), Vector3(60, 0, 22), Vector3(43, 0, 22), Vector3(43, 0, 17.6)], "gate")
	main._gate()
	main._pickup("note_gate")
	await w(0.2)
	main.ui_resume()
	await goto([Vector3(60, 0, 22), Vector3(76, 0, 22), Vector3(76, 0, 36), Vector3(82, 0, 36), Vector3(84.4, 0, 40.2)], "doghouse")
	main._doghouse()
	await w(15.0)
	log_("ow=%.2f flags.ow=%s" % [main.ow, main.flags.get("ow")])
	await goto([Vector3(82, 0, 36), Vector3(76, 0, 36), Vector3(76, 0, 22), Vector3(43, 0, 22), Vector3(43, 0, 17.6)], "gate_ow")
	main._gate()
	await w(4.0)
	await goto([Vector3(43, 0, 14.0)], "school")
	await w(1.0)
	log_("ending=%s" % main.flags.get("ending"))
	log_("game time walked; stuck count=%d; real ms=%d" % [stuck_log.size(), Time.get_ticks_msec() - t0])
	get_tree().quit()
