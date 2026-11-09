extends CanvasLayer
## 界面：标题、HUD、物品栏（3D 预览）、地图、文档、暂停/设置、死亡、结局

var F_SERIF: Font
var F_BOLD: Font
var F_HAND: Font
var root: Control
var mode := ""
var settings_from := ""

var hud: Control
var prompt_lbl: Label
var msg_panel: PanelContainer
var msg_lbl: Label
var msg_queue: Array = []
var msg_t := 0.0
var obj_lbl: Label
var obj_t := 0.0
var pick_lbl: Label
var pick_t := 0.0
var hint_lbl: Label
var hint_t := 0.0
var radio_lbl: Label
var save_lbl: Label
var save_t := 0.0

var title_root: Control
var title_box: VBoxContainer
var btn_continue: Button
var title_glow := 0.0

var intro_root: Control
var intro_lbl: Label
var intro_skip := false

var inv_root: Control
var inv_name: Label
var inv_desc: Label
var inv_count: Label
var inv_action: Label
var inv_status: Label
var inv_obj: Label
var inv_ecg: Control
var inv_list: Array = []
var inv_sel := 0
var inv_stage: Node3D
var inv_pivot: Node3D
var inv_vp: SubViewport

var map_root: Control
var map_tex: TextureRect
var map_marks: Control

var read_root: Control
var read_paper: TextureRect
var read_lbl: Label
var read_img: TextureRect
var read_cap: Label
var read_pages: Array = []
var read_page := 0
var read_title := ""

var pause_root: Control
var pause_box: VBoxContainer
var set_root: Control
var set_first: Control
var dead_root: Control
var dead_box: VBoxContainer
var end_root: Control
var end_bg: ColorRect
var end_lbl: Label
var end_credits: Label
var end_t := -1.0
var fader: ColorRect
var t := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	F_SERIF = load("res://assets/fonts/serif.otf")
	F_BOLD = load("res://assets/fonts/serif_bold.otf")
	F_HAND = load("res://assets/fonts/hand.ttf")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	_build_hud()
	_build_title()
	_build_intro()
	_build_inventory()
	_build_map()
	_build_reader()
	_build_pause()
	_build_settings()
	_build_dead()
	_build_end()
	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 1)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fader)
	# 浏览器全屏会隐藏网页外层说明，游戏画面内也保留准确版本号。
	if OS.has_feature("web"):
		var web_version := _lbl(root, "v1.1", 14, Color(0.8, 0.78, 0.74))
		web_version.anchor_left = 1.0
		web_version.anchor_right = 1.0
		web_version.position = Vector2(-62, 12)
		web_version.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ------------------------------------------------------------------ 工具
func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = F_SERIF
	th.default_font_size = 22
	var e := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		th.set_stylebox(s, "Button", e)
	th.set_color("font_color", "Button", Color(0.55, 0.53, 0.5))
	th.set_color("font_hover_color", "Button", Color(0.95, 0.92, 0.86))
	th.set_color("font_focus_color", "Button", Color(0.95, 0.92, 0.86))
	th.set_color("font_pressed_color", "Button", Color(0.85, 0.25, 0.18))
	th.set_color("font_hover_pressed_color", "Button", Color(0.85, 0.25, 0.18))
	th.set_color("font_disabled_color", "Button", Color(0.3, 0.3, 0.3))
	th.set_font_size("font_size", "Button", 26)
	th.set_color("font_color", "Label", Color(0.86, 0.84, 0.8))
	var pn := StyleBoxFlat.new()
	pn.bg_color = Color(0.03, 0.03, 0.03, 0.85)
	pn.border_color = Color(0.35, 0.33, 0.3, 0.6)
	pn.set_border_width_all(1)
	pn.set_content_margin_all(10)
	th.set_stylebox("normal", "OptionButton", pn)
	var pnh := pn.duplicate() as StyleBoxFlat
	pnh.border_color = Color(0.85, 0.8, 0.7)
	th.set_stylebox("hover", "OptionButton", pnh)
	th.set_stylebox("focus", "OptionButton", pnh)
	th.set_stylebox("pressed", "OptionButton", pnh)
	th.set_font_size("font_size", "OptionButton", 20)
	th.set_color("font_color", "OptionButton", Color(0.85, 0.83, 0.78))
	th.set_color("font_focus_color", "OptionButton", Color(1, 1, 1))
	th.set_color("font_hover_color", "OptionButton", Color(1, 1, 1))
	th.set_stylebox("panel", "PopupMenu", pn)
	th.set_font_size("font_size", "PopupMenu", 20)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0.25, 0.24, 0.22)
	sl.content_margin_top = 2
	sl.content_margin_bottom = 2
	th.set_stylebox("slider", "HSlider", sl)
	var sa := StyleBoxFlat.new()
	sa.bg_color = Color(0.7, 0.2, 0.15)
	sa.content_margin_top = 2
	sa.content_margin_bottom = 2
	th.set_stylebox("grabber_area", "HSlider", sa)
	th.set_stylebox("grabber_area_highlight", "HSlider", sa)
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.88, 0.85, 0.78))
	var gt := ImageTexture.create_from_image(img)
	var img2 := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img2.fill(Color(1, 0.4, 0.3))
	th.set_icon("grabber", "HSlider", gt)
	th.set_icon("grabber_highlight", "HSlider", ImageTexture.create_from_image(img2))
	th.set_font_size("font_size", "CheckBox", 20)
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		th.set_stylebox(s, "CheckBox", e)
	th.set_color("font_color", "CheckBox", Color(0.8, 0.78, 0.74))
	th.set_color("font_focus_color", "CheckBox", Color(1, 1, 1))
	th.set_color("font_hover_color", "CheckBox", Color(1, 1, 1))
	return th

