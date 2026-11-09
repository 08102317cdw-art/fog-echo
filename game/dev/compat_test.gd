extends Node3D
# 开发用：兼容渲染器 screen texture 测试
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.5, 0.8)
	env.glow_enabled = "glow" in args
	env.adjustment_enabled = "adj" in args
	env.fog_enabled = "fog" in args
	if "filmic" in args:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	var vp := get_viewport()
	if "msaa" in args:
		vp.msaa_3d = Viewport.MSAA_2X
	if "fxaa" in args:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if "scale" in args:
		vp.scaling_3d_scale = 0.75
	if "deband" in args:
		vp.use_debanding = true
	add_child(we)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 0, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.2, 0.1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	add_child(mi)
	if "probe" in args:
		var rp := ReflectionProbe.new()
		rp.size = Vector3(10, 5, 10)
		rp.interior = true
		rp.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		rp.ambient_color = Color(0.4, 0.4, 0.4)
		add_child(rp)
	if "shadow" in args:
		var dl := DirectionalLight3D.new()
		dl.shadow_enabled = true
		add_child(dl)
		var sl := SpotLight3D.new()
		sl.shadow_enabled = true
		add_child(sl)
	if "omni" in args:
		var ol := OmniLight3D.new()
		ol.shadow_enabled = true
		add_child(ol)
	if "subvp" in args:
		var ucl := CanvasLayer.new()
		ucl.layer = 10
		add_child(ucl)
		var root := Control.new()
		root.visible = "subvis" in args
		ucl.add_child(root)
		var inv_vp := SubViewport.new()
		inv_vp.size = Vector2i(512, 512)
		inv_vp.transparent_bg = true
		inv_vp.own_world_3d = true
		inv_vp.msaa_3d = Viewport.MSAA_4X
		inv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.size = Vector2(420, 420)
		root.add_child(svc)
		svc.add_child(inv_vp)
		var c2 := Camera3D.new()
		inv_vp.add_child(c2)
	if "prox" in args:
		var pm := MeshInstance3D.new()
		pm.mesh = QuadMesh.new()
		var wm := StandardMaterial3D.new()
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.albedo_color = Color(1, 1, 1, 0.3)
		wm.proximity_fade_enabled = true
		wm.proximity_fade_distance = 1.5
		pm.material_override = wm
		pm.position = Vector3(0.8, 0, 1)
		add_child(pm)
	var cl := CanvasLayer.new()
	add_child(cl)
	if "bb" in args:
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		cl.add_child(bb)
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D st : hint_screen_texture, filter_linear, repeat_disable;\nvoid fragment(){ COLOR = vec4(texture(st, SCREEN_UV).rgb, 1.0); }"
	sm.shader = sh
	if "realpost" in args:
		sm.shader = load("res://shaders/post.gdshader")
	cr.material = sm
	if not ("nopost" in args):
		cl.add_child(cr)
	if "lateresize" in args:
		for i in 4:
			await get_tree().process_frame
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(640, 360)
	if "resize" in args:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(640, 360)
	for i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	var c2 := img.get_pixel(5, 5)
	print("RESULT ", args, " center=", c, " corner=", c2)
	get_tree().quit()
