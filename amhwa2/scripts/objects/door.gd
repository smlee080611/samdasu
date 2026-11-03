extends StaticBody3D
## 병실 문. 열린 정도(amount 0~1)가 연속으로 바뀐다.
##  - E를 누르고 있으면 서서히 열리고, 떼면 그 각도에서 멈춘다. 살짝 누르면 틈만 열린다.
##  - 열려 있는 문을 짧게 탁 누르면 닫힌다.
## 열린 정도에 따라:
##  - 닫힘(< CRACK): 빛도 사람도 막음 (벽 레이어, "blocker")
##  - 틈(CRACK ~ PASS): 빛은 새어 들어가고, 사람은 못 지나감 (플레이어도 못 지나감)
##  - 열림(≥ PASS): 지나갈 수 있음
## 칸 단위 길찾기는 "지나갈 수 있나"만 본다. 각도는 따로 연속값이다.
## 자식 노드: CollisionShape3D, Mesh(Front, Back)

const CRACK := 0.08
const PASS := 0.6
const OPEN_SPEED := 0.8          ## 누르고 있을 때 초당 열리는 정도 (끝까지 약 1.2초)
const LAYER_DOOR_BLOCK := 16     ## 틈일 때: 플레이어만 막고 빛은 통과시키는 충돌 레이어 (5번)

@export var open := false        ## 처음에 활짝 열려 있는지
@export var sideways := false    ## 문이 동서로 놓였으면 체크(90도 회전)

@onready var mesh: Node3D = $Mesh
var amount := 0.0
var shown := 0.0                 # 화면에 보이는 각도 (부드럽게 따라감)
var _hold_start := 0.0
var _passable := false
var _closing := false

func _ready() -> void:
	add_to_group("door")
	if sideways:
		rotation.y = PI * 0.5
	amount = 1.0 if open else 0.0
	shown = amount
	_apply(true)

func _process(dt: float) -> void:
	if _closing:
		amount = maxf(0.0, amount - dt * 2.5)
		if amount <= 0.0:
			_closing = false
			Sfx.play_at("door_close", global_position + Vector3.UP * 1.5)
		_apply()
	shown = lerpf(shown, amount, minf(1.0, dt * 10.0))
	var a := shown * PI * 0.5
	mesh.rotation.y = -a
	mesh.position = Vector3(-1.0 + cos(a), mesh.position.y, sin(a))

## E를 누르고 있는 동안 매 프레임 (player.gd)
func hold(seconds: float) -> bool:
	if seconds <= get_process_delta_time() * 1.5:
		_hold_start = amount
		_closing = false
		if amount < 0.98:
			Sfx.play_at("door_open", global_position + Vector3.UP * 1.5, -6.0)
	if _hold_start < 0.98:
		amount = minf(1.0, _hold_start + seconds * OPEN_SPEED + 0.1)
		_apply()
	return false

## E를 뗐을 때 (player.gd). 짧게 눌렀고 문이 열려 있었으면 닫는다
func release(seconds: float) -> void:
	if seconds < 0.25 and _hold_start > CRACK:
		_try_close()

## 스크립트에서 쓰는 열기/닫기 전환 (공포 사건, 자동 점검)
func interact(_by: Node) -> void:
	if amount > CRACK:
		_try_close()
	else:
		amount = 1.0
		shown = 1.0
		Sfx.play_at("door_open", global_position + Vector3.UP * 1.5)
		_apply()
	open = amount >= PASS

func _try_close() -> void:
	var level := get_tree().get_first_node_in_group("level") as Level
	var t := level.to_tile(global_position)
	for p in get_tree().get_nodes_in_group("person"):
		if p.tile == t or p.target == t:
			GameState.say("문틀에 뭔가 걸려 있다.")
			return
	if level.to_tile(get_tree().get_first_node_in_group("player").global_position) == t:
		return
	amount = 0.0
	shown = 0.0
	_closing = false
	Sfx.play_at("door_close", global_position + Vector3.UP * 1.5)
	_apply()

func _apply(force := false) -> void:
	var closed := amount < CRACK
	var passable := amount >= PASS
	open = passable
	if closed:
		collision_layer = GameState.LAYER_WALL | GameState.LAYER_INTERACT
	elif not passable:
		collision_layer = GameState.LAYER_INTERACT | LAYER_DOOR_BLOCK
	else:
		collision_layer = GameState.LAYER_INTERACT
	if passable:
		remove_from_group("blocker")
	else:
		add_to_group("blocker")
	if force or passable != _passable:
		_passable = passable
		var level = get_tree().get_first_node_in_group("level")
		if level and level.astar.region.size != Vector2i.ZERO:
			level.refresh_nav()

func get_hint() -> String:
	if amount >= 0.98:
		return "E · 문 닫기"
	if amount > CRACK:
		return "E 누르고 있기 · 더 열기   /   짧게 · 닫기"
	return "E 누르고 있기 · 문 열기"