func _lbl(parent: Control, txt: String, size: int, col := Color(0.86, 0.84, 0.8), font: Font = null) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _shadow(l: Label, a := 0.85) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, a))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)

func _overlay(a: float) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	root.add_child(c)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, a)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	return c

func _btn(parent: Control, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func(): Game.ui_sfx("ui_move", -12.0))
	b.pressed.connect(func():
		Game.ui_sfx("ui_select", -6.0)
		cb.call())
	parent.add_child(b)
	return b

func _spaced(f: Font, sp: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = f
	fv.spacing_glyph = sp
	return fv

var fade_tw: Tween

func fade(to: float, dur: float) -> Tween:
	if fade_tw and fade_tw.is_valid():
		fade_tw.kill()
	var tw := create_tween()
	fade_tw = tw
	tw.tween_property(fader, "color:a", to, dur)
	return tw

# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	prompt_lbl = _lbl(hud, "", 21, Color(0.9, 0.88, 0.82))
	prompt_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.position = Vector2(-200, 70)
	prompt_lbl.size = Vector2(400, 30)
	_shadow(prompt_lbl)
	msg_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.set_content_margin_all(16)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.set_corner_radius_all(2)
	msg_panel.add_theme_stylebox_override("panel", sb)
	msg_panel.anchor_left = 0.5
	msg_panel.anchor_right = 0.5
	msg_panel.anchor_top = 1.0
	msg_panel.anchor_bottom = 1.0
	msg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	msg_panel.offset_bottom = -54
	msg_panel.offset_left = -430
	msg_panel.offset_right = 430
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_panel.modulate.a = 0.0
	hud.add_child(msg_panel)
	msg_lbl = _lbl(msg_panel, "", 23, Color(0.9, 0.88, 0.83))
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.custom_minimum_size = Vector2(790, 0)
	obj_lbl = _lbl(hud, "", 20, Color(0.85, 0.82, 0.75))
	obj_lbl.position = Vector2(46, 38)
	obj_lbl.size = Vector2(700, 60)
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_lbl.modulate.a = 0.0
	_shadow(obj_lbl)
	pick_lbl = _lbl(hud, "", 30, Color(0.92, 0.9, 0.84), F_BOLD)
	pick_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_lbl.position = Vector2(-400, -120)
	pick_lbl.size = Vector2(800, 50)
	pick_lbl.modulate.a = 0.0
	_shadow(pick_lbl)
	hint_lbl = _lbl(hud, "", 17, Color(0.82, 0.8, 0.76))
	hint_lbl.anchor_top = 1.0
	hint_lbl.anchor_bottom = 1.0
	hint_lbl.position = Vector2(40, -200)
	hint_lbl.size = Vector2(520, 170)
	hint_lbl.modulate.a = 0.0
	_shadow(hint_lbl)
	radio_lbl = _lbl(hud, "", 16, Color(0.75, 0.3, 0.25))
	radio_lbl.anchor_left = 1.0
	radio_lbl.anchor_right = 1.0
	radio_lbl.position = Vector2(-260, 34)
	radio_lbl.size = Vector2(220, 30)
	radio_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shadow(radio_lbl)
	save_lbl = _lbl(hud, "", 17, Color(0.8, 0.78, 0.72))
	save_lbl.anchor_left = 1.0
	save_lbl.anchor_right = 1.0
	save_lbl.anchor_top = 1.0
	save_lbl.anchor_bottom = 1.0
	save_lbl.position = Vector2(-300, -60)
	save_lbl.size = Vector2(260, 30)
	save_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	save_lbl.modulate.a = 0.0
	_shadow(save_lbl)
	hud.visible = false

func set_prompt(txt: String) -> void:
	prompt_lbl.text = ("[E]  " + txt) if txt != "" else ""

func message(txt: String, dur := 0.0) -> void:
	if msg_queue.size() > 0 and msg_queue[msg_queue.size() - 1][0] == txt:
		return
	if msg_t > 0.0 and msg_lbl.text == txt:
		return
	msg_queue.append([txt, dur if dur > 0.0 else 2.6 + txt.length() * 0.085])

func clear_messages() -> void:
	msg_queue.clear()
	msg_t = 0.0
	msg_panel.modulate.a = 0.0

func set_objective(txt: String, announce := true) -> void:
	inv_obj.text = txt
	if announce and txt != "":
		obj_lbl.text = "目标 ·  " + txt
		obj_t = 7.0
		Game.ui_sfx("paper", -14.0)

func show_pickup(name: String) -> void:
	pick_lbl.text = "获得  ·  " + name
	pick_t = 2.6

func show_saved() -> void:
	save_lbl.text = "—— 进度已记录 ——"
	save_t = 3.0

func show_hint(txt: String, dur := 14.0) -> void:
	hint_lbl.text = txt
	hint_t = dur

func set_radio_state(txt: String) -> void:
	radio_lbl.text = txt

func _process(dt: float) -> void:
	t += dt
	# 消息
	if msg_t > 0.0:
		msg_t -= dt
		msg_panel.modulate.a = clamp(min(msg_t * 2.5, msg_panel.modulate.a + dt * 5.0), 0.0, 1.0)
		if msg_t <= 0.0:
			msg_panel.modulate.a = 0.0
	elif msg_queue.size() > 0:
		var m: Array = msg_queue.pop_front()
		msg_lbl.text = m[0]
		msg_t = m[1]
		msg_panel.modulate.a = 0.0
	obj_t = max(obj_t - dt, 0.0)
	obj_lbl.modulate.a = clamp(min(obj_t * 0.8, (7.0 - obj_t) * 3.0), 0.0, 1.0)
	pick_t = max(pick_t - dt, 0.0)
	pick_lbl.modulate.a = clamp(min(pick_t * 1.5, (2.6 - pick_t) * 5.0), 0.0, 1.0)
	hint_t = max(hint_t - dt, 0.0)
	hint_lbl.modulate.a = clamp(hint_t * 0.5, 0.0, 0.9)
	save_t = max(save_t - dt, 0.0)
	save_lbl.modulate.a = clamp(min(save_t, (3.0 - save_t) * 3.0), 0.0, 1.0)
	if title_root.visible:
		title_glow += dt
	if inv_root.visible and inv_pivot:
		inv_pivot.rotation.y += dt * 0.7
		inv_ecg.queue_redraw()
	if map_root.visible:
		map_marks.queue_redraw()
	if end_t >= 0.0:
		_end_process(dt)

# ------------------------------------------------------------------ 标题
func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_root.visible = false
	root.add_child(title_root)
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.72))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(shade)
	var t1 := _lbl(title_root, "寂静岭", 104, Color(0.8, 0.77, 0.72), _spaced(F_BOLD, 26))
	t1.position = Vector2(96, 120)
	_shadow(t1, 0.6)
	var t2 := _lbl(title_root, "雾  中  回  响", 36, Color(0.66, 0.2, 0.15), _spaced(F_SERIF, 6))
	t2.position = Vector2(104, 262)
	var t3 := _lbl(title_root, "S I L E N T   H I L L   ·   E C H O E S   I N   T H E   F O G", 15, Color(0.6, 0.58, 0.55))
	t3.position = Vector2(106, 318)
	title_box = VBoxContainer.new()
	title_box.position = Vector2(100, 400)
	title_box.add_theme_constant_override("separation", 6)
	title_root.add_child(title_box)
	_btn(title_box, "开始游戏", func(): Game.main.ui_new_game())
	btn_continue = _btn(title_box, "继续游戏", func(): Game.main.ui_continue())
	_btn(title_box, "设    置", func(): open_settings("title"))
	if not OS.has_feature("web"):
		_btn(title_box, "退出游戏", func(): get_tree().quit())
	var disc := _lbl(title_root, "非官方同人作品 · 与 KONAMI 无关 · 仅供学习交流，请勿商用\n推荐佩戴耳机，在黑暗的房间中游玩", 15, Color(0.55, 0.53, 0.5))
	disc.anchor_top = 1.0
	disc.anchor_bottom = 1.0
	disc.position = Vector2(100, -86)
	disc.size = Vector2(900, 60)

