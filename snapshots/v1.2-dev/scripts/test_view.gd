extends Node
## 开发用：渲染若干视角截图
var shots := []
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var w = load("res://scripts/world.gd").new()
	w.name = "World"
	add_child(w)
	var ow := 0.0
	for a in args:
		if a.begins_with("ow="):
			ow = float(a.substr(3))
	w.set_ow(ow)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.63, 0.64).lerp(Color(0.02, 0.015, 0.012), ow)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.71, 0.72).lerp(Color(0.09, 0.06, 0.05), ow)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.07
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.025
	env.volumetric_fog_albedo = Color(0.9, 0.9, 0.9)
	env.volumetric_fog_ambient_inject = 0.6 * (1.0 - ow)
	env.ssao_enabled = true
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 30, 0)
	sun.light_energy = 0.35 * (1.0 - ow)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.current = true
	var fl := SpotLight3D.new()
	fl.spot_range = 22; fl.spot_angle = 26; fl.light_energy = 4.0 if ow > 0.5 else 0.0
	fl.shadow_enabled = true
	cam.add_child(fl)
	var views := []
	for a in args:
		if a.begins_with("v="):
			var p := a.substr(2).split(",")
			views.append([Vector3(float(p[0]), float(p[1]), float(p[2])), Vector3(float(p[3]), float(p[4]), float(p[5])), p[6]])
	for v in views:
		cam.position = v[0]
		cam.look_at(v[1])
		for i in 6:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/shots/%s.png" % v[2])
		print("saved ", v[2])
	get_tree().quit()
