extends SceneTree
## 读取 tools/sculpt_monster.py 输出的二进制，生成带蒙皮数组的 ArrayMesh 资源

func _init() -> void:
	var src := "/data/work/monster.bin"
	var dst := "res://assets/models/monster.res"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("src="):
			src = a.substr(4)
		if a.begins_with("dst="):
			dst = a.substr(4)
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		push_error("cannot open " + src)
		quit(1)
		return
	var magic := f.get_buffer(4).get_string_from_ascii()
	var nv := f.get_32()
	var nt := f.get_32()
	var nb := f.get_32()
	var bones := []
	for i in nb:
		var nbuf := f.get_buffer(16)
		var z := nbuf.find(0)
		var bname := nbuf.slice(0, z if z >= 0 else 16).get_string_from_ascii()
		var p := f.get_32()
		if p >= 2147483648:
			p -= 4294967296
		var h := Vector3(f.get_float(), f.get_float(), f.get_float())
		bones.append([bname, p, h])
	var pos := f.get_buffer(nv * 12).to_float32_array()
	var nrm := f.get_buffer(nv * 12).to_float32_array()
	var col := f.get_buffer(nv * 16).to_float32_array()
	var uv := f.get_buffer(nv * 8).to_float32_array()
	var uv2 := f.get_buffer(nv * 8).to_float32_array()
	var bi := f.get_buffer(nv * 16).to_int32_array()
	var bw := f.get_buffer(nv * 16).to_float32_array()
	var idx := f.get_buffer(nt * 12).to_int32_array()
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var C := PackedColorArray()
	var U := PackedVector2Array()
	var U2 := PackedVector2Array()
	V.resize(nv)
	N.resize(nv)
	C.resize(nv)
	U.resize(nv)
	U2.resize(nv)
	for i in nv:
		V[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		N[i] = Vector3(nrm[i * 3], nrm[i * 3 + 1], nrm[i * 3 + 2])
		C[i] = Color(col[i * 4], col[i * 4 + 1], col[i * 4 + 2], col[i * 4 + 3])
		U[i] = Vector2(uv[i * 2], uv[i * 2 + 1])
		U2[i] = Vector2(uv2[i * 2], uv2[i * 2 + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_NORMAL] = N
	arr[Mesh.ARRAY_COLOR] = C
	arr[Mesh.ARRAY_TEX_UV] = U
	arr[Mesh.ARRAY_TEX_UV2] = U2
	arr[Mesh.ARRAY_BONES] = bi
	arr[Mesh.ARRAY_WEIGHTS] = bw
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.set_meta("bones", bones)
	var err := ResourceSaver.save(mesh, dst, ResourceSaver.FLAG_COMPRESS)
	print("magic=%s nv=%d nt=%d nb=%d -> %s err=%d" % [magic, nv, nt, nb, dst, err])
	quit(0 if err == OK else 1)