func show_title(has_save: bool) -> void:
	mode = "title"
	title_root.visible = true
	hud.visible = false
	btn_continue.disabled = not has_save
	btn_continue.visible = has_save
	title_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(title_root, "modulate:a", 1.0, 2.5)
	(title_box.get_child(1 if has_save else 0) as Button).grab_focus()

func hide_title() -> void:
	title_root.visible = false

# ------------------------------------------------------------------ 开场
func _build_intro() -> void:
	intro_root = _overlay(1.0)
	intro_lbl = _lbl(intro_root, "", 28, Color(0.86, 0.84, 0.8))
	intro_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sk := _lbl(intro_root, "[E] / 空格  跳过", 15, Color(0.45, 0.44, 0.42))
	sk.anchor_left = 1.0
	sk.anchor_right = 1.0
	sk.anchor_top = 1.0
	sk.anchor_bottom = 1.0
	sk.position = Vector2(-240, -50)

func play_intro(lines: Array) -> void:
	mode = "intro"
	intro_skip = false
	intro_root.visible = true
	intro_root.modulate.a = 1.0
	fader.color.a = 0.0
	for ln in lines:
		if intro_skip:
			break
		intro_lbl.text = ln
		intro_lbl.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(intro_lbl, "modulate:a", 1.0, 1.2)
		var hold := 2.2 + (ln as String).length() * 0.09
		var tt := 0.0
		while tt < hold + 1.2 and not intro_skip:
			await get_tree().process_frame
			tt += get_process_delta_time()
		tw.kill()
		var tw2 := create_tween()
		tw2.tween_property(intro_lbl, "modulate:a", 0.0, 0.9)
		tt = 0.0
		while tt < 1.0 and not intro_skip:
			await get_tree().process_frame
			tt += get_process_delta_time()
	intro_lbl.text = ""
	fader.color.a = 1.0
	intro_root.visible = false
	mode = ""

