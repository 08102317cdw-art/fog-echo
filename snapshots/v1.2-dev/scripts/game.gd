extends Node
## 全局状态：设置、输入映射、音频总线、检查点

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
var settings := {
	"mouse_sens": 0.16, "brightness": 1.0, "pixel": 0, "grain": 1.0,
	"master": 0.9, "music": 0.8, "sfx": 0.9, "fullscreen": true, "invert_y": false,
	"quality": 1, "scale": 0,
}
var checkpoint: Dictionary = {}
var skip_title := false
var show_controls_hint := true
var main: Node = null
var world: Node3D = null
var player: Node3D = null
var _streams := {}
const SAVE_PATH := "user://save.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_settings()
	apply_settings()

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e in events:
		InputMap.action_add_event(action, e)

func _setup_input() -> void:
	_add("move_forward", [_key(KEY_W), _key(KEY_UP)])
	_add("move_back", [_key(KEY_S), _key(KEY_DOWN)])
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_add("run", [_key(KEY_SHIFT)])
	_add("interact", [_key(KEY_E)])
	_add("flashlight", [_key(KEY_F)])
	_add("inventory", [_key(KEY_TAB), _key(KEY_I)])
	_add("map", [_key(KEY_M)])
	_add("radio", [_key(KEY_T)])
	_add("reload", [_key(KEY_R)])
	_add("dodge", [_key(KEY_SPACE)])
	_add("push", [_key(KEY_Q)])
	_add("weapon_1", [_key(KEY_1)])
	_add("weapon_2", [_key(KEY_2)])
	_add("weapon_3", [_key(KEY_3)])
	_add("quick_heal", [_key(KEY_H)])
	_add("pause", [_key(KEY_ESCAPE), _key(KEY_P)])
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	_add("attack", [mb])
	var mr := InputEventMouseButton.new()
	mr.button_index = MOUSE_BUTTON_RIGHT
	_add("aim", [mr])
	var wu := InputEventMouseButton.new()
	wu.button_index = MOUSE_BUTTON_WHEEL_UP
	var wd := InputEventMouseButton.new()
	wd.button_index = MOUSE_BUTTON_WHEEL_DOWN
	_add("weapon_prev", [wu])
	_add("weapon_next", [wd])
	# 手柄
	var jb := func(b: int) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new(); e.button_index = b; return e
	var ja := func(axis: int, v: float) -> InputEventJoypadMotion:
		var e := InputEventJoypadMotion.new(); e.axis = axis; e.axis_value = v; return e
	InputMap.action_add_event("move_forward", ja.call(JOY_AXIS_LEFT_Y, -1.0))
	InputMap.action_add_event("move_back", ja.call(JOY_AXIS_LEFT_Y, 1.0))
	InputMap.action_add_event("move_left", ja.call(JOY_AXIS_LEFT_X, -1.0))
	InputMap.action_add_event("move_right", ja.call(JOY_AXIS_LEFT_X, 1.0))
	InputMap.action_add_event("run", jb.call(JOY_BUTTON_LEFT_SHOULDER))
	InputMap.action_add_event("interact", jb.call(JOY_BUTTON_A))
	InputMap.action_add_event("attack", ja.call(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	InputMap.action_add_event("flashlight", jb.call(JOY_BUTTON_Y))
	InputMap.action_add_event("inventory", jb.call(JOY_BUTTON_BACK))
	InputMap.action_add_event("map", jb.call(JOY_BUTTON_DPAD_UP))
	InputMap.action_add_event("radio", jb.call(JOY_BUTTON_DPAD_DOWN))
	InputMap.action_add_event("pause", jb.call(JOY_BUTTON_START))
	InputMap.action_add_event("aim", ja.call(JOY_AXIS_TRIGGER_LEFT, 1.0))
	InputMap.action_add_event("reload", jb.call(JOY_BUTTON_X))
	InputMap.action_add_event("dodge", jb.call(JOY_BUTTON_B))
	InputMap.action_add_event("push", jb.call(JOY_BUTTON_RIGHT_SHOULDER))
	InputMap.action_add_event("weapon_next", jb.call(JOY_BUTTON_DPAD_RIGHT))
	InputMap.action_add_event("weapon_prev", jb.call(JOY_BUTTON_DPAD_LEFT))
	InputMap.action_add_event("quick_heal", jb.call(JOY_BUTTON_RIGHT_STICK))
	_add("look_left", [ja.call(JOY_AXIS_RIGHT_X, -1.0)])
	_add("look_right", [ja.call(JOY_AXIS_RIGHT_X, 1.0)])
	_add("look_up", [ja.call(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("look_down", [ja.call(JOY_AXIS_RIGHT_Y, 1.0)])

func _setup_buses() -> void:
	for n in ["Music", "SFX", "Ambient", "UI"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.55; rv.damping = 0.55; rv.wet = 0.10; rv.dry = 1.0; rv.spread = 0.9; rv.predelay_msec = 40.0
		AudioServer.add_bus_effect(sfx, rv)
		var lim := AudioEffectLimiter.new()
		AudioServer.add_bus_effect(sfx, lim)

func set_reverb(wet: float, room: float) -> void:
	var sfx := AudioServer.get_bus_index("SFX")
	var rv := AudioServer.get_bus_effect(sfx, 0) as AudioEffectReverb
	if rv:
		rv.wet = wet; rv.room_size = room

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)

func apply_settings() -> void:
	_bus_vol("Master", settings.master)
	_bus_vol("Music", settings.music)
	_bus_vol("SFX", settings.sfx)
	_bus_vol("Ambient", settings.sfx)
	_bus_vol("UI", settings.sfx)
	if not OS.has_feature("editor_hint"):
		var w := get_window()
		if w:
			var want := Window.MODE_FULLSCREEN if settings.fullscreen else Window.MODE_WINDOWED
			if w.mode != want and not DisplayServer.get_name().begins_with("headless"):
				w.mode = want
	settings_changed.emit()

func _bus_vol(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(max(v, 0.0001)))

func set_setting(k: String, v) -> void:
	settings[k] = v
	apply_settings()
	save_settings()


# ------------------------------------------------------------ 音效
func stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := "res://assets/sfx/%s.ogg" % name
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
		else:
			var arr: Array = []
			for i in 6:
				var p2 := "res://assets/sfx/%s%d.ogg" % [name, i]
				if ResourceLoader.exists(p2):
					arr.append(load(p2))
			_streams[name] = arr
	var s = _streams[name]
	if s is Array:
		var a: Array = s
		return a.pick_random() if a.size() > 0 else null
	return s

func sfx(name: String, vol_db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var st := stream(name)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p

func ui_sfx(name: String, vol_db := -4.0) -> void:
	sfx(name, vol_db, 1.0, "UI")

func sfx3d(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, unit := 3.0, maxd := 40.0) -> AudioStreamPlayer3D:
	if world == null:
		return null
	var st := stream(name)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = "SFX"
	p.unit_size = unit
	p.max_distance = maxd
	p.attenuation_filter_cutoff_hz = 9000.0
	world.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p

# ------------------------------------------------------------ 存档
func save_checkpoint(cp: Dictionary) -> void:
	checkpoint = cp.duplicate(true)
	var cf := ConfigFile.new()
	cf.set_value("save", "cp", checkpoint)
	cf.save(SAVE_PATH)

func load_checkpoint() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		var v = cf.get_value("save", "cp", {})
		if v is Dictionary and not (v as Dictionary).is_empty():
			checkpoint = v
			return true
	return false

func has_save() -> bool:
	return not checkpoint.is_empty() or FileAccess.file_exists(SAVE_PATH)

func clear_save() -> void:
	checkpoint = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
