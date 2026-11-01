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
	# 바른 순서: 석상이 아직 돌일 때 랜턴부터 놓고(무릎 꿇는 동안 안전), 헤드램프로 깨운다
	player._toggle_lantern()
	await _wait(240)
	print("TEST after light: state=", p.state, " body_t=", p.body_t, " sanity=", p.sanity)
	player.headlamp.on = false
	await _wait(700)             # 풀리는 데 약 10초
	print("TEST after lantern: state=", p.state, " stiff=", player.stiff)
	var door = get_tree().get_nodes_in_group("blocker").filter(func(b): return b.has_method("interact"))[0]
	door.interact(player)
	print("TEST door open=", door.open, " walkable=", level.is_walkable(level.to_tile(door.global_position)))
	door.interact(player)
	print("TEST door open=", door.open)
	var c = get_node("/root/Main/Level1F/Curtains").get_child(0)
	c.hold(2.0)
	print("TEST curtain open=", c.open, " curtains_open=", GameState.curtains_open)
	var front := level.to_tile(c.global_position + c.global_transform.basis.z * 2.0)
	player.global_position = level.tile_center(front)
	player.look_at(Vector3(c.global_position.x, 0, c.global_position.z), Vector3.UP)
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
	# 랜턴: 놓는 데 시간이 걸리고 천천히 밝아짐
	player.global_position = level.tile_center(Vector2i(16, 12))
	GameState.game_over = false
	player.stiff = 0.0
	player.lanterns_held = 1
	player._toggle_lantern()
	await _wait(20)
	print("TEST kneel placing lanterns_held=", player.lanterns_held, " kneel=", snapped(player.kneel_t, 0.01))
	await _wait(40)
	var lt = player.placed_lanterns[-1]
	print("TEST lantern placed lit_k=", snapped(lt.lit_k, 0.01), " power=", snapped(lt.light.power, 0.01))
	await _wait(160)
	print("TEST lantern later lit_k=", snapped(lt.lit_k, 0.01))
	# 광인이 걸어가는 사람을 붙잡음
	player.global_position = level.tile_center(Vector2i(2, 9))
	player.headlamp.on = false
	var ps = get_tree().get_nodes_in_group("person").filter(func(q): return q.state == 0)
	var walker = ps[0]
	var mad = ps[1]
	walker.global_position = level.tile_center(Vector2i(20, 12)); walker.tile = Vector2i(20, 12); walker.target = walker.tile
	walker._set_state(2)
	mad.global_position = level.tile_center(Vector2i(18, 12)); mad.tile = Vector2i(18, 12); mad.target = mad.tile
	mad._set_state(1); mad.sanity = 0.3; mad.sanity_speed = 0.0
	await _wait(240)
	print("TEST npc grab held_t=", snapped(walker.held_t, 0.1), " held=", walker.held_by == mad, " victim=", mad.victim == walker)
	await _wait(300)
	print("TEST npc after 9s state=", walker.state)
	# 회복한 사람이 현관 밖 마당으로 나가 기다림
	var ps2 = get_tree().get_nodes_in_group("person").filter(func(q): return q.state == 0)
	var w2 = ps2[0]
	var before := GameState.rescued
	player.global_position = level.tile_center(Vector2i(28, 6))
	player.headlamp.on = true
	w2.global_position = level.tile_center(Vector2i(2, 12)); w2.tile = Vector2i(2, 12); w2.target = w2.tile
	w2._set_state(2)
	w2.confusion = 0.0
	await _wait(900)
	# 달리기: 스태미나가 닳고, 다 떨어지면 못 달림
	player.global_position = level.tile_center(Vector2i(5, 12))
	player.rotation.y = -PI * 0.5
	Input.action_press("sprint"); Input.action_press("move_forward")
	await _wait(120)
	print("TEST sprint sprinting=", player.sprinting, " stamina=", snapped(player.stamina, 1))
	await _wait(240)
	print("TEST sprint after 6s stamina=", snapped(player.stamina, 1), " winded=", player.winded, " sprinting=", player.sprinting)
	Input.action_release("sprint"); Input.action_release("move_forward")
	print("TEST exit: waiting=", w2.waiting, " rescued ", before, "->", GameState.rescued, " pos=", w2.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " outdoor=", level.is_outdoor(level.to_tile(w2.global_position)))
	get_tree().quit()