# ------------------------------------------------------------------ 物品栏
func _build_inventory() -> void:
	inv_root = _overlay(0.8)
	inv_vp = SubViewport.new()
	inv_vp.size = Vector2i(512, 512)
	inv_vp.transparent_bg = true
	inv_vp.own_world_3d = true
	inv_vp.msaa_3d = Viewport.MSAA_4X
	inv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	svc.position = Vector2(-210, -290)
	svc.size = Vector2(420, 420)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_root.add_child(svc)
	svc.add_child(inv_vp)
	inv_stage = Node3D.new()
	inv_vp.add_child(inv_stage)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.12, 0.95)
	cam.fov = 34
	inv_stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0))
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-35, 30, 0)
	dl.light_energy = 1.3
	inv_stage.add_child(dl)
	var ol := OmniLight3D.new()
	ol.position = Vector3(-0.6, 0.3, 0.4)
	ol.light_color = Color(1.0, 0.6, 0.45)
	ol.light_energy = 0.8
	ol.omni_range = 3.0
	inv_stage.add_child(ol)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.34, 0.33)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	inv_stage.add_child(we)
	var la := _lbl(inv_root, "◀", 30, Color(0.6, 0.58, 0.54))
	la.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	la.position = Vector2(-290, -100)
	var ra := _lbl(inv_root, "▶", 30, Color(0.6, 0.58, 0.54))
	ra.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ra.position = Vector2(262, -100)
	inv_name = _lbl(inv_root, "", 32, Color(0.93, 0.9, 0.84), F_BOLD)
	inv_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inv_name.position = Vector2(-400, 140)
	inv_name.size = Vector2(800, 44)
	inv_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_count = _lbl(inv_root, "", 16, Color(0.55, 0.53, 0.5))
	inv_count.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inv_count.position = Vector2(-400, 118)
	inv_count.size = Vector2(800, 22)
	inv_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_desc = _lbl(inv_root, "", 20, Color(0.78, 0.76, 0.72))
	inv_desc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inv_desc.position = Vector2(-390, 192)
	inv_desc.size = Vector2(780, 90)
	inv_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_action = _lbl(inv_root, "", 17, Color(0.62, 0.6, 0.56))
	inv_action.anchor_left = 0.5
	inv_action.anchor_right = 0.5
	inv_action.anchor_top = 1.0
	inv_action.anchor_bottom = 1.0
	inv_action.position = Vector2(-400, -48)
	inv_action.size = Vector2(800, 26)
	inv_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st := _lbl(inv_root, "状 态", 18, Color(0.6, 0.58, 0.54))
	st.position = Vector2(48, 36)
	inv_ecg = Control.new()
	inv_ecg.position = Vector2(48, 66)
	inv_ecg.size = Vector2(300, 74)
	inv_ecg.draw.connect(_draw_ecg)
	inv_root.add_child(inv_ecg)
	inv_status = _lbl(inv_root, "", 20, Color(0.4, 0.8, 0.45), F_BOLD)
	inv_status.position = Vector2(48, 146)
	var ot := _lbl(inv_root, "目 标", 18, Color(0.6, 0.58, 0.54))
	ot.anchor_left = 1.0
	ot.anchor_right = 1.0
	ot.position = Vector2(-430, 36)
	inv_obj = _lbl(inv_root, "", 19, Color(0.82, 0.8, 0.75))
	inv_obj.anchor_left = 1.0
	inv_obj.anchor_right = 1.0
	inv_obj.position = Vector2(-430, 66)
	inv_obj.size = Vector2(390, 150)
	inv_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _draw_ecg() -> void:
	var p: Node3D = Game.player
	var hp: float = p.hp if p else 100.0
	var col := Color(0.35, 0.85, 0.4)
	if hp < 20.0:
		col = Color(0.95, 0.15, 0.1)
	elif hp < 45.0:
		col = Color(0.95, 0.5, 0.15)
	elif hp < 75.0:
		col = Color(0.9, 0.85, 0.25)
	var w := inv_ecg.size.x
	var h := inv_ecg.size.y
	inv_ecg.draw_rect(Rect2(Vector2.ZERO, inv_ecg.size), Color(0.02, 0.05, 0.03, 0.8))
	for gx in range(0, int(w), 20):
		inv_ecg.draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.1, 0.25, 0.12, 0.35), 1.0)
	var beats := 2.5 + (100.0 - hp) / 40.0
	var pts := PackedVector2Array()
	var head := fmod(t * 0.45, 1.0) * w
	for i in range(0, int(w) + 1, 2):
		var x := float(i)
		var ph := fmod(x / w * beats, 1.0)
		var y := 0.0
		if ph > 0.1 and ph < 0.16:
			y = sin((ph - 0.1) / 0.06 * PI) * 0.12
		elif ph > 0.22 and ph < 0.25:
			y = -0.15
		elif ph > 0.25 and ph < 0.29:
			y = 0.85 * (1.0 - abs(ph - 0.27) / 0.02)
		elif ph > 0.29 and ph < 0.32:
			y = -0.3
		elif ph > 0.42 and ph < 0.52:
			y = sin((ph - 0.42) / 0.1 * PI) * 0.2
		pts.append(Vector2(x, h * 0.6 - y * h * 0.55))
	inv_ecg.draw_polyline(pts, Color(col, 0.25), 2.0, true)
	var lit := PackedVector2Array()
	for pt in pts:
		var dx := head - pt.x
		if dx >= 0.0 and dx < w * 0.45:
			lit.append(pt)
	if lit.size() > 1:
		inv_ecg.draw_polyline(lit, col, 2.4, true)
	var stt := "良 好"
	if hp < 20.0:
		stt = "危 险"
	elif hp < 45.0:
		stt = "警 告"
	elif hp < 75.0:
		stt = "注 意"
	inv_status.text = stt
	inv_status.add_theme_color_override("font_color", col)

func open_inventory(list: Array, sel := 0) -> void:
	mode = "inv"
	inv_list = list
	inv_sel = clamp(sel, 0, max(list.size() - 1, 0))
	inv_root.visible = true
	inv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Game.ui_sfx("ui_open", -6.0)
	_inv_refresh()

func close_overlay() -> void:
	inv_root.visible = false
	map_root.visible = false
	read_root.visible = false
	inv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mode = ""

