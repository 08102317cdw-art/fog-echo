extends Node
## 主控：场景装配、雾世界/里世界环境、剧情触发、物品、怪物、氛围音频、存档

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const MonsterScript = preload("res://scripts/monster.gd")
const GirlScript = preload("res://scripts/girl.gd")
const UIScript = preload("res://scripts/ui.gd")

const ITEMS := {
	"torch": {"name": "手电筒", "kind": "torch", "desc": "别在胸前口袋上的手电筒。光束能照亮黑暗——但也可能把那些东西引过来。（F 键开 / 关）"},
	"radio": {"name": "便携收音机", "kind": "radio", "desc": "咖啡馆里找到的旧收音机，收不到任何电台。那些东西靠近时，它会发出刺耳的杂音。（R 键开 / 关）"},
	"map": {"name": "小镇地图", "kind": "map", "desc": "寂静岭中心区的街道图。我用红笔在上面做了记号。（M 键查看）"},
	"pipe": {"name": "钢管", "kind": "weapon", "desc": "从厨房水槽下拆下来的锈蚀钢管，沉甸甸的。（鼠标左键挥击；敌人倒地后，靠近再按左键踩踏）"},
	"drink": {"name": "健康饮料", "kind": "use", "desc": "罐装营养饮料。喝下去能稍微恢复体力。"},
	"aid": {"name": "急救包", "kind": "use", "desc": "装着绷带与消毒药水的急救包。能大幅恢复体力。"},
	"key": {"name": "校门钥匙", "kind": "key", "desc": "狗屋里找到的钥匙。纸签上写着：“米德维奇小学 · 正门”。"},
	"note_cafe": {"name": "潦草的便条", "kind": "doc", "desc": "压在咖啡馆桌上的便条，字迹很匆忙。"},
	"drawing": {"name": "小雪的画", "kind": "doc", "desc": "公园长椅上的蜡笔画。画着一所学校，还有爸爸和她——以及旁边一团乱糟糟的黑线。"},
	"note_gate": {"name": "学校的告示", "kind": "doc", "desc": "贴在校门上的告示，已经被雾气浸得发软。"},
}

const NOTE_CAFE := "致任何还能读到这张纸的人：\n\n无线电全断了，镇上的人也不见了。\n\n雾里有东西。它们像人，又不是人——没有手臂，整个身体裹在一层皮里，拖着腿在地上爬。\n\n我的收音机每次在它们靠近时都会发出杂音。听到沙沙声，就别犹豫。\n\n打倒它们之后一定要补上几脚，否则它们还会爬起来。\n\n别相信这片雾。\n\n—— C.（布拉姆斯镇警局）"
const NOTE_GATE := "米德维奇小学 · 停课通知\n\n因持续浓雾，本校即日起停课，复课时间另行通知。\n\n校门已上锁。如有急事需要进入校园，备用钥匙由校工保管，放在 Levin 街后院的狗屋里。\n\n—— 校长室\n\n\n（告示的角落，有一行歪歪扭扭的红色蜡笔字：\n「爸爸，快点来。」）"
const CONTROLS := "操作说明\n\nWASD　移动　　　Shift　奔跑\n鼠标　环顾　　　E　调查 / 拾取\nF　手电筒　　　　鼠标左键　攻击 / 踩踏\nTab　物品栏　　　M　地图\nR　收音机　　　　Esc　暂停\n\n手柄：左摇杆移动，右摇杆视角，A 调查，X 攻击，Y 手电筒，Start 暂停。\n\n小提示：\n收音机的杂音越响，怪物越近。\n奔跑和手电筒都会让你更容易被发现。\n倒地的怪物一定要补上几脚。"

const INTRO := [
	"那天夜里，我们开车前往寂静岭度假。",
	"一个人影突然出现在车灯里——我猛打方向盘。",
	"……",
	"醒来时，天已经亮了。四周全是雾。",
	"副驾驶座上空无一人。",
	"小雪……？",
]

var PICKUPS := {
	"radio": {"item": "radio", "pos": Vector3(35.15, 0.9, 53.45), "prompt": "拾取"},
	"map": {"item": "map", "pos": Vector3(29.4, 0.9, 56.9), "prompt": "拾取"},
	"note_cafe": {"item": "note_cafe", "pos": Vector3(34.85, 0.9, 57.1), "prompt": "阅读"},
	"pipe": {"item": "pipe", "pos": Vector3(31.0, 0.15, 49.4), "prompt": "拾取"},
	"drink_cafe": {"item": "drink", "pos": Vector3(29.0, 1.11, 51.05), "prompt": "拾取"},
	"drink_alley": {"item": "drink", "pos": Vector3(57.7, 0.03, 52.6), "prompt": "拾取"},
	"drink_yard": {"item": "drink", "pos": Vector3(84.4, 0.03, 37.0), "prompt": "拾取"},
	"aid_levin": {"item": "aid", "pos": Vector3(81.6, 0.13, 27.2), "prompt": "拾取"},
	"drawing": {"item": "drawing", "pos": Vector3(56.0, 0.47, 38.75), "prompt": "查看"},
	"note_gate": {"item": "note_gate", "pos": Vector3(44.2, 1.25, 16.12), "prompt": "阅读"},
}

const MONSTERS := {
	"m_cafe": [Vector3(53.0, 0, 64.5), 90.0, false],
	"m_alley": [Vector3(59.6, 0, 49.0), 180.0, true],
	"m_levin": [Vector3(79.0, 0, 47.0), 0.0, false],
	"m_midwich": [Vector3(60.0, 0, 22.0), 90.0, true],
	"m_corpse": [Vector3(68.0, 0, 63.4), 90.0, false, "dormant"],
	"o1": [Vector3(79.0, 0, 54.0), 0.0, false],
	"o2": [Vector3(78.5, 0, 31.0), 180.0, false],
	"o3": [Vector3(68.0, 0, 23.0), 90.0, true],
	"o4": [Vector3(53.0, 0, 21.0), -90.0, false],
	"o5": [Vector3(31.0, 0, 22.5), -90.0, false],
	"o6": [Vector3(47.5, 0, 18.6), 0.0, true],
	"o7": [Vector3(73.5, 0, 24.6), -90.0, false, "dormant"],
}

