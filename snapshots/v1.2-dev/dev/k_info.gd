extends SceneTree
func _aabb(n: Node3D) -> AABB:
	var res := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var gt := Transform3D()
		var p: Node = m
		while p and p != n:
			gt = (p as Node3D).transform * gt
			p = p.get_parent()
		var bb: AABB = gt * m.get_aabb()
		if first:
			res = bb; first = false
		else:
			res = res.merge(bb)
	return res
func _init() -> void:
	for m in ["kitchenFridge", "kitchenStove", "kitchenSink", "kitchenCabinet", "kitchenCabinetUpper", "kitchenMicrowave", "table", "chair", "sideTable", "coatRackStanding", "bookcaseOpen", "tableRound", "televisionVintage", "radio", "trashcan", "box", "cardboardBoxClosed", "cardboardBoxOpen", "kitchenBar", "kitchenCoffeeMachine", "lampSquareCeiling", "stoolBar", "rugDoormat", "chairCushion", "bench"]:
		var ps: PackedScene = load("res://assets/models/%s.glb" % m)
		var n: Node3D = ps.instantiate()
		var bb := _aabb(n)
		var s := bb.size
		print("%-22s size=(%.3f, %.3f, %.3f) c=(%.3f,%.3f,%.3f)" % [m, s.x, s.y, s.z, bb.get_center().x, bb.position.y, bb.get_center().z])
		n.free()
	quit()