func _inv_refresh() -> void:
	if inv_pivot:
		inv_pivot.queue_free()
		inv_pivot = null
	if inv_list.is_empty():
		inv_name.text = "（空）"
		inv_desc.text = ""
		inv_count.text = ""
		inv_action.text = "[Tab] 返回"
		return
	var e: Dictionary = inv_list[inv_sel]
	var it: Dictionary = Game.main.ITEMS[e.id]
	inv_name.text = it.name + (("  ×%d" % e.n) if e.n > 1 else "")
	inv_desc.text = it.desc
	inv_count.text = "%d / %d" % [inv_sel + 1, inv_list.size()]
	var act := ""
	match it.kind:
		"use": act = "[E] 使用    "
		"doc": act = "[E] 阅读    "
		"map": act = "[E] 查看    "
		"radio": act = "[E] 开 / 关    "
		"torch": act = "[E] 开 / 关    "
	inv_action.text = act + "[A / D] 切换    [Tab] 返回"
	inv_pivot = Node3D.new()
	inv_pivot.rotation.x = 0.35
	inv_stage.add_child(inv_pivot)
	var m := _item_model(e.id)
	inv_pivot.add_child(m)

func _sm(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _paper_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _item_model(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"torch":
			var c := CylinderMesh.new()
			c.top_radius = 0.035; c.bottom_radius = 0.035; c.height = 0.2
			_mesh(n, c, _sm(Color(0.08, 0.08, 0.08), 0.3, 0.5), Vector3.ZERO, Vector3(0, 0, PI / 2))
			var h := CylinderMesh.new()
			h.top_radius = 0.05; h.bottom_radius = 0.036; h.height = 0.06
			_mesh(n, h, _sm(Color(0.5, 0.5, 0.48), 0.9, 0.3), Vector3(0.13, 0, 0), Vector3(0, 0, -PI / 2))
			var l := CylinderMesh.new()
			l.top_radius = 0.045; l.bottom_radius = 0.045; l.height = 0.005
			var lm := _sm(Color(1, 0.95, 0.8))
			lm.emission_enabled = true
			lm.emission = Color(1, 0.9, 0.7)
			_mesh(n, l, lm, Vector3(0.162, 0, 0), Vector3(0, 0, -PI / 2))
			n.scale = Vector3.ONE * 1.6
		"radio":
			var ps: PackedScene = load("res://assets/models/radio.glb")
			var r: Node3D = ps.instantiate()
			n.add_child(r)
			r.scale = Vector3.ONE * 0.75
			r.position = Vector3(0, -0.12, 0)
		"pipe":
			var c := CylinderMesh.new()
			c.top_radius = 0.022; c.bottom_radius = 0.022; c.height = 0.72; c.radial_segments = 12
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/tex/rust1_a.png")
			m.uv1_scale = Vector3(1, 3, 1)
			m.metallic = 0.6
			m.roughness = 0.75
			_mesh(n, c, m, Vector3.ZERO, Vector3(0, 0, PI / 2 - 0.4))
		"drink":
			var c := CylinderMesh.new()
			c.top_radius = 0.045; c.bottom_radius = 0.045; c.height = 0.17
			_mesh(n, c, _sm(Color(0.75, 0.76, 0.78), 0.85, 0.3))
			var b := CylinderMesh.new()
			b.top_radius = 0.0455; b.bottom_radius = 0.0455; b.height = 0.09
			_mesh(n, b, _sm(Color(0.12, 0.45, 0.32), 0.2, 0.5))
			n.scale = Vector3.ONE * 1.7
		"aid":
			var b := BoxMesh.new()
			b.size = Vector3(0.3, 0.2, 0.09)
			_mesh(n, b, _sm(Color(0.85, 0.84, 0.8), 0.0, 0.6))
			var c1 := BoxMesh.new()
			c1.size = Vector3(0.11, 0.035, 0.01)
			var red := _sm(Color(0.75, 0.08, 0.06))
			_mesh(n, c1, red, Vector3(0, 0, 0.047))
			var c2 := BoxMesh.new()
			c2.size = Vector3(0.035, 0.11, 0.01)
			_mesh(n, c2, red, Vector3(0, 0, 0.047))
		"key":
			var brass := _sm(Color(0.72, 0.56, 0.25), 0.9, 0.35)
			var tor := TorusMesh.new()
			tor.inner_radius = 0.025; tor.outer_radius = 0.045
			_mesh(n, tor, brass, Vector3(-0.09, 0, 0), Vector3(PI / 2, 0, 0))
			var sh := BoxMesh.new()
			sh.size = Vector3(0.15, 0.016, 0.008)
			_mesh(n, sh, brass, Vector3(0.02, 0, 0))
			for i in 3:
				var tb := BoxMesh.new()
				tb.size = Vector3(0.012, 0.025 + 0.01 * (i % 2), 0.008)
				_mesh(n, tb, brass, Vector3(0.06 + i * 0.02, -0.018, 0))
			var tag := QuadMesh.new()
			tag.size = Vector2(0.08, 0.05)
			_mesh(n, tag, _sm(Color(0.85, 0.8, 0.65)), Vector3(-0.15, -0.05, 0.0), Vector3(0, 0, 0.5))
			n.scale = Vector3.ONE * 2.2
		"map":
			var q := QuadMesh.new()
			q.size = Vector2(0.42, 0.47)
			_mesh(n, q, _paper_mat(load("res://assets/ui/map.png")))
		"drawing":
			var q := QuadMesh.new()
			q.size = Vector2(0.5, 0.356)
			_mesh(n, q, _paper_mat(load("res://assets/tex/drawing.png")))
		_:
			var q := QuadMesh.new()
			q.size = Vector2(0.36, 0.46)
			_mesh(n, q, _paper_mat(load("res://assets/tex/paper.png")))
			for i in 9:
				var ln := QuadMesh.new()
				ln.size = Vector2(0.26 - (0.1 if i == 8 else 0.0), 0.006)
				_mesh(n, ln, _sm(Color(0.2, 0.18, 0.2)), Vector3(-0.02 * float(i == 8), 0.16 - i * 0.035, 0.001))
	return n

func inv_selected() -> String:
	if inv_list.is_empty():
		return ""
	return inv_list[inv_sel].id

# ------------------------------------------------------------------ 地图
func _build_map() -> void:
	map_root = _overlay(0.88)
	map_tex = TextureRect.new()
	map_tex.texture = load("res://assets/ui/map.png")
	map_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_tex.anchor_right = 1.0
	map_tex.anchor_bottom = 1.0
	map_tex.offset_top = 16
	map_tex.offset_bottom = -44
	map_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(map_tex)
	map_marks = Control.new()
	map_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_marks.draw.connect(_draw_marks)
	map_tex.add_child(map_marks)
	var h := _lbl(map_root, "[M] / [Tab] 关闭", 16, Color(0.6, 0.58, 0.55))
	h.anchor_left = 0.5
	h.anchor_right = 0.5
	h.anchor_top = 1.0
	h.anchor_bottom = 1.0
	h.position = Vector2(-100, -36)
	h.size = Vector2(200, 24)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func open_map() -> void:
	mode = "map"
	map_root.visible = true
	Game.ui_sfx("paper", -4.0)

func _map_xf() -> Array:
	var ts := Vector2(1060, 1180)
	var rs := map_marks.size
	var s: float = min(rs.x / ts.x, rs.y / ts.y)
	var off := (rs - ts * s) * 0.5
	return [s, off]

func _mp(wx: float, wz: float) -> Vector2:
	var xf := _map_xf()
	return xf[1] + Vector2(80.0 + wx * 10.0, 120.0 + wz * 10.0) * float(xf[0])

func _draw_marks() -> void:
	var red := Color(0.72, 0.06, 0.04, 0.85)
	var s: float = _map_xf()[0]
	var marks: Array = Game.main.map_marks() if Game.main else []
	for mk in marks:
		var p := _mp(mk[1], mk[2])
		match mk[0]:
			"circle":
				var r: float = mk[3] * 10.0 * s
				map_marks.draw_arc(p, r, 0, TAU, 40, red, 3.0 * s + 1.0, true)
				map_marks.draw_arc(p + Vector2(1.5, -1), r * 0.96, 0.3, TAU - 0.4, 40, Color(red, 0.5), 2.0 * s + 0.5, true)
			"x":
				var r: float = mk[3] * 10.0 * s
				map_marks.draw_line(p + Vector2(-r, -r), p + Vector2(r, r), red, 4.0 * s + 1.0, true)
				map_marks.draw_line(p + Vector2(r, -r), p + Vector2(-r, r), red, 4.0 * s + 1.0, true)
			"text":
				map_marks.draw_string(F_HAND, p, mk[3], HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * s) + 6, red)
	var pl: Node3D = Game.player
	if pl:
		var p := _mp(pl.global_position.x, pl.global_position.z)
		var yaw: float = pl.rotation.y
		var f := Vector2(-sin(yaw), -cos(yaw))
		var rgt := Vector2(-f.y, f.x)
		var sz := 26.0 * s + 6.0
		var pts := PackedVector2Array([p + f * sz, p - f * sz * 0.6 + rgt * sz * 0.55, p - f * sz * 0.25, p - f * sz * 0.6 - rgt * sz * 0.55])
		var a := 0.6 + 0.4 * sin(t * 6.0)
		map_marks.draw_colored_polygon(pts, Color(0.85, 0.1, 0.05, a))

# ------------------------------------------------------------------ 文档
func _build_reader() -> void:
	read_root = _overlay(0.82)
	read_paper = TextureRect.new()
	read_paper.texture = load("res://assets/tex/paper.png")
	read_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	read_paper.stretch_mode = TextureRect.STRETCH_SCALE
	read_paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	read_paper.position = Vector2(-330, -330)
	read_paper.size = Vector2(660, 620)
	read_paper.modulate = Color(0.92, 0.88, 0.8)
	read_root.add_child(read_paper)
	read_lbl = _lbl(read_paper, "", 25, Color(0.13, 0.11, 0.12), F_HAND)
	read_lbl.position = Vector2(56, 50)
	read_lbl.size = Vector2(548, 520)
	read_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	read_lbl.add_theme_constant_override("line_spacing", 8)
	read_img = TextureRect.new()
	read_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	read_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	read_img.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	read_img.position = Vector2(-450, -330)
	read_img.size = Vector2(900, 600)
	read_root.add_child(read_img)
	read_cap = _lbl(read_root, "", 18, Color(0.65, 0.63, 0.6))
	read_cap.anchor_left = 0.5
	read_cap.anchor_right = 0.5
	read_cap.anchor_top = 1.0
	read_cap.anchor_bottom = 1.0
	read_cap.position = Vector2(-450, -50)
	read_cap.size = Vector2(900, 30)
	read_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func read_doc(title: String, pages: Array) -> void:
	mode = "read"
	read_root.visible = true
	read_title = title
	read_pages = pages
	read_page = 0
	read_paper.visible = true
	read_img.visible = false
	Game.ui_sfx("paper", -2.0)
	_read_refresh()

func _read_refresh() -> void:
	read_lbl.text = read_pages[read_page]
	var more := "    [E] 下一页" if read_page < read_pages.size() - 1 else "    [E] 关闭"
	read_cap.text = read_title + ("  (%d/%d)" % [read_page + 1, read_pages.size()] if read_pages.size() > 1 else "") + more

func show_image(tex: Texture2D, caption: String) -> void:
	mode = "read"
	read_root.visible = true
	read_pages = []
	read_paper.visible = false
	read_img.visible = true
	read_img.texture = tex
	read_cap.text = caption + "    [E] 关闭"
	Game.ui_sfx("paper", -2.0)

# ------------------------------------------------------------------ 暂停 / 设置
func _build_pause() -> void:
	pause_root = _overlay(0.66)
	var tl := _lbl(pause_root, "暂  停", 44, Color(0.8, 0.77, 0.72), F_BOLD)
	tl.position = Vector2(100, 150)
	pause_box = VBoxContainer.new()
	pause_box.position = Vector2(104, 250)
	pause_box.add_theme_constant_override("separation", 6)
	pause_root.add_child(pause_box)
	_btn(pause_box, "继续游戏", func(): Game.main.ui_resume())
	_btn(pause_box, "设    置", func(): open_settings("pause"))
	_btn(pause_box, "操作说明", func(): Game.main.ui_show_controls())
	_btn(pause_box, "返回标题", func(): Game.main.ui_to_title())
	if not OS.has_feature("web"):
		_btn(pause_box, "退出游戏", func(): get_tree().quit())

func open_pause() -> void:
	mode = "pause"
	pause_root.visible = true
	(pause_box.get_child(0) as Button).grab_focus()
	Game.ui_sfx("ui_open", -6.0)

func close_pause() -> void:
	pause_root.visible = false
	mode = ""

func _build_settings() -> void:
	set_root = _overlay(0.8)
	var tl := _lbl(set_root, "设  置", 40, Color(0.8, 0.77, 0.72), F_BOLD)
	tl.position = Vector2(100, 60)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(104, 140)
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	set_root.add_child(grid)
	var S: Dictionary = Game.settings
	set_first = _slider(grid, "鼠标灵敏度", "mouse_sens", 0.04, 0.5, 0.01)
	_slider(grid, "画面亮度", "brightness", 0.6, 1.8, 0.05)
	_slider(grid, "胶片颗粒", "grain", 0.0, 2.0, 0.05)
	_option(grid, "画质", "quality", ["低（无体积雾）", "中", "高"])
	_option(grid, "渲染分辨率", "scale", ["100%", "75%", "50%"])
	_option(grid, "复古像素滤镜", "pixel", ["关", "2×", "3×"])
	_slider(grid, "主音量", "master", 0.0, 1.0, 0.02)
	_slider(grid, "音乐", "music", 0.0, 1.0, 0.02)
	_slider(grid, "音效", "sfx", 0.0, 1.0, 0.02)
	_check(grid, "全屏", "fullscreen")
	_check(grid, "反转 Y 轴", "invert_y")
	var back := VBoxContainer.new()
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.position = Vector2(104, -110)
	set_root.add_child(back)
	_btn(back, "返    回", close_settings)

func _row_label(grid: GridContainer, txt: String) -> void:
	var l := _lbl(grid, txt, 21, Color(0.75, 0.73, 0.69))
	l.custom_minimum_size = Vector2(200, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _slider(grid: GridContainer, txt: String, key: String, mn: float, mx: float, step: float) -> Control:
	_row_label(grid, txt)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(340, 34)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float): Game.set_setting(key, v))
	s.mouse_entered.connect(s.grab_focus)
	grid.add_child(s)
	return s

