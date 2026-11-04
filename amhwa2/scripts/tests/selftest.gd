extends Node
## 자동 점검: godot --headless --path . -- selftest

func _ready() -> void:
	_run.call_deferred()

var fails := 0

## 새 점검 항목은 ok/FAIL로 적는다 (끝에 실패 개수를 모아 보여 줌)
func _check(what: String, ok: bool, detail := "") -> void:
	if not ok:
		fails += 1
	print("TEST ", what, " ", "ok" if ok else "FAIL", "  ", detail)

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
	door.interact(player)   # 닫힘 → 틈
	door.interact(player)   # 틈 → 활짝
	print("TEST door open=", door.open, " walkable=", level.is_walkable(level.to_tile(door.global_position)))
	door.interact(player)   # 활짝 → 닫힘
	print("TEST door open=", door.open)
	var c = get_node("/root/Main/Floors/Level1F/Curtains").get_child(0)
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
	await _wait(5)
	print("TEST relay heir items baton=", player.has_baton, " chem=", player.chemlights, " dropped_baton=", get_tree().get_root().find_children("*", "Area3D", true, false).filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("baton_pickup.gd")).size())
	player.set_baton(true)
	print("TEST relay statue at=", me[0].tile if me.size() > 0 else "none", " state=", me[0].state if me.size() > 0 else -1)
	await _wait(400)
	print("TEST after relay ui_blocking=", GameState.ui_blocking)
	var ev = get_node("/root/Main/Floors/Level1F/Events")
	ev.door_t = 0.0
	player.global_position = level.tile_center(Vector2i(18, 3))
	player.rotation.y = 0.0
	await _wait(5)
	print("TEST door event closed=", ev.doors_done)
	player.global_position = level.tile_center(Vector2i(19, 9))
	await _wait(200)
	print("TEST station event=", ev.station_done)
	GameState.rescued = 1
	player.global_position = level.tile_center(Vector2i(18, 3))
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
	player.global_position = level.tile_center(Vector2i(18, 3))
	player.headlamp.on = false
	var ps = get_tree().get_nodes_in_group("person").filter(func(q): return q.state == 0)
	var walker = ps[0]
	var mad = ps[1]
	walker.global_position = level.tile_center(Vector2i(28, 12)); walker.tile = Vector2i(28, 12); walker.target = walker.tile
	walker._set_state(2)
	mad.global_position = level.tile_center(Vector2i(26, 12)); mad.tile = Vector2i(26, 12); mad.target = mad.tile
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
	await _wait(2400)
	# 달리기: 스태미나가 닳고, 다 떨어지면 못 달림
	player.global_position = level.tile_center(Vector2i(5, 12))
	player.rotation.y = -PI * 0.5
	Input.action_press("sprint"); Input.action_press("move_forward")
	await _wait(120)
	print("TEST sprint sprinting=", player.sprinting, " stamina=", snapped(player.stamina, 1))
	await _wait(240)
	print("TEST sprint after 6s stamina=", snapped(player.stamina, 1), " winded=", player.winded, " sprinting=", player.sprinting)
	Input.action_release("sprint"); Input.action_release("move_forward")
	var all_out := true
	for k in 20:
		if not level.is_outdoor(level.to_tile(level.take_wait_spot())):
			all_out = false
	# 케미라이트: 던지면 하나 줄고 바닥에 떨어져 빛남, 손에 있으면 붙잡힘을 막음
	player.global_position = level.tile_center(Vector2i(10, 6))
	player.rotation.y = -PI * 0.5
	player.chemlights = 2
	var before_nodes := get_tree().get_nodes_in_group("light_source").size()
	player._throw_chemlight()
	await _wait(150)
	var cl = get_tree().get_nodes_in_group("light_source").size() - before_nodes
	print("TEST chem thrown left=", player.chemlights, " new lights=", cl)
	var sticks = get_tree().get_root().find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("chemlight.gd"))
	var st0 = sticks[-1]
	print("TEST chem landed flying=", st0.flying, " y=", snapped(st0.global_position.y, 0.01), " dist=", snapped(Vector2(st0.global_position.x, st0.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z)), 0.1), " bounces=", st0.bounces)
	# 경광봉: 앞의 광인을 휘두르기로 물러나게, 밀치기로 밀어냄
	var ps3 = get_tree().get_nodes_in_group("person").filter(func(q): return q.state == 0)
	var m3 = ps3[0]
	player.global_position = level.tile_center(Vector2i(16, 6))
	player.rotation.y = -PI * 0.5
	player.stamina = 100.0
	m3.global_position = player.global_position + Vector3(1.2, 0, 0); m3.tile = level.to_tile(m3.global_position); m3.target = m3.tile
	m3._set_state(1); m3.sanity = 0.3; m3.sanity_speed = 0.0
	player.baton_cd = 0.0
	player._baton_attack(1)
	print("TEST baton swing retreat=", snapped(m3.retreat_t, 0.1), " stamina=", snapped(player.stamina, 1))
	await _wait(60)
	m3.global_position = player.global_position + Vector3(1.2, 0, 0); m3.tile = level.to_tile(m3.global_position); m3.target = m3.tile
	player.baton_cd = 0.0
	var p_before: Vector3 = m3.global_position
	player._baton_attack(2)
	print("TEST baton shove pushed=", snapped(m3.global_position.distance_to(p_before), 0.1), " retreat=", snapped(m3.retreat_t, 0.1))
	print("TEST red light neutral lit=", LightSystem.is_lit(m3.global_position, [m3.get_rid()]), " in_neutral=", LightSystem.in_neutral(m3.global_position, [m3.get_rid(), player.get_rid()]))
	# 경광봉 너프: 스태미나 소모가 예전(10, 30)의 2배 이상, 휘두른 뒤 약 1초 무방비(이동·시점 둔화, 재사용 불가)
	_check("baton cost x2+", player.swing_stamina >= 20.0 and player.shove_stamina >= 60.0, "swing=%d shove=%d" % [player.swing_stamina, player.shove_stamina])
	_check("baton recover", player.recover_t >= 1.0 and player.baton_cd >= 1.0 and player.move_mult() < 0.5 and player.look_mult() < 0.5,
			"recover=%.2f cd=%.2f move=%.2f look=%.2f" % [player.recover_t, player.baton_cd, player.move_mult(), player.look_mult()])
	var st_before: float = player.stamina
	player._baton_attack(1)
	_check("baton no reuse during recover", player.stamina == st_before, "stamina %d->%d" % [st_before, player.stamina])
	await _wait(100)
	_check("baton recovered after ~1.5s", player.recover_t == 0.0 and player.move_mult() == 1.0, "recover=%.2f" % player.recover_t)
	# 문: E를 누를 때마다 살짝 열림(틈) → 활짝 → 닫힘. 틈이면 빛은 통과, 사람은 못 지나감
	var d2 = get_node("/root/Main/Floors/Level1F/Doors").get_children().filter(func(d): return d.amount < 0.05)[0]
	var dt2: Vector2i = level.to_tile(d2.global_position)
	d2.interact(player)
	await _wait(2)
	_check("door press 1 crack", d2.amount > 0.05 and d2.amount < 0.6 and not level.is_walkable(dt2) and (d2.collision_layer & 1) == 0,
			"amount=%.2f walkable=%s" % [d2.amount, level.is_walkable(dt2)])
	d2.interact(player)
	await _wait(2)
	_check("door press 2 open", d2.amount >= 0.98 and level.is_walkable(dt2), "amount=%.2f" % d2.amount)
	d2.interact(player)
	await _wait(2)
	_check("door press 3 close", d2.amount == 0.0 and not level.is_walkable(dt2) and (d2.collision_layer & 1) == 1, "amount=%.2f" % d2.amount)
	_check("door no hold", not d2.has_method("hold"))
	# 뒤지기
	var lockers = get_node("/root/Main/Floors/Level1F/Props").get_children().filter(func(q): return q.get("loot") == "battery")
	player.headlamp.battery = 20.0
	var lk = lockers[0]
	lk.hold(0.5); var done: bool = lk.hold(1.5)
	print("TEST search done=", done, " battery=", snapped(player.headlamp.battery, 1), " searched=", lk.searched)
	player.headlamp.adjust_zoom(1.0)
	await _wait(3)
	print("TEST zoom narrow angle=", snapped(player.headlamp.spot_angle, 0.1), " range=", snapped(player.headlamp.spot_range, 0.1))
	print("TEST 20 more wait spots all outdoors=", all_out)
	print("TEST exit: waiting=", w2.waiting, " rescued ", before, "->", GameState.rescued, " pos=", w2.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " outdoor=", level.is_outdoor(level.to_tile(w2.global_position)))
	await _new_tests(level, player)
	print("SELFTEST 새 점검 실패 ", fails, "개")
	get_tree().quit()

