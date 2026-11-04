extends CharacterBody3D
## 플레이어: 이동, 시점, 굳음 수치, 랜턴, 상호작용(문·차광막)
## 자식 노드: Head(Camera3D) > Headlamp(SpotLight3D), Head > InteractRay(RayCast3D)

@export var walk_speed := 3.2
@export var run_speed := 5.6
## 스태미나: 달리면 닳고(약 4.5초), 쉬면 찬다. 숫자는 안 보이고 거친 숨소리로 느낀다.
## 다 떨어지면 숨이 고를 때까지(40) 다시 못 달린다. 달리는 발소리는 커서 근처 광인이 몰려온다.
@export var stamina_drain := 22.0
@export var stamina_regen := 14.0
var stamina := 100.0
var sprinting := false
var winded := false
var bob_t := 0.0
var pant: AudioStreamPlayer
## 케미라이트: G로 던져 길바닥에 깐다(약 75초 빛남). 약한 빛이라 몸을 지켜 주진 않지만 길 표시가 되고 광인이 그 자리를 피한다.
## 주머니에 넣어 다니고, 개수는 C를 누르고 있을 때 왼손에 펼쳐서 확인한다.
@export var chemlight_scene: PackedScene = preload("res://scenes/chemlight.tscn")
@export var chemlights := 5
var hand_stick: Node3D
var toss_stick: MeshInstance3D
var pocket_t := 0.0
var toss_t := 0.0
var hold_target: Node = null   # E를 누르고 있는 대상 (차광막·문·뒤질 곳)
## 경광봉: 경비원의 빨간 경광봉. 오른손에 늘 들고 있다.
## 빨간 빛은 약해서 광인을 풀어 주지도, 다시 굳게 하지도 않는다(그 자리에서 변화 없음).
## 좌클릭(또는 V) 휘두르기: 앞의 광인을 움찔하게 하고 물러나게 함
## Space 양손 밀치기: 더 세게 밀어내고 잡고 있던 사람도 놓게 함
## 쓸 수는 있지만 막 휘두를 수는 없게: 스태미나를 크게 먹고(달리기와 같은 통을 씀),
## 휘두른 뒤에는 팔이 무거워 약 1초 동안 몸과 고개가 둔해지고 다시 휘두를 수 없다(무방비).
## 그래서 광인 여럿에게 둘러싸이면 경광봉으로는 버틸 수 없다.
@export var swing_stamina := 25.0         ## 휘두르기 스태미나 (예전 10)
@export var shove_stamina := 70.0         ## 밀치기 스태미나 (예전 30). 한 번 밀면 달리기는 거의 못 한다
@export var baton_recover := 1.0          ## 휘두른 동작이 끝난 뒤 무방비 시간(초). 이 동안 재사용 불가
@export var recover_move_mult := 0.35     ## 무방비 동안 이동 속도 배율
@export var recover_look_mult := 0.3      ## 무방비 동안 시점 회전 배율
var recover_t := 0.0                      # 남은 무방비 시간(휘두르는 동작 포함)
var baton: Node3D
var has_baton := true
var baton_cd := 0.0
var swing_t := 0.0
var swing_kind := 0
const BATON_REST_POS := Vector3(0.3, -0.34, -0.6)
const BATON_REST_ROT := Vector3(-0.55, 0.0, -0.22)   # 끝이 앞쪽 위를 향하게
@export var mouse_sens := 0.0025
@export var lantern_scene: PackedScene
@export var lanterns_held := 2

@onready var head: Camera3D = $Head
@onready var headlamp = $Head/Headlamp
@onready var ray: RayCast3D = $Head/InteractRay
@onready var heartbeat: AudioStreamPlayer = $Heartbeat

var stiff := 0.0          # 0~100, 100이면 완전히 굳음
var grab_cooldown := 0.0
var hold_time := 0.0
var placed_lanterns: Array[Node3D] = []
var step_t := 0.0
var shake := 0.0          # 화면 흔들림 세기
var kneel_t := 0.0        # 랜턴을 놓거나 줍는 중 (움직일 수 없음)
var kneel_total := 0.0
var kneel_action := Callable()
const HEAD_Y := 1.6
const PERSON_SCENE := preload("res://scenes/person.tscn")

