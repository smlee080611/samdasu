extends OmniLight3D
## 범위형 빛(랜턴, 비상 유도등, 달빛)에 공통으로 붙이는 스크립트.
## 씬에서 power(밝기 판정 세기)와 protects_body(몸을 지켜주는 빛인지)만 바꿔 쓴다.

@export var power := 1.0
@export var protects_body := true
@export var active := true
@export var neutral := false     ## 경광봉처럼 약한 빨간 빛: 풀어 주지도 굳게 하지도 않는다 (밝음 판정에서 빠지고, 어둠 속 굳어 가는 시간만 멈춤)
@export var judge_range := 0.0   ## 게임 판정 거리. 0이면 보이는 빛 범위(omni_range)와 같음. 보이는 빛을 더 넓게 퍼뜨려도 밸런스는 유지

func _ready() -> void:
	add_to_group("light_source")
	visible = active

func set_active(v: bool) -> void:
	active = v
	visible = v

func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if not active:
		return 0.0
	var r := judge_range if judge_range > 0.0 else omni_range
	var d := global_position.distance_to(target)
	if d >= r:
		return 0.0
	if not LightSystem.ray_clear(global_position, target, exclude):
		return 0.0
	return power * (1.0 - d / r)