func _new_tests(level: Level, player) -> void:
	GameState.game_over = false
	GameState.ui_blocking = false
	player.stiff = 0.0
	# 배터리 총량: 처음 100 + 홀 축전지 + 예비 배터리
	var packs = get_node("/root/Main/Floors/Level1F/Props").get_children().filter(func(q): return q.get("loot") == "battery" and not q.searched)
	var total: float = 100.0 + level.hall_reserve + (packs.size() + 1) * level.battery_amount   # +1: 위 점검에서 하나 뒤짐
	_check("battery budget", total <= 900.0 and packs.size() + 1 <= 7, "total=%d packs=%d hall=%d amount=%d" % [total, packs.size() + 1, level.hall_reserve, level.battery_amount])
	# 홀 충전은 축전지가 바닥나면 멈춘다
	level.hall_reserve = 5.0
	player.headlamp.on = false
	player.headlamp.battery = 50.0
	player.global_position = level.tile_center(level.entrance_tile)
	await _wait(90)
	_check("hall reserve limited", absf(player.headlamp.battery - 55.0) < 1.5 and level.hall_reserve == 0.0, "battery=%.1f reserve=%.1f" % [player.headlamp.battery, level.hall_reserve])
	# 석상을 풀 때 헤드램프 배터리가 크게 닳는다
	var stat = get_tree().get_nodes_in_group("person").filter(func(q): return q.state == 0 and not q.waiting)[0]
	var st_tile: Vector2i = stat.tile
	var stand: Vector2i = st_tile + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if level.is_walkable(st_tile + d):
			stand = st_tile + d
			break
	player.global_position = level.tile_center(stand)
	player.look_at(level.tile_center(st_tile), Vector3.UP)
	player.head.rotation.x = -0.15
	player.headlamp.on = true
	player.headlamp.battery = 100.0
	await _wait(60)
	var drop: float = 100.0 - player.headlamp.battery
	_check("wake drains lamp", drop > 3.5, "1초에 %.1f 닳음 (평소 %.1f) body_t=%.2f" % [drop, player.headlamp.drain_per_sec, stat.body_t])
	stat._set_state(0); stat.body_t = 0.0
	player.headlamp.on = false
	await _stamina(level, player)
	await _floors(level, player)
	level = get_tree().get_first_node_in_group("level")
	# 하룻밤: 시계와 하늘. 시간은 HUD에 숫자로 안 나온다
	var night = get_tree().get_first_node_in_group("night")
	_check("night 25min (1F+2F)", absf(night.night_seconds - 1500.0) < 1.0, "night=%ds" % night.night_seconds)
	night.set_progress(0.5)
	await _wait(2)
	var clocks = get_node("/root/Main/Floors/Level1F/Clocks").get_children()
	var want_min: float = -TAU * fmod(GameState.clock_minutes, 60.0) / 60.0
	_check("wall clocks", clocks.size() == 2 and absf(clocks[0].minute_hand.rotation.z - want_min) < 0.01, "count=%d time=%d:%02d" % [clocks.size(), int(GameState.clock_minutes) / 60, int(GameState.clock_minutes) % 60])
	var sky_half: float = night.sky_mat.get_shader_parameter("dawn")
	night.set_progress(0.9)
	await _wait(2)
	var sky_late: float = night.sky_mat.get_shader_parameter("dawn")
	_check("sky brightens", sky_half > 0.0 and sky_late > sky_half * 2.0, "dawn %.2f -> %.2f" % [sky_half, sky_late])
	var hud = get_node("/root/Main/HUD")
	var clock_txt := "%d:%02d" % [int(GameState.clock_minutes) / 60, int(GameState.clock_minutes) % 60]
	_check("no time on HUD", not (hud.center.text + hud.subtitle.text + hud.hint.text).contains(clock_txt))
	# 해돋이: 차광막을 걷은 방의 석상은 깨어나고, 닫힌 방의 석상은 그대로. 결과 화면
	var c = get_node("/root/Main/Floors/Level1F/Curtains").get_child(0)
	var room: Array[Vector2i] = c.room_tiles()
	_check("sunlit room tiles", room.size() >= 6 and room.size() <= 30, "tiles=%d" % room.size())
	var statues = get_tree().get_nodes_in_group("person").filter(func(q): return q.state == 0 and not q.waiting)
	var sun_p = statues[0]
	sun_p.global_position = level.tile_center(room[-1]); sun_p.tile = room[-1]; sun_p.target = sun_p.tile
	var dark_p = null
	for q in statues:
		if q != sun_p and not room.has(q.tile) and not level.is_outdoor(q.tile):
			var other_sun := false
			for c2 in get_tree().get_nodes_in_group("curtain"):
				if c2.open and c2.room_tiles().has(q.tile):
					other_sun = true
			if not other_sun:
				dark_p = q
				break
	var rescued_before := GameState.rescued
	night.set_progress(0.99995)
	await _wait(6)
	_check("sunrise", GameState.night_over and GameState.is_frozen(), "night_k=%.3f clock=%d" % [GameState.night_k, GameState.clock_minutes])
	_check("sunlit statue cured", sun_p.state == 2, "state=%d" % sun_p.state)
	_check("dark statue stays", dark_p != null and dark_p.state == 0, "state=%d" % (dark_p.state if dark_p else -1))
	await _wait(240)
	_check("result screen", hud.center.text.contains("날이 밝았다") and hud.center.text.contains("%d명" % rescued_before) and hud.center.modulate.a > 0.9,
			hud.center.text.replace("\n", " / "))