func _ready() -> void:
	add_to_group("player")
	pant = AudioStreamPlayer.new()
	pant.stream = load("res://sounds/pant.wav")
	pant.volume_db = -60.0
	add_child(pant)
	pant.play()
	_make_hand_stick()
	_make_baton()

func _unhandled_input(e: InputEvent) -> void:
	var was_captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.ui_blocking:
		var sens := mouse_sens * look_mult()
		rotate_y(-e.relative.x * sens)
		head.rotation.x = clamp(head.rotation.x - e.relative.y * sens, -1.3, 1.3)
	if GameState.is_frozen():
		return
	if e.is_action_pressed("toggle_lamp"):
		headlamp.toggle()
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			headlamp.adjust_zoom(0.1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			headlamp.adjust_zoom(-0.1)
	if e.is_action_pressed("throw"):
		_throw_chemlight()
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and was_captured
	if click or e.is_action_pressed("swing"):
		_baton_attack(1)
	if e.is_action_pressed("shove"):
		_baton_attack(2)
	if e.is_action_pressed("lantern"):
		_toggle_lantern()
	if e.is_action_pressed("interact"):
		var t := looking_at()
		if t and t.has_method("interact"):
			t.interact(self)

func _physics_process(dt: float) -> void:
	var searching: bool = hold_target != null and is_instance_valid(hold_target) and hold_target.get("loot") != null and hold_target.loot != ""
	if GameState.is_frozen() or kneel_t > 0.0 or searching or (swing_kind == 2 and swing_t > 0.0):
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var moving := input.length() > 0.1
	# 달리기와 스태미나
	if stamina <= 0.0:
		winded = true
	elif winded and stamina >= 40.0:
		winded = false
	sprinting = moving and input.y < 0.3 and Input.is_action_pressed("sprint") and not winded and recover_t <= 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - stamina_drain * dt)
	else:
		stamina = minf(100.0, stamina + stamina_regen * (1.4 if not moving else 1.0) * (1.0 - stiff / 200.0) * dt)
	var base := run_speed if sprinting else walk_speed
	var speed := base * (1.0 - stiff / 100.0 * 0.5) * move_mult()
	velocity = Vector3(dir.x * speed, 0, dir.z * speed)
	move_and_slide()
	# 발소리: 굳을수록 느리고 무거워짐, 달리면 크고 빠름
	if moving:
		bob_t += dt * (13.0 if sprinting else 8.5)
		step_t -= dt
		if step_t <= 0.0:
			step_t = (0.3 if sprinting else 0.45) + stiff / 100.0 * 0.3
			Sfx.play("step_%d" % (randi() % 3), -3.0 if sprinting else -10.0)
	else:
		step_t = 0.0

