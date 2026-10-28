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

var stiff := 0.0          # 0~100, 100이면 완전히 굳음
var grab_cooldown := 0.0
var hold_time := 0.0
var placed_lanterns: Array[Node3D] = []

func _ready() -> void:
	add_to_group("player")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * mouse_sens)
		head.rotation.x = clamp(head.rotation.x - e.relative.y * mouse_sens, -1.3, 1.3)
	if GameState.game_over or GameState.won:
		return
	if e.is_action_pressed("toggle_lamp"):
		headlamp.toggle()
	if e.is_action_pressed("lantern"):
		_toggle_lantern()
	if e.is_action_pressed("interact"):
		var t := looking_at()
		if t and t.has_method("interact"):
			t.interact(self)

func _physics_process(_dt: float) -> void:
	if GameState.game_over or GameState.won:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := walk_speed * (1.0 - stiff / 100.0 * 0.5)
	velocity = Vector3(dir.x * speed, 0, dir.z * speed)
	move_and_slide()

func _process(dt: float) -> void:
	if GameState.game_over or GameState.won:
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
	if stiff >= 100.0:
		GameState.game_over = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.state_changed.emit()

func looking_at() -> Node:
	if ray.is_colliding():
		return ray.get_collider()
	return null

func grabbed(by_name: String) -> void:
	if grab_cooldown > 0.0:
		return
	grab_cooldown = 1.2
	stiff += 25.0
	GameState.say("%s에게 붙잡혔다. 몸이 굳어 온다." % by_name)

func _toggle_lantern() -> void:
	for l in placed_lanterns:
		if l.global_position.distance_to(global_position) < 1.6:
			placed_lanterns.erase(l)
			l.queue_free()
			lanterns_held += 1
			GameState.say("랜턴을 회수했다.")
			return
	if lanterns_held <= 0:
		GameState.say("들고 있는 랜턴이 없다.")
		return
	var l: Node3D = lantern_scene.instantiate()
	get_parent().add_child(l)
	l.global_position = global_position - global_transform.basis.z * 0.8
	placed_lanterns.append(l)
	lanterns_held -= 1
	GameState.say("랜턴을 내려놓았다.")
