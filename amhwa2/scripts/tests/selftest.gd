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
	player.global_position = level.tile_center(level.to_tile(c.global_position) + Vector2i(0, 1))
	player.rotation.y = 0
	player.head.rotation.x = 0
	await _wait(3)
	print("TEST ray sees curtain=", player.looking_at() == c)
	# 붙잡힘: 헤드램프가 잠깐 꺼지고 화면이 흔들림
	player.grab_cooldown = 0.0
	player.grabbed("x")
	print("TEST grab lamp_off=", not player.headlamp.is_on(), " shake=", player.shake)
	# 교대: 홀에서 기다리는 사람이 있으면 이어받기
	var heir = null
	for q in get_tree().get_nodes_in_group("person"):
		if q.state == 0:
			heir = q
			break
	heir._set_state(2)
	heir.waiting = true
	heir.tile = Vector2i(-100, -100)
	heir.global_position = Vector3(6.6, 0, 16.5)
	GameState.rescued = 1
	var n_before := get_tree().get_nodes_in_group("person").size()
	player.global_position = level.tile_center(Vector2i(16, 6))
	player.stiff = 100.0
	await _wait(10)
	print("TEST relay: game_over=", GameState.game_over, " stiff=", player.stiff, " player=", level.to_tile(player.global_position), " rescued=", GameState.rescued, " persons ", n_before, "->", get_tree().get_nodes_in_group("person").size())
	var me = get_tree().get_nodes_in_group("person").filter(func(q): return q.person_name == "간호사 (나)")
	print("TEST relay statue at=", me[0].tile if me.size() > 0 else "none", " state=", me[0].state if me.size() > 0 else -1)
	await _wait(400)
	print("TEST after relay ui_blocking=", GameState.ui_blocking)
	var ev = get_node("/root/Main/Events")
	ev.door_t = 0.0
	player.global_position = level.tile_center(Vector2i(2, 9))
	player.rotation.y = PI * 0.5
	await _wait(5)
	print("TEST door event closed=", ev.doors_done)
	player.global_position = level.tile_center(Vector2i(16, 9))
	await _wait(200)
	print("TEST station event=", ev.station_done)
	GameState.rescued = 1
	player.global_position = level.tile_center(Vector2i(2, 9))
	await _wait(5)
	print("TEST elevator event=", ev.elevator_done)
	get_tree().quit()