func _process(dt: float) -> void:
	# 경광봉: 쿨타임과 휘두르는 모양
	baton_cd = maxf(0.0, baton_cd - dt)
	recover_t = maxf(0.0, recover_t - dt)
	if baton:
		if swing_t > 0.0:
			swing_t = maxf(0.0, swing_t - dt)
			var k := 1.0 - swing_t / (0.3 if swing_kind == 1 else 0.45)
			if swing_kind == 1:   # 오른쪽에서 왼쪽으로 크게 휘두름
				baton.position = Vector3(lerpf(0.32, -0.12, k), -0.3 + sin(k * PI) * 0.08, -0.6)
				baton.rotation = Vector3(-0.55 - sin(k * PI) * 0.5, 0.0, lerpf(-1.0, 1.0, k))
			else:                 # 양손으로 앞으로 쭉 밀기 (봉이 가로로)
				baton.position = Vector3(0.0, -0.3, lerpf(-0.45, -0.8, sin(k * PI)))
				baton.rotation = Vector3(0.0, 0.0, PI * 0.5)
		elif recover_t > 0.0:   # 무방비: 팔이 처져서 천천히 올라온다
			baton.position = baton.position.lerp(BATON_REST_POS + Vector3(0.04, -0.14, 0.06), minf(1.0, dt * 5.0))
			baton.rotation = baton.rotation.lerp(BATON_REST_ROT + Vector3(0.5, 0.0, -0.3), minf(1.0, dt * 5.0))
		else:
			baton.position = baton.position.lerp(BATON_REST_POS, minf(1.0, dt * 12.0))
			baton.rotation = baton.rotation.lerp(BATON_REST_ROT, minf(1.0, dt * 12.0))
	# 왼손: 주머니 확인(C), 던지는 동작
	pocket_t = maxf(0.0, pocket_t - dt)
	if hand_stick:
		hand_stick.visible = (Input.is_action_pressed("check_pocket") or pocket_t > 0.0) and chemlights > 0 and toss_t <= 0.0
	if toss_stick:
		toss_t = maxf(0.0, toss_t - dt)
		toss_stick.visible = toss_t > 0.0
		if toss_t > 0.0:
			var k := 1.0 - toss_t / 0.35
			toss_stick.position = Vector3(lerpf(-0.22, -0.05, k), lerpf(-0.28, -0.08, k), lerpf(-0.45, -0.75, k))
			toss_stick.rotation = Vector3(0.3 + k * 2.0, 0.0, 0.6)
	# 화면 흔들림
	shake = maxf(0.0, shake - dt * 2.2)
	head.h_offset = randf_range(-1, 1) * 0.06 * shake * shake
	head.v_offset = randf_range(-1, 1) * 0.06 * shake * shake
	# 무릎 꿇기: 시선이 내려갔다가 동작이 끝나면 일어남
	var kneel_k := 0.0
	if kneel_t > 0.0 and not GameState.is_frozen():
		kneel_t -= dt
		if kneel_t <= 0.0:
			kneel_t = 0.0
			if kneel_action.is_valid():
				kneel_action.call()
			kneel_action = Callable()
		else:
			kneel_k = sin(PI * (1.0 - kneel_t / kneel_total))
	var bob := sin(bob_t) * (0.055 if sprinting else 0.025) if velocity.length() > 0.5 else 0.0
	head.position.y = lerpf(head.position.y, HEAD_Y - 0.55 * kneel_k + bob, minf(1.0, dt * 12.0))
	# 숨이 찰수록 거친 숨소리가 커진다 (스태미나는 숫자로 보여주지 않음)
	var tired := 1.0 - stamina / 100.0
	pant.volume_db = lerpf(-40.0, -6.0, clampf(tired * 1.3, 0.0, 1.0)) if tired > 0.15 else -60.0
	pant.pitch_scale = 0.9 + tired * 0.35
	if GameState.is_frozen():
		return
	grab_cooldown -= dt
	# 길게 누르는 상호작용(차광막)
	var t := looking_at()
	if t and t.has_method("hold") and Input.is_action_pressed("interact") and (hold_target == null or hold_target == t):
		hold_target = t
		hold_time += dt
		if t.hold(hold_time):
			hold_time = 0.0
	else:
		if hold_target and is_instance_valid(hold_target) and hold_target.has_method("release"):
			hold_target.release(hold_time)
		hold_target = null
		hold_time = 0.0
	# 몸이 굳는 속도: 랜턴·달빛 곁이나 입구에서는 풀리고, 어둠에서는 빨리 굳는다
	var level := get_tree().get_first_node_in_group("level") as Level
	var at_entrance := level.has_rest() and level.to_tile(global_position).distance_to(level.entrance_tile) < 1.5
	if at_entrance or LightSystem.light_at(global_position, [get_rid()], true) > 0.25:
		stiff = max(0.0, stiff - 6.0 * dt)
		if at_entrance:
			_charge_at_hall(level, dt)
	else:
		stiff += (0.6 if headlamp.is_on() else 2.0) * dt
	_update_heartbeat()
	if stiff >= 100.0:
		var heir := _find_heir()
		if heir:
			_relay(heir)
		else:
			GameState.game_over = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			GameState.state_changed.emit()

## 엘리베이터 홀 충전은 비상 축전지에서 나온다. 바닥나면 한 번만 알려 준다 (숫자는 보여 주지 않음)
var _hall_empty_said := false
func _charge_at_hall(level: Level, dt: float) -> void:
	var want := minf(level.hall_charge_rate * dt, 100.0 - headlamp.battery)
	if want <= 0.0:
		return
	if level.hall_reserve <= 0.0:
		if not _hall_empty_said:
			_hall_empty_said = true
			GameState.say("충전기 불이 꺼졌다. 엘리베이터 축전지가 바닥났다.")
		return
	headlamp.recharge(level.draw_hall_charge(want))

