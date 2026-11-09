extends Node
# 开发用：完整主场景截图。参数 s=name,x,y,z,yaw,pitch,ow,torch,mon  title=name
var main: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()

func fr(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shots/%s.png" % name)
	print("saved ", name, " ", Time.get_ticks_msec())

func _run() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(640, 360)
	await fr(2)
	main.flags["girl_seen"] = true
	var args := OS.get_cmdline_user_args()
	if "simplepost" in args:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform sampler2D st : hint_screen_texture, filter_linear, repeat_disable;\nvoid fragment(){ COLOR = vec4(texture(st, SCREEN_UV).rgb, 1.0); }"
		main.post_mat.shader = sh
	if "dumppost" in args:
		for pn in ["time_s","grain","vignette","saturation","tint","gamma","contrast","noise_amt","damage","lowhp","fade","fade_color","ca","white_flash","warp","pixel"]:
			print("U ", pn, "=", main.post_mat.get_shader_parameter(pn))
	for a in args:
		if a.begins_with("kill="):
			for cls in a.substr(5).split(":"):
				for n in get_tree().root.find_children("*", cls, true, false):
					print("kill ", n)
					n.queue_free()
	if "noenv" in args:
		main.env.glow_enabled = false
		main.env.fog_enabled = false
		main.env.adjustment_enabled = false
		main.env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if "noglow" in args:
		main.env.glow_enabled = false
	if "nofxaa" in args:
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if "noadj" in args:
		main.env.adjustment_enabled = false
	if "hideui" in args:
		main.ui.visible = false
	for a in args:
		if a.begins_with("postlayer="):
			for n in main.get_children():
				if n is CanvasLayer and n != main.ui:
					n.layer = int(a.substr(10))
	if "nopost" in args:
		for n in main.find_children("*", "CanvasItem", true, false):
			if (n as CanvasItem).material == main.post_mat:
				(n as CanvasItem).visible = false
				print("hid post ", n)
	for a in args:
		if a.begins_with("title="):
			main.ui.fade(0.0, 0.01)
			main.title_t = 20.0
			await fr(118)
			save(a.substr(6))
	var began := false
	for a in args:
		if not a.begins_with("s="):
			continue
		var p := a.substr(2).split(",")
		if not began:
			began = true
			main._begin_play()
			main.ui.fade(0.0, 0.01)
		var name := p[0]
		for n in main.actors.get_children():
			n.queue_free()
		var pos := Vector3(float(p[1]), float(p[2]), float(p[3]))
		var o := float(p[6]) if p.size() > 6 else 0.0
		main.ow = o
		main.world.set_ow(o)
		main.world.set_ow_fences(o > 0.5)
		main.flags["ow"] = o > 0.5
		main.player.torch_on = p.size() > 7 and p[7] == "1"
		main.player.global_position = pos
		main.player.velocity = Vector3.ZERO
		main.player.set_yaw_pitch(deg_to_rad(float(p[4])), deg_to_rad(float(p[5])))
		var c: Vector2i = main.world.cell_of(pos)
		var ft: String = main.world.ch(c.x, c.y)
		main.interior = 1.0 if (ft == "w" or ft == "k") else 0.0
		main.alley_f = 1.0 if ft == "_" else 0.0
		if p.size() > 8 and p[8] != "":
			var mp := p[8].split(":")
			var m: CharacterBody3D = load("res://scripts/monster.gd").new()
			m.setup("shot", Vector3(float(mp[0]), 0, float(mp[1])), float(mp[2]), mp.size() > 3 and mp[3].contains("c"))
			if mp.size() > 4:
				m.preview = mp[4]
				m.dormant = mp[4] == "dormant"
			main.actors.add_child(m)
			m.set_physics_process(false)
		if p.size() > 9 and p[9] != "":
			var gp := p[9].split(":")
			var g: Node3D = load("res://scripts/girl.gd").new()
			main.actors.add_child(g)
			g.start([Vector3(float(gp[0]), 0, float(gp[1]))])
			g.hold = true
		await fr(9)
		save(name)
	get_tree().quit()
