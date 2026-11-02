extends Node3D
## 케미라이트(꺾으면 빛나는 막대). G로 던지면 바라보는 방향(위아래 각도 포함)으로 날아가
## 중력을 받아 포물선을 그리고, 벽·가구에 맞으면 튕기고, 바닥에서 한두 번 튀다가 멈춘다.
## 약한 빛이라 몸을 지켜 주지는 않지만, 길을 표시하고 광인이 그 자리를 피하게 만든다.
## 꺼지지 않는다: 앞사람이 깔아 둔 초록 불빛은 교대한 다음 사람의 길잡이가 된다.
## 자식 노드: Stick(MeshInstance3D), Light(OmniLight3D + point_light_source.gd)

const GRAVITY := 9.8
const HIT_MASK := 1 | 16          ## 벽·가구·닫힌 문(1), 틈만 열린 문(16)
@onready var light: OmniLight3D = $Light
@onready var stick: MeshInstance3D = $Stick
var vel := Vector3.ZERO
var flying := false
var bounces := 0
var spin := Vector3.ZERO

## 손에서 vel 속도로 던진다
func launch(start: Vector3, velocity: Vector3) -> void:
	global_position = start
	vel = velocity
	flying = true
	spin = Vector3(randf_range(8, 14), randf_range(-4, 4), randf_range(-3, 3))

func _process(dt: float) -> void:
	if not flying:
		return
	# 프레임이 길어도 벽을 뚫지 않게 잘게 나눠 움직인다
	var steps := int(ceil(dt / 0.01))
	var h := dt / steps
	for i in steps:
		if not _step(h):
			break
	rotation += spin * dt

func _step(h: float) -> bool:
	vel.y -= GRAVITY * h
	var from := global_position
	var to := from + vel * h
	var q := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var n: Vector3 = hit.normal
		global_position = hit.position + n * 0.03
		vel = vel.bounce(n) * 0.35          # 벽에 맞으면 힘이 빠지며 튕김
		_bump()
		return true
	if to.y <= 0.02:                          # 바닥
		to.y = 0.02
		if absf(vel.y) < 1.2 or bounces >= 2:
			global_position = to
			_land()
			return false
		vel.y = -vel.y * 0.3
		vel.x *= 0.55
		vel.z *= 0.55
		_bump()
	elif to.y > 2.9:                          # 천장
		to.y = 2.9
		vel.y = -absf(vel.y) * 0.3
	global_position = to
	return true

func _bump() -> void:
	bounces += 1
	Sfx.play_at("toss", global_position, -10.0 - bounces * 3.0, 0.2)

func _land() -> void:
	flying = false
	rotation = Vector3(0, randf() * TAU, PI * 0.5)   # 바닥에 누움
	Sfx.play_at("toss", global_position, -6.0)