const FOG_C := Color(0.6, 0.61, 0.62)
const BG_C := Color(0.6, 0.61, 0.62)
const AMB_C := Color(0.44, 0.45, 0.47)
const OW_FOG_C := Color(0.035, 0.012, 0.008)
const OW_BG_C := Color(0.012, 0.005, 0.004)
const OW_AMB_C := Color(0.1, 0.066, 0.056)

var world: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var stage: Node3D
var actors: Node3D
var env: Environment
var sun: DirectionalLight3D
var post_mat: ShaderMaterial
var title_cam: Camera3D
var snow: CPUParticles3D
var wisps: CPUParticles3D
var compat := false

var mode := "boot"
var ow := 0.0
var interior := 0.0
var alley_f := 0.0
var flags := {}
var items: Array = []
var picked: Array = []
var killed: Array = []
var objective := ""
var radio_on := true
var static_level := 0.0
var trans_t := -1.0
var t := 0.0
var title_t := 0.0
var amb_t := 6.0
var pickup_nodes := {}
var monsters := {}
var girl: Node3D
var ribbon: Node3D
var cafe_lights: Array = []
var ow_lights: Array = []
var probes := {}
var cafe_fog: FogVolume
var amb_fog: AudioStreamPlayer
var amb_ow: AudioStreamPlayer
var static_p: AudioStreamPlayer
var heart: AudioStreamPlayer
var music: AudioStreamPlayer
var hurt_prev := 0.0
var ending_t := -1.0
var flutter_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	compat = RenderingServer.get_rendering_device() == null
	stage = Node3D.new()
	stage.name = "Stage"
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)
	world = WorldScript.new()
	world.name = "World"
	stage.add_child(world)
	Game.world = world
	# 怪物寻路：小巷北端铁丝网
	world.astar.set_point_solid(Vector2i(29, 21), true)
	world.astar.set_point_solid(Vector2i(30, 21), true)
	actors = Node3D.new()
	actors.name = "Actors"
	stage.add_child(actors)
	player = PlayerScript.new()
	player.name = "Player"
	stage.add_child(player)
	Game.player = player
	player.position = Vector3(43.0, 0.2, 91.4)
	player.set_yaw_pitch(0.12, -0.05)
	player.died.connect(_on_player_died)
	_make_env()
	_make_post()
	_make_particles()
	_make_lights()
	_make_audio()
	_spawn_pickups()
	world.add_interact("doghouse", Vector3(85.3, 0.5, 41.0), Vector3(1.2, 1.0, 1.4), "调查")
	ui = UIScript.new()
	add_child(ui)
	title_cam = Camera3D.new()
	title_cam.fov = 62
	title_cam.far = 300
	stage.add_child(title_cam)
	Game.settings_changed.connect(_apply_settings)
	_apply_settings()
	if Game.skip_title and Game.load_checkpoint():
		Game.skip_title = false
		_restore(Game.checkpoint)
		_begin_play()
	else:
		Game.skip_title = false
		_show_title()

# ------------------------------------------------------------------ 构建
func _make_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_C
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMB_C
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 兼容渲染器没有体积雾，雾色整体偏白，降低曝光以接近 Forward+ 画面
	env.tonemap_exposure = 0.8 if compat else 1.0
	env.fog_enabled = true
	env.fog_light_color = FOG_C
	env.fog_light_energy = 1.0
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_begin = 0.5
	env.fog_depth_end = 30.0
	env.fog_depth_curve = 0.75
	env.fog_sky_affect = 1.0
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.95, 0.95, 0.96)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 1.45
	env.volumetric_fog_sky_affect = 1.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	# 兼容渲染器的辉光在低 HDR 精度下会把雾天背景整体泛白，故关闭
	env.glow_enabled = not compat
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.9
	we.environment = env
	stage.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 32, 0)
	sun.light_energy = 0.3
	sun.light_color = Color(0.92, 0.94, 1.0)
	sun.light_volumetric_fog_energy = 0.0
	stage.add_child(sun)

func _make_post() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	cr.material = post_mat
	cl.add_child(cr)

func _make_particles() -> void:
	snow = CPUParticles3D.new()
	snow.amount = 1000
	snow.lifetime = 9.0
	snow.preprocess = 9.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(15, 0.5, 15)
	snow.direction = Vector3(0.25, -1, 0.1)
	snow.spread = 30.0
	snow.initial_velocity_min = 0.4
	snow.initial_velocity_max = 0.8
	snow.gravity = Vector3(0.05, -0.15, 0.0)
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = load("res://assets/tex/dot.png")
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	qm.material = sm
	snow.mesh = qm
	snow.color = Color(1, 1, 1, 0.8)
	stage.add_child(snow)
	wisps = CPUParticles3D.new()
	wisps.amount = 34
	wisps.lifetime = 16.0
	wisps.preprocess = 16.0
	wisps.local_coords = false
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.emission_box_extents = Vector3(15, 0.7, 15)
	wisps.direction = Vector3(1, 0, 0.35)
	wisps.spread = 180.0
	wisps.flatness = 1.0
	wisps.initial_velocity_min = 0.15
	wisps.initial_velocity_max = 0.45
	wisps.gravity = Vector3.ZERO
	wisps.scale_amount_min = 0.7
	wisps.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	wisps.color_ramp = ramp
	var wq := QuadMesh.new()
	wq.size = Vector2(6, 3.2)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_texture = load("res://assets/tex/fog_wisp.png")
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wm.vertex_color_use_as_albedo = true
	# Godot 4.3 兼容渲染器中使用深度纹理会导致后处理读屏变黑，故仅在 Forward+ 下开启
	wm.proximity_fade_enabled = not compat
	wm.proximity_fade_distance = 1.5
	wm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	wm.distance_fade_min_distance = 1.0
	wm.distance_fade_max_distance = 5.0
	wm.disable_receive_shadows = true
	wq.material = wm
	wisps.mesh = wq
	wisps.color = Color(0.95, 0.95, 0.96, 0.16)
	stage.add_child(wisps)

