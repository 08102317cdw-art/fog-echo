extends Node3D
## 渲染 PH 模型缩略图：front = 从 +Z 方向看
func _aabb(n: Node3D) -> AABB:
	var res := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = (inv * m.global_transform) * m.get_aabb()
		if first:
			res = bb; first = false
		else:
			res = res.merge(bb)
	return res
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var only: String = args.get("only", "")
	var view: String = args.get("view", "q")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.5)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-40, 35, 0)
	dl.light_energy = 1.5
	add_child(dl)
	var cam := Camera3D.new()
	cam.fov = 35
	add_child(cam)
	var d := DirAccess.open("res://assets/ph")
	var names: Array = d.get_directories()
	if only != "":
		names = only.split(",")
	for m in names:
		var ps: PackedScene = load("res://assets/ph/%s/%s_1k.gltf" % [m, m])
		if ps == null:
			continue
		var n: Node3D = ps.instantiate()
		add_child(n)
		var bb := _aabb(n)
		var c := bb.get_center()
		var r := bb.size.length() * 0.5
		var dir := Vector3(0.55, 0.45, 1.0).normalized()
		match view:
			"f": dir = Vector3(0, 0.1, 1).normalized()
			"s": dir = Vector3(1, 0.1, 0).normalized()
			"t": dir = Vector3(0, 1, 0.01).normalized()
			"b": dir = Vector3(-0.55, 0.45, -1.0).normalized()
		var dist := r / tan(deg_to_rad(17.5)) * 1.05
		cam.look_at_from_position(c + dir * dist, c)
		for i in 4:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/shots/ph_%s_%s.png" % [m, view])
		n.queue_free()
		await get_tree().process_frame
	print("SHEET DONE")
	get_tree().quit()
