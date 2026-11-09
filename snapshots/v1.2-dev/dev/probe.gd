extends Node
func _ready():
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred(main)

func _run(main):
	for i in 3:
		await get_tree().physics_frame
	for a in main.world.interact_root.get_children():
		var id: String = a.get_meta("iid", "")
		if id in ["school_door", "house_door", "doghouse", "school_gate", "tv"] or id.begins_with("police"):
			print(id, " @ ", (a as Node3D).global_position, " rotY=", rad_to_deg((a as Node3D).global_rotation.y))
	for n in main.world.find_children("*", "Node3D", true, false):
		if String(n.name).begins_with("police") or n.has_meta("model") and String(n.get_meta("model")) == "police":
			print("police node ", n.name, " ", n.global_position, " rot ", n.global_rotation_degrees)
	print("PROBE DONE")
	get_tree().quit()