## 교대: 엘리베이터 홀에서 기다리던 사람이 있으면, 내 몸은 그 자리에서 석상이 되고 그 사람이 이어받는다.
## 굳은 내 몸은 다른 석상처럼 나중에 다시 깨워 구할 수 있다. 들고 있던 랜턴은 그 자리에 떨어진다.
func _find_heir() -> Node:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		return main.find_heir()   # 위층에서 굳어도 1층 마당에서 기다리던 사람이 이어받는다
	for p in get_tree().get_nodes_in_group("person"):
		if p.waiting:
			return p
	return null

func _relay(heir: Node) -> void:
	kneel_t = 0.0
	kneel_action = Callable()
	var level := get_tree().get_first_node_in_group("level") as Level
	var t := level.to_tile(global_position)
	var me := PERSON_SCENE.instantiate()
	me.person_name = "간호사 (나)"
	level.get_node("People").add_child(me)
	me.global_position = level.tile_center(t)
	me.rotation.y = rotation.y
	# 들고 있던 것은 굳은 자리에 떨어진다: 랜턴, 남은 케미라이트, 경광봉
	for i in lanterns_held:
		var l: Node3D = lantern_scene.instantiate()
		_floor().add_child(l)
		l.position = global_position + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		placed_lanterns.append(l)
	lanterns_held = 0
	# (줍는 물건은 다음 사람이 자리를 옮긴 뒤에 놓는다. 바로 놓으면 그 자리에서 바로 주워져 버림)
	_drop_later.call_deferred(global_position, chemlights, has_baton, _floor())
	# 다음 사람: 헤드램프(배터리 그대로)와 케미라이트 하나만 들고 밖에서 들어온다.
	# 앞사람이 깔아 둔 초록 불빛(케미라이트는 꺼지지 않음)을 따라가 물건을 되찾는다
	chemlights = 1
	set_baton(false)
	for i in hand_stick.get_child_count():
		hand_stick.get_child(i).visible = i < chemlights
	GameState.rescued -= 1
	# 이어받는 사람이 다른 층(1층 마당)에 있으면 그 층으로 바꾼다. 굳은 나와 물건은 원래 층에 남는다
	var heir_level := heir.get_parent().get_parent() as Level
	if heir_level and not heir_level.is_inside_tree():
		get_tree().get_first_node_in_group("main").switch_level(heir_level)
		level = heir_level
	global_position = heir.global_position
	rotation = Vector3.ZERO   # 마당에서 건물(북쪽)을 보고 시작
	head.rotation.x = 0.0
	heir.queue_free()
	stiff = 0.0
	grab_cooldown = 2.0
	level.refresh_nav()
	Sfx.play("petrify", -2.0, 0.0)
	GameState.relay_happened()

func _drop_later(pos: Vector3, chems: int, baton_too: bool, where: Node) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if chems > 0:
		var box: Node3D = load("res://scenes/chem_box.tscn").instantiate()
		box.amount = chems
		where.add_child(box)
		box.position = pos + Vector3(0.4, 0, 0.3)   # 층 원점이 (0,0,0)이라 같은 값. 그 층이 트리 밖이어도 됨
	if baton_too:
		var bp: Node3D = load("res://scenes/baton_pickup.tscn").instantiate()
		where.add_child(bp)
		bp.position = pos + Vector3(-0.4, 0.0, -0.3)
		bp.rotation.y = randf() * TAU

## 바닥에 두는 물건(랜턴, 케미라이트, 떨어뜨린 물건)은 지금 층에 붙인다.
## 그래야 다른 층으로 가면 그 층에 그대로 남아 있고, 돌아오면 다시 보인다.
func _floor() -> Node:
	var lv := get_tree().get_first_node_in_group("level")
	return lv if lv else get_parent()

func looking_at() -> Node:
	if ray.is_colliding():
		return ray.get_collider()
	return null

