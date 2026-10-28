extends OmniLight3D
## 범위형 빛(랜턴, 비상 유도등, 달빛)에 공통으로 붙이는 스크립트.
## 씬에서 power(밝기 판정 세기)와 protects_body(몸을 지켜주는 빛인지)만 바꿔 쓴다.

@export var power := 1.0
@export var protects_body := true
@export var active := true

func _ready() -> void:
	add_to_group("light_source")
	visible = active

func set_active(v: bool) -> void:
	active = v
	visible = v

func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if not active:
		return 0.0
	var d := global_position.distance_to(target)
	if d >= omni_range:
		return 0.0
	if not LightSystem.ray_clear(global_position, target, exclude):
		return 0.0
	return power * (1.0 - d / omni_range)
