extends SpotLight3D
## 헤드램프: 실제 조명 + "light_source" 그룹으로 빛 판정에 참여

@export var battery := 100.0
@export var drain_per_sec := 0.8
var on := true
var protects_body := false   # 헤드램프 빛은 내 몸이 굳는 걸 막아주지는 않는다

func _ready() -> void:
	add_to_group("light_source")

func is_on() -> bool:
	return on and battery > 0.0

func toggle() -> void:
	if battery <= 0.0:
		GameState.say("배터리가 없다.")
		return
	on = not on
	Sfx.play("click", -6.0)

func recharge(amount: float) -> void:
	battery = min(100.0, battery + amount)

func _process(dt: float) -> void:
	if is_on():
		battery -= drain_per_sec * dt
		if battery <= 0.0:
			battery = 0.0
			GameState.say("헤드램프가 꺼졌다.")
	visible = is_on()
	light_energy = 2.6 if battery > 20.0 or randf() > 0.08 else 0.1   # 배터리가 적으면 깜빡임

func light_value(target: Vector3, exclude: Array[RID]) -> float:
	if not is_on():
		return 0.0
	var to := target - global_position
	var d := to.length()
	if d >= spot_range or rad_to_deg((-global_transform.basis.z).angle_to(to)) >= spot_angle * 0.65:
		return 0.0
	if not LightSystem.ray_clear(global_position, target, exclude):
		return 0.0
	return 1.0 - d / spot_range * 0.6
