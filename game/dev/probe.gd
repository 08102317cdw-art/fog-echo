extends Node
func _ready():
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred(main)

func _run(main):
	for i in 5:
		await get_tree().physics_frame
	main.world.set_ow(1.0)
	main.world.set_ow_fences(true)
	for i in 3:
		await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = main.world.get_world_3d().direct_space_state
	for p in [Vector3(83.0, 0.8, 36.0), Vector3(82.6, 0.8, 36.0), Vector3(83.0, 0.8, 37.0), Vector3(83.0, 0.4, 36.0)]:
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.4
		q.shape = sh
		q.transform = Transform3D(Basis(), p)
		var res := space.intersect_shape(q, 8)
		var names := []
		for r in res:
			var c: Object = r.collider
			var info := "%s(%s)" % [c.name, c.get_class()]
			if c is Node3D:
				info += "@%s" % (c as Node3D).global_position
				var par: Node = (c as Node).get_parent()
				if par:
					info += " parent=%s" % par.name
			names.append(info)
		print("P ", p, " -> ", names)
	get_tree().quit()
