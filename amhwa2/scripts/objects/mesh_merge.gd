class_name MeshMerge
## 소품 하나를 이루는 여러 상자·원기둥 메시를, 게임이 시작될 때 재질별로 한 메시로 합친다.
## 에디터에서는 부품이 따로 보여서 고치기 쉽고, 게임 중에는 그리는 횟수(draw call)가 크게 줄어든다.

static func merge(root: Node3D, fade_end := 32.0) -> void:
	if Engine.is_editor_hint():
		return
	var tools := {}   # 재질 -> SurfaceTool
	var parts: Array[Node] = []
	for c in root.get_children():
		if c is MeshInstance3D and c.mesh:
			for s in c.mesh.get_surface_count():
				var mat: Material = c.material_override if c.material_override else c.mesh.surface_get_material(s)
				if not tools.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[mat] = st
				tools[mat].append_from(c.mesh, s, c.transform)
			parts.append(c)
	if parts.size() < 2:
		return
	var am := ArrayMesh.new()
	for mat in tools:
		var st: SurfaceTool = tools[mat]
		st.set_material(mat)
		st.commit(am)
	for p in parts:
		root.remove_child(p)
		p.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "Merged"
	mi.mesh = am
	mi.visibility_range_end = fade_end   # 멀리 있는 소품은 어차피 어둠 속이라 그리지 않음
	root.add_child(mi)