## 2층: 계단으로 오르내리기, 층마다 상태 보존, 수술등에 배터리 옮겨 꽂기, 구한 사람이 내려가기, 층을 건너는 교대
func _floors(level1: Level, player) -> void:
	var main = get_tree().get_first_node_in_group("main")
	var l2: Level = main.levels.get(2)
	_check("2F exists", l2 != null and not l2.is_inside_tree() and not l2.has_rest(), "")
	if l2 == null:
		return
	# 층 구조: main.tscn의 Floors 아래 층 씬들, 시작 층만 붙음. 출구는 계단에서 알아서 찾음
	_check("floors layout", main.floors_root.get_child_count() == 1 and main.floors_root.get_child(0) == level1 and main.levels.size() >= 2
			and l2.get_parent() == null, "floors=%d levels=%s" % [main.floors_root.get_child_count(), main.levels.keys()])
	_check("2F exits from stairs", l2.rescue_tile(Vector2i(30, 6)) == Vector2i(36, 4) and l2.rescue_tile(Vector2i(5, 6)) == Vector2i(2, 4),
			"%s %s" % [l2.rescue_tile(Vector2i(30, 6)), l2.rescue_tile(Vector2i(5, 6))])
	_check("stairs pairing", main.find_stairs(l2, "E", 1).arrive_tile == Vector2i(36, 4) and main.find_stairs(level1, "W", 2).arrive_tile == Vector2i(2, 4)
			and GameState.floor_label(-1) == "B1" and GameState.floor_label(2) == "2F", "")
	var p2 := 0
	var packs := 0
	for pr in l2.get_node("Props").get_children():
		if pr.get("loot") == "battery":
			packs += 1
	p2 = l2.get_node("People").get_child_count()
	_check("2F people/batteries", p2 >= 18 and p2 <= 24 and packs == 4 and l2.get_node("Lamps").get_child_count() == 4, "people=%d packs=%d" % [p2, packs])
	# 1층에 랜턴을 하나 놓고 올라간다 → 2층에선 안 보이고, 내려오면 그대로 있어야 한다
	var held_before: int = player.lanterns_held
	player.global_position = level1.tile_center(Vector2i(3, 6))
	player._place()
	var lan1: Node3D = player.placed_lanterns[-1]
	# 서쪽 계단 첫 단 앞으로 걸어 들어가기
	player.global_position = Vector3(4, 0, 6.8)
	player.rotation = Vector3.ZERO
	await _wait(100)
	var here = get_tree().get_first_node_in_group("level")
	_check("stairs up to 2F", GameState.floor_no == 2 and here == l2 and not level1.is_inside_tree() and here.to_tile(player.global_position) == Vector2i(2, 4),
			"floor=%d tile=%s" % [GameState.floor_no, here.to_tile(player.global_position)])
	_check("only 2F people active", get_tree().get_nodes_in_group("person").size() == p2 and not lan1.is_inside_tree(), "persons=%d" % get_tree().get_nodes_in_group("person").size())
	_check("2F is dark", not LightSystem.is_lit(l2.tile_center(Vector2i(9, 15))) and not l2.is_outdoor(Vector2i(9, 15)), "")
	# 2층 홀은 쉴 곳이 아니다: 홀에 서 있어도 몸이 굳는다
	player.global_position = l2.tile_center(Vector2i(19, 3))
	player.stiff = 10.0
	player.headlamp.on = false
	await _wait(60)
	_check("2F hall no rest", player.stiff > 10.5, "stiff=%.1f" % player.stiff)
	# 중환자실 천장등: 배터리를 옮겨 꽂는다
	var lamp = l2.get_node("Lamps/천장등_중환자실1")
	player.headlamp.battery = 100.0
	var tsum := 0.0
	for i in 120:   # E를 2초 누르고 있기
		tsum += 1.0 / 60.0
		lamp.hold(tsum)
	lamp.release(tsum)
	_check("lamp fed from headlamp", absf(lamp.charge - 50.0) < 2.0 and absf(player.headlamp.battery - 50.0) < 2.0, "charge=%.1f battery=%.1f" % [lamp.charge, player.headlamp.battery])
	var icu_p = null
	for q in l2.get_node("People").get_children():
		if q.tile == Vector2i(9, 16):
			icu_p = q
	_check("lamp lights ICU", LightSystem.is_lit(l2.tile_center(Vector2i(10, 15))) and LightSystem.light_at(l2.tile_center(Vector2i(13, 15)), [], true) > 0.25
			and not LightSystem.is_lit(l2.tile_center(Vector2i(10, 6))), "")
	# 등 아래에 서 있으면 몸이 풀린다
	player.global_position = l2.tile_center(Vector2i(10, 15))
	player.stiff = 40.0
	await _wait(60)
	_check("lamp protects body", player.stiff < 40.0, "stiff=%.1f" % player.stiff)
	_check("lamp wakes statue", icu_p != null and (icu_p.state != 0 or icu_p.body_t > 0.0), "state=%d body_t=%.2f" % [icu_p.state if icu_p else -1, icu_p.body_t if icu_p else -1.0])
	var c0: float = lamp.charge
	await _wait(60)
	_check("lamp drains", absf((c0 - lamp.charge) - lamp.drain_per_sec) < 0.3, "1초에 %.2f" % (c0 - lamp.charge))
	_check("headlamp not drained by lamp cure", player.headlamp.battery > 48.0, "battery=%.1f" % player.headlamp.battery)
	# 핵심 기믹: 등을 켜고 문을 닫아 두면, 깨어난 광인이 빛 밖으로 못 달아나 결국 정신이 돌아온다
	var icu := []
	for q in l2.get_node("People").get_children():
		if q.tile.x >= 5 and q.tile.x <= 15 and q.tile.y >= 14:
			icu.append(q)
	var icu_door = null
	for d in l2.get_node("Doors").get_children():
		if l2.to_tile(d.global_position) == Vector2i(10, 13):
			icu_door = d
	_check("ICU door starts closed", icu_door != null and not icu_door.open, "")
	player.global_position = l2.tile_center(Vector2i(22, 12))   # 문 밖 멀리
	lamp.charge = 100.0
	await _wait(1200)
	var cured_n := 0
	for q in icu:
		if not is_instance_valid(q) or q.state == 2:
			cured_n += 1
	_check("lamp + closed door cures room", cured_n >= icu.size() - 1, "%d/%d 회복, 등 남은 양 %.0f" % [cured_n, icu.size(), lamp.charge])
	lamp.charge = 0.0
	# 정신이 돌아온 사람은 가까운 계단으로 내려간다 → 1층에 나타남
	var walker = null
	for q in l2.get_node("People").get_children():
		if q.tile == Vector2i(6, 9):
			walker = q
	walker.global_position = l2.tile_center(Vector2i(2, 6))
	walker.tile = Vector2i(2, 6); walker.target = walker.tile
	walker.confusion = 0.0
	walker._set_state(2)
	player.global_position = l2.tile_center(Vector2i(30, 12))   # 멀리 (따라오지 않게)
	var name_w: String = walker.person_name
	await _wait(300)
	var came = null
	for q in level1.get_node("People").get_children():
		if q.get("came_down") and q.person_name == name_w:
			came = q
	_check("cured go downstairs", not is_instance_valid(walker) and came != null and came.state == 2, "came=%s" % came)
	# 2층에 랜턴 하나 두고 내려간다
	player._place()
	var lan2: Node3D = player.placed_lanterns[-1]
	player.global_position = Vector3(4, 0, 6.8)
	await _wait(100)
	_check("stairs down to 1F", GameState.floor_no == 1 and level1.is_inside_tree() and not l2.is_inside_tree() and lan1.is_inside_tree() and not lan2.is_inside_tree(),
			"floor=%d" % GameState.floor_no)
	player.global_position = level1.tile_center(Vector2i(19, 12))   # 옆에 있으면 따라오려고 기다리니 비켜 준다
	await _wait(240)
	_check("came-down walks out", came.tile != Vector2i(2, 4) or came.waiting, "tile=%s waiting=%s" % [came.tile, came.waiting])
	player._pick_up(lan1)
	# 다시 올라가 랜턴이 그대로 있는지
	player.global_position = Vector3(72, 0, 6.8)
	await _wait(100)
	_check("2F state kept", GameState.floor_no == 2 and lan2.is_inside_tree() and player.global_position.distance_to(l2.tile_center(Vector2i(36, 4))) < 0.5, "pos=%s" % player.global_position)
	player.global_position = lan2.global_position + Vector3(0.5, 0, 0)
	player._pick_up(lan2)
	_check("lanterns back", player.lanterns_held == held_before, "held=%d before=%d" % [player.lanterns_held, held_before])
	# 2층에서 완전히 굳으면 1층 마당에서 기다리던 사람이 이어받는다
	var heir = main.find_heir()
	if heir == null:
		var w = level1.get_node("People").get_child(0)
		w.waiting = true
		heir = w
	var n2 := l2.get_node("People").get_child_count()
	player.global_position = l2.tile_center(Vector2i(30, 6))
	player.headlamp.on = false
	player.stiff = 99.9
	await _wait(30)
	_check("relay across floors", GameState.floor_no == 1 and level1.is_inside_tree() and l2.get_node("People").get_child_count() == n2 + 1 and player.stiff < 1.0,
			"floor=%d people2=%d->%d" % [GameState.floor_no, n2, l2.get_node("People").get_child_count()])
	await _wait(240)   # 교대 안내 화면
	GameState.ui_blocking = false
	player.headlamp.on = false
	# 현관 로비까지 온 사람은 플레이어가 바로 옆에 있어도 따라오지 않고 알아서 나간다 (바로 구출로 셈)
	var lob = null
	for q in level1.get_node("People").get_children():
		if q.state == 0 and not q.waiting:
			lob = q
			break
	lob.global_position = level1.tile_center(Vector2i(19, 15))
	lob.tile = Vector2i(19, 15); lob.target = lob.tile
	lob._set_state(2)
	player.global_position = level1.tile_center(Vector2i(19, 14))   # 바로 옆 (예전엔 여기서 멈춰 기다렸음)
	var r0 := GameState.rescued
	await _wait(30)
	_check("lobby auto exit counts", lob.leaving and GameState.rescued == r0 + 1, "leaving=%s rescued %d->%d" % [lob.leaving, r0, GameState.rescued])
	await _wait(420)
	_check("lobby auto exit walks out", lob.waiting and GameState.rescued == r0 + 1, "tile=%s waiting=%s rescued=%d" % [lob.tile, lob.waiting, GameState.rescued])


