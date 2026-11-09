extends Node3D
# 开发用：怪物近景预览。参数：out=/tmp/shots/pv  states=idle,scream,...  views=front,side,back,face  t=1.2  crawl=1
var MS = preload("res://scripts/monster.gd")

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var out: String = args.get("out", "/tmp/shots/pv")
	var states: PackedStringArray = (args.get("states", "idle") as String).split(",")
	var views: PackedStringArray = (args.get("views", "front,side,face") as String).split(",")
	var tt := float(args.get("t", "1.5"))
	var crawl: bool = args.get("crawl", "0") == "1"
	var lit: String = args.get("lit", "torch")
	get_viewport().size = Vector2i(640, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.33, 0.34) if lit != "dark" else Color(0.02, 0.01, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.46, 0.48) if lit != "dark" else Color(0.08, 0.05, 0.05)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.35 if lit != "dark" else 0.0
	add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.2, 0.2)
	floor_m.material_override = fm
	add_child(floor_m)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	var spot := SpotLight3D.new()
	spot.spot_range = 12
	spot.spot_angle = 28
	spot.light_energy = 4.0 if lit != "flat" else 0.0
	spot.shadow_enabled = true
	cam.add_child(spot)
	spot.position = Vector3(0.25, -0.15, 0)
	for st in states:
		var m: CharacterBody3D = MS.new()
		m.setup("pv", Vector3.ZERO, 0.0, crawl)
		m.preview = st if st != "idle" else ""
		m.dormant = st == "dormant"
		add_child(m)
		m.set_physics_process(false)
		for i in int(tt * 30):
			await get_tree().process_frame
		for v in views:
			var p := Vector3(0, 1.25, -2.6)
			var look := Vector3(0, 1.0, 0)
			match v:
				"front": p = Vector3(0.0, 1.2, -2.7)
				"side": p = Vector3(-2.5, 1.2, -1.0)
				"back": p = Vector3(0.6, 1.3, 2.6)
				"face": p = Vector3(0.05, 1.55, -0.85); look = Vector3(0.0, 1.45, 0.0)
				"chest": p = Vector3(0.0, 1.3, -0.95); look = Vector3(0.0, 1.25, 0.0)
				"top": p = Vector3(0.0, 2.6, -1.6); look = Vector3(0.0, 0.2, 0.0)
				"low": p = Vector3(-1.2, 0.5, -2.0); look = Vector3(0.0, 0.3, 0.3)
			cam.position = p
			cam.look_at(look)
			for i in 3:
				await get_tree().process_frame
			var nseq := int(args.get("seq", "1"))
			for f in nseq:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s_%s_%s%s.png" % [out, st, v, ("_%02d" % f) if nseq > 1 else ""])
				for k in int(args.get("step", "3")):
					await get_tree().process_frame
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
