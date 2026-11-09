extends Node
# 开发用：死亡→重试→返回标题→继续游戏
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

var tree: SceneTree

func w(sec: float) -> void:
	for i in int(sec * 60.0):
		await tree.process_frame

func log_(s: String) -> void:
	print("[D] ", s)

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
	m.player.global_position = Vector3(32, 0.2, 56)
	await w(1.0)
	log_("cafe_in=%s tag=%s" % [m.flags.get("cafe_in"), Game.checkpoint.get("tag")])
	m._pickup("radio")
	await w(0.5)
	m.player.die()
	await w(3.0)
	log_("mode after die=%s" % m.mode)
	m.ui_retry()
	await w(1.5)
	var m2 = Game.main
	log_("new main=%s same=%s mode=%s pos=%s radio=%s cafe_in=%s monsters=%s hp=%.0f" % [m2, m2 == m, m2.mode, m2.player.global_position, m2.flags.get("radio"), m2.flags.get("cafe_in"), m2.monsters.keys(), m2.player.hp])
	m2.mode = "pause"
	tree.paused = true
	m2.ui.open_pause()
	await w(0.3)
	m2.ui_to_title()
	await w(1.5)
	var m3 = Game.main
	log_("after to_title mode=%s has_save=%s" % [m3.mode, Game.has_save()])
	await w(4.0)
	m3.ui_continue()
	await w(3.0)
	log_("after continue mode=%s pos=%s" % [m3.mode, m3.player.global_position])
	tree.quit()