func _option(grid: GridContainer, txt: String, key: String, opts: Array) -> void:
	_row_label(grid, txt)
	var o := OptionButton.new()
	for i in opts.size():
		o.add_item(opts[i], i)
	o.select(int(Game.settings[key]))
	o.custom_minimum_size = Vector2(340, 34)
	o.item_selected.connect(func(i: int): Game.set_setting(key, i))
	o.mouse_entered.connect(o.grab_focus)
	grid.add_child(o)

func _check(grid: GridContainer, txt: String, key: String) -> void:
	_row_label(grid, txt)
	var c := CheckBox.new()
	c.button_pressed = bool(Game.settings[key])
	c.text = "开启"
	c.toggled.connect(func(v: bool): Game.set_setting(key, v))
	c.mouse_entered.connect(c.grab_focus)
	grid.add_child(c)

func open_settings(from: String) -> void:
	settings_from = from
	mode = "settings"
	set_root.visible = true
	pause_root.visible = false
	title_root.visible = false
	set_first.grab_focus()

func close_settings() -> void:
	set_root.visible = false
	if settings_from == "title":
		mode = "title"
		title_root.visible = true
		(title_box.get_child(0) as Button).grab_focus()
	else:
		open_pause()

# ------------------------------------------------------------------ 死亡
func _build_dead() -> void:
	dead_root = _overlay(0.0)
	var bg: ColorRect = dead_root.get_child(0)
	bg.color = Color(0.12, 0.0, 0.0, 0.0)
	var tl := _lbl(dead_root, "你  死  了", 64, Color(0.75, 0.1, 0.07), _spaced(F_BOLD, 10))
	tl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tl.position = Vector2(-300, -140)
	tl.size = Vector2(600, 90)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _lbl(dead_root, "雾，吞没了一切。", 20, Color(0.6, 0.55, 0.5))
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub.position = Vector2(-300, -40)
	sub.size = Vector2(600, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_box = VBoxContainer.new()
	dead_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dead_box.position = Vector2(-110, 30)
	dead_box.size = Vector2(220, 120)
	dead_root.add_child(dead_box)
	_btn(dead_box, "从检查点继续", func(): Game.main.ui_retry())
	_btn(dead_box, "返回标题", func(): Game.main.ui_to_title())

func show_death() -> void:
	mode = "dead"
	dead_root.visible = true
	dead_root.modulate.a = 0.0
	var bg: ColorRect = dead_root.get_child(0)
	bg.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.85, 2.5)
	tw.parallel().tween_property(dead_root, "modulate:a", 1.0, 2.5)
	tw.tween_callback(func(): (dead_box.get_child(0) as Button).grab_focus())