## 광인이 붙잡을 때 부른다. (막는 수단이 생기면 true를 돌려준다)
func grabbed(by_name: String) -> bool:
	if grab_cooldown > 0.0:
		return false
	grab_cooldown = 1.2
	stiff += 25.0
	Sfx.play("grab", 0.0, 0.0)
	shake = 1.0
	if kneel_t > 0.0:            # 랜턴을 놓거나 줍다가 붙잡히면 취소
		kneel_t = 0.0
		kneel_action = Callable()
	headlamp.blackout_t = 0.9   # 붙잡히면 헤드램프가 잠깐 꺼진다. 1초 동안의 완전한 어둠
	return false

func _throw_chemlight() -> void:
	if chemlights <= 0:
		GameState.say("케미라이트가 없다.")
		return
	chemlights -= 1
	for i in hand_stick.get_child_count():
		hand_stick.get_child(i).visible = i < chemlights
	toss_t = 0.35
	Sfx.play("snap", -4.0, 0.1)
	# 바라보는 방향(위아래 포함)으로 초속 8.5m, 살짝 위로 띄워서 던진다. 왼손에서 출발
	var aim := -head.global_transform.basis.z
	var start := head.global_position - head.global_transform.basis.x * 0.2 - Vector3(0, 0.15, 0) + aim * 0.3
	var v := aim * 8.5 + Vector3(0, 2.0, 0) + velocity * 0.5
	var c: Node3D = chemlight_scene.instantiate()
	_floor().add_child(c)
	c.launch(start, v)

## 손은 하나만 쓴다: 오른손은 경광봉, 왼손은 비워 둔다(헤드램프·랜턴·문·뒤지기는 왼손으로).
## 케미라이트는 주머니에 넣어 두고, 던질 때만 왼손으로 꺼내 꺾어서 던지는 모습이 잠깐 보인다.
## C를 누르고 있으면 왼손에 남은 개수만큼 막대를 펼쳐 보여 준다 (화면 숫자 대신). 주웠을 때도 잠깐 보인다.
func _make_hand_stick() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 1.0, 0.55)
	m.emission_enabled = true
	m.emission = Color(0.35, 1.0, 0.45)
	m.emission_energy_multiplier = 0.35   # 아직 안 꺾어서 희미하게
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.12
	cm.material = m
	hand_stick = Node3D.new()            # 주머니 확인: 부채꼴로 펼친 막대들
	hand_stick.name = "Pocket"
	head.add_child(hand_stick)
	hand_stick.position = Vector3(-0.2, -0.24, -0.48)
	for i in 8:
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation = Vector3(0.2, 0.0, 0.7 - i * 0.18)
		mi.position = Vector3(i * 0.012, 0, 0)
		hand_stick.add_child(mi)
	toss_stick = MeshInstance3D.new()    # 던질 때 왼손에 잠깐 보이는 막대
	toss_stick.mesh = cm
	toss_stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(toss_stick)
	toss_stick.visible = false
	hand_stick.visible = false
	for i in hand_stick.get_child_count():
		hand_stick.get_child(i).visible = i < chemlights

func _make_baton() -> void:
	baton = Node3D.new()
	baton.name = "Baton"
	head.add_child(baton)
	baton.position = BATON_REST_POS
	baton.rotation = BATON_REST_ROT
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.022
	cm.height = 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.25, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.12, 0.05)
	m.emission_energy_multiplier = 0.9
	cm.material = m
	mi.mesh = cm
	mi.position = Vector3(0, 0.2, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	baton.add_child(mi)
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.022
	gm.bottom_radius = 0.022
	gm.height = 0.14
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.08, 0.08, 0.08)
	gm.material = g
	grip.mesh = gm
	grip.position = Vector3(0, -0.11, 0)
	grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 헤드램프에 손잡이 그림자가 벽에 비치던 버그
	baton.add_child(grip)
	var l := OmniLight3D.new()
	l.set_script(load("res://scripts/objects/point_light_source.gd"))
	l.light_color = Color(1.0, 0.15, 0.08)
	l.light_energy = 0.12      # 비상구 표시등 정도로 아주 희미하게
	l.omni_range = 2.0
	l.position = Vector3(0, 0.3, 0)
	l.set("power", 0.25)
	l.set("protects_body", false)
	l.set("neutral", true)   # 풀어 주지도 굳게 하지도 않는 빛
	baton.add_child(l)

