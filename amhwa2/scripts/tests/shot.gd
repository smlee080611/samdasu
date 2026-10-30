extends Node
## 스크린샷: godot --path . -- shot <파일명> <x> <y> <각도> [pitch] [freeze]
## 추가 옵션(어디든): stiff=70 (굳음 고정), note (첫 쪽지 열기), intro (시작 연출 찍기), grab (붙잡힘)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("shot")
	var out := args[i + 1]
	var level: Level = get_tree().get_first_node_in_group("level")
	var player = get_tree().get_first_node_in_group("player")
	for k in 3:
		await get_tree().process_frame
	player.global_position = level.tile_center(Vector2i(int(args[i + 2]), int(args[i + 3])))
	player.rotation.y = deg_to_rad(float(args[i + 4]))
	if args.size() > i + 5:
		player.head.rotation.x = deg_to_rad(float(args[i + 5]))  # pitch
	if args.size() > i + 6 and args[i + 6] == "freeze":
		for p in get_tree().get_nodes_in_group("person"):
			p.set_process(false)
			p.rotation.y = PI
			if "unshaded" in args:
				for m in p.mats:
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if "lantern" in args:   # 앞에 랜턴을 놓고 한 걸음 물러서서 찍기
		player._toggle_lantern()
		player.global_position += player.global_transform.basis.z * 0.9
	var stiff := -1.0
	for a in args:
		if a.begins_with("stiff="):
			stiff = float(a.substr(6))
	if "note" in args:
		var n = get_tree().get_nodes_in_group("note")[0] if get_tree().has_group("note") else null
		if n:
			n.interact(player)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < (2200 if ("intro" in args or stiff >= 0.0) else 700):
		if stiff >= 0.0:
			player.stiff = stiff
		if "grab" in args:
			player.grab_cooldown = 1.2
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT saved ", out)
	get_tree().quit()
