extends CharacterBody3D
## 플레이어: 이동, 시점, 굳음 수치, 랜턴, 상호작용(문·차광막)
## 자식 노드: Head(Camera3D) > Headlamp(SpotLight3D), Head > InteractRay(RayCast3D)

@export var walk_speed := 3.2
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
const PERSON_SCENE := preload("res://scenes/person.tscn")

func _ready() -> void:
	add_to_group("player")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.ui_blocking:
		rotate_y(-e.relative.x * mouse_sens)
		head.rotation.x = clamp(head.rotation.x - e.relative.y * mouse_sens, -1.3, 1.3)
	if GameState.is_frozen():
		return
	if e.is_action_pressed("toggle_lamp"):
		headlamp.toggle()
	if e.is_action_pressed("lantern"):
		_toggle_lantern()
	if e.is_action_pressed("interact"):
		var t := looking_at()
		if t and t.has_method("interact"):
			t.interact(self)

func _physics_process(dt: float) -> void:
	if GameState.is_frozen():
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := walk_speed * (1.0 - stiff / 100.0 * 0.5)
	velocity = Vector3(dir.x * speed, 0, dir.z * speed)
	move_and_slide()
	# 발소리: 굳을수록 느리고 무거워짐
	if input.length() > 0.1:
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.45 + stiff / 100.0 * 0.3
			Sfx.play("step_%d" % (randi() % 3), -10.0)
	else:
		step_t = 0.0

func _process(dt: float) -> void:
	# 화면 흔들림
	shake = maxf(0.0, shake - dt * 2.2)
	head.h_offset = randf_range(-1, 1) * 0.06 * shake * shake
	head.v_offset = randf_range(-1, 1) * 0.06 * shake * shake
	if GameState.is_frozen():
		return
	grab_cooldown -= dt
	# 길게 누르는 상호작용(차광막)
	var t := looking_at()
	if t and t.has_method("hold") and Input.is_action_pressed("interact"):
		hold_time += dt
		if t.hold(hold_time):
			hold_time = 0.0
	else:
		hold_time = 0.0
	# 몸이 굳는 속도: 랜턴·달빛 곁이나 입구에서는 풀리고, 어둠에서는 빨리 굳는다
	var level := get_tree().get_first_node_in_group("level") as Level
	var at_entrance := level.to_tile(global_position).distance_to(level.entrance_tile) < 1.5
	if at_entrance or LightSystem.light_at(global_position, [get_rid()], true) > 0.25:
		stiff = max(0.0, stiff - 6.0 * dt)
		if at_entrance:
			headlamp.recharge(12.0 * dt)
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

## 교대: 엘리베이터 홀에서 기다리던 사람이 있으면, 내 몸은 그 자리에서 석상이 되고 그 사람이 이어받는다.
## 굳은 내 몸은 다른 석상처럼 나중에 다시 깨워 구할 수 있다. 들고 있던 랜턴은 그 자리에 떨어진다.
func _find_heir() -> Node:
	for p in get_tree().get_nodes_in_group("person"):
		if p.waiting:
			return p
	return null

func _relay(heir: Node) -> void:
	var level := get_tree().get_first_node_in_group("level") as Level
	var t := level.to_tile(global_position)
	var me := PERSON_SCENE.instantiate()
	me.person_name = "간호사 (나)"
	level.get_node("People").add_child(me)
	me.global_position = level.tile_center(t)
	me.rotation.y = rotation.y
	for i in lanterns_held:
		var l: Node3D = lantern_scene.instantiate()
		get_parent().add_child(l)
		l.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		placed_lanterns.append(l)
	lanterns_held = 0
	GameState.rescued -= 1
	global_position = heir.global_position
	rotation = Vector3(0, -PI * 0.5, 0)   # 홀에서 복도 쪽(동쪽)을 보고 시작
	head.rotation.x = 0.0
	heir.queue_free()
	stiff = 0.0
	grab_cooldown = 2.0
	level.refresh_nav()
	Sfx.play("petrify", -2.0, 0.0)
	GameState.relay_happened()

func looking_at() -> Node:
	if ray.is_colliding():
		return ray.get_collider()
	return null

func grabbed(by_name: String) -> void:
	if grab_cooldown > 0.0:
		return
	grab_cooldown = 1.2
	stiff += 25.0
	Sfx.play("grab", 0.0, 0.0)
	shake = 1.0
	headlamp.blackout_t = 0.9   # 붙잡히면 헤드램프가 잠깐 꺼진다. 1초 동안의 완전한 어둠

func _toggle_lantern() -> void:
	for l in placed_lanterns:
		if l.global_position.distance_to(global_position) < 1.6:
			placed_lanterns.erase(l)
			l.queue_free()
			lanterns_held += 1
			Sfx.play("lantern", -6.0)
			return
	if lanterns_held <= 0:
		GameState.say("랜턴이 없다.")
		return
	var l: Node3D = lantern_scene.instantiate()
	get_parent().add_child(l)
	l.global_position = global_position - global_transform.basis.z * 0.8
	placed_lanterns.append(l)
	lanterns_held -= 1
	Sfx.play("lantern", -3.0)

## 어둠 속 광인이 가까울수록, 몸이 굳을수록 심장이 크고 빨리 뛴다
func _update_heartbeat() -> void:
	var danger := clampf((stiff - 40.0) / 60.0, 0.0, 1.0)
	for p in get_tree().get_nodes_in_group("person"):
		if p.state == 1:  # MAD
			var d: float = p.global_position.distance_to(global_position)
			danger = maxf(danger, clampf(1.0 - (d - 1.5) / 7.0, 0.0, 1.0))
	heartbeat.volume_db = linear_to_db(maxf(danger, 0.0001)) + 2.0
	heartbeat.pitch_scale = 0.9 + danger * 0.6
