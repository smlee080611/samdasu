extends Node
## 스크린샷: godot --path . -- shot <파일명> <x> <y> <각도>

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
	for k in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT saved ", out)
	get_tree().quit()