## PEAK식 스태미나: 막대 하나, 굳음·부상이 최대치를 깎음, 쓰고 나서 잠깐 뒤에 회복, 굳으면 랜턴 못 놓음, 붕대
func _stamina(level: Level, player) -> void:
	player.global_position = level.tile_center(Vector2i(28, 12))
	player.headlamp.on = true
	player.stiff = 50.0
	player.injury = 20.0
	await _wait(2)
	_check("max stamina cut by stiff+injury", absf(player.max_stamina() - 50.0) < 1.5 and player.stamina <= player.max_stamina() + 0.01,
			"max=%.1f stamina=%.1f" % [player.max_stamina(), player.stamina])
	_check("bar shows cuts", absf(get_node("/root/Main/HUD").stamina_bar.injury - 20.0) < 0.5 and get_node("/root/Main/HUD").stamina_bar.stiff_part > 25.0, "")
	# 굳음 50 이상이면 랜턴을 못 놓는다 (손에 랜턴이 있고, 근처에 놓아 둔 랜턴이 없는 자리에서)
	var held_before_test: int = player.lanterns_held
	player.lanterns_held = 2
	player.global_position = level.tile_center(Vector2i(30, 6))
	var held: int = player.lanterns_held
	player._toggle_lantern()
	_check("lantern locked by stiffness", player.kneel_t == 0.0 and player.lanterns_held == held, "kneel=%.2f" % player.kneel_t)
	player.stiff = 0.0
	player.injury = 0.0
	player.stamina = 100.0
	# 랜턴 놓기는 스태미나 10, 쓴 직후 잠깐은 안 참
	player._toggle_lantern()
	var after: float = player.stamina
	_check("lantern costs stamina", absf(after - (100.0 - player.lantern_stamina)) < 0.5 and player.kneel_t > 0.0, "stamina=%.1f" % after)
	await _wait(30)
	_check("regen waits", player.stamina <= after + 0.5, "0.5초 뒤 %.1f" % player.stamina)
	await _wait(90)
	_check("regen after delay", player.stamina > after + 3.0, "2초 뒤 %.1f" % player.stamina)
	await _wait(30)
	var mine = player.placed_lanterns[-1]
	player.placed_lanterns.erase(mine)
	mine.queue_free()
	player.lanterns_held = held_before_test
	# 붙잡히면 부상, 붕대로 회복 (C 길게)
	player.grab_cooldown = 0.0
	player.grabbed("광인")
	_check("grab injures", player.injury >= player.grab_injury - 0.1, "injury=%.1f stiff=%.1f" % [player.injury, player.stiff])
	player.injury = 50.0
	player.bandages = 1
	Input.action_press("check_pocket")
	await _wait(int(player.bandage_seconds * 60) + 10)
	Input.action_release("check_pocket")
	_check("bandage heals", absf(player.injury - (50.0 - player.bandage_heal)) < 0.5 and player.bandages == 0, "injury=%.1f bandages=%d" % [player.injury, player.bandages])
	player.injury = 100.0
	_check("incapacitated by injury", player.incapacitated(), "")
	player.injury = 70.0; player.stiff = 60.0
	_check("incapacitated by both", player.incapacitated() and player.max_stamina() == 0.0, "max=%.1f" % player.max_stamina())
	player.injury = 0.0; player.stiff = 0.0; player.stamina = 100.0; player.grab_cooldown = 0.0
	# 뒤져서 붕대 찾기
	var bp = null
	for q in level.get_node("Props").get_children():
		if q.get("loot") == "bandage" and not q.searched:
			bp = q
			break
	var b0: int = player.bandages
	if bp:
		bp.hold(0.5); bp.hold(2.0)
	_check("bandage loot", bp != null and player.bandages == b0 + 1, "")
	player.headlamp.on = false
