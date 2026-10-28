extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@onready var head = $Head

# 게임 시작 시 마우스 커서를 화면 중앙에 가두고 숨김 (1인칭 필수 설정)
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# 마우스를 움직일 때 시야(머리) 회전
func _input(event):
	if event is InputEventMouseMotion:
		# 고개를 좌우로 돌림 (Y축 회전)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# 고개를 상하로 돌림 (X축 회전 - 카메라만 위아래로 꺾음)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		# 고개가 너무 꺾여서 한 바퀴 돌지 않도록 각도 제한 (-89도 ~ 89도)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	# 1. 중력 적용 (바닥으로 떨어지게 함)
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. 점프 입력 처리
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# 3. WASD 키보드 입력 방향 가져오기 (3D 평면 XZ 기준)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# 4. 이동 실행
	move_and_slide()
