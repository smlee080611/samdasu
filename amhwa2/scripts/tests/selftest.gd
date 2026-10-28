extends Node
## 자동 점검: godot --headless --path . -- selftest

func _ready() -> void:
	_run.call_deferred()

func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	await _wait(5)
	var level: Level = get_tree().get_first_node_in_group("level")
	var player = get_tree().get_first_node_in_group("player")
	var p = get_tree().get_nodes_in_group("person")[0]
	var stand: Vector2i = p.tile + Vector2i(0, 1)
	if not level.is_walkable(stand):
		stand = p.tile + Vector2i(1, 0)
	player.global_position = level.tile_center(stand)
	player.look_at(level.tile_center(p.tile), Vector3.UP)
	player.head.rotation.x = -0.15
	print("TEST person=", p.person_name, " tile=", p.tile, " player=", stand, " persons=", get_tree().get_nodes_in_group("person").size(), " curtains=", GameState.curtains_total)
	await _wait(240)
	print("TEST after light: state=", p.state, " body_t=", p.body_t, " sanity=", p.sanity)
	player._toggle_lantern()
	player.headlamp.on = false
	await _wait(600)
	print("TEST after lantern: state=", p.state, " stiff=", player.stiff)
	var door = get_tree().get_nodes_in_group("blocker").filter(func(b): return b.has_method("interact"))[0]
	door.interact(player)
	print("TEST door open=", door.open, " walkable=", level.is_walkable(level.to_tile(door.global_position)))
	door.interact(player)
	print("TEST door open=", door.open)
	var c = get_node("/root/Main/Level1F/Curtains").get_child(0)
	c.hold(2.0)
	print("TEST curtain open=", c.open, " curtains_open=", GameState.curtains_open)
	player.global_position = level.tile_center(Vector2i(4, 1))
	player.rotation.y = 0
	player.head.rotation.x = 0
	await _wait(3)
	print("TEST ray sees curtain=", player.looking_at() == c)
	get_tree().quit()