## 경광봉 휘두르기(1)·밀치기(2): 앞쪽 부채꼴 안의 광인을 움찔하게 하고 물러나게 한다
func set_baton(v: bool) -> void:
	has_baton = v
	if baton:
		baton.visible = v

func _baton_attack(kind: int) -> void:
	if baton_cd > 0.0 or kneel_t > 0.0 or not has_baton:
		return
	var cost := swing_stamina if kind == 1 else shove_stamina
	if stamina < cost * 0.6:
		GameState.say("숨이 차서 팔이 안 올라간다.")
		return
	stamina = maxf(0.0, stamina - cost)
	swing_kind = kind
	swing_t = 0.3 if kind == 1 else 0.45
	recover_t = swing_t + baton_recover
	baton_cd = recover_t
	Sfx.play("whoosh", -4.0, 0.1)
	var reach := 1.9 if kind == 1 else 1.5
	var cone := 70.0 if kind == 1 else 85.0
	var fwd := -global_transform.basis.z
	var hit := false
	for p in get_tree().get_nodes_in_group("person"):
		if p.state != 1:   # 광인만
			continue
		var to: Vector3 = p.global_position - global_position
		to.y = 0
		if to.length() > reach or rad_to_deg(fwd.angle_to(to)) > cone * 0.5:
			continue
		p.struck(self, kind)
		hit = true
	if hit:
		Sfx.play("thud", 2.0 if kind == 2 else 0.0, 0.1)
		shake = maxf(shake, 0.7 if kind == 2 else 0.55)
		head.rotation.x += 0.035                 # 손에 걸리는 반동
		_hit_stop(0.07 if kind == 1 else 0.1)

## 휘두른 뒤 무방비 동안 이동·시점이 둔해지는 배율 (1이면 보통)
func move_mult() -> float:
	return recover_move_mult if recover_t > 0.0 else 1.0

func look_mult() -> float:
	return recover_look_mult if recover_t > 0.0 else 1.0

## 맞히는 순간 시간이 아주 잠깐 멈칫 (타격감)
func _hit_stop(seconds: float) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0

## 개수가 바뀌었을 때(주움): 주머니를 잠깐 보여 준다
func _update_hand_stick() -> void:
	if hand_stick:
		for i in hand_stick.get_child_count():
			hand_stick.get_child(i).visible = i < chemlights
		pocket_t = 1.2

## 랜턴 놓기·줍기는 무릎을 꿇어야 해서 시간이 걸린다(놓기 0.8초, 줍기 0.6초). 그동안 움직일 수 없다.
func _toggle_lantern() -> void:
	if kneel_t > 0.0:
		return
	for l in placed_lanterns:
		if is_instance_valid(l) and l.is_inside_tree() and l.global_position.distance_to(global_position) < 1.6:
			_kneel(0.6, _pick_up.bind(l))
			return
	if lanterns_held <= 0:
		GameState.say("랜턴이 없다.")
		return
	_kneel(0.8, _place)

func _kneel(seconds: float, action: Callable) -> void:
	kneel_t = seconds
	kneel_total = seconds
	kneel_action = action
	Sfx.play("step_%d" % (randi() % 3), -8.0)

func _place() -> void:
	var l: Node3D = lantern_scene.instantiate()
	_floor().add_child(l)
	l.global_position = global_position - global_transform.basis.z * 0.8
	placed_lanterns.append(l)
	lanterns_held -= 1
	Sfx.play("lantern", -3.0)

func _pick_up(l: Node3D) -> void:
	if not is_instance_valid(l):
		return
	placed_lanterns.erase(l)
	l.put_out()
	lanterns_held += 1
	Sfx.play("lantern", -6.0)

## 어둠 속 광인이 가까울수록, 몸이 굳을수록 심장이 크고 빨리 뛴다
func _update_heartbeat() -> void:
	var danger := clampf((stiff - 40.0) / 60.0, 0.0, 1.0)
	for p in get_tree().get_nodes_in_group("person"):
		if p.state == 1:  # MAD
			var d: float = p.global_position.distance_to(global_position)
			danger = maxf(danger, clampf(1.0 - (d - 1.5) / 7.0, 0.0, 1.0))
	heartbeat.volume_db = linear_to_db(maxf(danger, 0.0001)) + 2.0
	heartbeat.pitch_scale = 0.9 + danger * 0.6
