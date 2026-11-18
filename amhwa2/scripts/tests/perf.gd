extends Node
## 성능 점검: godot --headless --path . -- perf   (프레임당 스크립트 시간, 물리 시간, 광선 수)
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var level = get_tree().get_first_node_in_group("level")
	player.set_baton(true)
	player.lanterns_held = 2
	player.chemlights = 5
	var args := OS.get_cmdline_user_args()
	for i in 60:
		await get_tree().process_frame
	if "noshadow" in args:
		for l in get_tree().root.find_children("*", "Light3D", true, false):
			l.shadow_enabled = false
	if "nopeople" in args:
		for p in get_tree().get_nodes_in_group("person"):
			p.visible = false
	if "noprops" in args:
		for p in level.get_node("Props").get_children():
			p.visible = false
	if "nofog" in args:
		get_tree().get_first_node_in_group("world_env").environment.fog_enabled = false
	var ls := get_tree().root.find_children("*", "Light3D", true, false)
	var vis := ls.filter(func(l): return l.is_visible_in_tree() and l.light_energy > 0.0)
	print("PERF lights total=", ls.size(), " visible=", vis.size(), " shadowed=", vis.filter(func(l): return l.shadow_enabled).map(func(l): return l.get_parent().name + "/" + l.name + ":" + l.get_class()), " ", vis.map(func(l): return l.get_parent().name + "/" + l.name).slice(0, 30))
	print("PERF meshes=", get_tree().root.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.is_visible_in_tree()).size())
	var tiles := [Vector2i(19, 6), Vector2i(10, 6), Vector2i(28, 12)]
	for t in tiles:
		player.global_position = level.tile_center(t)
		var sp := 0.0
		var sph := 0.0
		var prim := 0.0
		var draws := 0.0
		var n := 240
		for i in n:
			player.rotate_y(0.02)
			await get_tree().process_frame
			sp += Performance.get_monitor(Performance.TIME_PROCESS)
			sph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("PERF ", t, " fps %d process %.2fms physics %.2fms  tris %dk draws %d persons=%d lights=%d" % [Engine.get_frames_per_second(), sp / n * 1000.0, sph / n * 1000.0, int(prim / n / 1000.0), int(draws / n), get_tree().get_nodes_in_group("person").size(), get_tree().get_nodes_in_group("light_source").size()])
	get_tree().quit()