# ------------------------------------------------------------------ 结局
func _build_end() -> void:
	end_root = Control.new()
	end_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_root.visible = false
	root.add_child(end_root)
	end_bg = ColorRect.new()
	end_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_bg.color = Color(1, 1, 1, 0)
	end_root.add_child(end_bg)
	end_lbl = _lbl(end_root, "", 30, Color(0.1, 0.1, 0.1))
	end_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_credits = _lbl(end_root, "", 20, Color(0.75, 0.73, 0.7))
	end_credits.anchor_left = 0.5
	end_credits.anchor_right = 0.5
	end_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_credits.position = Vector2(-450, 800)
	end_credits.size = Vector2(900, 1600)

const END_LINES := [
	[0.0, ""],
	[3.0, "……爸爸？"],
	[8.0, "她就站在那里。\n可当我伸出手，雾又一次合拢了。"],
	[15.0, "警报声远去。\n学校的大门在我身后缓缓关上。"],
	[22.0, ""],
]
const CREDITS := """寂静岭同人 · 雾中回响
SILENT HILL fan-made demo



—  DEMO 完  —

感谢你的游玩



制作
Notion AI（为 zhou sim 制作）

引擎
Godot Engine 4.3（MIT 许可）

贴图
Poly Haven · ambientCG（CC0）

模型
Kenney（CC0）

音效与音乐
程序合成 · CC0 音效素材

字体
思源宋体 Noto Serif CJK · 霞鹜文楷（SIL OFL）

致敬
《寂静岭》系列 —— KONAMI / Team Silent



本作为非官方同人作品，与 KONAMI 无关。
仅供学习与交流，请勿用于商业用途。




In my restless dreams, I see that town.
"""