func _make_lights() -> void:
	# 咖啡馆暖光（闪烁）
	for p in [Vector3(32.0, 2.72, 55.0), Vector3(29.5, 2.72, 49.0)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.76, 0.5)
		l.light_energy = 1.5
		l.omni_range = 7.5
		l.omni_attenuation = 1.2
		l.shadow_enabled = cafe_lights.is_empty()
		l.light_volumetric_fog_energy = 0.4
		stage.add_child(l)
		cafe_lights.append(l)
	var tvl := OmniLight3D.new()
	tvl.position = Vector3(30.4, 1.4, 51.8)
	tvl.light_color = Color(0.6, 0.7, 1.0)
	tvl.light_energy = 0.35
	tvl.omni_range = 2.5
	stage.add_child(tvl)
	cafe_lights.append(tvl)
	# 反射探针：室内环境光覆盖
	probes["cafe"] = _probe(Vector3(32, 1.6, 53), Vector3(10.6, 3.6, 12.6), Color(0.2, 0.165, 0.13), true)
	probes["alley"] = _probe(Vector3(59, 3.0, 51), Vector3(4.4, 7.0, 16.4), Color(0.4, 0.4, 0.42), false)
	if not compat:
		cafe_fog = FogVolume.new()
		cafe_fog.size = Vector3(10.2, 3.4, 12.2)
		cafe_fog.position = Vector3(32, 1.6, 53)
		var fm := FogMaterial.new()
		fm.density = -0.8
		cafe_fog.material = fm
		stage.add_child(cafe_fog)
	# 里世界红色灯光（在部分路灯处）
	var picks := [Vector3(43, 0, 19.5), Vector3(60, 0, 25.5), Vector3(79.5, 0, 26.0), Vector3(81.5, 0, 44.0), Vector3(79.5, 0, 58.0), Vector3(62.0, 0, 61.0), Vector3(45.5, 0, 61.0), Vector3(36.5, 0, 25.5)]
	for p in picks:
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, 3.2, 0)
		l.light_color = Color(0.95, 0.22, 0.1)
		l.light_energy = 0.0
		l.omni_range = 9.0
		l.omni_attenuation = 1.4
		l.light_volumetric_fog_energy = 1.6
		l.visible = false
		stage.add_child(l)
		ow_lights.append(l)

func _probe(pos: Vector3, size: Vector3, amb: Color, inside: bool) -> ReflectionProbe:
	var rp := ReflectionProbe.new()
	rp.position = pos
	rp.size = size
	rp.interior = inside
	rp.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	rp.ambient_color = amb
	rp.ambient_color_energy = 1.0
	rp.intensity = 0.35
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	stage.add_child(rp)
	return rp

func _loop(name: String, bus: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStream = Game.stream(name)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	p.bus = bus
	p.volume_db = vol
	stage.add_child(p)
	return p

func _make_audio() -> void:
	amb_fog = _loop("amb_fog", "Ambient", -6.0)
	amb_ow = _loop("amb_other", "Ambient", -60.0)
	static_p = _loop("static", "SFX", -60.0)
	heart = _loop("heartbeat", "SFX", -60.0)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)

func _play_music(path: String, vol := 0.0, loop := true) -> void:
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	music.stream = s
	music.volume_db = vol
	music.play()

