extends SceneTree
func _init() -> void:
	for m in ["service_pistol", "bolt_action_rifle_7_62", "ammo_box"]:
		var ps: PackedScene = load("res://assets/ph/%s/%s_1k.gltf" % [m, m])
		var n: Node3D = ps.instantiate()
		print("== ", m)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var x := mi as MeshInstance3D
			var gt := Transform3D()
			var p: Node = x
			while p and p != n:
				gt = (p as Node3D).transform * gt
				p = p.get_parent()
			var bb: AABB = gt * x.get_aabb()
			var mats := []
			for s in x.mesh.get_surface_count():
				var mt := x.mesh.surface_get_material(s)
				mats.append(mt.resource_name if mt else "-")
			print("  %-28s c=(%.3f,%.3f,%.3f) s=(%.3f,%.3f,%.3f) %s" % [x.name, bb.get_center().x, bb.get_center().y, bb.get_center().z, bb.size.x, bb.size.y, bb.size.z, str(mats)])
		n.free()
	quit()