func play_ending() -> void:
	mode = "ending"
	hud.visible = false
	end_root.visible = true
	end_bg.color = Color(1, 1, 1, 0)
	end_t = 0.0
	end_lbl.text = ""
	end_credits.text = CREDITS
	end_credits.position.y = 760
	end_credits.modulate.a = 0.0

func _end_process(dt: float) -> void:
	end_t += dt
	if end_t < 3.0:
		end_bg.color = Color(1, 1, 1, clamp(end_t / 3.0, 0.0, 1.0))
	elif end_t < 22.0:
		end_bg.color = Color(1, 1, 1, 1)
	elif end_t < 26.0:
		end_bg.color = Color(1, 1, 1, 1).lerp(Color(0, 0, 0, 1), (end_t - 22.0) / 4.0)
	var line := ""
	var la := 0.0
	for i in END_LINES.size():
		var e: Array = END_LINES[i]
		var nxt: float = END_LINES[i + 1][0] if i + 1 < END_LINES.size() else 999.0
		if end_t >= e[0] and end_t < nxt:
			line = e[1]
			la = clamp(min((end_t - e[0]) / 1.2, (nxt - end_t) / 1.0), 0.0, 1.0)
	end_lbl.text = line
	end_lbl.modulate.a = la
	if end_t > 26.0:
		end_credits.modulate.a = clamp((end_t - 26.0) / 2.0, 0.0, 1.0)
		end_credits.position.y -= dt * 38.0
		if end_credits.position.y < -end_credits.size.y + 200.0 or end_t > 95.0:
			end_t = -1.0
			Game.main.ui_ending_done()

# ------------------------------------------------------------------ 输入
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	match mode:
		"intro":
			if event.is_action("interact") or event.is_action("ui_accept") or event.is_action("pause"):
				intro_skip = true
				get_viewport().set_input_as_handled()
		"inv":
			if event.is_action("inventory") or event.is_action("pause"):
				Game.ui_sfx("ui_back", -6.0)
				Game.main.ui_resume()
			elif event.is_action("move_left") or event.is_action("ui_left"):
				if inv_list.size() > 1:
					inv_sel = (inv_sel - 1 + inv_list.size()) % inv_list.size()
					Game.ui_sfx("ui_move", -8.0)
					_inv_refresh()
			elif event.is_action("move_right") or event.is_action("ui_right"):
				if inv_list.size() > 1:
					inv_sel = (inv_sel + 1) % inv_list.size()
					Game.ui_sfx("ui_move", -8.0)
					_inv_refresh()
			elif event.is_action("interact") or event.is_action("ui_accept"):
				var id := inv_selected()
				if id != "":
					Game.main.use_item(id)
			get_viewport().set_input_as_handled()
		"map":
			if event.is_action("map") or event.is_action("inventory") or event.is_action("pause") or event.is_action("interact"):
				Game.ui_sfx("ui_back", -6.0)
				Game.main.ui_resume()
			get_viewport().set_input_as_handled()
		"read":
			if event.is_action("interact") or event.is_action("ui_accept") or event.is_action("pause") or event.is_action("inventory") or (event is InputEventMouseButton):
				if read_pages.size() > 0 and read_page < read_pages.size() - 1 and not event.is_action("pause"):
					read_page += 1
					Game.ui_sfx("paper", -6.0)
					_read_refresh()
				else:
					Game.ui_sfx("ui_back", -6.0)
					Game.main.ui_resume()
			get_viewport().set_input_as_handled()
		"pause":
			if event.is_action("pause"):
				Game.main.ui_resume()
				get_viewport().set_input_as_handled()
		"settings":
			if event.is_action("pause"):
				close_settings()
				get_viewport().set_input_as_handled()
		"ending":
			if end_t > 30.0 and (event.is_action("pause") or event.is_action("interact")):
				end_t = -1.0
				Game.main.ui_ending_done()
				get_viewport().set_input_as_handled()