func _fade_music(dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(music, "volume_db", -60.0, dur)
	tw.tween_callback(music.stop)

# ------------------------------------------------------------------ 物品
func _spawn_pickups() -> void:
	for id in PICKUPS:
		var d: Dictionary = PICKUPS[id]
		var n := Node3D.new()
		n.name = "Pick_" + id
		n.position = d.pos
		stage.add_child(n)
		_pickup_visual(id, d.item, n)
		var area: Area3D = world.add_interact("pick_" + id, d.pos + Vector3(0, 0.12, 0), Vector3(0.7, 0.5, 0.7), d.prompt)
		var glint := Sprite3D.new()
		glint.texture = load("res://assets/tex/dot.png")
		glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glint.pixel_size = 0.004
		glint.modulate = Color(1.0, 0.95, 0.85, 0.0)
		glint.shaded = false
		glint.transparent = true
		glint.position = Vector3(0, 0.12, 0)
		glint.name = "Glint"
		n.add_child(glint)
		pickup_nodes[id] = [n, area]

func _sm(c: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m

func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _paper(parent: Node3D, tex: Texture2D, size: Vector2, flat := true, yaw := 0.0) -> void:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi(parent, q, m, Vector3(0, 0.004, 0), Vector3(-PI / 2 if flat else 0.0, yaw, 0))

func _pickup_visual(id: String, item: String, n: Node3D) -> void:
	match item:
		"radio":
			world.model("radio", n.position, 200, 0.2, "h", false, n)
			var r: Node3D = n.get_child(n.get_child_count() - 1)
			r.global_transform = r.transform
			n.remove_child(r)
			n.add_child(r)
			r.position -= n.position
		"map":
			_paper(n, load("res://assets/ui/map.png"), Vector2(0.38, 0.42), true, 0.3)
		"note_cafe":
			_paper(n, load("res://assets/tex/paper.png"), Vector2(0.21, 0.28), true, -0.4)
		"drawing":
			_paper(n, load("res://assets/tex/drawing.png"), Vector2(0.42, 0.3), true, 0.15)
		"note_gate":
			_paper(n, load("res://assets/tex/paper.png"), Vector2(0.3, 0.4), false, 0.0)
		"pipe":
			var c := CylinderMesh.new()
			c.top_radius = 0.024
			c.bottom_radius = 0.024
			c.height = 0.8
			c.radial_segments = 10
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/tex/rust1_a.png")
			m.uv1_scale = Vector3(1, 3, 1)
			m.metallic = 0.5
			m.roughness = 0.8
			_mi(n, c, m, Vector3(0, 0.024, 0), Vector3(0, 0.6, PI / 2))
		"drink":
			var c := CylinderMesh.new()
			c.top_radius = 0.033
			c.bottom_radius = 0.033
			c.height = 0.12
			_mi(n, c, _sm(Color(0.72, 0.74, 0.76), 0.8, 0.35), Vector3(0, 0.06, 0))
			var b := CylinderMesh.new()
			b.top_radius = 0.0335
			b.bottom_radius = 0.0335
			b.height = 0.06
			_mi(n, b, _sm(Color(0.12, 0.45, 0.32), 0.2, 0.5), Vector3(0, 0.06, 0))
		"aid":
			var b := BoxMesh.new()
			b.size = Vector3(0.3, 0.09, 0.2)
			_mi(n, b, _sm(Color(0.85, 0.84, 0.8)), Vector3(0, 0.045, 0))
			var c1 := BoxMesh.new()
			c1.size = Vector3(0.11, 0.01, 0.035)
			var red := _sm(Color(0.75, 0.08, 0.06))
			_mi(n, c1, red, Vector3(0, 0.091, 0))
			var c2 := BoxMesh.new()
			c2.size = Vector3(0.035, 0.01, 0.11)
			_mi(n, c2, red, Vector3(0, 0.091, 0))

func _remove_pickup(id: String) -> void:
	if pickup_nodes.has(id):
		var arr: Array = pickup_nodes[id]
		if is_instance_valid(arr[0]):
			arr[0].queue_free()
		if is_instance_valid(arr[1]):
			arr[1].queue_free()
		pickup_nodes.erase(id)
	if not picked.has(id):
		picked.append(id)

func _pickup(id: String) -> void:
	var d: Dictionary = PICKUPS[id]
	var item: String = d.item
	_remove_pickup(id)
	items.append(item)
	var it: Dictionary = ITEMS[item]
	Game.sfx("pickup", -4.0)
	match item:
		"radio":
			flags.radio = true
			ui.show_pickup(it.name)
			ui.message("收音机突然发出刺耳的杂音……")
			ui.message("外面有什么东西正在靠近！")
			_set_objective("有东西过来了……找件能防身的东西")
			_spawn_monster("m_cafe", true)
			Game.sfx("radio_on", -2.0)
		"pipe":
			player.give_pipe()
			ui.show_pickup(it.name)
			ui.message("一截生锈的钢管。总比赤手空拳强。")
			ui.show_hint("鼠标左键　挥击\n敌人倒地后靠近，再按左键　踩踏", 10.0)
		"map":
			flags.map = true
			ui.show_pickup(it.name)
			ui.message("寂静岭的街道图。按 M 查看。")
		"drink", "aid":
			ui.show_pickup(it.name)
		"note_cafe", "note_gate":
			if item == "note_gate":
				flags.note_gate = true
				if not items.has("key"):
					_set_objective("去 Levin 街的后院，在狗屋里找钥匙")
			_read(item)
		"drawing":
			flags.drawing = true
			_read(item)
			if not flags.get("ow", false):
				_set_objective("去米德维奇小学（地图北侧，Midwich 街对面）")
				_checkpoint("park")

func _read(item: String) -> void:
	_open_overlay()
	match item:
		"note_cafe":
			ui.read_doc(ITEMS[item].name, [NOTE_CAFE])
		"note_gate":
			ui.read_doc(ITEMS[item].name, [NOTE_GATE])
		"drawing":
			ui.show_image(load("res://assets/tex/drawing.png"), "蜡笔画。背面用铅笔写着：放学以后，在学校等爸爸。")

func use_item(id: String) -> void:
	var it: Dictionary = ITEMS[id]
	match it.kind:
		"use":
			if player.hp >= 99.0:
				ui.message("现在还用不着。")
				return
			player.heal(35.0 if id == "drink" else 80.0)
			items.erase(id)
			Game.sfx("pickup", -8.0, 0.8)
			ui.message("体力恢复了一些。" if id == "drink" else "包扎好了伤口。")
			ui.open_inventory(_inv_list(), ui.inv_sel)
		"doc":
			ui.close_overlay()
			_read(id)
		"map":
			ui.close_overlay()
			ui.open_map()
		"radio":
			radio_on = not radio_on
			Game.sfx("click", -4.0)
			ui.message("打开了收音机。" if radio_on else "关掉了收音机。")
		"torch":
			player.torch_on = not player.torch_on
			Game.sfx("click", -4.0)
		"weapon":
			ui.message("已经握在手里了。")
		"key":
			ui.message("应该在校门那里用得上。")

func _inv_list() -> Array:
	var out: Array = [{"id": "torch", "n": 1}]
	var seen := {}
	for i in items:
		if seen.has(i):
			(out[seen[i]] as Dictionary).n += 1
		else:
			seen[i] = out.size()
			out.append({"id": i, "n": 1})
	return out

# ------------------------------------------------------------------ 怪物
func _spawn_monster(id: String, hunt := false) -> void:
	if killed.has(id) or monsters.has(id):
		return
	var d: Array = MONSTERS[id]
	var m: CharacterBody3D = MonsterScript.new()
	m.setup(id, d[0], d[1], d[2])
	m.hunt = hunt
	if d.size() > 3 and d[3] == "dormant":
		m.dormant = true
	actors.add_child(m)
	m.killed.connect(_on_monster_killed)
	monsters[id] = m

func _on_monster_killed(id: String) -> void:
	if not killed.has(id):
		killed.append(id)
	monsters.erase(id)
	if id == "m_cafe" and not flags.get("first_kill", false):
		flags.first_kill = true
		ui.message("……这到底是什么东西？")

func on_monster_wake(_id: String) -> void:
	Game.sfx("sting", -7.0, 0.62)
	if player:
		player.shake = max(player.shake, 0.25)

func on_phantom_leave() -> void:
	ui.message("……那是什么？刚才那个……是人吗？")

func _spawn_phantom(pos: Vector3, yaw_deg: float) -> void:
	var m: CharacterBody3D = MonsterScript.new()
	m.setup("phantom", pos, yaw_deg, false)
	m.phantom = true
	actors.add_child(m)

func _despawn_fog_monsters() -> void:
	for id in monsters.keys():
		if (id as String).begins_with("m_"):
			var m = monsters[id]
			if is_instance_valid(m):
				(m as Node).queue_free()
			monsters.erase(id)

func _spawn_for_flags() -> void:
	if flags.get("ow", false):
		for id in ["o1", "o2", "o3", "o4", "o5", "o6", "o7"]:
			_spawn_monster(id)
		return
	if flags.get("radio", false):
		_spawn_monster("m_cafe", true)
	if flags.get("spawn2", false):
		for id in ["m_alley", "m_levin", "m_midwich", "m_corpse"]:
			_spawn_monster(id)

# ------------------------------------------------------------------ 交互
const LOCKED := ["门锁着。", "门把手纹丝不动。", "锁坏了，打不开。", "门好像被什么东西从里面堵住了。", "门锁着。里面一点声音都没有。"]
const LOCKED_OW := ["门锈死了。", "门的另一边传来指甲刮擦的声音……", "打不开。门上全是暗红色的锈。", "门锁着。"]

func interact(a: Area3D) -> void:
	if mode != "game":
		return
	var id: String = a.get_meta("iid")
	if id.begins_with("pick_"):
		_pickup(id.substr(5))
		return
	match id:
		"locked_door":
			Game.sfx3d("door_locked", a.global_position, -2.0, randf_range(0.9, 1.05))
			ui.message((LOCKED_OW if ow > 0.5 else LOCKED).pick_random())
		"school_door":
			Game.sfx3d("door_locked", a.global_position, -2.0)
			ui.message("校舍的大门锁着。")
		"alley_fence":
			if flags.get("alley_end", false):
				ui.message("铁丝网对面就是公园。网眼很密，也爬不过去。网上挂着一根红色的发带。")
			else:
				ui.message("高高的铁丝网，过不去。")
		"tv":
			Game.sfx3d("static", a.global_position, -8.0, 1.0, 2.0, 12.0)
			ui.message("电视里只有雪花。……隐约能听到有人在说话，却听不清在说什么。")
		"school_gate":
			_gate()
		"doghouse":
			_doghouse()

func _gate() -> void:
	if flags.get("gate_open", false):
		return
	if items.has("key"):
		flags.gate_open = true
		items.erase("key")
		Game.sfx3d("gate_open", Vector3(43, 1.2, 16), 2.0)
		ui.message("用钥匙打开了挂锁。铁链哗啦一声掉在地上。")
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_method(world.open_gate, 0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE)
		_set_objective("进入学校")
	else:
		Game.sfx3d("door_locked", Vector3(43, 1.2, 16), 0.0, 0.8)
		ui.message("校门被粗铁链和挂锁锁住了。")
		if not picked.has("note_gate"):
			ui.message("门上贴着一张告示。")

func _doghouse() -> void:
	if items.has("key") or flags.get("ow", false):
		ui.message("狗屋里什么都没有了。")
		return
	ui.message("狗屋里一片漆黑……手伸进去，摸到了一把冰冷的钥匙。")
	items.append("key")
	ui.show_pickup(ITEMS.key.name)
	Game.sfx("pickup", -4.0)
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_callback(_start_transition)

# ------------------------------------------------------------------ 剧情
func _set_objective(txt: String) -> void:
	objective = txt
	ui.set_objective(txt, true)

func _story(dt: float) -> void:
	var p := player.global_position
	if not flags.get("girl_seen", false) and p.z < 86.0:
		flags.girl_seen = true
		girl = GirlScript.new()
		actors.add_child(girl)
		girl.start([Vector3(42.8, 0, 73.0), Vector3(42.4, 0, 64.6), Vector3(50.0, 0, 64.2), Vector3(58.8, 0, 63.4),
			Vector3(59.2, 0, 57.0), Vector3(59.0, 0, 50.0), Vector3(59.4, 0, 45.4), Vector3(59.6, 0, 43.7), Vector3(59.8, 0, 41.2)])
		girl.vanished.connect(func(): flags.girl_gone = true)
		Game.sfx("sting", -12.0, 0.9)
		ui.message("……小雪？！")
		_set_objective("追上雾中那个小小的身影")
	if flags.get("girl_seen", false) and not flags.get("alley_end", false):
		if Vector2(p.x - 59.0, p.z - 45.5).length() < 3.6 and (flags.get("girl_gone", false) or not is_instance_valid(girl)):
			flags.alley_end = true
			Game.sfx("sting", -8.0, 0.7)
			ui.message("她不见了。")
			ui.message("铁丝网对面是公园……她是从这里钻过去的吗？")
			_set_objective("雾越来越浓了。去街口那家亮着灯的咖啡馆（CAFÉ 5TO2）看看")
			_add_ribbon()
	var in_cafe := p.x > 27.0 and p.x < 37.0 and p.z > 47.0 and p.z < 59.0
	# 雾中人影：去咖啡馆的路上，远处站着一个抽搐的人形，靠近时转身走进雾里
	if flags.get("alley_end", false) and not flags.get("cafe_in", false) and not flags.get("phantom", false) and p.z > 59.0 and p.z < 69.0 and p.x > 46.0 and p.x < 61.0:
		flags.phantom = true
		_spawn_phantom(Vector3(max(p.x - 21.0, 35.0), 0, 64.8), -90.0)
	if in_cafe and not flags.get("cafe_in", false):
		flags.cafe_in = true
		ui.message("咖啡馆里亮着灯，却一个人也没有。桌上的咖啡还是温的。")
		_checkpoint("cafe")
	if flags.get("radio", false) and not flags.get("spawn2", false) and not in_cafe and p.z > 59.5:
		flags.spawn2 = true
		_spawn_for_flags()
		if not flags.get("drawing", false):
			_set_objective("去公园寻找小雪——公园在小巷北面，入口在 Midwich 街")
	if flags.get("gate_open", false) and not flags.get("ending", false) and p.z < 14.6 and p.x > 36.0 and p.x < 50.0:
		_start_ending()

func _add_ribbon() -> void:
	if ribbon:
		return
	ribbon = Node3D.new()
	stage.add_child(ribbon)
	ribbon.position = Vector3(59.5, 1.05, 43.06)
	var m := _sm(Color(0.55, 0.03, 0.03), 0.0, 0.7)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.3)
	_mi(ribbon, q, m, Vector3(0, -0.13, 0), Vector3(0, 0, 0.15))
	_mi(ribbon, q, m, Vector3(0.04, -0.12, 0.005), Vector3(0, 0, -0.25))

func map_marks() -> Array:
	var out: Array = []
	if flags.get("alley_end", false):
		out.append(["circle", 59.0, 45.0, 2.4])
		out.append(["text", 62.0, 46.0, "她不见了"])
	if flags.get("cafe_in", false):
		out.append(["circle", 32.0, 55.0, 3.2])
	if flags.get("spawn2", false) and not flags.get("drawing", false):
		out.append(["circle", 60.0, 35.0, 6.5])
		out.append(["text", 66.0, 30.0, "小雪？"])
	if flags.get("drawing", false):
		out.append(["circle", 43.0, 13.0, 4.0])
		out.append(["text", 48.0, 13.0, "学校！"])
	if flags.get("note_gate", false) and not items.has("key") and not flags.get("ow", false):
		out.append(["circle", 85.0, 40.0, 3.2])
		out.append(["text", 84.0, 35.0, "钥匙"])
	if flags.get("ow", false):
		out.append(["x", 60.0, 28.0, 1.6])
		out.append(["x", 59.0, 59.5, 1.4])
	return out

# ------------------------------------------------------------------ 里世界过渡
func _start_transition() -> void:
	if flags.get("ow", false):
		return
	flags.ow = true
	trans_t = 0.0
	player.cutscene = true
	Game.sfx("siren", 0.0, 1.0, "Ambient")
	ui.message("……警报声？")

func _transition(dt: float) -> void:
	trans_t += dt
	var tt := trans_t
	if tt > 2.6 and player.cutscene and ending_t < 0.0:
		player.cutscene = false
	var v: float = smoothstep(3.0, 10.0, tt)
	var disp := v
	if tt > 3.0 and tt < 10.5 and randf() < 0.12:
		disp = clamp(v + randf_range(-0.35, 0.25), 0.0, 1.0)
	ow = disp
	world.set_ow(disp)
	post_mat.set_shader_parameter("warp", sin(clamp(tt / 11.0, 0.0, 1.0) * PI) * 1.2)
	player.shake = max(player.shake, 0.08 * sin(clamp(tt / 11.0, 0.0, 1.0) * PI))
	if tt > 5.0 and not flags.get("trans_snd", false):
		flags.trans_snd = true
		Game.sfx("transition", 0.0)
		_despawn_fog_monsters()
	if tt >= 11.0:
		trans_t = -1.0
		flags.erase("trans_snd")
		ow = 1.0
		world.set_ow(1.0)
		world.set_ow_fences(true)
		post_mat.set_shader_parameter("warp", 0.0)
		player.torch_on = true
		Game.sfx("sting", -4.0, 0.8)
		_spawn_for_flags()
		ui.message("……这里是哪里？")
		ui.message("手电筒的光圈外面，什么都看不见。")
		_set_objective("回到学校，用钥匙打开校门")
		_checkpoint("otherworld")

# ------------------------------------------------------------------ 结局
func _start_ending() -> void:
	flags.ending = true
	ending_t = 0.0
	player.cutscene = true
	ui.clear_messages()
	Game.sfx("sting", -6.0, 0.6)
	var g: Node3D = GirlScript.new()
	actors.add_child(g)
	g.start([Vector3(43.0, 0, 9.8)])
	g.hold = true
	girl = g
	_play_music("res://assets/music/music_box.ogg", -4.0, false)
	var tw := create_tween()
	tw.tween_property(amb_ow, "volume_db", -40.0, 6.0)
	tw.parallel().tween_property(static_p, "volume_db", -60.0, 2.0)

func _ending_process(dt: float) -> void:
	ending_t += dt
	var to: Vector3 = Vector3(43.0, 1.0, 9.8) - player.cam.global_position
	var ty := atan2(-to.x, -to.z)
	var tp := atan2(to.y, Vector2(to.x, to.z).length())
	player.yaw = lerp_angle(player.yaw, ty, clamp(dt * 1.5, 0.0, 1.0))
	player.pitch = lerp(player.pitch, tp, clamp(dt * 1.5, 0.0, 1.0))
	if ending_t > 5.0 and mode == "game":
		mode = "ending"
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.play_ending()
		_play_music("res://assets/music/ending.ogg", -6.0, false)
	if ending_t > 7.0 and is_instance_valid(girl):
		girl.queue_free()

func ui_ending_done() -> void:
	Game.clear_save()
	get_tree().paused = false
	get_tree().reload_current_scene()

# ------------------------------------------------------------------ 存档
func _checkpoint(tag: String) -> void:
	var p := player.global_position
	var cp := {
		"flags": flags.duplicate(), "items": items.duplicate(), "picked": picked.duplicate(), "killed": killed.duplicate(),
		"pos": [p.x, p.y + 0.05, p.z], "yaw": player.yaw, "hp": max(player.hp, 60.0), "objective": objective, "tag": tag,
		"radio_on": radio_on,
	}
	Game.save_checkpoint(cp)
	ui.show_saved()

func _restore(cp: Dictionary) -> void:
	flags = (cp.get("flags", {}) as Dictionary).duplicate()
	items = (cp.get("items", []) as Array).duplicate()
	killed = (cp.get("killed", []) as Array).duplicate()
	radio_on = cp.get("radio_on", true)
	for id in (cp.get("picked", []) as Array):
		_remove_pickup(id)
	if items.has("pipe"):
		player.give_pipe()
	if flags.get("ow", false):
		ow = 1.0
		world.set_ow(1.0)
		world.set_ow_fences(true)
		player.torch_on = true
	if flags.get("alley_end", false):
		_add_ribbon()
	if flags.get("gate_open", false):
		world.open_gate(1.0)
	var pa: Array = cp.get("pos", [43.0, 0.2, 91.4])
	player.global_position = Vector3(pa[0], pa[1], pa[2])
	player.set_yaw_pitch(cp.get("yaw", 0.0), 0.0)
	player.hp = cp.get("hp", 100.0)
	objective = cp.get("objective", "")
	ui.set_objective(objective, false)
	_spawn_for_flags()

# ------------------------------------------------------------------ 流程
func _show_title() -> void:
	mode = "title"
	title_cam.current = true
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_title(Game.has_save())
	ui.fade(0.0, 3.0)
	_play_music("res://assets/music/title.ogg", -3.0, true)

func ui_new_game() -> void:
	if mode != "title":
		return
	mode = "intro"
	Game.clear_save()
	_fade_music(2.5)
	var tw: Tween = ui.fade(1.0, 1.5)
	await tw.finished
	ui.hide_title()
	amb_fog.volume_db = -60.0
	await ui.play_intro(INTRO)
	Game.sfx("breath", -8.0)
	_begin_play()
	ui.message("车撞在了路边的树上。小雪不在车里。")
	_set_objective("寻找小雪")
	ui.show_hint("WASD 移动　Shift 奔跑　鼠标 环顾\nE 调查 / 拾取　F 手电筒　左键 攻击\nTab 物品栏　M 地图　R 收音机　Esc 暂停", 18.0)
	_checkpoint("start")

func ui_continue() -> void:
	if mode != "title":
		return
	if not Game.load_checkpoint():
		return
	mode = "intro"
	_fade_music(1.5)
	var tw: Tween = ui.fade(1.0, 1.2)
	await tw.finished
	ui.hide_title()
	_restore(Game.checkpoint)
	_begin_play()

func _begin_play() -> void:
	mode = "game"
	ui.hide_title()
	ui.hud.visible = true
	player.cam.current = true
	player.enabled = true
	player.cutscene = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.fader.color.a = 1.0
	ui.fade(0.0, 2.5)
	var tw := create_tween()
	tw.tween_property(amb_fog, "volume_db", -6.0, 3.0)

func _open_overlay() -> void:
	if mode == "game":
		mode = "overlay"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.set_prompt("")

func ui_resume() -> void:
	ui.close_overlay()
	ui.close_pause()
	ui.set_root.visible = false
	get_tree().paused = false
	if mode == "overlay" or mode == "pause":
		mode = "game"
	if mode == "game":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func ui_to_title() -> void:
	get_tree().paused = false
	Game.skip_title = false
	get_tree().reload_current_scene()

func ui_retry() -> void:
	get_tree().paused = false
	Game.skip_title = true
	get_tree().reload_current_scene()

func ui_show_controls() -> void:
	ui.close_pause()
	mode = "overlay"
	ui.read_doc("操作说明", [CONTROLS])

func _on_player_died() -> void:
	mode = "dead"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.clear_messages()
	ui.hud.visible = false
	ui.show_death()

func _unhandled_input(event: InputEvent) -> void:
	if mode != "game":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not event.is_pressed() or event.is_echo() or player.dead:
		return
	if event.is_action("pause"):
		mode = "pause"
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.open_pause()
	elif event.is_action("inventory") and not player.cutscene:
		_open_overlay()
		ui.open_inventory(_inv_list())
	elif event.is_action("map") and not player.cutscene:
		if flags.get("map", false):
			_open_overlay()
			ui.open_map()
		else:
			ui.message("我没有地图。")
	elif event.is_action("radio"):
		if flags.get("radio", false):
			radio_on = not radio_on
			Game.sfx("click", -4.0)
			ui.message("打开了收音机。" if radio_on else "关掉了收音机。")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "game" and not get_tree().paused:
		mode = "pause"
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.open_pause()

# ------------------------------------------------------------------ 设置
func _apply_settings() -> void:
	var S: Dictionary = Game.settings
	var q: int = int(S.quality)
	env.volumetric_fog_enabled = q >= 1 and not compat
	env.ssao_enabled = q >= 1 and not compat
	env.ssil_enabled = q >= 2 and not compat
	if not compat:
		RenderingServer.environment_set_volumetric_fog_volume_size(128 if q >= 2 else 64, 96 if q >= 2 else 64)
	env.adjustment_brightness = float(S.brightness)
	var vp := get_viewport()
	var sc: float = [1.0, 0.75, 0.5][clamp(int(S.scale), 0, 2)]
	vp.scaling_3d_scale = sc
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (sc < 0.99 and not compat) else Viewport.SCALING_3D_MODE_BILINEAR
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	post_mat.set_shader_parameter("pixel", float([1, 2, 3][clamp(int(S.pixel), 0, 2)]))
	post_mat.set_shader_parameter("grain", 0.085 * float(S.grain))
	if player and player.torch:
		player.torch.shadow_enabled = q >= 1 or compat

# ------------------------------------------------------------------ 每帧
func _cam_pos() -> Vector3:
	if mode == "title" or mode == "intro" and not player.enabled:
		return title_cam.global_position
	return player.global_position

func _process(dt: float) -> void:
	t += dt
	post_mat.set_shader_parameter("time_s", t)
	if get_tree().paused:
		return
	if mode == "title" or (mode == "intro" and not player.enabled):
		_title_cam(dt)
	if mode == "game":
		_story(dt)
		_update_prompt()
	if trans_t >= 0.0:
		_transition(dt)
	if ending_t >= 0.0:
		_ending_process(dt)
	_update_env(dt)
	_update_audio(dt)
	_update_fx(dt)

func _title_cam(dt: float) -> void:
	title_t += dt
	var k := fmod(title_t / 80.0, 1.0)
	var a := Vector3(70.0, 1.75, 65.3)
	var b := Vector3(24.0, 1.75, 64.4)
	var p := a.lerp(b, k)
	p.y += sin(title_t * 0.5) * 0.04
	title_cam.position = p
	var look := p + Vector3(-6.0, -0.15 + sin(title_t * 0.21) * 0.1, sin(title_t * 0.13) * 1.6 - 0.6)
	title_cam.look_at(look)

func _update_prompt() -> void:
	var a: Area3D = player.cur_interact
	if a and is_instance_valid(a) and not player.cutscene:
		ui.set_prompt(a.get_meta("prompt", "调查"))
	else:
		ui.set_prompt("")

func _update_env(dt: float) -> void:
	var p := _cam_pos()
	var c: Vector2i = world.cell_of(p)
	var ft: String = world.ch(c.x, c.y)
	var want_in := 1.0 if (ft == "w" or ft == "k") else 0.0
	interior = move_toward(interior, want_in, dt * 0.8)
	var want_alley := 1.0 if ft == "_" else 0.0
	alley_f = move_toward(alley_f, want_alley, dt * 0.6)
	var o := ow
	var fogc := FOG_C.lerp(OW_FOG_C, o)
	env.background_color = BG_C.lerp(OW_BG_C, o)
	env.fog_light_color = fogc
	var fend: float = lerp(30.0, 22.0, o)
	if compat or not env.volumetric_fog_enabled:
		fend *= 0.88
	fend *= lerp(1.0, 1.7, interior)
	fend *= lerp(1.0, 0.85, alley_f)
	env.fog_depth_end = fend
	env.ambient_light_color = AMB_C.lerp(OW_AMB_C, o)
	env.volumetric_fog_density = lerp(0.018, 0.04, o)
	env.volumetric_fog_albedo = Color(0.95, 0.95, 0.96).lerp(Color(0.62, 0.5, 0.46), o)
	env.volumetric_fog_ambient_inject = lerp(1.45, 0.0, o)
	env.glow_intensity = lerp(0.4, 0.8, o)
	sun.light_energy = lerp(0.3, 0.0, o)
	sun.visible = o < 0.98
	(probes["cafe"] as ReflectionProbe).ambient_color = Color(0.2, 0.165, 0.13).lerp(Color(0.04, 0.02, 0.015), o)
	(probes["alley"] as ReflectionProbe).ambient_color = Color(0.4, 0.4, 0.42).lerp(Color(0.03, 0.02, 0.018), o)
	# 灯光
	for i in cafe_lights.size():
		var l: OmniLight3D = cafe_lights[i]
		var base := 1.5 if i < 2 else 0.35
		var fl := 1.0
		if randf() < (0.02 if o < 0.5 else 0.1):
			fl = randf_range(0.1, 0.6)
		l.light_energy = lerp(l.light_energy, base * fl * (1.0 - o * 0.85), clamp(dt * 25.0, 0.0, 1.0))
		if i < 2:
			l.light_color = Color(1.0, 0.76, 0.5).lerp(Color(0.9, 0.25, 0.12), o)
	for l in ow_lights:
		var ol: OmniLight3D = l
		ol.visible = o > 0.3
		if ol.visible:
			var fl2 := 1.0 if randf() > 0.04 else randf_range(0.0, 0.4)
			ol.light_energy = lerp(ol.light_energy, 1.3 * fl2 * o, clamp(dt * 20.0, 0.0, 1.0))
	# 后处理色调
	post_mat.set_shader_parameter("saturation", lerp(0.7, 0.92, o))
	post_mat.set_shader_parameter("tint", Vector3(1.0, 0.985, 0.95).lerp(Vector3(1.08, 0.86, 0.8), o))
	post_mat.set_shader_parameter("vignette", lerp(0.5, 0.72, o))
	post_mat.set_shader_parameter("contrast", lerp(1.05, 1.12, o))

func _update_audio(dt: float) -> void:
	var o := ow
	var alive := mode == "game" or mode == "title" or mode == "intro"
	if not amb_fog.playing:
		amb_fog.play()
	if amb_fog.volume_db > -59.0 or o < 0.9:
		pass
	if mode == "game" or mode == "overlay":
		amb_fog.volume_db = lerp(amb_fog.volume_db, linear_to_db(max(1.0 - o, 0.001)) - 6.0, clamp(dt * 2.0, 0.0, 1.0))
	if o > 0.02:
		if not amb_ow.playing:
			amb_ow.play()
		if ending_t < 0.0:
			amb_ow.volume_db = linear_to_db(max(o, 0.001)) - 3.0
	elif amb_ow.playing:
		amb_ow.stop()
	# 收音机杂音
	var nearest := 999.0
	if player and not player.dead:
		for m in get_tree().get_nodes_in_group("monster"):
			var md: float = (m as Node3D).global_position.distance_to(player.global_position)
			if m.get("state") == 9:
				md = md * 1.6 + 5.0
			nearest = min(nearest, md)
	var target := 0.0
	if flags.get("radio", false) and radio_on and mode == "game" and ending_t < 0.0:
		target = clamp(1.0 - (nearest - 4.0) / 19.0, 0.0, 1.0)
	static_level = lerp(static_level, target, clamp(dt * 2.5, 0.0, 1.0))
	flutter_t -= dt
	if static_level > 0.01:
		if not static_p.playing:
			static_p.play(randf() * 2.0)
		if flutter_t <= 0.0:
			flutter_t = randf_range(0.05, 0.18)
			static_p.volume_db = linear_to_db(static_level * 0.95) + randf_range(-4.0, 0.0)
			static_p.pitch_scale = randf_range(0.94, 1.06)
		ui.set_radio_state("◉  收音机 · 杂音" if static_level > 0.15 else "")
	else:
		if static_p.playing:
			static_p.stop()
		ui.set_radio_state("")
	# 心跳
	var hv := 0.0
	if player and not player.dead and mode == "game":
		hv = clamp((40.0 - player.hp) / 40.0, 0.0, 1.0)
	if hv > 0.01:
		if not heart.playing:
			heart.play()
		heart.volume_db = linear_to_db(hv) - 2.0
		heart.pitch_scale = 1.0 + hv * 0.25
	elif heart.playing:
		heart.stop()
	# 远处的环境声
	if mode == "game" and trans_t < 0.0 and ending_t < 0.0:
		amb_t -= dt
		if amb_t <= 0.0:
			amb_t = randf_range(9.0, 20.0) if o < 0.5 else randf_range(6.0, 13.0)
			var a := randf() * TAU
			var pos := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(16.0, 32.0) + Vector3(0, 2, 0)
			var opts := ["swing_creak", "hit_metal", "door_locked", "mon_step"] if o < 0.5 else ["hit_metal", "swing_creak", "mon_screech", "stomp", "hit_metal", "door_locked"]
			Game.sfx3d(opts.pick_random(), pos, -8.0 if o < 0.5 else -4.0, randf_range(0.5, 0.8), 6.0, 70.0)

func _update_fx(dt: float) -> void:
	var cp := _cam_pos()
	snow.global_position = cp + Vector3(2.0, 6.5, 0.0)
	wisps.global_position = cp + Vector3(0, 1.1, 0)
	var o := ow
	snow.color = Color(1, 1, 1, 0.8).lerp(Color(0.2, 0.17, 0.15, 0.9), o)
	snow.gravity = Vector3(0.05, -0.15, 0.0).lerp(Vector3(0.02, -0.05, 0.0), o)
	wisps.color = Color(0.95, 0.95, 0.96, 0.16 * (1.0 - interior * 0.85)).lerp(Color(0.08, 0.03, 0.025, 0.25), o)
	snow.emitting = interior < 0.5
	# 拾取物闪光
	for id in pickup_nodes:
		var arr: Array = pickup_nodes[id]
		var n: Node3D = arr[0]
		if not is_instance_valid(n):
			continue
		var g: Sprite3D = n.get_node_or_null("Glint")
		if g:
			var d := n.global_position.distance_to(cp)
			var pulse := 0.5 + 0.5 * sin(t * 2.5 + float(hash(id) % 100))
			g.modulate.a = clamp((7.0 - d) / 4.0, 0.0, 1.0) * (0.25 + 0.55 * pulse)
	# 受伤、低血量
	if player:
		var dmg: float = player.hurt_flash
		post_mat.set_shader_parameter("damage", dmg)
		post_mat.set_shader_parameter("lowhp", clamp((35.0 - player.hp) / 35.0, 0.0, 1.0) if not player.dead else 0.0)
	var nz := static_level * static_level * 0.35
	if trans_t >= 0.0:
		nz += sin(clamp(trans_t / 11.0, 0.0, 1.0) * PI) * 0.6
	post_mat.set_shader_parameter("noise_amt", nz)
	if ending_t >= 0.0:
		post_mat.set_shader_parameter("white_flash", clamp((ending_t - 2.0) / 3.0, 0.0, 1.0) * 0.6)
