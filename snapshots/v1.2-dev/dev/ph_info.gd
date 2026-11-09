extends SceneTree
func _aabb(n: Node3D) -> AABB:
	var res := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = m.transform * m.get_aabb()
		var p := m.get_parent()
		while p and p != n:
			if p is Node3D:
				bb = (p as Node3D).transform * bb
			p = p.get_parent()
		if first:
			res = bb; first = false
		else:
			res = res.merge(bb)
	return res
func _init() -> void:
	var d := DirAccess.open("res://assets/ph")
	for m in d.get_directories():
		var path := "res://assets/ph/%s/%s_1k.gltf" % [m, m]
		var ps: PackedScene = load(path)
		if ps == null:
			print(m, " LOAD FAIL")
			continue
		var n: Node3D = ps.instantiate()
		var bb := _aabb(n)
		var nm := 0
		var tris := 0
		var mats := []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			nm += 1
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var arr = mesh.surface_get_arrays(s)
				tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else 0
				var mt := mesh.surface_get_material(s)
				mats.append(mt.get_class() if mt else "none")
		print("%-32s size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f) meshes=%d tris=%d %s" % [m, bb.size.x, bb.size.y, bb.size.z, bb.position.x, bb.position.y, bb.position.z, nm, tris, str(mats)])
		n.free()
	quit()
